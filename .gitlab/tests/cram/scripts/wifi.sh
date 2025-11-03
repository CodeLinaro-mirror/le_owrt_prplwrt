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

# Print APMLD MACAddress
# In : APMLD object index
# Out : APMLD MACAddress
get_apmld_mac() {
  R "ba-cli -l -j 'WiFi.APMLD.${1}.MLDMACAddress?' | jsonfilter -e @[0]'[*].MLDMACAddress' || echo 'Could not get APMLD MAC'"
}

# Print intefrace name from a MACAddress
get_interface_name() {
  R "ba-cli -l -j 'WiFi.SSID.[MACAddress==\"${1}\"].Name?' | jsonfilter -e @[0]'[*].Name' || echo 'Could not find SSID'"
}

# Print link number of an interface
get_link_count() {
  R "iw dev ${1} info" | grep link | wc -l
}

# In : APMLD object index
# Out : main link interface
get_main_link_itf () {
    local found=0
    local ifaces

    ifaces=$(R ba-cli "WiFi.SSID.*.Name?0" | cut -d'=' -f2 | sed 's/"//g')

    for iface in $ifaces; do
        info=$(R iw dev "$iface" info 2>/dev/null)
        if echo "$info" | grep -i ${1} -B2 | grep -q "link"; then
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
# In : APMLD index
# Out : link number from iw output
link_number_from_apmld() {
  # Detect main link interface
  mac_address=$(get_apmld_mac "$1") && R logger -t cram "mac_address = $mac_address"
  #itf_name=$(get_interface_name "$mac_address") && R logger -t cram "interface = $itf_name"
  itf_name=$(get_main_link_itf "$mac_address")
  get_link_count "$itf_name"
}

