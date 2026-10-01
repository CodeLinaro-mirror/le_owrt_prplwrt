Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

The helpers come first, then the cases. Every read goes through ba-cli, as
`ba-cli -j -l <path>? | jsonfilter`, so a helper prints a bare value that cram
can compare byte for byte. A failed read keeps its error output, so it shows up
in the diff instead of reading as an empty value.

  $ BS_UNSET_TIME="0001-01-01T00:00:00Z"          # odl ${unknown_time}: "not set yet"
  $ BS_SERVICE_INIT="/etc/init.d/tr181-bootstatus"
  $ BS_TIME_INIT="/etc/init.d/time-manager"
  $ BS_STATE_FILE="/var/run/tr181-bootstatus.state"  # timeline restored on a restart (tmpfs)
  $ BS_BOOTTIMING="Device.DeviceInfo.BootTiming"
  $ BS_MILESTONE="Device.DeviceInfo.BootTiming.LastBootMilestone"

Tunables (override from CI).

  $ : "${BS_STAGE_WAIT:=120}"            # wait for a BootStage value, seconds
  $ : "${BS_SYNC_WAIT:=240}"             # wait for Device.Time.Status=Synchronized
  $ : "${BS_SERVICE_WAIT:=30}"           # wait for the service to stop or start
  $ : "${BS_CROSSCHECK_TOLERANCE:=15}"   # slack when correlating timestamps, seconds

DUT access

  $ bs_remote() {
  >     ${CRAM_REMOTE_COMMAND:-} "$@"
  > }

Datamodel reads

bs_get <full parameter path> -- bare value. Exact-path lookup only, not
alias-addressed instances. Errors are not hidden.

  $ bs_get() {
  >     bs_remote "ba-cli -j -l '$1?' | jsonfilter -e '@[0][\"${1%.*}.\"].${1##*.}'"
  > }

bs_probe <full parameter path> -- same read with errors hidden. Used only where
an absent value is a valid answer: inside polling loops, and to check that an
object has left the bus.

  $ bs_probe() {
  >     bs_remote "ba-cli -j -l '$1?' 2>/dev/null | jsonfilter -e '@[0][\"${1%.*}.\"].${1##*.}'" 2>/dev/null
  > }

  $ bs_bootstage()      { bs_get Device.DeviceInfo.BootStage; }
  $ bs_lastrebootref()  { bs_get Device.DeviceInfo.LastRebootRef; }
  $ bs_boot_start()     { bs_get "${BS_BOOTTIMING}.BootStartTime"; }
  $ bs_boot_complete()  { bs_get "${BS_BOOTTIMING}.BootCompleteTime"; }
  $ bs_boot_duration()  { bs_get "${BS_BOOTTIMING}.BootDuration"; }
  $ bs_milestone_count(){ bs_get "${BS_BOOTTIMING}.LastBootMilestoneNumberOfEntries"; }

bs_milestone_field <instance index> <Alias|BootStage|TimeStamp>

  $ bs_milestone_field() { bs_get "${BS_MILESTONE}.$1.$2"; }

Row indices 1..N, one per line.

  $ bs_rows() {
  >     _bs_n="$(bs_milestone_count)"
  >     _bs_i=1
  >     while [ "$_bs_i" -le "$_bs_n" ]; do
  >         echo "$_bs_i"
  >         _bs_i=$((_bs_i + 1))
  >     done
  > }

One field of every row, in instance order, on one line.

  $ _bs_field_sequence() {
  >     for _bs_r in $(bs_rows); do
  >         printf '%s ' "$(bs_milestone_field "$_bs_r" "$1")"
  >     done
  >     printf '\n'
  > }

  $ bs_stage_sequence() { _bs_field_sequence BootStage | sed 's/[[:space:]]*$//'; }
  $ bs_alias_sequence() { _bs_field_sequence Alias | sed 's/[[:space:]]*$//'; }

bs_stage_timestamp <stage>: TimeStamp of the row holding <stage>, if any.

  $ bs_stage_timestamp() {
  >     for _bs_r in $(bs_rows); do
  >         if [ "$(bs_milestone_field "$_bs_r" BootStage)" = "$1" ]; then
  >             bs_milestone_field "$_bs_r" TimeStamp
  >             return 0
  >         fi
  >     done
  >     return 1
  > }

Time arithmetic. bs_epoch prints nothing for an empty or unset time, so every
subtraction goes through bs_seconds_apart, which checks both values first.

  $ bs_epoch() {
  >     [ -n "$1" ] || return 1
  >     [ "$1" != "$BS_UNSET_TIME" ] || return 1
  >     date -u -d "$1" +%s
  > }

  $ bs_seconds_apart() {
  >     _bs_a="$(bs_epoch "$1")"
  >     _bs_b="$(bs_epoch "$2")"
  >     if [ -z "$_bs_a" ] || [ -z "$_bs_b" ]; then
  >         echo "UNREADABLE('$1','$2')"
  >         return 1
  >     fi
  >     _bs_d=$((_bs_a - _bs_b))
  >     echo "${_bs_d#-}"
  > }

  $ bs_dut_now_epoch() { bs_remote "date -u +%s"; }

