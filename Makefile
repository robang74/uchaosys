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
QBIN        := qemu-system-$(ARCH)
MUSLTGZ     := musl-output.tar.gz
LNXPATH     := kdev/linux-kernel
CCPREFIX    := $(ARCH)-linux-musl-
CPIOTMP     := cpio.tmp
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

ARTIFACTS   := bbox/busybox.elf gzcmd.gz.sh $(LNXPATH)
ARTIFACTS   += miniz/amalgamation/ kdev/uckaos cpio.cpio
ARTIFACTS   += musl/sources/.done $(OUTPUT)/.done minz/amalgamation/.done
ARTIFACTS   += $(CPIOTMP)/ virt/$(QBIN) virt/*.{bin,rom,done} qemu/output

#QROMS       := bios-256k.bin efi-virtio.rom kvmvapic.bin linuxboot_dma.bin qboot.rom
#QROMS_PATH  := qemu/src/pc-bios

ENV_VARS    ?=

.PHONY: all sources buildall install

all: sources buildall install

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
	@echo "Wait updating project dependencies ..."
	git submodule update --init --recursive --depth 32 \
	  --single-branch --jobs $(NCPU) && touch .sync
	@echo

.sync:
	$(MAKE) -j$(NCPU) update

sources: .sync gzcmd.gz.sh muslcfg
	@echo
	@echo "Wait downloading sources ..."
	$(MAKE) -j$(NCPU) -C musl extract_all
	@echo

# target: toolchain ////////////////////////////////////////////////////////////
.PHONY: toolchain

musl/sources/.done:
	$(MAKE) -j$(NCPU) sources
	touch $@

$(OUTPUT)/.done:
	$(MAKE) -j$(NCPU) -C musl install
	rm -f $(MUSLTGZ)
	touch $@

$(MUSLTGZ):
	@echo
	tar czf $(MUSLTGZ) $(OUTPUT)/
	@du -ms $(MUSLTGZ) $(OUTPUT)/  | sed -e "s/^/size: /" -e "s/\t/ MB /"
	@echo

# @echo "Sync and drop caches, ^C to skip root password"
# sync; echo 3 | sudo tee /proc/sys/vm/drop_caches | grep -q .
toolchain: muslcfg musl/sources/.done $(OUTPUT)/.done $(MUSLTGZ)

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
	$(MAKE) -j$(NCPU) $(OPTS) -C bbox oldconfig busybox
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
.PHONY: rngtest

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

$(CPIOTMP)/.done:
	@echo
	cp -arf cpio/. $(CPIOTMP)/
	cd $(CPIOTMP) && mkdir -p tmp/ var/log/ lib/modules/ usr/bin/
	cp -Lf kdev/$(KMOD).gz $(CPIOTMP)/lib/modules/$(KMOD)
	cp -Lf bbox/busybox.elf $(CPIOTMP)/usr/bin/busybox
	cp -Lf usrl/uchaosbox $(CPIOTMP)/usr/bin/
	chmod +x $(CPIOTMP)/init
	# Symbolic links
	ln -sf bin $(CPIOTMP)/usr/sbin
	ln -sf bin/busybox $(CPIOTMP)/linuxrc
	ln -sf usr/sbin $(CPIOTMP)/sbin
	ln -sf usr/bin $(CPIOTMP)/bin
	ln -sf busybox $(CPIOTMP)/bin/sh
#	touch $@

install: buildemu $(CPIOTMP)/.done
	@echo
	cp -Lf $(KIMG) $(VDIR)/
	cd $(VDIR) && sh start.sh -U
	@cd $(VDIR) && du -k $(QBIN) | sed -e "s/\t/ /"
	@echo

# //////////////////////////////////////////////////////////////////////////////

.PHONY: clean veryclean distclean buildsys uemutest uemurset runqemu

# target: clean ////////////////////////////////////////////////////////////////
clean:
	@echo "Removing artifacts and cleaning virt/ folder"
	rm -rf $(sort $(wildcard $(ARTIFACTS)))
	rm -f $(shell ls -1 virt/* | grep -v start.sh ||:)
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

# target: veryclean ////////////////////////////////////////////////////////////
# This removes files that the script normally protects with 'test' or 'if' logic
veryclean: clean
	@echo "Cleaning ..."
	echo gzcmd.sh minz/_build/ qemu/src/ | xargs -P0 -I {} rm -rf "{}"
	for dir in musl bbox kdev usrl prnd $(LNXPATH); do  \
		$(MAKE) -j$(NCPU) ARCH=$(ARCH) -C $$dir $@ ||:; done
# Call qemu/make.sh clean
	cd qemu && sh make.sh clean
# Call prnd/make veryclean
	for dir in musl bbox; do $(MAKE) -j$(NCPU) ARCH=$(ARCH) -C $$dir $@ ||:; done

# target: distclean ////////////////////////////////////////////////////////////
distclean: veryclean
	@echo "Removing everything apart from the updated repo"
# Call qemu/make.sh veryclean
	cd qemu && sh make.sh veryclean
	for dir in musl bbox; do $(MAKE) -j$(NCPU) ARCH=$(ARCH) -C $$dir $@ ||:; done
	rm -rf $(MUSLTGZ) $(sort $(wildcard $(OUTPUT))) musl/sources/

# target: buildsys /////////////////////////////////////////////////////////////
buildsys: bzImage busybox uchaos rngtest

# target: buildall /////////////////////////////////////////////////////////////
buildall: toolchain buildsys buildemu

# target: buildemu /////////////////////////////////////////////////////////////
.PHONY: buildemu

virt/.done:
	cp -Lf qemu/output/* virt/

qemu/output:
	cd qemu && time -p sh make.sh sources

buildemu: $(KIMG) kdev/$(KMOD).gz qemu/output virt/.done

# target: uemutest //////////////////////////////////////////////////////////////
uemutest: buildemu
	rm -rf $(CPIOTMP)/virt/
	cp -arf cpio/* $(CPIOTMP)/
	sh cpio.sh -c
	cp -arf virt/ $(CPIOTMP)/
	cd virt && $(ENV_VARS) KARGS="UCTEST=9" sh start.sh -uqm64 -M q35

# target: uemurset //////////////////////////////////////////////////////////////
uemurset:
	rm -rf $(CPIOTMP)/virt $(CPIOTMP)/.done
	$(MAKE) -j$(NCPU) install

# target: runqemu //////////////////////////////////////////////////////////////
runqemu: buildemu
	@echo Prepare and start the KVM 32MB machine
	cd virt && $(ENV_VARS) sh start.sh -qm32 -M q35

