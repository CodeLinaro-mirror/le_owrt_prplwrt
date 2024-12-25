Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Check that there are no signs of crashes:

  $ R "getDebugInformation --log --output /dev/stdout" | \
  > grep -C10 -E \
  >      -e '(traps:.*general protection|segfault at [[:digit:]]+ ip.*error.*in)' \
  >      -e 'do_page_fault\(\): sending' \
  >      -e 'Unable to handle kernel.*address' \
  >      -e '(PC is at |pc : )([^+\[ ]+).*' \
  >      -e 'epc\s+:\s+\S+\s+([^+ ]+).*' \
  >      -e 'EIP: \[<.*>\] ([^+ ]+).*' \
  >      -e 'RIP: [[:xdigit:]]{4}:(\[<[[:xdigit:]]+>\] \[<[[:xdigit:]]+>\] )?([^+ ]+)\+0x.*'
  [1]

Ensure that ProcessFaults does not contain any crashes:

  $ R "ba-cli ProcessFaults.? | grep -v '^>' | head -n -1 | sort"
  ProcessFaults.
  ProcessFaults.LastUpgradeCount=0
  ProcessFaults.MaxProcessFaultEntries=5
  ProcessFaults.MinFreeSpace=3000
  ProcessFaults.PreviousBootCount=0
  ProcessFaults.ProcessFaultNumberOfEntries=0
  ProcessFaults.StoragePath="/ext/faults"

Ensure that there are no core dumps in the system:

  $ storage_path=$(R "ba-cli -l ProcessFaults.StoragePath?" | tr -d '\n')
  $ R "test ! -d \"$storage_path\""