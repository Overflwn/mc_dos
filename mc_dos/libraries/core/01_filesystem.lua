--[[

		MC-DOS /mc_dos/libraries/core/filesystem.lua

	Initialize filesystem and a simple API.

	TODO: Implement removing drives
]]

-- table containing every hard drive (which get mounted automatically)
local hard_drives = {}

-- get the boot device and set the proxy to "mount point" "C:"
local boot_addr = computer.getBootAddress()
local current = "C"
local filesystem = {}
local available_drives = {
	"C",
	"D",
	"E",
	"F",
	"G",
	"H",
	"I",
	"J"
}
hard_drives["C"] = {
	proxy = component.proxy(boot_addr),
	address = boot_addr
}

function filesystem.listenForFilesystems()
	while true do
		local ev, addr, typ = computer.pullSignal()
		if ev == "component_added" and typ == "filesystem" then
			--NOTE: currently, there is a virtual limit of 8 drives, as I don't think you can
			--		add more anyway
			local new_letter
			for i=0, 8 do
				-- i+1 because lua tables start with 1
				if hard_drives[available_drives[i+1]] == nil then
					new_letter = available_drives[i+1]
					break
				end
			end
			if new_letter ~= nil then
				--If an empty drive letter is found
				hard_drives[new_letter] = {
					proxy = component.proxy(addr),
					address = addr
				}
			end
		elseif ev == "component_removed" and typ == "filesystem" then
			local remove_letter
			for i=0, 8 do
				if hard_drives[available_drives[i+1]] ~= nil and hard_drives[available_drives[i+1]].address == addr then
					remove_letter = available_drives[i+1]
					break
				end
			end
			if remove_letter then
				hard_drives[remove_letter] = nil
			end
		end
	end
end

function filesystem.setDriveLetter(letter)
	-- Switch the drive we are working in
	if hard_drives[letter] then
		current = letter
		return true
	else
		return false
	end
end

function filesystem.getDriveProxy(letter)
	if hard_drives[letter] then return hard_drives[letter].proxy else return nil end
end

function filesystem.getDriveAddress(letter)
	if hard_drives[letter] then return hard_drives[letter].address else return nil end
end

function filesystem.getLetter()
	return current
end

function filesystem.getMounted()
	local list = {}
	for each, disk in pairs(hard_drives) do
		table.insert(list, each)
	end
	return list
end

-- Here begin re-implementations of the standard filesystem API
-- to redirect them to the currently selected drive, because that's
-- how I do it.

function filesystem.spaceUsed(letter)
	if type(letter) ~= "string" or #letter ~= 2 then
		return hard_drives[current].proxy.spaceUsed()
	else
		local actual_letter = string.sub(letter, 1, 1)
		if hard_drives[actual_letter] then return hard_drives[actual_letter].proxy.spaceUsed() else return nil end
	end
end

function filesystem.open(path, mode)
	checkArg(1, path, "string")
	if string.sub(path, 2, 2) ~= ":" then
		return hard_drives[current].proxy.open(path, mode)
	else
		if hard_drives[string.sub(path, 1, 1)] then
			return hard_drives[string.sub(path, 1, 1)].proxy.open(string.sub(path, 3), mode), string.sub(path, 1, 1)
		end
	end
end

function filesystem.seek(handle, whence, offset, letter)
	if type(letter) ~= "string" then
		return hard_drives[current].proxy.seek(handle, whence, offset)
	else
		if hard_drives[letter] then
			return hard_drives[letter].proxy.seek(handle, whence, offset)
		end
	end
end

function filesystem.makeDirectory(path)
	checkArg(1, path, "string")
	if string.sub(path, 2, 2) ~= ":" then
		return hard_drives[current].proxy.makeDirectory(path)
	else
		if hard_drives[string.sub(path, 1, 1)] then
			return hard_drives[string.sub(path, 1, 1)].proxy.makeDirectory(string.sub(path, 3))
		end
	end
end

function filesystem.exists(path)
	checkArg(1, path, "string")
	if string.sub(path, 2, 2) ~= ":" then
		return hard_drives[current].proxy.exists(path)
	else
		if hard_drives[string.sub(path, 1, 1)] then
			return hard_drives[string.sub(path, 1, 1)].proxy.exists(string.sub(path, 3))
		end
	end
end

function filesystem.isReadOnly(letter)
	if type(letter) ~= "string" then
		return hard_drives[current].proxy.isReadOnly()
	else
		if hard_drives[letter] then
			return hard_drive[letter].proxy.isReadOnly()
		end
	end
end

