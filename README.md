## μChaoSys

**`(c)`** 2026 – Roberto A. Foglietta &lt;roberto.foglietta@gmail.com&gt;, CC BY-NC-ND 4.0

- &nbsp;Click on the button to know how to &nbsp;[![Sponsor me](https://img.shields.io/badge/Sponsor-%E2%9D%A4-ff69b4?style=flat&logo=github)](https://github.com/sponsors/robang74)&nbsp; this project and get in touch with me.

<br>

![0KVM](docs/zero-entropy-virtual-machine.jpg)

<br>

### μChaos minimal Linux qemu bootable system

This project is based on the previous case study `random.txt` in [WIP](https://github.com/robang74/working-in-progress?tab=readme-ov-file#working-in-progress), starting on **2026-01-26**. Which leveraged the [BMLS](https://github.com/robang74/bare-minimal-linux-system) testing system for evolving from shell script (PoC) to the kernel (MVP). The main goal of respawning from scratch the project on a new repository is to strip the project from all that stuff accumulated over and over during the experimental development.

* [Technical Proposal for Commercial Sponsorship](docs/uchaos-sponsorship-presentation.md) (2026-03-16)

Last but not least, this project provides a micro Linux embedded system with a **footprint below 2MB** (including the kernel and the initramfs, cfr. [Components](README.md#components)) as the result of a building process starting from the sources. Checking the information below and those reported in the link above, we can agree that this project is interesting from several point of views.

<br>

### Configuration

In this peculiar system configuration uChaos replaces all the entropy sources within the Linux kernel and creates a character device driver that can be seen as a side channel and/or a malicious entropy injection channel, as well.

Moreover, using extreme qemu parameters settings, it is possible testing the system into a condition of complete isolation (AFAIK) which grants the predictability by repeatability across reboots of the uchaos and Linux crng randomness providers, both.

<br>

### information

The data reported below are indicative and specific for the reference tagged version [v0.6.3](https://github.com/robang74/uchaosys/releases/tag/v0.6.3) which adopts the all-static policy (footprints: +3% sys, +1% musl).

Reference processor **i5-8365**, toolchain metrics:

- `system building total time: 1010 s  (16m 50s)`&hairsp;¹
- `dev/build environment size: 4889 MB (4.77 GB)`
- `repository .zip copy  size:  102 KB`

Reference architecture **x86_64**, system footprint:

- `uncompressed .cpio    size:  664 KB`
- `initramfs.cpio.gz     size:  416 KB`
- `linux kernel image    size: 1384 KB`
- `qemu bootable system  size: 1800 KB (1.76 MB)`&hairsp;²

Running this minimal system, the essential metrics:

- `CPU single-pipeline KVM: sh start.sh -q -m 32`
- `total time for being ready to user: 0.054 s `**!!!**
- `total available memory in userland: 18804 KB`
    - `host: 32768, zram: -4722, cpio:  -664 KB`
    - `mlnx: 23548, used: -2408, buff: -1460 KB`

It is interesting to note how the memory is allocated&hairsp;.<br>

¹ without accounting sources download variable time.<br>
² without `RNG_test` for which .cpio size +2.28 MB.

<br>

### Components

- **musl v1.2.15**, and related packages for the cross-compilation toolchain;
- **busybox v1.38**, as the whole initramfs system component and user shell;
- **linux v5.15.202**, as the kernel from a very widely spread LTS branch;
- **uchaosbox & dev.ko**, as userland utility toolbox and char device driver.

#### External tools 

- [dL1](https://github.com/robang74/bare-minimal-linux-system/raw/refs/heads/main/update/common/usr/bin/RNG_test.gz.sh) &dash; **PractRand RNG_test**, external static tool for testing randonmess quality 
- [dL2](https://github.com/robang74/bare-minimal-linux-system/raw/refs/heads/main/update/common/usr/bin/cmd.gz.sh) &dash; **gzcmd.sh**, converts an executable in a gziped self-extracting executable

While PractRand `RNG_test` (2288 KB) is indispensable for testing, the `gzcmd.sh` is also relevant despite initramfs compression. In fact, the unreclaimable memory is allocated to host the uncompressed initramfs (aka `cpio` archive).

The `RNG_test.gz.sh` (906 KB) is 1366 KB lighter than the original, as much as the `bzImage`. Indeed, `RNG_test` requires a lot of RAM when working versus which the gzcmd saving isn't relevant but the rationale remains, presented here as a practical example.

However, using gzcmd executables make sense only when a storage is available. Otherwise there are two copies in RAM, at least. After all, `gzcmd.sh` exists as an alternative to compressed archives and initramfs is nothing else than a compressed `cpio` archive.

<br>

### Abstract

In this specific system configuration kernel is compiled in such a way that uChaos is the only source of entropy available (and just for seed the internal crng once) by loading the module which needs [to hack the kernel internals](docs/linux-kernel-internals-hacking.png) because backport fix from 6.x left a corner case uncovered.

It is worth to underline that this choice is not suggested as per a standard case use of uChaos but it is necessary for testing uChaos/crng duo excluding every possible internal source of interference: if it doesn't fail, it isn't because other sources of entropy are supplying.

- [A Paradigm Shift: from Entropy Collection to Chaos Conduction](docs/uchaos-the-entropy-paradigm-shift.md) (2026-03-19)

It is essential to underline that uChaos at the time of this text first writing (v0.6) was a 7½-weeks long project developed by a single person (started on 2026-01-26) while the randomness in kernel space is a decades long team collaboration project. Hence, the same results in the same conditions, whatever confirmed, isn't something trivial to achieve.

Last but not least, the chaos engine is **exactly** the same in kernel and user spaces: the same [`uchaos_dev.h`](kdev/uchaos_dev.h) translated in userspace by trivial macros. It compiles twice, and the two binaries never misalign: same file, same code. Audited once, it runs everywhere.

<br>

### Quick Start

```sh
git clone https://github.com/robang74/uchaosys.git
cd uchaosys
time make sources
time make buildall
make runqemu
```

The instructions above are able to provide the same output in about 20m, depending on the download transfer rate, unfortunately these days many GNU repositories are experiencing severe downtime.

- [uchaosys binary snapshot](https://github.com/robang74/working-in-progress/tree/main/uchaosys.qemu) &hairsp;v0.6.3 &hairsp;for qemu x86 64 bit

Considering that the system footprint is below 2MB, offering a binary sample makes sense independently from the outages. This snapshot is not supposed to be updated often, therefore refers to the above project link.

<br>

### Hacked μ-qemu

Since [v0.6.4](https://github.com/robang74/uchaosys/releases/tag/v0.6.4) this project also provides the option of compiling a special [footprint reduced](qemu/) edition of the `qemu-system-x86_64` binary (6044 KB) which uses a subset of ROMs (488 KB). It is worth to notice that, despite this custom **qemu v10.2.2** is still a dynamically compiled instance, the whole uChaSys + μ-qemu package occupy less than 10MB on an uncompressed file-system storage (8.14 MB, plus shared system libraries).

<br>

### License

The overall license for the uChaoSys binaries is dependent on the system components thus the GPLv2 is the reference as the most demanding license among those involved as long as "GPLv2 or later" means GPLv2 as an option.

<br>

