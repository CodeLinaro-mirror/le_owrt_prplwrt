#!/usr/bin/env python3
"""
Minimal DHCPv4 probe for Cram:
- Sends DHCPDISCOVER with configurable Parameter Request List (PRL)
- Sends DHCPREQUEST using the offered address and server identifier
- Retransmits unanswered DHCPDISCOVER/DHCPREQUEST (--retries)
- Prints CLIENT_MAC=<mac> then RECEIVED_TAGS=1,3,6,...
- Optional: custom MAC (--chaddr) and hostname option 12 (--hostname)
- Errors are reported on stdout, packet dumps (--debug) on stderr
"""

import argparse
import random
import sys

from scapy.all import BOOTP, DHCP, Ether, IP, UDP, conf, sendp, srp1  # type: ignore
from scapy.layers.dhcp import DHCPRevOptions  # type: ignore


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("--iface", required=True, help="Interface used to send/receive DHCP")
    parser.add_argument("--request-options", default="", help="CSV option tags in PRL, e.g. 1,3,6,15,42")
    parser.add_argument("--timeout", type=int, default=8, help="Seconds waited for a reply per attempt")
    parser.add_argument("--retries", type=int, default=2, help="Retransmissions of an unanswered request")
    parser.add_argument("--debug", action="store_true")
    parser.add_argument("--chaddr", default="", help="MAC as aa:bb:cc:dd:ee:ff (default: aa:bb:cc:dd:ee:ff)")
    parser.add_argument("--hostname", default="", help="Hostname string for DHCP option 12")
    parser.add_argument("--release", action="store_true", help="Send DHCPRELEASE after DHCPACK")
    return parser.parse_args()


def parse_prl(csv_text):
    if not csv_text.strip():
        return []
    return [int(value.strip()) for value in csv_text.split(",") if value.strip()]


def parse_chaddr(mac_str):
    if not mac_str.strip():
        return b"\xaa\xbb\xcc\xdd\xee\xff"
    try:
        octets = [int(b, 16) for b in mac_str.strip().split(":")]
    except ValueError:
        print("ERROR: invalid --chaddr value: " + mac_str)
        sys.exit(2)
    if len(octets) != 6:
        print("ERROR: --chaddr must have exactly 6 octets, got " + str(len(octets)))
        sys.exit(2)
    if any(o < 0 or o > 255 for o in octets):
        print("ERROR: --chaddr octet out of range 0-255: " + mac_str)
        sys.exit(2)
    return bytes(octets)


def extract_option_tags(dhcp_options):
    tags = []
    for opt in dhcp_options:
        if not (isinstance(opt, tuple) and len(opt) >= 1):
            continue
        name = opt[0]
        if isinstance(name, int):
            tags.append(name)
            continue
        if isinstance(name, str):
            code = DHCPRevOptions.get(name)
            if isinstance(code, int):
                tags.append(code)
            elif isinstance(code, tuple) and len(code) >= 1 and isinstance(code[0], int):
                tags.append(code[0])
    return sorted(set(tags))


def get_option_value(dhcp_options, option_name):
    for opt in dhcp_options:
        if isinstance(opt, tuple) and len(opt) >= 2 and opt[0] == option_name:
            return opt[1]
    return None


def get_message_type(dhcp_options):
    value = get_option_value(dhcp_options, "message-type")
    if isinstance(value, int):
        return value
    if isinstance(value, str):
        value_map = {
            "discover": 1, "offer": 2, "request": 3, "decline": 4,
            "ack": 5, "nak": 6, "release": 7, "inform": 8,
        }
        return value_map.get(value.lower())
    return None


