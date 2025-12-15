Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Start udpst server:

  $ R "udpst -x -T"

Set the test parameters:

  $ R "ba-cli 'IPDiagnostics.IPLayerCapacityMetrics.ServerList=127.0.0.1:25000'" >/dev/null
  $ R "ba-cli 'IPDiagnostics.IPLayerCapacityMetrics.Interface=Device.IP.Interface.1.'" >/dev/null
  $ R "ba-cli 'IPDiagnostics.IPLayerCapacityMetrics.NumberTestSubIntervals=5'" >/dev/null

Test 1. Initiate diagnostic test and verify DiagnosticsState transitions:

Initiate diagnostic test by setting DiagnosticsState to Requested:

  $ R "ba-cli 'IPDiagnostics.IPLayerCapacityMetrics.DiagnosticsState=Requested'" >/dev/null

Verify output parameters are cleared:

  $ R "ba-cli --less --json 'IPDiagnostics.IPLayerCapacityMetrics.IncrementalResultNumberOfEntries?'" | jq --sort-keys '.[0]'
  {
    "IPDiagnostics.IPLayerCapacityMetrics.": {
      "IncrementalResultNumberOfEntries": 0
    }
  }

  $ R "ba-cli --less --json 'IPDiagnostics.IPLayerCapacityMetrics.ModalResultNumberOfEntries?'" | jq --sort-keys '.[0]'
  {
    "IPDiagnostics.IPLayerCapacityMetrics.": {
      "ModalResultNumberOfEntries": 0
    }
  }

  $ sleep 7

Verify DiagnosticsState is Complete after test completion:

  $ R "ba-cli --less --json 'IPDiagnostics.IPLayerCapacityMetrics.DiagnosticsState?'" | jq --sort-keys '.[0]'
  {
    "IPDiagnostics.IPLayerCapacityMetrics.": {
      "DiagnosticsState": "Complete"
    }
  }

Verify output parameters are updated:

  $ R "ba-cli --less --json 'IPDiagnostics.IPLayerCapacityMetrics.IncrementalResultNumberOfEntries?'" | jq --sort-keys '.[0]'
  {
    "IPDiagnostics.IPLayerCapacityMetrics.": {
      "IncrementalResultNumberOfEntries": 5
    }
  }

Test 2. Initiate a failed test:

Initiate a failed test by setting DiagnosticsState to Requested:

  $ R "ba-cli 'IPDiagnostics.IPLayerCapacityMetrics.ServerList=wrong_server_list'" >/dev/null
  $ R "ba-cli 'IPDiagnostics.IPLayerCapacityMetrics.DiagnosticsState=Requested'" >/dev/null
  $ sleep 7

Verify DiagnosticsState is Error_Timeout after test completion:

  $ R "ba-cli --less --json 'IPDiagnostics.IPLayerCapacityMetrics.DiagnosticsState?'" | jq --sort-keys '.[0]'
  {
    "IPDiagnostics.IPLayerCapacityMetrics.": {
      "DiagnosticsState": "Error_Other"
    }
  }

Verify output parameters are cleared:

  $ R "ba-cli --less --json 'IPDiagnostics.IPLayerCapacityMetrics.IncrementalResultNumberOfEntries?'" | jq --sort-keys '.[0]'
  {
    "IPDiagnostics.IPLayerCapacityMetrics.": {
      "IncrementalResultNumberOfEntries": 0
    }
  }

Test 3. Test DiagnosticsState Canceled functionality and restart:

Start test by setting DiagnosticsState to Requested:

  $ R "ba-cli 'IPDiagnostics.IPLayerCapacityMetrics.ServerList=127.0.0.1:25000'" >/dev/null
  $ R "ba-cli 'IPDiagnostics.IPLayerCapacityMetrics.DiagnosticsState=Requested'" >/dev/null
  $ sleep 2

Cancel test by setting DiagnosticsState to Canceled:

  $ R "ba-cli 'IPDiagnostics.IPLayerCapacityMetrics.DiagnosticsState=Canceled'" >/dev/null
  $ R "ba-cli --less --json 'IPDiagnostics.IPLayerCapacityMetrics.DiagnosticsState?'" | jq --sort-keys '.[0]'
  {
    "IPDiagnostics.IPLayerCapacityMetrics.": {
      "DiagnosticsState": "None"
    }
  }

Verify output parameters are cleared:

  $ R "ba-cli --less --json 'IPDiagnostics.IPLayerCapacityMetrics.IncrementalResultNumberOfEntries?'" | jq --sort-keys '.[0]'
  {
    "IPDiagnostics.IPLayerCapacityMetrics.": {
      "IncrementalResultNumberOfEntries": 0
    }
  }

