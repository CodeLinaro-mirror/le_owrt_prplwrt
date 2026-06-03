Create R alias:
  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Read the version from u-boot-active, kernel-active and rootfs-active and compare it to the version in /etc/os-release
  $ R 'fit=$(get_fit_version.sh $(blkid -t PARTLABEL="u-boot-active" -o device) 2>&1 | tr -d "\r\n "); os=$(sed -n "s/^VERSION=\"\([^\"]*\)\".*/\1/p" /etc/os-release | tr -d "\r\n "); [ "$fit" = "$os" ] && echo "Versions match" || echo "Versions mismatch"' | tr -d '\n'
  Versions match (no-eol)
  $ R 'fit=$(get_fit_version.sh $(blkid -t PARTLABEL="kernel-active" -o device) /security/public.pem 2>&1 | tr -d "\r\n "); os=$(sed -n "s/^VERSION=\"\([^\"]*\)\".*/\1/p" /etc/os-release | tr -d "\r\n "); [ "$fit" = "$os" ] && echo "Versions match" || echo "Versions mismatch"' | tr -d '\n'
  Versions match (no-eol)
  $ R 'fit=$(get_fit_version.sh $(blkid -t PARTLABEL="rootfs-active" -o device) /security/public.pem 2>&1 | tr -d "\r\n "); os=$(sed -n "s/^VERSION=\"\([^\"]*\)\".*/\1/p" /etc/os-release | tr -d "\r\n "); [ "$fit" = "$os" ] && echo "Versions match" || echo "Versions mismatch"' | tr -d '\n'
  Versions match (no-eol)
