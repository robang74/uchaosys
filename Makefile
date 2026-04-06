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

.PHONY: all sources toolchain bzImage busybox uchaos rngtest buildemu install

all: sources toolchain bzImage busybox uchaos rngtest buildemu install

# target: sources //////////////////////////////////////////////////////////////

.PHONY: update muslcfg muslcfg-force

muslcfg-force:
	cp -arf cnfg/hashes musl/
	cp -f musl/Makefile musl/Makefile.bak
	cp -f cnfg/Makefile.musl musl/Makefile
	cp -f cnfg/Makefile.lite musl/litecross/Makefile
	cp -f $(MUSLCFGMAK) musl/config.mak

musl/config.mak:
	$(MAKE) -j$(NCPU) muslcfg-force

muslcfg: musl/config.mak

gzcmd.sh:
	curl -sL $(GZCMD_REPO)/$(GZCMD_PATH)/gzcmd.sh -o gzcmd.sh

gzcmd.gz.sh: gzcmd.sh
	sh gzcmd.sh gzcmd.sh gzcmd

update:
	@echo Wait updating project dependencies ...
	git submodule update --init --recursive --depth 32 --single-branch --jobs $(NCPU)
	@echo

sources: update gzcmd.gz.sh muslcfg
	@echo Wait downloading sources ...
	$(MAKE) -j$(NCPU) -C musl extract_all
	@echo

# target: toolchain ////////////////////////////////////////////////////////////

musl/sources/.done:
	make -j$(NCPU) sources
	touch $@

musl/output/.done:
	make -j$(NCPU) -C musl install
	touch $@

musl-output.tar.gz:
	@echo
	tar czf musl-output.tar.gz musl/output/
	du -ms musl-output.tar.gz musl/output/
	@echo

# @echo "Sync and drop caches, ^C to skip root password"
# sync; echo 3 | sudo tee /proc/sys/vm/drop_caches | grep -q .
toolchain: muslcfg musl/sources/.done musl/output/.done musl-output.tar.gz

# target: bzImage //////////////////////////////////////////////////////////////

$(LNXPATH):
	ln -sf ../$(KDIR) $(LNXPATH)

$(LNXPATH)/.config: $(LNXPATH)
	cp -f cnfg/linux-$(KVER_SHORT).config $(KDIR)/.config

$(KIMG): $(LNXPATH)/.config
	$(MAKE) -j$(NCPU) $(OPTS) -C $(LNXPATH) syncconfig modules_prepare bzImage modules
	@echo
	@strings $(KDIR)/vmlinux | grep -e "^Linux version" | tr , \\n
	du -Lk  $(KIMG)
	@echo

bzImage: $(KIMG)

# target: busybox //////////////////////////////////////////////////////////////

bbox/.config:
	cp $(BBOX_CFG) bbox/.config

bbox/busybox: bbox/.config
	$(MAKE) -j$(NCPU) $(OPTS) -C bbox oldconfig
	$(MAKE) -j$(NCPU) $(OPTS) -C bbox busybox
	@echo
	file bbox/busybox
	du -k bbox/busybox
	@echo

busybox: bbox/busybox

# target: miniz ////////////////////////////////////////////////////////////////

.PHONY: miniz

minz/amalgamate/.done:
	cd minz && sh amalgamate.sh
	touch $@

miniz: minz/amalgamate/.done

# target: uchaos ///////////////////////////////////////////////////////////////

kdev/$(KDIR):
	ln -sf $(KDIR)/ kdev/

kdev/$(KMOD).gz: kdev/$(KDIR)
	$(MAKE) -j$(NCPU) -C kdev $(OPTS) dist

usrl/uchaosbox:
	$(MAKE) -j$(NCPU) -C usrl $(OPTS) uchaosbox

uchaos: miniz kdev/$(KMOD).gz usrl/uchaosbox
	@echo
	file kdev/$(KMOD).gz | sed -e s/\",/\"\\n/ -e s/n,/n\\n/
	du -k kdev/$(KMOD).gz
	@echo

# target: rngtest //////////////////////////////////////////////////////////////

prnd/RNG_test:
	$(MAKE) -j$(NCPU) $(OPTS) -C prnd/ RNG_test \
	  CCSYSROOT="-static -mavx2" CCPREFIX=$(CCPREFIX)

rngtest:
	@echo
	file prnd/RNG_test
	du -k prnd/RNG_test
	@echo

# target: install //////////////////////////////////////////////////////////////

$(TMPD)/.done:
	cp -arf cpio/ $(TMPD)/
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
	touch $@

install: $(TMPD)
	@echo
	cd $(VDIR) && sh start.sh -U
	@echo

# //////////////////////////////////////////////////////////////////////////////

.PHONY: clean veryclean distclean buildall buildsys buildemu uemutest uemurset runqemu

# target: clean ////////////////////////////////////////////////////////////////
clean:
	@echo "Cleaning ..."
	rm -rf gzcmd.sh cpio.cpio $(TMPD) minz/_build
	for dir in musl bbox kdev usrl prnd $(LNXPATH); do  \
		$(MAKE) -j$(NCPU) ARCH=$(ARCH) -C $$dir clean ||:; \
	done

# target: veryclean ////////////////////////////////////////////////////////////
# This removes files that the script normally protects with 'test' or 'if' logic
veryclean: clean
	@echo "Removing custom configuration files and links"
# Remove musl output
	rm -fr musl/output
# Protected by: test -r musl/config.mak
	rm -f musl/config.mak
	cp -f musl/Makefile.bak musl/Makefile
# Protected by: test -e $lnxpath
	rm -f $(LNXPATH)
# Protected by: test -r $lnxpath/.config
	rm -f $(KDIR)/.config
# Protected by: test -r bbox/.config
	rm -f bbox/.config
# Additional cleanup for symlinks created in kdev
	rm -f kdev/linux-kernel
# Remove all the hashes added, as well
	rm -f musl/$(shell cd cnfg && command ls -1 hashes/* ||:)
# Call qemu/make.sh clean
	cd qemu && sh make.sh clean

# target: distclean ////////////////////////////////////////////////////////////
distclean: veryclean
	@echo "Removing everything apart from the updated repo"
	rm -fr musl/sources musl-output.tar.gz miniz/amalgamation
	rm -f $(shell command ls -1 virt/* | command grep -v start.sh ||:)
# Call qemu/make.sh veryclean
	cd qemu && sh make.sh veryclean
	for dir in musl bbox; do  \
		$(MAKE) -j$(NCPU) ARCH=$(ARCH) -C $$dir distclean ||:; \
	done

# target: buildall /////////////////////////////////////////////////////////////
buildall: toolchain bzImage busybox uchaos install

# target: buildsys /////////////////////////////////////////////////////////////
buildsys: bzImage busybox uchaos install

# target: buildemu /////////////////////////////////////////////////////////////
qemu/qemu-system-x86_64:
	cd qemu && time -p sh make.sh sources

buildemu: qemu/qemu-system-x86_64

# target: uemutest //////////////////////////////////////////////////////////////
uemutest: buildemu
	rm -rf cpio.tmp/virt/
	cp -arf cpio/* cpio.tmp/
	sh cpio.sh -c
	cp -arf virt/ cpio.tmp/
	cd virt && KARGS="UCTEST=9" sh start.sh -uqm64

# target: uemurset //////////////////////////////////////////////////////////////
uemurset:
	rm -rf cpio.tmp/virt
	sh cpio.sh -c

# target: runqemu //////////////////////////////////////////////////////////////
runqemu: buildemu
	@echo Prepare and start the KVM 32MB machine
	cd virt && sh start.sh -qm32

