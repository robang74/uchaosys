/*
 * uchaos_seq.h - Character sequencer for uchaos-based jitter hashing
 * (c) 2026, Roberto A. Foglietta <roberto.foglietta@gmail.com>, GPLv2
 */
 #define VERSION "v0.2.9"
 /*
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

#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sched.h>
#include <time.h>

#define PAGEORDR    12
#define PAGESIZE    (2 << PAGEORDR)
#define PAGEFULL(x) (x >> PAGEORDR)
#define TABLESZE    256
#define BLOCKSZE    512
#define WRITESZE    BLOCKSZE

#define LSB32       0xffffffff
#define SEEDZ       0xec19

#define bit(y,x) (((x) >> (y)) & 1)

typedef union {
  uint64_t e;
  uint32_t h[2];
} __attribute__((aligned(8))) urnd_mr_t;

#ifdef UCHAOS_SEQ_C
__thread urnd_mr_t _urnd_entr;
__attribute__((aligned(4)))
__thread uint8_t table[TABLESZE];
#else
extern __thread urnd_mr_t _urnd_entr;
extern __thread uint8_t table[];
#endif

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

#define urnd_e32r() ({ _mr_r; })
#define urnd_e32m() ({ _mr_m; })
#define urnd_e64e() ({ _mr_e; })

#ifndef UCHAOS_SEQ_C
void urnd_eclt(void);
uint64_t urnd_emix(void);
#endif

#endif // UCHAOS_SEQ_H
