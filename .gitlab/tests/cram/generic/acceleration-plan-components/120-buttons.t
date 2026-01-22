Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Don't run test on Turris Omnia as it doesn't have Reset and WPS buttons:

  $ [ "$DUT_BOARD" = "turris-omnia" ] && exit 80
  [1]

Check that all buttons are in the expected state:

  $ R "ba-cli --less --json 'Buttons.Button.*.Status?'" | jq --sort-keys '.[0]'
  {
    "Buttons.Button.1.": {
      "Status": "Released"
    },
    "Buttons.Button.2.": {
      "Status": "Released"
    }
  }

Add the actions for testing:

  $ R "ba-cli 'Buttons.Action.+{Alias=\"TestPress\",Name=\"test_press\",Object=\"Buttons.Button.2.Event.1.\",Method=\"Set\",Message=\"\\{\\\"parameters\\\":\\{\\\"Min\\\":22222\\}\\}\"}'" >/dev/null
  $ R "ba-cli 'Buttons.Action.+{Alias=\"TestRelease\",Name=\"test_release\",Object=\"Buttons.Button.2.Event.1.\",Method=\"Set\",Message=\"\\{\\\"parameters\\\":\\{\\\"Max\\\":22222\\}\\}\"}'" >/dev/null
  $ R "ba-cli 'Buttons.Action.+{Alias=\"TestTimeout\",Name=\"test_timeout\",Object=\"Buttons.Button.2.Event.1.\",Method=\"Set\",Message=\"\\{\\\"parameters\\\":\\{\\\"Timeout\\\":22222\\}\\}\"}'" >/dev/null

Configure Button.1 for testing::

  $ R "ba-cli 'Buttons.Button.1.Event.*.Enable=0'" >/dev/null
  $ R "ba-cli 'Buttons.Button.1.Event.1.ActionsReference=\"Buttons.Action.TestPress\"'" >/dev/null
  $ R "ba-cli 'Buttons.Button.1.Event.2.ActionsReference=\"Buttons.Action.TestRelease\"'" >/dev/null
  $ R "ba-cli 'Buttons.Button.1.Event.3.ActionsReference=\"Buttons.Action.TestTimeout\"'" >/dev/null

Check that we have expected datamodel:

  $ R "ba-cli --less --json 'Buttons.Button.1.Event.?'" | jq --sort-keys '.[0]'
  {
    "Buttons.Button.1.Event.1.": {
      "ActionsReference": "Buttons.Action.TestPress",
      "Alias": "Press",
      "Enable": 0,
      "Max": 0,
      "Min": 0,
      "Name": "reset_press",
      "Timeout": 0,
      "Type": "Pressed"
    },
    "Buttons.Button.1.Event.2.": {
      "ActionsReference": "Buttons.Action.TestRelease",
      "Alias": "Release",
      "Enable": 0,
      "Max": 5000,
      "Min": 1000,
      "Name": "reset_release",
      "Timeout": 0,
      "Type": "Released"
    },
    "Buttons.Button.1.Event.3.": {
      "ActionsReference": "Buttons.Action.TestTimeout",
      "Alias": "Timeout",
      "Enable": 0,
      "Max": 0,
      "Min": 0,
      "Name": "reset_timeout",
      "Timeout": 5000,
      "Type": "Timeout"
    }
  }

  $ R "ba-cli --less --json 'Buttons.Button.2.Event.1.?'" | jq --sort-keys '.[0]'
  {
    "Buttons.Button.2.Event.1.": {
      "ActionsReference": "Buttons.Action.InitiateWPSPBC",
      "Alias": "Press",
      "Enable": 1,
      "Max": 0,
      "Min": 0,
      "Name": "wps_click",
      "Timeout": 0,
      "Type": "Pressed"
    }
  }

  $ R "ba-cli --less --json 'Buttons.Action.TestPress.?'" | jq --sort-keys '.[0]'
  {
    "Buttons.Action.\d+.": { (re)
      "Alias": "TestPress",
      "Message": "{\"parameters\":{\"Min\":22222}}",
      "Method": "Set",
      "Name": "test_press",
      "Object": "Buttons.Button.2.Event.1."
    }
  }
  $ R "ba-cli --less --json 'Buttons.Action.TestRelease.?'" | jq --sort-keys '.[0]'
  {
    "Buttons.Action.\d+.": { (re)
      "Alias": "TestRelease",
      "Message": "{\"parameters\":{\"Max\":22222}}",
      "Method": "Set",
      "Name": "test_release",
      "Object": "Buttons.Button.2.Event.1."
    }
  }
  $ R "ba-cli --less --json 'Buttons.Action.TestTimeout.?'" | jq --sort-keys '.[0]'
  {
    "Buttons.Action.\d+.": { (re)
      "Alias": "TestTimeout",
      "Message": "{\"parameters\":{\"Timeout\":22222}}",
      "Method": "Set",
      "Name": "test_timeout",
      "Object": "Buttons.Button.2.Event.1."
    }
  }

