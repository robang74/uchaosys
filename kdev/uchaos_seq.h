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

__attribute__((aligned(8)))
static uint64_t __thread _urnd_entr;

void urnd_eclt(void) { _urnd_entr = nano1rnd(_urnd_entr); }

#define _urnd_e32x(mp,rp) { _urnd_entr = nano3rnd(_urnd_entr, mp, rp); }

uint32_t urnd_e32r(void) {
  uint32_t m, r;
  _urnd_e32x(&m, &r);
  return r;
}

uint32_t urnd_e32m(void) {
  uint32_t m, r;
  _urnd_e32x(&m, &r);
  return m;
}

#define _u32_ptr(m,n) (&((uint32_t *)&m)[!!n])

uint64_t urnd_e64mr(void) {
  uint64_t mr; // RAF: single 64 bit var design is for x86_64
              // and it should be challenged on big-endian or
             // 32bit archictures against be right and faster
  _urnd_e32x(_u32_ptr(mr,0), _u32_ptr(mr,1));
  return mr;
}

#define urnd_e64e() ({ _urnd_entr; })

#endif
