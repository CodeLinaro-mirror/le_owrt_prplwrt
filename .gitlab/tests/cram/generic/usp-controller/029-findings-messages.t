SPDX-FileCopyrightText: Copyright (c) 2026 prpl Foundation

USP messages where the DUT agent does not give the result that TR-369 (USP
1.3, Issue 1 Amendment 3 Corrigendum 1) requires. Each case expects the
result of the specification and quotes the requirement. On a firmware where
the agent departs from the specification, this test fails and the diff shows
what the agent gives instead. The test changes nothing outside its own rows,
which it adds disabled and deletes at the end:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ . "${TESTDIR}/usp-controller.sh"
  $ a='Device.NAT.PortMapping.[Alias=="usp-msg-findings-a"].'
  $ b='Device.NAT.PortMapping.[Alias=="usp-msg-findings-b"].'

Remove the rows that an interrupted earlier run can have left:

  $ testbed-qemu usp delete "${a}" >/dev/null 2>&1; testbed-qemu usp delete "${b}" >/dev/null 2>&1; true

Get of an instance that does not exist, in an object of a USP service.

TR-369 section 7.5.1.3, R-GET.0: "If requested_path contains a Path Name
(that is not a Search Path) that does not match any Object or Parameter in
the Agent's Instantiated Data Model, or requested_path contains a Search Path
that does not match any Object or Parameter in the Agent's Supported Data
Model, the Agent MUST use the 7026 - Invalid Path error in this
RequestedPathResult."

The specification sets the code, not the message text. An object of the
agent itself gives 7026 (see 020-get.t):

  $ testbed-qemu usp get Device.IP.Interface.9999.
  error: 7026 Device\.IP\.Interface\.9999\.:.* (re)
  [1]

Delete of an instance that does not exist, in an object of a USP service, by
instance number and by search expression.

TR-369 section 7.4.6.3, R-DEL.2a: "If the requested_path was valid (i.e.,
properly formatted and in the Agent's supported data model) but did not
resolve to any Objects in the Agent's instantiated data model, the Agent MUST
return an OperationSuccess for this requested_path, and include an empty set
for affected_path."

An OperationSuccess with no affected path prints nothing. An object of the
agent itself gives this result (see 024-delete.t):

  $ testbed-qemu usp delete Device.NAT.PortMapping.9999.
  $ testbed-qemu usp delete 'Device.NAT.PortMapping.[Alias=="usp-msg-findings-none"].'

Set without allow_partial of two objects of one USP service, where the
second object fails. The paths use instance numbers, so each path matches
exactly one object.

TR-369 section 7.4.5.2, R-SET.1: "If the allow_partial field is set to
false, and no other exceptions are encountered, the Agent treats each
UpdateObject message obj_path holistically. A failure to update any one
Object MUST cause the Set Message to fail and return an Error Message (see
Using Allow Partial and Required Parameters)."

TR-369 section 7.4.3: "If allow_partial is false, the failure of any
required Parameters will cause the update or creation of the Object to fail,
which will cause the entire Message to fail. In this case, the Agent returns
an Error Message rather than a response Message."

The client marks every parameter as required. The read-only Status makes the
second object fail. The reply must be an Error message, and the first object
must keep its value:

  $ testbed-qemu usp add Device.NAT.PortMapping. Alias=usp-msg-findings-a ExternalPort=50531 Description=unchanged Enable=false >/dev/null
  $ testbed-qemu usp add Device.NAT.PortMapping. Alias=usp-msg-findings-b ExternalPort=50532 Enable=false >/dev/null
  $ pa=$(testbed-qemu usp get "${a}Alias" | sed -n 's/Alias=.*$//p')
  $ pb=$(testbed-qemu usp get "${b}Alias" | sed -n 's/Alias=.*$//p')
  $ testbed-qemu usp set --json "${pa}Description=changed" "${pb}Status=Enabled" 2>/dev/null | grep -o '"msg_type_name": "[A-Z_]*"'
  "msg_type_name": "ERROR"
  $ testbed-qemu usp get "${pa}Description"
  Device\.NAT\.PortMapping\.[0-9]+\.Description="unchanged" (re)

Remove the rows of this test:

  $ testbed-qemu usp delete "${a}" "${b}" >/dev/null
  $ testbed-qemu usp get 'Device.NAT.PortMapping.*.Alias' | grep -c usp-msg-findings
  0
  [1]
