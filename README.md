# Formative Kernel Building Script
[![Codacy Badge](https://api.codacy.com/project/badge/Grade/916a254720864c96ba0a4131c128f30c)](https://app.codacy.com/app/Panchajanya1999/myscripts?utm_source=github.com&utm_medium=referral&utm_content=Panchajanya1999/myscripts&utm_campaign=Badge_Grade_Settings)
## A useful script for building custom kernel for Android Devices
### This is a script which I use to compile custom kenel for my devices'.' It was written keeping in mind about compiling a standalone kernel in CI Deployments'.'

**Features of this script :**
  ~~~
  1. Device Specific Configuration
  2. Fetching the most needed stuffs like Toolchains(clang, gcc-arm64-4.9, gcc-arm-4.9) and Flasher(AnyKernel)(Device Specific)
  3. Integrate with Telegram
  4. Notifies when compilation starts with some useful informations
  5. Uploads build to Telegram
  ~~~
## How to use this script

```
  1. This script has most of it's stuffs in "Basic Information" part. In a nutshell, 

        KERENL_DIR - Points to the working directory, literally inside the actual kernel 
                     source.

        ZIPNAME    - This is literally the name of our kernel which you would prefer. This
                     applies to the name of the zip too.

        MODEL      - Name of your device, which is known to the market.

        DEVICE     - The codename of your device. 

        DEFCONFIG  - To build a kernel, you need a defconfig. It defines the defconfig which
                     you will need to build kernel. In case your source has the defconfig 
                     inside /arch/arm64/configs/vendor , then you need to set it as
                     '/vendor/<name of your defconfig>'

        INCREMENTAL- Whether you are going to clean your local source each time prior building
                     or not.

                     1 - No, You are not going to clean. Faster building times [ dirty ]
                     0 - Yeah, You are going to clean local everytime [ clean ]

        PTTG       - Abbreviation of Push To Telegram.
                     It is a general notifier, notifying you about build initialisation. Also
                     it delivers the ZIP file of the kernel.

                     CHATID - When you enable PTTG, you define the ID of your respective
                     group or channel where you want to push the build. You can use Plus
                     Messenger and get  the ID of your group.
                     It is formatted as "-100<your chat ID>"
                     E.G. my chat ID is 1234567890, the I set it as "-1001234567890"

                     1 - Yes, push to telegram ( set CHATID, else everything in vain)
                     0 - No, thanks

        DEF_REG    - It generates a full defconfig from your provided defconfig and replaces
                     it with your main defconfig.

                     1 - Yes, generate a defconfig
                     0 - No, thanks

        BUILD_DTBO - It builds a DTBO image, only flashable via AnyKernel. It is WIP and I 
                     should suggest you to keep it off

                     1 - Yes, build DTBO
                     0 - No, thanks

          
  2. You should take care of the AnyKernel repository the script is cloning. You should have
     a working AnyKernel, setup for your device on a branch which is named the codename of your 
     device or DEVICE. Else you are pretty fucked up. I dont care if you fuck up here

  3. After you finish setting up the script as per your requirements, run this in your local
          source kernel.sh
          
```