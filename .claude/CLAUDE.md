# draeUI

## Project Overview

draeUI is a World of Warcraft addon that provides a custom UI focused on unit frames, designed for healers. Built using the oUF (oUnitFrames) framework with components adapted from ElvUI and other addons.

**Target WoW Version**: Interface 120000-120001 (current expansion)

## Architecture

### Core Structure

- **init.lua**: Main addon initialization using Ace3 framework
  - Sets up the `DraeUI` global table (accessible via `_G.DraeUI`)
  - Initializes AceAddon-3.0, AceEvent-3.0, AceDB-3.0
  - Configures oUF color schemes for power types and reactions
  - Handles font system overrides for entire UI
  
- **config/config.defaults.lua**: Central configuration file
  - Contains all default settings for frames, textures, fonts, colors
  - Frame positioning is relative (player/target to screen center, all others to those)
  - Aura size/count settings organized by unit type
  
- **functions/**: Shared utility functions
  - `functions.lua`: `FetchMedia` (LSM key/path resolution), `SetFont`, `CreateFontObject`, `UTF8`, `Hex`, `Print`, `Debug`
  - `game.lua`: Game-state queries - `CanAccessValue`, `IsInPartyDungeon`, `IsDelveActive`, `GetActiveDelveTier`, `GetDelveName`, `IsQuestWorldQuest`, `GetQuestFrequency`, `GetQuestBaseCategory`
  - `toolkit.lua`: Methods mixed into the Frame/Texture/FontString metatables - `:Kill()`, `:StripTextures()`, and the reversible `:Suppress()` / `:Restore()` pair (plus `DraeUI.IsSuppressed`)

There is no backdrop, gradient, or pixel-perfect helper - backdrops are hand-rolled at each call site, and scaling uses `DraeUI.screenWidth` / `screenHeight` / `uiScale` directly.

### Module System

Modules are initialized through AceAddon's `:NewModule()` and loaded via the .toc file:

- **unitframes/** (modules/unitframes/): Core unit frame functionality
  - `init.lua`: Spawns all unit frames using oUF:Spawn()
  - `common.lua`: Shared frame element setup
  - `castbar.lua`: Cast bar implementation
  - `tags.lua`: Custom oUF tags
  - `units/*.lua`: Individual unit styles (player, target, pet, focus, boss, etc.)
  - `resources/*.lua`: Class-specific resource bars (monk.lua is active, others commented)
  - `elements/`: Additional frame elements (embed.xml)
  
- **buffbar/** (modules/buffbar/): Aura tracking system
- **skins/** (modules/skins/): Static decorative UI artwork (actionbar surround, minimap ring, micro menu)
- **presence/** (modules/presence/): Cinematic centre-screen toasts for zone changes, quests, achievements, level ups and scenarios, replacing Blizzard's zone text and banner frames. Ported from HorizonSuite (MIT). `init.lua` is both the AceAddon module and the host table the four still-verbatim `core/quest/scenario/achievement` files read as `addon`. See `modules/presence/resync.md` before touching those four.

### Library Dependencies

Located in `libs/` and loaded via libs.xml:

- **oUF**: Unit frame framework (custom embedded version: `DraeUI.oUF`)
- **Ace3**: AceAddon-3.0, AceEvent-3.0
- **LibStub**: Library management
- **LibSharedMedia-3.0**: Media (fonts, textures, sounds) management

## Key Conventions

### Addon Namespace Pattern

```lua
local addon, DraeUI = ...
local oUF = DraeUI.oUF or oUF
```

All files use this pattern to access the shared namespace table. The addon name is usually unused; `DraeUI` is the primary reference.

### Settings — there is no database

draeUI has **no saved variables/database**. Every setting lives in
`config/config.defaults.lua`, a hand-edited table read directly at the point of use. There is
no options UI, no accessor function, and no per-call-site defaults.

### Configuration Access

Access config via `DraeUI.config["section"].property`:

```lua
DraeUI.config["frames"].playerXoffset
DraeUI.config["general"].font
```

### Media Access

Media files cached in `DraeUI.media` after LibSharedMedia lookup:

```lua
DraeUI.media.font          -- Main UI font
DraeUI.media.fontSmall     -- Small text font
DraeUI.media.fontTitles    -- Title/header font
DraeUI.media.statusbar     -- Primary texture
DraeUI.media.sound1        -- Custom sound file
```

### Frame Positioning System

- Player/Target: Positioned relative to UIParent center using config offsets
- All other frames: Positioned relative to player/target frames
- Example: `targettarget` positions to `DraeTarget` BOTTOMRIGHT + offset

### oUF Styling Pattern

Each unit type has its own style:

```lua
oUF:SetActiveStyle("DraePlayer")
oUF:Spawn("player", "DraePlayer")
```

Styles defined in `modules/unitframes/units/*.lua` files.

### Local Function Caching

Heavily used pattern to optimize performance:

```lua
local CreateFrame = CreateFrame
local UnitClass, UnitName = UnitClass, UnitName
local select, mfloor = select, math.floor
```

Cache WoW API functions and Lua built-ins at file scope.

### Color Definitions

**Every colour value lives in `config.general.colours`.** Nothing else defines one.
`DraeUI:OnEnable` (init.lua) applies the oUF-facing subset onto `oUF.colors`; the rest
(`castbar`, `healthPrediction`, `auraBorder`, `healthText`, and Presence's
`quest`/`bossEmote`/`discovery`/`zone`) is read directly at the point of use.

Rules for the oUF subset:

- **Mutate, don't assign.** The applier calls `:SetRGB()` on the ColorMixin oUF already
  built. oUF aliases numeric power-type IDs to the *same objects* as the string tokens
  (`colors.power[0] == colors.power.MANA`), so assigning a fresh colour to the token
  orphans the numeric key and elements that look up by ID get Blizzard's original. This
  is why config keys power by string token only — the numeric aliases follow for free.
- **`dispel` is the exception:** it holds the raw `DEBUFF_TYPE_*_COLOR` globals, so those
  entries are assigned. It is also the only colour oUF *snapshots* (into a per-element
  `dispelColorCurve` at Enable), so it must be set before `oUF:Spawn` — which is why the
  applier stays in `DraeUI:OnEnable`, ahead of `UF:OnEnable`.
- **Never override `class`.** oUF rebuilds `colors.class` from a `CUSTOM_CLASS_COLORS`
  callback with fresh objects and would discard any override.
- Overrides are partial — any key left out keeps oUF's Blizzard-derived default.

### Power Bar Atlases

Power elements set `colorPowerAtlas = true` unconditionally. oUF then swaps the bar to
Blizzard's own artwork whenever `colors.power[token]:GetAtlas()` is non-nil, and otherwise
restores `element.__texture` and applies the config colour — so every power bar must set
`__texture` for that fallback to work. When an atlas is used the bar is drawn at
`SetVertexColor(1, 1, 1)`, so `colours.power` is ignored for that power.

**Which powers get one is controlled by `general.powerAtlas`, an allowlist of tokens.**
Blizzard ships an atlas for nearly every power type, but most are just the stock HUD bar
recoloured, so the applier in init.lua **clears `.atlas`** on everything not in the list —
that is what sends a power down the fallback path. Clear the field directly; `SetAtlas(nil)`
errors, as it validates through `C_Texture.GetAtlasInfo`. Everything that shipped with one
is recorded in `DraeUI.powerAtlases` first, for auditing the list.

All of this depends on the applier mutating colours rather than replacing them — oUF
attaches the atlas to the colour object it built from `PowerBarColor`, and assigning a
fresh `oUF:CreateColor()` over it silently drops the atlas.

### Blizzard Frame Hiding

Standard pattern to hide default Blizzard frames:

```lua
_G["FrameName"]:Kill()  -- or :Hide() + :UnregisterAllEvents()
FrameName.Show = FrameName.Hide  -- Prevent re-showing
```

## Console Commands

- `/rl` - Reload UI
- `/rar` - Ready check
- `/draeui grid [size]` - Toggle alignment grid (4-256 pixels, default 128)
- `/draeui hide` - Toggle UI visibility and friendly nameplates (for screenshots)

## Development Environment

### Lua Configuration (.luarc.json)

- Runtime: Lua 5.1 (WoW's Lua version)
- LibStub treated as `require` equivalent
- WoW API globals pre-declared to avoid diagnostics
- Uses LuaLS (Lua Language Server) with WoW library definitions

### File Loading Order

Controlled by draeUI.toc (TOC = Table of Contents):

1. Libraries (libs.xml)
2. Media (media.xml)
3. Core init (init.lua)
4. Config defaults
5. Functions
6. Modules (BuffBar, Skins, Unitframes)

Order matters for dependencies - libs before core, config before modules.

### Commenting Out Modules

Modules can be disabled by prefixing lines in .toc with `#`:

```
#modules\unitframes\resources\totems.lua
```

Currently, several class resource modules are disabled this way.

## Important Notes

- **Combat Lockdown**: Many frame operations require `InCombatLockdown()` checks
- **Addon Namespace**: Always use `DraeUI` table, not global variables, to avoid conflicts
- **oUF Framework**: Custom frames must follow oUF's element and update pattern
- **Font Updates**: Global font changes happen in PLAYER_ENTERING_WORLD event
- **Screen Coordinates**: Use `DraeUI.screenHeight`, `DraeUI.screenWidth`, `DraeUI.uiScale` for scaling
