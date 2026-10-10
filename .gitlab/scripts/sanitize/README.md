# Sanitizer job scripts

Scripts of the jobs `build test x86_64 prpl security sanitize` and `cram QEMU x86-64 [sanitize]`
(`.gitlab/sanitize.yml`). The profile is `profiles/sanitize.yml`: a glibc image with ASan, UBSan and LSan
(`CONFIG_SANITIZE`) and the preload shim `sanitizer-shim`. Reports are files under `/ext/sanitizer/report`
on the DUT; each report also writes a `SANREPORT` line to the console, which QEMU keeps in
`artifacts/serial.log`.

Python tools run with `python3 -I` and use only the standard library.

## Build job

- `build-checks.sh`: runs after the image build and calls the three scripts below.
- `instr-scan.sh` + `instr-allowlist.tsv`: fails on an ELF in the rootfs that is not instrumented
  (undefined `__asan_report_*` in the dynamic symbols), not opted out and not in the allowlist.
- `shim-regress.sh`: regression test of the shim, in bwrap on the rootfs (`--preflight` checks bwrap).
- `export-symbols.py`: `sanitize-symbols.tar.xz`, the debug data of every packaged ELF and a build-id stub of
  every rootfs ELF, for the symbolization after the run.

## Cram job

- `run-loop.sh`: the command of `testbed-qemu run`. The `[full]` selection in a loop for
  `SANITIZE_LOOP_SECONDS` (3 h) on one QEMU run; it adds the tests of `.gitlab/tests/cram/sanitize` (sampler,
  leak check broadcast before the reboot test, network probe, collector). Output: `artifacts/iter-NN/`.
  Between two iterations the DUT is reset to factory defaults (`firstboot -y`, reboot, SSH, then the
  datamodel), on the same QEMU run: /overlay keeps the configuration of an iteration (MQTT clients, a bulkdata
  profile, UPnP and PCP entries), and the next iteration would fail on it. `/ext` is not a mount point, so the
  reset also wipes `/ext/sanitizer` (reports, sampler log): the collector has copied them out already and
  the driver copies them once more right before the reset (`iter-NN/sanitizer-reports.tar.gz`, `san-rss.log`).
  A report written after that last copy-out survives only as a `SANREPORT` line in `serial.log`; the console
  index (`san-console-index.txt`) is the safety net for it.
  A reset that fails (no reboot, the marker `/etc/san-loop-marker` is still there) ends the run with exit 1.
  `iter-NN/reset.log` has the steps, `san-loop.txt` a `RESET` line. `SANITIZE_RESET=0` switches the reset off.
  The datamodel wait uses `TESTBED_QEMU_DATAMODEL_WAIT_FOR` (default `Device.WiFi.`), `_TIMEOUT` (240) and
  `_SETTLE` (6) like the testbed-qemu knobs do at the first boot, but polls over SSH in the script, so it also
  works with a testbed-qemu image that ignores the knobs. A time out is a warning.
  The loop ends with exit 1 when `serial.log` is missing after the first iteration, when two iterations in a row
  have no `cram.xml` or last less than 60 s, and, with `SANITIZE_MIN_MEM_KB` set, when the guest has less
  `MemTotal` than that. It ends with exit 2 before the first iteration when the selection has no
  `qemu-x86-64/reboot.t`: the leak check broadcast has to run right before that test.
- `finish.sh`: judges the artifacts: `serial-check.py`, `san-rss-trend.py`, `san-calibrate.py`,
  `san-symbolize.py`, `san-report.py`, `san-summary.py`. It also runs on a downloaded artifacts directory.
  Exit status: the status of `serial-check.py` when it is not 0 (88, 89, or another one when the check did not
  run), else 1 when the summary has a failure or a symbolization failed, else 0. The symbols archive carries the
  toolchain `addr2line` and `readelf`; the host ones are the fallback.
- `serial-check.py`: metrics-log check (SANRSS series: missing, gaps, stale), SANDEATH matching, SANREPORT index.
- `san-symbolize.py`: symbolizes the reports against the exported symbols; a module is only symbolized
  after an identity check by GNU build-id.
- `san-report.py`: one row per unique finding (dedup by stack).
- `san-rss-trend.py`: `/proc` memory trend from the SANRSS lines.
- `san-pmreboots.py`: reboots that `ProcessMonitor.MaxReboots=0` blocked, with the process monitor test name.
- `san-calibrate.py`: quarantine size suggestions from the SANSTATS and SANRSS lines (a human commits them),
  `publish` and `drift` for `package/utils/sanitizer-opts`.
- `san-summary.py`: `san-summary.md`, `san-junit.xml`, `cram-merged.xml`. Cram failures are listed apart:
  lab-network tests (`lab-network-tests.txt`), slow under sanitizer (a time out in the printed output), build
  configuration, other. They are not findings. A sanitizer report, a report file that `san-report.py` cannot
  parse, a failed metrics-log or SANDEATH check, a missing collector or cram result fails the job (exit code 1, 88 or 89).

## Run a check on saved artifacts

    .gitlab/scripts/sanitize/finish.sh DIR --symbols sanitize-symbols.tar.xz