def main():
    args = parse_args()
    conf.checkIPaddr = False

    xid = random.randint(1, 0xFFFFFFFF)
    prl = parse_prl(args.request_options)
    chaddr = parse_chaddr(args.chaddr)
    mac_str = args.chaddr.strip() if args.chaddr.strip() else "aa:bb:cc:dd:ee:ff"

    print("CLIENT_MAC=" + mac_str)
    if args.hostname:
        print("SENT_HOSTNAME=" + args.hostname)

    discover_options = [("message-type", "discover"), ("param_req_list", prl)]
    if args.hostname:
        discover_options.append(("hostname", args.hostname.encode()))
    discover_options.append("end")

    discover_packet = (
        Ether(dst="ff:ff:ff:ff:ff:ff")
        / IP(src="0.0.0.0", dst="255.255.255.255")
        / UDP(sport=68, dport=67)
        / BOOTP(chaddr=chaddr, xid=xid, flags=0x8000)
        / DHCP(options=discover_options)
    )

    if args.debug:
        print("--- DHCPDISCOVER sent ---", file=sys.stderr)
        print(discover_packet.show(dump=True), file=sys.stderr)

    offer = srp1(discover_packet, iface=args.iface, timeout=args.timeout,
                 retry=args.retries, verbose=False)
    if offer is None or not offer.haslayer(DHCP):
        print("ERROR: no DHCPOFFER received")
        return 2

    if args.debug:
        print("--- DHCPOFFER received ---", file=sys.stderr)
        print(offer.show(dump=True), file=sys.stderr)

    if get_message_type(offer[DHCP].options) != 2:
        print("ERROR: received DHCP response is not DHCPOFFER")
        return 2

    offered_ip = offer[BOOTP].yiaddr
    server_identifier = get_option_value(offer[DHCP].options, "server_id")

    request_options = [
        ("message-type", "request"),
        ("requested_addr", offered_ip),
        ("param_req_list", prl),
    ]
    if args.hostname:
        request_options.append(("hostname", args.hostname.encode()))
    if args.debug:
        print("DEBUG_DHCPREQUEST_PRL=" + ",".join(str(tag) for tag in prl), file=sys.stderr)
    if server_identifier is not None:
        request_options.append(("server_id", server_identifier))
    request_options.append("end")

    request_packet = (
        Ether(dst="ff:ff:ff:ff:ff:ff")
        / IP(src="0.0.0.0", dst="255.255.255.255")
        / UDP(sport=68, dport=67)
        / BOOTP(chaddr=chaddr, xid=xid, flags=0x8000)
        / DHCP(options=request_options)
    )

    if args.debug:
        print("--- DHCPREQUEST sent ---", file=sys.stderr)
        print(request_packet.show(dump=True), file=sys.stderr)

    final_reply = srp1(request_packet, iface=args.iface, timeout=args.timeout,
                       retry=args.retries, verbose=False)
    if final_reply is None or not final_reply.haslayer(DHCP):
        print("ERROR: no DHCPACK received")
        return 2

    if args.debug:
        print("--- DHCPACK received ---", file=sys.stderr)
        print(final_reply.show(dump=True), file=sys.stderr)

    message_type = get_message_type(final_reply[DHCP].options)
    if message_type == 6:
        print("ERROR: DHCPNAK received")
        return 2
    if message_type != 5:
        print("ERROR: final DHCP response is not DHCPACK")
        return 2

    tags = extract_option_tags(final_reply[DHCP].options)
    print("RECEIVED_TAGS=" + ",".join(str(tag) for tag in tags))

    if args.release:
        release_packet = (
            Ether(dst="ff:ff:ff:ff:ff:ff")
            / IP(src=offered_ip, dst=server_identifier or "255.255.255.255")
            / UDP(sport=68, dport=67)
            / BOOTP(chaddr=chaddr, xid=xid, ciaddr=offered_ip)
            / DHCP(options=[
                ("message-type", "release"),
                ("server_id", server_identifier),
                "end",
            ])
        )
        if args.debug:
            print("--- DHCPRELEASE sent ---", file=sys.stderr)
            print(release_packet.show(dump=True), file=sys.stderr)
        sendp(release_packet, iface=args.iface, verbose=False)
        print("RELEASED=" + offered_ip)

    return 0


if __name__ == "__main__":
    sys.exit(main())
