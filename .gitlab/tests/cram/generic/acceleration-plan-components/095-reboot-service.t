Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Check the root datamodel settings:

  $ R "ba-cli --json Reboot.? | sed -n '2p'" | jq --sort-keys '.[0]'
  {
    "Reboot.": {
      "BootCounter": 1,
      "MaximumNumberOfReboots": 10,
      "NumberOfReboots": 1,
      "WatchdogRebootCounter": 0
    },
    "Reboot.Reboot.1.": {
      "BootDate": "\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}.\d+Z", (re)
      "BootReason": "Planned reboot - initiated by \"LocalFactoryReset\""
    }
  }

Flush counters:

  $ R "ba-cli --json 'Reboot.flush()'" >/dev/null

Check if counters are flushed:

  $ R "ba-cli --json Reboot.?0 | sed -n '2p'" | jq --sort-keys '.[0]'
  {
    "Reboot.": {
      "BootCounter": 0,
      "MaximumNumberOfReboots": 10,
      "NumberOfReboots": 0,
      "WatchdogRebootCounter": 0
    }
  }
