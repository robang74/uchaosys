/*
 * (c) 2026, Roberto A. Foglietta <roberto.foglietta@gmail.com>, LGPLv2
 */
/* libm ********************************************************************* */

#include <stdint.h>

/* Minimal definition of the structure required by glibc on x86_64 */
struct cpu_features {
    uint32_t cpuid_features[4];
    uint32_t family;
    uint32_t model;
/* There are other fields, but the above are enough
   because resolvers only read the first few offsets. */
    uint64_t __padding_to_256_bit;
} __attribute__((packed)) __attribute__((aligned(32)));

/* Export the missing symbol, and use `weak` to avoid conflicts */
__attribute__((weak)) struct cpu_features _dl_x86_cpu_features;

/* glibc ******************************************************************** */

#define _GNU_SOURCE
#include <stdio.h>
#include <stdarg.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/syscall.h>
#include <errno.h>

/*
 * Export wrappers: `weak` to avoid conflicts and inline for optimisation
 *
 * WARNING !!! WARNING
 *
 * The keyword 'inline' is a suggestion for the compiler and **when** used the
 * "weak" symbol isn't passed anymore to the linker but wired in. This could
 * creates arbitrary mixing which "always_inline" prevents. However, this .o
 * could be absent during compilation and available only at linking time but
 * the linking stage could be LTO enabled. The "static" avoid LTO pollution.
 */
#if 0
#define weakinline static inline __attribute__((always_inline))
#else
#define weakinline __attribute__((weak))
#endif

weakinline
int __fprintf_chk(FILE *fp, int flag,
  const char *format, ...) {
    va_list ap;
    va_start(ap, format);
    int ret = vfprintf(fp, format, ap);
    va_end(ap);
    return ret;
}

weakinline
int __vfprintf_chk(FILE *fp, int flag,
  const char *format, va_list ap) {
    return vfprintf(fp, format, ap);
}

weakinline
int __snprintf_chk(char *s, size_t maxlen, int flag, size_t slen,
  const char *format, ...) {
    va_list ap;
    va_start(ap, format);
    int ret = vsnprintf(s, maxlen, format, ap);
    va_end(ap);
    return ret;
}

weakinline
int __vsprintf_chk(char *s, int flag, size_t slen,
  const char *format, va_list ap) {
    return vsprintf(s, format, ap);
}

weakinline
int __sprintf_chk(char *s, int flag, size_t slen,
  const char *format, ...) {
    va_list ap;
    va_start(ap, format);
    int ret = vsprintf(s, format, ap);
    va_end(ap);
    return ret;
}

weakinline
void *__memcpy_chk(void *dest, const void *src, size_t len, size_t destlen) {
    return memcpy(dest, src, len);
}

weakinline
void *__memmove_chk(void *dest, const void *src, size_t len, size_t destlen) {
    return memmove(dest, src, len);
}

weakinline
void *__memset_chk(void *dest, int c, size_t len, size_t destlen) {
    return memset(dest, c, len);
}

char *__strcpy_chk(char *dest, const char *src, size_t destlen) {
    return strcpy(dest, src);
}

weakinline
int close_range(unsigned int first, unsigned int last, unsigned int flags) {
#ifdef __NR_close_range
    return syscall(__NR_close_range, first, last, flags);
#else
    errno = ENOSYS;
    return -1;
#endif
}

weakinline
unsigned long long strtoull_l(const char *nptr, char **endptr, int base,
  void *loc __attribute__((unused)) ) {
    return strtoull(nptr, endptr, base);
}

weakinline
void __stack_chk_fail(void) {  /* Fallback for the stack protector, if needed */
    static const char *msg = "*** stack smashing detected ***: terminated\n";
    write(2, msg, strlen(msg));
    abort();
}

weakinline
int __printf_chk(int flag, const char *format, ...) {
    va_list ap;
    va_start(ap, format);
    int ret = vprintf(format, ap);
    va_end(ap);
    return ret;
}

weakinline
int __vasprintf_chk(char **ptr, int flag, const char *format, va_list ap) {
    return vasprintf(ptr, format, ap);
}

weakinline
long long strtoll_l(const char *nptr, char **endptr, int base, locale_t loc) {
    return strtoll(nptr, endptr, base);
}

weakinline
int __vsnprintf_chk(char *s, size_t maxlen, int flag,
  size_t slen, const char *format, va_list ap) {
    return vsnprintf(s, maxlen, format, ap);
}

