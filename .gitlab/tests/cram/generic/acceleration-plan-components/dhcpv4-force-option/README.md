# DHCPv4 Force Option Cram Test

This folder contains a Cram test and a minimal Python probe to validate DHCPv4 pool option forcing behavior.

## Covered behavior

1. If `Force=true`, the pool option is sent even when the client does **not** request it.
2. If `Force=false`, the pool option is **not** sent when the client does **not** request it.
3. If `Force=false`, the pool option is sent when the client **does** request it.

## Files

- `017-dhcpv4-force-option.t`: Cram scenario.
- `dhcpv4_option_probe.py`: Minimal DHCPv4 probe using Scapy.

## Requirements

- `python3`
- `scapy` (the Cram test exits with code 80 / skip if unavailable)
- `TESTBED_LAN_INTERFACE` environment variable available to Cram runner.

## Probe usage

```bash
python3 dhcpv4_option_probe.py --iface <interface> --request-options "1,3,6,15,42"
```

Example output:

```text
RECEIVED_TAGS=1,3,6,15,42
```
