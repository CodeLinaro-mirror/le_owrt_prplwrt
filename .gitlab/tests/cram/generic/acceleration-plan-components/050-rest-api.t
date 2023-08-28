Check that REST API is working on non-protected parameters:

  $ curl --silent --max-time 3 'http://192.168.1.1/serviceElements/DeviceInfo.FriendlyName'
  [{"parameters":{"FriendlyName":"prplHGW"},"path":"DeviceInfo."}] (no-eol)
