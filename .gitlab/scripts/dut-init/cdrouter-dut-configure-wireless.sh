#!/bin/bash

vap_index=1

echo "$LABGRID_TARGET" | grep -q "urx851" && vap_index=2
echo "$LABGRID_TARGET" | grep -q "prpl-haze" && vap_index=3

# shellcheck disable=SC2029
ssh "root@$TARGET_LAN_IP" "ubus -t 200 wait_for WiFi.AccessPoint.${vap_index}"

# shellcheck disable=SC2029
if echo "$CI_RUNNER_DESCRIPTION" | grep -q testbed-01; then
    export CDROUTER_CONFIG_WIFI_LAN_CHANNEL=6
    ssh "root@$TARGET_LAN_IP" "ba-cli 'WiFi.Radio.[OperatingFrequencyBand == \"2.4GHz\"].Channel=6'"
else
    export CDROUTER_CONFIG_WIFI_LAN_CHANNEL=12
    ssh "root@$TARGET_LAN_IP" "ba-cli 'WiFi.Radio.[OperatingFrequencyBand == \"2.4GHz\"].Channel=12'"
fi

ssh "root@$TARGET_LAN_IP" "ba-cli 'WiFi.Radio.[OperatingFrequencyBand == \"2.4GHz\"].Enable=1'"
