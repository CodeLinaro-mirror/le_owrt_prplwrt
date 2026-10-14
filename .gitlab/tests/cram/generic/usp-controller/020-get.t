SPDX-FileCopyrightText: Copyright (c) 2026 prpl Foundation

USP Get from the controller to the DUT agent over MQTT. The test reads only
rows that the firmware creates and selects them by Alias or Name, never by
the instance number:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ . "${TESTDIR}/usp-controller.sh"

A full parameter path:

  $ testbed-qemu usp get Device.LocalAgent.EndpointID
  Device.LocalAgent.EndpointID="proto::agent-id"

Two paths in one message:

  $ testbed-qemu usp get Device.LocalAgent.EndpointID 'Device.IP.Interface.[Alias=="lan"].Name'
  Device.IP.Interface.3.Name="br-lan"
  Device.LocalAgent.EndpointID="proto::agent-id"

A partial path returns all parameters below the object:

  $ testbed-qemu usp get 'Device.IP.Interface.[Alias=="lan"].IPv4Address.[Alias=="lan"].'
  Device.IP.Interface.3.IPv4Address.1.AddressingType="Static"
  Device.IP.Interface.3.IPv4Address.1.Alias="lan"
  Device.IP.Interface.3.IPv4Address.1.Enable="true"
  Device.IP.Interface.3.IPv4Address.1.IPAddress="192.168.1.1"
  Device.IP.Interface.3.IPv4Address.1.Status="Enabled"
  Device.IP.Interface.3.IPv4Address.1.SubnetMask="255.255.255.0"

A partial path with a maximum depth of 1 returns the parameters of the object
itself and none of its sub-objects:

  $ testbed-qemu usp get --depth 1 'Device.LocalAgent.MTP.[Alias=="cpe-1"].'
  Device.LocalAgent.MTP.1.Alias="cpe-1"
  Device.LocalAgent.MTP.1.Enable="true"
  Device.LocalAgent.MTP.1.Protocol="STOMP"
  Device.LocalAgent.MTP.1.Status="Down"

A wildcard returns the parameter of every instance:

  $ testbed-qemu usp get 'Device.Security.CABundle.*.Name'
  Device.Security.CABundle.1.Name="default"
  Device.Security.CABundle.2.Name="test"

Search expressions, with one condition and with two:

  $ testbed-qemu usp get 'Device.IP.Interface.[Name=="br-lan"].Alias'
  Device.IP.Interface.3.Alias="lan"
  $ testbed-qemu usp get 'Device.IP.Interface.[Alias=="lan"&&Enable==true].Name'
  Device.IP.Interface.3.Name="br-lan"

A search expression that matches no instance is not an error:

  $ testbed-qemu usp get 'Device.IP.Interface.[Alias=="no-such-interface"].Name'

A reference is followed with "+":

  $ testbed-qemu usp get 'Device.IP.Interface.[Alias=="lan"].LowerLayers' 'Device.IP.Interface.[Alias=="lan"].LowerLayers+.Name'
  Device.Ethernet.Link.4.Name="br-lan"
  Device.IP.Interface.3.LowerLayers="Device.Ethernet.Link.4"

A path that is not in the data model gives error 7026:

  $ testbed-qemu usp get Device.NoSuchObject.
  error: 7026 Device.NoSuchObject.: DM_PRIV_GetNodeFromPath: Path is invalid: Device.NoSuchObject
  [1]
  $ testbed-qemu usp get Device.DeviceInfo.NoSuchParameter
  error: 7026 Device.DeviceInfo.NoSuchParameter: CheckPathProperties: Path (Device.DeviceInfo.NoSuchParameter) does not exist in the schema
  [1]

An instance that does not exist, in an object of the agent itself, gives
error 7026:

  $ testbed-qemu usp get Device.LocalAgent.Subscription.9999.
  error: 7026 Device.LocalAgent.Subscription.9999.: ResolvePartialPath: Invalid instance numbers in path Device.LocalAgent.Subscription.9999
  [1]
