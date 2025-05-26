Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Check the root datamodel settings:

  $ R "ba-cli --json ProcessMonitor.?0 | sed -n '2p'" | jq --sort-keys '.[0]'
  {
    "ProcessMonitor.": {
      "CycleDuration": \d+, (re)
      "LastReboot": "0001-01-01T00:00:00Z",
      "MaxReboots": 3,
      "NumberOfTest": \d+, (re)
      "RebootReason": "Unknown",
      "TestCustomTimeout": 5000,
      "TestInterval": \d+, (re)
      "TestPluginTimeout": 3000
    }
  }

Check that only one instance of tr181-led manager is running:

  $ R "pgrep -cf 'tr181-led -D'"
  1

Get current tr181-led manager PID:

  $ current_pid=$(R "cat /var/run/tr181-led.pid")

Add test for checking tr181-leds manager using PID:

  $ R "ba-cli 'ProcessMonitor.Test+{Type=Process,Name=tr181-led,Subject=/var/run/tr181-led.pid,FailAction=RESTART,TestInterval=2,MaxFailNum=1}' | grep -v '^>'"
  ProcessMonitor.Test.\d+. (re)
  
Check the LED manager check datamodel settings:

  $ R "ba-cli --json ProcessMonitor.Test.[Name==\\\"tr181-led\\\"].? | sed -n '2p'" | jq --sort-keys '.[0]'
  {
    "ProcessMonitor.Test.\d+.": { (re)
      "CurrentTestInterval": \d+, (re)
      "FailAction": "RESTART",
      "FailedSince": "0001-01-01T00:00:00Z",
      "Health": "Initializing",
      "LastCheck": "0001-01-01T00:00:00Z",
      "LastFailAction": "0001-01-01T00:00:00Z",
      "LastFailReason": "Error_None",
      "LastSuccess": "0001-01-01T00:00:00Z",
      "MaxFailDuration": -1,
      "MaxFailNum": 1,
      "Name": "tr181-led",
      "NumFailActions": 0,
      "NumFailed": 0,
      "RebootAfterRestartThreshold": 0,
      "Subject": "/var/run/tr181-led.pid",
      "SuccessfulSince": "0001-01-01T00:00:00Z",
      "TestInterval": 2,
      "TestIntervalMultiplier": 1,
      "TestResetInterval": 3600,
      "Type": "Process"
    }
  }

Shorthen the test cycle duration to 1 second:

  $ current_cycle_duration="$(R 'ba-cli -lj "ProcessMonitor.CycleDuration?"' | jq -e '.[] | .[] |  .CycleDuration')"
  $ R "ba-cli -l -j 'ProcessMonitor.CycleDuration=1'"
  
  [{"ProcessMonitor.":{"CycleDuration":1}}]
  
Kill the LED manager service:

  $ R "kill \$(cat /var/run/tr181-led.pid)"
  $ sleep 1

Check that LED manager is not running:

  $ R "pgrep -cf 'tr181-led -D'"
  0
  [1]

Calculate a timeout with (number_of_tests * test_interval * 2s):

  $ number_of_tests="$(R 'ba-cli -lj "ProcessMonitor.NumberOfTest?"' | jq -e '.[] | .[] |  .NumberOfTest')"
  $ reactivation_timeout=$((number_of_tests*2*10))

Check that ProcessMonitor have restarted the LED manager properly:

  $ R "ubus -t $reactivation_timeout wait_for LEDs"

Check that one LED manager instance is running:

  $ R "pgrep -cf 'tr181-led -D'"
  1

Check that PIDs are different:

  $ new_pid=$(R "cat /var/run/tr181-led.pid")
  $ test $current_pid -ne $new_pid

Cleanup:

  $ R "ba-cli --json ProcessMonitor.Test.[Name==\\\"tr181-led\\\"].-" >/dev/null

Revert back the test cycle duration:

  $ R "ba-cli -l 'ProcessMonitor.CycleDuration=$current_cycle_duration'"
  
  \d+ (re)
  
