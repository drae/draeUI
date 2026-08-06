--[[


--]]
local DraeUI = select(2, ...)

local LSM = LibStub("LibSharedMedia-3.0")

-- Localise a bunch of functions
local pairs, type, unpack, select, pcall = pairs, type, unpack, select, pcall
local format, srep, slen = string.format, string.rep, string.len
local mmodf = math.modf

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
	if type(key) ~= "string" or key == "" then
		return fallback
	end

	if key:find("\\") or key:find("/") then
		return key
	end

	local ok, path = pcall(LSM.Fetch, LSM, class, key, true)

	if ok and type(path) == "string" and path ~= "" then
		return path
	end

	return fallback
end

--[[
	Font functions
--]]

do
	local FALLBACK_FONT = "Fonts\\FRIZQT__.TTF"

	--[[
		Adapted from the Presence module's SetSafeFont, which is where the pattern
		came from.
	--]]
	DraeUI.SetFont = function(fontString, font, size, flags)
		if not fontString then
			return false
		end

		flags = flags or "OUTLINE"

		if font and fontString:SetFont(font, size, flags) then
			return true
		end

		local fallback = DraeUI.media and DraeUI.media.font

		if fallback and fallback ~= font and fontString:SetFont(fallback, size, flags) then
			return true
		end

		return fontString:SetFont(FALLBACK_FONT, size, flags)
	end
end

--[[
	Create a positioned font string.

	Everything is optional - font defaults to the UI font and size to fontsize1,
	which is what most callers want, so the common case is just a point and an
	offset.

		DraeUI.CreateFontObject(parent, { point = "RIGHT", x = -5, y = 0 })

	Anchor to something other than the parent by naming it:

		DraeUI.CreateFontObject(parent, {
			point = "CENTER", relTo = frame.Health, relPoint = "TOP", y = 4,
		})

	justify follows point unless you say otherwise, and width/height save the
	SetSize call that used to follow most of these.
--]]
DraeUI.CreateFontObject = function(parent, opts)
	opts = opts or {}

	local point = opts.point or "LEFT"
	local font = opts.font or (DraeUI.media and DraeUI.media.font)
	local size = opts.size or DraeUI.config["general"].fontsize1

	local fo = parent:CreateFontString(nil, opts.layer or "OVERLAY")

	DraeUI.SetFont(fo, font, size, opts.flags)

	fo:SetJustifyH(opts.justify or point)

	if opts.relTo then
		fo:SetPoint(point, opts.relTo, opts.relPoint or point, opts.x or 0, opts.y or 0)
	else
		fo:SetPoint(point, opts.x or 0, opts.y or 0)
	end

	if opts.width or opts.height then
		fo:SetSize(opts.width or 0, opts.height or 0)
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

-- Smooth colour gradient between two r, g, b value
DraeUI.ColorGradient = function(perc, ...)
	if perc > 1 then
		local r, g, b = select(select("#", ...) - 2, ...)
		return r, g, b
	elseif perc < 0 then
		local r, g, b = ...
		return r, g, b
	end

	local num = select("#", ...) / 3

	local segment, relperc = mmodf(perc * (num - 1))
	local r1, g1, b1, r2, g2, b2 = select((segment * 3) + 1, ...)

	return r1 + (r2 - r1) * relperc, g1 + (g2 - g1) * relperc, b1 + (b2 - b1) * relperc
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
