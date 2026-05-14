/*
 * uchaos_seq.c - Character sequencer for uchaos-based jitter hashing
 * (c) 2026, Roberto A. Foglietta <roberto.foglietta@gmail.com>, GPLv2
 *
 #define VERSION "v0.3.0" // version definition moved in uchaos_seq.h
 *
 * Compile and run with:
 *   CFLAGS="-s -g0 -O3 -Wno-format-extra-args -falign-functions=32 -I../usrl"
 *   cc uchaos_seq.c umkaos.c $CFLAGS -mavx2 -o umkaos && ./umkaos
 *
 *******************************************************************************
 * TESTING
 *
 * px() { echo "px n:$1" >&2; eval parallel -uj$1 "'$2'" ::: {1..$1}; }
 * gx() { px $1 "./ucseq 30" & px $1 "./uckaos $((1<<19))"; }
 *
 * Speed test:
 *   px 8 "./umkaos 26" | dd bs=1M of=/dev/null
 *
 * Random test:
 *   px 4 "./umkaos 34" | ../prnd/RNG_test stdin64
 *
 * Mixed test:
 *   gx 4 | ../prnd/RNG_test stdin64
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
 *******************************************************************************
 *
 * CHANGES (in v0.2.6)
 *
 * Speed from 610 MB/s to 550 MB/s which is a -10% because endogenous robustness
 * px 4 "./umkaos 34" | ../prnd/RNG_test stdin64: passed 256 GB with no warnings
 * px 4 "./umkaos 20" | ent: 7.999989, 257.42, 44.58%, 127.4916, 0.03%,-0.000071
 *
 * CHANGES (in v0.2.7)
 *
 * nano0rnd() introduced for code maintenance (1pt), it regains 590 MB/s (-4%)
 *
 * CHANGES (in v0.3.0)
 *
 * get_30ns2() fills the gap, adds scramble and mem::barrier.   576 MB/s (-6%)
 *
 **************************************************************************** */

#ifndef UCHAOS_SEQ_C
#define UCHAOS_SEQ_C

#include "uchaos_seq.h"

__attribute__((always_inline)) static inline
uint32_t rotl32(uint32_t x, uint8_t n) {
  n &= 31;
  return (x << n) | (x >> (32-n));
}
#define rotl5(x) rotl32(x, 5)

__attribute__((always_inline)) static inline
uint32_t comb32make(uint32_t r) {
  register uint32_t m, c, i;

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

/* RAF: barrier here prevents caching skew and potentially pathological
 * concentration by arbitrary cache reordering. However, these phenomena
 * aren't systematic but random. Hence, they constitute welcoming deviations
 * from predictability. While pathological issue can easily skip using a variable
 * defined volatile which is involved in the hot-loop, like urnd_mr_t, the union
 * typedef defined in the .h -- However, from the PoV of those are in need to
 * review the code and certify the results. These "deviations" are an "issue"
 * to justify rather than a feature like a stochastic Easter egg surprise.
 */
#define get_30ns2() ({ uint64_t _t=_get_30ns2(); \
                      asm volatile("" : "+g"(_t)); _t; })

// RAF: this function is used only here, and its prototype
// consistency isn't relevant: returns 64 for the caller.
__attribute__((always_inline)) static inline
uint64_t _get_30ns2(void)  {
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
  dt =  ct - t            ; // this dif can skew (1)
   t =  ct                ; // save the previous (2)
  #if 0                     
  dt = (dt & 0xffff) << 10; // it closes the gap
  ct += dt                ; // sum always < 2^30 (a)
                            // and scrambles LSB
  ct ^= dt << 4           ; // 2^(16+14)-1 = 67M (b)
  #else
  dt = (dt & 0xffff) << 14; // it closes the gap
  ct = (dt ^ ct) + dt     ; // and adds scramble (c) 
  #endif
  // when using time as multiplier, it is nice to
  // fill-up the range uncovered by 2^30 and 1BLN.
  // LSB drive stochastics, who can control them?
  // a) static __thread t: memory write poisoning
  // b) LSB from clock_gettime(): easy to tamper!
  // both leave unchanged the two MSB at 2^30 31.
  // c) same concept but it avoids MSB poisoning.
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
uint64_t nano0rnd(
register uint64_t e,
register uint64_t t)  {
  e = (e&2) ? e : ~e  ; // >1 w/ endogenous bi-forcation
  return t ^ (e * ~t) ; // et robustness by t-complement
}

__attribute__((always_inline))
static inline
uint64_t nano1rnd(
register uint64_t e)  { // used during "e" warming phase
  uint64_t register t ;
  t = sched_yield_ns(); // jt
  return nano0rnd(e,t);
}

// RAF: here m is a "comb" 32bit multiplier constant made
// of bytes with 3 to 5 bits of the same kind and a good
// bit alternance, in which "111" or "000" are forbidden.
__attribute__((always_inline))
static inline
uint64_t nano2rnd(
register uint64_t e,
         uint64_t m)  { // used during gen/consume cycle
  uint64_t register t ;
  t = (m<<32) | tns2(); // mt
  return nano0rnd(e,t);
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
#ifdef _USE_SEQ_FUNCS

__thread urnd_mr_t _urnd_entr;

__attribute__((always_inline))
static inline
uint64_t nano4rnd(
register uint64_t e)  {
  uint64_t register x ;
  x =   e  ^ (e >> 32);
  e = (~e) ^  rotl5(x);
  x =    comb32make(x);
  e =   nano2rnd(e, x);
  return e;
}

void urnd_eclt(void) { _mr_e = nano1rnd(_mr_e); }

uint64_t urnd_emix(void) {
  _mr_e = nano4rnd(_mr_e);
                 // RAF: single 64 bit var design is for x86_64
                // and it should be challenged on big-endian or
               // 32bit archictures against be right and faster
  return _mr_e;
}

#endif
/* /////////////////////////////////////////////////////////////////////////////
 *
 * The stuff that was here, has been moved in umkaos.c
 *
 * /////////////////////////////////////////////////////////////////////////////
 */

#endif // UCHAOS_SEQ_C
