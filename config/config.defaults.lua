--[[


--]]
local DraeUI = select(2, ...)

--[[
		Default configuration settings
--]]
DraeUI.config = {
	general = {
		-- Textures
		statusbar = "Striped",
		statusbar_power = "Striped",
		statusbar_raid = "Striped",
		statusbar_raid_power = "Striped",
		statusbar_absorb = "DF Stripes Soft",

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

	-- Used by UF.CreateMirrorCastbars to size the breath/feign death bars
	castbar = {
		player = {
			width = 450,
			height = 20,
		}
	},

	-- Unit Frame settings
	frames = {
		-- Display or hide frames
		showBoss = true, -- Boss frames
		hideArena = true, -- Suppress Blizzard's arena enemy/prep frames
		-- Dimension of frames, large applies to player/target, small everything else
		-- don't change these, change the scale
		playerWidth = 240,
		playerHeight = 20,
		targetWidth = 450,
		targetHeight = 20,
		-- Player and Target are positioned relative to center of screen,
		-- all other frames are positioned relative to those
		playerXoffset = 0,
		playerYoffset = -320,
		targetXoffset = 0,
		targetYoffset = 480,
		totXoffset = 30,   -- Relative to right of target
		totYoffset = 0,
		focusXoffset = 50, -- Relative to left of target
		focusYoffset = 0,
		focusTargetXoffset = 30, -- Relative to right of focus target
		focusTargetYoffset = 0,
		petXoffset = -50,  --62, 	-- Relative to left of player
		petYoffset = 0,    ---100,
		bossXoffset = 0,   -- Relative to left of target
		bossYoffset = 200,
		-- Aura settings
		auras = {
			-- Large are debuffs on players, buffs on targets, Sml are buffs on player,
			-- debuffs on target and tiny are buffs/debuffs on other units
			auraHge = 32,
			auraLrg = 22,
			auraSml = 20,
			auraTny = 18,
			maxPlayerBuff = 7,
			maxPlayerDebuff = 4,
			maxPetBuff = 2,
			maxPetDebuff = 2,
			maxTargetBuff = 8,
			maxTargetDebuff = 8,
			maxFocusBuff = 5,
			maxFocusDebuff = 3,
			maxFocusTargetBuff = 3,
			maxOtherBuff = 2,
			maxOtherDebuff = 2,
			maxBossBuff = 2,
			buffs_per_row = {
				["player"] = 4,
				["target"] = 5,
				["focus"] = 3,
				["focustarget"] = 3,
				["boss"] = 3,
				["other"] = 3 -- focus, focus target, pet, etc.
			},
			debuffs_per_row = {
				["player"] = 4,
				["target"] = 5,
				["focus"] = 3,
				["other"] = 3
			},
			showBuffsOnPlayer = false, -- Short term buffs on myself or my pet
			showDebuffsOnPlayer = true, -- Debuffs on myself or pet
			showBuffsOnTarget = true,
			showDebuffsOnTarget = false,
		}
	},
}
