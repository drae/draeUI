-- A Masque skin, so button addons can wear draeUI's border. draeUI.toc must keep
-- Masque in OptionalDeps - without it draeUI loads first and this returns nil.
local DraeUI = select(2, ...)

local Masque = LibStub("Masque", true)
if not Masque then
	return
end

local TEXTURE_PATH = "Interface\\AddOns\\draeUI\\media\\textures\\"

-- Masque 12.0.8's API version. Metadata only, nothing gates on it.
local API_VERSION = 110210

-- unitframe.tga is a closed ring with a transparent middle, so the whole texture
-- is the border; CreateBorder's nine-slice carve only exists to stretch the edges
-- on non-square frames. Sized against Masque's 36px reference and rescaled per
-- group, so one number fits Dominos and the Cooldown Manager alike.
local BORDER_SIZE = 46

Masque:AddSkin("draeUI", {
	API_VERSION = API_VERSION,
	Shape = "Square",

	Authors = { "Drae" },
	Description = "draeUI's unit frame border.",
	Version = "1.0",

	Icon = {
		TexCoords = DraeUI.config["general"].texcoords,
	},

	-- Normal replaces Blizzard's NormalTexture, so this also strips the slot art.
	-- No UseStates - the border must not track button state.
	Normal = {
		Texture = TEXTURE_PATH .. "unitframe",
		Width = BORDER_SIZE,
		Height = BORDER_SIZE,
	},

	FloatingBG = {
		Hide = true,
	},
	Shadow = {
		Hide = true,
	},
})
