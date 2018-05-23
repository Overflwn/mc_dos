--[[

        MC_DOS Terminal
    
    The actual "OS"

    ~Piorjade
]]

local computer = require("computer")
local unicode = require("unicode")
local freeMemory = computer.freeMemory()
local totalMemory = computer.totalMemory()
totalMemory = math.floor(totalMemory/1000)
freeMemory = math.floor(freeMemory/1000)
term.clear()
term.setCursorPos(1,1)
term.write("--[[Welcome to MC-DOS!]]--\n")

term.write("Max memory: "..totalMemory.."kb   Free: "..freeMemory.."kb\n\n")


local function isControl(char)
    return type(char) == "number" and (char < 0x20 or (char >= 0x7F and char <= 0x9F))
end

local function read()
    local text = ""
    repeat
        local event, addr, char, code = computer.pullSignal()
        if event == "key_down" and not isControl(char) then
            text = text..unicode.char(char)
            term.write(unicode.char(char))
        elseif event == "key_down" and code == 14 and #text > 0 then
            --backspace
            text = string.sub(text, 1, #text-1)
            local oldX, oldY = term.getCursorPos()
            term.setCursorPos(oldX-1, oldY)
            term.getGPU().set(oldX-1, oldY, " ")
            --fix blinker remaining there
	    term.getGPU().set(oldX, oldY, " ")
    	end
        --enter
    until event == "key_down" and code == 28
    local x, y = term.getCursorPos()
    term.getGPU().set(x, y, " ")
    term.write("\n")
    return text
end


while true do
    term.write(filesystem.getLetter()..":> ")
    local cmd = read()
    if #cmd == 2 and string.sub(cmd, 2, 2) == ":" then
        local succ = filesystem.setDriveLetter(string.sub(cmd, 1, 1))
        if not succ then
            term.write("No such drive '"..string.sub(cmd, 1, 1).."'.\n")
        end
    elseif cmd == "disks" then
        local list = filesystem.getMounted()
        for each, letter in ipairs(list) do
            local spaceTotal = filesystem.spaceTotal(letter)
            local spaceUsed = filesystem.spaceUsed(letter)
            local spaceFree = math.floor((spaceTotal - spaceUsed)/1000)
            term.write("Letter: "..letter.." | Free Space: "..spaceFree.."\n")
        end
    elseif not filesystem.exists(cmd) and not filesystem.exists("/mc_dos/bin/"..cmd) then
        term.write("Command not found.\n")
    else
        local file, err = loadfile(cmd)
        if not file then
            term.write("LOADING ERROR: "..tostring(err))
        end
        local success, err = pcall(file)
        if not success then
            term.write("RUNTIME ERROR: "..tostring(err))
        end
    end
end
