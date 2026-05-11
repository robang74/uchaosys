/*
 * uchaos_seq.c - Character sequencer for uchaos-based jitter hashing
 * (c) 2026, Roberto A. Foglietta <roberto.foglietta@gmail.com>, GPLv2
 */
 #define VERSION "v0.2.6"
 /*
 * Compile and run with:
 *   CFLAGS="-s -g0 -O3 -Wno-format-extra-args -falign-functions=32 -I../usrl"
 *   cc uchaos_seq.c $CFLAGS -o ucseq && ./ucseq
 *
 *******************************************************************************
 * TESTING
 *
 * px() { echo "px n:$1" >&2; eval parallel -uj$1 "'$2'" ::: {1..$1}; }
 * gx() { px $1 "./ucseq 30" & px $1 "./uckaos $((1<<19))"; }
 *
 * Speed test:
 *    px 8 "./umkaos 26" | dd bs=1M of=/dev/null
 *
 * Random test:
 *    px 4 "./umkaos 34" | dd bs=1M | ../prnd/RNG_test stdin64
 *
 * Mixed test:
 *   gx 4 | dd bs=1M | ../prnd/RNG_test stdin64
 *
 *******************************************************************************
 * RESULTS (on v0.2.0)
 *
 * px 8 "./umkaos $((1<<30))" | dd bs=1M of=/dev/null
 * px n:8
 * ^C
 * 3806811648 bytes (3.8 GB, 3.5 GiB) copied, 4.57474 s, 832 MB/s !! 4/3 bc wo/m
 *
 * px 8 "./umkaos 26" | dd bs=1M of=/dev/null
 * px n:8
 * 2147483648 bytes (2.1 GB, 2.0 GiB) copied, 3.51551 s, 611 MB/s !! 4/4 cpu w/m
 *
 * px 4 "./umkaos 34" | ../prnd/RNG_test stdin64
 * px n:4
 * RNG_test using PractRand version 0.96
 * RNG = RNG_stdin64, seed = unknown
 * test set = core, folding = standard (64 bit)
 *
 * length= 512 megabytes (2^29 bytes), time= 6.2 seconds
 *   Test Name                         Raw       Processed     Evaluation
 *   [Low16/64]BCFN(2+2,13-3U)         R=  +9.0  p =  4.5e-4   unusual
 *   ...and 212 test result(s) without anomalies
 *
 * length= 128 gigabytes (2^37 bytes), time= 2037 seconds
 *   no anomalies in 320 test result(s)
 *
 * length= 256 gigabytes (2^38 bytes), time= 3935 seconds
 *   no anomalies in 332 test result(s)
 *
 * px 4 "./umkaos 20" | ent
 * px n:4
 * Entropy = 7.999989 bits per byte.
 *
 * Chi square distribution for 16777216 samples is 256.94, and randomly
 * would exceed this value 45.41 percent of the times.
 *
 * Arithmetic mean value of data bytes is 127.5339 (127.5 = random).
 * Monte Carlo value for Pi is 3.140727315 (error 0.03 percent).
 * Serial correlation coefficient is -0.000024 (totally uncorrelated = 0.0).
 *
 **************************************************************************** */

#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sched.h>

#include "getnanos.h"

#define PAGEORDR    12
#define PAGESIZE    (2 << PAGEORDR)
#define PAGEFULL(x) (x >> PAGEORDR)
#define BLOCKSZE    512
#define WRITESZE    BLOCKSZE

#define LSB32       0xffffffff
#define SEEDZ       0xec19

#if 0
#define MEMSRC      (1<<0) // unavoidable
#define WRTSRC      (1<<1)
#define CPUSRC      (1<<2)
#define ENSRCS      (MEMSRC | WRTSRC | CPUSRC)
static uint8_t      ENTRSRCS = ENSRCS;
#endif

#define bit(y,x) (((x) >> (y)) & 1)

#define cntbits(_x) ({ uint8_t x = (_x); \
( bit(0, x) + bit(1, x) + bit(2, x) + bit(3, x) +  \
+ bit(4, x) + bit(5, x) + bit(6, x) + bit(7, x) ); })

__attribute__((always_inline)) static inline
uint8_t chkbits(uint8_t x) {
  int i = 1, n = 1;
  uint8_t a, b = bit(0, x);
  for(i; i < 8; i++) {
    if(b != (a = bit(i, x))) {
      n = 0; b = a;
    } else if(++n == 3) {
      return 0;
    }
  }
  return x;
}

__attribute__((always_inline)) static inline
uint32_t rotl32(uint32_t x, uint8_t n) {
  n &= 31;
  return (x << n) | (x >> (32-n));
}
#define rotl5(x) rotl32(x, 5)

__attribute__((aligned(4)))
static uint8_t table[256];

