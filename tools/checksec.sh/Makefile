#
# Copyright (C) 2008-2015 OpenWrt.org
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#
include $(TOPDIR)/rules.mk

PKG_NAME:=checksec.sh
PKG_SOURCE_VERSION:=36a67b388193d26289773f4153cb3b9f5bf5c9ec

PKG_SOURCE_PROTO:=git
PKG_SOURCE_URL:=https://github.com/slimm609/checksec.sh.git
PKG_MIRROR_HASH:=06bfaa95ee3caf84b77c2d4a1089a4941cf8237a8d226df7c04cc831a5ea0014


include $(INCLUDE_DIR)/host-build.mk

define Host/Compile
endef

define Host/Install
  $(CP) $(HOST_BUILD_DIR)/checksec  $(STAGING_DIR_HOST)/bin/
endef


$(eval $(call HostBuild))
