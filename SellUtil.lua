--[[
    Sell Utilities
    LUA set of utilities to help manage Loot Settings and autoselling

    *** Be sure to set your Loot Settings location correctly with this line ***
    *** LUA uses \ as escape, so don't forget to \\ your paths
    self.LOOTSETTINGSINI = "C:\\E3_RoF2\\Macros\\e3 Macro Inis\\Loot Settings.ini"

    The script has a limited run time and will automatically exit after a designated time in seconds.  You can
    change the time by finding the following line and changing to to an appropriate value
    local scriptRunTime = 300
    
    What this script does.

    While this script is running, any items you sell to the merchant will get flagged in your Loot Settings.ini for Keep,Sell, so that any
    autosell utilities that rely on the Loot Settings will automatically sell these items in the future.

    Additionaly some binds are created that are helper items for this utility.  These binds only exists while the script is running.

    /pis - Print Item Status.  Prints the Loot Settings status for the item on the cursor.
    /kitem <###> - Keep Item, optionally specify how many if it's stackable.  Set's the item on your cursor to Keep in the Loot Settings.ini.
    /sitem <###> - Sell Item, optionally specify how many if it's stackable. Set's the item on your cursor to Keep,Sell in the Loot Settings.ini.
    /ditem - Destroy Item.  Set's the item on your cursor to Destroy in the Loot Settings.ini.
    /xitem - Add item to drop list for when you use /autodrop.  /adrop works on item name, so if you have multiple items with the same name flagging a single item with /xitem will drop all matching items in your inventory
    /skipitem - Skip Item.  Set's the item on your cursos to Skip in the Loot Settings.ini.
    /sinventory - Sync Inventory.  Sync's your inventory and marks everything new for Keep in Loot Settings.ini.
    /asell - Auto Sell.  This will find the nearest merchant, run up to them and sell any items in your inventory that are tagged Keep,Sell.
    /scaninv - Mostly used for my debug purposes.  Scans your inventory into an LUA table with appropriate information.   
    /pinv - Mostly used for my debug purposes.  Prints the contents of the LUA table where inventory information is held.
    /adrop loops through your autodrop list and drops all items in your inventory that have been flagged with /xitem.  AutoDrop is temporary and does not persist in Loot Settings.ini
    /dropclear - removes all items from your drop array
    These values are used to introduce delays after certaion actions.  If you run into situations where not all items get sold you may want to increase the delay values.  These values
    work pretty reliably for me.  Some people have had luck running with lower delays and have faster selling

    self.COMMANDDELAY = 50
    self.SELLDELAY = 300
    self.DESTROYDELAY = 100
]]

local mq = require('mq')
require('MoveUtil')
require('LootSettingUtil')

SellUtil = { }

