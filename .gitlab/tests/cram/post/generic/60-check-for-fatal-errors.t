Skip this test if the CI job name contains CDRouter and VLAN\
as SSH to DUT is not available (PCF-844):

  $ if echo "$CI_JOB_NAME" | grep -q "^CDRouter.* VLAN "; then exit 80; fi

Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Ensure no unexpected failures obiserved by checking for failure action taken by\
ProcessMointor.Test.i in /var/log/messages and rotated logs.
Exclude prplmesh, wifi-sensing and pwhm checks till FEAT-27 is merged:

  $ R "grep \"amx-processmonitor: process - \[!\]Test.*failed too often,"\
  > " executing action\" /var/log/messages* /var/log/messagess.? 2>/dev/null" \
  > "| grep -vE '(prplmesh|wifi-sensing|wifi-scheduler|wld)' || true"

Ensure no unexpected failures observed by checking for failure action taken by\
ProcessMonitor.Test.i in compressed logs. Exclude wifi-scheduler PPW-1679 \
Exclude prplmesh, wifi-sensing and pwhm checks till FEAT-27 is merged:

  $ R "zcat /var/log/messages*.gz 2>/dev/null | "\
  > "grep \"amx-processmonitor: process - "\
  > "\[!\]Test.*failed too often, executing action\" "\
  > "| grep -vE '(prplmesh|wifi-sensing|wifi-scheduler|wld)' || true"

Ensure no reboots are triggered due to failure by ProcessMonitor \
for ProcessMonitor.Test.i:

  $ R "ba-cli Reboot.Reboot.*.Reason?" | grep ProcessMonitor || true
