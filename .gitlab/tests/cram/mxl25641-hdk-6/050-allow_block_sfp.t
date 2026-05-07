# Test for FEAT-376 - Allow/block SFPs
#
# Short description
# - Check HGW has copper SFP which is allowed.
# - Instruct HGW to block all SFPs.
# - Simulate the SFP is replugged.
# - Check that SFPs and Ethernet in TR-181 DM both show the SFP as NotAllowed.
# - Instruct the HGW to allow all SFPs.
# - Simulate the SFP is replugged.
# - Check that SFPs and Ethernet in TR-181 DM no longer show the SFP as
#   NotAllowed.
#
# Detailed description
# - Check we're on the right board.
# - Check the current situaton:
#   - Check a copper Ethernet SFP is present in the 1st SFP cage and that it's
#     allowed.
#   - Check Ethernet.Interface.1.SFPReferenceList refers to the 1st cage.
#   - Check Ethernet.Interface.1.Status is different from NotAllowed.
#   - Check SFPs.AllowAllSFPs has default values:
#     - Check SFPs.AllowedSFPs.AllowAllSFPs is 1
#     - Check SFPs.AllowedSFPs.AllowedSFP is empty
# - Change SFPs.AllowedSFPs.AllowAllSFPs to 0.
# - Simulate SFP is unplugged.
# - Check SFPs DM indicates no SFP is present.
# - Simulate SFP is replugged.
# - Check HGW does not allow the SFP:
#   - Check SFPs DM shows the SFP as not allowed.
#   - Check Ethernet.Interface.1.Status is NotAllowed.
# - Change SFPs.AllowedSFPs.AllowAllSFPs to 1.
# - Simulate SFP is replugged.
# - Check HGW allows the SFP
#   - Check SFPs DM shows the SFP as not allowed.
#   - Check Ethernet.Interface.1.Status is different from NotAllowed.
#
# To simulate an SFP is replugged, the test uses knowledge on how tr181-sfp
# determines SFP presence.
#
# The main purpose of the test is to check interaction between tr181-sfp and
# tr181-ethernet. Therefore the test only changes SFPs.AllowedSFPs.AllowAllSFPs
# to block/allow SFPs. It does not use the table SFPs.AllowedSFPs.AllowedSFP.
# Allowing/blocking SFPs via that table is already covered by the unit tests of
# tr181-sfp.

  $ alias R="${CRAM_REMOTE_COMMAND:-ssh root@192.168.1.1}"

Check if we're on the right board

  $ R "ubus call system board | jsonfilter -e @.model"
  mxl,osp-tb341-v2

  $ R ba-cli 'SFPs.SFPCage.1.?' | grep -Ev '^>|^$'
  SFPs.SFPCage.1.
  SFPs.SFPCage.1.Alias="cpe-cage-1"
  SFPs.SFPCage.1.IsAllowed=1
  SFPs.SFPCage.1.MgmtInterface="SFF-8472"
  SFPs.SFPCage.1.Name="sfp0"
  SFPs.SFPCage.1.SFF8024Identifier=3
  SFPs.SFPCage.1.SFPPresent=1
  SFPs.SFPCage.1.SFPReference="Device.SFPs.Mgmt.SFF8472.1"
  SFPs.SFPCage.1.SFPType="Optical Ethernet"

  $ R ba-cli 'Ethernet.Interface.1.Name?' | grep -Ev '^>|^$'
  Ethernet.Interface.1.Name="eth1"

  $ R ba-cli 'Ethernet.Interface.1.SFPReferenceList?' | grep -Ev '^>|^$'
  Ethernet.Interface.1.SFPReferenceList="SFPs.SFPCage.1"

Check that Ethernet.Interface.1.Status is different from NotAllowed

  $ R ba-cli 'Ethernet.Interface.1.Status?' | grep -Ev '^>|^$' | grep NotAllowed | wc -l
  0

  $ R ba-cli 'SFPs.AllowedSFPs.?' | grep -Ev '^>|^$'
  SFPs.AllowedSFPs.
  SFPs.AllowedSFPs.AllowAllSFPs=1
  SFPs.AllowedSFPs.AllowedSFPNumberOfEntries=0

  $ R ba-cli 'SFPs.AllowedSFPs.AllowAllSFPs=0' | grep -Ev '^>|^$'
  SFPs.AllowedSFPs.
  SFPs.AllowedSFPs.AllowAllSFPs=0

