--[[
		MC-DOS

	boot.lua: Initialize low-level libraries and system

	~Piorjade

]]

local primitive_loadfile = load([[return function(file, env)
    local pc,cp = computer or package.loaded.computer, component or package.loaded.component
    local addr, invoke = pc.getBootAddress(), cp.invoke
    local handle, reason = invoke(addr, "open", file)
    assert(handle, reason)
    local buffer = ""
    repeat
      local data, reason = invoke(addr, "read", handle, math.huge)
      assert(data or not reason, reason)
      buffer = buffer .. (data or "")
    until not data
    invoke(addr, "close", handle)
    return load(buffer, "=" .. file, "bt", env or _G)
  end]], "=loadfile", "bt", _G)()

local fs, err = primitive_loadfile("/mc_dos/libraries/core/01_filesystem.lua")
assert(fs, "COULD NOT LOAD FILESYSTEM: "..tostring(err))
_G.filesystem = fs()
_G.loadfile = function(file, env)
	-- New loadfile utilizing the new filesystem API
	local handle, reason, ltr = filesystem.open(file)
	assert(type(handle) == "table", tostring(reason))
	local buffer = ""
    repeat
      local data, _reason = filesystem.read(handle, math.huge, reason)
      assert(data or not _reason, _reason)
      buffer = buffer .. (data or "")
    until not data
    filesystem.close(handle, reason)
    return load(buffer, "=" .. file, "bt", env or _G) 
end

loadfile("/mc_dos/libraries/core/02_package.lua")()

local component = require("component")
local computer = require("computer")
local gpu
for address, typ in component.list("gpu", true) do
  gpu = component.proxy(address)
  gpu.fill(1, 1, 50, 50, " ")
  gpu.set(1, 1, "Hello World!")
  break
end

while true do
  computer.pullSignal()
end