 #
 # Script For Building Android arm64 Kernel
 #
 # Copyright (c) 2018-2020 Panchajanya1999 <rsk52959@gmail.com>
 #
 # Licensed under the Apache License, Version 2.0 (the "License");
 # you may not use this file except in compliance with the License.
 # You may obtain a copy of the License at
 #
 #      http://www.apache.org/licenses/LICENSE-2.0
 #
 # Unless required by applicable law or agreed to in writing, software
 # distributed under the License is distributed on an "AS IS" BASIS,
 # WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 # See the License for the specific language governing permissions and
 # limitations under the License.
 #

#! /bin/sh

#Kernel building script

set -euo pipefail

##------------------------------------------------------##
##----------Basic Informations, COMPULSORY--------------##

# The defult directory where the kernel should be placed
KERNEL_DIR=$PWD

# The name of the Kernel, to name the ZIP
ZIPNAME="azure"

# The name of the device for which the kernel is built
MODEL="Redmi Note 7 Pro"

# The codename of the device
DEVICE="violet"

# The defconfig which should be used. Get it from config.gz from
# your device or check source
DEFCONFIG=vendor/violet-perf_defconfig

# Clean source prior building. 1 is NO(default) | 0 is YES
INCREMENTAL=1

# Push ZIP to Telegram. 1 is YES | 0 is NO(default)
PTTG=1
	if [ $PTTG == 1 ]
	then
		# Set Telegram Chat ID
		CHATID="-1001245830369"
	fi

# Generate a full DEFCONFIG prior building. 1 is YES | 0 is NO(default)
DEF_REG=0

# Build dtbo.img (select this only if your source has support to building dtbo.img)
# 1 is YES | 0 is NO(default)
BUILD_DTBO=1

# Sign the zipfile
# 1 is YES | 0 is NO
SIGN=1
	if [ $SIGN == 1 ]
	then
			#Check java installed or not
			JAVAEXEC="/usr/bin/java"
			if [ ! -d $JAVAEXEC ]
			then
				# install java 8 via aptitude
				apt-get -y install openjdk-8-jdk;
			fi
	fi

# Check if we are using a dedicated CI ( Continuous Integration ), and
# set KBUILD_BUILD_VERSION
if [ $CI == true ]
then
	if [ $CIRCLECI == true ]
	then
		export KBUILD_BUILD_VERSION=$CIRCLE_BUILD_NUM
	fi
fi

##------------------------------------------------------##
##---------Do Not Touch Anything Beyond This------------##

# Set a commit head
COMMIT_HEAD=$(git log --oneline -1)

# Set Date 
DATE=$(TZ=Asia/Jakarta date +"%Y%m%d-%T")

#Now Its time for other stuffs like cloning, exporting, etc

function clone {
	echo " "
	echo "★★Cloning Azure Clang 11"
	git clone --depth=1 https://github.com/Panchajanya1999/clang-llvm.git clang-llvm

	# Toolchain Directory defaults to clang-llvm
	TC_DIR=$PWD/clang-llvm

	echo "★★Clang Done, Now Its time for AnyKernel .."
	git clone --depth 1 --no-single-branch https://github.com/Panchajanya1999/AnyKernel2.git -b $DEVICE
	echo "★★Cloning libufdt"
	git clone https://android.googlesource.com/platform/system/libufdt $KERNEL_DIR/scripts/ufdt/libufdt
	echo "★★Cloning Kinda Done..!!!"
}

##------------------------------------------------------##

