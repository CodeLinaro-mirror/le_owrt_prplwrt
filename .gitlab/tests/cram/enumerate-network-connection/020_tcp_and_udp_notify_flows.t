Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

  $ R logger -t cram "Starting with Enumerate Network Connection test 1"

Read the existing Enumerate Network Connection object
  $ InitialInstance=$(R "ba-cli  ConnectionTracking.?")

  $ R logger -t cram 'Initial Enumerate Network Connection read is: $InitialInstance'

Configure two queries to track tcp and udp flow destined to the device.
  $ DeviceIP=$(echo $CRAM_REMOTE_COMMAND | sed -n 's/.*@\([0-9]\{1,3\}\(\.[0-9]\{1,3\}\)\{3\}\).*/\1/p')
  $ NotifyTcpId=$(R "ba-cli 'ConnectionTracking.NotifyFlow+{Name=Cram_Track_tcp_1,Protocol=tcp,DestIP=$DeviceIP,SourceIP=0.0.0.0}' | sed '/^$/d' | grep Name | sed -n 's/.*NotifyFlow\.\([0-9]\+\)\..*/\1/p'")
  $ R logger -t cram "Instance Id of TCP flow ConnectionTracking.NotifyFlow is $NotifyTcpId"

  $ NotifyUdpId=$(R "ba-cli 'ConnectionTracking.NotifyFlow+{Name=Cram_Track_udp_2,Protocol=udp,DestIP=$DeviceIP,SourceIP=0.0.0.0}' | sed '/^$/d' | grep Name | sed -n 's/.*NotifyFlow\.\([0-9]\+\)\..*/\1/p'")
  $ R logger -t cram "Instance Id of UDP flow ConnectionTracking.NotifyFlow is $NotifyUdpId"

Invoke RetrieveFlows query and verify current script execution connection is captured for TCP connection
  $ R "ba-cli 'ConnectionTracking.RetrieveFlows()' |  grep -Ec '\"dst\": \"192.168.122.100\"|\"dport\": \"22\"| \"proto\": \"6\"'"
  [1-9]\d* (re)

Delete the Udp flow
  $ R "ba-cli -l -j 'ConnectionTracking.NotifyFlow.$NotifyUdpId._del()' | sed '/^$/d' | grep -c "ConnectionTracking.NotifyFlow.$NotifyUdpId.""
  2

Configure RetrieveFlows query again and verify current script execution connection is captured under TCP connection
  $ R "ba-cli 'ConnectionTracking.RetrieveFlows()' |  grep -Ec '\"dst\": \"192.168.122.100\"|\"dport\": \"22\"| \"proto\": \"6\"'"
  [1-9]\d* (re)

Clean up, Remove the ConnectionTracking Entry created
  $ R "ba-cli -l -j 'ConnectionTracking.NotifyFlow.$NotifyTcpId._del()' | sed '/^$/d' | grep -c "ConnectionTracking.NotifyFlow.$NotifyTcpIdId.""
  2

  $ R logger -t cram "Tests finished!"

