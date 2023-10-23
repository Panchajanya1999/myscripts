import os
import subprocess
from datetime import datetime

# Function to show an informational message
def msger(option, message):
    if option == "-n":
        print(f"[*] {message}")
    elif option == "-e":
        print(f"[x] {message}")
        return 1

# Change directory or show an error message
def cdir(directory):
    try:
        os.chdir(directory)
    except FileNotFoundError:
        msger("-e", f"The directory {directory} doesn't exist!")

# Basic Informations, COMPULSORY
KERNEL_DIR = os.getcwd()
BASEDIR = os.path.basename(KERNEL_DIR)
ZIPNAME = "azure"
AUTHOR = "Panchajanya1999"
ARCH = "arm64"
MODEL = "Redmi Note 7 Pro"
DEVICE = "violet"
DEFCONFIG = "vendor/violet-perf_defconfig"
COMPILER = "gcc"
MODULES = 0
LINKER = "ld.lld"
INCREMENTAL = 1
PTTG = 1 if INCREMENTAL == 1 else 0
CHATID = "-1001231303646" if PTTG == 1 else ""
DEF_REG = 0
FILES = "Image.gz-dtb"
BUILD_DTBO = 1 if BUILD_DTBO == 1 else 0
DTBO_PATH = "xiaomi/violet-sm6150-overlay.dtbo" if BUILD_DTBO == 1 else ""
SIGN = 1 if SIGN == 1 and subprocess.getoutput("hash java 2>/dev/null") else 0
SILENCE = 0
VERBOSE = 0
LOG_DEBUG = 0

# Do Not Touch Anything Beyond This

# Set defaults first
DISTRO = subprocess.getoutput("source /etc/os-release && echo $NAME")
KBUILD_BUILD_HOST = subprocess.getoutput("uname -a | awk '{print $2}'")
CI_BRANCH = subprocess.getoutput("git rev-parse --abbrev-ref HEAD")

# Set defaults for CI
if os.environ.get("CI"):
    if os.environ.get("CIRCLECI"):
        KBUILD_BUILD_VERSION = os.environ.get("CIRCLE_BUILD_NUM")
        KBUILD_BUILD_HOST = "CircleCI"
        CI_BRANCH = os.environ.get("CIRCLE_BRANCH")
    if os.environ.get("DRONE"):
        KBUILD_BUILD_VERSION = os.environ.get("DRONE_BUILD_NUMBER")
        KBUILD_BUILD_HOST = os.environ.get("DRONE_SYSTEM_HOST")
        CI_BRANCH = os.environ.get("DRONE_BRANCH")
        BASEDIR = os.environ.get("DRONE_REPO_NAME")
        SERVER_URL = f"{os.environ.get('DRONE_SYSTEM_PROTO')}://{os.environ.get('DRONE_SYSTEM_HOSTNAME')}/{AUTHOR}/{BASEDIR}/{KBUILD_BUILD_VERSION}"
    else:
        msger("-n", "Not presetting Build Version")

# Check Kernel Version
KERVER = subprocess.getoutput("make kernelversion")

# Set a commit head
COMMIT_HEAD = subprocess.getoutput("git log --oneline -1")

# Set Date
DATE = datetime.now().strftime("%Y%m%d-%T")

# Other stuff like cloning, exporting, etc.
def clone():
    print(" ")
    if COMPILER == "gcc":
        msger("-n", "|| Cloning GCC 9.3.0 baremetal ||")
        subprocess.run(["git", "clone", "--depth=1", "https://github.com/mvaisakh/gcc-arm64.git", "gcc64"])
        subprocess.run(["git", "clone", "--depth=1", "https://github.com/arter97/arm32-gcc.git", "gcc32"])
        GCC64_DIR = os.path.join(KERNEL_DIR, "gcc64")
        GCC32_DIR = os.path.join(KERNEL_DIR, "gcc32")
    elif COMPILER == "clang":
        msger("-n", "|| Cloning Clang-16||")
        subprocess.run(["git", "clone", "--depth=1", "https://gitlab.com/Panchajanya1999/azure-clang.git", "clang-llvm"])
        TC_DIR = os.path.join(KERNEL_DIR, "clang-llvm")

    msger("-n", "|| Cloning Anykernel ||")
    subprocess.run(["git", "clone", "--depth", "1", "--no-single-branch", f"https://github.com/{AUTHOR}/AnyKernel3.git"])

    if BUILD_DTBO == 1:
        msger("-n", "|| Cloning libufdt ||")
        subprocess.run(["git", "clone", "https://android.googlesource.com/platform/system/libufdt", os.path.join(KERNEL_DIR, "scripts/ufdt/libufdt")])