function filesystem.write(handle, value, letter)
	checkArg(1, handle, "table")
	checkArg(2, value, "string")
	if type(letter) ~= "string" then
		return hard_drives[current].proxy.write(handle, value)
	else
		if hard_drives[letter] then
			return hard_drives[letter].proxy.write(handle, value)
		end
	end
end

function filesystem.spaceTotal(letter)
	if type(letter) ~= "string" then
		return hard_drives[current].proxy.spaceTotal()
	else
		if hard_drives[letter] then
			return hard_drives[letter].proxy.spaceTotal()
		end
	end
end

function filesystem.isDirectory(path, letter)
	checkArg(1, path, "string")
	if type(letter) ~= "string" then
		return hard_drives[current].proxy.isDirectory(path)
	else
		if hard_drives[letter] then
			return hard_drives[letter].proxy.isDirectory(path)
		end
	end
end

function filesystem.rename(from, to)
	checkArg(1, from, "string")
	checkArg(2, to, "string")
	local ltr_a = current
	local ltr_b = current
	if string.sub(from, 2, 2) == ":" then
		ltr_a = string.sub(from, 1, 1)
		from = string.sub(from, 3)
	end
	if string.sub(to, 2, 2) == ":" then
		ltr_b = string.sub(to, 1, 1)
		to = string.sub(to, 3)
	end
	--copy
	local handle, reason = filesystem.open(ltr_a..":"..from)
	assert(handle, reason)
	local buffer = ""
	repeat
		local data, reason = filesystem.read(handle, math.huge, ltr_a)
		assert(data or not reason, reason)
		buffer = buffer..(data or "")
	until not data
	filesystem.close(handle, ltr_a)
	filesystem.remove(ltr_a..":"..from)

	--paste
	handle, reason = filesystem.open(ltr_b..":"..to, "w")
	assert(handle, reason)
	filesystem.write(handle, buffer, ltr_b)
	filesystem.close(handle, ltr_b)

	--return hard_drives[current].proxy.rename(...)
end

function filesystem.list(path)
	checkArg(1, path, "string")
	if string.sub(path, 2, 2) ~= ":" then
		return hard_drives[current].proxy.list(path)
	else
		if hard_drives[string.sub(path, 1, 1)] then
			return hard_drives[string.sub(path, 1, 1)].proxy.list(string.sub(path, 3))
		end
	end
end

function filesystem.lastModified(path)
	checkArg(1, path, "string")
	if string.sub(path, 2, 2) ~= ":" then
		return hard_drives[current].proxy.lastModified(path)
	else
		if hard_drives[string.sub(path, 1, 1)] then
			return hard_drives[string.sub(path, 1, 1)].proxy.lastModified(string.sub(path, 3))
		end
	end
end

function filesystem.getLabel(letter)
	if type(letter) ~= "string" then
		return hard_drives[current].proxy.getLabel()
	else
		return hard_drives[letter].proxy.getLabel()
	end
end

function filesystem.remove(path)
	checkArg(1, path, "string")
	if string.sub(path, 2, 2) ~= ":" then
		return hard_drives[current].proxy.remove(path)
	else
		if hard_drives[string.sub(path, 1, 1)] then
			return hard_drives[string.sub(path, 1, 1)].proxy.remove(string.sub(path, 3))
		end
	end
end

function filesystem.close(handle, letter)
	checkArg(1, handle, "table")
	if type(letter) ~= "string" then
		return hard_drives[current].proxy.close(handle)
	else
		if hard_drives[letter] then
			return hard_drives[letter].proxy.close(handle)
		end
	end
end

function filesystem.size(path)
	checkArg(1, path, "string")
	if string.sub(path, 2, 2) ~= ":" then
		return hard_drives[current].proxy.size(path)
	else
		if hard_drives[string.sub(path, 1, 1)] then
			return hard_drives[string.sub(path, 1, 1)].proxy.size(string.sub(path, 3))
		end
	end
end

function filesystem.read(handle, count, letter)
	checkArg(1, handle, "table")
	checkArg(2, count, "number")
	if type(letter) ~= "string" then
		return hard_drives[current].proxy.read(handle, count)
	else
		if hard_drives[letter] then
			return hard_drives[letter].proxy.read(handle, count)
		end
	end
end

function filesystem.setLabel(label, letter)
	checkArg(1, label, "string")
	if type(letter) ~= "string" then
		return hard_drives[current].proxy.setLabel(label)
	else
		if hard_drives[letter] then
			return hard_drives[letter].proxy.setLabel(label)
		end
	end
end

return filesystem

