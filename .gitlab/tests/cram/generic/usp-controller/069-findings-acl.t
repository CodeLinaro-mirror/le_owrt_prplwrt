SPDX-FileCopyrightText: Copyright (c) 2026 prpl Foundation

Access control over MQTT with TLS where the DUT agent does not give the result
that TR-369 (USP 1.3, Issue 1 Amendment 3 Corrigendum 1) requires. Each case
expects the result of the specification and quotes the requirement. On a
firmware where the agent departs from the specification, this test fails and
the diff shows what the agent gives instead.

The test uses the same test fixture as 061-acl-tls.t, which describes it: it
limits the Role that the Credential row of the CA of the controller names,
switches the MQTT client of this controller to MQTT with TLS and waits until
the controller sees the encrypted connection, and at the end deletes the
permission rows and the port mappings and switches the MQTT client back to
MQTT without TLS. Before it changes anything on the DUT, it registers a
cleanup that does the same steps when the test shell exits, also when the
test stops early:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ . "${TESTDIR}/usp-controller.sh"
  $ usp_acl_trap
  $ usp_acl_rows_add
  $ role=$(usp_acl_ca_role) && echo "${role}"
  Device\.LocalAgent\.ControllerTrust\.Role\.[0-9]+ (re)
  $ usp_acl_unlimit "${role}."
  $ usp_acl_limit "${role}."
  $ usp_mqtt_switch true
  proto::agent-id mqtt connected=true tls=true
  $ [ "$(usp_dut_value "${usp_acl_ctl}InheritedRole")" = "${role}" ] && echo inherited
  inherited

Get of the object instance that the Role cannot read. The permission row
targets the object instance, so the Role can read neither the instance nor
any parameter in it.

TR-369 section 7.5.1.3.1, R-GET.1: "If the Controller making the Request does
not have Read permission on an Object or Parameter matched through the
requested_path field, the Object or Parameter MUST be treated as if it is not
present in the Agent's Supported data model."

R-GET.0: "If requested_path contains a Path Name (that is not a Search Path)
that does not match any Object or Parameter in the Agent's Instantiated Data
Model, or requested_path contains a Search Path that does not match any
Object or Parameter in the Agent's Supported Data Model, the Agent MUST use
the 7026 - Invalid Path error in this RequestedPathResult."

The specification sets the code, not the message text. A parameter of the
same instance gives 7026 (see 061-acl-tls.t):

  $ testbed-qemu usp get "${usp_acl_b}"
  error: 7026 Device\.NAT\.PortMapping\.[0-9]+\.:.* (re)
  [1]

Delete the permission rows, switch the MQTT client back to MQTT without TLS
and delete the port mappings:

  $ usp_acl_unlimit "${role}."
  $ usp_mqtt_switch false
  proto::agent-id mqtt connected=true tls=false
  $ usp_acl_rows_del
  $ testbed-qemu usp get 'Device.NAT.PortMapping.[Alias=="usp-acl-a"].Alias' 'Device.NAT.PortMapping.[Alias=="usp-acl-b"].Alias'
