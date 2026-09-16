tr181-device runs as tr181_app and reaches root through the two NOPASSWD rules
in /etc/sudoers.d/tr181-device. 002-processes-privileges.t asserts that those
rules are listed; this test asserts that they are usable by the service account.

Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

The debug-information module prepends sudo whenever its euid is not 0, so the
service account must be able to execute the collector as root:

  $ R "sudo -n -u tr181_app -g tr181_app sudo -n /bin/getDebugInformation --help" 2>&1 | grep -c "Collects misc information from the HGW"
  1

Device.Reboot() and Device.FactoryReset() both run "sudo /sbin/reboot".
Executing it would take the DUT down for the rest of the suite, so query the
policy for that exact command instead of running it. sudo -l exits 0 when the
command is permitted:

  $ R "sudo -n -u tr181_app -g tr181_app sudo -n -l /sbin/reboot >/dev/null 2>&1; echo \$?"
  0

The grant must stay command-scoped: a binary that is present but not listed in
the rules is refused:

  $ R "sudo -n -u tr181_app -g tr181_app sudo -n /bin/busybox true"
  sudo: a password is required
  [1]
