Skip test on Freedom board until PCF-2288 is fixed:

  $ [ "$DUT_BOARD" = "wnc-freedom" ] && exit 80
  [1]

Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Check the root datamodel settings:

  $ R "ba-cli --json Reboot.? | sed -n '2p'" | jq --sort-keys '.[0]'
  {
    "Reboot.": {
      "BootCount": 1,
      "ColdBootCount": 1,
      "CurrentBootCycle": "Cold",
      "CurrentVersionBootCount": 1,
      "MaxRebootEntries": 10,
      "RebootNumberOfEntries": 1,
      "WarmBootCount": 0,
      "WatchdogBootCount": 0
    },
    "Reboot.Reboot.1.": {
      "Alias": "cpe-Reboot-1",
      "Cause": "LocalFactoryReset",
      "FirmwareUpdated": 0,
      "Reason": "Power lost",
      "TimeStamp": "\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}.\d+Z" (re)
    }
  }


Flush counters:

  $ R "ba-cli --json 'Reboot.RemoveAllReboots()'" >/dev/null

Check if counters are flushed:

  $ R "ba-cli --json Reboot.?0 | sed -n '2p'" | jq --sort-keys '.[0]'
  {
    "Reboot.": {
      "BootCount": 1,
      "ColdBootCount": 1,
      "CurrentBootCycle": "Cold",
      "CurrentVersionBootCount": 1,
      "MaxRebootEntries": 10,
      "RebootNumberOfEntries": 0,
      "WarmBootCount": 0,
      "WatchdogBootCount": 0
    }
  }
