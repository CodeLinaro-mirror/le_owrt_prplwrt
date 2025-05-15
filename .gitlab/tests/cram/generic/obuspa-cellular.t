Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

If test is running on a Mozart, Turris, OSPv1 or Haze, lets skip the test as there is no Cellular support:
  $ if echo "$CI_JOB_NAME" | grep -q -E "(Mozart|Turris|Haze|HDK-3)"; then exit 80; fi

Check that obuspa has expected datamodel available for cellular:

  $ R "obuspa -f /etc/obuspa.db -c dump datamodel | grep '^Device.Cellular.'"
  Device.Cellular.                                                                                     proto::cellular-manager
  Device.Cellular.AccessPoint.{i}.                                                                     proto::cellular-manager
  Device.Cellular.AccessPoint.{i}.APN                                                                  proto::cellular-manager
  Device.Cellular.AccessPoint.{i}.Alias                                                                proto::cellular-manager
  Device.Cellular.AccessPoint.{i}.Enable                                                               proto::cellular-manager
  Device.Cellular.AccessPoint.{i}.Interface                                                            proto::cellular-manager
  Device.Cellular.AccessPoint.{i}.Password                                                             proto::cellular-manager
  Device.Cellular.AccessPoint.{i}.Proxy                                                                proto::cellular-manager
  Device.Cellular.AccessPoint.{i}.ProxyPort                                                            proto::cellular-manager
  Device.Cellular.AccessPoint.{i}.Username                                                             proto::cellular-manager
  Device.Cellular.AccessPoint.{i}.X_PRPLWARE-COM_IPType                                                proto::cellular-manager
  Device.Cellular.AccessPointNumberOfEntries                                                           proto::cellular-manager
  Device.Cellular.Interface.{i}.                                                                       proto::cellular-manager
  Device.Cellular.Interface.{i}.Alias                                                                  proto::cellular-manager
  Device.Cellular.Interface.{i}.AvailableNetworks                                                      proto::cellular-manager
  Device.Cellular.Interface.{i}.CurrentAccessTechnology                                                proto::cellular-manager
  Device.Cellular.Interface.{i}.DownstreamMaxBitRate                                                   proto::cellular-manager
  Device.Cellular.Interface.{i}.Enable                                                                 proto::cellular-manager
  Device.Cellular.Interface.{i}.IMEI                                                                   proto::cellular-manager
  Device.Cellular.Interface.{i}.LastChange                                                             proto::cellular-manager
  Device.Cellular.Interface.{i}.LowerLayers                                                            proto::cellular-manager
  Device.Cellular.Interface.{i}.Name                                                                   proto::cellular-manager
  Device.Cellular.Interface.{i}.NetworkInUse                                                           proto::cellular-manager
  Device.Cellular.Interface.{i}.NetworkRequested                                                       proto::cellular-manager
  Device.Cellular.Interface.{i}.PreferredAccessTechnology                                              proto::cellular-manager
  Device.Cellular.Interface.{i}.RSRP                                                                   proto::cellular-manager
  Device.Cellular.Interface.{i}.RSRQ                                                                   proto::cellular-manager
  Device.Cellular.Interface.{i}.RSSI                                                                   proto::cellular-manager
  Device.Cellular.Interface.{i}.Stats.                                                                 proto::cellular-manager
  Device.Cellular.Interface.{i}.Stats.BroadcastPacketsReceived                                         proto::cellular-manager
  Device.Cellular.Interface.{i}.Stats.BroadcastPacketsSent                                             proto::cellular-manager
  Device.Cellular.Interface.{i}.Stats.BytesReceived                                                    proto::cellular-manager
  Device.Cellular.Interface.{i}.Stats.BytesSent                                                        proto::cellular-manager
  Device.Cellular.Interface.{i}.Stats.DiscardPacketsReceived                                           proto::cellular-manager
  Device.Cellular.Interface.{i}.Stats.DiscardPacketsSent                                               proto::cellular-manager
  Device.Cellular.Interface.{i}.Stats.ErrorsReceived                                                   proto::cellular-manager
  Device.Cellular.Interface.{i}.Stats.ErrorsSent                                                       proto::cellular-manager
  Device.Cellular.Interface.{i}.Stats.MulticastPacketsReceived                                         proto::cellular-manager
  Device.Cellular.Interface.{i}.Stats.MulticastPacketsSent                                             proto::cellular-manager
  Device.Cellular.Interface.{i}.Stats.PacketsReceived                                                  proto::cellular-manager
  Device.Cellular.Interface.{i}.Stats.PacketsSent                                                      proto::cellular-manager
  Device.Cellular.Interface.{i}.Stats.UnicastPacketsReceived                                           proto::cellular-manager
  Device.Cellular.Interface.{i}.Stats.UnicastPacketsSent                                               proto::cellular-manager
  Device.Cellular.Interface.{i}.Stats.UnknownProtoPacketsReceived                                      proto::cellular-manager
  Device.Cellular.Interface.{i}.Status                                                                 proto::cellular-manager
  Device.Cellular.Interface.{i}.SupportedAccessTechnologies                                            proto::cellular-manager
  Device.Cellular.Interface.{i}.USIM.                                                                  proto::cellular-manager
  Device.Cellular.Interface.{i}.USIM.ICCID                                                             proto::cellular-manager
  Device.Cellular.Interface.{i}.USIM.IMSI                                                              proto::cellular-manager
  Device.Cellular.Interface.{i}.USIM.MSISDN                                                            proto::cellular-manager
  Device.Cellular.Interface.{i}.USIM.PIN                                                               proto::cellular-manager
  Device.Cellular.Interface.{i}.USIM.PINCheck                                                          proto::cellular-manager
  Device.Cellular.Interface.{i}.USIM.Status                                                            proto::cellular-manager
  Device.Cellular.Interface.{i}.Upstream                                                               proto::cellular-manager
  Device.Cellular.Interface.{i}.UpstreamMaxBitRate                                                     proto::cellular-manager
  Device.Cellular.Interface.{i}.X_PRPLWARE-COM_SignalQualityPollingRate                                proto::cellular-manager
  Device.Cellular.InterfaceNumberOfEntries                                                             proto::cellular-manager
  Device.Cellular.RoamingEnabled                                                                       proto::cellular-manager
  Device.Cellular.RoamingStatus                                                                        proto::cellular-manager

