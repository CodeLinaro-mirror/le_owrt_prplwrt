#!/usr/bin/python3
import argparse
import http.server
import ssl
import os

parser = argparse.ArgumentParser(description="Simple HTTPS server for firmware tests")
parser.add_argument("--cert", default="./server.crt", help="Path to server certificate")
parser.add_argument("--key", default="./server.key", help="Path to server private key")
parser.add_argument("--verify", default="./ca.crt", help="Path to CA certificate for client verification")
parser.add_argument("--mtls", action="store_true", help="Require client certificate verification")
args = parser.parse_args()

server_address = (os.getenv("SERVER_IP"), 8443)

httpd = http.server.HTTPServer(
    server_address,
    http.server.SimpleHTTPRequestHandler
)

ctx = ssl.create_default_context(ssl.Purpose.CLIENT_AUTH)
ctx.load_cert_chain(
    certfile=args.cert,
    keyfile=args.key
)
ctx.load_verify_locations(args.verify)
ctx.verify_mode = ssl.CERT_NONE
if args.mtls:
    ctx.verify_flags &= ~ssl.VERIFY_X509_STRICT  # Python 3.13 enables VERIFY_X509_STRICT by default, disable this
    # the root certificate fails as it does not include key usage extension
    ctx.verify_mode = ssl.CERT_REQUIRED

httpd.socket = ctx.wrap_socket(
    httpd.socket,
    server_side=True
)

print("Serving HTTPS on port 8443")
httpd.serve_forever()
