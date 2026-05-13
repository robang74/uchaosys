/*
 * uchaos_seq.h - Character sequencer for uchaos-based jitter hashing
 * (c) 2026, Roberto A. Foglietta <roberto.foglietta@gmail.com>, GPLv2
 *
 * Public interface, it hides internal but speed drops by 2/3 because functions.
 *
 * USAGE:
 *
 * warming-up, xN times: urnd_eclt(); { code block; } urnd_eclt();
 *                       ^^^--- cpu yeld/relax jitter does enough
 * generation, loop: r = urnd_e32r(); { some_thing; } urnd_eclt();
 *                                    ^^^--- optional part ---^^^
 * bits-comb 64 bit: mr = urnd_e64mr(); 32bit comb + 32bit entropy
 *
 * linking requires: uchaos_seq.o (or compiling with the uchaos_seq.c)
 *
 * STATUS:
 *
 * This .h is barely tested, provided just for generic API example
 */

#ifndef UCHAOS_SEQ_H
#define UCHAOS_SEQ_H

#include "uchaos_seq.c"

typedef union {
  uint64_t e;
  uint32_t h[2];
} __attribute__((aligned(8))) urnd_mr_t;

static __thread urnd_mr_t _urnd_entr;

#if __BYTE_ORDER == __BIG_ENDIAN
// RAF: the order is inverted in big-endian systems
  #define urnd_mr32_m(e) (e).h[1]
  #define urnd_mr32_r(e) (e).h[0]
#else
  #define urnd_mr32_m(e) (e).h[0]
  #define urnd_mr32_r(e) (e).h[1]
#endif
#define _mr_e             _urnd_entr.e
#define _mr_m urnd_mr32_m(_urnd_entr)
#define _mr_r urnd_mr32_r(_urnd_entr)

#define urnd_eclt() ({ _mr_e = nano1rnd(_mr_e); })

__attribute__((always_inline)) static inline
void _urnd_e32x(uint32_t * mp,uint32_t *rp) {
  _mr_e = nano3rnd(_mr_e, mp, rp);
}

static inline
uint32_t urnd_e32r(void) {
  __attribute__((aligned(4)))
  uint32_t m, r;
  _urnd_e32x(&m, &r);
  return r;
}

static inline
uint32_t urnd_e32m(void) {
  __attribute__((aligned(4)))
  uint32_t m, r;
  _urnd_e32x(&m, &r);
  return m;
}

#define _u32_ptr(m,n) (&((uint32_t *)&m)[!!n])

static inline
uint64_t urnd_e64mr(void) {
  __attribute__((aligned(8)))
  uint64_t mr; // RAF: single 64 bit var design is for x86_64
              // and it should be challenged on big-endian or
             // 32bit archictures against be right and faster
  _urnd_e32x(_u32_ptr(mr,0), _u32_ptr(mr,1));
  return mr;
}

#define urnd_e64e() ({ _mr_e; })

#endif
