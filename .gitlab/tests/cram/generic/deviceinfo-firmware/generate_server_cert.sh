#!/usr/bin/env bash

set -euo pipefail

if [ $# -ne 1 ]; then
    echo "Usage: $0 <server-ip>"
    exit 1
fi

SERVER_IP="$1"

if [ ! -f ./ca.crt ]; then
    echo "ERROR: ca.crt not found"
    exit 1
fi

if [ ! -f ./ca.key ]; then
    echo "ERROR: ca.key not found"
    exit 1
fi

echo "Generating server key..."
openssl genrsa -out ./server.key 2048

echo "Generating CSR..."
openssl req \
    -new \
    -key ./server.key \
    -out ./server.csr \
    -subj "/CN=${SERVER_IP}"

cat > ./server.ext <<EOF
subjectAltName = IP:${SERVER_IP}
extendedKeyUsage = serverAuth
keyUsage = digitalSignature, keyEncipherment
EOF

echo "Signing certificate..."

# Purposely sign the certificates from 2025 so that the device does not need
# to set it's time at boot
# The certificate will be valid until 2075, after which the tests will fail.
# OpenSSL version before 3.3 do not have -not_before, so use faketime
faketime "2025-01-01 00:00:00" openssl x509 \
    -req \
    -in ./server.csr \
    -CA ./ca.crt \
    -CAkey ./ca.key \
    -CAcreateserial \
    -out ./server.crt \
    -days 18262 \
    -sha256 \
    -extfile ./server.ext

echo
echo "Certificate generated successfully."
echo

openssl x509 -in ./server.crt -noout -subject
openssl x509 -in ./server.crt -noout -issuer
echo
openssl x509 -in ./server.crt -text -noout | grep -A1 "Subject Alternative Name"

echo
echo "Verification:"
openssl verify -CAfile ./ca.crt ./server.crt

echo
echo "Generating self-signed server certificate and key..."
faketime "2025-01-01 00:00:00" openssl req -x509 -nodes -newkey rsa:2048 \
    -keyout ./server-selfsigned.key \
    -out ./server-selfsigned.crt \
    -days 18262 \
    -subj "/CN=${SERVER_IP}" \
    -addext "subjectAltName = IP:${SERVER_IP}" \
    -sha256

echo "Self-signed certificate generated successfully."

openssl x509 -in ./server-selfsigned.crt -noout -subject
openssl x509 -in ./server-selfsigned.crt -noout -issuer
echo
openssl x509 -in ./server-selfsigned.crt -text -noout | grep -A1 "Subject Alternative Name"
