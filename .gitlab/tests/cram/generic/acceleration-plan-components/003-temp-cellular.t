Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

  $ R logger -t cram "Starting cellular manager test"

  $ R "ls /etc/init.d/modemmanager"

  $ R "ls /etc/init.d/mod*"

  $ R "mmcli -L"

  $ R "ubus-cli TrustedElements.?"

  $ R "ubus-cli TrustedElements.SIM.?"

  $ R "ubus-cli Cellular.Interface.?"

  $ R "ps -eaf | grep -i cellular"

