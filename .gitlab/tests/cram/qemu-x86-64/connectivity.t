Create a remote-command alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Require the remote command so the checks cannot run in the container:

  $ test -n "${CRAM_REMOTE_COMMAND:-}" && echo "Remote command is set"
  Remote command is set

Prove that SSH reaches the DUT over the private LAN:

  $ R "true" && echo "LAN SSH works"
  LAN SSH works

Wait for the WAN DHCP lease and record its observed client MAC:

  $ lease_file="${TESTBED_QEMU_ARTIFACT_ROOT}/dnsmasq.leases"
  $ for attempt in $(seq 1 30); do test -s "${lease_file}" && break; sleep 1; done
  $ awk '$3 == "10.0.0.2" && $2 ~ /^([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}$/ { print "WAN lease: " $3 " " $2; found = 1 } END { exit !found }' "${lease_file}"
  WAN lease: 10\.0\.0\.2 ([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2} (re)

Prove that the DUT can reach its WAN gateway:

  $ R "ping -c1 -W2 10.0.0.1 >/dev/null" && echo "WAN gateway works"
  WAN gateway works

Prove that DNS queries use the WAN forwarder:

  $ R "nslookup registry.gitlab.com 10.0.0.1 >/dev/null" && echo "WAN DNS works"
  WAN DNS works

Prove that HTTPS reaches the GitLab registry:

  $ R "curl -sS -o /dev/null https://registry.gitlab.com" && echo "WAN HTTPS works"
  WAN HTTPS works
