/*
 * uchaos_dev.h - Character device for uchaos-based jitter hashing
 * (c) 2026, Roberto A. Foglietta <roberto.foglietta@gmail.com>, GPLv2
 *
 */

#ifndef UCHAOS_DEV_H
#define UCHAOS_DEV_H

/* RAF: barrier here prevents caching skew and potentially
 * pathological concentration by arbitrary cache reordering.
 * However, these phenomena aren't systematic but random.
 * Hence, they constitute welcoming stochastic deviations.
 * While pathological issues can easily skip using a variable
 * defined volatile which is involved in the hot-loop, like
 * the indexes i,j that we can find in djb2tum() -- However,
 * from the PoV of those are in need to review the code and
 * certify its functioning. These "deviations" are an "issue"
 * to justify rather than a wishful feature.
 */
#ifdef __KERNEL__
  #if defined(_USE_RAW_CYCLES) || !defined(MODULE)
    /*
     * Fencing isn't optional here, otherwise unreliable values displaying
     */
    #if defined(CONFIG_ARM64)
      #define USE_RAW_CYCLES 1
	    #include <asm/sysreg.h>
	    #define __early_raw_cycles ({ u64 val; \
		    asm volatile("isb; mrs %0, cntvct_el0" : "=r"(val)); val; })
    #elif defined(CONFIG_X86_64)
      #define USE_RAW_CYCLES 1
		/*
		 * Ignoring rdtscp is fine, supposing uchaos seeds the crng only
		 */
	    #define __early_raw_cycles ({ u64 val; \
		    asm volatile("lfence; rdtsc; shl $32, %%rdx; or %%rdx, %%rax" \
			    : "=a"(val) : : "rdx"); val; })
    #elif defined(CONFIG_RISCV_TIMER)
      #define USE_RAW_CYCLES 1
	    #define __early_raw_cycles ({ u64 val; \
		    asm volatile("fence; rdtime %0" : "=r"(val)); val; })
    #endif
  #endif
  #ifndef USE_RAW_CYCLES
    #define USE_RAW_CYCLES 0
    #define get_time_ns() ({ u64 _t=ktime_get_ns(); \
      asm volatile("" : "+g"(_t)); _t; })
  #else
    #define get_time_ns() __early_raw_cycles
  #endif
  #define __THREAD
#else  // __KERNEL__
  #define __THREAD __thread
#endif // __KERNEL__

#define AB  (6)
#define ABL (AB-3)        //  2 or  3
#define ABN (1<<AB)       // 32 or 64
#define ABX (ABN-1)       // 31 or 63
#define ABx ((ABN>>1)-1)  // 15 or 31
#define ABy ((ABN>>2)-1)  //  7 or 15
#define ABz ((ABN>>3)-1)  //  3 or  7

#define HASHSIZE (ABN >> 3)
#define MAX_INPUT_SIZE (1024 << 3)
#define KBUFSIZE (MAX_INPUT_SIZE + HASHSIZE)
#define EBUF_ITEMS  4
#define rot1       47ULL
#define rot2       17ULL
#define rot3       13ULL
#define rot4        5ULL

#ifdef _USE_MTBL
#define USE_MTBL 1
#ifndef MLTP_SZE
#include "uchaos_tbl.h"
#endif
#define USE_FIX_MLTPLR 0
#define MLTP_MSK   (MLTP_SZE-1)
#define MLTP64(n)  (*(u64 *)(((u8 *)mltp) + ((n) & MLTP_MSK)))
#define HASHSEED   ( (rot4<<24) | (rot3<<16) | (rot2<<8) | rot1 )
#define murmul1    MLTP64(z ^ rot1)
#define murmul2    MLTP64(0 ^ rot2) // RAF: perculiar one
#define murmul3    MLTP64(w ^ rot3)
#define murmul4    MLTP64(t ^ rot4)
#else
#define USE_MTBL 0
#define HASHSEED 14695981039346656037ULL // FNV-1a
//                 0xCBF29CE484222325ULL // FNV-1a
#define murmul1    0xff51afd7ed558ccdULL
#define murmul2    0xc4ceb9fe1a85ec53ULL
#define murmul3    0x9E3779B9045d9f3bULL
#define murmul4    HASHSEED
#endif

