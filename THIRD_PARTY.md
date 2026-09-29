# Quest XP data

`quest_xp_data.lua` contains factual Classic quest IDs, levels, and base XP
rewards extracted from Questie's generated `xpDB-classic.lua`, as distributed
in the local QuestieDB support data on 2026-09-28. Comments and loader code
are omitted. Source project: https://github.com/Questie/Questie

The table is bundled with XP Tracker Pro; neither Questie nor QuestieDB is a
runtime dependency. Reward estimates target Classic Era, not seasonal XP
multipliers. Missing quest IDs are reported as unknown, not silently zeroed.
