Create alias:
  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ alias C="${CRAM_REMOTE_COPY:-}"

Check boot information before upgrade:
  $ BOOT_BANK=$(R "cat /proc/device-tree/chosen/u-boot,booted-bank | tr -d '\0'; echo")

Select software image based on current boot bank:
  $ [ "$BOOT_BANK" = "active" ] && SELECT_IMAGE="active" || SELECT_IMAGE="inactive"
  $ echo "BOOT_BANK=$BOOT_BANK, SELECT_IMAGE=$SELECT_IMAGE"
  BOOT_BANK=(active|.*inactive), SELECT_IMAGE=(active|inactive) (re)

Copy the .swu image for the upgrade
  $ C ${CI_PROJECT_DIR}/bin/targets/ipq95xx/generic/prplos-ipq95xx-generic-prpl_freedom-image.swu root@${TARGET_LAN_IP}:/tmp/

Upgrade with SWUpdate:
  $ R "test -f /tmp/prplos-ipq95xx-generic-prpl_freedom-image.swu"
  $ R "swupdate -k /security/public.pem -i /tmp/prplos-ipq95xx-generic-prpl_freedom-image.swu -v -H freedom:1.0.0 -e ${SELECT_IMAGE},full 2>/dev/null | grep -F 'SWUpdate was successful'"
  [INFO ] : SWUPDATE running :  [endupdate] : SWUpdate was successful !
