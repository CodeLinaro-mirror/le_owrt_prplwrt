Skip test on nec-wx3000hp until LCM-579 is fixed:

  $ [ "$DUT_BOARD" = "nec-wx3000hp" ] && exit 80
  [1]

Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Check that random LXC binaries work:

  $ R lxc-info
  lxc-info: No container name specified
  [1]

  $ R lxc-device
  lxc-device: No container name specified
  [1]

Check Cthulhu.Config datamodel:

  $ R "ubus-cli -l -j Cthulhu.Config.?0 | jsonfilter -e @[*].*.PluginLocation -e @[*].*.ImageLocation -e @[*].*.UseOverlayFS -e @[*].*.GracefulShutdownTimeoutSeconds -e @[*].*.UseBundles -e @[*].*.StorageLocation -e @[*].*.DefaultBackend -e @[*].*.BundleLocation -e @[*].*.BlobLocation | sort"
  /lcm/celephais/bundles
  /lcm/cthulhu
  /lcm/rlyeh/blobs
  /lcm/rlyeh/images
  /usr/lib/amx/cthulhu/plugins
  /usr/lib/cthulhu-lxc/cthulhu-lxc.so
  0
  1
  10


Check Rlyeh datamodel:

  $ R "ba-cli -l -j Rlyeh.?0 | jsonfilter -e @[*].*.PluginLocation  -e @[*].*.ImageLocation -e @[*].*.ROImageLocation -e @[*].*.ROStorageLocation -e @[*].*.CertificateVerification -e @[*].*.SignatureVerification -e @[*].*.StorageLocation -e @[*].*.RemainingDiskSpaceBytes -e @[*].*.OnboardingFile  | sort"
  /lcm/rlyeh/blobs
  /lcm/rlyeh/images
  /lcm/rlyeh_onboarded
  /usr/lib/amx/rlyeh/plugins
  /usr/rlyeh/blobs
  /usr/rlyeh/images
  1
  1
  1000001


Check SoftwareModules datamodel:

  $ R "ba-cli -l -j SoftwareModules.? | jsonfilter -e @[*].*.ExecEnvNumberOfEntries -e @[*].*.ExecutionUnitNumberOfEntries -e @[*].*.DeploymentUnitNumberOfEntries | sort"
  0
  0
  1


Check Timingila datamodel:

  $ R "ba-cli -l -j Timingila.?0 | jsonfilter -e @[*].*.ContainerPluginPath -e @[*].*.PackagerPluginPath -e @[*].*.RmAfterUninstall -e @[*].*.version | sort"
  /usr/lib/timingila-cthulhu/timingila-cthulhu.so
  /usr/lib/timingila-rlyeh/timingila-rlyeh.so
  1
  alpha


Check that Rlyeh has no container images:

  $ R "ba-cli -l -j 'Rlyeh.Images.?'"
  
  [{}]
  

Check that registry.gitlab.com is accessible:

  $ R "curl --silent --show-error --connect-timeout 60 https://registry.gitlab.com"

Check that Rlyeh can download testing container:

  $ R "ba-cli -l -j 'Rlyeh.pull(URI = \"docker://registry.gitlab.com/prpl-foundation/prplos/prplos/prplos-testing-container-intel_mips-xrx500:v1\", DUID = \"0f032bd7-54bd-5b81-b14e-9441d730092f\")'"
  
  Rlyeh.pull() returned
  [""]
  

  $ R 'i=1; while [ $i -lt 10 ] && [ "$(ba-cli -lj "Rlyeh.Images.[DUID == \"0f032bd7-54bd-5b81-b14e-9441d730092f\"].DUID?" | jsonfilter -e @[*].*.DUID)" != "0f032bd7-54bd-5b81-b14e-9441d730092f" ]; do i=$((i+1)); sleep 1; done'


Check that Rlyeh has downloaded the testing container:

  $ R "ba-cli -l -j 'Rlyeh.Images.[DUID == \"0f032bd7-54bd-5b81-b14e-9441d730092f\"].?' | jsonfilter -e @[*].*.Name -e @[*].*.Status | sort"
  Downloaded
  prpl-foundation/prplos/prplos/prplos-testing-container-intel_mips-xrx500

Remove testing container:

  $ R "ba-cli -l -j 'Rlyeh.remove(DUID=\"0f032bd7-54bd-5b81-b14e-9441d730092f\", Version = \"v1\")'"; sleep 5
  
  Rlyeh.remove() returned
  [""]
  

  $ R "ba-cli -l -j 'Rlyeh.Images.[DUID == \"0f032bd7-54bd-5b81-b14e-9441d730092f\"].?' | jsonfilter -e @[*].*.MarkForRemoval"
  1

  $ R "ba-cli -l -j 'Rlyeh.gc()'"; sleep 5
  
  Rlyeh.gc() returned
  [""]
  

Check that Rlyeh has no container images:

  $ R "ba-cli -l -j 'Rlyeh.Images.?'"
  
  [{}]
  

Check that testing image is gone from the filesystem as well:

  $ R "ls -al /lcm_data/rlyeh/images/prplos/prplos-testing-container-intel_mips-xrx500"
  ls: /lcm_data/rlyeh/images/prplos/prplos-testing-container-intel_mips-xrx500: No such file or directory
  [1]
