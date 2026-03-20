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

#define MAX_INPUT_SIZE (1024 << 3)

#define AB  (6)
#define ABL (AB-3)        //  2 or  3
#define ABN (1<<AB)       // 32 or 64
#define ABX (ABN-1)       // 31 or 63
#define ABx ((ABN>>1)-1)  // 15 or 31
#define ABy ((ABN>>2)-1)  //  7 or 15
#define ABz ((ABN>>3)-1)  //  3 or  7

#define HASH_SEED 14695981039346656037ULL
#define HASHSIZE (ABN >> 3)

#define u8  uint8_t
#define u32 uint32_t
#define u64 uint64_t
#define atomic_t bool
#define ATOMIC_INIT(a) (a)
#define ktime_get_ns get_nanos
#define cpu_relax sched_yield
#define signal_pending(a) (a)
#define current false

typedef u64 __attribute__((aligned(HASHSIZE))) archul_t;

static int min_delta = 3;
static int init_runs = 7;
static int loop_mult = 1;

#include "getnanos.h"
#include "uchaos_dev.h"
 
int main(int argc, char *argv[]) {
    size_t len = 8;
    archul_t ebuf[4];
    __init4_djb2tum(ebuf);
    
    len = _unprotected_interuptible_kbuf_fill(len);
    write(fileno(stdout), (u8 *)kbuf, len);
}
