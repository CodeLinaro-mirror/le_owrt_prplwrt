# Test for FEAT-376 - VendorName/VendorPN classification of SFPs.AllowedSFPs
#
# Short description
# - Read the plugged module's real VendorName/VendorPN from the DM, at
#   SFPs.Mgmt.SFF8472.{i}.Transceiver. where tr181-sfp publishes the EEPROM
#   data (varies per rig, so not hardcoded).
# - Block all SFPs, add an AllowedSFP row for that VendorName but with a
#   VendorPN that cannot match, reboot the board and check the module is
#   blocked in both the SFPs and Ethernet DM.
# - Correct the row's VendorPN to the module's real value, reboot again and
#   check the module is allowed in both.
# - Clean up (the board is already back in the allowed state, so restoring
#   the allow-all defaults needs no extra reboot).
#
# A full board reboot is used to force re-evaluation. Restarting only
# tr181-sfp re-creates the SFP cage objects and re-runs
# dm_allow_is_sfp_allowed() (tr181-sfp, src/dm_allowed_sfps.c), but
# tr181-ethernet does not follow that restart, so
# Ethernet.Interface.{i}.Status keeps its old value and the DM ends up
# inconsistent (IsAllowed=0 with Status="Up"). Rebooting starts both
# plugins fresh, evaluates the whitelist the way a real deployment would
# after a power cycle, and also proves the AllowedSFPs configuration
# survives a reboot.

  $ alias R="${CRAM_REMOTE_COMMAND:-ssh root@192.168.1.1}"
  $ TARGET_LAN_IP="${TARGET_LAN_IP:-192.168.1.1}"
  $ DUT_SSH="ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5"

Reboot wait helper: give the board time to go down, then poll until both
tr181-sfp and tr181-ethernet answer over the datamodel, then let the
remaining services settle

  $ wait_dut_back() {
  >     sleep 60
  >     tries=0
  >     until $DUT_SSH "root@$TARGET_LAN_IP" "ba-cli 'SFPs.SFPCage.1.IsAllowed?'" 2> /dev/null | grep -q 'IsAllowed='; do
  >         tries=$((tries+1))
  >         [ "$tries" -ge 48 ] && return 1
  >         sleep 5
  >     done
  >     until $DUT_SSH "root@$TARGET_LAN_IP" "ba-cli 'Ethernet.Interface.1.Status?'" 2> /dev/null | grep -q 'Status='; do
  >         tries=$((tries+1))
  >         [ "$tries" -ge 48 ] && return 1
  >         sleep 5
  >     done
  >     sleep 30
  > }

Read the plugged module's real VendorName and VendorPN

  $ SFP_VENDOR_NAME=$(R "ba-cli 'SFPs.Mgmt.SFF8472.1.Transceiver.VendorName?'" | grep -Ev '^(>|$)' | sed -n -E 's/.*VendorName="(.*)"$/\1/p')
  $ SFP_VENDOR_PN=$(R "ba-cli 'SFPs.Mgmt.SFF8472.1.Transceiver.VendorPN?'" | grep -Ev '^(>|$)' | sed -n -E 's/.*VendorPN="(.*)"$/\1/p')
  $ [ -n "$SFP_VENDOR_NAME" ] && [ -n "$SFP_VENDOR_PN" ]

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

Reboot the board so the whitelist is re-evaluated from a clean start

  $ R "ba-cli 'Device.Reboot()'" > /dev/null 2>&1 || true
  $ wait_dut_back

Check the module is blocked, in SFPs and in Ethernet

  $ R ba-cli 'SFPs.SFPCage.1.IsAllowed?' | grep -Ev '^(>|$)'
  SFPs.SFPCage.1.IsAllowed=0

  $ R ba-cli 'Ethernet.Interface.1.Status?' | grep -Ev '^(>|$)'
  Ethernet.Interface.1.Status="NotAllowed"

Correct the row's VendorPN to the module's real value

  $ R "ba-cli 'SFPs.AllowedSFPs.AllowedSFP.[VendorName==\"$SFP_VENDOR_NAME\"].VendorPN=\"$SFP_VENDOR_PN\"'" | grep -Ev '^(>|$)'
  SFPs\.AllowedSFPs\.AllowedSFP\.\d+\. (re)
  SFPs\.AllowedSFPs\.AllowedSFP\.\d+\.VendorPN=".+" (re)

Reboot the board so the whitelist is re-evaluated again

  $ R "ba-cli 'Device.Reboot()'" > /dev/null 2>&1 || true
  $ wait_dut_back

Check the module is now allowed, in SFPs and in Ethernet

  $ R ba-cli 'SFPs.SFPCage.1.IsAllowed?' | grep -Ev '^(>|$)'
  SFPs.SFPCage.1.IsAllowed=1

  $ R ba-cli 'Ethernet.Interface.1.Status?' | grep -Ev '^(>|$)' | grep NotAllowed | wc -l
  0

Clean up: delete the row and allow all SFPs again; the module is already in
the allowed state, so no extra reboot is needed

  $ R "ba-cli 'SFPs.AllowedSFPs.AllowedSFP.[VendorName==\"$SFP_VENDOR_NAME\"].-'" | grep -Ev '^(>|$)'
  SFPs\.AllowedSFPs\.AllowedSFP\.\d+\. (re)

  $ R "ba-cli 'SFPs.AllowedSFPs.AllowAllSFPs=1'" | grep -Ev '^(>|$)'
  SFPs.AllowedSFPs.
  SFPs.AllowedSFPs.AllowAllSFPs=1

  $ R ba-cli 'SFPs.SFPCage.1.IsAllowed?' | grep -Ev '^(>|$)'
  SFPs.SFPCage.1.IsAllowed=1
