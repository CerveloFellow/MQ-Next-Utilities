# MQ-Next-Utilities
Utilities I've written for Everquest(Project Lazarus) MacroQuest Next

# LUA Scripts
**MoveUtil.lua** - provides some utilities for using MQ2MoveUtils and MQ2Nav navigate to targets and locations.  This is a library included in other files below.  
**LootSettingUtil.lua** - provides some utilities for managing the Loot Settings.ini file. This is a library included in other files below.  
**InvUtil.lua** - Inventory utilities that provides some slash commands to help manage inventory and banking.  

# Usage
To use with Project Lazarus, download these files into your E3_RoF2\lua folder.  
  
 Within Everquest you can run:  
 **/lua run InvUtil**  
  
# Overview
## Binds
- **/abank** - Auto Bank.  When you're near a banker and you issue this command you will walk up to the nearest banker and put any items from your inventory that have been flagged as Keep,Bank into your bank.  **When your bank slots are full or the item is No Storage, it will now be placed back in your inventory where it came from and print a message notifying you of the error.**
- **/adrop** - Auto Drop.  Any items that have been flagged to drop with the **/xitem** command will be automatically dropped on the ground when you issue this command.  
- **/asell** - Auto Sell.  Any items in your inventory that are Flagged as Keep,Sell in your Loot Settings.ini will be automatically sold to the nearest vendor.
- **/bitem** - Bank Item.  While an item is on your cursor and you issue this command, this will flag the item in your Loot Settings.ini as Keep,Bank.
- **/dinv** - Print Drop List.  This will print the items that have been flagged to drop.  
- **/ditem** - Destroy Item.  While an item is on your cursor and you issue this command, this will flag the item in your Loot Settings.ini as Destroy.
- **/dropclear** - Clear Drop List.  Thsi will remove all items from your temporary drop list(any items added with the **/xitem** command).
- **/kitem <###>** - Keep Item.  While an item is on your cursor and you issue this command, this will flag the item in your Loot Settings.ini as Keep.  Optionally you can specify a count for how many to keep.
- **/pbank** - Print Bank.  This will print the items that are stored in your bank.  Primarily used by me for debugging purposes.
- **/pinv** - Print Inventory.  This will print the items in your inventory that have been scanned with **/scaninv**.  Primarily used by me for debugging purposes.
- **/pis** - Print Item Status.  While an item is on your cursor and you issue this command, it will print the status of the item from the Loot Settings.ini
- **/scaninv** - Scan Inventory.  Will run a rescan of your inventory to re-create the inventory array.  Primarily used by me for debugging.
- **/sinventory** - Synchronize Inventory.  This will run through your inventory list and put an entry in your Loot Settings.ini file for the new items.
- **/sitem <###>**- Sell Item.  While an item is on your cursor and you issue this command, this will flag the item in your Loot Settings.ini as Keep,Sell.  Optionally you can specify a count for how many to sell.
- **/skipitem** - Skip Item.  While an item is on your cursor and you issue this command, this will flag the item in your Loot Settings.ini as Skip.
- **/syncbank** - Synchronize Bank.  This will scan your bank and flag any item in your bank as Keep,Bank in your Loot Settings.ini file.
- **/xitem** - Drop Item. While an item is on your cursor and you issue this command, the item will **temporarily** get added to the drop array.  If you have multiple items with the same name, you only need to add a single item to the array.  Once you've added all the items you want to your drop array, you can issue the **/adrop** command.
## Events
- **event_soldItem** - Triggers on 'You receive #*# from #1# for the #2#(s).  While the script is running and you sell any item to the vendor, the item will automatically get flagged in your Loot Settings.ini for Keep,Sell in the future.

# Notes on Loot Settings.ini key creation
There appear to be a couple algorithims for determining keys in the Loot Settings.ini key/value pairs.  The main difference is in the coin value on an item entry.  I'm using the long coin setting algorithm where if you have a raw coin value of 54321, the value comes as 54p3g2s1c.  The other algorithm that some people use for a similar raw value will only use 54p for the value.  Both keys are stored and used for lookup when looking for a match in the Loot Settings.ini file, however when a new entry is created, the long algorithm is used.
