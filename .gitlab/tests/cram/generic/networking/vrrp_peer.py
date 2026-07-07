#!/usr/bin/env python3
"""Send VRRPv3 advertisements from the testbed LAN until CRAM stops the peer."""

import argparse
import ipaddress
from pathlib import Path
import sys
import time

from scapy.all import Ether, IP, IPv6, conf, sendp
from scapy.layers.vrrp import VRRPv3


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--iface", required=True)
    parser.add_argument("--source", required=True, type=ipaddress.ip_address)
    parser.add_argument("--vip", required=True, type=ipaddress.ip_address, nargs="+")
    parser.add_argument("--vrid", required=True, type=int, choices=range(1, 256))
    parser.add_argument("--priority", required=True, type=int, choices=range(1, 255))
    parser.add_argument("--stop-file", required=True, type=Path)
    parser.add_argument("--timeout", type=float, default=45)
    args = parser.parse_args()
    if any(vip.version != args.source.version for vip in args.vip):
        parser.error("source and VIPs must use the same address family")

    ipv6 = args.source.version == 6
    frame = Ether(
        src=f"00:00:5e:00:{2 if ipv6 else 1:02x}:{args.vrid:02x}",
        dst="33:33:00:00:00:12" if ipv6 else "01:00:5e:00:00:12",
    )
    if ipv6:
        frame /= IPv6(src=str(args.source), dst="ff02::12", hlim=255)
    else:
        frame /= IP(src=str(args.source), dst="224.0.0.18", ttl=255)
    frame /= VRRPv3(vrid=args.vrid, priority=args.priority, adv=100,
                    addrlist=[str(vip) for vip in args.vip])

    # Keep the peer alive while slow SSH/data-model reads inspect the DUT.
    # The timeout also bounds its lifetime if the test is interrupted.
    deadline = time.monotonic() + args.timeout
    with conf.L2socket(iface=args.iface) as socket:
        while time.monotonic() < deadline:
            if args.stop_file.exists():
                return 0
            sendp(frame, socket=socket, verbose=False)
            time.sleep(1)
    print("ERROR: VRRP peer timed out before CRAM stopped it", file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main())