#define dtskew(x) (!x || (x)>>28) // 2^29 is the biggest 2^n before 1E9
#define ONESEC msecs_to_jiffies(1 << 10)
#define getprmx16(w) (rot4 + (((w) & ABy) << 1))

#define abs_t(t, x)    ({ t _x = (x);             (t)((_x < 0) ? -_x : _x); })
#ifndef min_t
#define min_t(t, x, y) ({ t _x = (x); t _y = (y); (t)((_x < _y) ? _x : _y); })
#endif
#ifndef max_t
#define max_t(t, x, y) ({ t _x = (x); t _y = (y); (t)((_x > _y) ? _x : _y); })
#endif
#define align_t(t, x)  ({ uintptr_t _m = sizeof(t) -1; \
                                  (typeof(x))(((uintptr_t)(x) + _m) & ~_m); })

typedef u64 __attribute__((aligned(HASHSIZE))) archul_t;

#define ABL_ALIGN(x) align_t(archul_t, x)

static __THREAD archul_t *kbuf = NULL; // Stack allocation, one char device only
static __THREAD archul_t *kbufptr = NULL;

/*
 * ABOUT CODE INVARIABILITY: among different optimisation levels than the current:
 *
 * objdump -d kdev/uchaos_dev.ko | grep -E "rotlbit|knuthmx|murmux3"
 * 0000000000000000 <knuthmx>:
 *
 * with -O2 (current) only knuthmx remains a function, while others two are inlined.
 * Forcing the always_inline attribute the code porting is more robust and uniform.
 * After this change .ko size shrunk: 17752 --> 17648, .ko.gz: 5382 --> 5350 bytes.
 */

__attribute__((always_inline))
static inline archul_t rotlbit(register archul_t n, u8 c) {
    c &= ABX; return (n << c) | (n >> ((-c) & ABX));
}

/* xxhash.com - Extremely fast non-cryptographic hash algorithm
 *
 * uChaos is designed to be compiled with -O1 not -O3 like XXH3 should. With it,
 * the uChaos increase of performance is relatively small for the low contention
 * scenario in which uChaos is used to work. Moreover the Murmur3 is a quality
 * 10/10 hashing function like xxhash, while xxhash adds much more complication.
 * In short terms: murmur3() is fine, and xxhash makes it shiny by comparison.
 *
 * In fact, xxhash is 10% faster in the best case but 2% in uChaos ideal case.
 * Overall performance isn't 1:1 related with the hashing raw speed but it is
 * the only metric that makes an impact here, thus the only one that matters.
 *
 * Test              Hash None    Hash Mur3     Hash XXH3
 * P1 (One proc)     24.9 MB/s    23.5 MB/s     24.1 MB/s
 * P4 (Parallel 4)   67.8 MB/s    61.2 MB/s     63.4 MB/s
 * P8 (Parallel 8)   64.5 MB/s    58.8 MB/s     60.1 MB/s
 *
 * Compiling the source branch _USE_HASH_NONE we can observe that the hashing
 * generates an overload that might vary between 3% and 11%. This explains
 * why a 8x times faster hash has so little overall impact on performance.
 */
#if   defined( _USE_HASH_NONE )
  #define knuthmx(iw)    ({ archul_t _a=iw; ~_a; })
  #define murmux3(ks, p) ({ archul_t _a=ks; _a^(p); })
#elif defined( _USE_HASH_XXH3 )
  #define XXH_STATIC_LINKING_ONLY
  #define XXH_IMPLEMENTATION
  #define XXH_INLINE_ALL
  #define XXH_NO_STREAM
  #include "xxhash.h"
  #define murmux3(ks, p) ({ archul_t _a=ks; \
      (archul_t)XXH3_##ABN##bits_withSeed((const void *)&_a, HASHSIZE, p); })
  #define knuthmx(ks) ({ archul_t _a=ks; \
      (archul_t)XXH3_##ABN##bbits((const void *)&_a, HASHSIZE); })
