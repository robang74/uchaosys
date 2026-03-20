# uchaosys

`(c)` 2026, Roberto A. Foglietta <roberto.foglietta@gmail.com>, text published under CC BY-NC-ND 4.0

- &nbsp;Click on the button to know how to &nbsp;[![Sponsor me](https://img.shields.io/badge/Sponsor-%E2%9D%A4-ff69b4?style=flat&logo=github)](https://github.com/sponsors/robang74)&nbsp; this project and get in touch with me.

<br>

![0KVM](docs/zero-entropy-virtual-machine.jpg)

<br>

## uChaos minimal Linux **qemu** bootable system

This project is based on the previous case study `random.txt` in [WIP](https://github.com/robang74/working-in-progress?tab=readme-ov-file#working-in-progress), starting on **2026-01-26**. Which leveraged the [BMLS](https://github.com/robang74/bare-minimal-linux-system) testing system for evolving from shell script (PoC) to the kernel (MVP). The main goal of respawning from scratch the project on a new repository is to strip the project from all that stuff accumulated over and over during the experimental development.

* [Technical Proposal for Commercial Sponsorship](docs/uchaos-sponsorship-presentation.md)

Last but not least, this project provide the 2.3Mb Linux embedded system as the result of a building process starting from the sources. Checking the information below and those reported in the link above, we can agree that this project is interesting from several point of views.

<br>

### Configuration

In this peculiar system configuration uChaos replaces all the entropy sources within the Linux kernel and creates a character device driver that can be seen as a side channel and/or a malicious entropy injection channel, as well.

Moreover, using extreme qemu parameters settings, it is possible testing the system into a condition of complete isolation (AFAIK) which grants the predictability by repeatability across reboots of the uchaos and Linux crng randomness providers, both.

<br>

### information

Following data are indicative and specific to [v0.6.1](https://github.com/robang74/uchaosys/releases/tag/v0.6.1) (87 KB) which is the initial tagged version in this repository and define the footprint of the embedded system.

Reference processor **i5-8365**, building times:

- `musl building elapsed time: 1475 s`
- `linux kernel building time:   95 s`
- `busybox custom making time:   17 s`
- `uchaos proj compiling time:    9 s`
- `system building total time: 1596 s (26m 36s)`

Reference architecture **x86_64**, footprint sizes:

- `dev/build enviroment  size: 4728 MB (4.74 GB)`
- `uncompressed .cpio    size: 2056 KB`
- `initramfs.cpio.gz     size:  980 KB`
- `linux kernel image    size: 1388 KB`
- `qemu bootable system  size: 2368 KB (2.31 MB)`

Running a minimal system, the essential metrics:

- `VM type: QMSZE=32M KARGS=quiet sh start.sh`
- `total time for being ready to user: 0.067 s`
- `total available memory in userland: 17432 KB`
    - `host: 32768, zram: -4462, cpio: -2056 KB`
    - `mlnx: 23552, used: -2460, buff:  -800 KB`

It is interesting to note how memory is allocated¹.<br>
¹ PractRand `RNG_test` not installed, size: 980 KB.

<br>

### Components

- **musl v1.2.15**, and related packages for the cross-compilation toolschain;

- **busybox v1.38**, as the whole initramfs system component and user shell;

- **linux v5.15.202**, as the kernel from a very widely spread LTS branch;

- **uchaosbox & dev.ko**, as userland utility toolbox and char device driver;.

#### External tools 

- [dL1](https://github.com/robang74/bare-minimal-linux-system/raw/refs/heads/main/update/common/usr/bin/RNG_test.gz.sh) &dash; **PractRand RNG_test**, external static tool for testing randonmess quality 

- [dL2](https://github.com/robang74/bare-minimal-linux-system/raw/refs/heads/main/update/common/usr/bin/cmd.gz.sh) &dash; **gzcmd.sh**, converts an executable in a gziped self-extracting executable

While PractRand `RNG_test` (2272 KB) is indispensable for testing, the `gzcmd.sh` is also relevant despite initramfs compression. In fact, the unreclaimable memory is allocated to host the uncompressed initramfs (aka `cpio` archive).

The `RNG_test.gz.sh` (900 KB) is 1372 KB lighter than the original, as much as the `bzImage`. Indeed, `RNG_test` requires a lot of RAM when working versus which the gzcmd saving isn't relevant but the rationale remains, presented here as a practical example.

However, using gzcmd executables make sense only when a storage is available. Otherwise there are two copies in RAM, at least. After all, `gzcmd.sh` exists as an alternative to compressed archives and initramfs is nothing else than a compressed `cpio` archive.

<br>

### Abstract

- [A Paradigm Shift: from Entropy Collection to Chaos Conduction](docs/uchaos-the-entropy-paradigm-shift.md) (2026-03-19)

It is essential to underline that uChaos at the time of this text writing is a 7½-weeks long project developed by a single person while the randomness in kernel space is a decades long team collaboration project. Hence, same results in same conditions whatever confirmed, isn't something trivial to achieve.

<br>
