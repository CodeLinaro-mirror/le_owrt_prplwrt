Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Verification of main parameters:

  $ R "ba-cli UPnPDiscovery.DeviceNumberOfEntries? | sort | grep '='"
  UPnPDiscovery.DeviceNumberOfEntries=[0-9]+ (re)

  $ R "ba-cli UPnPDiscovery.RootDeviceNumberOfEntries? | sort | grep '='"
  UPnPDiscovery.RootDeviceNumberOfEntries=[0-9]+ (re)

  $ R "ba-cli UPnPDiscovery.ServiceNumberOfEntries? | sort | grep '='"
  UPnPDiscovery.ServiceNumberOfEntries=[0-9]+ (re)

Verification of RootDevice.1 parameters:

  $ R "ba-cli UPnPDiscovery.RootDevice.1.? | sort | grep '='"
  UPnPDiscovery.RootDevice.1.Host=".*" (re)
  UPnPDiscovery.RootDevice.1.LastUpdate=".*" (re)
  UPnPDiscovery.RootDevice.1.LeaseTime=\d+ (re)
  UPnPDiscovery.RootDevice.1.Location="http://.*" (re)
  UPnPDiscovery.RootDevice.1.Server=".*" (re)
  UPnPDiscovery.RootDevice.1.Status=".*" (re)
  UPnPDiscovery.RootDevice.1.USN="uuid:.*" (re)
  UPnPDiscovery.RootDevice.1.UUID=".*" (re)

Verification of Device.1 parameters:

  $ R "ba-cli UPnPDiscovery.Device.1.? | sort | grep '='"
  UPnPDiscovery.Device.1.Host=".*" (re)
  UPnPDiscovery.Device.1.LastUpdate=".*" (re)
  UPnPDiscovery.Device.1.LeaseTime=\d+ (re)
  UPnPDiscovery.Device.1.Location="http://.*" (re)
  UPnPDiscovery.Device.1.Server=".*" (re)
  UPnPDiscovery.Device.1.Status=".*" (re)
  UPnPDiscovery.Device.1.USN="uuid:.*" (re)
  UPnPDiscovery.Device.1.UUID=".*" (re)

Verification of Service.1 parameters:

  $ R "ba-cli UPnPDiscovery.Service.1.? | sort | grep '='"
  UPnPDiscovery.Service.1.Host=".*" (re)
  UPnPDiscovery.Service.1.LastUpdate=".*" (re)
  UPnPDiscovery.Service.1.LeaseTime=\d+ (re)
  UPnPDiscovery.Service.1.Location="http://.*" (re)
  UPnPDiscovery.Service.1.ParentDevice=".*" (re)
  UPnPDiscovery.Service.1.Server=".*" (re)
  UPnPDiscovery.Service.1.Status=".*" (re)
  UPnPDiscovery.Service.1.USN="uuid:.*" (re)