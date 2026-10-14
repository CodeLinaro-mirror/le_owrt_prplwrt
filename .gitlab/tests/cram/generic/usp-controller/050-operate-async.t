SPDX-FileCopyrightText: Copyright (c) 2026 prpl Foundation

USP Operate of an asynchronous command from the controller to the DUT agent
over MQTT. For an asynchronous Operate, the controller first adds its own
OperationComplete subscription for the command, then sends the Operate with
the command key of the test, waits for the OperationComplete notification with
that key and deletes its subscription again. The command is
Device.SelfTestDiagnostics(). It only reads state and writes a result file to
the DUT, which the test removes. The test changes nothing else:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ . "${TESTDIR}/usp-controller.sh"
  $ command='Device.SelfTestDiagnostics()'

The data model gives the command as asynchronous:

  $ testbed-qemu usp supported-dm "${command}" | grep -F "${command}"
  Device.SelfTestDiagnostics() command type=CMD_ASYNC output=Status,Results

No subscription refers to the command before the Operate, and no request is
running:

  $ testbed-qemu usp get "Device.LocalAgent.Subscription.[ReferenceList==\"${command}\"].ID"
  $ testbed-qemu usp instances Device.LocalAgent.Request.
  $ before=$(testbed-qemu usp get 'Device.LocalAgent.Subscription.*.ID' | wc -l)

The Operate. The command completes in about 5 s, so the test waits at most
30 s for the OperationComplete notification:

  $ since=$(usp_now)
  $ testbed-qemu usp operate-async --json --timeout 30 --command-key usp-async-selftest "${command}" > reply.json

The Operate response refers to the request object that the agent created for
the running command:

  $ python3 -c 'import json
  > for result in json.load(open("reply.json"))["operate_resp"]["body"]["response"]["operate_resp"]["operation_results"]:
  >     print(result["executed_command"], result.get("req_obj_path"))'
  Device\.SelfTestDiagnostics\(\) Device\.LocalAgent\.Request\.[0-9]+ (re)

The OperationComplete notification gives the command, the command key of the
test and the output arguments. The test selects the two arguments that the
data model defines: Status is Complete, and Results is vendor specific. The
agent also sends a vendor argument:

  $ python3 -c 'import json
  > complete = json.load(open("reply.json"))["operation_complete"]
  > for name in ("obj_path", "command_name", "command_key"):
  >     print(name + "=" + complete[name])
  > for name in ("Status", "Results"):
  >     print("output_args." + name + "=" + complete["output_args"][name])'
  obj_path=Device.
  command_name=SelfTestDiagnostics()
  command_key=usp-async-selftest
  output_args.Status=Complete
  output_args.Results=.+ (re)

The controller also keeps the notification. The test reads it through the
client and waits at most 10 s:

  $ testbed-qemu usp notifications --since "${since}" --wait oper_complete --timeout 10 > complete.txt
  $ cut -d ' ' -f 1,3,4 complete.txt
  oper_complete obj_path="Device." command_name="SelfTestDiagnostics()"
  $ grep -o -E '(command_key|output_args\.Status)="[^"]*"' complete.txt
  command_key="usp-async-selftest"
  output_args.Status="Complete"

The controller deleted its subscription: the row it added is gone, no
subscription refers to the command and the number of subscriptions is the same
as before:

  $ subscription=$(python3 -c 'import json; print(json.load(open("reply.json"))["subscription_path"])')
  $ echo "${subscription}"
  Device\.LocalAgent\.Subscription\.[0-9]+\. (re)
  $ testbed-qemu usp instances Device.LocalAgent.Subscription. | grep -c -x -F "${subscription}"
  0
  [1]
  $ testbed-qemu usp get "Device.LocalAgent.Subscription.[ReferenceList==\"${command}\"].ID"
  $ [ "$(testbed-qemu usp get 'Device.LocalAgent.Subscription.*.ID' | wc -l)" = "${before}" ] && echo "same number of subscriptions"
  same number of subscriptions

The agent removed the request object when the command completed:

  $ testbed-qemu usp instances Device.LocalAgent.Request.

Remove the result file of the command from the DUT:

  $ results=$(python3 -c 'import json; print(json.load(open("reply.json"))["operation_complete"]["output_args"]["Results"])')
  $ case ${results} in /tmp/*) R "rm -f '${results}'" ;; esac
