#!/usr/bin/env bash
# Build a LineageOS 22.2 kernel for the OnePlus 5T (dumpling) with
# KernelSU-Next (legacy branch, manual hooks) and package it as an
# AnyKernel3 flashable zip.
#
# Usage (from anywhere, on a Debian/Ubuntu x86_64 machine):
#   sudo apt install -y git clang bc bison flex libssl-dev \
#        binutils-aarch64-linux-gnu binutils-arm-linux-gnueabi zip python3
#   ./dumpling/build.sh
#
# Output: dumpling/out/KernelSU-Next-dumpling-<date>.zip
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
KSU_ROOT="$(cd "$HERE/.." && pwd)"          # this KernelSU-Next checkout
WORK="${WORK:-$HERE/work}"
KERNEL_DIR="$WORK/kernel"
KERNEL_REPO="${KERNEL_REPO:-https://github.com/LineageOS/android_kernel_oneplus_msm8998}"
KERNEL_BRANCH="${KERNEL_BRANCH:-lineage-22.2}"
DEFCONFIG="lineage_oneplus5_defconfig"
JOBS="${JOBS:-$(nproc)}"

mkdir -p "$WORK" "$HERE/out"

# 1. Kernel source
if [ ! -d "$KERNEL_DIR/.git" ]; then
	git clone --depth=1 -b "$KERNEL_BRANCH" "$KERNEL_REPO" "$KERNEL_DIR"
fi
cd "$KERNEL_DIR"

# 2. Manual hooks + defconfig (idempotent)
if ! grep -q "ksu_handle_sys_reboot" kernel/reboot.c; then
	git apply "$HERE/0001-kernelsu-next-manual-hooks.patch"
	echo "[+] Applied manual hooks patch"
fi

# 3. Wire KernelSU-Next into drivers/ (same as kernel/setup.sh, but uses this checkout)
ln -sfn "$KSU_ROOT/kernel" drivers/kernelsu
grep -q "kernelsu" drivers/Makefile || printf '\nobj-$(CONFIG_KSU) += kernelsu/\n' >> drivers/Makefile
grep -q 'source "drivers/kernelsu/Kconfig"' drivers/Kconfig || \
	sed -i '0,/^endmenu/s//source "drivers\/kernelsu\/Kconfig"\n\nendmenu/' drivers/Kconfig

# 4. Build
MAKE=(make O=out ARCH=arm64 CC=clang HOSTCC=gcc
      CLANG_TRIPLE=aarch64-linux-gnu-
      CROSS_COMPILE=aarch64-linux-gnu-
      CROSS_COMPILE_ARM32=arm-linux-gnueabi-)
"${MAKE[@]}" "$DEFCONFIG"
grep -q "^CONFIG_KSU_MANUAL_HOOK=y" out/.config || { echo "CONFIG_KSU_MANUAL_HOOK not enabled"; exit 1; }
# Parallel builds of this 4.4 tree sometimes fail with a spurious
# ".tmp_*.ver: No such file" linker error; simply re-running make fixes it.
for attempt in 1 2 3; do
	"${MAKE[@]}" -j"$JOBS" > >(tee "$WORK/build.log") 2>&1 && break
	echo "[!] make failed (attempt $attempt), retrying..."
	[ "$attempt" = 3 ] && { echo "[-] build failed, see $WORK/build.log"; exit 1; }
done

IMAGE=out/arch/arm64/boot/Image.gz-dtb
[ -f "$IMAGE" ] || { echo "[-] $IMAGE not found, see $WORK/build.log"; exit 1; }
grep -q "Hook mode: Manual" "$WORK/build.log" || echo "[!] warning: did not see 'Hook mode: Manual' in log"

# 5. AnyKernel3 zip (kernel-only replacement, ramdisk untouched)
AK3="$WORK/AnyKernel3"
[ -d "$AK3" ] || git clone --depth=1 https://github.com/osm0sis/AnyKernel3 "$AK3"
rm -f "$AK3"/Image* "$AK3"/*.zip
cp "$HERE/anykernel.sh" "$AK3/anykernel.sh"
cp "$IMAGE" "$AK3/"
ZIP="$HERE/out/KernelSU-Next-dumpling-$(date +%Y%m%d-%H%M).zip"
(cd "$AK3" && zip -r9 "$ZIP" . -x '.git*' 'README.md' '*placeholder')
echo "[+] Done: $ZIP"
