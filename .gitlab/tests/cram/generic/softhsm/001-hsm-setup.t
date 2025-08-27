Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ alias C="${CRAM_REMOTE_COPY:-}"


Verify that SoftHSM slot is initialised

  $ R "softhsm2-util --show-slots | grep -q -e 'Initialized.*yes'"


Verify that the expected keys are stored in SoftHSM

  $ R "pkcs11-tool --module /usr/lib/softhsm/libsofthsm2.so --login --pin 1234 --list-objects 2>&1 | grep -q 'ca-key'"
  $ R "pkcs11-tool --module /usr/lib/softhsm/libsofthsm2.so --login --pin 1234 --list-objects 2>&1 | grep -q 'server-key'"


Check pkcs11 openssl support:

  $ R "openssl engine -t | grep -q 'pkcs11 engine'"


Test the creation of a certificate using PKCS11 URIs

  $ R "openssl req -new -engine pkcs11 -keyform ENGINE -key 'pkcs11:object=server-key;type=private' -out /tmp/server.csr -subj '/CN=prplOS.lan' &> /dev/null"
  $ R "ls /tmp/server.csr &> /dev/null"
  $ R "openssl x509 -req -in /tmp/server.csr -CA /usr/share/ca-certificates/ca.crt -engine pkcs11 -CAkeyform ENGINE -CAkey 'pkcs11:object=ca-key;type=private' -CAcreateserial -out /tmp/server.crt -days 3650 -sha256 &> /dev/null"
  $ R "ls /tmp/server.crt &> /dev/null"


Create client key/cert needed for tests

  $ R "openssl genrsa -out /root/certs/client.key 2048"
  $ R "pkcs11-tool --module /usr/lib/softhsm/libsofthsm2.so --login --pin 1234 --write-object /root/certs/client.key --type privkey --label 'client-key' &> /dev/null"
  $ R "openssl req -new -engine pkcs11 -keyform ENGINE -key 'pkcs11:object=client-key;type=private' -out /root/certs/client.csr -subj '/CN=cpe.local' &> /dev/null"
  $ R "openssl x509 -req -in /root/certs/client.csr -CA /usr/share/ca-certificates/ca.crt -engine pkcs11 -CAkeyform ENGINE -CAkey 'pkcs11:object=ca-key;type=private' -CAcreateserial -out /root/certs/client.crt -days 3650 -sha256 &> /dev/null"


Allow HSM secure storage access for users in the certificates group:

  $ R "chgrp -R certificates /etc/softhsm/tokens/"
  $ R "chmod -R g+r /etc/softhsm/tokens/"
  $ R "find /etc/softhsm/tokens/ -type d -exec chmod g+x {} \;"
  $ R "chgrp -R certificates /root/certs/"
  $ R "chgrp certificates /root"
  $ R "chmod g+x /root/"
  $ R "chmod -R g+r /root/certs/"
  $ R "chgrp -R certificates /etc/config/autocert"
  $ R "chmod -R g+r /etc/config/autocert"
  $ R "ba-cli 'Security.Certificate.2.PrivateKeyURI=\"pkcs11:object=server-key;type=private\"' > /dev/null"
  $ R "ba-cli 'Security.Certificate.2.CertificateURI=\"/etc/config/autocert/server.crt\"' > /dev/null"
