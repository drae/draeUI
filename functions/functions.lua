--[[


--]]
local DraeUI = select(2, ...)

local LSM = LibStub("LibSharedMedia-3.0")

-- Localise a bunch of functions
local pairs, type, unpack, select, pcall = pairs, type, unpack, select, pcall
local format, srep, slen = string.format, string.rep, string.len

--[[
	Media functions
--]]

--[[
	Resolve a config value to a usable path.

	Config normally holds LibSharedMedia keys ("Proza"), but a value that already
	contains a slash is taken as a literal path and passed straight through, so a
	font or texture that was never registered with LSM can still be pointed at.
	The fallback covers an LSM key that doesn't resolve - typically media that got
	commented out of media/sharedmedia.lua.
--]]
DraeUI.FetchMedia = function(class, key, fallback)
	if (type(key) ~= "string" or key == "") then
		return fallback
	end

	if (key:find("\\") or key:find("/")) then
		return key
	end

	local ok, path = pcall(LSM.Fetch, LSM, class, key, true)

	if (ok and type(path) == "string" and path ~= "") then
		return path
	end

	return fallback
end

--[[

--]]
DraeUI.CanAccessValue = function(v)
	-- In Midnight/Retail, even comparing a secret value to nil can error.
	-- Wrap the nil check in pcall so nil stays "safe" without tripping secret comparisons.
	local okNil, isNil = pcall(function()
		return v == nil
	end)

	-- If it's actually nil, treat it as NOT accessible.
	if okNil and isNil then
		return false
	end

	if (canaccessvalue) then
		local ok, res = pcall(canaccessvalue, v)
		return ok and res or false
	end

	if (issecretvalue) then
		local ok, res = pcall(issecretvalue, v)
		return ok and (not res) or false
	end

	-- If we can safely compare to nil, it's not a secret value.
	return okNil and (not isNil)
end



--[[
	Font functions
--]]

-- Create and set font
DraeUI.CreateFontObject = function(parent, size, font, anchorAt, oX, oY, type, anchor, anchorTo)
	local fo = parent:CreateFontString(nil, "OVERLAY")
	fo:SetFont(font, size, type or "OUTLINE")

	if anchor then
		fo:SetPoint(anchorAt, anchor, anchorTo, oX, oY)
	else
		fo:SetJustifyH(anchorAt or "LEFT")

		if oX or oY then
			fo:SetPoint(anchorAt or "LEFT", oX or 0, oY or 0)
		end
	end

	return fo
end

--[[
	String functions
--]]

-- UTF-8 encoding
DraeUI.UTF8 = function(str, i, dots)
	if not str then
		return ""
	end
	local bytes = str:len()
	if bytes <= i then
		return str
	end

	local len, pos = 0, 1
	while pos <= bytes and len < i do
		len = len + 1
		local c = str:byte(pos)
		pos = pos + (c < 128 and 1 or c < 224 and 2 or c < 240 and 3 or 4)
	end

	return str:sub(1, pos - 1) .. (dots and "..." or "")
end

-- Output an rgb hex string
DraeUI.Hex = function(r, g, b, a)
	if type(r) == "table" then
		if r.r then
			r, g, b = r.r, r.g, r.b
		else
			r, g, b = unpack(r)
		end
	end

	return format("|c%02x%02x%02x%02x", (a or 1) * 255, r * 255, g * 255, b * 255)
end

--[[
	Print/Output
--]]

-- Print to ChatFrame1
DraeUI.Print = function(...)
	print("|cff33ff99DraeUI:|r ", ...)
end

DraeUI.Debug = function(t)
	local print_r_cache = {}

	local function sub_print_r(tbl, indent)
		if print_r_cache[tostring(tbl)] then
			print(indent .. "*" .. tostring(tbl))
		else
			print_r_cache[tostring(tbl)] = true

			if type(tbl) == "table" then
				for pos, val in pairs(tbl) do
					if type(val) == "table" then
						print(indent .. "[" .. pos .. "] => " .. tostring(val) .. " {")
						sub_print_r(val, indent .. srep(" ", slen(pos) + 8))
						print(indent .. srep(" ", slen(pos) + 6) .. "}")
					elseif type(val) == "string" then
						print(indent .. "[" .. pos .. '] => "' .. val .. '"')
					else
						print(indent .. "[" .. pos .. "] => " .. tostring(val))
					end
				end
			else
				print(indent .. tostring(tbl))
			end
		end
	end

	if type(t) == "table" then
		print(tostring(t) .. " {")
		sub_print_r(t, "  ")
		print("}")
	else
		sub_print_r(t, "  ")
	end

	print()
end
