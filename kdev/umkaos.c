/*
 * uchaos_seq.c - Character sequencer for uchaos-based jitter hashing
 * (c) 2026, Roberto A. Foglietta <roberto.foglietta@gmail.com>, GPLv2
 *
 * Compile and run with (check uchaos_seq.c for all the cases):
 *   CFLAGS="-s -g0 -O3 -Wno-format-extra-args -I../usrl"
 *   CFLAGS="$CFLAGS -mavx2 -flto -falign-functions=32"
 *   cc $CFLAGS                         umkaos.c -o umkaos && ./umkaos
 *   ./umkaos > uchaos_tbl.h
 *   cc $CFLAGS -D_RNG_ONLY -D_USE_FNCS umkaos.c -o umkaos && ./umkaos
 *   ./umkaos; size umkaos; echo;strings umkaos|sed -ne "s/.\{6\}/&/p"
 * 
 **************************************************************************** */

#include "uchaos_seq.c"

#ifdef _USE_FNCS
#pragma message "Using uchaos_seq functions"
#else
__attribute__((aligned(8)))
static volatile uint64_t e;
#endif

#ifdef _RNG_ONLY
#define RNG_ONLY 1
#include <sys/syscall.h>
#define prterr(x...)
#undef  write
#define write(a,b,c) syscall(SYS_write,a,b,c);
#else
#define RNG_ONLY 0
#include <inttypes.h>
#include "getnanos.h"
#define prterr(x...) fprintf(stderr, x)
#endif

#define MTBL_STRN "MTBL"
#define MLTP_STRN "MLTP"
#define MTBL_VARN "mtbl"
#define MLTP_VARN "mltp"

#ifdef _DO_DEBUG
#define DEBUG 1
#else
#define DEBUG 0
#endif
#define newln1()       if(DEBUG) { putchar('\n'); fflush(stderr); }
#define print1(fmt...) if(DEBUG) { fprintf(stderr, fmt); }

#define print2(fmt...) if(!argn) { fprintf(stdout, fmt); }
#define newln2()       if(!argn) { print2("\n"); fflush(stdout); }
#define write4(x)      if( argn) { ssize_t w = write(1, &x, 4); }

#define cntbits(_x) ({ uint8_t x = (_x); \
( bit(0, x) + bit(1, x) + bit(2, x) + bit(3, x) +  \
+ bit(4, x) + bit(5, x) + bit(6, x) + bit(7, x) ); })

static uint8_t umks_head[] = {
  "\n/*\n * (C) 2026, github::@robang74, GPLv2\n */"
  "\n//> Executing uChaoSys::umkaos " VERSION
#if RNG_ONLY
  "\n//> Use w/arg N for 2^N bytes dataout\n"
#endif
  "\n\0\0\0\0"
};

static inline
__attribute__((always_inline))
uint8_t chkbits(uint8_t x, uint8_t z) {
  int i = 1, n = z; // RAF: n=0 too many xxx
  uint8_t a, b = bit(0, x);
  for(i; i < 8; i++) {
    if(b != (a = bit(i, x))) {
      n = z; b = a; // RAF: n=1 too few goods
    } else if(++n == 3) {
      return 0;
    }
  }
  return 1;
}

static inline
__attribute__((always_inline))
void _scramtbl(uint32_t r) {
  uint8_t *p = (uint8_t *)table;
  for (int i = 0; i < 4; i++) {
    uint8_t a, b, n;
    n  = r >> (i<<3);
    a  = n & 0x0f;
    b  = n >> 4;
    b  = (b-a) ? b : (~a) & 0x0f;
    a += i << 4;
    b += i << 4;
    n    = p[a];
    p[a] = p[b];
    p[b] =    n;
  }
}

static inline
__attribute__((always_inline))
void scramtbl(register uint32_t r) {
  for (int i = 0; i < 6; i++) {
    _scramtbl(r);
    r = rotl5(r);
  }
}

#define prt08x(s,m) fprintf(stdout, "%s0x%08x, ", s, m)
static inline
uint64_t prntbl(uint32_t *tb, uint32_t sze) {
  uint32_t i;
  for (i = 0; i < sze; i++, tb++)
    prt08x((i&3)?"":"\n  ", *tb);
}

static inline
uint64_t _chktbl(uint32_t *tb) { // RAF, TODO: with void *, instead macro?
  uint64_t y;
  uint32_t i, m, s, w;
  for (i = s = w = 0, m = 1; *tb; i++, tb++) {
    w ^= *tb; m *= *tb; s += *tb;
  }
  if(!m)
    prterr("\n> ERROR: Check(!!m) failed!!\n");
  w ^= s + m;
  y  = (uint64_t)  w * m;
  y ^= (y >> 32) + s + m;
  return y;
}
#define chktbl(tp) _chktbl((uint32_t *)tp)

