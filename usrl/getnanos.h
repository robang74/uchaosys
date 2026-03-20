/*
 * (c) 2026, Roberto A. Foglietta <roberto.foglietta@gmail.com>, MIT license
 *
 */

static inline uint64_t get_nanos(void) {
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
