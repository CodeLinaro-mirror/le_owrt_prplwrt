Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ . "${TESTDIR}/../scripts/wifi.sh"

  $ R "logger -t cram 'Starting PWHM test (step 2) ...'"

Save hostap pid, it's needed as part of script split (PCF-2222):

  $ hostap_pid=$(R pgrep -f 'hostapd')
  $ R logger -t cram "hostap PID : $hostap_pid"

Save inodes (FEAT-389), it's needed as part of script split (PCF-2222)

  $ ilist_old=$(read_hostapd_inodes)
  $ ifindexes=$(R "iw dev" | grep ifindex -B 1 | sed 's/^[[:space:]]*//')

Check that hostapd is operating as expected:

  $ R logger -t cram "Check that hostapd is operating"

  $ R "ps axw" | sed -nE 's/.*(hostapd .*)/\1/p' | head -1 | tr -s ' ' '\n' | LC_ALL=C sort
  -g
  -s
  /tmp/wlan2_hapd.conf
  /var/run/hostapd/global\.0x.* (re)
  hostapd

Check iw interfaces and beaconing:

  $ R "iw dev | grep -e Interface -e ssid | tr -d '\t' | sort"
  Interface wlan0
  Interface wlan0.1
  Interface wlan0.2
  Interface wlan0.3
  Interface wlan1
  Interface wlan1.1
  Interface wlan1.2
  Interface wlan1.3
  Interface wlan2
  Interface wlan2.1
  Interface wlan2.2
  Interface wlan2.3
  ssid backhaul_(AC:91:9B|58:E4:03):[0-9A-F]{2}:[0-9A-F]{2}:[0-9A-F]{2} (re)
  ssid prplOS
  ssid prplOS-guest

Check that the tree interfaces are present in the main link interface:

  $ R "iw dev" | grep -e link -A 3 | grep -e link -e channel | sed 's/^[ \t]*//'
  link 0:
  channel.* (re)
  link 1:
  channel.* (re)
  link 2:
  channel.* (re)
  link 0:
  channel.* (re)
  link 1:
  channel.* (re)
  link 2:
  channel.* (re)
  link 0:
  channel.* (re)
  link 1:
  channel.* (re)
  link 2:
  channel.* (re)

#######################################
# Test deactivation of access point 9 #
#######################################

  $ enable_ap_sync 9 0
  AccessPoint.9.Enable=0

  $ wifi_dm "AccessPoint.*.Status?0"
  Device.WiFi.AccessPoint.1.Status="Enabled"
  Device.WiFi.AccessPoint.2.Status="Enabled"
  Device.WiFi.AccessPoint.3.Status="Enabled"
  Device.WiFi.AccessPoint.4.Status="Enabled"
  Device.WiFi.AccessPoint.5.Status="Enabled"
  Device.WiFi.AccessPoint.6.Status="Enabled"
  Device.WiFi.AccessPoint.7.Status="Enabled"
  Device.WiFi.AccessPoint.8.Status="Enabled"
  Device.WiFi.AccessPoint.9.Status="Disabled"

Check wpacltrl socket file:

  $ ls_ap_hapd_socket 9
  not found

  $ ls_hapd_sockets
  wlan2.1
  wlan2.1_link0
  wlan2.1_link1
  wlan2.1_link2
  wlan2.2
  wlan2.2_link0
  wlan2.2_link1
  wlan2.2_link2
  wlan2.3
  wlan2.3_link0
  wlan2.3_link1

Check and save inodes (FEAT-389):

  $ ilist_new=$(read_hostapd_inodes)

One link was removed, so there should be one less socket:
Provisory: The output also includes all the currently enabled non-TX BSS related 6GHz links (*_link2).
The non-TX bss links can't be dynamically reconfigured due to a limitation in hostapd requiring the links to be re-added. (PCF-2595).

  $ compare_list "$ilist_old" "$ilist_new"
  R: .* /var/run/hostapd/wlan2.1_link2 (re)
  R: .* /var/run/hostapd/wlan2.2_link2 (re)
  R: .* /var/run/hostapd/wlan2.3_link2 (re)
  A: .* /var/run/hostapd/wlan2.1_link2 (re)
  A: .* /var/run/hostapd/wlan2.2_link2 (re)

  $ ilist_old=$ilist_new

