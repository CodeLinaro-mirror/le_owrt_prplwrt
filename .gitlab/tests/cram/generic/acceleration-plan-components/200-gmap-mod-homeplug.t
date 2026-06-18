Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Verification of main parameters:

  $ R "ba-cli Device.HomePlug.Interface.1.Enable? | grep '='"
  Device.HomePlug.Interface.1.Enable=1

  $ R "ba-cli Device.HomePlug.Interface.1.Status? | grep '='"
  Device.HomePlug.Interface.1.Status="Up"

  $ R "ba-cli Device.HomePlug.Interface.1.AssociateDeviceNumberOfEntries? | grep '='"
  Device.HomePlug.Interface.1.AssociateDeviceNumberOfEntries=2

Verification of first AssociatedDevice:
  $ MAC=$(R "ba-cli Device.HomePlug.Interface.1.AssociatedDevice.1.MACAddress?" \
  > | sed -n 's/.*=//p' | tr -d '"')

  $ echo "$MAC"
  ([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2} (re)

  $ RX_HP=$(R "ba-cli -l Device.HomePlug.Interface.1.AssociatedDevice.1.RxPhyRate?" | grep -v -e '^$')  
  $ RX_GMAP=$(R "ba-cli -l Devices.Device.[PhysAddress==\\\"$MAC\\\"].HomePlug.RxPhyRate?" | grep -v -e '^$')  
  $ echo "$RX_HP"
  \d{1,3} (re)

  $ echo "$RX_GMAP"
  \d{1,3} (re)

  $ test "$RX_HP" = "$RX_GMAP"

  $ R "ba-cli Devices.Device.[PhysAddress==\\\"$MAC\\\"].Link.gmap_homeplug_device.? | grep -E 'Type=\"PLC\"'"
  Devices\.Device\.\d+\.Link\.\d+\.[LU]Device\.\d+\.Type="PLC" (re)

Verification of second AssociatedDevice:
  $ MAC=$(R "ba-cli Device.HomePlug.Interface.1.AssociatedDevice.2.MACAddress?" \
  > | sed -n 's/.*=//p' | tr -d '"')

  $ echo "$MAC"
  ([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2} (re)

  $ RX_HP=$(R "ba-cli -l Device.HomePlug.Interface.1.AssociatedDevice.2.RxPhyRate?" | grep -v -e '^$')  
  $ RX_GMAP=$(R "ba-cli -l Devices.Device.[PhysAddress==\\\"$MAC\\\"].HomePlug.RxPhyRate?" | grep -v -e '^$')  
  $ echo "$RX_HP"
  \d{1,3} (re)

  $ echo "$RX_GMAP"
  \d{1,3} (re)

  $ test "$RX_HP" = "$RX_GMAP"
  $ R "ba-cli Devices.Device.[PhysAddress==\\\"$MAC\\\"].Link.gmap_homeplug_device.? | grep -E 'Type=\"PLC\"'"
  Devices\.Device\.\d+\.Link\.\d+\.[LU]Device\.\d+\.Type="PLC" (re)