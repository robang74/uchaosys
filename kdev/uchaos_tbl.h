
//> Executing umkaos.c in v0.4.0

// RAF: not aligned at 32 bit on purpose
const uint32_t __thread mltp[] = {
  0xb4d63525, 0xd2cb4d34, 0xb2cd6a4c, 0x9ab32b26, 
  0x996d362a, 0xccd95a52, 0xa6d5534a, 0x95b52da4, 
  0x9db4d635, 0x0cd2cb4d, 0x80b2cd6a, 0x0a9ab32b, 
  0x85996d36, 0x00ccd95a, 0xa0a6d553, 0x0a95b52d, 
  0xb4d63525, 
};
#define MLTP_SZE 64
#define MLTP_CHK 0x7f5fa9ce7b933b50

__attribute__((aligned(4)))
const uint32_t __thread mtbl[] = {
  0x32342925, 0x9426924c, 0x4952542a, 0x64a42c4a, 
  0x564d6935, 0x662b4b6a, 0x555a6536, 0x592d3353, 
  0xb6cb6bd6, 0xadb3d3cd, 0xabd95b6d, 0xdab59bd5, 
  0xacd2cab4, 0xaa9ad4b2, 0xc9cca599, 0xa99596a6, 
};
#define MTBL_SZE 64
#define MTBL_CHK 0x8350813133f95cc7

//> Run time:   93143 nS --> 0.093 mS

