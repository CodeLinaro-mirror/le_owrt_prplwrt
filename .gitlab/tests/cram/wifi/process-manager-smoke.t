Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Check the services are enabled by default:

  $ R "{ ba-cli -l X_PRPLWARE-COM_ProcessManager.Sensing.Enable? ; ba-cli -l X_PRPLWARE-COM_ProcessManager.PWHM.Enable? ; ba-cli -l X_PRPLWARE-COM_ProcessManager.PrplMesh.Enable? ; }" | tr -d '\n'
  111 (no-eol)

Check the processes are actually running:

  $ R "pgrep -af /usr/bin/wifi-sensing"
  \d+ /usr/bin/wifi-sensing (re)

  $ R "pgrep -af /usr/bin/wld"
  \d+ /usr/bin/wld (re)

  $ R "pgrep -af /opt/prplmesh/bin/beerocks_agent"
  \d+ /opt/prplmesh/bin/beerocks_agent (re)

Check that this is reflected in the DM:

  $ R "ba-cli -l X_PRPLWARE-COM_ProcessManager.Sensing.Status?" | tr -d '\n'
  Active (no-eol)

  $ R "ba-cli -l X_PRPLWARE-COM_ProcessManager.PWHM.Status?" | tr -d '\n'
  Active (no-eol)

  $ R "ba-cli -l X_PRPLWARE-COM_ProcessManager.PrplMesh.Status?" | tr -d '\n'
  Active (no-eol)

Check that managing WiFi Sensing works:

  $ R "ba-cli -l X_PRPLWARE-COM_ProcessManager.Sensing.Enable=0" | tr -d '\n'
  0 (no-eol)
  $ sleep 10
  $ R "pgrep -cf '/usr/bin/wifi-sensing'"
  0
  [1]
  $ R "ba-cli -l X_PRPLWARE-COM_ProcessManager.Sensing.Status?" | tr -d '\n'
  Idle (no-eol)
  $ R "ba-cli -l X_PRPLWARE-COM_ProcessManager.Sensing.Enable=1" | tr -d '\n'
  1 (no-eol)

  $ R "amx_wait_for "X_PRPLWARE-COM_WiFiSensing." "
  $ R "pgrep -cf '/usr/bin/wifi-sensing'"
  1
  $ R "ba-cli -l X_PRPLWARE-COM_ProcessManager.Sensing.Status?" | tr -d '\n'
  Active (no-eol)

Check Sensing datamodel again:

  $ R "ba-cli X_PRPLWARE-COM_ProcessManager.Sensing.? | grep -v '>'"
  X_PRPLWARE-COM_ProcessManager.Sensing.
  X_PRPLWARE-COM_ProcessManager.Sensing.Enable=1
  X_PRPLWARE-COM_ProcessManager.Sensing.FaultCode="NoFault"
  X_PRPLWARE-COM_ProcessManager.Sensing.Status="Active"
  
