# DHCPv4 Option Probe Client (Python)

This directory contains the Python DHCPv4 probe client:

- `dhcpv4_option_probe.py`

## What the client checks

The client performs the DHCP exchange:

- `DHCPDISCOVER`
- `DHCPOFFER`
- `DHCPREQUEST`
- `DHCPACK`

Option checks are based on:

- options requested in `DHCPREQUEST` (`param_req_list`)
- options received in the final `DHCPACK`

The output is extracted from the final `DHCPACK` only.

## Requirements

- `python3`
- `scapy`
- root privileges (raw packet send/receive)

The `python3-scapy` dependency is preinstalled in the testbed image.

## Usage

```bash
sudo -E python3 dhcpv4_option_probe.py --iface <interface> --request-options "1,3,6,15,42"
```

Default output format:

```text
RECEIVED_TAGS=1,3,6,15,42
```

## Debug mode

Pass `--debug` to print the full scapy packet dump for each DHCP exchange to stderr:

```bash
sudo -E python3 dhcpv4_option_probe.py --iface <interface> --request-options "1,3,6,15,42" --debug
```

The debug output includes:

- `--- DHCPDISCOVER sent ---` — full packet before sending
- `--- DHCPOFFER received ---` — full packet from server
- `--- DHCPREQUEST sent ---` — full packet before sending
- `--- DHCPACK received ---` — full packet from server
- `DEBUG_DHCPREQUEST_PRL=<tags>` — the parameter request list sent in DHCPREQUEST (stdout)

Debug output goes to stderr so the `RECEIVED_TAGS=` line on stdout is unaffected.

## Real-environment recommendation (network delay tolerance)

Use a higher timeout when network delays are expected:

```bash
sudo -E python3 dhcpv4_option_probe.py --iface <interface> --request-options "1,3,6,15,42" --timeout 12
```

## Retransmission

`--timeout` is the time waited for a reply per attempt, `--retries` (default `2`)
is how often an unanswered `DHCPDISCOVER`/`DHCPREQUEST` is retransmitted. Writing
a `Device.DHCPv4.Server.` parameter makes `dhcpv4-manager` restart `dnsmasq`, so a
request sent right after such a write can be lost; without retransmission the probe
reports a missing reply instead of the option state it is meant to check.

## Exit codes

- `0`: success (`DHCPACK` received and parsed)
- `2`: error (`DHCPOFFER`/`DHCPACK` missing, `DHCPNAK`, or invalid DHCP response)

The `ERROR:` line explaining a non-zero exit is printed on stdout so it stays
visible in the Cram diff, which discards stderr.