Do NOT compute this as "date +%s minus /proc/uptime": both truncate to whole
seconds, so the result flips between btime and btime+1 and makes any
"-ge kernel boot" assertion randomly flaky. btime is stable and tracks steps.

  $ bs_dut_boot_epoch() { bs_remote "awk '/^btime/{print \$2}' /proc/stat"; }

Invariant checks. Each prints one line: a fixed token, or a self-describing
failure line so a cram diff says what went wrong.

The live scalar must equal the BootStage of the newest row.

  $ bs_live_matches_last_row() {
  >     _bs_count="$(bs_milestone_count)"
  >     _bs_live="$(bs_bootstage)"
  >     _bs_last="$(bs_milestone_field "$_bs_count" BootStage)"
  >     if [ -n "$_bs_live" ] && [ "$_bs_live" = "$_bs_last" ]; then
  >         echo "consistent"
  >     else
  >         echo "MISMATCH: live BootStage='${_bs_live}' newest row (${_bs_count})='${_bs_last}'"
  >     fi
  > }

Once the boot is Completed, every row has a real time and the rows are in
non-decreasing time order. NetworkReady is back-dated to the WAN's own
LastChange, so it is left out of the ordering and checked on its own by
bs_networkready_in_range.

  $ bs_timeline_ordered() {
  >     _bs_prev=""
  >     for _bs_r in $(bs_rows); do
  >         _bs_stage="$(bs_milestone_field "$_bs_r" BootStage)"
  >         _bs_ts="$(bs_milestone_field "$_bs_r" TimeStamp)"
  >         if [ -z "$_bs_ts" ] || [ "$_bs_ts" = "$BS_UNSET_TIME" ]; then
  >             echo "UNSET TimeStamp on row ${_bs_r} (${_bs_stage}) after Completed"
  >             return 0
  >         fi
  >         [ "$_bs_stage" != "NetworkReady" ] || continue
  >         _bs_e="$(bs_epoch "$_bs_ts")"
  >         if [ -n "$_bs_prev" ] && [ "$_bs_e" -lt "$_bs_prev" ]; then
  >             echo "OUT OF ORDER: row ${_bs_r} (${_bs_stage}) ${_bs_ts}"
  >             return 0
  >         fi
  >         _bs_prev="$_bs_e"
  >     done
  >     echo "in order"
  > }

NetworkReady must have a real time, no earlier than the kernel boot and no
later than Completed.

  $ bs_networkready_in_range() {
  >     _bs_net="$(bs_epoch "$(bs_stage_timestamp NetworkReady)")"
  >     _bs_done="$(bs_epoch "$(bs_stage_timestamp Completed)")"
  >     _bs_boot="$(bs_dut_boot_epoch)"
  >     if [ -z "$_bs_net" ] || [ -z "$_bs_done" ] || [ -z "$_bs_boot" ]; then
  >         echo "UNREADABLE: NetworkReady='$(bs_stage_timestamp NetworkReady)' Completed='$(bs_stage_timestamp Completed)' btime='${_bs_boot}'"
  >     elif [ "$_bs_net" -lt "$((_bs_boot - BS_CROSSCHECK_TOLERANCE))" ]; then
  >         echo "NetworkReady $(bs_stage_timestamp NetworkReady) precedes the kernel boot"
  >     elif [ "$_bs_net" -gt "$_bs_done" ]; then
  >         echo "NetworkReady $(bs_stage_timestamp NetworkReady) is after Completed $(bs_stage_timestamp Completed)"
  >     else
  >         echo "in range"
  >     fi
  > }

BootDuration must equal BootCompleteTime - BootStartTime.

  $ bs_duration_consistent() {
  >     _bs_start="$(bs_epoch "$(bs_boot_start)")"
  >     _bs_end="$(bs_epoch "$(bs_boot_complete)")"
  >     _bs_dur="$(bs_boot_duration)"
  >     if [ -z "$_bs_start" ] || [ -z "$_bs_end" ] || [ -z "$_bs_dur" ]; then
  >         echo "INCOMPLETE: BootStartTime/BootCompleteTime/BootDuration not all set"
  >     elif [ "$((_bs_end - _bs_start))" -eq "$_bs_dur" ]; then
  >         echo "consistent"
  >     else
  >         echo "MISMATCH: BootDuration=${_bs_dur} but BootCompleteTime-BootStartTime=$((_bs_end - _bs_start))"
  >     fi
  > }

Polling

bs_poll <timeout> <condition>: re-evaluate <condition> once a second until it
holds; fails once <timeout> seconds of wall clock have passed, so the time the
remote reads take counts against the timeout too.

  $ bs_poll() {
  >     _bs_deadline=$(($(date +%s) + $1))
  >     while ! eval "$2"; do
  >         [ "$(date +%s)" -lt "$_bs_deadline" ] || return 1
  >         sleep 1
  >     done
  > }

