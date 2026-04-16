#
# (c) 2026, Roberto A. Foglietta <roberto.foglietta@gmail.com>, MIT license
#     Makefile created by converting the initial make.lst shell script
#

# Settings /////////////////////////////////////////////////////////////////////
ARCH         ?= x86_64
ENV_VARS     ?=
NCPU         ?= $(shell nproc)
MUSLCFGMAK   := cnfg/musl-125x.config.mak
BBOXCFG      := $(shell ls -1 cnfg/busybox-*.config | tail -n1)

# Extract kernel version from config
KERNVER      := $(shell cut -d\# -f1 $(MUSLCFGMAK) | grep "LINUX_VER = [0-9]" |\
                 tail -n1 | tr -dc 0-9.)
KVER_SHORT   := $(shell echo $(KERNVER) | tr -dc 0-9 | head -c3)x
KERNCFG      := cnfg/linux-$(KVER_SHORT).config

# Paths
VDIR         := virt
SDIR         := musl/sources
KDIR         := musl/linux-$(KERNVER)
QBIN         := qemu-system-$(ARCH)
MUSLTGZ      := musl-output.tar.gz
LNXPATH      := kdev/linux-kernel
CCPREFIX     := $(ARCH)-linux-musl-
CPIOTMP      := cpio.tmp
KMOD         := uchaos_dev.ko

OUTPUT       ?= musl/output
KIMG         := $(KDIR)/bzImage
export PATH  := $(CURDIR)/$(OUTPUT)/bin:$(CURDIR)/$(OUTPUT)/$(ARCH)/bin:$(PATH)

# Tools and Options
HOSTCC       := gcc
CC           := $(CCPREFIX)gcc
EXTRA_CFLAGS += -falign-functions=32
OPTS         := ARCH=$(ARCH) CROSS_COMPILE=$(CCPREFIX)
OPTS         += CCPREFIX=$(CCPREFIX) KERNVER=$(KERNVER)
OPTS         += EXTRA_CFLAGS="$(EXTRA_CFLAGS)" PATH=$(PATH)
GZCMD_REPO   := https://raw.githubusercontent.com/robang74/bare-minimal-linux-system/
GZCMD_PATH   := refs/heads/main

KDIR_FILES   := $(addprefix $(KDIR)/, .config vmlinux bzImage System.map)
VIRT_FILES   := $(addprefix virt/, *.bin *.rom .done $(QBIN))
CONF_FILES   := $(addsuffix /.conf, bbox musl $(KDIR))

ARTIFACTS    := bbox/busybox.elf bbox/.config cpio.cpio $(CPIOTMP)/ usrl/uchaosbox
ARTIFACTS    += $(KDIR_FILES) $(CONF_FILES) $(SDIR)/.done $(OUTPUT)/.done $(KIMG)
ARTIFACTS    += minz/amalgamation/ $(LNXPATH) kdev/uckaos kdev/$(KMOD)*
ARTIFACTS    += prnd/RNG_test gzcmd.gz.sh $(VIRT_FILES) qemu/output/

MAKELNX      := $(MAKE) $(OPTS) -j$(NCPU)
MAKELOG      := make.log

define print_size
	du -$(2)s $(1) | sed -e "s/^/size: /" -e "s/\t/ $(3) /"
endef

define print_line
	echo "$1 $(shell date +%s) >>> "$@": "$^ | tee -a $(MAKELOG)
endef

define print_start
	echo "$1"; $(call print_line, "START"); echo "$2"
endef

define print_stop
	$(call print_line, "STOP ");
endef

.PHONY: all update sources buildall install

all:
	rm -f $(MAKELOG)
	for tg in sources buildall; do $(MAKELNX) $$tg || exit 1; done
	@echo "STOP >>> "$@": "$^ | tee -a $(MAKELOG)

# target: sources //////////////////////////////////////////////////////////////
.PHONY: update defconfig

