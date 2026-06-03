Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

U-Boot is not reflashed on refresh, so its version is not compared to os-release; verify get_fit_version.sh returns a well-formed version for u-boot-active:

  $ R 'fit=$(get_fit_version.sh $(blkid -t PARTLABEL="u-boot-active" -o device) 2>&1 | tr -d "\r\n "); echo "$fit" | grep -qE "^[0-9]+\.[0-9]+\.[0-9]+-[0-9a-f]+$" && echo "Version format valid" || echo "Invalid version: $fit"' | tr -d '\n'
  Version format valid (no-eol)

Read the version from kernel-active and rootfs-active partitions and compare it to the version in /etc/os-release:

  $ R 'fit=$(get_fit_version.sh $(blkid -t PARTLABEL="kernel-active" -o device) /security/public.pem 2>&1 | tr -d "\r\n "); os=$(sed -n "s/^VERSION=\"\([^\"]*\)\".*/\1/p" /etc/os-release | tr -d "\r\n "); [ "$fit" = "$os" ] && echo "Versions match" || echo "Versions mismatch: fit=$fit - os-release=$os"' | tr -d '\n'
  Versions match (no-eol)
  $ R 'fit=$(get_fit_version.sh $(blkid -t PARTLABEL="rootfs-active" -o device) /security/public.pem 2>&1 | tr -d "\r\n "); os=$(sed -n "s/^VERSION=\"\([^\"]*\)\".*/\1/p" /etc/os-release | tr -d "\r\n "); [ "$fit" = "$os" ] && echo "Versions match" || echo "Versions mismatch: fit=$fit - os-release=$os"' | tr -d '\n'
  Versions match (no-eol)