#else
  __attribute__((always_inline))
  static inline archul_t knuthmx(register archul_t iw) {
      register archul_t w = iw, m = murmul3 ;
      w ^= rotlbit(w,  getprmx16(w)) + rot3 ;
      w *= rotlbit(m,  w ^ rot4)     ;
      w ^= rotlbit(w, (w & 2) ? rot1 : rot2);
      return w;
  }
  __attribute__((always_inline))
  static inline archul_t murmux3(register archul_t z, register archul_t p) {
      z =  p ^ ((z >> (ABx-2)) * murmul1);
      z = (z ^ ( z <<  ABx  )) * murmul2;
      z =  z ^ ( z >> (ABx+2));
      return z;
  }
#endif

#ifdef _SKIP_TSMEM_SEED
#define USE_TSMEM_SEED 0
#define ts_kbufptr    kbufptr
#else
#define USE_TSMEM_SEED 1
#define ts_kbufptr ts.kbufptr
#include "uchaos_mem.h"
#endif

/*
 * ATOMICITY ON A 1CPU vs SMP SYSTEM: the 'loop_failure' flag is read in many
 * places, but wrote in one only: 'volatile' was fine, 'atomic_t' is the way.
 * However also failure_jiff requires multi-thread protection, by 'uchaos_lock'.
 * Because 'uchaos_lock' protects writes, reading a 'volatile bool' is safe.
 * The 'volatile' isn't a SMP memory barrier as we expect but each CPU core
 * cache therefore for the most general implementation 'atomic_t' is the way.
 */
static atomic_t loop_failure = ATOMIC_INIT(0);

/*
 * Every static inline function called in djb2tum will be
 * forced into inlining, regardless of its own attributes.
 */
