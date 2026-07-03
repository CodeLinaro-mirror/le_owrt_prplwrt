Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

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
