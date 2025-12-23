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
- Any ItemsToKeep are ALWAYS looted by any of the looters
- Any ItemsToShare are never looted and reported to the loot window and these items should be linked in group chat so you can inspect them
- Any ItemsToIgnore are not looted and ignored.
- Any items that are flagged as ItemsToShare or can be used by other group members will be sent to the Loot Window

### Queue Shared Item
- When you select an item from the Loot Window, select a character and press this button, it will queue that item up for the character to loot
- Multiple items can be queued to multiple characters before sending them off to loot them

### Get Shared Item(s)
- Commands the selected character to go and loot the items that were queued up from the Queue Shared Items button

---

## How to use

I typically have each character go through and loot, usually my driver character first.  
---

## Important Notes

- This is an **early, rough version**—expect bugs
- There are issues with trying to open the loot window.  #corpsefix is used judiciously in the code along with retries.  That being said there are still instances where a character cannot loot a corpse and the character should report that it cannot loot that corpse.
- You can issue the "/g mlru" command which will tell each character to report unlooted corpse numbers.
- If a character cannot loot a corpse you might have to manually target and loot the corpse.  use /target t <corpseId>, /warp t, /loot.  Sometimes you can reissue the Loot or Get Shared Item(s) command and they will loot on retry.

---

## Requirements

- **MQ2MMOWarp or MQ2Nav** - these are used to move around using /warp loc y x z or /nav locxyz x y z commands.

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
