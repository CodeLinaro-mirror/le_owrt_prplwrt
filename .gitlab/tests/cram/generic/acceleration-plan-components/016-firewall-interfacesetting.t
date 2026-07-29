Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

These tests exercise the standard Device.Firewall.InterfaceSetting.{i}. object
that replaces the deprecated Device.Firewall.X_PRPLWARE-COM_InterfaceSetting.{i}.
tree, using the pre-existing default entry for the LAN interface (Alias='lan').

Check that StealthMode is disabled by default and that, as a result,
explicit REJECT rules exist for the LAN interface:

  $ R "iptables -L INPUT_InterfaceSettings -n -v | grep -c 'REJECT.*br-lan'"
  2

Enable StealthMode on the LAN InterfaceSetting entry:

  $ script --command "ssh -t root@$TARGET_LAN_IP ba-cli Firewall.InterfaceSetting.lan.StealthMode=1" > /dev/null; sleep 1
  $ R "iptables -L INPUT_InterfaceSettings -n -v | grep -c 'REJECT.*br-lan'"
  0
  [1]

Restore StealthMode to its default (disable):

  $ script --command "ssh -t root@$TARGET_LAN_IP ba-cli Firewall.InterfaceSetting.lan.StealthMode=0" > /dev/null; sleep 1

Check that a REJECT rule now exists for the LAN interface:

  $ R "iptables -L INPUT_InterfaceSettings -n -v | grep -c 'REJECT.*br-lan'"
  2

Check that ICMPv4 echo requests on the LAN interface are accepted by default
(IPv4AcceptICMPEchoRequest=true), which is implemented as a generated
Firewall.Service.ifsetting_icmpv4_<Alias> instance with Action=Accept:

  $ R "ba-cli Firewall.Service.ifsetting_icmpv4_lan.Action? | grep -c 'Accept'"
  1

Disable ICMPv4 echo requests and check that the underlying generated service
switches to Drop and the status mirror updates accordingly:

  $ script --command "ssh -t root@$TARGET_LAN_IP ba-cli Firewall.InterfaceSetting.lan.IPv4AcceptICMPEchoRequest=0" > /dev/null; sleep 1
  $ R "ba-cli Firewall.Service.ifsetting_icmpv4_lan.Action? | grep -c 'Drop'"
  1

Restore IPv4AcceptICMPEchoRequest to its default (enabled):

  $ script --command "ssh -t root@$TARGET_LAN_IP ba-cli Firewall.InterfaceSetting.lan.IPv4AcceptICMPEchoRequest=1" > /dev/null; sleep 1
  $ R "ba-cli Firewall.Service.ifsetting_icmpv4_lan.Action? | grep -c 'Accept'"
  1
