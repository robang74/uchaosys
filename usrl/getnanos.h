/*
 * (c) 2026, Roberto A. Foglietta <roberto.foglietta@gmail.com>, MIT license
 *
 */

#ifndef GET_NANOS_H
#define GET_NANOS_H

#include <time.h>
#include <stdint.h>

#define _1MLN_ 1000000
#define _1BLN_ 1000000000

#define get_nanos() ({ uint64_t _t=_get_nanos(); \
                      asm volatile("" : "+g"(_t)); _t; })

static inline volatile uint64_t _get_nanos(void) {
    static uint64_t start = 0;
    struct timespec ts;
    
    clock_gettime(CLOCK_MONOTONIC, &ts);
    if (!start) {
        start = (uint64_t)ts.tv_sec * _1BLN_ + ts.tv_nsec;
        return start;
    }
    return ((uint64_t)ts.tv_sec * _1BLN_ + ts.tv_nsec) - start;
}

#endif //GET_NANOS_H
