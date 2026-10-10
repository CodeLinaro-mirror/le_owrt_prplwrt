# SPDX-License-Identifier: GPL-2.0-only
#
# Copyright (C) 2026 prpl Foundation
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=sanitizer-opts
PKG_RELEASE:=1

PKG_LICENSE:=GPL-2.0-only
PKG_MAINTAINER:=Petr Štetiar <petr.stetiar@prplfoundation.org>

# Where the .opts files come from, set by the choice in Config.in.
# Calibrated: ./files/opts, committed. Local: an absolute directory.
SANOPTS_SRC:=$(if $(CONFIG_SANITIZER_OPTS_CALIBRATED),$(CURDIR)/files/opts,$(if $(CONFIG_SANITIZER_OPTS_LOCAL),$(call qstrip,$(CONFIG_SANITIZER_OPTS_DIR))))

SANOPTS_FILES=$(if $(SANOPTS_SRC),$(wildcard $(SANOPTS_SRC)/*.opts))

# Rebuild when the files in a local directory change.
PKG_FILE_DEPENDS:=$(if $(CONFIG_SANITIZER_OPTS_LOCAL),$(call qstrip,$(CONFIG_SANITIZER_OPTS_DIR)))

PKG_CONFIG_DEPENDS:=\
	CONFIG_SANITIZER_OPTS_CALIBRATED \
	CONFIG_SANITIZER_OPTS_LOCAL \
	CONFIG_SANITIZER_OPTS_DIR

include $(INCLUDE_DIR)/package.mk

define Package/sanitizer-opts
  SECTION:=utils
  CATEGORY:=Utilities
  TITLE:=Per-binary sanitizer options for heavy allocators
  DEPENDS:=+sanitizer-shim
  PKGARCH:=all
endef

define Package/sanitizer-opts/description
  Data only. Installs <binary>.opts files into /etc/sanitizer/, which
  sanitizer-shim reads at the start of that binary (include_if_exists).
  They raise quarantine_size_mb, in absolute MB, for the few binaries that
  free much faster than the RAM tier of the shim assumes. The files come
  from the calibration of a reference run (.gitlab/scripts/sanitize/san-calibrate.py), or
  from a local directory for trials. The package never ships sleep.opts:
  that file belongs to sanitizer-shim.
  For the sanitize profile only, not for production images.
endef

define Package/sanitizer-opts/config
  source "$(SOURCE)/Config.in"
endef

define Build/Prepare
endef

define Build/Configure
endef

define Build/Compile
endef

# files/opts/PROVENANCE (package version of the calibrated binary, system
# version of the calibrated image) stays out of the image: nothing on the
# device reads it, the drift check runs on the host.
define Package/sanitizer-opts/install
	$(if $(CONFIG_SANITIZER_OPTS_LOCAL),$(if $(and $(SANOPTS_SRC),$(wildcard $(SANOPTS_SRC)/.)),,$(error sanitizer-opts: CONFIG_SANITIZER_OPTS_DIR "$(SANOPTS_SRC)" is not a directory)))
	$(if $(filter sleep.opts,$(notdir $(SANOPTS_FILES))),$(error sanitizer-opts: sleep.opts belongs to sanitizer-shim))
	$(INSTALL_DIR) $(1)/etc/sanitizer
	$(foreach f,$(SANOPTS_FILES),$(INSTALL_DATA) $(f) $(1)/etc/sanitizer/ &&) true
endef

$(eval $(call BuildPackage,sanitizer-opts))
