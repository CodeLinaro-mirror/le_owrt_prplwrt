#!/usr/bin/env python3
"""
Advanced DHCPv6 Client Simulator
Supports single and multi-client simulation with custom options, DUID, IAID, synthetic fallback, and IA_PD.
Requires: pip install scapy
"""
import argparse
import socket
import struct
import time
import random
import subprocess
import threading
from datetime import datetime
from typing import Any, Optional, Dict, Tuple

from scapy.all import *
from scapy.layers.dhcp6 import DHCP6OptIA_PD, DHCP6OptIAPrefix, DHCP6OptStatusCode

# -------------------------------
# Custom Help Formatter & Examples
# -------------------------------
class CustomHelpFormatter(argparse.RawDescriptionHelpFormatter):
    """Custom formatter to cleanly show option defaults and usage examples."""
    pass

EXAMPLES_TEXT = """
EXAMPLES:
  # Basic single-client request with custom client name:
    sudo python3 simulate_IANA_IAPD_ipv6_clients.py --iface eth0 --client-name my-laptop

  # Request Prefix Delegation (IA_PD) with requested prefix length 56:
    sudo python3 simulate_IANA_IAPD_ipv6_clients.py --iface eth0 --pd --pd-prefix-len 56

  # Request with custom DUID and IAID (hex or decimal):
    sudo python3 simulate_IANA_IAPD_ipv6_clients.py --iface eth0 --duid "00:03:00:01:00:11:22:33:44:55" --iaid 0x12345678

  # Simulate 5 distinct clients with custom base DUID and IAID (auto-increments per client):
    sudo python3 simulate_IANA_IAPD_ipv6_clients.py --iface eth0 --count 5 --duid "00:03:00:01:00:11:22:33:44:00" --iaid 1000 --apply-lease

  # Custom option request (DNS 23, Domain List 24, FQDN 39, Vendor Class 16, Vendor Info 17) with 10s timeout:
    sudo python3 simulate_IANA_IAPD_ipv6_clients.py --iface eth0 -n node --request-options "16,17,23,24,39,56" --timeout 10

  # Release a previously leased IA_NA address (odhcpd matches on DUID + IAID only):
    sudo python3 simulate_IANA_IAPD_ipv6_clients.py --iface eth0 --duid "00:03:00:01:02:aa:bb:cc:dd:ef" --iaid 0x12345678 --release --iana

  # Release a delegated IA_PD prefix (server DUID auto-discovered via Solicit):
    sudo python3 simulate_IANA_IAPD_ipv6_clients.py --iface eth0 --duid "00:03:00:01:02:aa:bb:cc:dd:ef" --iaid 0x12345678 --release --iapd

  # Release 3 simulated clients (DUID last byte and IAID auto-incremented per client):
    sudo python3 simulate_IANA_IAPD_ipv6_clients.py --iface eth0 --count 3 --duid "00:03:00:01:02:aa:bb:cc:dd:00" --iaid 1000 --release --iana

  # Release with an explicit server DUID (skips the discovery Solicit):
    sudo python3 simulate_IANA_IAPD_ipv6_clients.py --iface eth0 --duid "00:03:00:01:02:aa:bb:cc:dd:ef" --iaid 100 --release --iana --server-duid "00:01:00:01:..."

NOTE:
  odhcpd only matches RELEASE requests on Client DUID + IAID — the requested
  address/prefix content is not checked, so --release-address is optional and
  only cosmetic (a placeholder is sent automatically if omitted).
  This script creates raw socket packets using Scapy and modifies network addresses,
  so it generally requires administrative privileges (root/sudo).
"""

# -------------------------------
# Logging Helpers
# -------------------------------
def log(msg: str, level: str = "INFO"):
    ts = datetime.now().strftime("%H:%M:%S.%f")[:-3]
    print(f"[{ts}] [{level:<5}] {msg}")

def format_duid_bytes(duid_bytes: bytes) -> str:
    """Formats raw DUID bytes into a human-readable hex string with colons."""
    return ":".join(f"{b:02x}" for b in duid_bytes)

