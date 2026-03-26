#
# MLO / APMLD helpers (sources wifi.sh for R, wifi_dm, etc.)
#
[ -z "${TESTDIR}" ] || . "${TESTDIR}/../scripts/wifi.sh"

# Stop prplmesh, enable DataElements VAP config, set MLDUnit=-1 for all SSIDs,
# start gateway mode, wait for Network.Device.1, sleep.
# Optional: set check_process=1 to verify beerocks processes (output to stdout).
# Out: echoes "MLO_ENABLED" on success; use for Cram expected output if needed.
prplmesh_enable_mlo() {
  set -e
  R logger -t cram "Stop prplmesh"
  R "ba-cli -l X_PRPLWARE-COM_ProcessManager.PrplMesh.Enable=0" | tr -d '\n'
  R logger -t cram "Enabling DataElements VAP config..."
  R "sed -i 's/use_dataelements_vap_configs=0/use_dataelements_vap_configs=1/g' /opt/prplmesh/config/beerocks_controller.conf"
  R logger -t cram "Disabling MLO for all SSIDs and restart prplmesh"
  R "ba-cli -j -l WiFi.SSID.*.MLDUnit=-1 | jsonfilter -e @[0]'[*].MLDUnit'" > /dev/null
  R "ba-cli X_PRPLWARE-COM_ProcessManager.PrplMesh.ManagementMode=Multi-AP-Controller-and-Agent"  > /dev/null
  R "ba-cli -l X_PRPLWARE-COM_ProcessManager.PrplMesh.Enable=1" | tr -d '\n'
  R "amx_wait_for X_PRPLWARE-COM_WiFiController.Network.Device.1"
  sleep 15
  R logger -t cram "Checking beerocks process."
  R "ps axw" | sed -nE 's/.*(\/opt\/prplmesh\/bin.*)/\1/p' | LC_ALL=C sort
  set +e
  echo "MLO_ENABLED"
}

# Create Network.AccessPoint.1, configure bands/SSID/security/MLDUnit, commit.
# In: optional SSID (default TEST-FRONTHAUL), MLDUnit (default 7), passphrase (default password-fhl).
# Out: echoes "AP_COMMIT_OK" on success.
# $1=ssid $2=mldunit $3=passphrase $4=ap_index (default 1)
prplmesh_create_network_ap_mlo() {
  local ssid="${1:-prplOS}"
  local mldunit="${2:-7}"
  local passphrase="${3:-password}"
  local ap="${4:-1}"
  local vaptype="${5:-home}"
  local base="X_PRPLWARE-COM_WiFiController.Network.AccessPoint.${ap}"

  R logger -t cram "create Network.AccessPoint.${ap} and push to agent"
  R "ba-cli -l 'X_PRPLWARE-COM_WiFiController.Network.AccessPoint.+'" | sed '/^$/d'
  R "ba-cli -l '${base}.Band2_4G=1'"  | sed '/^$/d'
  R "ba-cli -l '${base}.Band5GH=1'" | sed '/^$/d'
  R "ba-cli -l '${base}.Band5GL=1'" | sed '/^$/d'
  R "ba-cli -l '${base}.Band6G=1'" | sed '/^$/d'
  R "ba-cli -l '${base}.Enable=1'"  | sed '/^$/d'
  R "ba-cli -l '${base}.SSID=${ssid}'" | sed '/^$/d'
  R "ba-cli -l '${base}.Security.ModeEnabled=WPA3-Personal'" | sed '/^$/d'
  R "ba-cli -l '${base}.Security.SAEPassphrase=${passphrase}'" | sed '/^$/d'
  R "ba-cli -l '${base}.Security.KeyPassphrase=${passphrase}'" | sed '/^$/d'
  R "ba-cli -l '${base}.MultiApMode=Fronthaul'" | sed '/^$/d'
  R "ba-cli -l '${base}.X_PRPLWARE_VapType=${vaptype}'" | sed '/^$/d'
  R "ba-cli -l '${base}.MLDUnit=${mldunit}'" | sed '/^$/d'
  R "ba-cli -j -l 'X_PRPLWARE-COM_Agent.Info.CurrentState?' | jsonfilter -e @[0]'[*].CurrentState'" | sed '/^$/d'
  R "ba-cli -l 'X_PRPLWARE-COM_WiFiController.Network.AccessPointCommit()'" | sed '/^$/d'
  sleep 10
  echo "AP_COMMIT_OK"
}