MUSL_DPNDS := $(wildcard cnfg/Makefile.*)
MUSL_DPNDS += $(wildcard cnfg/hashes/*.sha1)
MUSL_DPNDS += $(MUSLCFGMAK) # bbox/.config $(KDIR)/.config

PATCH_NAME := printk-early-boot-timestamps-hack-v6
PATCH_NAME += bothering-warn_unseeded_randomness-fix
PATHC_KDIR := musl/patches/linux-$(KERNVER)

.sync: .gitmodules
	@$(call print_start,"","Wait updating project dependencies ...")
	git submodule update --init --recursive --depth 32 \
	  --single-branch --jobs $(NCPU)
	@echo
	touch $@

musl/.conf: $(SDIR)/.done $(MUSL_DPNDS)
	@$(call print_start,"","")
	cp -arf cnfg/hashes/*.sha1 musl/hashes/
	cp -alLf cnfg/Makefile.musl musl/Makefile
	cp -alLf cnfg/Makefile.lite musl/litecross/Makefile
	mkdir -p $(PATHC_KDIR) && for fp in $(PATCH_NAME); do \
	  cp -alLf cnfg/$$fp.patch $(PATHC_KDIR)/0001-$$fp.diff; done
	cp -alLf $(MUSLCFGMAK) musl/config.mak
	touch $@

gzcmd.sh:
	@$(call print_start,"","")
	wget $(GZCMD_REPO)/$(GZCMD_PATH)/$@ -qO $@ ||\
	  curl -sL $(GZCMD_REPO)/$(GZCMD_PATH)/$@ -o $@
	sha1sum -c gzcmd.sh.sha1 || { rm -f $@; exit 1; }
	touch $@

gzcmd.gz.sh: gzcmd.sh
	@$(call print_start,"","")
	sh $< $< gzcmd
	touch $@

$(SDIR)/.done: .sync
	@$(call print_start,"","Wait downloading sources ...")
	$(MAKELNX) HOSTCC=$(HOSTCC) -C musl extract_all
	@echo "Sources download completed successfully"
	@echo
	touch $@

update: .sync

defconfig:
	rm -f musl/.conf $(MAKELOG) && $(MAKELNX) musl/.conf

sources: musl/.conf | gzcmd.gz.sh

# target: toolchain ////////////////////////////////////////////////////////////
.PHONY: toolchain

$(OUTPUT)/.done:
	@$(call print_start,"","")
	$(MAKELNX) HOSTCC=$(HOSTCC) -C musl install
	touch $@

$(MUSLTGZ): $(OUTPUT)/.done
	@$(call print_start,"","")
	rm -f $(MUSLTGZ) ; tar czf $@ $(OUTPUT)/
	@echo
	@$(call print_size, $(OUTPUT)/,m,MB)
	@$(call print_size,$@,m,MB)
	@echo

toolchain: $(SDIR)/.done $(OUTPUT)/.done $(MUSLTGZ)

# target: bzImage //////////////////////////////////////////////////////////////
.PHONY: bzImage

$(KDIR): $(SDIR)/.done
	@$(call print_start,"","")
	@test -r $@ || echo "Error do 'make sources' before, exit 1."
	@test -r $@ && $(call print_size,$@,k,KB)

$(KDIR)/.config: $(KERNCFG)
	cp -alLf $(KERNCFG) $(KDIR)/.config ||:

$(KDIR)/.conf: | $(KDIR)/.config
	@$(call print_start,"","")
	$(MAKELNX) -C $(KDIR) olddefconfig
	touch $@

$(KIMG): musl/.conf $(KDIR) $(KDIR)/.conf
	@$(call print_start,"","")
	$(MAKELNX) -C $(KDIR) all
	cp -alLf $(KDIR)/arch/$(ARCH)/boot/bzImage $@
	@echo
	@strings $(KDIR)/vmlinux | grep -e "^Linux version" | tr , \\n
	@$(call print_size,$@,k,KB)
	@echo
	touch $@

bzImage: $(SDIR)/.done musl/.conf $(KDIR) $(KDIR)/.conf $(KIMG)   

# target: busybox //////////////////////////////////////////////////////////////
.PHONY: busybox

bbox/.config: $(BBOXCFG)
	cp -alLf $(BBOXCFG) bbox/.config ||:

bbox/.conf: | bbox/.config
	@$(call print_start,"","")
	yes "" |  $(MAKE) $(OPTS) -j1 -C bbox oldconfig
	touch $@

bbox/busybox.elf: | bbox/.conf
	@$(call print_start,"","")
	rm -f $@
	$(MAKELNX) -C bbox busybox
	cp -alLf bbox/busybox $@
	@echo
	@file $@ | cut -d, -f1,2,4; $(call print_size,$@,k,KB)
	@echo

busybox: bbox/.config bbox/.conf bbox/busybox.elf

# target: miniz ////////////////////////////////////////////////////////////////
.PHONY: miniz

minz/amalgamation/.done: cnfg/amalgamate.sh
	@$(call print_start,"","")
	cp -alLf cnfg/amalgamate.sh minz/
	cd minz && $(OPTS) sh -x amalgamate.sh
	touch $@

miniz: minz/amalgamation/.done

# target: uchaos ///////////////////////////////////////////////////////////////
.PHONY: uchaos

$(LNXPATH):
	@$(call print_start,"","")
	ln -sf ../$(KDIR) $@

$(KDIR)/System.map: $(KIMG)

kdev/$(KMOD).gz: | $(LNXPATH) $(KDIR)/System.map
	@$(call print_start,"","")
	$(MAKELNX) -C kdev dist
	@echo
	touch $@

usrl/uchaosbox:
	@$(call print_start,"","")
	$(MAKELNX) -C usrl uchaosbox
	@echo

uchaos: minz/amalgamation/.done usrl/uchaosbox $(LNXPATH) kdev/$(KMOD).gz
	@$(call print_start,"","")
	@file kdev/$(KMOD).gz | cut -d, -f1,6-
	@file kdev/$(KMOD).gz | cut -d, -f2-4
	@strings kdev/$(KMOD) | grep -e "^version=" | tr '\n' ' '
	@$(call print_size,kdev/$(KMOD).gz,b,bytes)
	@echo

# target: rngtest //////////////////////////////////////////////////////////////
.PHONY: rngtest

prnd/RNG_test:
	@$(call print_start,"","")
	$(MAKELNX) CCSYSROOT="-static -mavx2" -C prnd RNG_test

rngtest: prnd/RNG_test
	@$(call print_start,"","")
	@file $< | cut -d, -f1,2,4; $(call print_size,$<,k,KB)
	@echo

# target: install //////////////////////////////////////////////////////////////
.PHONY: install glib

$(CPIOTMP)/.done: kdev/$(KMOD).gz bbox/busybox.elf usrl/uchaosbox
	@$(call print_start,"","")
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
	@$(call print_start,"","")
	cp -alLf $(KIMG) $(VDIR)/
	cd $(VDIR) && sh start.sh -U
	@cd $(VDIR) && du -k $(QBIN) | tr '\t' ' '
	@echo

glib:
	@$(call print_start,"","")
	$(MAKELNX) -C musl $@

# //////////////////////////////////////////////////////////////////////////////
.PHONY: clean veryclean deepclean distclean buildsys qemutest qemurset runqemu

clean:
	$(MAKELNX) realclean defconfig

realclean:
	@$(call print_start,"","Removing artifacts and cleaning virt/ folder")
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
# Remove qemu binary
	rm -f qemu/$(QBIN)

veryclean: realclean
	@$(call print_start,"","Cleaning ...")
	echo gzcmd.sh minz/_build/ qemu/src/ | xargs -P0 -I {} rm -rf "{}"
	for dir in kdev usrl prnd $(LNXPATH); do $(MAKELNX) -C $$dir $@ ||:; done
# Call qemu/make.sh clean
	cd qemu && sh make.sh $@
# Call prnd/make veryclean
	for dir in musl bbox qemu; do $(MAKELNX) -C $$dir clean ||:; done

deepclean: veryclean
	@$(call print_start,"","Removing everything apart from the updated repo")
# Call qemu/make.sh veryclean
	cd qemu && sh make.sh $@
	for dir in musl bbox; do $(MAKELNX) -C $$dir $@ ||:; done
	rm -rf $(MUSLTGZ) $(sort $(wildcard $(OUTPUT))) .sync

distclean: deepclean
	cd qemu && sh make.sh $@
	rm -rf $(SDIR)/

# target: build related ////////////////////////////////////////////////////////
.PHONY: buildemu

buildsys:
	for tg in bzImage busybox miniz uchaos rngtest; do $(MAKELNX) $$tg || exit 1; done
	@echo "STOP >>> "$@": "$^ | tee -a $(MAKELOG)

buildall:
	for tg in toolchain buildsys buildemu; do $(MAKELNX) $$tg || exit 1; done
	@echo "STOP >>> "$@": "$^ | tee -a $(MAKELOG)

qemu/output/.done: minz/amalgamation/.done
	@$(call print_start,"","")
	cd qemu && $(OPTS) time -p sh make.sh sources
	touch $@

virt/.done: qemu/output/.done
	@$(call print_start,"","")
	cp -alLf qemu/output/* virt/
	$(MAKELNX) install
	touch $@

buildemu: $(KIMG) kdev/$(KMOD).gz virt/.done

# targets: qemu related ////////////////////////////////////////////////////////
QEMU_FILES := virt/$(QBIN) virt/initramfs.cpio.gz

virt/$(QBIN):
	$(MAKELNX) buildemu

virt/initramfs.cpio.gz:
	$(MAKELNX) install

qemurset:
	@$(call print_start,"","")
	rm -rf $(CPIOTMP)/virt $(CPIOTMP)/.done
	$(MAKELNX) install

qemutest: $(QEMU_FILES) $(CPIOTMP)/.done
	@$(call print_start,"","")
	rm -rf $(CPIOTMP)/virt/
	sh cpio.sh -c
	cp -arf virt/ $(CPIOTMP)/
	cd virt && $(ENV_VARS) KARGS="UCTEST=9" sh start.sh -uqm64 -M q35

runqemu: $(QEMU_FILES)
	@$(call print_start,"","Prepare and start the KVM 32MB machine")
	cd virt && $(ENV_VARS) sh start.sh -qm32 -M q35

