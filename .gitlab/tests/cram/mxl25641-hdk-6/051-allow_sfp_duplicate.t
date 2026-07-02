# Test for FEAT-376 - Duplicate-prevention on SFPs.AllowedSFPs.AllowedSFP
#
# Short description
# - Add a row to SFPs.AllowedSFPs.AllowedSFP.
# - Check that adding a second row with the exact same classification criteria
#   is rejected.
# - Delete the row.
# - Check that adding the same row again now succeeds (nothing left to
#   conflict with).
# - Clean up.
#
# tr181-sfp rejects an AllowedSFP row on add/set if another row already has
# the exact same values for all 5 classification criteria (SFPType,
# VendorName, VendorOUI, VendorPN, Fingerprint). This is enforced via the
# "on action validate" callback on AllowedSFP[], which runs on both add and
# on parameter changes of an existing row.

  $ alias R="${CRAM_REMOTE_COMMAND:-ssh root@192.168.1.1}"

Check the table starts out empty (invariant left behind by 050-allow_block_sfp.t)

  $ R ba-cli 'SFPs.AllowedSFPs.AllowedSFPNumberOfEntries?' | grep -Ev '^(>|$)'
  SFPs.AllowedSFPs.AllowedSFPNumberOfEntries=0

Add a row allowing all optical Ethernet SFPs

  $ R "ba-cli 'SFPs.AllowedSFPs.AllowedSFP+{Enable=1,SFPType=\"Optical Ethernet\",VendorName=\"\",VendorOUI=\"\",VendorPN=\"\",Fingerprint=\"\"}'" | grep -Ev '^(>|$)'
  SFPs\.AllowedSFPs\.AllowedSFP\.\d+\. (re)
  SFPs\.AllowedSFPs\.AllowedSFP\.\d+\.Alias="cpe-AllowedSFP-\d+" (re)

  $ R ba-cli 'SFPs.AllowedSFPs.AllowedSFPNumberOfEntries?' | grep -Ev '^(>|$)'
  SFPs.AllowedSFPs.AllowedSFPNumberOfEntries=1

Adding a second row with the exact same criteria is rejected

  $ R "ba-cli 'SFPs.AllowedSFPs.AllowedSFP+{Enable=1,SFPType=\"Optical Ethernet\",VendorName=\"\",VendorOUI=\"\",VendorPN=\"\",Fingerprint=\"\"}'" | grep -Ev '^(>|$)'
  ERROR: add SFPs.AllowedSFPs.AllowedSFP failed (13 - duplicate)

  $ R ba-cli 'SFPs.AllowedSFPs.AllowedSFPNumberOfEntries?' | grep -Ev '^(>|$)'
  SFPs.AllowedSFPs.AllowedSFPNumberOfEntries=1

Delete the row

  $ R "ba-cli 'SFPs.AllowedSFPs.AllowedSFP.[SFPType==\"Optical Ethernet\"].-'" | grep -Ev '^(>|$)'
  SFPs\.AllowedSFPs\.AllowedSFP\.\d+\. (re)

  $ R ba-cli 'SFPs.AllowedSFPs.AllowedSFPNumberOfEntries?' | grep -Ev '^(>|$)'
  SFPs.AllowedSFPs.AllowedSFPNumberOfEntries=0

Adding the same values again now succeeds, since no conflicting row is left

  $ R "ba-cli 'SFPs.AllowedSFPs.AllowedSFP+{Enable=1,SFPType=\"Optical Ethernet\",VendorName=\"\",VendorOUI=\"\",VendorPN=\"\",Fingerprint=\"\"}'" | grep -Ev '^(>|$)'
  SFPs\.AllowedSFPs\.AllowedSFP\.\d+\. (re)
  SFPs\.AllowedSFPs\.AllowedSFP\.\d+\.Alias="cpe-AllowedSFP-\d+" (re)

  $ R ba-cli 'SFPs.AllowedSFPs.AllowedSFPNumberOfEntries?' | grep -Ev '^(>|$)'
  SFPs.AllowedSFPs.AllowedSFPNumberOfEntries=1

Clean up: delete the row, restore the table to its starting (empty) state

  $ R "ba-cli 'SFPs.AllowedSFPs.AllowedSFP.[SFPType==\"Optical Ethernet\"].-'" | grep -Ev '^(>|$)'
  SFPs\.AllowedSFPs\.AllowedSFP\.\d+\. (re)

  $ R ba-cli 'SFPs.AllowedSFPs.AllowedSFPNumberOfEntries?' | grep -Ev '^(>|$)'
  SFPs.AllowedSFPs.AllowedSFPNumberOfEntries=0