function exports {
	export KBUILD_BUILD_USER="panchajanya"
	export KBUILD_BUILD_HOST="circleci"
	export ARCH=arm64
	export SUBARCH=arm64
	export KBUILD_COMPILER_STRING=$($TC_DIR/bin/clang --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')
	PATH=$TC_DIR/bin/:$PATH
	export PATH
	export BOT_MSG_URL="https://api.telegram.org/bot$token/sendMessage"
	export BOT_BUILD_URL="https://api.telegram.org/bot$token/sendDocument"
	export PROCS=$(nproc --all)
}

##---------------------------------------------------------##

function tg_post_msg {
	curl -s -X POST "$BOT_MSG_URL" -d chat_id="$2" \
	-d "disable_web_page_preview=true" \
	-d "parse_mode=html" \
	-d text="$1"

}

##----------------------------------------------------------------##

function tg_post_build {
	curl --progress-bar -F document=@"$1" $BOT_BUILD_URL \
	-F chat_id="$2"  \
	-F "disable_web_page_preview=true" \
	-F "parse_mode=html" \
	-F caption="$3"  
}

##----------------------------------------------------------##

function build_kernel {
	if [ $INCREMENTAL == 0 ]
	then
		make clean && make mrproper && rm -rf out
	fi

	if [ "$PTTG" == 1 ]
 	then
		tg_post_msg "<b>$CIRCLE_BUILD_NUM CI Build Triggered</b>%0A<b>Date : </b><code>$(TZ=Asia/Jakarta date)</code>%0A<b>Device : </b><code>$MODEL [$DEVICE]</code>%0A<b>Pipeline Host : </b><code>CircleCI</code>%0A<b>Host Core Count : </b><code>$PROCS</code>%0A<b>Compiler Used : </b><code>$KBUILD_COMPILER_STRING</code>%0a<b>Branch : </b><code>$CIRCLE_BRANCH</code>%0A<b>Top Commit : </b><code>$COMMIT_HEAD</code>%0A<b>Status : </b>#Nightly" "$CHATID"
	fi

	make O=out $DEFCONFIG
	if [ $DEF_REG == 1 ]
	then
		cp .config arch/arm64/configs/$DEFCONFIG
		git add arch/arm64/configs/$DEFCONFIG
		git commit -m "$DEFCONFIG: Regenerate
								This is an auto-generated commit"
	fi

	BUILD_START=$(date +"%s")
	make -j$PROCS O=out \
		CROSS_COMPILE=aarch64-linux-gnu- \
		CROSS_COMPILE_ARM32=arm-linux-gnueabi- \
		CC=clang \
		AR=llvm-ar \
		NM=llvm-nm \
		LD=ld.lld \
		OBJCOPY=llvm-objcopy \
		OBJDUMP=llvm-objdump \
		STRIP=llvm-strip 2>&1 | tee error.log
	if [ $BUILD_DTBO == 1 ]
	then
		tg_post_msg "Building DTBO.." "$CHATID"
		python2 "$KERNEL_DIR/scripts/ufdt/libufdt/utils/src/mkdtboimg.py" \
			create "$KERNEL_DIR/out/arch/arm64/boot/dtbo.img" --page_size=4096 "$KERNEL_DIR/out/arch/arm64/boot/dts/qcom/sm6150-idp-overlay.dtbo"
	fi
	BUILD_END=$(date +"%s")
	DIFF=$((BUILD_END - BUILD_START))
	check_img
}

##-------------------------------------------------------------##

function check_img {
	if [ -f $KERNEL_DIR/out/arch/arm64/boot/Image.gz-dtb ] 
	    then
		gen_zip
	else
		if [ "$PTTG" == 1 ]
 		then
			tg_post_build "error.log" "$CHATID" "<b>Build failed to compile after $((DIFF / 60)) minute(s) and $((DIFF % 60)) seconds</b>"
		fi
	fi
}

##--------------------------------------------------------------##

function gen_zip {
	mv $KERNEL_DIR/out/arch/arm64/boot/Image.gz-dtb AnyKernel2/Image.gz-dtb
	if [ $BUILD_DTBO == 1 ]
	then
		mv $KERNEL_DIR/out/arch/arm64/boot/dtbo.img AnyKernel2/dtbo.img
	fi
	cd AnyKernel2
	zip -r9 $ZIPNAME-$DEVICE-$DATE * -x .git README.md

	if [ $SIGN == 1 ]
	then
		## Sign the zip before sending it to telegram
		if [ "$PTTG" == 1 ]
 		then
 			tg_post_msg "Signing Zip file with AOSP keys.." "$CHATID"
 		fi
		curl -sLo zipsigner-3.0.jar https://raw.githubusercontent.com/baalajimaestro/AnyKernel2/master/zipsigner-3.0.jar
		java -jar zipsigner-3.0.jar $ZIPNAME-$DEVICE-$DATE.zip $ZIPNAME-$DEVICE-$DATE-signed.zip
	fi

	MD5CHECK=$(md5sum $ZIPNAME-$DEVICE-$DATE-signed.zip | cut -d' ' -f1)
	if [ "$PTTG" == 1 ]
 	then
		tg_post_build $ZIPNAME-$DEVICE-$DATE-signed.zip "$CHATID" "Build took : $((DIFF / 60)) minute(s) and $((DIFF % 60)) second(s) | MD5 Checksum : <code>$MD5CHECK</code>"
	fi
	cd ..
}

clone
exports
build_kernel

##----------------*****-----------------------------##