Restart a new test by setting DiagnosticsState to Requested:

  $ R "ba-cli 'IPDiagnostics.IPLayerCapacityMetrics.DiagnosticsState=Requested'" >/dev/null
  $ sleep 7

Verify DiagnosticsState is Complete after test completion:

  $ R "ba-cli --less --json 'IPDiagnostics.IPLayerCapacityMetrics.DiagnosticsState?'" | jq --sort-keys '.[0]'
  {
    "IPDiagnostics.IPLayerCapacityMetrics.": {
      "DiagnosticsState": "Complete"
    }
  }

Verify output parameters are updated:

  $ R "ba-cli --less --json 'IPDiagnostics.IPLayerCapacityMetrics.IncrementalResultNumberOfEntries?'" | jq --sort-keys '.[0]'
  {
    "IPDiagnostics.IPLayerCapacityMetrics.": {
      "IncrementalResultNumberOfEntries": 5
    }
  }

Test 4. Modify writable parameter during execution:

Start test by setting DiagnosticsState to Requested:

  $ R "ba-cli 'IPDiagnostics.IPLayerCapacityMetrics.NumberFirstModeTestSubIntervals=0'" >/dev/null
  $ R "ba-cli 'IPDiagnostics.IPLayerCapacityMetrics.DiagnosticsState=Requested'" >/dev/null
  $ sleep 2

Modify writable parameter during execution:

  $ R "ba-cli 'IPDiagnostics.IPLayerCapacityMetrics.NumberFirstModeTestSubIntervals=1'" >/dev/null

Verify DiagnosticsState is None:

  $ R "ba-cli --less --json 'IPDiagnostics.IPLayerCapacityMetrics.DiagnosticsState?'" | jq --sort-keys '.[0]'
  {
    "IPDiagnostics.IPLayerCapacityMetrics.": {
      "DiagnosticsState": "None"
    }
  }

Test 5. Requested during execution terminates and restarts with new params:

Start test by setting DiagnosticsState to Requested:

  $ R "ba-cli 'IPDiagnostics.IPLayerCapacityMetrics.NumberFirstModeTestSubIntervals=0'" >/dev/null
  $ R "ba-cli 'IPDiagnostics.IPLayerCapacityMetrics.NumberTestSubIntervals=5'" >/dev/null
  $ R "ba-cli 'IPDiagnostics.IPLayerCapacityMetrics.DiagnosticsState=Requested'" >/dev/null
  $ sleep 2

Modify writable parameter during execution and restart test:

  $ R "ba-cli 'IPDiagnostics.IPLayerCapacityMetrics.NumberFirstModeTestSubIntervals=1'" >/dev/null
  $ R "ba-cli 'IPDiagnostics.IPLayerCapacityMetrics.DiagnosticsState=Requested'" >/dev/null
  $ sleep 7

Verify DiagnosticsState is Complete after test completion:

  $ R "ba-cli --less --json 'IPDiagnostics.IPLayerCapacityMetrics.DiagnosticsState?'" | jq --sort-keys '.[0]'
  {
    "IPDiagnostics.IPLayerCapacityMetrics.": {
      "DiagnosticsState": "Complete"
    }
  }

Verify output parameters are updated according to new params:

  $ R "ba-cli --less --json 'IPDiagnostics.IPLayerCapacityMetrics.IncrementalResultNumberOfEntries?'" | jq --sort-keys '.[0]'
  {
    "IPDiagnostics.IPLayerCapacityMetrics.": {
      "IncrementalResultNumberOfEntries": 5
    }
  }

  $ R "ba-cli --less --json 'IPDiagnostics.IPLayerCapacityMetrics.ModalResultNumberOfEntries?'" | jq --sort-keys '.[0]'
  {
    "IPDiagnostics.IPLayerCapacityMetrics.": {
      "ModalResultNumberOfEntries": 1
    }
  }

Test 6. USP command with optional test parameters set via CWMP:

Modify writable parameter via CWMP DataModel:

  $ R "ba-cli 'IPDiagnostics.IPLayerCapacityMetrics.NumberFirstModeTestSubIntervals=1'" >/dev/null

Start test via USP command:

  $ R "ubus call IPDiagnostics IPLayerCapacity '{\"Role\":\"Sender\", \"ServerList\":\"127.0.0.1:25000\"}'" | jq -s '.[2]["amxd-error-code"]'
  0

Verify DiagnosticsState is Complete after test completion:

  $ R "ba-cli --less --json 'IPDiagnostics.IPLayerCapacityMetrics.DiagnosticsState?'" | jq --sort-keys '.[0]'
  {
    "IPDiagnostics.IPLayerCapacityMetrics.": {
      "DiagnosticsState": "Complete"
    }
  }

