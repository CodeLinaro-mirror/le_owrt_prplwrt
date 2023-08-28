Check that REST API is working on non-protected parameters:

  $ curl --silent --max-time 3 "http://$TARGET_LAN_IP/serviceElements/Device.DeviceInfo.FriendlyName"
  [{"parameters":{"FriendlyName":"prplHGW"},"path":"Device.DeviceInfo."}] (no-eol)

Check we can get protected parameters:

  $ session_id=$(curl -X POST -i "http://$TARGET_LAN_IP/session" --data '{"username":"admin","password":"admin"}' --silent | grep sessionID | cut -d ":" -f4 | cut -d "}" -f1)
  $ session_id=${session_id//\"}
  $ curl -X GET -i "http://$TARGET_LAN_IP/serviceElements/Device.Time.Client.1.Version" -H "Authorization: bearer $session_id"
  [{"parameters":{"Version":4},"path":"Device.Time.Client.1."}]
