# uchaosys

uChaos minimal Linux **qemu** bootable system

## information

Reference processor **i5-8365**, building times:

- `musl building elapsed time: 1475 s`
- `linux kernel building time:   95 s`
- `busybox custom making time:   17 s`
- `uchaos proj compiling time:    9 s`
- `system building total time: 1596 s (26m 36s)`

Reference architecture **x86_64**, footprint sizes:

- `dev/build enviroment  size: 4726 MB`
- `uncompressed cpio/    size: 2116 KB`
- `initramfs.cpio.gz     size:  980 KB`
- `linux kernel image    size: 1388 KB`
- `qemu bootable system  size: 2368 KB (2.31 MB)`

Running system, essential metrics, boot time & RAM:

- `total time for being ready to user: 0.06 s`
- `used memory including 2116 KB cpio: 3348 KB`
- `total memory by qemu-system-x86_64: 9360 KB`