# -------------------------------
# Utility Functions
# -------------------------------
def get_link_local_addr(iface: str) -> str:
    result = subprocess.run(["ip", "-6", "addr", "show", "dev", iface], capture_output=True, text=True)
    for line in result.stdout.splitlines():
        line = line.strip()
        if line.startswith("inet6") and "scope link" in line:
            return line.split()[1].split("/")[0]
    raise RuntimeError(f"No link-local IPv6 address found on {iface}")

def parse_duid_str(duid_str: str) -> Tuple[Any, str]:
    """Parses a hex-colon or plain hex string into a Scapy DUID structure and readable string."""
    clean_hex = duid_str.replace(":", "").replace("-", "").replace(" ", "").strip()
    try:
        duid_bytes = bytes.fromhex(clean_hex)
        return parse_server_duid(duid_bytes), format_duid_bytes(duid_bytes)
    except ValueError as e:
        raise ValueError(f"Invalid DUID hex string '{duid_str}': {e}")

def get_client_duid_iaid(
    client_idx: int, 
    custom_duid: Optional[str] = None, 
    custom_iaid: Optional[int] = None
):
    """Generates DUID and IAID using custom input or synthetic values."""
    if custom_duid:
        clean_hex = custom_duid.replace(":", "").replace("-", "").replace(" ", "").strip()
        duid_raw = bytearray.fromhex(clean_hex)
        if len(duid_raw) > 0 and client_idx > 0:
            duid_raw[-1] = (duid_raw[-1] + client_idx) & 0xFF
        duid, duid_str = parse_duid_str(format_duid_bytes(bytes(duid_raw)))
        mac_str = "Custom/Static"
    else:
        mac_bytes = bytes([
            0x02, 
            random.randint(0, 255), 
            random.randint(0, 255), 
            random.randint(0, 255), 
            random.randint(0, 255), 
            client_idx & 0xFF
        ])
        mac_str = ":".join(f"{b:02x}" for b in mac_bytes)
        duid = DUID_LL(lladdr=mac_str)
        duid_str = format_duid_bytes(bytes(duid))

    if custom_iaid is not None:
        iaid = (custom_iaid + client_idx) & 0xFFFFFFFF
    else:
        if custom_duid:
            iaid = (int.from_bytes(bytes(duid)[:4], "big") + client_idx) & 0xFFFFFFFF
        else:
            iaid = int.from_bytes(mac_bytes[-4:], byteorder="big")

    return duid, duid_str, iaid, mac_str

def apply_lease_to_iface(addr: str, iface: str, preflt: int, validlt: int) -> bool:
    try:
        cmd = ["ip", "-6", "addr", "add", f"{addr}/128", "dev", iface,
               "valid_lft", str(validlt), "preferred_lft", str(preflt)]
        result = subprocess.run(cmd, capture_output=True, text=True)
        if result.returncode != 0:
            if "File exists" in result.stderr:
                return True
            log(f"Failed to apply lease: {result.stderr.strip()}", "ERROR")
            return False
        return True
    except Exception as e:
        log(f"Exception applying lease: {e}", "ERROR")
        return False

# -------------------------------
# Raw DHCPv6 Options Parser
# -------------------------------
def parse_dhcpv6_options(data: bytes) -> Dict[int, bytes]:
    options = {}
    offset = 0
    while offset + 4 <= len(data):
        optcode = struct.unpack("!H", data[offset:offset+2])[0]
        optlen = struct.unpack("!H", data[offset+2:offset+4])[0]
        if offset + 4 + optlen > len(data):
            break
        optdata = data[offset+4:offset+4+optlen]
        options[optcode] = optdata
        offset += 4 + optlen
    return options

