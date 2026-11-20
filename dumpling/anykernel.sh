### AnyKernel3 Ramdisk Mod Script
## KernelSU-Next for OnePlus 5T (dumpling), LineageOS 22.2
## Replaces only the kernel in boot; the ramdisk is left untouched.

### AnyKernel setup
# global properties
properties() { '
kernel.string=LineageOS 22.2 kernel + KernelSU-Next (legacy) for OnePlus 5T
do.devicecheck=1
do.modules=0
do.systemless=0
do.cleanup=1
do.cleanuponabort=0
device.name1=dumpling
device.name2=OnePlus5T
device.name3=
supported.versions=
supported.patchlevels=
supported.vendorpatchlevels=
'; } # end properties

### AnyKernel install
# boot shell variables
BLOCK=/dev/block/bootdevice/by-name/boot;
IS_SLOT_DEVICE=0;
RAMDISK_COMPRESSION=auto;
PATCH_VBMETA_FLAG=auto;

# import functions/variables and setup patching - see for reference (DO NOT REMOVE)
. tools/ak3-core.sh;

# boot install: swap the kernel (Image.gz-dtb) only
split_boot;
flash_boot;
## end boot install
