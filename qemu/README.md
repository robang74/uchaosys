### Experimental hacked u-footprint QEMU edition

In 2019, RedHat presented the minimal footprint QEMU at **31MB for the Q35 machine with KVM** support. I tested a similar configuration and I found out that it was not less than 28MB. In these six years they did a good job in reducing 10% of the minimal footprint.

- [KVM Forum 2019 (un)bloated QEMU](https://static.sched.com/hosted_files/kvmforum2019/c6/kvmforum19-bloat.pdf) &nbsp;(pdf, by RedHat)

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
