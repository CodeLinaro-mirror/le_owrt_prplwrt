Create R alias and find the host IP:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ if [ "$DUT_BOARD" = "qemu-standard-pc-q35-ich9-2009" ]; then exit 80; fi
  $ export SERVER_IP="`ip route | grep "192.168.1.0/24" | grep -o "src [0-9.]*" | cut -d' ' -f2 | head -1`"

Start a plain (8189) and an authenticated (8190) HTTP server:

  $ mkdir -p /tmp/cram-download-fail
  $ echo dummy-firmware > /tmp/cram-download-fail/fw.swu
  $ servefile -l /tmp/cram-download-fail -p 8189 >/dev/null 2>&1 &
  $ open_pid="$!"
  $ servefile -a prpl:prpl -l /tmp/cram-download-fail -p 8190 >/dev/null 2>&1 &
  $ auth_pid="$!"
  $ sleep 1

Pick the active and inactive bank:

  $ ACTIVE=$(R "ba-cli -l 'DeviceInfo.ActiveFirmwareImage?'" | grep -oE '[0-9]+' | head -1)
  $ INACTIVE=$(R "ba-cli 'DeviceInfo.FirmwareImage.*.Status?'" | grep -oE 'FirmwareImage\.[0-9]+' | grep -oE '[0-9]+' | sort -u | grep -v "^$ACTIVE\$" | head -1)
  $ test -n "$ACTIVE" || exit 1
  $ test -n "$INACTIVE" || exit 1

Select the inactive firmware bank as test target:

  $ IMG=$INACTIVE

Check the servers answer 404 and 401:

  $ R "curl -s -o /dev/null -w '%{http_code}\n' http://$SERVER_IP:8189/nonexistent.swu"
  404
  $ R "curl -s -o /dev/null -w '%{http_code}\n' http://$SERVER_IP:8190/fw.swu"
  401

Connection refused is reported as curl error (7):

  $ R "ba-cli 'DeviceInfo.FirmwareImage.$IMG.Download(URL=\"http://$SERVER_IP:9099/fw.swu\",AutoActivate=false)'" 2>&1
  *DeviceInfo.FirmwareImage.*.Download(URL="http://*:9099/fw.swu",AutoActivate=false) (glob)
  ERROR: call (null) failed with status 1 - unknown error
  DeviceInfo.FirmwareImage.*.Download() returned (glob)
  [
      ""
  ]
  $ R "ba-cli 'DeviceInfo.FirmwareImage.$IMG.Status?'"
  *DeviceInfo.FirmwareImage.*.Status? (glob)
  DeviceInfo.FirmwareImage.*.Status="DownloadFailed" (glob)
  $ R "ba-cli 'DeviceInfo.FirmwareImage.$IMG.BootFailureLog?'"
  *DeviceInfo.FirmwareImage.*.BootFailureLog? (glob)
  DeviceInfo.FirmwareImage.*.BootFailureLog="*\(7\) Error*" (glob)
  $ R "ba-cli 'DeviceInfo.ActiveFirmwareImage?'" | grep -oE "FirmwareImage.$ACTIVE\"" | wc -l | tr -d ' '
  1

DNS resolution failure is reported as curl error (6):

  $ R "ba-cli 'DeviceInfo.FirmwareImage.$IMG.Download(URL=\"http://no-such-host.invalid/fw.swu\",AutoActivate=false)'" 2>&1
  *DeviceInfo.FirmwareImage.*.Download(URL="http://no-such-host.invalid/fw.swu",AutoActivate=false) (glob)
  ERROR: call (null) failed with status 1 - unknown error
  DeviceInfo.FirmwareImage.*.Download() returned (glob)
  [
      ""
  ]
  $ R "ba-cli 'DeviceInfo.FirmwareImage.$IMG.Status?'"
  *DeviceInfo.FirmwareImage.*.Status? (glob)
  DeviceInfo.FirmwareImage.*.Status="DownloadFailed" (glob)
  $ R "ba-cli 'DeviceInfo.FirmwareImage.$IMG.BootFailureLog?'"
  *DeviceInfo.FirmwareImage.*.BootFailureLog? (glob)
  DeviceInfo.FirmwareImage.*.BootFailureLog="*\(6\) Error*" (glob)
  $ R "ba-cli 'DeviceInfo.ActiveFirmwareImage?'" | grep -oE "FirmwareImage.$ACTIVE\"" | wc -l | tr -d ' '
  1

HTTP 401 (no credentials) is reported as 401 Unauthorized:

  $ R "ba-cli 'DeviceInfo.FirmwareImage.$IMG.Download(URL=\"http://$SERVER_IP:8190/fw.swu\",AutoActivate=false)'" 2>&1
  *DeviceInfo.FirmwareImage.*.Download(URL="http://*:8190/fw.swu",AutoActivate=false) (glob)
  ERROR: call (null) failed with status 1 - unknown error
  DeviceInfo.FirmwareImage.*.Download() returned (glob)
  [
      ""
  ]
  $ R "ba-cli 'DeviceInfo.FirmwareImage.$IMG.Status?'"
  *DeviceInfo.FirmwareImage.*.Status? (glob)
  DeviceInfo.FirmwareImage.*.Status="DownloadFailed" (glob)
  $ R "ba-cli 'DeviceInfo.FirmwareImage.$IMG.BootFailureLog?'"
  *DeviceInfo.FirmwareImage.*.BootFailureLog? (glob)
  DeviceInfo.FirmwareImage.*.BootFailureLog="*401 Unauthorized*" (glob)
  $ R "ba-cli 'DeviceInfo.ActiveFirmwareImage?'" | grep -oE "FirmwareImage.$ACTIVE\"" | wc -l | tr -d ' '
  1

HTTP 404 (missing file) is reported as 404 Not Found:

  $ R "ba-cli 'DeviceInfo.FirmwareImage.$IMG.Download(URL=\"http://$SERVER_IP:8189/nonexistent.swu\",AutoActivate=false)'" 2>&1
  *DeviceInfo.FirmwareImage.*.Download(URL="http://*:8189/nonexistent.swu",AutoActivate=false) (glob)
  ERROR: call (null) failed with status 1 - unknown error
  DeviceInfo.FirmwareImage.*.Download() returned (glob)
  [
      ""
  ]
  $ R "ba-cli 'DeviceInfo.FirmwareImage.$IMG.Status?'"
  *DeviceInfo.FirmwareImage.*.Status? (glob)
  DeviceInfo.FirmwareImage.*.Status="DownloadFailed" (glob)
  $ R "ba-cli 'DeviceInfo.FirmwareImage.$IMG.BootFailureLog?'"
  *DeviceInfo.FirmwareImage.*.BootFailureLog? (glob)
  DeviceInfo.FirmwareImage.*.BootFailureLog="*404 Not Found*" (glob)
  $ R "ba-cli 'DeviceInfo.ActiveFirmwareImage?'" | grep -oE "FirmwareImage.$ACTIVE\"" | wc -l | tr -d ' '
  1
