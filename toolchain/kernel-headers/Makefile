# 
# Copyright (C) 2006-2009 OpenWrt.org
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#
include $(TOPDIR)/rules.mk

KERNEL_BUILD_DIR := $(BUILD_DIR_TOOLCHAIN)
BUILD_DIR := $(KERNEL_BUILD_DIR)

override QUILT:=
override HOST_QUILT:=

include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=linux
PKG_VERSION:=$(LINUX_VERSION)
PKG_SOURCE:=$(LINUX_SOURCE)
PKG_CPE_ID:=cpe:/o:linux:linux_kernel
ifneq ($(call qstrip,$(CONFIG_KERNEL_GIT_CLONE_URI)),)
  PKG_SOURCE_PROTO:=git
  PKG_SOURCE_URL:=$(call qstrip,$(CONFIG_KERNEL_GIT_CLONE_URI))
  PKG_SOURCE_VERSION:=$(call qstrip,$(CONFIG_KERNEL_GIT_REF))
  PKG_MIRROR_HASH:=$(call qstrip,$(CONFIG_KERNEL_GIT_MIRROR_HASH))
ifdef CHECK
  PLATFORM_DIR:=$(firstword $(wildcard $(TOPDIR)/target/linux/feeds/$(BOARD) $(TOPDIR)/target/linux/$(BOARD)))
  include $(PLATFORM_DIR)/Makefile
  include $(INCLUDE_DIR)/kernel-version.mk
  include $(INCLUDE_DIR)/kernel-build.mk
  PKG_VERSION:=$(LINUX_VERSION)
else
  PKG_SOURCE:=$(LINUX_SOURCE)
endif
else
  PKG_SOURCE:=$(LINUX_SOURCE)
  PKG_SOURCE_URL:=$(LINUX_SITE)
endif
HOST_BUILD_DIR:=$(KERNEL_BUILD_DIR)/linux-$(LINUX_VERSION)
PKG_HASH:=$(LINUX_KERNEL_HASH)
LINUX_DIR := $(HOST_BUILD_DIR)
FILES_DIR := 
PATCH_DIR := ./patches$(if $(wildcard ./patches-$(LINUX_VERSION)),-$(LINUX_VERSION))

include $(INCLUDE_DIR)/toolchain-build.mk
include $(INCLUDE_DIR)/kernel-defaults.mk

ifeq ($(strip $(BOARD)),uml)
  LINUX_KARCH:=$(subst x86_64,x86,$(subst i386,x86,$(ARCH)))
endif

HOST_EXTRACFLAGS=

LINUX_HAS_HEADERS_INSTALL:=y

HOST_KMAKE := $(MAKE) -C $(HOST_BUILD_DIR) \
	$(KERNEL_MAKE_FLAGS) \
	CC="$(KERNEL_CC)" \
	HOSTCFLAGS="$(HOST_CFLAGS)"

ifneq ($(DISABLE_KERNEL_BUILD),1)

define Host/Configure/all
	mkdir -p $(BUILD_DIR_TOOLCHAIN)/linux-dev
	$(HOST_KMAKE) \
		INSTALL_HDR_PATH="$(BUILD_DIR_TOOLCHAIN)/linux-dev/" \
		headers_install
endef

# XXX: the following is needed to build lzma-loader
ifneq ($(CONFIG_mips)$(CONFIG_mipsel),)
  define Host/Configure/lzma
	$(CP) \
		$(HOST_BUILD_DIR)/arch/mips/include/asm/asm.h \
		$(HOST_BUILD_DIR)/arch/mips/include/asm/regdef.h \
		$(HOST_BUILD_DIR)/arch/mips/include/asm/asm-eva.h \
		$(HOST_BUILD_DIR)/arch/mips/include/asm/isa-rev.h \
		$(BUILD_DIR_TOOLCHAIN)/linux-dev/include/asm/
  endef
endif

define Host/Configure/post/mips
	$(call Host/Configure/lzma)
endef

define Host/Configure/post/mipsel
	$(call Host/Configure/lzma)
endef

