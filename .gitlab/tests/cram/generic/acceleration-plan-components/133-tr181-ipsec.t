Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

The plugin runs as tr181_app and re-escalates through the NOPASSWD rule in
/etc/sudoers.d/tr181-ipsec to start the charon daemon as root. IPsec.Enable
defaults to true, so charon is already started from app:start at boot. Boards
that do not build strongswan-charon have no daemon and skip its assertions:

  $ R "test -x /usr/lib/ipsec/charon" >/dev/null 2>&1 && HASCHARON=1 || HASCHARON=0

The sudo grant is installed for the group the plugin actually runs as:

  $ R "grep -c '^%tr181_app ALL=NOPASSWD:/usr/lib/ipsec/charon$' /etc/sudoers.d/tr181-ipsec"
  1

The plugin itself is not root:

  $ R "pgrep -x --count -u tr181_app tr181-ipsec"
  1

The plugin reports Enabled only once it has connected to the vici socket of the
daemon it started, so poll for it:

  $ if [ "$HASCHARON" = 1 ]; then \
  >     R "i=0; \
  >        while [ \$i -lt 30 ] && \
  >              ! ba-cli 'IPsec.Status?' 2>/dev/null | grep -qF 'Status=\"Enabled\"'; \
  >        do i=\$((i+1)); sleep 1; done; \
  >        ba-cli 'IPsec.Status?' 2>/dev/null | grep -cF 'Status=\"Enabled\"'"; \
  > else echo 1; fi
  1

The escalation end to end: exactly one charon, running as root, child of a sudo
that is itself a child of the tr181_app plugin:

  $ if [ "$HASCHARON" = 1 ]; then \
  >     R "ipsecpid=\$(pgrep -x -u tr181_app tr181-ipsec); \
  >        sudopid=\$(pgrep -x -P \$ipsecpid sudo); \
  >        pgrep -x --count -u root -P \$sudopid charon"; \
  > else echo 1; fi
  1

Check the IPsec datamodel starts empty:

  $ R ba-cli 'IPsec.Filter.*.-\;IPsec.Profile.*.-' >/dev/null 2>&1; true
  $ R "ba-cli 'IPsec.FilterNumberOfEntries?'" | grep -v '>' | grep -F 'NumberOfEntries='
  IPsec.FilterNumberOfEntries=0
  $ R "ba-cli 'IPsec.IKEv2SANumberOfEntries?'" | grep -v '>' | grep -F 'NumberOfEntries='
  IPsec.IKEv2SANumberOfEntries=0
  $ R "ba-cli 'IPsec.InterfaceNumberOfEntries?'" | grep -v '>' | grep -F 'NumberOfEntries='
  IPsec.InterfaceNumberOfEntries=0
  $ R "ba-cli 'IPsec.ProfileNumberOfEntries?'" | grep -v '>' | grep -F 'NumberOfEntries='
  IPsec.ProfileNumberOfEntries=0
  $ R "ba-cli 'IPsec.SecretNumberOfEntries?'" | grep -v '>' | grep -F 'NumberOfEntries='
  IPsec.SecretNumberOfEntries=0
  $ R "ba-cli 'IPsec.TunnelNumberOfEntries?'" | grep -v '>' | grep -F 'NumberOfEntries='
  IPsec.TunnelNumberOfEntries=0

Create an IPsec Profile and map a Filter on it:

  $ IPSECIDXPROFILE=`R ba-cli "IPsec.Profile.+{Alias='p1'}" 2>/dev/null | sed -ne 's/^IPsec.Profile.\([0-9]\+\).$/\1/p'`
  $ IPSECIDXFILTER=`R ba-cli "IPsec.Filter.+{Alias='f1',Enable=1,ProcessingChoice='Protect',Profile='Device.IPsec.Profile.$IPSECIDXPROFILE'}" 2>/dev/null | sed -ne 's/^IPsec.Filter.\([0-9]\+\).$/\1/p'`
  $ IPSECIFACE=`R ba-cli "protected\;IPsec.Interface.$IPSECIDXPROFILE.Name?" | sed -ne 's/^IPsec.Interface.[0-9]\+.Name="\(.*\)"$/\1/p'`
  $ R ba-cli "IPsec.Filter.$IPSECIDXFILTER.Status?" | sed -ne 2p
  IPsec.Filter.[0-9]+.Status="Error_Misconfigured" (re)
  $ R ba-cli "protected\;IPsec.Interface.$IPSECIFACE.Status?" | sed -ne '/^IPsec.Interface.*$/p'
  IPsec.Interface.[0-9]+.Status="Down" (re)
  $ R ba-cli "IPsec.Tunnel.$IPSECIFACE.Filters?" | sed -ne 2p
  IPsec.Tunnel.[0-9]+.Filters="Device.IPsec.Filter.[0-9]+" (re)

Verify status in NetModel, once the interface has been resolved:

  $ R "i=1; while [ \$i -lt 10 ] && \
  >     ! ba-cli 'NetModel.Intf.ip-$IPSECIFACE.Status_ext?' | grep -q '\"Up\"'; \
  >     do i=\$((i+1)); sleep 1; done"
  $ R ba-cli "NetModel.Intf.ipsec-$IPSECIFACE.Status_ext?" | sed -ne 2p
  NetModel.Intf.[0-9]+.Status_ext="Down" (re)
  $ R ba-cli "NetModel.Intf.ip-$IPSECIFACE.Status_ext?" | sed -ne 2p
  NetModel.Intf.[0-9]+.Status_ext="Up" (re)
  $ R ba-cli "NetModel.Intf.ip-$IPSECIFACE-tunneled.Status_ext?" | sed -ne 2p
  NetModel.Intf.[0-9]+.Status_ext="Unknown" (re)

Cleanup:

  $ R ba-cli "IPsec.Filter.f1-\;IPsec.Profile.p1-" >/dev/null 2>&1