bs_wait_stage <stage> [timeout]: prints the stage, or a self-describing timeout.
Completed needs Device.Time.Status=Synchronized, so the timeout names the clock
state as well.

  $ bs_wait_stage() {
  >     _bs_want="$1"
  >     if bs_poll "${2:-$BS_STAGE_WAIT}" '[ "$(bs_probe Device.DeviceInfo.BootStage)" = "$_bs_want" ]'; then
  >         echo "$_bs_want"
  >     else
  >         echo "TIMEOUT after ${2:-$BS_STAGE_WAIT}s waiting for ${_bs_want}, BootStage='$(bs_probe Device.DeviceInfo.BootStage)' Device.Time.Status='$(bs_probe Device.Time.Status)'"
  >     fi
  > }

  $ bs_wait_time_synchronized() {
  >     if bs_poll "$BS_SYNC_WAIT" '[ "$(bs_probe Device.Time.Status)" = "Synchronized" ]'; then
  >         echo "Synchronized"
  >     else
  >         echo "TIMEOUT after ${BS_SYNC_WAIT}s waiting for Device.Time.Status=Synchronized, got '$(bs_probe Device.Time.Status)': the DUT needs a reachable NTP server"
  >         return 1
  >     fi
  > }

Service control

NOT `pgrep -x`: comm is capped at 15 chars so the name shows as
"tr181-bootstatu". The "[t]..." bracket idiom matches the daemon only.

  $ bs_service_running() { bs_remote "ps ax | grep -q '[t]r181-bootstatus'"; }
  $ bs_service_state() {
  >     if bs_service_running; then
  >         echo "running"
  >     else
  >         echo "stopped"
  >     fi
  > }

Stop and start check the exit status of the init script, then poll for the
result instead of sleeping a fixed time. Start waits until BootTiming. is back
on the bus.

  $ bs_service_stop() {
  >     bs_remote "${BS_SERVICE_INIT} stop" >/dev/null || echo "FAIL: ${BS_SERVICE_INIT} stop exited $?"
  >     bs_poll "$BS_SERVICE_WAIT" '! bs_service_running' || echo "TIMEOUT: tr181-bootstatus still running ${BS_SERVICE_WAIT}s after stop"
  > }
  $ bs_service_start() {
  >     bs_remote "${BS_SERVICE_INIT} start" >/dev/null || echo "FAIL: ${BS_SERVICE_INIT} start exited $?"
  >     bs_poll "$BS_SERVICE_WAIT" '[ -n "$(bs_probe "${BS_BOOTTIMING}.LastBootMilestoneNumberOfEntries")" ]' || echo "TIMEOUT: BootTiming. not on the bus ${BS_SERVICE_WAIT}s after start"
  > }
  $ bs_service_restart() { bs_service_stop; bs_service_start; }

A plain restart restores the timeline from the state file, so it does not re-run
the boot sequence. bs_service_fresh_start removes the state file between stop
and start, so the start is the first one in this boot, as after a reboot. It
also sends Boot! again, since the file records that Boot! was sent.

  $ bs_service_fresh_start() {
  >     bs_service_stop
  >     bs_remote "rm -f ${BS_STATE_FILE}" || echo "FAIL: cannot remove ${BS_STATE_FILE}"
  >     bs_service_start
  > }

LastRebootRef

bs_lastreboot_field <Cause|Reason>: the field on the row LastRebootRef names.

  $ bs_lastreboot_field() { bs_get "$(bs_lastrebootref).$1"; }

The highest Reboots.Reboot.{i} instance number that exists. The component picks
the highest index, not the next one, so a gap in the indexes does not matter.

  $ bs_reboot_highest() {
  >     bs_remote "ba-cli -j -l 'Device.DeviceInfo.Reboots.Reboot.*.?'" |
  >         grep -o 'Device\.DeviceInfo\.Reboots\.Reboot\.[0-9]\+\.' |
  >         sed 's/.*Reboot\.\([0-9]\+\)\./\1/' | sort -n | tail -n 1
  > }

LastRebootRef must be the Path Name of the highest existing Reboots.Reboot.{i}.
row.

  $ bs_lastrebootref_valid() {
  >     _bs_ref="$(bs_lastrebootref)"
  >     _bs_top="$(bs_reboot_highest)"
  >     if [ -z "$_bs_top" ]; then
  >         echo "NO Reboots.Reboot rows, LastRebootRef='${_bs_ref}'"
  >     elif [ "$_bs_ref" != "Device.DeviceInfo.Reboots.Reboot.${_bs_top}" ]; then
  >         echo "WRONG LastRebootRef='${_bs_ref}', the newest row is Device.DeviceInfo.Reboots.Reboot.${_bs_top}"
  >     else
  >         echo "valid"
  >     fi
  > }

Read-only enforcement

