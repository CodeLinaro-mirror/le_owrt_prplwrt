Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Check that logrotate is properly setup:

  $ R "/usr/sbin/logrotate /etc/logrotate.conf"

  $ R 'grep /var/log/messages /var/lib/logrotate.status | cut -d\" -f2'
  /var/log/messages_wifi
  /var/log/messages_lcm.log
  /var/log/messages_cram
  /var/log/messages_dhcp
  /var/log/messages
  /var/log/messages_firewall

  $ R 'grep /var/log/hostapd /var/lib/logrotate.status | cut -d\" -f2'
  /var/log/hostapd

  $ R 'grep /var/log/wpa_supplicant /var/lib/logrotate.status | cut -d\" -f2'
  /var/log/wpa_supplicant

  $ R "grep /usr/sbin/logrotate /etc/crontabs/root"
  */10 * * * * /usr/sbin/logrotate /etc/logrotate.conf
