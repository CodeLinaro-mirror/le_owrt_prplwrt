DHCPv4 Server Pool - Cross-Parameter Address Range Validation

Verify that DHCPv4.Server.Pool.{i} parameter validation enforces coherent 
address pools. Setting invalid params (MinAddress > MaxAddress or non-contiguous 
subnet masks) must fail with an error rather than being accepted silently.

Setup environment and define remote command alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Identify target DHCPv4 Server Pool instance:

  $ POOL_INST=$(R "ba-cli 'Device.DHCPv4.Server.Pool.*.Enable?' | grep -Ev '^(>|$)' | head -n1 | cut -d. -f5")
  $ [ -n "$POOL_INST" ] || POOL_INST="1"

Save original pool parameters for cleanup:

  $ ORIG_MIN=$(R "ba-cli 'Device.DHCPv4.Server.Pool.${POOL_INST}.MinAddress?' | awk -F= '{print \$2}' | tr -d '\"'")
  $ ORIG_MAX=$(R "ba-cli 'Device.DHCPv4.Server.Pool.${POOL_INST}.MaxAddress?' | awk -F= '{print \$2}' | tr -d '\"'")
  $ ORIG_MASK=$(R "ba-cli 'Device.DHCPv4.Server.Pool.${POOL_INST}.SubnetMask?' | awk -F= '{print \$2}' | tr -d '\"'")

# Step 1 - Set a valid baseline pool configuration

  $ R "ba-cli 'Device.DHCPv4.Server.Pool.${POOL_INST}.SubnetMask=\"255.255.255.0\"'" >/dev/null
  $ R "ba-cli 'Device.DHCPv4.Server.Pool.${POOL_INST}.MinAddress=\"192.168.1.10\"'" >/dev/null
  $ R "ba-cli 'Device.DHCPv4.Server.Pool.${POOL_INST}.MaxAddress=\"192.168.1.100\"'" >/dev/null

Verify valid baseline parameters are applied successfully:

  $ R "ba-cli 'Device.DHCPv4.Server.Pool.${POOL_INST}.MinAddress?' | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+'"
  192.168.1.10

  $ R "ba-cli 'Device.DHCPv4.Server.Pool.${POOL_INST}.MaxAddress?' | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+'"
  192.168.1.100

# Step 2 - Verify validation fails on inverted address range (MinAddress > MaxAddress)

Attempt to set MaxAddress to a value below MinAddress (Min: 192.168.1.10, Max: 192.168.1.5):

  $ R "ba-cli 'Device.DHCPv4.Server.Pool.${POOL_INST}.MaxAddress=\"192.168.1.5\"'" 2>&1 | grep -qi 'error' && echo "REJECTED_INVALID_RANGE" || echo "ACCEPTED_INVALID_RANGE"
  REJECTED_INVALID_RANGE

Verify MaxAddress remained at its previous valid value:

  $ R "ba-cli 'Device.DHCPv4.Server.Pool.${POOL_INST}.MaxAddress?' | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+'"
  192.168.1.100

Attempt to set MinAddress to a value above MaxAddress (Min: 192.168.1.200, Max: 192.168.1.100):

  $ R "ba-cli 'Device.DHCPv4.Server.Pool.${POOL_INST}.MinAddress=\"192.168.1.200\"'" 2>&1 | grep -qi 'error' && echo "REJECTED_INVALID_RANGE" || echo "ACCEPTED_INVALID_RANGE"
  REJECTED_INVALID_RANGE

Verify MinAddress remained at its previous valid value:

  $ R "ba-cli 'Device.DHCPv4.Server.Pool.${POOL_INST}.MinAddress?' | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+'"
  192.168.1.10

# Step 3 - Verify validation fails on non-contiguous subnet mask

Attempt to set SubnetMask to a non-contiguous mask (255.0.255.0):

  $ R "ba-cli 'Device.DHCPv4.Server.Pool.${POOL_INST}.SubnetMask=\"255.0.255.0\"'" 2>&1 | grep -qi 'error' && echo "REJECTED_MALFORMED_MASK" || echo "ACCEPTED_MALFORMED_MASK"
  REJECTED_MALFORMED_MASK

Verify SubnetMask remained at its valid value:

  $ R "ba-cli 'Device.DHCPv4.Server.Pool.${POOL_INST}.SubnetMask?' | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+'"
  255.255.255.0

# Cleanup - Restore original pool state

  $ R "ba-cli 'Device.DHCPv4.Server.Pool.${POOL_INST}.MinAddress=\"${ORIG_MIN}\"'" >/dev/null
  $ R "ba-cli 'Device.DHCPv4.Server.Pool.${POOL_INST}.MaxAddress=\"${ORIG_MAX}\"'" >/dev/null
  $ R "ba-cli 'Device.DHCPv4.Server.Pool.${POOL_INST}.SubnetMask=\"${ORIG_MASK}\"'" >/dev/null