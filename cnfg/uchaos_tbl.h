
//> Executing umkaos.c in v0.4.2

// RAF: not aligned at 32 bit on purpose
__attribute__((weak))
const uint32_t __thread mltp[] = {
  0x99d365a4, 0xa9b64d34, 0xaacd6a2a, 0xccda5394, 
  0xa6d52b29, 0xb4d96664, 0x9a6b352c, 0xca5b594a, 
  0x0099d365, 0x00a9b64d, 0x0eaacd6a, 0x5bccda53, 
  0x39a6d52b, 0x15b4d966, 0xab9a6b35, 0xe8ca5b59, 
  0x99d365a4, 0xa9b64d34, 0xaacd6a2a, 0xccda5394, 
  0x00000000, 
};
#define MLTP_SZE 64
#define MLTP_CHK 0x2b49d09b44fd7858

__attribute__((weak))
__attribute__((aligned(4)))
const uint32_t __thread mtbl[] = {
  0x253432a4, 0x9294492a, 0x26644c29, 0x524a542c, 
  0x694d5565, 0x4b535a6a, 0x3366362b, 0x2d595635, 
  0x9bb66dd3, 0xd6dacbcd, 0xadd9b3d5, 0xab5bb56b, 
  0xc9a9ac99, 0x95cc96aa, 0xb2b4d4a6, 0xd2caa59a, 
  0x00000000, 
};
#define MTBL_SZE 64
#define MTBL_CHK 0x0693b99741df784b

//> Run time:   48675 nS --> 0.049 mS

