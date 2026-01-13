Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Flash the reference image

  $ :

Set the Wi-Fi password

  $ R "ba-cli 'Device.WiFi.AccessPoint.1.Security.KeyPassPhrase=TEST_TEST_TEST'" | grep -v '^>'
  Device.WiFi.AccessPoint.1.Security.
  Device.WiFi.AccessPoint.1.Security.KeyPassPhrase="TEST_TEST_TEST"
  

Store backup:

  $ R "ba-cli 'PersistentConfiguration.Backup()'" | grep -v '^>'
  PersistentConfiguration.Backup() returned
  [
      ""
  ]
  

  $ R tar -C /cfg -czf /tmp/backup.tar.gz pcm

  $ scp -O root@${TARGET_LAN_IP}:/tmp/backup.tar.gz ./backup.tar.gz

Perform upgrade via sysupgrade:

  $ scp -O "$TESTBED_TFTP_PATH"/prplos-*-generic-prpl_freedom-squashfs-sysupgrade.bin root@${TARGET_LAN_IP}:/tmp/image.bin

  $ R sysupgrade /tmp/image.bin > /dev/null 2>&1 || :

  $ sleep ${DUT_SLEEP_AFTER_BOOT} 

Restore backup:

  $ ssh-keyscan -H "$TARGET_LAN_IP" > ~/.ssh/known_hosts 2>/dev/null
  $ scp -O -r ./backup.tar.gz root@${TARGET_LAN_IP}:/tmp/backup.tar.gz

  $ R tar -C /cfg -xzf /tmp/backup.tar.gz

  $ R "ba-cli 'PersistentConfiguration.Restore()'" | grep -v '^>'
  PersistentConfiguration.Restore() returned
  [
      ""
  ]
  

Check the Wi-Fi password

  $ R "ba-cli 'Device.WiFi.AccessPoint.1.Security.KeyPassPhrase?'" | grep -q TEST_TEST_TEST
