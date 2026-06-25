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
GZIP         := $(shell command -v pigz gzip | head -n1)

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
HDIR         := $(CURDIR)/$(OUTPUT)/$(ARCH)-linux-musl/include
export PATH  := $(CURDIR)/$(OUTPUT)/bin:$(CURDIR)/$(OUTPUT)/$(ARCH)/bin:$(PATH)

# Tools and Options
HOSTCC       := gcc
CC           := $(CCPREFIX)gcc
EXTRA_CFLAGS += -falign-functions=32
export EXTRA_CFLAGS := $(EXTRA_CFLAGS)
OPTS         := ARCH=$(ARCH) CROSS_COMPILE=$(CCPREFIX)
OPTS         += CCPREFIX=$(CCPREFIX) KERNVER=$(KERNVER)
OPTS         += EXTRA_CFLAGS="$(EXTRA_CFLAGS)" PATH=$(PATH)

KDIR_FILES   := $(addprefix $(KDIR)/, vmlinux bzImage System.map)
VIRT_FILES   := $(addprefix virt/, *.bin *.rom .done $(QBIN))
CONF_FILES   := $(addsuffix /.conf, bbox musl $(KDIR))

ARTIFACTS    := prnd/RNG_test zcmd/uzpexec $(VIRT_FILES) qemu/output/ ucfg/pkg-config
ARTIFACTS    += bbox/busybox.elf bbox/.config cpio.cpio $(CPIOTMP)/ usrl/uchaosbox
ARTIFACTS    += $(KDIR_FILES) $(CONF_FILES) $(SDIR)/.done $(OUTPUT)/.done
ARTIFACTS    += minz/amalgamation/ $(LNXPATH) kdev/uckaos kdev/umkaos kdev/$(KMOD)*

MAKELNX      := $(MAKE) $(OPTS) -j$(NCPU)
MAKELOG      := make.log

TRGDONE      := kdev/uckaos prnd/RNG_test usrl/uchaosbox
TRGDONE      += ucfg/pkg-config bbox/busybox.elf kdev/$(KMOD).gz
TRGDONE      += virt/initramfs.cpio.gz $(KIMG) qemu/output/$(QBIN)
TRGDONE      += kdev/umkaos $(MUSLTGZ) zcmd/uzpexec

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
	for tg in buildall status; do $(MAKELNX) $$tg || exit 1; done
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
.PHONY: update defconfig _defconfig sources _sources uzpexec

