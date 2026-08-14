--[[
		Skinning and texturing.

		Two things live here. The module itself lays down the static artwork
		overlaid on the default UI - the actionbar surround and the micro menu -
		which aren't unit frames, they just used to live in the UnitFrames module.

		The rest of the file is the addon's shared skinning helpers, exported onto
		the namespace so call sites stay short: CreateBorder, which is the
		hand-rolled nine-slice the unit frames and the minimap both frame
		themselves with, and CreateOverlay, which anchors a decorative texture to
		a parent. Anything else that decorates a frame belongs here too rather
		than being hand-rolled at a third call site.

		This file loads before the minimap and unit frame modules, which is what
		makes those exports safe to call.
--]]
local DraeUI = select(2, ...)

local Skins = DraeUI:NewModule("Skins")

--
local CreateFrame = CreateFrame
local type, setmetatable, ipairs = type, setmetatable, ipairs

local TEXTURE_PATH = "Interface\\AddOns\\draeUI\\media\\textures\\"

--[[
		Anchor a decorative texture to a parent frame
--]]
DraeUI.CreateOverlay = function(parent, width, height, layer, texture, point, x, y)
	if not parent then
		return
	end

	local frame = CreateFrame("Frame", nil, parent)
	frame:SetSize(width, height)
	frame:SetPoint(point, x, y)

	local tex = frame:CreateTexture(nil, layer)
	tex:SetTexture(TEXTURE_PATH .. texture)
	tex:SetAllPoints(frame)

	return frame
end

--[[
		The flat backing behind a small square button or a text band.

		Hand-rolled from one texture rather than a backdrop, the same way the
		infobar draws its statusbar backgrounds - BackdropTemplate drags in a
		whole mixin to do what SetColorTexture does in a line.

		The colour is read at call time rather than captured, because callers run
		at OnEnable and general.colours is the single place any colour lives.
--]]
DraeUI.CreateBackdrop = function(frame, layer)
	local colour = DraeUI.config["general"].colours.panel

	local bg = frame:CreateTexture(nil, layer or "BACKGROUND")
	bg:SetAllPoints(frame)
	bg:SetColorTexture(colour[1], colour[2], colour[3], colour[4] or 1)

	return bg
end

--[[
		A flat single-colour edge, for a frame too small to carry CreateBorder's
		nine-slice art - a meter's bar rows, an aura icon.

		`size` is the edge thickness and `inset` how far it sits outside the frame
		rect, both defaulting to 1. `colour` is { r, g, b, a }, defaulting to
		colours.rowOutline.

		A BackdropTemplate frame rather than four textures, so edgeSize tracks a
		frame that resizes.
--]]
DraeUI.CreateOutline = function(frame, size, colour, inset)
	if not frame then
		return
	end

	size = size or 1
	inset = inset or 1
	colour = colour or DraeUI.config["general"].colours.rowOutline

	local border = CreateFrame("Frame", nil, frame, "BackdropTemplate")
	border:SetPoint("TOPLEFT", frame, -inset, inset)
	border:SetPoint("BOTTOMRIGHT", frame, inset, -inset)
	border:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", tile = false, edgeSize = size })
	border:SetBackdropBorderColor(colour[1], colour[2], colour[3], colour[4] or 1)

	return border
end

