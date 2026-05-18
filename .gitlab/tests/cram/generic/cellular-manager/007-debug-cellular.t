Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

  $ R logger -t cram "Starting 003-temp-cellular.t cellular manager test"

Execute commands to collect debug information for Cellular-Manager:

  $ R "echo ls /etc/init.d/modemmanager > /etc/cellular-manager.log"
  $ R "ls /etc/init.d/modemmanager >> /etc/cellular-manager.log 2>&1 || true"

  $ R "echo ls /etc/init.d/mod* >> /etc/cellular-manager.log"
  $ R "ls /etc/init.d/mod* >> /etc/cellular-manager.log 2>&1 || true"

  $ R "echo mmcli -L >> /etc/cellular-manager.log"
  $ R "mmcli -L >> /etc/cellular-manager.log 2>&1 || true"

  $ R "echo mmcli -m 0 >> /etc/cellular-manager.log"
  $ R "mmcli -m 0 >> /etc/cellular-manager.log 2>&1 || true"

  $ R "echo mmcli -m 0 -i any >> /etc/cellular-manager.log"
  $ R "mmcli -m 0 -i any >> /etc/cellular-manager.log 2>&1 || true"

  $ R "echo mmcli -m 0 --signal-get >> /etc/cellular-manager.log"
  $ R "mmcli -m 0 --signal-get >> /etc/cellular-manager.log 2>&1 || true"

  $ R "echo mmcli -m 1 >> /etc/cellular-manager.log"
  $ R "mmcli -m 1 >> /etc/cellular-manager.log 2>&1 || true"

  $ R "echo mmcli -m 1 -i any >> /etc/cellular-manager.log"
  $ R "mmcli -m 1 -i any >> /etc/cellular-manager.log 2>&1 || true"

  $ R "echo mmcli -m 0 --signal-get >> /etc/cellular-manager.log"
  $ R "mmcli -m 0 --signal-get >> /etc/cellular-manager.log 2>&1 || true"

  $ R "echo ubus-cli TrustedElements.? >> /etc/cellular-manager.log"
  $ R "ubus-cli TrustedElements.? >> /etc/cellular-manager.log 2>&1 || true"

  $ R "echo ubus-cli Cellular.? >> /etc/cellular-manager.log"
  $ R "ubus-cli Cellular.? >> /etc/cellular-manager.log 2>&1 || true"

  $ R "echo ubus-cli Device.SessionManagement.? >> /etc/cellular-manager.log"
  $ R "ubus-cli Device.SessionManagement.? >> /etc/cellular-manager.log 2>&1 || true"

  $ R logger -t cram "Completed with 003-temp-cellular.t testcase"
