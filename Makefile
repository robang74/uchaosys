#
# (c) 2026, Roberto A. Foglietta <roberto.foglietta@gmail.com>, MIT license
#     Makefile created by converting make.lst shell script
#

# Settings /////////////////////////////////////////////////////////////////////
ARCH        ?= x86_64
ENV_VARS    ?=
NCPU        ?= $(shell nproc)
MUSLCFGMAK  := cnfg/musl-125x.config.mak
BBOXCFG     := $(shell ls -1 cnfg/busybox-*.config | tail -n1)

# Extract kernel version from config
KERNVER     := $(shell cut -d\# -f1 $(MUSLCFGMAK) | grep "LINUX_VER = [0-9]" |\
                 tail -n1 | tr -dc 0-9.)
KVER_SHORT  := $(shell echo $(KERNVER) | tr -dc 0-9 | head -c3)x
KERNCFG     := cnfg/linux-$(KVER_SHORT).config

# Paths
VDIR        := virt
SDIR        := musl/sources
KDIR        := musl/linux-$(KERNVER)
QBIN        := qemu-system-$(ARCH)
MUSLTGZ     := musl-output.tar.gz
LNXPATH     := kdev/linux-kernel
CCPREFIX    := $(ARCH)-linux-musl-
CPIOTMP     := cpio.tmp
KMOD        := uchaos_dev.ko

# Tools and Options
HOSTCC      := gcc
CC          := $(CCPREFIX)gcc
EXTRA_CFLAGS += -falign-functions=32
OPTS        := ARCH=$(ARCH) CROSS_COMPILE=$(CCPREFIX) CCPREFIX=$(CCPREFIX)
OPTS        += EXTRA_CFLAGS="$(EXTRA_CFLAGS)" KERNVER=$(KERNVER)
GZCMD_REPO  := https://raw.githubusercontent.com/robang74/bare-minimal-linux-system/
GZCMD_PATH  := refs/heads/main

OUTPUT      ?= musl/output
KIMG        := $(KDIR)/bzImage
export PATH := $(CURDIR)/$(OUTPUT)/bin:$(CURDIR)/$(OUTPUT)/$(ARCH)/bin:$(PATH)

KDIR_FILES  := $(addprefix $(KDIR)/, .config vmlinux bzImage System.map)
VIRT_FILES  := $(addprefix virt/, *.bin *.rom .done $(QBIN))
CONF_FILES  := $(addsuffix /.conf, bbox musl $(KDIR))

ARTIFACTS   := bbox/busybox.elf bbox/.config cpio.cpio $(CPIOTMP)/ usrl/uchaosbox
ARTIFACTS   += $(KDIR_FILES) $(CONF_FILES) $(SDIR)/.done $(OUTPUT)/.done $(KIMG)
ARTIFACTS   += minz/amalgamation/ $(LNXPATH) kdev/uckaos kdev/$(KMOD)*
ARTIFACTS   += prnd/RNG_test gzcmd.gz.sh $(VIRT_FILES) qemu/output/

MAKELNX     := $(MAKE) $(OPTS) -j$(NCPU)
MAKELOG     := make.log

#QROMS      := bios-256k.bin efi-virtio.rom kvmvapic.bin linuxboot_dma.bin qboot.rom
#QROMS_PATH := qemu/src/pc-bios

define print_size
	du -$(2)s $(1) | sed -e "s/^/size: /" -e "s/\t/ $(3) /"
endef

.PHONY: all update sources buildall install

all:
	rm -f $(MAKELOG)
	for tg in update sources buildall install; do $(MAKELNX) $$tg; done
	@echo "STOP >>> "$@": "$^ | tee -a $(MAKELOG)

# target: sources //////////////////////////////////////////////////////////////
.PHONY: update defconfig patches

