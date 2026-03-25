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