--[[
		A hand-rolled nine-slice from one 64x64 sheet quartered into a 4x4 grid:
		four corners pinned at their own texcoord quadrants, four edges taken from
		the 1/4..3/4 bands and double-anchored between the corners so they stretch
		to whatever the frame is without the corners distorting.

		`size` is the pixel thickness of the framing art. A corner is size x size
		anchored at -4 - x where x = size / 2 - 5, so the art extends size/2 - 1 px
		outside the frame rect and size/2 + 1 px inside it. 14 is what every unit
		frame uses.

		`omit` optionally leaves one side off - "LEFT", "RIGHT", "TOP" or
		"BOTTOM" - for a frame butted up against something that already has a
		border. The minimap's button columns use it so the map's own edging forms
		their inner side and they read as hanging off the map rather than
		floating beside it.

		There used to be a second "shadow" pass here building another 8 textures per
		border at SetVertexColor(0, 0, 0, 0). Nothing ever changed their alpha, so
		they were submitted for rendering while being completely invisible - and
		every frame borders its Health, its Power and a wrapper, so that was ~24
		wasted textures per unit frame. If the shadow is wanted back, give it a real
		colour rather than a zero alpha.
--]]
do
	--[[
			Which frames already have one. A weak-keyed table rather than a field on
			the frame itself: this is called on Blizzard's Minimap as well as on
			oUF's frames, and writing an addon field onto a Blizzard frame table is
			how you taint it for nothing. Nothing outside this guard ever read the
			`borderTexture` field this replaced.
	--]]
	local bordered = setmetatable({}, { __mode = "k" })

	--[[
			Which of the eight pieces go when a side is omitted, and which of the
			survivors have to stretch to cover for them.

			The two perpendicular edges each stop `size` short of the corner they
			were anchored to, so dropping a corner without re-anchoring them
			leaves a notch. Re-pointing them at the border's own corner closes it
			- SetPoint replaces a point of the same name, so this overrides the
			original anchor rather than adding to it.
	--]]
	-- stylua: ignore start
	local OMIT = {
		LEFT   = { hide = { 1, 4, 7 }, extend = { { 3, "TOPLEFT"     }, { 6, "BOTTOMLEFT"  } } },
		RIGHT  = { hide = { 2, 5, 8 }, extend = { { 3, "TOPRIGHT"    }, { 6, "BOTTOMRIGHT" } } },
		TOP    = { hide = { 1, 2, 3 }, extend = { { 7, "TOPLEFT"     }, { 8, "TOPRIGHT"    } } },
		BOTTOM = { hide = { 4, 5, 6 }, extend = { { 7, "BOTTOMLEFT"  }, { 8, "BOTTOMRIGHT" } } },
	}
	-- stylua: ignore end

	DraeUI.CreateBorder = function(frame, size, omit)
		if not frame or type(frame) ~= "table" or bordered[frame] then
			return
		end

		size = size or 14
		bordered[frame] = true

		local tex = {}

		local border = CreateFrame("Frame", nil, frame)
		border:SetAllPoints(frame)

		-- creating the textures
		for i = 1, 8 do
			tex[i] = border:CreateTexture(nil, "BORDER", nil, 5)
			tex[i]:SetTexture(TEXTURE_PATH .. "unitframe")

			local width = (i == 3 or i == 6) and size * 2 or size
			local height = (i == 7 or i == 8) and size * 2 or size
			tex[i]:SetSize(width, height)
		end

		local x = size / 2 - 5

		tex[1].id = "TOPLEFT"
		tex[1]:SetTexCoord(0, 1 / 4, 0, 1 / 4)
		tex[1]:SetPoint("TOPLEFT", border, -4 - x, 4 + x)

		tex[2].id = "TOPRIGHT"
		tex[2]:SetTexCoord(3 / 4, 1, 0, 1 / 4)
		tex[2]:SetPoint("TOPRIGHT", border, 4 + x, 4 + x)

		tex[4].id = "BOTTOMLEFT"
		tex[4]:SetTexCoord(0, 1 / 4, 3 / 4, 1)
		tex[4]:SetPoint("BOTTOMLEFT", border, -4 - x, -4 - x)

		tex[5].id = "BOTTOMRIGHT"
		tex[5]:SetTexCoord(3 / 4, 1, 3 / 4, 1)
		tex[5]:SetPoint("BOTTOMRIGHT", border, 4 + x, -4 - x)

		-- width = 2 * normal width
		tex[3].id = "TOP"
		tex[3]:SetTexCoord(1 / 4, 3 / 4, 0, 1 / 4)
		tex[3]:SetPoint("TOPLEFT", tex[1], "TOPRIGHT")
		tex[3]:SetPoint("TOPRIGHT", tex[2], "TOPLEFT")

		-- width = 2 * normal width
		tex[6].id = "BOTTOM"
		tex[6]:SetTexCoord(1 / 4, 3 / 4, 3 / 4, 1)
		tex[6]:SetPoint("BOTTOMLEFT", tex[4], "BOTTOMRIGHT")
		tex[6]:SetPoint("BOTTOMRIGHT", tex[5], "BOTTOMLEFT")

		tex[7].id = "LEFT"
		tex[7]:SetTexCoord(0, 1 / 4, 1 / 4, 3 / 4)
		tex[7]:SetPoint("TOPLEFT", tex[1], "BOTTOMLEFT")
		tex[7]:SetPoint("BOTTOMLEFT", tex[4], "TOPLEFT")

		-- height = 2 * normal height
		tex[8].id = "RIGHT"
		tex[8]:SetTexCoord(3 / 4, 1, 1 / 4, 3 / 4)
		tex[8]:SetPoint("TOPRIGHT", tex[2], "BOTTOMRIGHT")
		tex[8]:SetPoint("BOTTOMRIGHT", tex[5], "TOPRIGHT")

		local open = omit and OMIT[omit]

		if open then
			for _, i in ipairs(open.hide) do
				tex[i]:Hide()
			end

			for _, entry in ipairs(open.extend) do
				tex[entry[1]]:SetPoint(entry[2], border, entry[2])
			end
		end

		return border
	end
end

Skins.OnEnable = function(self)
	DraeUI.CreateOverlay(UIParent, 800, 64, "BACKGROUND", "ActionBar.tga", "CENTER", 0, -455)

	-- Guarded: the micro button bar has been reshuffled repeatedly across
	-- expansions, so don't assume the anchor exists
	DraeUI.CreateOverlay(CharacterMicroButton, 64, 512, "BACKGROUND", "MicroMenu.tga", "CENTER", 11, -203)
end
