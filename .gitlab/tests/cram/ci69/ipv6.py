#!/usr/bin/env python3
# SPDX-FileCopyrightText: Copyright (c) 2026 prpl Foundation
# Prepared by AI Codex for CI-69.
"""SLAAC readiness, Kea control and TCP probes for the IPv6 CRAM examples."""

import argparse
import json
import ipaddress
import os
import re
from pathlib import Path
import selectors
import shlex
import signal
import socket
import subprocess
import sys
import time

PAYLOAD = b"CI-69: IPv6 TCP through the DUT\n"


def command(args, *, quiet=False, check=True):
    if not quiet:
        print("+", shlex.join(args), flush=True)
    result = subprocess.run(args, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
                            stderr=subprocess.PIPE, text=True, timeout=15)
    if not quiet or (check and result.returncode):
        print(result.stdout, end="", file=sys.stderr if quiet else sys.stdout, flush=True)
        print(result.stderr, end="", file=sys.stderr, flush=True)
    if check:
        result.check_returncode()
    return result


def stop(process):
    """Stop an owned process group, including children of unshare."""
    if process is None:
        return
    try:
        os.killpg(process.pid, signal.SIGTERM)
    except ProcessLookupError:
        pass
    try:
        process.wait(timeout=3)
    except subprocess.TimeoutExpired:
        os.killpg(process.pid, signal.SIGKILL)
        process.wait()
    if process.stdout:
        process.stdout.close()


def start_ready(args, *, hold=False):
    process = subprocess.Popen(args, stdin=subprocess.PIPE if hold else subprocess.DEVNULL, stdout=subprocess.PIPE,
                               text=True, start_new_session=True)
    try:
        with selectors.DefaultSelector() as selector:
            selector.register(process.stdout, selectors.EVENT_READ)
            if not selector.select(timeout=10):
                raise RuntimeError("child readiness timed out")
        line = process.stdout.readline().strip()
        if not line.startswith("READY"):
            raise RuntimeError(f"child did not become ready: {line!r}")
        return process, line
    except BaseException:
        stop(process)
        raise


def kea_request(path, name, arguments=None):
    """Read one complete JSON response, without assuming one recv is enough."""
    request = {"command": name}
    if arguments is not None:
        request["arguments"] = arguments
    deadline = time.monotonic() + 5
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as client:
        client.settimeout(5)
        client.connect(path)
        client.sendall(json.dumps(request).encode())
        response = bytearray()
        while len(response) < 4 * 1024 * 1024:
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                raise TimeoutError("Kea control response timed out")
            client.settimeout(remaining)
            chunk = client.recv(65536)
            if not chunk:
                raise RuntimeError("Kea closed the socket before a complete JSON response")
            response.extend(chunk)
            try:
                result = json.loads(response)
            except (ValueError, UnicodeDecodeError):
                continue
            if not isinstance(result, dict) or result.get("result") != 0:
                raise RuntimeError(f"Kea command failed: {result}")
            return result
    raise RuntimeError("Kea control response exceeds 4 MiB")


def tcp_server(address, expected_prefix=None, hold=False):
    with socket.socket(socket.AF_INET6, socket.SOCK_STREAM) as server:
        server.settimeout(10)
        server.bind((address, 0))
        server.listen(1)
        print(f"READY {server.getsockname()[1]}", flush=True)
        connection, peer = server.accept()
        with connection:
            connection.settimeout(10)
            if expected_prefix and ipaddress.ip_address(peer[0]) not in ipaddress.ip_network(expected_prefix):
                raise RuntimeError(f"TCP source {peer[0]} is outside {expected_prefix}")
            with connection.makefile("rb") as stream:
                data = stream.read(len(PAYLOAD))
            if data != PAYLOAD:
                raise RuntimeError(f"unexpected TCP request: {data!r}")
            connection.sendall(data)
            if hold:
                print(f"PEER {peer[0]} {peer[1]}", flush=True)
                connection.settimeout(30)
                connection.recv(1)


