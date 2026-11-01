#
# WiFi Templates helpers.
#

templates_set() {
	R "ba-cli Device.WiFi.Templates.$1" >/dev/null 2>&1
}

templates_stop() {
	templates_set "Network.Enable=0"
	templates_set "BSSTemplate.*.Enable=0"
	sleep 2
}

templates_start() {
	templates_set "BSSTemplate.*.Enable=1"
	templates_set "Network.Enable=1"
}

# Configure one BSSTemplate instance.
# Usage: templates_set_bss <idx> <ssid> <vap> <radio> <ssc> <sec> <adv> [apmld]
#   radio/ssc/sec/apmld are instance numbers under X_PRPLWARE-COM_Templates.
#   omit apmld (or pass "") to clear APMLDTemplateReference.
templates_set_bss() {
	local idx="$1" ssid="$2" vap="$3" radio="$4" ssc="$5" sec="$6" adv="$7" apmld="${8:-}"

	templates_set "BSSTemplate.${idx}.SSID=${ssid}"
	templates_set "BSSTemplate.${idx}.KeyPassphrase=password"
	templates_set "BSSTemplate.${idx}.X_PRPLWARE-COM_VapType=${vap}"
	templates_set "BSSTemplate.${idx}.AdvertisementEnable=${adv}"
	templates_set "BSSTemplate.${idx}.RadioTemplateReference=X_PRPLWARE-COM_Templates.RadioTemplate.${radio}"
	templates_set "BSSTemplate.${idx}.SSCTemplateReference=X_PRPLWARE-COM_Templates.SSCTemplate.${ssc}"
	templates_set "BSSTemplate.${idx}.SecurityGroupReference=X_PRPLWARE-COM_Templates.SecurityGroup.${sec}"
	if [ -n "$apmld" ]; then
		templates_set "BSSTemplate.${idx}.APMLDTemplateReference=X_PRPLWARE-COM_Templates.APMLDTemplate.${apmld}"
	else
		templates_set "BSSTemplate.${idx}.APMLDTemplateReference="
	fi
}

templates_set_operating_generation() {
	# Values may contain commas; keep them inside ba-cli single-quotes.
	R "ba-cli 'Device.WiFi.Templates.RadioTemplate.1.OperatingGeneration=$1'" >/dev/null 2>&1
	R "ba-cli 'Device.WiFi.Templates.RadioTemplate.2.OperatingGeneration=$2'" >/dev/null 2>&1
	R "ba-cli 'Device.WiFi.Templates.RadioTemplate.3.OperatingGeneration=$3'" >/dev/null 2>&1
}

# Colocated 3-link MLO on BSS.1/.2/.3 -> radios 5G / 2.4G / 6G
templates_configure_mlo() {
	local ssid="${1:-TEST_MLO}"

	templates_stop
	testbed_set_wifi_defaults
	templates_set_operating_generation "4,6,7" "7" "7"

	templates_set_bss 1 "$ssid" home 2 2 1 1 1
	templates_set_bss 2 "$ssid" home 1 2 1 1 1
	templates_set_bss 3 "$ssid" home 3 2 1 1 1
	sleep 2

	templates_set "APMLDTemplate.1.MLOEnable=1"
	templates_start
}

# Default: private 5G / guest 2.4 / BH 5G, MLO off
templates_restore_defaults() {
	templates_stop
	templates_set "APMLDTemplate.1.MLOEnable=0"
	templates_set_operating_generation "" "" ""

	templates_set_bss 1 PRPL-PRIVATE-5G home 2 2 2 1
	templates_set_bss 2 PRPL-GUEST-2G guest 1 3 2 1
	templates_set_bss 3 PRPL-BH-5G backhaul 2 1 1 0
	sleep 2
}
