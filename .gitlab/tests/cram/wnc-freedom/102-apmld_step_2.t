Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ . "${TESTDIR}/../scripts/wifi.sh"

  $ R logger -t cram "Starting APMLD test 2/2..."

Save hostap pid:

  $ hostap_pid=$(R pgrep -f 'hostapd')
  $ R logger -t cram "hostap PID : $hostap_pid"

Read private and guest MLDUnit:

  $ private_mldunit=$(get_private_mldunit)
  $ guest_mldunit=$(get_guest_mldunit)
  $ test_mldunit=12

#########################################
# Set a distinct MLDUnit                #
#########################################

Move AP1 to a new APMLD:

  $ R logger -t cram "Move AP1 to a new APMLD"
  $ wifi_dm "AccessPoint.1.SSIDReference+.MLDUnit=${test_mldunit}"
  Device.WiFi.SSID.1.MLDUnit=12

  $ sleep 10

Check private APMLD number of links:

  $ iw_affliated_link_info_from_mldid ${private_mldunit}
  addr ([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2} (re)
  addr ([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2} (re)
  channel 36 .* (re)
  channel 37 .* (re)
  link 0
  link 1

Check the new APMLD 3 number of links:

  $ iw_affliated_link_info_from_mldid ${test_mldunit}
  addr ([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2} (re)
  channel 1 .* (re)
  link 0

Read AffiliatedAP MAC addresses:

  $ iw_affilated_mac_list_from_mldid ${private_mldunit}
  link \d+ addr ([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2} (re)
  link \d+ addr ([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2} (re)

  $ iw_affilated_mac_list_from_mldid ${test_mldunit}
  link \d+ addr ([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2} (re)

Check wpacltrl socket file: AP1 interface (wlan2.1) should appear as
main link interface with one link

  $ ls_hapd_sockets
  wlan1.1
  wlan1.1_link0
  wlan1.1_link1
  wlan2.1
  wlan2.1_link0
  wlan2.2
  wlan2.2_link0
  wlan2.2_link1
  wlan2.2_link2
  wlan2.3
  wlan2.3_link0
  wlan2.3_link1
  wlan2.3_link2

Check hostapd configration file :

  $ R "cat /tmp/wlan*_hapd.conf" | grep ttlm_enable= | sort
  ttlm_enable=1
  ttlm_enable=1
  ttlm_enable=1
  ttlm_enable=1
  ttlm_enable=1
  ttlm_enable=1
  ttlm_enable=1
  ttlm_enable=1
  ttlm_enable=1

#########################################
# Restore MLDUnit                       #
#########################################

Move back AP1 to its APMLD:

  $ R logger -t cram "Move back AP1 to its previous APMLD"
  $ wifi_dm "AccessPoint.1.SSIDReference+.MLDUnit=${private_mldunit}"
  Device.WiFi.SSID.1.MLDUnit=0

  $ sleep 10

Check private APMLD number of links:

  $ iw_affliated_link_info_from_mldid ${private_mldunit}
  addr ([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2} (re)
  addr ([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2} (re)
  addr ([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2} (re)
  channel 1 .* (re)
  channel 36 .* (re)
  channel 37 .* (re)
  link 0
  link 1
  link 2

Check if new APMLD was cleared:

  $ get_apmld_mac_from_dm ${test_mldunit}
  not_found

Check hostapd configration file :

  $ R "cat /tmp/wlan*_hapd.conf" | grep ttlm_enable= | sort
  ttlm_enable=1
  ttlm_enable=1
  ttlm_enable=1
  ttlm_enable=1
  ttlm_enable=1
  ttlm_enable=1
  ttlm_enable=1
  ttlm_enable=1
  ttlm_enable=1

#########################################
# Test Guest MLD deactivation           #
#########################################

Disable guest vaps:

  $ R logger -t cram "Disable guest vaps"
  $ wifi_dm "AccessPoint.[DefaultDeviceType==\"Guest\"].Enable=0" "WiFi." "ba-cli"
  WiFi.AccessPoint.\d+.Enable=0 (re)
  WiFi.AccessPoint.\d+.Enable=0 (re)
  WiFi.AccessPoint.\d+.Enable=0 (re)

  $ sleep 10

  $ wifi_dm "AccessPoint.[DefaultDeviceType==\"Guest\"].Status?" "WiFi." "ba-cli"
  WiFi.AccessPoint.\d+.Status="Disabled" (re)
  WiFi.AccessPoint.\d+.Status="Disabled" (re)
  WiFi.AccessPoint.\d+.Status="Disabled" (re)

Check if guest apmld is cleared:

  $ wifi_dm "APMLD.2.?"
  Device.WiFi.APMLD.2.APMLDConfig.EMLMREnabled=0
  Device.WiFi.APMLD.2.APMLDConfig.EMLSREnabled=1
  Device.WiFi.APMLD.2.APMLDConfig.NSTREnabled=1
  Device.WiFi.APMLD.2.APMLDConfig.STREnabled=1
  Device.WiFi.APMLD.2.AffiliatedAPNumberOfEntries=0
  Device.WiFi.APMLD.2.MLDID=1
  Device.WiFi.APMLD.2.MLDMACAddress=""
  Device.WiFi.APMLD.2.TIDLinkMap.1.BSSID="([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}" (re)
  Device.WiFi.APMLD.2.TIDLinkMap.1.Direction="Up"
  Device.WiFi.APMLD.2.TIDLinkMap.1.LinkMapFrequencyBands=""
  Device.WiFi.APMLD.2.TIDLinkMap.1.TID=0
  Device.WiFi.APMLD.2.TIDLinkMap.10.BSSID="([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}" (re)
  Device.WiFi.APMLD.2.TIDLinkMap.10.Direction="Down"
  Device.WiFi.APMLD.2.TIDLinkMap.10.LinkMapFrequencyBands=""
  Device.WiFi.APMLD.2.TIDLinkMap.10.TID=1
  Device.WiFi.APMLD.2.TIDLinkMap.11.BSSID="([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}" (re)
  Device.WiFi.APMLD.2.TIDLinkMap.11.Direction="Down"
  Device.WiFi.APMLD.2.TIDLinkMap.11.LinkMapFrequencyBands=""
  Device.WiFi.APMLD.2.TIDLinkMap.11.TID=2
  Device.WiFi.APMLD.2.TIDLinkMap.12.BSSID="([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}" (re)
  Device.WiFi.APMLD.2.TIDLinkMap.12.Direction="Down"
  Device.WiFi.APMLD.2.TIDLinkMap.12.LinkMapFrequencyBands=""
  Device.WiFi.APMLD.2.TIDLinkMap.12.TID=3
  Device.WiFi.APMLD.2.TIDLinkMap.13.BSSID="([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}" (re)
  Device.WiFi.APMLD.2.TIDLinkMap.13.Direction="Down"
  Device.WiFi.APMLD.2.TIDLinkMap.13.LinkMapFrequencyBands=""
  Device.WiFi.APMLD.2.TIDLinkMap.13.TID=4
  Device.WiFi.APMLD.2.TIDLinkMap.14.BSSID="([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}" (re)
  Device.WiFi.APMLD.2.TIDLinkMap.14.Direction="Down"
  Device.WiFi.APMLD.2.TIDLinkMap.14.LinkMapFrequencyBands=""
  Device.WiFi.APMLD.2.TIDLinkMap.14.TID=5
  Device.WiFi.APMLD.2.TIDLinkMap.15.BSSID="([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}" (re)
  Device.WiFi.APMLD.2.TIDLinkMap.15.Direction="Down"
  Device.WiFi.APMLD.2.TIDLinkMap.15.LinkMapFrequencyBands=""
  Device.WiFi.APMLD.2.TIDLinkMap.15.TID=6
  Device.WiFi.APMLD.2.TIDLinkMap.16.BSSID="([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}" (re)
  Device.WiFi.APMLD.2.TIDLinkMap.16.Direction="Down"
  Device.WiFi.APMLD.2.TIDLinkMap.16.LinkMapFrequencyBands=""
  Device.WiFi.APMLD.2.TIDLinkMap.16.TID=7
  Device.WiFi.APMLD.2.TIDLinkMap.2.BSSID="([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}" (re)
  Device.WiFi.APMLD.2.TIDLinkMap.2.Direction="Up"
  Device.WiFi.APMLD.2.TIDLinkMap.2.LinkMapFrequencyBands=""
  Device.WiFi.APMLD.2.TIDLinkMap.2.TID=1
  Device.WiFi.APMLD.2.TIDLinkMap.3.BSSID="([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}" (re)
  Device.WiFi.APMLD.2.TIDLinkMap.3.Direction="Up"
  Device.WiFi.APMLD.2.TIDLinkMap.3.LinkMapFrequencyBands=""
  Device.WiFi.APMLD.2.TIDLinkMap.3.TID=2
  Device.WiFi.APMLD.2.TIDLinkMap.4.BSSID="([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}" (re)
  Device.WiFi.APMLD.2.TIDLinkMap.4.Direction="Up"
  Device.WiFi.APMLD.2.TIDLinkMap.4.LinkMapFrequencyBands=""
  Device.WiFi.APMLD.2.TIDLinkMap.4.TID=3
  Device.WiFi.APMLD.2.TIDLinkMap.5.BSSID="([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}" (re)
  Device.WiFi.APMLD.2.TIDLinkMap.5.Direction="Up"
  Device.WiFi.APMLD.2.TIDLinkMap.5.LinkMapFrequencyBands=""
  Device.WiFi.APMLD.2.TIDLinkMap.5.TID=4
  Device.WiFi.APMLD.2.TIDLinkMap.6.BSSID="([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}" (re)
  Device.WiFi.APMLD.2.TIDLinkMap.6.Direction="Up"
  Device.WiFi.APMLD.2.TIDLinkMap.6.LinkMapFrequencyBands=""
  Device.WiFi.APMLD.2.TIDLinkMap.6.TID=5
  Device.WiFi.APMLD.2.TIDLinkMap.7.BSSID="([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}" (re)
  Device.WiFi.APMLD.2.TIDLinkMap.7.Direction="Up"
  Device.WiFi.APMLD.2.TIDLinkMap.7.LinkMapFrequencyBands=""
  Device.WiFi.APMLD.2.TIDLinkMap.7.TID=6
  Device.WiFi.APMLD.2.TIDLinkMap.8.BSSID="([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}" (re)
  Device.WiFi.APMLD.2.TIDLinkMap.8.Direction="Up"
  Device.WiFi.APMLD.2.TIDLinkMap.8.LinkMapFrequencyBands=""
  Device.WiFi.APMLD.2.TIDLinkMap.8.TID=7
  Device.WiFi.APMLD.2.TIDLinkMap.9.BSSID="([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}" (re)
  Device.WiFi.APMLD.2.TIDLinkMap.9.Direction="Down"
  Device.WiFi.APMLD.2.TIDLinkMap.9.LinkMapFrequencyBands=""
  Device.WiFi.APMLD.2.TIDLinkMap.9.TID=0
  Device.WiFi.APMLD.2.TIDLinkMapConfig.AdvertisedExpectedDuration=300
  Device.WiFi.APMLD.2.TIDLinkMapConfig.AdvertisedLinkMapFrequencyBands=""
  Device.WiFi.APMLD.2.TIDLinkMapConfig.AdvertisedMapSwitchTime=100
  Device.WiFi.APMLD.2.TIDLinkMapConfig.Mode="Advertised"

#########################################
# Test TIDLinkMap                       #
#########################################

Check TIDLinkMapConfig before setting new mode:

  $ R logger -t cram "Test TIDLinkMap default config"
  $ wifi_dm "APMLD.1.TIDLinkMapConfig.?"
  Device.WiFi.APMLD.1.TIDLinkMapConfig.AdvertisedExpectedDuration=300
  Device.WiFi.APMLD.1.TIDLinkMapConfig.AdvertisedLinkMapFrequencyBands=""
  Device.WiFi.APMLD.1.TIDLinkMapConfig.AdvertisedMapSwitchTime=100
  Device.WiFi.APMLD.1.TIDLinkMapConfig.Mode="Advertised"

  $ wifi_dm "APMLD.1.TIDLinkMap.?"
  Device.WiFi.APMLD.1.TIDLinkMap.1.BSSID="([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}" (re)
  Device.WiFi.APMLD.1.TIDLinkMap.1.Direction="Up"
  Device.WiFi.APMLD.1.TIDLinkMap.1.LinkMapFrequencyBands=""
  Device.WiFi.APMLD.1.TIDLinkMap.1.TID=0
  Device.WiFi.APMLD.1.TIDLinkMap.10.BSSID="([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}" (re)
  Device.WiFi.APMLD.1.TIDLinkMap.10.Direction="Down"
  Device.WiFi.APMLD.1.TIDLinkMap.10.LinkMapFrequencyBands=""
  Device.WiFi.APMLD.1.TIDLinkMap.10.TID=1
  Device.WiFi.APMLD.1.TIDLinkMap.11.BSSID="([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}" (re)
  Device.WiFi.APMLD.1.TIDLinkMap.11.Direction="Down"
  Device.WiFi.APMLD.1.TIDLinkMap.11.LinkMapFrequencyBands=""
  Device.WiFi.APMLD.1.TIDLinkMap.11.TID=2
  Device.WiFi.APMLD.1.TIDLinkMap.12.BSSID="([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}" (re)
  Device.WiFi.APMLD.1.TIDLinkMap.12.Direction="Down"
  Device.WiFi.APMLD.1.TIDLinkMap.12.LinkMapFrequencyBands=""
  Device.WiFi.APMLD.1.TIDLinkMap.12.TID=3
  Device.WiFi.APMLD.1.TIDLinkMap.13.BSSID="([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}" (re)
  Device.WiFi.APMLD.1.TIDLinkMap.13.Direction="Down"
  Device.WiFi.APMLD.1.TIDLinkMap.13.LinkMapFrequencyBands=""
  Device.WiFi.APMLD.1.TIDLinkMap.13.TID=4
  Device.WiFi.APMLD.1.TIDLinkMap.14.BSSID="([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}" (re)
  Device.WiFi.APMLD.1.TIDLinkMap.14.Direction="Down"
  Device.WiFi.APMLD.1.TIDLinkMap.14.LinkMapFrequencyBands=""
  Device.WiFi.APMLD.1.TIDLinkMap.14.TID=5
  Device.WiFi.APMLD.1.TIDLinkMap.15.BSSID="([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}" (re)
  Device.WiFi.APMLD.1.TIDLinkMap.15.Direction="Down"
  Device.WiFi.APMLD.1.TIDLinkMap.15.LinkMapFrequencyBands=""
  Device.WiFi.APMLD.1.TIDLinkMap.15.TID=6
  Device.WiFi.APMLD.1.TIDLinkMap.16.BSSID="([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}" (re)
  Device.WiFi.APMLD.1.TIDLinkMap.16.Direction="Down"
  Device.WiFi.APMLD.1.TIDLinkMap.16.LinkMapFrequencyBands=""
  Device.WiFi.APMLD.1.TIDLinkMap.16.TID=7
  Device.WiFi.APMLD.1.TIDLinkMap.2.BSSID="([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}" (re)
  Device.WiFi.APMLD.1.TIDLinkMap.2.Direction="Up"
  Device.WiFi.APMLD.1.TIDLinkMap.2.LinkMapFrequencyBands=""
  Device.WiFi.APMLD.1.TIDLinkMap.2.TID=1
  Device.WiFi.APMLD.1.TIDLinkMap.3.BSSID="([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}" (re)
  Device.WiFi.APMLD.1.TIDLinkMap.3.Direction="Up"
  Device.WiFi.APMLD.1.TIDLinkMap.3.LinkMapFrequencyBands=""
  Device.WiFi.APMLD.1.TIDLinkMap.3.TID=2
  Device.WiFi.APMLD.1.TIDLinkMap.4.BSSID="([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}" (re)
  Device.WiFi.APMLD.1.TIDLinkMap.4.Direction="Up"
  Device.WiFi.APMLD.1.TIDLinkMap.4.LinkMapFrequencyBands=""
  Device.WiFi.APMLD.1.TIDLinkMap.4.TID=3
  Device.WiFi.APMLD.1.TIDLinkMap.5.BSSID="([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}" (re)
  Device.WiFi.APMLD.1.TIDLinkMap.5.Direction="Up"
  Device.WiFi.APMLD.1.TIDLinkMap.5.LinkMapFrequencyBands=""
  Device.WiFi.APMLD.1.TIDLinkMap.5.TID=4
  Device.WiFi.APMLD.1.TIDLinkMap.6.BSSID="([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}" (re)
  Device.WiFi.APMLD.1.TIDLinkMap.6.Direction="Up"
  Device.WiFi.APMLD.1.TIDLinkMap.6.LinkMapFrequencyBands=""
  Device.WiFi.APMLD.1.TIDLinkMap.6.TID=5
  Device.WiFi.APMLD.1.TIDLinkMap.7.BSSID="([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}" (re)
  Device.WiFi.APMLD.1.TIDLinkMap.7.Direction="Up"
  Device.WiFi.APMLD.1.TIDLinkMap.7.LinkMapFrequencyBands=""
  Device.WiFi.APMLD.1.TIDLinkMap.7.TID=6
  Device.WiFi.APMLD.1.TIDLinkMap.8.BSSID="([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}" (re)
  Device.WiFi.APMLD.1.TIDLinkMap.8.Direction="Up"
  Device.WiFi.APMLD.1.TIDLinkMap.8.LinkMapFrequencyBands=""
  Device.WiFi.APMLD.1.TIDLinkMap.8.TID=7
  Device.WiFi.APMLD.1.TIDLinkMap.9.BSSID="([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}" (re)
  Device.WiFi.APMLD.1.TIDLinkMap.9.Direction="Down"
  Device.WiFi.APMLD.1.TIDLinkMap.9.LinkMapFrequencyBands=""
  Device.WiFi.APMLD.1.TIDLinkMap.9.TID=0

Force 2.4GHz link usage:

  $ wifi_dm "APMLD.1.TIDLinkMapConfig.AdvertisedLinkMapFrequencyBands=\"2.4GHz\""
  Device.WiFi.APMLD.1.TIDLinkMapConfig.AdvertisedLinkMapFrequencyBands="2.4GHz"

  $ sleep 5

Check if all TIDLinkMap are now set to 2.4GHz:

  $ wifi_dm "APMLD.1.TIDLinkMap.*.LinkMapFrequencyBands?"
  Device.WiFi.APMLD.1.TIDLinkMap.1.LinkMapFrequencyBands="2.4GHz"
  Device.WiFi.APMLD.1.TIDLinkMap.10.LinkMapFrequencyBands="2.4GHz"
  Device.WiFi.APMLD.1.TIDLinkMap.11.LinkMapFrequencyBands="2.4GHz"
  Device.WiFi.APMLD.1.TIDLinkMap.12.LinkMapFrequencyBands="2.4GHz"
  Device.WiFi.APMLD.1.TIDLinkMap.13.LinkMapFrequencyBands="2.4GHz"
  Device.WiFi.APMLD.1.TIDLinkMap.14.LinkMapFrequencyBands="2.4GHz"
  Device.WiFi.APMLD.1.TIDLinkMap.15.LinkMapFrequencyBands="2.4GHz"
  Device.WiFi.APMLD.1.TIDLinkMap.16.LinkMapFrequencyBands="2.4GHz"
  Device.WiFi.APMLD.1.TIDLinkMap.2.LinkMapFrequencyBands="2.4GHz"
  Device.WiFi.APMLD.1.TIDLinkMap.3.LinkMapFrequencyBands="2.4GHz"
  Device.WiFi.APMLD.1.TIDLinkMap.4.LinkMapFrequencyBands="2.4GHz"
  Device.WiFi.APMLD.1.TIDLinkMap.5.LinkMapFrequencyBands="2.4GHz"
  Device.WiFi.APMLD.1.TIDLinkMap.6.LinkMapFrequencyBands="2.4GHz"
  Device.WiFi.APMLD.1.TIDLinkMap.7.LinkMapFrequencyBands="2.4GHz"
  Device.WiFi.APMLD.1.TIDLinkMap.8.LinkMapFrequencyBands="2.4GHz"
  Device.WiFi.APMLD.1.TIDLinkMap.9.LinkMapFrequencyBands="2.4GHz"

Clear AdvertisedLinkMapFrequencyBands:

  $ R logger -t cram "Clear AdvertisedLinkMapFrequencyBands"
  $ wifi_dm "APMLD.1.TIDLinkMapConfig.AdvertisedLinkMapFrequencyBands=\"\""
  Device.WiFi.APMLD.1.TIDLinkMapConfig.AdvertisedLinkMapFrequencyBands=""

  $ sleep 5

Check if all TIDLinkMap are now cleared:

  $ wifi_dm "APMLD.1.TIDLinkMap.*.LinkMapFrequencyBands?"
  Device.WiFi.APMLD.1.TIDLinkMap.1.LinkMapFrequencyBands=""
  Device.WiFi.APMLD.1.TIDLinkMap.10.LinkMapFrequencyBands=""
  Device.WiFi.APMLD.1.TIDLinkMap.11.LinkMapFrequencyBands=""
  Device.WiFi.APMLD.1.TIDLinkMap.12.LinkMapFrequencyBands=""
  Device.WiFi.APMLD.1.TIDLinkMap.13.LinkMapFrequencyBands=""
  Device.WiFi.APMLD.1.TIDLinkMap.14.LinkMapFrequencyBands=""
  Device.WiFi.APMLD.1.TIDLinkMap.15.LinkMapFrequencyBands=""
  Device.WiFi.APMLD.1.TIDLinkMap.16.LinkMapFrequencyBands=""
  Device.WiFi.APMLD.1.TIDLinkMap.2.LinkMapFrequencyBands=""
  Device.WiFi.APMLD.1.TIDLinkMap.3.LinkMapFrequencyBands=""
  Device.WiFi.APMLD.1.TIDLinkMap.4.LinkMapFrequencyBands=""
  Device.WiFi.APMLD.1.TIDLinkMap.5.LinkMapFrequencyBands=""
  Device.WiFi.APMLD.1.TIDLinkMap.6.LinkMapFrequencyBands=""
  Device.WiFi.APMLD.1.TIDLinkMap.7.LinkMapFrequencyBands=""
  Device.WiFi.APMLD.1.TIDLinkMap.8.LinkMapFrequencyBands=""
  Device.WiFi.APMLD.1.TIDLinkMap.9.LinkMapFrequencyBands=""

Disable TIDLinkMap on private MLD:

  $ R logger -t cram "Disable TIDLinkMap on private MLD"
  $ wifi_dm "APMLD.1.TIDLinkMapConfig.Mode=\"Disabled\""
  Device.WiFi.APMLD.1.TIDLinkMapConfig.Mode="Disabled"

  $ sleep 5

Check hostapd configration file (assume guest APMLD deactivated):

  $ itf=$(wifi_dm "AccessPoint.1.SSIDReference+.Name?" | cut -d'"' -f2)
  $ get_hapd_config $itf ttlm_enable
  0

  $ itf=$(wifi_dm "AccessPoint.3.SSIDReference+.Name?" | cut -d'"' -f2)
  $ get_hapd_config $itf ttlm_enable
  0

  $ itf=$(wifi_dm "AccessPoint.5.SSIDReference+.Name?" | cut -d'"' -f2)
  $ get_hapd_config $itf ttlm_enable
  0

  $ R "cat /tmp/wlan*_hapd.conf" | grep ttlm_enable= | sort
  ttlm_enable=0
  ttlm_enable=0
  ttlm_enable=0
  ttlm_enable=1
  ttlm_enable=1
  ttlm_enable=1

Restore mode:

  $ wifi_dm "APMLD.1.TIDLinkMapConfig.Mode=\"Advertised\""
  Device.WiFi.APMLD.1.TIDLinkMapConfig.Mode="Advertised"

  $ sleep 5

  $ R "cat /tmp/wlan*_hapd.conf" | grep ttlm_enable= | sort
  ttlm_enable=1
  ttlm_enable=1
  ttlm_enable=1
  ttlm_enable=1
  ttlm_enable=1
  ttlm_enable=1

#########################################
# Terminate test                       #
#########################################

Before deactivating all vaps, check if hostap pid has changed or not:

  $ if [ "$(R pgrep -f 'hostapd')" = "$hostap_pid" ]; then echo "true"; else echo "hostap restarted during the test !"; fi
  true

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

Check if private apmld is cleared:

  $ wifi_dm "APMLD.1.?"
  Device.WiFi.APMLD.1.APMLDConfig.EMLMREnabled=0
  Device.WiFi.APMLD.1.APMLDConfig.EMLSREnabled=1
  Device.WiFi.APMLD.1.APMLDConfig.NSTREnabled=1
  Device.WiFi.APMLD.1.APMLDConfig.STREnabled=1
  Device.WiFi.APMLD.1.AffiliatedAPNumberOfEntries=0
  Device.WiFi.APMLD.1.MLDID=0
  Device.WiFi.APMLD.1.MLDMACAddress=""
  Device.WiFi.APMLD.1.TIDLinkMap.1.BSSID="([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}" (re)
  Device.WiFi.APMLD.1.TIDLinkMap.1.Direction="Up"
  Device.WiFi.APMLD.1.TIDLinkMap.1.LinkMapFrequencyBands=""
  Device.WiFi.APMLD.1.TIDLinkMap.1.TID=0
  Device.WiFi.APMLD.1.TIDLinkMap.10.BSSID="([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}" (re)
  Device.WiFi.APMLD.1.TIDLinkMap.10.Direction="Down"
  Device.WiFi.APMLD.1.TIDLinkMap.10.LinkMapFrequencyBands=""
  Device.WiFi.APMLD.1.TIDLinkMap.10.TID=1
  Device.WiFi.APMLD.1.TIDLinkMap.11.BSSID="([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}" (re)
  Device.WiFi.APMLD.1.TIDLinkMap.11.Direction="Down"
  Device.WiFi.APMLD.1.TIDLinkMap.11.LinkMapFrequencyBands=""
  Device.WiFi.APMLD.1.TIDLinkMap.11.TID=2
  Device.WiFi.APMLD.1.TIDLinkMap.12.BSSID="([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}" (re)
  Device.WiFi.APMLD.1.TIDLinkMap.12.Direction="Down"
  Device.WiFi.APMLD.1.TIDLinkMap.12.LinkMapFrequencyBands=""
  Device.WiFi.APMLD.1.TIDLinkMap.12.TID=3
  Device.WiFi.APMLD.1.TIDLinkMap.13.BSSID="([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}" (re)
  Device.WiFi.APMLD.1.TIDLinkMap.13.Direction="Down"
  Device.WiFi.APMLD.1.TIDLinkMap.13.LinkMapFrequencyBands=""
  Device.WiFi.APMLD.1.TIDLinkMap.13.TID=4
  Device.WiFi.APMLD.1.TIDLinkMap.14.BSSID="([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}" (re)
  Device.WiFi.APMLD.1.TIDLinkMap.14.Direction="Down"
  Device.WiFi.APMLD.1.TIDLinkMap.14.LinkMapFrequencyBands=""
  Device.WiFi.APMLD.1.TIDLinkMap.14.TID=5
  Device.WiFi.APMLD.1.TIDLinkMap.15.BSSID="([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}" (re)
  Device.WiFi.APMLD.1.TIDLinkMap.15.Direction="Down"
  Device.WiFi.APMLD.1.TIDLinkMap.15.LinkMapFrequencyBands=""
  Device.WiFi.APMLD.1.TIDLinkMap.15.TID=6
  Device.WiFi.APMLD.1.TIDLinkMap.16.BSSID="([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}" (re)
  Device.WiFi.APMLD.1.TIDLinkMap.16.Direction="Down"
  Device.WiFi.APMLD.1.TIDLinkMap.16.LinkMapFrequencyBands=""
  Device.WiFi.APMLD.1.TIDLinkMap.16.TID=7
  Device.WiFi.APMLD.1.TIDLinkMap.2.BSSID="([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}" (re)
  Device.WiFi.APMLD.1.TIDLinkMap.2.Direction="Up"
  Device.WiFi.APMLD.1.TIDLinkMap.2.LinkMapFrequencyBands=""
  Device.WiFi.APMLD.1.TIDLinkMap.2.TID=1
  Device.WiFi.APMLD.1.TIDLinkMap.3.BSSID="([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}" (re)
  Device.WiFi.APMLD.1.TIDLinkMap.3.Direction="Up"
  Device.WiFi.APMLD.1.TIDLinkMap.3.LinkMapFrequencyBands=""
  Device.WiFi.APMLD.1.TIDLinkMap.3.TID=2
  Device.WiFi.APMLD.1.TIDLinkMap.4.BSSID="([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}" (re)
  Device.WiFi.APMLD.1.TIDLinkMap.4.Direction="Up"
  Device.WiFi.APMLD.1.TIDLinkMap.4.LinkMapFrequencyBands=""
  Device.WiFi.APMLD.1.TIDLinkMap.4.TID=3
  Device.WiFi.APMLD.1.TIDLinkMap.5.BSSID="([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}" (re)
  Device.WiFi.APMLD.1.TIDLinkMap.5.Direction="Up"
  Device.WiFi.APMLD.1.TIDLinkMap.5.LinkMapFrequencyBands=""
  Device.WiFi.APMLD.1.TIDLinkMap.5.TID=4
  Device.WiFi.APMLD.1.TIDLinkMap.6.BSSID="([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}" (re)
  Device.WiFi.APMLD.1.TIDLinkMap.6.Direction="Up"
  Device.WiFi.APMLD.1.TIDLinkMap.6.LinkMapFrequencyBands=""
  Device.WiFi.APMLD.1.TIDLinkMap.6.TID=5
  Device.WiFi.APMLD.1.TIDLinkMap.7.BSSID="([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}" (re)
  Device.WiFi.APMLD.1.TIDLinkMap.7.Direction="Up"
  Device.WiFi.APMLD.1.TIDLinkMap.7.LinkMapFrequencyBands=""
  Device.WiFi.APMLD.1.TIDLinkMap.7.TID=6
  Device.WiFi.APMLD.1.TIDLinkMap.8.BSSID="([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}" (re)
  Device.WiFi.APMLD.1.TIDLinkMap.8.Direction="Up"
  Device.WiFi.APMLD.1.TIDLinkMap.8.LinkMapFrequencyBands=""
  Device.WiFi.APMLD.1.TIDLinkMap.8.TID=7
  Device.WiFi.APMLD.1.TIDLinkMap.9.BSSID="([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}" (re)
  Device.WiFi.APMLD.1.TIDLinkMap.9.Direction="Down"
  Device.WiFi.APMLD.1.TIDLinkMap.9.LinkMapFrequencyBands=""
  Device.WiFi.APMLD.1.TIDLinkMap.9.TID=0
  Device.WiFi.APMLD.1.TIDLinkMapConfig.AdvertisedExpectedDuration=300
  Device.WiFi.APMLD.1.TIDLinkMapConfig.AdvertisedLinkMapFrequencyBands=""
  Device.WiFi.APMLD.1.TIDLinkMapConfig.AdvertisedMapSwitchTime=100
  Device.WiFi.APMLD.1.TIDLinkMapConfig.Mode="Advertised"

Resume prplMesh:

  $ R "ba-cli -l X_PRPLWARE-COM_ProcessManager.PrplMesh.Enable=1" | tr -d '\n'
  1 (no-eol)

  $ sleep 10
  $ R logger -t cram "Test finished!"
