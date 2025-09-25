Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Verify CPUs — Data Model of Freedom Board:

  $ R "ba-cli -lj CPUs.?" | jq .
  [
    {
      "CPUs.CPU.3.": {
        "Alias": "cpe-cpu2"
      },
      "CPUs.CPU.1.DVFS.": {
        "CurrentFrequency": \d+, (re)
        "ScalingGovernor": "performance",
        "Status": "Disabled",
        "Supported": 1,
        "ScalingAvailableGovernors": "conservative,ondemand,userspace,powersave,performance",
        "ScalingMaxFrequency": 2208000,
        "Enable": 0,
        "MaxFrequency": 2208000,
        "ScalingAvailableFrequencies": "936000,1104000,1416000,1488000,1800000,2208000",
        "ScalingMinFrequency": 936000,
        "MinFrequency": 936000
      },
      "CPUs.CPU.4.DVFS.": {
        "CurrentFrequency": \d+, (re)
        "ScalingGovernor": "performance",
        "Status": "Disabled",
        "Supported": 1,
        "ScalingAvailableGovernors": "conservative,ondemand,userspace,powersave,performance",
        "ScalingMaxFrequency": 2208000,
        "Enable": 0,
        "MaxFrequency": 2208000,
        "ScalingAvailableFrequencies": "936000,1104000,1416000,1488000,1800000,2208000",
        "ScalingMinFrequency": 936000,
        "MinFrequency": 936000
      },
      "CPUs.CPU.2.": {
        "Alias": "cpe-cpu1"
      },
      "CPUs.CPU.2.DVFS.": {
        "CurrentFrequency": \d+, (re)
        "ScalingGovernor": "performance",
        "Status": "Disabled",
        "Supported": 1,
        "ScalingAvailableGovernors": "conservative,ondemand,userspace,powersave,performance",
        "ScalingMaxFrequency": 2208000,
        "Enable": 0,
        "MaxFrequency": 2208000,
        "ScalingAvailableFrequencies": "936000,1104000,1416000,1488000,1800000,2208000",
        "ScalingMinFrequency": 936000,
        "MinFrequency": 936000
      },
      "CPUs.CPU.4.": {
        "Alias": "cpe-cpu3"
      },
      "CPUs.CPU.3.DVFS.": {
        "CurrentFrequency": \d+, (re)
        "ScalingGovernor": "performance",
        "Status": "Disabled",
        "Supported": 1,
        "ScalingAvailableGovernors": "conservative,ondemand,userspace,powersave,performance",
        "ScalingMaxFrequency": 2208000,
        "Enable": 0,
        "MaxFrequency": 2208000,
        "ScalingAvailableFrequencies": "936000,1104000,1416000,1488000,1800000,2208000",
        "ScalingMinFrequency": 936000,
        "MinFrequency": 936000
      },
      "CPUs.CPU.1.": {
        "Alias": "cpe-cpu0"
      },
      "CPUs.": {
        "CPUNumberOfEntries": 4
      }
    }
  ]

Enable the Dynamic Voltage and Frequency Scaling (DVFS) feature:

  $ R 'ba-cli CPUs.CPU.1.DVFS.Enable=1'| sed -n '3p'
  CPUs.CPU.1.DVFS.Enable=1

Change governor to performance:

  $ R 'ba-cli CPUs.CPU.1.DVFS.ScalingGovernor="performance"'| sed -n '3p'
  CPUs.CPU.1.DVFS.ScalingGovernor="performance"

Check that the governor was changed to performance in datamodel:

  $ R "ba-cli CPUs.CPU.*.DVFS.ScalingGovernor?" | tail -n+2 | LC_ALL=C sort
  
  CPUs.CPU.1.DVFS.ScalingGovernor="performance"
  CPUs.CPU.2.DVFS.ScalingGovernor="performance"
  CPUs.CPU.3.DVFS.ScalingGovernor="performance"
  CPUs.CPU.4.DVFS.ScalingGovernor="performance"

Check that the governor was changed in sysfs:

  $ R "cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor"
  performance
  performance
  performance
  performance

Change governor back to powersave:

  $ R 'ba-cli CPUs.CPU.1.DVFS.ScalingGovernor="powersave"'| sed -n '3p'
  CPUs.CPU.1.DVFS.ScalingGovernor="powersave"

Check that the governor was changed back to powersave in datamodel:

  $ R "ba-cli CPUs.CPU.*.DVFS.ScalingGovernor?" | tail -n+2 | LC_ALL=C sort
  
  CPUs.CPU.1.DVFS.ScalingGovernor="powersave"
  CPUs.CPU.2.DVFS.ScalingGovernor="powersave"
  CPUs.CPU.3.DVFS.ScalingGovernor="powersave"
  CPUs.CPU.4.DVFS.ScalingGovernor="powersave"

Check that the governor was changed back to powersave in sysfs:

  $ R "cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor"
  powersave
  powersave
  powersave
  powersave

Check that its not possible to use unavailable conservative governor:

  $ R 'ba-cli CPUs.CPU.1.DVFS.ScalingGovernor="Test"'| sed -n '2p'
  ERROR: set CPUs.CPU.1.DVFS.ScalingGovernor failed (10 - invalid value)

Check that the governor is still set to powersave in datamodel:

  $ R "ba-cli CPUs.CPU.*.DVFS.ScalingGovernor?" | tail -n+2 | LC_ALL=C sort
  
  CPUs.CPU.1.DVFS.ScalingGovernor="powersave"
  CPUs.CPU.2.DVFS.ScalingGovernor="powersave"
  CPUs.CPU.3.DVFS.ScalingGovernor="powersave"
  CPUs.CPU.4.DVFS.ScalingGovernor="powersave"

Check that the governor was is still set to powersave in sysfs:

  $ R "cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor"
  powersave
  powersave
  powersave
  powersave

Set the governor back to performance to avoid affecting other tests:

  $ R 'ba-cli CPUs.CPU.1.DVFS.ScalingGovernor="performance"'| sed -n '3p'
  CPUs.CPU.1.DVFS.ScalingGovernor="performance"

Check that the governor was changed to performance in datamodel:

  $ R "ba-cli CPUs.CPU.*.DVFS.ScalingGovernor?" | tail -n+2 | LC_ALL=C sort
  
  CPUs.CPU.1.DVFS.ScalingGovernor="performance"
  CPUs.CPU.2.DVFS.ScalingGovernor="performance"
  CPUs.CPU.3.DVFS.ScalingGovernor="performance"
  CPUs.CPU.4.DVFS.ScalingGovernor="performance"