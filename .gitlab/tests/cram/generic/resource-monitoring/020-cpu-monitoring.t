Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

This Helper method takes attributes in order Param#1 CPU-Core-Id Param#2 0 - Disable, 1 - Enable:

  $ set_cpu_monitoring() \
  > { R "ba-cli -l -j Device.DeviceInfo.ProcessStatus.CPU.$1.Enable=$2 | sed '/^$/d'";}

This Helper method takes attributes in order Param#1 CPU-Core-Id:

  $ get_cpu_monitoring_values() \
  > {  R "ba-cli -l -j Device.DeviceInfo.ProcessStatus.CPU.$1.? | sed '/^$/d'" \
  > "| jsonfilter -e @[0]'[\"Device.DeviceInfo.ProcessStatus.CPU.$1.\"].Enable' " \
  > "-e @[0]'[\"Device.DeviceInfo.ProcessStatus.CPU.$1.\"].PollInterval' " \
  > "-e @[0]'[\"Device.DeviceInfo.ProcessStatus.CPU.$1.\"].NumSamples' " \
  > "-e @[0]'[\"Device.DeviceInfo.ProcessStatus.CPU.$1.\"].CriticalRiseTimeStamp' " \
  > "-e @[0]'[\"Device.DeviceInfo.ProcessStatus.CPU.$1.\"].CriticalFallTimeStamp'";}

This Helper method takes attributes in order Param#1 - CPU-Core-Id Param#2 - SystemModeUtilization \
or UserModeUtilization or IdleModeUtilization Param#3 - Higher end utilization limit for the CPU mode:

  $ verify_cpu_mode_utilization() \
  > { CpuModeUtilization=$(R "ba-cli -l -j Device.DeviceInfo.ProcessStatus.CPU.$1.? " \
  > "| sed '/^$/d' | jsonfilter -e @[0]'[\"Device.DeviceInfo.ProcessStatus.CPU.$1.\"].$2'"); \
  > R logger -t cram $2" read: "$CpuModeUtilization; \
  > if [ $CpuModeUtilization -le $3 ]; then echo $2": PASS"; \
  > else echo "FAIL - "$2": "$CpuModeUtilization; fi;}

This Helper method takes attributes in order Param#1-CPU-Core-Id Param#2-SystemModeUtilization \
or UserModeUtilization or IdleModeUtilization:

  $ verify_disable_cpu_utilization() \
  > { CpuModeUtilization=$(R "ba-cli -l -j Device.DeviceInfo.ProcessStatus.CPU.$1.? " \
  > "| sed '/^$/d' | jsonfilter -e @[0]'[\"Device.DeviceInfo.ProcessStatus.CPU.$1.\"].$2'");\
  > R logger -t cram $2" read: "$CpuModeUtilization; if [ $CpuModeUtilization  -eq 0 ]; \
  > then echo $2": PASS"; else echo "FAIL - "$2": "$CpuModeUtilization" after disabling CPU Monitoring"; fi;}

  $ R logger -t cram "Starting CPU Monitoring tests"

Read CPU Monitoring Object attributes:

  $ CPUMonitor=$(R "ba-cli Device.DeviceInfo.ProcessStatus.CPU.?")

  $ R logger -t cram "Initial CPU Monitoring object attributes: "$CPUMonitor

Enable CPU Monitoring for first CPU core:

  $ set_cpu_monitoring 1 1
  [{"Device.DeviceInfo.ProcessStatus.CPU.1.":{"Enable":1}}]

  $ R "ba-cli -l -j Device.DeviceInfo.ProcessStatus.CPU.1.NumSamples=4 | sed '/^$/d'"
  [{"Device.DeviceInfo.ProcessStatus.CPU.1.":{"NumSamples":4}}]

  $ R "ba-cli -l -j Device.DeviceInfo.ProcessStatus.CPU.1.PollInterval=3 | sed '/^$/d'"
  [{"Device.DeviceInfo.ProcessStatus.CPU.1.":{"PollInterval":3}}]

Read CPU Monitoring values after NumSamples * Polling Interval duration (+2 seconds):

  $ sleep 14

  $ get_cpu_monitoring_values 1
  1
  3
  4
  0001-01-01T00:00:00Z
  0001-01-01T00:00:00Z

Verify Normal CPU utilization values:
  $ verify_cpu_mode_utilization 1 SystemModeUtilization 75
  SystemModeUtilization: PASS

  $ verify_cpu_mode_utilization 1 UserModeUtilization 75
  UserModeUtilization: PASS

  $ verify_cpu_mode_utilization 1 IdleModeUtilization 100
  IdleModeUtilization: PASS

  $ verify_cpu_mode_utilization 1 CPUUtilization 70
  CPUUtilization: PASS

Disable CPU Monitoring for first core:

  $ set_cpu_monitoring 1 0
  [{"Device.DeviceInfo.ProcessStatus.CPU.1.":{"Enable":0}}]

  $ verify_disable_cpu_utilization 1 SystemModeUtilization
  SystemModeUtilization: PASS

  $ verify_disable_cpu_utilization 1 UserModeUtilization
  UserModeUtilization: PASS

  $ verify_disable_cpu_utilization 1 IdleModeUtilization
  IdleModeUtilization: PASS

  $ verify_disable_cpu_utilization 1 CPUUtilization
  CPUUtilization: PASS

  $ R logger -t cram "CPU Monitoring test finished"