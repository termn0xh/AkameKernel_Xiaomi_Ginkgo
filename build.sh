#!/usr/bin/env bash
#
# Copyright (C) 2023 Edwiin Kusuma Jaya (ryuzenn)
#
# Simple Local Kernel Build Script
#
# Configured for Redmi Note 8 / ginkgo custom kernel source
#
# Setup build env with akhilnarang/scripts repo
#
# Use this script on root of kernel directory

SECONDS=0 # builtin bash timer
LOCAL_DIR=/opt/munir/
ZIPNAME="AkameKernel-ginkgo-$(TZ=Asia/Baku date +"%Y%m%d-%H%M").zip"
ZIPNAME_KSU="AkameKernel-ginkgo-KSU-$(TZ=Asia/Baku date +"%Y%m%d-%H%M").zip"
TC_DIR="${LOCAL_DIR}toolchain"
NEUTRON_DIR="${TC_DIR}/Azure"
AK3_DIR="$HOME/tc/Anykernel"
DEFCONFIG="nethunter_defconfig"

export KBUILD_BUILD_USER="termnh"
export KBUILD_BUILD_HOST="Ubuntu"
export KBUILD_BUILD_VERSION="1"
export LOCALVERSION

# Setup Neutron Clang
if ! [ -d "${NEUTRON_DIR}" ]; then
echo "Neutron Clang not found! Setting up to ${TC_DIR}..."
mkdir -p ${TC_DIR}
cd ${TC_DIR}

curl -LO "https://raw.githubusercontent.com/Neutron-Toolchains/antman/main/antman" || exit 1
chmod +x antman

echo 'Setting up neutron toolchain in '${TC_DIR}
bash antman -S || exit 1

echo 'Build libarchive for bsdtar'
git clone https://github.com/libarchive/libarchive || true
cd libarchive
bash build/autogen.sh
./configure
make -j$(nproc)
cd ..

echo 'Patch for glibc'
wget https://gist.githubusercontent.com/itsHanibee/fac63ea2fc0eca7b8d7dcbb7eb678c3b/raw/beacf8f0f71f4e8231eaa36c3e03d2bee9ae3758/patch-for-old-glibc.sh
export PATH=$(pwd)/libarchive:$PATH
bash patch-for-old-glibc.sh

cd $KERNEL_PATH
fi

# Set PATH for Neutron Clang
export PATH="${NEUTRON_DIR}/bin:$PATH"
export USE_HOST_LEX=yes

if [[ $1 = "-k" || $1 = "--ksu" ]]; then
	echo -e "\nCleanup KernelSU first on local build\n"
	rm -rf KernelSU drivers/kernelsu
	git restore .
else
	echo -e "\nSet No KernelSU Install, just skip\n"
fi

# Set function for override kernel name and variants
if [[ $1 = "-k" || $1 = "--ksu" ]]; then
echo -e "\nKSU Support, let's Make it On\n"
curl -kLSs "https://raw.githubusercontent.com/kutemeikito/KernelSU-Next/next/kernel/setup.sh" | bash -s next
git apply KernelSU-hook.patch
sed -i 's/CONFIG_KSU=n/CONFIG_KSU=y/g' arch/arm64/configs/vendor/ginkgo-perf_defconfig
sed -i 's/CONFIG_LOCALVERSION="-EklerKernel"/CONFIG_LOCALVERSION="-EklerKernel-KSU"/g' arch/arm64/configs/vendor/ginkgo-perf_defconfig
else
echo -e "\nKSU not Support, let's Skip\n"
fi

mkdir -p out
make O=out ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- LLVM=1 $DEFCONFIG

echo -e "\nStarting compilation...\n"
make -j$(nproc) O=out \
					  ARCH=arm64 \
					  CC=clang \
					  LLVM=1 \
					  LLVM_IAS=1 \
					  AR=llvm-ar \
					  NM=llvm-nm \
					  OBJCOPY=llvm-objcopy \
					  OBJDUMP=llvm-objdump \
					  STRIP=llvm-strip \
					  LD=ld.lld \
					  CROSS_COMPILE=aarch64-linux-gnu- \
					  CROSS_COMPILE_ARM32=arm-linux-gnueabi- \
					  Image.gz-dtb \
					  dtbo.img

if [ -f "out/arch/arm64/boot/Image.gz-dtb" ] && [ -f "out/arch/arm64/boot/dtbo.img" ]; then
echo -e "\nKernel compiled succesfully! Zipping up...\n"
git restore arch/arm64/configs/nethunter_defconfig
if [ -d "$AK3_DIR" ]; then
cp -r $AK3_DIR Anykernel
elif ! git clone -q https://github.com/termn0xh/Anykernel.git -b ginkgo-udc; then
echo -e "\nAnyKernel repo not found locally and cloning failed! Aborting..."
exit 1
fi
cp out/arch/arm64/boot/Image.gz-dtb Anykernel
cp out/arch/arm64/boot/dtbo.img Anykernel
rm -f *zip
cd Anykernel
git checkout master &> /dev/null
if [[ $1 = "-k" || $1 = "--ksu" ]]; then
zip -r9 "../$ZIPNAME_KSU" * -x .git README.md *placeholder
else
zip -r9 "../$ZIPNAME" * -x .git README.md *placeholder
fi
cd ..
rm -rf Anykernel
rm -rf out/arch/arm64/boot
echo -e "Build OK"
echo -e "Completed in $((SECONDS / 60)) minute(s) and $((SECONDS % 60)) second(s) !"
if [[ $1 = "-k" || $1 = "--ksu" ]]; then
echo "Zip: $ZIPNAME_KSU"
else
echo "Zip: $ZIPNAME"
fi
else
echo -e "\nCompilation failed!"
exit 1
fi
echo "Move Zip into Home Directory"
mv *.zip ${LOCAL_DIR}
echo -e "======================================="
