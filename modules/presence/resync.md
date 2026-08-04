# Re-syncing Presence with HorizonSuite

Presence is ported from **HorizonSuite** by Crystilac, MIT licensed — see
`LICENSE.HorizonSuite`. Upstream source: _TODO: record the repository URL._

The port is deliberately uneven. Four files are still close to verbatim so they can be
diffed against upstream; everything else has been rewritten against draeUI's own API and
should not be compared.

## Still close to verbatim

| draeUI | upstream |
|---|---|
| `core.lua` | `PresenceCore.lua` |
| `quest.lua` | `PresenceQuest.lua` |
| `scenario.lua` | `PresenceScenario.lua` |
| `achievement.lua` | `PresenceAchievement.lua` |

These are excluded from StyLua in `.styluaignore`, for the same reason `libs/` is:
reformatting them turns every re-sync into a whole-file conflict.

They spell the module `addon` and reach everything through it:

```lua
local addon = DraeUI:GetModule("Presence", true)  -- draeUI: was _G.HorizonSuite
```

`init.lua` is therefore two things at once — the AceAddon module, and the host table
those four read as `addon`. Anything they need that isn't a plain draeUI call lives
there: the config accessor, the inert logger, and a few real helpers.

Every intentional divergence inside these four is marked with a `-- draeUI:` comment.
**Grep for `draeUI:` before re-syncing** — those are the lines that have to be carried
forward by hand.

## Rewritten — do not diff against upstream

| draeUI | upstream | note |
|---|---|---|
| `init.lua` | (no equivalent) | AceAddon module + host table |
| `blizzard.lua` | `PresenceBlizzard.lua` | uses `:Suppress()` / `:Restore()` from `functions/toolkit.lua` |
| `errors.lua` | `PresenceErrors.lua` | |
| `events.lua` | `PresenceEvents.lua` | |
| `zone.lua` | `PresenceZone.lua` | |

## Where draeUI's versions of things live

- **Settings** — `DraeUI.config["presence"]` in `config/config.defaults.lua`. Upstream's
  saved-variables database has no equivalent here; draeUI has no database at all.
- **Colours** — `config.general.colours.quest` (reached as `QUEST_COLORS`), plus
  `bossEmote`, `discovery` and `zone`.
- **Strings** — `DraeUI.L`, from `config/locale.enGB.lua`.
- **Fonts** — `DraeUI.SetFont` in `functions/functions.lua`, which is where upstream's
  `SetSafeFont` pattern ended up.
- **Game-state queries** — `functions/game.lua` (`IsInPartyDungeon`, `IsDelveActive`,
  `GetQuestBaseCategory`, …).
- **Logging** — upstream's tag-filtered logger with a docked panel has no equivalent, so
  `Presence.Log` in `init.lua` is inert. It can't be nil: `core.lua` indexes it at file
  scope, and a nil index there aborts the rest of the file and takes its exports with it.

## Procedure

1. Fetch the new upstream and diff it against the four verbatim files.
2. Apply upstream's changes, re-applying every `-- draeUI:` line by hand.
3. Check whether anything upstream added reaches for a helper that only exists on their
   side — if so it goes into `init.lua`, not into the verbatim file.
4. `mise run lint`. Do **not** run `mise run fmt` expecting it to touch these four; they
   are ignored on purpose.
5. In-game: zone change, subzone discovery, quest accept/complete, achievement, level up,
   scenario start/update/complete. Toggle a `config.presence.toasts.*` key off, `/rl`,
   and confirm Blizzard's own frame comes back — that is the `:Restore()` path.