def conntrack_snapshot(port):
    """Save DUT conntrack entries, including failed probe diagnostics."""
    path = Path(os.environ["TESTBED_QEMU_ARTIFACT_ROOT"]) / f"conntrack-{port}.txt"
    try:
        result = command(shlex.split(os.environ["CRAM_REMOTE_COMMAND"]) +
                         ["if [ -r /proc/net/nf_conntrack ]; then cat /proc/net/nf_conntrack; "
                          "else conntrack -L -f ipv6 -p tcp; fi"], quiet=True, check=False)
        path.write_text(result.stdout + result.stderr)
        result.check_returncode()
        return result.stdout
    except subprocess.SubprocessError as error:
        with path.open("a") as log:
            log.write(str(error) + "\n")
        raise


def verify_conntrack(table, source, client_port, destination, server_port, translated):
    """Match both tuples of this live TCP connection, not an earlier probe."""
    expected = (source, destination, client_port, server_port,
                destination, translated, server_port, client_port)
    expected = tuple(str(ipaddress.ip_address(value)) if index % 4 < 2 else value
                     for index, value in enumerate(expected))
    for line in table.splitlines():
        fields = re.findall(r"(?:src|dst|sport|dport)=(\S+)", line)
        if len(fields) != 8:
            continue
        fields = tuple(str(ipaddress.ip_address(value)) if index % 4 < 2 else value
                       for index, value in enumerate(fields))
        if fields == expected and "ESTABLISHED" in line and "[ASSURED]" in line:
            return
    raise RuntimeError(f"no established, assured conntrack entry for {source}:{client_port} "
                       f"-> {destination}:{server_port}, reply destination {translated}")


def tcp_probe(direction, source=None, expected_prefix=None, check_conntrack=False):
    if check_conntrack and direction != "lan-to-wan":
        raise ValueError("--check-conntrack requires lan-to-wan")
    lan = [os.environ["TESTBED_LAN_CLIENT_EXEC"]]
    server_prefix, client_prefix, address = (
        ([], lan, os.environ["TESTBED_WAN_ADDRESS"]) if direction == "lan-to-wan" else
        (lan, [], os.environ["TESTBED_LAN_CLIENT_ADDRESS"]))
    if direction == "wan-to-lan" and source is None:
        source = os.environ["TESTBED_WAN_ADDRESS"]
    server_args = server_prefix + [sys.executable, str(Path(__file__).resolve()), "tcp-server", address]
    if expected_prefix:
        server_args += ["--expect-peer-prefix", expected_prefix]
    if check_conntrack:
        server_args += ["--hold"]
    server, ready = start_ready(server_args)
    port = ready.split()[1]
    client = None
    snapshot_taken = False
    try:
        client_args = client_prefix + [sys.executable, str(Path(__file__).resolve()),
                                       "tcp-client", address, port]
        if source:
            client_args += ["--source", source]
        if check_conntrack:
            client, connected = start_ready(client_args + ["--hold"], hold=True)
            _, client_address, client_port = connected.split()
            _, translated, peer_port = server.stdout.readline().split()
            table = conntrack_snapshot(port)
            snapshot_taken = True
            if peer_port != client_port:
                raise RuntimeError("NPT changed the TCP source port")
            verify_conntrack(table, client_address, client_port, address, port, translated)
            print("Conntrack established and reply tuple verified")
            client.stdin.close()
            if client.wait(timeout=5):
                raise RuntimeError("TCP client failed")
        else:
            command(client_args, quiet=True)
        if server.wait(timeout=12):
            raise RuntimeError("TCP server failed")
    finally:
        stop(client)
        stop(server)
        if check_conntrack and not snapshot_taken:
            try:
                conntrack_snapshot(port)
            except (OSError, subprocess.SubprocessError) as error:
                print(f"Conntrack snapshot failed: {error}", file=sys.stderr)
    print("TCP payload and echo verified")


