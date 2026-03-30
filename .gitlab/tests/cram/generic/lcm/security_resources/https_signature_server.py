#!/bin/python3
"""
HTTP/HTTPS signature server simulator for LCM security testing.

Serves container image signature files with multiple authentication methods (Basic, Bearer, mTLS)
and SSL/TLS configurations across different ports. Used to test signature verification workflows
in the LCM security test suite.
"""

from http.server import BaseHTTPRequestHandler, HTTPServer
import base64
import os
from urllib.parse import urlparse
import ssl
import threading
import time

# Get the directory where this script is located
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))

config1 = {
    "enable_basic": False,
    "enable_bearer": True,

    # Basic auth
    "basic_realm": "Secure File Server",
    "username": "admin",
    "password": "secret",

    # Bearer auth
    "bearer_service": "example-file-server",
    "bearer_scope": "files:read",
    "bearer_token": '{"token":"mysecrettoken","expires_in":300}',
    "bearer_token_expected": "mysecrettoken",

    "signature_dir": SCRIPT_DIR
}

config2 = {
    "enable_basic": False,
    "enable_bearer": True,

    # Basic auth
    "basic_realm": "Secure File Server",
    "username": "admin",
    "password": "secret",

    # Bearer auth
    "bearer_service": "example-file-server",
    "bearer_scope": "files:read",
    "bearer_token": '{"token":"mysecrettoken","expires_in":300}',
    "bearer_token_expected": "mysecrettoken",

    "signature_dir": SCRIPT_DIR
}

config3 = {
    "enable_basic": False,
    "enable_bearer": True,

    # Basic auth
    "basic_realm": "Secure File Server",
    "username": "admin",
    "password": "secret",

    # Bearer auth
    "bearer_service": "example-file-server",
    "bearer_scope": "files:read",
    "bearer_token": '{"token":"mysecrettoken","expires_in":300}',
    "bearer_token_expected": "mysecrettoken",

    "signature_dir": SCRIPT_DIR
}


config4 = {
    "enable_basic": True,
    "enable_bearer": False,

    # Basic auth
    "basic_realm": "Secure File Server",
    "username": "admin",
    "password": "secret",

    "signature_dir": SCRIPT_DIR
}

config5 = {
    "enable_basic": False,
    "enable_bearer": False,
    "signature_dir": SCRIPT_DIR
}

class AuthHandler(BaseHTTPRequestHandler):

    def unauthorized(self):
        self.send_response(401)

        if self.CONFIG["enable_basic"]:
            self.send_header(
                "WWW-Authenticate",
                f'Basic realm="{self.CONFIG["basic_realm"]}"'
            )

        if self.CONFIG["enable_bearer"]:
            self.send_header(
                "WWW-Authenticate",
                'Bearer '
                f'realm="{self.CONFIG["bearer_realm"]}", '
                f'service="{self.CONFIG["bearer_service"]}", '
                f'scope="{self.CONFIG["bearer_scope"]}"'
            )

        self.end_headers()

    def check_basic(self, encoded):
        try:
            decoded = base64.b64decode(encoded).decode()
            username, password = decoded.split(":", 1)
        except Exception:
            return False

        return (
            username == self.CONFIG["username"]
            and password == self.CONFIG["password"]
        )

    def check_bearer(self, token):
        return token == self.CONFIG["bearer_token_expected"]

    def authenticate(self):
        # If no authentication is enabled, allow access
        if not self.CONFIG["enable_basic"] and not self.CONFIG["enable_bearer"]:
            return True

        auth_header = self.headers.get("Authorization")

        if not auth_header:
            return False

        try:
            scheme, value = auth_header.split(" ", 1)
        except ValueError:
            return False

        if scheme == "Basic" and self.CONFIG["enable_basic"]:
            return self.check_basic(value)

        if scheme == "Bearer" and self.CONFIG["enable_bearer"]:
            return self.check_bearer(value)

        return False
     
    def serve_token(self):
        auth_header = self.headers.get("Authorization")

        if not auth_header:
            self.send_response(401)
            self.send_header("WWW-Authenticate", 'Basic realm="Token"')
            self.end_headers()
            return

        try:
            scheme, encoded = auth_header.split(" ", 1)
            if scheme != "Basic":
                raise ValueError()

            decoded = base64.b64decode(encoded).decode()
            username, password = decoded.split(":", 1)
        except Exception:
            self.send_response(400)
            self.end_headers()
            return

        # validate user
        if (
            username != self.CONFIG.get("username")
            or password != self.CONFIG.get("password")
        ):
            self.send_response(403)
            self.end_headers()
            return

        token = self.CONFIG["bearer_token"].encode()

        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(token)))
        self.end_headers()

        if self.command != "HEAD":
            self.wfile.write(token)


    def serve_signature(self, name):
        base_dir = self.CONFIG["signature_dir"]  # change from single file → directory

        # Build full path
        path = os.path.join(base_dir, name)

        if not os.path.exists(path):
            self.send_response(404)
            self.end_headers()
            return

        size = os.path.getsize(path)

        self.send_response(200)
        self.send_header("Content-Type", "application/octet-stream")
        self.send_header("Content-Length", str(size))
        self.end_headers()

        if self.command != "HEAD":
            with open(path, "rb") as f:
                self.wfile.write(f.read())


    def do_HEAD(self):
        useragent = self.headers.get("User-agent")
        if useragent:
            print(f"Request received from: {useragent}")
            with open('/tmp/lcm_http_useragent.txt', 'w') as file:
                # Write a string into the file
                file.write(f"{useragent}\n")

        parsed = urlparse(self.path)

        if parsed.path == "/token":
            self.serve_token()
            return

        if parsed.path.startswith("/signature"):
            if not self.authenticate():
                self.unauthorized()
                return

            name = parsed.path
            if name.startswith("/"):
                name = name[1:]

            self.serve_signature(name)
            return

        # Unknown path - return 404
        self.send_response(404)
        self.end_headers()

    def do_GET(self):
        useragent = self.headers.get("User-agent")
        if useragent:
            print(f"Request received from {useragent}")

        parsed = urlparse(self.path)

        if parsed.path == "/token":
            self.serve_token()
            return

        if parsed.path.startswith("/signature"):
            if not self.authenticate():
                self.unauthorized()
                return

            name = parsed.path
            if name.startswith("/"):
                name = name[1:]

            self.serve_signature(name)
            return

        # Unknown path - return 404
        self.send_response(404)
        self.end_headers()


