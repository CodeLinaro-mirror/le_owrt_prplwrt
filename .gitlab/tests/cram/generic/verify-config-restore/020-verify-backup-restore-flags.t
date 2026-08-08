Create alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

If test is running on a Valyrian, skip the test due to PCF-2669:
  $ if echo "$CI_JOB_NAME" | grep -q -E "Valyrian"; then exit 80; fi

  $ logger -t cram "Starting with Backup and restore flags verification test"

Verify %upc and %usersetting flags are moved from normal odl files, these are\
now moved to upc.odl or odl.uc, except for lcm components (cthulhu/timigila) and gmap-server\
PPW-1729, PPW-1731 and PPW-1786:

  $ cat > /tmp/allowed-upc-odl <<'EOF'
  > /etc/amx/cthulhu/cthulhu_definition.odl
  > /etc/amx/cthulhu/extensions/plugin-capabilities/plugin-capabilities-definition.odl
  > /etc/amx/cthulhu/extensions/plugin-networking/plugin-networking-definition.odl
  > /etc/amx/cthulhu/extensions/plugin-pcm/plugin-pcm-definition.odl
  > /etc/amx/cthulhu/extensions/plugin-usp/plugin-usp-definition.odl
  > /etc/amx/ethernet-manager/ethernet-manager_interface.odl
  > /etc/amx/gmap-server/mibs/dhcp.odl
  > /etc/amx/prplmesh-process-manager/prplmesh-process-manager_definition.odl
  > /etc/amx/timingila/extensions/timingila-rlyeh-security/timingila-rlyeh-security-definition.odl
  > /etc/amx/timingila/softwaremodules_definition.odl
  > /etc/amx/tr181-cpu/tr181-cpu_definition.odl
  > /etc/amx/tr181-gre/tr181-gre_definition.odl
  > /etc/amx/tr181-ipsec/tr181-ipsec_definition.odl
  > /etc/amx/tr181-ipsec/tr181-ipsec_filter.odl
  > /etc/amx/tr181-ipsec/tr181-ipsec_profile.odl
  > /etc/amx/tr181-ipsec/tr181-ipsec_secret.odl
  > /etc/amx/tr181-ipsec/tr181-ipsec_tunnel.odl
  > /etc/amx/tr181-mqtt/tr181-mqtt_definition.odl
  > /etc/amx/tr181-usb/tr181-usb_port.odl
  > /etc/amx/tr181-wireguard/tr181-wireguard_definition.odl
  > EOF

  $ R "grep -r %upc /etc/amx/ | grep -vE '(upc.odl|.*default.*)' | sed -E 's#:.*##' | sort | uniq" > /tmp/actual-upc-odl || exit $?
  $ grep -vxFf /tmp/allowed-upc-odl /tmp/actual-upc-odl || [ "$?" -eq 1 ]

  $ cat > /tmp/allowed-usersetting-odl <<'EOF'
  > /etc/amx/gmap-server/mibs/information.odl
  > /etc/amx/gmap-server/mibs/location.odl
  > /etc/amx/gmap-server/mibs/mac.odl
  > /etc/amx/tr181-schedules/tr181-schedules_definition.odl
  > EOF

  $ R "grep -r %usersetting /etc/amx | grep -vE '(upc.odl|.*default.*)' "\
  > " | sed -E 's#:.*##' | sort | uniq" > /tmp/actual-usersetting-odl || exit $?
  $ grep -vxFf /tmp/allowed-usersetting-odl /tmp/actual-usersetting-odl || [ "$?" -eq 1 ]

  $ logger -t cram "Backup and restore flags verification test finished"
