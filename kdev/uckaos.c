/*
 * uchaos_dev.h - Character device for uchaos-based jitter hashing
 * (c) 2026, Roberto A. Foglietta <roberto.foglietta@gmail.com>, GPLv2
 *
 * RATIONALE
 *
 * The aim of this application is to bring in userland the same stuff
 * that it is doing uchaos_dev in kernel space as a module. For granting
 * as much as possible that the two are the same stuff, a common .h is
 * used in kernel space and userland, both. That .h shares the same code.
 *
 * Compile with: musl-gcc uckaos.c -O3 -o uckaos -I../usrl -s -static
 */

/* RAF: userland counterparts moved in uchaos_dev.h */

#include "uchaos_dev.h"

static const
uint8_t ucks_head[] = {
  "\n/*\n * (C) 2026, github::@robang74, GPLv2\n */"
  "\n//> Executing uChaoSys::uckaos " VERSION
  "\n//> Use w/arg N for each 8KB dataout\n"
  "\n \0\0\0"
};

int main(int argc, char *argv[]) {
  archul_t ebuf[EBUF_ITEMS];
  size_t n, rept = 1, len = sizeof(ebuf);

  write(2, ucks_head, sizeof(ucks_head));
  if(argc > 1) rept = atol(argv[1]);

  __init4_djb2tum(ebuf, EBUF_ITEMS);
  write(2, "\n", 1);
  if(!kbuf || !rept) {
    n = write(fileno(stdout), (u8 *)ebuf, len);
    return rept ? -1 : 0;
  }

  while(rept--) {
    len = _unprotected_interuptible_kbuf_fill(MAX_INPUT_SIZE);
    n = write(fileno(stdout), (u8 *)kbuf, len);
  }
  return 0; // exit() does free() et al.
}
