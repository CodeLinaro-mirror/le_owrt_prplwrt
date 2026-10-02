Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ . "${TESTDIR}/../scripts/wifi.sh"

  $ R logger -t cram "Starting $TESTFILE"

  $ prplmesh_stop

#####################################
# Test Enable/Disable all EndPoints # 
#####################################

Enable all EndPoints

  $ R logger -t cram "Enable all EndPoints"

  $ wifi_dm "EndPoint.*.Enable=1"
  Device.WiFi.EndPoint.1.Enable=1
  Device.WiFi.EndPoint.2.Enable=1
  Device.WiFi.EndPoint.3.Enable=1

  $ sleep 2

Check one wpa_supplicant process is running:

  $ R "pgrep wpa_supplicant"
  \d+ (re)

  $ R "ps axw" | sed -nE 's/.*(wpa_supplicant .*)/\1/p' | head -1 | tr -s ' ' '\n'
  wpa_supplicant
  -s
  -g
  /var/run/wpa_supplicant/global\.0x.* (re)
  -i
  wlan0
  -Dnl80211
  -c
  /tmp/wlan0_wpa_supplicant.conf
  -N
  -i
  wlan1
  -Dnl80211
  -c
  /tmp/wlan1_wpa_supplicant.conf
  -N
  -i
  wlan2
  -Dnl80211
  -c
  /tmp/wlan2_wpa_supplicant.conf

Check wpaCtrl sockets in /var/run/wpa_supplicant:

  $ ls_wpa_sockets
  wlan0
  wlan1
  wlan2

Disable all EndPoints:

  $ R logger -t cram "Disable all EndPoints"

  $ wifi_dm "EndPoint.*.Enable=0"
  Device.WiFi.EndPoint.1.Enable=0
  Device.WiFi.EndPoint.2.Enable=0
  Device.WiFi.EndPoint.3.Enable=0

  $ sleep 2

Check wpa_supplicant is stopped:

  $ R "pgrep -f 'wpa_supplicant'"
  [1]

  $ ls_wpa_sockets

#####################################
#        Test Ep activation         #
#####################################

Enable 2.4GHz endpoint:

  $ R logger -t cram "Enable 2.4GHz endpoint"

  $ wifi_dm "EndPoint.1.Enable=1"
  Device.WiFi.EndPoint.1.Enable=1

  $ sleep 2

Check one wpa_supplicant process is running:
  $ R "pgrep wpa_supplicant"
  \d+ (re)

  $ R "ps axw" | sed -nE 's/.*(wpa_supplicant .*)/\1/p' | head -1 | tr -s ' ' '\n' | LC_ALL=C sort
  -Dnl80211
  -c
  -g
  -i
  -s
  /tmp/wlan2_wpa_supplicant.conf
  /var/run/wpa_supplicant/global\.0x.* (re)
  wlan2
  wpa_supplicant

  $ wpa_pid=$(R "pgrep wpa_supplicant")
  $ R logger -t cram "wpa_supplicant PID: $wpa_pid"

Check one wpaCtrl socket (wlan2) in /var/run/wpa_supplicant:

  $ ls_wpa_sockets
  wlan2

  $ ilist_wpa_old=
  $ ilist_wpa_new=$(read_wpa_inodes)
  $ compare_list "$ilist_wpa_old" "$ilist_wpa_new"
  A: .* /var/run/wpa_supplicant/wlan2 (re)

  $ ilist_wpa_old=$ilist_wpa_new

Enable 5GHz endpoint:

  $ R logger -t cram "Enable 5GHz endpoint"

  $ wifi_dm "EndPoint.2.Enable=1"
  Device.WiFi.EndPoint.2.Enable=1

  $ sleep 2

