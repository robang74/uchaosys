#
# (c) 2026, Roberto A. Foglietta <roberto.foglietta@gmail.com>, MIT license
#     Makefile created by converting the initial make.lst shell script
#

# Settings /////////////////////////////////////////////////////////////////////
ARCH         ?= x86_64
export ARCH  := $(ARCH)
ENV_VARS     ?=
NCPU         ?= $(shell nproc 2>/dev/null || echo 1)
export NCPU  := $(NCPU)
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
HDIR         := $(CURDIR)/$(OUTPUT)
export PATH  := $(HDIR)/bin:$(HDIR)/$(ARCH)/bin:$(PATH)

# Tools and Options
HOSTCC       := gcc
CC           := $(CCPREFIX)gcc
EXTRA_CFLAGS += -falign-functions=32
EXTRA_CFLAGS += -isystem  $(PWD)/musl/output/include
EXTRA_CFLAGS += -isystem  $(PWD)/musl/build/obj_sysroot/include
EXTRA_CFLAGS += --sysroot=$(PWD)/musl/output/
#export EXTRA_CFLAGS := $(EXTRA_CFLAGS)
#C_INCLUDE_PATH := $(PWD)/musl/output/include:$(PWD)/musl/build/obj_sysroot/include
#CPLUS_INCLUDE_PATH := $(PWD)/musl/output/x86_64-linux-musl/include/c++/14.3.0
OPTS         := ARCH=$(ARCH) CROSS_COMPILE=$(CCPREFIX)
OPTS         += CCPREFIX=$(CCPREFIX) KERNVER=$(KERNVER)
OPTS         += EXTRA_CFLAGS="$(EXTRA_CFLAGS)" PATH=$(PATH)
#OPTS        += EXTRA_CXXFLAGS="$(EXTRA_CFLAGS) $(SYSROOT_ARGS)"
#OPTS        += C_INCLUDE_PATH=$(C_INCLUDE_PATH)
#OPTS        += CPLUS_INCLUDE_PATH=$(CPLUS_INCLUDE_PATH)
GZCMD_REPO   := https://raw.githubusercontent.com/robang74/bare-minimal-linux-system/
GZCMD_PATH   := refs/heads/main

KDIR_FILES   := $(addprefix $(KDIR)/, vmlinux bzImage System.map)
VIRT_FILES   := $(addprefix virt/, *.bin *.rom .done $(QBIN))
CONF_FILES   := $(addsuffix /.conf, bbox musl $(KDIR))

ARTIFACTS    := prnd/RNG_test gzcmd.gz.sh $(VIRT_FILES) qemu/output/ ucfg/pkg-config
ARTIFACTS    += bbox/busybox.elf bbox/.config cpio.cpio $(CPIOTMP)/ usrl/uchaosbox
ARTIFACTS    += $(KDIR_FILES) $(CONF_FILES) $(SDIR)/.done $(OUTPUT)/.built
ARTIFACTS    += minz/amalgamation/ $(LNXPATH) kdev/uckaos kdev/$(KMOD)*

MAKELNX      := $(MAKE) $(OPTS) -j$(NCPU)
MAKELOG      := make.log

TRGDONE      := gzcmd.gz.sh kdev/uckaos prnd/RNG_test usrl/uchaosbox
TRGDONE      += ucfg/pkg-config bbox/busybox.elf kdev/$(KMOD).gz
TRGDONE      += virt/initramfs.cpio.gz $(KIMG) qemu/output/$(QBIN)
TRGDONE      += musl/output/meson.pyz $(MUSLTGZ)

define print_size
	du -$(2)s $(1) | sed -e "s/^/size: /" -e "s/\t/ $(3) /"
endef

define print_line
	echo "$2 $1 $(shell date +%s) $2 "$@": "$^ | tee -a $(MAKELOG)
endef

define print_start
	echo "$1"; $(call print_line,"START","=o="); echo "$2"
endef

define print_stop
	$(call print_line,"STOP ","~x~");
endef

define print_status
	for i in $(TRGDONE); do ok="ok"; test -e "$$i" || ok="ko"; \
		echo "  $$i: $$ok"; done | grep -e ": $1$$"  || echo "  none"
endef

.PHONY: all update sources buildall install status _status

all:
	rm -f $(MAKELOG)
	for tg in sources buildall status; do $(MAKELNX) $$tg || exit 1; done
	@$(call print_stop)

_status:
	@echo
	@echo "Target completed:"
	@$(call print_status,"ok")
	@echo "Target missing:"
	@$(call print_status,"ko")
	@echo

