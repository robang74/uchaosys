## Linux kernel hacking

**`(c)`** 2026 – Roberto A. Foglietta &lt;roberto.foglietta@gmail.com&gt;, CC BY-NC-ND 4.0

- &nbsp;Click on the button to know how to &nbsp;[![Sponsor me](https://img.shields.io/badge/Sponsor-%E2%9D%A4-ff69b4?style=flat&logo=github)](https://github.com/sponsors/robang74)&nbsp; this project and get in touch with me.

This page explains the topic reporting a few posts of mine on Linkedin, presented by a thematic logical order rather than by pubblication chronology:

1. [post #1](https://www.linkedin.com/posts/robertofoglietta_uchaos-v056-kernel-hacked-despite-backport-share-7438605908743479296-i1ej) - uCHAOS v0.5.6: KERNEL HACKED DESPITE BACKPORT FIX &nbsp;(April 2026)
2. [post #3](https://www.linkedin.com/posts/robertofoglietta_kernel-address-randomisation-the-hack-share-7457708512408928258-I6hD) - KERNEL ADDRESS RANDOMISATION, THE HACK & THE PATCH - &nbsp;(May 2026)
3. [post #2](https://www.linkedin.com/posts/robertofoglietta_uchaos-v057-guess-the-sequence-if-you-share-7438867791648210944-7XAF) - uCHAOS v0.5.7: GUESS THE SEQUENCE, IF YOU CAN - &nbsp;(April 2026)

---

![kernel-hack-screenshot](linux-kernel-internals-hacking.png)

- Image source: `docs/`[`linux-kernel-internals-hacking.png`](linux-kernel-internals-hacking.png)

---

### The hack despite the back-porting fix

Despite the 5.15.x LTS serie had received a backport fix, the early init of the internal RNG creates troubles (a Kernel OOPS, precisely) therefore in the aim to set uChaos kernel module as the only entropy source for the kernel, I had to hack it calling an internal function by its bare address.

Once forced in this way the system has been tested against PractRand for several gigabytes both against /dev/uchaos and /dev/random which in this configuration has been activated and seeded by the uchaos_dev module. It is a testing / devel configuration, not supposed to be used as-is, at least in production but everything depends on the gut of the admins.

Both the sources showed the same quality of randomness during tests. The reference test system is BMLS v0.3 which incorporate the uckdev v0.5.6:

- https://lnkd.in/dq9mTrvG (testing system w/ qemu)
- https://lnkd.in/dtxuKm96 (Linux kernel driver)
- https://lnkd.in/dTKDYzzT (kernel config)
- https://lnkd.in/ddpg7h8N (Makefile)

#### UPDATE (CODE CLARIFICATION)

Direct Feed Mechanism: The module does not rely on standard registration interfaces (which are often unstable on kernel 5.15.x), but injects raw entropy via add_device_randomness() and immediately validates the bits through a direct call to credit_entropy_bits(). This ensures that the kernel pool is instantly ‘seeded’ at init without relying on external handlers.

Making a bare-address call within `uchaos_init` means that the uchaos module is not a “continuous generator” in the traditional kernel sense, but acts as a boot super-Seeder. Upon loading, it ensures that the entropy goes from “zero” to “ready” almost instantly, injecting the bare minimum volume of data for such a task which is for certainty less than 8 bits entropy per byte. This underfeeding is deliberate: if it fails, it should fail fast.

Also in this context the bare-minimum principle is ruling: the uchaos continues to not using cryptographic whitening, does whitening as less as possible (before delivery the final output, only), init the RNG internals with the theoretical bare minimum entropy to set it ready and never re-seed it again which is the main difference between /dev/uchaos and /dev/random and possibly the reason because the first does 22 MB/tick while the second 33 MB/tick (+50% more instruction per I/O byte efficiency).

For sake of clarity: /dev/uchaos is 1/3 less efficient (so /dev/random is 50% more efficient in terms of I/O per icount tick) because uchaos, as a producer of raw entropy, relies on cpu_relax(), whereas /dev/random performs ‘collection and computation’ with no waiting, as it certainly operates on a request-based (to give) or queuing (to take) basis. Despite cpu_relax() does not generate instructions, it allows another kernel thread to temporarily take over, and that thread advances the ticks counter, which in the -icount virtual machine is the 1:1 basis for the time passing.

---

### Kernel address randomisation, the hack

Actually uchaosys runs a Linux embedded system in which running address randomisation is set to off, totally. Which means that also the kernel is loaded at the same fixed address, every boot.

This makes perfectly sense because the main goal of the uchaosys is to establish which are the conditions for which a system can be totally isolated, thus it cannot receive entropy from the outside.

Once the isolation is achieved, the main question can be challenged: an isolated system that is deterministic and digital by design could generate true random chaos OR just deterministic (thus totally predictable) chaos? The second one, as expected.

As expected, means that for claiming something else we should provide exceptional evidence that true random chaos could be created by a deterministic digital system (analog systems are completely another story, but a digital system with ECC error correction system can be a totally pure deterministic system).

It makes no sense adding randomisation of the address when isolation is achieved because it generates a second layer of deterministic randomness. So, the question would be: would it work the same? And in particular the kernel hacking for which the uchaos_dev.ko can hijack the kernel CRNG, would work anyway?

This 2-prompts chat with Kimi provides some information about this topic:

- https://lnkd.in/dwT24AgB

Using an AI for retrieving information, it is fine and when a seasoned professional is involved, it can also share that information because he knows that it is fine. In fact, the answer is YES uchaos_dev.ko can work the same also when the kernel boots from a (true) random address because the module knows the offset (the address gap) between an internal static always present function like _printk() and the target function to call.

The series 5.15.x has been used because it suffers from a peculiar bug that should be fixed by a back-porting but such back-porting fix (or the original bugfix) doesn't cover a corner case. As usual, hackers like corner cases to kick in and load their code, so I did. And I did in a way to build the .ko AFTER knowing the addresses relative gap (offset). Which means that another kernel compiled in a slightly different manner would crash because that offset would be not valid (or just valid for chance, not in general).

Therefore, I do not need to check for the kernel version because that gap is like a finger-print between THAT build and its .ko which makes this working despite address randomisation but it would have no impact in the wild because that range changes micro-version by micro-version, at every sensitive .config change and building by building. And when the build changes, the .ko generates a kernel OOPS also when randomisation is off.

Moreover, hacking the kernel isn't necessary when we can patch the sources and rebuild the bzImage. It is a totally functional academic-performative hack instead of patch! 😎

---

### Chaos exists befirehands, or none at all

Can we simulate a Lorentz attractor by running a deterministic software on a deterministic machine? No, those are just pictures that provide a vague idea of that math concept. Yes, that's because the machine has an intrinsic chaotic nature but it usually does not emerge because engineers did their best to keep the hardware (and software) within conditions in which determinism and predictability appear to be absolute.

Under this perspective uChaos does the opposite: hypersensitive to nanosecond variations leverage them for forking stochastics (triggered by p=1:999, not p~50%) branches. Therefore it achieves unpredictability not because it is "magic" but because it is working outside the perimeter of stability that engineers designed. In some systems, that perimeter is about nanosecond scale, in others it might be micro or millisecond scale. Whatever the scale is, there is always a finite timing precision behind which the chaos can be found and exploited for providing randomness.

Wrong to say that uChaos emulates a Lorentz strange attractor. It works considering the whole system as a chaotic system. Therefore, chaos is over there even before uChaos 1st instruction runs. From this awareness, the user arguments (or their default values) instruct uChaos to work on the edge where determinism is fading into chaos and thus real entropy is abundant. Not pure white noise, but stochastic events that fork randomness into an unpredictable sequence of branches. uChaos is the endpoint of ONE of too many to guess the line of Universe.

- https://lnkd.in/djZW9CGq (paper, 2015, MIT)
- https://lnkd.in/dfKqc-W2 (v0.5.7 presentation)

From the “Entropy Poisoning from the Hypervisor” PoV, uchaos_dev does exactly the same when calling an internal not exported function of the Linux crng and init that system with 8 bytes of "its stuff". Then it exports the /dev/uchaos that can be seed by 8 zeros. At that point the side channel is created /dev/uchaos and the /dev/random is the victim. The main point and challenge: by all these facilities I provided you can you guess something?

- **No?** Because the chaos belong to the system beforehand and uchaos extract and amplify it.

- **Yes?** Then I need to improve the sensitivity of the branch frequencies. That's the reason because uchaos_dev has parameters. This is the main assumption to falsify: zeroing the chaos nature intrically embedded in any complex system to the point of not being leveraged by uchaos is equivalent to destroying utility or dumping the whole system to gain root/god privileges. Both aren't feasible in practice, and hard to reach in extreme controlled labs, if any.

#### PRACTICAL EXPERIMENTAL EXAMPLE

Starting an automatic endless test against `/dev/uchaos` seeded by 8-zeros.

```sh
UCTEST=4 QZERO=0 QWARM=0 QMSZE=1G sh start.sh "" bzImage.515x
rng=RNG_stdin64, seed=unknown
length= 32 gigabytes (2^35 bytes), time= 3818 seconds
 no anomalies in 296 test result(s)
 ```
 