Check same wpa_supplicant pid, two wpaCtrl sockets (wlan1 and wlan2):

  $ if [ "$(R pgrep -f 'wpa_supplicant')" = "$wpa_pid" ]; then echo "true"; else echo "wpa_supplicant restarted !"; fi
  true

  $ ls_wpa_sockets
  wlan1
  wlan2

  $ ilist_wpa_new=$(read_wpa_inodes)
  $ compare_list "$ilist_wpa_old" "$ilist_wpa_new"
  A: .* /var/run/wpa_supplicant/wlan1 (re)

  $ ilist_wpa_old=$ilist_wpa_new

Enable 6GHz endpoint:

  $ R logger -t cram "Enable 6GHz endpoint"

  $ wifi_dm "EndPoint.3.Enable=1"
  Device.WiFi.EndPoint.3.Enable=1

  $ sleep 2

Check same wpa_supplicant pid, three wpaCtrl sockets (wlan0, wlan1 and wlan2):

  $ if [ "$(R pgrep -f 'wpa_supplicant')" = "$wpa_pid" ]; then echo "true"; else echo "wpa_supplicant restarted !"; fi
  true

  $ ls_wpa_sockets
  wlan0
  wlan1
  wlan2

  $ ilist_wpa_new=$(read_wpa_inodes)
  $ compare_list "$ilist_wpa_old" "$ilist_wpa_new"
  A: .* /var/run/wpa_supplicant/wlan0 (re)

  $ ilist_wpa_old=$ilist_wpa_new

#####################################
#       Test EP deactivation        #
#####################################

Disable 2.4GHz endpoint:

  $ R logger -t cram "Disable 2.4GHz endpoint"

  $ wifi_dm "EndPoint.1.Enable=0"
  Device.WiFi.EndPoint.1.Enable=0

  $ sleep 2

Check same wpa_supplicant pid, two wpaCtrl sockets (wlan0 and wlan1):

  $ if [ "$(R pgrep -f 'wpa_supplicant')" = "$wpa_pid" ]; then echo "true"; else echo "wpa_supplicant restarted !"; fi
  true

  $ ls_wpa_sockets
  wlan0
  wlan1

  $ ilist_wpa_new=$(read_wpa_inodes)
  $ compare_list "$ilist_wpa_old" "$ilist_wpa_new"
  R: .* /var/run/wpa_supplicant/wlan2 (re)

  $ ilist_wpa_old=$ilist_wpa_new

Disable 5GHz endpoint:

  $ R logger -t cram "Disable 5GHz endpoint"

  $ wifi_dm "EndPoint.2.Enable=0"
  Device.WiFi.EndPoint.2.Enable=0

  $ sleep 2

Check same wpa_supplicant pid, one wpaCtrl sockets (wlan0):

  $ if [ "$(R pgrep -f 'wpa_supplicant')" = "$wpa_pid" ]; then echo "true"; else echo "wpa_supplicant restarted !"; fi
  true

  $ ls_wpa_sockets
  wlan0

  $ ilist_wpa_new=$(read_wpa_inodes)
  $ compare_list "$ilist_wpa_old" "$ilist_wpa_new"
  R: .* /var/run/wpa_supplicant/wlan1 (re)

  $ ilist_wpa_old=$ilist_wpa_new

Disable 6GHz endpoint:

  $ R logger -t cram "Disable 6GHz endpoint"

  $ wifi_dm "EndPoint.3.Enable=0"
  Device.WiFi.EndPoint.3.Enable=0

  $ sleep 2

Check wpa_supplicant is stopped
  $ R "pgrep -f 'wpa_supplicant'"
  [1]

Check no wpaCtrl socket in /var/run/wpa_supplicant
  $ ls_wpa_sockets

  $ ilist_wpa_new=$(read_wpa_inodes)
  $ compare_list "$ilist_wpa_old" "$ilist_wpa_new"
  R: .* /var/run/wpa_supplicant/wlan0 (re)

Resume prplMesh:

  $ prplmesh_start

  $ R logger -t cram "$TESTFILE finished!"
