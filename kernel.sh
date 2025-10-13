#!/bin/bash

set -e

# Telegram configuration
TG_CHANNEL="-1001231303646"
TG_BOT_TOKEN="817057403:AAHPg4e3LFMZVx_Epg4FTwFjLjSXfvsSOGM"

# Configuration
WORK_DIR="$HOME/kernel-build"
KERNEL_REPO="https://github.com/torvalds/linux.git"
JOBS=$(nproc)
BUILD_LOG="$WORK_DIR/build.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Function to send Telegram notification
send_telegram() {
    local message="$1"
    curl -s -X POST "https://api.telegram.org/bot${TG_BOT_TOKEN}/sendMessage" \
        -d chat_id="${TG_CHANNEL}" \
        -d text="${message}" \
        -d parse_mode="HTML" > /dev/null
}

# Function to send file via Telegram
send_telegram_file() {
    local file_path="$1"
    local caption="$2"
    curl -s -X POST "https://api.telegram.org/bot${TG_BOT_TOKEN}/sendDocument" \
        -F chat_id="${TG_CHANNEL}" \
        -F document=@"${file_path}" \
        -F caption="${caption}" > /dev/null
}

# Function to log with color
log() {
    local color="$1"
    local message="$2"
    echo -e "${color}[$(date '+%Y-%m-%d %H:%M:%S')] ${message}${NC}"
}

# Error handler
error_handler() {
    local line_no=$1
    log "$RED" "ERROR: Script failed at line $line_no"
    
    # Send build logs if they exist
    if [ -f "$WORK_DIR/build.log" ]; then
        send_telegram_file "$WORK_DIR/build.log" "Build FAILED at line $line_no"
    fi
    
    send_telegram "<b>FAILED</b>: Kernel build process failed at line $line_no"
    exit 1
}

trap 'error_handler ${LINENO}' ERR

log "$GREEN" "Starting Linux kernel build and boot process"

# Check dependencies
log "$YELLOW" "Checking dependencies..."
DEPS="git build-essential libncurses-dev bison flex libssl-dev libelf-dev qemu-system-x86 bc curl"
for dep in $DEPS; do
    if ! dpkg -l | grep -q "^ii  $dep"; then
        log "$RED" "Missing dependency: $dep"
        log "$YELLOW" "Please install with: sudo apt-get install $DEPS"
        exit 1
    fi
done

# Create working directory
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

# Clone kernel repository
if [ ! -d "linux" ]; then
    log "$YELLOW" "Cloning Linux kernel repository..."
    git clone --depth 1 "$KERNEL_REPO"
    log "$GREEN" "Repository cloned successfully"
else
    log "$YELLOW" "Repository already exists, updating..."
    cd linux
    git pull
    cd ..
fi

cd linux

# Get kernel version
KERNEL_VERSION=$(make kernelversion)
log "$GREEN" "Building kernel version: $KERNEL_VERSION"

# Send initial notification
send_telegram "<b>BUILD STARTED</b>

Kernel Version: $KERNEL_VERSION
Parallel Jobs: $JOBS
Status: Cloning, configuring, and compiling kernel..."

# Configure kernel
log "$YELLOW" "Configuring kernel..."
make defconfig

# Enable necessary options for basic boot
scripts/config --enable CONFIG_VIRTIO_PCI
scripts/config --enable CONFIG_VIRTIO_BLK
scripts/config --enable CONFIG_VIRTIO_NET
scripts/config --enable CONFIG_EXT4_FS
scripts/config --enable CONFIG_BINFMT_SCRIPT
scripts/config --enable CONFIG_BLK_DEV_INITRD
scripts/config --enable CONFIG_NET_9P
scripts/config --enable CONFIG_NET_9P_VIRTIO
scripts/config --enable CONFIG_9P_FS

log "$GREEN" "Kernel configured"

# Build kernel
log "$YELLOW" "Building kernel (this may take a while)..."
make -j${JOBS} 2>&1 | tee "$BUILD_LOG"
BUILD_STATUS=${PIPESTATUS[0]}

if [ $BUILD_STATUS -eq 0 ]; then
    log "$GREEN" "Kernel built successfully"
    send_telegram_file "$BUILD_LOG" "Kernel build completed successfully"
else
    log "$RED" "Kernel build failed"
    send_telegram_file "$BUILD_LOG" "Kernel build FAILED - see logs"
    exit 1
fi

# Create minimal initramfs
log "$YELLOW" "Creating minimal root filesystem..."
INITRAMFS_DIR="$WORK_DIR/initramfs"
rm -rf "$INITRAMFS_DIR"
mkdir -p "$INITRAMFS_DIR"
cd "$INITRAMFS_DIR"

# Create directory structure
mkdir -p bin sbin etc proc sys dev tmp

# Install busybox-static if not present
if ! dpkg -l | grep -q "^ii  busybox-static"; then
    log "$YELLOW" "Installing busybox-static..."
    sudo apt-get install -y busybox-static
fi

# Copy busybox-static
cp /bin/busybox bin/busybox
chmod +x bin/busybox

