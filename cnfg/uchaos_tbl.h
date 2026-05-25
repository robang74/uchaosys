
/*
 * (c) 2026, roberto.foglietta@gmail.com, GPLv2
 */
//> Executing uChaoSys::umkaos.c v0.4.2

// RAF: not aligned at 32 bit on purpose
__attribute__((weak))
const uint32_t __thread mltp[] = {
  0xa5b3654c, 0xd4ab66a4, 0x9a9b4b25, 0x996d3332, 
  0xccd96964, 0xb4d63552, 0xd2da5994, 0xa9cb4d2c, 
  0x00a5b365, 0x00d4ab66, 0x009a9b4b, 0x00996d33, 
  0x00ccd969, 0x00b4d635, 0x00d2da59, 0x00a9cb4d, 
  0xa5b3654c, 0xd4ab66a4, 0x9a9b4b25, 0x996d3332, 
  0x00000000, 
};
#define MLTP_SZE 64
#define MLTP_CHK 0x21b63455b21acae6

__attribute__((weak))
__attribute__((aligned(4)))
const uint32_t __thread mtbl[] = {
  0x2aa4544c, 0x92323425, 0x26524a64, 0x492c2994, 
  0x5a665665, 0x2b33534b, 0x55352d69, 0x364d6a59, 
  0xcdabadb3, 0x5b6d6b9b, 0xb6d6b5d9, 0xd3cbd5da, 
  0x96d4aaa5, 0x9599b29a, 0xcab4accc, 0xc9a9a6d2, 
  0x00000000, 
};
#define MTBL_SZE 64
#define MTBL_CHK 0x8c9c602f2f656be6

//> Run time:   30447 nS --> 0.030 mS

