--[[
    Bank Utilities
    LUA set of utilities to help manage Loot Settings and banking

    *** Be sure to set your Loot Settings location correctly with this line ***
    self.LOOTSETTINGSINI = "C:\\E3_RoF2\\Macros\\e3 Macro Inis\\Loot Settings.ini"

    The script has a limited run time and will automatically exit after a designated time in seconds.  You can
    change the time by finding the following line and changing to to an appropriate value
    local scriptRunTime = 300
    
    What this script does.

    The following binds are available while this script is running

    /pis - Print Item Status.  Prints the Loot Settings status for the item on the cursor.
    /kitem <###> - Keep Item, optionally specify how many if it's stackable.  Set's the item on your cursor to Keep in the Loot Settings.ini.
    /sitem <###> - Sell Item, optionally specify how many if it's stackable.. Set's the item on your cursor to Keep,Sell in the Loot Settings.ini.
    /bitem - Bank Item.  Set's the item on your cursor to Keep,Bank in the Loot Settings.ini.
    /ditem - Destroy Item.  Set's the item on your cursor to Destroy in the Loot Settings.ini.
    /syncbank - Sync Bank.  Sync's your bank and marks everything in the bank for Keep,Bank in Loot Settings.ini.
    /scaninv - Mostly used for my debug purposes.  Scans your inventory into an LUA table with appropriate information.   
    /pinv - Mostly used for my debug purposes.  Prints the contents of the LUA table where inventory information is held.
    /abank - Auto Bank - when running this command near a banker, it will open the bank window and auto bank any items in your inventory that are flagged for Keep,Bank

        These values are used to introduce delays after certaion actions.  If you run into situations where not all items get sold you may want to increase the delay values.  These values
    work pretty reliably for me.  Some people have had luck running with lower delays and have faster selling/banking

    self.COMMANDDELAY = 50
    self.BANKDELAY = 300
]]

local mq = require('mq')
require('MoveUtil')
require('LootSettingUtil')

BankUtil = { }

