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
PKG_MIRROR_HASH:=32b03ef4c7232bcb67ca7e6aff53a2b84d9c754196b9a09ff4cb1abdb22ce20a


include $(INCLUDE_DIR)/host-build.mk

define Host/Compile
endef

define Host/Install
  $(CP) $(HOST_BUILD_DIR)/checksec  $(STAGING_DIR_HOST)/bin/
endef


$(eval $(call HostBuild))
