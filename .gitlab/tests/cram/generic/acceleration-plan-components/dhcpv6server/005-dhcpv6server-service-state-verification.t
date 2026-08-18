DHCPv6 Server - Enable/Disable Toggle and Startup Order

Verify that DHCPv6 Server starts only after DHCPv6 Client receives info from WAN servers, 
and that toggling Device.DHCPv6.Server.Enable correctly starts and stops the odhcpd daemon.

Create the remote alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

# Step 0 - Verify startup order and misconfiguration state before bound

Extract key timestamps for DHCPv6 Client status transitions and Server pool activation:

  $ CLIENT_BOUND_TIME=$(R "grep -E 'DHCPv6 Client .* is Bound' /tmp/amx_mon_objects.log | head -n1 | awk '{print \$1}'")
  $ SERVER_ENABLED_TIME=$(R "grep -E 'DHCPv6Server\.Pool\..*\.Status = '\''Enabled'\''' /tmp/amx_mon_objects.log | head -n1 | awk '{print \$1}'")

Verify initial misconfiguration handling when client is not yet bound:

  $ R "grep -q 'DHCPv6Server\.Pool\..*\.Status = '\''Error_Misconfigured'\''' /tmp/amx_mon_objects.log && echo INITIAL_MISCONFIGURED_OK"
  INITIAL_MISCONFIGURED_OK

Verify server is enabled ONLY after client reaches bound state:

  $ R "awk -v client=\"$CLIENT_BOUND_TIME\" -v server=\"$SERVER_ENABLED_TIME\" 'BEGIN { exit !(client <= server) }' && echo STARTUP_ORDER_CORRECT || echo STARTUP_ORDER_INCORRECT"
  STARTUP_ORDER_CORRECT

# Step 1 - Verify DHCPv6 Server is initially enabled and running

Check that the data model reports the server as enabled

  $ R "ba-cli 'Device.DHCPv6.Server.Enable?' | grep -Ev '^(>|$)' | grep 'Enable'"
  Device.DHCPv6.Server.Enable=1

Verify the odhcpd daemon is active on the system:

  $ R "pidof odhcpd" >/dev/null && echo ODHCPD_RUNNING
  ODHCPD_RUNNING

# Step 2 - Verify disabling the server stops the daemon

Disable the DHCPv6 server via the data model:

  $ R "ba-cli 'Device.DHCPv6.Server.Enable=0'" >/dev/null
  $ sleep 2

Verify the odhcpd daemon is no longer running:

  $ R "pidof odhcpd" >/dev/null || echo ODHCPD_STOPPED
  ODHCPD_STOPPED

# Step 3 - Verify re-enabling the server starts the daemon

Re-enable the DHCPv6 server via the data model:

  $ R "ba-cli 'Device.DHCPv6.Server.Enable=1'" >/dev/null
  $ sleep 2

Verify the odhcpd daemon has started back up:

  $ R "pidof odhcpd >/dev/null && echo ODHCPD_RUNNING"
  ODHCPD_RUNNING

# Cleanup - Ensure the server remains in its expected default enabled state

  $ R "ba-cli 'Device.DHCPv6.Server.Enable=1'" >/dev/null