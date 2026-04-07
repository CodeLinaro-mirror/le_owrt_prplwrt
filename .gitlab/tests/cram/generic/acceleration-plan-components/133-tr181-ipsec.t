Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Check IPsec root datamodel:

  $ R ba-cli 'IPsec.Filter.*.-\;IPsec.Profile.*.-' >/dev/null 2>&1; true
  $ R "ubus -S call IPsec _get"
  {"IPsec.":{"IKEv2SupportedEncryptionAlgorithms":"DES,3DES,CAST,BLOWFISH,AES-CBC,AES-CTR,AES-CCM-8,AES-CCM-12,AES-CCM-16,AES-GCM-8,AES-GCM-12,AES-GCM-16,CAMELLIA-CBC","ProfileNumberOfEntries":0,"Status":"Enabled","Enable":true,"IKEv2SupportedIDTypes":"ID_IPV4_ADDR,ID_FQDN,ID_RFC822_ADDR,ID_IPV6_ADDR,ID_KEY_ID,ID_DER_ASN1_DN,ID_DER_ASN1_GN","AHSupported":true,"FilterNumberOfEntries":0,"MaxProfileEntries":0,"MaxFilterEntries":0,"SupportedIntegrityAlgorithms":"HMAC-MD5-96,HMAC-SHA1-96,AES-XCBC-96,HMAC-MD5-128,HMAC-SHA1-160,AES-CMAC-96,HMAC-SHA2-256-128,HMAC-SHA2-256-256,HMAC-SHA2-384-192,HMAC-SHA2-512-256","ESPSupportedEncryptionAlgorithms":"NULL,DES,3DES,CAST,BLOWFISH,AES-CBC,AES-CTR,AES-CCM-8,AES-CCM-12,AES-CCM-16,AES-GCM-8,AES-GCM-12,AES-GCM-16,CAMELLIA-CBC,CAMELLIA-CTR,CAMELLIA-CCM-8,CAMELLIA-CCM-12,CAMELLIA-CCM-16","InterfaceNumberOfEntries":0,"SupportedDiffieHellmanGroupTransforms":"MODP-768,MODP-1024,MODP-1536,MODP-2048,MODP-3072,MODP-4096,MODP-6144,MODP-8192,ECP-256,ECP-384,ECP-521,MODP-1024-PRIME-160,MODP-2048-PRIME-224,MODP-2048-PRIME-256,ECP-192,ECP-224","IKEv2SANumberOfEntries":0,"IKEv2SupportedPseudoRandomFunctions":"HMAC-MD5,HMAC-SHA1,AES-128-XCBC,HMAC-SHA2-256,HMAC-SHA2-384,HMAC-SHA2-512,AES-128-CMAC","SecretNumberOfEntries":0,"TunnelNumberOfEntries":0}}
  {}
  {"amxd-error-code":0}

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

Verify status in NetModel:

  $ R ba-cli "NetModel.Intf.ipsec-$IPSECIFACE.Status_ext?" | sed -ne 2p
  NetModel.Intf.[0-9]+.Status_ext="Down" (re)
  $ R ba-cli "NetModel.Intf.ip-$IPSECIFACE.Status_ext?" | sed -ne 2p
  NetModel.Intf.[0-9]+.Status_ext="Up" (re)
  $ R ba-cli "NetModel.Intf.ip-$IPSECIFACE-tunneled.Status_ext?" | sed -ne 2p
  NetModel.Intf.[0-9]+.Status_ext="Unknown" (re)

Cleanup:

  $ R ba-cli "IPsec.Filter.f1-\;IPsec.Profile.p1-" >/dev/null 2>&1