function BankUtil.new()
    local self = {}
    local bankArray = {}
    local inventoryArray = {}
    local lsu = LootSettingUtil.new()

    self.bankArray = bankArray
    self.inventoryArray = inventoryArray
    self.LOOTSETTINGSINI = "C:\\E3_RoF2\\Macros\\e3 Macro Inis\\Loot Settings.ini"
    -- for testing purposes set these to TestKeep, TestSell, etc and use the binds calls to flag itemss
    self.SELL = "Keep,Sell"
    self.DESTROY = "Destroy"
    self.KEEP = "Keep"
    self.BANK = "Keep,Bank"
    self.COMMANDDELAY = 50
    self.BANKDELAY = 300

    function self.printBank()
        for i=1,#self.bankArray do
            local value1 = self.bankArray[i].key.."---"..self.bankArray[i].value[1]
            local value2 = self.bankArray[i].key.."---"..self.bankArray[i].value[2]
            print(value1)
            if(value1 ~= value2) then
                print(value2)
            end

        end

        print(string.format("%d items in your bank", #self.bankArray))
    end

    function self.bankSlotsOpen()
        local bankSlotsOpen = 0

        for i=1,24 do
            if (mq.TLO.Me.Bank(i).Container()~=nil and mq.TLO.Me.Bank(i).Container() > 0) then
                local containerSize = tonumber(mq.TLO.Me.Bank(i).Container())
                for x=1,containerSize do
                    if(mq.TLO.Me.Bank(i).Item(x).Name() == nil) then
                        bankSlotsOpen = bankSlotsOpen + 1
                    end
                end
            else
                if(mq.TLO.Me.Bank(i).Name() == nil) then
                    bankSlotsOpen = bankSlotsOpen + 1
                end
            end
        end

        return bankSlotsOpen
    end

    function self.scanBank()
        self.bankArray = {}
        for i=1,24 do
            if (mq.TLO.Me.Bank(i).Container()~=nil and mq.TLO.Me.Bank(i).Container() > 0) then
                local containerSize = tonumber(mq.TLO.Me.Bank(i).Container())
                for x=1,containerSize do
                    if(mq.TLO.Me.Bank(i).Item(x).Name() ~= nil) then
                        local currentItem = mq.TLO.Me.Bank(i).Item(x)
                        local lookup = {}
                        lookup.key = currentItem.Name()
                        lookup.value = lsu.getIniKey(currentItem.Name(), currentItem.Value(), currentItem.StackSize(), currentItem.NoDrop(), currentItem.Lore())
                        table.insert(self.bankArray, lookup)
                    end
                end
            else
                if(mq.TLO.Me.Bank(i).Name() ~= nil) then
                    local currentItem = mq.TLO.Me.Bank(i)
                    local lookup = {}
                    lookup.key = currentItem.Name()
                    lookup.value = lsu.getIniKey(currentItem.Name(), currentItem.Value(), currentItem.StackSize(), currentItem.NoDrop(), currentItem.Lore())
                    table.insert(self.bankArray, lookup)
                end
            end
        end
    end

    function self.scanInventory()
        self.inventoryArray = {}
        for i=1,10 do
            if (mq.TLO.Me.Inventory(i+22).Container()~=nil and mq.TLO.Me.Inventory(i+22).Container() > 0) then
                local containerSize = tonumber(mq.TLO.Me.Inventory(i+22).Container())
                for x=1,containerSize do

                    if(mq.TLO.Me.Inventory(i+22).Item(x).Name() ~= nil) then
                        local currentItem = mq.TLO.Me.Inventory(i+22).Item(x)
                        local lookup = {}
                        lookup.key = currentItem.Name()
                        lookup.value = lsu.getIniKey(currentItem.Name(), currentItem.Value(), currentItem.StackSize(), currentItem.NoDrop(), currentItem.Lore())
                        lookup.location = string.format("in pack%d %d", currentItem.ItemSlot()-22, currentItem.ItemSlot2() + 1)
                        table.insert(self.inventoryArray, lookup)
                    end
                end
            else
                if(mq.TLO.Me.Inventory(i+22).Name() ~= nil) then
                    local currentItem = mq.TLO.Me.Inventory(i+22)
                    local lookup = {}
                    lookup.key = currentItem.Name()
                    lookup.value = lsu.getIniKey(currentItem.Name(), currentItem.Value(), currentItem.StackSize(), currentItem.NoDrop(), currentItem.Lore())
                    lookup.location = string.format("%d", currentItem.ItemSlot())
                    table.insert(self.inventoryArray, lookup)
                end
            end
        end
    end

    function self.printItemStatus()
        local lsu = LootSettingUtil.new(self.LOOTSETTINGSINI)

        if (not (mq.TLO.Cursor.ID() == nil)) and (mq.TLO.Cursor.ID() > 0) then
            local currentItem = mq.TLO.Cursor
            local currentIniKey = lsu.getIniKey(currentItem.Name(), currentItem.Value(), currentItem.StackSize(), currentItem.NoDrop(), currentItem.Lore())
            local lootSetting = lsu.getIniValue(currentIniKey[1]) or "No Loot Setting Defined"
            print(mq.TLO.Cursor.Name().."|"..currentIniKey[1].."|"..lootSetting.."|")
            if(currentIniKey[1] ~= currentIniKey[2]) then
                lootSetting = lsu.getIniValue(currentIniKey[2]) or "No Loot Setting Defined"
                print(mq.TLO.Cursor.Name().."|"..currentIniKey[2].."|"..lootSetting.."|")
            end
        else
            print("No item is on your cursor.")
        end
    end

    function self.destroyThisItem()
        local lsu = LootSettingUtil.new(self.LOOTSETTINGSINI)

        if (not (mq.TLO.Cursor.ID() == nil)) and (mq.TLO.Cursor.ID() > 0) then
            local currentItem = mq.TLO.Cursor
            local keys = lsu.getIniKey(currentItem.Name(), currentItem.Value(), currentItem.StackSize(), currentItem.NoDrop(), currentItem.Lore())
            lsu.setIniValue(keys[1], self.DESTROY)
            if(lsu.getIniValue(keys[2])) then
                lsu.setIniValue(keys[1], self.DESTROY)
            end
            print(mq.TLO.Cursor.Name().." has been set to Destroy in Loot Settings.ini")
        else
            print("No item is on your cursor.")
        end
    end
    
    function self.keepThisItem(line)
        local lsu = LootSettingUtil.new(self.LOOTSETTINGSINI)

        if (not (mq.TLO.Cursor.ID() == nil)) and (mq.TLO.Cursor.ID() > 0) then
            local currentItem = mq.TLO.Cursor
            local stackSize = line or currentItem.StackSize()
            local stackSizeSetting = currentItem.Stackable() and "|"..stackSize or ""
            local keys = lsu.getIniKey(currentItem.Name(), currentItem.Value(), currentItem.StackSize(), currentItem.NoDrop(), currentItem.Lore())
            lsu.setIniValue(keys[1], self.KEEP..stackSizeSetting)
            if(lsu.getIniValue(keys[2])) then
                lsu.setIniValue(keys[1], self.KEEP..stackSizeSetting)
            end
            print(mq.TLO.Cursor.Name().." has been set to Keep in Loot Settings.ini")
        else
            print("No item is on your cursor.")
        end
    end
    
    function self.sellThisItem(line)
        local lsu = LootSettingUtil.new(self.LOOTSETTINGSINI)

        if (not (mq.TLO.Cursor.ID() == nil)) and (mq.TLO.Cursor.ID() > 0) then
            local currentItem = mq.TLO.Cursor
            local stackSize = line or currentItem.StackSize()
            local stackSizeSetting = currentItem.Stackable() and "|"..stackSize or ""
            local keys = lsu.getIniKey(currentItem.Name(), currentItem.Value(), currentItem.StackSize(), currentItem.NoDrop(), currentItem.Lore())
            lsu.setIniValue(keys[1],self.SELL..stackSizeSetting)
            if(lsu.getIniValue(keys[2])) then
                lsu.setIniValue(keys[1], self.SELL..stackSizeSetting)
            end
            print(mq.TLO.Cursor.Name().." has been set to Keep,Sell|"..mq.TLO.Cursor.StackSize().." in Loot Settings.ini")
        else
            print("No item is on your cursor.")
        end
    end
    
    function self.bankThisItem(line)
        local lsu = LootSettingUtil.new(self.LOOTSETTINGSINI)

        if (not (mq.TLO.Cursor.ID() == nil)) and (mq.TLO.Cursor.ID() > 0) then
            local currentItem = mq.TLO.Cursor
            local stackSize = line or currentItem.StackSize()
            local stackSizeSetting = currentItem.Stackable() and "|"..stackSize or ""
            local keys = lsu.getIniKey(currentItem.Name(), currentItem.Value(), currentItem.StackSize(), currentItem.NoDrop(), currentItem.Lore())
            lsu.setIniValue(keys[1],self.BANK..stackSizeSetting)
            if(lsu.getIniValue(keys[2])) then
                lsu.setIniValue(keys[1], self.BANK..stackSizeSetting)
            end
            print(currentItem.Name().." has been set to Keep,Bank in Loot Settings.ini")
        else
            print("No item is on your cursor.")
        end
    end

    function findIniEntry(itemName)
        for i=1, #self.inventoryArray do
            if(self.inventoryArray[i].key == itemName) then
                return self.inventoryArray[i].value
            end 
        end
    end 

    function self.syncBank()
        local lsu = LootSettingUtil.new(self.LOOTSETTINGSINI)

        self.scanBank()
        print("Sync Bank Starting")
        for i=1, #self.bankArray do
            local lootSetting = lsu.getIniValue(self.bankArray[i].value[1])
            lsu.setIniValue(self.bankArray[i].value[1], self.BANK)
            print(string.format("Flag Bank Item: %s.", self.bankArray[i].key))
        end
        print("Sync Bank Complete")
    end

    function bankSingleItem(location, maxClickAttempts)
        mq.cmdf("/itemnotify %s leftmouseup", location)
        mq.delay(self.COMMANDDELAY)
        if(mq.TLO.Window("BigBankWnd").Child("BIGB_AutoButton").Enabled()) then
            mq.cmdf("/notify BigBankWnd BIGB_AutoButton leftmouseup")
            mq.delay(self.COMMANDDELAY)
            local clickAttempts = 1
            while mq.TLO.Window("QuantityWnd").Open() and clickAttempts < maxClickAttempts do
                clickAttempts = clickAttempts + 1
                mq.cmdf("/notify QuantityWnd QTYW_Accept_Button leftmouseup")
                mq.delay(self.COMMANDDELAY)
                mq.cmdf("/notify BigBankWnd BIGB_AutoButton leftmouseup")
                mq.delay(self.COMMANDDELAY)
            end
        end
    end

    function openBanker()
        local maxBankerDistance = 500
        local banker = mq.TLO.Spawn(string.format("Banker radius %s", maxBankerDistance))
        local maxRetries = 3
        local attempt = 0
        if (banker.ID() == nil) then
            print(string.format("There are no bankers within line of sight or %s units distance from you.", maxBankerDistance))
            return false
        end

        if mq.TLO.Me.AutoFire() then
            mq.cmdf("/autofire")
        end

        local moveProps = { target=banker, timeToWait="5s", arrivalDistance=15}
        local moveUtilInstance = MoveUtil.new(moveProps)
        moveUtilInstance.moveToLocation()

        if not mq.TLO.Window("BigBankWnd").Open() then
            while( not mq.TLO.Window("BigBankWnd").Open() and attempt < maxRetries)
            do
                mq.cmdf("/target id %d", banker.ID())
                mq.delay(self.COMMANDDELAY)
                mq.cmdf("/click right target")
                mq.delay(self.COMMANDDELAY)
                attempt = attempt + 1
            end
            if attempt >= maxRetries then
                return false
            end
        end

        return true
    end

    function closeBanker()
        local attempt = 0
        local maxRetries = 3

        while( mq.TLO.Window("BigBankWnd").Open() and attempt < maxRetries)
        do
            mq.cmdf("/notify BigBankWnd BIGB_DoneButton leftmouseup")
            mq.delay(self.COMMANDDELAY)
            attempt = attempt + 1
        end
        if attempt >= maxRetries then
            return false
        end
        return true
    end

    function self.autoBank()
        local maxClickAttempts = 3
        local lsu = LootSettingUtil.new(self.LOOTSETTINGSINI)

        self.scanInventory()

        if not openBanker() then
            print("Error attempting to open banker window with the banker.")
            return
        end

        for i=1, #self.inventoryArray do
            for j=1, #self.inventoryArray[i].value do
                local lootSetting = lsu.getIniValue(self.inventoryArray[i].value[j]) or "Nothing"
                if(string.find(lootSetting, self.BANK)) then
                    if mq.TLO.Window("BigBankWnd").Open() then
                        print("Banking: ",self.inventoryArray[i].key," - ",self.inventoryArray[i].location)
                        bankSingleItem(self.inventoryArray[i].location,3)
                        mq.delay(self.BANKDELAY)
                    end
                    break
                end
            end
        end

        closeBanker()
        self.scanInventory()
    end

    return self
end

local scriptRunTime = 300
local startTime = os.clock()
local instance = BankUtil.new()
local loopBoolean = true

instance.scanBank()
print("Available Bank Slots=",instance.bankSlotsOpen())

print(string.format("Bank Utilities enabled for the next %ss seconds", scriptRunTime))

mq.bind("/pis", instance.printItemStatus)
mq.bind("/kitem", instance.keepThisItem)
mq.bind("/sitem", instance.sellThisItem)
mq.bind("/ditem", instance.destroyThisItem)
mq.bind("/bitem", instance.bankThisItem)
mq.bind("/syncbank", instance.syncBank)
mq.bind("/scaninv", instance.scanBank)
mq.bind("/pbank", instance.printBank)
mq.bind("/abank", instance.autoBank)

while(loopBoolean)
do
    mq.doevents()
    mq.delay(1) -- just yield the frame every loop
    if(os.clock() - startTime > scriptRunTime) then
        loopBoolean = false
    end
end

print("Bank Utility terminated.")
