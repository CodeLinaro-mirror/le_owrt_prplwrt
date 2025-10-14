Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"


Prepare new instance for Tests:

  $ R 'ubus-cli "Reboot.RemoveAllReboots()" >/dev/null'
  $ R 'ubus-cli "Reboot.AddNewEntry()" >/dev/null'
  $ R 'ubus-cli "Ethernet.Link.+ {Alias=\"test_pcb\", Name=\"test_pcb\"}" >/dev/null'
  $ R 'ubus-cli "MQTTBroker.Broker.+ {Alias =\"test_pcb\", Name=\"test_pcb\"}" >/dev/null'
  $ R 'ubus-cli "DHCPv6Client.Client.+ {Alias=\"test_pcb\"}" >/dev/null'


  $ alias_val=$(R "ubus-cli 'Reboot._get_instances(rel_path=\"Reboot.\")'" | grep -oE 'Alias = \"[^\"]+\"' | sed 's/Alias = \"//; s/\"//' | head -1)

Apply all parameter changes:

  $ R 'ubus-cli Cellular.RoamingEnabled=1 >/dev/null'
  $ R 'ubus-cli ProcessFaults.MaxProcessFaultEntries=10 >/dev/null'
  $ R 'ubus-cli KernelFaults.MaxKernelFaultEntries=10 >/dev/null'
  $ R "ubus-cli Reboot.Reboot.${alias_val}.Alias=\"test-${alias_val}\" >/dev/null"
  $ R 'ubus-cli DHCPv6Client.Client.test_pcb.Enable=1 >/dev/null'
  $ R 'ubus-cli Firewall.Enable=0 >/dev/null'
  $ R 'ubus-cli MQTTBroker.Broker.test_pcb.Enable=1 >/dev/null'
  $ R 'ubus-cli BulkData.Enable=1 >/dev/null'
  $ R 'ubus-cli Ethernet.Link.test_pcb.Enable=1 >/dev/null'
  $ R 'ubus-cli LEDs.BrightnessLimiter=50 >/dev/null'
  $ R 'ubus-cli PeriodicFileTransfer.Enable=0 >/dev/null'
  $ R 'ubus-cli WANManager.SensingTimeout=10 >/dev/null'

Run one backup for all:

  $ R 'ubus-cli "PersistentConfiguration.Backup()" >/dev/null'

Check JSON content matches updated values:

  $ if R "grep -aq '\"RoamingEnabled\": 1' /cfg/pcm/cellular-manager_Cellular.json"; then echo 'Backup OK for plugin cellular-manager'; else echo 'Backup ERROR for plugin cellular-manager'; fi
  Backup OK for plugin cellular-manager

  $ if R "grep -aq '\"MaxProcessFaultEntries\": 10' /cfg/pcm/amx-faultmonitor_ProcessFaults.json"; then echo 'Backup OK for plugin amx-faultmonitor'; else echo 'Backup ERROR for plugin amx-faultmonitor'; fi
  Backup OK for plugin amx-faultmonitor

  $ if R "grep -aq '\"MaxKernelFaultEntries\": 10' /cfg/pcm/oopsmonitor_KernelFaults.json"; then echo 'Backup OK for plugin oopsmonitor'; else echo 'Backup ERROR for plugin oopsmonitor'; fi
  Backup OK for plugin oopsmonitor

  $ if R "grep -aq '\"Alias\": \"test-${alias_val}\"' /cfg/pcm/reboot-service_Reboot.json"; then echo 'Backup OK for plugin reboot-service'; else echo 'Backup ERROR for plugin reboot-service'; fi
  Backup OK for plugin reboot-service

  $ if R "grep -A5 -a '\"test_pcb\"' /cfg/pcm/tr181-dhcpv6client_DHCPv6Client.json | grep -aq '\"Enable\": 1'"; then echo 'Backup OK for plugin tr181-dhcpv6client'; else echo 'Backup ERROR for plugin tr181-dhcpv6client'; fi
  Backup OK for plugin tr181-dhcpv6client

  $ if R "grep -aq '\"Enable\": 0' /cfg/pcm/tr181-firewall_Firewall.json"; then echo 'Backup OK for plugin tr181-firewall'; else echo 'Backup ERROR for plugin tr181-firewall'; fi
  Backup OK for plugin tr181-firewall

  $ if R "grep -A11 -a '\"test_pcb\"' /cfg/pcm/tr181-mqttbroker_MQTTBroker.json | grep -aq '\"Enable\": 1'"; then echo 'Backup OK for plugin tr181-mqttbroker'; else echo 'Backup ERROR for plugin tr181-mqttbroker'; fi
  Backup OK for plugin tr181-mqttbroker

  $ if R "grep -aq '\"Enable\": 1' /cfg/pcm/tr181-bulkdata_BulkData.json"; then echo 'Backup OK for plugin tr181-bulkdata'; else echo 'Backup ERROR for plugin tr181-bulkdata'; fi
  Backup OK for plugin tr181-bulkdata

  $ if R "grep -A22 -a '\"test_pcb\"' /cfg/pcm/ethernet-manager_Ethernet.json | grep -aq '\"Enable\": 1'"; then echo 'Backup OK for plugin ethernet-manager'; else echo 'Backup ERROR for plugin ethernet-manager'; fi
  Backup OK for plugin ethernet-manager

  $ if R "grep -aq '\"BrightnessLimiter\": 50' /cfg/pcm/tr181-led_LEDs.json"; then echo 'Backup OK for plugin tr181-led'; else echo 'Backup ERROR for plugin tr181-led'; fi
  Backup OK for plugin tr181-led

  $ if R "grep -aq '\"Enable\": 0' /cfg/pcm/tr181-periodicfileupload_PeriodicFileTransfer.json"; then echo 'Backup OK for plugin tr181-periodicfileupload'; else echo 'Backup ERROR for plugin tr181-periodicfileupload'; fi
  Backup OK for plugin tr181-periodicfileupload

  $ if R "grep -aq '\"SensingTimeout\": 10' /cfg/pcm/wan-manager_WANManager.json"; then echo 'Backup OK for plugin wan-manager'; else echo 'Backup ERROR for plugin wan-manager'; fi
  Backup OK for plugin wan-manager

Restore to the configuration before test:

  $ R 'ubus-cli Cellular.RoamingEnabled=0 >/dev/null'
  $ R 'ubus-cli ProcessFaults.MaxProcessFaultEntries=5 >/dev/null'
  $ R 'ubus-cli KernelFaults.MaxKernelFaultEntries=5 >/dev/null'
  $ R 'ubus-cli "Reboot.RemoveAllReboots()" >/dev/null'
  $ R 'ubus-cli "Reboot.AddNewEntry()" >/dev/null'
  $ R 'ubus-cli DHCPv6Client.Client.test_pcb.- >/dev/null'
  $ R 'ubus-cli Firewall.Enable=1 >/dev/null'
  $ R 'ubus-cli MQTTBroker.Broker.test_pcb.- >/dev/null'
  $ R 'ubus-cli BulkData.Enable=0 >/dev/null'
  $ R 'ubus-cli Ethernet.Link.test_pcb.- >/dev/null'
  $ R 'ubus-cli LEDs.BrightnessLimiter=100 >/dev/null'
  $ R 'ubus-cli PeriodicFileTransfer.Enable=1 >/dev/null'
  $ R 'ubus-cli WANManager.SensingTimeout=8 >/dev/null'

Run one backup for restored configuration:

  $ R 'ubus-cli "PersistentConfiguration.Backup()" >/dev/null'