status:
	@make _status | tee -a $(MAKELOG)

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

$(SDIR)/.done: .sync
	@$(call print_start,"","Wait downloading sources ...")
	$(MAKELNX) HOSTCC=$(HOSTCC) -C musl extract_all
	@$(call print_stop)
	@echo "Sources download completed successfully"
	@echo
	touch $@

musl/.conf: $(MUSL_DPNDS)
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

sources: .sync gzcmd.gz.sh
	@$(call print_start,"","")
	@$(MAKELNX) musl/.conf
	@$(MAKELNX) $(SDIR)/.done
	@$(call print_stop)

# //////////////////////////////////////////////////////////////////////////////
.PHONY: copysrc defconfig updatebbox update

update: .sync
	@$(call print_stop)

updatebbox: .sync
	@echo "Updating busybox at the uchaosys branch HEAD"
	cd bbox && git fetch origin uchaosys --jobs $(NCPU) \
	  && git checkout FETCH_HEAD

defconfig: .sync
	rm -f bbox/.config bbox/.conf $(OUTPUT)/.hdrs $(SDIR)/.done
	rm -f musl/.conf $(MAKELOG) && $(MAKELNX) musl/.conf

copysrc: .sync $(FROM)/
	@test -d  $(FROM)/
	make -j$(NCPU) update
	cp -arlLf $(FROM)/$(SDIR) musl/
	cp -arlLf $(FROM)/qemu/v*.tar.* qemu/
	rm -f $(SDIR)/.done
	make -j$(NCPU) defconfig
	@echo
	@$(call print_stop)
	du -ks qemu/v*.tar.* $(SDIR)
	@echo

# target: toolchain ////////////////////////////////////////////////////////////
.PHONY: toolchain glib

ucfg/pkg-config:
	$(HOSTCC) $(EXTRA_CFLAGS) -o $@ ucfg/main_posix.c -s -O1
	mkdir -p $(HDIR)/usr/bin/
	cp -alLf $@ $(HDIR)/usr/bin/

$(OUTPUT)/.glib: $(OUTPUT)/.hdrs
	@$(call print_start,"","")
	$(MAKELNX) -C musl glib
	touch $@	

glib: $(OUTPUT)/.glib

# $(OUTPUT)/.glib ucfg/pkg-config
$(MUSLTGZ): ucfg/pkg-config
	@$(call print_start,"","")
	rm -f $(MUSLTGZ) ; tar czf $@ $(OUTPUT)/
	@echo
	@$(call print_size, $(OUTPUT)/,m,MB)
	@$(call print_size,$@,m,MB)
	@echo

$(OUTPUT)/.built: musl/.conf
	@$(call print_start,"","")
	$(MAKELNX) HOSTCC=$(HOSTCC) -C musl install
	@$(call print_stop)
	touch $@

toolchain: $(OUTPUT)/.built
	@$(call print_start,"","")
	@$(MAKELNX) $(MUSLTGZ)
	@$(call print_stop)

# target: bzImage //////////////////////////////////////////////////////////////
.PHONY: bzImage

$(KDIR)/.config: $(KERNCFG)
	cp -alLf $(KERNCFG) $(KDIR)/.config ||:
	sed -e "s,^\(headers: .* archheaders\) archscripts,\\1," -i $(KDIR)/Makefile

$(KDIR)/.conf: | $(KDIR)/.config
	@$(call print_start,"","")
	$(MAKELNX) -C $(KDIR) olddefconfig
	touch $@

$(OUTPUT)/.hdrs: $(KDIR)/.conf
	@$(call print_start,"","")
	$(MAKELNX) -C $(KDIR) INSTALL_HDR_PATH=$(HDIR) headers_install
	touch $@

$(KIMG): $(KDIR)/.conf
	@$(call print_start,"","")
	$(MAKELNX) -C $(KDIR) all
	@$(call print_stop)
	cp -alLf $(KDIR)/arch/$(ARCH)/boot/bzImage $@
	@echo
	@strings $(KDIR)/vmlinux | grep -e "^Linux version" | tr , \\n
	@$(call print_size,$@,k,KB)
	@echo
	touch $@

$(KDIR): $(KIMG)
	@$(call print_start,"","")
	@test -r $@ || echo "Error do 'make sources' before, exit 1."
	@test -r $@ && $(call print_size,$@,k,KB)
	@touch   $@
	@echo

bzImage: $(OUTPUT)/.built
	@$(call print_start,"","")
	@$(MAKELNX) $(KDIR)
	@$(call print_stop)

