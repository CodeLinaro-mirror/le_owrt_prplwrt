Create alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

  $ logger -t cram "Starting with Backup and restore schemaVersion test"

Read PersistentConfiguration.Service.i.schemaVersion to ensure proper \
registration with version Id towards PCM:

  $ R "ba-cli -l PersistentConfiguration.Service.*.schemaVersion? | "\
  > " sed '/^$/d' | grep -v \"\d\+\"" || true

  $ logger -t cram "Backup and restore schemaVersion test finished"
