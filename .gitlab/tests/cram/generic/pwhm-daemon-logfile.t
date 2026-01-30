Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Check that pwhm log files are not empty:

  $ test -s "/var/log/wpa_supplicant"
  [1]

  $ test -s "/var/log/hostapd"
  [1]
