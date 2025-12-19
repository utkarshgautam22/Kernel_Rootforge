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

CONFIG_FILE=".config"
if [ ! -f ".config" ]; then
    echo "[+] Creating kernel config..."
    make defconfig
else
    echo "[!] Kernel config already exists"
fi

# Only run debug configuration updates if script is invoked with -d
debug_flag=false
for arg in "$@"; do
    if [ "$arg" = "-d" ]; then
        debug_flag=true
        break
    fi
done

if [ "$debug_flag" = true ]; then
    echo "[*] Updating kernel debug options in $CONFIG_FILE"

    set_option() {
        local opt="$1"
        local val="$2"

        # If option exists as =y or =n, replace it
        if grep -qE "^${opt}=" "$CONFIG_FILE"; then
            sed -i "s/^${opt}=.*/${opt}=${val}/" "$CONFIG_FILE"
            return
        fi

        # If option exists as "# CONFIG_X is not set"
        if grep -qE "^# ${opt} is not set" "$CONFIG_FILE"; then
            sed -i "s/^# ${opt} is not set/${opt}=${val}/" "$CONFIG_FILE"
            return
        fi

        # Otherwise, append
        echo "${opt}=${val}" >> "$CONFIG_FILE"
    }

    # ===============================
    # REQUIRED DEBUG OPTIONS
    # ===============================
    set_option CONFIG_DEBUG_KERNEL y

    set_option CONFIG_DEBUG_INFO y
    set_option CONFIG_DEBUG_INFO_DWARF5 y
    set_option CONFIG_DEBUG_INFO_NONE n

    set_option CONFIG_STACKTRACE y
    set_option CONFIG_FRAME_POINTER y

    set_option CONFIG_DEBUG_VM y
    set_option CONFIG_DEBUG_VM_VMACACHE y

    set_option CONFIG_DEBUG_SPINLOCK y
    set_option CONFIG_DEBUG_MUTEXES y
    set_option CONFIG_DEBUG_ATOMIC_SLEEP y
    set_option CONFIG_DEBUG_LIST y

    echo "[+] Done. Run 'make olddefconfig' next."
    make olddefconfig
else
    echo "[*] -d flag not set, skipping kernel debug option updates"
fi

# Build the kernel

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
    busybox --list | grep -v '^busybox$' | xargs -r -n1 -I{} ln -sf busybox "{}"
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
mount -t 9p -o trans=virtio shared /mnt
echo "Installing pwn.ko module"
insmod /mnt/pwn.ko
chown root:root /bin/su
chmod +s /bin/su
echo "=== By UG ==="
exec /bin/sh
EOF
    chmod +x init
else
    echo "[!] init script already exists"
fi
cd ..
cp etc/init .

#Creating users usr,root
echo "[+] Creating users... usr and root"
echo "usr:x:1001:1001:usr:/home/usr:/bin/sh" > etc/passwd
echo "root:x:0:0:root:/root:/bin/sh" >> etc/passwd
mkdir -p home/usr

# Create rootfs archive
if [ ! -f "../rootfs.cpio.gz" ]; then
    echo "[+] Creating rootfs archive..."
    find . -print0 | cpio --null -ov --format=newc | gzip -9 > ../rootfs.cpio.gz
    echo "[+] Setup complete!"
else
    echo "[!] rootfs.cpio.gz already exists, skipping creation"
    echo "[+] Setup complete!"
fi

cd ..

#create shared directory for qemu
if [ ! -d "shared" ]; then
    echo "[+] Creating shared directory..."
    mkdir -p shared
else
    echo "[!] shared directory already exists"
fi

mv ../pwn.ko shared/ || echo "[!] pwn.ko not found, please place it in the shared directory manually"
mv ../vm_setup.sh . || echo "[!] vm_setup.sh not found, please place it in the pwn_test directory manually"
echo "[*] pwn environment is ready in pwn_test directory."
echo "[*] You can now proceed to run the VM using QEMU. vm_setup.sh is provided for that purpose."
