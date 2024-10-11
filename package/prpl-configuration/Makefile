include $(TOPDIR)/rules.mk

PKG_NAME:=prpl-configuration
PKG_VERSION:=v0.2.0
PKG_RELEASE:=1
PKG_LICENSE:=BSD-2-Clause-Patent

include $(INCLUDE_DIR)/package.mk

define Package/prpl-configuration
  TITLE:=prpl-configuration
  CATEGORY:=prpl Foundation
endef

define Package/prpl-configuration-qca-ipq95xx
  TITLE:=prpl-configuration-qca-ipq95xx
  CATEGORY:=prpl Foundation
endef

define Build/Compile
endef

define Package/prpl-configuration/install
	$(CP) ./files/common/* $(1)/
endef

define Package/prpl-configuration-qca-ipq95xx/install
	$(CP) ./files/wnc-freedom/* $(1)/
endef

$(eval $(call BuildPackage,prpl-configuration))
$(eval $(call BuildPackage,prpl-configuration-qca-ipq95xx))
