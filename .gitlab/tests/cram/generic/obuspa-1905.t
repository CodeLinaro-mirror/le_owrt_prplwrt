Set up the remote command:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Work around prplMesh not reconnecting to obuspa after an obuspa restart. This
test must run before obuspa-cellular.t and obuspa.t. Once prplMesh reconnect is
fixed, remove this test and add IEEE1905 to fixtures/obuspa.expected:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

  $ R obuspa -f /etc/obuspa.db -c dump datamodel | grep Device.IEEE1905
  Device.IEEE1905.                                                                                     proto::prplmesh-controller
  Device.IEEE1905.Network.                                                                             proto::prplmesh-controller
  Device.IEEE1905.Network.AL.{i}.                                                                      proto::prplmesh-controller
  Device.IEEE1905.Network.AL.{i}.AssocWiFiNetworkDeviceRef                                             proto::prplmesh-controller
  Device.IEEE1905.Network.AL.{i}.BridgingTuple.{i}.                                                    proto::prplmesh-controller
  Device.IEEE1905.Network.AL.{i}.BridgingTuple.{i}.InterfaceList                                       proto::prplmesh-controller
  Device.IEEE1905.Network.AL.{i}.BridgingTupleNumberOfEntries                                          proto::prplmesh-controller
  Device.IEEE1905.Network.AL.{i}.ControlURL                                                            proto::prplmesh-controller
  Device.IEEE1905.Network.AL.{i}.FriendlyName                                                          proto::prplmesh-controller
  Device.IEEE1905.Network.AL.{i}.IEEE1905Id                                                            proto::prplmesh-controller
  Device.IEEE1905.Network.AL.{i}.IPv4Address.{i}.                                                      proto::prplmesh-controller
  Device.IEEE1905.Network.AL.{i}.IPv4Address.{i}.DHCPServer                                            proto::prplmesh-controller
  Device.IEEE1905.Network.AL.{i}.IPv4Address.{i}.IPv4Address                                           proto::prplmesh-controller
  Device.IEEE1905.Network.AL.{i}.IPv4Address.{i}.IPv4AddressType                                       proto::prplmesh-controller
  Device.IEEE1905.Network.AL.{i}.IPv4Address.{i}.MACAddress                                            proto::prplmesh-controller
  Device.IEEE1905.Network.AL.{i}.IPv4AddressNumberOfEntries                                            proto::prplmesh-controller
  Device.IEEE1905.Network.AL.{i}.IPv6Address.{i}.                                                      proto::prplmesh-controller
  Device.IEEE1905.Network.AL.{i}.IPv6Address.{i}.IPv6Address                                           proto::prplmesh-controller
  Device.IEEE1905.Network.AL.{i}.IPv6Address.{i}.IPv6AddressOrigin                                     proto::prplmesh-controller
  Device.IEEE1905.Network.AL.{i}.IPv6Address.{i}.IPv6AddressType                                       proto::prplmesh-controller
  Device.IEEE1905.Network.AL.{i}.IPv6Address.{i}.MACAddress                                            proto::prplmesh-controller
  Device.IEEE1905.Network.AL.{i}.IPv6AddressNumberOfEntries                                            proto::prplmesh-controller
  Device.IEEE1905.Network.AL.{i}.Interface.{i}.                                                        proto::prplmesh-controller
  Device.IEEE1905.Network.AL.{i}.Interface.{i}.APChannelBand                                           proto::prplmesh-controller
  Device.IEEE1905.Network.AL.{i}.Interface.{i}.FrequencyIndex1                                         proto::prplmesh-controller
  Device.IEEE1905.Network.AL.{i}.Interface.{i}.FrequencyIndex2                                         proto::prplmesh-controller
  Device.IEEE1905.Network.AL.{i}.Interface.{i}.GenericPhy.                                             proto::prplmesh-controller
  Device.IEEE1905.Network.AL.{i}.Interface.{i}.GenericPhy.OUI                                          proto::prplmesh-controller
  Device.IEEE1905.Network.AL.{i}.Interface.{i}.GenericPhy.URL                                          proto::prplmesh-controller
  Device.IEEE1905.Network.AL.{i}.Interface.{i}.GenericPhy.Variant                                      proto::prplmesh-controller
  Device.IEEE1905.Network.AL.{i}.Interface.{i}.IEEE1905Neighbor.{i}.                                   proto::prplmesh-controller
  Device.IEEE1905.Network.AL.{i}.Interface.{i}.IEEE1905Neighbor.{i}.IEEE1905DeviceRef                  proto::prplmesh-controller
  Device.IEEE1905.Network.AL.{i}.Interface.{i}.IEEE1905Neighbor.{i}.IEEE802dot1Bridge                  proto::prplmesh-controller
  Device.IEEE1905.Network.AL.{i}.Interface.{i}.IEEE1905Neighbor.{i}.NeighborDeviceId                   proto::prplmesh-controller
  Device.IEEE1905.Network.AL.{i}.Interface.{i}.IEEE1905NeighborNumberOfEntries                         proto::prplmesh-controller
  Device.IEEE1905.Network.AL.{i}.Interface.{i}.InterfaceId                                             proto::prplmesh-controller
  Device.IEEE1905.Network.AL.{i}.Interface.{i}.L2Neighbor.{i}.                                         proto::prplmesh-controller
  Device.IEEE1905.Network.AL.{i}.Interface.{i}.L2Neighbor.{i}.BehindInterfaceIds                       proto::prplmesh-controller
  Device.IEEE1905.Network.AL.{i}.Interface.{i}.L2Neighbor.{i}.NeighborInterfaceId                      proto::prplmesh-controller
  Device.IEEE1905.Network.AL.{i}.Interface.{i}.L2NeighborNumberOfEntries                               proto::prplmesh-controller
  Device.IEEE1905.Network.AL.{i}.Interface.{i}.Link.{i}.                                               proto::prplmesh-controller
  Device.IEEE1905.Network.AL.{i}.Interface.{i}.Link.{i}.GenericPhy.                                    proto::prplmesh-controller
  Device.IEEE1905.Network.AL.{i}.Interface.{i}.Link.{i}.GenericPhy.OUI                                 proto::prplmesh-controller
  Device.IEEE1905.Network.AL.{i}.Interface.{i}.Link.{i}.GenericPhy.URL                                 proto::prplmesh-controller
  Device.IEEE1905.Network.AL.{i}.Interface.{i}.Link.{i}.GenericPhy.Variant                             proto::prplmesh-controller
  Device.IEEE1905.Network.AL.{i}.Interface.{i}.Link.{i}.IEEE1905Id                                     proto::prplmesh-controller
  Device.IEEE1905.Network.AL.{i}.Interface.{i}.Link.{i}.InterfaceId                                    proto::prplmesh-controller
  Device.IEEE1905.Network.AL.{i}.Interface.{i}.Link.{i}.MediaType                                      proto::prplmesh-controller
  Device.IEEE1905.Network.AL.{i}.Interface.{i}.Link.{i}.Metric.                                        proto::prplmesh-controller
  Device.IEEE1905.Network.AL.{i}.Interface.{i}.Link.{i}.Metric.IEEE802dot1Bridge                       proto::prplmesh-controller
  Device.IEEE1905.Network.AL.{i}.Interface.{i}.Link.{i}.Metric.LinkAvailability                        proto::prplmesh-controller
  Device.IEEE1905.Network.AL.{i}.Interface.{i}.Link.{i}.Metric.MACThroughputCapacity                   proto::prplmesh-controller
  Device.IEEE1905.Network.AL.{i}.Interface.{i}.Link.{i}.Metric.PHYRate                                 proto::prplmesh-controller
  Device.IEEE1905.Network.AL.{i}.Interface.{i}.Link.{i}.Metric.PacketErrors                            proto::prplmesh-controller
  Device.IEEE1905.Network.AL.{i}.Interface.{i}.Link.{i}.Metric.PacketErrorsReceived                    proto::prplmesh-controller
  Device.IEEE1905.Network.AL.{i}.Interface.{i}.Link.{i}.Metric.PacketsReceived                         proto::prplmesh-controller
  Device.IEEE1905.Network.AL.{i}.Interface.{i}.Link.{i}.Metric.RSSI                                    proto::prplmesh-controller
  Device.IEEE1905.Network.AL.{i}.Interface.{i}.Link.{i}.Metric.TransmittedPackets                      proto::prplmesh-controller
  Device.IEEE1905.Network.AL.{i}.Interface.{i}.LinkNumberOfEntries                                     proto::prplmesh-controller
  Device.IEEE1905.Network.AL.{i}.Interface.{i}.MediaType                                               proto::prplmesh-controller
  Device.IEEE1905.Network.AL.{i}.Interface.{i}.NetworkMembership                                       proto::prplmesh-controller
  Device.IEEE1905.Network.AL.{i}.Interface.{i}.NonIEEE1905Neighbor.{i}.                                proto::prplmesh-controller
  Device.IEEE1905.Network.AL.{i}.Interface.{i}.NonIEEE1905Neighbor.{i}.NeighborInterfaceId             proto::prplmesh-controller
  Device.IEEE1905.Network.AL.{i}.Interface.{i}.NonIEEE1905NeighborNumberOfEntries                      proto::prplmesh-controller
  Device.IEEE1905.Network.AL.{i}.Interface.{i}.PowerState                                              proto::prplmesh-controller
  Device.IEEE1905.Network.AL.{i}.Interface.{i}.Role                                                    proto::prplmesh-controller
  Device.IEEE1905.Network.AL.{i}.InterfaceNumberOfEntries                                              proto::prplmesh-controller
  Device.IEEE1905.Network.AL.{i}.ManufacturerModel                                                     proto::prplmesh-controller
  Device.IEEE1905.Network.AL.{i}.ManufacturerName                                                      proto::prplmesh-controller
  Device.IEEE1905.Network.AL.{i}.RegistrarFreqBand                                                     proto::prplmesh-controller
  Device.IEEE1905.Network.AL.{i}.Version                                                               proto::prplmesh-controller
  Device.IEEE1905.Network.ALNumberOfEntries                                                            proto::prplmesh-controller
  Device.IEEE1905.Network.Enable                                                                       proto::prplmesh-controller
  Device.IEEE1905.Network.Status                                                                       proto::prplmesh-controller
