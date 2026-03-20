/*
 * uchaos_dev.c - Character device for uchaos-based jitter hashing
 * (c) 2026, Roberto A. Foglietta <roberto.foglietta@gmail.com>, GPLv2
 *
 * Ported for Linux 5.15.x, usage:
 * echo "seed data" > /dev/uchaos   (Triggers hashing/jitter)
 * cat /dev/uchaos                  (Reads the resulting 64-bit hash)
 *
 * insmod lib/modules/uchaos_dev.ko && dmesg > /dev/uchaos    # to load and init
 * dd if=/dev/uchaos bs=8 count=1 | od -x; done               # to check unicity
 * dd if=/dev/uchaos bs=1k count=1k of=/dev/null              # to check speed
 *
 * dd if=/dev/uchaos bs=8k count=1k | RNG_test.gz.sh stdin64 -tlshow 512K
 * Since the driver uses a 8KB buffer to provide reads to userland, bs=8K
 *
 *******************************************************************************
 *
 * GEMINI 1ST ATTEMPT TO CONVERT GROK'S DRIVER INTO CHARACTER DEVICE DRIVER
 *
 * Converting the driver from a passive entropy source to a character device
 * (/dev/uchaos) makes it much easier to debug, profile, and validate the "chaos"
 * logic through standard user-space tools.
 *
 * AI refactored the code to remove the hwrng framework and replace it with
 * a standard Linux Character Device. I’ve also added Module Parameters so user
 * can tune the dry runs and exception range at runtime without recompiling.
 *
 * Input source: prpr/uchaos-kernlnx-driver-by-grok.c
 * Purpose of using AI: driver template and makefile quick writing
 *
 * Once upon a time we were copying a generic template from a book or Internet
 * nowadays we ask to a chatbot to create a customised one for our needs and
 * then we take care of filling the template of the relevant code.
 *
 * Relevant code primary source: prpr/uchaos.c
 */

#include <linux/jiffies.h>
#include <linux/version.h>
#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/fs.h>
#include <linux/uaccess.h>
#include <linux/ktime.h>
#include <linux/delay.h>
#include <linux/slab.h>
#include <linux/cdev.h>

#define MODULE_NAME "uchaos"
#define DEVICE_NAME MODULE_NAME
#define  CLASS_NAME MODULE_NAME"_cls"
#define DRIVER_VERSION "0.5.9.1"
#define DRIVER_LICENSE "GPL v2"
#define DRIVER_AUTHOR  "Roberto A. Foglietta <roberto.foglietta@gmail.com>"
#define DRIVER_DESCRIPTION "Stochastic scheduler-jitter chaos RNG stream device"

// --- Module Parameters ---

static int badb_init = 0;
module_param(badb_init, int, 0644);
MODULE_PARM_DESC(badb_init,
    " Badboy mode enforces the kernel's crng init ([0]:1:2)");

/*
 * WARNING: badboy mode is a temporary hack which is needed only at init time
 * and before acting in such mode, it should check being called from pid == 1.
 * Instead the following parameter would be better to have as sysctl variables
 * in a production grade implementation. Command line parameters offer a simple
 * and immediately actionable way which is the best for .ko debug and testing
 */

static int verbosity = 4;
module_param(verbosity, int, 0644);
MODULE_PARM_DESC(verbosity,
    " Verbosity level is for debug / testing only (0:[4]:8)");

static int entr_qlty = 100;
module_param(entr_qlty, int, 0644);
MODULE_PARM_DESC(entr_qlty,
    " Entropy source's quality for the kernel (1:[100]:1000)");

static int min_delta = 3;
module_param(min_delta, int, 0644);
MODULE_PARM_DESC(min_delta,
    " Min. expected variance o/wise extra pass  (1:[3]:255)");

static int init_runs = 7;
module_param(init_runs, int, 0644);
MODULE_PARM_DESC(init_runs,
    " N. init runs as Lyapunov decoherence time (1:[7]:63)");

