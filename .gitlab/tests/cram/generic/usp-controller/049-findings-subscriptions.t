SPDX-FileCopyrightText: Copyright (c) 2026 prpl Foundation

Subscriptions where the DUT agent does not give the result that TR-369 (USP
1.3, Issue 1 Amendment 3 Corrigendum 1) requires. Each case expects the
result of the specification and quotes the requirement. On a firmware where
the agent departs from the specification, this test fails and the diff shows
what the agent gives instead. The test deletes every subscription that it
adds and restores the value it changes:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ . "${TESTDIR}/usp-controller.sh"
  $ event='Device.LocalAgent.Subscription.[ID=="usp-sub-findings-event"].'
  $ command='Device.LocalAgent.Subscription.[ID=="usp-sub-findings-command"].'
  $ ctl=$(usp_controller_id)
  $ row=$(testbed-qemu usp get "Device.LocalAgent.Controller.[EndpointID==\"${ctl}\"].EndpointID" | sed -n 's/EndpointID=.*$//p')

Remove the subscriptions that an interrupted earlier run can have left:

  $ testbed-qemu usp delete "${event}" "${command}" >/dev/null 2>&1; true

An Object Path in the ReferenceList of an Event or an OperationComplete
subscription.

TR-369 section 7.6.1, R-NOT.0: "The Agent and Controller MUST follow the
normative requirements defined in the Device.LocalAgent.Subscription.{i}.
Object specified in the Device:2 Data Model [3]."

The Device:2 Data Model (TR-181 Issue 2 Amendment 17),
Device.LocalAgent.Subscription.{i}.ReferenceList: "Event: may be either a
Path Name, Search Path, or Event reference; if an Object Path (one type of
Path Name) then it is treated like a filter match such that all supported
Events in all objects below this point will be relevant for the
subscription." and "OperationComplete: may be either a Path Name, Search
Path, or Command reference; if an Object Path (one type of Path Name) then it
is treated like a filter match such that all supported data model commands in
all objects below this point will be relevant for the subscription."

An Event subscription to the Object Path Device.LocalAgent. is added, and it
gets Periodic!, an event of that object. The test sets the notification
interval of the controller row of this controller to 5 s, waits at most 15 s
and restores the interval:

  $ testbed-qemu usp subscribe usp-sub-findings-event Event Device.LocalAgent. | grep '\.ID='
  Device\.LocalAgent\.Subscription\.[0-9]+\.ID="usp-sub-findings-event" (re)
  $ old=$(testbed-qemu usp get "${row}PeriodicNotifInterval" | sed -n 's/^[^=]*="\(.*\)"$/\1/p')
  $ since=$(usp_now)
  $ testbed-qemu usp set "${row}PeriodicNotifInterval=5" >/dev/null
  $ usp_notify_wait "${since}" usp-sub-findings-event 15 | head -n 1
  event usp-sub-findings-event obj_path="Device.LocalAgent." event_name="Periodic!"
  $ testbed-qemu usp set "${row}PeriodicNotifInterval=${old}" >/dev/null
  $ [ "$(testbed-qemu usp get "${row}PeriodicNotifInterval")" = "${row}PeriodicNotifInterval=\"${old}\"" ] && echo restored
  restored

An OperationComplete subscription to the Object Path of the controller row of
this controller is added:

  $ testbed-qemu usp subscribe --disable usp-sub-findings-command OperationComplete "${row}" | grep '\.ID='
  Device\.LocalAgent\.Subscription\.[0-9]+\.ID="usp-sub-findings-command" (re)

Remove the subscriptions of this test:

  $ testbed-qemu usp delete "${event}" "${command}" >/dev/null 2>&1; true
  $ testbed-qemu usp get "${event}ID" "${command}ID"
