#!/bin/bash
set -e

echo "[*] Setting up pwn environment..."

# Create main directory
if [ ! -d "pwn_test" ]; then
    echo "[+] Creating pwn_test directory..."
    mkdir -p pwn_test
else
    echo "[!] pwn_test directory already exists"
fi

cd pwn_test

# Download kernel source
KERNEL_TAR="linux-6.1.159.tar.xz"
if [ ! -f "$KERNEL_TAR" ]; then
    echo "[+] Downloading kernel source..."
    wget https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.1.159.tar.xz
else
    echo "[!] $KERNEL_TAR already exists, skipping download"
fi

# Extract and build kernel
if [ ! -d "linux-6.1.159" ]; then
    echo "[+] Extracting kernel source..."
    tar xf linux-6.1.159.tar.xz
fi

cd linux-6.1.159

if [ ! -f ".config" ]; then
    echo "[+] Creating kernel config..."
    make defconfig
else
    echo "[!] Kernel config already exists"
fi

if [ ! -f "vmlinux" ]; then
    echo "[+] Building kernel (this may take a while)..."
    make -j$(nproc)
else
    echo "[!] Kernel already built"
fi

cd ..

# Create rootfs
if [ ! -d "rootfs" ]; then
    echo "[+] Creating rootfs directory structure..."
    mkdir -p rootfs/{bin,sbin,etc,proc,sys,dev,tmp,root,home,mnt}
else
    echo "[!] rootfs directory already exists"
fi

cd rootfs/bin

# Download busybox
if [ ! -f "busybox" ]; then
    echo "[+] Downloading busybox..."
    wget https://busybox.net/downloads/binaries/1.35.0-x86_64-linux-musl/busybox
    chmod +x busybox
else
    echo "[!] busybox already exists"
fi

# Create symlinks
if [ ! -L "ls" ]; then
    echo "[+] Creating busybox symlinks..."
    busybox --list | xargs -n1 ln -sf busybox
else
    echo "[!] Busybox symlinks already exist"
fi

# create init script in rootfs/etc
cd ../etc
if [ ! -f "init" ]; then
    echo "[+] Creating init script..."
    cat << 'EOF' > init
#!/bin/sh
mount -t proc proc /proc
mount -t sysfs sys /sys
mount -t devtmpfs dev /dev
mount -t tmpfs tmp /tmp
echo "=== Kernel RootForge VM Ready ==="
echo "=== By UG ==="
exec /bin/sh
EOF
    chmod +x init
else
    echo "[!] init script already exists"
fi  

cd ..

# Create rootfs archive
if [ ! -f "../rootfs.cpio.gz" ]; then
    echo "[+] Creating rootfs archive..."
    find . -print0 | cpio --null -ov --format=newc | gzip -9 > ../rootfs.cpio.gz
    echo "[+] Setup complete!"
else
    echo "[!] rootfs.cpio.gz already exists, skipping creation"
    echo "[+] Setup complete!"
fi

#create shared directory for qemu
if [ ! -d "../shared" ]; then
    echo "[+] Creating shared directory..."
    mkdir -p ../shared
else
    echo "[!] shared directory already exists"
fi
