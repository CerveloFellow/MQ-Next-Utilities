# MQ-Next-Utilities
Utilities I've written for Everquest(Project Lazarus) MacroQuest Next

# LUA Scripts
**MoveUtil.lua** - provides some utilities for using MQ2MoveUtils and MQ2Nav navigate to targets and locations.  This is a library included in other files below.  
**LootSettingUtil.lua** - provides some utilities for managing the Loot Settings.ini file. This is a library included in other files below.  
**InvUtil.lua** - Inventory utilities that provides some slash commands to help manage inventory and banking.  

# Usage
To use with Project Lazarus, download these files into your E3_RoF2\lua folder.  

## Script configuration
There is one setting in the script you'll have to set manually to point to the location you want your INI file.  Update this line to point to the correct config location where you want your INI to reside.  Be sure to use double forward slashes(\\\\) since these get escaped in strings.

**self.INVUTILINI = "C:\\\\E3_RoF2\\\\config\\\\InvUtil.ini"**


 Within Everquest you can run:  
 **/lua run InvUtil**  
  
# Overview
## InvUtil.ini

The first time you run the script, if an INI file is not present, one will be created with default values and the script will exit automatically.

|Key|Value|
|------------|-------------|
|**Script&nbsp;Run&nbsp;Time(seconds)**|The time in seconds for the script to auto terminate.  Setting this to 0 will disable auto terminate|
|**Enable&nbsp;Sold&nbsp;Item&nbsp;Event(true\false)**|Toggle whether the enable sold items event is on.  If true, any items sold to the vendor will automatically get flagged as Keep,Sell|
|**Loot&nbsp;Settings&nbsp;File**|The path to your Loot Settings.ini(e.g. C:\E3_RoF2\Macros\e3 Macro Inis\Loot Settings.ini)|

## Binds
- **/abank [print]** - Auto Bank.  When you're near a banker and you issue this command you will walk up to the nearest banker and put any items from your inventory that have been flagged as Keep,Bank into your bank.  **When the item can't be stored in the bank for some reason(your bank is full, item is No Storage, etc.), the item will now be placed back in your inventory.**  Optionally **/abank print** will only print the items that will be banked.
- **/adrop** - Auto Drop.  Any items that have been flagged to drop with the **/xitem** command will be automatically dropped on the ground when you issue this command.  
- **/asell [print]** - Auto Sell.  Any items in your inventory that are Flagged as Keep,Sell in your Loot Settings.ini will be automatically sold to the nearest vendor.  Optionally **/sell print** will only print the items that will be banked.
- **/bitem** - Bank Item.  While an item is on your cursor and you issue this command, this will flag the item in your Loot Settings.ini as Keep,Bank.
- **/dinv** - Print Drop List.  This will print the items that have been flagged to drop.  
- **/ditem** - Destroy Item.  While an item is on your cursor and you issue this command, this will flag the item in your Loot Settings.ini as Destroy.
- **/dropclear** - Clear Drop List.  Thsi will remove all items from your temporary drop list(any items added with the **/xitem** command).
- **/kitem <###>** - Keep Item.  While an item is on your cursor and you issue this command, this will flag the item in your Loot Settings.ini as Keep.  Optionally you can specify a count for how many to keep.
- **/pbank** - Print Bank.  This will print the items that are stored in your bank.  Primarily used by me for debugging purposes.
- **/pinv** - Print Inventory.  This will print the items in your inventory that have been scanned with **/scaninv**.  Primarily used by me for debugging purposes.
- **/pis** - Print Item Status.  While an item is on your cursor and you issue this command, it will print the status of the item from the Loot Settings.ini
- **/scaninv** - Scan Inventory.  Will run a rescan of your inventory to re-create the inventory array.  Primarily used by me for debugging.
- **/sinventory** - Synchronize Inventory.  This will iterate through your inventory list and put an entry in your Loot Settings.ini file for any items in your inventory that are not in the Loot Settings.ini file.
- **/sitem <###>**- Sell Item.  While an item is on your cursor and you issue this command, this will flag the item in your Loot Settings.ini as Keep,Sell.  Optionally you can specify a count for how many to sell.
- **/skipitem** - Skip Item.  While an item is on your cursor and you issue this command, this will flag the item in your Loot Settings.ini as Skip.
- **/syncbank** - Synchronize Bank.  This will scan your bank and flag any item in your bank as Keep,Bank in your Loot Settings.ini file.
- **/xitem** - Drop Item. While an item is on your cursor and you issue this command, the item will **temporarily** get added to the drop array.  If you have multiple items with the same name, you only need to add a single item to the array.  Once you've added all the items you want to your drop array, you can issue the **/adrop** command.  The drop array will exist as long as the script is running or until you issue a **/dropclear** command.
## Events
- **event_soldItem** - Triggers on 'You receive #*# from #1# for the #2#(s).  While the script is running and you sell any item to the vendor, the item will automatically get flagged in your Loot Settings.ini for Keep,Sell in the future.

# Notes on Loot Settings.ini key creation
There appear to be a couple algorithims for determining keys in the Loot Settings.ini key/value pairs.  The main difference is in the coin value on an item entry.  I'm using the long coin setting algorithm where if you have a raw coin value of 54321, the value comes as 54p3g2s1c.  The other algorithm that some people use for a similar raw value will only use 54p for the value.  Both keys are used for lookup when looking for a match in the Loot Settings.ini file, however when a new entry is created, only the long algorithm is used.
