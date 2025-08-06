Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

  $ R logger -t cram "Starting pwhm direct USP socket test ..."

Check pwhm usp socket:

  $ R "netstat -ap 2>/dev/null | grep 'LISTENING.*pwhm_usp.sock'"
  .*LISTENING.*pwhm_usp.sock (re)

Check if there is at least one connected client (should be beerocks processes):

  $ R "netstat -ap 2>/dev/null | grep 'CONNECTED.*pwhm_usp.sock'| wc -l"
  [1-9]$ (re)

  $ R logger -t cram "Test finished!"
