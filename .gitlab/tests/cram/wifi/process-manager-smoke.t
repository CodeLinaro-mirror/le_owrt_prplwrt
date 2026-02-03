Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Check the services are enabled by default:

  $ R "{ ba-cli -l X_PRPLWARE-COM_ProcessManager.Sensing.Enable? ; ba-cli -l X_PRPLWARE-COM_ProcessManager.PWHM.Enable? ; ba-cli -l X_PRPLWARE-COM_ProcessManager.PrplMesh.Enable? ; }" | tr -d '\n'
  111 (no-eol)

Check the processes are actually running:

  $ R "pgrep -afc wifi-sensing"
  1

  $ R "pgrep -afc wld"
  1

  $ R "pgrep -afc beerocks_agent"
  1

Check that this is reflected in the DM:

  $ R "ba-cli -l X_PRPLWARE-COM_ProcessManager.Sensing.Status?" | tr -d '\n'
  Active (no-eol)

  $ R "ba-cli -l X_PRPLWARE-COM_ProcessManager.PWHM.Status?" | tr -d '\n'
  Active (no-eol)

  $ R "ba-cli -l X_PRPLWARE-COM_ProcessManager.PrplMesh.Status?" | tr -d '\n'
  Active (no-eol)

Check that managing pWHM works:

  $ R "ba-cli -l X_PRPLWARE-COM_ProcessManager.PWHM.Enable=0" | tr -d '\n'
  0 (no-eol)
  $ sleep 10
  $ R "pgrep -cf 'wld'"
  0
  [1]
  $ R "ba-cli -l X_PRPLWARE-COM_ProcessManager.PWHM.Status?" | tr -d '\n'
  Idle (no-eol)
  $ R "ba-cli -l X_PRPLWARE-COM_ProcessManager.PWHM.Enable=1" | tr -d '\n'
  1 (no-eol)

  $ R "amx_wait_for "WiFi." "
  $ R "pgrep -cf 'wld'"
  1
  $ R "ba-cli -l X_PRPLWARE-COM_ProcessManager.PWHM.Status?" | tr -d '\n'
  Active (no-eol)

Check Sensing datamodel again:

  $ R "ba-cli X_PRPLWARE-COM_ProcessManager.PWHM.? | grep -v '>'"
  X_PRPLWARE-COM_ProcessManager.PWHM.
  X_PRPLWARE-COM_ProcessManager.PWHM.Enable=1
  X_PRPLWARE-COM_ProcessManager.PWHM.FaultCode="NoFault"
  X_PRPLWARE-COM_ProcessManager.PWHM.Status="Active"
  
