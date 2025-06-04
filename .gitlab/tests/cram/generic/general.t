Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Assure that X_PRPL-COM is not being referenced anywhere in the ODL datamodel PCF-1489:

  $ R "grep -r X_PRPL-COM /etc/amx"
  [1]
