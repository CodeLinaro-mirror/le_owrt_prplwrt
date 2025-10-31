Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Check the root datamodel settings:

  $ R "ba-cli --json ProcessFaults.?0 | sed -n '2p'" | jq --sort-keys '.[0]'
  {
    "ProcessFaults.": {
      "LastUpgradeCount": \d+, (re)
      "MaxProcessFaultEntries": 5,
      "MinFreeSpace": 3000,
      "PreviousBootCount": \d+, (re)
      "ProcessFaultNumberOfEntries": \d+, (re)
      "RotateProcessFaultEntries": 0,
      "StoragePath": "/ext/faults"
    }
  }

Save current fault list:

  $ fault_list="$(R "ba-cli -j 'ProcessFaults.ProcessFault.?' | sed -n 2p" | jq ".[] | keys[]" | tr -d '"')"

Start a dummy process and cause it to crash with a SIGSEGV:

  $ dummy_pid="$(R 'sleep 60 & sleepPid="$!"; sleep 1; kill -SEGV "$sleepPid"; echo "$sleepPid"')"
  $ sleep 2

Get new entry in the fault list

  $ new_fault_list="$(R "ba-cli -j 'ProcessFaults.ProcessFault.?' | sed -n 2p" | jq ".[] | keys[]")"
  $ if [ -n "$fault_list" ]; then
  >   sed_script="$(echo "$fault_list" | while read line; do echo -n "/${line}/d;";done)"
  >   new_fault="$(echo "$new_fault_list" | sed "$sed_script" )"
  > else
  >   new_fault="$new_fault_list"
  > fi

Check if process fault has been registered:

  $ R "ba-cli -j ${new_fault}? | sed -n '2p'" | jq ".[] | .[] | .ProcessName"
  "sleep"

Check PID of the process:

  $ test "$dummy_pid" -eq $(R "ba-cli -j ${new_fault}? | sed -n '2p'" | jq ".[] | .[] | .ProcessID")

Check if core dump has been created:

  $ core_dump_location="$(R "ba-cli -j ${new_fault}? | sed -n '2p'" | jq ".[] | .[] | .FaultLocation" | tr -d '"')"
  $ R "gunzip -c \"${core_dump_location}core.gz\" 2>&1 | hexdump -c -n4 | grep -q 'E   L   F'"

Cleanup only if entry is from this test:

  $ number_of_entries="$( R "ba-cli -l 'ProcessFaults.ProcessFaultNumberOfEntries?' | sed -n '2p'")"
  $ if [ "$number_of_entries" -eq 1 ]; then R "ba-cli 'ProcessFaults.RemoveAllProcessFaults()' >/dev/null"; fi

Check if dump files have really been removed:

  $ if [ "$number_of_entries" -eq 1 ]; then R "! test -f \"${core_dump_location}core.gz\""; fi

Ensure that ProcessFaults does not contain any crashes, expected LastUpgradeCount to be 1 because of the simulated crash

  $ R "ba-cli ProcessFaults.? | grep -v '^>' | head -n -1 | sort"
  ProcessFaults.
  ProcessFaults.LastUpgradeCount=1
  ProcessFaults.MaxProcessFaultEntries=5
  ProcessFaults.MinFreeSpace=3000
  ProcessFaults.PreviousBootCount=0
  ProcessFaults.ProcessFaultNumberOfEntries=0
  ProcessFaults.RotateProcessFaultEntries=0
  ProcessFaults.StoragePath="/ext/faults"
