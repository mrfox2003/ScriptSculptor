#!/bin/bash

set -e

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ "$1" == "-ksu" ]]; then
    KERNEL_DIR="$BASE_DIR/kernelsu"
else
    KERNEL_DIR="$BASE_DIR/kernel"
fi

DEFCONFIG="arch/arm64/configs/vendor/sweet_user_defconfig"
OUT_DEFCONFIG="out/defconfig"

cd "$KERNEL_DIR"

echo "========================================"
echo " Regenerating defconfig"
echo " Directory: $KERNEL_DIR"
echo " Defconfig: $DEFCONFIG"
echo "========================================"
echo

echo "==> Loading defconfig..."
make O=out ARCH=arm64 vendor/sweet_user_defconfig

echo
echo "==> Generating minimal defconfig..."
make O=out ARCH=arm64 savedefconfig

echo
echo "==> Checking for changes..."

if cmp -s "$DEFCONFIG" "$OUT_DEFCONFIG"; then
    echo
    echo "No changes needed."
    exit 0
fi

echo
echo "Changes detected:"
echo "----------------------------------------"

diff -u "$DEFCONFIG" "$OUT_DEFCONFIG" || true

echo "----------------------------------------"
echo
echo "==> Updating original defconfig..."

cp "$OUT_DEFCONFIG" "$DEFCONFIG"

echo
echo "Defconfig updated successfully."
