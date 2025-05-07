Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Check QoS root datamodel:

  $ R "ubus -S call QoS _get"
  {"QoS.":{"SupportedControllers":"mod-qos-tc","ShaperNumberOfEntries":1,"QueueNumberOfEntries":5,"MaxSchedulerEntries":20,"SchedulerNumberOfEntries":1,"QueueStatsNumberOfEntries":4,"ClassificationNumberOfEntries":4,"MaxClassificationEntries":40,"BrokenQDiscPrioMap":false,"MarkMask":31,"MaxQueueEntries":20,"MaxShaperEntries":20}}
  {}
  {"amxd-error-code":0}

Check Qos.Node.7 datamodel:

  $ R "ubus call QoS.Node.7 _get | jsonfilter -e @[*].TrafficClasses -e @[*].DropAlgorithm -e @[*].Controller -e @[*].AllInterfaces -e @[*].SchedulerAlgorithm -e @[*].Alias " | sort
  3
  DT
  HTB
  false
  mod-qos-tc
  node-queue-home-iptv

Enable QoS.Queue datamodel for stats-home-iptv configurations:

  $ R "ba-cli -lj 'QoS.Shaper.shaper-wan.Enable = true; QoS.Scheduler.scheduler-wan.Enable = true; QoS.Queue.queue-home-data.Enable = true; QoS.Queue.5.Enable=true; QoS.QueueStats.4.Enable=true' | sort -u"
  
  [{"QoS.Queue.3.":{"Enable":1}}]
  [{"QoS.Queue.5.":{"Enable":1}}]
  [{"QoS.QueueStats.4.":{"Enable":1}}]
  [{"QoS.Scheduler.1.":{"Enable":1}}]
  [{"QoS.Shaper.1.":{"Enable":1}}]

  $ sleep 1

Check QoS.Queue datamodel for stats-home-iptv:

  $ R "ubus call QoS.Queue.5 _get | jsonfilter -e @[*].Alias -e @[*].SchedulerAlgorithm -e @[*].Status -e @[*].Controller -e @[*].TrafficClasses" | sort
  3
  Enabled
  HTB
  mod-qos-tc
  queue-home-iptv

Check QoS.QueueStats datamodel for stats-home-iptv:

  $ R "ubus -S call QoS.QueueStats.4 _get | jsonfilter -e @[*].Status -e @[*].QueueOccupancyPercentage -e @[*].Alias -e @[*].Queue" | sort
  0
  Enabled
  QoS.Queue.queue-home-iptv
  stats-home-iptv

Check QoS.Scheduler datamodel:

  $ R "ubus call QoS.Scheduler _get | jsonfilter -e @[*].DefaultQueue -e @[*].SchedulerAlgorithm -e @[*].Status -e @[*].Controller" | sort
  Enabled
  HTB
  QoS.Queue.queue-home-data.
  mod-qos-tc

Enable QoS.Shaper.1 configurations:

  $ R "ba-cli -lj 'QoS.Queue.queue-guest.Enable = true; QoS.Queue.queue-guest.Enable = true; QoS.Shaper.shaper-wan.Enable = true' | sort -u"
  
  [{"QoS.Queue.1.":{"Enable":1}}]
  [{"QoS.Shaper.1.":{"Enable":1}}]

  $ sleep 1

Check QoS.Shaper.1 datamodel:

  $ R "ubus call QoS.Shaper.1 _get | jsonfilter -e @[*].Controller -e @[*].Enable -e @[*].Status" | sort
  Enabled
  mod-qos-tc
  true

Check DSCP value for IPv4 ICMP packets with icmp_dscp_cs6 classification configuration:

  $ R "ba-cli -lj 'QoS.Classification.1.Enable = true' | sort -u"
  
  [{"QoS.Classification.1.":{"Enable":1}}]

  $ sleep 1
  $ R "ubus call QoS.Classification.1 _get | jsonfilter -e @[*].Status -e @[*].DSCPMark -e @[*].Alias -e @[*].Protocol -e @[*].IPVersion" | sort
  1
  4
  48
  Enabled
  icmp_dscp_cs6

  $ R "iptables -t mangle -L POSTROUTING_class | grep 'DSCP set'"
  DSCP       icmp --  anywhere             anywhere             DSCP set 0x30

