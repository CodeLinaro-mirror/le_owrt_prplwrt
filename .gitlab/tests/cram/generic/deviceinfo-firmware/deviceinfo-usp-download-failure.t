Run the test only on OSPv2 and Freedom boards (FEAT-29):

  $ [ "$DUT_BOARD" = "mxl25641-hdk-6" ] || [ "$DUT_BOARD" = "wnc-freedom" ] || exit 80

Create R alias and find the host IP; skip if usp-cli is absent:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ export SERVER_IP="`ip route | grep "192.168.1.0/24" | grep -o "src [0-9.]*" | cut -d' ' -f2 | head -1`"
  $ R "command -v usp-cli > /dev/null" || exit 1

Start a plain (8888) and an always-401 (8889) HTTP server:

  $ mkdir -p /tmp/cram-usp-dl
  $ python3 -m http.server 8888 --directory /tmp/cram-usp-dl > usp-http-$LABGRID_TARGET.log 2>&1 &
  $ open_pid="$!"
  $ python3 -c "import http.server as H
  > class A(H.BaseHTTPRequestHandler):
  >  def do_GET(s): s.send_response(401); s.send_header('Content-Length', '0'); s.end_headers()
  >  def log_message(s, *a): pass
  > H.HTTPServer(('0.0.0.0', 8889), A).serve_forever()" > usp-http401-$LABGRID_TARGET.log 2>&1 &
  $ auth_pid="$!"
  $ sleep 1

Check the servers answer 404 and 401:

  $ R "curl -s -o /dev/null -w '%{http_code}\n' http://$SERVER_IP:8888/firmware-not-found.swu"
  404
  $ R "curl -s -o /dev/null -w '%{http_code}\n' http://$SERVER_IP:8889/firmware.swu"
  401

Pick the active and inactive bank:

  $ ACTIVE=$(R "ba-cli -l 'DeviceInfo.ActiveFirmwareImage?'" | grep -oE '[0-9]+' | head -1)
  $ INACTIVE=$(R "ba-cli 'DeviceInfo.FirmwareImage.*.Status?'" | grep -oE 'FirmwareImage\.[0-9]+' | grep -oE '[0-9]+' | sort -u | grep -v "^$ACTIVE\$" | head -1)
  $ test -n "$ACTIVE" || exit 1
  $ test -n "$INACTIVE" || exit 1

Select the inactive firmware bank as test target:

  $ IMG=$INACTIVE

Without an OperationComplete subscription the async Download() is refused:

  $ R "for i in \$(usp-cli 'Device.LocalAgent.Subscription.*.ID?' | grep -F '\"cram-usp-dl\"' | grep -oE 'Subscription\.[0-9]+' | grep -oE '[0-9]+'); do usp-cli \"Device.LocalAgent.Subscription.\$i-\"; done" > /dev/null 2>&1
  $ R "usp-cli 'Device.DeviceInfo.FirmwareImage.$IMG.Download(URL=\"http://$SERVER_IP:8888/x.swu\", AutoActivate=false)'" 2>&1
  *Device.DeviceInfo.FirmwareImage.*.Download(URL="http://*:8888/x.swu", AutoActivate=false) (glob)
  ERROR: call (null) failed with status 7002 - unknown error
  Device.DeviceInfo.FirmwareImage.*.Download() returned (glob)
  [
      <NULL>,
      {
          err_code = 7002,
          err_msg = "USP_BROKER_CheckAsyncCommandIsSubscribedTo: OperationComplete subscription must be set before invoking 'Device.DeviceInfo.FirmwareImage.*.Download()'" (glob)
      }
  ]

Subscribe to OperationComplete on the Download:

  $ SUB=$(R "usp-cli 'Device.LocalAgent.Subscription.+'" | grep -oE 'Subscription\.[0-9]+' | grep -oE '[0-9]+' | head -1)
  $ R "usp-cli 'Device.LocalAgent.Subscription.$SUB.ID=\"cram-usp-dl\"'" > /dev/null
  $ R "usp-cli 'Device.LocalAgent.Subscription.$SUB.NotifType=\"OperationComplete\"'" > /dev/null
  $ R "usp-cli 'Device.LocalAgent.Subscription.$SUB.ReferenceList=\"Device.DeviceInfo.FirmwareImage.$IMG.Download()\"'" > /dev/null
  $ R "usp-cli 'Device.LocalAgent.Subscription.$SUB.Enable=true'" > /dev/null

Connection refused is reported as curl error (7):

  $ R "usp-cli 'Device.DeviceInfo.FirmwareImage.$IMG.Download(URL=\"http://$SERVER_IP:9099/x.swu\", AutoActivate=false)'" > /dev/null 2>&1
