# Embedded settings libraries

AceGUI-3.0 and AceConfig-3.0 are embedded from https://github.com/WoWUIDev/Ace3
at commit `a3604956e6e98a2b41144e7dbffadb21b917f828`. These versions fix tooltip
opacity arguments and support numeric Blizzard Settings category IDs.
The Ace3 license is included in `Ace3-LICENSE.txt`.

All runtime libraries load from this addon folder via `../XPTrackerPro.toc`.
No separate addon is required. Include the entire `libs` folder when packaging.
The old `AceConfig-3.0 copy` directory is unused and is not loaded by the TOC.
