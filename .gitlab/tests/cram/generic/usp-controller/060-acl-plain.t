SPDX-FileCopyrightText: Copyright (c) 2026 prpl Foundation

Access control for a controller that connects over MQTT without TLS. Without
TLS, the DUT agent has no certificate of the controller. The agent then gives
the controller the inherited Role Device.LocalAgent.ControllerTrust.Role.1
(Full Access). This is the vendor default of the agent: the build sets the
inherited Role of a connection without TLS (ROLE_NON_SSL and ROLE_DEFAULT in
the vendor definitions of obuspa), and no parameter changes it.

TR-369 section 8.9.2.3: "Where multiple assigned and inherited Roles have
overlapping Targets entries, the resulting permission is the union of all
assigned and inherited permissions."

The test adds a limited Role and assigns it to the controller row of this
controller. The limited Role has the same three permission rows that
061-acl-tls.t adds to the Role of a TLS connection: no permission on the port
mapping usp-acl-b, no write on the Description of the port mapping usp-acl-a,
and no execute on SendOnBoardRequest() of this controller. Each operation that
061-acl-tls.t shows as denied succeeds here, because the inherited Role
permits it. The test deletes the rows, the subscription and the Role that it
adds, and puts the assigned Role back. Before it changes anything on the
DUT, it registers a cleanup that does the same steps when the test shell
exits, also when the test stops early:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ . "${TESTDIR}/usp-controller.sh"
  $ limited='Device.LocalAgent.ControllerTrust.Role.[Alias=="usp-acl-limited"].'
  $ sub='Device.LocalAgent.Subscription.[ID=="usp-acl-plain"].'
  $ usp_acl_trap usp-acl-plain

Remove what an interrupted earlier run can have left, then add the two port
mappings:

  $ testbed-qemu usp delete "${sub}" >/dev/null 2>&1; testbed-qemu usp delete "${limited}" >/dev/null 2>&1; true
  $ usp_acl_rows_add

Add the limited Role with its permission rows, and assign it to the controller
row of this controller:

  $ testbed-qemu usp add Device.LocalAgent.ControllerTrust.Role. Alias=usp-acl-limited Name=usp-acl-limited Enable=true >/dev/null
  $ role=$(testbed-qemu usp get "${limited}Alias" | sed -n 's/Alias=.*$//p')
  $ usp_acl_limit "${role}"
  $ usp_acl_assigned=$(usp_dut_value "${usp_acl_ctl}AssignedRole")
  $ testbed-qemu usp set "${usp_acl_ctl}AssignedRole=${role%.}" >/dev/null

The controller connects without TLS. Its inherited Role is the vendor default
Full Access Role, and its assigned Role is the limited Role:

  $ usp_mqtt_wait false
  proto::agent-id mqtt connected=true tls=false
  $ usp_dut_value "${usp_acl_ctl}InheritedRole"
  Device.LocalAgent.ControllerTrust.Role.1
  $ [ "$(usp_dut_value "${usp_acl_ctl}AssignedRole")" = "${role%.}" ] && echo assigned
  assigned

A Get of a parameter of usp-acl-b returns the value:

  $ testbed-qemu usp get "${usp_acl_b}Description"
  Device\.NAT\.PortMapping\.[0-9]+\.Description="usp-acl-b0" (re)

A Get with a wildcard returns both port mappings:

  $ testbed-qemu usp get 'Device.NAT.PortMapping.*.Alias' | grep usp-acl-
  Device\.NAT\.PortMapping\.[0-9]+\.Alias="usp-acl-a" (re)
  Device\.NAT\.PortMapping\.[0-9]+\.Alias="usp-acl-b" (re)

A Set of the Description of usp-acl-a changes it:

  $ testbed-qemu usp set "${usp_acl_a}Description=usp-acl-a1"
  Device\.NAT\.PortMapping\.[0-9]+\.Description="usp-acl-a1" (re)
  $ usp_dut_value "${usp_acl_a}Description"
  usp-acl-a1

An Operate of SendOnBoardRequest() runs, and the controller receives the
OnBoardRequest. The test waits at most 10 s:

  $ since=$(usp_now)
  $ testbed-qemu usp operate "${usp_acl_ctl}SendOnBoardRequest()"
  Device\.LocalAgent\.Controller\.[0-9]+\.SendOnBoardRequest\(\) (re)
  $ testbed-qemu usp notifications --since "${since}" --wait on_board_req --timeout 10 | grep -c '^on_board_req '
  1

A ValueChange subscription to the Description of usp-acl-b delivers a
notification when the value changes on the DUT. The test waits at most 10 s:

  $ testbed-qemu usp subscribe usp-acl-plain ValueChange "${usp_acl_b}Description" | grep '\.ID='
  Device\.LocalAgent\.Subscription\.[0-9]+\.ID="usp-acl-plain" (re)
  $ since=$(usp_now)
  $ R "ba-cli -l 'NAT.PortMapping.[Alias==\"usp-acl-b\"].Description=\"usp-acl-b1\"'" >/dev/null
  $ usp_notify_wait "${since}" usp-acl-plain 10
  value_change usp-acl-plain param_path="Device\.NAT\.PortMapping\.[0-9]+\.Description" param_value="usp-acl-b1" (re)

Put the assigned Role back, and delete the subscription, the Role and the port
mappings:

  $ testbed-qemu usp set "${usp_acl_ctl}AssignedRole=${usp_acl_assigned}" >/dev/null
  $ [ "$(usp_dut_value "${usp_acl_ctl}AssignedRole")" = "${usp_acl_assigned}" ] && echo restored
  restored
  $ testbed-qemu usp delete "${sub}" "${limited}" >/dev/null
  $ usp_acl_rows_del
  $ testbed-qemu usp get "${sub}ID" "${limited}Alias" 'Device.NAT.PortMapping.[Alias=="usp-acl-a"].Alias' 'Device.NAT.PortMapping.[Alias=="usp-acl-b"].Alias'
