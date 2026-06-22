Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Backup the state of the system:

  $ R "mkdir -p /etc/config/autocert"
  $ R "mv /etc/config/autocert /etc/config/autocert.bak"
  $ R "mkdir -p /usr/share/ca-certificates"
  $ R "mv /usr/share/ca-certificates /usr/share/ca-certificates.bak"

Copy over testing certificates:

  $ R "mkdir -p /etc/config/autocert"
  $ scp ${CI_PROJECT_DIR}/.gitlab/certs/tr181-security/autocert/* "root@${TARGET_LAN_IP}:/etc/config/autocert/"

Restart tr181-security service:

  $ R "/etc/init.d/tr181-security restart" > /dev/null 2>&1

Check that certs are in place as expected:

  $ R "ba-cli -l 'Security.Certificate.*.Enable?;Security.Certificate.*.Subject?;Security.Certificate.*.SignatureAlgorithm?;Security.Certificate.*.NotBefore?' | grep -v '^$' | LC_ALL=C sort"
  /C=US/O=PrplFoundation/OU=prplOS/CN=prplOS.lan
  /C=US/O=PrplFoundation/OU=prplOS/CN=prplOS.lan
  2023-12-04T17:41:08.* (re)
  2023-12-04T17:41:08.* (re)
  ecdsa-with-SHA512
  sha512WithRSAEncryption
  1
  1

Check that certificate can be disabled (PCF-1054):

  $ R "ba-cli 'Security.Certificate.[SignatureAlgorithm==\"ecdsa-with-SHA512\"].Enable=0' | sed -n '3p'"
  Security.Certificate.\d+.Enable=0 (re)

  $ R "ba-cli --json 'Security.Certificate.[SignatureAlgorithm==\"ecdsa-with-SHA512\" && Enable==False].?' | sed -n '2p'" | jq --sort-keys .[0] | grep -v -E '(NotAfter|NotBefore|LastModif)'
  {
    "Security.Certificate.\d+.": { (re)
      "Enable": 0,
      "Issuer": "/C=US/O=PrplFoundation/OU=prplOS/CN=prplOS.lan",
      "SerialNumber": "2022A6A3FDECA910242A18EFFB214776206F2ED8",
      "SignatureAlgorithm": "ecdsa-with-SHA512",
      "Subject": "/C=US/O=PrplFoundation/OU=prplOS/CN=prplOS.lan",
      "SubjectAlt": ""
    }
  }

Check that certificate can be enabled (PCF-1054):

  $ R "ba-cli 'Security.Certificate.[SignatureAlgorithm==\"ecdsa-with-SHA512\"].Enable=1' | sed -n '3p'"
  Security.Certificate.\d+.Enable=1 (re)

  $ R "ba-cli --json 'Security.Certificate.[SignatureAlgorithm==\"ecdsa-with-SHA512\" && Enable==True].?' | sed -n '2p'" | jq --sort-keys .[0] | grep -v -E '(NotAfter|NotBefore|LastModif)'
  {
    "Security.Certificate.\d+.": { (re)
      "Enable": 1,
      "Issuer": "/C=US/O=PrplFoundation/OU=prplOS/CN=prplOS.lan",
      "SerialNumber": "2022A6A3FDECA910242A18EFFB214776206F2ED8",
      "SignatureAlgorithm": "ecdsa-with-SHA512",
      "Subject": "/C=US/O=PrplFoundation/OU=prplOS/CN=prplOS.lan",
      "SubjectAlt": ""
    }
  }

Remove first certificate from the system:

  $ R "rm /etc/config/autocert/testing*1.pem"

Restart tr181-security service:

  $ R "/etc/init.d/tr181-security restart" > /dev/null 2>&1 ; sleep .5

Check that the first certificate is not present anymore:

  $ R "ba-cli -l 'Security.Certificate.*.Enable?;Security.Certificate.*.Subject?;Security.Certificate.*.SignatureAlgorithm?;Security.Certificate.*.NotBefore?' | grep -v '^$' | LC_ALL=C sort"
  /C=US/O=PrplFoundation/OU=prplOS/CN=prplOS.lan
  2023-12-04T17:41:08.* (re)
  ecdsa-with-SHA512
  1

Check that CABundle are presents:

  $ R "echo '%populate{object Security{object CABundle{instance add(){parameter Enable=1; parameter Name=cram; parameter CAFileURI=\"/tmp/server-cert.crt\";}}}}' > /etc/amx/tr181-security/extensions/01_cram_periodic_transfer.odl" ; sleep 1
  $ R '/etc/init.d/tr181-security restart'
  $ R 'ba-cli Security.CABundleNumberOfEntries?' | grep -v '>'
  Security.CABundleNumberOfEntries=1
  

Check CABundle RPC:

  $ R "ba-cli 'Security.CABundle.1.CAFile()'" | grep -v '>'
  Security.CABundle.1.CAFile() returned
  [
      "",
      {
          CAFile = "/tmp/server-cert.crt"
      }
  ]
  
  $ R "ba-cli 'Security.CABundle.1.CADir()'" | grep -v '>'
  Security.CABundle.1.CADir() returned
  [
      "",
      {
          CADir = ""
      }
  ]
  
  $ R "ba-cli 'Security.CABundle.1.CADirURI=/tmp'" >/dev/null
  $ R "ba-cli 'Security.CABundle.1.CADir()'" | grep -v '>'
  Security.CABundle.1.CADir() returned
  [
      "",
      {
          CADir = "/tmp"
      }
  ]
  

Restore the state of the system:

  $ R 'rm -rf /etc/amx/tr181-security/extensions/01_cram_periodic_transfer.odl'
  $ R '/etc/init.d/tr181-security restart'
  $ R "rm -rf /etc/config/autocert"
  $ R "mv /etc/config/autocert.bak /etc/config/autocert"
  $ R "rm -rf /usr/share/ca-certificates"
  $ R "mv /usr/share/ca-certificates.bak /usr/share/ca-certificates"
  $ R "/etc/init.d/tr181-security restart" > /dev/null 2>&1 ; sleep .5