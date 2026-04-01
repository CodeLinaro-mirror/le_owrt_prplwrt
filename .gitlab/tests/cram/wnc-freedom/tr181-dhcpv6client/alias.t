Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"


Create DHCPv6.Client.{i}. with Alias value of maximal length (64 chars):

  $ R ba-cli "Device.DHCPv6.Client.+ { Alias=$(yes b | tr -d '\n' | head -c 64) }" | grep -Ev '^>|^$'
  Device.DHCPv6.Client.*. (re)
  Device.DHCPv6.Client.*.Alias="bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" (re)

Create DHCPv6.Client.{i}. with Alias value with range overflow (65 chars):

  $ R ba-cli "Device.DHCPv6.Client.+ { Alias=$(yes b | tr -d '\n' | head -c 65) }" | grep -Ev '^>|^$'
  ERROR: add Device.DHCPv6.Client. failed (10 - invalid value)

Cleanup - remove only the instance created in this test:

  $ R ba-cli "Device.DHCPv6.Client.$(yes b | tr -d '\n' | head -c 64).-" | grep -Ev '^>|^$'
  Device.DHCPv6.Client.*. (re)
  Device.DHCPv6.Client.*.Server. (re)
  Device.DHCPv6.Client.*.SentOption. (re)
  Device.DHCPv6.Client.*.Retransmission. (re)
  Device.DHCPv6.Client.*.ReceivedOption. (re)
  Device.DHCPv6.Client.*.Stats. (re)
  Device.DHCPv6.Client.*.X_PRPLWARE-COM_Config. (re)