Check tr181-sfp uses get_eeprom_info.sh to determine SFP presence

  $ R ls /lib/sfp/get_eeprom_info.sh
  /lib/sfp/get_eeprom_info.sh

Simulate that SFP is unplugged

  $ R 'echo "echo \"0 0 0 0\"" > /lib/sfp/get_eeprom_info.sh.cram_no_sfp'
  $ R chmod +x /lib/sfp/get_eeprom_info.sh.cram_no_sfp
  $ R cp -af /lib/sfp/get_eeprom_info.sh /lib/sfp/get_eeprom_info.sh.orig
  $ R cp -af /lib/sfp/get_eeprom_info.sh.cram_no_sfp /lib/sfp/get_eeprom_info.sh
  $ sleep 2
  $ R ba-cli 'SFPs.SFPCage.1.SFPPresent?' | grep -Ev '^>|^$'
  SFPs.SFPCage.1.SFPPresent=0

Simulate that SFP is replugged

  $ R cp -af /lib/sfp/get_eeprom_info.sh.orig /lib/sfp/get_eeprom_info.sh
  $ sleep 2
  $ R ba-cli 'SFPs.SFPCage.1.?' | grep -Ev '^>|^$'
  SFPs.SFPCage.1.
  SFPs.SFPCage.1.Alias="cpe-cage-1"
  SFPs.SFPCage.1.IsAllowed=0
  SFPs.SFPCage.1.MgmtInterface="SFF-8472"
  SFPs.SFPCage.1.Name="sfp0"
  SFPs.SFPCage.1.SFF8024Identifier=3
  SFPs.SFPCage.1.SFPPresent=1
  SFPs.SFPCage.1.SFPReference="Device.SFPs.Mgmt.SFF8472.1"
  SFPs.SFPCage.1.SFPType="Optical Ethernet"

  $ R ba-cli 'Ethernet.Interface.1.Status?' | grep -Ev '^>|^$'
  Ethernet.Interface.1.Status="NotAllowed"

  $ R ba-cli 'SFPs.AllowedSFPs.AllowAllSFPs=1' | grep -Ev '^>|^$'
  SFPs.AllowedSFPs.
  SFPs.AllowedSFPs.AllowAllSFPs=1

Simulate that SFP is unplugged

  $ R cp -af /lib/sfp/get_eeprom_info.sh.cram_no_sfp /lib/sfp/get_eeprom_info.sh
  $ sleep 2
  $ R ba-cli 'SFPs.SFPCage.1.SFPPresent?' | grep -Ev '^>|^$'
  SFPs.SFPCage.1.SFPPresent=0

Simulate that SFP is replugged

  $ R cp -af /lib/sfp/get_eeprom_info.sh.orig /lib/sfp/get_eeprom_info.sh
  $ R sleep 2
  $ R ba-cli 'SFPs.SFPCage.1.?' | grep -Ev '^>|^$'
  SFPs.SFPCage.1.
  SFPs.SFPCage.1.Alias="cpe-cage-1"
  SFPs.SFPCage.1.IsAllowed=1
  SFPs.SFPCage.1.MgmtInterface="SFF-8472"
  SFPs.SFPCage.1.Name="sfp0"
  SFPs.SFPCage.1.SFF8024Identifier=3
  SFPs.SFPCage.1.SFPPresent=1
  SFPs.SFPCage.1.SFPReference="Device.SFPs.Mgmt.SFF8472.1"
  SFPs.SFPCage.1.SFPType="Optical Ethernet"

Check that Ethernet.Interface.1.Status is different from NotAllowed

  $ R ba-cli 'Ethernet.Interface.1.Status?' | grep -Ev '^>|^$' | grep NotAllowed | wc -l
  0