# Use busybox to install all applets
cd bin
./busybox --install -s .
cd ..

# Create init script with explicit busybox calls
cat > init << 'INITEOF'
#!/bin/busybox sh

/bin/busybox mount -t proc proc /proc
/bin/busybox mount -t sysfs sysfs /sys
/bin/busybox mount -t devtmpfs devtmpfs /dev

/bin/busybox echo "Linux kernel booted successfully"
/bin/busybox echo "Kernel version: $(/bin/busybox uname -r)"
/bin/busybox echo "System information:"
/bin/busybox uname -a
/bin/busybox echo ""
/bin/busybox echo "CPU information:"
/bin/busybox cat /proc/cpuinfo | /bin/busybox grep "model name" | /bin/busybox head -1
/bin/busybox echo ""
/bin/busybox echo "Memory information:"
/bin/busybox free -h
/bin/busybox echo ""

# Mount shared folder and save dmesg
/bin/busybox mkdir -p /mnt/shared
/bin/busybox mount -t 9p -o trans=virtio,version=9p2000.L shared /mnt/shared
/bin/busybox dmesg > /mnt/shared/dmesg.txt
/bin/busybox echo "Boot logs saved to shared folder"

/bin/busybox echo "Boot successful! Shutting down in 3 seconds..."
/bin/busybox sleep 3
/bin/busybox poweroff -f
INITEOF

chmod +x init

# Verify critical files exist
log "$YELLOW" "Verifying initramfs contents..."
ls -lh init bin/busybox bin/sh

# Create initramfs with proper structure
log "$YELLOW" "Creating initramfs archive..."
find . -print0 | cpio --null -o --format=newc 2>/dev/null | gzip -9 > "$WORK_DIR/initramfs.cpio.gz"

# Verify the archive was created
if [ ! -f "$WORK_DIR/initramfs.cpio.gz" ] || [ ! -s "$WORK_DIR/initramfs.cpio.gz" ]; then
    log "$RED" "Failed to create initramfs archive"
    exit 1
fi

log "$GREEN" "Initramfs created ($(du -h $WORK_DIR/initramfs.cpio.gz | cut -f1))"

# Boot kernel in KVM
log "$YELLOW" "Booting kernel in KVM..."

KERNEL_IMAGE="$WORK_DIR/linux/arch/x86/boot/bzImage"

# Send kernel image
log "$YELLOW" "Sending kernel image via Telegram..."
send_telegram_file "$KERNEL_IMAGE" "Kernel image: bzImage ($(du -h $KERNEL_IMAGE | cut -f1))"

# Create shared directory for dmesg output
SHARED_DIR="$WORK_DIR/shared"
mkdir -p "$SHARED_DIR"

log "$GREEN" "Starting QEMU/KVM..."
log "$YELLOW" "Kernel: $KERNEL_IMAGE"
log "$YELLOW" "Initramfs: $WORK_DIR/initramfs.cpio.gz"
log "$YELLOW" "Shared dir: $SHARED_DIR"
log "$GREEN" "----------------------------------------"

# Send final notification
send_telegram "<b>BUILD COMPLETE</b>

Kernel Version: $KERNEL_VERSION
Status: Compilation successful
Action: Booting kernel in QEMU/KVM now..."

# Boot the kernel (try KVM, fallback to TCG if unavailable)
if [ -e /dev/kvm ] && [ -r /dev/kvm ] && [ -w /dev/kvm ]; then
    KVM_FLAG="-enable-kvm"
    log "$GREEN" "Using KVM acceleration"
else
    KVM_FLAG=""
    log "$YELLOW" "KVM not available, using software emulation (slower)"
fi

qemu-system-x86_64 \
    $KVM_FLAG \
    -kernel "$KERNEL_IMAGE" \
    -initrd "$WORK_DIR/initramfs.cpio.gz" \
    -append "console=ttyS0 quiet" \
    -m 1G \
    -smp 2 \
    -virtfs local,path="$SHARED_DIR",mount_tag=shared,security_model=passthrough,id=shared \
    -nographic

QEMU_EXIT_CODE=$?

log "$GREEN" "KVM session ended"

# Send dmesg logs if available
if [ -f "$SHARED_DIR/dmesg.txt" ]; then
    log "$YELLOW" "Sending dmesg logs via Telegram..."
    send_telegram_file "$SHARED_DIR/dmesg.txt" "Kernel dmesg output from KVM boot"
else
    log "$RED" "dmesg.txt not found in shared directory"
fi

# Send completion notification
if [ $QEMU_EXIT_CODE -eq 0 ]; then
    send_telegram "<b>SUCCESS</b>

Kernel Version: $KERNEL_VERSION
Status: Kernel booted and ran successfully in QEMU/KVM
Exit Code: $QEMU_EXIT_CODE"
else
    send_telegram "<b>WARNING</b>

Kernel Version: $KERNEL_VERSION
Status: QEMU exited with non-zero code
Exit Code: $QEMU_EXIT_CODE"
fi