#######################################
# Test deactivation of access point 8 #
#######################################

  $ R logger -t cram "Test AccessPoint 8 deactivation \"$(get_ssid_ref 8)\""

  $ enable_ap_sync 8 0
  AccessPoint.8.Enable=0

  $ wifi_dm "AccessPoint.*.Status?0"
  Device.WiFi.AccessPoint.1.Status="Enabled"
  Device.WiFi.AccessPoint.2.Status="Enabled"
  Device.WiFi.AccessPoint.3.Status="Enabled"
  Device.WiFi.AccessPoint.4.Status="Enabled"
  Device.WiFi.AccessPoint.5.Status="Enabled"
  Device.WiFi.AccessPoint.6.Status="Enabled"
  Device.WiFi.AccessPoint.7.Status="Enabled"
  Device.WiFi.AccessPoint.8.Status="Disabled"
  Device.WiFi.AccessPoint.9.Status="Disabled"

Check wpacltrl socket file:

  $ ls_ap_hapd_socket 8
  not found

  $ ls_hapd_sockets
  wlan2.1
  wlan2.1_link0
  wlan2.1_link1
  wlan2.1_link2
  wlan2.2
  wlan2.2_link0
  wlan2.2_link1
  wlan2.2_link2
  wlan2.3
  wlan2.3_link0

Check and save inodes (FEAT-389):

  $ ilist_new=$(read_hostapd_inodes)

One link was removed, so there should be one less socket:

  $ compare_list "$ilist_old" "$ilist_new"
  R: .* /var/run/hostapd/wlan2.3_link1 (re)

  $ ilist_old=$ilist_new

#######################################
# Test deactivation of access point 7 #
#######################################

  $ R logger -t cram "Test AccessPoint 7 deactivation \"$(get_ssid_ref 7)\""

  $ enable_ap_sync 7 0
  AccessPoint.7.Enable=0

  $ wifi_dm "AccessPoint.*.Status?0"
  Device.WiFi.AccessPoint.1.Status="Enabled"
  Device.WiFi.AccessPoint.2.Status="Enabled"
  Device.WiFi.AccessPoint.3.Status="Enabled"
  Device.WiFi.AccessPoint.4.Status="Enabled"
  Device.WiFi.AccessPoint.5.Status="Enabled"
  Device.WiFi.AccessPoint.6.Status="Enabled"
  Device.WiFi.AccessPoint.7.Status="Disabled"
  Device.WiFi.AccessPoint.8.Status="Disabled"
  Device.WiFi.AccessPoint.9.Status="Disabled"

Check wpacltrl socket file:

  $ ls_ap_hapd_socket 7
  not found

  $ ls_hapd_sockets
  wlan2.1
  wlan2.1_link0
  wlan2.1_link1
  wlan2.1_link2
  wlan2.2
  wlan2.2_link0
  wlan2.2_link1
  wlan2.2_link2

Check and save inodes (FEAT-389):

  $ ilist_new=$(read_hostapd_inodes)

The MLD was disabled, so there should be two less socket:

  $ compare_list "$ilist_old" "$ilist_new"
  R: .* /var/run/hostapd/wlan2.3 (re)
  R: .* /var/run/hostapd/wlan2.3_link0 (re)

  $ ilist_old=$ilist_new

#######################################
# Test deactivation of access point 6 #
#######################################

  $ enable_ap_sync 6 0
  AccessPoint.6.Enable=0

  $ wifi_dm "AccessPoint.*.Status?0"
  Device.WiFi.AccessPoint.1.Status="Enabled"
  Device.WiFi.AccessPoint.2.Status="Enabled"
  Device.WiFi.AccessPoint.3.Status="Enabled"
  Device.WiFi.AccessPoint.4.Status="Enabled"
  Device.WiFi.AccessPoint.5.Status="Enabled"
  Device.WiFi.AccessPoint.6.Status="Disabled"
  Device.WiFi.AccessPoint.7.Status="Disabled"
  Device.WiFi.AccessPoint.8.Status="Disabled"
  Device.WiFi.AccessPoint.9.Status="Disabled"

