Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

  $ R logger -t cram "Starting ConnectionTrackingQuery attribute config test"

Read the existing Enumerate Network Connection object:

  $ InitialInstance=$(R "ba-cli Device.X_PRPLWARE-COM_ConnectionTrackingQuery.?")

  $ R logger -t cram "Initial Enumerate Network Connection read is: "$InitialInstance

Configure a enumerate network connection query:

  $ DeviceIP=$(echo $CRAM_REMOTE_COMMAND | sed -n 's/.*@\([0-9]\{1,3\}\(\.[0-9]\{1,3\}\)\{3\}\).*/\1/p')

  $ NotifyFlowId=$(R "ba-cli 'Device.X_PRPLWARE-COM_ConnectionTrackingQuery.NotifyFlow+{Name=" \
  > "Cram_attribute_test_1,DestIP=$DeviceIP,SourceIP=0.0.0.0}' | " \
  > "sed '/^$/d' | grep Name | sed -n 's/.*NotifyFlow\.\([0-9]\+\)\..*/\1/p'")

  $ R logger -t cram "Instance Id of Notify flow " \
  > "Device.X_PRPLWARE-COM_ConnectionTrackingQuery.NotifyFlow is "$NotifyFlowId

Attempt to update invalid attributes for the Notify flow:
Try to set invalid DestIP:

  $ R "ba-cli -j -l 'Device.X_PRPLWARE-COM_ConnectionTrackingQuery.NotifyFlow."\
  > "$NotifyFlowId.DestIP="invalid_type"' | sed '/^$/d'"
  ERROR: set Device.X_PRPLWARE-COM_ConnectionTrackingQuery.NotifyFlow.\d+.DestIP failed \(1 - unknown error\) (re)

Try to set invalid SourcePort:

  $ R "ba-cli -j -l 'Device.X_PRPLWARE-COM_ConnectionTrackingQuery.NotifyFlow."\
  > "$NotifyFlowId.SourcePort="hello"' | sed '/^$/d'"
  ERROR: set Device.X_PRPLWARE-COM_ConnectionTrackingQuery.NotifyFlow.\d+.SourcePort failed \(10 - invalid value\) (re)

Try to set invalid DestPort:

  $ R "ba-cli -j -l 'Device.X_PRPLWARE-COM_ConnectionTrackingQuery.NotifyFlow."\
  > "$NotifyFlowId.DestPort="-4567"' | sed '/^$/d'"
  ERROR: set Device.X_PRPLWARE-COM_ConnectionTrackingQuery.NotifyFlow.\d+.DestPort failed \(10 - invalid value\) (re)

Try to set invalid Event:

  $ R "ba-cli -j -l 'Device.X_PRPLWARE-COM_ConnectionTrackingQuery.NotifyFlow."\
  > "$NotifyFlowId.Event="Recreate"' | sed '/^$/d'"
  ERROR: set Device.X_PRPLWARE-COM_ConnectionTrackingQuery.NotifyFlow.\d+.Event failed \(1 - unknown error\) (re)

Try to set invalid Protocol:

  $ R "ba-cli -j -l 'Device.X_PRPLWARE-COM_ConnectionTrackingQuery.NotifyFlow."\
  > "$NotifyFlowId.Protocol="http"' | sed '/^$/d'"
  ERROR: set Device.X_PRPLWARE-COM_ConnectionTrackingQuery.NotifyFlow.\d+.Protocol failed \(1 - unknown error\) (re)

  $ R "ba-cli -j -l 'Device.X_PRPLWARE-COM_ConnectionTrackingQuery.NotifyFlow."\
  > "$NotifyFlowId.Protocol="dns"' | sed '/^$/d'"
  ERROR: set Device.X_PRPLWARE-COM_ConnectionTrackingQuery.NotifyFlow.\d+.Protocol failed \(1 - unknown error\) (re)

  $ R "ba-cli -j -l 'Device.X_PRPLWARE-COM_ConnectionTrackingQuery.NotifyFlow."\
  > "$NotifyFlowId.Protocol="17"' | sed '/^$/d'"
  ERROR: set Device.X_PRPLWARE-COM_ConnectionTrackingQuery.NotifyFlow.\d+.Protocol failed \(10 - invalid value\) (re)

Attempt to create NotifyFlow with invalid parameters:
Try NotifyFlow create with invalid SourceIP:

  $ R "ba-cli -l -j 'Device.X_PRPLWARE-COM_ConnectionTrackingQuery.NotifyFlow+{Name=" \
  > "\"invalid_SourceIP\",DestIP=$DeviceIP,SourceIP=1000.0.0.0,SourcePort=1034}' | " \
  > " sed '/^$/d'"
  ERROR: add Device.X_PRPLWARE-COM_ConnectionTrackingQuery.NotifyFlow failed (1 - unknown error)

Try NotifyFlow create with invalid DestIP:

  $ R "ba-cli -l -j 'Device.X_PRPLWARE-COM_ConnectionTrackingQuery.NotifyFlow+{Name=" \
  > "\"invalid_DestIP\",DestIP="remote.100",DestPort=80,SourceIP=0.0.0.0}' | " \
  > " sed '/^$/d'"
  ERROR: add Device.X_PRPLWARE-COM_ConnectionTrackingQuery.NotifyFlow failed (10 - invalid value)

Try NotifyFlow create with invalid SourcePort:

  $ R "ba-cli -l -j 'Device.X_PRPLWARE-COM_ConnectionTrackingQuery.NotifyFlow+{Name=" \
  > "\"invalid_source_port\",DestIP="remote.100",SourceIP=0.0.0.0,SourcePort="-40312"}' | " \
  > " sed '/^$/d'"
  ERROR: add Device.X_PRPLWARE-COM_ConnectionTrackingQuery.NotifyFlow failed (10 - invalid value)

Try NotifyFlow create with invalid DestPort:

  $ R "ba-cli -l -j 'Device.X_PRPLWARE-COM_ConnectionTrackingQuery.NotifyFlow+{Name=" \
  > "\"invalid_dest_port\",DestIP=$DeviceIP,DestPort=test,SourceIP=0.0.0.0}' | " \
  > " sed '/^$/d'"
  ERROR: add Device.X_PRPLWARE-COM_ConnectionTrackingQuery.NotifyFlow failed (10 - invalid value)

Verify Initial NotifyFlow created:

  $ R "ba-cli --less --json Device.X_PRPLWARE-COM_ConnectionTrackingQuery.?" | jq --sort-keys '.[0]'
  {
    "Device.X_PRPLWARE-COM_ConnectionTrackingQuery.": {
      "MaxNotifyQueries": 16,
      "NotifyFlowNumberOfEntries": 1
    },
    "Device.X_PRPLWARE-COM_ConnectionTrackingQuery.NotifyFlow.\d+.": \{ (re)
      "DestIP": "\d+\.\d+\.\d+\.\d+", (re)
      "DestPort": "",
      "Enable": 1,
      "Event": "",
      "LastChange": .*, (re)
      "Name": "Cram_attribute_test_1",
      "Protocol": "",
      "SourceIP": "0.0.0.0",
      "SourcePort": ""
    }
  }

Clean up, Remove the ConnectionTracking entry created:

  $ R "ba-cli -l -j 'Device.X_PRPLWARE-COM_ConnectionTrackingQuery.NotifyFlow.$NotifyFlowId._del()' " \
  > "| sed '/^$/d' | tail -n 1"
  \[\["Device.X_PRPLWARE-COM_ConnectionTrackingQuery.NotifyFlow.\d+."\]\] (re)

  $ R logger -t cram "ConnectionTrackingQuery attribute config test finished"
