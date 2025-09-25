Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Check CPUs root datamodel:

  $ R "ubus -S call CPUs _get"
  {"CPUs.":{"CPUNumberOfEntries":[1-9][0-9]*}} (re)
  {}
  {"amxd-error-code":0}

Check CPUNumberOfEntries:

  $ R "ubus-cli 'CPUs.CPUNumberOfEntries?' | grep '=' | sed 's/.*=//'"
  [1-9][0-9]* (re)

Check that the DVFS.Supported parameter is synchronized with the system:

  $ obj_indexes=$(R "ubus-cli 'CPUs.CPU.*.Alias?' | grep '=' | sort | sed -E 's/[^.]*\.[^.]*\.([^.]*).*/\1/'")

  $ all_exist_supported=true
  $ for obj_index in $obj_indexes; do
  >   cpu_name=$(R "ubus-cli "CPUs.CPU.$obj_index.Alias?" | grep 'CPUs.CPU.[0-9]*.Alias=' | sort | sed 's/.*=//' | tr -d '\"' | sed 's/^cpe-//'")
  >   ret=$(R "ubus-cli "CPUs.CPU.1.DVFS.Supported?" | grep -oE '[0-9]+$'")
  >   if [ "$ret" -eq 1 ] && [ ! -f "/sys/devices/system/cpu/$cpu_name/cpufreq/scaling_governor" ]; then
  >     all_exist_supported=false
  >   fi
  >   if [ "$ret" -eq 0 ] && [ -f "/sys/devices/system/cpu/$cpu_name/cpufreq/scaling_governor" ]; then
  >     all_exist_supported=false
  >   fi
  > done

  $ if [ "$all_exist_supported" = true ]; then 
  >   echo "DVFS Supported OK"
  > fi
  DVFS Supported OK

Check that the scaling frequencies is synchronized with the system:

  $ all_values_match=true

  $ for obj_index in $obj_indexes; do
  >   cpu_name=$(R "ubus-cli "CPUs.CPU.$obj_index.Alias?" | grep 'CPUs.CPU.[0-9]*.Alias=' | sort | sed 's/.*=//' | tr -d '\"' | sed 's/^cpe-//'")
  >   get_scaling_governor=$(R "cat /sys/devices/system/cpu/$cpu_name/cpufreq/scaling_governor")
  >   get_scaling_max_freq=$(R "cat /sys/devices/system/cpu/$cpu_name/cpufreq/scaling_max_freq")
  >   get_scaling_min_freq=$(R "cat /sys/devices/system/cpu/$cpu_name/cpufreq/scaling_min_freq")
  >   dm_scaling_governor=$(R "ubus-cli "CPUs.CPU.$obj_index.DVFS.ScalingGovernor?" | grep '=' | sort | sed 's/.*=//' | tr -d '\"'")
  >   dm_scaling_max_freq=$(R "ubus-cli "CPUs.CPU.$obj_index.DVFS.ScalingMaxFrequency?" | grep '=' | sort | sed 's/.*=//'")
  >   dm_scaling_min_freq=$(R "ubus-cli "CPUs.CPU.$obj_index.DVFS.ScalingMinFrequency?" | grep '=' | sort | sed 's/.*=//'")
  >   if [ "$get_scaling_governor" != "$dm_scaling_governor" ]; then
  >     echo "dm scaling_governor $dm_scaling_governor, sys scaling_governor $get_scaling_governor, objindex $obj_index"
  >     all_values_match=false
  >   fi
  >   if [ "$get_scaling_max_freq" != "$dm_scaling_max_freq" ]; then
  >     echo "dm scaling_max_freq $dm_scaling_max_freq, sys scaling_max_freq $dm_scaling_max_freq, objindex $obj_index"
  >     all_values_match=false
  >   fi
  >   if [ "$get_scaling_min_freq" != "$dm_scaling_min_freq" ]; then
  >     echo "dm scaling_min_freq $dm_scaling_min_freq, sys scaling_min_freq $dm_scaling_min_freq, objindex $obj_index"
  >     all_values_match=false
  >   fi
  > done

  $ if [ "$all_values_match" = true ]; then 
  >   echo "All values matched"
  > fi
  All values matched
