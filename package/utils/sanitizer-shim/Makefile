# SPDX-License-Identifier: GPL-2.0-only
#
# Copyright (C) 2026 prpl Foundation
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=sanitizer-shim
PKG_RELEASE:=1

PKG_LICENSE:=GPL-2.0-only
PKG_MAINTAINER:=Petr Štetiar <petr.stetiar@prplfoundation.org>

# The shim runs inside every sanitized process: it must not be sanitized.
PKG_BUILD_FLAGS:=no-sanitize

PKG_CONFIG_DEPENDS:=\
	CONFIG_SANITIZER_SHIM_LOG_PATH \
	CONFIG_SANITIZER_SHIM_HALT_ON_ERROR \
	CONFIG_SANITIZER_SHIM_SYMBOLIZE \
	CONFIG_SANITIZER_SHIM_DETECT_LEAKS \
	CONFIG_SANITIZER_SHIM_UBSAN_PRINT_STACKTRACE \
	CONFIG_SANITIZER_SHIM_UBSAN_LOG_SUFFIX \
	CONFIG_SANITIZER_SHIM_OPTS_INCLUDE \
	CONFIG_SANITIZER_SHIM_LSAN_SUPPRESSIONS \
	CONFIG_SANITIZER_SHIM_OFF_DIR \
	CONFIG_SANITIZER_SHIM_LEAK_SIGNAL_OFFSET \
	CONFIG_SANITIZER_SHIM_PROFILE_TOP_PERCENT \
	CONFIG_SANITIZER_SHIM_PROFILE_MAX_CONTEXTS \
	CONFIG_SANITIZER_SHIM_FORK_CHILD_WORKER \
	CONFIG_SANITIZER_SHIM_EXTRA_ASAN_OPTS \
	CONFIG_SANITIZER_SHIM_EXTRA_LSAN_OPTS \
	CONFIG_SANITIZER_SHIM_EXTRA_UBSAN_OPTS

include $(INCLUDE_DIR)/package.mk

define Package/sanitizer-shim
  SECTION:=utils
  CATEGORY:=Utilities
  TITLE:=Sanitizer defaults, leak-check signal and runtime switches
  DEPENDS:=@USE_GLIBC
endef

define Package/sanitizer-shim/description
  Preloaded alone through /etc/ld.so.preload. In instrumented processes
  (libasan through DT_NEEDED) it provides the default
  options of ASan, LSan and UBSan (report files, halt_on_error=0), a
  SIGRTMIN+3 handler that runs a recoverable leak check and prints a memory
  profile, per-binary options in /etc/sanitizer/<binary>.opts and a
  switch-off file for the leak check of a binary.
  For the sanitize profile only: it is no production package, and its
  world-writable report directories are meant for debug images.
endef

define Package/sanitizer-shim/config
  source "$(SOURCE)/Config.in"
endef

define Package/sanitizer-shim/conffiles
/etc/sanitizer/lsan.supp
endef

SHIM_STR = $(call qstrip,$(CONFIG_SANITIZER_SHIM_$(1)))
SHIM_BOOL = $(if $(CONFIG_SANITIZER_SHIM_$(1)),1,0)

define Build/Prepare
	$(CP) ./src/* $(PKG_BUILD_DIR)/
endef

# Values are single-quoted for printf: no ' in the Kconfig strings.
define Build/Configure
	{ \
		printf '#define SHIM_LOG_PATH "%s"\n' '$(call SHIM_STR,LOG_PATH)'; \
		printf '#define SHIM_UBSAN_LOG_SUFFIX "%s"\n' '$(call SHIM_STR,UBSAN_LOG_SUFFIX)'; \
		printf '#define SHIM_OPTS_INCLUDE "%s"\n' '$(call SHIM_STR,OPTS_INCLUDE)'; \
		printf '#define SHIM_LSAN_SUPPRESSIONS "%s"\n' '$(call SHIM_STR,LSAN_SUPPRESSIONS)'; \
		printf '#define SHIM_OFF_DIR "%s"\n' '$(call SHIM_STR,OFF_DIR)'; \
		printf '#define SHIM_EXTRA_ASAN_OPTS "%s"\n' '$(call SHIM_STR,EXTRA_ASAN_OPTS)'; \
		printf '#define SHIM_EXTRA_LSAN_OPTS "%s"\n' '$(call SHIM_STR,EXTRA_LSAN_OPTS)'; \
		printf '#define SHIM_EXTRA_UBSAN_OPTS "%s"\n' '$(call SHIM_STR,EXTRA_UBSAN_OPTS)'; \
		printf '#define SHIM_HALT_ON_ERROR %s\n' '$(call SHIM_BOOL,HALT_ON_ERROR)'; \
		printf '#define SHIM_SYMBOLIZE %s\n' '$(call SHIM_BOOL,SYMBOLIZE)'; \
		printf '#define SHIM_DETECT_LEAKS %s\n' '$(call SHIM_BOOL,DETECT_LEAKS)'; \
		printf '#define SHIM_UBSAN_PRINT_STACKTRACE %s\n' '$(call SHIM_BOOL,UBSAN_PRINT_STACKTRACE)'; \
		printf '#define SHIM_FORK_CHILD_WORKER %s\n' '$(call SHIM_BOOL,FORK_CHILD_WORKER)'; \
		printf '#define SHIM_LEAK_SIGNAL_OFFSET %s\n' '$(call SHIM_STR,LEAK_SIGNAL_OFFSET)'; \
		printf '#define SHIM_PROFILE_TOP_PERCENT %s\n' '$(call SHIM_STR,PROFILE_TOP_PERCENT)'; \
		printf '#define SHIM_PROFILE_MAX_CONTEXTS %s\n' '$(call SHIM_STR,PROFILE_MAX_CONTEXTS)'; \
	} > $(PKG_BUILD_DIR)/shim-config.h
endef

define Build/Compile
	$(MAKE) -C $(PKG_BUILD_DIR) \
		CC="$(TARGET_CC)" \
		CFLAGS="$(TARGET_CFLAGS) $(TARGET_CPPFLAGS)" \
		CPPFLAGS="-DHAVE_SHIM_CONFIG_H" \
		LDFLAGS="$(TARGET_LDFLAGS)"
endef

# The report directory ships in the image: during preinit the root is
# read-only, and libsanitizer dies at start if it cannot create it.
define Package/sanitizer-shim/install
	$(INSTALL_DIR) $(1)/usr/lib $(1)/etc/sanitizer
	$(INSTALL_DIR) -m1777 $(1)$(dir $(call SHIM_STR,LOG_PATH))
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/libsanitizer-shim.so $(1)/usr/lib/
	$(INSTALL_DATA) ./files/etc/ld.so.preload $(1)/etc/
	$(INSTALL_DATA) ./files/etc/sanitizer/lsan.supp $(1)/etc/sanitizer/
endef

$(eval $(call BuildPackage,sanitizer-shim))
