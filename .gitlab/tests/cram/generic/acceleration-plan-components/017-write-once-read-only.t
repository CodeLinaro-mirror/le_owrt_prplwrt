Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"


Test write-once read-only functionality with DHCPv4.Client Alias parameter:

Create DHCPv4.Client.{i}. with Alias value:

  $ R "ba-cli 'Device.DHCPv4.Client.+ { Alias=WriteOnceTest }' | grep -Ev '^>|^$'"
  Device.DHCPv4.Client.*. (re)
  Device.DHCPv4.Client.*.Alias="WriteOnceTest" (re)

Verify the Alias was set correctly:

  $ R "ba-cli 'Device.DHCPv4.Client.*.Alias?' | grep -Ev '^>|^$' | grep WriteOnceTest"
  Device.DHCPv4.Client.*.Alias="WriteOnceTest" (re)

Attempt to modify the Alias (should fail - write-once read-only):

  $ R "ba-cli 'Device.DHCPv4.Client.WriteOnceTest.Alias=ModifiedValue' 2>&1 | grep -Ev '^>|^$|^\+'"
  ERROR: set Device.DHCPv4.Client.WriteOnceTest.Alias failed (15 - is read only)

Verify the Alias remains unchanged:

  $ R "ba-cli 'Device.DHCPv4.Client.*.Alias?' | grep -Ev '^>|^$' | grep WriteOnceTest"
  Device.DHCPv4.Client.*.Alias="WriteOnceTest" (re)

Cleanup - remove only the instance created in this test:

  $ R "ba-cli 'Device.DHCPv4.Client.WriteOnceTest.-' | grep -Ev '^>|^$'"
  Device.DHCPv4.Client.*. (re)
  Device.DHCPv4.Client.*.SentOption. (re)
  Device.DHCPv4.Client.*.ReqOption. (re)
  Device.DHCPv4.Client.*.Stats. (re)


Test write-once read-only functionality with DHCPv6.Client Alias parameter:

Create DHCPv6.Client.{i}. with Alias value:

  $ R "usp-cli 'Device.DHCPv6.Client.+ { Alias=WriteOnceTestV6 }' | grep -Ev '^>|^$'"
  Device.DHCPv6.Client.*. (re)
  Device.DHCPv6.Client.*.Alias="WriteOnceTestV6" (re)

Verify the Alias was set correctly:

  $ R "usp-cli 'Device.DHCPv6.Client.*.Alias?' | grep -Ev '^>|^$' | grep WriteOnceTestV6"
  Device.DHCPv6.Client.*.Alias="WriteOnceTestV6" (re)

Attempt to modify the Alias (should fail - write-once read-only):

  $ R "usp-cli 'Device.DHCPv6.Client.[Alias==\"WriteOnceTestV6\"].Alias=ModifiedValueV6'" > /dev/null 2>&1 || true

Verify the Alias remains unchanged:

  $ R "usp-cli 'Device.DHCPv6.Client.*.Alias?' | grep -Ev '^>|^$' | grep WriteOnceTestV6"
  Device.DHCPv6.Client.*.Alias="WriteOnceTestV6" (re)

Verify the rejected value was not applied:

  $ R "usp-cli 'Device.DHCPv6.Client.*.Alias?' | grep -Ev '^>|^$' | grep ModifiedValueV6 || echo 'Not found'"
  Not found

Cleanup - remove only the instance created in this test:

  $ R "usp-cli 'Device.DHCPv6.Client.[Alias==\"WriteOnceTestV6\"].-'" > /dev/null 2>&1 || true

Verify the instance was removed:

  $ R "usp-cli 'Device.DHCPv6.Client.*.Alias?' | grep -Ev '^>|^$' | grep WriteOnceTestV6 || echo 'Not found'"
  Not found