MUSL_DPNDS := $(wildcard cnfg/Makefile.*)
MUSL_DPNDS += $(wildcard cnfg/hashes/*.sha1)
MUSL_DPNDS += $(MUSLCFGMAK) bbox/.config $(KDIR)/.config

PATCH_NAME := printk-early-boot-timestamps-hack-v5
PATCH_NAME += bothering-warn_unseeded_randomness-fix
PATHC_KDIR := musl/patches/linux-$(KERNVER)

patches: .sync
	mkdir -p $(PATHC_KDIR) && for fp in $(PATCH_NAME); do \
	  cp -alLf cnfg/$$fp.patch $(PATHC_KDIR)/0001-$$fp.diff; done

musl/.conf: patches $(MUSL_DPNDS)
	@echo "START >>> "$@": "$^ | tee -a $(MAKELOG)
	cp -arf cnfg/hashes/*.sha1 musl/hashes/
	cp -alLf cnfg/Makefile.musl musl/Makefile
	cp -alLf cnfg/Makefile.lite musl/litecross/Makefile
	cp -alLf $(MUSLCFGMAK) musl/config.mak
	touch $@

defconfig:
	rm -f musl/.conf && $(MAKELNX) musl/.conf

gzcmd.sh:
	@echo "START >>> "$@": "$^ | tee -a $(MAKELOG)
#	curl -sL $(GZCMD_REPO)/$(GZCMD_PATH)/$@ -o $@
	wget $(GZCMD_REPO)/$(GZCMD_PATH)/$@ -qO $@
	sha1sum -c gzcmd.sh.sha1 || { rm -f $@; exit 1; }
	touch $@

gzcmd.gz.sh: gzcmd.sh
	@echo "START >>> "$@": "$^ | tee -a $(MAKELOG)
	sh $< $< gzcmd
	touch $@

.sync: .gitmodules
	@echo "START >>> "$@": "$^ | tee -a $(MAKELOG)
	@echo
	@echo "Wait updating project dependencies ..."
	git submodule update --init --recursive --depth 32 \
	  --single-branch --jobs $(NCPU)
	@echo
	touch $@

update: .sync

$(SDIR)/.done: musl/.conf | gzcmd.gz.sh
	@echo "START >>> "$@": "$^ | tee -a $(MAKELOG)
	@echo
	@echo "Wait downloading sources ..."
	$(MAKELNX) HOSTCC=$(HOSTCC) -C musl extract_all
	@echo "Sources download completed successfully"
	@echo
	touch $@

sources: $(SDIR)/.done

# target: toolchain ////////////////////////////////////////////////////////////
.PHONY: toolchain

$(OUTPUT)/.done:
	@echo "START >>> "$@": "$^ | tee -a $(MAKELOG)
	$(MAKELNX) HOSTCC=$(HOSTCC) -C musl install
	touch $@

$(MUSLTGZ): $(OUTPUT)/.done
	@echo "START >>> "$@": "$^ | tee -a $(MAKELOG)
	rm -f $(MUSLTGZ) ; tar czf $@ $(OUTPUT)/
	@echo
	@$(call print_size, $(OUTPUT)/,m,MB)
	@$(call print_size,$@,m,MB)
	@echo

# @echo "Sync and drop caches, ^C to skip root password"
# sync; echo 3 | sudo tee /proc/sys/vm/drop_caches | grep -q .
# muslcfg $(SDIR)/.done $(OUTPUT)/.done $(MUSLTGZ)
toolchain: $(SDIR)/.done $(OUTPUT)/.done $(MUSLTGZ)

# target: bzImage //////////////////////////////////////////////////////////////
.PHONY: bzImage

$(KDIR): $(SDIR)/.done
	@echo "START >>> "$@": "$^ | tee -a $(MAKELOG)
	@test -r $@ || echo "Error do 'make sources' before, exit 1."
	@test -r $@ && $(call print_size,$@,k,KB)

$(KDIR)/.config: $(KERNCFG)
	cp -alLf $(KERNCFG) $(KDIR)/.config ||:

$(KDIR)/.conf: | $(KDIR)/.config
	@echo "START >>> "$@": "$^ | tee -a $(MAKELOG)
	$(MAKELNX) -C $(KDIR) olddefconfig
	touch $@

$(KIMG): patches $(KDIR)/.conf
	@echo "START >>> "$@": "$^ | tee -a $(MAKELOG)
	$(MAKELNX) -C $(KDIR) all
	cp -alLf $(KDIR)/arch/$(ARCH)/boot/bzImage $@
	@echo
	@strings $(KDIR)/vmlinux | grep -e "^Linux version" | tr , \\n
	@$(call print_size,$@,k,KB)
	@echo
	touch $@

bzImage: $(KIMG)

# target: busybox //////////////////////////////////////////////////////////////
.PHONY: busybox

bbox/.config: $(BBOXCFG)
	cp -alLf $(BBOXCFG) bbox/.config ||:

bbox/.conf: | bbox/.config
	@echo "START >>> "$@": "$^ | tee -a $(MAKELOG)
	yes "" |  $(MAKE) $(OPTS) -j1 -C bbox oldconfig
	touch $@

bbox/busybox.elf: | bbox/.conf
	@echo "START >>> "$@": "$^ | tee -a $(MAKELOG)
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
	@echo "START >>> "$@": "$^ | tee -a $(MAKELOG)
	cp -alLf cnfg/amalgamate.sh minz/
	cd minz && $(OPTS) sh -x amalgamate.sh
	touch $@

miniz: minz/amalgamation/.done

# target: uchaos ///////////////////////////////////////////////////////////////
.PHONY: uchaos

$(LNXPATH):
	@echo "START >>> "$@": "$^ | tee -a $(MAKELOG)
	ln -sf ../$(KDIR) $@

$(KDIR)/System.map: $(KIMG)

kdev/$(KMOD).gz: | $(LNXPATH) $(KDIR)/System.map
	@echo "START >>> "$@": "$^ | tee -a $(MAKELOG)
	$(MAKELNX) -C kdev dist
	@echo
	touch $@

usrl/uchaosbox:
	@echo "START >>> "$@": "$^ | tee -a $(MAKELOG)
	$(MAKELNX) -C usrl uchaosbox
	@echo

uchaos: miniz usrl/uchaosbox kdev/$(KMOD).gz
	@echo "START >>> "$@": "$^ | tee -a $(MAKELOG)
	@file kdev/$(KMOD).gz | cut -d, -f1,6-
	@file kdev/$(KMOD).gz | cut -d, -f2-4
	@strings kdev/$(KMOD) | grep -e "^version=" | tr '\n' ' '
	@$(call print_size,kdev/$(KMOD).gz,b,bytes)
	@echo

# target: rngtest //////////////////////////////////////////////////////////////
.PHONY: rngtest

prnd/RNG_test:
	@echo "START >>> "$@": "$^ | tee -a $(MAKELOG)
	$(MAKELNX) CCSYSROOT="-static -mavx2" -C prnd RNG_test

rngtest: prnd/RNG_test
	@echo "START >>> "$@": "$^ | tee -a $(MAKELOG)
	@file $< | cut -d, -f1,2,4; $(call print_size,$<,k,KB)
	@echo

# target: install //////////////////////////////////////////////////////////////
.PHONY: install

$(CPIOTMP)/.done: kdev/$(KMOD).gz bbox/busybox.elf usrl/uchaosbox
	@echo "START >>> "$@": "$^ | tee -a $(MAKELOG)
	mkdir -p $(CPIOTMP)/
	cp -arf cpio/* $(CPIOTMP)/
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

install: $(KIMG) $(CPIOTMP)/.done qemu/output/.done
	@echo "START >>> "$@": "$^ | tee -a $(MAKELOG)
	cp -alLf $(KIMG) $(VDIR)/
	cd $(VDIR) && sh start.sh -U
	@cd $(VDIR) && du -k $(QBIN) | tr '\t' ' '
	@echo

glib:
	@echo "START >>> "$@": "$^ | tee -a $(MAKELOG)
	$(MAKELNX) -C musl $@

# //////////////////////////////////////////////////////////////////////////////

.PHONY: clean veryclean distclean buildsys qemutest qemurset runqemu

# target: clean ////////////////////////////////////////////////////////////////
clean:
	@echo "START >>> "$@": "$^ | tee -a $(MAKELOG)
	@echo "Removing artifacts and cleaning virt/ folder"
	rm -rf $(ARTIFACTS)
	rm -f $(shell ls -1d virt/* | grep -v start.sh ||:)
	@echo "Removing custom configuration files and links"
# Protected by: test -r musl/config.mak
	rm -f musl/{config.mak,.conf}
# Protected by: test -e $lnxpath
	rm -f $(LNXPATH)
# Protected by: test -r $lnxpath/.config
	rm -f $(KDIR)/{.config,.conf}
# Protected by: test -r bbox/.config
	rm -f bbox/.config
# Remove all the hashes added, as well
	rm -f musl/$(shell cd cnfg && command ls -1 hashes/* ||:)

# target: veryclean ////////////////////////////////////////////////////////////
# This removes files that the script normally protects with 'test' or 'if' logic
veryclean: clean
	@echo "START >>> "$@": "$^ | tee -a $(MAKELOG)
	@echo "Cleaning ..."
	echo gzcmd.sh minz/_build/ qemu/src/ | xargs -P0 -I {} rm -rf "{}"
	for dir in kdev usrl prnd $(LNXPATH); do $(MAKELNX) -C $$dir $@ ||:; done
# Call qemu/make.sh clean
	cd qemu && sh make.sh clean
# Call prnd/make veryclean
	for dir in musl bbox; do $(MAKELNX) -C $$dir clean ||:; done

# target: distclean ////////////////////////////////////////////////////////////
distclean: veryclean
	@echo "START >>> "$@": "$^ | tee -a $(MAKELOG)
	@echo "Removing everything apart from the updated repo"
# Call qemu/make.sh veryclean
	cd qemu && sh make.sh veryclean
	for dir in musl bbox; do $(MAKELNX) -C $$dir $@ ||:; done
	rm -rf $(MUSLTGZ) $(sort $(wildcard $(OUTPUT))) $(SDIR)/ .sync

# target: buildsys /////////////////////////////////////////////////////////////
buildsys:
	for tg in bzImage busybox miniz uchaos rngtest; do $(MAKELNX) $$tg; done
	@echo "STOP >>> "$@": "$^ | tee -a $(MAKELOG)

# target: buildall /////////////////////////////////////////////////////////////
buildall:
	for tg in toolchain buildsys buildemu; do $(MAKELNX) $$tg; done
	@echo "STOP >>> "$@": "$^ | tee -a $(MAKELOG)

# target: buildemu /////////////////////////////////////////////////////////////
.PHONY: buildemu

qemu/output/.done:
	@echo "START >>> "$@": "$^ | tee -a $(MAKELOG)
	cd qemu && $(OPTS) time -p sh make.sh sources
	touch $@

virt/.done: qemu/output/.done
	@echo "START >>> "$@": "$^ | tee -a $(MAKELOG)
	cp -alLf qemu/output/* virt/
	touch $@

buildemu: $(KIMG) kdev/$(KMOD).gz virt/.done

# target: qemurset //////////////////////////////////////////////////////////////
qemurset:
	@echo "START >>> "$@": "$^ | tee -a $(MAKELOG)
	rm -rf $(CPIOTMP)/virt $(CPIOTMP)/.done
	$(MAKELNX) install

# target: qemutest //////////////////////////////////////////////////////////////
qemutest: virt/.done $(CPIOTMP)/.done
	@echo "START >>> "$@": "$^ | tee -a $(MAKELOG)
	rm -rf $(CPIOTMP)/virt/
# cp -arf cpio/* $(CPIOTMP)/
	sh cpio.sh -c
	cp -arf virt/ $(CPIOTMP)/
	cd virt && $(ENV_VARS) KARGS="UCTEST=9" sh start.sh -uqm64 -M q35

# target: runqemu //////////////////////////////////////////////////////////////
runqemu: virt/.done $(CPIOTMP)/.done
	@echo "START >>> "$@": "$^ | tee -a $(MAKELOG)
	@echo "Prepare and start the KVM 32MB machine"
	cd virt && $(ENV_VARS) sh start.sh -qm32 -M q35

