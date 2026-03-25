### Experimental hacked μ-footprint QEMU edition

In 2019, RedHat presented the minimal footprint QEMU at **31MB for the Q35 machine with KVM** support. I tested a similar configuration and I found out that it was not less than 28MB. In these six years they did a good job in reducing 10% of the minimal footprint.

- [KVM Forum 2019 (un)bloated QEMU](https://static.sched.com/hosted_files/kvmforum2019/c6/kvmforum19-bloat.pdf) &nbsp;(PDF slides, by RedHat)

I did a "trick of mine", possibly two, and the minimal footprint to have a x86-64 with both kvm (q35) and tcg (microvm) is **a bit less than 6MB**. Do not trust me and try to replicate.

![image](red-hat-kvm-2019-qemu-footprint.png)

---

### Quick Start

```sh
git clone https://github.com/robang74/uchaosys.git
cd uchaosys/qemu
git switch devl
sh make.sh veryclean sources
```

---

### Rationale

The debloating here presented is a quick hack that removes the CXL support without introducing a `--disable-cxl` parameter that `configure` can deal acting upon a value on a specific define like `CONFIG_DISNABLE_CXL` but passed by `-D_DISABLE_CXL` in `--extra-cflags`. Which implies that the proposed hack is for testing only.

#### Impact

- You won't find a CXL device in a typical workstation, laptop, or embedded system.

Compute Express Link (CXL) is an open standard interconnect for high-speed, high capacity CPU-to-device and CPU-to-memory connections, designed for high performance data center computers. The CXL specification 1.0 and 1.1 were released in 2019, based on PCIe 5.0 bus protocol support which allows the host CPU to access shared memory on accelerator devices with a cache coherent protocol.

CXL is designed for high performance data center computers, and the first real-world CPU support arrived with Intel Sapphire Rapids and AMD Zen 4 EPYC "Genoa" and "Bergamo" in 2021 — both server-class parts.

PCIe 5.0 on consumer/desktop platforms only started appearing with Intel 12th/13th gen and AMD Ryzen 7000, but even then those platforms don't expose CXL — the CPU has the PHY but the ecosystem (CXL memory expanders, accelerators) remains entirely a datacenter story.