bs_write <path> <value>: the ERROR line ba-cli prints for the write, then
"unchanged", or a line that says how the value changed.

  $ bs_write() {
  >     _bs_before="$(bs_get "$1")"
  >     bs_remote "ba-cli '$1=\"$2\"'" 2>&1 | grep '^ERROR'
  >     _bs_after="$(bs_get "$1")"
  >     if [ "$_bs_after" = "$_bs_before" ]; then
  >         echo "unchanged"
  >     else
  >         echo "CHANGED: $1 was '${_bs_before}', now '${_bs_after}'"
  >     fi
  > }

bs_cli <command>: the ERROR line ba-cli prints for <command>.

  $ bs_cli() { bs_remote "ba-cli '$1'" 2>&1 | grep '^ERROR'; }

Timeline snapshots

  $ bs_table_fingerprint() {
  >     printf '%s|%s|%s|' "$(bs_milestone_count)" "$(bs_stage_sequence)" "$(bs_alias_sequence)"
  >     for _bs_r in $(bs_rows); do
  >         printf '%s,' "$(bs_milestone_field "$_bs_r" TimeStamp)"
  >     done
  >     printf '\n'
  > }

  $ bs_snapshot() {
  >     printf '%s|%s|%s|%s|%s|' "$(bs_bootstage)" "$(bs_lastrebootref)" "$(bs_boot_start)" "$(bs_boot_complete)" "$(bs_boot_duration)"
  >     bs_table_fingerprint
  > }

FSM transitions logged after a marker. The component logs every transition as
a NOTICE "BootStage -> <stage>" (src/lifecycle_fsm.c). Starting from a marker
line, not a line count, keeps the window right when the log ring buffer wraps;
if the marker itself has been rotated out, nothing is printed and the check
fails.

  $ bs_logged_stages() {
  >     bs_remote "logread" | sed -n "/$1/,\$p" | sed -n 's/.*BootStage -> \([A-Za-z]*\).*/\1/p' |
  >         awk '{ printf "%s%s", sep, $0; sep = " " } END { printf "\n" }'
  > }

Check the DUT answers and the component is installed. There is no skip: if any
of this is missing, the test fails. When the DUT does not answer, the test
stops here with a failure instead of running every wait to its timeout.

  $ [ -n "${CRAM_REMOTE_COMMAND:-}" ] && echo "remote" || echo "FAIL: CRAM_REMOTE_COMMAND is unset, so every probe would run on the cram host instead of the DUT"
  remote
  $ R "echo bootstatus-cram-alive" || { echo "FAIL: the DUT does not answer via '${CRAM_REMOTE_COMMAND:-}'"; exit 1; }
  bootstatus-cram-alive
  $ R "test -x ${BS_SERVICE_INIT} && echo present"
  present
  $ R "test -x ${BS_TIME_INIT} && echo present"
  present
  $ R "logger -t cram 'bootstatus-cram: starting BootStatus run'"

Put time-manager and tr181-bootstatus back if the test stops early, so the
tests that run after this one find both running, with the FSM trace zone at its
default. Starting a service that is already running does nothing:

  $ trap 'bs_remote "${BS_TIME_INIT} start; ${BS_SERVICE_INIT} start; ba-cli \"BootTiming.set_trace_zone(zone=bootstatus_fsm, level=200)\"" >/dev/null 2>&1' EXIT

Check the clock is trusted, since Completed needs it. Without a reachable NTP
server every later wait for Completed would time out for the same reason, so the
test stops here instead:

  $ bs_wait_time_synchronized || exit 1
  Synchronized
  $ bs_wait_stage Completed
  Completed

C-1. Every published value can be read back:

Read the current boot stage, the reference to the last reboot, the boot start
time, the boot complete time, the boot duration and the milestone table over
ba-cli. Every value must come back, the row counter must agree with the number
of rows actually present, and every row must carry its alias, its stage name
and its timestamp.

Check BootStage and LastRebootRef:

  $ bs_bootstage
  Completed
  $ bs_lastrebootref
  Device\.DeviceInfo\.Reboots\.Reboot\.\d+ (re)

Check the three BootTiming scalars. The clock is synchronized, so both times
must be real ones; the unset value 0001-01-01T00:00:00Z does not match:

  $ bs_boot_start
  20\d{2}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z (re)
  $ bs_boot_complete
  20\d{2}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z (re)
  $ bs_boot_duration
  \d+ (re)

Check the counter agrees with the rows present:

  $ bs_milestone_count
  6
  $ R "ba-cli -j -l '${BS_MILESTONE}.*.?' | jsonfilter -e '@[0][*].BootStage'" | grep -c .
  6

Check every row carries all three parameters, in boot order, with agent-assigned
aliases:

  $ bs_stage_sequence
  Started PowerOn KernelReady NetworkReady ManagementReady Completed
  $ bs_alias_sequence
  cpe-LastBootMilestone-1 cpe-LastBootMilestone-2 cpe-LastBootMilestone-3 cpe-LastBootMilestone-4 cpe-LastBootMilestone-5 cpe-LastBootMilestone-6
  $ for i in $(bs_rows); do
  >   [ -n "$(bs_milestone_field "$i" TimeStamp)" ] || echo "FAIL: row $i has no TimeStamp"
  > done; echo done
  done

