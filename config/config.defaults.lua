--[[


--]]
local DraeUI = select(2, ...)

--[[
		Default configuration settings
--]]
DraeUI.config = {
	general = {
		--[[
			Textures. LSM keys, resolved by FetchMedia in init.lua.

			The key doesn't have to be one draeUI ships - LSM is a shared
			registry, so anything any installed addon has registered resolves
			here. "Striped" is one of those: draeUI's own copy was retired in
			0a3c414 and media/sharedmedia.lua doesn't list it, but another addon
			provides it. Don't read an absence there as a broken key.
		--]]
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
			--[[
				The one entry here that isn't a colour: power types allowed to
				keep Blizzard's own bar artwork, instead of statusbar_power
				tinted with `power` below. Keyed by oUF's string token.

				To see everything that ships with an atlas, so you can audit
				this list, log in and run:
				/run for k,v in pairs(DraeUI.powerAtlases) do print(k,v) end

				Set to false to use statusbar_power for every power type.
			--]]
			atlas = {
				EBON_MIGHT = true, -- Augmentation evoker
				FURY = true, -- Havoc demon hunter
				INSANITY = true, -- Shadow priest
				LUNAR_POWER = true, -- Balance druid
				MAELSTROM = true, -- Elemental/enhancement shaman
				PAIN = true, -- Vengeance demon hunter
			},

			--[[
				Everything from `power` down to `quest` is applied onto oUF.colors
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
				Aura border tint per dispel type, keyed by the dispel name oUF
				takes from AuraUtil.GetDebuffDisplayInfoTable(). Bleed and
				Enrage are left out and keep oUF's defaults.

				There is no None entry any more. The old step curve resolved a
				dispel-less aura to a None colour rather than nil, so one had
				to be supplied to stop Blizzard's dark-red DEBUFF_TYPE_NONE_COLOR
				tinting every ordinary debuff border. AuraButton has no such
				fallback - an aura with no dispel type simply gets no tint.
			--]]
			dispel = {
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

			--[[
				Chrome rather than game state: the backing behind the minimap's
				buttons and its zone/clock bands. One knob so they always agree.

				Black at 0.8 reads as part of the frame against the map without
				going fully opaque. Lower the alpha to let more map through.
			--]]
			panel = { 0, 0, 0, 0.8 },

			--[[
				Zone PvP ruleset. Two readers: Presence's zone toasts, when
				presence.zoneTypeColouring is on, and the minimap's zone label,
				when minimap.text.zone.pvpColour is on. They agreeing on what
				"hostile" looks like is the point of one table rather than two.

				C_PvP.GetZonePVPInfo also returns "arena" and "combat"; the
				minimap folds both into hostile, since all three mean the same
				thing to someone reading a zone name.
			--]]
			zone = {
				friendly = { 0.1, 1.0, 0.1 },
				hostile = { 1.0, 0.1, 0.1 },
				contested = { 1.0, 0.7, 0.0 },
				sanctuary = { 0.41, 0.8, 0.94 },
			},
		},
	},

	--[[
		The info bar. Read by modules/infobar/init.lua on enable.

		It stretches between two anchors rather than carrying a width, so by
		default it fills whatever gap the micro menu and the minimap leave
		between them and follows either of those moving.

		relTo is a global frame name, resolved at enable and guarded - these are
		Blizzard's frames and Blizzard has moved them before now
		(MicroButtonAndBagsBar simply stopped existing). If one can't be found
		the bar falls back to a UIParent-relative position so the module still
		loads with something on screen.

		There is deliberately nothing here about which readouts appear or in
		what order: a plugin exists because it registered, and places itself by
		the `order` in its own Register call.
	--]]
	infobar = {
		height = 30,

		--[[
			Minimum widths, keyed by the name a plugin passes to InfoBar:Register.
			Anything not listed sizes to its text and nothing more.

			Experience has one because its progress bars span the plugin frame:
			left to the text alone the readout collapses to a stub of a bar as
			soon as the numbers are short - "[80] 4%xp" is barely wider than the
			word. The text stays left-aligned and the surplus extends right, so
			the bar gets the room rather than the label.
		--]]
		minWidth = {
			Experience = 250,
		},

		left = {
			relTo = "MicroMenuContainer",
			point = "TOPLEFT",
			relPoint = "TOPRIGHT",
			x = 15,
			y = -15,
		},

		right = {
			relTo = "MinimapCluster",
			point = "TOPRIGHT",
			relPoint = "TOPLEFT",
			x = -100,
			y = -15,
		},
	},

	--[[
		The minimap. Read by modules/minimap/*.lua on enable.

		draeUI skins Blizzard's minimap *in place*. It stays inside
		MinimapCluster, the cluster keeps its alpha and its mouse, and Edit Mode
		still owns both where the thing sits and how big it is. That is a
		deliberate departure from every other minimap addon and it buys three
		things: Edit Mode keeps working, infobar.right.relTo = "MinimapCluster"
		keeps measuring something real, and the Minimap is never reparented -
		which is the manoeuvre that makes Blizzard's map pin code blow up on the
		protected SetPropagateMouseClicks during a world map open.

		There is deliberately no `size` key. See the header of
		modules/minimap/init.lua for why forcing one is a fight not worth having.

		Every `pos` below is one of the ten anchors in modules/minimap/init.lua:
		the eight compass points on the map itself, plus ABOVE and BELOW, which
		float clear of it. x/y nudge from there in pixels, positive being
		right/up regardless of which corner you anchored to.

		There are no colours here. Everything draeUI tints lives in
		general.colours - the zone readout reads general.colours.zone.
	--]]
	minimap = {
		--[[
			Pixel thickness of the framing art, the same unitframe.tga nine-slice
			the unit frames use. 14 matches a unit frame exactly; 20 is the
			visual match for the fixed Minimap.tga ring this replaced.
		--]]
		border = 20,

		--[[
			Wheel zoom, 0-5. persist keeps the level in draeUIDB across reloads.
			That is data the player set with the mouse rather than a setting -
			the same reason the infobar's Coin plugin is allowed in there.
		--]]
		zoom = {
			wheel = true,
			persist = true,
		},

		--[[
			Middle-click opens the micro menu. The world ping is swallowed either
			way; the overlay that swallows it is also what makes the square
			corners scrollable at all.
		--]]
		microMenu = {
			enabled = true,
			width = 150,
			rowHeight = 18,
		},

		--[[
			Readouts, each on its own small plate straddling an edge of the map.

			Straddling rather than sitting inside is the point: the plate is
			centred ON the border, so it reads as part of the frame instead of as
			something floating on the map. Each is only as wide as its own string,
			and a readout with nothing to say hides its plate rather than leaving
			an empty tab - which is what the difficulty one does in the open world.

			Blizzard's zone text and clock are hidden whenever ours are on; its
			difficulty flag is hidden whenever `difficulty` is, since the two say
			the same thing.

			`band` is top or bottom, `align` is LEFT, CENTER or RIGHT along it.
			Two readouts can share an edge as long as they don't share an
			alignment. Corner-hung plates inset themselves clear of the framing
			art automatically.

			`border` frames each plate in the same nine-slice as the map. 0 is
			off; try 10 or 12 if you want them to match the map's own edging
			rather than being flat panels.
		--]]
		text = {
			height = 16,
			border = 10,

			padding = 10, -- padding around text

			-- y nudges outward from the map, so the same positive value raises a
			-- top plate and lowers a bottom one
			zone = { band = "bottom", align = "CENTER", size = 12, y = 2, pvpColour = true },
			clock = { band = "top", align = "CENTER", size = 12, y = 2 },
			difficulty = { band = "top", align = "RIGHT", size = 12, y = 2 },
		},

		--[[
			Two columns of buttons, both hanging off the outside of the map's
			left edge.

			The split is by what makes a button come and go. `elements` holds the
			Blizzard-derived indicators, which appear and disappear with game
			state - mail arrives, a crafting order lands - so they grow DOWN from
			the top and the movement stays up there. `buttons` holds ours and any
			third-party ones, which are fixed for the session, so they grow UP
			from the bottom and don't get shoved around when mail turns up.

			Anything false below is absent from its column entirely rather than
			present-and-hidden, so the gaps close.

			Our indicators are addon-owned buttons drawn from Blizzard's atlases;
			Blizzard's own are alpha-zeroed rather than reparented, so nothing of
			theirs is ever moved and there is no taint surface.

			pos takes the OUT* anchors from modules/minimap/init.lua, which hang
			a column beside the map rather than on it. grow is DOWN/UP/LEFT/RIGHT.
			Both are symmetric, so putting the columns on the right edge is
			OUTRIGHTTOP + OUTRIGHTBOTTOM and nothing else.
		--]]
		rows = {
			size = 20,

			-- 0 so a bordered group reads as one block rather than as tiles with
			-- map showing between them. The group's backdrop sits behind any gap
			gap = 0,

			--[[
				One border around each column, in the same nine-slice as the map
				and the text plates - per group rather than per button, so a
				column reads as a single framed object rather than a stack of
				them. 0 turns it off.

				It draws border/2 - 1 px outside the column, so raising it eats
				into the gap the x nudge below leaves against the map's own art.
			--]]
			border = 10,

			-- x/y are a nudge on top of the automatic border clearance, so 0
			-- means flush against the framing art rather than on top of it
			elements = { pos = "OUTLEFTTOP", grow = "DOWN", x = 3, y = 0 },
			buttons = { pos = "OUTLEFTBOTTOM", grow = "UP", x = 3, y = 0 },

			-- Off: right-clicking the map opens Blizzard's tracking menu anyway
			tracking = false,
			calendar = true,
			lockouts = true, -- saved instances in the calendar button's tooltip
			mail = true,
			crafting = true,
			friends = true,

			-- Blizzard's addon compartment. Only takes a slot when something
			-- has actually registered an entry with it
			compartment = true,
		},

		--[[
			Third-party minimap buttons.

			They are swept off the map and held down - Blizzard's addon
			compartment is the collector, so an addon that registers an entry is
			reachable there and one that only scatters a button on the map is
			simply hidden.

			`standalone` is the exception list: these keep their icon and go in
			the button column instead. Named with any LibDBIcon10_ prefix already
			stripped, and the order here is the order in the column.

			`/draeui buttons` lists every child of the Minimap and what was
			decided about it, for when something is still visible.
		--]]
		buttons = {
			standalone = {
				"BugSack",
			},
		},

		-- Online guild members and friends. maxRows 0 is uncapped
		friends = {
			maxRows = 0,
			width = 260,
			rowHeight = 14,
		},

		--[[
			The expansion landing button, centred on a map corner. Blizzard
			re-anchors it after loading screens without calling Show, so it needs
			re-asserting; see modules/minimap/buttons.lua.

			A button column anchored to the same corner shifts along its growth
			direction to clear this, and only while the button actually exists and
			is shown - so moving the columns to the right edge, or playing an
			expansion with no landing button, needs no other change here.
		--]]
		landingPage = { pos = "OVERBOTTOMLEFT", x = 0, y = 0, scale = 0.75 },
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
		Buff bar - the player's own buffs, bottom right, plus temporary
		weapon enchants in a second container to their left.

		Sizes are in pixels. `pitch` is button size + gap, and it is what the
		old secure header called xOffset/wrapYOffset; `perRow * pitch` is the
		line width the flow layout wraps at.
	--]]
	buffbar = {
		size = 25, -- button edge
		spacing = 9, -- gap between buttons, and between rows
		perRow = 16, -- buttons before wrapping to the next row
		maxBuffs = 32, -- hard cap; perRow * 2 keeps it to two rows
		x = -20, -- offset from UIParent BOTTOMRIGHT
		y = 20,
		enchantOffset = -20, -- gap between the buff bar and the enchant bar

		--[[
			"Long duration only" mode.

			There is no minDuration/isPermanent candidate filter - Blizzard
			ships maxDuration and nothing that inverts it - so long-only is
			not directly expressible. Two mechanisms, allowlist winning:

			- longDurationSpells populated -> exactly those spell IDs show.
			  Exact, and spell-ID filtering stays legal under secret auras.
			- left empty -> approximate it by sorting longest-first and
			  capping at longDurationCount.

			Takes effect on /rl. The container can be reconfigured live
			(SetAuraGroupCandidateFilters and friends), but with no options
			UI to drive it there is nothing to gain from the machinery.
		--]]
		longDurationOnly = false,
		longDurationCount = 8,
		longDurationSpells = {}, -- [spellID] = true
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
