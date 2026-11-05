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
  - `game.lua`: Game-state queries - `CanAccessValue`, `IsInPartyDungeon`, `IsProtectedInstance`, `IsDelveActive`, `GetActiveDelveTier`, `GetDelveName`, `IsQuestWorldQuest`, `GetQuestFrequency`, `GetQuestBaseCategory`
  - `toolkit.lua`: Methods mixed into the Frame/Texture/FontString metatables - `:Kill()`, `:StripTextures()`, and the reversible `:Suppress()` / `:Restore()` pair (plus `DraeUI.IsSuppressed`)

`IsProtectedInstance` is deliberately coarser than `IsInPartyDungeon`: it answers "am I
somewhere Blizzard hands out secret values freely" (raids and Mythic Keystones), and callers
use it to skip a query entirely rather than to branch on its result.

Shared *skinning* helpers are not here - they live in the Skins module, which owns
`DraeUI.CreateBorder` and `DraeUI.CreateOverlay`. Beyond those there is no backdrop,
gradient, or pixel-perfect helper - backdrops are hand-rolled at each call site, and scaling
uses `DraeUI.screenWidth` / `screenHeight` / `uiScale` directly.

### Module System

Modules are initialized through AceAddon's `:NewModule()` and loaded via the .toc file:

- **unitframes/** (modules/unitframes/): Core unit frame functionality
  - `init.lua`: Spawns all unit frames using oUF:Spawn()
  - `common.lua`: Shared frame element setup
  - `castbar.lua`: Cast bars. A replica of Blizzard's player cast bar (their "CLASSIC"
    look) on the target and focus frames, built as oUF Castbar elements from the
    `ui-castingbar-*` atlases and their font objects. Only size and placement are
    draeUI's, from `config.castbar`. The player keeps Blizzard's own
    `PlayerCastingBarFrame`. **Do not try to instance `CastingBarFrameTemplate`
    instead** - see the taint note below
  - `tags.lua`: Custom oUF tags
  - `units/*.lua`: Individual unit styles (player, target, pet, focus, boss, etc.)
  - `classpower.lua`: One resource bar for every class, drawn as chi orbs. oUF's own
    ClassPower element decides which resource a spec actually has - the per-class
    tables this used to keep drifted, because several class powers are aura stacks
    with no power ID at all. `PostUpdate` here is purely the orb animation
  
- **buffbar/** (modules/buffbar/): Aura tracking system
- **skins/** (modules/skins/): Two jobs. It lays down the static decorative artwork (the
  actionbar surround and the micro menu), and it is the home for the addon's shared skinning
  helpers, exported onto the namespace: `DraeUI.CreateBorder(frame, size)`, the 8-piece
  nine-slice from `media/textures/unitframe.tga` that both the unit frames and the minimap
  frame themselves with, and `DraeUI.CreateOverlay(...)`. It loads before both consumers,
  which is what makes those exports safe to call. New decoration helpers belong here rather
  than hand-rolled at a third call site.
- **minimap/** (modules/minimap/): A square skin on Blizzard's minimap, built **in place**.
  The Minimap is never reparented out of MinimapCluster and never resized, so Edit Mode keeps
  owning both position and size and `infobar.right.relTo = "MinimapCluster"` keeps measuring
  something real. Both are load-bearing - see the header of `minimap/init.lua`, which records
  what reparenting costs and why forcing `SetSize` is a fight not worth having. Carries
  zone/clock/difficulty readouts, four indicator buttons in two bordered columns down the
  map's left edge, an addon-button bin, a friends roster and a middle-click micro menu.
  Every tooltip body is a plain `Fill(tooltip)` matching an infobar plugin's `OnTooltip`, so
  any of these readouts can move to the infobar as a file move rather than a rewrite.
  `/draeui minimap` dumps what MinimapCluster is drawing, with ours marked - Blizzard renames
  those regions between expansions, so identify rather than guess.

  An M+ teleport flyout was built here and **removed**. There is no API mapping a dungeon to
  its teleport spell, so it had to match `C_ChallengeMode.GetMapTable()` names against the
  player's spellbook, and that never worked reliably. Don't rebuild it without a real
  dungeon-to-spell source.
- **skins/** (modules/skins/): Static decorative UI artwork (actionbar surround, minimap ring, micro menu)
- **infobar/** (modules/infobar/): FPS, latency, durability, gold, XP/reputation and Rebirth-charge readouts in the strip between the micro menu and the minimap. See the registration contract below. Restored from `55e4c81^` and brought up to 12.0 — fps, latency, durability and gold are confirmed working; the res plugin has never been exercised in a raid or M+, so treat it with suspicion.
- **presence/** (modules/presence/): Cinematic centre-screen toasts for zone changes, quests, achievements, level ups and scenarios, replacing Blizzard's zone text and banner frames. Ported from HorizonSuite (MIT). `init.lua` is both the AceAddon module and the host table the four still-verbatim `core/quest/scenario/achievement` files read as `addon`. Those four are StyLua-ignored so they stay diffable against upstream; every deliberate divergence in them carries a `-- draeUI:` comment.
- **damagemeter/** (modules/damagemeter/): Stacked bar windows over Blizzard's
  `C_DamageMeter`.

  **There is no combat log parsing here and there should never be any.**
  `COMBAT_LOG_EVENT_UNFILTERED` is not a viable meter source in 12.1 - Details! and
  EllesmereUIDamageMeters have both migrated off it. Blizzard aggregates the session,
  attributes pets to their owner and returns `combatSources` already sorted; re-sorting
  would mean comparing secret amounts, which throws. `data.lua` is the only file that
  touches the API, which is what keeps the secret-value rules in one place. The others are
  `init.lua` (module, window registry, `ShowTip`, combat state machine, `Report`),
  `window.lua`, `rows.lua`, `menu.lua` and `tooltip.lua`.

  Blizzard's own meter window is turned off at enable with
  `SetCVar("damageMeterEnabled", 0)`. That CVar governs their UI, not the collection - the
  API keeps working.

  Windows are placed from `config.damagemeter.windows` and are **not draggable**, since
  nothing in draeUI saves a setting. A window's height is never set: it derives from
  `window.rows` and the row and header sizes, so a window can't show part of a bar. Each
  window's readout is a key of `Enum.DamageMeterType` and its segment is Current, Overall
  or a past fight; config sets only the starting state, and the header menus change either
  at runtime.

  **Known gap: Feign Death registers as a death.** `C_DamageMeter` gives a feign a valid
  `deathRecapID`, so a hunter feigning shows up in the Deaths readout.

  `test.lua` stands in for the API when `/draeui meter test` is on, so the windows can be
  judged without a group. It is optional - every getter in `data.lua` asks for it and
  copes with it being absent, so dropping its .toc line costs the command and nothing
  else. Its fake segment IDs are negative, which is how leaving the mode knows to clear
  them off a window.

### Library Dependencies

Located in `libs/` and loaded via libs.xml:

- **oUF**: Unit frame framework (custom embedded version: `DraeUI.oUF`)
- **Ace3**: AceAddon-3.0, AceEvent-3.0
- **LibStub**: Library management
- **LibSharedMedia-3.0**: Media (fonts, textures, sounds) management

LibDataBroker-1.1 used to be here for the infobar and is **gone** — see the infobar
section. Don't reintroduce it: the bar has its own registry, and LDB's conventions
never fitted what the plugins actually emit.

## Key Conventions

### Code Style — StyLua is authoritative

**Don't hand-format. Run `mise run fmt` before committing and `mise run fmt:check` to
verify.** The whole addon was reformatted in `d0fbb1d`, so a clean tree is a fixed point:
`stylua .` is a no-op, and `fmt:check` passing is a real gate rather than an aspiration.
Format-on-save is enabled in `.vscode/settings.json` and should stay that way.

The addon previously wrote guards as `if (cond) then`. **That style is gone** — StyLua
strips the redundant wrapper and has no option to preserve it, so writing new code that way
just creates churn on the next format. Write `if cond then`. Parens that actually affect
grouping or readability inside a condition are kept, so `if a and (b or c) then` survives
untouched.

Settings live in `stylua.toml`, and each one is a measured optimum rather than a taste call
— the file records the numbers. Don't tune them casually.

Two escape hatches, in order of preference:

- **`-- stylua: ignore start` / `-- stylua: ignore end`** around a block whose hand-alignment
  is worth keeping (a colour table in columns, say). Verified working; the markers
  themselves must sit at the indentation StyLua expects for that scope, or it reformats the
  marker line.
- **`.styluaignore`** for whole files that must stay byte-comparable with upstream. It
  currently covers `libs/`, `.tools/`, and the four verbatim `modules/presence/` files.
  Adding to it is a decision about provenance, not about style.

### Comments — describe the code, not its history

**A comment says what the code does.** A function opens with a one-line statement of purpose,
and any parameter whose meaning isn't visible from the call site is named and explained.
`DraeUI.CreateFontObject` in `functions/functions.lua` is the model: purpose, then what the
options mean, then an example where one helps.

**A constraint survives as a rule, never as a story.** "Don't do X, it causes Y" earns its
place — it stops the next person reintroducing a bug. "X is what we tried first and it cost a
frame rate" does not: the reader needs the constraint, not the diary. The two bullets in
`castbar.lua`'s `SuppressBlizzardCastBars` are the right shape — each names a call not to
make and the error it produces, and stops there.

**Be short.** One or two `--` lines is the default. A `--[[ ]]` block is for something that
genuinely needs a paragraph, and four to six lines is its ceiling; past that you are arguing
for the code rather than describing it. State the constraint and stop — the reader doesn't
need the reasoning chain that got you to it. Say it once, too: if a rule already sits at the
call site that depends on it, a second copy in the file header is a pointer, not a comment.

So, concretely, these do **not** belong in a comment:

- what an earlier version of this code did, or which round of work fixed what
- how a bug was found, how long it took, or what was tried and rejected
- comparisons to upstream or another addon that don't change what you'd write here
- a restatement of a signature or a name the next line already shows
- a pointer to where something else lives

and these do:

- secret values, taint, and the secure trust chain — the rules in "Secret Values and Taint"
  below are the reason several files look over-cautious
- any place Blizzard's behaviour forces an unobvious shape (idempotent re-assert hooks, LoD
  frames that don't exist at login, `SetPoint` hooks that must no-op when nothing moved)
- a known gap, so it arrives as a documented limitation rather than a bug report
- a number or offset that is Blizzard's rather than ours, and what it assumes

Density is a symptom rather than the target, but it locates the line: the files converted to
this style run 13–25% comment lines — `modules/unitframes/common.lua` at 18%, `castbar.lua`
at 25% because it is largely a transcription of Blizzard's template. Anything still in the
thirties or forties predates the style and is a candidate, not an example. Verbatim reference
material doesn't count against it: the animation XML quoted in `classpower.lua`, and the four
upstream `modules/presence/` files.

Judge a comment by whether it changes what the next person writes.

### Addon Namespace Pattern

```lua
local addon, DraeUI = ...
local oUF = DraeUI.oUF or oUF
```

All files use this pattern to access the shared namespace table. The addon name is usually unused; `DraeUI` is the primary reference.

### Settings — there is no database

**No setting is ever saved.** Every setting lives in `config/config.defaults.lua`, a
hand-edited table read directly at the point of use. There is no options UI, no accessor
function, and no per-call-site defaults.

There is exactly one saved variable, and it holds *data*, not settings: `draeUIDB`, wired up
in `DraeUI:OnInitialize` and exposed as `DraeUI.dbGlobal`. Three consumers, each owning its
own top-level key:

- the infobar's **Coin** plugin — `gold[realm][character] = copper`, so its tooltip can total
  the realm
- the infobar's **Experience** plugin — a rolling XP-per-hour average, so a `/reload` doesn't
  throw it away
- the **minimap**'s zoom level, when `minimap.zoom.persist` is on

The line each of those sits on the far side of is *data the player produced by playing*, not
a setting. If you can't imagine hand-editing it, it belongs here; if you can, it belongs in
`config.defaults.lua`.

Deliberately **not** AceDB — that library was dropped for doing nothing but writing an empty
file on logout, and is no longer in `libs/`. A plain table is enough because every consumer
guards its own access with `x = x or {}`, so there are no defaults to merge. Add a fourth the
same way rather than reintroducing a defaults mechanism.

### Configuration Access

Access config via `DraeUI.config["section"].property`:

```lua
DraeUI.config["frames"].playerXoffset
DraeUI.config["general"].font
```

### Infobar plugins — registration is the contract

**To add a readout: drop a file in `modules/infobar/plugins/` and add one `.toc` line.
That is the whole list.** There is no manifest to update, and nothing to remember when
retiring one — deleting the file and its `.toc` line leaves nothing behind. That's the
point of the design: expansion-specific readouts (azerite power, artifact weapons) come
and go, and the previous `initOrder` list meant a plugin missing from it was created,
parented and then *silently never positioned*, sitting at the frame origin.

```lua
local plugin = InfoBar:Register("FPS", { order = 10 })

plugin.OnTooltip = function(tooltip) tooltip:AddLine("…") end
plugin.OnClick = function(frame, button) end

plugin:SetText("30fps")
```

`Register` runs at file load, long before the bar exists, so it returns a *handle*
rather than a frame — and the handle is also the value store. Every setter writes its
field first and touches a widget only if one exists, which is why a plugin can push
values from its `OnInitialize`. Frames are built in `InfoBar:OnEnable`.

Handle methods: `SetText`, `SetShown`, `SetBar(name, cur, min, max)`, `SetBarColor`,
`SetBarShown`, `RefreshTooltip`, `Resize`. Callbacks: `OnTooltip(tooltip)`, `OnEnter`,
`OnLeave`, `OnClick`.

- **`order` is spaced in tens.** Slot a new readout between two existing ones by picking
  35, rather than renumbering. Ties break on name, since `table.sort` isn't stable.
- **Tooltips are framework-owned.** Provide `OnTooltip` and add lines; owning, anchoring
  and showing is done for you. `GameTooltip` should not appear in a plugin file.
  `RefreshTooltip()` is a no-op unless that plugin currently owns the tooltip, so a
  plugin's existing update tick can drive a live tooltip with no extra timer.
- **Register unconditionally and self-hide** with `SetShown(false)` when there's nothing
  to say — what `xp.lua` does at max level and `res.lua` does outside instanced content.
  Retiring such a plugin is then just deleting the file.
- Setters skip unchanged values, and that guard is **secret-safe** via
  `DraeUI.CanAccessValue` — `res.lua` can set a secret string as its text.

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

### oUF keeps its own state private

**A unit frame's unit is `frame.__unit`.** There is no `frame.unit` — oUF stopped writing
one, and nothing else does either. It is set before the style function runs, so it's
readable at style time as well as from a callback. The one place a plain `.unit` is still
needed is Blizzard's `UnitFrame_UpdateTooltip`, which reads it; `common.lua` fills it in
from its `OnEnter` wrapper rather than keeping a copy that would go stale on a vehicle swap.

**An element's working state is not on the element.** Each element module keeps a table
keyed by widget, so `Castbar.channeling`, `Castbar.notInterruptible`, `Castbar.holdTime`,
`ClassPower.__max`, `Power.cost` and friends all read `nil` from a layout. Nothing errors —
the value is simply absent, which is what makes this class of breakage look like a
rendering bug. What a layout gets instead:

- **the `Post*` callback arguments**, which is where most of it moved. Check the parameter
  list in the element source before trusting a signature; several gained arguments in the
  middle (`ClassPower:PostUpdate` now passes `hasCurChanged` ahead of `hasMaxChanged`).
- **the API**, re-read the way the element reads it. `castbar.lua`'s `SyncCastType` is the
  model: it derives cast/channel/empower from `UnitCastingInfo`/`UnitChannelInfo` with the
  same precedence oUF uses, so the two can't disagree.
- **the documented `Override`/`OnUpdate` hooks**, when behaviour rather than a value is
  what's wanted. `Castbar` installs `element.OnUpdate` in place of its own, which is how
  the cast bar keeps its fade-out alive now that `holdTime` is unreachable.

Health prediction is no longer an element. Its widgets are **PascalCase sub-widgets of
Health** — `TempLoss`, `HealingAll`, `HealingPlayer`, `HealingOther`, `DamageAbsorb`,
`HealAbsorb`, `OverHealIndicator`, `OverDamageAbsorbIndicator`, `OverHealAbsorbIndicator`.
oUF looks each name up and skips what it can't find, so a misspelled one leaves the bar
built, unsized and permanently full instead of erroring. The over-indicators are driven by
`SetAlphaFromBoolean`, never `Show`/`Hide`, so they must be created at alpha 0.

**Known gap: `frame.Health` is not a fixed rectangle.** `UF.CreateHealthBar` follows oUF's
own layout — the `TempLoss` bar holds the size and placement, and the health bar's
BOTTOMRIGHT is anchored to `TempLoss`'s *fill*. So once a unit's max health is temporarily
reduced, `frame.Health`'s RIGHT, TOPRIGHT, BOTTOMRIGHT, TOP, BOTTOM and CENTER all move
with it. LEFT and BOTTOM don't, which is why the power bars and aura anchors hang off
TOPLEFT/BOTTOMLEFT and are unaffected. What *is* affected, and is accepted rather than
fixed: the player frame's health backdrop and border, the name-text containers on
focus/focustarget/pet/target/targettarget, the raid target icon, and any cast bar with
`relTo = "Health"` all contract with the bar. `frame.Health.TempLoss` is the full
rectangle if one of these ever needs pinning down.

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
(`healthPrediction`, `auraBorder`, `healthText`, and Presence's
`quest`/`bossEmote`/`discovery`/`zone`) is read directly at the point of use.

The one key in there that isn't a colour is `colours.atlas`, the power-atlas allowlist —
it lives alongside `colours.power` because it decides which powers get artwork *instead*
of a tint. See "Power Bar Atlases" below.

The cast bars are the one part of the UI with no entry here at all - every colour on
them is baked into Blizzard's fill atlases.

Rules for the oUF subset:

- **Mutate, don't assign.** The applier calls `:SetRGB()` on the ColorMixin oUF already
  built. oUF aliases numeric power-type IDs to the *same objects* as the string tokens
  (`colors.power[0] == colors.power.MANA`), so assigning a fresh colour to the token
  orphans the numeric key and elements that look up by ID get Blizzard's original. This
  is why config keys power by string token only — the numeric aliases follow for free.
- **`dispel` used to be the exception; it no longer is.** Since the 12.1 aura rewrite oUF
  builds `colors.dispel` from `AuraUtil.GetDebuffDisplayInfoTable()` as its own
  `oUF:CreateColor` objects, keyed by dispel **name** ("Magic", "Curse", …) rather than a
  numeric `oUF.Enum.DispelType` index — that enum is gone. So it mutates like everything
  else, and there are no Blizzard-shared `DEBUFF_TYPE_*_COLOR` globals left to protect.
  The `dispelColorCurve` snapshot is gone too, but **the applier still runs in
  `DraeUI:OnEnable` ahead of `UF:OnEnable`**: the table is handed to Blizzard as an
  `AuraButton`'s `customDispelColorMap` at button creation, and whether that reads live or
  copies C-side is unverified.
- There is deliberately **no `None` entry**. The old step curve resolved a dispel-less aura
  to `None` rather than nil, so one had to be supplied to stop `DEBUFF_TYPE_NONE_COLOR`
  tinting every ordinary debuff border. `AuraButton` has no such fallback.
- **Never override `class`.** oUF rebuilds `colors.class` from a `CUSTOM_CLASS_COLORS`
  callback with fresh objects and would discard any override.
- Overrides are partial — any key left out keeps oUF's Blizzard-derived default.

### Power Bar Atlases

Power elements set `colorPowerAtlas = true` unconditionally. oUF then swaps the bar to
Blizzard's own artwork whenever `colors.power[token]:GetAtlas()` is non-nil, and otherwise
restores the bar's original texture and applies the config colour. That original is
snapshotted from the bar itself when the element is enabled, so **the only thing a power
bar has to do is call `SetStatusBarTexture` before it's handed to oUF** — there is no
`__texture` field to set any more. When an atlas is used the bar is drawn at
`SetVertexColor(1, 1, 1)`, so `colours.power` is ignored for that power.

**Which powers get one is controlled by `general.colours.atlas`, an allowlist of tokens.**
Blizzard ships an atlas for nearly every power type, but most are just the stock HUD bar
recoloured, so the applier in init.lua **clears `.atlas`** on everything not in the list —
that is what sends a power down the fallback path. Clear the field directly; `SetAtlas(nil)`
errors, as it validates through `C_Texture.GetAtlasInfo`. Everything that shipped with one
is recorded in `DraeUI.powerAtlases` first, for auditing the list.

All of this depends on the applier mutating colours rather than replacing them — oUF
attaches the atlas to the colour object it built from `PowerBarColor`, and assigning a
fresh `oUF:CreateColor()` over it silently drops the atlas.

### Secret Values and Taint

Separate rules, all of which this codebase has been bitten by.

**You cannot branch on a secret value.** `if secret then` from addon-tainted execution
errors with *"attempted to perform boolean test on ... (a secret boolean value)"*. You
*can* still hand one to a widget setter, and that's the intended escape hatch:
`Region:SetAlphaFromBoolean(value, ifTrue, ifFalse)` and
`Region:SetVertexColorFromBoolean(value, ifTrue, ifFalse)` — both live on `Frame` too,
since `Frame : Region`. `DraeUI.CanAccessValue` (functions/game.lua) is the last resort
for when you genuinely have to read one; it returns false rather than erroring.

The live example is `notInterruptible` from `UnitCastingInfo`/`UnitChannelInfo`, which is
secret when the caster is another player and plain otherwise — so this class of bug only
shows up on other players' casts, never your own or an NPC's. oUF drives its castbar
Shield through `SetAlphaFromBoolean` for exactly this reason, and
`modules/unitframes/castbar.lua` drives the uninterruptible fill overlay the same way.

**You cannot iterate a secret-keyed table.** Some Blizzard tables are keyed by
`secretwrap()` values, and `pairs()` over one from
addon-tainted execution errors with *"attempted to iterate a table that cannot be
accessed while tainted"*. Direct indexing still works — only iteration is blocked.

The one this codebase has already hit is `CastingBarTypeInfo` in
`Blizzard_UIPanels_Game/Mainline/CastingBarFrame.lua`. `CastingBarMixin:ShowSpark`,
`HideSpark` and `StopFinishAnims` all iterate it, and those sit on the main cast path,
so **`CastingBarMixin` is unusable from an addon** — including on an instance of
`CastingBarFrameTemplate` you created yourself, and including `SetUnit()`, which reaches
`StopAnims`. Rebuild from the atlases instead; that's what `modules/unitframes/castbar.lua`
does.

The same rule bites teardown: `TargetFrame.spellbar:SetUnit(nil)` errors. Suppress those
bars with a plain `showCastbar = false` field write plus `UnregisterAllEvents()`/`Hide()`.
`:Kill()` is also wrong for them — it reparents, and `TargetSpellBarMixin:AdjustPosition`
reads `auraRows` off its parent.

**Aura data is secret** in combat, encounters, M+ and PvP as of 12.1. Every `C_UnitAuras`
and `C_TooltipInfo` function that reads an aura **by index, slot or instance ID** errors
when an addon calls it while auras are secret — `GetAuraDataByIndex`, `GetAuraSlots`,
`GetAuraDataBySlot`, `GetAuraDispelTypeColor`. Only spell-ID and spell-name lookups
survive, which is why `candidateFilters.includeSpellIDs` is the one exact filter the
buffbar can offer. `SECURE_ACTIONS.cancelaura` is dead for the same reason: it needs an
aura index.

**Combat meter data is secret** in a raid, M+ or PvP, and never secret in the world - so
everything below fires only in group content and never against a target dummy. Three shapes
the damage meter has to write around, all of which look like ordinary Lua:

- **`value or fallback` boolean-tests its left side.** Where a field may be secret, that is
  a boolean test on a secret. Test for genuine *absence* instead: comparing a secret to nil
  throws, so a failed `pcall` on the nil check is the test. `Data.IsAbsent` in
  `modules/damagemeter/data.lua` is the implementation, and `Data.Amount` the wrapper that
  substitutes only for a field that really isn't there.
- **`AbbreviateNumbers` returns a secret string** for a secret amount. It may only reach
  `SetFormattedText`, never concatenation - so build the arguments and let the engine join
  them.
- **Never compute a bar fraction.** `SetMinMaxValues(0, max)` then `SetValue(amount)`, so
  the division happens engine-side. Dividing secrets throws, and zeroing them instead
  leaves every row empty for the whole fight.

The failure signature is worth knowing because it is quiet: a swallowed secret shows up as
rows that are present but grey and blank, not as an error.

### The 12.1 AuraContainer

Both aura displays run on Blizzard's `AuraContainer`/`AuraButton` intrinsics.
`SecureAuraHeaderTemplate` is gone from Mainline. The division of labour is fixed:
**Blizzard owns the data and the behaviour, addons own the presentation.** Anything that
looks like re-implementing enumeration, sorting, throttling or tooltips is a sign of
working against it.

- **Configure everything inside `initializeFrame`.** `AuraButton`s become forbidden to
  tainted code once auras are secret, applied after that callback returns.
- **`ScriptedInput` is a Forbidden Aspect on `AuraButton`.** No `OnEnter`/`OnLeave`/
  `OnUpdate`/`OnClick` — tooltips come from `SetTooltipAnchorPoint`, cancelling from
  `SetCancelAuraButtons` (which calls `RegisterForClicks` itself; don't call it too).
  Cancelling works **in and out of combat**, because the handler is Blizzard's and
  untainted, so it can reach the restricted `C_UnitAuras.CancelAuraByInstanceID`.
- **A container's size is `secretwrap`ped.** Nothing may measure it.
- **`AddAuraGroup` stamps `ForbiddenAspect.UntrustedLayoutScriptExecution` on the
  container**, which blocks addon frames from anchoring to it. The opt-in is inheriting
  `DisableUntrustedLayoutScriptsTemplate` (Blizzard's `ForbiddenAspectTemplates.xml`) on
  the frame doing the anchoring, **at creation** — that's how `DraeUIEnchantBar` anchors
  to `DraeUIBuffBar`.
- **A texture handed to `AddDispelTypeTexture` gains `SecretAspect.VertexColor`, `Alpha`,
  `TexCoords` and `Shown`** — its appearance stops being yours to set. That is why the
  unit frames keep their plain outline as a *separate, unregistered* backdrop frame
  (`button.Outline`) underneath oUF's dispel texture.
- **Container enums are bare globals** — `AuraContainerSortMethod`,
  `AuraContainerSortDirection`, `AuraContainerItemEnchantmentSlot`. *Button* enums are
  `Enum.`-prefixed. Layout uses `AnchorUtil.FlowLayoutAxis` / `AnchorUtil.FlowDirection`,
  and `maximumLineSize` is in **pixels**, not buttons.
- On the oUF side auras are a **meta element**: `frame:CreateAuras(options)` then
  `:AddGroup(filter, options)` / `:AddSlot(filter, options)`. There is no `self.Buffs` or
  `self.Debuffs`. `options.templates` inherits onto the *container*; a group's
  `templateNames` is what reaches the buttons.

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
- `/draeui meter` - Dump the damage meter's state: whether the API is available and why not,
  the `damageMeterEnabled` CVar, session duration, and each window's readout and segment.
  Says which layer is at fault when a window is empty rather than leaving you to guess
- `/draeui meter test` - Toggle fake animated sessions, for judging the windows without a
  group. Every readout is populated and the amounts follow a sine, so bars overtake each
  other and the row pool is exercised

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
6. Modules (BuffBar, Skins, Minimap, Presence, Infobar, DamageMeter, Unitframes)

Two module orderings are load-bearing:

- **Skins before Minimap, DamageMeter and Unitframes.** Skins owns the shared framing
  helpers those three decorate themselves with.
- **Within Infobar**, `init.lua` then `plugin.lua` then the `plugins/` sources, since each of
  those calls `InfoBar:Register` at load. The plugins themselves may be listed in any order -
  placement comes from `order`, not the .toc.

Within Minimap, `init.lua` must come first: it creates the module table, the anchor
vocabulary (`Mod.Place`), the square mouse surface and the tooltip helper that the other six
files read off it. Those six may be listed in any order - none touches another at load, only
at enable, and `OnEnable` calls their `Build` methods in a fixed sequence.

Within DamageMeter, the same contract: `init.lua` first, creating the module table, the
window registry and the tooltip helper the other five read off it. Those five may be listed
in any order.

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
