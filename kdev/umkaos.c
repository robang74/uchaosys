/*
 * uchaos_seq.c - Character sequencer for uchaos-based jitter hashing
 * (c) 2026, Roberto A. Foglietta <roberto.foglietta@gmail.com>, GPLv2
 *
 * Compile and run with:
 *   CFLAGS="-s -g0 -O3 -Wno-format-extra-args -falign-functions=32 -I../usrl"
 *   cc uchaos_seq.c umkaos.c $CFLAGS -mavx2 -o umkaos && ./umkaos
 *
 **************************************************************************** */

#include "getnanos.h"
#if 0
#include "uchaos_seq.h"
#else
#include "uchaos_seq.c"
#endif

#define newln1()       if(!argn) { putchar('\n'); }
#define print1(fmt...) if(!argn) { fprintf(stdout, fmt); }
#define print2(fmt...) if(!argn) { fprintf(stderr, fmt); }
#define write4(x)      if( argn) { ssize_t w = write(1, &x, 4); }

#ifdef UCHAOS_SEQ_H
#else
__attribute__((aligned(8)))
static volatile uint64_t e;
#endif

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
  uint64_t t = get_nanos(); // init the timer, first of all
  uint8_t mpage[WRITESZE];
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

  #ifdef UCHAOS_SEQ_H
  urnd_eclt();
  #else
  e = nano1rnd(t); 
  #endif

  // select the good ones
  for (int i = 0; i < 256; i++) {
    bytes[i] = chkbits(i);
    nbits[i] = cntbits(i);
    if((c = nbits[i]) > 2 && c < 6)
      continue;
    bytes[i] = 0;
  }

  #ifdef UCHAOS_SEQ_H
  urnd_eclt();
  #else
  e = nano1rnd(e); 
  #endif

  // count the good ones
  *(uint32_t *)nb = 0;
  for (i = 0, n = 0; i < 256; i++) {
      if(!(c = bytes[i])) continue;
      nb[nbits[c]-3]++;
      n++;
  }

  #ifdef UCHAOS_SEQ_H
  urnd_eclt();
  #else
  e = nano1rnd(e); 
  #endif

  // check their counting
  print1("  tot: %3d/124\n", n);
  print1("   3b: %3d/124\n", nb[0]);
  print1("   4b: %3d/124\n", nb[1]);
  print1("   5b: %3d/124\n", nb[2]);
  newln1();
  if(n != 124) return(1);

  #ifdef UCHAOS_SEQ_H
  urnd_eclt();
  #else
  e = nano1rnd(e); 
  #endif

  // store the good ones
  n = 1;
  memset(goods, 0, sizeof(goods));
  for (i = 0; i < 256; i++) {
      if(!(c = bytes[i])) continue;
      goods[n++] = c;
      if(n & 0x1F) continue;
      goods[n++] = 0;
  }

  #ifdef UCHAOS_SEQ_H
  urnd_eclt();
  #else
  e = nano1rnd(e); 
  #endif

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

  #ifdef UCHAOS_SEQ_H
  urnd_eclt();
  #else
  e = nano1rnd(e); 
  #endif

  // create their table
  memset(table, 0, sizeof(table));
  for(int m = 3; m < 6; m++) {
    n = (m-3) << 6;
    for (i = 0; i < 128; i++) {
      if((c = goods[i]) && nbits[c] == m)
        table[n++] = c;
    }
  }

  #ifdef UCHAOS_SEQ_H
  urnd_eclt();
  #else
  e = nano1rnd(e); 
  #endif

  // spacing their table
  for(i = 8; i < 56; i += 8) {
    n = 128 - i;
    memcpy(&table[n], &table[n-8], 8);
    memset(&table[n-8], 0, 8);
  }

  #ifdef UCHAOS_SEQ_H
  urnd_eclt();
  #else
  e = nano1rnd(e); 
  #endif

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

  #ifdef UCHAOS_SEQ_H
  urnd_eclt();
  #else
  e = nano1rnd(e); 
  #endif

  // checking the spacing
  n = 0;
  for(i = 0; i < 64; i++)
    if(!table[64+i] && !table[64+((~i)&63)])
      print1("%s %03d", n++?",":"  err:", i);
  if(n) newln1();

  #ifdef UCHAOS_SEQ_H
  urnd_eclt();
  #else
  e = nano1rnd(e); 
  #endif

  #ifdef ENSRCS
  // stop collecting CPU jitters
  ENTRSRCS = (MEMSRC | WRTSRC);
  #endif

  // for-loop is optimised for 32bit
  union {
    uint64_t e;
    uint32_t h[2];
  } mr;
  #ifdef UCHAOS_SEQ_H
  mr.e = urnd_e64e();
  #else
  mr.e = e;
  #endif
  #define e mr.e
#if __BYTE_ORDER == __BIG_ENDIAN
// RAF: the order is inverted in big-endian systems
  #define m mr.h[1]
  #define r mr.h[0]
#else
  #define m mr.h[0]
  #define r mr.h[1]
#endif
  int max = (argn?:4);
  for(int k = 0; k < ncycl; k++) {
    for(n = 0; n < max; n++) {

      #ifdef UCHAOS_SEQ_H
      e = urnd_e64mr();
      #else
      e = nano3rnd(e, &m, &r);
      #endif

      if(argn) {
        *p++ = r;
        if((uint8_t *)p == mpage + WRITESZE) {
          ssize_t wn = write(1, mpage, WRITESZE);
          #ifdef ENSRCS
          if(ENTRSRCS & WRTSRC)
          #endif
          #ifdef UCHAOS_SEQ_H
          urnd_eclt();
          #else
          e = nano1rnd(t);
          #endif
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
    t = write(1, mpage, ((uint8_t *)p)-mpage);

  t = get_nanos(); // collecting the running time
  print2(
    "\n//> Run time: %7lu nS --> %.03lf mS\n",
      t, (double)t/1E6);

  newln1();
  return 0;
}

