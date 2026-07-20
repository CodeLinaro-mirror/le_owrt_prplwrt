Create R alias and find the host IP:

  $ alias R="$(echo "${CRAM_REMOTE_COMMAND}" | sed 's/ ssh / ssh -n /')"
  $ alias C="${CRAM_REMOTE_COPY:-}"
  $ export SERVER_IP="`ip route | grep "192.168.1.0/24" | grep -o "src [0-9.]*" | cut -d' ' -f2 | head -1`"

Run the test only on OSPv2 and Freedom boards:

  $ [ "$DUT_BOARD" = "mxl25641-hdk-6" ] || [ "$DUT_BOARD" = "wnc-freedom" ] || exit 80

Grab the ca crt and keys from the device and copy other files (these are copied to the device from feed_prplos/security/softhsm2/files)

  $ cd $CRAMTMP
  $ C root@${TARGET_LAN_IP}:/rom/root/certs/ca.key $CRAMTMP 2>/dev/null
  $ C root@${TARGET_LAN_IP}:/usr/share/ca-certificates/test/ca.crt $CRAMTMP 2>/dev/null
  $ $TESTDIR/generate_server_cert.sh $SERVER_IP >/dev/null 2>&1

Create the dummy download, installs will fail but successfully download

  $ echo "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" > $CRAMTMP/img.bin

Start download server using self signed CA

  $ $TESTDIR/tls_server.py --cert=server-selfsigned.crt --key=server-selfsigned.key >/dev/null 2>&1 &
  $ tls_server_pid="$!"
  $ sleep 5

Pick the active and inactive bank:

  $ ACTIVE=$(R "ba-cli -l 'DeviceInfo.ActiveFirmwareImage?'" | grep -oE '[0-9]+' | head -1)
  $ INACTIVE=$(R "ba-cli 'DeviceInfo.FirmwareImage.*.Status?'" | grep -oE 'FirmwareImage\.[0-9]+' | grep -oE '[0-9]+' | sort -u | grep -v "^$ACTIVE\$" | head -1)
  $ test -n "$ACTIVE" || exit 1
  $ test -n "$INACTIVE" || exit 1

Get the alias for the prplOS test certificate and the test ca crt (one without a private key)
  $ CERT_ALIAS=$(R 'ba-cli -l "Device.Security.Certificate.[ Subject == \"/CN=prplOS.lan\" ].Alias?"' | grep '[a-zA-Z].*' | head -1)
  $ NO_PRIV_CERT_ALIAS=$(R 'ba-cli -l "Device.Security.Certificate.[ Subject == \"/CN=Test CA\" ].Alias?"' | grep '[a-zA-Z].*' | head -1)
  $ test -n "$CERT_ALIAS" || exit 1
  $ test -n "$NO_PRIV_CERT_ALIAS" || exit 1
  $ CERT="Security.Certificate.${CERT_ALIAS}."
  $ NO_PRIV_CERT="Security.Certificate.${NO_PRIV_CERT_ALIAS}."
  $ CABUNDLE="Security.CABundle.test."

Select the inactive firmware bank as test target:

  $ IMG=$INACTIVE

Ensure CADefaults are not set

  $ R 'ba-cli Device.Security.CADefaults.FirmwareImage.CABundle=""' > /dev/null;
  $ R 'ba-cli Device.Security.CADefaults.FirmwareImage.Certificate=""' > /dev/null; sleep 1

Perform download where the server has an unknown certificate, this should fail

  $ R "ba-cli 'DeviceInfo.FirmwareImage.$IMG.Download(URL=\"https://$SERVER_IP:8443/img.bin\",AutoActivate=false, CABundle = \"${CABUNDLE}\")'" 2>&1 ; sleep 2
  *DeviceInfo.FirmwareImage.*.Download(URL="https://*:8443/img.bin",AutoActivate=false, CABundle = "Security.CABundle.*.") (glob)
  ERROR: call (null) failed with status 1 - unknown error
  DeviceInfo.FirmwareImage.*.Download() returned (glob)
  [
      ""
  ]

  $ R 'logread' |  grep 'deviceinfo-manager.*Download' | tail -n 1 | awk -F'Download | - \\(' '{print $2}'
  returned with errorcode 9012

  $ R "ba-cli 'DeviceInfo.FirmwareImage.$IMG.Status?'"
  *DeviceInfo.FirmwareImage.*.Status? (glob)
  DeviceInfo.FirmwareImage.*.Status="DownloadFailed" (glob)

  $ R "ba-cli 'DeviceInfo.FirmwareImage.$IMG.BootFailureLog?'"
  *DeviceInfo.FirmwareImage.*.BootFailureLog? (glob)
  DeviceInfo.FirmwareImage.*.BootFailureLog="\(60\) Error" (glob)

Start download server with test certs

  $ kill -9 "$tls_server_pid"
  $ $TESTDIR/tls_server.py >/dev/null 2>&1 &
  $ tls_server_pid="$!"
  $ sleep 5