Verify output parameters are updated according to USP parameters instead of CWMP parameters:

  $ R "ba-cli --less --json 'IPDiagnostics.IPLayerCapacityMetrics.ModalResultNumberOfEntries?'" | jq --sort-keys '.[0]'
  {
    "IPDiagnostics.IPLayerCapacityMetrics.": {
      "ModalResultNumberOfEntries": 0
    }
  }

  $ R "ba-cli --less --json 'IPDiagnostics.IPLayerCapacityMetrics.IncrementalResultNumberOfEntries?'" | jq --sort-keys '.[0]'
  {
    "IPDiagnostics.IPLayerCapacityMetrics.": {
      "IncrementalResultNumberOfEntries": 10
    }
  }

Test 7. CWMP to USP; nearest command (USP) should execute:

Start test via CWMP command:

  $ R "ba-cli 'IPDiagnostics.IPLayerCapacityMetrics.NumberFirstModeTestSubIntervals=1'" >/dev/null
  $ R "ba-cli 'IPDiagnostics.IPLayerCapacityMetrics.DiagnosticsState=Requested'" >/dev/null
  $ sleep 2
  $ R "ubus call IPDiagnostics IPLayerCapacity '{\"Role\":\"Sender\", \"ServerList\":\"127.0.0.1:25000\"}'" | jq -s '.[2]["amxd-error-code"]'
  0

Verify DiagnosticsState is Complete after test completion:

  $ R "ba-cli --less --json 'IPDiagnostics.IPLayerCapacityMetrics.DiagnosticsState?'" | jq --sort-keys '.[0]'
  {
    "IPDiagnostics.IPLayerCapacityMetrics.": {
      "DiagnosticsState": "Complete"
    }
  }

Verify output parameters are updated according to USP parameters instead of CWMP parameters:

  $ R "ba-cli --less --json 'IPDiagnostics.IPLayerCapacityMetrics.ModalResultNumberOfEntries?'" | jq --sort-keys '.[0]'
  {
    "IPDiagnostics.IPLayerCapacityMetrics.": {
      "ModalResultNumberOfEntries": 0
    }
  }

  $ R "ba-cli --less --json 'IPDiagnostics.IPLayerCapacityMetrics.IncrementalResultNumberOfEntries?'" | jq --sort-keys '.[0]'
  {
    "IPDiagnostics.IPLayerCapacityMetrics.": {
      "IncrementalResultNumberOfEntries": 10
    }
  }

Test 8. USP to CWMP; nearest command (CWMP) should execute:

Start test via USP command:

  $ R "ubus call IPDiagnostics IPLayerCapacity '{\"Role\":\"Sender\", \"ServerList\":\"127.0.0.1:25000\"}'&"
  $ sleep 2

Start test via CWMP DataModel:

  $ R "ba-cli 'IPDiagnostics.IPLayerCapacityMetrics.NumberFirstModeTestSubIntervals=1'" >/dev/null
  $ R "ba-cli 'IPDiagnostics.IPLayerCapacityMetrics.NumberTestSubIntervals=5'" >/dev/null
  $ R "ba-cli 'IPDiagnostics.IPLayerCapacityMetrics.DiagnosticsState=Requested'" >/dev/null
  $ sleep 7

Verify DiagnosticsState is Complete after test completion:

  $ R "ba-cli --less --json 'IPDiagnostics.IPLayerCapacityMetrics.DiagnosticsState?'" | jq --sort-keys '.[0]'
  {
    "IPDiagnostics.IPLayerCapacityMetrics.": {
      "DiagnosticsState": "Complete"
    }
  }

Verify output parameters are updated according to CWMP parameters instead of USP parameters:

  $ R "ba-cli --less --json 'IPDiagnostics.IPLayerCapacityMetrics.ModalResultNumberOfEntries?'" | jq --sort-keys '.[0]'
  {
    "IPDiagnostics.IPLayerCapacityMetrics.": {
      "ModalResultNumberOfEntries": 1
    }
  }

  $ R "ba-cli --less --json 'IPDiagnostics.IPLayerCapacityMetrics.IncrementalResultNumberOfEntries?'" | jq --sort-keys '.[0]'
  {
    "IPDiagnostics.IPLayerCapacityMetrics.": {
      "IncrementalResultNumberOfEntries": 5
    }
  }

Restore original parameter:

  $ R "ba-cli 'IPDiagnostics.IPLayerCapacityMetrics.NumberFirstModeTestSubIntervals=0'" >/dev/null
  $ R "ba-cli 'IPDiagnostics.IPLayerCapacityMetrics.NumberTestSubIntervals=10'" >/dev/null
  $ R "ba-cli 'IPDiagnostics.IPLayerCapacityMetrics.Interface=Device.IP.Interface.2.'" >/dev/null

Stop udpst server:

  $ R "killall udpst"