Alter the previous classification and set the DSCP marking to 52:

  $ script --command "ssh -t root@$TARGET_LAN_IP 'ubus-cli QoS.Classification.icmp_dscp_cs6.DSCPMark=52'" > /dev/null;  sleep 2

Check altered classification instance configuration:

  $ R "ubus call QoS.Classification.1 _get | jsonfilter -e @[*].Status -e @[*].DSCPMark -e @[*].Alias -e @[*].Protocol -e @[*].IPVersion" | sort
  1
  4
  52
  Enabled
  icmp_dscp_cs6

  $ R "iptables -t mangle -L POSTROUTING_class | grep 'DSCP set'"
  DSCP       icmp --  anywhere             anywhere             DSCP set 0x34

Add a new classification instance 5. Mark ICMP packets to network 192.168.25.0/24 with value 8 (CS1):

  $ cat > /tmp/new-classification <<EOF
  > ba-cli QoS.Classification.+{Alias=icmp_dscp_cs1}
  > ba-cli QoS.Classification.icmp_dscp_cs1.DSCPMark=8
  > ba-cli QoS.Classification.icmp_dscp_cs1.Interface=""
  > ba-cli QoS.Classification.icmp_dscp_cs1.X_PRPLWARE-COM_Direction="Postrouting"
  > ba-cli QoS.Classification.icmp_dscp_cs1.Protocol=1
  > ba-cli QoS.Classification.icmp_dscp_cs1.IPVersion=4
  > ba-cli QoS.Classification.icmp_dscp_cs1.DestIP=192.168.25.0
  > ba-cli QoS.Classification.icmp_dscp_cs1.DestMask="255.255.255.0"
  > ba-cli QoS.Classification.icmp_dscp_cs1.Enable=1
  > EOF
  $ script --command "ssh -t root@$TARGET_LAN_IP '$(cat /tmp/new-classification)'" > /dev/null
  $ R "ba-cli 'QoS.Classification.lansubnet1.Enable = true' > /dev/null"
  $ sleep 2

The firewall rule to set a DSCP value for ICMP packets to network 192.168.25.0/24 must be the first one, so change the order:

  $ script --command "ssh -t root@$TARGET_LAN_IP 'ubus-cli QoS.Classification.icmp_dscp_cs1.Order=1'" > /dev/null;  sleep 2

Check correct change of packet classification ordering:

  $ R "ba-cli -lj 'QoS.Classification.icmp_dscp_cs6.?' | sed -n '2p'" | jq -e '.[] | .[] | .Order'
  2

  $ R "ba-cli -lj 'QoS.Classification.icmp_dscp_cs1.?' | sed -n '2p'" | jq -e '.[] | .[] | .Order'
  1

  $ R "iptables -t mangle -L POSTROUTING_class | grep 'DSCP set'"
  DSCP       icmp --  anywhere             192.168.25.0/24      DSCP set 0x08
  DSCP       icmp --  anywhere             anywhere             DSCP set 0x34

Check default QoS configuration:

  $ cat > /tmp/new-classification <<EOF
  > ba-cli QoS.Classification.lansubnet1.Enable = true
  > ba-cli QoS.Classification.icmp_to_voip_queue.Enable = true
  > ba-cli QoS.QueueStats.stats-guest.Enable = true
  > ba-cli QoS.QueueStats.stats-home-data.Enable = true
  > ba-cli QoS.QueueStats.stats-home-voip.Enable = true
  > ba-cli QoS.QueueStats.stats-home-iptv.Enable = true
  > ba-cli QoS.Queue.queue-home.Enable = true
  > ba-cli QoS.Queue.queue-home-data.Enable = true
  > ba-cli QoS.Queue.queue-home-voip.Enable = true
  > ba-cli QoS.Queue.queue-home-iptv.Enable = true
  > EOF
  $ script --command "ssh -t root@$TARGET_LAN_IP '$(cat /tmp/new-classification)'" > /dev/null
  $ sleep 2

  $ R "tc qdisc show dev $DUT_WAN_INTERFACE"
  qdisc htb 1: root refcnt (2|5|9|17) r2q 10 default 0x10003 direct_packets_stat [0-9]+ direct_qlen (532|1000|1024) (re)

  $ R "tc class show dev $DUT_WAN_INTERFACE" | sort
  class htb 1:1 parent 1:101 prio 5 rate 25Mbit ceil 25Mbit burst *b cburst *b (glob)
  class htb 1:101 root rate 325Mbit ceil 325Mbit burst *b cburst *b (glob)
  class htb 1:2 parent 1:101 rate 300Mbit ceil 300Mbit burst *b cburst *b (glob)
  class htb 1:3 parent 1:2 prio 3 rate 250Mbit ceil 250Mbit burst *b cburst *b (glob)
  class htb 1:4 parent 1:2 prio 1 rate 10Mbit ceil 10Mbit burst *b cburst *b (glob)
  class htb 1:5 parent 1:2 prio 2 rate 40Mbit ceil 40Mbit burst *b cburst *b (glob)

  $ R "tc filter show dev $DUT_WAN_INTERFACE" | sort
  filter parent 1: protocol all pref 1 fw.*  (re)
  filter parent 1: protocol all pref 1 fw.*handle 0x4/0x1f classid 1:4  (re)
  filter parent 1: protocol all pref 2 fw.*  (re)
  filter parent 1: protocol all pref 2 fw.*handle 0x5/0x1f classid 1:5  (re)
  filter parent 1: protocol all pref 5 fw.*  (re)
  filter parent 1: protocol all pref 5 fw.*handle 0x1/0x1f classid 1:1  (re)