def parse_ia_na_payload(data: bytes) -> Optional[Dict]:
    if len(data) < 12:
        return None
    iaid = struct.unpack("!I", data[:4])[0]
    t1 = struct.unpack("!I", data[4:8])[0]
    t2 = struct.unpack("!I", data[8:12])[0]
    addresses = []
    status_code = None
    offset = 12
    while offset + 4 <= len(data):
        subcode = struct.unpack("!H", data[offset:offset+2])[0]
        sublen = struct.unpack("!H", data[offset+2:offset+4])[0]
        if offset + 4 + sublen > len(data):
            break
        subdata = data[offset+4:offset+4+sublen]
        if subcode == 5:  # IAADDR
            if len(subdata) >= 24:
                addr = socket.inet_ntop(socket.AF_INET6, subdata[:16])
                pref, valid = struct.unpack("!II", subdata[16:24])
                addresses.append((addr, pref, valid))
        elif subcode == 13: # StatusCode
            if len(subdata) >= 2:
                status_code = struct.unpack("!H", subdata[:2])[0]
        offset += 4 + sublen
    return {"iaid": iaid, "t1": t1, "t2": t2, "addresses": addresses, "status": status_code}

def parse_ia_pd_payload(data: bytes) -> Optional[Dict]:
    """Parses Option 25 (IA_PD) payload for delegated prefixes."""
    if len(data) < 12:
        return None
    iaid = struct.unpack("!I", data[:4])[0]
    t1 = struct.unpack("!I", data[4:8])[0]
    t2 = struct.unpack("!I", data[8:12])[0]
    prefixes = []
    status_code = None
    offset = 12
    while offset + 4 <= len(data):
        subcode = struct.unpack("!H", data[offset:offset+2])[0]
        sublen = struct.unpack("!H", data[offset+2:offset+4])[0]
        if offset + 4 + sublen > len(data):
            break
        subdata = data[offset+4:offset+4+sublen]
        if subcode == 26:  # IAPREFIX
            if len(subdata) >= 25:
                pref, valid = struct.unpack("!II", subdata[:8])
                plen = subdata[8]
                prefix = socket.inet_ntop(socket.AF_INET6, subdata[9:25])
                prefixes.append((prefix, plen, pref, valid))
        elif subcode == 13: # StatusCode
            if len(subdata) >= 2:
                status_code = struct.unpack("!H", subdata[:2])[0]
        offset += 4 + sublen
    return {"iaid": iaid, "t1": t1, "t2": t2, "prefixes": prefixes, "status": status_code}

def parse_server_duid(duid_bytes: bytes):
    if len(duid_bytes) < 2:
        return Raw(duid_bytes)
    duid_type = struct.unpack("!H", duid_bytes[:2])[0]
    if duid_type == 1: return DUID_LLT(duid_bytes)
    elif duid_type == 2: return DUID_EN(duid_bytes)
    elif duid_type == 3: return DUID_LL(duid_bytes)
    return Raw(duid_bytes)

def parse_vendor_info(parsed_opts: Dict[int, bytes]) -> str:
    opt_data = parsed_opts.get(16) or parsed_opts.get(17)
    if not opt_data or len(opt_data) < 4:
        return "Unknown / Not Provided"
    
    enterprise_id = struct.unpack("!I", opt_data[:4])[0]
    raw_payload = opt_data[4:]
    
    if not raw_payload:
        return f"Enterprise ID: {enterprise_id}"

    try:
        decoded = raw_payload.decode('ascii', errors='ignore').strip()
        clean_str = ''.join(c for c in decoded if c.isprintable())
        if clean_str:
            return f"Enterprise ID: {enterprise_id} ({clean_str})"
    except Exception:
        pass
        
    return f"Enterprise ID: {enterprise_id} (Hex: {raw_payload.hex()})"

