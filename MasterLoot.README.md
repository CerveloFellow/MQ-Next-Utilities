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
|**useWarp(true\false)**|True will use MQMMOWarp commands to warp to corpses, false will use MQNAV commands to navigate to corpses|
|**LootStackableMinValue**|The minimum value in copper for a stackable item to always be looted|
|**LootSingleMinValue**|The minimum value in copper for a single item to always be looted|

## Features

### Loot
- Select a group member from the radio buttons and that group member will start looting any corpses that it has not looted
- The group member will only loot items that no one else in the group can use, or items that can be traded to each other
- The INI file settings will be applied
- -Any ItemsToKeep are ALWAYS looted by any of the looters
- -Any ItemsToShare are never looted and reported to the loot window
- -Any ItemsToIgnore are not looted and ignored.

### Queue Shared Item
- After master looting, select a group member and an item from the displayed list
- Queue the item for that character to loot (ignores No Trade/No Drop restrictions)

### Loot Item(s)
- Commands the selected character to loot everything currently queued for them

---

## How to use

After all the mobs are dead, I will typically use Peer Loot for all of my bot characters which will have them go through and loot any items that only they can use, or are in the [ItemsToKeep] section.  Next i will do Master Loot with my main character who will loot only things that they can use similar to Peer Loot.  Master Loot will make a list of items that are usable by 2 or more people in your group and display them in the listbox in the window, and also print them out to your group(/g) chat.  From there you can inspect objects and determine which character you want to loot it.  You would select the character's radio button, select the item in the list box, and then press the Queue Item button which will add it to that characters queue to loot(while removing it from the list).  Once all items are queued up, you select a character and press the Loot Item(s) button to send the character off to go loot the items in their queue.
---

## Important Notes

- This is an **early, rough version**—expect bugs
- Some corpses may not be immediately lootable; use the `#corpsefix` command as a workaround
- After queuing items, you may need to click **Loot Item(s)** again for any remaining queued items

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