static inline
int _chktbl_match(uint32_t *tb, uint64_t tochk, const char *str) {
  uint64_t chk = _chktbl(tb);
  if(tochk != chk)
    prterr("\n> MISMATCH %s: 0x%016" PRIx64 ", \n", str, chk);
  return (tochk != chk);
}
#define chktbl_match(tb,a,b) _chktbl_match((uint32_t *)tb,a,b)

static inline
__attribute__((always_inline))
unsigned _strlen(uint8_t *str) {
  unsigned n = 0;
  if(str) while(*str++) n++;
  return n;
}

#if USE_FNCS
#define collect_entropy() urnd_eclt()
#else
#define collect_entropy() (void)(e = nano1rnd(e))
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

typedef struct {
  uint8_t unos;
  uint8_t trns;
  uint8_t bval;
  uint8_t good;
} good_byte_t;

int main(int argc, char *argv[]) {
#if RNG_ONLY
#else
  uint64_t t = get_nanos(); // init the timer, first of all
#endif
  good_byte_t gb[256];
  uint8_t mpage[WRITESZE], nb[7], c;
  uint32_t i, n, r, ncycl = 1, argn = 0;
  ssize_t wn;

  // for-loop is optimised for 32bit
  if(argc & 2) {
    argn = atol(argv[1]);
    if(argn < 4) argn = 4;
    if(argn < 64) {
      if(argn > 31) {
        ncycl = 1ULL << (argn-31);
        argn  = 1ULL << 31;
      } else {
        argn  = 1ULL << argn;
      }
    }
  }

  collect_entropy(); // #1

  r = 1 + !!argn;
  n = _strlen(umks_head);
  wn = sizeof(umks_head);
  c = umks_head[n + 1];
  print1("\n hsize: %d / %ld, xchar: 0x%02x\n", n, wn, c);
#if RNG_ONLY
  if( n != 123 || wn != 128 )
    return 1;
  else
  // RAF: when the header is masked, it never appears in RAM
  // becuase its printout is made a single char at time but
  // this doesn't imply that the whole string isn't cached
  // by something in the between. Anyway, in best effort.
  {
    uint8_t *q = umks_head;
    for(i = 0; (*q ^= c); i++, q++)
       write(r, q, 1);
  }
#else
  if( n != 84 || wn != 89 || c )
    return 1;
  wn = write(r, umks_head, n);
#endif

  collect_entropy(); // #2

  if( (MLTP_SZE != 64 && MLTP_SZE != 128)
#if USE_MTBL
   || (MTBL_SZE != 64 && MTBL_SZE != 128)
#endif
   || (TABLESZE != 64 && TABLESZE != 128) )
  {
    prterr("\n> ERROR: unsupported table size\n");
    return 1;
  }

  urnd_init();

  collect_entropy(); // #3

#if USE_MLTP
  if(chktbl_match(mltp, MLTP_CHK, MLTP_STR))
    return 1;
  collect_entropy(); // #4
#endif

#if USE_MTBL | USE_MLTP
  if(chktbl_match(mtbl, MTBL_CHK, MTBL_STRN))
    return 1;
  collect_entropy(); // #4
#else
  // byte WR pointer to the table
  uint8_t *q = (uint8_t *)table;

  // select & count the good ones
  *(uint32_t *)nb = 0;
  for (i = 0; i < 256; i++) {
    good_byte_t *pg = &gb[i]    ;
    pg->unos  =   cntbits(i)    ;
    pg->bval  =           i     ;
    pg->good  =   chkbits(i,1)  ;
    pg->good &= (pg->unos > 2)  ;
    pg->good &= (pg->unos < 6)  ;
    nb[pg->unos-3] += !!pg->good;
  }

  collect_entropy(); // #4

  // fill the goods array, p.1-3
  for (n = 0, r = 0; n < 3; n++) {
    for (i = 0; i < 256; i++) {
      if(gb[i].good
      && gb[i].unos == 3+n) {
        q[r++] = gb[i].bval;
        if( !(r%16) ) break;
      }
    }
  }

  collect_entropy(); // #5

  // fill the goods array, p.4
  for (i = 255; i; i--) {
    if(gb[i].good
    && gb[i].unos == 4) {
      q[r++] = gb[i].bval;
      if( !(r%16) ) break;
    }
  }

  collect_entropy(); // #6

  // check their counting
  newln1();
  print1("goods[]:\n");
  n = nb[0] + nb[1] + nb[2];
  print1("  tot: %3d/66\n", n);
  print1("   3b: %3d/66\n", nb[0]);
  print1("   4b: %3d/66\n", nb[1]);
  print1("   5b: %3d/66\n", nb[2]);
  if(n != 66) return(1);

  collect_entropy(); // #7

  // print the good ones
  newln1();
  print1("goods[]:\n");
  for (i = 0; i < 4; i++)
    print1("  idx:  hex, bits%3s| ","");
  newln1();
  for (i = 0; i < TABLESZE; i) {
    c = table[i];
    print1("  %03d: 0x%02x, %s%2d%-4s| ",
         i, c,
      gb[c].unos ? " " : "(",
      gb[c].unos,
            c    ? " " : ")");
    if(!(++i & 3)) newln1();
  }
#endif

  collect_entropy(); // #8

  // RAF: for-loop is optimised for 32bit //////////////////////////////////////
  int max = (argn?:4);
  uint32_t rndr[4], rndm[4];
  uint32_t *p = (uint32_t *)mpage;
  for(int k = 0; k < ncycl; k++) {
    for(n = 0; n < max; n++) {

#if USE_FNCS
      #define r urnd_e32r()
      #define m urnd_e32m()
      urnd_emix();
#else
      __attribute__((aligned(4)))
              uint32_t m,  r ;
      e = nano3rnd(e, &m, &r);
#endif
      if(argn) {
        *p++ = r;
        if((uint8_t *)p == mpage + WRITESZE) {
          wn = write(1, mpage, WRITESZE);
          collect_entropy();
          p = (uint32_t *)mpage;
        }
      } else {
        rndr[n] = r;
        rndm[n] = m;

        newln1();
        print1("   entr. pool: 0x%08x --> b#%s\n",
             rndr[n], bit64str(rndr[n], 32));
        print1("  const. n.%02d: 0x%08x --> b#%s\n",
          n, rndm[n], bit64str(rndm[n], 32));
      }
    }
  }
#if USE_FNCS
  #undef m
  #undef r
#endif
  newln1();

  if(argn) {
    wn = (uintptr_t)p - (uintptr_t)mpage;
    //fprintf(stderr, "\nwn: %ld\n", sizeof(umks_head), wn);
    if(wn > 0 & wn < WRITESZE)
      wn = write(1, mpage, wn);
  }
#if RNG_ONLY
#else
  else
  { ////////////////////////////////////////////////////////////////////////////

  uint32_t tb[MLTP_SZE + 16];
  uint8_t *w = (uint8_t *)tb;

  // scramble the table by sectors
  while (n--) {
    uint32_t m = rndm[n];
    scramtbl((r = rndr[n]));
    for(i = 1; i & 7; i++) {
      r = rotl32(r, 20);
      m = urnd_comb(r) ;
      scramtbl(r);
    }
  }

  #define ATTR_WEAK "\n__attribute__((weak))"
  #define ATTR_ALGN "\n__attribute__((aligned(4)))"
  #define ARRY_TYPE "\nconst uint32_t __thread "
  #define ARRY_OPEN "[] = {"
  #define ARRY_CLSE "\n};"
  #define DEFN_STRN "\n#define "

  //RAF: 32bit x 4 x 8 = 128byte, but also 128 words:
  //r32:   0|        8|       16|       24|       32|
  //1\0:    |  3bit   |  4bit   |  5bit   |  4bit   |
  //1by:    | 3,4,5,4 | 4,5,4,3 | 5,4,3,4 | 4,5,4,3 |
  n = MLTP_SZE >> 2;
  // RAF: mltp is not aligned at 32-bit on purpose
  print2(ATTR_WEAK ARRY_TYPE MLTP_VARN ARRY_OPEN);
  for(i = 0; i < (TABLESZE >> 2); i++) {
    const uint8_t *q = &table[i];
    *w++ =  q[ 0 + i];
    *w++ =  q[16 + i];
    *w++ =  q[32 + i];
    *w++ =  q[48 + i];
  }
#if MLTP_SZE > 64
  for(i = 0; i < (TABLESZE >> 2); i++) {
    const uint8_t *q = &table[i];
    *w++ = ~q[32 + i]; // ~5  -->  3  bits
    *w++ =  q[48 + i]; // 2nd --> 4th byte
    *w++ = ~q[ 0 + i]; // ~3  -->  5  bits
    *w++ =  q[16 + i]; // 2nd --> 4th byte
  }
#endif
  for(i = 0; i < 4; i++) {
    table[TABLESZE+i] = 0;
    tb[n++] = tb[i];
  }
  tb[n++] = 0;
  prntbl(tb, n);
  print2(ARRY_CLSE
    DEFN_STRN MLTP_STRN "_SZE %d"
    DEFN_STRN MLTP_STRN "_CHK 0x%016" PRIx64,
      MLTP_SZE, chktbl(tb) );
  newln2();

  print2(ATTR_WEAK ATTR_ALGN ARRY_TYPE MTBL_VARN ARRY_OPEN);
  prntbl((uint32_t *)table, 1 + (TABLESZE >> 2));
  print2(ARRY_CLSE
    DEFN_STRN MTBL_STRN "_SZE %d"
    DEFN_STRN MTBL_STRN "_CHK 0x%016" PRIx64,
      TABLESZE, chktbl(table) );
  newln2();

  t = get_nanos(); // collecting the running time
  print2(
    "\n//> Run time: %7.0f nS --> %.03lf mS\n",
      (float)t, (double)t/1E6);
  newln2();

  } ////////////////////////////////////////////////////////////////////////////
#endif

  return 0;
}

