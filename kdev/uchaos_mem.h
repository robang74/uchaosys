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
#define KBUFSIZE (MAX_INPUT_SIZE + HASHSIZE)

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
    memset(kbufptr, 0, KBUFSIZE);
    kfree(kbufptr);
  } else
  if(ts.kbufptr && ts.kbuf_pages_order) {
    memset(ts.kbufptr, 0, (size_t)1 << ts.kbuf_pages_order);
    free_pages((unsigned long)ts.kbufptr, ts.kbuf_pages_order);
  }
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
#define AVOID_CACHE_LINE_TRASHING 1

#if AVOID_CACHE_LINE_TRASHING
#define _IM7(a) IM7((a+1))
#else
#define _IM7(a) IM7(a)
#endif

static void *ts_mempages_zalloc(void) {
  if( ts.kbufptr ) return NULL;

  ts.kbuf_pages_order = get_order(KBUFSIZE);
  if( ts.kbuf_pages_order < get_order(_IM7(TS_N_OFFSET)) )
    return NULL;

  ts.kbufptr = (void *)__get_free_pages(GPF_KBUF_FLAGS, ts.kbuf_pages_order);
  if(!ts.kbufptr) return NULL;
/*
  for (i = 0; i < TS_N_REPLICAS; ++i)
    ts_replicas[i] = (archul_t *)(base + (TS_N_OFFSET * i));
*/
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

static u64 kbufptr_mseed(u64 t) {
  register int i;
  register archul_t v = 0;
  archul_t *p = ts.kbufptr;

  if( p ) return TS_N_ADDVAL;

  for (i = 0; i < TS_N_REPLICAS; ++i) {
      v ^= *( p + (TS_N_OFFSET * i)
#if AVOID_CACHE_LINE_TRASHING
        + i
#endif
            ) + TS_N_ADDVAL;
    v ^= ktime_get_ns() - t;
  }
  return v * TS_N_MULVAL;
}

#endif /* UCHAOS_MEM_H */
