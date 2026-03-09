# Purpose: manually test Ethernet_DHCP mode
#
# Before running this script, prepare the setup manually by following the steps
# below. cram tests cannot pause mid-test and interactively ask a human for
# input.
#
# - Log in on the HGW, run 'firstboot -yr', and wait until HGW has rebooted.
# - Plug in optical Ethernet SFP.
# - Connect SFP to a link partner. The link partner must run a DHCP server which
#   assigns IPv4 addresses on VLAN 100.
# - Log in on the HGW and change the WAN mode to Ethernet_DHCP with the command:
#   ba-cli "WANManager.setWANMode(WANMode = Ethernet_DHCP)"
# - Wait until the HGW has rebooted and the Ethernet WAN IF has received an
#   IPv4 address. You can check this by running following command on the HGW:
#   ip a show dev vlan_data

  $ alias R="${CRAM_REMOTE_COMMAND:-ssh root@192.168.1.1}"

# Check if we're on the right board

  $ R "ubus call system board | jsonfilter -e @.model"
  mxl,osp-tb341-v2

  $ R ba-cli 'WANManager.WANMode?' | grep -Ev '^>|^$'
  WANManager.WANMode="Ethernet_DHCP"

  $ R ba-cli 'SFPs.SFPCage.1.?' | grep -Ev '^>|^$'
  SFPs.SFPCage.1.
  SFPs.SFPCage.1.Alias="cpe-cage-1"
  SFPs.SFPCage.1.MgmtInterface="SFF-8472"
  SFPs.SFPCage.1.Name="sfp0"
  SFPs.SFPCage.1.SFF8024Identifier=3
  SFPs.SFPCage.1.SFPPresent=1
  SFPs.SFPCage.1.SFPReference="Device.SFPs.Mgmt.SFF8472.1"
  SFPs.SFPCage.1.SFPType="Optical Ethernet"

  $ R usp-cli 'Device.SFPs.SFPCage.1.?' | grep -Ev '^>|^$'
  Device.SFPs.SFPCage.1.
  Device.SFPs.SFPCage.1.Alias="cpe-cage-1"
  Device.SFPs.SFPCage.1.MgmtInterface="SFF-8472"
  Device.SFPs.SFPCage.1.Name="sfp0"
  Device.SFPs.SFPCage.1.SFF8024Identifier=3
  Device.SFPs.SFPCage.1.SFPPresent=1
  Device.SFPs.SFPCage.1.SFPReference="Device.SFPs.Mgmt.SFF8472.1"
  Device.SFPs.SFPCage.1.SFPType="Optical Ethernet"

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
  eth

