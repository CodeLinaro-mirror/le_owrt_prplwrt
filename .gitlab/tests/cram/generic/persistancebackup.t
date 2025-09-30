Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Apply all parameter changes:

  $ R 'ubus-cli Cellular.RoamingEnabled=1 >/dev/null'
  $ R 'ubus-cli ProcessFaults.MaxProcessFaultEntries=10 >/dev/null'
  $ R 'ubus-cli KernelFaults.MaxKernelFaultEntries=10 >/dev/null'
  $ R 'ubus-cli Reboot.Reboot.1.Alias="test-cpe-Reboot-1" >/dev/null'
  $ R 'ubus-cli DHCPv6Client.Client.wan.Enable=0 >/dev/null'
  $ R 'ubus-cli Firewall.Enable=0 >/dev/null'
  $ R 'ubus-cli MQTTBroker.Broker.local.Enable=0 >/dev/null'
  $ R 'ubus-cli BulkData.Enable=1 >/dev/null'
  $ R 'ubus-cli Ethernet.Interface.cpe-wan.EDPDEnable=1 >/dev/null'
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

  $ if R "grep -aq '\"Alias\": \"test-cpe-Reboot-1\"' /cfg/pcm/reboot-service_Reboot.json"; then echo 'Backup OK for plugin reboot-service'; else echo 'Backup ERROR for plugin reboot-service'; fi
  Backup OK for plugin reboot-service

  $ if R "grep -A5 -a '\"wan\"' /cfg/pcm/tr181-dhcpv6client_DHCPv6Client.json | grep -aq '\"Enable\": 0'"; then echo 'Backup OK for plugin tr181-dhcpv6client'; else echo 'Backup ERROR for plugin tr181-dhcpv6client'; fi
  Backup OK for plugin tr181-dhcpv6client

  $ if R "grep -aq '\"Enable\": 0' /cfg/pcm/tr181-firewall_Firewall.json"; then echo 'Backup OK for plugin tr181-firewall'; else echo 'Backup ERROR for plugin tr181-firewall'; fi
  Backup OK for plugin tr181-firewall

  $ if R "grep -A11 -a '\"local\"' /cfg/pcm/tr181-mqttbroker_MQTTBroker.json | grep -aq '\"Enable\": 0'"; then echo 'Backup OK for plugin tr181-mqttbroker'; else echo 'Backup ERROR for plugin tr181-mqttbroker'; fi
  Backup OK for plugin tr181-mqttbroker

  $ if R "grep -aq '\"Enable\": 1' /cfg/pcm/tr181-bulkdata_BulkData.json"; then echo 'Backup OK for plugin tr181-bulkdata'; else echo 'Backup ERROR for plugin tr181-bulkdata'; fi
  Backup OK for plugin tr181-bulkdata

  $ if R "grep -A22 -a '\"cpe-wan\"' /cfg/pcm/ethernet-manager_Ethernet.json | grep -aq '\"EDPDEnable\": 1'"; then echo 'Backup OK for plugin ethernet-manager'; else echo 'Backup ERROR for plugin ethernet-manager'; fi
  Backup OK for plugin ethernet-manager

  $ if R "grep -aq '\"BrightnessLimiter\": 50' /cfg/pcm/tr181-led_LEDs.json"; then echo 'Backup OK for plugin tr181-led'; else echo 'Backup ERROR for plugin tr181-led'; fi
  Backup OK for plugin tr181-led

  $ if R "grep -aq '\"Enable\": 0' /cfg/pcm/tr181-periodicfileupload_PeriodicFileTransfer.json"; then echo 'Backup OK for plugin tr181-periodicfileupload'; else echo 'Backup ERROR for plugin tr181-periodicfileupload'; fi
  Backup OK for plugin tr181-periodicfileupload

  $ if R "grep -aq '\"SensingTimeout\": 10' /cfg/pcm/wan-manager_WANManager.json"; then echo 'Backup OK for plugin wan-manager'; else echo 'Backup ERROR for plugin wan-manager'; fi
  Backup OK for plugin wan-manager