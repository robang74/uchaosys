# uchaosys

`(c)` 2026, Roberto A. Foglietta <roberto.foglietta@gmail.com>, text published under CC BY-NC-ND 4.0

- &nbsp;Click on the button to know how to &nbsp;[![Sponsor me](https://img.shields.io/badge/Sponsor-%E2%9D%A4-ff69b4?style=flat&logo=github)](https://github.com/sponsors/robang74)&nbsp; this project and get in touch with me.

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

Following data are indicative and specific to [v0.6](https://github.com/robang74/uchaosys/releases/tag/v0.6) (69Kb)

Reference processor **i5-8365**, building times:

- `musl building elapsed time: 1475 s`
- `linux kernel building time:   95 s`
- `busybox custom making time:   17 s`
- `uchaos proj compiling time:    9 s`
- `system building total time: 1596 s (26m 36s)`

Reference architecture **x86_64**, footprint sizes:

- `dev/build enviroment  size: 4726 MB`
- `uncompressed .cpio    size: 2056 KB`
- `initramfs.cpio.gz     size:  980 KB`
- `linux kernel image    size: 1388 KB`
- `qemu bootable system  size: 2368 KB (2.31 MB)`

Running system, essential metrics:

- `total time for being ready to user: 0.06 s`
- `used memory including 2856 KB cpio: 3468 KB`
- `total memory by qemu-system-x86_64: 9360 KB`

<br>

### Components

- **musl v1.2.15**, and related packages for the cross-compilation toolschain;

- **busybox v1.38**, as the whole initramfs system component and user shell;

- **linux v5.15.202**, as the kernel from a very widely spread LTS branch;

- **uchaosbox & dev.ko**, as userland utility toolbox and char device driver.

<br>

### Abstract

- [A Paradigm Shift: from Entropy Collection to Chaos Conduction](docs/uchaos-the-entropy-paradigm-shift.md) (2026-03-19)

It is essential to underline that uChaos at the time of this text writing is a 7½-weeks long project developed by a single person while the randomness in kernel space is a decades long team collaboration project. Hence, same results in same conditions whatever confirmed, isn't something trivial to achieve.

<br>
