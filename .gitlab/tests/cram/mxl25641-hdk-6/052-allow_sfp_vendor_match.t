# VendorName/VendorPN classification of SFPs.AllowedSFPs
#
# Short description
# - Read the plugged module's real VendorName/VendorPN from the DM, at
#   SFPs.Mgmt.SFF8472.{i}.Transceiver. where tr181-sfp publishes the EEPROM
#   data (varies per rig, so not hardcoded).
# - Block all SFPs, add an AllowedSFP row for that VendorName but with a
#   VendorPN that cannot match, simulate a replug and check the module is
#   blocked in both the SFPs and the Ethernet data model.
# - Correct the row's VendorPN to the module's real value, simulate a replug
#   again and check the module is allowed in both.
# - Restore the allow-all defaults and check the module is allowed again.
#
# Re-evaluation of the whitelist is forced by simulating a replug, exactly as
# 050-allow_block_sfp.t does: tr181-sfp determines SFP presence through
# /lib/sfp/get_eeprom_info.sh, so swapping that script for one reporting no
# module and swapping it back makes the plugin re-read the EEPROM data and
# re-run its allow check. This is the only path that re-evaluates an
# already-plugged module: the allow check runs from sfpmgr_sfp_inserted(),
# which the discovery poll calls on a presence transition, while writing
# AllowAllSFPs or an AllowedSFP row only validates the write.
#
# A replug is also what makes tr181-ethernet follow. It subscribes to the SFP
# cage with the filter contains('parameters.SFPPresent') and only then re-reads
# IsAllowed, so a presence transition is what updates
# Ethernet.Interface.{i}.Status - which is exactly what a real deployment sees
# when a blocked module is inserted.
#
# A board reboot is deliberately not used to trigger re-evaluation. A reboot
# costs several minutes of a suite budget shared by the whole board, which
# would make this test unusable in CI, and it tests the boot path rather than
# the insertion path this requirement is about. Restarting only the tr181-sfp
# process is not an alternative either: it re-runs the allow check, but
# tr181-ethernet does not follow a restart of tr181-sfp, so
# Ethernet.Interface.{i}.Status keeps its previous value and the data model
# ends up inconsistent (IsAllowed=0 while Status is still Up).
#
# For that reason this test is numbered ahead of the two tests that stop and
# start tr181-sfp (053-allow_sfp_odl_default.t and 054-allow_sfp_persistence.t):
# cram runs the suite in filename order, and this test is the one that needs the
# SFP-to-Ethernet subscription still live.

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Read the plugged module's real VendorName and VendorPN

  $ SFP_VENDOR_NAME=$(R "ba-cli 'SFPs.Mgmt.SFF8472.1.Transceiver.VendorName?'" | grep -Ev '^(>|$)' | sed -n -E 's/.*VendorName="(.*)"$/\1/p')
  $ SFP_VENDOR_PN=$(R "ba-cli 'SFPs.Mgmt.SFF8472.1.Transceiver.VendorPN?'" | grep -Ev '^(>|$)' | sed -n -E 's/.*VendorPN="(.*)"$/\1/p')
  $ [ -n "$SFP_VENDOR_NAME" ] && [ -n "$SFP_VENDOR_PN" ]

Check tr181-sfp uses get_eeprom_info.sh to determine SFP presence, and keep a
copy of it plus a stand-in reporting no module, to simulate replugging

  $ R ls /lib/sfp/get_eeprom_info.sh
  /lib/sfp/get_eeprom_info.sh

  $ R 'echo "echo \"0 0 0 0\"" > /lib/sfp/get_eeprom_info.sh.cram_no_sfp'
  $ R chmod +x /lib/sfp/get_eeprom_info.sh.cram_no_sfp
  $ R cp -af /lib/sfp/get_eeprom_info.sh /lib/sfp/get_eeprom_info.sh.cram_orig

Block all SFPs, then allow only this VendorName with a VendorPN that cannot
match the plugged module (fixed short value: VendorPN validates with
check_maximum_length 16, so appending a suffix to the real PN could be
rejected)

  $ R "ba-cli 'SFPs.AllowedSFPs.AllowAllSFPs=0'" | grep -Ev '^(>|$)'
  SFPs.AllowedSFPs.
  SFPs.AllowedSFPs.AllowAllSFPs=0

  $ R "ba-cli 'SFPs.AllowedSFPs.AllowedSFP+{Enable=1,SFPType=\"\",VendorName=\"$SFP_VENDOR_NAME\",VendorOUI=\"\",VendorPN=\"CRAM_NO_MATCH\",Fingerprint=\"\"}'" | grep -Ev '^(>|$)'
  SFPs\.AllowedSFPs\.AllowedSFP\.\d+\. (re)
  SFPs\.AllowedSFPs\.AllowedSFP\.\d+\.Alias="cpe-AllowedSFP-\d+" (re)