#########################################
# RUID / APMLD compare helpers          #
#########################################

# Derive RUID from AffiliatedAP BSSID: BSSID -> SSID -> LowerLayers -> Radio.BaseMACAddress
# In : BSSID (e.g. from WiFi.APMLD.*.AffiliatedAP.*.BSSID)
# Out : RUID (radio base MAC) or empty on failure
get_ruid_from_bssid() {
  local bssid="$1"
  [ -z "$bssid" ] && return 1
  local bssid_lc lower_layers ruid
  bssid_lc=$(echo "$bssid" | tr '[:upper:]' '[:lower:]')
  lower_layers=$(R "ba-cli -l 'Device.WiFi.SSID.[BSSID==\"$bssid_lc\"].LowerLayers?'" 2>/dev/null | grep LowerLayers= | head -1 | sed -E 's/.*=\"?([^\"]*)\"?/\1/')
  [ -z "$lower_layers" ] && return 1
  ruid=$(R "ba-cli -l '${lower_layers}.BaseMACAddress?'" 2>/dev/null | grep BaseMACAddress= | sed -E 's/.*=\"?([^\"]*)\"?/\1/' | tr -d '"' | tr '[:upper:]' '[:lower:]')
  [ -z "$ruid" ] && return 1
  echo "$ruid"
}

# Get normalized APMLD lines from WiFi.APMLD (MLDMACAddress, BSSID, LinkID; RUID derived via get_ruid_from_bssid)
# In : optional device index for WiFi (default 1). Uses ba-cli on remote.
# Out : sorted lines "mlarmac=... bssid=... linkid=... ruid=..." (lowercase MACs)
get_wifi_apmld_normalized() {
  local dev="${1:-1}"
  R "ba-cli -l 'WiFi.APMLD.?'" 2>/dev/null | grep -E 'MLDMACAddress=|AffiliatedAP\.|BSSID=|LinkID=' | while read -r line; do
    if echo "$line" | grep -q 'MLDMACAddress='; then
      mldmac=$(echo "$line" | sed -E 's/.*=\"?([^\"]*)\"?/\1/' | tr '[:upper:]' '[:lower:]')
    elif echo "$line" | grep -q 'BSSID='; then
      bssid=$(echo "$line" | sed -E 's/.*=\"?([^\"]*)\"?/\1/' | tr '[:upper:]' '[:lower:]')
      ruid=$(get_ruid_from_bssid "$bssid")
      [ -z "$ruid" ] && ruid=""
    elif echo "$line" | grep -q 'LinkID='; then
      linkid=$(echo "$line" | sed -E 's/.*LinkID=//')
      printf "mlarmac=%s bssid=%s linkid=%s ruid=%s\n" "$mldmac" "$bssid" "$linkid" "$ruid"
    fi
  done | LC_ALL=C sort
}

# Get normalized APMLD lines from Device.WiFi.DataElements.Network.Device.N.APMLD
# In : device index (default 2 for agent)
# Out : sorted lines "mlarmac=... bssid=... linkid=... ruid=..."
get_dataelements_apmld_normalized() {
  local dev="${1:-1}"
  R "ba-cli -l 'Device.WiFi.DataElements.Network.Device.${dev}.APMLD.?'" 2>/dev/null | grep -E 'MLDMACAddress=|AffiliatedAP\.|BSSID=|LinkID=|RUID=' | while read -r line; do
    if echo "$line" | grep -q 'MLDMACAddress='; then
      mldmac=$(echo "$line" | sed -E 's/.*=\"?([^\"]*)\"?/\1/' | tr '[:upper:]' '[:lower:]')
    elif echo "$line" | grep -q 'BSSID='; then
      bssid=$(echo "$line" | sed -E 's/.*=\"?([^\"]*)\"?/\1/' | tr '[:upper:]' '[:lower:]')
    elif echo "$line" | grep -q 'RUID='; then
      ruid=$(echo "$line" | sed -E 's/.*=\"?([^\"]*)\"?/\1/' | tr '[:upper:]' '[:lower:]')
    elif echo "$line" | grep -q 'LinkID='; then
      linkid=$(echo "$line" | sed -E 's/.*LinkID=//')
      printf "mlarmac=%s bssid=%s linkid=%s ruid=%s\n" "$mldmac" "$bssid" "$linkid" "$ruid"
    fi
  done | LC_ALL=C sort
}