static int loop_mult = 1;
module_param(loop_mult, int, 0644);
MODULE_PARM_DESC(loop_mult,
    " Nun. of turns before providing the output (1:[1]:7)");

// --- Driver State ---

static int major;
static struct class* uchaos_class   = NULL;
static struct device* uchaos_device = NULL;
static DEFINE_MUTEX(uchaos_lock);

// --- Fuctional Definitions ---

#if 0
static const u8 primes64[20] = {  3, 61,  5, 59, 11, 53, 17, 47, 23, 41,
                                 19, 45, 29, 35, 31, 33, 13, 51,  7, 57 };
#define getprmx(val) (primes64[getprmx16((val))])  // because %10 is slower
#define MULTIPLIER 0xff51afd7ed558ccdULL
#define LSHIFT (ABx+2)
#endif

// --- Fuctional Declarations ---

#define prtkinfo(x...) { if(verbosity) printk(KERN_INFO MODULE_NAME ": " x); }

#define _CHK_LOOP_FAIL
#include "uchaos_dev.h"

// --- File Operations ---

static ssize_t dev_read(struct file *fp, char *ubuf, size_t len, loff_t *of)
{
    size_t sent;

    /*
     * RATIONALE: a single read can provide 8KB of data not more. Doing LCG in
     * a middle of a read() on average means 4KB of low-quality entropy which
     * is a VERY bad but RARE condition of a system wide failure, anyway.
     * Within 512 interactions in LCG mode there is a tiny hope that the sequence
     * would not predictable despite the seed isn't known but "tiny" is about
     * gov size attackers not a common threat. However, refuses to provide more
     * LCG instead of entropy is a sany policy: end the current duty and stop.
     */
    if( atomic_read( &loop_failure ) ) return -ETIMEDOUT;

    if (len < HASHSIZE) return -EINVAL;

    if (mutex_lock_interruptible(&uchaos_lock)) // lock for kbuf ------------ //
        return -ERESTARTSYS;

    sent = _unprotected_interuptible_kbuf_fill(len);
    if ( !sent )
        sent = -ERESTARTSYS;
    else
    if ( copy_to_user(ubuf, (u8 *)kbuf, sent) )
        sent = -EFAULT;

    mutex_unlock(&uchaos_lock); // ------------------------------------------- //

    return sent;
}

static ssize_t dev_write(struct file *filep, const char *buffer, size_t len,
    loff_t *offset)
{
    int ret = 0;
    size_t n, nh;
    archul_t hash;

    if(len < HASHSIZE) return -EINVAL;
    len = min_t(size_t, len, MAX_INPUT_SIZE);

    if (mutex_lock_interruptible(&uchaos_lock))
        return -ERESTARTSYS;

    /*
     * RATIONALE: because the access to djb2tum() is blocked at dev_read() after
     * an "infinite loop" failure has been detected, there is no other way to
     * unlock the device than writing 8-bytes at least into the char device.
     * Since uChaos shows, both in kernel and userland spaces, to be able to
     * extract entropy from the micro-chaos conditions it creates with dumb
     * input as well then 8-byte from /dev/zero or echo "ciao bella" is enough
     * to trigger the device and ripristinate its functioning. That's why the
     * printk exists in first place: to inform sysadmin or debugging developers
     * that a certain situation arises and it requires more attention than a
     * simple read again or read later. Because it isn't supposed to happen.
     * Moreover, the timeout of one second does not allow that an automated
     * regular write() like a seeder or a watchdog would do frequently (1ms)
     * can bypass the protection that prevents flooding the system of printks.
     */
    if(copy_from_user((u8 *)kbuf, buffer, len)) {
        ret = -EFAULT;
    } else {
        ret = len;
        for(n = 0, nh = len >> ABL; n < nh; hash ^= (archul_t)kbuf[n++]);
        (void)djb2tum(hash, init_runs);
    }

    mutex_unlock(&uchaos_lock);
    return ret;
}

