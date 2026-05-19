Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

add firewall rule :
  $ R  " ba-cli NAT.PortMapping.+\{Alias=cpe-PortMapping-2,Enable=true,Protocol=TCP,ExternalPort=2000,InternalPort=1000,InternalClient="192.168.10.11",Interface="Device.IP.Interface2",AllInterfaces=false,LeaseDuration=0,RemoteHost=""\} "  > /dev/null; sleep .5

Conntrack entries should be seen in NEW/ESTABLISHED state:
  $ R  " conntrack -E -p tcp &" > /dev/null; sleep .5

disable the port mapping :
  $ R "ba-cli NAT.PortMapping.cpe-PortMapping-2.Enable=0" > /dev/null; sleep .5

Verify that traffic is stopped and DESTROY message :
  $ R  " conntrack -E -p tcp " > /dev/null; sleep .5

remove firewall rule :
  $ R " ba-cli NAT.PortMapping.cpe-PortMapping-2.-" > /dev/null; sleep .5


configure  DMZ rule:
  $ R "ba-cli Firewall.DMZ.+{Alias=cpe-DMZ-2,Enable=true,DestIP="192.168.10.10",Interface="Device.Logical.Interface.1"}" > /dev/null; sleep .5

disable DMZ rule 
  $ R "ba-cli Firewall.DMZ.2.Enable=0" > /dev/null; sleep .5