Check wpacltrl socket file:

  $ ls_ap_hapd_socket 6
  not found

  $ ls_hapd_sockets
  wlan2.1
  wlan2.1_link0
  wlan2.1_link1
  wlan2.1_link2
  wlan2.2
  wlan2.2_link0
  wlan2.2_link1

Check and save inodes (FEAT-389):

  $ ilist_new=$(read_hostapd_inodes)

One link was removed, so there should be one less socket:
Provisory: The output also includes all the currently enabled non-TX BSS related 6GHz links (*_link2).
The non-TX bss links can't be dynamically reconfigured due to a limitation in hostapd requiring the links to be re-added (PCF-2595).

  $ compare_list "$ilist_old" "$ilist_new"
  R: .* /var/run/hostapd/wlan2.1_link2 (re)
  R: .* /var/run/hostapd/wlan2.2_link2 (re)
  A: .* /var/run/hostapd/wlan2.1_link2 (re)

  $ ilist_old=$ilist_new

#######################################
# Test deactivation of access point 5 #
#######################################

  $ R logger -t cram "Test AccessPoint 5 deactivation \"$(get_ssid_ref 5)\""

  $ enable_ap_sync 5 0
  AccessPoint.5.Enable=0

  $ wifi_dm "AccessPoint.*.Status?0"
  Device.WiFi.AccessPoint.1.Status="Enabled"
  Device.WiFi.AccessPoint.2.Status="Enabled"
  Device.WiFi.AccessPoint.3.Status="Enabled"
  Device.WiFi.AccessPoint.4.Status="Enabled"
  Device.WiFi.AccessPoint.5.Status="Disabled"
  Device.WiFi.AccessPoint.6.Status="Disabled"
  Device.WiFi.AccessPoint.7.Status="Disabled"
  Device.WiFi.AccessPoint.8.Status="Disabled"
  Device.WiFi.AccessPoint.9.Status="Disabled"

Check wpacltrl socket file:

  $ ls_ap_hapd_socket 5
  not found

  $ ls_hapd_sockets
  wlan2.1
  wlan2.1_link0
  wlan2.1_link1
  wlan2.2
  wlan2.2_link0
  wlan2.2_link1

Check and save inodes (FEAT-389):

  $ ilist_new=$(read_hostapd_inodes)

One link was removed, so there should be one less socket:

  $ compare_list "$ilist_old" "$ilist_new"
  R: .* /var/run/hostapd/wlan2.1_link2 (re)

  $ ilist_old=$ilist_new

#######################################
# Test deactivation of access point 4 #
#######################################

  $ R logger -t cram "Test AccessPoint 4 deactivation \"$(get_ssid_ref 4)\""

  $ enable_ap_sync 4 0
  AccessPoint.4.Enable=0

  $ wifi_dm "AccessPoint.*.Status?0"
  Device.WiFi.AccessPoint.1.Status="Enabled"
  Device.WiFi.AccessPoint.2.Status="Enabled"
  Device.WiFi.AccessPoint.3.Status="Enabled"
  Device.WiFi.AccessPoint.4.Status="Disabled"
  Device.WiFi.AccessPoint.5.Status="Disabled"
  Device.WiFi.AccessPoint.6.Status="Disabled"
  Device.WiFi.AccessPoint.7.Status="Disabled"
  Device.WiFi.AccessPoint.8.Status="Disabled"
  Device.WiFi.AccessPoint.9.Status="Disabled"

Check wpacltrl socket file:

  $ ls_ap_hapd_socket 4
  not found

  $ ls_hapd_sockets
  wlan2.1
  wlan2.1_link0
  wlan2.1_link1
  wlan2.2
  wlan2.2_link0

Check and save inodes (FEAT-389):

  $ ilist_new=$(read_hostapd_inodes)

One link was removed, so there should be one less socket:

  $ compare_list "$ilist_old" "$ilist_new"
  R: .* /var/run/hostapd/wlan2.2_link1 (re)

  $ ilist_old=$ilist_new

