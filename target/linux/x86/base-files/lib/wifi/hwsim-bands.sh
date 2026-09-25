# Copyright (C) 2026 prpl Foundation
#
# QEMU-only band fix-up for mac80211_hwsim radios, hooked into `wifi
# config`'s existing per-driver detect loop instead of a uci-defaults
# script - see NOTES.md "Band assignment: why every boot" for why a
# one-shot uci-defaults script is not enough here.
#
# package/network/config/wifi-scripts/files/sbin/wifi sources every
# /lib/wifi/*.sh via `include /lib/wifi` before dispatch, then
# wifi_config() runs `ucode /lib/wifi/mac80211.uc | uci -q batch`
# (creates one wifi-device section per phy, band picked by
# bands_order=[6G,5G,2G] first-match - every hwsim phy advertises all
# three, so every radio lands on 6G) followed by
# `for driver in $DRIVERS; do detect_$driver; done`. Appending to
# $DRIVERS here runs detect_hwsim_bandfix right after that ucode
# batch, every single time `wifi config` runs - on first boot (in
# time for 98netlayout_from_uci.sh/99build_default_odl.sh to render
# networklayout.json/the pWHM defaults from the corrected bands) and
# on every boot after (see NOTES.md for why that repetition is
# required, not just cheap insurance).
DRIVERS="$DRIVERS hwsim_bandfix"

# hwsim wiphys live under /sys/devices/virtual/mac80211_hwsim/; any other
# driver (a real NIC) resolves elsewhere - this is what keeps this hook
# from ever touching a real radio, on top of the file only shipping on x86
# and the module only ever autoloading on QEMU (78_load_qemu_hwsim).
hwsim_is_hwsim_phy() {
	case "$(readlink -f "/sys/class/ieee80211/$1/device" 2>/dev/null)" in
	*mac80211_hwsim*) return 0 ;;
	*) return 1 ;;
	esac
}

hwsim_phy_index() {
	cat "/sys/class/ieee80211/$1/index" 2>/dev/null
}

# Mirrors usr/share/hostap/wifi-detect.uc's phy_path(): realpath the
# device symlink and strip the /sys/devices/ prefix. hwsim never shares
# one device across wiphys, so the "+offset" suffix wifi-detect.uc adds
# for that case never applies here.
hwsim_phy_path() {
	local p
	p="$(readlink -f "/sys/class/ieee80211/$1/device" 2>/dev/null)"
	echo "${p#/sys/devices/}"
}

# mac80211.uc's own `id` is `path='...'` whenever the kernel phy name
# matches ^phy[0-9] (true for hwsim's default naming - config_get cfg_path
# below) and `phy='phyN'` otherwise; both forms are matched back to a
# phy here.
hwsim_find_phy_for_section() {
	local section="$1" cfg_phy cfg_path candidate

	config_get cfg_phy "$section" phy
	if [ -n "$cfg_phy" ] && hwsim_is_hwsim_phy "$cfg_phy"; then
		echo "$cfg_phy"
		return 0
	fi

	config_get cfg_path "$section" path
	[ -n "$cfg_path" ] || return 1

	for candidate in /sys/class/ieee80211/*; do
		candidate="${candidate##*/}"
		hwsim_is_hwsim_phy "$candidate" || continue
		[ "$(hwsim_phy_path "$candidate")" = "$cfg_path" ] || continue
		echo "$candidate"
		return 0
	done

	return 1
}

hwsim_collect_section() {
	local section="$1" phy idx radio

	phy="$(hwsim_find_phy_for_section "$section")" || return 0
	idx="$(hwsim_phy_index "$phy")"
	# mac80211.uc sets `option radio 'N'` (the wiphy-internal sub-radio
	# index) only on sections it derived from a phy's `info.radios[]`
	# array - i.e. exactly the single-wiphy multi_radio=1 case, where
	# every sub-radio section shares one phy and thus one idx above.
	# Defaults to 0 for the N>1 separate-wiphy case, where idx alone
	# already discriminates sections and this field is absent.
	config_get radio "$section" radio 0
	echo "${idx:-99} ${radio:-0} $phy $section" >> "$hwsim_bandfix_map"
}

# Channel/htmode picked to match the mac80211_hwsim regtest=11 testbed
# regdomain (../../../../../patches/900-...testbed-regtest-mode.patch):
# 5g ch36 (160 MHz-capable rule) EHT160, 6g ch37 (320 MHz-capable rule)
# EHT320. UNVERIFIED end to end - see NOTES.md "Open risks".
detect_hwsim_bandfix() {
	local i band channel htmode idx radio phy section hwsim_bandfix_map

	[ -f /etc/config/wireless ] || return 0

	hwsim_bandfix_map="/tmp/.hwsim_band_map.$$"
	rm -f "$hwsim_bandfix_map"

	config_load wireless
	config_foreach hwsim_collect_section wifi-device

	[ -s "$hwsim_bandfix_map" ] || {
		rm -f "$hwsim_bandfix_map"
		return 0
	}

	i=0
	# Primary key: phy index (still discriminates the N>1 separate-wiphy
	# case exactly as before). Secondary key: the `radio` sub-index
	# above, needed for the N=1 multi_radio=1 default, where every
	# section shares one phy/idx and would otherwise tie - and this
	# runs under busybox sort, which does not guarantee stable ordering
	# on ties, so an untied key is required, not just relied upon.
	sort -k1,1n -k2,2n "$hwsim_bandfix_map" | while read -r idx radio phy section; do
		case $((i % 3)) in
		0) band=2g; channel=1;  htmode=HE20 ;;
		1) band=5g; channel=36; htmode=EHT160 ;;
		2) band=6g; channel=37; htmode=EHT320 ;;
		esac

		uci set wireless.$section.band="$band"
		uci set wireless.$section.channel="$channel"
		uci set wireless.$section.htmode="$htmode"
		logger -t hwsim "wireless.$section ($phy, index $idx): band=$band channel=$channel htmode=$htmode"

		i=$((i + 1))
	done

	uci commit wireless
	rm -f "$hwsim_bandfix_map"

	return 0
}
