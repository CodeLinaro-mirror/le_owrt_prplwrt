Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"


Set unexistent interface:

  $ R "ba-cli Device.DHCPv6.Client.1.Interface=Device.IP.Interface.99" | grep -v '^>'
  ERROR: set Device.DHCPv6.Client.1.Interface failed (21 - invalid path)
  

Create a client with duplicate interface:

  $ R "ba-cli Device.DHCPv6.Client.+{Alias=Test1,Interface=Device.IP.Interface.2}" | grep -v '^>'
  ERROR: add Device.DHCPv6.Client. failed (13 - duplicate)

Create a client with existing non-duplicate interface:

  $ R "ba-cli Device.DHCPv6.Client.+{Alias=Test2,Interface=Device.IP.Interface.3}" | grep -v '^>'
  Device.DHCPv6.Client.2.
  Device.DHCPv6.Client.2.Alias="Test2"

Remove a test client:

  $ R "ba-cli Device.DHCPv6.Client.Test2.-" | grep -v '^>'
  Device.DHCPv6.Client.2.
  Device.DHCPv6.Client.2.Server.
  Device.DHCPv6.Client.2.SentOption.
  Device.DHCPv6.Client.2.Retransmission.
  Device.DHCPv6.Client.2.ReceivedOption.
  Device.DHCPv6.Client.2.Stats.
  Device.DHCPv6.Client.2.X_PRPLWARE-COM_Config.
