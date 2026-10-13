Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Add testing service:

  $ scp -O -r $TESTDIR/035-multisettings/* root@${TARGET_LAN_IP}:/

Restart multisettings service and start testing service:

  $ R "/etc/init.d/testing-emitter start 2> /dev/null"
  $ R "/etc/init.d/testing-receiver start 2> /dev/null"
  $ R "/etc/init.d/multisettings restart 2> /dev/null"

multisettings must still run as tr181_app after that restart. A RUN_AS mismatch
silently leaves it as root, which would make the escalation below vacuous:

  $ R "i=0; while [ \$i -lt 30 ] && ! pgrep -x -u tr181_app multisettings >/dev/null; do i=\$((i+1)); sleep 1; done; pgrep -x --count -u tr181_app multisettings"
  1

Add testing profiles and triggers:

  $ printf "\
  > ubus-cli MultiSettings.DetectionAtBoot=1
  > ubus-cli MultiSettings.Profile.+{Alias='france-profile'}
  > ubus-cli MultiSettings.Profile.france-profile.Name='france'
  > ubus-cli MultiSettings.Profile.france-profile.ImpactedModules='testing-receiver'
  > ubus-cli MultiSettings.Profile.france-profile.Trigger.+{Alias='country-france'}
  > ubus-cli MultiSettings.Profile.france-profile.Trigger.country-france.LeftMember='TestingEmitter.CountryCode'
  > ubus-cli MultiSettings.Profile.france-profile.Trigger.country-france.RelationalOperator='Equal'
  > ubus-cli MultiSettings.Profile.france-profile.Trigger.country-france.RightMember='FR'
  > ubus-cli MultiSettings.Profile.+{Alias='usa-profile'}
  > ubus-cli MultiSettings.Profile.usa-profile.Name='usa'
  > ubus-cli MultiSettings.Profile.usa-profile.ImpactedModules='testing-receiver'
  > ubus-cli MultiSettings.Profile.usa-profile.Trigger.+{Alias='country-usa'}
  > ubus-cli MultiSettings.Profile.usa-profile.Trigger.country-usa.LeftMember='TestingEmitter.CountryCode'
  > ubus-cli MultiSettings.Profile.usa-profile.Trigger.country-usa.RelationalOperator='Equal'
  > ubus-cli MultiSettings.Profile.usa-profile.Trigger.country-usa.RightMember='US'
  > " > /tmp/cram
  $ script --command "ssh -t root@$TARGET_LAN_IP '$(cat /tmp/cram)'" > /dev/null

Check that there is no profile currently selected:

  $ R "cat /var/run/selected_profile"
  cat: can't open '/var/run/selected_profile': No such file or directory
  [1]

Check that TestingReceiver and TestingEmitter have correct default settings:

  $ R "ubus call TestingReceiver _get \"{'rel_path':''}\" | jsonfilter -e @[*].NTPServer1 -e @[*].NTPServer2 | sort"
  0.eu.pool.ntp.org
  1.eu.pool.ntp.org

  $ R "ubus call TestingEmitter _get \"{'rel_path':''}\" | jsonfilter -e @[*].CountryCode"
  EU

Change profile to France:

  $ script --command "ssh -t root@$TARGET_LAN_IP ubus-cli TestingEmitter.CountryCode='FR'" > /dev/null; sleep 5

Check that french profile is correctly applied:

  $ R "ubus list | grep TestingReceiver"
  TestingReceiver

  $ R "ubus call TestingReceiver _get \"{'rel_path':''}\" | jsonfilter -e @[*].NTPServer1 -e @[*].NTPServer2 | sort"
  0.fr.pool.ntp.org
  1.fr.pool.ntp.org

multisettings stops and starts its impacted modules with
"sudo /etc/init.d/<module> <action>". Verify the service account can really
drive an init.d script through that grant, using the fixture installed above:

  $ R "sudo -n -u tr181_app -g tr181_app sudo -n /etc/init.d/testing-receiver stop"
  $ R "i=0; while [ \$i -lt 30 ] && ubus list | grep -qx TestingReceiver; do i=\$((i+1)); sleep 1; done; ubus list | grep -cx TestingReceiver"
  0
  [1]

  $ R "sudo -n -u tr181_app -g tr181_app sudo -n /etc/init.d/testing-receiver start"
  $ R "i=0; while [ \$i -lt 30 ] && ! ubus list | grep -qx TestingReceiver; do i=\$((i+1)); sleep 1; done; ubus list | grep -cx TestingReceiver"
  1

The grant covers only start, stop and restart, and the wildcard does not cross a
directory separator. Query the policy without executing anything: sudo -l exits
0 when a command is permitted and 1 when it is not.

  $ R "sudo -n -u tr181_app -g tr181_app sudo -n -l /etc/init.d/testing-receiver restart >/dev/null 2>&1; echo \$?"
  0

  $ R "sudo -n -u tr181_app -g tr181_app sudo -n -l /etc/init.d/testing-receiver status >/dev/null 2>&1; echo \$?"
  1

  $ R "sudo -n -u tr181_app -g tr181_app sudo -n -l /etc/init.d/../../bin/busybox start >/dev/null 2>&1; echo \$?"
  1

Cleanup:

  $ R "/etc/init.d/testing-emitter stop 2> /dev/null"
  $ R "/etc/init.d/testing-receiver stop 2> /dev/null"
  $ R "/etc/init.d/multisettings stop 2> /dev/null"
  $ R "rm -fr /etc/config/multisettings /etc/init.d/testing-receiver /etc/init.d/testing-emitter /etc/amx/testing-receiver /etc/amx/testing-emitter"
  $ R "rm -fr /var/run/selected_profile /usr/bin/testing-emitter rm /usr/bin/testing-receiver"
  $ R "/etc/init.d/multisettings start 2> /dev/null"