__attribute__((always_inline)) static inline
uint32_t comb32make(uint32_t r) {
  uint32_t m, c, i;

  i = (r = rotl5(r)) & 31;
  c = table[1 + i];
  m = c << 24;

  i = (r = rotl5(r)) & 63;
  c = table[64 + i] ?: table[64 + ((~i)&63)];
  m |= c << 16;

  i = (r = rotl5(r)) & 31;
  c = table[129 + i];
  m |= c << 8;

  i = (r = rotl5(r)) & 63;
  c = table[64 + i] ?: table[64 + ((~i)&63)];
  m |= c << 0;

  return m;
}

// RAF: this function is used only here, and its prototype
// consistency isn't relevant: returns 64 for the caller.
__attribute__((always_inline)) static inline
uint64_t get_30ns2(void)  {
  static
  uint32_t __thread t = 0 ;
  struct timespec   ts    ;
  uint32_t register ct, dt;

  // RAF: systems with coarser timers than nS but same API
  // will make this code fail. However, it is better than
  // it fails rather than trying to address unknown cases.
  // Especially because nS or uS or mS do not matter apart
  // from a right shift, as long as there is some entropy
  // leaking by the LSB timings. Otherwise, deterministic.
  clock_gettime(CLOCK_MONOTONIC, &ts);
  // RAF: 2^30 -1BLN = 74M, but +2 bits & setdata()
  // cannot influence the nanornd() 0-init anymore.
  ct = ( (ts.tv_sec & 3) << 30 ) | ts.tv_nsec;
  dt = ct - t;                     // this dif can skew (1)
   t = ct;                         // save the previous (2)
  #if 0
  ct = ct ^ ((dt & 0xffff) << 14); // 2^(16+14)-1 = 67M (a)
  #else
  ct = ct + ((dt & 0xffff) << 10); // sum always < 2^30 (b)
  #endif
  // when using time as multiplier, it is nice to
  // fill-up the range uncovered by 2^30 and 1BLN.
  // LSB drive stochastics, who can control them?
  // a) LSB from clock_gettime(): easy to tamper!
  // b) static __thread t: memory write poisoning
  // both leave unchanged the two MSB at 2^30 31.
  // 1: a feature than a bug; 2: jitter needs dt.
  return ct;
}
// RAF: since the CPU jittering already shown its validity
// and its performance, keeping it out the generation makes
// sense in the quest of challenging the RAM access jitter.
#define tns2() get_30ns2() // redefinition can include vvv
#define   sched_yield_ns() ({ sched_yield(); get_30ns2(); })

__attribute__((always_inline))
static inline
uint64_t nano1rnd(
register uint64_t e)  { // used during "e" warming phase
  uint64_t register  t;
  t = sched_yield_ns(); // jt
  e = (e&2) ? e : ~e  ; // >1
  return t ^ (e * ~t) ; // et
}

// RAF: here m is a "comb" 32bit multiplier constant made
// of bytes with 3 to 5 bits of the same kind and a good
// bit alternance, in which "111" or "000" are forbidden.
__attribute__((always_inline))
static inline
uint64_t nano2rnd(
register uint64_t e,
         uint64_t m)  { // used during gen/consume cycle
  uint64_t register  t;
  t = (m<<32) | tns2(); // mt
  e = (e&2) ? e : ~e  ; // >1
  return t ^ (e * ~t) ; // et
}

__attribute__((always_inline))
static inline
uint64_t nano3rnd(
register uint64_t e,
         uint32_t *m,
         uint32_t *r) {
  uint64_t register x ;
  *r = x = e^(e >> 32);
   e = (~e) ^ rotl5(x);
  *m =   comb32make(x);
   e = nano2rnd(e, *m);
  return e;
}

////////////////////////////////////////////////////////////////////////////////

#define newln1()       if(!argn) { putchar('\n'); }
#define print1(fmt...) if(!argn) { fprintf(stdout, fmt); }
#define print2(fmt...) if(!argn) { fprintf(stderr, fmt); }
#define write4(x)      if( argn) { ssize_t w = write(1, &x, 4); }

// RAF: printf() %b isn't supported by early gcc/libc and by musl.
// This "least effort" funtion displays differntly on big-endian,
// but it can be a "feature" rather than a bug see the enconding.
static const volatile char *
bit64str (uint64_t register v,
          const unsigned    n) {
  static char __thread b[65]   ;
  for (int i = 0; i < n; i++)
    b[i] = '0' + bit(n-i-1, v) ;
  return ({ b[n] = 0; b; })    ;
}

