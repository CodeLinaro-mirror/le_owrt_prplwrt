Create a remote-command alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Require the remote command so the checks cannot run in the container:

  $ test -n "${CRAM_REMOTE_COMMAND:-}" && echo "Remote command is set"
  Remote command is set

Prove that a factory-fresh batch run did not inherit state:

  $ marker=/cram-reboot-marker
  $ R "test ! -e ${marker}" && echo "Marker starts absent"
  Marker starts absent

Wait until fstools has committed first-boot state:

  $ first_boot_ready=false
  $ for attempt in $(seq 1 300); do if test "$(R "readlink /overlay/.fs_state 2>/dev/null")" = 2; then first_boot_ready=true; break; fi; sleep 1; done
  $ if test "${first_boot_ready}" = true; then echo "First boot completed"; else echo "First boot did not complete within 300 seconds" >&2; false; fi
  First boot completed

Write and flush persistent state, then record the uninterrupted-uptime
baseline:

  $ R "touch ${marker} && sync" && echo "Marker flushed"
  Marker flushed
  $ uptime_before=$(R "cut -d. -f1 /proc/uptime")
  $ wall_before=$(date +%s)

Reboot the DUT, observe SSH go away, and wait for it to return:

  $ R "reboot" >/dev/null 2>&1 || true
  $ disconnected=false; for attempt in $(seq 1 60); do if ! R "true" >/dev/null 2>&1; then disconnected=true; break; fi; sleep 1; done
  $ test "${disconnected}" = true
  $ testbed-qemu wait

Prove that persistent state survived and uptime restarted at boot:

  $ wall_after=$(date +%s)
  $ uptime_after=$(R "cut -d. -f1 /proc/uptime")
  $ R "test -e ${marker}" && echo "Marker survived reboot"
  Marker survived reboot
  $ uninterrupted=$((uptime_before + wall_after - wall_before))
  $ test "${uptime_after}" -lt "$((uninterrupted - 5))" && echo "Uptime reset"
  Uptime reset
