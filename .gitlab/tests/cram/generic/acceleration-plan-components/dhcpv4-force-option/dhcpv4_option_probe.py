#!/usr/bin/env python3
"""
Minimal DHCPv4 probe for Cram:
- Sends DHCPDISCOVER with configurable Parameter Request List (PRL)
- Prints received option tags from first DHCPOFFER as:
  RECEIVED_TAGS=1,3,6,...
"""

import argparse
import random
import sys

from scapy.all import Ether, IP, UDP, BOOTP, DHCP, srp1, conf  # type: ignore
from scapy.layers.dhcp import DHCPRevOptions  # type: ignore


def parse_args():
    p = argparse.ArgumentParser()
    p.add_argument("--iface", required=True, help="Interface used to send/receive DHCP")
    p.add_argument("--request-options", default="", help="CSV option tags in PRL, e.g. 1,3,6,15,42")
    p.add_argument("--timeout", type=int, default=8)
    return p.parse_args()


def parse_prl(csv_text):
    if not csv_text.strip():
        return []
    return [int(x.strip()) for x in csv_text.split(",") if x.strip()]


def extract_option_tags(dhcp_options):
    tags = []
    for opt in dhcp_options:
        if not (isinstance(opt, tuple) and len(opt) >= 1):
            continue

        name = opt[0]

        # scapy keeps unknown options as integer tags
        if isinstance(name, int):
            tags.append(name)
            continue

        # known options are often represented by their textual name
        if isinstance(name, str):
            code = DHCPRevOptions.get(name)
            if isinstance(code, int):
                tags.append(code)

    return sorted(set(tags))


def main():
    args = parse_args()
    conf.checkIPaddr = False

    xid = random.randint(1, 0xFFFFFFFF)
    prl = parse_prl(args.request_options)

    pkt = (
        Ether(dst="ff:ff:ff:ff:ff:ff")
        / IP(src="0.0.0.0", dst="255.255.255.255")
        / UDP(sport=68, dport=67)
        / BOOTP(chaddr=b"\xaa\xbb\xcc\xdd\xee\xff", xid=xid)
        / DHCP(options=[
            ("message-type", "discover"),
            ("param_req_list", prl),
            "end",
        ])
    )

    ans = srp1(pkt, iface=args.iface, timeout=args.timeout, verbose=False)
    if ans is None or not ans.haslayer(DHCP):
        print("ERROR: no DHCPOFFER received", file=sys.stderr)
        return 2

    options = ans[DHCP].options
    tags = extract_option_tags(options)
    print("RECEIVED_TAGS=" + ",".join(str(t) for t in tags))
    return 0


if __name__ == "__main__":
    sys.exit(main())
