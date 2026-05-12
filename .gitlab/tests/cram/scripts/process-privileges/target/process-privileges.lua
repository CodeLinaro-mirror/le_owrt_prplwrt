#!/usr/bin/env lua

-- Collect process information into a data structure
local processes = {}
local uid_to_name = {}
local gid_to_name = {}
local full_capeff = nil
local with_color = false

local color = {
    red = "\27[31m",
    green = "\27[32m",
    yellow = "\27[33m",
    blue = "\27[34m",
    magenta = "\27[35m",
    cyan = "\27[36m",
    white = "\27[37m",
    normal = "\27[39;49m"
}

-- Parse /etc/passwd for UID to username mapping
local function load_passwd()
    local f = io.open("/etc/passwd", "r")
    if f then
        for line in f:lines() do
            local name, _, uid = line:match("^([^:]+):([^:]*):(%d+)")
            if name and uid then
                uid_to_name[uid] = name
            end
        end
        f:close()
    end
end

-- Parse /etc/group for GID to group name mapping
local function load_group()
    local f = io.open("/etc/group", "r")
    if f then
        for line in f:lines() do
            local name, _, gid = line:match("^([^:]+):([^:]*):(%d+)")
            if name and gid then
                gid_to_name[gid] = name
            end
        end
        f:close()
    end
end

