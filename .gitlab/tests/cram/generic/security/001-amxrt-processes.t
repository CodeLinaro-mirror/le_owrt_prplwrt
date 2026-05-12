Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Verify that processes are running with reduced privileges:

  $ R "
  > is_amxrt_process() {
  >   [ \"\$proc_exe\" == \"/usr/bin/amxrt\" ]
  > }
  > 
  > get_proc_cmd() {
  >   local cmd_path=\"\$(cat \${proc_dir}/cmdline | tr '\0' ' ' | cut -d ' ' -f1)\"
  >   basename -a -- \"\${cmd_path}\"
  > }
  > 
  > inspect_proc_status() {
  >   awk '
  >     /^Uid:/    { uid=\$2 \"/\" \$3 \"/\" \$4 \"/\" \$5 }
  >     /^Gid:/    { gid=\$2 \"/\" \$3 \"/\" \$4 \"/\" \$5 }
  >     /^CapEff:/ { printf \"UID=%s GID=%s CapEff=%s\n\",
  >                         uid, gid, \$2 }
  >   ' \"\${proc_dir}/status\" 2>/dev/null
  > }
  > 
  > inspect_process() {
  >   local proc_dir=\"\$1\"
  > 
  >   local proc_exe=\"\$(readlink \${proc_dir}/exe)\"
  >   is_amxrt_process || return
  > 
  >   local proc_cmd=\"\$(get_proc_cmd)\"
  >   [ -z \"\${proc_cmd}\" ] && return
  >   local proc_status=\"\$(inspect_proc_status)\"
  > 
  >   echo \"\${proc_cmd} \${proc_status}\"
  > }
  > 
  > 
  > (
  > for s in /proc/[0-9]*/status; do
  >   inspect_process \"\$(dirname \$s)\"
  > done
  > ) | sort | uniq
  > "
  acl-manager UID=10/10/10/10 GID=300/300/300/300 CapEff=0000000000000007
  amx-faultmonitor UID=10/10/10/10 GID=10/10/10/10 CapEff=0000000000000002
  amx-fcgi UID=103/103/103/103 GID=300/300/300/300 CapEff=0000000000000000
  amx-processmonitor UID=10/10/10/10 GID=10/10/10/10 CapEff=0000000000000022
  amxrt UID=0/0/0/0 GID=0/0/0/0 CapEff=000001ffffffffff
  cthulhu UID=0/0/0/0 GID=0/0/0/0 CapEff=000001ffffffffff
  cwmp_plugin UID=0/0/0/0 GID=0/0/0/0 CapEff=000001ffffffffff
  deviceinfo-manager UID=0/0/0/0 GID=0/0/0/0 CapEff=000001ffffffffff
  deviceinfo-system UID=0/0/0/0 GID=0/0/0/0 CapEff=000001ffffffffff
  dhcpv4-manager UID=10/10/10/10 GID=10/10/10/10 CapEff=0000000080003422
  dhcpv6s-manager UID=10/10/10/10 GID=10/10/10/10 CapEff=0000000000000002
  ethernet-manager UID=10/10/10/10 GID=10/10/10/10 CapEff=0000000000021002
  gmap-client UID=10/10/10/10 GID=10/10/10/10 CapEff=0000000000000002
  gmap-server UID=10/10/10/10 GID=10/10/10/10 CapEff=0000000000000002
  hosts-manager UID=10/10/10/10 GID=10/10/10/10 CapEff=0000000000000002
  ip-manager UID=10/10/10/10 GID=10/10/10/10 CapEff=0000000000003002
  multisettings UID=10/10/10/10 GID=10/10/10/10 CapEff=0000000000000007
  netdev-plugin UID=10/10/10/10 GID=10/10/10/10 CapEff=0000000000001000
  netmodel UID=10/10/10/10 GID=10/10/10/10 CapEff=0000000000000002
  netmodel-clients UID=10/10/10/10 GID=10/10/10/10 CapEff=0000000000003002
  oopsmonitor UID=10/10/10/10 GID=10/10/10/10 CapEff=000000000000000e
  packet-interception UID=10/10/10/10 GID=10/10/10/10 CapEff=0000000000003002
  pcm-manager UID=10/10/10/10 GID=10/10/10/10 CapEff=0000000000000003
  prplmesh-dm-mapper UID=0/0/0/0 GID=0/0/0/0 CapEff=000001ffffffffff
  prplmesh-process-manager UID=0/0/0/0 GID=0/0/0/0 CapEff=000001ffffffffff
  reboot-service UID=10/10/10/10 GID=10/10/10/10 CapEff=0000000000000002
  rlyeh UID=0/0/0/0 GID=0/0/0/0 CapEff=0000000000000000
  routing-manager UID=10/10/10/10 GID=10/10/10/10 CapEff=0000000000003002
  ssh_server UID=0/0/0/0 GID=0/0/0/0 CapEff=000001ffffffffff
  time-manager UID=323/323/323/323 GID=323/323/323/323 CapEff=00000000020004c7
  timingila UID=0/0/0/0 GID=0/0/0/0 CapEff=0000000000000000
  tr181-bridging UID=10/10/10/10 GID=10/10/10/10 CapEff=0000000000001002
  tr181-bulkdata UID=10/10/10/10 GID=10/10/10/10 CapEff=0000000000000007
  tr181-button UID=10/10/10/10 GID=10/10/10/10 CapEff=0000000000000007
  tr181-captiveportal UID=10/10/10/10 GID=10/10/10/10 CapEff=0000000000000007
  tr181-conmon UID=10/10/10/10 GID=10/10/10/10 CapEff=0000000000002400
  tr181-conntrack-query UID=10/10/10/10 GID=10/10/10/10 CapEff=0000000000000007
  tr181-cpu UID=10/10/10/10 GID=10/10/10/10 CapEff=0000000000000007
  tr181-device UID=10/10/10/10 GID=10/10/10/10 CapEff=0000000000000007
  tr181-dhcpv4client UID=10/10/10/10 GID=10/10/10/10 CapEff=0000000000002422
  tr181-dhcpv6client UID=10/10/10/10 GID=10/10/10/10 CapEff=0000000080002422
  tr181-dns UID=10/10/10/10 GID=10/10/10/10 CapEff=000000008000242a
  tr181-dnssd UID=10/10/10/10 GID=10/10/10/10 CapEff=0000000080000022
  tr181-dslite UID=10/10/10/10 GID=10/10/10/10 CapEff=0000000000001002
  tr181-dynamicdns UID=10/10/10/10 GID=10/10/10/10 CapEff=0000000000000007
  tr181-firewall UID=10/10/10/10 GID=10/10/10/10 CapEff=0000000080013002
  tr181-flashmonitor UID=10/10/10/10 GID=10/10/10/10 CapEff=0000000000000007
  tr181-gnimanager UID=10/10/10/10 GID=10/10/10/10 CapEff=0000000000000007
  tr181-homeplug UID=10/10/10/10 GID=10/10/10/10 CapEff=0000000000002002
  tr181-ipdiagnostics UID=10/10/10/10 GID=10/10/10/10 CapEff=00000000000020e2
  tr181-led UID=10/10/10/10 GID=10/10/10/10 CapEff=0000000000000002
  tr181-logical UID=10/10/10/10 GID=10/10/10/10 CapEff=0000000000000002
  tr181-mcastd UID=10/10/10/10 GID=10/10/10/10 CapEff=0000000080003002
  tr181-mqtt UID=10/10/10/10 GID=10/10/10/10 CapEff=0000000000000002
  tr181-mqttbroker UID=10/10/10/10 GID=10/10/10/10 CapEff=0000000080000022
  tr181-neighbordiscovery UID=10/10/10/10 GID=10/10/10/10 CapEff=0000000000003002
  tr181-pcp UID=10/10/10/10 GID=10/10/10/10 CapEff=0000000000000002
  tr181-periodicfileupload UID=0/0/0/0 GID=10/10/10/10 CapEff=0000000000000000
  tr181-powerstatus UID=10/10/10/10 GID=10/10/10/10 CapEff=0000000000000002
  tr181-ppp UID=10/10/10/10 GID=10/10/10/10 CapEff=0000000000033002
  tr181-qos UID=10/10/10/10 GID=10/10/10/10 CapEff=0000000000003002
  tr181-routeradvertisement UID=10/10/10/10 GID=10/10/10/10 CapEff=0000000080002022
  tr181-security UID=10/10/10/10 GID=10/10/10/10 CapEff=0000000000000006
  tr181-sfp UID=10/10/10/10 GID=10/10/10/10 CapEff=0000000000000002
  tr181-syslog UID=10/10/10/10 GID=10/10/10/10 CapEff=0000000400002c0f
  tr181-temperature UID=10/10/10/10 GID=10/10/10/10 CapEff=0000000000000000
  tr181-upnp UID=10/10/10/10 GID=10/10/10/10 CapEff=0000000080003022
  tr181-upnpdiscovery UID=10/10/10/10 GID=10/10/10/10 CapEff=0000000000000000
  tr181-usb UID=10/10/10/10 GID=10/10/10/10 CapEff=0000000000000002
  tr181-usermanagement UID=10/10/10/10 GID=10/10/10/10 CapEff=0000000000000007
  tr181-xpon UID=10/10/10/10 GID=10/10/10/10 CapEff=0000000000011002
  wan-manager UID=10/10/10/10 GID=10/10/10/10 CapEff=0000000000000002
  wifi-sensing UID=0/0/0/0 GID=0/0/0/0 CapEff=000001ffffffffff
  wld UID=0/0/0/0 GID=0/0/0/0 CapEff=000001ffffffffff
