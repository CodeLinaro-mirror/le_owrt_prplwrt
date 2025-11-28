Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"


Check DNS.SD.Service running:
  $ R 'ba-cli "Device.UPnP.Description.DeviceInstance.1.?" | grep -q "not found" && echo "Not present" || echo "Present" '
  Present

Check instance found in gmap datamodel:
  $ R 'ubus-cli "Devices.Device.UPnP-1.?" | grep -q "not found" && echo "Not present" || echo "Present" '
  Present
