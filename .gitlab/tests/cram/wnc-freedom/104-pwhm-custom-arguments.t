Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ . "${TESTDIR}/../scripts/wifi.sh"

  $ R logger -t cram "Starting PWHM test for custom arguments..."

Wait for Device.WiFi. datamodel availability:

  $ R "amx_wait_for 'Device.WiFi.AccessPoint.'"

  $ sleep 10

Stop prplMesh:

  $ R "ba-cli -l X_PRPLWARE-COM_ProcessManager.PrplMesh.Enable=0" | tr -d '\n'
  0 (no-eol)

  $ sleep 2

Check that pwhm is running:

  $ R "ba-cli X_PRPLWARE-COM_ProcessManager.PWHM.Status? | sed '1d' | awk 'NF'"
  X_PRPLWARE-COM_ProcessManager.PWHM.Status="Active"

Enabling few accesspoints to check hostapd:

  $ R logger -t cram "Enable private vaps"

  $ enable_ap_sync 1 1
  AccessPoint.\d+.Enable=1 (re)

  $ wifi_dm "AccessPoint.1.Status?0"
  Device.WiFi.AccessPoint.1.Status="Enabled"

Check that hostapd is operating as expected:

  $ R logger -t cram "Check that hostapd is operating"

  $ R "ps axw" | sed -nE 's/.*(hostapd .*)/\1/p' | head -1 | tr -s ' ' '\n' | LC_ALL=C sort
  -g
  -s
  /tmp/wlan2_hapd.conf
  /var/run/hostapd/global\.0x.* (re)
  hostapd

Test the custom arguments for hostapd:

  $ R "ba-cli -j -l 'protected; WiFi.DaemonMgt.Daemon.hostapd.ExecutionSettings.CustomArguments=-dds' | grep CustomArguments"
  [{"WiFi.DaemonMgt.Daemon.1.ExecutionSettings.":{"CustomArguments":"-dds"}}]

  $ sleep 10

  $ R "ba-cli -j -l 'protected; WiFi.DaemonMgt.Daemon.hostapd.ExecutionSettings.CustomArguments?' | grep CustomArguments"
  [{"WiFi.DaemonMgt.Daemon.1.ExecutionSettings.":{"CustomArguments":"-dds"}}]

  $ R logger -t cram "Check that hostapd is operating with new custom argument"

  $ R "ps axw" | sed -nE 's/.*(hostapd .*)/\1/p' | head -1 | tr -s ' ' '\n' | LC_ALL=C sort
  -dds
  -g
  /tmp/wlan2_hapd.conf
  /var/run/hostapd/global\.0x.* (re)
  hostapd

Setting the custom arguments back to default value for hostapd:

  $ R "ba-cli -j -l 'protected; WiFi.DaemonMgt.Daemon.hostapd.ExecutionSettings.CustomArguments="-s"' | grep CustomArguments"
  [{"WiFi.DaemonMgt.Daemon.1.ExecutionSettings.":{"CustomArguments":"-s"}}]

  $ sleep 10

  $ R "ba-cli -j -l 'protected; WiFi.DaemonMgt.Daemon.hostapd.ExecutionSettings.CustomArguments?' | grep CustomArguments"
  [{"WiFi.DaemonMgt.Daemon.1.ExecutionSettings.":{"CustomArguments":"-s"}}]

  $ R logger -t cram "Check that hostapd is operating with default custom argument"

  $ R "ps axw" | sed -nE 's/.*(hostapd .*)/\1/p' | head -1 | tr -s ' ' '\n' | LC_ALL=C sort
  -g
  -s
  /tmp/wlan2_hapd.conf
  /var/run/hostapd/global\.0x.* (re)
  hostapd

Disabling the accesspoints back:

Test deactivation of access point 1:

  $ R logger -t cram "Test AccessPoint 1 deactivation"

  $ enable_ap_sync 1 0
  AccessPoint.1.Enable=0

  $ wifi_dm "AccessPoint.1.Status?0"
  Device.WiFi.AccessPoint.1.Status="Disabled"

Enable the end points for wpa_supplicant:

  $ R "ba-cli 'WiFi.EndPoint.*.Enable=1' | sed '1d' | awk 'NF'"
  WiFi.EndPoint.1.
  WiFi.EndPoint.1.Enable=1
  WiFi.EndPoint.2.
  WiFi.EndPoint.2.Enable=1
  WiFi.EndPoint.3.
  WiFi.EndPoint.3.Enable=1

  $ sleep 5

  $ R "ba-cli 'WiFi.EndPoint.*.Status?' | sed '1d' | awk 'NF'"
  WiFi.EndPoint.1.Status="Enabled"
  WiFi.EndPoint.2.Status="Enabled"
  WiFi.EndPoint.3.Status="Enabled"

  $ R logger -t cram "Check that wpa_supplicant is operating"

  $ R "ps axw" | sed -n '/[w]pa_supplicant/ { s/^.*\bwpa_supplicant[[:space:]]/wpa_supplicant /; p }' | head -3 | LC_ALL=C sort
  wpa_supplicant -s -i wlan0 -Dnl80211 -c /tmp/wlan0_wpa_supplicant.conf
  wpa_supplicant -s -i wlan1 -Dnl80211 -c /tmp/wlan1_wpa_supplicant.conf
  wpa_supplicant -s -i wlan2 -Dnl80211 -c /tmp/wlan2_wpa_supplicant.conf

