--[[


--]]
local DraeUI = select(2, ...)

--[[
		Default configuration settings
--]]
DraeUI.config = {
	general = {
		-- Textures
		statusbar = "Gradient1",
		statusbar_power = "Gradient1",
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
			--[[
				Everything here is applied onto oUF.colors by DraeUI:OnEnable,
				or read directly at the point of use. They are partial
				overrides - any key left out keeps oUF's Blizzard-derived
				default.

				Keyed by oUF's own key names. Power uses the string token
				because that's oUF's canonical key; it aliases the numeric
				power-type IDs to the same colour objects, so overriding the
				token updates both.

				Deliberately absent: `class`. oUF rebuilds colors.class from a
				CUSTOM_CLASS_COLORS callback with fresh objects, which would
				throw any override away - class colours must stay oUF's.
			--]]
			power = {
				MANA        = { 46 / 255, 158 / 255, 255 / 255 },
				RAGE        = { 199 / 255, 64 / 255, 64 / 255 },
				FOCUS       = { 255 / 255, 128 / 255, 64 / 255 },
				ENERGY      = { 255 / 255, 249 / 255, 105 / 255 },
				RUNIC_POWER = { 0 / 255, 204 / 255, 255 / 255 },
				LUNAR_POWER = { 77 / 255, 133 / 255, 230 / 255 },
				MAELSTROM   = { 0, 128 / 255, 255 / 255 },
				INSANITY    = { 102 / 255, 0, 204 / 255 },
				FURY        = { 201 / 255, 66 / 255, 252 / 255 },
				PAIN        = { 255 / 255, 156 / 255, 0 },
				ALTERNATE   = { 51 / 255, 102 / 255, 204 / 255 },
			},

			-- FACTION_BAR_COLORS indices; 1/3/6/7/8 keep Blizzard's
			reaction = {
				[2] = { 255 / 255, 0, 0 }, -- Hostile
				[4] = { 255 / 255, 255 / 255, 0 }, -- Neutral
				[5] = { 0 / 255, 255 / 255, 0 }, -- Friendly
			},

			disconnected = { 230 / 255, 230 / 255, 230 / 255 },
			tapped = { 153 / 255, 153 / 255, 153 / 255 },

			--[[
				Aura border tint per dispel type, keyed by oUF.Enum.DispelType
				name. Bleed and Enrage are left out and keep oUF's defaults.

				None has to be listed: oUF evaluates a step curve, so an aura
				with no dispel type resolves to the None colour rather than
				nil, and Blizzard's DEBUFF_TYPE_NONE_COLOR is a dark red that
				would tint every ordinary debuff border.
			--]]
			dispel = {
				None = { 0, 0, 0 },
				Magic = { 51 / 255, 153 / 255, 255 / 255 },
				Curse = { 153 / 255, 0, 255 / 255 },
				Disease = { 153 / 255, 102 / 255, 0 },
				Poison = { 0, 153 / 255, 0 },
			},

			-- Aura icon border when the aura has no dispel type
			auraBorder = { 0, 0, 0 },

			castbar = {
				casting = { 0.3, 0.3, 1.0 },
				channeling = { 1.0, 0.3, 0.3 },
				safezone = { 1.0, 0, 0, 0.75 },
			},

			healthPrediction = {
				healingPlayer = { 0, 1.0, 0.3, 0.25 },
				healingOther = { 0, 1.0, 0, 0.25 },
				damageAbsorb = { 1.0, 1.0, 1.0, 0.33 },
				healAbsorb = { 1.0, 0, 0.8, 0.33 },
				overAbsorb = { 1, 1, 1, 0.5 },
				overHealAbsorb = { 1.0, 0, 0, 0.5 },
			},

			-- Offline/ghost/dead health text
			healthText = { 170 / 255, 170 / 255, 170 / 255 },
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
