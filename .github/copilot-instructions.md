# draeUI - Copilot Instructions

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
  - `functions.lua`: Font creation, string utilities (UTF-8, hex colors, gradients), frame helpers
  - `toolkit.lua`: Additional UI toolkit functions

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
- **infobar/** (modules/infobar/): Information bar with LDB plugins (currently commented out in .toc)

### Library Dependencies

Located in `libs/` and loaded via libs.xml:

- **oUF**: Unit frame framework (custom embedded version: `DraeUI.oUF`)
- **Ace3**: AceAddon-3.0, AceEvent-3.0, AceDB-3.0
- **LibStub**: Library management
- **LibSharedMedia-3.0**: Media (fonts, textures, sounds) management
- **LibRangeCheck-3.0**: Unit range detection
- **LibDataBroker-1.1**: Data display framework

## Key Conventions

### Addon Namespace Pattern

```lua
local addon, DraeUI = ...
local oUF = DraeUI.oUF or oUF
```

All files use this pattern to access the shared namespace table. The addon name is usually unused; `DraeUI` is the primary reference.

### Database Structure

Four database scopes (set up in init.lua OnInitialize):

- `self.dbGlobal` - Account-wide global data
- `self.db` - Per-character profile data (keyed by "name-realm")
- `self.dbClass` - Per-class data
- `self.dbChar` - Per-character specific data

Stored in `draeUIDB` (global) and `draeUICharDB` (per-character) SavedVariables.

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

oUF colors configured in init.lua OnEnable:
- Both string keys (`oUF.colors.power["MANA"]`) and numeric keys (`oUF.colors.power[0]`) for power types
- Reaction colors for hostile/neutral/friendly units
- Debuff type colors for magic/curse/disease/poison

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
6. Modules (BuffBar, Unitframes - Infobar currently disabled)

Order matters for dependencies - libs before core, config before modules.

### Commenting Out Modules

Modules can be disabled by prefixing lines in .toc with `#`:

```
#modules\infobar\init.lua
```

Currently, infobar and several class resource modules are disabled this way.

## Important Notes

- **Combat Lockdown**: Many frame operations require `InCombatLockdown()` checks
- **Addon Namespace**: Always use `DraeUI` table, not global variables, to avoid conflicts
- **oUF Framework**: Custom frames must follow oUF's element and update pattern
- **Font Updates**: Global font changes happen in PLAYER_ENTERING_WORLD event
- **Screen Coordinates**: Use `DraeUI.screenHeight`, `DraeUI.screenWidth`, `DraeUI.uiScale` for scaling
