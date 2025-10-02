Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

  $ R logger -t cram "Starting with Enumerate Network Connection multiple query test"

Read the existing Enumerate Network Connection object:

  $ InitialInstance=$(R "ba-cli Device.X_PRPLWARE-COM_ConnectionTrackingQuery.?")

  $ R logger -t cram "Initial Enumerate Network Connection read is: "$InitialInstance

Configure two queries to track tcp and udp flow destined to the device:

  $ DeviceIP=$(echo $CRAM_REMOTE_COMMAND | sed -n 's/.*@\([0-9]\{1,3\}\(\.[0-9]\{1,3\}\)\{3\}\).*/\1/p')

  $ NotifyTcpId=$(R "ba-cli 'Device.X_PRPLWARE-COM_ConnectionTrackingQuery.NotifyFlow+{Name=" \
  > "Cram_Track_tcp_1,Protocol=tcp,DestIP=$DeviceIP,SourceIP=0.0.0.0}' | " \
  > "sed '/^$/d' | grep Name | sed -n 's/.*NotifyFlow\.\([0-9]\+\)\..*/\1/p'")

  $ R logger -t cram "Instance Id of TCP flow " \
  > "Device.X_PRPLWARE-COM_ConnectionTrackingQuery.NotifyFlow is "$NotifyTcpId

  $ NotifyUdpId=$(R "ba-cli 'Device.X_PRPLWARE-COM_ConnectionTrackingQuery.NotifyFlow+" \
  > "{Name=Cram_Track_udp_2,Protocol=udp,DestIP=$DeviceIP,SourceIP=0.0.0.0}'" \
  > " | sed '/^$/d' | grep Name | sed -n 's/.*NotifyFlow\.\([0-9]\+\)\..*/\1/p'")

  $ R logger -t cram "Instance Id of UDP flow "\
  > "Device.X_PRPLWARE-COM_ConnectionTrackingQuery.NotifyFlow is "$NotifyUdpId

Invoke RetrieveFlows query and verify current script execution connection is captured for TCP connection:

  $ R "ba-cli -l -j 'ConnectionTrackingQuery.RetrieveFlows()'" | sed '/^$/d' | tail -n 1 | \
  > grep  -Ec '\"DestIP\":\"$DeviceIP\"|\"DestPort\":\"22\"|\"Protocol\":\"6\"'
  [1-9]+ (re)

  $ R "ba-cli -l -j 'Device.X_PRPLWARE-COM_ConnectionTrackingQuery.RetrieveFlows()' | sed '/^$/d' | tail -n 1"
  \[{.*}\] (re)

Delete the Udp flow:

  $ R "ba-cli -l -j 'Device.X_PRPLWARE-COM_ConnectionTrackingQuery.NotifyFlow.$NotifyUdpId._del()' " \
  > "| sed '/^$/d' | tail -n 1"
  \[\["Device.X_PRPLWARE-COM_ConnectionTrackingQuery.NotifyFlow.\d+."\]\] (re)

Invoke RetrieveFlows query again and verify current script execution connection is captured under TCP connection:

  $ R "ba-cli -l -j 'ConnectionTrackingQuery.RetrieveFlows()'" | sed '/^$/d' | tail -n 1 | \
  > grep  -Ec '\"DestIP\":\"$DeviceIP\"|\"DestPort\":\"22\"|\"Protocol\":\"6\"'
  [1-9]+ (re)

  $ R "ba-cli -l -j 'Device.X_PRPLWARE-COM_ConnectionTrackingQuery.RetrieveFlows()' | sed '/^$/d' | tail -n 1"
  \[{.*}\] (re)

Clean up, Remove the ConnectionTracking Entry created:

  $ R "ba-cli -l -j 'Device.X_PRPLWARE-COM_ConnectionTrackingQuery.NotifyFlow.$NotifyTcpId._del()'"\
  > " | sed '/^$/d' | tail -n 1"
  \[\["Device.X_PRPLWARE-COM_ConnectionTrackingQuery.NotifyFlow.\d+."\]\] (re)

  $ R logger -t cram "Enumerate network connection multiple query test finished"