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

# Fixed validity window: start 2025 so devices don't need to set their
# clock at boot; valid until 2075 so tests keep passing for decades.
STARTDATE="20250101000000Z"
ENDDATE="20750101000000Z"

# --- Minimal CA database, used only to drive `openssl ca` for explicit
# --- notBefore/notAfter dates (no faketime needed).
CADB_DIR="./ca_db"
mkdir -p "${CADB_DIR}"
[ -f "${CADB_DIR}/index.txt" ] || touch "${CADB_DIR}/index.txt"
[ -f "${CADB_DIR}/serial" ] || echo 1000 > "${CADB_DIR}/serial"
# Allow re-running this script for the same SERVER_IP without the
# "already a certificate for /CN=..." duplicate-subject error.
echo "unique_subject = no" > "${CADB_DIR}/index.txt.attr"

cat > ./ca.cnf <<EOF
[ca]
default_ca = my_ca

[my_ca]
dir             = ${CADB_DIR}
database        = ${CADB_DIR}/index.txt
serial          = ${CADB_DIR}/serial
new_certs_dir   = ${CADB_DIR}
certificate     = ./ca.crt
private_key     = ./ca.key
default_md      = sha256
policy          = my_policy
email_in_dn     = no
copy_extensions = copy
unique_subject  = no

[my_policy]
commonName = supplied
EOF

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
openssl ca \
    -config ./ca.cnf \
    -in ./server.csr \
    -out ./server.crt \
    -extfile ./server.ext \
    -startdate "${STARTDATE}" \
    -enddate "${ENDDATE}" \
    -notext -batch

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
openssl genrsa -out ./server-selfsigned.key 2048

openssl req \
    -new \
    -key ./server-selfsigned.key \
    -out ./server-selfsigned.csr \
    -subj "/CN=${SERVER_IP}"

cat > ./server-selfsigned.ext <<EOF
subjectAltName = IP:${SERVER_IP}
extendedKeyUsage = serverAuth
keyUsage = digitalSignature, keyEncipherment
EOF

# Self-sign using the same explicit start/end dates. -selfsign uses the
# CSR's own key (via -keyfile) to sign its own cert, no CA involved.
openssl ca \
    -config ./ca.cnf \
    -selfsign \
    -in ./server-selfsigned.csr \
    -keyfile ./server-selfsigned.key \
    -out ./server-selfsigned.crt \
    -extfile ./server-selfsigned.ext \
    -startdate "${STARTDATE}" \
    -enddate "${ENDDATE}" \
    -notext -batch

echo "Self-signed certificate generated successfully."

openssl x509 -in ./server-selfsigned.crt -noout -subject
openssl x509 -in ./server-selfsigned.crt -noout -issuer
echo
openssl x509 -in ./server-selfsigned.crt -text -noout | grep -A1 "Subject Alternative Name"
