#
# Copyright (C) 2009-2014 OpenWrt.org
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=mtd-utils
PKG_VERSION:=2.1.5
PKG_RELEASE:=1

PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION).tar.bz2
PKG_SOURCE_URL:=https://infraroot.at/pub/mtd/
PKG_HASH:=386e27fd121699b6b729bc2e8e04dda987b31cca6b16e12fb6cc6dcf26449f46

PKG_INSTALL:=1
PKG_FIXUP:=autoreconf

PKG_FLAGS:=nonshared
PKG_BUILD_FLAGS:=gc-sections

PKG_BUILD_DEPENDS:=util-linux mtd-utils/host

PKG_LICENSE:=GPLv2
PKG_LICENSE_FILES:=
PKG_CPE_ID:=cpe:/a:mtd-utils_project:mtd-utils

PKG_MAINTAINER:=John Crispin <john@phrozen.org>

include $(INCLUDE_DIR)/package.mk
include $(INCLUDE_DIR)/host-build.mk

ifneq ($(HOST_OS),Linux)
  HOST_CFLAGS += \
        -I$(CURDIR)/include \
        -Dloff_t=off_t \
        -D__BYTE_ORDER=BYTE_ORDER \
        -include endian.h \
        -DNO_NATIVE_SUPPORT \
        -include fls.h
endif

HOST_CONFIGURE_VARS+= \
UUID_CFLAGS="-I$(STAGING_DIR_HOST)/include/e2fsprogs/uuid -I$(STAGING_DIR_HOSTPKG)/include -L$(STAGING_DIR_HOSTPKG)/lib" \
PKG_CONFIG_PATH="$(STAGING_DIR_HOSTPKG)/lib/pkgconfig:$(STAGING_DIR_HOST)/lib/pkgconfig"
HOST_BUILD_DEPENDS:=libselinux/host

PKG_CONFIG_PATH:=$(PKG_CONFIG_PATH):$(STAGING_DIR_HOSTPKG)/lib/pkgconfig

HOST_LDFLAGS+="-L$(STAGING_DIR_HOSTPKG)/lib"
HOST_CFLAGS+="-I$(STAGING_DIR_HOSTPKG)/include"

HOST_CONFIGURE_ARGS+= \
        --disable-tests \
        --with-crypto \
        --without-xattr \
        --without-zstd \
        --without-lzo  \
        --with-selinux

HOST_MAKE_FLAGS += \
        PROGRAMS="ubinize mkfs.ubifs "

define Host/Install
	$(INSTALL_DIR) $(STAGING_DIR_HOSTPKG)/bin
	$(CP) $(HOST_BUILD_DIR)/mkfs.ubifs $(STAGING_DIR_HOSTPKG)/bin/
	$(CP) $(HOST_BUILD_DIR)/ubinize $(STAGING_DIR_HOSTPKG)/bin/
endef

define Host/Clean
        rm -f $(STAGING_DIR_HOSTPKG)/bin/{mkfs.ubifs,ubinize}
endef

define Package/mtd-utils/Default
  SECTION:=utils
  CATEGORY:=Utilities
  URL:=http://www.linux-mtd.infradead.org/
  DEPENDS:=@NAND_SUPPORT +libselinux
endef

define Package/ubi-utils
 $(call Package/mtd-utils/Default)
  TITLE:=Utilities for ubi info/debug
endef

define Package/ubi-utils/description
  Utilities for manipulating memory technology devices.
endef

define Package/nand-utils
 $(call Package/mtd-utils/Default)
  TITLE:=Utilities for nand flash erase/read/write/test
endef

define Package/nand-utils/description
  Utilities for NAND devices.
endef

MAKE_FLAGS += LDLIBS+="$(LIBGCC_S)"

CONFIGURE_ARGS += \
	--disable-tests \
	--without-crypto \
	--without-xattr \
	--without-zstd \
	--without-lzo

define Package/ubi-utils/install
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) \
		$(PKG_INSTALL_DIR)/usr/sbin/{ubiattach,ubicrc32,ubiblock,ubidetach,ubiformat,ubimkvol} $(1)/usr/sbin/
	$(INSTALL_BIN) \
		$(PKG_INSTALL_DIR)/usr/sbin/{ubinfo,ubinize,ubirename,ubirmvol,ubirsvol,ubiupdatevol} $(1)/usr/sbin/
endef

define Package/nand-utils/install
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) \
	$(PKG_INSTALL_DIR)/usr/sbin/{flash_erase,nanddump,nandwrite,nandtest,mtdinfo} $(1)/usr/sbin/
endef

$(eval $(call HostBuild))
$(eval $(call BuildPackage,ubi-utils))
$(eval $(call BuildPackage,nand-utils))
