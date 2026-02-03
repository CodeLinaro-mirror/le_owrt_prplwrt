#!/usr/bin/lua

local req_object = arg[1]
local req_event = arg[2]
local filter = arg[3]

local lamx = require 'lamx'

local usp_socket = "usp:/var/run/pwhm_usp.sock"
if arg[4] == "broker" then
    usp_socket = "usp:/var/run/usp/broker_agent_path"
end

local usp_backend_config = {
    usp = {
        EndpointID = 'proto::local_controller'
    }
}

lamx.backend.load("/usr/bin/mods/usp/mod-amxb-usp.so")
lamx.backend.push_config(usp_backend_config)
lamx.bus.open(usp_socket)

local el = lamx.eventloop.new()
local print_event = function(event, data)
  if event == req_event then
    print("Event " .. event)
    table.dump(data)
    el:stop()
  end
end

local sub = lamx.bus.subscribe(req_object, print_event, filter);

el:start()

--lamx.bus.ubsubscribe(sub)

lamx.backend.remove("usp")