# Restore default MLD/config after MLO test: WiFi MLDUnit for AP 1..9 (0,1,0,1,0,1,0,1,0),
# use_dataelements_vap_configs=0, Network.AccessPoint.1 SSID=prplOS, KeyPassphrase=password,
# commit, prplmesh restart.
# Out: echoes "MLO_DEFAULTS_RESTORED" when done.
prplmesh_revert_mlo_to_defaults() {
  R logger -t cram "Restore default MLD configuration"
  R "ba-cli -j -l WiFi.AccessPoint.1.SSIDReference+.MLDUnit=-1" | sed '/^$/d'
  R "ba-cli -j -l WiFi.AccessPoint.2.SSIDReference+.MLDUnit=1" | sed '/^$/d'
  R "ba-cli -j -l WiFi.AccessPoint.3.SSIDReference+.MLDUnit=-1" | sed '/^$/d'
  R "ba-cli -j -l WiFi.AccessPoint.4.SSIDReference+.MLDUnit=1" | sed '/^$/d'
  R "ba-cli -j -l WiFi.AccessPoint.5.SSIDReference+.MLDUnit=-1" | sed '/^$/d'
  R "ba-cli -j -l WiFi.AccessPoint.6.SSIDReference+.MLDUnit=1" | sed '/^$/d'
  R "ba-cli -j -l WiFi.AccessPoint.7.SSIDReference+.MLDUnit=0" | sed '/^$/d'
  R "ba-cli -j -l WiFi.AccessPoint.8.SSIDReference+.MLDUnit=1" | sed '/^$/d'
  R "ba-cli -j -l WiFi.AccessPoint.9.SSIDReference+.MLDUnit=0" | sed '/^$/d'
  R "sed -i 's/^use_dataelements_vap_configs=.*/use_dataelements_vap_configs=0/' /opt/prplmesh/config/beerocks_controller.conf"
  sleep 10
  R "ba-cli -l X_PRPLWARE-COM_ProcessManager.PrplMesh.Enable=0" | tr -d '\n'

  R logger -t cram "Restart prplmesh"

  R "ba-cli X_PRPLWARE-COM_ProcessManager.PrplMesh.ManagementMode=Multi-AP-Controller-and-Agent"  > /dev/null
  R "ba-cli -l X_PRPLWARE-COM_ProcessManager.PrplMesh.Enable=1" | tr -d '\n'
  sleep 10
  R "ps axw" | sed -nE 's/.*(\/opt\/prplmesh\/bin.*)/\1/p' | LC_ALL=C sort
  echo "MLO_DEFAULTS_RESTORED"
}

verify_mldunit_by_ssid() {
  local ssid="${1:?ssid is required}"
  R "ba-cli -l 'WiFi.SSID.[SSID==\"${ssid}\"].MLDUnit?'" | sed '/^$/d'
}

# Add the FH link back to the same MLD group.
# Default group value is 0 based on your current agent-applied result.
prplmesh_restore_one_fh_link_to_mld_group() {
  local ssid_idx="${1:-7}"
  local mld_unit="${2:-0}"
  R logger -t cram "Restoring FH link WiFi.SSID.${ssid_idx} to MLDUnit=${mld_unit}"
  R "ba-cli -j -l 'WiFi.SSID.${ssid_idx}.MLDUnit=${mld_unit}'"
}
