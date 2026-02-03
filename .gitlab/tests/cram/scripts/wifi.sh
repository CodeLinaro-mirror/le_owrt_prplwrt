#
# Common WiFi helpers:
#

# Enable AccessPoints
# In : AccessPoint object index
# Out : "enabled" if success, empty otherwise
enable_ap() {
  R "usp-cli -j -l Device.WiFi.AccessPoint.${1}.Enable=1 | grep -q Enable && echo 'Device.WiFi.AccessPoint.${1} enabled'"
}

# Disable AccessPoints
# In : AccessPoint object index
# Out : "disabled" if success, empty otherwise
disable_ap() {
  R "usp-cli -j -l Device.WiFi.AccessPoint.${1}.Enable=0 | grep -q Enable && echo 'Device.WiFi.AccessPoint.${1} disabled'"
}

# Wait until SSID status is Up/Down
# In : AccessPoint object index
# In : Expected status Up/Down
# Out: "SSID Reference is {Up/Down}"
check_ap_ref_ssid() {
  R "
    i=10
    while [ \$i -gt 1 ]; do
      usp-cli -j -l Device.WiFi.AccessPoint.${1}.SSIDReference+.Status? |
        grep Device.WiFi.SSID. |
        grep -q \"${2}\" &&
        echo 'Device.WiFi.AccessPoint.${1} SSID Reference is ${2}' && break
      i=\$(( i - 1 ))
      sleep 2
    done
  "
}

# Print SSIDReference status
# In : AccessPoint object index
# Out : Enable / Disable / Dormant ...
get_ssid_ref() {
  msg=$(R "usp-cli -j -l Device.WiFi.AccessPoint.${1}.SSIDReference+.Status?")
  echo "$msg" | sed '/^$/d'
}

# Print SSIDs status
get_ssid_status() {
  R "usp-cli -j -l Device.WiFi.SSID.?0 | jsonfilter -e @[0]'[@.Alias != \"ep2g0\" && @.Alias != \"ep5g0\" && @.Alias != \"ep6g0\"].Status'" | LC_ALL=C sort
}

# Print SSIDs values
get_ssid_ssid() {
  R "usp-cli -j -l Device.WiFi.SSID.?0 | jsonfilter -e @[0]'[@.Alias != \"ep2g0\" && @.Alias != \"ep5g0\" && @.Alias != \"ep6g0\"].SSID'" | LC_ALL=C sort
}
