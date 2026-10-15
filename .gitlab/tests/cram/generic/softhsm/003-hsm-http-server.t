Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Setup https server at prplOS.lan/localhost 127.0.0.1:

  $ cat > /tmp/httpaccess-setup.sh <<EOF
  > ba-cli UserInterface.HTTPAccessSupportedProtocols="HTTP,HTTPS"
  > ba-cli UserInterface.HTTPAccess.1.Enable=0
  > ba-cli UserInterface.HTTPAccess.1.Interface="Device.IP.Interface.1"
  > ba-cli UserInterface.HTTPAccess.1.Protocol="HTTPS"
  > ba-cli UserInterface.HTTPAccess.1.Port="443"
  > ba-cli UserInterface.HTTPAccess.1.Certificate="Device.Security.Certificate.2."
  > ba-cli UserInterface.HTTPAccess.1.Enable=1
  > EOF
  $ script --command "ssh -t root@$TARGET_LAN_IP '$(cat /tmp/httpaccess-setup.sh)'" > /dev/null
  $ deadline=$(($(date +%s%N) + ${TESTBED_QEMU_TIMEOUT_SCALE:-1} * 1000000000))
  $ while [ "$(date +%s%N)" -lt "$deadline" ]; do
  >   response=$(R "curl --cacert /usr/share/ca-certificates/test/ca.crt --silent --output /dev/null --write-out \"%{http_code}\\n\" https://prplOS.lan" 2>/dev/null) && [ "$response" = 200 ] && break
  >   sleep .1
  > done

Check server response ok:

  $ R "curl --cacert /usr/share/ca-certificates/test/ca.crt --silent --output /dev/null --write-out \"%{http_code}\\n\" https://prplOS.lan"
  200
