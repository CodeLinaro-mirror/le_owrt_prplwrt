Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Skip the test on images without prplMesh:

  $ R "test -x /opt/prplmesh/bin/beerocks_agent" || exit 80

Check that the first radio of the first device is in the data model, so the next checks cannot pass on an empty data model:

  $ R "usp-cli -l 'Device.WiFi.DataElements.Network.Device.1.Radio.1.ID?' 2>&1" | sed '/^$/d'
  ([0-9a-f]{2}:){5}[0-9a-f]{2} (re)

The controller creates the CAC completion object when the first CAC completion report arrives. Check that a get on it, before that, returns object not found:

  $ R "usp-cli -l 'Device.WiFi.DataElements.Network.Device.1.Radio.1.X_PRPLWARE-COM_CACCompletion.?' 2>&1" | sed '/^$/d'
  ERROR: get Device.WiFi.DataElements.Network.Device.1.Radio.1.X_PRPLWARE-COM_CACCompletion. failed (2 - object not found)

The controller creates the Spatial Reuse object when the first Spatial Reuse Report arrives. Check the same for it:

  $ R "usp-cli -l 'Device.WiFi.DataElements.Network.Device.1.Radio.1.SpatialReuse.?' 2>&1" | sed '/^$/d'
  ERROR: get Device.WiFi.DataElements.Network.Device.1.Radio.1.SpatialReuse. failed (2 - object not found)
