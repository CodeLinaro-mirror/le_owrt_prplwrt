Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Don't run test on Turris Omnia and OSPv1 boards as they don't have Reset and WPS buttons:

  $ [ "$DUT_BOARD" = "turris-omnia" ] || exit 80
  $ [ "$DUT_BOARD" = "urx851-hdk-3" ] || exit 80

Check that all buttons are in the expected state:

  $ R "ba-cli --less --json 'Device.Buttons.Button.*.Status?'" | jq --sort-keys '.[0]'
  {
    "Device.Buttons.Button.1.": {
      "Status": "Released"
    },
    "Device.Buttons.Button.2.": {
      "Status": "Released"
    }
  }
