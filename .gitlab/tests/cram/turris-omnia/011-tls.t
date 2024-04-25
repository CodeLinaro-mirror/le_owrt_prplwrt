Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Check that there is just single TLS library OpenSSL:

  $ R "opkg list-installed" | grep -E '(openssl|mbedtls|wolfssl)' | sort | awk -F ' - ' '{print $1}'
  hostapd.*openssl (re)
  libopenssl-conf
  libopenssl-legacy
  libopenssl3
  libustream-openssl.* (re)
  openssl-util
  wpa-supplicant.*openssl (re)
