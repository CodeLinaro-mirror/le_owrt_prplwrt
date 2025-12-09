Create alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

  $ logger -t cram "Starting with Backup and restore flags verification test"

Verify %upc and %usersetting flags are moved from normal odl files, these are\
now moved to upc.odl or odl.uc, except for cthulhu and gmap-server:

  $ R "grep -r %upc /etc/amx/ | grep -vE '(upc.odl|.*default.*)' | sed -E 's#:.*##' | sort | uniq"
  /etc/amx/cthulhu/cthulhu_definition.odl
  /etc/amx/cthulhu/extensions/plugin-capabilities/plugin-capabilities-definition.odl
  /etc/amx/cthulhu/extensions/plugin-networking/plugin-networking-definition.odl
  /etc/amx/cthulhu/extensions/plugin-pcm/plugin-pcm-definition.odl
  /etc/amx/gmap-server/mibs/dhcp.odl
  /etc/amx/prplmesh-process-manager/prplmesh-process-manager_definition.odl

  $ R "grep -r %usersetting /etc/amx | grep -vE '(upc.odl|.*default.*)' "\
  > " | sed -E 's#:.*##' | sort | uniq"
  /etc/amx/gmap-server/mibs/information.odl
  /etc/amx/gmap-server/mibs/location.odl
  /etc/amx/gmap-server/mibs/mac.odl

  $ logger -t cram "Backup and restore flags verification test finished"
