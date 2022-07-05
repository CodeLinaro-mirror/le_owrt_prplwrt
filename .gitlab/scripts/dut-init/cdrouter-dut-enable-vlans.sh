#!/bin/bash

run_cmd()
{
  local cmd="$1"
  local self="$(basename $0)"
  printf "\n%s run_cmd: %s\n" "${self}" "$1"
  ssh root@$TARGET_LAN_IP "$cmd 2>&1"
  echo '----------------------------------------------------------------------'
}

# run_cmd "ubus -t 60 wait_for Ethernet.VLANTermination"
# run_cmd "ubus call Ethernet.VLANTermination _add '{\"parameters\":{\"Alias\":\"vlanWan\", \"Name\":\"vlan_wan\", \"LowerLayers\":\"$DUT_TR181_WAN_INTERFACE\", \"VLANID\":101, \"Enable\":1}}'"
# run_cmd "ubus -t 60 wait_for IP.Interface"
# run_cmd "ubus call IP.Interface.2 _set '{\"parameters\":{\"LowerLayers\":\"Ethernet.VLANTermination.1.\"}}'"

run_cmd "/etc/init.d/wan-manager stop; rm -fr /etc/config/wan-manager"
run_cmd "sed -i 's/VlanID = 201/VlanID = 101/' /etc/amx/wan-manager/defaults.d/10_wan_manager.odl"
run_cmd "/etc/init.d/wan-manager start; ubus -t 60 wait_for X_PRPL-COM_WANManager.WAN"
run_cmd "ubus call X_PRPL-COM_WANManager setWANMode '{\"WANMode\":\"demo_vlanmode\"}'"

case "$DUT_BOARD" in
  glinet-b1300)
    run_cmd " \
      uci add network switch_vlan ; \
      uci set network.@switch_vlan[-1]=switch_vlan ; \
      uci set network.@switch_vlan[-1].device='switch0' ; \
      uci set network.@switch_vlan[-1].vlan='2' ; \
      uci set network.@switch_vlan[-1].vid='101' ; \
      uci set network.@switch_vlan[-1].ports='0t 5t' ; \
      uci commit network \
    "
    run_cmd "swconfig dev switch0 vlan 2 set vid 101; swconfig dev switch0 vlan 2 set ports '0t 5t'"
    run_cmd "swconfig dev switch0 vlan 2 show; uci show network.@switch_vlan[1]"
    ;;
  turris-omnia)
    ;;
esac

run_cmd "ubus call Ethernet.VLANTermination _get"
run_cmd "(cat /proc/vlan101 || cat /proc/net/vlan/vlan101) 2> /dev/null"
run_cmd "ip address show vlan101; ip route show"

true