Simulate that the SFP is unplugged

  $ R cp -af /lib/sfp/get_eeprom_info.sh.cram_no_sfp /lib/sfp/get_eeprom_info.sh
  $ sleep 2
  $ R ba-cli 'SFPs.SFPCage.1.SFPPresent?' | grep -Ev '^(>|$)'
  SFPs.SFPCage.1.SFPPresent=0

Simulate that the SFP is replugged, so the whitelist is evaluated against it

  $ R cp -af /lib/sfp/get_eeprom_info.sh.cram_orig /lib/sfp/get_eeprom_info.sh
  $ sleep 2

Check the module is blocked, in SFPs and in Ethernet

  $ R ba-cli 'SFPs.SFPCage.1.SFPPresent?' | grep -Ev '^(>|$)'
  SFPs.SFPCage.1.SFPPresent=1

  $ R ba-cli 'SFPs.SFPCage.1.IsAllowed?' | grep -Ev '^(>|$)'
  SFPs.SFPCage.1.IsAllowed=0

  $ R ba-cli 'Ethernet.Interface.1.Status?' | grep -Ev '^(>|$)'
  Ethernet.Interface.1.Status="NotAllowed"

Correct the row's VendorPN to the module's real value

  $ R "ba-cli 'SFPs.AllowedSFPs.AllowedSFP.[VendorName==\"$SFP_VENDOR_NAME\"].VendorPN=\"$SFP_VENDOR_PN\"'" | grep -Ev '^(>|$)'
  SFPs\.AllowedSFPs\.AllowedSFP\.\d+\. (re)
  SFPs\.AllowedSFPs\.AllowedSFP\.\d+\.VendorPN=".+" (re)

Simulate that the SFP is unplugged and replugged, so the corrected row is
evaluated against it

  $ R cp -af /lib/sfp/get_eeprom_info.sh.cram_no_sfp /lib/sfp/get_eeprom_info.sh
  $ sleep 2
  $ R ba-cli 'SFPs.SFPCage.1.SFPPresent?' | grep -Ev '^(>|$)'
  SFPs.SFPCage.1.SFPPresent=0

  $ R cp -af /lib/sfp/get_eeprom_info.sh.cram_orig /lib/sfp/get_eeprom_info.sh
  $ sleep 2

Check the module is now allowed, in SFPs and in Ethernet

  $ R ba-cli 'SFPs.SFPCage.1.IsAllowed?' | grep -Ev '^(>|$)'
  SFPs.SFPCage.1.IsAllowed=1

  $ R ba-cli 'Ethernet.Interface.1.Status?' | grep '^Ethernet\.Interface\.1\.Status="' | grep -v '="NotAllowed"$'
  Ethernet\.Interface\.1\.Status=".+" (re)

Restore the allow-all defaults, and replug once more so the restored
configuration is evaluated too

  $ R "ba-cli 'SFPs.AllowedSFPs.AllowAllSFPs=1'" | grep -Ev '^(>|$)'
  SFPs.AllowedSFPs.
  SFPs.AllowedSFPs.AllowAllSFPs=1

  $ R "ba-cli 'SFPs.AllowedSFPs.AllowedSFP.[VendorName==\"$SFP_VENDOR_NAME\"].-'" | grep -Ev '^(>|$)'
  SFPs\.AllowedSFPs\.AllowedSFP\.\d+\. (re)

  $ R cp -af /lib/sfp/get_eeprom_info.sh.cram_no_sfp /lib/sfp/get_eeprom_info.sh
  $ sleep 2
  $ R cp -af /lib/sfp/get_eeprom_info.sh.cram_orig /lib/sfp/get_eeprom_info.sh
  $ sleep 2

Check the device is back to its starting state

  $ R ba-cli 'SFPs.AllowedSFPs.AllowedSFPNumberOfEntries?' | grep -Ev '^(>|$)'
  SFPs.AllowedSFPs.AllowedSFPNumberOfEntries=0

  $ R ba-cli 'SFPs.SFPCage.1.IsAllowed?' | grep -Ev '^(>|$)'
  SFPs.SFPCage.1.IsAllowed=1

  $ R ba-cli 'Ethernet.Interface.1.Status?' | grep '^Ethernet\.Interface\.1\.Status="' | grep -v '="NotAllowed"$'
  Ethernet\.Interface\.1\.Status=".+" (re)

  $ R rm -f /lib/sfp/get_eeprom_info.sh.cram_no_sfp /lib/sfp/get_eeprom_info.sh.cram_orig
