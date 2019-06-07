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
ARG1=$1 #It is the devicename [generally codename]
ARG2=$2 #It is the make arguments, whether CLEAN / DIRTY / DEF_REG[regenerates defconfig]
ARG3=$3 #Build should be pushed or not [PUSH / !PUSH]
DATE=$(TZ=Asia/Jakarta date +"%Y%m%d-%T")
DIFF=$((BUILD_END - BUILD_START))

##----------------------------------------------------##

# START : Arguments Check
if [ $# -lt 3 ] # 3 arguments is must
  then
        echo -e "\nToo less Arguments..!! Provided - $# , Required - 3\nCheck README"
        return
  #Get outta
elif [ $# == 3 ]
  then
# START : Argument 1 [ARG1] Check
case "$ARG1" in
  "violet" ) # Execute violet function / scripts
      export DEVICE="Redmi Note 7 Pro [violet]"
      DEFCONFIG=vendor/violet-perf_defconfig
      CHATID="-1001260378423"
  ;;
  "X00T" ) # Execute X00T function / scripts
      export DEVICE="ASUS Zenfone Max Pro M1"
      DEFCONFIG=X00T_defconfig
      CHATID="-1001181445763"
  ;;
  * ) echo -e "\nError..!! Unknown device. Please add device details to script and re-execute\n"
      return
  ;;
esac # END : Argument 1 [ARG2] Check

##----------------------------------------------------##

# START : Argument 2 [ARG1] Check
case "$ARG2" in
  "CLEAN" ) # Execute Clean build function
      alias MAKE="make clean && make mrproper && rm -rf out"
  ;;
  "DIRTY" ) # Do not CLEAN
      
  ;;
  "DEF_REG" ) # Regenerate defconfig
      make O=out $DEFCONFIG
      mv out/.config $DEFCONFIG
      echo "Defconfig Regenerated"
      return;
  ;;
  * ) echo -e "\nError..!! Unknown Build Command.\n"
      return
  ;;
esac # END : Argument 2 [ARG2] Check

##---------------------------------------------------##

#START : Argument 3 [ARG3] Check
case "$ARG3" in
  "PUSH" ) # Push build to TG Channel
      build_push=true
  ;;
  "!PUSH" ) # Do not push
      build_push=false
  ;;
  * ) echo -e "\nError..!! Unknown command. Please refer README.\n"
      return
  ;;
esac # END : Argument 3 [ARG3] Check

##-----------------------------------------------------##

else
  echo -e "\nToo many Arguments..!! Provided - $# , Required - 3\nCheck README"
  return
#Get outta
fi

##------------------------------------------------------##

#Now Its time for other stuffs like cloning, exporting, etc

function clone {
	echo " "
	echo "★★Cloning GCC Toolchain from Android GoogleSource .."
	git clone --depth 5 --no-single-branch https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9.git
	git clone --depth 5 --no-single-branch https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/arm/arm-linux-androideabi-4.9

	#Workaround to remove deprecation spam of gcc
	cd aarch64-linux-android-4.9
	git reset --hard 22f053ccdfd0d73aafcceff3419a5fe3c01e878b
	cd ../arm-linux-androideabi-4.9
	git reset --hard 42e5864a7d23921858ca8541d52028ff88acb2b6
	cd $KERNEL_DIR

	echo "★★GCC cloning done"
	echo ""
	echo "★★Cloning Clang 8 sources"
	git clone --depth 1 https://github.com/Panchajanya1999/clang-llvm.git -b 8.0
	echo "★★Clang Done, Now Its time for AnyKernel .."
	git clone --depth 1 --no-single-branch https://github.com/Panchajanya1999/AnyKernel2.git -b $ARG1
	echo "★★Cloning Kinda Done..!!!"
}

##------------------------------------------------------##

function exports {
	export KBUILD_BUILD_USER="panchajanya"
	export KBUILD_BUILD_HOST="circleci"
	export ARCH=arm64
	export SUBARCH=arm64
	export KBUILD_COMPILER_STRING=$($KERNEL_DIR/clang-llvm/bin/clang --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')
	LD_LIBRARY_PATH=$KERNEL_DIR/clang-llvm/lib64:$LD_LIBRARY_PATH
	export LD_LIBRARY_PATH
	PATH=$KERNEL_DIR/clang-llvm/bin/:$KERNEL_DIR/aarch64-linux-android-4.9/bin/:$PATH
	export PATH
	export BOT_MSG_URL="https://api.telegram.org/bot$token/sendMessage"
	export BOT_BUILD_URL="https://api.telegram.org/bot$token/sendDocument"
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
	curl -F chat_id="$2" -F document=@"$1" \
	-F "disable_web_page_preview=true" \
	-F "parse_mode=html" \
	-F caption="$3" \
	 $BOT_BUILD_URL
}

##----------------------------------------------------------##

function build_kernel {
	if [ "$build_push" = true ]; then
		tg_post_msg "<b>CI Build Triggered</b>%0A<b>Date : </b><code>$(TZ=Asia/Jakarta date)</code>%0A<b>Device : </b><code>$DEVICE</code>%0A<b>Pipeline Host : </b><code>CircleCI</code>%0A<b>Compiler Used : </b><code>$KBUILD_COMPILER_STRING</code>%0A<b>Status : </b><code>#Nightly</code>" "$CHATID"
	fi
	make O=out $DEFCONFIG
	BUILD_START=$(date +"%s")
	make -j8 O=out \
		CC=$KERNEL_DIR/clang-llvm/bin/clang \
		CLANG_TRIPLE=aarch64-linux-gnu- \
		CROSS_COMPILE_ARM32=$KERNEL_DIR/arm-linux-androideabi-4.9/bin/arm-linux-androideabi- \
		CROSS_COMPILE=$KERNEL_DIR/aarch64-linux-android-4.9/bin/aarch64-linux-android- 2>&1 | tee build.log
	BUILD_END=$(date +"%s")
}

##-------------------------------------------------------------##

function check_img {
	if [ -f $KERNEL_DIR/out/arch/arm64/boot/Image.gz-dtb ] 
	    then
		gen_zip
	else
		tg_post_build "build.log" "$CHATID" "<b>Build failed to compile after $((DIFF / 60)) minute(s) and $((DIFF % 60)) seconds</b>"
	fi
}

##--------------------------------------------------------------##

function gen_zip {
	mv $KERNEL_DIR/out/arch/arm64/boot/Image.gz-dtb AnyKernel2/Image.gz-dtb
	cd AnyKernel2
	zip -r9 azure-$ARG1-$DATE * -x .git README.md
	ZIP=$(echo azure-*.zip)
	MD5CHECK=md5sum $ZIP | grep -v "$ZIP"
	tg_post_build "$ZIP" "$GROUP_ID" "<b>Build took : </b><code>$((DIFF / 60)) minute(s) and $((DIFF % 60)) seconds</code>%0A<b>md5check sum : </b><code>$MD5CHECK</code>s"
	cd ..
}

clone
exports
build_kernel
check_img

##----------------*****-----------------------------##