# -------------------------------
# Server DUID Discovery
# -------------------------------
def discover_server_duid(iface: str, src_ll: str, duid, iaid: int, timeout: int,
                         use_pd: bool = False, pd_plen: int = 64) -> Optional[bytes]:
    """Send a Solicit and return the server DUID bytes from the first ADVERTISE (no lease created)."""
    trid = random.randint(0, 0xFFFFFF)
    found: list = [None]
    done = threading.Event()

    sol = DHCP6_Solicit(trid=trid) / DHCP6OptClientId(duid=duid)
    if use_pd:
        sol /= DHCP6OptIA_PD(iaid=iaid, T1=0, T2=0,
                             iapdopt=[DHCP6OptIAPrefix(preflft=0, validlft=0, plen=pd_plen, prefix="::")])
    else:
        sol /= DHCP6OptIA_NA(iaid=iaid, T1=0, T2=0)
    pkt = IPv6(src=src_ll, dst="ff02::1:2") / UDP(sport=546, dport=547) / sol

    def _handle(p):
        if not (UDP in p and p[UDP].sport == 547 and p[UDP].dport == 546):
            return
        raw = bytes(p[UDP].payload)
        if len(raw) < 4 or raw[0] != 2:
            return
        if struct.unpack("!I", b'\x00' + raw[1:4])[0] != trid:
            return
        opts = parse_dhcpv6_options(raw[4:])
        if 2 in opts:
            found[0] = opts[2]
            done.set()

    stop_discover = False

    def _capture():
        sniff(iface=iface, prn=_handle, store=False,
              stop_filter=lambda p: stop_discover or done.is_set())

    t = threading.Thread(target=_capture, daemon=True)
    t.start()
    time.sleep(0.25)
    sendp(Ether(dst="33:33:00:01:00:02") / pkt, iface=iface, verbose=False)
    done.wait(timeout=timeout)
    stop_discover = True
    t.join(timeout=1.0)
    return found[0]

