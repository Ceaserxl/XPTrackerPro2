# XP Tracker Pro 2.0

Classic Era leveling dashboard with a charcoal frame, gold trim, purple XP fill,
blue rested overlay, and separately aligned statistic rows.

## Controls

- Drag the header to move the window; position is saved.
- Header minus/plus: compact view. Cog: settings. Close: hide.
- Minimap left-click or `/xtp`: toggle the window.
- Minimap right-click or `/xtp config`: settings.
- `/xtp lock`: lock/unlock movement.
- `/xtp compact`: switch between full and compact views.
- `/xtp reset`: clear tracked session XP, time, gold, and sample averages.
  Lifetime and current-level played time are not reset.

The window has a fixed width of 280 UI units at the default frame scale of 1.
Larger statistic text and tighter padding keep the display readable and compact.
Settings retain all previous statistic and bar toggles, plus frame scale,
background opacity, compact view, movement lock, minimap visibility, and a
Center Window action. Reset Session in settings requires confirmation.

## How the numbers work

- **XP gained:** positive changes in the player's XP bar, including exploration.
  Level overflow includes the unfinished portion of the previous level.
  Chat and quest events do not increment the session total.
- **Kill average:** the latest 10 recognized kill rewards, matched against
  Blizzard's localized named-kill formats, including rested/group variants.
  Generic XP messages and quest turn-ins cannot enter this average.
- **Quest average:** the latest 10 positive QUEST_TURNED_IN XP rewards.
- **XP/hour:** session XP multiplied by 3,600, divided by online session seconds.
- **Kills/quests remaining:** remaining XP divided by the respective average,
  rounded up. These are estimates; enemy levels, rested bonuses, and quest
  rewards vary.
- **Time to level:** remaining XP divided by session XP/hour. Shows -- without
  a positive rate or at the level cap.
- **Session time:** online time including idle time. Offline time is excluded.
- **Played time:** the game's TIME_PLAYED_MSG snapshot plus online elapsed time.
  Total and level clocks have independent timestamps. Unknown values show --.
- **Gold:** net money received minus money spent while tracking; negative values
  are expected after purchases or repairs. Rates use online session time.
- The window and minimap tooltip use the same snapshot and row definitions.

Existing character sessions and profile preferences are retained. Historical
numbers produced by older versions cannot be reconstructed. Reset the session
if those numbers include previously misclassified quest XP. Reset-on-login also
applies to UI reloads, as in the prior version.

## Validation

`tests/regression.lua` exercises the calculations, mocked event handling,
saved state, settings, minimap, and layout row behavior. From this folder:

```text
lua tests/regression.lua
```

The first-party files target Lua 5.1. The automated suite does not render WoW
fonts/textures or execute Blizzard's actual event system.

In game, enable Lua errors with `/console scriptErrors 1`, then `/reload`.
Check dragging/locking, compact view, all settings, and the minimap tooltip.
Gain kill, quest, and exploration XP; compare session XP with the XP bar.
Test a level-up, spending/receiving money, and a logout/login. Confirm quest
turn-ins leave the kill average unchanged and the two displays agree.

Localized format reference:
https://github.com/Ketho/BlizzardInterfaceResources/blob/classic/Resources/GlobalStrings/enUS.lua
