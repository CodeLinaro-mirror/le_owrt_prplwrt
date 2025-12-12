Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ . "${TESTDIR}/../scripts/wifi.sh"

  $ R logger -t cram "Starting PWHM test for custom arguments..."

Wait for Device.WiFi. datamodel availability:

  $ R "amx_wait_for "Device.WiFi." "

  $ sleep 10

Stop prplMesh:

  $ R "ba-cli -l X_PRPLWARE-COM_ProcessManager.PrplMesh.Enable=0" | tr -d '\n'
  0 (no-eol)

  $ sleep 2

Enabling few accesspoints to check hostapd:

  $ R logger -t cram "Test AccessPoint 1 activation"

  $ enable_ap 1
  WiFi.AccessPoint.1 enabled

  $ sleep 5

  $ R logger -t cram "Test AccessPoint 3 activation"

  $ enable_ap 3
  WiFi.AccessPoint.3 enabled

  $ sleep 5

  $ R logger -t cram "Test AccessPoint 5 activation"

  $ enable_ap 5
  WiFi.AccessPoint.5 enabled

  $ sleep 5

Check that hostapd is operating as expected:

  $ R logger -t cram "Check that hostapd is operating"

  $ R "ps axw" | sed -nE 's/.*(hostapd .*)/\1/p' | head -1 | tr -s ' ' '\n' | LC_ALL=C sort
  -g
  -s
  /tmp/wlan2_hapd.conf
  /var/run/hostapd/global\.0x.* (re)
  hostapd

Enable the end points for wpa_supplicant:

  $ R "ba-cli 'Device.WiFi.EndPoint.*.Enable=1' | sed '1d' | awk 'NF'"
  Device.WiFi.EndPoint.1.
  Device.WiFi.EndPoint.1.Enable=1
  Device.WiFi.EndPoint.2.
  Device.WiFi.EndPoint.2.Enable=1
  Device.WiFi.EndPoint.3.
  Device.WiFi.EndPoint.3.Enable=1

Test the custom arguments:

  $ R "ba-cli -j -l 'protected; WiFi.DaemonMgt.Daemon.hostapd.ExecutionSettings.CustomArguments=-dds' | grep CustomArguments"
  [{"WiFi.DaemonMgt.Daemon.1.ExecutionSettings.":{"CustomArguments":"-dds"}}]

  $ R "ba-cli -j -l 'protected; WiFi.DaemonMgt.Daemon.hostapd.ExecutionSettings.CustomArguments?' | grep CustomArguments"
  [{"WiFi.DaemonMgt.Daemon.1.ExecutionSettings.":{"CustomArguments":"-dds"}}]

  $ R "ba-cli -j -l 'protected; WiFi.DaemonMgt.Daemon.wpa_supplicant.ExecutionSettings.CustomArguments=-ds' | grep CustomArguments"
  [{"WiFi.DaemonMgt.Daemon.2.ExecutionSettings.":{"CustomArguments":"-ds"}}]

  $ R "ba-cli -j -l 'protected; WiFi.DaemonMgt.Daemon.wpa_supplicant.ExecutionSettings.CustomArguments?' | grep CustomArguments"
  [{"WiFi.DaemonMgt.Daemon.2.ExecutionSettings.":{"CustomArguments":"-ds"}}]

  $ sleep 10

  $ R logger -t cram "Check that hostapd is operating with new custom argument"

  $ R "ps axw" | sed -nE 's/.*(hostapd .*)/\1/p' | head -1 | tr -s ' ' '\n' | LC_ALL=C sort
  -dds
  -g
  /tmp/wlan0_hapd.conf
  /tmp/wlan1_hapd.conf
  /tmp/wlan2_hapd.conf
  /var/run/hostapd/global\.0x.* (re)
  hostapd

  $ R logger -t cram "Check that wpa_supplicant is operating with new custom argument"

  $ R "ps axw" | sed -n '/[w]pa_supplicant/ { s/^.*\bwpa_supplicant[[:space:]]/wpa_supplicant /; p }' | head -3 | LC_ALL=C sort
  wpa_supplicant -ds -i wlan0 -Dnl80211 -c /tmp/wlan0_wpa_supplicant.conf
  wpa_supplicant -ds -i wlan1 -Dnl80211 -c /tmp/wlan1_wpa_supplicant.conf
  wpa_supplicant -ds -i wlan2 -Dnl80211 -c /tmp/wlan2_wpa_supplicant.conf

