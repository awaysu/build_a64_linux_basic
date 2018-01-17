USER := $(shell whoami)
PWD := $(shell pwd)
PATH := $(PWD)/gcc-linaro-5.3.1-2016.05-x86_64_aarch64-linux-gnu/bin:$(PWD)/gcc-arm-linux-gnueabihf-4.7/bin:$(PATH)

A64_TOOLCHAIN_URL := https://releases.linaro.org/components/toolchain/binaries/5.3-2016.05/aarch64-linux-gnu/gcc-linaro-5.3.1-2016.05-x86_64_aarch64-linux-gnu.tar.xz
ARM_TOOLCHAIN_URL := https://github.com/awaysu/gcc-arm-linux-gnueabihf-4.7.git
A64_KERNEL_URL := https://github.com/awaysu/linux-pine64.git
BUSYBOX_URL := https://github.com/awaysu/busybox.git
BUILDROOT_URL := https://github.com/awaysu/buildroot.git
UBOOT_URL := https://github.com/awaysu/u-boot-pine64.git
A64_FIRMWARE_URL := https://github.com/awaysu/arm-trusted-firmware.git
SUNXI_TOOL_URL := https://github.com/awaysu/sunxi-pack-tools.git
START_TIME=$$(date +%s)


all: check download copy_files build_kernel build_uboot build_busyobx build_buildroot build_out build_img
	@echo "========================================================================="
	@echo "Build took $$(($$(date +%s)-START_TIME)) seconds"
	@echo
	
download:
	@if [ ! -d "./gcc-linaro-5.3.1-2016.05-x86_64_aarch64-linux-gnu" ]; then \
        wget $(A64_TOOLCHAIN_URL); \
		tar Jxvf gcc-linaro-5.3.1-2016.05-x86_64_aarch64-linux-gnu.tar.xz; \
		rm gcc-linaro-5.3.1-2016.05-x86_64_aarch64-linux-gnu.tar.xz; \
	fi
	@if [ ! -d "./gcc-arm-linux-gnueabihf-4.7" ]; then \
		git clone $(ARM_TOOLCHAIN_URL); \
	fi
	@if [ ! -d "./linux-pine64" ]; then \
		git clone --depth 1 --branch pine64-hacks-1.2 --single-branch $(A64_KERNEL_URL) linux-pine64; \
    fi
	@if [ ! -d "./busybox" ]; then \
		git clone $(BUSYBOX_URL) busybox; \
	fi
	@if [ ! -d "./buildroot" ]; then \
		git clone $(BUILDROOT_URL) buildroot; \
	fi
	@if [ ! -d "./u-boot-pine64" ]; then \
		git clone --depth 1 --branch pine64-hacks --single-branch $(UBOOT_URL) u-boot-pine64; \
	fi
	@if [ ! -d "./arm-trusted-firmware-pine64" ]; then \
		git clone --branch allwinner-a64-bsp --single-branch $(A64_FIRMWARE_URL) arm-trusted-firmware-pine64; \
	fi
	@if [ ! -d "./sunxi-pack-tools" ]; then \
		git clone $(SUNXI_TOOL_URL) sunxi-pack-tools; \
	fi
	
copy_files:
	cp files/install_kernel.sh linux-pine64
	cp files/make_initrd.sh busybox
	cp files/a64_busybox_config busybox/.config
	cp files/a64_buildroot_config buildroot/.config
	cp linux-pine64/arch/arm64/configs/sun50iw1p1smp_linux_defconfig linux-pine64/

clean:
	rm out -Rf
	@if [ -d "./linux-pine64" ]; then \
        make -C linux-pine64 clean; \
    fi
	@if [ -d "./busybox" ]; then \
        make -C  busybox clean; \
    fi
	@if [ -d "./buildroot" ]; then \
        make -C buildroot clean; \
    fi
	@if [ -d "./u-boot-pine64" ]; then \
      make -C u-boot-pine64 clean; \
    fi
	@if [ -d "./arm-trusted-firmware-pine64" ]; then \
      make -C arm-trusted-firmware-pine64 clean; \
    fi
	@if [ -d "./sunxi-pack-tools" ]; then \
      make -C sunxi-pack-tools clean; \
    fi
	
distclean:
	rm -rf gcc-linaro-5.3.1-2016.05-x86_64_aarch64-linux-gnu gcc-arm-linux-gnueabihf-4.7 linux-pine64 busybox buildroot u-boot-pine64 arm-trusted-firmware-pine64 sunxi-pack-tools out
	
build_kernel:
	@echo "[Build kernel ...]"
	make -C linux-pine64 ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- sun50iw1p1smp_linux_defconfig
	make -C linux-pine64 ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- -j4 LOCALVERSION= Image
	make -C linux-pine64 ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- -j4 LOCALVERSION= modules
	LICHEE_KDIR=$(PWD)/linux-pine64 ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- LICHEE_PLATFORM=Pine64 make -C linux-pine64/modules/gpu build
	
build_busyobx:
	@echo "[Build busyobx ...]"
	make -C busybox ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- -j4
	cd busybox;./make_initrd.sh;cd $(PWD)

build_buildroot:
	@echo "[Build buildroot ...]"
	make -C buildroot/

build_uboot:
	@echo "[Build u-boot-pine64 ...]"
	make -C u-boot-pine64 ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- sun50iw1p1_config
	make -C u-boot-pine64 ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf-
	make -C arm-trusted-firmware-pine64 ARCH=arm CROSS_COMPILE=aarch64-linux-gnu- PLAT=sun50iw1p1 bl31
	make -C sunxi-pack-tools
	cd $(PWD); $(PWD)/files/u-boot-postprocess.sh
	cp $(PWD)/blobs/boot0.bin $(PWD)/out/bootfile
	cp $(PWD)/files/update_command.sh $(PWD)/out/
	
build_out:
	@echo "[Create kernel and rootfs ...]"
	cd $(PWD)/linux-pine64;./install_kernel.sh $(PWD)/out/sdx1 .
	cp $(PWD)/buildroot/output/target/ $(PWD)/out/sdx2 -a
	cp $(PWD)/busybox/busybox $(PWD)/out/sdx2/bin/
	rm $(PWD)/out/sdx2/dev/console -Rf
	mknod -m 600 $(PWD)/out/sdx2/dev/console c 5 1
	mknod -m 666 $(PWD)/out/sdx2/dev/null c 1 3
	cd $(PWD)

check:
ifeq ($(USER),root)
	@echo "[Start build images ...]"
else
	@echo "[Please use root to build ...]"
	@sleep 9999
endif

build_img:
	@echo "[Create images ...]"
	mkdir out/image_tmp
	dd if=/dev/zero of=out/sdx1.fat32.img bs=1M count=50
	dd if=/dev/zero of=out/sdx2.ext4.img bs=1M count=100
	@echo "build sdx1.fat32.img"
	#mkfs.vfat out/sdx1.fat32.img
	mkfs.vfat -n BOOT out/sdx1.fat32.img
	mount out/sdx1.fat32.img out/image_tmp
	rsync -a --no-owner --no-group out/sdx1/* out/image_tmp
	umount out/image_tmp
	@echo "build sdx2.ext4.img"
	mkfs.ext4 -F out/sdx2.ext4.img
	mount out/sdx2.ext4.img out/image_tmp
	rsync -a --no-owner --no-group out/sdx2/* out/image_tmp
	umount out/image_tmp
	rm -rf out/image_tmp