Check button Status changes using Push() and Release() methods:

  $ R "ba-cli 'Buttons.Button.1.Push()'" >/dev/null
  $ R "ba-cli --less --json 'Buttons.Button.1.Status?'" | jq --sort-keys '.[0]'
  {
    "Buttons.Button.1.": {
      "Status": "Pushed"
    }
  }

  $ R "ba-cli 'Buttons.Button.1.Release()'" >/dev/null
  $ R "ba-cli --less --json 'Buttons.Button.1.Status?'" | jq --sort-keys '.[0]'
  {
    "Buttons.Button.1.": {
      "Status": "Released"
    }
  }

Check Timeout actions/events are triggered and works:

  $ R "ba-cli 'Buttons.Button.1.Event.3.Enable=1'" >/dev/null
  $ R "ba-cli 'Buttons.Button.1.Push()'" >/dev/null
  $ sleep 6
  $ R "ba-cli 'Buttons.Button.1.Release()'" >/dev/null
  $ R "ba-cli --less --json 'Buttons.Button.2.Event.1.Timeout?'" | jq --sort-keys '.[0]'
  {
    "Buttons.Button.2.Event.1.": {
      "Timeout": 22222
    }
  }

Check Pressed/Released actions/events are triggered and works:

  $ R "ba-cli 'Buttons.Button.1.Event.1.Enable=1'" >/dev/null
  $ R "ba-cli 'Buttons.Button.1.Event.2.Enable=1'" >/dev/null
  $ R "ba-cli 'Buttons.Button.1.Push()'" >/dev/null
  $ sleep 2
  $ R "ba-cli 'Buttons.Button.1.Release()'" >/dev/null
  $ R "ba-cli --less --json 'Buttons.Button.2.Event.1.Min?'" | jq --sort-keys '.[0]'
  {
    "Buttons.Button.2.Event.1.": {
      "Min": 22222
    }
  }
  $ R "ba-cli --less --json 'Buttons.Button.2.Event.1.Max?'" | jq --sort-keys '.[0]'
  {
    "Buttons.Button.2.Event.1.": {
      "Max": 22222
    }
  }

Cleanup:

  $ R "ba-cli Buttons.Action.TestPress.-" >/dev/null
  $ R "ba-cli Buttons.Action.TestRelease.-" >/dev/null
  $ R "ba-cli Buttons.Action.TestTimeout.-" >/dev/null

Revert back the default datamodel:

  $ R "ba-cli 'Buttons.Button.2.Event.1.{Min=0,Max=0,Timeout=0}'" >/dev/null
  $ R "ba-cli 'Buttons.Button.1.Event.1.ActionsReference=\"\"'" >/dev/null
  $ R "ba-cli 'Buttons.Button.1.Event.2.ActionsReference=\"Buttons.Action.Reboot\"'" >/dev/null
  $ R "ba-cli 'Buttons.Button.1.Event.3.ActionsReference=\"Buttons.Action.FactoryReset\"'" >/dev/null
  $ R "ba-cli 'Buttons.Button.1.Event.*.Enable=1'" >/dev/null
