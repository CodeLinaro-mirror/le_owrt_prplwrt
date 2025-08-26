Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Helper methods
This method takes attributes in order Param#1 CPU-Core-Id Param#2 0 - Disable, 1 - Enable
  $ set_cpu_monitoring() { R "ba-cli -l -j Device.DeviceInfo.ProcessStatus.CPU.$1.Enable=$2 | sed '/^$/d'";}

  $ get_cpu_monitoring_values() {  R "ba-cli -l -j Device.DeviceInfo.ProcessStatus.CPU.$1.? | sed '/^$/d' | jsonfilter -e @[0]'[\"Device.DeviceInfo.ProcessStatus.CPU.$1.\"].Enable' -e @[0]'[\"Device.DeviceInfo.ProcessStatus.CPU.$1.\"].PollInterval' -e @[0]'[\"Device.DeviceInfo.ProcessStatus.CPU.$1.\"].NumSamples' -e @[0]'[\"Device.DeviceInfo.ProcessStatus.CPU.$1.\"].CriticalRiseTimeStamp' -e @[0]'[\"Device.DeviceInfo.ProcessStatus.CPU.$1.\"].CriticalFallTimeStamp'";}

This method takes attributes in order Param#1 - CPU-Core-Id Param#2 - SystemModeUtilization or UserModeUtilization or IdleModeUtilization Param#3 - Higher end utilization limit for the CPU mode.
  $ verify_cpu_mode_utilization() { CpuModeUtilization=$(R "ba-cli -l -j Device.DeviceInfo.ProcessStatus.CPU.$1.? | sed '/^$/d' | jsonfilter -e @[0]'[\"Device.DeviceInfo.ProcessStatus.CPU.$1.\"].$2'"); R logger -t cram "$2 read: $CpuModeUtilization"; if [ $CpuModeUtilization  -gt 0 -a $CpuModeUtilization -lt $3 ]; then echo "PASS"; else echo "FAIL - $2: $CpuModeUtilization"; fi;}

This method takes attributes in order Param#1-CPU-Core-Id Param#2-SystemModeUtilization or UserModeUtilization or IdleModeUtilization
  $ verify_disable_cpu_utilization() { CpuModeUtilization=$(R "ba-cli -l -j Device.DeviceInfo.ProcessStatus.CPU.$1.? | sed '/^$/d' | jsonfilter -e @[0]'[\"Device.DeviceInfo.ProcessStatus.CPU.$1.\"].$2'"); R logger -t cram "$2 read: $CpuModeUtilization"; if [ $CpuModeUtilization  -eq 0 ]; then echo "PASS"; else echo "FAIL - $2: $CpuModeUtilization after disabling CPU Monitoring"; fi;}

  $ logger -t cram "Starting CPU Monitoring tests"

Read CPU Monitoring Object attributes
  $ CPUMonitor=$(R "ba-cli Device.DeviceInfo.ProcessStatus.CPU.?")
  $ logger -t cram 'Initial CPU Monitoring object attributes: $CPUMonitor'

Enable CPU Monitoring with default values for first CPU core
  $ set_cpu_monitoring 1 1
  [{"Device.DeviceInfo.ProcessStatus.CPU.1.":{"Enable":1}}]

Read CPU Monitoring values after NumSamples * Polling Interval duration (+2 seconds)
  $ sleep 152

  $ get_cpu_monitoring_values 1
  1
  5
  30
  0001-01-01T00:00:00Z
  0001-01-01T00:00:00Z

Verify Normal CPU utilization values
  $ verify_cpu_mode_utilization 1 SystemModeUtilization 70
  PASS

  $ verify_cpu_mode_utilization 1 UserModeUtilization 70
  PASS

  $ verify_cpu_mode_utilization 1 IdleModeUtilization 100
  PASS

  $ verify_cpu_mode_utilization 1 CPUUtilization 70
  PASS

Update NumSamples and PollInterval and verify CPU Monitoring values after NumSamples * Polling Interval
  $ R "ba-cli -l -j Device.DeviceInfo.ProcessStatus.CPU.1.NumSamples=32 | sed '/^$/d'"
  [{"Device.DeviceInfo.ProcessStatus.CPU.1.":{"NumSamples":32}}]

  $ R "ba-cli -l -j Device.DeviceInfo.ProcessStatus.CPU.1.PollInterval=7 | sed '/^$/d'"
  [{"Device.DeviceInfo.ProcessStatus.CPU.1.":{"PollInterval":7}}]


Read CPU Monitoring values after NumSamples * Polling Interval duration (+2 seconds)
  $ sleep 226

  $ get_cpu_monitoring_values 1
  1
  7
  32
  0001-01-01T00:00:00Z
  0001-01-01T00:00:00Z


Verify Normal CPU utilization values after updating NumSamples and PollingInterval for first core
  $ verify_cpu_mode_utilization 1 SystemModeUtilization 70
  PASS

  $ verify_cpu_mode_utilization 1 UserModeUtilization 70
  PASS

  $ verify_cpu_mode_utilization 1 IdleModeUtilization 100
  PASS

  $ verify_cpu_mode_utilization 1 CPUUtilization 70
  PASS

Disable CPU Monitoring for first core
  $ set_cpu_monitoring 1 0
  [{"Device.DeviceInfo.ProcessStatus.CPU.1.":{"Enable":0}}]

  $ verify_disable_cpu_utilization 1 SystemModeUtilization
  PASS

  $ verify_disable_cpu_utilization 1 UserModeUtilization
  PASS

  $ verify_disable_cpu_utilization 1 IdleModeUtilization
  PASS

  $ verify_disable_cpu_utilization 1 CPUUtilization
  PASS

Revert PollingInterval and NumSamples to default value
  $ R "ba-cli -l -j Device.DeviceInfo.ProcessStatus.CPU.1.NumSamples=30 | sed '/^$/d'"
  [{"Device.DeviceInfo.ProcessStatus.CPU.1.":{"NumSamples":30}}]

  $ R "ba-cli -l -j Device.DeviceInfo.ProcessStatus.CPU.1.PollInterval=5 | sed '/^$/d'"
  [{"Device.DeviceInfo.ProcessStatus.CPU.1.":{"PollInterval":5}}]

  $ R logger -t cram "Tests finished!"

