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
		fontsize3 = 10,

		texcoords = { 0.1, 0.9, 0.1, 0.9 },

		colours = {
			power = {
				[0]  = { 46 / 255, 158 / 255, 255 / 255 }, -- MANA
				[1]  = { 199 / 255, 64 / 255, 64 / 255 }, -- RAGE
				[2]  = { 255 / 255, 128 / 255, 64 / 255 }, -- FOCUS
				[3]  = { 255 / 255, 249 / 255, 105 / 255 }, -- ENERGY
				[6]  = { 0 / 255, 204 / 255, 255 / 255 }, -- RUNIC_POWER
				[8]  = { 77 / 255, 133 / 255, 230 / 255 }, -- LUNAR_POWER
				[11] = { 0, 128 / 255, 255 / 255 }, -- MAELSTROM
				[13] = { 102 / 255, 0, 204 / 255 }, -- INSANITY
				[17] = { 201 / 255, 66 / 255, 252 / 255 }, -- FURY
				[18] = { 255 / 255, 156 / 255, 0 }, -- PAIN
			},
			reaction = {
				[2] = { 255 / 255, 0, 0 }, -- Hostile
				[4] = { 255 / 255, 255 / 255, 0 }, -- Neutral
				[5] = { 0 / 255, 255 / 255, 0 }, -- Friendly
			}
		}
	},

	infobar = {
		xp = {
			enable = true,
			altxp = "reputation"
		}
	},

	-- Unit Frame settings
	frames = {
		-- Display or hide frames
		showBoss = true, -- Boss frames
		-- Dimension of frames, large applies to player/target, small everything else
		-- don't change these, change the scale
		largeWidth = 280,
		smallWidth = 140,
		-- Player and Target are positioned relative to center of screen,
		-- all other frames are positioned relative to those
		playerXoffset = -430,
		playerYoffset = -205,
		targetXoffset = 430,
		targetYoffset = -205,
		totXoffset = 30,   -- Relative to right of target
		totYoffset = 0,
		focusXoffset = 0,  -- Relative to left of target
		focusYoffset = -150,
		focusTargetXoffset = 30, -- Relative to right of focus target
		focusTargetYoffset = 0,
		petXoffset = 0,    --62, 	-- Relative to left of player
		petYoffset = -150, ---100,
		bossXoffset = 0,   -- Relative to left of target
		bossYoffset = 200,
		arenaXoffset = 0,  -- Relative to left of target
		arenaYoffset = 300,
		-- Aura settings
		auras = {
			-- Large are debuffs on players, buffs on targets, Sml are buffs on player,
			-- debuffs on target and tiny are buffs/debuffs on other units
			auraHge = 26,
			auraLrg = 22,
			auraSml = 20,
			auraTny = 18,
			maxPlayerBuff = 7,
			maxPlayerDebuff = 5,
			maxPetBuff = 2,
			maxPetDebuff = 2,
			maxTargetBuff = 7,
			maxTargetDebuff = 5,
			maxFocusBuff = 5,
			maxFocusDebuff = 3,
			maxFocusTargetBuff = 3,
			maxOtherBuff = 2,
			maxOtherDebuff = 2,
			maxBossBuff = 2,
			buffs_per_row = {
				["player"] = 4,
				["target"] = 4,
				["focus"] = 3,
				["focustarget"] = 3,
				["boss"] = 3,
				["other"] = 3 -- focus, focus target, pet, etc.
			},
			debuffs_per_row = {
				["player"] = 3,
				["target"] = 3,
				["focus"] = 3,
				["other"] = 3
			},
			showBuffsOnMe = true, -- Short term buffs on myself or my pet
			showDebuffsOnMe = true, -- Debuffs on myself or pet
			showBuffsOnFriends = true, -- Buffs on friends (excluding 0 duration auras)
			showDebuffsOnFriends = true,
			showBuffsOnEnemies = true,
			showDebuffsOnEnemies = false,
		}
	},
}
