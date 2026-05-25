# Define the base module name here
MODULE_NAME := uchaos_dev

obj-m += $(MODULE_NAME).o

# Add GDB flags to force symbol generation during compilation
EXTRA_CFLAGS += -g0 -O2 -Wall -fstack-protector -s
# not yet supported -ftrivial-auto-var-init=zero

# Automatically create dependencies by c code files
EXTRA_CFLAGS += -MD -falign-functions=32
-include $(sources:.c=.d)

KERNVER ?= $(shell uname -r)

# Point to your compiled kernel source or headers
KO_FILE := $(MODULE_NAME).ko
KDIR    := linux-kernel
PWD     := $(shell pwd)

$(KDIR)/System.map:
	@echo "ERROR: file '$(KDIR)/System.map' is required, exit 1."; exit 1

KMAP := $(KDIR)/System.map System.map
ADDR := 0x$(shell grep " _credit_init_bits" $(KMAP) 2>/dev/null |\
            tail -n1 | cut -d' ' -f1 | cut -d: -f2)
ccflags-y += -D_CREDIT_INIT_ADDR=$(ADDR)

KCFG  := $(KDIR)/.config .config
KASLR := $(shell grep "CONFIG_RANDOMIZE_BASE=y" $(KCFG) 2>/dev/null)
ifneq ($(KASLR),)
	KASLR := 1
	ccflags-y += -D_KASLR_ENABLED=1
else
	KASLR := 0
	ccflags-y += -D_KASLR_ENABLED=0
endif

PRINTK := 0x$(shell grep -w "_printk" $(KMAP) 2>/dev/null |\
             tail -n1 | cut -d' ' -f1 | cut -d: -f2)
ccflags-y += -D_STATIC_PRINTK=$(PRINTK)

ccflags-y += $(CFLAGS) $(EXTRA_CFLAGS)
ldflags-y += $(LDFLAGS)"

################################################################################
.PHONY: all dist sign clean veryclean deepclean distclean

$(KDIR)/.conf:
	$(MAKE) -C $(KDIR) olddefconfig
	touch $@

all: uckaos umkaos $(KDIR)/.conf
	@ls -al $^
	@echo
	@echo ">>> _CREDIT_INIT_ADDR=$(ADDR) w/ KASLR=$(KASLR),$(PRINTK)"
	$(MAKE) $(OPTS) -C $(KDIR) M=$(PWD) modules_prepare modules

dist: all
	@echo "Stripping debug symbols from uchaos_dev.ko..."
	strip --strip-debug $(KO_FILE)
	@echo "Compressing with gzip -9 ... "
	gzip -9 -c $(KO_FILE) > $(KO_FILE).gz
	@printf "Final size: "
	@du -b $(KO_FILE).gz | tr '\t' ' '
	@printf "Final size: "
	@du -b uckaos | tr '\t' ' '

sign: all
	@echo "Signing the kernel module requires root priviledges"
	sudo /usr/src/linux-headers-$(KERNVER)/scripts/sign-file sha256 /var/lib/shim-signed/mok/MOK.priv /var/lib/shim-signed/mok/MOK.der $(KO_FILE) && modinfo $(KO_FILE)
	@echo ""
	@echo "The signature is valid only if it is enrolled in UEFI"
	@echo "Check the signature with 'sudo mokutil --list-enrolled'"

%.ko: %.o

%.o: %.c %.h

uckaos: uckaos.c uchaos_dev.h
	$(OPTS) $(CC) -O3 $< -I../usrl -o $@ -s

uchaos_tbl.h: umkaos.c uchaos_seq.h uchaos_seq.c
	$(OPTS) $(CC) -O3 $< -I../usrl -o umkaos -s -Wno-format-extra-args
	./umkaos >uchaos_tbl.h

umkaos: umkaos.c uchaos_seq.h uchaos_seq.c uchaos_tbl.h
	$(OPTS) $(CC) -O3 $< -I../usrl -o $@ -s -Wno-format-extra-args -D_USE_MLTP

clean:
	$(MAKE) -C $(KDIR) M=$(PWD) clean
	rm -f $(KO_FILE).gz uckaos umkaos

veryclean: clean
deepclean: veryclean
distclean: deepclean

