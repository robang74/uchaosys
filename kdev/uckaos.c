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
#define ktime_get_ns get_nanos
#define cpu_relax sched_yield
#define signal_pending(a) (a)
#define current false
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

#include "getnanos.h"
#include "uchaos_dev.h"

static void *kbufptr = NULL;

int main(int argc, char *argv[]) {
    size_t n, len = sizeof(archul_t) * EBUF_ITEMS;

    if(len > MAX_INPUT_SIZE) {
        fprintf(stderr, "\n\n>>> BUG: len = %zu > max = %zu\n\n",
            (size_t)len, (size_t)MAX_INPUT_SIZE);
    }

    kbufptr = malloc(MAX_INPUT_SIZE + HASHSIZE);
    if(!kbufptr) {
        perror("malloc");
        return -1;
    }
    ts.kbufptr = kbuf = align_t(archul_t, kbufptr);
    ts.kbuf_pages_order = get_order(MAX_INPUT_SIZE);

    __init4_djb2tum(kbuf, EBUF_ITEMS);
    n = write(fileno(stdout), (u8 *)kbuf, len);

    len = _unprotected_interuptible_kbuf_fill(MAX_INPUT_SIZE);
    n = write(fileno(stdout), (u8 *)kbuf, len);

    free(kbufptr);
    return 0;
}
