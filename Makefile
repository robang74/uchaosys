#
# (c) 2026, Roberto A. Foglietta <roberto.foglietta@gmail.com>, MIT license
#     Makefile created by converting make.lst shell script
#

# Settings /////////////////////////////////////////////////////////////////////
ARCH        ?= x86_64

NCPU        := $(shell nproc)
MUSLCFGMAK  := cnfg/musl-125x.config.mak
BBOX_CFG    := $(shell ls -1 cnfg/busybox-*.config | tail -n1)

# Extract kernel version from config
KERNVER     := $(shell grep "LINUX_VER" $(MUSLCFGMAK) | cut -d\# -f1 | tr -dc 0-9. | tail -n1)
KVER_SHORT  := $(shell echo $(KERNVER) | tr -dc 0-9 | head -c3)x

# Paths
KDIR        := musl/linux-$(KERNVER).orig
KIMG        := $(KDIR)/arch/$(ARCH)/boot/bzImage
LNXPATH     := kdev/linux-kernel
CCPREFIX    := $(ARCH)-linux-musl-
TMPD        := cpio.tmp
KMOD        := uchaos_dev.ko

# Tools and Options
HOSTCC      := gcc
CC          := $(CCPREFIX)gcc
OPTS        := HOSTCC=$(HOSTCC) ARCH=$(ARCH) CROSS_COMPILE=$(CCPREFIX) CCPREFIX=$(CCPREFIX)
GZCMD_REPO  := https://raw.githubusercontent.com/robang74/bare-minimal-linux-system/
GZCMD_PATH  := refs/heads/main

path        := musl/output
export PATH := $(CURDIR)/$(path)/bin:$(CURDIR)/$(path)/$(ARCH)/bin:$(PATH)

.PHONY: all sources toolchain bzImage busybox uchaos rngtest install clean

all: sources toolchain bzImage busybox uchaos rngtest install

# target: sources //////////////////////////////////////////////////////////////
sources:
	git submodule update --init --recursive
	# Fetching gzcmd logic
	curl -sL $(GZCMD_REPO)/$(GZCMD_PATH)/gzcmd.sh -o gzcmd.sh
	sh gzcmd.sh gzcmd.sh gzcmd
	@echo

# target: toolchain ////////////////////////////////////////////////////////////
toolchain:
	@test -r musl/config.mak || cp $(MUSLCFGMAK) musl/config.mak
	cp -arf cnfg/hashes musl/
	$(MAKE) -j$(NCPU) -C musl install
	@echo
	tar czf musl-output.tar.gz musl/output/
	du -ms musl-output.tar.gz musl/output/
	@echo

# target: bzImage //////////////////////////////////////////////////////////////
bzImage:
	@test -e $(LNXPATH) || ln -sf ../$(KDIR) $(LNXPATH)
	@test -r $(LNXPATH)/.config || cp -f cnfg/linux-$(KVER_SHORT).config $(KDIR)/.config
	$(MAKE) -j$(NCPU) $(OPTS) -C $(LNXPATH) syncconfig modules_prepare bzImage modules
	@echo
	@strings $(KDIR)/vmlinux | grep -e "^Linux version" | tr , \\n
	du -Lk  $(KIMG)
	@echo

# target: busybox //////////////////////////////////////////////////////////////
busybox:
	@test -r bbox/.config || cp $(BBOX_CFG) bbox/.config
	$(MAKE) -j$(NCPU) $(OPTS) -C bbox oldconfig
	$(MAKE) -j$(NCPU) $(OPTS) -C bbox busybox
	@echo
	file bbox/busybox
	du -k bbox/busybox
	@echo

# target: uchaos ///////////////////////////////////////////////////////////////
uchaos:
	ln -sf $(KDIR)/ kdev
	cd minz; sh amalgamate.sh; cd ..
	$(MAKE) -j$(NCPU) -C kdev $(OPTS) dist
	$(MAKE) -j$(NCPU) -C usrl $(OPTS) uchaosbox
	@echo
	file kdev/$(KMOD).gz | sed -e s/\",/\"\\n/ -e s/n,/n\\n/
	du -k   kdev/$(KMOD).gz
	@echo

# target: rngtest //////////////////////////////////////////////////////////////
rngtest:
	$(MAKE) -j$(NCPU) -C prnd/ CCSYSROOT="-static -mavx2" CCPREFIX=$(CCPREFIX) RNG_test
	@echo
	file prnd/RNG_test
	du -k prnd/RNG_test
	@echo

# target: install //////////////////////////////////////////////////////////////
install:
	cp -arf cpio $(TMPD)/
	mkdir -p $(TMPD)/tmp/ $(TMPD)/var/log/ $(TMPD)/lib/modules/ $(TMPD)/usr/bin/
	cp -Lf $(KIMG) qemu/
	cp -Lf kdev/$(KMOD).gz $(TMPD)/lib/modules/$(KMOD)
	cp -Lf usrl/uchaosbox $(TMPD)/usr/bin/
	cp -Lf bbox/busybox $(TMPD)/usr/bin/
	chmod +x $(TMPD)/init
	# Symbolic links
	ln -sf bin $(TMPD)/usr/sbin
	ln -sf bin/busybox $(TMPD)/linuxrc
	ln -sf usr/sbin $(TMPD)/sbin
	ln -sf usr/bin $(TMPD)/bin
	ln -sf busybox $(TMPD)/bin/sh
	@echo
	cd qemu; sh start.sh -U; cd ..
	@echo

# target: clean ////////////////////////////////////////////////////////////////
clean:
	rm -rf gzcmd.sh gzcmd.sh.gz cpio.cpio $(TMPD)
	for dir in musl bbox kdev usrl prnd $(LNXPATH); do \
		$(MAKE) -C $$dir clean || true; \
	done

# target: veryclean ////////////////////////////////////////////////////////////
# This removes files that the script normally protects with 'test' or 'if' logic
veryclean: clean
	@echo "Removing custom configuration files and links"
# Protected by: test -r musl/config.mak
	rm -f musl/config.mak
# Protected by: test -e $lnxpath
	rm -f $(LNXPATH)
# Protected by: test -r $lnxpath/.config
	rm -f $(KDIR)/.config
# Protected by: test -r bbox/.config
	rm -f bbox/.config
# Additional cleanup for symlinks created in kdev
	rm -f kdev/linux-kernel
# Remove all the hashes added, as well
	rm -f musl/$(shell cd cnfg; ls -1 hashes/*)

# target: buildall /////////////////////////////////////////////////////////////
buildall: toolchain bzImage busybox uchaos install

# target: buildsys /////////////////////////////////////////////////////////////
buildsys: bzImage busybox uchaos install

