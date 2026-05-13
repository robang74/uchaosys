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

#include "uchaos_seq.c" ////////////////////////////////////////////////////////

#define urnd_e32r() ({ _mr_r; })
#define urnd_e32m() ({ _mr_m; })
#define urnd_e64e() ({ _mr_e; })

#define urnd_eclt() ({ _mr_e = nano1rnd(_mr_e); })

#define e _mr_e
__attribute__((always_inline))
static inline
uint64_t nano4rnd(
register urnd_mr_t mr){
  uint64_t register x ;
  x =   e  ^ (e >> 32);
  e = (~e) ^  rotl5(x);
  x =    comb32make(x);
  e =   nano2rnd(e, x);
  return e;
}
#undef e

static inline
uint64_t urnd_emix(void) {
  _mr_e = nano4rnd(_urnd_entr);
                 // RAF: single 64 bit var design is for x86_64
                // and it should be challenged on big-endian or
               // 32bit archictures against be right and faster
  return _mr_e;
}

#endif
