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

#define u8  uint8_t
#define u32 uint32_t
#define u64 uint64_t
#define atomic_t bool
#define ATOMIC_INIT(a) (a)
#define ktime_get_ns get_nanos
#define cpu_relax sched_yield
#define signal_pending(a) (a)
#define current false

static int min_delta = 3;
static int init_runs = 7;
static int loop_mult = 1;

#include "getnanos.h"
#include "uchaos_dev.h"

static void *kbufptr = NULL;

int main(int argc, char *argv[]) {
    size_t len = sizeof(archul_t) * EBUF_ITEMS;

    if(len > MAX_INPUT_SIZE) {
        fprintf(stderr, "\n\n>>> BUG: len = %zu > max = %zu\n\n",
            (size_t)len, (size_t)MAX_INPUT_SIZE);
    }

    kbufptr = malloc(MAX_INPUT_SIZE + HASHSIZE);
    if(!kbufptr) {
        perror("malloc");
        return -1;
    }
    kbuf = align_t(archul_t, kbufptr);

    __init4_djb2tum(kbuf, EBUF_ITEMS);
    write(fileno(stdout), (u8 *)kbuf, len);

    len = _unprotected_interuptible_kbuf_fill(len);
    write(fileno(stdout), (u8 *)kbuf, len);

    free(kbufptr);
    return 0;
}