Check one subtree read returns all four scalars:

  $ R "ba-cli -j -l '${BS_BOOTTIMING}.?'" | grep -oE '"(BootStartTime|BootCompleteTime|BootDuration|LastBootMilestoneNumberOfEntries)"' | sort -u | wc -l | tr -d ' '
  4

C-2. The reference to the last reboot points at the right record:

Confirm the reference names the newest row of the reboot history and that the
row records both a cause and a reason. The DUT is not rebooted, so the row is
the one the current boot created. 154-reboot-service.t runs after this test,
flushes the history and checks that the reference is then cleared.

Check a reboot history is present:

  $ bs_get Device.DeviceInfo.Reboots.RebootNumberOfEntries
  [1-9]\d* (re)

Check LastRebootRef names the newest row:

  $ bs_lastrebootref_valid
  valid

Check the row records a cause and a reason:

  $ [ -n "$(bs_lastreboot_field Cause)" ] && echo "has Cause" || echo "FAIL: no Cause on $(bs_lastrebootref)"
  has Cause
  $ [ -n "$(bs_lastreboot_field Reason)" ] && echo "has Reason" || echo "FAIL: no Reason on $(bs_lastrebootref)"
  has Reason

C-3. The published values do not drift once the boot is over:

Take a snapshot of every published value and compare it with a second read
straight away. The same snapshot is compared once more at the end of C-6, after
the write attempts of C-4 to C-6, so the values are compared across the time
those cases take without an idle wait. The device's own clock must move on while
the recorded timeline does not: the boot completion time stays in the past and
the boot start time never precedes the moment the kernel started.

  $ FIRST="$(bs_snapshot)"

Check reads are not silently failing:

  $ echo "$FIRST" | cut -d'|' -f1
  Completed

Check back-to-back reads agree:

  $ [ "$(bs_snapshot)" = "$FIRST" ] && echo stable || echo "DRIFTED immediately: '$(bs_snapshot)' != '$FIRST'"
  stable

Check the DUT clock is past the recorded timeline:

  $ NOW="$(bs_dut_now_epoch)"
  $ DONE="$(bs_epoch "$(bs_boot_complete)")"
  $ [ -n "$NOW" ] && [ -n "$DONE" ] && [ "$NOW" -gt "$DONE" ] && echo OK || echo "FAIL: BootCompleteTime '$(bs_boot_complete)' is not before the DUT time '$NOW'"
  OK
  $ START="$(bs_epoch "$(bs_boot_start)")"
  $ BTIME="$(bs_dut_boot_epoch)"
  $ [ -n "$START" ] && [ -n "$BTIME" ] && [ "$START" -ge "$BTIME" ] && echo OK || echo "FAIL: BootStartTime '$(bs_boot_start)' precedes the kernel boot instant '$BTIME'"
  OK

C-4. The boot stage cannot be written:

Attempt to set the boot stage to another stage and to a value that is not one of
the defined stages, and confirm each write is refused with "is read only" and
the value is unchanged afterwards. The values must not change.

Check BootStage rejects a write:

  $ bs_write Device.DeviceInfo.BootStage Started
  ERROR: set Device.DeviceInfo.BootStage failed (15 - is read only)
  unchanged
  $ bs_write Device.DeviceInfo.BootStage NotAStage
  ERROR: set Device.DeviceInfo.BootStage failed (15 - is read only)
  unchanged

Check both values are still the same:

  $ STAGE_BEFORE="$(bs_bootstage)"
  $ REF_BEFORE="$(bs_lastrebootref)"
  $ [ "$(bs_bootstage)" = "$STAGE_BEFORE" ] && echo unchanged || echo "FAIL: BootStage is now '$(bs_bootstage)', was '$STAGE_BEFORE'"
  unchanged
  $ [ "$(bs_lastrebootref)" = "$REF_BEFORE" ] && echo unchanged || echo "FAIL: LastRebootRef is now '$(bs_lastrebootref)', was '$REF_BEFORE'"
  unchanged

C-5. The reference to the last reboot cannot be written:

Attempt to set the reference both to a reboot row that does not exist and to an
empty value, and confirm each write is refused, the value is unchanged, and it
still names the newest reboot record afterwards.

Check LastRebootRef rejects a wrong reference and a clear:

  $ bs_write Device.DeviceInfo.LastRebootRef "Device.DeviceInfo.Reboots.Reboot.99"
  ERROR: set Device.DeviceInfo.LastRebootRef failed (15 - is read only)
  unchanged
  $ bs_write Device.DeviceInfo.LastRebootRef ""
  ERROR: set Device.DeviceInfo.LastRebootRef failed (15 - is read only)
  unchanged
  $ bs_lastrebootref_valid
  valid
  $ [ -n "$(bs_lastreboot_field Reason)" ] && echo OK || echo "FAIL: the referenced row no longer resolves"
  OK

C-6. The boot timing values cannot be written:

Attempt to set the boot start time, the boot complete time and the boot
duration, and confirm each write is refused and each value is unchanged. The
milestone rows are covered too: no row's timestamp, stage name or alias may be
written, and no row may be added or deleted. After each attempt the table must
be unchanged. Afterwards the values must still match the C-3 snapshot, the
duration must still add up, the timestamps must still be in order and the
service must still be running.

Check the BootTiming scalars reject writes:

  $ bs_write "${BS_BOOTTIMING}.BootStartTime" "2000-01-01T00:00:00Z"
  ERROR: set Device.DeviceInfo.BootTiming.BootStartTime failed (15 - is read only)
  unchanged
  $ bs_write "${BS_BOOTTIMING}.BootCompleteTime" "2000-01-01T00:00:00Z"
  ERROR: set Device.DeviceInfo.BootTiming.BootCompleteTime failed (15 - is read only)
  unchanged
  $ bs_write "${BS_BOOTTIMING}.BootDuration" "1"
  ERROR: set Device.DeviceInfo.BootTiming.BootDuration failed (15 - is read only)
  unchanged

Check the milestone rows are read-only. BootStage is %unique, so a stage that
another row already holds is refused as a duplicate:

  $ TABLE_BEFORE="$(bs_table_fingerprint)"
  $ bs_table_unchanged() { [ "$(bs_table_fingerprint)" = "$TABLE_BEFORE" ] && echo "table unchanged" || echo "FAIL: table is now '$(bs_table_fingerprint)', was '$TABLE_BEFORE'"; }
  $ bs_write "${BS_MILESTONE}.1.TimeStamp" "2000-01-01T00:00:00Z"
  ERROR: set Device.DeviceInfo.BootTiming.LastBootMilestone.1.TimeStamp failed (15 - is read only)
  unchanged
  $ bs_table_unchanged
  table unchanged
  $ bs_write "${BS_MILESTONE}.1.BootStage" "Completed"
  ERROR: set Device.DeviceInfo.BootTiming.LastBootMilestone.1.BootStage failed (13 - duplicate)
  unchanged
  $ bs_table_unchanged
  table unchanged
  $ bs_write "${BS_MILESTONE}.1.BootStage" "Stopping"
  ERROR: set Device.DeviceInfo.BootTiming.LastBootMilestone.1.BootStage failed (15 - is read only)
  unchanged
  $ bs_table_unchanged
  table unchanged

Check the Agent-assigned Alias cannot be written a second time:

  $ bs_write "${BS_MILESTONE}.1.Alias" "cram-alias"
  ERROR: set Device.DeviceInfo.BootTiming.LastBootMilestone.1.Alias failed (15 - is read only)
  unchanged
  $ bs_table_unchanged
  table unchanged

Check rows cannot be added or deleted:

  $ bs_cli "${BS_MILESTONE}.+"
  ERROR: .* \(11 - invalid action\) (re)
  $ bs_table_unchanged
  table unchanged
  $ bs_cli "${BS_MILESTONE}.1.-"
  ERROR: .* \(11 - invalid action\) (re)
  $ bs_table_unchanged
  table unchanged

Check everything still matches the C-3 snapshot and the service is unharmed:

  $ [ "$(bs_snapshot)" = "$FIRST" ] && echo stable || echo "DRIFTED since C-3: '$(bs_snapshot)' != '$FIRST'"
  stable
  $ bs_duration_consistent
  consistent
  $ bs_timeline_ordered
  in order
  $ bs_networkready_in_range
  in range
  $ bs_service_state
  running

C-7 (part 1). The device records every boot stage change, in order:

Take the BootStatus service through one stop and one start. The device must
record every state change exactly once and in boot order: Stopping, then
Started, PowerOn, KernelReady, NetworkReady, ManagementReady, Completed. No
stage may be recorded twice or skipped, the last one must equal the value that
can be read live, and the sequence must match the milestone table. The restart
replays the stages saved in the state file, so it logs every stage again. The
changes are read from the FSM's own log lines, after a marker.

C-8 is the stop half of that cycle, so C-7 resumes below it. The device is never
rebooted.

The stage changes are NOTICE lines, which the default trace level (200) leaves
out. Raise the FSM trace zone until C-7 is done:

  $ R "ba-cli 'BootTiming.set_trace_zone(zone=bootstatus_fsm, level=500)'" > /dev/null

  $ MARK="bootstatus-cram-mark-$$-$(date +%s)"
  $ R "logger -t cram '$MARK'"

C-8. The device reports Stopping before the service goes down:

Take the BootStatus service down and confirm it publishes the Stopping state
before it exits, that the boot timing branch leaves the bus together with the
service that owns it, and that the boot stage and the reference to the last
reboot stay readable. Only the service is stopped; the device stays up.

Stop the service:

  $ bs_service_stop
  $ bs_service_state
  stopped

Check Stopping was published and logged before exit:

  $ bs_bootstage
  Stopping
  $ bs_logged_stages "$MARK"
  Stopping