Test the custom arguments for wpa_supplicant:

  $ R "ba-cli -j -l 'protected; WiFi.DaemonMgt.Daemon.wpa_supplicant.ExecutionSettings.CustomArguments=-ds' | grep CustomArguments"
  [{"WiFi.DaemonMgt.Daemon.2.ExecutionSettings.":{"CustomArguments":"-ds"}}]

  $ sleep 10

  $ R "ba-cli -j -l 'protected; WiFi.DaemonMgt.Daemon.wpa_supplicant.ExecutionSettings.CustomArguments?' | grep CustomArguments"
  [{"WiFi.DaemonMgt.Daemon.2.ExecutionSettings.":{"CustomArguments":"-ds"}}]

  $ R logger -t cram "Check that wpa_supplicant is operating with new custom argument"

  $ R "ba-cli X_PRPLWARE-COM_ProcessManager.PWHM.Status? | sed '1d' | awk 'NF'"
  X_PRPLWARE-COM_ProcessManager.PWHM.Status="Active"

  $ R "ba-cli 'WiFi.EndPoint.*.Status?' | sed '1d' | awk 'NF'"
  WiFi.EndPoint.1.Status="Enabled"
  WiFi.EndPoint.2.Status="Enabled"
  WiFi.EndPoint.3.Status="Enabled"

  $ R "ps axw" | sed -n '/[w]pa_supplicant/ { s/^.*\bwpa_supplicant[[:space:]]/wpa_supplicant /; p }' | head -3 | LC_ALL=C sort
  wpa_supplicant -ds -i wlan0 -Dnl80211 -c /tmp/wlan0_wpa_supplicant.conf
  wpa_supplicant -ds -i wlan1 -Dnl80211 -c /tmp/wlan1_wpa_supplicant.conf
  wpa_supplicant -ds -i wlan2 -Dnl80211 -c /tmp/wlan2_wpa_supplicant.conf

  $ R "ba-cli ProcessFaults.ProcessFault.? | grep -iE 'hostapd|wpa_supplicant'"
  [1]

Setting the custom arguments back to default value:

  $ R "ba-cli -j -l 'protected; WiFi.DaemonMgt.Daemon.wpa_supplicant.ExecutionSettings.CustomArguments="-s"' | grep CustomArguments"
  [{"WiFi.DaemonMgt.Daemon.2.ExecutionSettings.":{"CustomArguments":"-s"}}]

  $ sleep 10

  $ R "ba-cli -j -l 'protected; WiFi.DaemonMgt.Daemon.wpa_supplicant.ExecutionSettings.CustomArguments?' | grep CustomArguments"
  [{"WiFi.DaemonMgt.Daemon.2.ExecutionSettings.":{"CustomArguments":"-s"}}]

  $ R "ba-cli X_PRPLWARE-COM_ProcessManager.PWHM.Status? | sed '1d' | awk 'NF'"
  X_PRPLWARE-COM_ProcessManager.PWHM.Status="Active"

  $ R "ba-cli 'WiFi.EndPoint.*.Status?' | sed '1d' | awk 'NF'"
  WiFi.EndPoint.1.Status="Enabled"
  WiFi.EndPoint.2.Status="Enabled"
  WiFi.EndPoint.3.Status="Enabled"

  $ R "ps axw" | sed -n '/[w]pa_supplicant/ { s/^.*\bwpa_supplicant[[:space:]]/wpa_supplicant /; p }' | head -3 | LC_ALL=C sort
  wpa_supplicant -s -i wlan0 -Dnl80211 -c /tmp/wlan0_wpa_supplicant.conf
  wpa_supplicant -s -i wlan1 -Dnl80211 -c /tmp/wlan1_wpa_supplicant.conf
  wpa_supplicant -s -i wlan2 -Dnl80211 -c /tmp/wlan2_wpa_supplicant.conf

  $ R "ba-cli ProcessFaults.ProcessFault.? | grep -iE 'hostapd|wpa_supplicant'"
  [1]

  $ R "ba-cli 'WiFi.EndPoint.*.Enable=0' | sed '1d' | awk 'NF'"
  WiFi.EndPoint.1.
  WiFi.EndPoint.1.Enable=0
  WiFi.EndPoint.2.
  WiFi.EndPoint.2.Enable=0
  WiFi.EndPoint.3.
  WiFi.EndPoint.3.Enable=0

Resume prplMesh:

  $ R "ba-cli -l X_PRPLWARE-COM_ProcessManager.PrplMesh.Enable=1" | tr -d '\n'
  1 (no-eol)

  $ R logger -t cram "Stopping PWHM test for custom arguments.."

Wait 20s before leaving the test:

  $ sleep 20

  $ R logger -t cram "Test finished!"