static struct file_operations fops = {
    .owner = THIS_MODULE,
    .read = dev_read,
    .write = dev_write,
};

#include <linux/random.h>
#include <linux/bitops.h>
#include <linux/hw_random.h>

#ifdef hwrng_register
static int uchaos_read(struct hwrng *rng, void *buf, size_t max, bool wait) {
    mutex_lock(&uchaos_lock);
    max = _unprotected_interuptible_kbuf_fill(max);
    memcpy(buf, kbuf, max);
    mutex_unlock(&uchaos_lock);
    return max;
}
static struct hwrng uchaos_rng = {
    .name = MODULE_NAME,
    .read = uchaos_read,
    .quality = 100,
};
#define retnfree(x) { hwrng_unregister(&uchaos_rng); if(kbufptr) kfree(kbufptr); return (x); }
#else
#define retnfree(x) { if(kbufptr) kfree(kbufptr); return (x); }
#endif

static archul_t *kbufptr = NULL;
typedef void (* credit_entropy_bits_t)(size_t nbits);

static int __init uchaos_init(void)
{
#if defined(_CREDIT_INIT_ADDR) && defined(_STATIC_PRINTK)
  /*
   * hwrng_register() OOPS because a kernel bug despite the backport fix
   * then badboy mode and grep credit_init_bits linux-kernel/System.map
   */
    credit_entropy_bits_t kernel_credit_entropy_bits = (credit_entropy_bits_t)\
        _CREDIT_INIT_ADDR + ((uintptr_t)_printk - _STATIC_PRINTK);
#else
#define kernel_credit_entropy_bits(x)
#endif
    // 256 bit are enough to fullfil the kernel pool
    archul_t ebuf[4];

    // Parameters ranges sanitisation min values
    if( !loop_mult ) loop_mult = 1;
    if( !init_runs ) init_runs = 1;
    if( !min_delta ) min_delta = 1;
    if( !entr_qlty ) entr_qlty = 1;
    // Parameters ranges sanitisation max values
    if( loop_mult >>  3 ) loop_mult =    7;
    if( init_runs >>  6 ) init_runs =   63;
    if( min_delta >>  8 ) min_delta =  255;
    if( entr_qlty > 1000) entr_qlty = 1000;
    // It is a mode index, every value is fine
    // badb_init = badb_init

    prtkinfo("Init (bb:%d) auxiliary entropy source, quality: %d\n",
        badb_init, entr_qlty);
    __init4_djb2tum(ebuf);

    /* -------------------------------------------------------------------- */ {
    size_t len = sizeof(ebuf);

#ifdef hwrng_register                  // UNTESTED branch
    int err;
    uchaos_rng.quality = entr_qlty;
    err = hwrng_register(&uchaos_rng); // this OOPS because a kernel bug
    if (err) {
        printk(KERN_ERR MODULE_NAME
            ": Failed to register as hwrng source: %d\n", err);
        return err;
    }
    add_hwgenerator_randomness(ebuf, len, len << 3);
#else
    if(verbosity >> 2)
        prtkinfo("Inject entropy %ld bytes, 1st seed: 0x%016llx\n",
            len, ebuf[0]);
    #ifdef add_bootloader_randomness   // UNTESTED branch
    add_bootloader_randomness(ebuf, len);
    #else                                                    // backport fix but
    if( badb_init == 2 ) {                                  // in 5.15.202 OOPS!
        add_hwgenerator_randomness(ebuf, len, len << 3);   //
    } else {                                              //
        add_device_randomness(ebuf, len);                // always safe to mix*
    }                                                   //
    if( badb_init == 1 ) {                             //
        if(verbosity >> 1)                            //
            prtkinfo("Credit entropy function address  : 0x%016lx\n",
                (uintptr_t)kernel_credit_entropy_bits);
                                                   // when doing good OOPS and
                                                  // this is the only viable way
        kernel_credit_entropy_bits(len << 3);    // then badboy mode init! ;-)
    }                                           //
    #endif                                     //* always safe, unless paranoic
#endif
    // Only for debug and testing purposes, like everything else here, anyway
    if(verbosity >> 2) {
        get_random_bytes(ebuf, sizeof(ebuf));
        prtkinfo("crng begins w/: 0x%016llx 0x%016llx\n", ebuf[0], ebuf[1]);
    }
    /* -------------------------------------------------------------------- */ }

    // static *ptr allocation at init means: go or not-go, there is not try
    kbufptr = kzalloc(MAX_INPUT_SIZE + HASHSIZE, GFP_KERNEL);
    if (!kbufptr) retnfree( -ENOMEM );
    kbuf = (archul_t *)ABL_ALIGN( kbufptr );

    major = register_chrdev(0, DEVICE_NAME, &fops);
    if (major < 0) retnfree( major );

#if LINUX_VERSION_CODE >= KERNEL_VERSION(6, 4, 0)
    uchaos_class = class_create(CLASS_NAME);
#else
    uchaos_class = class_create(THIS_MODULE, CLASS_NAME);
#endif
    if (IS_ERR(uchaos_class)) {
        unregister_chrdev(major, DEVICE_NAME);
        retnfree( PTR_ERR(uchaos_class) );
    }

    /*
     * RATIONALE: a char device allows to test the quality of the output (audit)
     * optionally also on a living system in production. Despite this could be a
     * leak thus a possible security problem, a flag in compilation and a signed
     * kernel will prevent anyone to load a module or incorporate code that later
     * can be leveraged for a side attack. After all, every debug facility is keen
     * to provide a larger and porose attack surface. No any news about this.
     * The same concept applies to murmur3() as last whitening passage instead of
     * using a cryptographic state of art function like ChaCha20(). Because murmur3
     * spreads the bits, would not masquerade a poor-quality / low-quantity entropy
     * source. This has been shown in userspace with uchaos.c: appling parkmiller32
     * before murmur3, whitening preserve the grid-bias introduced by PM32 zeroing
     * any doubt that murmur3() can conceal a LCG behind its hashing strength.
     */
    uchaos_device = device_create(uchaos_class,
        NULL, MKDEV(major, 0), NULL, DEVICE_NAME);
    if (IS_ERR(uchaos_device)) {
        class_destroy(uchaos_class);
        unregister_chrdev(major, DEVICE_NAME);
        retnfree( PTR_ERR(uchaos_device) );
    }

    if(verbosity >> 1) {
        printk(KERN_INFO MODULE_NAME
            ": kbuf algn: %u bits, size: %u bytes, offs: 0x%02lx lsb\n",
                HASHSIZE << 3, MAX_INPUT_SIZE, (uintptr_t)kbuf & 0xff);
        printk(KERN_INFO MODULE_NAME
            ": kmod loop=%d, init=%d, dlta=%d, qlty=%d, verb=%d\n",
                loop_mult, init_runs, min_delta, entr_qlty, verbosity);
    } else {
        if(verbosity) printk(KERN_INFO MODULE_NAME "loaded");
    }
    return 0;
}

static void __exit uchaos_exit(void)
{
    device_destroy(uchaos_class, MKDEV(major, 0));
    class_destroy(uchaos_class);
    unregister_chrdev(major, DEVICE_NAME);
    if(verbosity)  printk(KERN_INFO MODULE_NAME ": unloaded\n");
    retnfree((void)0);
}

module_init(uchaos_init);
module_exit(uchaos_exit);

MODULE_AUTHOR(DRIVER_AUTHOR);
MODULE_LICENSE(DRIVER_LICENSE);
MODULE_VERSION(DRIVER_VERSION);
MODULE_DESCRIPTION(DRIVER_DESCRIPTION);