# Exports
def exports():
    global DISTRO, KBUILD_BUILD_HOST, CI_BRANCH
    DISTRO = subprocess.getoutput("source /etc/os-release && echo $NAME")
    KBUILD_BUILD_HOST = subprocess.getoutput("uname -a | awk '{print $2}'")
    CI_BRANCH = subprocess.getoutput("git rev-parse --abbrev-ref HEAD")

    KBUILD_BUILD_USER = AUTHOR
    SUBARCH = ARCH

    if COMPILER == "clang":
        KBUILD_COMPILER_STRING = subprocess.getoutput(f"{TC_DIR}/bin/clang --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//'")
        os.environ["PATH"] = f"{TC_DIR}/bin/:{os.environ['PATH']}"
    elif COMPILER == "gcc":
        KBUILD_COMPILER_STRING = subprocess.getoutput(f"{GCC64_DIR}/bin/aarch64-elf-gcc --version | head -n 1}")
        os.environ["PATH"] = f"{GCC64_DIR}/bin/:{GCC32_DIR}/bin/:/usr/bin:{os.environ['PATH']}"

    BOT_MSG_URL = "https://api.telegram.org/bot{token}/sendMessage"
    BOT_BUILD_URL = "https://api.telegram.org/bot{token}/sendDocument"
    PROCS = os.cpu_count()

    os.environ["KBUILD_BUILD_USER"] = KBUILD_BUILD_USER
    os.environ["ARCH"] = ARCH
    os.environ["SUBARCH"] = SUBARCH
    os.environ["PATH"] = os.environ["PATH"]
    os.environ["KBUILD_COMPILER_STRING"] = KBUILD_COMPILER_STRING
    os.environ["BOT_MSG_URL"] = BOT_MSG_URL
    os.environ["BOT_BUILD_URL"] = BOT_BUILD_URL
    os.environ["PROCS"] = PROCS

# Post message to Telegram
def tg_post_msg(message):
    payload = {
        "chat_id": CHATID,
        "disable_web_page_preview": "true",
        "parse_mode": "html",
        "text": message
    }
    subprocess.run(["curl", "-s", "-X", "POST", BOT_MSG_URL, *["-d", f"{key}={value}" for key, value in payload.items()]])

# Post build to Telegram
def tg_post_build(file_path, message):
    md5check = subprocess.getoutput(f"md5sum {file_path} | cut -d' ' -f1")
    payload = {
        "document": f"@{file_path}",
        "chat_id": CHATID,
        "disable_web_page_preview": "true",
        "parse_mode": "Markdown",
        "caption": f"{message} | *MD5 Checksum : *`{md5check}`"
    }
    subprocess.run(["curl", "--progress-bar", *["-F", f"{key}={value}" for key, value in payload.items()]])

