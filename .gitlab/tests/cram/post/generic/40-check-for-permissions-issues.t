Skip this test if the CI job name contains CDRouter and VLAN as SSH to DUT is not available (PCF-844):

  $ if echo "$CI_JOB_NAME" | grep -q "^CDRouter.* VLAN "; then exit 80; fi

Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Check that there are no signs of failed file access attempts
in /var/log/messages and rotated logs:

  $ R "grep " \
  > "-e EPERM -e EACCES " \
  > "/var/log/messages* /var/log/messagess.? 2>/dev/null " \
  > "|| true"

Check that there are no signs of failed file access attempts
in compressed logs:

  $ R "zcat /var/log/messages*.gz 2>/dev/null | grep " \
  > "-e EPERM -e EACCES " \
  > "|| true"

Check that there are no signs of failed sudo attempts
in /var/log/messages and rotated logs

  $ R "grep " \
  > "-E \"sudo: .*: command not allowed\" " \
  > "/var/log/messages* /var/log/messagess.? 2>/dev/null " \
  > "|| true"

Check that there are no signs of failed sudo attempts
in compressed logs:

  $ R "zcat /var/log/messages*.gz 2>/dev/null | grep " \
  > "-E \"sudo: .*: command not allowed\" " \
  > "|| true"
