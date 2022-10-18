include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=uslm
PKG_VERSION:=0.0.1
PKG_RELEASE:=1

include $(INCLUDE_DIR)/package.mk

define KernelPackage/uslm
  SUBMENU:=Network Support
  TITLE:=Unassociated STA Link Metrics Module
  FILES:=$(PKG_BUILD_DIR)/uslm_mod.ko
  DEPENDS:=kmod-cfg80211
  AUTOLOAD:=$(call AutoLoad,50,uslm_mod)
  MODPARAMS.uslm_mod:=nic_name=mon0
endef

define KernelPackage/uslm/description
uslm registers packet protocol handlers, the main of which
sniffs radiotap headers and marshalls station link statistics to userspace.
endef

include $(INCLUDE_DIR)/kernel-defaults.mk

define Build/Compile
	$(KERNEL_MAKE) SUBDIRS="$(PKG_BUILD_DIR)" modules
endef

$(eval $(call KernelPackage,uslm))
