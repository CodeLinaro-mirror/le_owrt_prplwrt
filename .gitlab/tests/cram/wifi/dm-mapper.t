Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

  $ R logger -t cram "Starting DM Mapper test ..."

Check Ubus DM and DataModelMapper USP DM shows same values

  $ WIFI_SSID_1=$(R "ba-cli -j -l WiFi.SSID.1.SSID? | jsonfilter -e '@[0][\"WiFi.SSID.1.\"].SSID'")
  $ MAPPED_WIFI_SSID_1=$(R "usp-cli -j -l Device.WiFi.SSID.1.SSID? | jsonfilter -e '@[0][\"Device.WiFi.SSID.1.\"].SSID'")
  $ USP_WIFI_SSID_1=$(R "obuspa -f /etc/obuspa.db -c get  Device.WiFi.SSID.1.SSID | sed -n 's/^.* => //p'")

  $ [ "$WIFI_SSID_1" = "$MAPPED_WIFI_SSID_1" ]
  $ [ "$USP_WIFI_SSID_1" = "$MAPPED_WIFI_SSID_1" ]

Change a DM from Ubus and Check Again:

  $ R "ba-cli -j -l WiFi.SSID.1.SSID=\"prplOSnew\" | sed '/^$/d'"
  [{"WiFi.SSID.1.":{"SSID":"prplOSnew"}}]

  $ sleep 2

  $ WIFI_SSID_1=$(R "ba-cli -j -l WiFi.SSID.1.SSID? | jsonfilter -e '@[0][\"WiFi.SSID.1.\"].SSID'")
  $ MAPPED_WIFI_SSID_1=$(R "usp-cli -j -l Device.WiFi.SSID.1.SSID? | jsonfilter -e '@[0][\"Device.WiFi.SSID.1.\"].SSID'")
  $ USP_WIFI_SSID_1=$(R "obuspa -f /etc/obuspa.db -c get  Device.WiFi.SSID.1.SSID | sed -n 's/^.* => //p'")

  $ [ "$WIFI_SSID_1" = "$MAPPED_WIFI_SSID_1" ]
  $ [ "$USP_WIFI_SSID_1" = "$MAPPED_WIFI_SSID_1" ]
 
Change a DM from Mapper and Check Again:

  $ R "obuspa -f /etc/obuspa.db -c set Device.WiFi.SSID.2.SSID \"prplOSnew2\""
  Device.WiFi.SSID.2.SSID => prplOSnew2

  $ sleep 2

  $ WIFI_SSID_2=$(R "ba-cli -j -l WiFi.SSID.2.SSID? | jsonfilter -e '@[0][\"WiFi.SSID.2.\"].SSID'")
  $ MAPPED_WIFI_SSID_2=$(R "usp-cli -j -l Device.WiFi.SSID.2.SSID? | jsonfilter -e '@[0][\"Device.WiFi.SSID.2.\"].SSID'")
  $ USP_WIFI_SSID_2=$(R "obuspa -f /etc/obuspa.db -c get  Device.WiFi.SSID.2.SSID | sed -n 's/^.* => //p'")

  $ [ "$WIFI_SSID_2" = "$MAPPED_WIFI_SSID_2" ]
  $ [ "$USP_WIFI_SSID_2" = "$MAPPED_WIFI_SSID_2" ]

Restart WiFiSensing mapper service and verify DM disappears/returns:
 
  $ R "amx_wait_for Device.WiFi.X_PRPLWARE-COM_WiFiSensing."

  $ R "service wifi-sensing stop"

  $ sleep 3

  $ R "service wifi-sensing start"

  $ R "amx_wait_for Device.WiFi.X_PRPLWARE-COM_WiFiSensing."

Write invalid value to Device.WiFi.AccessPoint.1.Enable and expect error:

  $ R "usp-cli -j -l Device.WiFi.AccessPoint.1.Enable=notabool 2>&1 | sed '/^$/d' | sed 's/ failed.*/ failed is OK/'"
  ERROR: set Device.WiFi.AccessPoint.1.Enable failed is OK

Write to non-existent parameter must fail:

  $ R "usp-cli -j -l Device.WiFi.AccessPoint.1.NotExist=param 2>&1 | sed '/^$/d' | sed 's/ failed.*/ failed is OK/'"
  ERROR: set Device.WiFi.AccessPoint.1.NotExist failed is OK

  $ R logger -t cram "Finished DM Mapper test."