# target: busybox //////////////////////////////////////////////////////////////
.PHONY: busybox

bbox/.config: $(BBOXCFG)
	cp -alLf $(BBOXCFG) bbox/.config ||:

bbox/.conf: | bbox/.config
	@$(call print_start,"","")
	yes "" |  $(MAKE) $(OPTS) -j1 -C bbox oldconfig
	@$(call print_stop)
	touch $@

# $(OUTPUT)/.hdrs
bbox/busybox.elf: | bbox/.conf
	rm -f $@
	@$(call print_start,"","")
	$(MAKELNX) -C bbox busybox
	@$(call print_stop)
	cp -alLf bbox/busybox $@
	@echo
	@file $@ | cut -d, -f1,2,4; $(call print_size,$@,k,KB)
	@echo

busybox:
	@$(call print_start,"","")
	@$(MAKELNX) bbox/busybox.elf CFLAGS="$(EXTRA_CFLAGS)"
	@$(call print_stop)

# target: miniz ////////////////////////////////////////////////////////////////
.PHONY: miniz

minz/amalgamation/.done: cnfg/amalgamate.sh
	@$(call print_start,"","")
	cp -alLf cnfg/amalgamate.sh minz/
	cd minz && EXTRA_CFLAGS="$(EXTRA_CFLAGS)" sh -x amalgamate.sh
	touch $@

miniz: minz/amalgamation/.done
	@$(call print_stop)

# target: uchaos ///////////////////////////////////////////////////////////////
.PHONY: uchaos

$(LNXPATH):
	@$(call print_start,"","")
	ln -sf ../$(KDIR) $@

$(KDIR)/System.map: $(KIMG)

kdev/$(KMOD).gz: | $(LNXPATH) $(KDIR)/System.map
	@$(call print_start,"","")
	$(MAKELNX) -C kdev dist
	@$(call print_stop)
	@echo
	touch $@

usrl/uchaosbox:
	@$(call print_start,"","")
	$(MAKELNX) -C usrl uchaosbox CFLAGS="$(EXTRA_CFLAGS)"
	@$(call print_stop)
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
# make -j8 CCPREFIX="" EXTRA_CXXFLAGS="" CCSYSROOT="-static -mavx2" -C prnd RNG_test
	$(MAKELNX) CCSYSROOT="-static -mavx2" -C prnd RNG_test
	@$(call print_stop)

rngtest: prnd/RNG_test
	@$(call print_start,"","")
	@file $< | cut -d, -f1,2,4; $(call print_size,$<,k,KB)
	@echo

# target: install //////////////////////////////////////////////////////////////
.PHONY: install

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

# //////////////////////////////////////////////////////////////////////////////
.PHONY: clean realclean veryclean deepclean distclean

clean:
	$(MAKELNX) realclean defconfig

realclean:
	@$(call print_start,"","Removing artifacts and cleaning virt/ folder")
	rm -rf $(ARTIFACTS) $(SDIR)/*.tmp
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
	rm -rf gzcmd.sh minz/_build/ qemu/src/
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
	rm -rf $(MUSLTGZ) $(sort $(wildcard $(OUTPUT))) $(MAKELOG) .sync

distclean: deepclean
	cd qemu && sh make.sh $@
	rm -rf $(SDIR)/

# target: build related ////////////////////////////////////////////////////////
.PHONY: buildemu _buildemu buildsys

qemu/output/.done: minz/amalgamation/.done
	@$(call print_start,"","")
	cd qemu && $(OPTS) time -p sh make.sh sources
	touch $@

virt/.done: qemu/output/.done
	@$(call print_start,"","")
	cp -alLf qemu/output/* virt/
	$(MAKELNX) install
	touch $@

buildemu: kdev/$(KMOD).gz
	@$(call print_start,"","")
	@$(MAKELNX) virt/.done
	@$(call print_stop)

buildsys:
	@$(call print_start,"","")
	for tg in bzImage busybox miniz uchaos rngtest; do $(MAKELNX) $$tg || exit 1; done
	@$(call print_stop)

buildall:
	@$(call print_start,"","")
	for tg in toolchain buildsys buildemu; do $(MAKELNX) $$tg || exit 1; done
	@$(call print_stop)

# targets: qemu related ////////////////////////////////////////////////////////
.PHONY: qemutest qemurset runqemu

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

# //////////////////////////////////////////////////////////////////////////////

.DEFAULT:
	$(MAKELNX) -C musl $@
