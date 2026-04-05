#
# (c) 2026, Roberto A. Foglietta <roberto.foglietta@gmail.com>, MIT license
#     Makefile created by converting make.lst shell script
#

# Settings /////////////////////////////////////////////////////////////////////
ARCH        ?= x86_64

NCPU        ?= $(shell nproc)
MUSLCFGMAK  := cnfg/musl-125x.config.mak
BBOX_CFG    := $(shell ls -1 cnfg/busybox-*.config | tail -n1)

# Extract kernel version from config
KERNVER     := $(shell grep "LINUX_VER" $(MUSLCFGMAK) | cut -d\# -f1 | tr -dc 0-9. | tail -n1)
KVER_SHORT  := $(shell echo $(KERNVER) | tr -dc 0-9 | head -c3)x

# Paths
VDIR        := virt
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
OPTS        += CFLAGS_EXTRA="-falign-functions=32"
GZCMD_REPO  := https://raw.githubusercontent.com/robang74/bare-minimal-linux-system/
GZCMD_PATH  := refs/heads/main

path        ?= musl/output
export PATH := $(CURDIR)/$(path)/bin:$(CURDIR)/$(path)/$(ARCH)/bin:$(PATH)

.PHONY: all muslcfg sources toolchain bzImage busybox miniz uchaos rngtest install veryclean clean  buildall buildsys buildemu uemutest uemurset runqemu

all: sources toolchain bzImage busybox uchaos rngtest buildemu install

# target: muslcfg //////////////////////////////////////////////////////////////
muslcfg:
	if [ ! -r musl/config.mak ]; then cp $(MUSLCFGMAK) musl/config.mak; \
cp -arf cnfg/hashes musl/; cp -f musl/Makefile musl/Makefile.bak; \
cp -f cnfg/Makefile.musl musl/Makefile; cp -f cnfg/Makefile.lite musl/litecross/Makefile; fi

# target: sources //////////////////////////////////////////////////////////////
sources: update muslcfg
	@echo Wait downloading sources ...
	$(MAKE) -j$(NCPU) -C musl extract_all
	@echo

# target: update ///////////////////////////////////////////////////////////////
update:
	@echo Wait updating project dependencies ...
	git submodule update --init --recursive --depth 32 --single-branch --jobs $(NCPU)
	curl -sL $(GZCMD_REPO)/$(GZCMD_PATH)/gzcmd.sh -o gzcmd.sh && sh gzcmd.sh gzcmd.sh gzcmd
	@echo

# target: toolchain ////////////////////////////////////////////////////////////
# @echo "Sync and drop caches, ^C to skip root password"
# sync; echo 3 | sudo tee /proc/sys/vm/drop_caches | grep -q .
toolchain: muslcfg
	make -j$(NCPU) -C musl install
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

# target: miniz ////////////////////////////////////////////////////////////////
miniz:
	cd minz; sh amalgamate.sh; cd ..

# target: uchaos ///////////////////////////////////////////////////////////////
uchaos: miniz
	ln -sf $(KDIR)/ kdev
	$(MAKE) -j$(NCPU) -C kdev $(OPTS) dist
	$(MAKE) -j$(NCPU) -C usrl $(OPTS) uchaosbox
	@echo
	file kdev/$(KMOD).gz | sed -e s/\",/\"\\n/ -e s/n,/n\\n/
	du -k   kdev/$(KMOD).gz
	@echo

# target: rngtest //////////////////////////////////////////////////////////////
rngtest:
	$(MAKE) -j$(NCPU) $(OPTS) -C prnd/ RNG_test \
	  CCSYSROOT="-static -mavx2" CCPREFIX=$(CCPREFIX)
	@echo
	file prnd/RNG_test
	du -k prnd/RNG_test
	@echo

# target: install //////////////////////////////////////////////////////////////
install:
	cp -arf cpio $(TMPD)/
	mkdir -p $(TMPD)/tmp/ $(TMPD)/var/log/ $(TMPD)/lib/modules/ $(TMPD)/usr/bin/
	cp -Lf $(KIMG) $(VDIR)/
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
	cd $(VDIR); sh start.sh -U; cd ..
	@echo

# target: clean ////////////////////////////////////////////////////////////////
clean:
	rm -rf gzcmd.sh gzcmd.sh.gz cpio.cpio $(TMPD) || true
	for dir in musl bbox kdev usrl prnd $(LNXPATH); do \
		$(MAKE) -j$(NCPU) ARCH=$(ARCH) -C $$dir clean || true; \
	done

# target: veryclean ////////////////////////////////////////////////////////////
# This removes files that the script normally protects with 'test' or 'if' logic
veryclean: clean
	@echo "Removing custom configuration files and links"
# Protected by: test -r musl/config.mak
	rm -f musl/config.mak || true
	cp -f musl/Makefile.bak musl/Makefile
# Protected by: test -e $lnxpath
	rm -f $(LNXPATH) || true
# Protected by: test -r $lnxpath/.config
	rm -f $(KDIR)/.config || true
# Protected by: test -r bbox/.config
	rm -f bbox/.config || true
# Additional cleanup for symlinks created in kdev
	rm -f kdev/linux-kernel || true
# Remove all the hashes added, as well
	rm -f musl/$(shell cd cnfg; ls -1 hashes/*) || true

# target: buildall /////////////////////////////////////////////////////////////
buildall: toolchain bzImage busybox uchaos install

# target: buildsys /////////////////////////////////////////////////////////////
buildsys: bzImage busybox uchaos install

# target: buildemu /////////////////////////////////////////////////////////////
buildemu:
	cd qemu && time -p sh make.sh sources

# target: uemutest //////////////////////////////////////////////////////////////
uemutest:
	rm -rf cpio.tmp/virt/ || true
	cp -arf cpio/* cpio.tmp/
	sh cpio.sh -c || exit 1
	cp -arf virt/ cpio.tmp/
	cd virt && KARGS="UCTEST=9" sh start.sh -uqm64

# target: uemurset //////////////////////////////////////////////////////////////
uemurset:
	rm -rf cpio.tmp/virt || true
	sh cpio.sh -c

# target: runqemu //////////////////////////////////////////////////////////////
runqemu:
	@echo Prepare and start the KVM 32MB machine
	cd virt; sh start.sh -q -m 32

