/*
 * uchaos_mem.h - Character device for uchaos-based jitter hashing
 * (c) 2026, Roberto A. Foglietta <roberto.foglietta@gmail.com>, GPLv2
 *
 */

#ifndef UCHAOS_MEM_H
#define UCHAOS_MEM_H

#define TS_N_ORDER 3
#define TS_N_MULVAL murmul1
#define TS_N_ADDVAL murmul2
#define TS_N_OFFSET (HASHSIZE << 1)
#define TS_N_REPLICAS ((1 << TS_N_ORDER) - 1)
#define GPF_KBUF_FLAGS (GFP_KERNEL | __GFP_ZERO | __GFP_COMP | __GFP_NOWARN)
#define IM7(a) ({ size_t _a = (a); ((_a << TS_N_ORDER) - _a); }) // 2^n - 1

static struct {
  void *kbufptr;
  unsigned kbuf_pages_order;
//archul_t *replicas[TS_N_REPLICAS];
} ts = { 0 };

/*
 * RATIONALE: reset the buffer to avoid the risk of leaking precious information
 */
static void kbufptr_zfree(void *kbufptr) {
  if(kbufptr) {
    memset(kbufptr, 0, MAX_INPUT_SIZE);
    kfree(kbufptr);
  }
#ifdef __KERNEL__
  else
  if(ts.kbufptr && ts.kbuf_pages_order) {
    memset(ts.kbufptr, 0, (size_t)PAGE_SIZE << ts.kbuf_pages_order);
    free_pages((unsigned long)ts.kbufptr, ts.kbuf_pages_order);
  }
#endif
}

/*
 * RATIONALE: doing a plain p + (TS_N_OFFSET * i) with TS_N_OFFSET as m * 2^n,
 * all the accessed addresses can easily map to the exact same cache set(s).
 * This causes conflict misses and thrashing inside the limited ways of that set
 * (L1d is usually 8-way). This phenomenon is usually named as cache line trashing.
 *
 * Despite being usually unwelcome, cache line trashing might help to collect
 * wider distributed timings about memory reads. However, it depends on hardware.
 * On the other hand, increasing the address to read by an incremental unit,
 * disrupts the 64bit alignment which also affects the access time spread.
 */
#if 0 // Current version is using _printk code as data for scrambling the pointer
#ifdef _TRASH_CACHE_LINE
#define AVOID_CACHE_LINE_TRASHING 0
#else
#define AVOID_CACHE_LINE_TRASHING 127
#endif
#define _IM7(a) IM7((a)+AVOID_CACHE_LINE_TRASHING)
#else
#define _IM7(a) IM7(a)
#endif

static void *ts_mempages_zalloc(void) {
  if( !ts.kbufptr ) {
    ts.kbuf_pages_order = get_order(MAX_INPUT_SIZE);
    if( ts.kbuf_pages_order < get_order(_IM7(TS_N_OFFSET)) )
      return NULL;
    ts.kbufptr = (void *)__get_free_pages(GPF_KBUF_FLAGS, ts.kbuf_pages_order);
  }
  return ts.kbufptr;
}

/*
 * RATIONALE: tail-slayer style DRAM channel hedging for RAM read tail latency
 *
 * An isolated virtual machine with a software emulation doesn't provide entropy
 * from the scheduler jittering because it is deterministic unless KVM passthrough
 * However, from a recent Laurie Wired's work (+), the RAM access provide latencies
 * which, in particular, have a relatively long tail, sometimes. Can it seed?
 *
 * (+) Tailslayer - https://github.com/robang74/tailslayer (fork)
 *
 * An isolated qemu software virtual machine still has access to RAM and therefore
 * it might leak some hardware-related latency and related jittering which can
 * provide an unpredictable seed. Which would be great for a deterministic scenario.
 *
 * In fact, in an isolated software virtual machine, as expected. uChaos shown to
 * be deterministic, thus repetible among reboots, thus predictable but RAM access?
 *
 * The straightforward answer is no, it cannot provide entropy, because -icount.
 * In fact, time w/-icount isn't flowing but it is a counter based on the number of
 * instructions executed and RAM accesses are just instructions. Moreover the work
 * by Laurie Wired is based on the first returning among parallel concurrent threads.
 *
 * In the most deterministic scenario, the SW emulated VM has a single-core CPU only.
 * Hence, the first write of this example is a sequential read of memory addresses.
 * As expected with QZERO=1 the TS mem access seeding is repeatable among reboots.
 */

#define IDIV(a,b) ({ u64 _a=(a), _b=(b); (_a + (_b >> 1)) / _b; })

#ifndef _NO_PROVIDE_STATS // Logic inversion, stats here are light a 1-time only
  #ifndef  _PROVIDE_STATS
  #define  _PROVIDE_STATS
  #endif
#endif

static u64 kbufptr_mseed(u64 t) {
  register unsigned i;
  register archul_t v = TS_N_ADDVAL;
  volatile archul_t *ptr = ts.kbufptr;
  volatile u64 *buf = (u64 *)ts.kbufptr;
  u64 msk, sze = ((u64)PAGE_SIZE << ts.kbuf_pages_order) >> 1;
  u64 t1, t2, dt, odt = 0;
#ifdef _PROVIDE_STATS
  u64 mint = -1ULL, maxt = 0, avgt = 0;
#endif

  if( (t1 = t) && ptr && buf && sze ) {
    // creating a mask for half of the buffer size and 64-bit aligned addresses
    msk = ((sze - 1) >> 3) << 3;
    for (i = 0; i < TS_N_REPLICAS; ++i) {
      memcpy((void *)ptr, (void *)_printk + ((u16)t1 & msk), sze);
      v ^= *ptr + TS_N_ADDVAL;
      t2 = get_time_ns();
      dt = (t2 > t1) ? t2 - t1 : 0;
      v ^= rotlbit(v + dt - odt, dt);
      ptr = (volatile archul_t *)( (u64)buf + ((v + t1) & msk) );
#ifdef _PROVIDE_STATS
      if(mint > dt) mint = dt;
      if(maxt < dt) maxt = dt;
      avgt += dt;
#endif
      odt = dt;
      t1 = t2;
    }
  }
#ifdef _PROVIDE_STATS
  avgt = i ? IDIV(avgt * 10, i) : 0;
  prtkinfo("Init mts %uB access x%u times: %u < %u.%u > %u %s\n",
    (u32)sze, i, (u32)mint, (u32)(avgt / 10), (u32)(avgt % 10),
      (u32)maxt, USE_RAW_CYCLES ? "uP" : "nS");
#endif
  return v * TS_N_MULVAL;
}

#endif /* UCHAOS_MEM_H */
