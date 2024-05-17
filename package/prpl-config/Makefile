include $(TOPDIR)/rules.mk

PKG_NAME:=prpl-configuration
PKG_VERSION:=v0.1.0
PKG_RELEASE:=1
PKG_LICENSE:=BSD-2-Clause-Patent

include $(INCLUDE_DIR)/package.mk

define Package/prpl-configuration
  TITLE:=prpl-configuration
  CATEGORY:=prpl Foundation
endef

define Build/Compile
endef

define Package/prpl-configuration/install
	$(CP) ./files/* $(1)/
endef

$(eval $(call BuildPackage,prpl-configuration))
