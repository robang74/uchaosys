
//> Executing umkaos.c in v0.4.0

// RAF: not aligned at 32 bit on purpose
const uint32_t __thread mltp[] = {
  0xa6d35a25, 0xa5d53694, 0xd26d5626, 0xb4b56932, 
  0xacb34b4a, 0x969b352c, 0x9ad64d92, 0xb26b2b4c, 
  0xdba6d35a, 0x50a5d536, 0x00d26d56, 0x00b4b569, 
  0x87acb34b, 0x9a969b35, 0x3e9ad64d, 0x7fb26b2b, 
  0xa6d35a25, 0xa5d53694, 0xd26d5626, 0xb4b56932, 
};
#define MLTP_SZE 64
#define MLTP_CHK 0x14dbc2512d72b70e

__attribute__((aligned(4)))
const uint32_t __thread mtbl[] = {
  0x49942925, 0x2a32a426, 0x342c524a, 0x544c6492, 
  0x5536655a, 0x59695356, 0x6a352d4b, 0x662b334d, 
  0xadd5b6d3, 0xcdb5ab6d, 0x5b9bcbb3, 0xda6bd9d6, 
  0xd4a5cca6, 0xaab499d2, 0x9596a9ac, 0xcab2c99a, 
};
#define MTBL_SZE 64
#define MTBL_CHK 0x0c48de8474c2157b

//> Run time:   46750 nS --> 0.047 mS