__attribute__((flatten))
static archul_t djb2tum(archul_t seed, int num)
{
    static __THREAD archul_t dmx = 0, dmn = -1, mavg = 0, ohs = HASHSEED;
#ifdef _PROVIDE_STATS
    static __THREAD u64 nexp = 0, evnt = 0, ncl = 0, tcyl = 0, nhsh = 0;
    static __THREAD archul_t avg = 0, jmn = -1, jmx = 0, javg = 0;
#endif
    static __THREAD unsigned long failure_jiff = 0;

    volatile int i, j = 0; // volatile as current CPU memory barrier in the loop
    register archul_t ent = 0, hsh = ohs; // these two in particular need accel.
    archul_t tns, dlt, dff, ons = 0;
    u8 b0, b1, excp = 0;

#ifdef _CHK_LOOP_FAIL
/*
 * RATIONALE: also flooding the system of printks isn't a good idea, after all.
 * There is not an easy way to fall in this "SYSBUG" but also not an easy way to
 * deal with it because it is not within the coding/logic of this driver's scope.
 */
    if( atomic_read( &loop_failure ) ) {
        if ( time_after(jiffies, failure_jiff + ONESEC) ) {
            failure_jiff = 0;
            atomic_set(&loop_failure, 0);
        } else goto enforcedquit;
    }
#endif

    if( seed ) hsh ^= seed;
    else { ons = ent = 0; } // useless and gcc ignores, unless ons/ent defined static

    if( !ons ) {
        ons = get_time_ns();
        hsh = knuthmx(hsh ^ ons);
    }

    for (i = 0; i < num; i++) {
        if( ent && hsh ) ent ^= rotlbit(ent, getprmx16(hsh));
/* -----------------------------------------------------------------------------
 * WARNING:
 * it might loop forever, because of a BUG rather than falling in a corner case
 * -------------------------------------------------------------------------- */
reschedule:
#ifdef _CHK_LOOP_FAIL
/*
 * RATIONALE: we cannot ignore that in some extreme conditions this code can
 * create a livelock rescheduling for an unlimited number of times. Something
 * exotic like get_time_ns() function pointer was corrupted in a way that it
 * returns always the same value. The expectation is 3-12 range of reschedules
 * for each function cold-call. When 1% might require 100x more, performance
 * is halved and it is a degradation of the service but never a lock. Hopefully,
 * we never see this kind of failure in a production system. In critical systems
 * a lock/hack by get_time_ns() can cost a disaster, not just low-quality entropy
 * or scarcity. Anyway, when get_time_ns() systematically fails much probably
 * other parts of the kernel would create DoS or SysFail in such a way that
 * uChaos will be the least of the issues. Not being a critical one, is enough.
 */
        // 2^10 is a large arbitrary value, don't overlook 'arbitrary' when coding
        if( (++j) >> 10 ) {
            failure_jiff = jiffies;
            #define UCWRN MODULE_NAME ": EMERGENCY ABORT - "
            printk(KERN_ALERT UCWRN "potential infinite reschedule loop!\n");
            if(verbosity)
            prtkinfo("Abort w/ loops=%d,%d kbuf_offset=0x%02lx, jiffies=%lu\n",
                i, j, (unsigned long)kbuf & 255, jiffies);
            atomic_set(&loop_failure, 1);
            // A more drastic way would be unregistering the char device
            goto enforcedquit;
        }
#endif
        /*
         * Immediately after the infinite loop check,
         * hashing stuff is starting with a CPU nap!
         */
        cpu_relax();
#ifdef _PROVIDE_STATS
        nexp++;
#endif
        do {
            tns = get_time_ns();
            dlt = tns - ons;
            if( !dlt ) {                                      goto reschedule; }
            else ons = tns;
        } while( dtskew(dlt) );

        if(dmn == -1) { dmn = dlt;                            goto reschedule; }

        if( dlt < dmn ) {
            dff = dmn - dlt; dmn = dlt;
            ent ^= -dff ^ dmn;
#ifdef _PROVIDE_STATS
            evnt++;
#endif
        } else
        if( dlt > dmx ) {
            dff = dlt - dmn; dmx = dlt;
            ent ^= dff ^ -dmx;
#ifdef _PROVIDE_STATS
            evnt++;
#endif
        } else {
            dff = dlt - dmn;
            ent ^= ~dff ^ dmx;
        }
        if( !dff ) { hsh = knuthmx(hsh);                      goto reschedule; }

        // dff is jittering for the exeption manager activation
        if( dff < min_delta + excp ) {
            excp += 4;                     // excp is accounting vs dff
#ifdef _PROVIDE_STATS
            nexp++;
#endif
        } else {
            // Knuth, based on gold section seeded by 1E-3 ~ 1E-4 event idx
            if( excp ) { hsh = murmux3(hsh, ons); }
            excp = 0;
#ifdef _PROVIDE_STATS
            if( jmn == -1 ) jmn = dff;
            else
            if( dff < jmn ) jmn = dff;
            if( dff > jmx ) jmx = dff;
            avg += dlt; javg += dff;
            ncl++;
#endif
        }

        // Half of the values above and below expected but few around creates
        // uncertanty which affects how ent is calculated but not on average
        // Instead, a trigger by "uncommon" events spawn a ca.10-12bit branch
        // and this detour apports unpredicatbility not just flat-white noise.
        #define MAVG(x) (( tns > min_delta ) ? (x) : ~(x))

        tns  = abs_t(u32, dlt - mavg)  ;
        ent ^= MAVG(dlt)  <<      ABz  ;     // 1st derivative of time
        ent ^= MAVG(ons)  <<     rot3  ;    // current monotonic time
        ent  = knuthmx(ent ^ MAVG(dff));   // 2nd derivative of time

        b0 = ent & 0x01; b1 = ent & 0x02;
        hsh = ( hsh << (4 + (b0 ? b1 : 1)) ) + (b1 ? -hsh : hsh);
        hsh ^= rotlbit( hsh ^ MAVG(tns), getprmx16(ent >> 2) );

        // Moving average, where (mavg * 255) = (mavg + 256 - mavg) but faster
        mavg = ((mavg << 8) - mavg + dlt) >> 8;
    }
#ifdef _PROVIDE_STATS
    nexp -= num;
    tcyl += num;
#endif

/*
 * RATIONALE: if 'goto enforcedquit' is enforced, the system is probably done
 * and near an imminent collapse but this wouldn't allow to creates a DoS here
 * rather than a soft-degradation of the service quality like doing LCG as RNG.
 */
enforcedquit:
    ent = hsh;                             // forget the entropy mixed in hash
    hsh = murmux3(hsh, ohs);               // whitening the hash before deliver
    ohs = ent;                             // keep the hashing internal state

/*
 * RATIONALE: preserving ohs and some other static variable is necessary while
 * in general the variables values is better to reset them for avoid leaks.
 * A more robust solution is using the -ftrivial-auto-var-init=zero by gcc.
 */
    ons = ent = tns = b0 = b1 = 0;         // zeroing for safety before return
    dlt = dff = excp = i = j = 0;          // i,j as volatile do memory barrier
                                           // unfortunately compiler can skip.

#ifdef _PROVIDE_STATS
    nhsh++;
#endif
    return hsh; // to clean this value after return, a pointer should be used
}

