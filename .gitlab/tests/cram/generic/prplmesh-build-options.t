Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Skip the test on images without prplMesh:

  $ R "test -x /opt/prplmesh/bin/beerocks_agent" || exit 80

Fetch the build configuration of the image:

  $ R "cat /etc/build.config" > build.config

Resolve the effective prplMesh build options, the ubus backend forces BML on when it is disabled:

  $ is_set() { grep -qx "CONFIG_$1=y" build.config; }
  $ is_unset() { grep -qx "# CONFIG_$1 is not set" build.config; }
  $ if is_unset PRPLMESH_ENABLE_AMBIORIX_UBUS_BACKEND; then UBUS=n; else UBUS=y; fi
  $ if is_set PRPLMESH_BML || [ "$UBUS" = n ]; then BML=y; else BML=n; fi
  $ if [ "$UBUS" = y ] && ! is_unset PRPLMESH_CLI; then CLI=y; else CLI=n; fi
  $ if is_set PRPLMESH_BEEROCKS_CLI; then BEEROCKS_CLI=y; else BEEROCKS_CLI=n; fi
  $ if is_set PRPLMESH_VENDOR_EXTENSIONS; then VENDOR=y; else VENDOR=n; fi

Define the check that an installed file matches the option that selects it:

  $ check() { if R "ls $2" >/dev/null 2>&1; then found=y; else found=n; fi; [ "$found" = "$1" ] && echo consistent || echo "inconsistent: $2 installed=$found, expected=$1"; }

Check that prplmesh_cli is installed only when PRPLMESH_CLI is enabled:

  $ check "$CLI" /opt/prplmesh/bin/prplmesh_cli
  consistent

Check that the BML library is installed only when PRPLMESH_BML is enabled:

  $ check "$BML" "/usr/lib/libbml.so*"
  consistent

Check that beerocks_cli is installed only when PRPLMESH_BEEROCKS_CLI is enabled:

  $ check "$BEEROCKS_CLI" /opt/prplmesh/bin/beerocks_cli
  consistent

Check that the vendor extensions are installed only when PRPLMESH_VENDOR_EXTENSIONS is enabled:

  $ check "$VENDOR" "/usr/lib/libmulti_vendor.so*"
  consistent

  $ check "$VENDOR" /opt/prplmesh/bin/beerocks_vendor_message
  consistent

Check that no procd instance is registered for the vendor message daemon when it is not installed:

  $ instances=$(R "ubus call service list '{\"name\":\"prplmesh\"}'" | grep -c '"prplmesh_vendor_message"' || true)
  $ [ "$VENDOR" = y ] || [ "$instances" -eq 0 ] && echo consistent || echo "inconsistent: prplmesh_vendor_message registered without the daemon"
  consistent
