Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

  $ R logger -t cram "Starting Memory Monitoring tests"

Read Memory Monitoring object attributes:

  $ MemoryMonitor=$(R "ba-cli -j -l Device.DeviceInfo.MemoryStatus.MemoryMonitor.?")

  $ R logger -t cram "Memory Monitoring object attributes: "$MemoryMonitor

Enable Memory Monitoring with 3 seconds polling interval:

  $ R "ba-cli -l -j Device.DeviceInfo.MemoryStatus.MemoryMonitor.Enable=1 | sed '/^$/d'"
  [{"Device.DeviceInfo.MemoryStatus.MemoryMonitor.":{"Enable":1}}]

  $ R "ba-cli -l -j Device.DeviceInfo.MemoryStatus.MemoryMonitor.PollingInterval=3 | sed '/^$/d'"
  [{"Device.DeviceInfo.MemoryStatus.MemoryMonitor.":{"PollingInterval":3}}]

Sleep for polling interval of 3 seconds (+1 second):

  $ sleep 4

Read Memory utilization values, Verify Memory Monitoring Enabled and Memory utilization is normal:

  $ R "ba-cli -l -j Device.DeviceInfo.MemoryStatus.MemoryMonitor.? | sed '/^$/d'" \
  > "| jsonfilter -e @[0]'[\"Device.DeviceInfo.MemoryStatus.MemoryMonitor.\"].Enable' -e" \
  > "@[0]'[\"Device.DeviceInfo.MemoryStatus.MemoryMonitor.\"].CriticalRiseTimeStamp' -e" \
  > "@[0]'[\"Device.DeviceInfo.MemoryStatus.MemoryMonitor.\"].CriticalFallTimeStamp'"
  1
  0001-01-01T00:00:00Z
  0001-01-01T00:00:00Z

Verify Memory utilization reported is not abnormal:

  $ MemoryUtilized=$(R "ba-cli -j -l Device.DeviceInfo.MemoryStatus.MemoryMonitor.? " \
  > "| sed '/^$/d' | " \
  > "jsonfilter -e @[0]'[\"Device.DeviceInfo.MemoryStatus.MemoryMonitor.\"].MemUtilization'")

  $ R logger -t cram "Memory Utilization read after enabling: $MemoryUtilized"

  $ if [ $MemoryUtilized  -gt 0 -a $MemoryUtilized -lt 70 ]; then echo "PASS";
  > else echo "FAIL - Memory Utilization: $MemoryUtilized"; fi
  PASS

Update Polling Interval for Memory monitoring:

  $ R "ba-cli -l -j Device.DeviceInfo.MemoryStatus.MemoryMonitor.PollingInterval=6 | sed '/^$/d'"
  [{"Device.DeviceInfo.MemoryStatus.MemoryMonitor.":{"PollingInterval":6}}]

Sleep for configured polling interval of 6 seconds (+2 second):

  $ sleep 8

Read Memory utilization values, Verify Memory utilization is not abnormal:

  $ MemoryUtilizedUpdate=$(R "ba-cli -j -l Device.DeviceInfo.MemoryStatus.MemoryMonitor.? " \
  > "| sed '/^$/d' | " \
  > "jsonfilter -e @[0]'[\"Device.DeviceInfo.MemoryStatus.MemoryMonitor.\"].MemUtilization'")

  $ R logger -t cram "Memory Utilization read after changing polling interval with " \
  > "6 seconds: $MemoryUtilizedUpdate"

  $ if [ $MemoryUtilized  -gt 0 -a $MemoryUtilized -lt 70 ]; then echo "PASS"; \
  > else echo "FAIL - Memory Utilization: $MemoryUtilized"; fi
  PASS

Disable Memory Monitoring:

  $ R "ba-cli -l -j Device.DeviceInfo.MemoryStatus.MemoryMonitor.Enable=0 | sed '/^$/d'"
  [{"Device.DeviceInfo.MemoryStatus.MemoryMonitor.":{"Enable":0}}]

Verify Memory Monitoring stopped after disable:

  $ R "ba-cli -l -j Device.DeviceInfo.MemoryStatus.MemoryMonitor.? | sed '/^$/d' |" \
  > "jsonfilter -e @[0]'[\"Device.DeviceInfo.MemoryStatus.MemoryMonitor.\"].Enable'" \
  > "-e @[0]'[\"Device.DeviceInfo.MemoryStatus.MemoryMonitor.\"].CriticalRiseTimeStamp'" \
  > "-e @[0]'[\"Device.DeviceInfo.MemoryStatus.MemoryMonitor.\"].CriticalFallTimeStamp'"
  0
  0001-01-01T00:00:00Z
  0001-01-01T00:00:00Z

  $ R logger -t cram "Memory Monitoring test finished"