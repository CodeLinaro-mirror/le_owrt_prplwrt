#!/usr/bin/lua

local req_object = arg[1]
local req_event = arg[2]
local filter = arg[3]

local lamx = require 'lamx'

lamx.backend.load("/usr/bin/mods/amxb/mod-amxb-ubus.so")
lamx.bus.open("ubus:/var/run/ubus/ubus.sock")

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

lamx.backend.remove("ubus")
