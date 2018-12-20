 #
 # Script For Building Android arm64 Kernel 
 #
 # Copyright (c) 2018-2019 Panchajanya1999 <rsk52959@gmail.com>
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

KERNEL_DIR=$PWD

function colors {
	blue='\033[0;34m' cyan='\033[0;36m'
	yellow='\033[0;33m'
	red='\033[0;31m'
	nocol='\033[0m'
}

colors;

function clone {
	echo " "
	echo "★★Cloning GCC Toolchain from Android GoogleSource .."
	sleep 2
	git clone --depth 1 --no-single-branch https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9.git
	echo "★★GCC cloning done"
	sleep 2
	echo "★★Cloning Clang 7 sources (r328903)"
	git clone --depth=1 https://github.com/Panchajanya1999/clang-r328903.git
	echo "★★Clang Done, Now Its time for AnyKernel .."
	git clone --depth=1 --no-single-branch https://github.com/Panchajanya1999/AnyKernel2.git
	echo "★★Cloning Kinda Done..!!!"
}

function exports {
	export KBUILD_BUILD_USER="ci"
	export KBUILD_BUILD_HOST="semaphore"
	export ARCH=arm64
	export SUBARCH=arm64
	export KBUILD_COMPILER_STRING=$($KERNEL_DIR/clang-r328903/bin/clang --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')
}

function tg_post_msg {
	curl -s -X POST "$BOT_MSG_URL" -d chat_id="$CHANNEL_ID" -d text="$1"
	curl -s -X POST "$BOT_MSG_URL" -d chat_id="$GROUP_ID" -d text="$1"
}

function tg_post_build {
	curl -F chat_id="$CHANNEL_ID" -F document=@"$1" $BOT_BUILD_URL
	curl -F chat_id="$GROUP_ID" -F document=@"$1" $BOT_BUILD_URL
}

function build_kernel {
	#better checking defconfig at first
	if [ -f $KERNEL_DIR/arch/arm64/configs/X00T_defconfig ]
	then 
		DEFCONFIG=X00T_defconfig
	elif [ -f $KERNEL_DIR/arch/arm64/configs/X00TD_defconfig ]
	then
		DEFCONFIG=X00TD_defconfig
	else
		echo "Defconfig Mismatch"
		tg_post_msg "☠☠Defconfig Mismatch..!! Build Failed..!!👎👎"
		echo "Exiting in 5 seconds"
		sleep 5
		exit
	fi
	
	make O=out $DEFCONFIG
	BUILD_START=$(date +"%s")
	tg_post_msg "★★Build Started on $(uname)"
	make -j8 O=out \
		CC=$KERNEL_DIR/clang-r328903/bin/clang \
		CLANG_TRIPLE=aarch64-linux-gnu- \
		CROSS_COMPILE=$KERNEL_DIR/aarch64-linux-android-4.9/bin/aarch64-linux-android-
	BUILD_END=$(date +"%s")
	BUILD_TIME=$(date +"%Y%m%d-%T")
	DIFF=$(($BUILD_END - $BUILD_START))	
}

function check_img {
	if [ -f $KERNEL_DIR/arch/arm64/boot/Image.gz-dtb ]
	then 
		echo -e "Kernel Built Successfully in $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) seconds..!!"
		tg_post_msg "Kernel Built Successfully in $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) seconds..!!"
		gen_changelog
	else 
		echo -e "Kernel failed to compile after $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) seconds..!!"
		tg_post_msg "Kernel failed to compile after $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) seconds..!!"
		exit
	fi	
}

function gen_changelog {
	tg_post_msg "★★ChangeLog --
	$(git log --oneline --decorate --color --pretty=%s --first-parent -7)"
}


clone
exports
build_kernel
check_img



