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
		statusbar_absorb = "DF Stripes Soft",

		--[[
				Power types allowed to use Blizzard's own bar artwork instead of
				statusbar_power tinted with colours.power.

				To see everything that ships with an atlas, so you can audit this
				list, log in and run:
				/run for k,v in pairs(DraeUI.powerAtlases) do print(k,v) end

				Set to false to use statusbar_power for every power type.
		--]]
		powerAtlas = {
			EBON_MIGHT = true, -- Augmentation evoker
			FURY = true, -- Havoc demon hunter
			INSANITY = true, -- Shadow priest
			LUNAR_POWER = true, -- Balance druid
			MAELSTROM = true, -- Elemental/enhancement shaman
			PAIN = true, -- Vengeance demon hunter
		},

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
				Everything from here down to `quest` is applied onto oUF.colors
				by DraeUI:OnEnable. They are partial overrides - any key left
				out keeps oUF's Blizzard-derived default.

				Keyed by oUF's own key names. Power uses the string token
				because that's oUF's canonical key; it aliases the numeric
				power-type IDs to the same colour objects, so overriding the
				token updates both.

				Deliberately absent: `class`. oUF rebuilds colors.class from a
				CUSTOM_CLASS_COLORS callback with fresh objects, which would
				throw any override away - class colours must stay oUF's.
			--]]
			power = {
				MANA = { 46 / 255, 158 / 255, 255 / 255 },
				RAGE = { 199 / 255, 64 / 255, 64 / 255 },
				FOCUS = { 255 / 255, 128 / 255, 64 / 255 },
				ENERGY = { 255 / 255, 249 / 255, 105 / 255 },
				RUNIC_POWER = { 0 / 255, 204 / 255, 255 / 255 },
				LUNAR_POWER = { 77 / 255, 133 / 255, 230 / 255 },
				MAELSTROM = { 0, 128 / 255, 255 / 255 },
				INSANITY = { 102 / 255, 0, 204 / 255 },
				FURY = { 201 / 255, 66 / 255, 252 / 255 },
				PAIN = { 255 / 255, 156 / 255, 0 },
				ALTERNATE = { 51 / 255, 102 / 255, 204 / 255 },
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

			--[[
				Presence toast accents, keyed by the category a notification
				resolves to. Named "quest" because the ported files reach it as
				QUEST_COLORS, but it covers achievements, scenarios, zones and
				rares too.
			--]]
			quest = {
				DEFAULT = { 0.90, 0.90, 0.90 },
				CURRENT = { 0.95, 0.55, 0.45 },
				AVAILABLE = { 0.28, 0.48, 0.88 },
				CURRENT_EVENT = { 0.28, 0.48, 0.88 },
				NEARBY = { 0.35, 0.75, 0.98 },
				CAMPAIGN = { 1.00, 0.82, 0.20 },
				IMPORTANT = { 1.00, 0.45, 0.80 },
				LEGENDARY = { 1.00, 0.50, 0.00 },
				DUNGEON = { 0.64, 0.21, 0.93 },
				RAID = { 0.85, 0.25, 0.25 },
				DELVES = { 0.32, 0.72, 0.68 },
				SCENARIO = { 0.38, 0.52, 0.88 },
				SCENARIO_STAGE = { 0.55, 0.65, 0.75 },
				WORLD = { 0.78, 0.42, 0.95 },
				WEEKLY = { 0.25, 0.88, 0.92 },
				PREY = { 0.72, 0.22, 0.22 },
				DAILY = { 0.25, 0.88, 0.92 },
				CALLING = { 0.20, 0.60, 1.00 },
				COMPLETE = { 0.20, 1.00, 0.40 },
				RARE = { 0.96, 0.56, 0.08 },
				RARE_LOOT = { 0.96, 0.56, 0.08 },
				ACHIEVEMENT = { 0.78, 0.48, 0.22 },
				ENDEAVOR = { 0.45, 0.95, 0.75 },
				ENDEAVORS = { 0.45, 0.95, 0.75 },
				DECOR = { 0.65, 0.55, 0.45 },
				APPEARANCE = { 135 / 255, 96 / 255, 1 },
				APPEARANCES = { 135 / 255, 96 / 255, 1 },
				RECIPE = { 0.55, 0.75, 0.45 },
				RECIPES = { 0.55, 0.75, 0.45 },
				ADVENTURE = { 0.90, 0.80, 0.50 },
			},

			-- The two Presence toasts that aren't category-keyed
			bossEmote = { 1, 0.2, 0.2 },
			discovery = { 0.4, 1, 0.5 },

			-- Zone toasts, when presence.zoneTypeColouring is on
			zone = {
				friendly = { 0.1, 1.0, 0.1 },
				hostile = { 1.0, 0.1, 0.1 },
				contested = { 1.0, 0.7, 0.0 },
				sanctuary = { 0.41, 0.8, 0.94 },
			},
		},
	},

	infobar = {
		xp = {
			enable = true,
			altxp = "reputation",
		},
	},

	--[[
		Cast bars - replicas of Blizzard's player cast bar, on the target and
		focus frames. Read by UF.CreateCastBar.

		The player keeps Blizzard's own PlayerCastingBarFrame, so it isn't
		listed here. Add an entry and a UF.CreateCastBar call in units/player.lua
		if you ever want draeUI to own that one too.

		All that lives here is size and placement; everything about how the bar
		looks is Blizzard's. relTo names a key on the unit frame (the frame
		itself when nil), so the bar hangs off the health bar the way the rest
		of the frame does.

		Every flag defaults to whatever Blizzard's own bar does, so leaving them
		all unset gives you their bar:

			time        off - the cast timer, off in their Edit Mode too
			tradeSkills off - crafting casts, which they keep off unit frames
			icon        on  - the spell icon at the left end
			fx          on  - interrupt shake, interrupt outer glow, and the
			                  glow trailing the spark

		icon is turned off below - the one deliberate departure from their bar.

		sliceCap is how many pixels of each end of the framing art are held back
		from stretching. Blizzard's border is drawn for a 208-wide bar and the
		atlas carries no slice data, so on a bar much wider than that the rounded
		end caps stretch with everything else. Left unset it guesses generously,
		which is the safe direction - too wide only pins some of the straight
		middle, too narrow stretches the curve. Raise it if the ends still look
		pulled; lower it if they look cropped.
	--]]
	castbar = {
		-- 11 is the height of Blizzard's player cast bar
		target = {
			width = 450,
			height = 11,
			point = "TOPLEFT",
			relTo = "Health",
			relPoint = "BOTTOMLEFT",
			x = 0,
			y = -25,
			icon = false,
		},

		focus = {
			width = 150,
			height = 11,
			point = "BOTTOMRIGHT",
			relTo = "Health",
			relPoint = "TOPRIGHT",
			x = 0,
			y = 25,
			icon = false,
		},
	},

	--[[
		Presence - cinematic zone/quest/achievement toasts.
	--]]
	presence = {
		-- Centre-screen frame. y is measured from the top, so negative is down
		frame = {
			y = -180,
			scale = 1,
			uiScale = 1,
		},

		--[[
				Durations in seconds. enabled = false makes toasts appear and vanish
				instantly; hold scales how long each type stays up for.
		--]]
		animation = {
			enabled = true,
			entrance = 0.7,
			exit = 0.8,
			hold = 1,
		},

		-- Stay quiet in instanced content; toasts are for the open world
		suppress = {
			dungeon = true,
			raid = true,
			delve = true,
			pvp = true,
			battleground = true,
		},

		-- One switch per kind of toast
		toasts = {
			levelUp = true,
			bossEmote = false, -- Leave boss emotes to Blizzard's own frame
			achievement = true,
			achievementProgress = false, -- Noisy; every criteria tick fires one

			zoneChange = true,
			subzoneChange = true,

			questAccept = true,
			questComplete = true,
			questUpdate = true,
			worldQuestAccept = true,
			worldQuest = true,

			scenarioStart = true,
			scenarioUpdate = true,
			scenarioComplete = true,
		},

		--[[
			Toast text sizes.

			Which set a toast uses is decided by its type, not chosen here:
			zone changes and level ups are large, quest and scenario toasts
			medium, progress updates small. primary is the heading, secondary
			the line under it.

			discovery is the "Discovered <subzone>" line appended to a zone
			toast. Clamped on read - 12-72 for primary, 12-40 for the rest -
			so a slip here can't produce an unreadable toast.
		--]]
		fontSize = {
			large = { primary = 48, secondary = 24 },
			medium = { primary = 36, secondary = 22 },
			small = { primary = 28, secondary = 20 },

			discovery = 16,
		},

		-- Font flags per element: OUTLINE, THICKOUTLINE, MONOCHROME or NONE
		outline = {
			title = "OUTLINE",
			subtitle = "OUTLINE",
			discovery = "OUTLINE",
		},

		shadow = {
			x = 1,
			y = -1,
			alpha = 0.8,
		},

		-- Append "Discovered <subzone>" to a zone toast when exploring
		discovery = true,

		-- Progress toasts show just the objective line, no "QUEST UPDATE" heading
		hideQuestUpdateTitle = true,

		-- Drop the zone name from a subzone toast when the zone hasn't changed
		hideZoneForSubzone = false,

		worldQuestSound = true,

		-- Colour zone toasts by PvP status rather than category, from
		-- general.colours.zone
		zoneTypeColouring = false,

		-- Tint toasts with the player's class colour
		classColour = false,
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
		totXoffset = 30, -- Relative to right of target
		totYoffset = 0,
		focusXoffset = 50, -- Relative to left of target
		focusYoffset = 0,
		focusTargetXoffset = 30, -- Relative to right of focus target
		focusTargetYoffset = 0,
		petXoffset = -50, --62, 	-- Relative to left of player
		petYoffset = 0, ---100,
		bossXoffset = 0, -- Relative to left of target
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
				["other"] = 3, -- focus, focus target, pet, etc.
			},
			debuffs_per_row = {
				["player"] = 4,
				["target"] = 5,
				["focus"] = 3,
				["other"] = 3,
			},
			showBuffsOnPlayer = false, -- Short term buffs on myself or my pet
			showDebuffsOnPlayer = true, -- Debuffs on myself or pet
			showBuffsOnTarget = true,
			showDebuffsOnTarget = false,
		},
	},
}