-- Read a file and return its content
local function read_file(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local content = f:read("*all")
    f:close()
    return content
end

-- Get value from /proc/[pid]/status content string
local function get_proc_status_value(status, key)
    return status:match(key .. ":%s*([^\n]+)")
end

-- Execute command and return output
local function exec(cmd)
    local handle = io.popen(cmd)
    if not handle then return "" end
    local result = handle:read("*all")
    handle:close()
    return result
end

-- Get basename of path
local function basename(path)
    return path:match("([^/]+)$") or path
end

-- Parse command name from cmdline
local function parse_command_name(cmdline)
    -- Get command name (basename only)
    local cmd = cmdline:match("([^%z]+)")
    if not cmd then
        return nil
    end
    cmd = basename(cmd)

    -- For certain interpreters/launchers, append the first argument to clarify identity
    -- e.g., "lua" -> "lua:script_name", "amxrt" -> "amxrt:module_name"
    if cmd == "lua" or cmd == "amxrt" then
        -- Extract second argument (first argument after command)
        local arg = cmdline:match("[^%z]*%z([^%z]+)")
        if arg then
            arg = basename(arg)
            -- Remove common extensions
            arg = arg:gsub("%.lua$", ""):gsub("%.odl$", "")
            cmd = cmd .. ":" .. arg
        end
    end

    return cmd
end

-- Format ID (user or group) with real/effective notation if needed
-- Args: id_line (space-separated: real effective saved filesystem), id_to_name (lookup table)
local function format_id(id_line, id_to_name)
    if not id_line then
        return "0"
    end

    -- Parse the ID line (Real, Effective, Saved, Filesystem)
    local ids = {}
    for id in id_line:gmatch("%S+") do
        table.insert(ids, id)
    end

    local rid = ids[1] or "0"
    local eid = ids[2] or "0"
    local sid = ids[3] or "0"
    local fsid = ids[4] or "0"

    local ename = id_to_name[eid] or eid

    -- Check if IDs differ
    if rid ~= eid or sid ~= eid or fsid ~= eid then
        local rname = id_to_name[rid] or rid
        return rname .. "/" .. ename
    end
    return ename
end

-- Decode capabilities
local function decode_caps(capeff)
    if not capeff or capeff == "0" or capeff == "0000000000000000" then
        return "none"
    elseif capeff == full_capeff then
        return "full"
    end

    -- Use capsh to decode
    local caps_raw = exec("capsh --decode=" .. capeff .. " 2>/dev/null")
    if not caps_raw or caps_raw == "" then
        return capeff
    end
    caps_raw = caps_raw:gsub("0x[0-9a-f]*=", "")

    -- Split by comma, remove cap_ prefix, sort, and rejoin
    local caps_list = {}
    for cap in caps_raw:gmatch("[^,]+") do
        cap = cap:gsub("^%s*cap_", ""):gsub("^%s+", ""):gsub("%s+$", "")
        if cap ~= "" then
            table.insert(caps_list, cap)
        end
    end

    if #caps_list == 0 then
        return "none"
    end

    table.sort(caps_list)
    return table.concat(caps_list, ",")
end

-- Collect information for a single process
local function collect_process(pid)
    -- Check if it's a kernel thread (empty cmdline)
    local cmdline = read_file("/proc/" .. pid .. "/cmdline")
    if not cmdline or cmdline == "" then
        return
    end

    -- Get command name
    local cmd = parse_command_name(cmdline)
    if not cmd then
        return
    end

    -- Get process status
    local status = read_file("/proc/" .. pid .. "/status")
    if not status or status == "" then
        return
    end

    -- Get PPID
    local ppid = get_proc_status_value(status, "PPid")

    -- Format user and group with real/effective notation if needed
    local user = format_id(get_proc_status_value(status, "Uid"), uid_to_name)
    local group = format_id(get_proc_status_value(status, "Gid"), gid_to_name)

    -- Get capabilities
    local capeff = get_proc_status_value(status, "CapEff")
    local caps = decode_caps(capeff)

    -- Store process info
    processes[pid] = {
        pid = pid,
        ppid = ppid,
        cmd = cmd,
        user = user,
        group = group,
        caps = caps
    }
end

-- Collect all process information
local function collect_processes()
    -- Get init's capabilities as the baseline for "full" capabilities
    local init_status = read_file("/proc/1/status")
    if init_status then
        full_capeff = get_proc_status_value(init_status, "CapEff")
    end

    -- Get list of PIDs and collect for each
    for entry in io.popen("ls -1 /proc"):lines() do
        if entry:match("^%d+$") then
            collect_process(entry)
        end
    end
end

-- Get children of a process, sorted by command name
local function get_sorted_children(ppid)
    local children = {}
    for pid, proc in pairs(processes) do
        if proc.ppid == ppid then
            table.insert(children, proc)
        end
    end

    table.sort(children, function(a, b)
        return a.cmd < b.cmd
    end)

    return children
end

-- Recursively print process in a tree
local function print_tree_proc(indent, proc)
    if not with_color then
        print(string.format("%s%s %s:%s %s", indent, proc.cmd, proc.user, proc.group, proc.caps))
        return
    end

    local user_color = color.normal
    local group_color = color.normal
    local caps_color = color.normal

    if proc.user == "root" then
        user_color = color.red
    elseif proc.user == "tr181_app" then
        user_color = color.blue
    else
        user_color = color.cyan
    end

    if proc.group == "root" then
        group_color = color.red
    elseif proc.group == "tr181_app" then
        group_color = color.blue
    else
        group_color = color.cyan
    end

    if proc.caps == "full" then
        caps_color = color.red
    elseif proc.caps == "none" then
        caps_color = color.green
    else
        caps_color = color.yellow
    end

    print_str = string.format("%s%s %s%s%s:%s%s %s%s%s",
        indent,
        proc.cmd,
        user_color, proc.user,
        color.normal,
        group_color, proc.group,
        caps_color, proc.caps,
        color.normal
    )
    print(print_str)
end

-- Recursively print process tree
local function print_tree(pid, indent, parent_cmd)
    local children = get_sorted_children(pid)

    for _, proc in ipairs(children) do
        print_tree_proc(indent, proc)

        -- Skip children of dropbear (SSH sessions are not deterministic)
        if proc.cmd ~= "dropbear" then
            print_tree(proc.pid, indent .. "  ", proc.cmd)
        end
    end
end

local function print_root_tree()
    -- Print init (PID 1) and its tree
    if processes["1"] then
        local init = processes["1"]
        print(string.format("%s %s:%s %s", init.cmd, init.user, init.group, init.caps))
        print_tree("1", "  ")
    end

    -- Print orphaned processes (parent doesn't exist in our list)
    for pid, proc in pairs(processes) do
        if pid ~= "1" and not processes[proc.ppid] then
            print(string.format("%s %s:%s %s", proc.cmd, proc.user, proc.group, proc.caps))
            print_tree(pid, "  ")
        end
    end
end

local function print_list()
    local sorted_keys = {}
    for pid in pairs(processes) do
        table.insert(sorted_keys, pid)
    end
    table.sort(sorted_keys, function(a,b)
        return tonumber(a) < tonumber(b)
    end)
    for _, pid in ipairs(sorted_keys) do
        local proc = processes[pid]
        print(string.format("%d %d %s %s:%s %s", pid, proc.ppid, proc.cmd, proc.user, proc.group, proc.caps))
    end
end

-- Main execution
load_passwd()
load_group()
collect_processes()

if arg[1] == "list" then
    print_list()
elseif arg[1] == "color_tree" then
    with_color = true
    print_root_tree()
else
    print_root_tree()
end
