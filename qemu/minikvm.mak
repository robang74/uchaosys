# Ultra-minimal config for q35 + microvm only
# Works with --without-default-devices --without-default-features
# https://static.sched.com/hosted_files/kvmforum2019/c6/kvmforum19-bloat.pdf

################################################################################
CONFIG_Q35=y
# Hardware necessary support
  CONFIG_IVSHMEM=y
# CONFIG_PC=y      # this is the key one, enabled by Q35
# CONFIG_PC_PCI=y
# CONFIG_ACPI_ICH9=y
# CONFIG_ACPI_X86=y
# Disable everything that pulls CXL isn't possible
# CONFIG_ACPI_NVDIMM=y
# CONFIG_ACPI_VMGENID=y
# CONFIG_ACPI_HMAT=y
# CONFIG_ACPI_ERST=y
# CONFIG_ACPI_CXL=y
  #CONFIG_PXB=y
# CONFIG_PCI=y
# CONFIG_PCI_BRIDGE=y
  #CONFIG_PCI_EXPRESS_Q35=y
  #CONFIG_MSI_NONBROKEN=y
# CONFIG_ICH9_LPC=y
  CONFIG_ACPI_CXL=y # <-- this is the source of the problem

################################################################################
# CONFIG_MICROVM=y
# # Core bus + devices you want
# CONFIG_VIRTIO_PCI=y
# CONFIG_VIRTIO_NET=y
# CONFIG_VIRTIO_BLK=y
# CONFIG_VIRTIO_MMIO=y
# CONFIG_VIRTIO_SCSI=y
# CONFIG_VIRTIO_SERIAL=y
# CONFIG_VIRTIO_BALLOON=y
# # Other common sources of missing symbols / bloat
# CONFIG_VIRTIO_INPUT=n
# CONFIG_VIRTIO_GPU=n
# CONFIG_VIRTIO_RNG=n
# CONFIG_VIRTIO_CRYPTO=n