def make_handler(config):
    class AuthHandlerWithConfig(AuthHandler):
        CONFIG = config  # attach config to the class

    return AuthHandlerWithConfig


def get_common_name(certificate):
    cert = ssl._ssl._test_decode_cert(certificate)

    subject = cert.get("subject", [])

    cn = None
    for item in subject:
        for key, value in item:
            if key == "commonName":
                cn = value

    return cn

def run_server(port, certfile, keyfile, config, clientCA=None):

    handler_class = make_handler(config)
    server = HTTPServer(("0.0.0.0", port), handler_class)

    if certfile != None:
        context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        context.load_cert_chain(certfile=certfile, keyfile=keyfile)

        if clientCA:
            # Trust the CA that issued client certificates
            context.load_verify_locations(cafile=clientCA)

            # Require client certificate (mTLS)
            context.verify_mode = ssl.CERT_REQUIRED
        else:
            # Explicitly disable client cert requirement (good practice)
            context.verify_mode = ssl.CERT_NONE

        server.socket = context.wrap_socket(server.socket, server_side=True)

        mode = "mTLS MANDATORY" if clientCA else "No mTLS"
        used_cert= f"cert is {certfile}"
        cn = get_common_name(certfile)
        config["bearer_realm"] = f"https://{cn}:{port}/token"

    auth_mode = "No authentication"
    if config["enable_basic"]:
        auth_mode = "Basic authentication"
    if config["enable_bearer"]:
        auth_mode = "Token/Bearer authentication"

    

    if certfile == None:
        print(f"HTTP server running on http://0.0.0.0:{port} ({auth_mode})")
    else:
        print(f"HTTPS server running on https://{cn}:{port} ({used_cert}, {mode} with {auth_mode})")
    server.serve_forever()


def main():
    """Start all HTTPS servers with different configurations."""
    print("Starting HTTPS signature servers...")

    # No auth server on port 5443
    threading.Thread(
        target=run_server,
        args=(5443, os.path.join(SCRIPT_DIR, "server_1.crt"), os.path.join(SCRIPT_DIR, "server_1.key"), config5),
        daemon=True
    ).start()
    time.sleep(0.2)

    # Basic auth server on port 6443
    threading.Thread(
        target=run_server,
        args=(6443, os.path.join(SCRIPT_DIR, "server_1.crt"), os.path.join(SCRIPT_DIR, "server_1.key"), config4),
        daemon=True
    ).start()
    time.sleep(0.2)

    # Bearer/Token auth server on port 7443
    threading.Thread(
        target=run_server,
        args=(7443, os.path.join(SCRIPT_DIR, "server_1.crt"), os.path.join(SCRIPT_DIR, "server_1.key"), config3),
        daemon=True
    ).start()
    time.sleep(0.2)

    # mTLS with bearer auth server on port 8443
    threading.Thread(
        target=run_server,
        args=(8443, os.path.join(SCRIPT_DIR, "server_1.crt"), os.path.join(SCRIPT_DIR, "server_1.key"),  config1, os.path.join(SCRIPT_DIR, "lcm_test_root_ca_client.crt")),
        daemon=True
    ).start()
    time.sleep(0.2)

    # Different CA server on port 9443
    threading.Thread(
        target=run_server,
        args=(9443, os.path.join(SCRIPT_DIR, "server_2.crt"), os.path.join(SCRIPT_DIR, "server_2.key"), config2),
        daemon=True
    ).start()
    time.sleep(0.2)

    # HTTP server on port 8888 with no auth
    threading.Thread(
        target=run_server,
        args=(8888, None, None, config5),
        daemon=True
    ).start()
    time.sleep(0.2)

    print("All servers started. Press Ctrl+C to stop.")

    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        print("\nShutting down servers...")


if __name__ == "__main__":
    main()