Perform download without CABundle set should fail

  $ R "ba-cli 'DeviceInfo.FirmwareImage.$IMG.Download(URL=\"https://$SERVER_IP:8443/img.bin\",AutoActivate=false)'" 2>&1 ; sleep 2
  *DeviceInfo.FirmwareImage.*.Download(URL="https://*:8443/img.bin",AutoActivate=false) (glob)
  ERROR: call (null) failed with status 1 - unknown error
  DeviceInfo.FirmwareImage.*.Download() returned (glob)
  [
      ""
  ]

  $ R 'logread' |  grep 'deviceinfo-manager.*Download' | tail -n 1 | awk -F'Download | - \\(' '{print $2}'
  returned with errorcode 9012

  $ R "ba-cli 'DeviceInfo.FirmwareImage.$IMG.Status?'"
  *DeviceInfo.FirmwareImage.*.Status? (glob)
  DeviceInfo.FirmwareImage.*.Status="DownloadFailed" (glob)

  $ R "ba-cli 'DeviceInfo.FirmwareImage.$IMG.BootFailureLog?'"
  *DeviceInfo.FirmwareImage.*.BootFailureLog? (glob)
  DeviceInfo.FirmwareImage.*.BootFailureLog="\(60\) Error" (glob)

Perform download without CABundle set should fail

  $ R "ba-cli 'DeviceInfo.FirmwareImage.$IMG.Download(URL=\"https://$SERVER_IP:8443/img.bin\",AutoActivate=false)'" 2>&1 ; sleep 2
  *DeviceInfo.FirmwareImage.*.Download(URL="https://*:8443/img.bin",AutoActivate=false) (glob)
  ERROR: call (null) failed with status 1 - unknown error
  DeviceInfo.FirmwareImage.*.Download() returned (glob)
  [
      ""
  ]

  $ R 'logread' |  grep 'deviceinfo-manager.*Download' | tail -n 1 | awk -F'Download | - \\(' '{print $2}'
  returned with errorcode 9012

  $ R "ba-cli 'DeviceInfo.FirmwareImage.$IMG.Status?'"
  *DeviceInfo.FirmwareImage.*.Status? (glob)
  DeviceInfo.FirmwareImage.*.Status="DownloadFailed" (glob)

  $ R "ba-cli 'DeviceInfo.FirmwareImage.$IMG.BootFailureLog?'"
  *DeviceInfo.FirmwareImage.*.BootFailureLog? (glob)
  DeviceInfo.FirmwareImage.*.BootFailureLog="\(60\) Error" (glob)
Perform download via TLS

  $ R "ba-cli 'DeviceInfo.FirmwareImage.$IMG.Download(URL=\"https://$SERVER_IP:8443/img.bin\",AutoActivate=false, CABundle = \"${CABUNDLE}\")'" 2>&1 ; sleep 2
  *DeviceInfo.FirmwareImage.*.Download(URL="https://*:8443/img.bin",AutoActivate=false, CABundle = "Security.CABundle.*.") (glob)
  ERROR: call (null) failed with status 1 - unknown error
  DeviceInfo.FirmwareImage.*.Download() returned (glob)
  [
      ""
  ]

  $ R 'logread' |  grep 'deviceinfo-manager.*Download' | tail -n 1 | awk -F'Download | - \\(' '{print $2}'
  image succeeded

  $ R "ba-cli 'DeviceInfo.FirmwareImage.$IMG.Status?'"
  *DeviceInfo.FirmwareImage.*.Status? (glob)
  DeviceInfo.FirmwareImage.*.Status="InstallationFailed" (glob)

  $ R "ba-cli 'DeviceInfo.FirmwareImage.$IMG.BootFailureLog?'"
  *DeviceInfo.FirmwareImage.*.BootFailureLog? (glob)
  DeviceInfo.FirmwareImage.*.BootFailureLog="swupdate failed to upgrade" (glob)

Verify that enabling a certificate in TLS mode doesn't fail

  $ R "ba-cli 'DeviceInfo.FirmwareImage.$IMG.Download(URL=\"https://$SERVER_IP:8443/img.bin\",AutoActivate=false, CABundle = \"${CABUNDLE}\", Certificate=\"${CERT}\")'" 2>&1 ; sleep 2
  *DeviceInfo.FirmwareImage.*.Download(URL="https://*:8443/img.bin",AutoActivate=false, CABundle = "Security.CABundle.*.", Certificate="Security.Certificate.*.") (glob)
  ERROR: call (null) failed with status 1 - unknown error
  DeviceInfo.FirmwareImage.*.Download() returned (glob)
  [
      ""
  ]

  $ R 'logread' |  grep 'deviceinfo-manager.*Download' | tail -n 1 | awk -F'Download | - \\(' '{print $2}'
  image succeeded

  $ R "ba-cli 'DeviceInfo.FirmwareImage.$IMG.Status?'"
  *DeviceInfo.FirmwareImage.*.Status? (glob)
  DeviceInfo.FirmwareImage.*.Status="InstallationFailed" (glob)

  $ R "ba-cli 'DeviceInfo.FirmwareImage.$IMG.BootFailureLog?'"
  *DeviceInfo.FirmwareImage.*.BootFailureLog? (glob)
  DeviceInfo.FirmwareImage.*.BootFailureLog="swupdate failed to upgrade" (glob)

