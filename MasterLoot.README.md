# MasterLoot.lua

A MacroQuest (MQNext) Lua utility to streamline master looting when multiboxing with E3.

**Repository:** [https://github.com/CerveloFellow/MQ-Next-Utilities](https://github.com/CerveloFellow/MQ-Next-Utilities)  
**Main File:** `MasterLoot.lua`

---

## Overview

This script solves a common pain point when running multiple bots: looting takes forever after clearing groups of mobs. Each character normally has to check every corpse for class-specific gear, especially when entering a new tier.

MasterLoot.lua centralizes and automates much of this process, reducing the workload on your main character.

---
## Configuration Settings

The first time you run the script, if an INI file is not present, one will be created with default values and the script will exit automatically.

|Key|Value|
|------------|-------------|
|**[ItemsToKeep]**|Any items in this list are always looted by any character who loots with Master or Peer Looting|
|**[ItemsToShare]**|Any items in this list are always ignored and will be listed in the loot window to use with Queue Item and Loot Item(s) |
|**[ItemsToIgnore]**|Any items in this list are always ignored and will never be looted|
|**[Settings]**|This section contains configurable options for MasterLoot.lua|
|**useWarp(true|fase)**|True will use MQMMOWarp commands to warp to corpses, false will use MQNAV commands to navigate to corpses|

## Features

### Master Loot
- Automatically loots all "safe" items (anything not No Trade or No Drop)
- Includes a hardcoded list of high-priority items (e.g., advancement orbs)
- After completion, displays remaining No Trade/No Drop items that may be usable by multiple classes in your group

### Peer Loot
- Non-master group members automatically loot only items that no one else in the group can use
- Ideal for quickly picking up class-specific tier gear

### Queue Item
- After master looting, select a group member and an item from the displayed list
- Queue the item for that character to loot (ignores No Trade/No Drop restrictions)

### Loot Item(s)
- Commands the selected character to loot everything currently queued for them

---

## Important Notes

- This is an **early, rough version**—expect bugs
- Some corpses may not be immediately lootable; use the `#corpsefix` command as a workaround
- After queuing items, you may need to click **Loot Item(s)** again for any remaining queued items
- **Debug command:** `/ti` shows the current queue (ItemID + CorpseID). An empty list means all queued items were successfully looted

---

## Future Plans

- Add INI configuration (window position, always-loot lists, etc.)
- Integrate better navigation options (MQNav or alternatives to MQ2MMOWarp)
- Additional polish and features

---

## Requirements

- **MQ2MMOWarp plugin** (required for warping to corpses during looting)

---

## Installation & Usage

1. Place `MasterLoot.lua` in your MacroQuest `/lua` folder
2. Start the script with:
   ```
   /lua run MasterLoot
   ```

---

## Feedback & Contributions

This is still very much a **work in progress**. Feedback, bug reports, and testing are greatly appreciated!

If you're comfortable with Lua and would like to help improve it, let me know—I'm happy to grant repository access for contributions.

**Enjoy faster looting!**
