# Purpose: manually test GPON_ONBOARD_DHCP mode to test PON via onboard BOSA
#
# Before running this script, prepare the setup manually by following the steps
# below. cram tests cannot pause mid-test and interactively ask a human for
# input.
#
# - Log in on the HGW, run 'firstboot -yr', and wait until HGW has rebooted.
# - Remove any SFP.
# - Plug in XGS-PON fiber into onboard BOSA.
# - Connect other end of XGS-PON fiber to a link partner, typically an OLT.
# - The network behind the OLT must run a DHCP server which assigns IPv4
#   addresses on a certain network VLAN.
# - Log in on the HGW and change the WAN mode to GPON_ONBOARD_DHCP with the
#   command:
#   ba-cli "WANManager.setWANMode(WANMode = GPON_ONBOARD_DHCP)"
# - Wait a few seconds. If the HGW reboots, wait until the HGW has rebooted.
# - Let the OLT activate the ONU and send OMCI config. The OMCI config must
#   configure (at least) one bidirectional unicast GEM port which supports VLAN
#   translation between VLAN 100 on the HGW and the network VLAN mentioned
#   before.
# - Wait until the HGW has rebooted and the PON WAN IF has received an
#   IPv4 address. You can check this by running following command on the HGW:
#   ip a show dev vlan_data

  $ alias R="${CRAM_REMOTE_COMMAND:-ssh root@192.168.1.1}"

# Check if we're on the right board

  $ R "ubus call system board | jsonfilter -e @.model"
  mxl,osp-tb341-v2

  $ R ba-cli 'WANManager.WANMode?' | grep -Ev '^>|^$'
  WANManager.WANMode="GPON_ONBOARD_DHCP"

  $ R ba-cli 'SFPs.SFPCage.1.?' | grep -Ev '^>|^$'
  SFPs.SFPCage.1.
  SFPs.SFPCage.1.Alias="cpe-cage-1"
  SFPs.SFPCage.1.MgmtInterface="SFF-8472"
  SFPs.SFPCage.1.Name="sfp0"
  SFPs.SFPCage.1.SFF8024Identifier=2
  SFPs.SFPCage.1.SFPPresent=1
  SFPs.SFPCage.1.SFPReference="Device.SFPs.Mgmt.SFF8472.1"
  SFPs.SFPCage.1.SFPType="XGS-PON"

  $ R usp-cli 'Device.SFPs.SFPCage.1.?' | grep -Ev '^>|^$'
  Device.SFPs.SFPCage.1.
  Device.SFPs.SFPCage.1.Alias="cpe-cage-1"
  Device.SFPs.SFPCage.1.MgmtInterface="SFF-8472"
  Device.SFPs.SFPCage.1.Name="sfp0"
  Device.SFPs.SFPCage.1.SFF8024Identifier=2
  Device.SFPs.SFPCage.1.SFPPresent=1
  Device.SFPs.SFPCage.1.SFPReference="Device.SFPs.Mgmt.SFF8472.1"
  Device.SFPs.SFPCage.1.SFPType="XGS-PON"

  $ R ba-cli 'XPON.ONU.1.ANI.1.Transceiver.1.PONMode?' | grep -Ev '^>|^$'
  XPON.ONU.1.ANI.1.Transceiver.1.PONMode="XGS-PON"

  $ R ba-cli 'XPON.ONU.1.ANI.1.PONMode?' | grep -Ev '^>|^$'
  XPON.ONU.1.ANI.1.PONMode="XGS-PON"

  $ R ba-cli 'XPON.ONU.1.ANI.1.Status?' | grep -Ev '^>|^$'
  XPON.ONU.1.ANI.1.Status="Up"

  $ R ba-cli 'XPON.ONU.1.ANI.1.TC.ONUActivation.ONUState?' | grep -Ev '^>|^$'
  XPON.ONU.1.ANI.1.TC.ONUActivation.ONUState="O5"

  $ R ba-cli 'XPON.ONU.1.EthernetUNI.1.Status?' | grep -Ev '^>|^$'
  XPON.ONU.1.EthernetUNI.1.Status="Up"

# Uncomment next test and replace the default GW by the one on your HGW if you
# want to check if the 'ip r' command returns the correct default GW. Uncomment
# by inserting 2 spaces at the beginning of each line. The 'sed' command strips
# any whitespace from the end.

$ R ip r | grep default | sed -e 's/[[:space:]]*$//'
default via 10.100.0.1 dev vlan100 proto static

# Check HGW received default route via vlan100.

  $ R ip r | grep default | cut -d" " -f1
  default

  $ R ip r | grep default | cut -d" " -f5
  vlan100

# Check implementation details
  $ R fw_printenv -n wantype
  pon

  $ R cat /etc/config/serdes | grep -A 6 generic
  config serdes 'generic'
  	option tx_eq_pre '0'
  	option tx_eq_main '14'
  	option tx_eq_post '32'
  	option vboost_en '1'
  	option vboost_lvl '7'
  	option iboost_lvl '12'


