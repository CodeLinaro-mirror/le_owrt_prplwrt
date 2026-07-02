# Test for FEAT-376 - Factory-reset behavior of SFPs.AllowedSFPs
#
# Short description
# - Put SFPs.AllowedSFPs in a non-default state (AllowAllSFPs=0, one row in
#   AllowedSFP).
# - Trigger Device.FactoryReset().
# - Wait for the device to come back up.
# - Check the reset actually happened (Reboot.Reboot.1.Cause).
# - Requirement: upon factory reset, the whitelist must be disabled
#   (AllowAllSFPs back to true/allow-all), so the gateway is not accidentally
#   locked out of talking to the USP controller (e.g. over an SFP-based WAN
#   interface) after a reset.
# - Requirement: upon factory reset, the whitelist database (AllowedSFP
#   table) is reset to its factory defaults - any addition/deletion done
#   before the reset does not survive it and must be re-executed. Prove this
#   by adding and then deleting a fresh row after the reset and checking
#   both operations still work normally.
#
# WARNING: this test is disruptive. Device.FactoryReset() wipes ALL
# persisted configuration on the device, not just SFPs.AllowedSFPs - it is
# not scoped to a single component. It runs unconditionally as part of this
# suite.

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

Put SFPs.AllowedSFPs in a non-default state

  $ R "ba-cli 'SFPs.AllowedSFPs.AllowAllSFPs=0'" | grep -Ev '^(>|$)'
  SFPs.AllowedSFPs.
  SFPs.AllowedSFPs.AllowAllSFPs=0

  $ R "ba-cli 'SFPs.AllowedSFPs.AllowedSFP+{Enable=1,SFPType=\"Optical Ethernet\",VendorName=\"\",VendorOUI=\"\",VendorPN=\"\",Fingerprint=\"\"}'" | grep -Ev '^(>|$)'
  SFPs\.AllowedSFPs\.AllowedSFP\.\d+\. (re)
  SFPs\.AllowedSFPs\.AllowedSFP\.\d+\.Alias="cpe-AllowedSFP-\d+" (re)

  $ R ba-cli 'SFPs.AllowedSFPs.AllowedSFPNumberOfEntries?' | grep -Ev '^(>|$)'
  SFPs.AllowedSFPs.AllowedSFPNumberOfEntries=1

Trigger a factory reset

  $ R "ba-cli 'Device.FactoryReset()'" > /dev/null 2>&1

Wait for the device to reboot and come back up

  $ wait_dut_back

Device.FactoryReset() wipes /etc, which regenerates the DUT's SSH host key,
so the runner's previous known_hosts entry would otherwise make every R
call below fail with "Host key verification failed" - refresh it the same
way the testbed pre-flight check does (.gitlab/testbed.yml)

  $ ssh-keygen -R "$TARGET_LAN_IP" > /dev/null 2>&1; ssh-keyscan "$TARGET_LAN_IP" >> ~/.ssh/known_hosts 2> /dev/null

Check the reset actually happened

  $ R "ba-cli --json Reboot.Reboot.1.Cause? | sed -n '2p'" | jq -r '.[0]["Reboot.Reboot.1."].Cause'
  LocalFactoryReset

Requirement: the whitelist is disabled after factory reset, so the gateway
can talk to the USP controller instead of being locked out by a stale
AllowedSFP configuration

  $ R "ba-cli 'SFPs.AllowedSFPs.AllowAllSFPs?'" | grep -Ev '^(>|$)'
  SFPs.AllowedSFPs.AllowAllSFPs=1

Requirement: the whitelist database is reset to its factory defaults - the
row added before the reset is gone

  $ R ba-cli 'SFPs.AllowedSFPs.AllowedSFPNumberOfEntries?' | grep -Ev '^(>|$)'
  SFPs.AllowedSFPs.AllowedSFPNumberOfEntries=0

Requirement: add/delete operations must be re-executed after a factory
reset - prove the table is fully functional again, not just empty

  $ R "ba-cli 'SFPs.AllowedSFPs.AllowedSFP+{Enable=1,SFPType=\"Optical Ethernet\",VendorName=\"\",VendorOUI=\"\",VendorPN=\"\",Fingerprint=\"\"}'" | grep -Ev '^(>|$)'
  SFPs\.AllowedSFPs\.AllowedSFP\.\d+\. (re)
  SFPs\.AllowedSFPs\.AllowedSFP\.\d+\.Alias="cpe-AllowedSFP-\d+" (re)

  $ R ba-cli 'SFPs.AllowedSFPs.AllowedSFPNumberOfEntries?' | grep -Ev '^(>|$)'
  SFPs.AllowedSFPs.AllowedSFPNumberOfEntries=1

  $ R "ba-cli 'SFPs.AllowedSFPs.AllowedSFP.[SFPType==\"Optical Ethernet\"].-'" | grep -Ev '^(>|$)'
  SFPs\.AllowedSFPs\.AllowedSFP\.\d+\. (re)

  $ R ba-cli 'SFPs.AllowedSFPs.AllowedSFPNumberOfEntries?' | grep -Ev '^(>|$)'
  SFPs.AllowedSFPs.AllowedSFPNumberOfEntries=0
