## uChaos test status

Constants used:

```
#define HASHSEED 14695981039346656037ULL // FNV-1a
//                 0xCBF29CE484222325ULL // FNV-1a
#define murmul1    0xff51afd7ed558ccdULL
#define murmul2    0xc4ceb9fe1a85ec53ULL
#define murmul3    0x9E3779B9045d9f3bULL
#define murmul4    HASHSEED
```

Tests unit used:

```sh
grep name /proc/cpuinfo | head -n1
p4() { parallel -j4 "kdev/uckaos 32768" ::: {1..4}; }
p8() { parallel -j8 "kdev/uckaos 16384" ::: {1..8}; }
for i in $(seq 128); do p4; done | prnd/RNG_test stdin64
```

Lastest results:

```
model name	: Intel(R) Core(TM) i5-8365U CPU @ 1.60GHz

p4 | dd bs=1M of=/dev/null
Init mts 4096B access x7 times: 57 < 661.3 > 3137 nS
Init mts 4096B access x7 times: 59 < 637.0 > 3052 nS
Init mts 4096B access x7 times: 57 < 627.6 > 3075 nS
Init mts 4096B access x7 times: 57 < 646.1 > 3058 nS
0+120105 records in
0+120105 records out
1073741824 bytes (1.1 GB, 1.0 GiB) copied, 11.976 s, 89.7 MB/s

p8 | dd bs=1M of=/dev/null
Init mts 4096B access x7 times: 90 < 1034.1 > 4798 nS
Init mts 4096B access x7 times: 111 < 1429.4 > 6831 nS
Init mts 4096B access x7 times: 106 < 1262.4 > 6080 nS
Init mts 4096B access x7 times: 113 < 1200.1 > 5796 nS
Init mts 4096B access x7 times: 139 < 1226.1 > 5662 nS
Init mts 4096B access x7 times: 90 < 939.6 > 4436 nS
Init mts 4096B access x7 times: 85 < 948.4 > 4485 nS
Init mts 4096B access x7 times: 78 < 949.9 > 4581 nS
0+118048 records in
0+118048 records out
1073741824 bytes (1.1 GB, 1.0 GiB) copied, 12.4741 s, 86.1 MB/s

RNG_test using PractRand version 0.96
RNG = RNG_stdin64, seed = unknown
test set = core, folding = standard (64 bit)

length= 128 megabytes (2^27 bytes), time= 2.1 seconds
  no anomalies in 185 test result(s)

length= 256 megabytes (2^28 bytes), time= 4.4 seconds
  no anomalies in 199 test result(s)

length= 512 megabytes (2^29 bytes), time= 8.1 seconds
  no anomalies in 213 test result(s)

length= 1 gigabyte (2^30 bytes), time= 15.1 seconds
  no anomalies in 227 test result(s)

length= 2 gigabytes (2^31 bytes), time= 47.5 seconds
  no anomalies in 242 test result(s)

length= 4 gigabytes (2^32 bytes), time= 111 seconds
  no anomalies in 256 test result(s)

length= 8 gigabytes (2^33 bytes), time= 234 seconds
  no anomalies in 270 test result(s)

length= 16 gigabytes (2^34 bytes), time= 478 seconds
  no anomalies in 283 test result(s)

length= 32 gigabytes (2^35 bytes), time= 989 seconds
  Test Name                         Raw       Processed     Evaluation
  [Low16/64]BCFN(2+1,13-0U)         R=  +8.2  p =  6.3e-4   unusual
  ...and 295 test result(s) without anomalies

length= 64 gigabytes (2^36 bytes), time= 1993 seconds
  no anomalies in 308 test result(s)

length= 128 gigabytes (2^37 bytes), time= 4084 seconds
  no anomalies in 320 test result(s)
```
