/*
 * uchaos_seq.c - Character sequencer for uchaos-based jitter hashing
 * (c) 2026, Roberto A. Foglietta <roberto.foglietta@gmail.com>, GPLv2
 */
 #define VERSION "v0.0.7"
 /*
 * Compile and run with:
 *   CFLAGS="-s -g0 -O1 -Wno-format-extra-args -I../usrl"
 *   cc uchaos_seq.c $CFLAGS -o ucseq && ./ucseq
 *   ./ucseq $((1<<30)) | dd bs=1M | ../prnd/RNG_test stdin64
 *   px() { echo "px n:$1" >&2; eval parallel -uj$1 "'$2'" ::: {1..$1}; }
 *   px 4 "./ucseq $((1<<30))" | dd bs=1M | ../prnd/RNG_test stdin64
 */

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

#define bit(y,x) (((x) >> (y)) & 1)

#define cntbits(_x) ({ uint8_t x = (_x); \
  (x&1) + ((x >> 1) & 1) + ((x >> 2) & 1) + \
  ((x >> 3) & 1) + ((x >> 4) & 1) + ((x >> 5) & 1) \
  + ((x >> 6) & 1) + ((x >> 7) & 1); })

static inline uint8_t chkbits(uint8_t x) {
  int i = 1, n = 1;
  uint8_t a, b = bit(0,x);
  for(i; i < 8; i++) {
    if(b != (a = bit(i,x))) {
      n = 0;
      b = a;
    } else
    if(++n == 3)
      return 0;
  }
  return x;
}

static inline uint32_t rotl32(uint32_t x, uint8_t n) {
  n &= 31; return (x << n) | (x >> (32-n));
}
#define rotl5(x) rotl32(x, 5)

static inline uint64_t nanornd(uint64_t e) {
  uint64_t t;
  sched_yield();
  t = get_nanos();
  return t ^ (e * t);
}

#define newln1()       if(!argn) { putchar('\n'); }
#define print1(fmt...) if(!argn) { fprintf(stdout, fmt); }
#define print2(fmt...) if(!argn) { fprintf(stderr, fmt); }
#define write4(x)      if( argn) { ssize_t w = write(1, &x, 4); }

int main(int argc, char *argv[]) {
  uint8_t mpage[PAGESIZE];
  uint64_t e = get_nanos();
  uint32_t i, n, r, argn = 0, *p = (uint32_t *)mpage;
  uint8_t bytes[256], count[256], nbits[256];
  uint8_t goods[128], table[256], nb[4], c;

  if(argc & 2)
    argn = atol(argv[1]);

  print2(
    "\n//> Executing %s in %s\n",
    __FILE__, VERSION);
  newln1();

  e = nanornd(0xec19);

  // select the good ones
  for (int i = 0; i < 256; i++) {
    bytes[i] = chkbits(i);
    nbits[i] = cntbits(i);
    count[i] = 0;
    if((c = nbits[i]) > 2 && c < 6)
      continue;
    bytes[i] = 0;
  }

  e = nanornd(e);

  // count the good ones
  *(uint32_t *)nb = 0;
  for (i = 0; i < 256; i++) {
      if(!(c = bytes[i])) continue;
      nb[nbits[c]-3]++;
      n++;
  }

  e = nanornd(e);

  // check their counting
  print1("  tot: %3d/124\n", n);
  print1("   3b: %3d/124\n", nb[0]);
  print1("   4b: %3d/124\n", nb[1]);
  print1("   5b: %3d/124\n", nb[2]);
  newln1();
  if(n != 124) return(1);

  e = nanornd(e);

  // store the good ones
  n = 1;
  memset(goods, 0, sizeof(goods));
  for (i = 0; i < 256; i++) {
      if(!(c = bytes[i])) continue;
      goods[n++] = c;
      if(n & 0x1F) continue;
      goods[n++] = 0;
  }

  e = nanornd(e);

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

  e = nanornd(e);

  // create their table
  memset(table, 0, sizeof(table));
  for(int m = 3; m < 6; m++) {
    n = (m-3) << 6;
    for (i = 0; i < 128; i++) {
      if((c = goods[i]) && nbits[c] == m)
        table[n++] = c;
    }
  }

  e = nanornd(e);

  // spacing their table
  for(i = 8; i < 56; i += 8) {
    n = 128 - i;
    memcpy(&table[n], &table[n-8], 8);
    memset(&table[n-8], 0, 8);
  }

  e = nanornd(e);

  // print their table
  for(int m = 3; m < 6; m++) {
    int k = 0;
    n = (m-3) << 6;
    for (int i = 0; i < 64; i++) {
      if(!(c = table[n+i])) continue;
      if(!(k++ & 3)) newln1();
      print1("  %03d: b#%08b %d | ",
        n+i, c, nbits[c]);
    }
    newln1();
  }

  e = nanornd(e);

  // checking the spacing
  n = 0;
  for(i = 0; i < 64; i++)
    if(!table[64+i] && !table[64+((~i)&63)])
      print1("%s %03d", n++?",":"  err:", i);
  if(n) newln1();

  e = nanornd(e);

  for(n = 0; n < (argn?:4); n++) {
    uint32_t m = 0;

    r = (e >> 32) ^ (e & 0xffffffff);
    if(argn) {
      *p++ = r;
      if((uint8_t *)p == mpage + PAGESIZE) {
        ssize_t wn = write(1, mpage, PAGESIZE);
        p = (uint32_t *)mpage;
      }
    }
    print1(
      "\n  entr. pool: 0x%08x --> b#%032b\n",
        r, r);
    print1("  const. #%d", n);

    i = (r = rotl5(r)) & 31;
    c = table[1 + i];
    print1(": %03d", c);
    m = c << 24;

    i = (r = rotl5(r)) & 63;
    c = table[64 + i] ?: table[64 + ((~i)&63)];
    print1(", %03d", c);
    m |= c << 16;

    i = (r = rotl5(r)) & 31;
    c = table[129 + i];
    print1(", %03d", c);
    m |= c << 8;

    i = (r = rotl5(r)) & 63;
    c = table[64 + i] ?: table[64 + ((~i)&63)];
    print1(", %03d", c);
    m |= c << 0;

    print1(" --> 0x%08x\n", m);
    e = nanornd((~e) ^ rotl5(r));
  }
  if(argn && (uint8_t *)p != mpage)
    r = write(1, mpage, ((uint8_t *)p)-mpage);

  e = get_nanos();
  print2(
    "\n//> Time spent: %7lu nS --> %.03lf mS\n",
      e, (double)e/1000000);

  newln1();
  return 0;
}