Check BootTiming. left the bus while BootStage and LastRebootRef survived:

  $ [ -z "$(bs_probe "${BS_BOOTTIMING}.LastBootMilestoneNumberOfEntries")" ] && echo "BootTiming. is off the bus" || echo "FAIL: BootTiming. still answers although its owner is stopped"
  BootTiming. is off the bus
  $ bs_lastrebootref
  Device\.DeviceInfo\.Reboots\.Reboot\.\d+ (re)

C-7 (part 2). The changes are checked once the service is back:

Start the service again:

  $ bs_service_start
  $ bs_wait_stage Completed
  Completed

Check one change per stage, in FSM order:

  $ bs_logged_stages "$MARK"
  Stopping Started PowerOn KernelReady NetworkReady ManagementReady Completed

Check the changes agree with the live value and the restored table:

  $ [ "$(bs_logged_stages "$MARK" | awk '{ print $NF }')" = "$(bs_bootstage)" ] && echo OK || echo "FAIL: last logged '$(bs_logged_stages "$MARK" | awk '{ print $NF }')' != live '$(bs_bootstage)'"
  OK
  $ [ "$(bs_logged_stages "$MARK" | cut -d' ' -f2-)" = "$(bs_stage_sequence)" ] && echo OK || echo "FAIL: logged boot sequence differs from the milestone table"
  OK

Put the FSM trace zone back to the default:

  $ R "ba-cli 'BootTiming.set_trace_zone(zone=bootstatus_fsm, level=200)'" > /dev/null

Re-check the invariants:

  $ bs_milestone_count
  6
  $ bs_live_matches_last_row
  consistent
  $ bs_timeline_ordered
  in order
  $ bs_networkready_in_range
  in range
  $ bs_duration_consistent
  consistent

C-9. The milestone table is kept across a restart and rebuilt every boot:

The timeline describes the device boot, not the service, so a restart of the
BootStatus service must keep it as it was: the same values, the same table, the
same completion time. Then run the boot sequence twice more as the first start
in this boot, by removing the state file between stop and start, each time over
the table the previous run left behind, and confirm after each run that the
table is replaced rather than extended: the same six rows in the same order and
aliases starting again from the first. The moment the kernel started must not
move, because it belongs to the running kernel and not to the service. A first
start back-dates every stage it missed from the kernel, WAN and management agent
times, so both rebuilds in the same boot must give the same table. A new
completion time needs a new boot; proving it across two real reboots is manual
procedure M-8.

  $ KERNEL_TS="$(bs_stage_timestamp Started)"
  $ PREV_SNAPSHOT="$(bs_snapshot)"

Restart the service and check the timeline is kept:

  $ bs_service_restart
  $ bs_wait_stage Completed
  Completed
  $ [ "$(bs_snapshot)" = "$PREV_SNAPSHOT" ] && echo kept || echo "FAIL: the restart changed the timeline: '$(bs_snapshot)' != '$PREV_SNAPSHOT'"
  kept

Run the boot sequence again:

  $ bs_service_fresh_start
  $ bs_wait_stage Completed
  Completed

Check the row set is identical and Aliases restart from the first:

  $ bs_milestone_count
  6
  $ bs_stage_sequence
  Started PowerOn KernelReady NetworkReady ManagementReady Completed
  $ bs_alias_sequence
  cpe-LastBootMilestone-1 cpe-LastBootMilestone-2 cpe-LastBootMilestone-3 cpe-LastBootMilestone-4 cpe-LastBootMilestone-5 cpe-LastBootMilestone-6

Check the kernel-entry timestamp did not move (tolerance, not byte-equality):

  $ D="$(bs_seconds_apart "$(bs_stage_timestamp Started)" "$KERNEL_TS")" && [ "$D" -le "$BS_CROSSCHECK_TOLERANCE" ] && echo preserved || echo "FAIL: Started moved ${D}s on a service restart ($KERNEL_TS -> $(bs_stage_timestamp Started)); it must stay anchored to kernel entry"
  preserved

Check the rebuilt timeline is consistent:

  $ bs_timeline_ordered
  in order
  $ bs_networkready_in_range
  in range
  $ bs_duration_consistent
  consistent
  $ bs_live_matches_last_row
  consistent

Run the boot sequence a third time:

  $ PREV_TABLE="$(bs_table_fingerprint)"
  $ bs_service_fresh_start
  $ bs_wait_stage Completed
  Completed

Check the same again, so the table does not grow, and check the second rebuild
gives the same table as the first:

  $ bs_milestone_count
  6
  $ bs_stage_sequence
  Started PowerOn KernelReady NetworkReady ManagementReady Completed
  $ bs_alias_sequence
  cpe-LastBootMilestone-1 cpe-LastBootMilestone-2 cpe-LastBootMilestone-3 cpe-LastBootMilestone-4 cpe-LastBootMilestone-5 cpe-LastBootMilestone-6
  $ D="$(bs_seconds_apart "$(bs_stage_timestamp Started)" "$KERNEL_TS")" && [ "$D" -le "$BS_CROSSCHECK_TOLERANCE" ] && echo preserved || echo "FAIL: Started moved ${D}s on a service restart ($KERNEL_TS -> $(bs_stage_timestamp Started)); it must stay anchored to kernel entry"
  preserved
  $ [ "$(bs_table_fingerprint)" = "$PREV_TABLE" ] && echo same || echo "FAIL: the second rebuild in this boot differs: '$(bs_table_fingerprint)' != '$PREV_TABLE'"
  same
  $ bs_timeline_ordered
  in order
  $ bs_networkready_in_range
  in range
  $ bs_duration_consistent
  consistent
  $ bs_live_matches_last_row
  consistent

