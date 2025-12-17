#!/bin/bash

echo "[*] Creating compressed initramfs (rootfs.cpio.gz)..."
cd rootfs
find . | cpio -H newc -o | gzip > ../rootfs.cpio.gz
cd ..

echo "[*] Starting the VM with QEMU..."

KERNEL_PATH="linux-6.1.159/arch/x86/boot/bzImage"
ROOTFS_PATH="rootfs.cpio.gz"

# Accept a single argument: 1 to enable debug (-s -S), otherwise disabled
DEBUG_FLAGS=""
if [ "$1" = "1" ]; then
    DEBUG_FLAGS="-s -S"
    echo "[*] Debug enabled: $DEBUG_FLAGS"
else
    echo "[*] Debug disabled"
fi

qemu-system-x86_64 \
  -kernel "$KERNEL_PATH" \
  -initrd "$ROOTFS_PATH" \
  -m 512M \
  -cpu qemu64,+smep \
  -append "console=ttyS0 nosmap nopti panic=1" \
  -nographic \
  -fsdev local,id=shared_dev,path=shared,security_model=none \
  -device virtio-9p-pci,fsdev=shared_dev,mount_tag=shared \
  $DEBUG_FLAGS \
  -no-reboot


# mount -t 9p -o trans=virtio shared /mnt to mount the shared folder inside the VM