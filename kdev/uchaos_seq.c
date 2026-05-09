#include <stdio.h>
#include <stdint.h>

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
  int n = 0;
  uint8_t c, bytes[256], count[256], nbits[256], goods[128];

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
  for (int i = 0; i < 256; i++) {
      if(!(c = bytes[i])) continue;
      n++;
  }

  // check their counting
  fprintf(stderr, "\n  tot: %d/124\n\n", n);
  if(n != 124) return(1);

  // store the good ones
  n = 1;
  goods[0] = 0;
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
  for (int i = 0; i < 128; ) {
    c = goods[i];
    printf("  %03d: 0x%02x, %s%2d%-4s| ",
         i, c,
      nbits[c] ? " " : "(",
      nbits[c],
            c  ? " " : ")");
    if(!(++i & 3)) putchar('\n');
  }
  putchar('\n');

  return 0;
}
