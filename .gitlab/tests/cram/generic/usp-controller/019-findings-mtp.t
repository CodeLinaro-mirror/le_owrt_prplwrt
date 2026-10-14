SPDX-FileCopyrightText: Copyright (c) 2026 prpl Foundation

The configuration of the DUT agent can change through its local command line
while the agent runs. This test deletes the MQTT client that the onboarding
created, adds a new MQTT client and adds a subscription to it. It expects
each command to succeed and the agent to keep running as the same process,
with no fault recorded. On a firmware where the agent stops instead, this test
fails and the diff shows what the agent gives. Whatever the result, the test
then puts the agent back in the state that the later tests expect: it removes
its own rows and the controller rows, restarts the agent and onboards it over
MQTT again:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ . "${TESTDIR}/usp-controller.sh"

The MQTT client that the onboarding created for the controller:

  $ ctl=$(usp_controller_id)
  $ client=$(usp_dut_value "Device.LocalAgent.Controller.[EndpointID==\"${ctl}\"].MTP.[Protocol==\"MQTT\"].MQTT.Reference")
  $ echo "${client}"
  Device\.MQTT\.Client\.[0-9]+\. (re)
  $ pid=$(R pidof obuspa)
  $ faults=$(R "cat /ext/faults/count 2>/dev/null || echo 0")

Delete the client, add a new client and add a subscription to the new client:

  $ R "obuspa -c del ${client}"
  Deleted Device\.MQTT\.Client\.[0-9]+ (re)
  $ R "obuspa -c add Device.MQTT.Client." > added.txt; cat added.txt
  Added Device\.MQTT\.Client\.[0-9]+ (re)
  $ added=$(sed -n 's/^Added \(Device\.MQTT\.Client\.[0-9]*\)$/\1./p' added.txt)
  $ R "obuspa -c add ${added}Subscription."
  Added Device\.MQTT\.Client\.[0-9]+\.Subscription\.[0-9]+ (re)

The agent still runs as the same process:

  $ [ "$(R pidof obuspa)" = "${pid}" ]

Put the agent back. Wait until it answers, remove the client that this test
added and the controller rows, restart the agent and onboard it over MQTT
again:

  $ usp_agent_wait
  $ [ -z "${added}" ] || R "obuspa -c del ${added}" >/dev/null
  $ testbed-qemu usp cleanup --all >/dev/null
  $ usp_agent_restart
  $ testbed-qemu usp onboard mqtt --no-tls >/dev/null
  $ testbed-qemu usp agents | sed 's/ enabled=[a-z]*//'
  proto::agent-id connected=true
  proto::agent-id mqtt connected=true tls=false
  proto::agent-id stomp connected=false tls=false
  proto::agent-id websocket connected=false tls=false

The agent recorded no fault during this test:

  $ [ "$(R "cat /ext/faults/count 2>/dev/null || echo 0")" = "${faults}" ]
