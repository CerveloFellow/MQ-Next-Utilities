# MQ-Next-Utilities
Utilities I've written for Everquest(Project Lazarus) MacroQuest Next

MoveUtil.lua - provides some utilities for using MQ2MoveUtils and MQ2Nav navigate to targets and locations.  This is a library included in other files below.  
LootSettingUtil.lua - provides some utilities for managing the Loot Settings.ini file. This is a library included in other files below.  
BankUtil.lua  - provides some bank utilities that allow for autobanking items from your inventory.  See lua code for commands that it makes available.  
SellUtil.lua - provides some utilities for managing Loot Settings.ini along with autosell and autodrop features.  Se the lua code for the commands and events it makes available.  
  
To use with Project Lazarus, download these files into your E3_RoF2\lua folder.   
 Within Everquest you can run:  
  /lua run SellUtil  
  /lua run BankUtil  

**Note** Both SellUtil and BankUtil use some of the same binds, so running them together will give you an error about the binds(slash commands in game). I'm probably going to combine these into a single library to avoid that if there is enough interest.
