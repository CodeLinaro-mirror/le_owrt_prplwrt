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

Verify two NotifyFlows created:

  $ R "ba-cli --less --json Device.X_PRPLWARE-COM_ConnectionTrackingQuery.?" | jq --sort-keys '.[0]'
  {
    "Device.X_PRPLWARE-COM_ConnectionTrackingQuery.": {
      "MaxNotifyQueries": 16,
      "NotifyFlowNumberOfEntries": 2
    },
    "Device.X_PRPLWARE-COM_ConnectionTrackingQuery.NotifyFlow.\d+.": \{ (re)
      "DestIP": "\d+\.\d+\.\d+\.\d+", (re)
      "DestPort": "",
      "Enable": 1,
      "Event": "",
      "LastChange": .*, (re)
      "Name": "Cram_Track_tcp_1",
      "Protocol": "tcp",
      "SourceIP": "0.0.0.0",
      "SourcePort": ""
    },
    "Device.X_PRPLWARE-COM_ConnectionTrackingQuery.NotifyFlow.\d+.": \{ (re)
      "DestIP": "\d+.\d+.\d+.\d+", (re)
      "DestPort": "",
      "Enable": 1,
      "Event": "",
      "LastChange": .*, (re)
      "Name": "Cram_Track_udp_2",
      "Protocol": "udp",
      "SourceIP": "0.0.0.0",
      "SourcePort": ""
    }
  }

Delete the Udp flow:

  $ R "ba-cli -l -j 'Device.X_PRPLWARE-COM_ConnectionTrackingQuery.NotifyFlow.$NotifyUdpId._del()' " \
  > "| sed '/^$/d' | tail -n 1"
  \[\["Device.X_PRPLWARE-COM_ConnectionTrackingQuery.NotifyFlow.\d+."\]\] (re)

Invoke RetrieveFlows query for reference:

  $ R "ba-cli -l -j 'Device.X_PRPLWARE-COM_ConnectionTrackingQuery.RetrieveFlows()' | sed '/^$/d' | tail -n 1"
  \[{.*}\] (re)

Clean up, Remove the ConnectionTracking entry created:

  $ R "ba-cli -l -j 'Device.X_PRPLWARE-COM_ConnectionTrackingQuery.NotifyFlow.$NotifyTcpId._del()'"\
  > " | sed '/^$/d' | tail -n 1"
  \[\["Device.X_PRPLWARE-COM_ConnectionTrackingQuery.NotifyFlow.\d+."\]\] (re)

  $ R logger -t cram "Enumerate network connection multiple query test finished"