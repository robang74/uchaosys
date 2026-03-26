
/*
 * (c) 2026, Roberto A. Foglietta <roberto.foglietta@gmail.com>, LGPLv2
 */

#include <stdint.h>

/* Definizione minima della struttura richiesta da glibc su x86_64 */
struct cpu_features {
    uint32_t cpuid_features[4];
    uint32_t family;
    uint32_t model;
    /* Altri campi seguono, ma per il link statico spesso basta questo 
       perché i resolver leggono solo i primi offset. */
};

/* Esporta il simbolo che manca al linker ma per evitare collisoni us weak */
__attribute__((weak)) struct cpu_features _dl_x86_cpu_features;

#define _GNU_SOURCE
#include <stdio.h>
#include <stdarg.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/syscall.h>
#include <errno.h>

/* --- 1. PROTEZIONE PRINTF / SCANF --- */

__attribute__((weak))
int __fprintf_chk(FILE *fp, int flag, const char *format, ...) {
    va_list ap;
    va_start(ap, format);
    int ret = vfprintf(fp, format, ap);
    va_end(ap);
    return ret;
}

__attribute__((weak))
int __vfprintf_chk(FILE *fp, int flag, const char *format, va_list ap) {
    return vfprintf(fp, format, ap);
}

__attribute__((weak))
int __snprintf_chk(char *s, size_t maxlen, int flag, size_t slen, const char *format, ...) {
    va_list ap;
    va_start(ap, format);
    int ret = vsnprintf(s, maxlen, format, ap);
    va_end(ap);
    return ret;
}

__attribute__((weak))
int __vsprintf_chk(char *s, int flag, size_t slen, const char *format, va_list ap) {
    return vsprintf(s, format, ap);
}

__attribute__((weak))
int __sprintf_chk(char *s, int flag, size_t slen, const char *format, ...) {
    va_list ap;
    va_start(ap, format);
    int ret = vsprintf(s, format, ap);
    va_end(ap);
    return ret;
}

/* --- 2. PROTEZIONE MEMORIA (STRING.H) --- */

__attribute__((weak))
void *__memcpy_chk(void *dest, const void *src, size_t len, size_t destlen) {
    return memcpy(dest, src, len);
}

__attribute__((weak))
void *__memmove_chk(void *dest, const void *src, size_t len, size_t destlen) {
    return memmove(dest, src, len);
}

__attribute__((weak))
void *__memset_chk(void *dest, int c, size_t len, size_t destlen) {
    return memset(dest, c, len);
}

char *__strcpy_chk(char *dest, const char *src, size_t destlen) {
    return strcpy(dest, src);
}

/* --- 3. SYSCALL E LOCALI --- */

__attribute__((weak))
int close_range(unsigned int first, unsigned int last, unsigned int flags) {
#ifdef __NR_close_range
    return syscall(__NR_close_range, first, last, flags);
#else
    errno = ENOSYS;
    return -1;
#endif
}

//typedef void *locale_t;

__attribute__((weak))
unsigned long long strtoull_l(const char *nptr, char **endptr, int base, locale_t loc) {
    return strtoull(nptr, endptr, base);
}

/* Fallback per lo stack protector se necessario */
__attribute__((weak))
void __stack_chk_fail(void) {
    const char *msg = "*** stack smashing detected ***: terminated\n";
    write(2, msg, strlen(msg));
    abort();
}

/* funzioni aggiuntive che richiedono un wrapper */

__attribute__((weak))
int __printf_chk(int flag, const char *format, ...) {
    va_list ap;
    va_start(ap, format);
    int ret = vprintf(format, ap);
    va_end(ap);
    return ret;
}

__attribute__((weak))
int __vasprintf_chk(char **ptr, int flag, const char *format, va_list ap) {
    return vasprintf(ptr, format, ap);
}

__attribute__((weak))
long long strtoll_l(const char *nptr, char **endptr, int base, locale_t loc) {
    return strtoll(nptr, endptr, base);
}

/* Includi anche queste se il linker le chiede */
__attribute__((weak))
int __vsnprintf_chk(char *s, size_t maxlen, int flag, size_t slen, const char *format, va_list ap) {
    return vsnprintf(s, maxlen, format, ap);
}

