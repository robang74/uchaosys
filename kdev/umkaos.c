/*
 * uchaos_seq.c - Character sequencer for uchaos-based jitter hashing
 * (c) 2026, Roberto A. Foglietta <roberto.foglietta@gmail.com>, GPLv2
 *
 * Compile with:
 *   CFLAGS="-s -g0 -O3 -Wno-format-extra-args -I../usrl"
 *   CFLAGS="$CFLAGS -mavx2 -flto -falign-functions=32"
 *   cc $CFLAGS -D_USE_SEQ_FUNCS uchaos_seq.c umkaos.c -o umkaos
 *   cc $CFLAGS umkaos.c -o umkaos && ./umkaos
 *
 * Functions tests:
 *  px() { echo "px n:$1" >&2; eval parallel -uj$1 "'$2'" ::: {1..$1}; }
 *  px 8 "./umkaos 25" | dd bs=1M of=/dev/null --> 1GB @ 576 MB/s (same)
 *  px 4 "./umkaos 34" | ../prnd/RNG_test stdin64 --> 256GB passed (same)
 *
 **************************************************************************** */

#include "getnanos.h"

#ifdef  _USE_SEQ_FUNCS
#pragma message "Using uchaos_seq functions"
#include "uchaos_seq.h"
#else
#include "uchaos_seq.c"
__attribute__((aligned(8)))
static volatile uint64_t e;
#endif

#define newln1()       if(!argn) { putchar('\n'); fflush(stdout); }
#define print1(fmt...) if(!argn) { fprintf(stdout, fmt); }
#define print2(fmt...) if(!argn) { fprintf(stderr, fmt); }
#define write4(x)      if( argn) { ssize_t w = write(1, &x, 4); }
#define newln2()       if(!argn) { print2("\n"); fflush(stderr); }

#define cntbits(_x) ({ uint8_t x = (_x); \
( bit(0, x) + bit(1, x) + bit(2, x) + bit(3, x) +  \
+ bit(4, x) + bit(5, x) + bit(6, x) + bit(7, x) ); })