MUSL_DPNDS := $(wildcard cnfg/Makefile.*)
MUSL_DPNDS += $(wildcard cnfg/hashes/*.sha1)
MUSL_DPNDS += $(MUSLCFGMAK) # bbox/.config $(KDIR)/.config

PATCH_NAME := printk-early-boot-timestamps-hack-v6
PATCH_NAME += bothering-warn_unseeded_randomness-fix
PATHC_KDIR := musl/patches/linux-$(KERNVER)

.sync: | .gitmodules
	@$(call print_start,"","Wait updating project dependencies ...")
	git submodule update --init --recursive --depth 32 \
	  --single-branch --jobs $(NCPU)
	@echo
	touch $@

musl/.conf: $(MUSL_DPNDS)
	@$(call print_start,"","")
	cp -arLf cnfg/hashes/*.sha1 musl/hashes/
	cp -alLf cnfg/Makefile.musl musl/Makefile
	cp -alLf cnfg/Makefile.lite musl/litecross/Makefile
	mkdir -p $(PATHC_KDIR) && for fp in $(PATCH_NAME); do \
	  cp -alLf cnfg/$$fp.patch $(PATHC_KDIR)/0001-$$fp.diff; done
	cp -alLf $(MUSLCFGMAK) musl/config.mak
	touch $@

zcmd/uzpexec: | .sync
	@$(call print_start,"","")
	make -C zcmd uzpexec -j1

uzpexec: | zcmd/uzpexec

$(SDIR)/.done: cnfg/musl-gcc-cp-make-lang-in.patch
	@$(call print_start,"","Wait downloading sources ...")
	$(MAKELNX) HOSTCC=$(HOSTCC) -C musl extract_all
	patch -Rfp1 --dry-run < $^ >&- || patch -p1 < $^
	@$(call print_stop)
	@echo "Sources download completed successfully"
	@echo
	touch $@

update: | .sync
	@$(call print_stop)

updatebbox: | .sync
	@echo "Updating busybox at the uchaosys branch HEAD"
	cd bbox && git fetch origin uchaosys --jobs $(NCPU) \
	  && git checkout FETCH_HEAD

updatezcmd: | .sync
	@echo "Updating zcmd at the main branch HEAD"
	cd zcmd && git fetch origin main --jobs $(NCPU) \
	  && git checkout FETCH_HEAD

.dcfg: | .sync
	rm -f $(KDIR)/.hdrs $(SDIR)/.done
	rm -f bbox/.config bbox/.conf
	rm -f musl/.conf $(MAKELOG)
	cp -f cnfg/uchaos_tbl.h kdev
	$(MAKELNX) musl/.conf
	@touch .dcfg

_defconfig: | .dcfg

defconfig:
	rm -f .dcfg
	@$(call print_start,"","")
	@$(MAKELNX) _$@
	@$(call print_stop)

_sources: $(SDIR)/.done qemu/src/.done

sources: _defconfig 
	@$(call print_start,"","")
	@$(MAKELNX) _$@
	@$(call print_stop)

copysrc: $(FROM)/
	@test -d  $(FROM)/
	$(MAKELNX) update
	cp -arlLf $(FROM)/$(SDIR) musl/
	cp -arlLf $(FROM)/qemu/v*.tar.* qemu/
	rm -f $(SDIR)/.done
	$(MAKELNX) defconfig
	@echo
	@$(call print_stop)
	du -ks qemu/v*.tar.* $(SDIR)
	@echo

# target: toolchain ////////////////////////////////////////////////////////////
.PHONY: toolchain _toolchain

$(OUTPUT)/.done: $(KDIR)/.hdrs
	@$(call print_start,"","")
	$(MAKELNX) HOSTCC=$(HOSTCC) -C musl install
	@$(call print_stop)
	touch $@

$(MUSLTGZ): $(OUTPUT)/.done
	@$(call print_start,"","")
	rm -f $@ && tar -c $(OUTPUT)/ | $(GZIP) -1c >$@
	@echo
	@$(call print_size,$(OUTPUT)/,m,MB)
	@$(call print_size,$@,m,MB)
	@echo

_toolchain: $(SDIR)/.done $(OUTPUT)/.done $(MUSLTGZ)

toolchain:
	@$(call print_start,"","")
	@$(MAKELNX) _toolchain
	@$(call print_stop)

# target: bzImage //////////////////////////////////////////////////////////////
.PHONY: bzImage _bzImage

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

$(KDIR)/.hdrs: $(SDIR)/.done
	@$(call print_start,"","")
	$(MAKELNX) -C $(KDIR) INSTALL_HDR_PATH=$(CURDIR)/$(OUTPUT)/$(ARCH)-linux-musl headers_install
	touch $@

$(KIMG): musl/.conf $(KDIR) $(KDIR)/.conf
	@$(call print_start,"","")
	$(MAKELNX) -C $(KDIR) all
	@$(call print_stop)
	cp -alLf $(KDIR)/arch/$(ARCH)/boot/bzImage $@
	@echo
	@strings $(KDIR)/vmlinux | grep -e "^Linux version" | tr , \\n
	@$(call print_size,$@,k,KB)
	@echo
	touch $@

_bzImage: $(SDIR)/.done musl/.conf $(KDIR) $(KDIR)/.conf $(KDIR)/.hdrs $(KIMG)

bzImage:
	@$(call print_start,"","")
	@$(MAKELNX) _bzImage
	@$(call print_stop)

# target: busybox //////////////////////////////////////////////////////////////
.PHONY: busybox _busybox

bbox/.config: $(BBOXCFG)
	cp -alLf $(BBOXCFG) bbox/.config ||:

bbox/.conf: bbox/.config
	@$(call print_start,"","")
	yes "" |  $(MAKE) $(OPTS) -j1 -C bbox oldconfig
	@$(call print_stop)
	touch $@

bbox/busybox.elf: bbox/.conf | $(KDIR)/.hdrs
	rm -f $@
	@$(call print_start,"","")
	$(MAKELNX) -C bbox busybox
	@$(call print_stop)
	cp -alLf bbox/busybox $@
	@echo
	@file $@ | cut -d, -f1,2,4; $(call print_size,$@,k,KB)
	@echo

_busybox: bbox/.config bbox/.conf $(KDIR)/.hdrs bbox/busybox.elf

busybox:
	@$(call print_start,"","")
	@$(MAKELNX) _busybox
	@$(call print_stop)

# target: miniz ////////////////////////////////////////////////////////////////
.PHONY: miniz

minz/amalgamation/.done: cnfg/amalgamate.sh
	@$(call print_start,"","")
	cp -alLf cnfg/amalgamate.sh minz/
	cd minz && $(OPTS) sh amalgamate.sh
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
	CC="$(CC) -static -mavx2" $(MAKELNX) -C kdev dist
	@$(call print_stop)
	@echo
	touch $@

usrl/uchaosbox:
	@$(call print_start,"","")
	$(MAKELNX) -C usrl uchaosbox
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
	$(MAKELNX) CCSYSROOT="-static -mavx2" -C prnd RNG_test
	@$(call print_stop)

rngtest: prnd/RNG_test
	@$(call print_start,"","")
	@file $< | cut -d, -f1,2,4; $(call print_size,$<,k,KB)
	@echo

# target: install //////////////////////////////////////////////////////////////
.PHONY: install glib

$(CPIOTMP)/.done: zcmd/uzpexec kdev/$(KMOD).gz bbox/busybox.elf usrl/uchaosbox
	@$(call print_start,"","")
	mkdir -p $(CPIOTMP)/
	cp -arf cpio/* $(CPIOTMP)/
	cd $(CPIOTMP) && mkdir -p tmp/ var/log/ lib/modules/ usr/bin/
	cp -alLf kdev/$(KMOD).gz $(CPIOTMP)/lib/modules/$(KMOD)
	cp -alLf bbox/busybox.elf $(CPIOTMP)/usr/bin/busybox
	cp -alLf usrl/uchaosbox kdev/u?kaos $(CPIOTMP)/usr/bin/
	cp -alLf zcmd/uzpexec $(CPIOTMP)/usr/bin/
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
	@echo

glib:
	@$(call print_start,"","")
	$(MAKELNX) -C musl $@

# //////////////////////////////////////////////////////////////////////////////
.PHONY: clean realclean veryclean deepclean distclean

clean:
	$(MAKELNX) realclean defconfig

realclean:
	@$(call print_start,"","Removing artifacts and cleaning virt/ folder")
	rm -rf $(ARTIFACTS) $(SDIR)/*.tmp
	rm -f $(shell ls -1d virt/* | grep -v start.sh ||:)
	@echo "Removing custom configuration files and links"
	rm -f .dcfg
# Protected by: test -e $lnxpath
	rm -f $(LNXPATH)
# Protected by: test -r musl/config.mak
	rm -f musl/{config.mak,.conf}
# Protected by: test -r $lnxpath/.config
	rm -f $(KDIR)/{.config,.conf,.hdrs}
# Protected by: test -r bbox/.config
	rm -f bbox/.config
# Remove all the hashes added, as well
	rm -f musl/$(shell cd cnfg && command ls -1 hashes/* ||:)
# Remove qemu binary
	rm -f qemu/$(QBIN)

veryclean: realclean
	@$(call print_start,"","Cleaning ...")
	rm -rf minz/_build/ qemu/src/
	for dir in kdev usrl prnd $(LNXPATH); do $(MAKELNX) -C $$dir $@ ||:; done
# Call zcmd clean
	make -C zcmd clean
# Call qemu/make.sh clean
	cd qemu && sh make.sh $@
# Call prnd/make veryclean
	for dir in bbox qemu musl; do $(MAKELNX) -C $$dir clean ||:; done

deepclean: veryclean
	@$(call print_start,"","Removing everything apart from the updated repo")
# Call qemu/make.sh veryclean
	cd qemu && sh make.sh $@
	for dir in bbox musl; do $(MAKELNX) -C $$dir $@ ||:; done
	rm -rf $(MUSLTGZ) $(sort $(wildcard $(OUTPUT))) $(MAKELOG) .sync

distclean: deepclean
	cd qemu && sh make.sh $@
	rm -rf $(SDIR)/

# target: build related ////////////////////////////////////////////////////////
.PHONY: buildemu _buildemu buildsys

ucfg/pkg-config:
	cd ucfg && $(HOSTCC) $(EXTRA_CFLAGS) -o pkg-config main_posix.c -s -O1

qemu/src/.done:
	@$(call print_start,"","")
	cd qemu && sh make.sh sources
	@$(call print_stop)

qemu/output/.done: minz/amalgamation/.done ucfg/pkg-config qemu/src/.done zcmd/uzpexec
	@$(call print_start,"","")
	cd qemu && rm -f output/$(QBIN) && sh make.sh
	cp -af zcmd/uzpexec qemu/output/$(QBIN).uzp
	cd qemu/output && $(GZIP) -9c $(QBIN) >> $(QBIN).uzp
	cd qemu/output && mv -f $(QBIN).uzp $(QBIN)
	touch $@

virt/.done: qemu/output/.done
	@$(call print_start,"","")
	cp -alf qemu/output/* $(VDIR)/
	$(MAKELNX) install
	touch $@

_buildemu: $(KIMG) kdev/$(KMOD).gz virt/.done
	@$(call print_stop)

buildemu:
	@$(call print_start,"","")
	@$(MAKELNX) _buildemu
	@$(call print_stop)

buildsys:
	@$(call print_start,"","")
	for tg in _bzImage _busybox miniz uchaos rngtest; do $(MAKELNX) $$tg || exit 1; done
	@$(call print_stop)

buildall: _defconfig _sources
	@$(call print_start,"","")
	for tg in _toolchain buildsys _buildemu; do $(MAKELNX) $$tg || exit 1; done; sync
	@$(call print_stop)

# targets: qemu related ////////////////////////////////////////////////////////
.PHONY: qemutest qemurset runqemu

QEMU_FILES := virt/initramfs.cpio.gz virt/$(QBIN)

virt/initramfs.cpio.gz: $(KIMG)

virt/$(QBIN): buildemu

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

