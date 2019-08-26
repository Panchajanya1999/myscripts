# myscripts
[![Codacy Badge](https://api.codacy.com/project/badge/Grade/916a254720864c96ba0a4131c128f30c)](https://app.codacy.com/app/Panchajanya1999/myscripts?utm_source=github.com&utm_medium=referral&utm_content=Panchajanya1999/myscripts&utm_campaign=Badge_Grade_Settings)
## A useful script for building custom kernel for Android Devices
###### This is a script which I use to compile custom kenel for my devices. It was written keeping in mind about compiling a standalone kernel in CI Deployments. 

**Features of this script :**
  ~~~
  1. Device Specific Configuration
  2. Fetching the most needed stuffs like Toolchains(clang, gcc-arm64-4.9, gcc-arm-4.9) and Flasher(AnyKernel)(Device Specific)
  3. Integrate with Telegram
  4. Notifies when compilation starts with some useful informations
  5. Uploads build to Telegram
  ~~~