# waiting for output in a loop as usp-cli executes async RPC in non-blocking way
  $ for i in $(seq 1 20); do R "usp-cli 'Device.DeviceInfo.FirmwareImage.$IMG.Status?'" | grep -qF '"DownloadFailed"' && break; sleep 2; done
  $ R "usp-cli 'Device.DeviceInfo.FirmwareImage.$IMG.Status?'"
  *Device.DeviceInfo.FirmwareImage.*.Status? (glob)
  Device.DeviceInfo.FirmwareImage.*.Status="DownloadFailed" (glob)
  $ R "usp-cli 'Device.DeviceInfo.FirmwareImage.$IMG.BootFailureLog?'"
  *Device.DeviceInfo.FirmwareImage.*.BootFailureLog? (glob)
  Device.DeviceInfo.FirmwareImage.*.BootFailureLog="*\(7\) Error*" (glob)
  $ R "ba-cli 'DeviceInfo.ActiveFirmwareImage?'" | grep -oE "FirmwareImage.$ACTIVE\"" | wc -l | tr -d ' '
  1

DNS resolution failure is reported as curl error (6):

  $ R "usp-cli 'Device.DeviceInfo.FirmwareImage.$IMG.Download(URL=\"http://no-such-host.invalid/x.swu\", AutoActivate=false)'" > /dev/null 2>&1
# waiting for output in a loop as usp-cli executes async RPC in non-blocking way
  $ for i in $(seq 1 20); do R "usp-cli 'Device.DeviceInfo.FirmwareImage.$IMG.Status?'" | grep -qF '"DownloadFailed"' && break; sleep 2; done
  $ R "usp-cli 'Device.DeviceInfo.FirmwareImage.$IMG.Status?'"
  *Device.DeviceInfo.FirmwareImage.*.Status? (glob)
  Device.DeviceInfo.FirmwareImage.*.Status="DownloadFailed" (glob)
  $ R "usp-cli 'Device.DeviceInfo.FirmwareImage.$IMG.BootFailureLog?'"
  *Device.DeviceInfo.FirmwareImage.*.BootFailureLog? (glob)
  Device.DeviceInfo.FirmwareImage.*.BootFailureLog="*\(6\) Error*" (glob)
  $ R "ba-cli 'DeviceInfo.ActiveFirmwareImage?'" | grep -oE "FirmwareImage.$ACTIVE\"" | wc -l | tr -d ' '
  1

HTTP 401 (no credentials) is reported as 401 Unauthorized:

  $ R "usp-cli 'Device.DeviceInfo.FirmwareImage.$IMG.Download(URL=\"http://$SERVER_IP:8889/firmware.swu\", AutoActivate=false)'" > /dev/null 2>&1
# waiting for output in a loop as usp-cli executes async RPC in non-blocking way
  $ for i in $(seq 1 20); do R "usp-cli 'Device.DeviceInfo.FirmwareImage.$IMG.Status?'" | grep -qF '"DownloadFailed"' && break; sleep 2; done
  $ R "usp-cli 'Device.DeviceInfo.FirmwareImage.$IMG.Status?'"
  *Device.DeviceInfo.FirmwareImage.*.Status? (glob)
  Device.DeviceInfo.FirmwareImage.*.Status="DownloadFailed" (glob)
  $ R "usp-cli 'Device.DeviceInfo.FirmwareImage.$IMG.BootFailureLog?'"
  *Device.DeviceInfo.FirmwareImage.*.BootFailureLog? (glob)
  Device.DeviceInfo.FirmwareImage.*.BootFailureLog="*401 Unauthorized*" (glob)
  $ R "ba-cli 'DeviceInfo.ActiveFirmwareImage?'" | grep -oE "FirmwareImage.$ACTIVE\"" | wc -l | tr -d ' '
  1

HTTP 404 (missing file) is reported as DownloadFailed with 404 Not Found:

  $ R "usp-cli 'Device.DeviceInfo.FirmwareImage.$IMG.Download(URL=\"http://$SERVER_IP:8888/firmware-not-found.swu\", AutoActivate=false)'" > /dev/null 2>&1
# waiting for output in a loop as usp-cli executes async RPC in non-blocking way
  $ for i in $(seq 1 20); do R "usp-cli 'Device.DeviceInfo.FirmwareImage.$IMG.Status?'" | grep -qF '"DownloadFailed"' && break; sleep 2; done
  $ R "usp-cli 'Device.DeviceInfo.FirmwareImage.$IMG.Status?'"
  *Device.DeviceInfo.FirmwareImage.*.Status? (glob)
  Device.DeviceInfo.FirmwareImage.*.Status="DownloadFailed" (glob)
  $ R "usp-cli 'Device.DeviceInfo.FirmwareImage.$IMG.BootFailureLog?'"
  *Device.DeviceInfo.FirmwareImage.*.BootFailureLog? (glob)
  Device.DeviceInfo.FirmwareImage.*.BootFailureLog="*404 Not Found*" (glob)
  $ R "ba-cli 'DeviceInfo.ActiveFirmwareImage?'" | grep -oE "FirmwareImage.$ACTIVE\"" | wc -l | tr -d ' '
  1