def wait_lan(prefix):
    """Wait for SLAAC addressing and an RA default route in the LAN namespace.

    CRAM invokes this explicitly and sources the resulting shell exports.
    This helper does not configure either the client or the DUT.
    """
    expected = ipaddress.ip_network(prefix)
    inside = [os.environ["TESTBED_LAN_CLIENT_EXEC"]]
    interface = os.environ["TESTBED_LAN_CLIENT_INTERFACE"]
    deadline = time.monotonic() + 90
    while time.monotonic() < deadline:
        addresses = json.loads(command(inside + ["ip", "-j", "-6", "address", "show",
                                                "dev", interface], quiet=True).stdout)
        routes = json.loads(command(inside + ["ip", "-j", "-6", "route", "show", "default",
                                             "dev", interface], quiet=True).stdout)
        clients = [info for link in addresses for info in link["addr_info"]
                   if info["prefixlen"] == 64 and info.get("dynamic")
                   and ipaddress.ip_address(info["local"]) in expected
                   and not any(info.get(flag) for flag in ("tentative", "dadfailed", "deprecated"))]
        gateways = [route["gateway"] for route in routes
                    if route.get("protocol") == "ra" and "gateway" in route]
        if clients and gateways:
            client = ipaddress.IPv6Interface(clients[0]["local"] + "/64")
            for name, value in {"TESTBED_LAN_CLIENT_ADDRESS": str(client.ip),
                                "TESTBED_LAN_GATEWAY": gateways[0],
                                "TESTBED_LAN_PREFIX": str(client.network)}.items():
                print(f"export {name}={shlex.quote(value)}")
            return
        time.sleep(1)
    raise RuntimeError(f"LAN client did not receive a SLAAC address in {expected} and an RA default route")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="action", required=True)
    lan = sub.add_parser("wait-lan", help="wait for a SLAAC address and RA default route")
    lan.add_argument("--prefix", default=os.environ.get("TESTBED_PD_PREFIX"), required=False)
    kea = sub.add_parser("kea", help="send a Kea command via TESTBED_KEA_SOCKET")
    kea.add_argument("command")
    kea.add_argument("arguments", nargs="?", help="JSON object")
    tcp = sub.add_parser("tcp", help="exchange a TCP payload through the DUT")
    tcp.add_argument("direction", choices=("lan-to-wan", "wan-to-lan"))
    tcp.add_argument("--source", help="bind the client to this IPv6 address")
    tcp.add_argument("--expect-peer-prefix", help="require the server-observed source in this prefix")
    tcp.add_argument("--check-conntrack", action="store_true", help="verify the live TCP entry on the DUT")
    server = sub.add_parser("tcp-server")
    server.add_argument("address")
    server.add_argument("--expect-peer-prefix")
    server.add_argument("--hold", action="store_true")
    client = sub.add_parser("tcp-client")
    client.add_argument("address")
    client.add_argument("port", type=int)
    client.add_argument("--source")
    client.add_argument("--hold", action="store_true")
    args = parser.parse_args()
    if args.action == "wait-lan":
        if not args.prefix:
            parser.error("wait-lan needs --prefix or TESTBED_PD_PREFIX")
        wait_lan(args.prefix)
    elif args.action == "kea":
        arguments = json.loads(args.arguments) if args.arguments is not None else None
        print(json.dumps(kea_request(os.environ["TESTBED_KEA_SOCKET"], args.command, arguments)))
    elif args.action == "tcp":
        tcp_probe(args.direction, args.source, args.expect_peer_prefix, args.check_conntrack)
    elif args.action == "tcp-server":
        tcp_server(args.address, args.expect_peer_prefix, args.hold)
    else:
        with socket.socket(socket.AF_INET6, socket.SOCK_STREAM) as connection:
            connection.settimeout(10)
            if args.source:
                connection.bind((args.source, 0))
            connection.connect((args.address, args.port))
            connection.sendall(PAYLOAD)
            with connection.makefile("rb") as stream:
                data = stream.read(len(PAYLOAD))
            if data != PAYLOAD:
                raise RuntimeError(f"unexpected TCP echo: {data!r}")
            if args.hold:
                local = connection.getsockname()
                print(f"READY {local[0]} {local[1]}", flush=True)
                sys.stdin.readline()


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
        sys.exit(str(error))
