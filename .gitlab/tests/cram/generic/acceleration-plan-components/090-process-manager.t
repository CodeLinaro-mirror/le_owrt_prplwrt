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

# Blocked by PPM-3590
# $ R "pgrep -afc beerocks_agent"
# 1

Check that this is reflected in the DM:

  $ R "ba-cli -l X_PRPLWARE-COM_ProcessManager.Sensing.Status?" | tr -d '\n'
  Active (no-eol)

  $ R "ba-cli -l X_PRPLWARE-COM_ProcessManager.PWHM.Status?" | tr -d '\n'
  Active (no-eol)

# Blocked by PPM-3590
# $ R "ba-cli -l X_PRPLWARE-COM_ProcessManager.PrplMesh.Status?" | tr -d '\n'
# Active (no-eol)

Check that managing WiFi Sensing works:

  $ R "ba-cli -l X_PRPLWARE-COM_ProcessManager.Sensing.Enable=0" | tr -d '\n'
  0 (no-eol)
  $ R "sleep 10s"
  $ R " pgrep -cf 'wifi-sensing'"
  0
  [1]
  $ R "ba-cli -l X_PRPLWARE-COM_ProcessManager.Sensing.Status?" | tr -d '\n'
  Idle (no-eol)
  $ R "ba-cli -l X_PRPLWARE-COM_ProcessManager.Sensing.Enable=1" | tr -d '\n'
  1 (no-eol)
  $ R "sleep 10s"
  $ R "pgrep -cf 'wifi-sensing'"
  1
  $ R "ba-cli -l X_PRPLWARE-COM_ProcessManager.Sensing.Status?" | tr -d '\n'
  Active (no-eol)

Check that managing pWHM works:
# Blocked by PPM-3590
#  $ R "ba-cli -l X_PRPLWARE-COM_ProcessManager.PWHM.Enable=0" | tr -d '\n'
#  0 (no-eol)
#  $ R "sleep 10s"
#  $ R "pgrep -cf 'wld'"
#  0
#  [1]
#  $ R "ba-cli -l X_PRPLWARE-COM_ProcessManager.PWHM.Status?" | tr -d '\n'
#  Idle (no-eol)
#  $ R "ba-cli -l X_PRPLWARE-COM_ProcessManager.PWHM.Enable=1" | tr -d '\n'
#  1 (no-eol)
#  $ R "sleep 10s"
#  $ R "pgrep -cf 'wld'"
#  1
#  $ R "ba-cli -l X_PRPLWARE-COM_ProcessManager.PWHM.Status?" | tr -d '\n'
#  Active (no-eol)


Check that managing prplMesh works:

  $ R "ba-cli -l X_PRPLWARE-COM_ProcessManager.PrplMesh.Enable=0" | tr -d '\n'
  0 (no-eol)
  $ R "sleep 20s"
  $ R "ba-cli -l X_PRPLWARE-COM_ProcessManager.PrplMesh.Status?" | tr -d '\n'
  Idle (no-eol)
  $ R "pgrep -cf beerocks_agent"
  0
  [1]
  $ R "ba-cli -l X_PRPLWARE-COM_ProcessManager.PrplMesh.Enable=1" | tr -d '\n'
  1 (no-eol)
  $ R "sleep 20s"
  $ R "ba-cli -l X_PRPLWARE-COM_ProcessManager.PrplMesh.Status?" | tr -d '\n'
  Active (no-eol)
  $ R "pgrep -cf beerocks_agent"
  1

Check that switching ManagementMode restarts prplMesh:

  $ R '
  > MODE=$(ba-cli -l X_PRPLWARE-COM_ProcessManager.PrplMesh.ManagementMode? | tr -d "\n")
  > PID=$(pgrep -f beerocks_agent)
  > [[ $MODE == *"Controller"* ]] && NEW_MODE=Multi-AP-Agent || NEW_MODE=Multi-AP-Controller-and-Agent
  > ba-cli X_PRPLWARE-COM_ProcessManager.PrplMesh.ManagementMode=$NEW_MODE >/dev/null
  > sleep 30
  > NEW_PID=$(pgrep -f beerocks_agent)
  > [[ "$NEW_PID" != "$PID" ]] || echo $PID $NEW_PID
  > '

Restoring default state:

  $ R "ba-cli X_PRPLWARE-COM_ProcessManager.PrplMesh.ManagementMode=Multi-AP-Controller-and-Agent"  > /dev/null

  $ R "ba-cli -l X_PRPLWARE-COM_ProcessManager.PrplMesh.Enable=1" | tr -d '\n'
  1 (no-eol)

  $ R "ba-cli -l X_PRPLWARE-COM_ProcessManager.PWHM.Enable=1" | tr -d '\n'
  1 (no-eol)

  $ R "ba-cli -l X_PRPLWARE-COM_ProcessManager.Sensing.Enable=1" | tr -d '\n'
  1 (no-eol)

  $ R "sleep 30s"

  $ R "ba-cli X_PRPLWARE-COM_ProcessManager.? | grep -v '>'"
  X_PRPLWARE-COM_ProcessManager.
  X_PRPLWARE-COM_ProcessManager.PWHM.
  X_PRPLWARE-COM_ProcessManager.PWHM.Enable=1
  X_PRPLWARE-COM_ProcessManager.PWHM.FaultCode="NoFault"
  X_PRPLWARE-COM_ProcessManager.PWHM.Status="Active"
  X_PRPLWARE-COM_ProcessManager.PrplMesh.
  X_PRPLWARE-COM_ProcessManager.PrplMesh.CertificationMode=0
  X_PRPLWARE-COM_ProcessManager.PrplMesh.Enable=1
  X_PRPLWARE-COM_ProcessManager.PrplMesh.FaultCode="NoFault"
  X_PRPLWARE-COM_ProcessManager.PrplMesh.ManagementMode="Multi-AP-Controller-and-Agent"
  X_PRPLWARE-COM_ProcessManager.PrplMesh.Status="Active"
  X_PRPLWARE-COM_ProcessManager.Sensing.
  X_PRPLWARE-COM_ProcessManager.Sensing.Enable=1
  X_PRPLWARE-COM_ProcessManager.Sensing.FaultCode="NoFault"
  X_PRPLWARE-COM_ProcessManager.Sensing.Status="Active"
  
