#!/usr/bin/env python3
"""Minimal HTTPS AFC server for the cram inquiry test.

Same grant payload as afc_server6_6515.py, served with the Python standard
library so the LAN client does not need fastapi or uvicorn.
"""

import argparse
import json
import ssl
from datetime import datetime, timedelta, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


def _dig(obj, *keys, default=""):
    cur = obj
    for key in keys:
        if not isinstance(cur, dict) or key not in cur:
            return default
        cur = cur[key]
    return cur if cur is not None else default


def build_response(req):
    inquiry = {}
    requests = req.get("availableSpectrumInquiryRequests") if isinstance(req, dict) else None
    if isinstance(requests, list) and requests and isinstance(requests[0], dict):
        inquiry = requests[0]

    request_id = inquiry.get("requestId") or "cram-afc-1"
    version = req.get("version") if isinstance(req, dict) else None
    version = version or "1.4"
    ruleset_id = _dig(
        inquiry,
        "deviceDescriptor",
        "certificationId",
        default=None,
    )
    if isinstance(ruleset_id, list) and ruleset_id and isinstance(ruleset_id[0], dict):
        ruleset_id = ruleset_id[0].get("rulesetId") or "US_47_CFR_PART_15_SUBPART_E"
    elif not isinstance(ruleset_id, str) or not ruleset_id:
        ruleset_id = "US_47_CFR_PART_15_SUBPART_E"

    expiry_time = (datetime.now(timezone.utc) + timedelta(minutes=30)).strftime("%Y-%m-%dT%H:%M:%SZ")

    return {
        "availableSpectrumInquiryResponses": [
            {
                "response": {
                    "responseCode": 0,
                    "shortDescription": "SUCCESS",
                },
                "availableFrequencyInfo": [
                    {
                        "frequencyRange": {"highFrequency": 6205, "lowFrequency": 6185},
                        "maxPsd": 16.5,
                    },
                    {
                        "frequencyRange": {"highFrequency": 6425, "lowFrequency": 6405},
                        "maxPsd": 18.2,
                    },
                ],
                "availableChannelInfo": [
                    {
                        "channelCfi": [49, 53, 57, 61, 65, 69, 73, 77, 81, 85, 89, 93],
                        "globalOperatingClass": 131,
                        "maxEirp": [29, 21, 22, 25, 31, 34, 28, 22, 29, 25, 23, 31],
                    },
                    {
                        "channelCfi": [51, 59, 67, 75, 83, 91],
                        "globalOperatingClass": 132,
                        "maxEirp": [24, 25, 34, 25, 28, 26],
                    },
                    {
                        "channelCfi": [55, 71, 87],
                        "globalOperatingClass": 133,
                        "maxEirp": [27, 28, 29],
                    },
                ],
                "requestId": request_id,
                "availabilityExpireTime": expiry_time,
                "rulesetId": ruleset_id,
            }
        ],
        "version": version,
    }


class AfcHandler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, fmt, *args):
        # One line the cram test can grep. BaseHTTPRequestHandler writes to stderr.
        print("afc-http %s %s" % (self.command, self.path), flush=True)
        super().log_message(fmt, *args)

    def _send(self, code, payload):
        body = payload.encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        self._send(200, json.dumps({"status": "AFC server running"}))

    def do_POST(self):
        length = int(self.headers.get("Content-Length", "0") or "0")
        raw = self.rfile.read(length) if length else b"{}"
        try:
            req = json.loads(raw.decode("utf-8") or "{}")
        except json.JSONDecodeError:
            req = {}
        request_id = ""
        requests = req.get("availableSpectrumInquiryRequests") if isinstance(req, dict) else None
        if isinstance(requests, list) and requests and isinstance(requests[0], dict):
            request_id = requests[0].get("requestId", "")
        print("afc-inquiry-bytes %d requestId=%s" % (len(raw), request_id), flush=True)
        self._send(200, json.dumps(build_response(req)))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--host", default="0.0.0.0")
    parser.add_argument("--port", type=int, default=8443)
    parser.add_argument("--cert", required=True)
    parser.add_argument("--key", required=True)
    args = parser.parse_args()

    httpd = ThreadingHTTPServer((args.host, args.port), AfcHandler)
    ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    ctx.minimum_version = ssl.TLSVersion.TLSv1_2
    ctx.load_cert_chain(args.cert, args.key)
    httpd.socket = ctx.wrap_socket(httpd.socket, server_side=True)
    print("afc-server-listen %s:%d" % (args.host, args.port), flush=True)
    httpd.serve_forever()


if __name__ == "__main__":
    main()
