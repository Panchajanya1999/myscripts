# myscript

Automated Linux kernel build, boot, and testing system with Telegram notifications.

## Overview

This script automates the complete workflow of downloading, building, and testing the Linux kernel from Linus Torvalds' official repository. It compiles the kernel, boots it in a QEMU/KVM virtual machine, captures all relevant logs, and sends comprehensive reports via Telegram.

## Features

- Downloads the latest Linux kernel from torvalds/linux repository
- Configures kernel with KVM-optimized settings
- Compiles kernel using all available CPU cores
- Creates minimal bootable initramfs with busybox
- Boots kernel in QEMU/KVM (with fallback to software emulation)
- Automatically captures and extracts dmesg logs from the running kernel
- Sends real-time Telegram notifications at each stage
- Uploads build logs, kernel image, and dmesg output to Telegram
- Handles errors gracefully with detailed failure notifications

## Prerequisites

### System Requirements

- Linux system (tested on Debian/Ubuntu)
- At least 20GB free disk space
- 4GB RAM minimum (8GB recommended)
- Internet connection for downloading kernel source
- Telegram bot and channel for notifications

### Required Packages

Install all dependencies:

```bash
sudo apt-get update
sudo apt-get install -y git build-essential libncurses-dev bison flex \
    libssl-dev libelf-dev qemu-system-x86 bc curl busybox-static
```

### Telegram Setup

1. Create a Telegram bot via BotFather and obtain the bot token
2. Create a Telegram channel or group
3. Add your bot to the channel/group as an administrator
4. Get the channel ID (use @userinfobot or other methods)

## Configuration

Edit the script and update the following variables with your Telegram credentials:

```bash
TG_CHANNEL="-1001231303646"      # Your Telegram channel ID
TG_BOT_TOKEN="817057403:AAH..."  # Your bot token
```

Optional configuration:

```bash
WORK_DIR="$HOME/kernel-build"    # Working directory
KERNEL_REPO="https://github.com/torvalds/linux.git"  # Kernel repository
JOBS=$(nproc)                     # Number of parallel compilation jobs
```

## Usage

### Basic Usage

Make the script executable and run it:

```bash
chmod +x myscript
./myscript
```

### What Happens

1. Script checks for all required dependencies
2. Clones or updates the Linux kernel repository
3. Configures kernel with default and KVM-specific options
4. Compiles the kernel (takes 30-60 minutes on first run)
5. Creates a minimal initramfs with busybox
6. Boots the kernel in QEMU/KVM
7. Kernel runs for 3 seconds, displays system info, and shuts down
8. dmesg logs are extracted and saved
9. All logs and files are uploaded to Telegram

### Telegram Notifications

You will receive the following messages and files:

**Messages:**
1. BUILD STARTED - Initial notification with kernel version
2. BUILD COMPLETE - Compilation finished, starting boot
3. SUCCESS/WARNING - Final status after kernel boot

**Files:**
1. build.log - Complete compilation logs (pass or fail)
2. bzImage - The compiled kernel binary
3. dmesg.txt - Kernel boot logs from the virtual machine

## Output Files

All files are stored in the working directory:

```
~/kernel-build/
├── linux/                      # Kernel source code
├── initramfs/                  # Initramfs root filesystem
├── initramfs.cpio.gz          # Compressed initramfs
├── build.log                  # Compilation logs
└── shared/
    └── dmesg.txt              # Kernel boot logs
```

## Kernel Configuration

The script enables the following kernel options for proper KVM boot:

- CONFIG_VIRTIO_PCI - VirtIO PCI support
- CONFIG_VIRTIO_BLK - VirtIO block device
- CONFIG_VIRTIO_NET - VirtIO network device
- CONFIG_EXT4_FS - Ext4 filesystem
- CONFIG_BINFMT_SCRIPT - Script execution support
- CONFIG_BLK_DEV_INITRD - Initial RAM disk support
- CONFIG_NET_9P - Plan 9 protocol (for shared folders)
- CONFIG_NET_9P_VIRTIO - VirtIO transport for 9P
- CONFIG_9P_FS - Plan 9 filesystem

## Troubleshooting

### KVM Not Available

If you see "KVM not available, using software emulation":
- Check if virtualization is enabled in BIOS
- Load KVM modules: `sudo modprobe kvm kvm_intel` (or kvm_amd)
- Verify `/dev/kvm` exists and is accessible
- Software emulation will work but will be slower

### Build Failures

If compilation fails:
- Check build.log for detailed error messages
- Ensure all dependencies are installed
- Verify you have enough disk space
- Try reducing parallel jobs: edit JOBS variable

### Missing dmesg.txt

If dmesg logs are not captured:
- Verify 9P filesystem support is compiled in kernel
- Check shared directory permissions
- Review QEMU output for mount errors

### Telegram Upload Issues

If files don't appear in Telegram:
- Verify bot token and channel ID are correct
- Ensure bot has admin rights in the channel
- Check internet connectivity
- Review curl output for API errors

## Customization

### Change Kernel Version

To build a specific kernel version or branch:

```bash
cd ~/kernel-build/linux
git fetch --all
git checkout v6.6  # or any tag/branch
cd ..
./myscript
```

### Modify Boot Time

Edit the init script section and change the sleep duration:

```bash
/bin/busybox sleep 3  # Change to desired seconds
```

### Keep Interactive Shell

To boot into an interactive shell instead of auto-shutdown, replace the init script poweroff line with:

```bash
exec /bin/busybox sh
```

Then use Ctrl+A followed by X to exit QEMU manually.

### Adjust VM Resources

Modify QEMU parameters in the script:

```bash
-m 1G      # Memory (change to 2G, 4G, etc.)
-smp 2     # CPU cores (change to 4, 8, etc.)
```

## Performance Notes

- First build: 30-60 minutes (downloads ~3GB source, compiles entire kernel)
- Subsequent builds: 5-15 minutes (only recompiles changed files)
- KVM acceleration: Near-native performance
- Software emulation: 10-50x slower than KVM

## Security Considerations

- Keep your Telegram bot token private
- Never commit the script with credentials to public repositories
- The script requires internet access to download kernel source
- QEMU runs in user mode, no root privileges for VM itself

## License

This script is provided as-is for educational and development purposes. The Linux kernel itself is licensed under GPL v2.

## Contributing

Feel free to modify and improve this script for your needs. Common enhancements:
- Support for different kernel configurations (tinyconfig, allmodconfig)
- Multiple architecture support (arm64, riscv)
- Custom kernel patches application
- Parallel testing of multiple kernel versions
- Integration with CI/CD pipelines

## Credits

- Linux kernel: Linus Torvalds and contributors
- QEMU: Fabrice Bellard and QEMU team
- BusyBox: BusyBox contributors

## Support

For issues related to:
- Kernel compilation: Check Linux kernel documentation
- QEMU usage: Refer to QEMU documentation
- Telegram bot: See Telegram Bot API documentation
- This script: Review the troubleshooting section above