function SellUtil.new()
    local self = {}
    local inventoryArray = {}
    local lsu = LootSettingUtil.new()
    local dropArray = {}

    self.inventoryArray = inventoryArray
    self.dropArray = dropArray
    self.LOOTSETTINGSINI = "C:\\E3_RoF2\\Macros\\e3 Macro Inis\\Loot Settings.ini"
    -- for testing purposes set these to TestKeep, TestSell, etc and use the binds calls to flag itemss
    self.SELL = "Keep,Sell"
    self.SKIP = "Skip"
    self.DESTROY = "Destroy"
    self.KEEP = "Keep"
    self.COMMANDDELAY = 50
    self.SELLDELAY = 300
    self.DESTROYDELAY = 100

    function self.printInventory()

        for k,v in pairs(self.inventoryArray) do
            local value1 = v.ID..": "..k.."---"..v.location.."---"..v.value[1]
            local value2 = v.ID..": "..k.."---"..v.location.."---"..v.value[2]
            print(value1)
            if(value1 ~= value2) then
                print(value2)
            end
        end
    end

    function self.dropClear()
        self.dropArray = {}
    end

    function self.dropThisItem()
        local item = mq.TLO.Cursor
        if (not (item.ID() == nil)) and (item.ID() > 0) then
            if(item.NoTrade() or item.NoDrop() or item.NoDestroy()) then
                print(item.Name(), " is No Drop, No Trade, or No Destroy and cannot be dropped.")
            else
                self.dropArray[mq.TLO.Cursor.ID()] = mq.TLO.Cursor.Name()
                print(item.Name().." has been added to your Drop Array")
            end
        else
            print("No item is on your cursor.")
        end
    end

    function self.printDrop()
        for k,v in pairs(self.dropArray) do
            print("ID=",k," Name=",v)
        end
    end

    function self.autoDrop()
        local clickAttempts = 0
        local maxClickAttempts = 8
        self.scanInventory()

        for k,v in pairs(self.inventoryArray) do
            local id = self.dropArray[v.ID]
            if(self.dropArray[v.ID]) then
                for i=1,#v.locations do
                    mq.cmdf("/itemnotify %s leftmouseup", v.locations[i])
                    mq.delay(self.COMMANDDELAY)
                    while mq.TLO.Window("QuantityWnd").Open() and clickAttempts < maxClickAttempts do
                        clickAttempts = clickAttempts + 1
                        mq.cmdf("/notify QuantityWnd QTYW_Accept_Button leftmouseup")
                        mq.delay(self.COMMANDDELAY)
                    end
                    mq.cmdf("/drop")
                    mq.delay(self.COMMANDDELAY)
                end
            end
        end
    end

    function self.scanInventory()
        -- Scan inventory creates an array of the items in your inventory.  This serves a couple of purposes.
        -- When you sell an item to the vendor, we can get the details from this array rather than having to 
        -- query the Merchant or track multiple events.  Also allows for single looping and more readable code
        -- when walking inventory.
        -- The downside is if items are moved from your inventory and scanInventory isn't called, the inventory array
        -- will be out of synch
        self.inventoryArray = {}

        for i=1,10 do
            if (mq.TLO.Me.Inventory(i+22).Container()~=nil and mq.TLO.Me.Inventory(i+22).Container() > 0) then
                local containerSize = tonumber(mq.TLO.Me.Inventory(i+22).Container())
                for x=1,containerSize do

                    if(mq.TLO.Me.Inventory(i+22).Item(x).Name() ~= nil) then
                        local currentItem = mq.TLO.Me.Inventory(i+22).Item(x)
                        local lookup = {}
                        lookup.key = currentItem.Name()
                        lookup.ID = currentItem.ID()
                        lookup.value = lsu.getIniKey(currentItem.Name(), currentItem.Value(), currentItem.StackSize(), currentItem.NoDrop(), currentItem.Lore())
                        lookup.location = string.format("in pack%d %d", currentItem.ItemSlot()-22, currentItem.ItemSlot2() + 1)
                        local locations = {}
                        table.insert(locations, lookup.location)
                        lookup.locations = locations
                        -- can have multiple items with same name, so create a table of locations
                        if(self.inventoryArray[currentItem.Name()]) then
                            table.insert(self.inventoryArray[currentItem.Name()].locations, lookup.location)
                        else
                            self.inventoryArray[currentItem.Name()] = lookup
                        end
                    end
                end
            else
                if(mq.TLO.Me.Inventory(i+22).Name() ~= nil) then
                    local currentItem = mq.TLO.Me.Inventory(i+22)
                    local lookup = {}
                    lookup.key = currentItem.Name()
                    lookup.value = lsu.getIniKey(currentItem.Name(), currentItem.Value(), currentItem.StackSize(), currentItem.NoDrop(), currentItem.Lore())
                    lookup.location = string.format("%d", currentItem.ItemSlot())
                    local locations = {}
                    table.insert(locations, lookup.location)
                    lookup.locations = locations
                    -- can have multiple items with same name, so create a table of locations
                    if(self.inventoryArray[currentItem.Name()]) then
                        table.insert(self.inventoryArray[currentItem.Name()].locations, lookup.location)
                    else
                        self.inventoryArray[currentItem.Name()] = lookup
                    end
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
    
    function self.skipThisItem()
        local lsu = LootSettingUtil.new(self.LOOTSETTINGSINI)

        if (not (mq.TLO.Cursor.ID() == nil)) and (mq.TLO.Cursor.ID() > 0) then
            local currentItem = mq.TLO.Cursor
            local keys = lsu.getIniKey(currentItem.Name(), currentItem.Value(), currentItem.StackSize(), currentItem.NoDrop(), currentItem.Lore())
            lsu.setIniValue(keys[1], self.SKIP)
            if(lsu.getIniValue(keys[2])) then
                lsu.setIniValue(keys[1], self.SKIP)
            end
            print(mq.TLO.Cursor.Name().." has been set to Skip in Loot Settings.ini")
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

    function self.syncInventory()
        local lsu = LootSettingUtil.new(self.LOOTSETTINGSINI)

        self.scanInventory()
        print("Sync Inventory Starting")
        for k,v in pairs(self.inventoryArray) do
            local lootSetting = lsu.getIniValue(v.value[1])

            if(lootSetting == nil) then
                --add this item to the Loot Settings.ini
                lsu.setIniValue(v.value[1], self.KEEP)
                print(string.format("Added: %s", v.key))
            end
        end
        print("Sync Inventory Complete")
    end

    function self.itemSold(line, merchantName, itemName)
        local lsu = LootSettingUtil.new(self.LOOTSETTINGSINI)
        local lootIniKey = self.inventoryArray[itemName].value
        lsu.setIniValue(lootIniKey[1], self.SELL)
        print(itemName, " has been set to ", self.SELL)
    end

    function sellSingleItem(location, maxClickAttempts)
        mq.cmdf("/itemnotify %s leftmouseup", location)
        mq.delay(self.COMMANDDELAY)
        if(mq.TLO.Window("MerchantWnd").Child("MW_Sell_Button").Enabled()) then
            mq.cmdf("/notify MerchantWnd MW_Sell_Button leftmouseup")
            mq.delay(self.COMMANDDELAY)
            local clickAttempts = 1
            while mq.TLO.Window("QuantityWnd").Open() and clickAttempts < maxClickAttempts do
                clickAttempts = clickAttempts + 1
                mq.cmdf("/notify QuantityWnd QTYW_Accept_Button leftmouseup")
                mq.delay(self.COMMANDDELAY)
            end
        end
    end
    
    function destroySingleItem(location, maxClickAttempts)
        -- put the item on the cursor
        mq.cmdf("/itemnotify %s leftmouseup", location)
        mq.delay(self.COMMANDDELAY)
        
        local clickAttempts = 1
        -- if quantity window comes up, click button to close it
        while mq.TLO.Window("QuantityWnd").Open() and clickAttempts < maxClickAttempts do
            clickAttempts = clickAttempts + 1
            mq.cmdf("/notify QuantityWnd QTYW_Accept_Button leftmouseup")
            mq.delay(self.COMMANDDELAY)
        end

        local attempts = 0
        while(mq.TLO.Cursor.ID() ~= nil and attempts < maxClickAttempts)
        do
            mq.cmdf("/destroy")
            mq.delay(self.DESTROYDELAY)
            attempts = attempts + 1
        end
        
    end

    function openMerchant()
        local maxMerchantDistance = 500
        local merchant = mq.TLO.Spawn(string.format("Merchant radius %s los", maxMerchantDistance))
        local maxRetries = 8
        local attempt = 0
        if (merchant.ID() == nil) then
            print(string.format("There are no merchants within line of sight or %s units distance from you.", maxMerchantDistance))
            return false
        end

        if mq.TLO.Me.AutoFire() then
            mq.cmdf("/autofire")
        end

        local moveProps = { target=merchant, timeToWait="5s", arrivalDistance=15}
        local moveUtilInstance = MoveUtil.new(moveProps)
        moveUtilInstance.moveToLocation()

        if not mq.TLO.Window("MerchantWnd").Open() then
            while( not mq.TLO.Window("MerchantWnd").Open() and attempt < maxRetries)
            do
                mq.cmdf("/target id %d", merchant.ID())
                mq.delay(self.COMMANDDELAY)
                mq.cmdf("/click right target")
                mq.delay(self.COMMANDDELAY)
                attempt = attempt + 1
            end
            if attempt >= maxRetries and not mq.TLO.Window("MerchantWnd").Open() then
                return false
            end
        end

        return true
    end

    function closeMerchant()
        local attempt = 0
        local maxRetries = 8

        while( mq.TLO.Window("MerchantWnd").Open() and attempt < maxRetries)
        do
            mq.cmdf("/notify MerchantWnd MW_Done_Button leftmouseup")
            mq.delay(self.COMMANDDELAY)
            attempt = attempt + 1
        end
        if attempt >= maxRetries then
            return false
        end
        return true
    end

    function self.autoSell()
        local maxClickAttempts = 3
        local lsu = LootSettingUtil.new(self.LOOTSETTINGSINI)

        self.scanInventory()

        if not openMerchant() then
            print("Error attempting to open trade window with merchant.")
            return
        end

        for k1,v1 in pairs(self.inventoryArray) do
            for k2,v2 in pairs(v1.value) do
                local lootSetting = lsu.getIniValue(v2) or "Nothing"
                if(string.find(lootSetting, self.SELL)) then
                    if mq.TLO.Window("MerchantWnd").Open() then
                        for y=1,#v1.locations do
                            print("Selling: ",v1.key," - ",v1.locations[y])
                            sellSingleItem(v1.locations[y],3)
                            mq.delay(self.SELLDELAY)
                        end
                        break
                    end
                end
            end
        end

        closeMerchant()
        self.scanInventory()

        for k1,v1 in pairs(self.inventoryArray) do
            for k2, v2 in pairs(v1.value) do
                local lootSetting = lsu.getIniValue(v2) or "Nothing"
                if(string.find(lootSetting, self.DESTROY)) then
                    for y=1,#v1.locations do
                        print("Destroying: ",v1.key," - ",v1.locations[y])
                        destroySingleItem(v1.locations[y],3)
                        mq.delay(self.DESTROYDELAY)
                    end
                    break
                end
            end
        end

        self.scanInventory()
    end

    return self
