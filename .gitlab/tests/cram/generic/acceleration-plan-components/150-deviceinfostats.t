Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Check GetBusStats() function:

  $ R "ba-cli 'DeviceInfo.GetBusStats()' | grep -v '>'"
  DeviceInfo.GetBusStats() returned
  [
      {
          ubus:/var/run/ubus/ubus.sock = {
              rx = {
                  operation = {
                      invoke = [0-9]+ (re)
                  }
              },
              tx = {
                  operation = {
                      add = [0-9]+, (re)
                      async_invoke = [0-9]+, (re)
                      del = [0-9]+, (re)
                      describe = [0-9]+, (re)
                      get = [0-9]+, (re)
                      get_filtered = [0-9]+, (re)
                      get_instances = [0-9]+, (re)
                      get_supported = [0-9]+, (re)
                      has = [0-9]+, (re)
                      invoke = [0-9]+, (re)
                      list = [0-9]+, (re)
                      set = [0-9]+, (re)
                      subscribe = [0-9]+, (re)
                      unsubscribe = [0-9]+, (re)
                      wait_for = [0-9]+ (re)
                  }
              }
          },
          usp:/var/run/usp/broker_agent_path = {
              rx = {
                  operation = {
                      add = [0-9]+, (re)
                      del = [0-9]+, (re)
                      get = [0-9]+, (re)
                      get_instances = [0-9]+, (re)
                      get_supported = [0-9]+, (re)
                      invoke = [0-9]+, (re)
                      notify = [0-9]+, (re)
                      set = [0-9]+ (re)
                  }
              },
              tx = {
                  operation = {
                      add = [0-9]+, (re)
                      async_invoke = [0-9]+, (re)
                      del = [0-9]+, (re)
                      describe = [0-9]+, (re)
                      get = [0-9]+, (re)
                      get_filtered = [0-9]+, (re)
                      get_instances = [0-9]+, (re)
                      get_supported = [0-9]+, (re)
                      has = [0-9]+, (re)
                      invoke = [0-9]+, (re)
                      list = [0-9]+, (re)
                      set = [0-9]+, (re)
                      subscribe = [0-9]+, (re)
                      unsubscribe = [0-9]+, (re)
                      wait_for = [0-9]+ (re)
                  }
              }
          },
          usp:/var/run/usp/broker_controller_path = {
              rx = {
                  operation = {
                      add = [0-9]+, (re)
                      del = [0-9]+, (re)
                      get = [0-9]+, (re)
                      get_instances = [0-9]+, (re)
                      get_supported = [0-9]+, (re)
                      invoke = [0-9]+, (re)
                      notify = [0-9]+, (re)
                      set = [0-9]+ (re)
                  }
              },
              tx = {
                  operation = {
                      add = [0-9]+, (re)
                      async_invoke = [0-9]+, (re)
                      del = [0-9]+, (re)
                      describe = [0-9]+, (re)
                      get = [0-9]+, (re)
                      get_filtered = [0-9]+, (re)
                      get_instances = [0-9]+, (re)
                      get_supported = [0-9]+, (re)
                      has = [0-9]+, (re)
                      invoke = [0-9]+, (re)
                      list = [0-9]+, (re)
                      set = [0-9]+, (re)
                      subscribe = [0-9]+, (re)
                      unsubscribe = [0-9]+, (re)
                      wait_for = [0-9]+ (re)
                  }
              }
          }
      }
  ]
  

Check stats after doing an action:

  $ init_cnt=$(R "ba-cli 'DeviceInfo.GetBusStats()' | grep -A 10 'ubus:/var/run/ubus/ubus.sock' | grep 'rx' -A 5 | grep 'invoke' | awk -F'= ' '{print \$2}'")
  $ echo "$init_cnt"
  [0-9]+ (re)

  $ R "ubus-cli 'DeviceInfo._get()' | grep -v '>' | grep 'DeviceInfo._get()'"
  DeviceInfo._get() returned

  $ final_cnt=$(R "ba-cli 'DeviceInfo.GetBusStats()' | grep -A 10 'ubus:/var/run/ubus/ubus.sock' | grep 'rx' -A 5 | grep 'invoke' | awk -F'= ' '{print \$2}'")
  $ echo "$final_cnt"
  [0-9]+ (re)

  $ if [ "$final_cnt" -gt "$init_cnt" ]; then
  >  echo "Test Successful"
  > else
  >  echo "Test failed: final_cnt($final_cnt) is not greater then init_cnt($init_cnt)"
  > fi
  Test Successful
