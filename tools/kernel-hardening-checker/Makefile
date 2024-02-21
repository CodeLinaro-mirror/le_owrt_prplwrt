#
# Copyright (C) 2008-2015 OpenWrt.org
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#
include $(TOPDIR)/rules.mk

PKG_NAME:=kernel-hardening-checker
PKG_SOURCE_VERSION:=31352cfaebcf88a4cf39ab41396182f61e0a0ab6

PKG_SOURCE_PROTO:=git
PKG_SOURCE_URL:=git@github.com:a13xp0p0v/kernel-hardening-checker.git
PKG_MIRROR_HASH:=868aaf0209e9596524e14f76e5a32625c4902a237e7043f319fe92f598f549ef

include $(INCLUDE_DIR)/host-build.mk

define Host/Compile
endef

define Host/Install
	$(CP) -r $(HOST_BUILD_DIR)/bin  $(STAGING_DIR_HOST)/
	$(CP) -r $(HOST_BUILD_DIR)/kernel_hardening_checker  $(STAGING_DIR_HOST)/
endef

$(eval $(call HostBuild))
