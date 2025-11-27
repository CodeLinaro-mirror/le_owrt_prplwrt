Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ . "${TESTDIR}/../scripts/wifi.sh"

Configure controller, requires PPM-3022 to work:

  $ R logger -t cram "Stop prplmesh"

  $ R "ba-cli -l X_PRPLWARE-COM_ProcessManager.PrplMesh.Enable=0" | tr -d '\n'
  0 (no-eol)

  $ R "sed -i 's/use_dataelements_vap_configs=1/use_dataelements_vap_configs=0/g' /opt/prplmesh/config/beerocks_controller.conf"
Restart prplmesh:

  $ R logger -t cram "Restart prplmesh"

  $ R "ba-cli X_PRPLWARE-COM_ProcessManager.PrplMesh.ManagementMode=Multi-AP-Controller-and-Agent"  > /dev/null
  $ R "ba-cli -l X_PRPLWARE-COM_ProcessManager.PrplMesh.Enable=1" | tr -d '\n'
  1 (no-eol)

  $ R "amx_wait_for X_PRPLWARE-COM_WiFiController.Network.Device.1"

  $ sleep 5
  $ R "find /tmp/beerocks/logs -type f -exec sh -c 'echo -n > "{}"' \;"

Check events:

  $ R ba-cli 'Device.WiFi.AccessPoint.*.Enable=1' 1>/dev/null
  $ sleep 20

  $ R "grep -roh -e 'radio wlan.* status Up' /tmp/beerocks/logs | sort | uniq"
  radio wlan0 status Up
  radio wlan1 status Up
  radio wlan2 status Up

  $ R "grep -roh 'event from iface wlan...' /tmp/beerocks/logs | sort | uniq"
  event from iface wlan0.1
  event from iface wlan0.2
  event from iface wlan0.3
  event from iface wlan1.1
  event from iface wlan1.2
  event from iface wlan1.3
  event from iface wlan2.1
  event from iface wlan2.2
  event from iface wlan2.3

  $ R "find /tmp/beerocks/logs -type f -exec sh -c 'echo -n > "{}"' \;"
  $ R ba-cli 'Device.WiFi.Radio.2.Channel=36' 1>/dev/null
  $ sleep 5
  $ R ba-cli 'Device.WiFi.Radio.2.Channel=40' 1>/dev/null
  $ sleep 5

Channel switching doesn’t have a direct log; but can be grepped on "Unhandled event: 27"
  $ R "grep -roh 'Unhandled event: 27' /tmp/beerocks/logs | uniq"
  Unhandled event: 27


  $ R "find /tmp/beerocks/logs -type f -exec sh -c 'echo -n > "{}"' \;"
  $ R ba-cli 'Device.WiFi.AccessPoint.*.Enable=0' 1>/dev/null
  $ sleep 20

  $ R "grep -roh 'event from iface wlan...' /tmp/beerocks/logs | sort | uniq"
  event from iface wlan0.1
  event from iface wlan0.2
  event from iface wlan0.3
  event from iface wlan1.1
  event from iface wlan1.2
  event from iface wlan1.3
  event from iface wlan2.1
  event from iface wlan2.2
  event from iface wlan2.3

  $ R "grep -roh -e 'radio wlan.* status Dormant' /tmp/beerocks/logs | sort | uniq"
  radio wlan0 status Dormant
  radio wlan1 status Dormant
  radio wlan2 status Dormant

  $ R logger -t cram "Test finished!"