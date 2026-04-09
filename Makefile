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
KDIR        := musl/linux-$(KERNVER)
KIMGPATH    := $(KDIR)/arch/$(ARCH)/boot/bzImage
LNXPATH     := kdev/linux-kernel
CCPREFIX    := $(ARCH)-linux-musl-
TMPD        := cpio.tmp
KMOD        := uchaos_dev.ko

# Tools and Options
HOSTCC      := gcc
CC          := $(CCPREFIX)gcc
OPTS        := HOSTCC=$(HOSTCC) ARCH=$(ARCH) CROSS_COMPILE=$(CCPREFIX) CCPREFIX=$(CCPREFIX)
OPTS        += CFLAGS_EXTRA="-falign-functions=32" KERNVER=$(KERNVER)
GZCMD_REPO  := https://raw.githubusercontent.com/robang74/bare-minimal-linux-system/
GZCMD_PATH  := refs/heads/main

OUTPUT      ?= musl/output
KIMG        := $(OUTPUT)/bzImage
export PATH := $(CURDIR)/$(OUTPUT)/bin:$(CURDIR)/$(OUTPUT)/$(ARCH)/bin:$(PATH)

ARTIFACTS   := bbox/busybox.elf musl-output.tar.gz gzcmd.gz.sh $(LNXPATH)
ARTIFACTS   += musl/sources/ musl/output/ miniz/amalgamation/ kdev/uckaos

ENV_VARS    ?=

.PHONY: all sources buildall rngtest buildemu

all: sources buildall rngtest buildemu

# target: sources //////////////////////////////////////////////////////////////
.PHONY: update muslcfg muslcfg-force

muslcfg-force:
	cp -arf cnfg/hashes musl/
	for a in musl/Makefile musl/litecross/Makefile; \
	  do test -r $$a.bak || cp -f $$a $$a.bak; done
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
	@echo
	@echo Wait updating project dependencies ...
	git submodule update --init --recursive --depth 32 --single-branch --jobs $(NCPU)
	@echo

sources: update gzcmd.gz.sh muslcfg
	@echo
	@echo Wait downloading sources ...
	$(MAKE) -j$(NCPU) -C musl extract_all
	@echo

# target: toolchain ////////////////////////////////////////////////////////////
.PHONY: toolchain

musl/sources/.done:
	make -j$(NCPU) sources
	touch $@

musl/output/.done:
	make -j$(NCPU) -C musl install
	rm -f musl-output.tar.gz
	touch $@

musl-output.tar.gz:
	@echo
	tar czf musl-output.tar.gz musl/output/
	@du -ms musl-output.tar.gz musl/output/  | sed -e "s/^/size: /" -e "s/\t/ MB /"
	@echo

# @echo "Sync and drop caches, ^C to skip root password"
# sync; echo 3 | sudo tee /proc/sys/vm/drop_caches | grep -q .
toolchain: muslcfg musl/sources/.done musl/output/.done musl-output.tar.gz

# target: bzImage //////////////////////////////////////////////////////////////
.PHONY: bzImage

$(KDIR):
	@test -r $(KIMG) || { echo "Error do 'make sources' before, exit 1."; exit 1; }
	@test -r $(KIMG) && { du -k $(KIMG) | sed -e "s/^/size: /" -e "s/\t/ KB /"; exit 1; }

$(LNXPATH): $(KDIR)
	ln -sf ../$(KDIR) $(LNXPATH)

$(LNXPATH)/.config: | $(LNXPATH)
	cp -Lf cnfg/linux-$(KVER_SHORT).config $(LNXPATH)/.config

$(KIMG): | $(LNXPATH)/.config
	rm -f $(KIMG) $(LNXPATH)/System.map
	yes "" | $(MAKE)  -C $(LNXPATH) syncconfig
	$(MAKE) -j$(NCPU) -C $(LNXPATH) modules_prepare
	$(MAKE) -j$(NCPU) $(OPTS) -C $(LNXPATH) bzImage
	cp -Lf $(KDIR)/System.map $(OUTPUT)
	cp -Lf $(KIMGPATH) $(KIMG)
	@echo
	@strings $(KDIR)/vmlinux | grep -e "^Linux version" | tr , \\n
	@du -k $(KIMG) | sed -e "s/^/size: /" -e "s/\t/ KB /"
	@echo

bzImage: $(KIMG)

# target: busybox //////////////////////////////////////////////////////////////
.PHONY: busybox

bbox/.config:
	cp $(BBOX_CFG) bbox/.config

bbox/busybox.elf: bbox/.config
	@rm -f $@
	$(MAKE) -j$(NCPU) $(OPTS) -C bbox oldconfig
	$(MAKE) -j$(NCPU) $(OPTS) -C bbox busybox
	@ln -f bbox/busybox $@
	@echo
	@file $@; du -k $@ | sed -e "s/^/size: /" -e "s/\t/ KB /"
	@echo

busybox: bbox/busybox.elf

# target: miniz ////////////////////////////////////////////////////////////////
.PHONY: miniz

minz/amalgamation/.done:
	cd minz && sh amalgamate.sh
	touch $@

miniz: minz/amalgamation/.done

# target: uchaos ///////////////////////////////////////////////////////////////
.PHONY: uchaos

$(KDIR)/System.map:
	cp -Lf $(OUTPUT)/System.map $(KDIR)/System.map || { \
	  echo "ERROR: try 'make bzImage' before this"; exit 1; }

kdev/$(KMOD).gz: | $(KDIR)/System.map
	@echo
	$(MAKE) -j$(NCPU) -C kdev $(OPTS) dist
	@echo

