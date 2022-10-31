Skip test on nec-wx3000hp until LCM-579 is fixed:

  $ [ "$DUT_BOARD" = "nec-wx3000hp" ] && exit 80
  [1]

Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Check that Rlyeh has no container images:

  $ R "ubus -S call Rlyeh.Images _get"
  {"Rlyeh.Images.":{}}

Check that Rlyeh can download testing container:

  $ R "ubus -S call Rlyeh pull '{\"URI\":\"docker://registry.gitlab.com/prpl-foundation/prplos/prplos/prplos-testing-container-intel_mips-xrx500:v1\",\"UUID\":\"testing\"}'"
  {"retval":""}

  $ R "ubus -t 60 wait_for Rlyeh.Images.1"

Check that Rlyeh has downloaded the testing container:

  $ R "ubus -S call Rlyeh.Images _get | jsonfilter -e @[*].Name -e @[*].Status | sort"
  Downloaded
  prplos/prplos-testing-container-intel_mips-xrx500

Remove testing container:

  $ R "ubus -S call Rlyeh remove '{\"UUID\":\"testing\",\"Version\":\"v1\"}'"; sleep 5
  {"retval":""}

  $ R "ubus -S call Rlyeh.Images.1 _get | jsonfilter -e @[*].MarkForRemoval"
  true

  $ R "ubus -S call Rlyeh gc"
  {"retval":""}

Check that Rlyeh has no container images:

  $ R "ubus -S call Rlyeh.Images _get"
  {"Rlyeh.Images.":{}}

Check that testing image is gone from the filesystem as well:

  $ R "ls -al /usr/share/rlyeh/images/prplos/prplos-testing-container-intel_mips-xrx500"
  ls: /usr/share/rlyeh/images/prplos/prplos-testing-container-intel_mips-xrx500: No such file or directory
  [1]