Stop download server, and restart for mTLS

  $ kill -9 "$tls_server_pid"
  $ $TESTDIR/tls_server.py --mtls >/dev/null 2>&1 &
  $ tls_server_pid="$!"
  $ sleep 5

Perform download via TLS - will fail as server is in mTLS mode

  $ R "ba-cli 'DeviceInfo.FirmwareImage.$IMG.Download(URL=\"https://$SERVER_IP:8443/img.bin\",AutoActivate=false, CABundle = \"${CABUNDLE}\")'" 2>&1 ; sleep 2
  *DeviceInfo.FirmwareImage.*.Download(URL="https://*:8443/img.bin",AutoActivate=false, CABundle = "Security.CABundle.*.") (glob)
  ERROR: call (null) failed with status 1 - unknown error
  DeviceInfo.FirmwareImage.*.Download() returned (glob)
  [
      ""
  ]

  $ R 'logread' |  grep 'deviceinfo-manager.*Download' | tail -n 1 | awk -F'Download | - \\(' '{print $2}'
  returned with errorcode 9010

  $ R "ba-cli 'DeviceInfo.FirmwareImage.$IMG.Status?'"
  *DeviceInfo.FirmwareImage.*.Status? (glob)
  DeviceInfo.FirmwareImage.*.Status="DownloadFailed" (glob)

  $ R "ba-cli 'DeviceInfo.FirmwareImage.$IMG.BootFailureLog?'"
  *DeviceInfo.FirmwareImage.*.BootFailureLog? (glob)
  DeviceInfo.FirmwareImage.*.BootFailureLog="\(*\) Error" (glob)

Perform download via mTLS

  $ R "ba-cli 'DeviceInfo.FirmwareImage.$IMG.Download(URL=\"https://$SERVER_IP:8443/img.bin\",AutoActivate=false, CABundle = \"${CABUNDLE}\", Certificate=\"${CERT}\")'" 2>&1 ; sleep 2
  *DeviceInfo.FirmwareImage.*.Download(URL="https://*:8443/img.bin",AutoActivate=false, CABundle = "Security.CABundle.*.", Certificate="Security.Certificate.*.") (glob)
  ERROR: call (null) failed with status 1 - unknown error
  DeviceInfo.FirmwareImage.*.Download() returned (glob)
  [
      ""
  ]

  $ R 'logread' |  grep 'deviceinfo-manager.*Download' | tail -n 1 | awk -F'Download | - \\(' '{print $2}'
  image succeeded

  $ R "ba-cli 'DeviceInfo.FirmwareImage.$IMG.Status?'"
  *DeviceInfo.FirmwareImage.*.Status? (glob)
  DeviceInfo.FirmwareImage.*.Status="InstallationFailed" (glob)

  $ R "ba-cli 'DeviceInfo.FirmwareImage.$IMG.BootFailureLog?'"
  *DeviceInfo.FirmwareImage.*.BootFailureLog? (glob)
  DeviceInfo.FirmwareImage.*.BootFailureLog="swupdate failed to upgrade" (glob)

Perform download via mTLS with a certificate without a PrivateKeyURI

  $ R "ba-cli 'DeviceInfo.FirmwareImage.$IMG.Download(URL=\"https://$SERVER_IP:8443/img.bin\",AutoActivate=false, CABundle = \"${CABUNDLE}\", Certificate=\"${NO_PRIV_CERT}\")'" 2>&1 ; sleep 2
  *DeviceInfo.FirmwareImage.*.Download(URL="https://*:8443/img.bin",AutoActivate=false, CABundle = "Security.CABundle.*.", Certificate="Security.Certificate.*.") (glob)
  ERROR: call (null) failed with status 7 - invalid function argument
  DeviceInfo.FirmwareImage.*.Download() returned (glob)
  [
      ""
  ]

  $ R "ba-cli 'DeviceInfo.FirmwareImage.$IMG.Status?'"
  *DeviceInfo.FirmwareImage.*.Status? (glob)
  DeviceInfo.FirmwareImage.*.Status="DownloadFailed" (glob)

  $ R "ba-cli 'DeviceInfo.FirmwareImage.$IMG.BootFailureLog?'"
  *DeviceInfo.FirmwareImage.*.BootFailureLog? (glob)
  DeviceInfo.FirmwareImage.*.BootFailureLog="" (glob)

Reset the state of deviceinfo-manager

  $ R "/etc/init.d/deviceinfo-manager restart" > /dev/null 2>&1
  $ sleep 2

Stop the download server

  $ kill -9 "$tls_server_pid"