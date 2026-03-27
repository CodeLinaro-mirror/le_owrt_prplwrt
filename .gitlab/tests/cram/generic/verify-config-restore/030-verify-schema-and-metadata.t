Create alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

  $ logger -t cram "Starting with Backup and restore schema, metadata "\
  > "verification test"

Create backup configuration:
  $ R "ba-cli -l -j 'PersistentConfiguration.Backup()' | sed '/^$/d'"
  PersistentConfiguration.Backup() returned
  [""]

Wait some seconds for configuration file generation:
  $ sleep 2

Verify the json file generated contains metadata and schemaVersion in it\
Upon successful verification of metadata with schemaVersion we expect no\
output, if there is no _metadata entry with schemaVersion error is retruned:

  $ R "for json_file in /cfg/pcm/*.json; do "\
  > " if ! cat \"\$json_file\" | "\
  > "jsonfilter -e '@._metadata.schemaVersion' > /dev/null 2>&1; "\
  > "then echo \"Pattern not found in file: \"\$json_file\"\"; fi; done"

  $ logger -t cram "Backup and restore schema, metadata verification "\
  > "test finished"