Let all upstream (LAN -> WAN) UDP packets to network 192.168.55.0/24 go through queue-home-iptv (highest priority):

  $ cat > /tmp/new-classification <<EOF
  > ba-cli QoS.Classification.+{Alias=subnet1_high_prio}
  > ba-cli QoS.Classification.subnet1_high_prio.Interface=""
  > ba-cli QoS.Classification.subnet1_high_prio.X_PRPLWARE-COM_Direction="Forward"
  > ba-cli QoS.Classification.subnet1_high_prio.Protocol=17
  > ba-cli QoS.Classification.subnet1_high_prio.IPVersion=4
  > ba-cli QoS.Classification.subnet1_high_prio.DestIP=192.168.55.0
  > ba-cli QoS.Classification.subnet1_high_prio.DestMask="255.255.255.0"
  > ba-cli QoS.Classification.subnet1_high_prio.TrafficClass=5
  > ba-cli QoS.Classification.subnet1_high_prio.Enable=1
  > EOF
  $ script --command "ssh -t root@$TARGET_LAN_IP '$(cat /tmp/new-classification)'" > /dev/null
  $ sleep 2

Check that iptables rule is created in the FORWARD_class chain in the mangle table:

  $ R "iptables -t mangle -L FORWARD_class | grep 'MARK xset'"
  MARK       all  --  anywhere             192.168.25.0/24      MARK xset 0x5/0x1f
  MARK       udp  --  anywhere             192.168.55.0/24      udp MARK xset 0x4/0x1f

Restore original classification configuration:

  $ cat > /tmp/new-classification <<EOF
  > ba-cli QoS.Classification.icmp_dscp_cs6.Order=1
  > ba-cli QoS.Classification.icmp_dscp_cs6.DSCPMark=48
  > ba-cli QoS.Classification.icmp_dscp_cs1- 
  > ba-cli QoS.Classification.subnet1_high_prio-
  > ba-cli QoS.Classification.icmp_dscp_cs6.Enable = false
  > ba-cli QoS.Classification.lansubnet1.Enable = false
  > ba-cli QoS.Classification.icmp_to_voip_queue.Enable = false
  > ba-cli QoS.QueueStats.stats-guest.Enable = false
  > ba-cli QoS.QueueStats.stats-home-data.Enable = false
  > ba-cli QoS.QueueStats.stats-home-voip.Enable = false
  > ba-cli QoS.QueueStats.stats-home-iptv.Enable = false
  > ba-cli QoS.Queue.queue-guest.Enable = false
  > ba-cli QoS.Queue.queue-home.Enable = false
  > ba-cli QoS.Queue.queue-home-data.Enable = false
  > ba-cli QoS.Queue.queue-home-voip.Enable = false
  > ba-cli QoS.Queue.queue-home-iptv.Enable = false
  > ba-cli QoS.Shaper.shaper-wan.Enable = false
  > ba-cli QoS.Scheduler.scheduler-wan.Enable = false
  > EOF
  $ script --command "ssh -t root@$TARGET_LAN_IP '$(cat /tmp/new-classification)'" > /dev/null
  $ sleep 2
