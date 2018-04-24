--[[
		package library

	Handle library loading, prevent libraries from being loaded
	multiple times
]]

local package = {}
package.loaded = {}
package.loaded["component"] = component
package.loaded["computer"] = computer
package.loaded["unicode"] = unicode
_G.component = nil
_G.computer = nil
_G.unicode = nil
package.searchPath = "C:/mc_dos/libraries;C:/mc_dos/libraries/core;/lib"

function package.unload(name)
	checkArg(1, name, "string")
	package.loaded[name] = nil
end

local function split(str, sep)
	if sep == nil then
		sep = "%s"
	end
	local t = {}; i=1
	for str in string.gmatch(str, "([^"..sep.."]+)") do
		t[i] = str
		i = i+1
	end
	return t
end

function _G.require(path)
	local rpath = path
	local ltr = filesystem.getLetter()
	if string.sub(rpath, 2, 2) == ":" then
		ltr = string.sub(rpath, 1, 1)
		rpath = string.sub(rpath, 3)
	end
	local parts = split(rpath, "/")
	local parents = split(package.searchPath, ";")

	if not package.loaded[parts[#parts]] then
		--Search library in every path or in the path given
		local lib, err = nil, "file not found"
		if string.sub(rpath, 1, 1) == "/" or ltr ~= filesystem.getLetter() then
			lib, err = loadfile(ltr..":"..rpath)
		else
			if string.sub(rpath, 1, 1) ~= "/" then rpath = "/"..rpath end
			for each, parent in ipairs(parents) do
				if filesystem.exists(parent..rpath) then
					lib, err = loadfile(parent..rpath)
				end
			end
		end
		assert(lib, err)
		
		local success, data = pcall(lib)
		assert(success, data)
		--Last item in parts should be just the filename (so no parent directory)
		package.loaded[parts[#parts]] = data
		return data
	else
		return package.loaded[parts[#parts]]
	end
end

_G.package = package

