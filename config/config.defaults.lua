--[[


--]]
local DraeUI = select(2, ...)

--[[
		Default configuration settings
--]]
DraeUI.config = {
	general = {
		-- Textures
		statusbar = "striped",
		statusbar_power = "striped",
		statusbar_raid = "striped",
		statusbar_raid_power = "striped",

		font = "Proza",
		fontSmall = "LiberationSans",
		fontTitles = "Vollkorn",

		fontsize0 = 16,
		fontsize1 = 14,
		fontsize2 = 12,
		fontsize3 = 11,

		texcoords = { 0.1, 0.9, 0.1, 0.9 },
	},

	infobar = {
		xp = {
			enable = true,
			altxp = "reputation",
		},
	},
}