Check that USP stack is handling the reconnection scenario properly PCF-1198/PPW-65 by restarting obuspa:

  $ R "service obuspa restart" ; sleep 20

Check that obuspa provides the same datamodel for cellular again:

  $ R "obuspa -f /etc/obuspa.db -c dump datamodel | grep '^Device.Cellular.'"
  Device.Cellular.                                                                                     proto::cellular-manager
  Device.Cellular.AccessPoint.{i}.                                                                     proto::cellular-manager
  Device.Cellular.AccessPoint.{i}.APN                                                                  proto::cellular-manager
  Device.Cellular.AccessPoint.{i}.Alias                                                                proto::cellular-manager
  Device.Cellular.AccessPoint.{i}.Enable                                                               proto::cellular-manager
  Device.Cellular.AccessPoint.{i}.Interface                                                            proto::cellular-manager
  Device.Cellular.AccessPoint.{i}.Password                                                             proto::cellular-manager
  Device.Cellular.AccessPoint.{i}.Proxy                                                                proto::cellular-manager
  Device.Cellular.AccessPoint.{i}.ProxyPort                                                            proto::cellular-manager
  Device.Cellular.AccessPoint.{i}.Username                                                             proto::cellular-manager
  Device.Cellular.AccessPoint.{i}.X_PRPLWARE-COM_IPType                                                proto::cellular-manager
  Device.Cellular.AccessPointNumberOfEntries                                                           proto::cellular-manager
  Device.Cellular.Interface.{i}.                                                                       proto::cellular-manager
  Device.Cellular.Interface.{i}.Alias                                                                  proto::cellular-manager
  Device.Cellular.Interface.{i}.AvailableNetworks                                                      proto::cellular-manager
  Device.Cellular.Interface.{i}.CurrentAccessTechnology                                                proto::cellular-manager
  Device.Cellular.Interface.{i}.DownstreamMaxBitRate                                                   proto::cellular-manager
  Device.Cellular.Interface.{i}.Enable                                                                 proto::cellular-manager
  Device.Cellular.Interface.{i}.IMEI                                                                   proto::cellular-manager
  Device.Cellular.Interface.{i}.LastChange                                                             proto::cellular-manager
  Device.Cellular.Interface.{i}.LowerLayers                                                            proto::cellular-manager
  Device.Cellular.Interface.{i}.Name                                                                   proto::cellular-manager
  Device.Cellular.Interface.{i}.NetworkInUse                                                           proto::cellular-manager
  Device.Cellular.Interface.{i}.NetworkRequested                                                       proto::cellular-manager
  Device.Cellular.Interface.{i}.PreferredAccessTechnology                                              proto::cellular-manager
  Device.Cellular.Interface.{i}.RSRP                                                                   proto::cellular-manager
  Device.Cellular.Interface.{i}.RSRQ                                                                   proto::cellular-manager
  Device.Cellular.Interface.{i}.RSSI                                                                   proto::cellular-manager
  Device.Cellular.Interface.{i}.Stats.                                                                 proto::cellular-manager
  Device.Cellular.Interface.{i}.Stats.BroadcastPacketsReceived                                         proto::cellular-manager
  Device.Cellular.Interface.{i}.Stats.BroadcastPacketsSent                                             proto::cellular-manager
  Device.Cellular.Interface.{i}.Stats.BytesReceived                                                    proto::cellular-manager
  Device.Cellular.Interface.{i}.Stats.BytesSent                                                        proto::cellular-manager
  Device.Cellular.Interface.{i}.Stats.DiscardPacketsReceived                                           proto::cellular-manager
  Device.Cellular.Interface.{i}.Stats.DiscardPacketsSent                                               proto::cellular-manager
  Device.Cellular.Interface.{i}.Stats.ErrorsReceived                                                   proto::cellular-manager
  Device.Cellular.Interface.{i}.Stats.ErrorsSent                                                       proto::cellular-manager
  Device.Cellular.Interface.{i}.Stats.MulticastPacketsReceived                                         proto::cellular-manager
  Device.Cellular.Interface.{i}.Stats.MulticastPacketsSent                                             proto::cellular-manager
  Device.Cellular.Interface.{i}.Stats.PacketsReceived                                                  proto::cellular-manager
  Device.Cellular.Interface.{i}.Stats.PacketsSent                                                      proto::cellular-manager
  Device.Cellular.Interface.{i}.Stats.UnicastPacketsReceived                                           proto::cellular-manager
  Device.Cellular.Interface.{i}.Stats.UnicastPacketsSent                                               proto::cellular-manager
  Device.Cellular.Interface.{i}.Stats.UnknownProtoPacketsReceived                                      proto::cellular-manager
  Device.Cellular.Interface.{i}.Status                                                                 proto::cellular-manager
  Device.Cellular.Interface.{i}.SupportedAccessTechnologies                                            proto::cellular-manager
  Device.Cellular.Interface.{i}.USIM.                                                                  proto::cellular-manager
  Device.Cellular.Interface.{i}.USIM.ICCID                                                             proto::cellular-manager
  Device.Cellular.Interface.{i}.USIM.IMSI                                                              proto::cellular-manager
  Device.Cellular.Interface.{i}.USIM.MSISDN                                                            proto::cellular-manager
  Device.Cellular.Interface.{i}.USIM.PIN                                                               proto::cellular-manager
  Device.Cellular.Interface.{i}.USIM.PINCheck                                                          proto::cellular-manager
  Device.Cellular.Interface.{i}.USIM.Status                                                            proto::cellular-manager
  Device.Cellular.Interface.{i}.Upstream                                                               proto::cellular-manager
  Device.Cellular.Interface.{i}.UpstreamMaxBitRate                                                     proto::cellular-manager
  Device.Cellular.Interface.{i}.X_PRPLWARE-COM_SignalQualityPollingRate                                proto::cellular-manager
  Device.Cellular.InterfaceNumberOfEntries                                                             proto::cellular-manager
  Device.Cellular.RoamingEnabled                                                                       proto::cellular-manager
  Device.Cellular.RoamingStatus                                                                        proto::cellular-manager
