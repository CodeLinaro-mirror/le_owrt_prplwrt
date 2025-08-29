Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

  $ R logger -t cram "Starting process started by procd verification tests"

Verify expected processes that should be started by procd are running using ubus call service list command
Verify amx-processmonitor
  $ R "ubus call service list | sed '/^$/d' | jsonfilter -e '@[\"amx-processmonitor\"][\"instances\"][\"amx-processmonitor\"].running' -e '@[\"amx-processmonitor\"][\"instances\"][\"amx-processmonitor\"].pid'"
  true
  \d+ (re)

Verify tr181-device process
  $ R "ubus call service list | sed '/^$/d' |  jsonfilter -e '@[\"tr181-device\"][\"instances\"][\"tr181-device\"].running'  -e '@[\"tr181-device\"][\"instances\"][\"tr181-device\"].pid'"
  true
  \d+ (re)

Verify tr181.mqtt process
  $ R "ubus call service list | sed '/^$/d' |  jsonfilter -e '@[\"tr181-mqtt\"][\"instances\"][\"tr181-mqtt\"].running' -e '@[\"tr181-mqtt\"][\"instances\"][\"tr181-mqtt\"].pid'"
  true
  \d+ (re)

Verify tr181-pcp, tr181-firewall, tr181-qos processes
  $ R "ubus call service list | jsonfilter -e '@[\"tr181-pcp\"][\"instances\"][\"tr181-pcp\"].running'  -e '@[\"tr181-pcp\"][\"instances\"][\"tr181-pcp\"].pid' -e '@[\"tr181-firewall\"][\"instances\"][\"tr181-firewall\"].running'  -e '@[\"tr181-firewall\"][\"instances\"][\"tr181-firewall\"].pid' -e '@[\"tr181-qos\"][\"instances\"][\"tr181-qos\"].running'  -e '@[\"tr181-qos\"][\"instances\"][\"tr181-qos\"].pid' -e '@[\"tr181-mqttbroker\"][\"instances\"][\"tr181-mqttbroker\"].running' -e '@[\"tr181-mqttbroker\"][\"instances\"][\"tr181-mqttbroker\"].pid'"
  true
  \d+ (re)
  true
  \d+ (re)
  true
  \d+ (re)
  true
  \d+ (re)

Verify tr181-bridging process
  $ R "ubus call service list | sed '/^$/d' |  jsonfilter -e '@[\"tr181-bridging\"][\"instances\"][\"tr181-bridging\"].running' -e '@[\"tr181-bridging\"][\"instances\"][\"tr181-bridging\"].pid'"
  true
  \d+ (re)

Verify tr181-ppp process
  $ R "ubus call service list | sed '/^$/d' |  jsonfilter -e '@[\"tr181-ppp\"][\"instances\"][\"tr181-ppp\"].running' -e '@[\"tr181-ppp\"][\"instances\"][\"tr181-ppp\"].pid'"
  true
  \d+ (re)

Verify tr181-dns process
  $ R "ubus call service list | sed '/^$/d' |  jsonfilter -e '@[\"tr181-dns\"][\"instances\"][\"tr181-dns\"].running' -e '@[\"tr181-dns\"][\"instances\"][\"tr181-dns\"].pid'"
  true
  \d+ (re)

Verify tr181-xpon process
  $ R "ubus call service list | sed '/^$/d' |  jsonfilter -e '@[\"tr181-xpon\"][\"instances\"][\"tr181-xpon\"].running' -e '@[\"tr181-xpon\"][\"instances\"][\"tr181-xpon\"].pid'"
  true
  \d+ (re)

Verify deviceinfo-manager process
  $ R "ubus call service list | sed '/^$/d' | jsonfilter -e '@[\"deviceinfo-manager\"][\"instances\"][\"deviceinfo-manager\"].running' -e '@[\"deviceinfo-manager\"][\"instances\"][\"deviceinfo-manager\"].pid'"
  true
  \d+ (re)

  $ R logger -t cram "Test finished!"