end

local scriptRunTime = 300
local startTime = os.clock()
local instance = SellUtil.new()
local loopBoolean = true

instance.scanInventory()

print(string.format("For the next %ss seconds, any items you sell the the vendor will automatically get flagged as Keep,Sell", scriptRunTime))

mq.bind("/pis", instance.printItemStatus)
mq.bind("/kitem", instance.keepThisItem)
mq.bind("/sitem", instance.sellThisItem)
mq.bind("/ditem", instance.destroyThisItem)
mq.bind("/xitem", instance.dropThisItem)
mq.bind("/skipitem", instance.skipThisItem)
mq.bind("/sinventory", instance.syncInventory)
mq.bind("/asell", instance.autoSell)
mq.bind("/scaninv", instance.scanInventory)
mq.bind("/pinv", instance.printInventory)
mq.bind("/dinv", instance.printDrop)
mq.bind("/adrop", instance.autoDrop)
mq.bind("/dropclear", instance.dropClear)
mq.event('event_soldItem', 'You receive #*# from #1# for the #2#(s).', instance.itemSold)

while(loopBoolean)
do
    mq.doevents()
    mq.delay(1) -- just yield the frame every loop
    if(os.clock() - startTime > scriptRunTime) then
        loopBoolean = false
    end
end

print("SellUtil expired.  You are no longer autoflagging items that you sell.")
