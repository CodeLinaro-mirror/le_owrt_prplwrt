Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ alias C="${CRAM_REMOTE_COPY:-}"


Reset certiificates and secure storage:

  $ R "mkdir -p /etc/config/autocert"
  $ R "rm -rf /etc/config/autocert/*"
  $ R "rm -rf /etc/softhsm/tokens/*"
  $ R "softhsm2-util --init-token --free --label cpe-token --pin 1234 --so-pin 123456 &> /dev/null"


Create cert/key:

  $ R "openssl genrsa -out ca.key 2048"
  $ R "OPENSSL_CONF= openssl req -x509 -new -nodes -key ca.key -sha256 -days 3650 -out ca.crt -subj '/CN=Test CA'"

  $ R "openssl genrsa -out server.key 2048"
  $ R "OPENSSL_CONF= openssl req -new -key server.key -out server.csr -subj '/CN=prplOS.lan'"
  $ R "OPENSSL_CONF= openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out server.crt -days 3650 -sha256 &> /dev/null"

  $ R "openssl genrsa -out client.key 2048"
  $ R "OPENSSL_CONF= openssl req -new -key client.key -out client.csr -subj '/CN=cpe.local'"
  $ R "OPENSSL_CONF= openssl x509 -req -in client.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out client.crt -days 3650 -sha256 &> /dev/null"

  $ R "mkdir -p ~/certs"
  $ R "mv *.key *.crt ~/certs"
  $ R "chmod -R a+r ~/certs/*"
  $ R "chmod +rx ~"


Put server key into HSM:

  $ R "pkcs11-tool --module /usr/lib/softhsm/libsofthsm2.so --login --pin 1234 --write-object ~/certs/server.key --type privkey --label 'server-key' &> /dev/null"
  $ R "softhsm2-util --show-slots | grep -q -e 'Initialized.*yes'"
  $ R "pkcs11-tool --module /usr/lib/softhsm/libsofthsm2.so --login --pin 1234 --list-objects 2>&1 | grep -q 'server-key'"


Allow HSM secure storage access for mosquitto:

  $ R "chgrp -R certificates /etc/softhsm/tokens/"
  $ R "chmod -R g+r /etc/softhsm/tokens/"
  $ R "find /etc/softhsm/tokens/ -type d -exec chmod g+x {} \;"

  $ R "cp ~/certs/server* /etc/config/autocert/"
  $ R "chgrp -R certificates /etc/config/autocert/"
  $ R "/etc/init.d/tr181-security restart"
  $ R "ba-cli 'Security.Certificate.1.PrivateKeyURI=\"pkcs11:object=server-key;type=private\"' > /dev/null"
  $ R "ba-cli 'Security.Certificate.1.CertificateURI=\"/etc/config/autocert/server.crt\"' > /dev/null"


Check pkcs11 openssl support:

  $ R "openssl engine -t | grep -q 'pkcs11 engine'"
