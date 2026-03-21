# uchaosys

`(c)` 2026, Roberto A. Foglietta <roberto.foglietta@gmail.com>, text published under CC BY-NC-ND 4.0

- &nbsp;Click on the button to know how to &nbsp;[![Sponsor me](https://img.shields.io/badge/Sponsor-%E2%9D%A4-ff69b4?style=flat&logo=github)](https://github.com/sponsors/robang74)&nbsp; this project and get in touch with me.

<br>

![0KVM](docs/zero-entropy-virtual-machine.jpg)

<br>

## uChaos minimal Linux **qemu** bootable system

This project is based on the previous case study `random.txt` in [WIP](https://github.com/robang74/working-in-progress?tab=readme-ov-file#working-in-progress), starting on **2026-01-26**. Which leveraged the [BMLS](https://github.com/robang74/bare-minimal-linux-system) testing system for evolving from shell script (PoC) to the kernel (MVP). The main goal of respawning from scratch the project on a new repository is to strip the project from all that stuff accumulated over and over during the experimental development.

* [Technical Proposal for Commercial Sponsorship](docs/uchaos-sponsorship-presentation.md) (2026-03-16)

Last but not least, this project provide a **micro 1.70 MB Linux embedded system** (footprint v0.6.2 including the kernel and the initramfs, cfr. [Components](README.md#components)) as the result of a building process starting from the sources. Checking the information below and those reported in the link above, we can agree that this project is interesting from several point of views.

<br>

### Configuration

In this peculiar system configuration uChaos replaces all the entropy sources within the Linux kernel and creates a character device driver that can be seen as a side channel and/or a malicious entropy injection channel, as well.

Moreover, using extreme qemu parameters settings, it is possible testing the system into a condition of complete isolation (AFAIK) which grants the predictability by repeatability across reboots of the uchaos and Linux crng randomness providers, both.

<br>

### information

The data reported below are indicative and specific for the reference tagged version [v0.6.2](https://github.com/robang74/uchaosys/releases/tag/v0.6.2) (repository archive size: 101 KB).

Reference processor **i5-8365**, building times:

- `musl building elapsed time: 1021 s`&hairsp;¹
- `linux kernel building time:  117 s`
- `busybox custom making time:   15 s`
- `uchaos proj compiling time:    8 s`
- `system building total time: 1092 s  (18m 12s)`

Reference architecture **x86_64**, footprint sizes:

- `dev/build enviroment  size: 4824 MB (4.71 GB)`
- `uncompressed .cpio    size:  644 KB`
- `initramfs.cpio.gz     size:  416 KB`
- `linux kernel image    size: 1328 KB`
- `qemu bootable system  size: 1744 KB (1.70 MB)`

Running a minimal system, the essential metrics:

- `VM type: QMSZE=32M KARGS=quiet sh start.sh`
- `total time for being ready to user: 0.056 s `**!!!**
- `total available memory in userland: 18856 KB`
    - `host: 32768, zram: -4724, cpio:  -736 KB`
    - `mlnx: 23548, used: -2404, buff: -1468 KB`

It is interesting to note how the memory is allocated&hairsp;².<br>
² without `RNG_test` installed which size is 2.23 MB.<br>
¹ without accounting sources download variable time.

<br>

### Components

- **musl v1.2.15**, and related packages for the cross-compilation toolschain;

- **busybox v1.38**, as the whole initramfs system component and user shell;

- **linux v5.15.202**, as the kernel from a very widely spread LTS branch;

- **uchaosbox & dev.ko**, as userland utility toolbox and char device driver;.

#### External tools 

- [dL1](https://github.com/robang74/bare-minimal-linux-system/raw/refs/heads/main/update/common/usr/bin/RNG_test.gz.sh) &dash; **PractRand RNG_test**, external static tool for testing randonmess quality 

- [dL2](https://github.com/robang74/bare-minimal-linux-system/raw/refs/heads/main/update/common/usr/bin/cmd.gz.sh) &dash; **gzcmd.sh**, converts an executable in a gziped self-extracting executable

While PractRand `RNG_test` (2288 KB) is indispensable for testing, the `gzcmd.sh` is also relevant despite initramfs compression. In fact, the unreclaimable memory is allocated to host the uncompressed initramfs (aka `cpio` archive).

The `RNG_test.gz.sh` (906 KB) is 1366 KB lighter than the original, as much as the `bzImage`. Indeed, `RNG_test` requires a lot of RAM when working versus which the gzcmd saving isn't relevant but the rationale remains, presented here as a practical example.

However, using gzcmd executables make sense only when a storage is available. Otherwise there are two copies in RAM, at least. After all, `gzcmd.sh` exists as an alternative to compressed archives and initramfs is nothing else than a compressed `cpio` archive.

<br>

### Abstract

In this specific system configuration kernel is compiled in such a way that uChaos is the only source of entropy available (and just for seed the internal crng once) by loading the module which needs to hack the kernel internals because backport fix from 6.x left a corner case uncovered.

It is worth to underline that this choice is not suggested as per a standard case use of uChaos but it is necessary for testing uChaos/crng duo excluding every possible internal source of interference: if it doesn't fail, it isn't because other sources of entropy are supplying.

- [A Paradigm Shift: from Entropy Collection to Chaos Conduction](docs/uchaos-the-entropy-paradigm-shift.md) (2026-03-19)

It is essential to underline that uChaos at the time of this text writing is a 7½-weeks long project developed by a single person while the randomness in kernel space is a decades long team collaboration project. Hence, same results in same conditions whatever confirmed, isn't something trivial to achieve.

<br>