define Host/Prepare
	rm -rf $(BUILD_DIR_TOOLCHAIN)/linux-*
	$(call Kernel/Prepare/Default)
	rm -f $(BUILD_DIR_TOOLCHAIN)/linux
	ln -s linux-$(LINUX_VERSION) $(BUILD_DIR_TOOLCHAIN)/linux
	$(SED) 's/@expr length/@-expr length/' $(HOST_BUILD_DIR)/Makefile
endef

define Host/Configure
	yes '' | $(HOST_KMAKE) oldconfig
	$(call Host/Configure/all)
	$(call Host/Configure/post/$(ARCH))
endef

define Host/Compile
endef

define Host/Install
	$(CP) $(BUILD_DIR_TOOLCHAIN)/linux-dev/* $(TOOLCHAIN_DIR)/
endef

define Host/Clean
	rm -rf \
		$(HOST_BUILD_DIR) \
		$(BUILD_DIR_TOOLCHAIN)/linux \
		$(BUILD_DIR_TOOLCHAIN)/linux-dev
endef

else

define Host/Prepare
	mkdir -p $(TOPDIR)/build_dir/$(TARGET_DIR_NAME)/linux-$(BOARD)$(if $(SUBTARGET),_$(SUBTARGET)); \
	cd $(KERNEL_DIST_DIR); \
	tar -xzvf kernel-headers.tar.gz; \
	tar -zxvf kernel-uapi-headers.tar.gz; \
	cd -; \
	cd $(TOPDIR); \
	source owrt-qti-conf/set_openwrt_env.sh; \
	uname_version $(BOARD) $(TARGET_VARIANT); \
	cd -; \
	cd $(TOPDIR)/build_dir/$(TARGET_DIR_NAME)/linux-$(BOARD)$(if $(SUBTARGET),_$(SUBTARGET)); \
	mkdir -p kernel_dtbs; \
	mkdir -p merged_dtbs; \
	cp -r $(KERNEL_DIST_DIR)/*.dtb kernel_dtbs/; \
	mkdir -p build-tools/linux-x86; \
	ln -sf $(TOPDIR)/src/kernel-$(LINUX_VERSION)/kernel_platform/prebuilts/kernel-build-tools/linux-x86/bin/mkdtimg $(TOPDIR)/build_dir/$(TARGET_DIR_NAME)/linux-$(BOARD)$(if $(SUBTARGET),_$(SUBTARGET))/build-tools/linux-x86/mkdtimg; \
	cp -r $(TOPDIR)/src/kernel-$(LINUX_VERSION)/kernel_platform/tools/mkbootimg $(TOPDIR)/build_dir/$(TARGET_DIR_NAME)/linux-$(BOARD)$(if $(SUBTARGET),_$(SUBTARGET))/build-tools/; \
	chmod +x $(TOPDIR)/build_dir/$(TARGET_DIR_NAME)/linux-$(BOARD)$(if $(SUBTARGET),_$(SUBTARGET))/build-tools/mkbootimg/mkbootimg.py; \
	mkdir -p linux-$(LINUX_VERSION)/include; \
	cp -r $(KERNEL_DIST_DIR)/.config linux-$(LINUX_VERSION)/; \
	cp $(TOPDIR)/owrt-qti-bsp/kernel-packages/build_modules/Makefile linux-$(LINUX_VERSION)/; \
	cp -r $(TOPDIR)/owrt-qti-bsp/kernel-packages/build_modules/kernel-modules linux-$(LINUX_VERSION)/; \
	sed -i '1iBOARD=$(BOARD)' linux-$(LINUX_VERSION)/kernel-modules/Makefile; \
	sed -i '2iBUILD_CONFIG_NAME=$(BUILD_CONFIG_NAME)' linux-$(LINUX_VERSION)/kernel-modules/Makefile; \
	sed -i '3iTARGET_DIR_NAME=$(TARGET_DIR_NAME)' linux-$(LINUX_VERSION)/kernel-modules/Makefile; \
	sed -i '4iOUT_DIR_NAME=$(OUT_DIR_NAME)' linux-$(LINUX_VERSION)/kernel-modules/Makefile; \
	sed -i '5iLINUX_VERSION=$(LINUX_VERSION)' linux-$(LINUX_VERSION)/kernel-modules/Makefile; \
	sed -i '6iTARGET_VARIANT=$(TARGET_VARIANT)' linux-$(LINUX_VERSION)/kernel-modules/Makefile; \
	sed -i '7iKERNEL_PLATFORM_TARGET=$(KERNEL_PLATFORM_TARGET)' linux-$(LINUX_VERSION)/kernel-modules/Makefile; \
	if [ "$(BOARD)" = "sdx35" ]; then \
	cp -r $(KERNEL_DIST_DIR)/zImage .; \
	sed -i '1iARCH=\"$(ARCH)\"' linux-$(LINUX_VERSION)/Makefile; \
	sed -i '2iCROSS_COMPILE=\"arm-linux-gnu-\"' linux-$(LINUX_VERSION)/Makefile; else \
	sed -i '1iARCH=\"arm64\"' linux-$(LINUX_VERSION)/Makefile; \
	sed -i '2iCROSS_COMPILE=\"aarch64-linux-gnu-\"' linux-$(LINUX_VERSION)/Makefile; \
	cp -r $(KERNEL_DIST_DIR)/Image .; \
	fi ; \
	cp -r $(KERNEL_DIST_DIR)/vmlinux .; \
	cp -r $(KERNEL_DIST_DIR)/unsigned_abl_userdebug.elf .; \
	cp -r $(KERNEL_DIST_DIR)/unsigned_abl_user.elf .; \
	cp -r $(KERNEL_DIST_DIR)/kernel-headers/include/linux linux-$(LINUX_VERSION)/include/; \
	cp -r $(KERNEL_DIST_DIR)/kernel-headers/include/net linux-$(LINUX_VERSION)/include/; \
	mkdir -p linux-$(LINUX_VERSION)/include/uapi; \
	cp -r $(KERNEL_DIST_DIR)/usr/include/* linux-$(LINUX_VERSION)/include/uapi/; \
	cd -; \
	cd $(BUILD_DIR_TOOLCHAIN); \
	mkdir -p linux-dev/include; \
	mkdir -p linux-$(LINUX_VERSION)/include; \
	cp -r $(KERNEL_DIST_DIR)/usr/include/* linux-dev/include/; \
	cp -r $(KERNEL_DIST_DIR)/kernel-headers/include/linux linux-$(LINUX_VERSION)/include/; \
	cp -r $(KERNEL_DIST_DIR)/usr/include/* linux-$(LINUX_VERSION)/include/; \
	cd -;
	cd $(TOPDIR)/src/kernel-$(LINUX_VERSION)/kernel_platform; \
	BUILD_CONFIG=msm-kernel/$(BUILD_CONFIG_NAME) KERNEL_KIT=../out/$(OUT_DIR_NAME)/ OUT_DIR=temp_out_dir ./build/build_module.sh; \
	if [ "$(LINUX_VERSION)" = "6.6" ]; then \
	cp ../out/$(OUT_DIR_NAME)/dist/kernel-headers/include/generated/utsrelease.h temp_out_dir/msm-kernel/include/generated/; else \
	cp ../out/$(OUT_DIR_NAME)/msm-kernel/include/generated/utsrelease.h temp_out_dir/msm-kernel/include/generated/; \
	fi
	cd -;
endef

define Host/Configure
	@true
endef

define Host/Compile
	@true
endef

define Host/InstallDev
	$(CP) $(BUILD_DIR_TOOLCHAIN)/linux-dev/* $(TOOLCHAIN_DIR)/
endef

define Host/Install
	$(CP) $(BUILD_DIR_TOOLCHAIN)/linux-dev/* $(TOOLCHAIN_DIR)/
endef

define Host/Clean
	cd $(TOPDIR)/build_dir/$(TARGET_DIR_NAME)/linux-$(BOARD)$(if $(SUBTARGET),_$(SUBTARGET)); \
	rm -rf linux-$(LINUX_VERSION); \
	cd -; \
	cd $(BUILD_DIR_TOOLCHAIN); \
	rm -rf linux-dev; \
	rm -rf linux-$(LINUX_VERSION); \
	cd -;
endef

endif

$(eval $(call HostBuild))
