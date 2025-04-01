Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Check that there is SFP+ stick present:

  $ R 'ba-cli --less --json SFPs.Cage.1.SFP.Transceiver.?' | jq -r '.[0]."SFPs.Cage.1.SFP.Transceiver." | [.VendorSN, .VendorPN, .TransceiverType, .VendorName] | sort | .[]'
  10G Base-SR
  F\d+$ (re)
  FS
  SFP-10G-T
