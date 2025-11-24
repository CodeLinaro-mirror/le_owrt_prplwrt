#
# Common WiFi helpers:
#

# Enable AccessPoints
# In : AccessPoint object index
# Out : "enabled" if success, empty otherwise
enable_ap() {
  R "ba-cli -j -l WiFi.AccessPoint.${1}.Enable=1 | grep -q Enable && echo 'WiFi.AccessPoint.${1} enabled'"
}

# Disable AccessPoints
# In : AccessPoint object index
# Out : "disabled" if success, empty otherwise
disable_ap() {
  R "ba-cli -j -l WiFi.AccessPoint.${1}.Enable=0 | grep -q Enable && echo 'WiFi.AccessPoint.${1} disabled'"
}

# Wait until SSID status is Up/Down
# In : AccessPoint object index
# In : Expected status Up/Down
# Out: "SSID Reference is {Up/Down}"
check_ap_ref_ssid() {
  R "
    i=10
    while [ \$i -gt 1 ]; do
      ba-cli -j -l WiFi.AccessPoint.${1}.SSIDReference+.Status? |
        grep WiFi.SSID. |
        grep -q \"${2}\" &&
        echo 'WiFi.AccessPoint.${1} SSID Reference is ${2}' && break
      i=\$(( i - 1 ))
      sleep 2
    done
  "
}

# Print SSIDReference status
# In : AccessPoint object index
# Out : Enable / Disable / Dormant ...
get_ssid_ref() {
  msg=$(R "ba-cli -j -l WiFi.AccessPoint.${1}.SSIDReference+.Status?")
  echo "$msg" | sed '/^$/d'
}

# Print SSIDs status
get_ssid_status() {
  R "ba-cli -j -l WiFi.SSID.?0 | jsonfilter -e @[0]'[@.Alias != \"ep2g0\" && @.Alias != \"ep5g0\" && @.Alias != \"ep6g0\"].Status'" | LC_ALL=C sort
}

# Print SSIDs values
get_ssid_ssid() {
  R "ba-cli -j -l WiFi.SSID.?0 | jsonfilter -e @[0]'[@.Alias != \"ep2g0\" && @.Alias != \"ep5g0\" && @.Alias != \"ep6g0\"].SSID'" | LC_ALL=C sort
}

#
# APMLD helpers
#

# Print MLDUnit of private MLD based on default SSID (prplOS)
# In : N/A
# Out : MLDUNit
get_private_mldunit() {
   R 'ba-cli -j -l "WiFi.SSID.[SSID==\"prplOS\"].MLDUnit?" | jsonfilter -e @[0]'[*].MLDUnit''  | head -n 1
}

# Print MLDUnit of private MLD based on default SSID (prplOS-guest)
# In : N/A
# Out : MLDUnit
get_guest_mldunit() {
   R 'ba-cli -j -l "WiFi.SSID.[SSID==\"prplOS-guest\"].MLDUnit?" | jsonfilter -e @[0]'[*].MLDUnit''  | head -n 1
}

# validate mac address
is_valid_mac() {
  printf '%s\n' "$1" | grep -Eq '^([0-9A-Fa-f]{2}[:\-]){5}[0-9A-Fa-f]{2}$'
}

# Print APMLD MACAddress
# In : MLDID (MLDUnit)
# Out : APMLD MACAddress. If an APMLD matches the MLDID with empty MACAddress return an error message
get_apmld_mac_from_dm() {
  mac=$(R "ba-cli -l -j 'WiFi.APMLD.[MLDID == ${1}].MLDMACAddress?' | jsonfilter -e @[0]'[*].MLDMACAddress' | strings")
  if ! is_valid_mac "$mac"; then
    echo "not_found"
    R logger -t cram "get_apmld_mac_from_dm: MLDMACAddress $mac of MLD ${1} not found"
    #R "iw dev > /tmp/$(R date +'%Y_%m_%d_%H_%M_%S')_aplmd_iw_out.txt"
  else
    echo "$mac"
  fi
}

# Print intefrace name from a MACAddress
# In : wlan MAC address
# Out : interface name
get_interface_name() {
  R "ba-cli -l -j 'WiFi.SSID.[MACAddress==\"${1}\"].Name?' | jsonfilter -e @[0]'[*].Name' || echo 'Could not find SSID'"
}

# Print link number of an interface
# In : wlan interface
# Out : link number
get_link_info() {
  R logger -t cram "get_link_info: interface ${1}"
  R "iw dev ${1} info" | grep -e addr -e channe | sed 's/^[ \t]*//' | sort | uniq
}

# print main link interface name from MAC address
# In : interface MAC address
# Out : main link interface name
get_main_link_itf () {
  local found=0
  local ifaces
  local mac=$1

  ifaces=$(R ba-cli -l "WiFi.SSID.*.Name?0 | strings")

  for iface in $ifaces; do
    info=$(R iw dev "$iface" info 2>/dev/null)
    if echo "$info" | grep -i ${mac} -B2 | grep -q "link"; then
      R logger -t cram "MAC $1 found in main link interface $iface"
      echo "$iface"
      found=1
      break
    fi
  done

  if [ "$found" -eq 0 ]; then
    R logger -t cram "MAC $1 not associated to any main link"
    echo "MAC $1 not associated to any main link"
  fi
}

# print link number from iw output
# In : APMLD index (ie MLDID)
# Out : link number from iw output
iw_affliated_link_info_from_mldid() {
  # Detect main link interface
  mac_address=$(get_apmld_mac_from_dm "$1")
  if [ -z "$mac_address" ]; then
    R logger -t cram "iw_affliated_link_info_from_mldid: empty mac_address !"
  else
    R logger -t cram "iw_affliated_link_info_from_mldid: mac_address = $mac_address"
    itf_name=$(get_main_link_itf "$mac_address")
    get_link_info "$itf_name"
  fi
}

# print MAC addresses list of link interfaces from iw  output
# In : main link interface name
# Out : MAC addresses list of link interfaces
iw_get_main_link_mac_list() {
  local iface=$1
  R logger -t cram "get_main_link_mac_list $iface"
  R "iw dev $iface info"  | grep link -A3 | grep 'addr ' | sed -n 's/.*addr \([0-9a-fA-F:]*\).*/\1/p'  | LC_ALL=C sort
}

# print MAC addresses list of link interfaces from iw  output
# In : MLDID
# Out : MAC addresses list of link interfaces
iw_affliated_mac_from_mldid() {
  # Detect main link interface
  mac_address=$(get_apmld_mac_from_dm "$1") && R logger -t cram "mac_address = $mac_address"
  if [ -z "$mac_address" ]; then
    R logger -t cram "iw_affliated_mac_from_mldid: empty mac_address !"
  else
    itf_name=$(get_main_link_itf "$mac_address")
    iw_get_main_link_mac_list "$itf_name"
  fi
}

# print MAC addresses list of link interfaces from WiFi DM
# In : MLDID
# Out : MAC addresses list of affiliated interfaces
dm_affilated_mac_list_from_mldid() {
  R "ba-cli -j -l 'WiFi.APMLD.[ MLDID == ${1} ].AffiliatedAP.*.BSSID?' | jsonfilter -e @[0]'[*].BSSID'"
}
