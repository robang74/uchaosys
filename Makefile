#
# (c) 2026, Roberto A. Foglietta <roberto.foglietta@gmail.com>, MIT license
#     Makefile created by converting make.lst shell script
#

# Settings /////////////////////////////////////////////////////////////////////
ARCH        ?= x86_64

NCPU        ?= $(shell nproc)
MUSLCFGMAK  := cnfg/musl-125x.config.mak
BBOXCFG     := $(shell ls -1 cnfg/busybox-*.config | tail -n1)

# Extract kernel version from config
KERNVER     := $(shell cut -d\# -f1 $(MUSLCFGMAK) | grep "LINUX_VER = [0-9]" |\
                 tail -n1 | tr -dc 0-9.)
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
KIMG        := $(KDIR)/bzImage
export PATH := $(CURDIR)/$(OUTPUT)/bin:$(CURDIR)/$(OUTPUT)/$(ARCH)/bin:$(PATH)

ARTIFACTS   := bbox/{busybox.elf,.config} cpio.cpio $(CPIOTMP)/ usrl/uchaosbox
ARTIFACTS   += miniz/amalgamation/ $(LNXPATH) kdev/uckaos kdev/$(KMOD){,.gz}
ARTIFACTS   += musl/sources/.done $(OUTPUT)/.done prnd/RNG_test gzcmd.gz.sh
ARTIFACTS   += virt/$(QBIN) virt/*.{bin,rom,done} qemu/output/
ARTIFACTS   += $(KDIR)/{.config,bzImage,System.map}

MAKELNX     := $(MAKE) $(OPTS) -j$(NCPU)

#QROMS       := bios-256k.bin efi-virtio.rom kvmvapic.bin linuxboot_dma.bin qboot.rom
#QROMS_PATH  := qemu/src/pc-bios

define print_size
	du -$(2)s $(1) | sed -e "s/^/size: /" -e "s/\t/ $(3) /"
endef

ENV_VARS    ?=

.PHONY: all sources buildall install

all: buildall install

# target: sources //////////////////////////////////////////////////////////////
.PHONY: update muslcfg defconfig

defconfig:
	@echo "START >>> "$@": "$<
	cp -arf cnfg/hashes/. musl/hashes/
	for a in musl/Makefile musl/litecross/Makefile; do \
		test -r $$a.bak || cp -af $$a $$a.bak; done ||:
	cp -af cnfg/Makefile.musl musl/Makefile
	cp -af cnfg/Makefile.lite musl/litecross/Makefile
	cp -af $(MUSLCFGMAK) musl/config.mak

musl/config.mak: defconfig

muslcfg: musl/config.mak

gzcmd.sh:
	@echo "START >>> "$@": "$<
#	curl -sL $(GZCMD_REPO)/$(GZCMD_PATH)/$@ -o $@
	wget $(GZCMD_REPO)/$(GZCMD_PATH)/$@ -qO $@
	sha1sum -c gzcmd.sh.sha1 || { rm -f $@; exit 1; }

gzcmd.gz.sh: gzcmd.sh
	@echo "START >>> "$@": "$<
	sh $< $< gzcmd

update:
	@echo "START >>> "$@": "$<
	@echo
	@echo "Wait updating project dependencies ..."
	git submodule update --init --recursive --depth 32 \
	  --single-branch --jobs $(NCPU)
	@echo

.sync: update
	@echo "START >>> "$@": "$<
	touch $@

sources: .sync gzcmd.gz.sh muslcfg
	@echo "START >>> "$@": "$<
	@echo
	@echo "Wait downloading sources ..."
	$(MAKELNX) -C musl extract_all
	@echo "Sources download completed successfully"
	@echo

# target: toolchain ////////////////////////////////////////////////////////////
.PHONY: toolchain

musl/sources/.done: sources
	@echo "START >>> "$@": "$<
	touch $@

$(OUTPUT)/.done:
	@echo "START >>> "$@": "$<
	$(MAKELNX) -C musl install
	touch $@

$(MUSLTGZ): $(OUTPUT)/.done
	@echo "START >>> "$@": "$<
	@echo
	@$(call print_size, $(OUTPUT)/,m,MB)
	rm -f $(MUSLTGZ) ; tar czf $@ $(OUTPUT)/
	@$(call print_size,$@,m,MB)
	@echo

# @echo "Sync and drop caches, ^C to skip root password"
# sync; echo 3 | sudo tee /proc/sys/vm/drop_caches | grep -q .
# muslcfg musl/sources/.done $(OUTPUT)/.done $(MUSLTGZ)
toolchain: musl/sources/.done $(OUTPUT)/.done $(MUSLTGZ)

# target: bzImage //////////////////////////////////////////////////////////////
.PHONY: bzImage

$(KDIR): musl/sources/.done
	@echo "START >>> "$@": "$<
	@test -r $@ || echo "Error do 'make sources' before, exit 1."
	@test -r $@ && $(call print_size,$@,k,KB)

$(KDIR)/.config: cnfg/linux-$(KVER_SHORT).config $(KDIR)
	@echo "START >>> "$@": "$<
	cp -alLf $< $@
	$(MAKELNX) -C $(KDIR) olddefconfig
	$(MAKELNX) -C $(KDIR) modules_prepare

$(KIMG): $(KDIR)/.config
	@echo "START >>> "$@": "$<
#	mkdir -p $(OUTPUT)/boot
#	rm -f $@ {$(KDIR),$(OUTPUT)/boot}/{System.map,bzImage}
	$(MAKELNX) -C $(KDIR) bzImage
#	cp -alLf $(KDIR)/System.map $(KIMGPATH) $(OUTPUT)/boot/
	cp -alLf $(KDIR)/arch/$(ARCH)/boot/bzImage $@
	@echo
	@strings $(KDIR)/vmlinux | grep -e "^Linux version" | tr , \\n
	@$(call print_size,$@,k,KB)
	@echo

bzImage: $(KDIR)/bzImage

# target: busybox //////////////////////////////////////////////////////////////
.PHONY: busybox

bbox/.config: $(BBOXCFG)
	@echo "START >>> "$@": "$<
	cp -alLf $(BBOXCFG) $@
	yes "" |  $(MAKE) $(OPTS) -j1 -C bbox oldconfig

bbox/busybox.elf: bbox/.config
	@echo "START >>> "$@": "$<
	rm -f $@
	$(MAKELNX) -C bbox busybox
	cp -alLf bbox/busybox $@
	@echo
	@file $@ | cut -d, -f1,2,4; $(call print_size,$@,k,KB)
	@echo

busybox: bbox/busybox.elf

# target: miniz ////////////////////////////////////////////////////////////////
.PHONY: miniz

minz/amalgamation/.done: cnfg/amalgamate.sh
	@echo "START >>> "$@": "$<
	cp -alLf cnfg/amalgamate.sh minz/
	cd minz && $(OPTS) sh -x amalgamate.sh
	touch $@

miniz: minz/amalgamation/.done

# target: uchaos ///////////////////////////////////////////////////////////////
.PHONY: uchaos

$(LNXPATH):
	@echo "START >>> "$@": "$<
	ln -sf ../$(KDIR) $@

$(KDIR)/System.map: $(KDIR)/bzImage

kdev/$(KMOD).gz: $(KDIR)/System.map | $(LNXPATH)
	@echo "START >>> "$@": "$<
	@echo
	$(MAKELNX) -C kdev dist
	@echo

usrl/uchaosbox:
	@echo "START >>> "$@": "$<
	@echo
	$(MAKELNX) -C usrl uchaosbox
	@echo

uchaos: miniz usrl/uchaosbox kdev/$(KMOD).gz
	@echo "START >>> "$@": "$<
	@echo
	@file kdev/$(KMOD).gz | cut -d, -f1,6-
	@file kdev/$(KMOD).gz | cut -d, -f2-4
	@strings kdev/$(KMOD) | grep -e "^version=" | tr '\n' ' '
	@$(call print_size,kdev/$(KMOD).gz,b,bytes)
	@echo

# target: rngtest //////////////////////////////////////////////////////////////
.PHONY: rngtest

prnd/RNG_test:
	@echo "START >>> "$@": "$<
	$(MAKELNX) CCSYSROOT="-static -mavx2" -C prnd RNG_test

rngtest: prnd/RNG_test
	@echo "START >>> "$@": "$<
	@echo
	@file $< | cut -d, -f1,2,4; $(call print_size,$<,k,KB)
	@echo

# target: install //////////////////////////////////////////////////////////////
.PHONY: install

$(CPIOTMP)/.done: kdev/$(KMOD).gz bbox/busybox.elf usrl/uchaosbox
	@echo "START >>> "$@": "$<
	cp -arf cpio/. $(CPIOTMP)/
	cd $(CPIOTMP) && mkdir -p tmp/ var/log/ lib/modules/ usr/bin/
	cp -alLf kdev/$(KMOD).gz $(CPIOTMP)/lib/modules/$(KMOD)
	cp -alLf bbox/busybox.elf $(CPIOTMP)/usr/bin/busybox
	cp -alLf usrl/uchaosbox $(CPIOTMP)/usr/bin/
	chmod +x $(CPIOTMP)/init
	# Symbolic links
	ln -sf bin $(CPIOTMP)/usr/sbin
	ln -sf bin/busybox $(CPIOTMP)/linuxrc
	ln -sf usr/sbin $(CPIOTMP)/sbin
	ln -sf usr/bin $(CPIOTMP)/bin
	ln -sf busybox $(CPIOTMP)/bin/sh
	touch $@

install: $(CPIOTMP)/.done $(KIMG) virt/$(QBIN)
	@echo "START >>> "$@": "$<
	cp -alLf $(KIMG) $(VDIR)/
	cd $(VDIR) && sh start.sh -U
	@cd $(VDIR) && du -k $(QBIN) | tr '\t' ' '
	@echo

# //////////////////////////////////////////////////////////////////////////////

.PHONY: clean veryclean distclean buildsys qemutest qemurset runqemu

# target: clean ////////////////////////////////////////////////////////////////
clean:
	@echo "START >>> "$@": "$<
	@echo "Removing artifacts and cleaning virt/ folder"
	rm -rf $(sort $(wildcard $(ARTIFACTS)))
	rm -f $(shell ls -1 virt/* | grep -v start.sh ||:)
	@echo "Removing custom configuration files and links"
# Protected by: test -r musl/config.mak
	rm -f musl/config.mak
	for a in musl/Makefile musl/litecross/Makefile; do \
		test -r $$a.bak && cp -f $$a.bak $$a; done ||:
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
	@echo "START >>> "$@": "$<
	@echo "Cleaning ..."
	echo gzcmd.sh minz/_build/ qemu/src/ | xargs -P0 -I {} rm -rf "{}"
	for dir in kdev usrl prnd $(LNXPATH); do $(MAKELNX) -C $$dir $@ ||:; done
# Call qemu/make.sh clean
	cd qemu && sh make.sh clean
# Call prnd/make veryclean
	for dir in musl bbox; do $(MAKELNX) -C $$dir clean ||:; done

# target: distclean ////////////////////////////////////////////////////////////
distclean: veryclean
	@echo "START >>> "$@": "$<
	@echo "Removing everything apart from the updated repo"
# Call qemu/make.sh veryclean
	cd qemu && sh make.sh veryclean
	for dir in musl bbox; do $(MAKELNX) -C $$dir $@ ||:; done
	rm -rf $(MUSLTGZ) $(sort $(wildcard $(OUTPUT))) musl/sources/

# target: buildsys /////////////////////////////////////////////////////////////
buildsys: bzImage busybox uchaos rngtest

# target: buildall /////////////////////////////////////////////////////////////
buildall: toolchain buildsys buildemu

# target: buildemu /////////////////////////////////////////////////////////////
.PHONY: buildemu

virt/.done:
	@echo "START >>> "$@": "$<
	cp -alLf qemu/output/* virt/

qemu/output:
	@echo "START >>> "$@": "$<
	cd qemu && $(OPTS) time -p sh make.sh sources

buildemu: $(KIMG) kdev/$(KMOD).gz qemu/output virt/.done

# target: qemutest //////////////////////////////////////////////////////////////
qemutest: buildemu
	@echo "START >>> "$@": "$<
	rm -rf $(CPIOTMP)/virt/
	cp -arf cpio/* $(CPIOTMP)/
	sh cpio.sh -c
	cp -arf virt/ $(CPIOTMP)/
	cd virt && $(ENV_VARS) KARGS="UCTEST=9" sh start.sh -uqm64 -M q35

# target: qemurset //////////////////////////////////////////////////////////////
qemurset:
	@echo "START >>> "$@": "$<
	rm -rf $(CPIOTMP)/virt $(CPIOTMP)/.done
	$(MAKELNX) install

# target: runqemu //////////////////////////////////////////////////////////////
runqemu: buildemu
	@echo "START >>> "$@": "$<
	@echo "Prepare and start the KVM 32MB machine"
	cd virt && $(ENV_VARS) sh start.sh -qm32 -M q35

