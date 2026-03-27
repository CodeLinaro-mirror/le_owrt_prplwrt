Create alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

  $ logger -t cram "Starting with Backup and restore SchemaVersion test"

Read PersistentConfiguration.Service.i.SchemaVersion to ensure proper \
registration with version Id towards PCM:

  $ R "ba-cli PersistentConfiguration.Service.*.SchemaVersion? | "\
  > " sed '/^$/d' | grep -c "\
  > "PersistentConfiguration.Service.[0-9][0-9]*.SchemaVersion=[0-9][0-9]*"
  [1-9]\d* (re)

  $ logger -t cram "Backup and restore SchemaVersion test finished"
