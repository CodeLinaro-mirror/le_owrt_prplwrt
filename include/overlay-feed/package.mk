include $(INCLUDE_DIR)/overlay-feed/helpers.mk

# All patches which paths added into OVERLAY_PATCHES
# will be applied on package build dir after Prepare step
# of main package
OVERLAY_PATCHES ?=

define Overlay/Prepare/Patch
    $(foreach pf,$(filter %.patch,$(OVERLAY_PATCHES)), \
            patch -d "$(PKG_BUILD_DIR)" -p1 < $(pf) $$(newline) \
    )
endef
Hooks/Prepare/Post += Overlay/Prepare/Patch

# All patches which paths added into OVERLAY_HOST_PATCHES
# will be applied to the host build dir.
# If left empty (the default), the host build receives the same patches as
# the target build (OVERLAY_PATCHES), mirroring the HOST_PATCH_DIR convention.
OVERLAY_HOST_PATCHES ?=

define Overlay/HostPrepare/Patch
    $(foreach pf,$(filter %.patch,$(if $(OVERLAY_HOST_PATCHES),$(OVERLAY_HOST_PATCHES),$(OVERLAY_PATCHES))), \
            patch -d "$(HOST_BUILD_DIR)" -p1 < $(pf) $$(newline) \
    )
endef
Hooks/HostPrepare/Post += Overlay/HostPrepare/Patch

ifneq ($(wildcard $(TMP_DIR)/info/.files-packageinfo-$(SCAN_COOKIE)),)
$(call rewrite,OVERLAY_MAKEFILE_APPENDS,$(shell grep '^[$$].*/$(PKG_DIR_NAME)/Makefile.append' $(TMP_DIR)/info/.files-packageinfo-$(SCAN_COOKIE)))
else
OVERLAY_MAKEFILE_APPENDS := $(foreach feed,$(shell $(TOPDIR)/scripts/feeds list -n 2>/dev/null),$(shell find -L $(TOPDIR)/feeds/$(feed)/ -path '*/$(PKG_DIR_NAME)/Makefile.append' | sort))
endif
PKG_FILE_DEPENDS += $(foreach mk,$(OVERLAY_MAKEFILE_APPENDS), $(dir $(mk)))

define Build/IncludeOverlay
    # Clean out Build/IncludeOverlay to prevent recursive expansion
    $(eval Build/IncludeOverlay=)
    $(foreach mk,$(OVERLAY_MAKEFILE_APPENDS), \
        $(eval THISDIR := $(dir $(mk))) \
        $(eval -include $(mk)) \
    )
endef

$(call prepend,BuildPackage,$$(Build/IncludeOverlay)$(newline))
$(call prepend,HostBuild,$$(Build/IncludeOverlay)$(newline))
