Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ . "${TESTDIR}/../scripts/wifi.sh"

  $ R logger -t cram "Starting PWHM AFC test ..."

Stop prplMesh:

  $ R "ba-cli -l X_PRPLWARE-COM_ProcessManager.PrplMesh.Enable=0" | tr -d '\n'
  0 (no-eol)

  $ sleep 2

  $ R "ba-cli -l X_PRPLWARE-COM_ProcessManager.PrplMesh.Status?" | tr -d '\n'
  Idle (no-eol)

Wait for Device.WiFi. datamodel availability:

  $ R 'amx_wait_for "Device.WiFi." '

Activate 6GHz vaps:

  $ R logger -t cram "Activate 6GHz vaps"

  $ enable_ap_sync 5 1
  AccessPoint.\d+.Enable=1 (re)

  $ sleep 2


  $ enable_ap_sync 6 1
  AccessPoint.\d+.Enable=1 (re)

  $ sleep 2

  $ enable_ap_sync 9 1
  AccessPoint.\d+.Enable=1 (re)


Check AccessPoints status:

  $ wifi_dm "AccessPoint.*.Status?0"
  Device.WiFi.AccessPoint.1.Status="Disabled"
  Device.WiFi.AccessPoint.2.Status="Disabled"
  Device.WiFi.AccessPoint.3.Status="Disabled"
  Device.WiFi.AccessPoint.4.Status="Disabled"
  Device.WiFi.AccessPoint.5.Status="Enabled"
  Device.WiFi.AccessPoint.6.Status="Enabled"
  Device.WiFi.AccessPoint.7.Status="Disabled"
  Device.WiFi.AccessPoint.8.Status="Disabled"
  Device.WiFi.AccessPoint.9.Status="Enabled"

  $ sleep 10

Check that hostapd is operating as expected:

  $ R logger -t cram "Check that hostapd is operating"

  $ R "ps axw" | sed -nE 's/.*(hostapd .*)/\1/p' | head -1 | tr -s ' ' '\n' | LC_ALL=C sort
  -g
  -s
  /tmp/wlan0_hapd.conf
  /var/run/hostapd/global\.0x.* (re)
  hostapd

Check default country code and Power Type of 6GHz:

  $ dm_radio_powertype_get 3
  Indoor

  $ dm_radio_regulatory_domain_set DE
  DE
  DE
  DE

  $ dm_radio_regulatory_domain_get
  DE
  DE
  DE

  $ sleep 5

Check that hostapd is operating as expected:

  $ R logger -t cram "Check that hostapd is operating"

  $ R "ps axw" | sed -nE 's/.*(hostapd .*)/\1/p' | head -1 | tr -s ' ' '\n' | LC_ALL=C sort
  -g
  -s
  /tmp/wlan0_hapd.conf
  /var/run/hostapd/global\.0x.* (re)
  hostapd

Set 6ghz power type to VeryLowPower for DE countrycode:

  $ dm_radio_powertype_set 3 VeryLowPower
  VeryLowPower

  $ dm_radio_powertype_get 3
  VeryLowPower

  $ sleep 10

Check 6GHz regulatory power type in hostapd config (VeryLowPower = 2):

  $ R "cat /tmp/wlan0_hapd.conf | grep -i he_6ghz_reg_pwr_type"
  he_6ghz_reg_pwr_type=2

Check that hostapd is operating as expected:

  $ R logger -t cram "Check that hostapd is operating"

  $ R "ps axw" | sed -nE 's/.*(hostapd .*)/\1/p' | head -1 | tr -s ' ' '\n' | LC_ALL=C sort
  -g
  -s
  /tmp/wlan0_hapd.conf
  /var/run/hostapd/global\.0x.* (re)
  hostapd


  $ dm_radio_powertype_set 3 Indoor
  Indoor

  $ dm_radio_regulatory_domain_set US
  US
  US
  US

  $ sleep 10

Check 6GHz regulatory power type in hostapd config (Indoor = 0):

  $ R "cat /tmp/wlan0_hapd.conf | grep -i he_6ghz_reg_pwr_type"
  he_6ghz_reg_pwr_type=0

Check that hostapd is operating as expected:

  $ R logger -t cram "Check that hostapd is operating"

  $ R "ps axw" | sed -nE 's/.*(hostapd .*)/\1/p' | head -1 | tr -s ' ' '\n' | LC_ALL=C sort
  -g
  -s
  /tmp/wlan0_hapd.conf
  /var/run/hostapd/global\.0x.* (re)
  hostapd


Disable all vaps:

  $ R logger -t cram "Disable all vaps"
  $ wifi_dm "AccessPoint.*.Enable=0"
  Device.WiFi.AccessPoint.1.Enable=0
  Device.WiFi.AccessPoint.2.Enable=0
  Device.WiFi.AccessPoint.3.Enable=0
  Device.WiFi.AccessPoint.4.Enable=0
  Device.WiFi.AccessPoint.5.Enable=0
  Device.WiFi.AccessPoint.6.Enable=0
  Device.WiFi.AccessPoint.7.Enable=0
  Device.WiFi.AccessPoint.8.Enable=0
  Device.WiFi.AccessPoint.9.Enable=0

  $ sleep 10

Check AccessPoints status:

  $ wifi_dm "AccessPoint.*.Status?0"
  Device.WiFi.AccessPoint.1.Status="Disabled"
  Device.WiFi.AccessPoint.2.Status="Disabled"
  Device.WiFi.AccessPoint.3.Status="Disabled"
  Device.WiFi.AccessPoint.4.Status="Disabled"
  Device.WiFi.AccessPoint.5.Status="Disabled"
  Device.WiFi.AccessPoint.6.Status="Disabled"
  Device.WiFi.AccessPoint.7.Status="Disabled"
  Device.WiFi.AccessPoint.8.Status="Disabled"
  Device.WiFi.AccessPoint.9.Status="Disabled"

Check if hostapd process is stopped:

  $ R "pgrep -f 'hostapd'"
  [1]

Resume prplMesh:

  $ R "ba-cli -l X_PRPLWARE-COM_ProcessManager.PrplMesh.Enable=1" | tr -d '\n'
  1 (no-eol)

  $ sleep 2

  $ R "ba-cli -l X_PRPLWARE-COM_ProcessManager.PrplMesh.Status?" | tr -d '\n'
  Active (no-eol)

  $ R logger -t cram "Stopping PWHM AFC test .."

Wait 5s before leaving the test:

  $ sleep 5

  $ R logger -t cram "Test finished!"

