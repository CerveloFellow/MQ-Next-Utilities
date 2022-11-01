--[[
    Sell Utilities
    LUA set of utilities to help manage Loot Settings and autoselling

    *** Be sure to set your Inventory Util INI location correctly with this line ***
    *** LUA uses \ as escape, so don't forget to \\ your paths
    self.INVUTILINI = "C:\\E3_RoF2\\config\\InvUtil.ini"

    You may also want to edit your default Loot Settings file location.  This can be updated in the Inventory Util INI file at any time.
    self.defaultLootSettingsIni = "C:\\E3_RoF2\\Macros\\e3 Macro Inis\\Loot Settings.ini"

    See the README for usage https://github.com/CerveloFellow/MQ-Next-Utilities/blob/main/README.md

    self.COMMANDDELAY = 50
    self.SELLDELAY = 300
    self.DESTROYDELAY = 100
    self.BANKDELAY = 300
]]

local mq = require('mq')
require('MoveUtil')
require('LootSettingUtil')

InvUtil = { }

function InvUtil.new()
    local self = {}
    local inventoryArray = {}
    local bankArray = {}
    local lsu = LootSettingUtil.new()
    local dropArray = {}

    self.inventoryArray = inventoryArray
    self.dropArray = dropArray
    self.INVUTILINI = "C:\\E3_RoF2\\config\\InvUtil.ini"
    self.SELL = "Keep,Sell"
    self.SKIP = "Skip"
    self.DESTROY = "Destroy"
    self.KEEP = "Keep"
    self.BANK = "Keep,Bank"
    self.COMMANDDELAY = 50
    self.SELLDELAY = 300
    self.DESTROYDELAY = 100
    self.BANKDELAY = 300
    self.defaultScriptRunTime = 300
    self.enableItemSoldEvent = true
    self.notAutoSelling = true
    self.defaultLootSettingsIni = "C:\\E3_RoF2\\Macros\\e3 Macro Inis\\Loot Settings.ini"

    function self.printBank()
        local lastBankItem = ""
        local bankItemCount = 0
        for k1,v1 in pairs(self.bankArray) do
            bankItemCount = bankItemCount + v1.itemCount
            local printLine = string.format("%s (%d)",v1.key,v1.itemCount)
            print(printLine)
        end
        print(string.format("%d items in your bank", bankItemCount))
        print(string.format("%d free bank slots", self.bankSlotsOpen()))
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
                        lookup.ID = currentItem.ID()
                        lookup.value = lsu.getIniKey(currentItem.Name(), currentItem.Value(), currentItem.StackSize(), currentItem.NoDrop(), currentItem.Lore())
                        lookup.itemCount = 1
                        if(self.bankArray[currentItem.Name()]) then
                            local itemCount = self.bankArray[currentItem.Name()].itemCount
                            self.bankArray[currentItem.Name()].itemCount = itemCount +1
                        else
                            self.bankArray[currentItem.Name()] = lookup
                        end
                    end
                end
            else
                if(mq.TLO.Me.Bank(i).Name() ~= nil) then
                    local currentItem = mq.TLO.Me.Bank(i)
                    local lookup = {}
                    lookup.key = currentItem.Name()
                    lookup.ID = currentItem.ID()
                    lookup.value = lsu.getIniKey(currentItem.Name(), currentItem.Value(), currentItem.StackSize(), currentItem.NoDrop(), currentItem.Lore())
                    lookup.itemCount = 1
                    if(self.bankArray[currentItem.Name()]) then
                        local itemCount = self.bankArray[currentItem.Name()].itemCount
                        self.bankArray[currentItem.Name()].itemCount = itemCount +1
                    else
                        self.bankArray[currentItem.Name()] = lookup
                    end
                end
            end
        end
    end

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
                    mq.cmdf("/shiftkey /itemnotify %s leftmouseup", v.locations[i])
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

    function getAugmentCount(item)
        local augmentCount = 0
        
        if((item.Augs() == 0) or (item.Container()>0)) then
            return augmentCount
        else
            for i=1,item.Augs() do
                if(item.Item(i).Name()) then
                    augmentCount = augmentCount +1
                end
            end
        end

        return augmentCount
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
                        lookup.augmentCount = getAugmentCount(currentItem)
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
                    lookup.ID = currentItem.ID()
                    lookup.augmentCount = getAugmentCount(currentItem)
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

    function self.sortLootFile()
        local lsu = LootSettingUtil.new(self.lootSettingsIni)
        lsu.iniSort()
    end
    
    function self.printItemStatus()
        local lsu = LootSettingUtil.new(self.lootSettingsIni)

        if (not (mq.TLO.Cursor.ID() == nil)) and (mq.TLO.Cursor.ID() > 0) then
            local currentItem = mq.TLO.Cursor
            local currentIniKey = lsu.getIniKey(currentItem.Name(), currentItem.Value(), currentItem.StackSize(), currentItem.NoDrop(), currentItem.Lore())
            local lootSetting = lsu.getIniValue(currentIniKey[1]) or "No Loot Setting Defined"
            print(mq.TLO.Cursor.Name().."|"..currentIniKey[1].."|"..lootSetting.."|")
            if(currentIniKey[1] ~= currentIniKey[2]) then
                lootSetting = lsu.getIniValue(currentIniKey[2])
                if(lootSetting) then
                    print(mq.TLO.Cursor.Name().."|"..currentIniKey[2].."|"..lootSetting.."|")
                end 
            end
        else
            print("No item is on your cursor.")
        end
    end

    function self.bankThisItem(line)
        local lsu = LootSettingUtil.new(self.lootSettingsIni)

        if (not (mq.TLO.Cursor.ID() == nil)) and (mq.TLO.Cursor.ID() > 0) then
            local currentItem = mq.TLO.Cursor
            local stackSize = line or currentItem.StackSize()
            local stackSizeSetting = currentItem.Stackable() and "|"..stackSize or ""
            local keys = lsu.getIniKey(currentItem.Name(), currentItem.Value(), currentItem.StackSize(), currentItem.NoDrop(), currentItem.Lore())
            lsu.setIniValue(keys[1],self.BANK..stackSizeSetting)
            if(lsu.getIniValue(keys[2])) then
                lsu.setIniValue(keys[2], self.BANK..stackSizeSetting)
            end
            print(currentItem.Name().." has been set to Keep,Bank in Loot Settings.ini")
        else
            print("No item is on your cursor.")
        end
    end

    function self.destroyThisItem()
        local lsu = LootSettingUtil.new(self.lootSettingsIni)

        if (not (mq.TLO.Cursor.ID() == nil)) and (mq.TLO.Cursor.ID() > 0) then
            local currentItem = mq.TLO.Cursor
            local keys = lsu.getIniKey(currentItem.Name(), currentItem.Value(), currentItem.StackSize(), currentItem.NoDrop(), currentItem.Lore())
            lsu.setIniValue(keys[1], self.DESTROY)
            if(lsu.getIniValue(keys[2])) then
                lsu.setIniValue(keys[2], self.DESTROY)
            end
            print(mq.TLO.Cursor.Name().." has been set to Destroy in Loot Settings.ini")
        else
            print("No item is on your cursor.")
        end
    end
    
    function self.skipThisItem()
        local lsu = LootSettingUtil.new(self.lootSettingsIni)

        if (not (mq.TLO.Cursor.ID() == nil)) and (mq.TLO.Cursor.ID() > 0) then
            local currentItem = mq.TLO.Cursor
            local keys = lsu.getIniKey(currentItem.Name(), currentItem.Value(), currentItem.StackSize(), currentItem.NoDrop(), currentItem.Lore())
            lsu.setIniValue(keys[1], self.SKIP)
            if(lsu.getIniValue(keys[2])) then
                lsu.setIniValue(keys[2], self.SKIP)
            end
            print(mq.TLO.Cursor.Name().." has been set to Skip in Loot Settings.ini")
        else
            print("No item is on your cursor.")
        end
    end

    function self.keepThisItem(line)
        local lsu = LootSettingUtil.new(self.lootSettingsIni)

        if (not (mq.TLO.Cursor.ID() == nil)) and (mq.TLO.Cursor.ID() > 0) then
            local currentItem = mq.TLO.Cursor
            local stackSize = line or currentItem.StackSize()
            local stackSizeSetting = currentItem.Stackable() and "|"..stackSize or ""
            local keys = lsu.getIniKey(currentItem.Name(), currentItem.Value(), currentItem.StackSize(), currentItem.NoDrop(), currentItem.Lore())
            lsu.setIniValue(keys[1], self.KEEP..stackSizeSetting)
            if(lsu.getIniValue(keys[2])) then
                lsu.setIniValue(keys[2], self.KEEP..stackSizeSetting)
            end
            print(mq.TLO.Cursor.Name().." has been set to Keep in Loot Settings.ini")
        else
            print("No item is on your cursor.")
        end
    end
    
    function self.sellThisItem(line)
        local lsu = LootSettingUtil.new(self.lootSettingsIni)

        if (not (mq.TLO.Cursor.ID() == nil)) and (mq.TLO.Cursor.ID() > 0) then
            local currentItem = mq.TLO.Cursor
            local stackSize = line or currentItem.StackSize()
            local stackSizeSetting = currentItem.Stackable() and "|"..stackSize or ""
            local keys = lsu.getIniKey(currentItem.Name(), currentItem.Value(), currentItem.StackSize(), currentItem.NoDrop(), currentItem.Lore())
            lsu.setIniValue(keys[1],self.SELL..stackSizeSetting)
            if(lsu.getIniValue(keys[2])) then
                lsu.setIniValue(keys[2], self.SELL..stackSizeSetting)
            end
            print(mq.TLO.Cursor.Name().." has been set to Keep,Sell|"..mq.TLO.Cursor.StackSize().." in Loot Settings.ini")
        else
            print("No item is on your cursor.")
        end
    end

    function self.syncBank()
        local lsu = LootSettingUtil.new(self.lootSettingsIni)

        self.scanBank()
        print("Sync Bank Starting")
        for k,v in pairs(bankArray) do
            local lootSetting = lsu.getIniValue(v.value[1])
            lsu.setIniValue(v.value[1], self.BANK)
            print(string.format("Flag Bank Item: %s.", v.key))
        end
        print("Sync Bank Complete")
    end

    function self.syncInventory()
        local lsu = LootSettingUtil.new(self.lootSettingsIni)

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
        if(self.enableItemSoldEvent and self.notAutoSelling and self.inventoryArray[itemName]) then
            local lsu = LootSettingUtil.new(self.lootSettingsIni)
            local lootIniKey = self.inventoryArray[itemName].value
            lsu.setIniValue(lootIniKey[1], self.SELL)
            print(itemName, " has been set to ", self.SELL)
        end
    end

    function bankSingleItem(location, maxClickAttempts)
        mq.cmdf("/shiftkey /itemnotify %s leftmouseup", location)
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
            -- Something went wrong trying to autobank it.  Put item bank where you found it.
            if(mq.TLO.Cursor) then
                print(string.format("Unable to bank %s.  Check if you have available bank space and that the item is not No Storage", mq.TLO.Cursor.Name()))
                mq.cmdf("/shiftkey /itemnotify %s leftmouseup", location)
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

    function self.autoBank(...)
        local arg={...}
        local maxClickAttempts = 3
        local lsu = LootSettingUtil.new(self.lootSettingsIni)
        local printMode = #arg > 0 and (string.lower(arg[1]) == "print") and true or false

        self.scanInventory()

        if not openBanker() then
            print("Error attempting to open banker window with the banker.")
            return
        end

        for k1,v1 in pairs(self.inventoryArray) do
            for k2,v2 in pairs(v1.value) do
                local lootSetting = lsu.getIniValue(v2) or "Nothing"
                if(string.find(lootSetting, self.BANK)) then
                    if mq.TLO.Window("BigBankWnd").Open() then
                        for y=1,#v1.locations do
                            print("Banking: ",v1.key," - ",v1.locations[y])
                            if not printMode then
                                bankSingleItem(v1.locations[y],3)
                            end
                            mq.delay(self.BANKDELAY)
                        end
                    end
                    break
                end
            end
        end

        closeBanker()
        self.scanInventory()
    end

    function sellSingleItem(location, maxClickAttempts)
        mq.cmdf("/itemnotify %s leftmouseup", location)
        mq.delay(self.COMMANDDELAY)
        local itemValue = mq.TLO.Window("MerchantWnd").Child("MW_SelectedPriceLabel").Text()
        if(mq.TLO.Window("MerchantWnd").Child("MW_Sell_Button").Enabled() and mq.TLO.Window("MerchantWnd").Child("MW_SelectedPriceLabel").Text() ~= "0c") then
            mq.cmdf("/shiftkey /notify MerchantWnd MW_Sell_Button leftmouseup")
            mq.delay(self.COMMANDDELAY)
            local clickAttempts = 1
            while mq.TLO.Window("QuantityWnd").Open() and clickAttempts < maxClickAttempts do
                clickAttempts = clickAttempts + 1
                mq.cmdf("/notify QuantityWnd QTYW_Accept_Button leftmouseup")
                mq.delay(self.COMMANDDELAY)
            end
        end

        return itemValue
    end
    
    function destroySingleItem(location, maxClickAttempts)
        -- put the item on the cursor
        mq.cmdf("/shiftkey /itemnotify %s leftmouseup", location)
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
        local merchantId = mq.TLO.Spawn(string.format("Merchant radius %s los", maxMerchantDistance)).ID() or 0
        local merchant = mq.TLO.Spawn(string.format("Merchant radius %s los", maxMerchantDistance))
        local maxRetries = 8
        local attempt = 0

        if (merchantId==0) then
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

    function self.autoSell(...)
        local arg = {...}
        local maxClickAttempts = 3
        local lsu = LootSettingUtil.new(self.lootSettingsIni)
        local printMode = #arg > 0 and (string.lower(arg[1]) == "print") and true or false

        mq.cmdf("/bc Autosell started for %s", mq.TLO.Me.Name())
        self.notAutoSelling = false
        self.scanInventory()

        if not openMerchant() then
            print("Error attempting to open trade window with merchant.")
            return
        end
    
        -- loops through all of your inventory array
        for k1,v1 in pairs(self.inventoryArray) do
            local attempts = 0

            -- check if the item has augments inserted into it, if so skip it.  Probably going to have to make this
            -- a function at some point to check for other things that might hold up selling
            if(v1.augmentCount == 0) then
                -- we store multiple loot setting values(old algorithm versus new algorithm).  So iterate over all of the 
                -- loot settings that we have to see if we have a match.
                for k2,v2 in pairs(v1.value) do
                    local lootSetting = lsu.getIniValue(v2) or "Nothing"
                    if(string.find(lootSetting, self.SELL)) then
                        if mq.TLO.Window("MerchantWnd").Open() then
                            for y=1,#v1.locations do
                                print("Selling: ",v1.key," - ",v1.locations[y])
                                if not printMode then
                                    attempts = 0
                                    while(not self.inventoryLocationEmpty(v1.locations[y]) and (attempts < 5))
                                    do
                                        local merchantOffer = sellSingleItem(v1.locations[y],3)
                                        attempts = attempts + 1
                                        -- sometimes selling things can take a long time depending on lag/latency.  putting in 
                                        -- a 5s delay with a callback that checks the inventory slot that I just sold from.  If the 
                                        -- inventory slot is empty, the delay stops early.
                                        if(string.sub(merchantOffer, 1, 2) == "0c") then
                                            break
                                        else
                                            mq.delay("5s", function() return self.inventoryLocationEmpty(v1.locations[y]) end)
                                        end
                                    end
                                end
                            end
                            break
                        end
                    end
                end
            else
                print(string.format("Skipping: %s has %d augmentation(s)",v1.key, v1.augmentCount))
            end
        end

        closeMerchant()

        self.autoDestroy(...)
        self.scanInventory()
        mq.cmdf("/bc Autosell Complete for %s", mq.TLO.Me.Name())
        -- before re-enabling autoselling, flush events and pause.  I would occasionally get errors because the autoSell event would
        -- get triggered after re-enabling autosell
        mq.flushevents("event_soldItem")
        mq.delay("1s")
        self.notAutoSelling = true
    end

    function self.autoDestroy(...)
        local arg = {...}
        local maxClickAttempts = 3
        local lsu = LootSettingUtil.new(self.lootSettingsIni)
        local printMode = #arg > 0 and (string.lower(arg[1]) == "print") and true or false

        self.scanInventory()
        for k1,v1 in pairs(self.inventoryArray) do
            for k2, v2 in pairs(v1.value) do
                local lootSetting = lsu.getIniValue(v2) or "Nothing"
                if(string.find(lootSetting, self.DESTROY)) then
                    for y=1,#v1.locations do
                        print("Destroying: ",v1.key," - ",v1.locations[y])
                        if not printMode then
                            destroySingleItem(v1.locations[y],3)
                        end
                        mq.delay(self.DESTROYDELAY)
                    end
                    break
                end
            end
        end
    end

    function createIniDefaults()
        mq.cmdf('/ini "%s" "%s" "%s" "%s"', self.INVUTILINI, "Settings", "Script Run Time(seconds)", self.defaultScriptRunTime)
        mq.cmdf('/ini "%s" "%s" "%s" "%s"', self.INVUTILINI, "Settings", "Enable Sold Item Event(true\\false)", "true")
        mq.cmdf('/ini "%s" "%s" "%s" "%s"', self.INVUTILINI, "Settings", "Loot Settings File", self.defaultLootSettingsIni)
    end

    function self.getIniSettings()
        stringtoboolean={ ["true"]=true, ["false"]=false }

        if(mq.TLO.Ini(self.INVUTILINI)()) then
            local tempString = mq.TLO.Ini(self.INVUTILINI,"Settings", "Script Run Time(seconds)")()
            if(tempString) then 
                self.scriptRunTime = tonumber(tempString)
            end

            tempString = mq.TLO.Ini(self.INVUTILINI,"Settings", "Enable Sold Item Event(true\\false)")()
            if(tempString) then
                self.enableItemSoldEvent = stringtoboolean[tempString]
            end

            tempString = mq.TLO.Ini(self.INVUTILINI,"Settings", "Loot Settings File")()
            if(tempString) then
                self.lootSettingsIni = tempString
            end
        else
            print("No InvUtil.ini is present.  Creating one and exiting.  Please edit the file and re-run the script.")
            createIniDefaults()
            self.scriptRunTime = self.defaultScriptRunTime
            self.enableItemSoldEvent = true
            self.lootSettingsIni = self.defaultLootSettingsIni
            os.exit()
        end
    end

    function self.windowOpenCallback(windowName)

    end

    -- returns true if inventory location is empty, otherwise it returns false if there is an item in the slot
    function self.inventoryLocationEmpty(itemLocation)
        words = {}
        for word in itemLocation:gmatch("%w+") do 
            table.insert(words, word) 
        end

        if(#words > 1) then
            return not (mq.TLO.Me.Inventory(words[2]).Item(words[3]).Name())
        else
            return not (mq.TLO.Me.Inventory(tonumber(words[1])).Name())
        end
    end

    return self
end

local startTime = os.clock()
local instance = InvUtil.new()
local loopBoolean = true

instance.getIniSettings()
instance.scanInventory()
instance.scanBank()

print("InvUtil has been started")
if(instance.scriptRunTime > 0) then
    print(string.format("InvUtil will automatically terminat in %s seconds.", instance.scriptRunTime))
else
    print("InvUtil will not automatically terminate and you will have to issue /lua stop or /lua stop InvUtil to terminate this script.")
end

if(instance.enableItemSoldEvent) then
    print("Enable Sold Item Event is true.  Any items you sell to the vendor while this script is running will automatically get flagged in yoru Loot Settings.ini as Keep,Sell")
end

mq.bind("/abank", instance.autoBank)
mq.bind("/adestroy", instance.autoDestroy)
mq.bind("/adrop", instance.autoDrop)
mq.bind("/asell", instance.autoSell)
mq.bind("/bitem", instance.bankThisItem)
mq.bind("/dinv", instance.printDrop)
mq.bind("/ditem", instance.destroyThisItem)
mq.bind("/dropclear", instance.dropClear)
mq.bind("/kitem", instance.keepThisItem)
mq.bind("/pbank", instance.printBank)
mq.bind("/pinv", instance.printInventory)
mq.bind("/pis", instance.printItemStatus)
mq.bind("/scaninv", instance.scanInventory)
mq.bind("/sinventory", instance.syncInventory)
mq.bind("/sitem", instance.sellThisItem)
mq.bind("/skipitem", instance.skipThisItem)
mq.bind("/sortlootfile", instance.sortLootFile)
mq.bind("/syncbank", instance.syncBank)
mq.bind("/xitem", instance.dropThisItem)

mq.event('event_soldItem', 'You receive #*# from #1# for the #2#(s).', instance.itemSold)

while(loopBoolean)
do
    mq.doevents()
    mq.delay(1) -- just yield the frame every loop
    if((os.clock() - startTime > instance.scriptRunTime) and (instance.scriptRunTime ~= 0 )) then
        loopBoolean = false
    end
end

print("InvUtil expired.  You are no longer autoflagging items that you sell.")
