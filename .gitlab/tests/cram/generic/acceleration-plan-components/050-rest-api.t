Check that REST API is working as expected:

  $ curl --silent --max-time 3 --user admin:admin 'http://192.168.1.1:8080/serviceElements/DeviceInfo.FriendlyName'
  [{"parameters":{"FriendlyName":"prplHGW"},"path":"DeviceInfo."}] (no-eol)

Check that REST API is not usable with invalid credentials:

  $ curl --silent --max-time 3 --user admin:failure 'http://192.168.1.1:8080/serviceElements/DeviceInfo.FriendlyName' | grep h1
    <h1>401 Unauthorized</h1>
