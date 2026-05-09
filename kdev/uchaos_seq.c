/*
 * uchaos_seq.c - Character sequencer for uchaos-based jitter hashing
 * (c) 2026, Roberto A. Foglietta <roberto.foglietta@gmail.com>, GPLv2
 */
 #define VERSION "v0.0.2"
 /*
 * Compile and run with:
 *     cc -s -g0 -O1 uchaos_seq.c -o ucseq && ./ucseq
 */

#include <stdio.h>
#include <stdint.h>
#include <string.h>

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

#if 0

int k, z = 0;
uint8_t *p = start_addr;

uint8_t byte[256], count[256];
for (int i = 0; i < 256; i++) {
  byte[i] = chkbits(i);
  count[i] = 0;
}

do {
  uint8_t b, b1 = 0, b2 = 0, b3 = 0;

  memcpy(ibuf, p, PAGESIZE);
  k = 0;
  do {
    b = byte[ibuf[k++]];
    if(!b || (count[b] >> 4)
    || !(b^b1) || !(b^b2) || !(b^b3))
      continue;
    obuf[z++] = b;
    count[b]++;
    b3 = b2;
    b2 = b1;
    b1 = b;
    if (PAGEFULL(z))
      break;
  } while (!PAGEFULL(k));

  p += PAGESIZE;
} while (!PAGEFULL(z));

#endif

int main(void) {
  int i, n, m;
  uint8_t bytes[256], count[256], nbits[256];
  uint8_t goods[128], table[256], nb[4], c;

  // select the good ones
  for (int i = 0; i < 256; i++) {
    bytes[i] = chkbits(i);
    nbits[i] = cntbits(i);
    count[i] = 0;
    if((c = nbits[i]) > 2 && c < 6)
      continue;
    bytes[i] = 0;
  }

  // count the good ones
  *(uint32_t *)nb = 0;
  for (int i = 0; i < 256; i++) {
      if(!(c = bytes[i])) continue;
      nb[nbits[c]-3]++;
      n++;
  }

  // check their counting
  printf("\n  Executing %s in %s\n\n",
    __FILE__, VERSION);
  printf("  tot: %3d/124\n", n);
  printf("   3b: %3d/124\n", nb[0]);
  printf("   4b: %3d/124\n", nb[1]);
  printf("   5b: %3d/124\n", nb[2]);
  printf("\n");
  if(n != 124) return(1);

  // store the good ones
  n = 1;
  memset(goods, 0, sizeof(goods));
  for (int i = 0; i < 256; i++) {
      if(!(c = bytes[i])) continue;
      goods[n++] = c;
      if(n & 0x1F) continue;
      goods[n++] = 0;
  }

  // print the good ones
  for (int i = 0; i < 4; i++)
    printf("  idx:  hex, bits%3s| ","");
  putchar('\n');
  for (int i = 0; i < 128; i) {
    c = goods[i];
    printf("  %03d: 0x%02x, %s%2d%-4s| ",
         i, c,
      nbits[c] ? " " : "(",
      nbits[c],
            c  ? " " : ")");
    if(!(++i & 3)) putchar('\n');
  }

  // create their table
  memset(table, 0, sizeof(table));
  for(m = 3; m < 6; m++) {
    n = (m-3) << 6;
    for (int i = 0; i < 128; i++) {
      if((c = goods[i]) && nbits[c] == m)
        table[n++] = c;
    }
  }

  // print their table
  for(m = 3; m < 6; m++) {
    n = (m-3) << 6;
    for (int i = 0; i < 64; i++) {
      if(!(i & 3)) putchar('\n');
      if(!(c = table[n+i])) break;
      printf("  %03d: b#%08b %d | ",
        n+i, c, nbits[c]);
    }
    putchar('\n');
  }

  putchar('\n');
  return 0;
}
