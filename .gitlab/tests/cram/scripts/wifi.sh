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

# Set MLDUnit
# In : AccessPoint object index, MLDUnit
# Out : MLDUnit value set
set_mlduint() {
  R "ba-cli -l WiFi.AccessPoint.$1.SSIDReference+.MLDUnit=$2"  | sed '/^$/d'
}

# Set Radio [Arg1] OperatingStandardsFormat = [Arg2]; Standard : list of all standards; Legacy : only highest enabled 802.11 standard
set_radio_operating_standard_format(){
  R "ba-cli -l -j \"WiFi.Radio.[OperatingFrequencyBand=='$1'].OperatingStandardsFormat='$2'\" | jsonfilter -e @[0]'[*].OperatingStandardsFormat'"
}

# Set Radio [Arg1] OperatingStandards = [Arg2];
set_radio_operating_standards(){
  R "ba-cli -l -j \"WiFi.Radio.[OperatingFrequencyBand=='$1'].OperatingStandards='$2'\" | jsonfilter -e @[0]'[*].OperatingStandards'"
}

# read hostapd option from configuration file
# Input : interface name, option
# Output : echo option value if it exists else error message
get_hapd_config() {
  local target_iface="$1"
  local target_param="$2"
  local result
  local target_conf_path="/tmp/${target_iface%.*}_hapd.conf"

  # As when in MLO all relevant interface options are set to main link itf name, use the BSSID instead while parsing parameters
  # this ensure the detection of the right section
  target_bssid=$(R "ba-cli -l \"WiFi.SSID.[Name=='$itf'].BSSID?\"" | sed '/^$/d' | awk '{print toupper($0)}')

  R logger -t cram "get_hapd_config: get '$target_param' of '$target_iface' with bssid '$target_bssid' from '$target_conf_path'"

  result=$(R "cat $target_conf_path" 2>/dev/null | awk -v t_if="$target_bssid" -v t_pa="$target_param" '
      BEGIN { f_sec=0; f_val=0 }

      # Detect start of a section (Primary interface or BSS)
      /^bssid=/ || /^bss=/ {
          split($0, a, "=");
          current_if = a[2];
          if (current_if == t_if) { f_sec=1 }
          next
      }

      # If inside the correct section, look for the parameter
      f_sec == 1 && current_if == t_if {
          # Check for exact parameter match (start of line followed by =)
          if ($0 ~ "^" t_pa "=") {
              split($0, b, "=");
              print b[2];
              f_val=1;
              exit;
          }
      }

      END {
          if (f_sec == 0) { print "ERR_SECTION_NOT_FOUND"; exit 1 }
          if (f_val == 0) { print "ERR_OPTION_NOT_FOUND"; exit 1 }
      }
  ')

  # Handle the output and exit codes
  case "$result" in
      "ERR_SECTION_NOT_FOUND")
          R logger -t cram "get_hapd_config: Interface section not found"
          echo "Interface section not found"
          return 0
          ;;
      "ERR_OPTION_NOT_FOUND")
          R logger -t cram "get_hapd_config: Option '$target_param' not found"
          echo "Option '$target_param' not found"
          return 0
          ;;
      *)
          R logger -t cram "get_hapd_config: $target_param='$result'"
          echo "$result"
          return 0
          ;;
  esac
}
