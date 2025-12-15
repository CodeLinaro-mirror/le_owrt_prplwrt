define rewrite
$(eval $(3) define $(1)
$(2)
endef)
endef

define prepend
$(call rewrite,$(1),$(2)$(value $(1)),$(3))
endef

define append
$(call rewrite,$(1),$(value $(1))$(2),$(3))
endef

define remove
$(call rewrite,$(1),$(filter-out $(2),$(value $(1))),$(3))
endef

define newline


endef
