--[[


--]]
local DraeUI = select(2, ...)

-- Localise a bunch of functions
local _G = _G
local pairs, format, match, gupper, gsub, type, unpack =
	pairs, string.format, string.match, string.upper, string.gsub, type, unpack
local mmax, mmin, mfloor, mceil, mabs = math.max, math.min, math.floor, math.ceil, math.abs
local UIParent, CreateFrame = UIParent, CreateFrame

--[[
	Font functions
--]]

-- Create and set font
DraeUI.CreateFontObject = function(parent, size, font, anchorAt, oX, oY, type, anchor, anchorTo)
	local fo
	if parent:IsObjectType("EditBox") or parent:IsObjectType("FontString") then
		fo = parent
	else
		fo = parent:CreateFontString(nil, "OVERLAY")
	end

	fo:SetFont(font, size, type or "THINOUTLINE")

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
	Math functions
--]]

-- Reduce to nearest kilo value, e.g. 1,200,00 becomes 1.2M, 1450 becomes 1.45K
DraeUI.ShortVal = function(value)
	if mabs(value) >= 1e6 then
		return ("%.2fM"):format(value / 1e6):gsub("%.?0+([km])$", "%1")
	elseif mabs(value) >= 1e3 or value <= -1e3 then
		return ("%.1fK"):format(value / 1e3):gsub("%.?0+([km])$", "%1")
	else
		return value
	end
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

	return ("|c%02x%02x%02x%02x"):format((a or 1) * 255, r * 255, g * 255, b * 255)
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

	local segment, relperc = math.modf(perc * (num - 1))
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
						sub_print_r(val, indent .. string.rep(" ", string.len(pos) + 8))
						print(indent .. string.rep(" ", string.len(pos) + 6) .. "}")
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
