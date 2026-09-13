End-to-end IPsec tunnel test with certificate authentication (IKEv2 +
ESP). The remote peer runs a dedicated charon instance inside a network
namespace on the DUT: ip-full's netns exec provides a private mount
namespace, so /var/run is remounted as tmpfs to isolate the peer charon
(pid file, vici socket) from the CPE charon instance.

Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

  $ R logger -t cram "Starting IPsec E2E test"

Create the peer network namespace with a veth link emulating the WAN:

  $ R "(ip netns add ipsecpeer; \
  >     ip link add veth-ips type veth peer name veth-ipsp; \
  >     ip link set veth-ipsp netns ipsecpeer; \
  >     ip addr add 192.168.79.1/24 dev veth-ips; \
  >     ip link set veth-ips up; \
  >     ip netns exec ipsecpeer ip addr add 192.168.79.2/24 dev veth-ipsp; \
  >     ip netns exec ipsecpeer ip addr add 10.30.0.1/24 dev veth-ipsp; \
  >     ip netns exec ipsecpeer ip link set veth-ipsp up; \
  >     ip netns exec ipsecpeer ip link set lo up) > /dev/null 2>&1"

Generate the certificates. IKEv2RemoteAuthenticationMethod designates the
authority the peer is validated against, so the peer needs an end entity
certificate issued by the imported certificate: a self-signed certificate
is never its own issuer and is rejected by the constraint check. The CPE
authenticates with a self-signed certificate, pinned by the peer. The CA key
and serial stay outside the swanctl tree, which is loaded wholesale and fails
on any file in it that is not a certificate. Issuing the peer certificate runs
without the system openssl.cnf: it enables the pkcs11 engine for softhsm, and
an enabled engine makes signing with an on-disk CA key fail on OpenSSL 3 with
"digital envelope routines:default_check:command not supported".

  $ R "(mkdir -p /root/certs /etc/config/autocert /tmp/ipsecpeer/swanctl/x509 /tmp/ipsecpeer/swanctl/x509ca /tmp/ipsecpeer/swanctl/private; \
  >     openssl req -x509 -newkey rsa:2048 -nodes -days 30 \
  >         -keyout /root/certs/tr181-ipsec.pem \
  >         -out /etc/config/autocert/tr181-ipsec.pem \
  >         -subj '/CN=tr181-ipsec@prplos.test'; \
  >     openssl req -x509 -newkey rsa:2048 -nodes -days 30 \
  >         -keyout /tmp/ipsecpeer/ca-key.pem \
  >         -out /tmp/ipsecpeer/ca-cert.pem \
  >         -subj '/CN=ipsec-peer-ca@prplos.test'; \
  >     openssl req -new -newkey rsa:2048 -nodes \
  >         -keyout /tmp/ipsecpeer/swanctl/private/peer-key.pem \
  >         -out /tmp/ipsecpeer/peer-csr.pem \
  >         -subj '/CN=ipsec-peer@prplos.test'; \
  >     OPENSSL_CONF=/dev/null openssl x509 -req -days 30 -sha256 \
  >         -CAserial /tmp/ipsecpeer/ca-cert.srl -CAcreateserial \
  >         -in /tmp/ipsecpeer/peer-csr.pem \
  >         -CA /tmp/ipsecpeer/ca-cert.pem \
  >         -CAkey /tmp/ipsecpeer/ca-key.pem \
  >         -out /tmp/ipsecpeer/swanctl/x509/peer-cert.pem; \
  >     cp /etc/config/autocert/tr181-ipsec.pem /tmp/ipsecpeer/swanctl/x509/cpe-cert.pem; \
  >     cp /tmp/ipsecpeer/ca-cert.pem /tmp/ipsecpeer/swanctl/x509ca/peer-ca.pem; \
  >     cp /tmp/ipsecpeer/ca-cert.pem /etc/config/autocert/ipsec-peer.pem) > /dev/null 2>&1"

Import the certificates into the Security data model:

  $ R "/etc/init.d/tr181-security restart > /dev/null 2>&1"
  $ sleep 3
  $ CPECERTIDX=$(R "ba-cli 'Security.Certificate.[CAFileName == \"tr181-ipsec.pem\"].SerialNumber?'" | sed -ne 's/^Security.Certificate.\([0-9]\+\)\..*/\1/p' | head -n 1)
  $ PEERCERTIDX=$(R "ba-cli 'Security.Certificate.[CAFileName == \"ipsec-peer.pem\"].SerialNumber?'" | sed -ne 's/^Security.Certificate.\([0-9]\+\)\..*/\1/p' | head -n 1)
  $ R "ba-cli 'Security.Certificate.$CPECERTIDX.PrivateKeyURI=\"file:///root/certs/tr181-ipsec.pem\"'" > /dev/null 2>&1
  $ test -n "$CPECERTIDX" && test -n "$PEERCERTIDX" && echo certs-imported
  certs-imported