C-10. A boot the device runs without a trusted clock:

Run the boot sequence again as the first start in this boot, with the time
service off the bus, so the device has no trusted time, and confirm the boot advances to ManagementReady and stops
there, because completion requires a trusted clock. Five milestone rows exist and
every published time reads the unset placeholder, while the device's own wall
clock still reads a plausible time. Put the time service back and the timeline
fills itself in: completion is reached on its own, the placeholders are replaced
by real times that fall between the kernel starting and now, and the ordering and
the duration stay consistent. Proving the same across a real boot with no
reachable time source is manual procedure M-7.

The component has no timeout on the wait for Completed: BootStage stays at
ManagementReady for as long as the clock is untrusted, which is what this case
checks.

Check the clock is trusted right now:

  $ bs_get Device.Time.Status
  Synchronized

Take Device.Time. off the bus and re-run the boot sequence:

  $ R "${BS_TIME_INIT} stop" >/dev/null && echo stopped || echo "FAIL: ${BS_TIME_INIT} stop exited $?"
  stopped
  $ bs_poll "$BS_SERVICE_WAIT" '[ -z "$(bs_probe Device.Time.Status)" ]' && echo gone || echo "FAIL: Device.Time. is still answering"
  gone
  $ bs_service_fresh_start

Check the FSM stops at ManagementReady (Completed needs Time.Status Synchronized):

  $ bs_wait_stage ManagementReady
  ManagementReady
  $ bs_stage_sequence
  Started PowerOn KernelReady NetworkReady ManagementReady
  $ bs_milestone_count
  5

Check the DUT wall clock reads a plausible time:

  $ YEAR="$(R "date -u +%Y")"
  $ [ -n "$YEAR" ] && [ "$YEAR" -ge 2020 ] && echo plausible || echo "IMPLAUSIBLE: DUT date reads year '$YEAR'"
  plausible

Check every published timestamp reads the unset sentinel:

  $ bs_boot_start
  0001-01-01T00:00:00Z
  $ bs_boot_complete
  0001-01-01T00:00:00Z
  $ bs_boot_duration
  0
  $ for i in $(bs_rows); do
  >   [ "$(bs_milestone_field "$i" TimeStamp)" = "$BS_UNSET_TIME" ] || echo "FAIL: row $i reads $(bs_milestone_field "$i" TimeStamp)"
  > done; echo checked
  checked

Restore the clock and check the timeline back-fills:

  $ R "${BS_TIME_INIT} start" >/dev/null && echo started || echo "FAIL: ${BS_TIME_INIT} start exited $?"
  started
  $ bs_wait_time_synchronized
  Synchronized

Check Completed advances on its own and the times are filled in:

  $ bs_wait_stage Completed
  Completed
  $ bs_poll "$BS_SERVICE_WAIT" '[ "$(bs_probe "${BS_BOOTTIMING}.BootCompleteTime")" != "$BS_UNSET_TIME" ]' && echo "back-filled" || echo "FAIL: BootCompleteTime still reads the sentinel"
  back-filled
  $ [ "$(bs_boot_start)" != "$BS_UNSET_TIME" ] && echo "back-filled" || echo "FAIL: BootStartTime still reads the sentinel"
  back-filled
  $ bs_milestone_count
  6
  $ bs_timeline_ordered
  in order
  $ bs_networkready_in_range
  in range
  $ bs_duration_consistent
  consistent
  $ bs_live_matches_last_row
  consistent

Check the back-filled times are real:

  $ START="$(bs_epoch "$(bs_boot_start)")"
  $ BTIME="$(bs_dut_boot_epoch)"
  $ [ -n "$START" ] && [ -n "$BTIME" ] && [ "$START" -ge "$BTIME" ] && echo OK || echo "FAIL: BootStartTime '$(bs_boot_start)' precedes the kernel boot instant '$BTIME'"
  OK
  $ DONE="$(bs_epoch "$(bs_boot_complete)")"
  $ NOW="$(bs_dut_now_epoch)"
  $ [ -n "$DONE" ] && [ -n "$NOW" ] && [ "$DONE" -le "$NOW" ] && echo OK || echo "FAIL: BootCompleteTime '$(bs_boot_complete)' is after the DUT time '$NOW'"
  OK

Teardown. Both services are running again, so the cleanup trap is no longer
needed:

  $ bs_service_state
  running
  $ bs_get Device.Time.Status
  Synchronized
  $ trap - EXIT
