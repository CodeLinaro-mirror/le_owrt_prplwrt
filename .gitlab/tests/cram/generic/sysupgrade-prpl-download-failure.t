
Create R alias and find the host IP:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ if [ "$DUT_BOARD" = "qemu-standard-pc-q35-ich9-2009" ]; then exit 80; fi
  $ export SERVER_IP="`ip route | grep "192.168.1.0/24" | grep -o "src [0-9.]*" | cut -d' ' -f2 | head -1`"

Start a plain HTTP server (8189) over an empty directory (404 for any path):

  $ mkdir -p /tmp/cram-sysupgrade-404
  $ servefile -l /tmp/cram-sysupgrade-404 -p 8189 >/dev/null 2>&1 &
  $ open_pid="$!"
  $ sleep 1

The server answers 404 for the missing image:

  $ R "curl -s -o /dev/null -w '%{http_code}\n' http://$SERVER_IP:8189/nonexistent.swu"
  404

Pick the active and inactive bank:

  $ ACTIVE=$(R "ba-cli -l 'DeviceInfo.ActiveFirmwareImage?'" | grep -oE '[0-9]+' | head -1)
  $ INACTIVE=$(R "ba-cli 'DeviceInfo.FirmwareImage.*.Status?'" | grep -oE 'FirmwareImage\.[0-9]+' | grep -oE '[0-9]+' | sort -u | grep -v "^$ACTIVE\$" | head -1)
  $ test -n "$ACTIVE" || exit 1
  $ test -n "$INACTIVE" || exit 1

Select the inactive firmware bank (the bank sysupgrade-prpl targets):

  $ IMG=$INACTIVE

sysupgrade-prpl accepts the URL and dispatches Download() on the inactive bank:

  $ R "sysupgrade-prpl http://$SERVER_IP:8189/nonexistent.swu" | grep -oE 'Download\(\) returned' | head -1
  Download() returned
  $ R "ba-cli 'DeviceInfo.ActiveFirmwareImage?'" | grep -oE "FirmwareImage.$ACTIVE\"" | wc -l | tr -d ' '
  1

The 404 fails the download - the inactive bank reports DownloadFailed:

  $ R "ba-cli 'DeviceInfo.FirmwareImage.$IMG.Status?'"
  *DeviceInfo.FirmwareImage.*.Status? (glob)
  DeviceInfo.FirmwareImage.*.Status="DownloadFailed" (glob)
  $ R "ba-cli 'DeviceInfo.FirmwareImage.$IMG.BootFailureLog?'"
  *DeviceInfo.FirmwareImage.*.BootFailureLog? (glob)
  DeviceInfo.FirmwareImage.*.BootFailureLog="*404 Not Found*" (glob)
  $ R "ba-cli 'DeviceInfo.ActiveFirmwareImage?'" | grep -oE "FirmwareImage.$ACTIVE\"" | wc -l | tr -d ' '
  1

sysupgrade-prpl fails if DeviceInfo data model is down:

  $ R "/etc/init.d/deviceinfo-manager stop > /dev/null 2>&1"
  $ R "sysupgrade-prpl http://$SERVER_IP:8189/nonexistent.swu 2>&1"
  Cannot determine currently unused firmware image
  [1]
  $ R "/etc/init.d/deviceinfo-manager start > /dev/null 2>&1"
# Wait for deviceinfo to start
  $ for i in $(seq 1 5); do R "ba-cli 'DeviceInfo.FirmwareImage.$ACTIVE.Status?'" | grep -qF '="Active"' && break; sleep 2; done
