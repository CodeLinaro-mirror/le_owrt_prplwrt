
Create R alias for remote execution:
  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Check that the configuration file for obuspa has been created and the content is complete:

  $ R "cat \$(source /etc/environment 2>/dev/null ; echo \$OBUSPA_CONFIGURATION_FILE)"
  CertificateURI=file:///etc/config/autocert/cpe.crt
  PrivateKeyURI=pkcs11:object=cpe-key;type=private
