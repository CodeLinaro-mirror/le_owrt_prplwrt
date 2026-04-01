Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"


Create DHCPv4.Client.{i}. with Alias value of maximal length (64 chars):

  $ R ba-cli "Device.DHCPv4.Client.+ { Alias=$(yes a | tr -d '\n' | head -c 64) }" | grep -Ev '^>|^$'
  Device.DHCPv4.Client.*. (re)
  Device.DHCPv4.Client.*.Alias="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" (re)

Create DHCPv4.Client.{i}. with Alias value with range overflow (65 chars):

  $ R ba-cli "Device.DHCPv4.Client.+ { Alias=$(yes a | tr -d '\n' | head -c 65) }" | grep -Ev '^>|^$'
  ERROR: add Device.DHCPv4.Client. failed (10 - invalid value)

Create ReqOption.{i}. with Alias value of maximal length (64 chars):

  $ R ba-cli "Device.DHCPv4.Client.aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.ReqOption.+ { Alias=$(yes r | tr -d '\n' | head -c 64) }" | grep -Ev '^>|^$'
  Device.DHCPv4.Client.*.ReqOption.*. (re)
  Device.DHCPv4.Client.*.ReqOption.*.Alias="rrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr" (re)

Create ReqOption.{i}. with Alias value with range overflow (65 chars):

  $ R ba-cli "Device.DHCPv4.Client.*.ReqOption.+ { Alias=$(yes r | tr -d '\n' | head -c 65) }" | grep -Ev '^>|^$'
  ERROR: add Device.DHCPv4.Client.*.ReqOption. failed (10 - invalid value)

Create SentOption.{i}. with Alias value of maximal length (64 chars):

  $ R ba-cli "Device.DHCPv4.Client.aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.SentOption.+ { Alias=$(yes s | tr -d '\n' | head -c 64) }" | grep -Ev '^>|^$'
  Device.DHCPv4.Client.*.SentOption.*. (re)
  Device.DHCPv4.Client.*.SentOption.*.Alias="ssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssss" (re)

Create SentOption.{i}. with Alias value with range overflow (65 chars):

  $ R ba-cli "Device.DHCPv4.Client.*.SentOption.+ { Alias=$(yes s | tr -d '\n' | head -c 65) }" | grep -Ev '^>|^$'
  ERROR: add Device.DHCPv4.Client.*.SentOption. failed (10 - invalid value)

Cleanup - remove only the instance created in this test:

  $ R ba-cli "Device.DHCPv4.Client.$(yes a | tr -d '\n' | head -c 64).-" | grep -Ev '^>|^$'
  Device.DHCPv4.Client.*. (re)
  Device.DHCPv4.Client.*.SentOption. (re)
  Device.DHCPv4.Client.*.SentOption.*. (re)
  Device.DHCPv4.Client.*.ReqOption. (re)
  Device.DHCPv4.Client.*.ReqOption.*. (re)
  Device.DHCPv4.Client.*.Stats. (re)
