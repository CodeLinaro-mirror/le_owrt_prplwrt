#!/usr/bin/env python3
from scapy.all import *
import random
import sys
import time

conf.checkIPaddr = False
conf.verb = 0

#!/usr/bin/env python3
from scapy.all import *
import random
import sys
import time

conf.checkIPaddr = False
conf.verb = 0

def die(msg, iface=None, offered_ip=None, server_id=None, mac=None, xid=None):
    """Print error and optionally send DHCP RELEASE if we got an IP"""
    print(msg)
    if iface and offered_ip and server_id and mac and xid:
        release = (
            Ether(dst="ff:ff:ff:ff:ff:ff") /
            IP(src=offered_ip, dst=server_id) /
            UDP(sport=68, dport=67) /
            BOOTP(chaddr=mac2str(mac), xid=xid, ciaddr=offered_ip) /
            DHCP(options=[
                ("message-type", "release"),
                ("server_id", server_id),
                "end"
            ])
        )
        sendp(release, iface=iface)
        print(f"RELEASE_SENT {offered_ip}")
    sys.exit(1)

def main():
    if len(sys.argv) != 2:
        die("USAGE: dhcp_full_client.py <iface>")

    iface = sys.argv[1]
    mac = get_if_hwaddr(iface)
    xid = random.randint(1, 0xFFFFFFFF)

    test_option = ("vendor_class_id", b"cram-test-client")

    def print_dhcp(pkt):
        if DHCP in pkt:
            print(pkt.summary(), pkt[BOOTP].xid, pkt[BOOTP].yiaddr)

    sniff(iface=iface, promisc=True, timeout=5, prn=print_dhcp)

    # ---- DISCOVER ----
    discover = (
        Ether(dst="ff:ff:ff:ff:ff:ff") /
        IP(src="0.0.0.0", dst="255.255.255.255") /
        UDP(sport=68, dport=67) /
        BOOTP(chaddr=mac2str(mac), xid=xid, flags=0x8000) /
        DHCP(options=[
            ("message-type", "discover"),
            test_option,
            "end"
        ])
    )

    # Start background sniff
    offers_sniffer = AsyncSniffer(
        iface=iface,
        promisc=True,
        #filter="udp and (port 67 or 68)",
        lfilter=lambda p: DHCP in p and p[BOOTP].xid == xid
        and p[DHCP].options[0][1] == 2  # OFFER
    )
    offers_sniffer.start()

    sendp(discover, iface=iface)
    print("DISCOVER_SENT")

    # ---- WAIT FOR OFFER ----
    offers_sniffer.join(timeout=5)
    offers = offers_sniffer.results

    if not offers:
        die("NO_OFFER", iface=iface, mac=mac, xid=xid)
    offer = offers[0]
    offered_ip = offer[BOOTP].yiaddr
    server_id = next(opt[1] for opt in offer[DHCP].options if opt[0] == "server_id")
    print(f"OFFER_RECEIVED {offered_ip}")

    # ---- REQUEST ----
    request = (
        Ether(dst="ff:ff:ff:ff:ff:ff") /
        IP(src="0.0.0.0", dst="255.255.255.255") /
        UDP(sport=68, dport=67) /
        BOOTP(chaddr=mac2str(mac), xid=xid, flags=0x8000) /
        DHCP(options=[
            ("message-type", "request"),
            ("requested_addr", offered_ip),
            ("server_id", server_id),
            test_option,
            "end"
        ])
    )
    sendp(request, iface=iface)
    print("REQUEST_SENT")

    # ---- WAIT FOR ACK ----
    acks = sniff(
        iface=iface,
        timeout=5,
        filter="udp and (port 67 or 68)",
        lfilter=lambda p: DHCP in p and p[BOOTP].xid == xid
        and p[DHCP].options[0][1] == 5  # ACK
    )
    if not acks:
        die("NO_ACK", iface=iface, mac=mac, xid=xid, offered_ip=offered_ip, server_id=server_id)

    ack = acks[0]
    lease_time = next((opt[1] for opt in ack[DHCP].options if opt[0] == "lease_time"), None)
    print(f"ACK_RECEIVED {offered_ip} LEASE={lease_time}")

if __name__ == "__main__":
    main()