# -------------------------------
# Exchange Function
# -------------------------------
def dhcpv6_exchange(iface, src_ll, duid, duid_str, iaid, req_opts, timeout, apply_lease, client_id, client_name, use_pd=False, pd_plen=64):
    trid = random.randint(0, 0xFFFFFF)
    log(f"Client {client_id} ({client_name}): Starting exchange (TRID: {trid:#x})")
    
    opts = DHCP6OptOptReq(reqopts=req_opts) / DHCP6OptClientFQDN(fqdn=client_name)
    
    solicit_payload = DHCP6_Solicit(trid=trid) / DHCP6OptClientId(duid=duid)
    
    if use_pd:
        ia_pd = DHCP6OptIA_PD(
            iaid=iaid, T1=0, T2=0,
            iapdopt=[DHCP6OptIAPrefix(preflft=0, validlft=0, plen=pd_plen, prefix="::")]
        )
        solicit_payload /= ia_pd
    else:
        ia_na = DHCP6OptIA_NA(iaid=iaid, T1=0, T2=0)
        solicit_payload /= ia_na
        
    solicit_payload /= opts
    
    solicit = IPv6(src=src_ll, dst="ff02::1:2") / UDP(sport=546, dport=547) / solicit_payload
    
    result = {
        "client_id": client_id, "client_name": client_name, "trid": trid,
        "client_duid": duid_str, "iaid": iaid, "server_duid": None,
        "advertise_received": False, "reply_received": False,
        "leased_addresses": [], "applied": [], "server_vendor": "Unknown"
    }
    context = {"server_duid": None}
    done = threading.Event()
    
    def handle_packet(pkt):
        if not (UDP in pkt and pkt[UDP].sport == 547 and pkt[UDP].dport == 546):
            return
        raw = bytes(pkt[UDP].payload)
        if len(raw) < 4: return
        
        msg_type = raw[0]
        pkt_trid = struct.unpack("!I", b'\x00' + raw[1:4])[0]
        if pkt_trid != trid: return
            
        parsed_opts = parse_dhcpv6_options(raw[4:])
        
        if 16 in parsed_opts or 17 in parsed_opts:
            result["server_vendor"] = parse_vendor_info(parsed_opts)
        
        if msg_type == 2 and not result["advertise_received"]:
            if 2 not in parsed_opts:
                log("Server DUID missing in ADVERTISE", "ERROR")
                done.set()
                return
            
            context["server_duid"] = parsed_opts[2]
            server_duid_str = format_duid_bytes(parsed_opts[2])
            result["server_duid"] = server_duid_str
            result["advertise_received"] = True
            
            log(f"Client {client_id}: ADVERTISE received from Server DUID: {server_duid_str}")
            
            req_payload = (
                DHCP6_Request(trid=trid) /
                DHCP6OptClientId(duid=duid) /
                DHCP6OptServerId(duid=parse_server_duid(context["server_duid"]))
            )

            if use_pd:
                ia_pd_parsed = parse_ia_pd_payload(parsed_opts[25]) if 25 in parsed_opts else None
                if ia_pd_parsed and ia_pd_parsed.get("prefixes"):
                    iapref_opts = [
                        DHCP6OptIAPrefix(prefix=p, plen=l, preflft=pref, validlft=valid)
                        for p, l, pref, valid in ia_pd_parsed["prefixes"]
                    ]
                    req_ia_pd = DHCP6OptIA_PD(
                        iaid=ia_pd_parsed["iaid"], T1=ia_pd_parsed["t1"], T2=ia_pd_parsed["t2"],
                        iapdopt=iapref_opts,
                    )
                else:
                    req_ia_pd = DHCP6OptIA_PD(
                        iaid=iaid, T1=0, T2=0,
                        iapdopt=[DHCP6OptIAPrefix(preflft=0, validlft=0, plen=pd_plen, prefix="::")]
                    )
                req_payload /= req_ia_pd
            else:
                ia_na_parsed = parse_ia_na_payload(parsed_opts[3]) if 3 in parsed_opts else None
                if ia_na_parsed and ia_na_parsed.get("addresses"):
                    iaaddr_opts = [
                        DHCP6OptIAAddress(addr=addr, preflft=pref, validlft=valid)
                        for addr, pref, valid in ia_na_parsed["addresses"]
                    ]
                    req_ia_na = DHCP6OptIA_NA(
                        iaid=ia_na_parsed["iaid"], T1=ia_na_parsed["t1"], T2=ia_na_parsed["t2"],
                        ianaopts=iaaddr_opts,
                    )
                else:
                    req_ia_na = DHCP6OptIA_NA(iaid=iaid, T1=0, T2=0)
                req_payload /= req_ia_na
                
            req_payload /= DHCP6OptOptReq(reqopts=req_opts) / DHCP6OptClientFQDN(fqdn=client_name)
            
            req = IPv6(src=src_ll, dst="ff02::1:2") / UDP(sport=546, dport=547) / req_payload
            log(f"Client {client_id}: Sending REQUEST")
            sendp(Ether(dst="33:33:00:01:00:02") / req, iface=iface, verbose=False)
            
        elif msg_type == 7 and not result["reply_received"]:
            log(f"Client {client_id}: REPLY received")
            result["reply_received"] = True
            
            if use_pd and 25 in parsed_opts:
                ia_pd_parsed = parse_ia_pd_payload(parsed_opts[25])
                if ia_pd_parsed:
                    if ia_pd_parsed.get("status") is not None and ia_pd_parsed["status"] != 0:
                        log(f"Client {client_id}: Server returned IA_PD Status Code: {ia_pd_parsed['status']}", "WARN")
                    if ia_pd_parsed.get("prefixes"):
                        result["leased_addresses"] = [
                            (f"{prefix}/{plen}", pref, valid) 
                            for prefix, plen, pref, valid in ia_pd_parsed["prefixes"]
                        ]
            elif not use_pd and 3 in parsed_opts:
                ia_na_parsed = parse_ia_na_payload(parsed_opts[3])
                if ia_na_parsed:
                    if ia_na_parsed.get("status") is not None and ia_na_parsed["status"] != 0:
                        log(f"Client {client_id}: Server returned IA_NA Status Code: {ia_na_parsed['status']}", "WARN")
                    if ia_na_parsed.get("addresses"):
                        result["leased_addresses"] = ia_na_parsed["addresses"]
                    
            if apply_lease and not use_pd:
                for addr, pref, valid in result["leased_addresses"]:
                    if apply_lease_to_iface(addr, iface, pref, valid):
                        result["applied"].append(addr)
            done.set()

    stop_sniffer = False

    def capture_packets():
        sniff(
            iface=iface, 
            prn=handle_packet, 
            store=False, 
            stop_filter=lambda p: stop_sniffer or done.is_set()
        )

    sniffer_thread = threading.Thread(target=capture_packets, daemon=True)
    sniffer_thread.start()
    time.sleep(0.25)
    
    log(f"Client {client_id}: Sending SOLICIT")
    sendp(Ether(dst="33:33:00:01:00:02") / solicit, iface=iface, verbose=False)
    
    done.wait(timeout=timeout * 2)
    
    stop_sniffer = True
    sniffer_thread.join(timeout=1.0)
        
    if not result["advertise_received"]:
        log(f"Client {client_id}: No ADVERTISE received", "WARN")
    elif not result["reply_received"]:
        log(f"Client {client_id}: No REPLY received", "WARN")
    elif not result["leased_addresses"]:
        log(f"Client {client_id}: No prefix/address assigned", "WARN")
    else:
        addrs = ", ".join(a for a, _, _ in result["leased_addresses"])
        log(f"Client {client_id}: Success! Leased: {addrs}", "OK")
        
    return result

