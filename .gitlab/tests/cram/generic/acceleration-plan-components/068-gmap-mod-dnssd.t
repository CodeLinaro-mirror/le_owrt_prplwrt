Create R alias:
  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Check DNS.SD.Service running:
  $ R 'ba-cli "Device.DNS.SD.Service.1.?" | grep -q "not found" && echo "Not present" || echo "Present" '
  Present

Check instance found in gmap datamodel:
  $ R 'ba-cli "Devices.Device.*.mDNSService.?" | grep -q "not found" && echo "Not present" || echo "Present" '
  Present
