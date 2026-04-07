Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Check that there is just single TLS library OpenSSL:

  $ R "opkg list-installed" | grep -E '(openssl|mbedtls|wolfssl|strongswan)' | sort | awk -F ' - ' '{print $1}'
  libopenssl-conf
  libopenssl.* (re)
  libustream-openssl.* (re)
  lighttpd-mod-openssl
  openssl-util
  strongswan
  strongswan-charon
  strongswan-default
  strongswan-mod-aes
  strongswan-mod-attr
  strongswan-mod-connmark
  strongswan-mod-constraints
  strongswan-mod-des
  strongswan-mod-dnskey
  strongswan-mod-fips-prf
  strongswan-mod-gmp
  strongswan-mod-hmac
  strongswan-mod-kdf
  strongswan-mod-kernel-netlink
  strongswan-mod-md5
  strongswan-mod-mgf1
  strongswan-mod-openssl
  strongswan-mod-pem
  strongswan-mod-pgp
  strongswan-mod-pkcs1
  strongswan-mod-pubkey
  strongswan-mod-random
  strongswan-mod-rc2
  strongswan-mod-resolve
  strongswan-mod-revocation
  strongswan-mod-sha1
  strongswan-mod-sha2
  strongswan-mod-socket-default
  strongswan-mod-sshkey
  strongswan-mod-updown
  strongswan-mod-vici
  strongswan-mod-x509
  strongswan-mod-xauth-generic
  strongswan-mod-xcbc
  strongswan-swanctl