# -------------------------------
# Release Function
# -------------------------------
def dhcpv6_release(iface: str, src_ll: str, duid, duid_str: str, iaid: int, timeout: int,
                   client_id: int, client_name: str, release_addr: str,
                   server_duid_hex: Optional[str] = None,
                   use_pd: bool = False, pd_plen: int = 64) -> bool:
    """Send DHCPv6 RELEASE (msg type 8) for a previously leased address or delegated prefix."""
    if server_duid_hex:
        clean = server_duid_hex.replace(":", "").replace("-", "").replace(" ", "")
        server_duid_bytes = bytes.fromhex(clean)
    else:
        log(f"Client {client_id}: No server DUID provided — discovering via Solicit...")
        server_duid_bytes = discover_server_duid(iface, src_ll, duid, iaid, timeout, use_pd, pd_plen)
        if server_duid_bytes is None:
            log(f"Client {client_id}: [RELEASE_FAILED] Could not discover server DUID", "ERROR")
            return False

    server_duid_obj = parse_server_duid(server_duid_bytes)
    server_duid_str = format_duid_bytes(server_duid_bytes)
    trid = random.randint(0, 0xFFFFFF)
    log(f"Client {client_id} ({client_name}): Sending RELEASE to server {server_duid_str} (TRID: {trid:#x})")

    rel = (
        DHCP6_Release(trid=trid) /
        DHCP6OptClientId(duid=duid) /
        DHCP6OptServerId(duid=server_duid_obj)
    )

    if use_pd:
        if "/" in release_addr:
            prefix, plen_str = release_addr.rsplit("/", 1)
            plen = int(plen_str)
        else:
            prefix, plen = release_addr, pd_plen
        rel /= DHCP6OptIA_PD(iaid=iaid, T1=0, T2=0,
                              iapdopt=[DHCP6OptIAPrefix(preflft=0, validlft=0, plen=plen, prefix=prefix)])
    else:
        rel /= DHCP6OptIA_NA(iaid=iaid, T1=0, T2=0,
                              ianaopts=[DHCP6OptIAAddress(addr=release_addr, preflft=0, validlft=0)])

    pkt = IPv6(src=src_ll, dst="ff02::1:2") / UDP(sport=546, dport=547) / rel
    done = threading.Event()
    success = [False]

    def _handle_reply(p):
        if not (UDP in p and p[UDP].sport == 547 and p[UDP].dport == 546):
            return
        raw = bytes(p[UDP].payload)
        if len(raw) < 4 or raw[0] != 7:
            return
        if struct.unpack("!I", b'\x00' + raw[1:4])[0] != trid:
            return
        opts = parse_dhcpv6_options(raw[4:])
        sc = 0
        if 13 in opts and len(opts[13]) >= 2:
            sc = struct.unpack("!H", opts[13][:2])[0]
        if sc == 0:
            success[0] = True
            log(f"Client {client_id}: [RELEASE_SUCCESS] {release_addr}", "OK")
        else:
            log(f"Client {client_id}: [RELEASE_FAILED] Server status code: {sc}", "WARN")
        done.set()

    stop_release = False

    def _capture():
        sniff(iface=iface, prn=_handle_reply, store=False,
              stop_filter=lambda p: stop_release or done.is_set())

    t = threading.Thread(target=_capture, daemon=True)
    t.start()
    time.sleep(0.25)
    sendp(Ether(dst="33:33:00:01:00:02") / pkt, iface=iface, verbose=False)
    done.wait(timeout=timeout)
    stop_release = True
    t.join(timeout=1.0)

    if not done.is_set():
        log(f"Client {client_id}: [RELEASE_FAILED] No REPLY from server within {timeout}s", "WARN")
    return success[0]

