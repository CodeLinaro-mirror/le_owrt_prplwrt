Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Read a non encrypted SMD field:

  $ R "readmfg -s MODEL_NAME" | tr -d '\n'
  OSPv2 (no-eol)

Read an encrypted SMD field:

  $ R "readmfg -s DEVICE_CERT" | tr -d '\n'; echo
  (-{5}BEGIN CERTIFICATE-{5}[A-Za-z0-9+/=]*-{5}END CERTIFICATE-{5})+ (re)