__attribute__((always_inline)) static inline
uint8_t chkbits(uint8_t x) {
  int i = 1, n = 1; // RAF: n=0 too many xxx
  uint8_t a, b = bit(0, x);
  for(i; i < 8; i++) {
    if(b != (a = bit(i, x))) {
      n = 0; b = a; // RAF: n=1 too few goods
    } else if(++n == 3) {
      return 0;
    }
  }
  return x;
}

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
  uint8_t bytes[TABLESZE], nbits[TABLESZE];
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
    "\n//> Executing %s in %s",
    __FILE__, VERSION);
  newln2();

  #if USE_SEQ_FUNCS
  urnd_eclt();
  #else
  e = nano1rnd(t);
  #endif

  // select the good ones
  for (int i = 0; i < TABLESZE; i++) {
    bytes[i] = chkbits(i);
    nbits[i] = cntbits(i);
    if((c = nbits[i]) > 2 && c < 6)
      continue;
    bytes[i] = 0;
  }

  #if USE_SEQ_FUNCS
  urnd_eclt();
  #else
  e = nano1rnd(e);
  #endif

  // count the good ones
  *(uint32_t *)nb = 0;
  for (i = 0, n = 0; i < TABLESZE; i++) {
      if(!(c = bytes[i])) continue;
      nb[nbits[c]-3]++;
      n++;
  }

  #if USE_SEQ_FUNCS
  urnd_eclt();
  #else
  e = nano1rnd(e);
  #endif

  // check their counting
  newln1();
  print1("goods[]:\n");
  print1("  tot: %3d/124\n", n);
  print1("   3b: %3d/124\n", nb[0]);
  print1("   4b: %3d/124\n", nb[1]);
  print1("   5b: %3d/124\n", nb[2]);
  if(n != 124) return(1);

  #if USE_SEQ_FUNCS
  urnd_eclt();
  #else
  e = nano1rnd(e);
  #endif

  // store the good ones
  n = 1;
  memset(goods, 0, sizeof(goods));
  for (i = 0; i < TABLESZE; i++) {
      if(!(c = bytes[i])) continue;
      goods[n++] = c;
      if(n & 0x9F) continue;
      goods[n++] = 0;
  }

  #if USE_SEQ_FUNCS
  urnd_eclt();
  #else
  e = nano1rnd(e);
  #endif

  // print the good ones
  newln1();
  print1("goods[]:\n");
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

  #if USE_SEQ_FUNCS
  urnd_eclt();
  #else
  e = nano1rnd(e);
  #endif

  // create their table
  memset(table, 0, TABLESZE);
  for(int m = 3; m < 6; m++) {
    n = (m-3) << 6;
    for (i = 0; i < 128; i++) {
      if((c = goods[i]) && nbits[c] == m)
        table[n++] = c;
    }
  }

  #if USE_SEQ_FUNCS
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

  #if USE_SEQ_FUNCS
  urnd_eclt();
  #else
  e = nano1rnd(e);
  #endif

  // print their table
  print1("\ntable[]:");
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

  #if USE_SEQ_FUNCS
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

  #if USE_SEQ_FUNCS
  urnd_eclt();
  #else
  e = nano1rnd(e);
  #endif

  #ifdef ENSRCS
  // stop collecting CPU jitters
  ENTRSRCS = (MEMSRC | WRTSRC);
  #endif

  // RAF: fill the whole table, r&63 always
  for(i = 0; i < TABLESZE; i += 128)
    memcpy(table + i + 34, table + i, 64-34);

  // for-loop is optimised for 32bit
  int max = (argn?:4);
  uint32_t rndr[4], rndm[4];
  for(int k = 0; k < ncycl; k++) {
    for(n = 0; n < max; n++) {

      #if USE_SEQ_FUNCS
      #define r urnd_e32r()
      #define m urnd_e32m()
      urnd_emix();
      #else
      __attribute__((aligned(4)))
      uint32_t m, r;
      e = nano3rnd(e, &m, &r);
      #endif

      if(argn) {
        *p++ = r;
        if((uint8_t *)p == mpage + WRITESZE) {
          ssize_t wn = write(1, mpage, WRITESZE);
          #ifdef ENSRCS
          if(ENTRSRCS & WRTSRC)
          #endif
          #if USE_SEQ_FUNCS
          urnd_eclt();
          #else
          e = nano1rnd(e);
          #endif
          p = (uint32_t *)mpage;
        }
      }

      if(!argn) {
        rndr[n] = r;
        newln1();
        print1("  entr. pool: 0x%08x --> b#%s\n",
             rndr[n], bit64str(rndr[n], 32));
        rndm[n] = m;
        print1(" const. n.%02d: 0x%08x --> b#%s\n",
          n, rndm[n], bit64str(rndm[n], 32));
      }
    }
  }

  //RAF: 32bit x 4 x 8 = 128byte, but also 128 words:
  //r32:   0|        8|       16|       24|       32|
  //1\0:    |  3bit   |  4bit   |  5bit   |  4bit   |
  //1by:    | 3,4,5,4 | 4,5,4,3 | 5,4,3,4 | 4,5,4,3 |
  #undef m
  #undef r
  print2("\nstatic const uint32_t mltp[] = { \n")
  #define prt2(s,m) print2("%s0x%08x, ", s, m);
  if(!argn) while (n--) {
    uint32_t m = rndm[n], r = rndr[n];
    prt2("  ", m);
    for(int k = 1; k & 7; k++) {
      r = rotl32(r, 20);
      m = urnd_comb(r);
      prt2("", m);
    }
    newln2();
  }
  print2("};")
  newln2();

#if 0
  if(!argn) {
    print1("\nr&63 (dec):\n");
    memset(mpage, 0, sizeof(mpage));
    for(int i = 0; i < TABLESZE; i += 128)
      memcpy(table + i + 34, table + i, 64-34);
    // RAF ^^^: fill the whole table, r&63 always
    uint8_t *q = mpage;
    for(i = 0; i < 4; i++) {
      for(n = 0; n < 4; n++) {
        uint32_t z = n*16, r = rotl32(rndr[n], 1<<i);
        for(int k = 0; k < 16; k++, r = rotl5(r)) {
          uint8_t w, v = r & 63;
          w = table[z + v];
          v = w ? v : (~v) & 63;
          *q++ = table[z + v];
          print1("  %02d", v);
        }
        newln1();
      }
    }
    q = mpage;
    print1("\ntable[%d] (hex):", TABLESZE);
    for(int i = 0; i < TABLESZE; i ++) {
      print1("%s  %02x", (i&15)?"":"\n", q[i], q[i]);
    }
    newln1();

    p = (uint32_t *)mpage;
    print2("\nstatic const uint32_t ctbl[] = {\n");
    for(int i = 0; i < TABLESZE/4; i++) {
      print2("%s0x%08x,%s", (i&7) ? ""  : "  ",
                  *p++, ((i+1)&7) ? " " : "\n");
    }
    print2("};")
    newln2();
  }
#endif

  if( argn && (uint8_t *)p != mpage)
    t = write(1, mpage, ((uint8_t *)p)-mpage);

  t = get_nanos(); // collecting the running time
  print2(
    "\n//> Run time: %7lu nS --> %.03lf mS\n",
      t, (double)t/1E6);

  newln2();
  return 0;
}

