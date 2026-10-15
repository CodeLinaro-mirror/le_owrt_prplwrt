SPDX-FileCopyrightText: Copyright (c) 2026 prpl Foundation

Access control for a controller that connects over MQTT with TLS, with a Role
that denies some operations. The controller asks for each denied operation,
and the DUT agent refuses it as TR-369 requires.

Over TLS, the agent gives the controller the Role of the
ControllerTrust.Credential row of the CA that signed the certificate of the
server. TR-369 section 8.9.2.4: "The ControllerTrust.Credential.{i}.Role
Parameter value is inherited by Controllers whose credentials have been
validated using the credentials in the same entry of the
ControllerTrust.Credential.{i}. table."

The limited Role is a test fixture, not the behaviour of the product. On this
firmware the Credential table and its Role parameter are read-only, and the
agent gives every CA of its trust store the same Role at start. So the test
cannot point the Credential row of the CA of the controller to a new Role.
Instead it limits the Role that this Credential row names. It adds three
permission rows to that Role, with an Order higher than the Order of the rows
of the agent. The Device:2 Data Model (TR-181 Issue 2 Amendment 17),
Device.LocalAgent.ControllerTrust.Role.{i}.Permission.{i}.: "If there are
multiple entries in this table for a specific Role where the Targets overlap,
the permissions for the entry with the highest value takes priority over all
others." The first row gives no permission on the port mapping usp-acl-b,
the object instance and all its parameters. The second row gives read and
notify, but no write, on the Description of the port mapping usp-acl-a. The
third row gives read, but no execute, on SendOnBoardRequest() of the
controller row of this controller.

While the rows exist, they apply to every controller with that Role. The test
adds them, then switches the MQTT client of this controller to MQTT with TLS
and waits until the controller sees the encrypted connection. At the end it
deletes the rows with the command line of the agent and switches the MQTT
client back to MQTT without TLS. It also deletes the port mappings and
subscriptions that it adds. Before it changes anything on the DUT, it
registers a cleanup that does the same steps when the test shell exits, also
when the test stops early:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ . "${TESTDIR}/usp-controller.sh"
  $ sub_a='Device.LocalAgent.Subscription.[ID=="usp-acl-tls-a"].'
  $ sub_b='Device.LocalAgent.Subscription.[ID=="usp-acl-tls-b"].'
  $ usp_acl_trap usp-acl-tls-a usp-acl-tls-b

Remove what an interrupted earlier run can have left, then add the two port
mappings:

  $ testbed-qemu usp delete "${sub_a}" >/dev/null 2>&1; testbed-qemu usp delete "${sub_b}" >/dev/null 2>&1; true
  $ usp_acl_rows_add

The Role of the CA of the controller, and the permission rows:

  $ role=$(usp_acl_ca_role) && echo "${role}"
  Device\.LocalAgent\.ControllerTrust\.Role\.[0-9]+ (re)
  $ usp_acl_unlimit "${role}."
  $ usp_acl_limit "${role}."

Switch the MQTT client of this controller to MQTT with TLS and wait until
the controller sees the encrypted connection. The inherited Role of the
controller is the Role of the CA. The agent sets the inherited Role when it
connects:

  $ usp_mqtt_switch true
  proto::agent-id mqtt connected=true tls=true
  $ [ "$(usp_dut_value "${usp_acl_ctl}InheritedRole")" = "${role}" ] && echo inherited
  inherited

Get of a parameter that the Role cannot read.

TR-369 section 7.5.1.3.1, R-GET.1: "If the Controller making the Request does
not have Read permission on an Object or Parameter matched through the
requested_path field, the Object or Parameter MUST be treated as if it is not
present in the Agent's Supported data model."

R-GET.0: "If requested_path contains a Path Name (that is not a Search Path)
that does not match any Object or Parameter in the Agent's Instantiated Data
Model, or requested_path contains a Search Path that does not match any
Object or Parameter in the Agent's Supported Data Model, the Agent MUST use
the 7026 - Invalid Path error in this RequestedPathResult."

  $ testbed-qemu usp get "${usp_acl_b}Description"
  error: 7026 Device\.NAT\.PortMapping\.[0-9]+\.Description: DM_PRIV_CheckGetReadPermissions: Invalid path (re)
  [1]

