# Quest XP data

`quest_xp_data.lua` contains factual Classic quest IDs, levels, and base XP
rewards extracted from Questie's generated `xpDB-classic.lua`, as distributed
in the local QuestieDB support data on 2026-09-28. Comments and loader code
are omitted. Source project: https://github.com/Questie/Questie

The table is bundled with XP Tracker Pro; neither Questie nor QuestieDB is a
runtime dependency. Reward estimates target Classic Era, not seasonal XP
multipliers. Missing quest IDs are reported as unknown, not silently zeroed.

## Completion requirements

`quest_requirements.lua` contains generated numeric facts for all 3,494 quests
in the XP table. Source: CMaNGOS Classic DB (a community-maintained 1.12 data
snapshot, not a live Blizzard API):
https://github.com/cmangos/classic-db/tree/ec4f596146be6467ea93c57397858e329e2db852

Input: `Full_DB/ClassicDB_1_12_1_z2815.sql.gz`; SHA-256:
`4f92db520868ab4e566726f68b5b2e380ae781209beaf22237b4f7f04600d0c0`.
The generator extracts only IDs, requirement classifications, money costs and
objective counts; no quest dialogue, SQL scripts, or upstream program code is
included. Run `python scripts/generate_quest_requirements.py` to reproduce it;
`--source PATH --check` verifies an existing download and generated output.

Turn-in-only classification excludes objective requirements, scripted starts,
event/exploration flags, timers, reputation objectives, conditions, end-event
text and required source items. All other special cases require native
completion. Live failed/unfinished states and money requirements take precedence.
New or changed quests may require a data refresh; absent data stays unknown.
