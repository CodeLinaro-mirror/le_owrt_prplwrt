Check that REST API is working on non-protected parameters:

  $ curl --silent --max-time 3 "http://192.168.1.1/serviceElements/Device.DeviceInfo.FriendlyName"
  [{"parameters":{"FriendlyName":"prplHGW"},"path":"Device.DeviceInfo."}] (no-eol)

Check we can get protected parameters:

  $ session_id=$(curl -X POST -i "http://192.168.1.1/session" --data '{"username":"admin","password":"admin"}' --silent | grep sessionID | cut -d ":" -f4 | cut -d "}" -f1 | cut -d '"' -f2)
  $ curl -X GET "http://192.168.1.1/serviceElements/Device.Time.Client.1.Version" -H "Authorization: bearer $session_id" --silent
  [{"parameters":{"Version":4},"path":"Device.Time.Client.1."}]
