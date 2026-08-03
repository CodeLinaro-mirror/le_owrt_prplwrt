Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Select the number of prplMesh devices in the testbed:

  $ if echo "$CI_RUNNER_DESCRIPTION" | grep -q testbed-02; then expected_devices=2; else expected_devices=1; fi

Check that prplMesh is running in Controller+Agent mode:

  $ R ba-cli -l X_PRPLWARE-COM_ProcessManager.PrplMesh.ManagementMode? | tr -d '\n'
  Multi-AP-Controller-and-Agent (no-eol)

Check that IEEE1905 and DataElements contain all testbed devices:

  $ ieee1905_count="$(R ba-cli -l IEEE1905.Network.ALNumberOfEntries? | tr -d '\n')"
  $ test "$ieee1905_count" = "$expected_devices" && echo ok || { echo "IEEE1905 device count mismatch: actual=$ieee1905_count expected=$expected_devices"; false; }
  ok

  $ dataelements_count="$(R ba-cli -l Device.WiFi.DataElements.Network.DeviceNumberOfEntries? | tr -d '\n')"
  $ test "$dataelements_count" = "$expected_devices" && echo ok || { echo "DataElements device count mismatch: actual=$dataelements_count expected=$expected_devices"; false; }
  ok

Check that the device IDs in both models match:

  $ ieee1905_ids="$(R ba-cli -l IEEE1905.Network.AL.*.IEEE1905Id? | sed '/^$/d' | LC_ALL=C sort)"
  $ dataelements_ids="$(R ba-cli -l Device.WiFi.DataElements.Network.Device.*.ID? | sed '/^$/d' | LC_ALL=C sort)"

  $ test "$ieee1905_ids" = "$dataelements_ids" && echo ok || { printf 'IEEE1905 IDs:\n%s\nDataElements IDs:\n%s\n' "$ieee1905_ids" "$dataelements_ids"; false; }
  ok

Check that all DataElements devices are referenced from IEEE1905:

  $ referenced_ids="$(for ref in $(R ba-cli -l IEEE1905.Network.AL.*.AssocWiFiNetworkDeviceRef? | sed '/^$/d'); do R ba-cli -l "$ref.ID?"; done | sed '/^$/d' | LC_ALL=C sort)"

  $ test "$dataelements_ids" = "$referenced_ids" && echo ok || { printf 'DataElements IDs:\n%s\nReferenced DataElements IDs:\n%s\n' "$dataelements_ids" "$referenced_ids"; false; }
  ok

Check that disabling and enabling the IEEE1905 model works:

  $ R ba-cli -l IEEE1905.Network.Enable=0 | tr -d '\n'
  0 (no-eol)

  $ R ba-cli -l IEEE1905.Network.ALNumberOfEntries? | tr -d '\n'
  0 (no-eol)

  $ R ba-cli -l IEEE1905.Network.Enable=1 | tr -d '\n'
  1 (no-eol)

  $ sleep 3

  $ ieee1905_count="$(R ba-cli -l IEEE1905.Network.ALNumberOfEntries? | tr -d '\n')"
  $ test "$ieee1905_count" = "$expected_devices" && echo ok || { echo "IEEE1905 device count mismatch after enabling: actual=$ieee1905_count expected=$expected_devices"; false; }
  ok
