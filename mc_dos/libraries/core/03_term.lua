--[[
    Term Library

    This is a simple implementation, nothing fancy

    Just to simplify the gpu API a bit
]]

local component = require("component")
local computer = require("computer")
local gpu
local maxX, maxY = 10, 10
local blink = false
local cursorX, cursorY = 1, 1
for address, typ in component.list("gpu", true) do
  gpu = component.proxy(address)
  break
end
maxX, maxY = gpu.maxResolution()
gpu.setResolution(maxX, maxY)
gpu.fill(1, 1, maxX, maxY, " ")

local term = {}

function term.clear()
    gpu.fill(1, 1, maxX, maxY, " ")
end

function term.getBlink()
    return blink
end

function term.setBlink(bl)
    blink = bl
end

function term.setCursorPos(x, y)
    checkArg(1, x, "number")
    checkArg(2, y, "number")
    cursorX = x
    cursorY = y
end

function term.getCursorPos()
    return cursorX, cursorY
end

function term.getGPU()
    return gpu
end

function term.write(text)
    checkArg(1, text, "string")
    if #text < 1 then return false end
    local final_lines = {}
    local buffer = text
    local line = 1
    final_lines[line] = ""
    repeat
        local ch = string.sub(buffer, 1, 1)
        if ch == "\n" then
            line = line+1
            final_lines[line] = ""
            buffer = string.sub(buffer, 2)
        elseif #final_lines[line]+1 <= maxX then
            final_lines[line] = final_lines[line]..ch
            buffer = string.sub(buffer, 2)
        else
            line = line+1
            final_lines[line] = ch
            buffer = string.sub(buffer, 2)
        end
    until #buffer < 1

    local newX = cursorX
    local newY = cursorY
    for each, line in ipairs(final_lines) do
        
        if each == 1 then
            newX = cursorX+#line
            gpu.set(cursorX, cursorY, line)
        else
            gpu.set(1, newY, line)
            newX = #line
        end
        if each < #final_lines then
            newY = newY+1
            if newY > maxY then
                term.scroll(1)
                newY = maxY
            end
        end
    end
    if newX < 1 then newX = 1 end
    if newX > maxX then newX = maxX end
    if newY < 1 then newY = 1 end
    if newY > maxY then newY = maxY end
    cursorX = newX
    cursorY = newY
end

function term.nextLine()
    cursorY = cursorY+1
    cursorX = 1
    if cursorY > maxY then
        term.scroll(1)
        cursorY = maxY
    end
end

function term.scroll(off)
    checkArg(1, off, "number")
    if off >= 1 and off < maxY then
        --scroll down
        gpu.copy(1, 1+off, maxX, maxY-off, 0, -off)
        gpu.fill(1, maxY-off+1, maxX, off, " ")
    elseif off <= -1 and math.abs(off) < maxY then
        --scroll up
        gpu.copy(1, 1, maxX, maxY+off, maxX, maxY+off, 0, -off)
        gpu.fill(1, 1, maxX, math.abs(off), " ")
    elseif off ~= 0 then
        --just clear
        term.clear()
    end
end

_G.term = term