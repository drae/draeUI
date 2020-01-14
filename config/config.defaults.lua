--[[


--]]
local T, C, G, P, U, _ = select(2, ...):UnPack()

--[[
		Default configuration settings

		Try not to change settings in this file, instead create
		a new file in this folder called config.lua. Then copy
		the section/s containing the variables you want to alter
		into that new file. You don't need to copy the entire
		section just the variable/s you want to change.
--]]
C["general"] = {
	-- Textures
	statusbar = "Striped",
	font = "Liberation Sans",
	fontFancy = "Proza",
	fontsize0 = 16,
	fontsize1 = 13,
	fontsize2 = 12,
	fontsize3 = 10,
	fontsize4 = 9
}

-- Unit Frame settings
C["frames"] = {
	numFormatLong = false,
	-- Display or hide frames
	showBoss = true, -- Boss frames
	showArena = true,
	-- Player and Target are positioned relative to center of screen,
	-- all other frames are positioned relative to those
	playerXoffset = -450,
	playerYoffset = -120,
	targetXoffset = 450,
	targetYoffset = -120,
	totXoffset = 25, -- Relative to right of target
	totYoffset = 0,
	focusXoffset = 6, -- Relative to left of target
	focusYoffset = 75,
	focusTargetXoffset = 25, -- Relative to right of focus target
	focusTargetYoffset = 0,
	petXoffset = -6, --62, 	-- Relative to left of player
	petYoffset = 30, ---100,
	petTargetXoffset = 6, -- Relative to right of pet
	petTargetYoffset = -10,
	bossXoffset = 0, -- Relative to left of target
	bossYoffset = 300,
	arenaXoffset = 0, -- Relative to left of player
	arenaYoffset = 140,
	largeScale = 1.0,
	mediumScale = 1.0,
	smallScale = 1.0,
	-- Dimension of frames, large applies to player/target, small everything else
	-- don't change these, change the scale
	largeWidth = 200,
	largeHeight = 20,
	mediumWidth = 140,
	mediumHeight = 20,
	smallWidth = 90,
	smallHeight = 20,
	-- Aura settings
	auras = {
		-- Large are debuffs on players, buffs on targets, Sml are buffs on player,
		-- debuffs on target and tiny are buffs/debuffs on other units
		auraHge = 28,
		auraLrg = 26,
		auraSml = 24,
		auraTny = 22,
		auraMag = 1.8, -- Multiplier for the magnified view of auras
		maxPlayerBuff = 10,
		maxPlayerDebuff = 4,
		maxPetBuff = 4,
		maxPetDebuff = 4,
		maxTargetBuff = 4,
		maxTargetDebuff = 10,
		maxFocusBuff = 4,
		maxFocusDebuff = 4,
		maxFocusTargetBuff = 10,
		maxOtherBuff = 2,
		maxOtherDebuff = 2,
		maxBossBuff = 1,
		maxArenaBuff = 4,
		buffs_per_row = {
			["player"] = 5,
			["target"] = 2,
			["focus"] = 2,
			["focustarget"] = 4,
			["boss"] = 2,
			["other"] = 2 -- focus, focus target, pet, etc.
		},
		debuffs_per_row = {
			["player"] = 2,
			["target"] = 5,
			["focus"] = 2,
			["other"] = 2
		},
		showBuffsOnMe = true, -- Short term buffs on myself or my pet
		showDebuffsOnMe = true, -- Debuffs on myself or pet
		showBuffsOnFriends = true, -- Buffs on friends (excluding 0 duration auras)
		showDebuffsOnFriends = true,
		showBuffsOnEnemies = true,
		showDebuffsOnEnemies = true,
		showStealableBuffs = true,
		-- These auras are never displayed regardless of any other settings
		blacklistAuraFilter = {
			["Chill of the Throne"] = true,
			["Strength of Wrynn"] = true
		},
		filterType = "WHITELIST", -- dictates which filter we"ll use
		-- If debuff filtering is enabled only the debuffs in the following list will appear on targets
		whiteListFilter = {
			["DEBUFF"] = {},
			["BUFF"] = {}
		},
		blackListFilter = {
			["DEBUFF"] = {},
			["BUFF"] = {}
		}
	}
}

C["raidframes"] = {
	-- General frame parameters
	width = 60,
	height = 35,
	gridLayout = "HORIZONTAL", -- groups are arranged horizontally - one above (or below) the other,
	-- VERTICAL would have groups appear to the right (or left) of each other
	gridGroupsAnchor = "BOTTOMLEFT", -- This is the anchor point for each group - groups will grow from this point
	padding = 2, -- Distance between frames - the highlight border is 3px, so keep it >3
	showPets = true, -- Pets will be shown as seperate units, vehicles will appear as pets if enabled
	colorSmooth = true,
	colorPet = false,
	colorCharmed = true,
	indicatorLrg = 8,
	indicatorSml = 5,
	-- X, Y position of frames - the 1, 2, 3, etc. tables
	-- Equates to the total number of groups in the raid (not each group!). If you do not
	-- specify a position for a total number of groups the position of the last highest
	-- will be used
	position = {
		[1] = {"BOTTOM", UIParent, "CENTER", 0, -415}, --275
		[6] = {"BOTTOM", UIParent, "CENTER", -850, -130}
	},
	-- Button parameters
	raidnamelength = 6,
	showRaidHealthPct = false, -- Show health as a "remaining percentage" rather than an "absolute deficit"
	showOnlyDispellable = false -- true to only show dispellable unknown debuffs
}

-- Player, target and focus castbar
C["castbar"] = {
	player = {
		width = 200,
		height = 8,
		xOffset = -6,
		yOffset = 40,
		anchor = "DraePlayer",
		anchorat = "RIGHT",
		anchorto = "RIGHT"
	},
	target = {
		width = 200,
		height = 8,
		xOffset = 7,
		yOffset = 40,
		anchor = "DraeTarget",
		anchorat = "LEFT",
		anchorto = "LEFT"
	},
	focus = {
		width = 150,
		height = 6,
		xOffset = 3,
		yOffset = 54,
		anchor = "DraeFocus",
		anchorat = "LEFT",
		anchorto = "LEFT"
	},
	boss = {
		width = 150,
		height = 6,
		xOffset = -12,
		yOffset = 0,
		anchorat = "RIGHT",
		anchorto = "LEFT"
	},
	arena = {
		width = 150,
		height = 6,
		xOffset = 0,
		yOffset = 12,
		anchorat = "LEFT",
		anchorto = "RIGHT"
	}
}

C["infobar"] = {
	xp = {
		enable = true,
		altxp = "reputation"
	}
}

--[[
		Global variables - for all chars
--]]
G["chat"] = {
	sticky = true,
	shortChannels = true,
	timeStampFormat = "%H:%M ",
	scrollDownInterval = 15,
	throttleInterval = 45
}

-- Minimap
G["minimap"] = {
	buttons = {
		["MiniMapTracking"] = {angle = 25}, -- The tracking button/menu
		["MiniMapMailFrame"] = {angle = 310}, -- New mail alert
		["QueueStatusMinimapButton"] = {angle = 212}, -- Dungeon Finder
		["GameTimeFrame"] = {angle = 50}, -- The Calendar
		["MiniMapInstanceDifficulty"] = {angle = 126}, -- Instance difficulty
		["GuildInstanceDifficulty"] = {angle = 126}, -- As above when in guild group
		["MiniMapChallengeMode"] = {angle = 126}, -- As above when in doing challenge modes
		["TimeManagerClockButton"] = {anchorat = "BOTTOM", anchorto = "BOTTOM", posx = 0, posy = -11} -- The clock
	}
}