Get with a wildcard and with a search expression, and GetInstances. They
leave out the port mapping that the Role cannot read, and they give no error.
R-GET.1 above applies, and the Device:2 Data Model gives this Read permission
for an object instance in the InstantiatedObj parameter of the Permission
object: "Read: Grants the capability to read the instance numbers and unique
keys of the Instantiated Object via GetInstances and read the value of
Parameters related to the Instantiated Object via a Get containing a search
expression or wildcard in place of the instance identifier."

  $ testbed-qemu usp get 'Device.NAT.PortMapping.*.Alias' > rows.txt
  $ grep usp-acl- rows.txt
  Device\.NAT\.PortMapping\.[0-9]+\.Alias="usp-acl-a" (re)
  $ testbed-qemu usp get 'Device.NAT.PortMapping.[Alias=="usp-acl-b"].Alias'
  $ testbed-qemu usp instances Device.NAT.PortMapping. > instances.txt
  $ grep -cxF "${usp_acl_a}" instances.txt; grep -cxF "${usp_acl_b}" instances.txt
  1
  0
  [1]

Set of a parameter that the Role can read but cannot write. The agent
refuses it with the code that the error table of TR-369 section 7.8 gives:
"7006 Permission denied Error Message This error indicates that the source
Endpoint does not have the authorization for this action." The value on the
DUT does not change.

TR-369 section 8.2, R-SEC.1: "An Agent MUST confirm a Controller has the
necessary permissions to perform the requested actions in a Message prior to
performing that action."

  $ testbed-qemu usp set "${usp_acl_a}Description=usp-acl-a1"
  error: 7006 Device\.NAT\.PortMapping\.[0-9]+\.Description: GROUP_SET_VECTOR_Add: No permission to write to Device\.NAT\.PortMapping\.[0-9]+\.Description (re)
  error: 7006 GROUP_SET_VECTOR_Add: No permission to write to Device\.NAT\.PortMapping\.[0-9]+\.Description (re)
  [1]
  $ usp_dut_value "${usp_acl_a}Description"
  usp-acl-a0

Operate of a command that the Role can read but cannot execute. R-SEC.1
applies, and the Device:2 Data Model gives this permission in the
CommandEvent parameter of the Permission object: "Execute: Grants the
capability to execute the Command via Operate, but grants no capabilities to
an Event." The reply is an Error message, and the controller receives no
OnBoardRequest. The test waits 5 s for it, and the client reports that none
arrived. The error code is not shown here: no TR-369 requirement sets it:

  $ since=$(usp_now)
  $ testbed-qemu usp operate --json "${usp_acl_ctl}SendOnBoardRequest()" 2>/dev/null | grep -o '"msg_type_name": "[A-Z_]*"'
  "msg_type_name": "ERROR"
  $ testbed-qemu usp notifications --since "${since}" --wait on_board_req --timeout 5
  error: no on_board_req notification from proto::agent-id@[0-9a-f]+ within 5 s (re)
  [1]

ValueChange subscriptions to the Description of each port mapping. The value
of both changes on the DUT. The controller gets a notification for usp-acl-a,
which the Role can read and be notified of. It gets none for usp-acl-b. The
Device:2 Data Model gives this permission in the Param parameter of the
Permission object: "Notify: Grants the capability to receive Notify Messages
of type ValueChange for this Parameter." The test waits at most 10 s for
usp-acl-a, then 5 s more for usp-acl-b:

  $ testbed-qemu usp subscribe usp-acl-tls-b ValueChange "${usp_acl_b}Description" | grep '\.ID='
  Device\.LocalAgent\.Subscription\.[0-9]+\.ID="usp-acl-tls-b" (re)
  $ testbed-qemu usp subscribe usp-acl-tls-a ValueChange "${usp_acl_a}Description" | grep '\.ID='
  Device\.LocalAgent\.Subscription\.[0-9]+\.ID="usp-acl-tls-a" (re)
  $ since=$(usp_now)
  $ R "ba-cli -l 'NAT.PortMapping.[Alias==\"usp-acl-b\"].Description=\"usp-acl-b1\"'" >/dev/null
  $ R "ba-cli -l 'NAT.PortMapping.[Alias==\"usp-acl-a\"].Description=\"usp-acl-a2\"'" >/dev/null
  $ usp_notify_wait "${since}" usp-acl-tls-a 10
  value_change usp-acl-tls-a param_path="Device\.NAT\.PortMapping\.[0-9]+\.Description" param_value="usp-acl-a2" (re)
  $ usp_notify_wait "${since}" usp-acl-tls-b 5
  usp-controller: no notification for subscription usp-acl-tls-b within 5 s
  [1]

Delete the subscriptions and the permission rows, and switch the MQTT client
back to MQTT without TLS:

  $ testbed-qemu usp delete "${sub_a}" "${sub_b}" >/dev/null
  $ usp_acl_unlimit "${role}."
  $ usp_mqtt_switch false
  proto::agent-id mqtt connected=true tls=false

Delete the port mappings:

  $ usp_acl_rows_del
  $ testbed-qemu usp get "${sub_a}ID" "${sub_b}ID" 'Device.NAT.PortMapping.[Alias=="usp-acl-a"].Alias' 'Device.NAT.PortMapping.[Alias=="usp-acl-b"].Alias'