# -------------------------------
# Main
# -------------------------------
def parse_int_or_hex(val: str) -> int:
    try:
        return int(val, 0)
    except ValueError:
        raise argparse.ArgumentTypeError(f"Invalid IAID integer value: '{val}'")

def main():
    parser = argparse.ArgumentParser(
        description="Advanced DHCPv6 Client Simulator\nSimulates Solicit/Request exchanges with multi-client and options support.",
        epilog=EXAMPLES_TEXT,
        formatter_class=CustomHelpFormatter
    )
    
    parser.add_argument("-i", "--iface", required=True, metavar="IFACE", help="Target network interface (e.g., eth0, wlan0)")
    parser.add_argument("-n", "--client-name", default="client", metavar="NAME", help="Base name for the simulated client (default: %(default)s)")
    parser.add_argument("--duid", metavar="HEX_STRING", help="Custom Client DUID as hex bytes (e.g. 00:03:00:01:00:11:22:33:44:55)")
    parser.add_argument("--iaid", type=parse_int_or_hex, metavar="INT_OR_HEX", help="Custom IAID as integer or hex (e.g. 100 or 0x12345678)")
    parser.add_argument("-r", "--request-options", default="16,17,23,24,39", metavar="CODES", help="Comma-separated Option Request List (ORO) IDs (default: %(default)s)")
    parser.add_argument("-t", "--timeout", type=int, default=5, metavar="SEC", help="Timeout in seconds to wait for server responses (default: %(default)s)")
    parser.add_argument("-a", "--apply-lease", action="store_true", help="Automatically apply assigned IPv6 lease to the network interface using `ip addr`")
    parser.add_argument("-c", "--count", type=int, default=1, metavar="NUM", help="Number of simulated clients (generates unique synthetic DUID/IAIDs) (default: %(default)s)")
    parser.add_argument("--pd", action="store_true", help="Enable DHCPv6 Prefix Delegation (IA_PD) request instead of Address (IA_NA)")
    parser.add_argument("--pd-prefix-len", type=int, default=64, metavar="LEN", help="Requested prefix length when --pd is used (default: %(default)s)")
    parser.add_argument("--release", action="store_true",
                        help="Send DHCPv6 RELEASE (type 8) to remove existing leases; requires --iana or --iapd")
    release_type_group = parser.add_mutually_exclusive_group()
    release_type_group.add_argument("--iana", action="store_true",
                        help="Release an IA_NA (address) lease. odhcpd matches RELEASE on Client DUID + IAID only, so the address content doesn't matter")
    release_type_group.add_argument("--iapd", action="store_true",
                        help="Release an IA_PD (prefix) delegation. odhcpd matches RELEASE on Client DUID + IAID only, so the prefix content doesn't matter")
    parser.add_argument("--release-address", metavar="ADDR[,ADDR...]",
                        help="Optional comma-separated IPv6 address(es)/prefix(es) to include in the RELEASE, one per --count client (e.g. fd00::1 or fd00::/56). "
                             "Purely cosmetic: odhcpd matches on DUID+IAID only, so a placeholder is used automatically if this is omitted")
    parser.add_argument("--server-duid", metavar="HEX_STRING",
                        help="Server DUID for RELEASE (optional; auto-discovered via Solicit if omitted)")

    args = parser.parse_args()

    req_opts = [int(x.strip()) for x in args.request_options.split(",") if x.strip()]
    
    try:
        src_ll = get_link_local_addr(args.iface)
        log(f"Using link-local address: {src_ll}")
    except RuntimeError as e:
        log(str(e), "ERROR")
        exit(1)

    if args.release:
        if not (args.iana or args.iapd):
            log("--release requires --iana or --iapd to specify which lease type to release", "ERROR")
            exit(1)
        use_pd_release = args.iapd

        # odhcpd only matches RELEASE on Client DUID + IAID; the address/prefix content
        # is not checked, so it's optional and a placeholder is used when omitted.
        if args.release_address:
            release_addrs = [a.strip() for a in args.release_address.split(",") if a.strip()]
            if len(release_addrs) != args.count:
                log(f"--release-address: expected {args.count} address(es) for --count {args.count}, got {len(release_addrs)}", "ERROR")
                exit(1)
        else:
            placeholder = f"::/{args.pd_prefix_len}" if use_pd_release else "::"
            release_addrs = [placeholder] * args.count

        release_results = []
        for i in range(args.count):
            try:
                duid, duid_str, iaid, mac = get_client_duid_iaid(
                    client_idx=i, custom_duid=args.duid, custom_iaid=args.iaid
                )
            except ValueError as e:
                log(str(e), "ERROR")
                exit(1)
            curr_client_name = args.client_name if args.count == 1 else f"{args.client_name}-{i+1}"
            log(f"--- Releasing Client {i+1}/{args.count} (Name: {curr_client_name}, DUID: {duid_str}, IAID: {iaid:#x}) ---")
            ok = dhcpv6_release(
                iface=args.iface, src_ll=src_ll, duid=duid, duid_str=duid_str, iaid=iaid,
                timeout=args.timeout, client_id=i+1, client_name=curr_client_name,
                release_addr=release_addrs[i], server_duid_hex=args.server_duid,
                use_pd=use_pd_release, pd_plen=args.pd_prefix_len,
            )
            release_results.append((curr_client_name, release_addrs[i], ok))
            if i < args.count - 1:
                time.sleep(0.5)
        print("\n" + "="*80)
        print("RELEASE SUMMARY")
        print("="*80)
        for name, addr, ok in release_results:
            status = "RELEASE_SUCCESS" if ok else "RELEASE_FAILED"
            print(f"  {name}: [{status}] {addr}")
        print()
        return

    all_results = []
    for i in range(args.count):
        try:
            duid, duid_str, iaid, mac = get_client_duid_iaid(
                client_idx=i,
                custom_duid=args.duid,
                custom_iaid=args.iaid
            )
        except ValueError as e:
            log(str(e), "ERROR")
            exit(1)

        curr_client_name = args.client_name if args.count == 1 else f"{args.client_name}-{i+1}"

        log(f"--- Starting Client {i+1}/{args.count} (Name: {curr_client_name}, MAC: {mac}, DUID: {duid_str}, IAID: {iaid:#x}) ---")
        
        result = dhcpv6_exchange(
            iface=args.iface, src_ll=src_ll, duid=duid, duid_str=duid_str, iaid=iaid,
            req_opts=req_opts, timeout=args.timeout, 
            apply_lease=args.apply_lease, client_id=i+1,
            client_name=curr_client_name,
            use_pd=args.pd, pd_plen=args.pd_prefix_len
        )
        all_results.append(result)
        
        if i < args.count - 1:
            time.sleep(1)

    # Print summary
    print("\n" + "="*80)
    print("SIMULATION SUMMARY")
    print("="*80)
    for r in all_results:
        status = "SUCCESS" if r["reply_received"] and r["leased_addresses"] else "FAILED"
        addrs = ", ".join(a for a, _, _ in r["leased_addresses"]) if r["leased_addresses"] else "None"
        applied = ", ".join(r["applied"]) if r["applied"] else "None"
        srv_duid = r["server_duid"] if r["server_duid"] else "N/A"
        srv_vendor = r.get("server_vendor", "Unknown / Not Provided")
        print(f"Client {r['client_id']} ({r['client_name']}) [{status}]")
        print(f"  ├─ Client DUID: {r['client_duid']}")
        print(f"  ├─ IAID: {r['iaid']}")
        print(f"  ├─ IAID_HEX: {r['iaid']:#x}")
        print(f"  ├─ Server DUID: {srv_duid}")
        print(f"  ├─ Server Vendor: {srv_vendor}")
        print(f"  ├─ Leased Addr/Prefix: {addrs}")
        print(f"  └─ Applied: {applied}")
        print("-" * 80)
    print()

if __name__ == "__main__":
    main()
