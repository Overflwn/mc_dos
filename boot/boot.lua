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
local list = filesystem.list("/mc_dos/libraries/core/")
for each, file in ipairs(list) do
  if file ~= "01_filesystem.lua" and file ~= "02_package.lua" then
    local func, err = loadfile("/mc_dos/libraries/core/"..file)
    assert(func, "COULD NOT LOAD '"..file.."': "..tostring(err))
    local success, err = pcall(func)
    assert(success, tostring(err))
    if term then
      term.write(file.." LOADED! ")
      term.nextLine()
    end
  end
end

local computer = require("computer")
--Re-implement computer.pullSignal, to make it coroutine-compatible
local oldpull = computer.pullSignal
function computer.pullSignal(timeout)
  return coroutine.yield(timeout)
end
local timers = {}
local last_id = 0
function computer.setTimer(timeout)
  local timer = {
    timeout = timeout,
    counter = 0,
    id = last_id
  }
  last_id = last_id+1
  table.insert(timers, timer)
  return last_id-1
end

function computer.sleep(timeout)
  checkArg(1, timeout, "number")
  if timeout < 1 then
    return false
  end
  local timer = computer.setTimer(timeout)
  repeat
    local event, id = computer.pullSignal()
  until event == "timer" and id == timer
end
term.write("Hello World!\n")

local function blink()
  local on = false
  while true do
    computer.sleep(1)
    on = not on
    local cX, cY = term.getCursorPos()
    local gpu = term.getGPU()
    if on then
      gpu.set(cX, cY, "_")
    else
      gpu.set(cX, cY, " ")
    end
  end
end

local blinker = coroutine.create(blink)

local func, err = loadfile("/mc_dos/bin/shell.lua")
assert(func, tostring(err))
local shell = coroutine.create(func)
local ev = {}
local last_time = computer.uptime()
local shell_startedToWait = -1
local blink_startedToWait = -1
local shell_counter = 0
local blink_counter = 0
local shell_timeout = 0
local shell_timeout = 0
while true do
  local succ, timeout = coroutine.resume(shell, unpack(ev))
  assert(succ, timeout)
  shell_startedToWait = computer.uptime()
  shell_timeout = timeout
  shell_counter = 0
  succ, timeout = coroutine.resume(blinker, unpack(ev))
  assert(succ, timeout)
  blink_startedToWait = computer.uptime()
  ev = {}
  local newTime = computer.uptime()
  if newTime > last_time then
    local difference = newtime - last_time
    local to_remove = {}
    for each, timer in ipairs(timers) do
      timer.counter = timer.counter+difference
      if timer.counter >= timer.timeout then
        computer.pushSignal("timer", timer.id)
        table.insert(to_remove, each)
      end
    end
    for each, timer in ipairs(to_remove) do
      table.remove(timers, timer)
    end
  end

  ev = table.pack(oldpull(0))
end
func()