static inline ssize_t _unprotected_interuptible_kbuf_fill(size_t len) {
    archul_t *p = __builtin_assume_aligned(kbuf, 8);
    size_t sent;

    if ( !len ) return 0;

    len = (size_t)ABL_ALIGN( len );
    len = min_t(size_t, len, MAX_INPUT_SIZE);

    // Continuous loop to fill the user-requested buffer size
    for (sent = 0; sent < len; sent += HASHSIZE) {
        // Check for signals to remain non-blocking/interruptible
        if (signal_pending(current))
            break;
        *p++ = djb2tum(HASHSEED, loop_mult);
    }

    return sent;
}

/* mur3sum engine for deterministic non-cryptographic hashing
 *
 * Notice that replacing get_time_ns() with a 64bit read from a file, and
 * disabling the USE_TSMEM_SEED initialisation, it works as a mur3sum, an
 * applet that given a file provides a non cryptographic hash like md5sum
 * but faster. The shortcoming is having just 64 or 32 bit in output which
 * requires to port it in 128, 256 or 512 advanced ASM registry operations
 * or for back compatibility with older/tinier CPUs wrap it around a logic
 * that splits the input in a way the predetermined hash size is granted.
 * Both the strategies can be engaged at the same time starting N light
 * threads to elaborate a file long enough to make the multithreading
 * setup O(1) negligible compared with the elaboration time O(size/N).
 */
static inline int __init4_djb2tum(archul_t *ebuf, int nents) {
    archul_t seed = HASHSEED ^ get_time_ns();
#if USE_TSMEM_SEED
    kbuf = ts_mempages_zalloc();
    seed = (!kbuf)  ? knuthmx(seed) : kbufptr_mseed(get_time_ns());
#else
    kbuf = NULL;
    seed =            knuthmx(seed) ;
#endif
    seed = djb2tum(seed,  loop_mult * init_runs); // RAF: !overflow, 7*63 max
    if(!kbuf) {
      // static *ptr allocation at init means: go or not-go, there is not try
      kbufptr = kzalloc(KBUFSIZE, GFP_KERNEL);
      kbuf = (archul_t *)ABL_ALIGN( kbufptr );
    }
    if(!ebuf || nents < 4) return 0 ;

    ebuf[0] = seed;
    // by default settings, the previous call with init_runs brings in variance
    seed    = murmux3(get_time_ns(),  seed);
    ebuf[1] = djb2tum(seed,      loop_mult);
    // by default settings, further calls with loop_mult have a smaller variance
    ebuf[2] = djb2tum(0,         loop_mult);
    ebuf[3] = djb2tum(0,         loop_mult);
    return 4;
}

#endif /* UCHAOS_DEV_H */
