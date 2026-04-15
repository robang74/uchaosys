/*
 * (c) 2026, Roberto A. Foglietta <roberto.foglietta@gmail.com>, MIT license
 *
 */

#define get_nanos() ({ uint64_t _t=_get_nanos(); \
                      asm volatile("" : "+g"(_t)); _t; })

static inline volatile uint64_t _get_nanos(void) {
    static const unsigned long BLN = 1000000000;
    static uint64_t start = 0;
    struct timespec ts;
    
    clock_gettime(CLOCK_MONOTONIC, &ts);
    if (!start) {
        start = (uint64_t)ts.tv_sec * BLN + ts.tv_nsec;
        return start;
    }
    return ((uint64_t)ts.tv_sec * BLN + ts.tv_nsec) - start;
}
