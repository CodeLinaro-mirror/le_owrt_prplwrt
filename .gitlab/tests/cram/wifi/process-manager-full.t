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

Check that managing WiFi Sensing works:

  $ R "ba-cli -l X_PRPLWARE-COM_ProcessManager.Sensing.Enable=0" | tr -d '\n'
  0 (no-eol)
  $ sleep 10
  $ R " pgrep -cf '/usr/bin/wifi-sensing'"
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

Check that managing pWHM and prplMesh works:

  $ R "ba-cli -l X_PRPLWARE-COM_ProcessManager.PrplMesh.Enable=0" | tr -d '\n'
  0 (no-eol)

  $ sleep 25

  $ R "ba-cli -l X_PRPLWARE-COM_ProcessManager.PrplMesh.Status?" | tr -d '\n'
  Idle (no-eol)

  $ R "pgrep -cf /opt/prplmesh/bin/beerocks_agent"
  0
  [1]

  $ R "ba-cli -l X_PRPLWARE-COM_ProcessManager.PWHM.Enable=0" | tr -d '\n'
  0 (no-eol)

  $ sleep 25

  $ R "ba-cli -l X_PRPLWARE-COM_ProcessManager.PWHM.Status?" | tr -d '\n'
  Idle (no-eol)

  $ R "pgrep -cf '/usr/bin/wld'"
  0
  [1]

  $ R "ba-cli -l X_PRPLWARE-COM_ProcessManager.PWHM.Enable=1" | tr -d '\n'
  1 (no-eol)

  $ R "amx_wait_for "WiFi." "

  $ R "ba-cli -l X_PRPLWARE-COM_ProcessManager.PWHM.Status?" | tr -d '\n'
  Active (no-eol)

  $ R "pgrep -cf '/usr/bin/wld'"
  1

  $ R "ba-cli -l X_PRPLWARE-COM_ProcessManager.PrplMesh.Enable=1" | tr -d '\n'
  1 (no-eol)

  $ R "amx_wait_for "X_PRPLWARE-COM_Agent." "
  $ sleep 5

  $ R "ba-cli -l X_PRPLWARE-COM_ProcessManager.PrplMesh.Status?" | tr -d '\n'
  Active (no-eol)

  $ R "pgrep -cf /opt/prplmesh/bin/beerocks_agent"
  1

# Blocked by PPM-3590. May be not needed because requere additional ~1 min delays
# Check that switching ManagementMode restarts prplMesh:

  $ R '
  > MODE=$(ba-cli -l X_PRPLWARE-COM_ProcessManager.PrplMesh.ManagementMode? | tr -d "\n")
  > PID=$(pgrep -f beerocks_agent)
  > [[ $MODE == *"Controller"* ]] && NEW_MODE=Multi-AP-Agent || NEW_MODE=Multi-AP-Controller-and-Agent
  > ba-cli X_PRPLWARE-COM_ProcessManager.PrplMesh.ManagementMode=$NEW_MODE >/dev/null
  > sleep 30
  > NEW_PID=$(pgrep -f beerocks_agent)
  > [[ "$NEW_PID" != "$PID" ]] || echo $PID $NEW_PID
  > '

# Restoring default state:

  $ R "ba-cli X_PRPLWARE-COM_ProcessManager.PrplMesh.ManagementMode=Multi-AP-Controller-and-Agent"  > /dev/null


# Waiting for agent to complete statup
  $ R "amx_wait_for "X_PRPLWARE-COM_Agent.Info." "

  $ R "ba-cli X_PRPLWARE-COM_ProcessManager.? | grep -Ev '^(>|$)'"
  X_PRPLWARE-COM_ProcessManager.
  X_PRPLWARE-COM_ProcessManager.PWHM.
  X_PRPLWARE-COM_ProcessManager.PWHM.Enable=1
  X_PRPLWARE-COM_ProcessManager.PWHM.FaultCode="NoFault"
  X_PRPLWARE-COM_ProcessManager.PWHM.Status="Active"
  X_PRPLWARE-COM_ProcessManager.PrplMesh.
  X_PRPLWARE-COM_ProcessManager.PrplMesh.CertificationMode=0
  X_PRPLWARE-COM_ProcessManager.PrplMesh.ControllerConfigSource="Device.WiFi"
  X_PRPLWARE-COM_ProcessManager.PrplMesh.Enable=1
  X_PRPLWARE-COM_ProcessManager.PrplMesh.FaultCode="NoFault"
  X_PRPLWARE-COM_ProcessManager.PrplMesh.ManagementMode="Multi-AP-Controller-and-Agent"
  X_PRPLWARE-COM_ProcessManager.PrplMesh.Status="Active"
  X_PRPLWARE-COM_ProcessManager.Sensing.
  X_PRPLWARE-COM_ProcessManager.Sensing.Enable=1
  X_PRPLWARE-COM_ProcessManager.Sensing.FaultCode="NoFault"
  X_PRPLWARE-COM_ProcessManager.Sensing.Status="Active"
# NOTE:
# This test restarts PWHM and prplMesh services.
# As a result, the system requires ~30 seconds to fully recover and stabilize.
# To avoid random failures in subsequent tests, this test must be executed last.