#######################################
# Test deactivation of access point 3 #
#######################################

  $ R logger -t cram "Test AccessPoint 3 deactivation \"$(get_ssid_ref 3)\""

  $ enable_ap_sync 3 0
  AccessPoint.3.Enable=0

  $ wifi_dm "AccessPoint.*.Status?0"
  Device.WiFi.AccessPoint.1.Status="Enabled"
  Device.WiFi.AccessPoint.2.Status="Enabled"
  Device.WiFi.AccessPoint.3.Status="Disabled"
  Device.WiFi.AccessPoint.4.Status="Disabled"
  Device.WiFi.AccessPoint.5.Status="Disabled"
  Device.WiFi.AccessPoint.6.Status="Disabled"
  Device.WiFi.AccessPoint.7.Status="Disabled"
  Device.WiFi.AccessPoint.8.Status="Disabled"
  Device.WiFi.AccessPoint.9.Status="Disabled"

Check wpacltrl socket file:

  $ ls_ap_hapd_socket 3
  not found

  $ ls_hapd_sockets
  wlan2.1
  wlan2.1_link0
  wlan2.2
  wlan2.2_link0

Check and save inodes (FEAT-389):

  $ ilist_new=$(read_hostapd_inodes)

One link was removed, so there should be one less socket:

  $ compare_list "$ilist_old" "$ilist_new"
  R: .* /var/run/hostapd/wlan2.1_link1 (re)

  $ ilist_old=$ilist_new

#######################################
# Test deactivation of access point 2 #
#######################################

  $ enable_ap_sync 2 0
  AccessPoint.2.Enable=0

  $ wifi_dm "AccessPoint.*.Status?0"
  Device.WiFi.AccessPoint.1.Status="Enabled"
  Device.WiFi.AccessPoint.2.Status="Disabled"
  Device.WiFi.AccessPoint.3.Status="Disabled"
  Device.WiFi.AccessPoint.4.Status="Disabled"
  Device.WiFi.AccessPoint.5.Status="Disabled"
  Device.WiFi.AccessPoint.6.Status="Disabled"
  Device.WiFi.AccessPoint.7.Status="Disabled"
  Device.WiFi.AccessPoint.8.Status="Disabled"
  Device.WiFi.AccessPoint.9.Status="Disabled"

Check wpacltrl socket file:

  $ ls_ap_hapd_socket 2
  not found

  $ ls_hapd_sockets
  wlan2.1
  wlan2.1_link0

Check and save inodes (FEAT-389):

  $ ilist_new=$(read_hostapd_inodes)

The MLD was disabled, so there should be two less socket:

  $ compare_list "$ilist_old" "$ilist_new"
  R: .* /var/run/hostapd/wlan2.2 (re)
  R: .* /var/run/hostapd/wlan2.2_link0 (re)

  $ ilist_old=$ilist_new

Before deactivating last AP (ie stopping hostpad), check if hostap pid has changed or not:

  $ if [ "$(R pgrep -f 'hostapd')" = "$hostap_pid" ]; then echo "true"; else echo "hostap restarted during the test !"; fi
  true

#######################################
# Test deactivation of access point 1 #
#######################################

  $ R logger -t cram "Test AccessPoint 1 deactivation \"$(get_ssid_ref 1)\""

  $ enable_ap_sync 1 0
  AccessPoint.1.Enable=0

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

Check wpacltrl socket file:

  $ ls_ap_hapd_socket 1
  not found

  $ ls_hapd_sockets
  ls: /var/run/hostapd/: No such file or directory

Check inodes (FEAT-389):

  $ ilist_new=$(read_hostapd_inodes)

The MLD was disabled, so there should be two less socket so all sockets are now closed:

  $ compare_list "$ilist_old" "$ilist_new"
  R: .* /var/run/hostapd/wlan2.1 (re)
  R: .* /var/run/hostapd/wlan2.1_link0 (re)

Check is any ifindex changed (FEAT-389):

  $ ifidx_cur=$(R "iw dev" | grep ifindex -B 1 | sed 's/^[[:space:]]*//')
  $ compare_list "$ifindexes" "$ifidx_cur"

Check if hostapd process is stopped:

  $ R "pgrep -f 'hostapd'"
  [1]

Resume prplMesh:

  $ R "ba-cli -l X_PRPLWARE-COM_ProcessManager.PrplMesh.Enable=1" | tr -d '\n'
  1 (no-eol)

  $ R logger -t cram "Stopping PWHM test .."

Wait for prplMesh before leaving the test:

  $ sleep 5

  $ R logger -t cram "Test finished!"
