## uChaos: Technical Proposal for Commercial Sponsorship

`(c)` 2026, Roberto A. Foglietta &lt;roberto.foglietta@gmail.com&gt;

&nbsp;Click on the button to know how to &nbsp;[![Sponsor me](https://img.shields.io/badge/Sponsor-%E2%9D%A4-ff69b4?style=flat&logo=github)](https://github.com/sponsors/robang74)&nbsp; this project



<br>

### Presentation of the uChaos Project

The [`uchaos.c`](usrl/uchaos.c), [`uchaosd.c`](usrl/uchaosd.c) and [`uchaos_dev.c`](kdev/uchaos_dev.c) are a set of **C** language coded solutions (MVP) among which the last one is a kernel device driver that recently developed within a month timeframe in which I did my own research about randomness.

The comments are also half of the interesting part in terms of presentation. So, let me quickly recap what I found out:

- randomness is currently a fundamental asset for cryptography which is a necessity in modern IT infrastructure

- randomness and entropy are two separate concepts which have been not deeply understood (physics, rather than math)

- modern distributed infrastructure virtualise almost everything because scalability on-demand and load balancing

- instead CPU and RAM are usually the two hardware which are universally provided by passthrough to VMs

- the above two points are mainly related to performances because huge numbers / volume requires efficiency

- the IoT and swarm meshes are another story but the same: cpu is universal, while hrng is not

- modern times includes geopolitical uncertainty and mass-surveillance by Gov agencies

Under the perspective from the points above listed, virtio-rng is free entropy only in a fully trustable environment and distributed infrastructure aren't by definition because they are geographically displaced in many countries which Govs do not share the same interest or way of resolving conflicts.

Networks geographically fragmentation / separation is a common best practice but did not solve the trust issue when infrastructure ownership, administration and hardware collocation did not match the same Gov agenda.

---

### Trust Sovereignty for Security Strategy

How does uChaos fit into a trust sovereignty by vendor/HW agnostic security strategy?

- uChaos novelty is being designed with physics-first rather than engineering-first mindset

- uChaos is Linux crng orthogonal and independent, a self-sufficient randomness source that can be also integrated in `/dev/*random`

- uChaos acts on the principle that CPU jittering, also leaking in VMs, is a good and abundant source of real entropy

- uChaos hasn't "trust issue" about input which can be a set of zeros, garbage or something bringing in entropy

- uChaos is available as out-of-the-three module and can replace integrally and frictionless the linux crng / virtio-rng

- uChaos is available in userland without even the need of root privilege and can be embedded into an application

- uChaos provide (AFAIK) a throughput 2/3 compared the `/dev/random`, the same randomness quality

- uChaos does not need to rely on cryptographic functions nor a secret seed, it is transparent and inspectable

- using [this](https://github.com/robang74/uchaosys) repository, it is possible to replicates MIT case study (2015) about malicious entropy injection in Linux crng.

- uChaos is not a finished commercial product but a minimum-viable-product (MVP) and it is ready for testing

In the above uChaos description list, self-sufficient refers to any real or virtual machine in which the CPU or the KVM passthrough leaks entropy directly or indirectly by scheduler jittering, In a totally deterministic machine the output is totally predictable and its security relies only on the secrecy of the seeding. In absolute zero entropy special case, uchaos behaviour, requirements and vulnerability fallback to the Linux crng model.

---

### Antagonist Testing uChaos in an Isolated VM

- `KARGS=quiet QMSZE=32M QZERO=1 ZWARM=0 sh start.sh`

which executes:

```sh
  qemu-system-x86_64 -m 32M -kernel bzImage -initrd initramfs.cpio.gz -nographic \
  -vga none -display none -no-reboot -boot order=dc -name zroklnx -accel tcg     \
  -cpu qemu64 -smp 1 -icount shift=0,sleep=off,align=off -serial mon:stdio       \ 
  -net none -rtc base=2026-03-01,clock=vm,driftfix=none -nodefaults -append      \
    'lpj=2000000 noapic nolapic clocksource=pit video=off nomodeset HOST=x86_64  \
    root=/dev/ram0 init=/init console=ttyS0,115200n8 net.ifnames=0 nokaslr       \
    deferred_probe_timeout=0 page_alloc.shuffle=0 memtest=0 random.trust_cpu=off \
    mitigations=off quiet'
```

Instead the nearest configuration to the real-world use case in distributed infrastructures:

- `KARGS=quiet QMSZE=2G QZERO=0 ZWARM=0 sh start.sh`

which executes:

```sh
  qemu-system-x86_64 -m 2G -kernel bzImage -initrd initramfs.cpio.gz -nographic  \
  -vga none -display none -no-reboot -boot order=dc -name tinylnx -enable-kvm    \
  -cpu host -machine accel=kvm -netdev user,id=net0,restrict=yes -device         \
  virtio-net-pci,netdev=net0 -append 'HOST=x86_64 root=/dev/ram0 init=/init      \
    console=ttyS0,115200n8 net.ifnames=0 nokaslr quiet'  
```

Those above listed and all the other configurations included into the start.sh have been tested against `PractRand stdin64` and passed tests also 128GB long while testing on terabyte scale, risks auditing and certifications are left to those needs them for their own sake or provided to those commercial sponsors interested in.

---

### Fields of Interest:

- High-Security Cloud, IoT Meshes / Fleet, Edge Computing, Personal VIP security.

In case your company could be seriously interested in participating and funding this project of mine, there are many ways to establish a collaboration including a sponsorship by github platform:

- [github.com/sponsors/robang74](https://github.com/sponsors/robang74)

The github platform is the natural 1st-channel of contact and at least granted as 3rd party intermediation but is not necessarily the best one in all the cases.

`--`<br>
Best regards,<br>
[Roberto A. Foglietta](https://www.linkedin.com/in/robertofoglietta/)<br>
+49.176.274.75.661<br>
+39.349.33.30.697