int main(int argc, char *argv[]) {
  uint8_t mpage[WRITESZE];
  __attribute__((aligned(8))) volatile uint64_t e = get_nanos();
  uint32_t i, n, r, ncycl = 1, argn = 0, *p = (uint32_t *)mpage;
  uint8_t bytes[256], nbits[256];
  uint8_t goods[128], nb[4], c;

  // for-loop is optimised for 32bit
  if(argc & 2) {
    argn = atol(argv[1]);
    if(argn < 2) argn = 4;
    if(argn < 64) {
      if(argn > 32) {
        ncycl = 1ULL << (argn-31);
        argn  = 1ULL << 31;
      } else {
        argn  = 1ULL << argn;
      }
    }
  }

  print2(
    "\n//> Executing %s in %s\n",
    __FILE__, VERSION);
  newln1();

  e = nano1rnd(e);

  // select the good ones
  for (int i = 0; i < 256; i++) {
    bytes[i] = chkbits(i);
    nbits[i] = cntbits(i);
    if((c = nbits[i]) > 2 && c < 6)
      continue;
    bytes[i] = 0;
  }

  e = nano1rnd(e);

  // count the good ones
  *(uint32_t *)nb = 0;
  for (i = 0, n = 0; i < 256; i++) {
      if(!(c = bytes[i])) continue;
      nb[nbits[c]-3]++;
      n++;
  }

  e = nano1rnd(e);

  // check their counting
  print1("  tot: %3d/124\n", n);
  print1("   3b: %3d/124\n", nb[0]);
  print1("   4b: %3d/124\n", nb[1]);
  print1("   5b: %3d/124\n", nb[2]);
  newln1();
  if(n != 124) return(1);

  e = nano1rnd(e);

  // store the good ones
  n = 1;
  memset(goods, 0, sizeof(goods));
  for (i = 0; i < 256; i++) {
      if(!(c = bytes[i])) continue;
      goods[n++] = c;
      if(n & 0x1F) continue;
      goods[n++] = 0;
  }

  e = nano1rnd(e);

  // print the good ones
  for (i = 0; i < 4; i++)
    print1("  idx:  hex, bits%3s| ","");
  newln1();
  for (i = 0; i < 128; i) {
    c = goods[i];
    print1("  %03d: 0x%02x, %s%2d%-4s| ",
         i, c,
      nbits[c] ? " " : "(",
      nbits[c],
            c  ? " " : ")");
    if(!(++i & 3)) newln1();
  }

  e = nano1rnd(e);

  // create their table
  memset(table, 0, sizeof(table));
  for(int m = 3; m < 6; m++) {
    n = (m-3) << 6;
    for (i = 0; i < 128; i++) {
      if((c = goods[i]) && nbits[c] == m)
        table[n++] = c;
    }
  }

  e = nano1rnd(e);

  // spacing their table
  for(i = 8; i < 56; i += 8) {
    n = 128 - i;
    memcpy(&table[n], &table[n-8], 8);
    memset(&table[n-8], 0, 8);
  }

  e = nano1rnd(e);

  // print their table
  for(int m = 3; m < 6; m++) {
    int k = 0;
    n = (m-3) << 6;
    for (int i = 0; i < 64; i++) {
      if(!(c = table[n+i])) continue;
      if(!(k++ & 3)) newln1();
      print1("  %03d: b#%s %d | ",
        n+i, bit64str(c,8), nbits[c]);
    }
    newln1();
  }

  e = nano1rnd(e);

  // checking the spacing
  n = 0;
  for(i = 0; i < 64; i++)
    if(!table[64+i] && !table[64+((~i)&63)])
      print1("%s %03d", n++?",":"  err:", i);
  if(n) newln1();

  e = nano1rnd(e);

#ifdef ENSRCS
  // stop collecting CPU jitters
  ENTRSRCS = (MEMSRC | WRTSRC);
#endif

  // for-loop is optimised for 32bit
  int max = (argn?:4);
  for(int k = 0; k < ncycl; k++) {
    for(n = 0; n < max; n++) {
      uint32_t m;

      e = nano3rnd(e, &m, &r);

      if(argn) {
        *p++ = r;
        if((uint8_t *)p == mpage + WRITESZE) {
          ssize_t wn = write(1, mpage, WRITESZE);
#ifdef ENSRCS
          if(ENTRSRCS & WRTSRC)
#endif
          e = nano1rnd(e);
          p = (uint32_t *)mpage;
        }
      }

      print1("\n  entr. pool: 0x%08x --> b#%s\n",
        r,    bit64str(r, 32));
      print1(" const. n.%02d: 0x%08x --> b#%s\n",
        n, m, bit64str(m, 32));
    }
  }
  if(argn && (uint8_t *)p != mpage)
    r = write(1, mpage, ((uint8_t *)p)-mpage);

  e = get_nanos();
  print2(
    "\n//> Run time: %7lu nS --> %.03lf mS\n",
      e, (double)e/1000000);

  newln1();
  return 0;
}

