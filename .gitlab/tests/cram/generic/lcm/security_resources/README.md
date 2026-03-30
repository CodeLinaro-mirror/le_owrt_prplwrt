# LCM Security Test Resources

This directory contains resources required for the LCM security test (`040-lcm-security.t`). The test validates secure container deployment using various authentication methods, certificate validation, and image signature verification. The resources are organized into device configuration files and signature server simulation tools.

## Table of Contents

- [Device Configuration Files](#device-configuration-files)
  - [File Descriptions](#file-descriptions)
    - [Certificate Authority (CA) Files](#certificate-authority-ca-files)
    - [ca_bundle.crt](#ca_bundlecrt)
    - [Image Signature Files](#image-signature-files)
    - [Configuration Files](#configuration-files)
- [Signature Server Simulation Tool](#signature-server-simulation-tool)
  - [https_signature_server.py](#https_signature_serverpy)
  - [Certificate Authority (CA)](#certificate-authority-ca-1)
  - [Server Certificates](#server-certificates)

## Device Configuration Files

Files required for setting up security infrastructure on the device:

| File | Type | Purpose |
|------|------|---------|
| `lcm_test_root_ca_client.crt` | CA Certificate | Root CA for signing client certificates |
| `lcm_test_root_ca_client.key` | CA Private Key | Private key for client certificate CA |
| `ca_bundle.crt` | CA Bundle | Common trusted CAs for signature/registry validation |
| `sign_test_pub.asc` | GPG Public Key | Public key for verifying container image signatures |
| `signature_lcm-test-x86-64_prplos-v1` | Image Signature | GPG signature for x86-64 container images |
| `signature_lcm-test-ipq807x-generic_prplos-v1` | Image Signature | GPG signature for ipq807x container images |


### File Descriptions

#### Certificate Authority (CA) Files

##### `lcm_test_root_ca_client.crt` / `lcm_test_root_ca_client.key`
- **Role**: Root CA for signing client certificates
- **Usage**: Used to sign the client certificate CSR generated on the device
- **Test Context**: The test generates a CSR on the device via SoftHSM, copies it to the host, signs it with this CA, and provisions the signed certificate back to the device for mTLS authentication
- **Example generation**:
```bash
openssl genrsa -out lcm_test_root_ca_client.key 3072
openssl req -new -x509 -days 3650 -key lcm_test_root_ca_client.key \
  -out lcm_test_root_ca_client.crt \
  -subj "/C=BE/ST=Brabant/L=Wijgmaal/O=SoftAtHome/OU=Test/CN=LCM Test Root CA Client"
```

#### `ca_bundle.crt`
- **Role**: CA bundle containing the most common trusted CAs
- **Usage**: Referenced in the device datamodel as `Device.Security.CABundle.[Name == "ca_bundle"]`
- **Test Context**: Used for successful signature verification when the correct CA bundle is configured
- **ODL Config**: Configured in `01_security_cram_lcm.odl` with certificate reference `Security.Certificate.[SerialNumber=="5EC3B7A6437FA4E0"]`

##### Generating CA Bundle

The `ca_bundle.crt` is typically a concatenation of multiple trusted CA certificates:

```bash
# Download common CA certificates or concatenate your own
cat /etc/ssl/certs/ca-certificates.crt > ca_bundle.crt

# Or create a custom bundle
cat lcm_servers_root_ca1.crt >> ca_bundle.crt
cat other_trusted_ca.crt >> ca_bundle.crt
```


#### Image Signature Files

##### `sign_test_pub.asc`
- **Role**: GPG public key for verifying container image signatures
- **Key Details**: "Test signing key <lcm_test_signing@softathome.com>"
- **Usage**: Installed to `/usr/share/rlyeh/keys/` on the device
- **Test Context**: Rlyeh uses this public key to verify signatures downloaded from the signature server
- **Format**: ASCII-armored PGP public key block
- **Example generation**:
```bash
# Generate GPG key pair
gpg --quick-generate-key --pinentry-mode=loopback --passphrase "" "LCM signing key <lcm_test_signing@softathome.com>" rsa2048 sign never

# Export public key
gpg --armor --export lcm_test_signing@softathome.com > sign_test_pub.asc
```

##### Image Signature Files (by Architecture)

**Files**: `signature_lcm-test-x86-64_prplos-v1` and `signature_lcm-test-ipq807x-generic_prplos-v1`

- **Role**: GPG-signed signature files for `lcm-test-x86-64` and `lcm-test-ipq807x-generic` container images (both version `prplos-v1`)
- **Usage**: Served by the signature server and verified against the container image manifest
- **Format**: JSON signature created by skopeo standalone-sign
- **Example Generation**:
```bash
# Download the container image using skopeo
DOCKER_URL="docker://registry.gitlab.com/prpl-foundation/prplos/prplos/prplos/lcm-test-x86-64:prplos-v1"
IMAGE_NAME="lcm-test-x86-64"
IMAGE_VERSION="prplos-v1"
DEST_DIR="/tmp/${IMAGE_NAME}_${IMAGE_VERSION}"
FINGERPRINT=$(gpg --with-colons --fingerprint lcm_test_signing@softathome.com | awk -F: '/^fpr:/ {print $10; exit}')

mkdir -p ${DEST_DIR}
skopeo copy ${DOCKER_URL} dir:${DEST_DIR}

# Sign the manifest using skopeo (requires GPG key already generated)
NO_PROTO=$(echo "$DOCKER_URL" | sed 's/^docker:\/\///')
skopeo standalone-sign ${DEST_DIR}/manifest.json ${NO_PROTO} \
  ${FINGERPRINT} --output signature_lcm-test-x86-64_prplos-v1
```
##### Verify Signature (for testing)

```bash
# Verify a signature using skopeo
skopeo standalone-verify ${DEST_DIR}/manifest.json \
  ${NO_PROTO} ${FINGERPRINT} --output signature_lcm-test-x86-64_prplos-v1
```

#### Configuration Files

##### `01_security_cram_lcm.odl`
- **Role**: ODL configuration for TR-181 security datamodel extensions
- **Usage**: Copied to `/etc/amx/tr181-security/extensions/01_cram_lcm.odl` on the device
- **Content**: Defines two CA bundle instances:
  - `ca_bundle`: Points to `/usr/share/ca-certificates/ca_bundle.crt`
  - `root_ca1`: Points to `/usr/share/ca-certificates/lcm_servers_root_ca1.crt`
- **Test Context**: Populates the `Device.Security.CABundle` datamodel with CA certificates that can be referenced by repository configurations

##### `timingila.odl`
- **Role**: Software modules configuration for the Timingila service
- **Usage**: Copied to `/etc/config/softwaremodules/odl/timingila.odl` on the device
- **Test Context**: Configures default software module configuration for the test



## Signature Server Simulation Tool

Files used by `https_signature_server.py` to simulate signature servers:

| File | Type | Purpose |
|------|------|---------|
| `lcm_servers_root_ca1.crt` | CA Certificate | Root CA for signature.server1.local.com |
| `lcm_servers_root_ca1.key` | CA Private Key | Private key for server1 CA |
| `lcm_servers_root_ca2.crt` | CA Certificate | Root CA for signature.server2.local.com (wrong CA testing) |
| `lcm_servers_root_ca2.key` | CA Private Key | Private key for server2 CA |
| `server_1.crt` | Server Certificate | TLS certificate for signature.server1.local.com |
| `server_1.key` | Server Private Key | Private key for server1 TLS |
| `server_2.crt` | Server Certificate | TLS certificate for signature.server2.local.com |
| `server_2.key` | Server Private Key | Private key for server2 TLS |

#### `https_signature_server.py`
- **Role**: Python-based HTTP/HTTPS simulation server for serving container image signatures
- **Features**:
  - Multiple authentication methods: Basic, Bearer/Token, none
  - TLS/SSL support with configurable certificates
  - mTLS (mutual TLS) support for client certificate validation
  - User-Agent header capture for testing
- **Server Configurations**:

| Port | Protocol | Authentication | Server | Notes |
|------|----------|----------------|--------|-------|
| 5443 | HTTPS | No authen | signature.server1.local.com | |
| 6443 | HTTPS | Basic | signature.server1.local.com | |
| 7443 | HTTPS | Bearer | signature.server1.local.com | |
| 8443 | HTTPS | mTLS + Bearer | signature.server1.local.com | Requires client cert |
| 8888 | HTTP | Bearer | signature.server1.local.com | Non-encrypted |
| 9443 | HTTPS | Bearer | signature.server2.local.com | Wrong CA test |
- **Usage**: Started before running the security test to serve signature files
- **Authentication Credentials**: Username/password: `admin:secret`
- **Test Context**: Simulates a production signature server with various security configurations serving files prefixed with `signature`
- **Note**: Test domains (signature.server1.local.com and signature.server2.local.com) are fake domains and must be resolved on client device (via `/etc/hosts`) to the IP address of the host where the script is run.
- **Example command**:
```bash
# Start the signature server (runs all configured ports)
python3 https_signature_server.py
```

#### Certificate Authority (CA)

##### `lcm_servers_root_ca1.crt` / `lcm_servers_root_ca1.key`
- **Role**: Root CA for signing server certificates (signature.server1.local.com)
- **Usage**: Referenced in the device datamodel as `Device.Security.CABundle.[Name == "root_ca1"]`
- **Test Context**: Used to validate HTTPS connections to signature.server1.local.com
- **ODL Config**: Configured in `01_security_cram_lcm.odl` with serial number `5C467BFB94E62AC5A899BBFFC605E0938F262832`
- **Example generation**:
```bash
openssl genrsa -out lcm_servers_root_ca1.key 3072
openssl req -new -x509 -days 3650 -key lcm_servers_root_ca1.key \
  -out lcm_servers_root_ca1.crt \
  -subj "/C=BE/ST=Brabant/L=Wijgmaal/O=SoftAtHome/OU=Test/CN=LCM Servers Root CA 1"
```

##### `lcm_servers_root_ca2.crt` / `lcm_servers_root_ca2.key`
- **Role**: Root CA for signing server certificates (signature.server2.local.com)
- **Usage**: Used for negative testing - validates that using the wrong CA bundle causes signature verification to fail
- **Test Context**: Server2 uses a different CA to test CA bundle validation failures
- **Example generation**:
```bash
openssl genrsa -out lcm_servers_root_ca2.key 3072
openssl req -new -x509 -days 3650 -key lcm_servers_root_ca2.key \
  -out lcm_servers_root_ca2.crt \
  -subj "/C=BE/ST=Brabant/L=Wijgmaal/O=SoftAtHome/OU=Test/CN=LCM Servers Root CA 2"
```

#### Server Certificates

##### `server_1.crt` / `server_1.key`
- **Role**: TLS certificate and private key for `signature.server1.local.com`
- **Usage**: Used by the HTTPS signature server running on multiple ports (5443, 6443, 7443, 8443, 9443)
- **Example generation**:
```bash
openssl genrsa -out server_1.key 2048
openssl req -new -key server_1.key -out server_1.csr \
  -subj "/C=BE/ST=Brabant/L=Wijgmaal/O=SoftAtHome/OU=Test/CN=signature.server1.local.com"
openssl x509 -req -in server_1.csr \
  -CA lcm_servers_root_ca1.crt -CAkey lcm_servers_root_ca1.key \
  -CAcreateserial -out server_1.crt -days 36500 -sha256
```

##### `server_2.crt` / `server_2.key`
- **Role**: TLS certificate and private key for `signature.server2.local.com`
- **Usage**: Used for negative CA bundle testing
- **Example generation**:
```bash
openssl genrsa -out server_2.key 2048
openssl req -new -key server_2.key -out server_2.csr \
  -subj "/C=BE/ST=Brabant/L=Wijgmaal/O=SoftAtHome/OU=Test/CN=signature.server2.local.com"
openssl x509 -req -in server_2.csr \
  -CA lcm_servers_root_ca2.crt -CAkey lcm_servers_root_ca2.key \
  -CAcreateserial -out server_2.crt -days 36500 -sha256
```