Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

  $ R logger -t cram "Starting with Enumerate network connection test"

Read the existing Enumerate Network Connection object:

  $ InitialInstance=$(R "ba-cli  Device.X_PRPLWARE-COM_ConnectionTrackingQuery.?")

  $ R logger -t cram "Initial Enumerate Network Connection read is: "$InitialInstance

Configure a query to track tcp flow destined to the device:

  $ DeviceIP=$(echo $CRAM_REMOTE_COMMAND | sed -n 's/.*@\([0-9]\{1,3\}\(\.[0-9]\{1,3\}\)\{3\}\).*/\1/p')

  $ NotifyInstanceId=$(R "ba-cli 'Device.X_PRPLWARE-COM_ConnectionTrackingQuery.NotifyFlow+" \
  > "{Name=Cram_Track_1,Protocol=tcp,DestIP=$DeviceIP,SourceIP=0.0.0.0}' | " \
  > "sed '/^$/d' | grep Name | sed -n 's/.*NotifyFlow\.\([0-9]\+\)\..*/\1/p'")

  $ R logger -t cram "Instance Id of Device.X_PRPLWARE-COM_ConnectionTrackingQuery.NotifyFlow is "$NotifyInstanceId

Invoke instant RetrieveFlows query and verify current script execution connection is captured:

  $ R "ba-cli -l -j 'ConnectionTrackingQuery.RetrieveFlows()'" | sed '/^$/d' | tail -n 1 | \
  > grep  -Ec '\"DestIP\":\"$DeviceIP\"|\"DestPort\":\"22\"|\"Protocol\":\"6\"'
  [1-9]+ (re)

  $ R "ba-cli -l -j 'Device.X_PRPLWARE-COM_ConnectionTrackingQuery.RetrieveFlows()' | sed '/^$/d' | tail -n 1"
  \[{.*}\] (re)

Clean up, Remove the ConnectionTracking entry created:

  $ R "ba-cli -l -j 'Device.X_PRPLWARE-COM_ConnectionTrackingQuery.NotifyFlow.$NotifyInstanceId._del()' " \
  > "| sed '/^$/d' | tail -n 1"
  \[\["Device.X_PRPLWARE-COM_ConnectionTrackingQuery.NotifyFlow.\d+."\]\] (re)

  $ R logger -t cram "Enumerate network connection test-1 finished"