Create alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ alias C="${CRAM_REMOTE_COPY:-}"

Check boot information before upgrade:

  $ R "cat /proc/device-tree/chosen/u-boot,booted-bank | tr -d '\0'; echo"
  active

Copy the .swu image for the swupdate dry run test:

  $ C ${CI_PROJECT_DIR}/bin/targets/ipq95xx/generic/prplos-ipq95xx-generic-prpl_freedom-image.swu root@${TARGET_LAN_IP}:/tmp/
  Warning: Permanently added '*' (*) to the list of known hosts* (glob)

Run SWUpdate in dry-run mode:

  $ R "test -f /tmp/prplos-ipq95xx-generic-prpl_freedom-image.swu"
  $ R "swupdate -n -k /security/public.pem -i /tmp/prplos-ipq95xx-generic-prpl_freedom-image.swu -v -H freedom:1.0.0 -e active,full 2>/dev/null | grep -F 'SWUpdate was successful'"
  [INFO ] : SWUPDATE running :  [endupdate] : SWUpdate was successful !

Run SWUpdate in dry-run mode using a wrong public key:

  $ R "test -f /tmp/prplos-ipq95xx-generic-prpl_freedom-image.swu"
  $ R "openssl genrsa -out /tmp/private.pem 2048; openssl rsa -in /tmp/private.pem -pubout -out /tmp/public.pem > /dev/null 2>&1"
  $ R "swupdate -n -k /tmp/public.pem -i /tmp/prplos-ipq95xx-generic-prpl_freedom-image.swu -v -H freedom:1.0.0 -e active,full 2>&1 | grep -i 'endupdate .* SWUpdate \*failed\* !'"
  [ERROR] : SWUPDATE failed [0] ERROR install_from_file.c : endupdate : 55 : SWUpdate *failed* !
