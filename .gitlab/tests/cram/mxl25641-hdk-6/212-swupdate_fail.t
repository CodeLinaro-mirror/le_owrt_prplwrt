Create R alias:
  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ alias C="${CRAM_REMOTE_COPY:-}"

Check boot information before upgrade:
  $ BOOT_BANK=$(R "cat /proc/device-tree/chosen/u-boot,booted-bank | tr -d '\0'; echo")

Select software image based on current boot bank:
  $ [ "$BOOT_BANK" = "active" ] && SELECT_IMAGE="active" || SELECT_IMAGE="inactive"
  $ echo "BOOT_BANK=$BOOT_BANK, SELECT_IMAGE=$SELECT_IMAGE"
  BOOT_BANK=(active|.*inactive), SELECT_IMAGE=(active|inactive) (re)

Copy the .swu image for the upgrade
  $ C ${CI_PROJECT_DIR}/bin/targets/intel_x86/lgm/prplos-intel_x86-lgm-PRPL_OSP_v2-tb341_wav700-image.swu root@${TARGET_LAN_IP}:/tmp/

Upgrade with SWUpdate using wrong public key:
  $ R "test -f /tmp/prplos-intel_x86-lgm-PRPL_OSP_v2-tb341_wav700-image.swu"
  $ R "openssl genrsa -out /tmp/private.pem 2048; openssl rsa -in /tmp/private.pem -pubout -out /tmp/public.pem > /dev/null 2>&1"
  $ R "swupdate -k /tmp/public.pem -i /tmp/prplos-intel_x86-lgm-PRPL_OSP_v2-tb341_wav700-image.swu -v -H ospv2:1.0.0 -e ${SELECT_IMAGE},full 2>&1 | grep -i 'endupdate .* SWUpdate \*failed\* !'"
  [ERROR] : SWUPDATE failed [0] ERROR install_from_file.c : endupdate : 55 : SWUpdate *failed* !