Setting the custom arguments back to default value:

  $ R "ba-cli -j -l 'protected; WiFi.DaemonMgt.Daemon.hostapd.ExecutionSettings.CustomArguments="-s"' | grep CustomArguments"
  [{"WiFi.DaemonMgt.Daemon.1.ExecutionSettings.":{"CustomArguments":"-s"}}]

  $ R "ba-cli -j -l 'protected; WiFi.DaemonMgt.Daemon.hostapd.ExecutionSettings.CustomArguments?' | grep CustomArguments"
  [{"WiFi.DaemonMgt.Daemon.1.ExecutionSettings.":{"CustomArguments":"-s"}}]

  $ R "ba-cli -j -l 'protected; WiFi.DaemonMgt.Daemon.wpa_supplicant.ExecutionSettings.CustomArguments="-s"' | grep CustomArguments"
  [{"WiFi.DaemonMgt.Daemon.2.ExecutionSettings.":{"CustomArguments":"-s"}}]

  $ R "ba-cli -j -l 'protected; WiFi.DaemonMgt.Daemon.wpa_supplicant.ExecutionSettings.CustomArguments?' | grep CustomArguments"
  [{"WiFi.DaemonMgt.Daemon.2.ExecutionSettings.":{"CustomArguments":"-s"}}]

  $ sleep 10

  $ R logger -t cram "Check that hostapd and wpa_supplicant are operating with default custom argument"

  $ R "ps axw" | sed -nE 's/.*(hostapd .*)/\1/p' | head -1 | tr -s ' ' '\n' | LC_ALL=C sort
  -g
  -s
  /tmp/wlan0_hapd.conf
  /tmp/wlan1_hapd.conf
  /tmp/wlan2_hapd.conf
  /var/run/hostapd/global\.0x.* (re)
  hostapd

  $ R "ps axw" | sed -n '/[w]pa_supplicant/ { s/^.*\bwpa_supplicant[[:space:]]/wpa_supplicant /; p }' | head -3 | LC_ALL=C sort
  wpa_supplicant -s -i wlan0 -Dnl80211 -c /tmp/wlan0_wpa_supplicant.conf
  wpa_supplicant -s -i wlan1 -Dnl80211 -c /tmp/wlan1_wpa_supplicant.conf
  wpa_supplicant -s -i wlan2 -Dnl80211 -c /tmp/wlan2_wpa_supplicant.conf

  $ R "ba-cli 'Device.WiFi.EndPoint.*.Enable=0' | sed '1d' | awk 'NF'"
  Device.WiFi.EndPoint.1.
  Device.WiFi.EndPoint.1.Enable=0
  Device.WiFi.EndPoint.2.
  Device.WiFi.EndPoint.2.Enable=0
  Device.WiFi.EndPoint.3.
  Device.WiFi.EndPoint.3.Enable=0

Disabling the accesspoints back:

  $ R logger -t cram "Test AccessPoint 5 deactivation"

  $ disable_ap 5
  WiFi.AccessPoint.5 disabled

  $ sleep 5

Test deactivation of access point 3:

  $ R logger -t cram "Test AccessPoint 3 deactivation"

  $ disable_ap 3
  WiFi.AccessPoint.3 disabled

  $ sleep 5

Test deactivation of access point 1:

  $ R logger -t cram "Test AccessPoint 1 deactivation"

  $ disable_ap 1
  WiFi.AccessPoint.1 disabled

  $ sleep 5

Resume prplMesh:

  $ R "ba-cli -l X_PRPLWARE-COM_ProcessManager.PrplMesh.Enable=1" | tr -d '\n'
  1 (no-eol)

  $ R logger -t cram "Stopping PWHM test for custom arguments.."

Wait 20s before leaving the test:

  $ sleep 20

  $ R logger -t cram "Test finished!"

