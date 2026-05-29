Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Verify CPUs — Data Model of OSPv2 Board:

  $ R "ba-cli -lj CPUs.?" | jq .
  [
    {
      "CPUs.CPU.2.DVFS.": {
        "CurrentFrequency": \d+, (re)
        "ScalingGovernor": "powersave",
        "Status": "Disabled",
        "Supported": 1,
        "ScalingAvailableGovernors": "performance,powersave",
        "ScalingMaxFrequency": 1716000,
        "Enable": 0,
        "MaxFrequency": 1716000,
        "ScalingAvailableFrequencies": "624000,780000,936000,1092000,1248000,1404000,1560000,1716000",
        "ScalingMinFrequency": 624000,
        "MinFrequency": 624000
      },
      "CPUs.CPU.1.DVFS.": {
        "CurrentFrequency": \d+, (re)
        "ScalingGovernor": "powersave",
        "Status": "Disabled",
        "Supported": 1,
        "ScalingAvailableGovernors": "performance,powersave",
        "ScalingMaxFrequency": 1716000,
        "Enable": 0,
        "MaxFrequency": 1716000,
        "ScalingAvailableFrequencies": "624000,780000,936000,1092000,1248000,1404000,1560000,1716000",
        "ScalingMinFrequency": 624000,
        "MinFrequency": 624000
      },
      "CPUs.CPU.1.": {
        "Alias": "cpe-cpu0"
      },
      "CPUs.": {
        "CPUNumberOfEntries": 2
      },
      "CPUs.CPU.2.": {
        "Alias": "cpe-cpu1"
      }
    }
  ]

Enable the Dynamic Voltage and Frequency Scaling (DVFS) feature:

  $ R 'ba-cli CPUs.CPU.1.DVFS.Enable=1' | grep -Ev '^(>|$)' | grep 'CPUs.CPU.1.DVFS.Enable='
  CPUs.CPU.1.DVFS.Enable=1

Change governor to performance:

  $ R 'ba-cli CPUs.CPU.1.DVFS.ScalingGovernor="performance"' | grep -Ev '^(>|$)' | grep 'CPUs.CPU.1.DVFS.ScalingGovernor='
  CPUs.CPU.1.DVFS.ScalingGovernor="performance"

Check that the governor was changed to performance in datamodel:

  $ R "ba-cli CPUs.CPU.*.DVFS.ScalingGovernor?" | grep -Ev '^(>|$)' | LC_ALL=C sort
  CPUs.CPU.1.DVFS.ScalingGovernor="performance"
  CPUs.CPU.2.DVFS.ScalingGovernor="powersave"

Check that the governor was changed in sysfs:

  $ R "cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor"
  performance
  powersave

Change governor back to powersave:

  $ R 'ba-cli CPUs.CPU.1.DVFS.ScalingGovernor="powersave"' | grep -Ev '^(>|$)' | grep 'CPUs.CPU.1.DVFS.ScalingGovernor='
  CPUs.CPU.1.DVFS.ScalingGovernor="powersave"

Check that the governor was changed back to powersave in datamodel:

  $ R "ba-cli CPUs.CPU.*.DVFS.ScalingGovernor?" | grep -Ev '^(>|$)' | LC_ALL=C sort
  CPUs.CPU.1.DVFS.ScalingGovernor="powersave"
  CPUs.CPU.2.DVFS.ScalingGovernor="powersave"

Check that the governor was changed back to powersave in sysfs:

  $ R "cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor"
  powersave
  powersave

Check that its not possible to use unavailable conservative governor:

  $ R 'ba-cli CPUs.CPU.1.DVFS.ScalingGovernor="Test"' | grep -Ev '^(>|$)' | grep 'ERROR:'
  ERROR: set CPUs.CPU.1.DVFS.ScalingGovernor failed (10 - invalid value)

Check that the governor is still set to powersave in datamodel:

  $ R "ba-cli CPUs.CPU.*.DVFS.ScalingGovernor?" | grep -Ev '^(>|$)' | LC_ALL=C sort
  CPUs.CPU.1.DVFS.ScalingGovernor="powersave"
  CPUs.CPU.2.DVFS.ScalingGovernor="powersave"

Check that the governor was is still set to powersave in sysfs:

  $ R "cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor"
  powersave
  powersave