# Build kernel
def build_kernel():
    global INCREMENTAL, PTTG, CHATID, DEF_REG, FILES, BUILD_DTBO, DTBO_PATH, SIGN, SILENCE, VERBOSE, LOG_DEBUG
    if INCREMENTAL == 0:
        msger("-n", "|| Cleaning Sources ||")
        subprocess.run(["make", "mrproper"])
        subprocess.run(["rm", "-rf", "out"])

    if PTTG == 1:
        tg_post_msg(f"<b>{KBUILD_BUILD_VERSION} CI Build Triggered</b>%0A<b>Docker OS: </b><code>{DISTRO}</code>%0A<b>Kernel Version : </b><code>{KERVER}</code>%0A<b>Date : </b><code>{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}</code>%0A<b>Device : </b><code>{MODEL} [{DEVICE}]</code>%0A<b>Pipeline Host : </b><code>{KBUILD_BUILD_HOST}</code>%0A<b>Host Core Count : </b><code>{PROCS}</code>%0A<b>Compiler Used : </b><code>{KBUILD_COMPILER_STRING}</code>%0A<b>Linker : </b><code>{LINKER}</code>%0a<b>Branch : </b><code>{CI_BRANCH}</code>%0A<b>Top Commit : </b><code>{COMMIT_HEAD}</code>%0A<a href='{SERVER_URL}'>Link</a>")

    subprocess.run(["make", f"O=out {DEFCONFIG}"])
    if DEF_REG == 1:
        subprocess.run(["cp", ".config", f"arch/arm64/configs/{DEFCONFIG}"])
        subprocess.run(["git", "add", f"arch/arm64/configs/{DEFCONFIG}"])
        subprocess.run(["git", "commit", "-m", f"{DEFCONFIG}: Regenerate\n\n\t\t\t\t\t\t\tThis is an auto-generated commit"])

    BUILD_START = datetime.now()

    MAKE = []
    if COMPILER == "clang":
        MAKE.extend([
            "CROSS_COMPILE=aarch64-linux-gnu-",
            "CROSS_COMPILE_ARM32=arm-linux-gnueabi-",
            "CC=clang",
            "AR=llvm-ar",
            "OBJDUMP=llvm-objdump",
            "STRIP=llvm-strip",
            "NM=llvm-nm",
            "OBJCOPY=llvm-objcopy",
            "LD={LINKER}"
        ])
    elif COMPILER == "gcc":
        MAKE.extend([
            "CROSS_COMPILE_ARM32=arm-eabi-",
            "CROSS_COMPILE=aarch64-elf-",
            "AR=aarch64-elf-ar",
            "OBJDUMP=aarch64-elf-objdump",
            "STRIP=aarch64-elf-strip",
            "NM=aarch64-elf-nm",
            "OBJCOPY=aarch64-elf-objcopy",
            "LD=aarch64-elf-{LINKER}"
        ])

    if SILENCE == 1:
        MAKE.append("-s")

    msger("-n", "|| Started Compilation ||")
    subprocess.run(["make", "-kj{PROCS} O=out V={VERBOSE} {' '.join(MAKE)}"], stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True)
    
    if MODULES == 1:
        msger("-n", "|| Started Compiling Modules ||")
        subprocess.run(["make", f"-j{PROCS} O=out {' '.join(MAKE)} modules_prepare"])
        subprocess.run(["make", f"-j{PROCS} O=out {' '.join(MAKE)} modules INSTALL_MOD_PATH={KERNEL_DIR}/out/modules"])
        subprocess.run(["make", f"-j{PROCS} O=out {' '.join(MAKE)} modules_install INSTALL_MOD_PATH={KERNEL_DIR}/out/modules"])
        subprocess.run(["find", f"{KERNEL_DIR}/out/modules", "-type", "f", "-iname", "'*.ko'", "-exec", "cp", "{}", "AnyKernel3/modules/system/lib/modules/"])

    BUILD_END = datetime.now()
    DIFF = BUILD_END - BUILD_START

    if os.path.isfile(f"{KERNEL_DIR}/out/arch/arm64/boot/{FILES}"):
        msger("-n", "|| Kernel successfully compiled ||")
        if BUILD_DTBO == 1:
            msger("-n", "|| Building DTBO ||")
            tg_post_msg("<code>Building DTBO..</code>")
            subprocess.run([f"python2 {KERNEL_DIR}/scripts/ufdt/libufdt/utils/src/mkdtboimg.py", "create", f"{KERNEL_DIR}/out/arch/arm64/boot/dtbo.img", "--page_size=4096", f"{KERNEL_DIR}/out/arch/arm64/boot/dts/{DTBO_PATH}"])
        gen_zip()
    else:
        if PTTG == 1:
            tg_post_build("error.log", f"*Build failed to compile after {DIFF.total_seconds() / 60} minute(s) and {DIFF.total_seconds() % 60} seconds*")

# Generate flashable zip
def gen_zip():
    msger("-n", "|| Zipping into a flashable zip ||")
    subprocess.run(["mv", f"{KERNEL_DIR}/out/arch/arm64/boot/{FILES}", f"{KERNEL_DIR}/AnyKernel3/{FILES}"])
    if BUILD_DTBO == 1:
        subprocess.run(["mv", f"{KERNEL_DIR}/out/arch/arm64/boot/dtbo.img", f"{KERNEL_DIR}/AnyKernel3/dtbo.img"])
    cdir(f"{KERNEL_DIR}/AnyKernel3")
    subprocess.run(["zip", "-r", f"{ZIPNAME}-{DEVICE}-{DATE}", ".", "-x", ".git*", "-x", "README.md", "-x", "*.zip"])

    ZIP_FINAL = f"{ZIPNAME}-{DEVICE}-{DATE}"

    if SIGN == 1:
        if PTTG == 1:
            msger("-n", "|| Signing Zip ||")
            tg_post_msg("<code>Signing Zip file with AOSP keys..</code>")
        subprocess.run(["curl", "-sLo", "zipsigner-3.0.jar", "https://github.com/Magisk-Modules-Repo/zipsigner/raw/master/bin/zipsigner-3.0-dexed.jar"])
        subprocess.run(["java", "-jar", "zipsigner-3.0.jar", f"{ZIP_FINAL}.zip", f"{ZIP_FINAL}-signed.zip"])
        ZIP_FINAL = f"{ZIP_FINAL}-signed"

    if PTTG == 1:
        tg_post_build(f"{ZIP_FINAL}.zip", f"Build took : {DIFF.total_seconds() / 60} minute(s) and {DIFF.total_seconds() % 60} second(s)")

clone()
exports()
build_kernel()

if LOG_DEBUG == 1:
    tg_post_build("error.log", CHATID, "Debug Mode Logs")
