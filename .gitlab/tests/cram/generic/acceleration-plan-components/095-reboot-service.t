Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Check the root datamodel settings:

  $ R "ba-cli --json Reboot.? | sed -n '2p'" | jq --sort-keys '.[0]'
  {
    "Reboot.": {
      "BootCount": 1,
      "ColdBootCount": 0,
      "MaxRebootEntries": 10,
      "RebootNumberOfEntries": 1,
      "WarmBootCount": 0,
      "WatchdogBootCount": 0,
      "X_PRPLWARE-COM_CurrentBootCycle": ""
    },
    "Reboot.Reboot.1.": {
      "Alias": "cpe-Reboot-1",
      "Cause": "LocalFactoryReset",
      "FirmwareUpdated": 0,
      "Reason": "Initiated by Unknown",
      "TimeStamp": "\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}.\d+Z" (re)
    },
    "Reboot.X_PRPLWARE-COM_Reasons.1.": {
      "Alias": "REASON_FIRMWARE_UPGRADE",
      "Format": "Firmware Upgrade %s"
    },
    "Reboot.X_PRPLWARE-COM_Reasons.10.": {
      "Alias": "REASON_INITIATED_BY_SOURCE",
      "Format": "Initiated by %s"
    },
    "Reboot.X_PRPLWARE-COM_Reasons.11.": {
      "Alias": "REASON_UNKNOWN",
      "Format": "Unknown"
    },
    "Reboot.X_PRPLWARE-COM_Reasons.2.": {
      "Alias": "REASON_FIRMWARE_DOWNGRADE",
      "Format": "Firmware Downgrade %s"
    },
    "Reboot.X_PRPLWARE-COM_Reasons.3.": {
      "Alias": "REASON_POWER_LOST",
      "Format": "Power lost"
    },
    "Reboot.X_PRPLWARE-COM_Reasons.4.": {
      "Alias": "REASON_OVERHEAT",
      "Format": "Overheat"
    },
    "Reboot.X_PRPLWARE-COM_Reasons.5.": {
      "Alias": "REASON_AUTOMATIC_PLANNED_REBOOT",
      "Format": "Automatic planned reboot"
    },
    "Reboot.X_PRPLWARE-COM_Reasons.6.": {
      "Alias": "REASON_USERSPACE_CRASH",
      "Format": "Userspace crash in %s %s"
    },
    "Reboot.X_PRPLWARE-COM_Reasons.7.": {
      "Alias": "REASON_KERNEL_CRASH",
      "Format": "Kernel crash %s"
    },
    "Reboot.X_PRPLWARE-COM_Reasons.8.": {
      "Alias": "REASON_HARDWARE_WATCHDOG",
      "Format": "Hardware watchdog %s"
    },
    "Reboot.X_PRPLWARE-COM_Reasons.9.": {
      "Alias": "REASON_CRASH_LOOP_PROTECTION_DETECTION",
      "Format": "Crash loop Protection detected on %s %s"
    }
  }


Flush counters:

  $ R "ba-cli --json 'Reboot.RemoveAllReboots()'" >/dev/null

Check if counters are flushed:

  $ R "ba-cli --json Reboot.?0 | sed -n '2p'" | jq --sort-keys '.[0]'
  {
    "Reboot.": {
      "BootCount": 1,
      "ColdBootCount": 0,
      "MaxRebootEntries": 10,
      "RebootNumberOfEntries": 0,
      "WarmBootCount": 0,
      "WatchdogBootCount": 0,
      "X_PRPLWARE-COM_CurrentBootCycle": ""
    }
  }