usrl/uchaosbox:
	@echo
	$(MAKE) -j$(NCPU) -C usrl $(OPTS) uchaosbox
	@echo

uchaos: miniz usrl/uchaosbox kdev/$(KMOD).gz
	@echo
	@file kdev/$(KMOD).gz | sed -e "s/\",/\"\\n/" -e "s/n,/n\\n/"
	@zcat kdev/uchaos_dev.ko.gz | strings | grep -e "^version=" | tr '\n' ' '
	@du -b kdev/$(KMOD).gz | sed -e "s/^/size: /" -e "s/\t/ bytes /"
	@echo

# target: rngtest //////////////////////////////////////////////////////////////

prnd/RNG_test:
	$(MAKE) -j$(NCPU) $(OPTS) -C prnd/ RNG_test \
	  CCSYSROOT="-static -mavx2" CCPREFIX=$(CCPREFIX)

rngtest: prnd/RNG_test
	@echo
	@file prnd/RNG_test #| sed -e "s/V),/V)\\n/" -e "s/n,/n\\n/"
	@du -k prnd/RNG_test | sed -e "s/^/size: /" -e "s/\t/ KB /"
	@echo

# target: install //////////////////////////////////////////////////////////////
.PHONY: install

$(TMPD)/.done:
	@echo
	cp -arf cpio/. $(TMPD)/
	mkdir -p $(TMPD)/tmp/ $(TMPD)/var/log/ $(TMPD)/lib/modules/ $(TMPD)/usr/bin/
	cp -Lf kdev/$(KMOD).gz $(TMPD)/lib/modules/$(KMOD)
	cp -Lf bbox/busybox.elf $(TMPD)/usr/bin/busybox
	cp -Lf usrl/uchaosbox $(TMPD)/usr/bin/
	chmod +x $(TMPD)/init
	# Symbolic links
	ln -sf bin $(TMPD)/usr/sbin
	ln -sf bin/busybox $(TMPD)/linuxrc
	ln -sf usr/sbin $(TMPD)/sbin
	ln -sf usr/bin $(TMPD)/bin
	ln -sf busybox $(TMPD)/bin/sh
#	touch $@

install: $(TMPD)/.done
	@echo
	cp -Lf $(KIMG) $(VDIR)/
	cd $(VDIR) && sh start.sh -U
	@cd $(VDIR) && du -k qemu-system-$(ARCH) | sed -e "s/\t/ /"
	@echo

# //////////////////////////////////////////////////////////////////////////////

.PHONY: clean veryclean distclean buildsys uemutest uemurset runqemu

# target: clean ////////////////////////////////////////////////////////////////
clean:
	@echo "Cleaning ..."
	echo gzcmd.sh cpio.cpio $(TMPD)/ minz/_build/ qemu/src/ | xargs -P0 -I {} rm -rf "{}"
	for dir in musl bbox kdev usrl prnd $(LNXPATH); do  \
		$(MAKE) -j$(NCPU) ARCH=$(ARCH) -C $$dir $@ ||:; \
	done

# target: veryclean ////////////////////////////////////////////////////////////
# This removes files that the script normally protects with 'test' or 'if' logic
veryclean: clean
	@echo "Removing custom configuration files and links"
# Protected by: test -r musl/config.mak
	rm -f musl/config.mak
	for a in musl/Makefile musl/litecross/Makefile; do cp -f $$a.bak $$a; done
# Protected by: test -e $lnxpath
	rm -f $(LNXPATH)
# Protected by: test -r $lnxpath/.config
	rm -f $(KDIR)/.config
# Protected by: test -r bbox/.config
	rm -f bbox/.config
# Remove all the hashes added, as well
	rm -f musl/$(shell cd cnfg && command ls -1 hashes/* ||:)
# Call qemu/make.sh clean
	cd qemu && sh make.sh clean
# Call prnd/make veryclean
	for dir in musl bbox; do $(MAKE) -j$(NCPU) ARCH=$(ARCH) -C $$dir $@ ||:; done

# target: distclean ////////////////////////////////////////////////////////////
distclean: veryclean
	@echo "Removing everything apart from the updated repo"
	echo $(ARTIFACTS) | xargs -P0 -I {} rm -rf "{}"
	rm -f $(shell ls -1 virt/* | grep -v start.sh ||:)
# Call qemu/make.sh veryclean
	cd qemu && sh make.sh veryclean
	for dir in musl bbox; do $(MAKE) -j$(NCPU) ARCH=$(ARCH) -C $$dir $@ ||:; done

# target: buildsys /////////////////////////////////////////////////////////////
buildsys: bzImage busybox uchaos install

# target: buildall /////////////////////////////////////////////////////////////
buildall: toolchain buildsys

# target: buildemu /////////////////////////////////////////////////////////////
qemu/qemu-system-$(ARCH):
	cd qemu && time -p sh make.sh sources

buildemu: $(KIMG) kdev/$(KMOD).gz qemu/qemu-system-$(ARCH)

# target: uemutest //////////////////////////////////////////////////////////////
uemutest: buildemu
	rm -rf cpio.tmp/virt/
	cp -arf cpio/* cpio.tmp/
	sh cpio.sh -c
	cp -arf virt/ cpio.tmp/
	cd virt && $(ENV_VARS) KARGS="UCTEST=9" sh start.sh -uqm64 -M q35

# target: uemurset //////////////////////////////////////////////////////////////
uemurset:
	rm -rf cpio.tmp/virt
	sh cpio.sh -c

# target: runqemu //////////////////////////////////////////////////////////////
runqemu: buildemu
	@echo Prepare and start the KVM 32MB machine
	cd virt && $(ENV_VARS) sh start.sh -qm32 -M q35

