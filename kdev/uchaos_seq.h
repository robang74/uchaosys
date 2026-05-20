/*
 * uchaos_seq.h - Character sequencer for uchaos-based jitter hashing
 * (c) 2026, Roberto A. Foglietta <roberto.foglietta@gmail.com>, GPLv2
 */
 #define VERSION "v0.3.5"
 /*
 * Public interface, it hides internal but speed drops by 2/3 because functions.
 *
 * USAGE:
 *
 * warming-up, xN times: urnd_eclt(); { code block; } urnd_eclt();
 *                       ^^^--- cpu yeld/relax jitter does enough
 * generation, loop: e = urnd_emix(); { some_thing; } urnd_eclt();
 *                                    ^^^--- optional part ---^^^
 * bits-comb 64 bit: mr.e = {m, r} is 32bit comb + 32bit entropy
 *
 * linking requires: uchaos_seq.o (or compiling with the uchaos_seq.c)
 *
 * STATUS:
 *
 * This .h provides just a generic API canvas
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
#define BLOCKSZE    512
#define WRITESZE    BLOCKSZE

#define LSB32       0xffffffff
#define SEEDZ       0xec19

#define bit(y,x) (((x) >> (y)) & 1)

#ifdef _USE_MLTP
#define USE_MLTP 1
#undef _USE_MTBL
#define TABLESZE 128
#else
#define USE_MLTP 0
#define TABLESZE 64
#endif

#ifdef _USE_MTBL
#define USE_MTBL 1
#else
#define USE_MTBL 0
#endif

#ifdef UCHAOS_SEQ_C
#include "uchaos_tbl.h"
#else
extern
#endif
const uint8_t __thread *table;

static inline
__attribute__((always_inline))
uint32_t rotl32(uint32_t x, uint8_t n) {
  n &= 31;
  return (x << n) | (x >> (32-n));
}
#define rotl5(x) rotl32(x, 5)

#if   USE_MTBL
  #define urnd_init() { table = (const uint8_t *)mtbl; }
#elif USE_MLTP
  #define urnd_init() { table = (const uint8_t *)mltp; }
#else // mtbl[] may not exist
  __attribute__((aligned(4)))
  uint8_t __thread _buf[TABLESZE];
  #define urnd_init() { table = (const uint8_t *)_buf; }
#endif

#ifdef _USE_FNCS //////////////////////////////////////////////////////////
#define USE_FNCS 1
typedef union {
  uint64_t e;
  uint32_t h[2];
} __attribute__((aligned(8))) volatile urnd_mr_t;

extern
__thread urnd_mr_t _urnd_entr;

uint32_t urnd_comb(register uint32_t r);
uint64_t urnd_emix(void);
void     urnd_eclt(void);

#if __BYTE_ORDER == __BIG_ENDIAN
// RAF: the order is inverted in big-endian systems
  #define     urnd_mr32_m(e) (e).h[1]
  #define     urnd_mr32_r(e) (e).h[0]
#else           // LITTLE ENDIAN
  #define     urnd_mr32_m(e) (e).h[0]
  #define     urnd_mr32_r(e) (e).h[1]
#endif          // ENDIANESS END

#define _mr_e             _urnd_entr.e
#define _mr_m urnd_mr32_m(_urnd_entr)
#define _mr_r urnd_mr32_r(_urnd_entr)

#define       urnd_e32r() ({ _mr_r; })
#define       urnd_e32m() ({ _mr_m; })
#define       urnd_e64e() ({ _mr_e; })

#else //////////////////////////////////////////////////////////////////////////
#define USE_FNCS 0
#endif

#endif // UCHAOS_SEQ_H
