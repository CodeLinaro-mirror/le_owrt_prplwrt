Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Check Device.Logical.TUN datamodel object:

  $ R "ubus -S call Device.Logical.TUN _get"
  {"Device.Logical.TUN.":{"InterfaceNumberOfEntries":0}}
  {}
  {"amxd-error-code":0}

Check Device.Logical.TAP datamodel object:

  $ R "ubus -S call Device.Logical.TAP _get"
  {"Device.Logical.TAP.":{"InterfaceNumberOfEntries":0}}
  {}
  {"amxd-error-code":0}

Ensure we start with no custom TUN devices:

  $ R "ip link show | grep \"tun.*\""

Ensure we start with no custom TAP devices:

  $ R "ip link show | grep \"tap.*\""

Create TUN interface:

  $ R "ba-cli 'Device.Logical.TUN.CreateInterface()'" | grep -v '>'
  Device.Logical.TUN.CreateInterface() returned
  [
      0,
      {
          args = {
              FileDescriptor = "[0-9]+", (re)
              Interface = "Device.Logical.TUN.Interface.1."
          }
      }
  ]

Ensure TUN device is created:

  $ R "ip link show | grep -E \"tun[0-9]+:\" | sed 's/^[0-9]*: //'"
  tun0: <POINTOPOINT,MULTICAST,NOARP,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UNKNOWN mode DEFAULT group default qlen 500

Create TAP interface:

  $ R "ba-cli 'Device.Logical.TAP.CreateInterface()'" | grep -v '>'
  Device.Logical.TAP.CreateInterface() returned
  [
      0,
      {
          args = {
              FileDescriptor = "[0-9]+", (re)
              Interface = "Device.Logical.TAP.Interface.1."
          }
      }
  ]

Ensure TAP device is created:

  $ R "ip link show | grep -E \"tap[0-9]+:\" | sed 's/^[0-9]*: //'"
  tap0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UNKNOWN mode DEFAULT group default qlen 1000

Verify TUN and TAP DM entries are in sync:

  $ R "ba-cli 'Device.Logical.TUN.Interface.1.Enable?'" | tail -n 2
  Device.Logical.TUN.Interface.1.Enable=1
  $ R "ba-cli 'Device.Logical.TAP.Interface.1.Enable?'" | tail -n 2
  Device.Logical.TAP.Interface.1.Enable=1
  $ R "ba-cli 'Device.Logical.TUN.Interface.1.Status?'" | tail -n 2
  Device.Logical.TUN.Interface.1.Status="Up"
  $ R "ba-cli 'Device.Logical.TAP.Interface.1.Status?'" | tail -n 2
  Device.Logical.TAP.Interface.1.Status="Unknown"

Verify TUN and TAP Netmodel entries are in sync:

  $ TUNIFACE=`R "ba-cli 'Device.Logical.TUN.Interface.1.Name?'" | sed -ne 2p | awk -F= '{print $2}' | sed -e s/'\"'//g`
  $ R "ba-cli 'NetModel.Intf.[Name ~= \"'$TUNIFACE'\"].Status_ext?'" | tail -n2 | head -n1
  NetModel.Intf.[0-9]+.Status_ext="Up" (re)

  $ TAPIFACE=`R "ba-cli 'Device.Logical.TAP.Interface.1.Name?'" | sed -ne 2p | awk -F= '{print $2}' | sed -e s/'\"'//g`
  $ R "ba-cli 'NetModel.Intf.[Name ~= \"'$TAPIFACE'\"].Status_ext?'" | tail -n2 | head -n1
  NetModel.Intf.[0-9]+.Status_ext="Unknown" (re)

Delete TUN interface:

  $ R "ba-cli 'Device.Logical.TUN.Interface.1.Delete()'" | grep -v '>'
  Device.Logical.TUN.Interface.1.Delete() returned
  [
      ""
  ]

  $ R "ip link show | grep -E "tun[0-9]+:" | sed 's/^[0-9]*: //'"

Delete TAP interface:

  $ R "ba-cli 'Device.Logical.TAP.Interface.1.Delete()'" | grep -v '>'
  Device.Logical.TAP.Interface.1.Delete() returned
  [
      ""
  ]

  $ R "ip link show | grep -E "tap[0-9]+:" | sed 's/^[0-9]*: //'"
