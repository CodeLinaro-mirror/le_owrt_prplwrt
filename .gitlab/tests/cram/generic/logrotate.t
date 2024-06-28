Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Check the which file paths are defined, every filed in define should result in a config in the next part of the test
  $ R 'ubus-cli Syslog.Action.*.LogFile.FilePath?'| grep -o '\".*\"'
  "file:///var/log/messages_wifi"
  "file:///var/log/messages_firewall"
  "file:///var/log/messages_dhcp"
  "file:///var/log/messages_lcm.log"
  "file:///var/log/messages"
  ""

Check that logrotate is properly setup:

  $ R "/usr/sbin/logrotate /etc/logrotate.conf"

  $ R 'grep /var/log/messages /var/lib/logrotate.status | cut -d\" -f2'
  /var/log/messages_wifi
  /var/log/messages_lcm.log
  /var/log/messages_dhcp
  /var/log/messages
  /var/log/messages_firewall

  $ R "grep /usr/sbin/logrotate /etc/crontabs/root"
  */10 * * * * /usr/sbin/logrotate /etc/logrotate.conf
