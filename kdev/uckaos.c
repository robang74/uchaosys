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

#include <time.h>
#include <stdint.h>
#include <stdbool.h>
#include <sys/mman.h>
#include <unistd.h>
#include <sched.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define u8  uint8_t
#define u16 uint16_t
#define u32 uint32_t
#define u64 uint64_t
#define atomic_t bool
#define ATOMIC_INIT(a) (a)
#define printk(fmt, ...) fprintf(stderr, fmt, ##__VA_ARGS__)
#define ktime_get_ns get_nanos
#define cpu_relax sched_yield
#define signal_pending(a) (a)
#define prtkinfo printk
#define current false
#define GFP_KERNEL 0
#define kfree free

static int min_delta = 3;
static int init_runs = 7;
static int loop_mult = 1;

extern char __executable_start;
#define _printk (&__executable_start)
#define PAGE_SIZE sysconf(_SC_PAGESIZE)

static inline unsigned get_order(uint32_t len) {
  unsigned i = 0;
  uint64_t n = (len + PAGE_SIZE - 1) / PAGE_SIZE;
  if (n > 1) for(n--; n > 0; n >>= 1) i++;
  return i;
}

static inline void *zmalloc(size_t len) {
  void *p = malloc(len);
  if(p) memset(p, 0, len);
  return p;
}
#define kzalloc(a,b) zmalloc(a)

#define __get_free_pages(a,b) mmap(NULL, (size_t)PAGE_SIZE << b, \
            PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_ANONYMOUS, -1, 0)

#include "getnanos.h"
#include "uchaos_dev.h"

int main(int argc, char *argv[]) {
  archul_t ebuf[EBUF_ITEMS];
  size_t n, rept = 1, len = sizeof(ebuf);

  if(argc > 1) rept = atol(argv[1]);

  __init4_djb2tum(ebuf, EBUF_ITEMS);
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
