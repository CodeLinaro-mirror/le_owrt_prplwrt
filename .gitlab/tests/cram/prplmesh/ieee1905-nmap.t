Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

This test runs after the other prplMesh tests because changing the management mode restarts prplMesh.
On multi-device testbeds, rediscovering a remote AL after restoring Controller+Agent mode can take over 60 seconds.

Check that prplMesh starts in Controller+Agent mode:

  $ R ba-cli -l X_PRPLWARE-COM_ProcessManager.PrplMesh.ManagementMode? | tr -d '\n'
  Multi-AP-Controller-and-Agent (no-eol)

Switch prplMesh to NMAP mode:

  $ R ba-cli -l X_PRPLWARE-COM_ProcessManager.PrplMesh.ManagementMode="Not-Multi-AP" | tr -d '\n'
  Not-Multi-AP (no-eol)

  $ sleep 5

Check that the local AL is present in the IEEE1905 model:

  $ ieee1905_count="$(R ba-cli -l IEEE1905.Network.ALNumberOfEntries? | tr -d '\n')"
  $ test "$ieee1905_count" -ge 1 && echo ok || { echo "IEEE1905 model is empty: ALNumberOfEntries=$ieee1905_count"; false; }
  ok

Remote ALs are not checked because they appear only after the corresponding device sends its periodic Topology Discovery.

Check that the EasyMesh Network model is removed while controller configuration remains in NMAP mode:

  $ R ba-cli -l Device.WiFi.DataElements.Network.? | sed '/^$/d'
  ERROR: Device.WiFi.DataElements.Network. not found.

  $ R ba-cli -l Device.WiFi.DataElements.X_PRPLWARE-COM_Controller.Configuration.HigherLayerRequestIntervalSec? | tr -d '\n'
  60 (no-eol)

  $ R ba-cli -l IEEE1905.Network.AL.*.AssocWiFiNetworkDeviceRef? | sed '/^$/d' | wc -l
  0

Check that disabling the IEEE1905 model also works in NMAP mode:

  $ R ba-cli -l IEEE1905.Network.Enable=0 | tr -d '\n'
  0 (no-eol)

  $ R ba-cli -l IEEE1905.Network.ALNumberOfEntries? | tr -d '\n'
  0 (no-eol)

  $ R ba-cli -l IEEE1905.Network.Enable=1 | tr -d '\n'
  1 (no-eol)

Restore Controller+Agent mode:

  $ R ba-cli -l X_PRPLWARE-COM_ProcessManager.PrplMesh.ManagementMode="Multi-AP-Controller-and-Agent" | tr -d '\n'
  Multi-AP-Controller-and-Agent (no-eol)

  $ sleep 5

  $ R ba-cli -l X_PRPLWARE-COM_ProcessManager.PrplMesh.Status? | tr -d '\n'
  Active (no-eol)
