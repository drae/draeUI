local DraeUI = select(2, ...)

DraeUI.config = {
	general = {
		-- LSM keys, resolved by FetchMedia in init.lua. Any key another installed
		-- addon has registered resolves here too
		statusbar = "Striped",
		statusbar_power = "Striped",
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
			-- Not a colour: power types allowed to keep Blizzard's own bar artwork
			-- instead of statusbar_power tinted with `power` below
			atlas = {
				EBON_MIGHT = true, -- Augmentation evoker
				FURY = true, -- Havoc demon hunter
				INSANITY = true, -- Shadow priest
				LUNAR_POWER = true, -- Balance druid
				MAELSTROM = true, -- Elemental/enhancement shaman
				PAIN = true, -- Vengeance demon hunter
			},

			--[[
				`power` down to `quest` is applied onto oUF.colors by DraeUI:OnEnable
				as partial overrides - any key left out keeps oUF's default.
				Deliberately absent: `class`. oUF rebuilds it from a
				CUSTOM_CLASS_COLORS callback and would throw an override away.
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

			-- Keyed by the dispel name oUF takes from
			-- AuraUtil.GetDebuffDisplayInfoTable(). No None entry: no dispel type
			-- means no tint. Bleed and Enrage keep oUF's defaults
			dispel = {
				Magic = { 51 / 255, 153 / 255, 255 / 255 },
				Curse = { 153 / 255, 0, 255 / 255 },
				Disease = { 153 / 255, 102 / 255, 0 },
				Poison = { 0, 153 / 255, 0 },
			},

			auraBorder = { 0, 0, 0 }, -- aura icon border when there is no dispel type

			healthPrediction = {
				healingPlayer = { 0, 1.0, 0.3, 0.25 },
				healingOther = { 0, 1.0, 0, 0.25 },
				damageAbsorb = { 1.0, 1.0, 1.0, 0.33 },
				healAbsorb = { 1.0, 0, 0.8, 0.33 },
				overAbsorb = { 1, 1, 1, 0.5 },
				overHealAbsorb = { 1.0, 0, 0, 0.5 },
			},

			healthText = { 170 / 255, 170 / 255, 170 / 255 }, -- offline/ghost/dead

			-- Presence toast accents. Named "quest" because the ported files reach
			-- it as QUEST_COLORS, but it covers achievements, scenarios and zones
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

			bossEmote = { 1, 0.2, 0.2 },
			discovery = { 0.4, 1, 0.5 },

			panel = { 0, 0, 0, 0.8 }, -- backing behind the minimap's buttons and bands

			-- Zone PvP ruleset, read by Presence's zone toasts and the minimap's
			-- zone label. The minimap folds "arena" and "combat" into hostile
			zone = {
				friendly = { 0.1, 1.0, 0.1 },
				hostile = { 1.0, 0.1, 0.1 },
				contested = { 1.0, 0.7, 0.0 },
				sanctuary = { 0.41, 0.8, 0.94 },
			},

			rowOutline = { 0, 0, 0, 1 }, -- default edge for CreateOutline

			-- `unknown` is not an error case - classFilename is secret mid-combat,
			-- so this is what other players' rows wear in M+ and raid
			damagemeter = {
				barBackground = { 0, 0, 0, 0.2 },
				overlay = { 0.7, 0.7, 0.7, 0.2 },
				text = { 1, 1, 1, 1 },
				highlight = { 1, 1, 1, 0.08 },
				unknown = { 0.5, 0.5, 0.5 },

				-- Rows in EnemyDamageTaken, which are mobs and have no class
				enemy = { 0.87, 0.19, 0.19 },
			},
		},
	},

	-- The info bar stretches between two anchors rather than carrying a width.
	-- relTo is a global frame name, resolved and guarded at enable - if one can't
	-- be found the bar falls back to a UIParent-relative position
	infobar = {
		height = 30,

		-- Keyed by the name a plugin passes to InfoBar:Register; anything not
		-- listed sizes to its text. Experience needs one or its bars collapse
		minWidth = {
			Experience = 250,
		},

		left = {
			relTo = "UIParent",
			point = "TOPLEFT",
			relPoint = "TOPLEFT",
			x = 55,
			y = -22,
		},

		right = {
			relTo = "UIParent",
			point = "TOPRIGHT",
			relPoint = "TOPRIGHT",
			x = -400,
			y = -22,
		},
	},

	damagemeter = {
		-- Out of combat the meter redraws only on Blizzard's session events
		refreshRate = 1,

		strata = "LOW",

		--[[
			Windows, in the order they stack. `readout` is a key of
			Enum.DamageMeterType: DamageDone, Dps, HealingDone, Hps, Absorbs,
			Interrupts, Dispels, DamageTaken, AvoidableDamageTaken, Deaths,
			EnemyDamageTaken. `segment` is Current or Overall. Both are only the
			starting state; the header menus change either at runtime. Only the
			first window carries an anchor while `grouped` is on.
		--]]
		windows = {
			{
				readout = "DamageDone",
				segment = "Current",
				point = "TOPLEFT",
				relTo = "UIParent",
				relPoint = "TOPLEFT",
				x = 64,
				y = -80,
			},

			{
				readout = "HealingDone",
				segment = "Current",
			},
		},

		grouped = true,
		gap = 6,

		-- Height follows from `rows` and the row and header sizes below, so a
		-- window can never show a part of a bar
		window = {
			width = 240,
			rows = 5,

			-- Alpha of the window's own backing. 0 floats the bars on nothing
			backdrop = 0,
			outline = 0,
		},

		header = {
			enabled = true,
			height = 18,
			fontSize = 12,
			timer = true,

			iconSize = 14,
			icons = {
				readout = true,
				segment = true,
				reset = true,
				close = false,
			},
		},

		-- Pitch is `height` plus `spacing`. At 0 padding the icon sits on top of
		-- the fill rather than beside it
		rows = {
			height = 20,
			spacing = 1,
			padding = { left = 0, right = 0 },

			showRank = false, -- "1." ahead of the name
			outline = 0,
		},

		-- "spec" uses the specIconID Blizzard gives per source, falling back to the
		-- class icon; "class" always uses the class icon
		icon = {
			enabled = true,
			style = "spec",
			zoom = 0.06,
		},

		-- `texture` is an LSM key; nil takes general.statusbar
		bar = {
			texture = nil,
			alpha = 1.0,
			overlay = true,
		},

		-- `font` nil takes general.font. flags = "" with a shadow rather than OUTLINE:
		-- at 12px over a striped bar an outline blurs the glyphs. The `right` flags
		-- apply in order - all three on reads "1.2M (412K, 38%)"
		text = {
			font = nil,
			size = 12,
			flags = "",
			shadow = true,

			right = {
				total = false,
				perSecond = true,
				percent = false,
			},
		},
	},

	--[[
		The minimap is skinned in place, so Edit Mode still owns where it sits and
		how big it is - there is deliberately no `size` key. Every `pos` below is
		one of the ten anchors in modules/minimap/init.lua; x/y nudge from there in
		pixels, positive being right/up.
	--]]
	minimap = {
		-- Thickness of the framing art, the unitframe.tga nine-slice. 14 matches a
		-- unit frame exactly; 20 matches the fixed Minimap.tga ring
		border = 20,

		-- Wheel zoom, 0-5. persist keeps the level in draeUIDB across reloads
		zoom = {
			wheel = true,
			persist = true,
		},

		-- Middle-click opens the micro menu. The world ping is swallowed either
		-- way, by the same overlay that makes the square corners scrollable
		microMenu = {
			enabled = true,
			width = 150,
			rowHeight = 18,
		},

		--[[
			Readouts, each on a plate centred ON an edge of the map. A readout with
			nothing to say hides its plate, and Blizzard's zone text, clock and
			difficulty flag are hidden whenever ours are on. `band` is top or
			bottom, `align` is LEFT, CENTER or RIGHT along it; two readouts can
			share an edge if they don't share an alignment.
		--]]
		text = {
			height = 16,
			border = 10, -- nine-slice around each plate, 0 for off
			padding = 10,

			-- y nudges outward from the map, so the same positive value raises a
			-- top plate and lowers a bottom one
			zone = { band = "bottom", align = "CENTER", size = 12, y = 2, pvpColour = true },
			clock = { band = "top", align = "CENTER", size = 12, y = 2 },
			difficulty = { band = "top", align = "RIGHT", size = 12, y = 2 },
		},

		--[[
			Two columns hanging off the outside of the map's left edge. `elements`
			holds the Blizzard-derived indicators, which come and go with game
			state, so they grow DOWN and the movement stays at the top; `buttons` is
			fixed for the session and grows UP. Anything false is absent from its
			column rather than present-and-hidden. pos takes the OUT* anchors and
			grow is DOWN/UP/LEFT/RIGHT.
		--]]
		rows = {
			size = 20,
			gap = 0,

			-- One nine-slice border per column rather than per button. It draws
			-- border/2 - 1 px outside the column, eating into the x nudge below
			border = 10,

			-- x/y nudge on top of the automatic border clearance, so 0 means flush
			-- against the framing art rather than on top of it
			elements = { pos = "OUTLEFTTOP", grow = "DOWN", x = 3, y = 0 },
			buttons = { pos = "OUTLEFTBOTTOM", grow = "UP", x = 3, y = 0 },

			-- Off: right-clicking the map opens Blizzard's tracking menu anyway
			tracking = false,
			calendar = true,
			lockouts = true, -- saved instances in the calendar button's tooltip
			mail = true,
			crafting = true,
			friends = true,

			-- Only takes a slot when something has registered an entry with it
			compartment = true,
		},

		-- Third-party minimap buttons are swept off the map and hidden; Blizzard's
		-- addon compartment is the collector. `standalone` keeps an icon and puts it
		-- in the button column instead, LibDBIcon10_ prefix stripped, in column order
		buttons = {
			standalone = {
				"BugSack",
			},
		},

		-- Online guild members and friends
		friends = {
			maxRows = 0, -- 0 is uncapped
			width = 260,
			rowHeight = 14,
		},

		-- Blizzard re-anchors the landing button after loading screens without
		-- calling Show, so it needs re-asserting; see modules/minimap/buttons.lua
		landingPage = { pos = "OVERBOTTOMLEFT", x = 0, y = 0, scale = 0.75 },
	},

	--[[
		Cast bars on the target and focus frames, read by UF.CreateCastBar. Only
		size and placement live here; relTo names a key on the unit frame, or the
		frame itself when nil. Flags default to Blizzard's own bar:

			time        off - the cast timer
			tradeSkills off - crafting casts
			icon        on  - the spell icon at the left end
			fx          on  - interrupt shake, outer glow, spark glow

		sliceCap holds that many pixels of each end of the framing art back from
		stretching - Blizzard's border is drawn for a 208-wide bar and the atlas
		carries no slice data. Unset, it guesses generously.
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

	-- The player's own buffs, bottom right, plus temporary weapon enchants in a
	-- second container to their left. `perRow * (size + spacing)` is the wrap width
	buffbar = {
		size = 25, -- button edge
		spacing = 9, -- gap between buttons, and between rows
		perRow = 16, -- buttons before wrapping to the next row
		maxBuffs = 32, -- hard cap; perRow * 2 keeps it to two rows
		x = -20, -- offset from UIParent BOTTOMRIGHT
		y = 20,
		enchantOffset = -20, -- gap between the buff bar and the enchant bar

		--[[
			"Long duration only". Blizzard ships a maxDuration candidate filter and
			nothing that inverts it, so this is two mechanisms with the allowlist
			winning: longDurationSpells populated shows exactly those spell IDs and
			stays legal under secret auras; left empty, sort longest-first and cap
			at longDurationCount. Takes effect on /rl.
		--]]
		longDurationOnly = false,
		longDurationCount = 8,
		longDurationSpells = {}, -- [spellID] = true
	},

	presence = {
		-- y is measured from the top of the screen, so negative is down
		frame = {
			y = -180,
			scale = 1,
			uiScale = 1,
		},

		-- Seconds. enabled = false makes toasts appear and vanish instantly
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

		-- Which set a toast uses is decided by its type: zone changes and level ups
		-- large, quest and scenario toasts medium, progress updates small. Clamped
		-- on read - 12-72 for primary, 12-40 for the rest
		fontSize = {
			large = { primary = 48, secondary = 24 },
			medium = { primary = 36, secondary = 22 },
			small = { primary = 28, secondary = 20 },

			discovery = 16,
		},

		-- OUTLINE, THICKOUTLINE, MONOCHROME or NONE
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

		discovery = true, -- append "Discovered <subzone>" to a zone toast

		-- Progress toasts show just the objective line, no "QUEST UPDATE" heading
		hideQuestUpdateTitle = true,

		-- Drop the zone name from a subzone toast when the zone hasn't changed
		hideZoneForSubzone = false,

		worldQuestSound = true,

		-- Colour zone toasts by PvP status rather than category
		zoneTypeColouring = false,
		classColour = false,
	},

	frames = {
		showBoss = true,
		hideArena = true, -- Suppress Blizzard's arena enemy/prep frames

		-- Mage only: the spellsteal sparkle over stealable buffs on the target.
		-- Known gap - common.lua reads this key but the overlay has never appeared
		showStealableBuffs = false,

		--[[
			A coloured glow behind the player health and power bars, tinted by the dispel
			school of debuff on player.
		--]]
		dispelGlow = {
			enabled = true,
			spill = 40,
			schools = { Magic = true, Curse = true, Disease = true, Poison = true },
		},

		-- Don't change these, change the scale
		playerWidth = 240,
		playerHeight = 20,
		targetWidth = 450,
		targetHeight = 20,

		-- Player and target are positioned relative to the centre of the screen,
		-- every other frame relative to those
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
		petXoffset = -50, -- Relative to left of player
		petYoffset = 0,
		bossXoffset = 0, -- Relative to left of target
		bossYoffset = 200,

		auras = {
			-- Large are debuffs on players and buffs on targets, small are buffs on
			-- player and debuffs on target, tiny are auras on every other unit
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

			-- Blizzard's dispel-school orb on a debuff icon; colour and visibility
			-- are theirs. The scale is a fraction of the icon, not a fixed size
			showDispelIndicator = true,
			dispelIndicatorScale = 0.6,
		},
	},
}