Configure the strongSwan peer inside the namespace:

  $ R "printf '%s\n' \
  >     'charon {' \
  >     '    port = 500' \
  >     '    port_nat_t = 4500' \
  >     '}' > /tmp/ipsecpeer/strongswan.conf"
  $ R "printf '%s\n' \
  >     'connections {' \
  >     '    cpe {' \
  >     '        version = 2' \
  >     '        local_addrs = 192.168.79.2' \
  >     '        remote_addrs = 192.168.79.1' \
  >     '        proposals = aes256-sha256-modp3072' \
  >     '        local {' \
  >     '            auth = pubkey' \
  >     '            certs = peer-cert.pem' \
  >     '            id = \"CN=ipsec-peer@prplos.test\"' \
  >     '        }' \
  >     '        remote {' \
  >     '            auth = pubkey' \
  >     '            certs = cpe-cert.pem' \
  >     '            id = \"CN=tr181-ipsec@prplos.test\"' \
  >     '        }' \
  >     '        children {' \
  >     '            cpe {' \
  >     '                local_ts = 10.30.0.0/24' \
  >     '                remote_ts = 192.168.1.1/32' \
  >     '                esp_proposals = aes256-sha512' \
  >     '            }' \
  >     '        }' \
  >     '    }' \
  >     '}' > /tmp/ipsecpeer/swanctl/swanctl.conf"

Start the peer charon and load its configuration (private /var/run keeps
it separated from the CPE charon):

  $ R "ip netns exec ipsecpeer sh -c ' \
  >     mount -t tmpfs tmpfs /var/run; \
  >     STRONGSWAN_CONF=/tmp/ipsecpeer/strongswan.conf /usr/lib/ipsec/charon > /tmp/ipsecpeer/charon.log 2>&1 & \
  >     echo \$! > /tmp/ipsecpeer/charon.pid; \
  >     sleep 3; \
  >     STRONGSWAN_CONF=/tmp/ipsecpeer/strongswan.conf SWANCTL_DIR=/tmp/ipsecpeer/swanctl swanctl --load-all >> /tmp/ipsecpeer/charon.log 2>&1; \
  >     echo \$?'"
  0

Configure the CPE IPsec profile and filter through the data model:

  $ PROFIDX=$(R "ba-cli 'IPsec.Profile.+{Alias=\"e2e\",ESPAllowedEncryptionAlgorithms=\"AES-CBC\",ESPAllowedIntegrityAlgorithms=\"HMAC-SHA2-512-256\",IKEv2AllowedDiffieHellmanGroupTransforms=\"MODP-3072\",IKEv2AllowedEncryptionAlgorithms=\"AES-CBC\",IKEv2AllowedIntegrityAlgorithms=\"HMAC-SHA2-256-128\",IKEv2AuthenticationMethod=\"Device.Security.Certificate.$CPECERTIDX\",IKEv2RemoteAuthenticationMethod=\"Device.Security.Certificate.$PEERCERTIDX\",IKEv2LocalID=\"CN=tr181-ipsec@prplos.test\",IKEv2RemoteID=\"CN=ipsec-peer@prplos.test\",RemoteEndpoints=\"192.168.79.2\"}'" 2>/dev/null | sed -ne 's/^IPsec.Profile.\([0-9]\+\).$/\1/p')
  $ R "ba-cli 'IPsec.Filter.+{Alias=\"e2e\",AllInterfaces=1,DestIP=\"192.168.1.1\",SourceIP=\"10.30.0.0/24\",Enable=1,ProcessingChoice=\"Protect\",Profile=\"Device.IPsec.Profile.$PROFIDX\"}'" > /dev/null 2>&1

The plugin binds the security policies to the xfrm interface it creates for
the profile, so the remote subnet must be routed through that interface for
the traffic to be protected:

  $ IPSECDEV="ipsec$((PROFIDX - 1))"
  $ R "(ip link set $IPSECDEV up; ip route add 10.30.0.0/24 dev $IPSECDEV) > /dev/null 2>&1; true"
  $ sleep 5

Send traffic matching the filter to trigger the IKE negotiation:

  $ R "ping -I 192.168.1.1 -c 2 -W 15 10.30.0.1 > /dev/null 2>&1; true"
  $ R "ping -I 192.168.1.1 -c 3 -W 10 10.30.0.1 > /dev/null 2>&1; echo \$?"
  0

Verify the IKEv2 SA and its Child SA are up:

  $ R "ba-cli 'IPsec.IKEv2SA.*.Status?'" | grep -c '"Up"'
  1
  $ R "ba-cli 'IPsec.IKEv2SA.*.ChildSA.*.Status?'" | grep -c '"Up"'
  1

Traffic counters increase on the Child SA:

  $ R "ba-cli 'IPsec.IKEv2SA.*.ChildSA.*.Stats.PacketsSent?'" | sed -ne 's/.*PacketsSent=\([0-9]\+\).*/\1/p' | head -n 1 | awk '{print (($1 > 0) ? "packets-sent" : "no-packets")}'
  packets-sent

Cleanup:

  $ R "ba-cli 'IPsec.Filter.e2e-'" > /dev/null 2>&1
  $ R "ba-cli 'IPsec.Profile.e2e-'" > /dev/null 2>&1
  $ R "(kill \$(cat /tmp/ipsecpeer/charon.pid) 2>/dev/null; \
  >     ip route del 10.30.0.0/24 dev $IPSECDEV; \
  >     ip netns del ipsecpeer; \
  >     rm -rf /tmp/ipsecpeer; \
  >     rm -f /root/certs/tr181-ipsec.pem /etc/config/autocert/tr181-ipsec.pem /etc/config/autocert/ipsec-peer.pem; \
  >     /etc/init.d/tr181-security restart) > /dev/null 2>&1; true"

  $ R logger -t cram "IPsec E2E test finished"
