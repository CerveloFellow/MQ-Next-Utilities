local mq = require('mq')
local imgui = require('ImGui')

-- ============================================================================
-- Configuration
-- ============================================================================
local Config = {
    defaultAllowCombatLooting = false,
    defaultSlotsToKeepFree = 2,
    lootRadius = 50,
    useWarp = true,
    lootStackableMinValue = 1000,
    lootSingleMinValue = 10000,
    iniFile = mq.configDir .. '/MasterLoot.ini',
    itemsToKeep = {},
    itemsToShare = {},
    itemsToIgnore = {}
}

-- ============================================================================
-- INI Management Module (Updated)
-- ============================================================================
local INIManager = {}

function INIManager.loadItemList(section)
    local items = {}
    local index = 1
    
    while true do
        local item = mq.TLO.Ini.File(Config.iniFile).Section(section).Key('Item' .. index).Value()
        if item == nil or item == 'NULL' or item == '' then
            break
        end
        table.insert(items, item)
        index = index + 1
    end
    
    return items
end

function INIManager.saveItemList(section, items)
    -- Clear existing items
    local index = 1
    while true do
        local existing = mq.TLO.Ini.File(Config.iniFile).Section(section).Key('Item' .. index).Value()
        if existing == nil or existing == 'NULL' or existing == '' then
            break
        end
        mq.cmdf('/ini "%s" "%s" "Item%d"', Config.iniFile, section, index)
        index = index + 1
    end
    
    -- Write new items
    for i, item in ipairs(items) do
        mq.cmdf('/ini "%s" "%s" "Item%d" "%s"', Config.iniFile, section, i, item)
    end
    
    print(string.format("Saved %d items to [%s]", #items, section))
end

function INIManager.loadSettings()
    -- Load UseWarp setting
    local useWarpValue = mq.TLO.Ini.File(Config.iniFile).Section('Settings').Key('UseWarp').Value()
    
    if useWarpValue ~= nil and useWarpValue ~= 'NULL' and useWarpValue ~= '' then
        Config.useWarp = (useWarpValue == 'true' or useWarpValue == '1')
        print(string.format("Loaded UseWarp setting: %s", tostring(Config.useWarp)))
    else
        -- Save default value if not present
        INIManager.saveSettings()
    end
    
    -- Load lootStackableMinValue
    local stackableValue = mq.TLO.Ini.File(Config.iniFile).Section('Settings').Key('LootStackableMinValue').Value()
    
    if stackableValue ~= nil and stackableValue ~= 'NULL' and stackableValue ~= '' then
        Config.lootStackableMinValue = tonumber(stackableValue)
        print(string.format("Loaded LootStackableMinValue: %d", Config.lootStackableMinValue))
    else
        -- Save default value if not present
        INIManager.saveSettings()
    end
    
    -- Load lootSingleMinValue
    local singleValue = mq.TLO.Ini.File(Config.iniFile).Section('Settings').Key('LootSingleMinValue').Value()
    
    if singleValue ~= nil and singleValue ~= 'NULL' and singleValue ~= '' then
        Config.lootSingleMinValue = tonumber(singleValue)
        print(string.format("Loaded LootSingleMinValue: %d", Config.lootSingleMinValue))
    else
        -- Save default value if not present
        INIManager.saveSettings()
    end
end

function INIManager.saveSettings()
    mq.cmdf('/ini "%s" "Settings" "UseWarp" "%s"', Config.iniFile, tostring(Config.useWarp))
    mq.cmdf('/ini "%s" "Settings" "LootStackableMinValue" "%d"', Config.iniFile, Config.lootStackableMinValue)
    mq.cmdf('/ini "%s" "Settings" "LootSingleMinValue" "%d"', Config.iniFile, Config.lootSingleMinValue)
    
    print(string.format("Saved UseWarp setting: %s", tostring(Config.useWarp)))
    print(string.format("Saved LootStackableMinValue: %d", Config.lootStackableMinValue))
    print(string.format("Saved LootSingleMinValue: %d", Config.lootSingleMinValue))
end

function INIManager.initializeINI()
    -- Check if file exists, if not create with defaults
    local fileExists = mq.TLO.Ini.File(Config.iniFile).Section('ItemsToKeep').Key('Item1').Value()
    
    if fileExists == nil or fileExists == 'NULL' or fileExists == '' then
        print("INI file not found or empty, creating with default values...")
        
        -- Default ItemsToKeep
        local defaultKeep = {
            'Green Stone of Minor Advancement',
            'Frosty Stone of Hearty Advancement',
            'Fiery Stone of Incredible Advancement',
            'Moneybags - Bag of Platinum Pieces',
            'Moneybags - Heavy Bag of Platinum!',
            "Unidentified Item",
            "Epic Gemstone of Immortality"
        }
        INIManager.saveItemList('ItemsToKeep', defaultKeep)
        
        -- Default ItemsToShare
        local defaultShare = {
            "Ancient Elvish Essence", "Ancient Life's Stone", "Astrial Mist", 
            "Book of Astrial-1", "Book of Astrial-2", "Book of Astrial-6", 
            "Bottom Piece of Astrial", "Bottom Shard of Astrial", 
            "celestial ingot", "celestial temper", "Center Shard of Astrial", 
            "Center Splinter of Astrial", "Death's Soul", "Elemental Infused Elixir", 
            "Epic Gemstone of Immortality", "Fallen Star", "Hermits Lost Chisel", 
            "hermits lost Forging Hammer", "Left Shard of Astrial", 
            "Overlords Anguish Stone", "Right Shard of Astrial", 
            "Testimony of the Lords", "The Horadric Lexicon", "The Lost Foci", 
            "Token of Discord", "Tome of Power: Anguish", "Tome of Power: Hole", 
            "Tome of Power: Kael", "Tome of Power: MPG", "Tome of Power: Najena", 
            "Tome of Power: Riftseekers", "Tome of Power: Sleepers", 
            "Tome of Power: Veeshan", "Top Splinter of Astrial", "Warders Guise"
        }
        INIManager.saveItemList('ItemsToShare', defaultShare)
        
        local defaultIgnore = {
            "Rusty Shortsword"
        }
        -- ItemsToIgnore starts with default
        INIManager.saveItemList('ItemsToIgnore', defaultIgnore)
    end
end

function INIManager.loadConfig()
    INIManager.initializeINI()
    
    Config.itemsToKeep = INIManager.loadItemList('ItemsToKeep')
    Config.itemsToShare = INIManager.loadItemList('ItemsToShare')
    Config.itemsToIgnore = INIManager.loadItemList('ItemsToIgnore')
    INIManager.loadSettings()
    
    print(string.format("Loaded %d items to keep", #Config.itemsToKeep))
    print(string.format("Loaded %d items to share", #Config.itemsToShare))
    print(string.format("Loaded %d items to ignore", #Config.itemsToIgnore))
end

function INIManager.reloadConfig()
    print("Reloading configuration from INI file...")
    INIManager.loadConfig()
    mq.cmdf('/g Configuration reloaded from INI file')
end

-- ============================================================================
-- Utility Functions
-- ============================================================================
local Utils = {}

function Utils.contains(tbl, value)
    for _, v in ipairs(tbl) do
        if v == value then
            return true
        end
    end
    return false
end

function Utils.ownItem(itemName)
    local itemCount = mq.TLO.FindItemCount('=' .. itemName)()
    return itemCount > 0
end


function Utils.multimapInsert(map, key, value)
    if map[key] == nil then
        map[key] = {}
    end
    
    for _, v in pairs(map[key]) do
        if v.itemId == value.itemId then
            return false
        end
    end
    
    table.insert(map[key], value)
    return true
end

function Utils.printTable(tbl, indent)
    indent = indent or 0
    local toprint = string.rep(" ", indent) .. "{\n"
    indent = indent + 2

    for k, v in pairs(tbl) do
        toprint = toprint .. string.rep(" ", indent)
        
        if type(k) == "number" then
            toprint = toprint .. "[" .. k .. "] = "
        elseif type(k) == "string" then
            toprint = toprint .. k .. " = "
        end

        if type(v) == "table" then
            toprint = toprint .. Utils.printTable(v, indent + 2) .. ",\n"
        elseif type(v) == "string" then
            toprint = toprint .. "\"" .. v .. "\",\n"
        else
            toprint = toprint .. tostring(v) .. ",\n"
        end
    end

    toprint = toprint .. string.rep(" ", indent - 2) .. "}"
    return toprint
end

-- ============================================================================
-- Navigation Module
-- ============================================================================
local Navigation = {}

function Navigation.navigateToLocation(x, y, z)
    if Config.useWarp then
        mq.cmdf("/squelch /warp loc %d %d %d", y, x, z)
    else
        mq.cmdf("/squelch /nav  locxyz %d %d %d", x, y, z)
    end
end

-- ============================================================================
-- Item Evaluation Module
-- ============================================================================
local ItemEvaluator = {}

function ItemEvaluator.groupMembersCanUse(corpseItem)
    local count = 0
    
    if corpseItem.NoDrop() or corpseItem.NoTrade() then
        for i = 1, corpseItem.Classes() do
            for j = 0, mq.TLO.Group.Members() do
                if corpseItem.Class(i).Name() == mq.TLO.Group.Member(j).Class() then
                    count = count + 1
                end
            end
        end
    end

    return count
end

function ItemEvaluator.skipItem(corpseItem)
    if Config.itemsToIgnore  and Utils.contains(Config.itemsToIgnore, corpseItem.Name()) then
        print("Item to ignore - Skip"..corpseItem.Name())
        return true
    end
end

function ItemEvaluator.shouldLoot(corpseItem)
    -- Check if player can use the item

    if Config.itemsToIgnore  and Utils.contains(Config.itemsToIgnore, corpseItem.Name()) then
        --print("Item to ignore - Skip"..corpseItem.Name())
        return false
    end

    if corpseItem.CanUse() then
        -- Skip lore items we already own
        if corpseItem.Lore() and Utils.ownItem(corpseItem.Name()) then
            --print("Lore Item and I own it - Skip")
            return false
        end
        
        -- Skip No Drop/No Trade items multiple group members can use
        if (corpseItem.NoDrop() or corpseItem.NoTrade()) and 
           (ItemEvaluator.groupMembersCanUse(corpseItem) > 1) then
            --print("Item is No Drop/No Trade and multiple group members can use, skipping.")
            mq.cmdf('/g ***' .. corpseItem.ItemLink('CLICKABLE')() .. '*** can be used by multiple classes')
            return false
        end
        
        -- Loot wearable items
        for i = 1, corpseItem.WornSlots() do
            --print("Item is worse slot item - Looting")
            if corpseItem.WornSlot(i).ID() < 23 then
                return true
            end
        end
    end
    
    -- Loot valuable items
    if (corpseItem.Value() or 0) > Config.lootSingleMinValue then
        --print("Value greater than single item min value - Looting")
        return true
    end
    
    -- Loot valuable stackables
    if corpseItem.Stackable() and (corpseItem.Value() or 0) >= Config.lootSingleMinValue then
        --print("Value greater than stacked item min value - Looting")
        return true
    end
    
    -- Check items to keep list
    if Utils.contains(Config.itemsToKeep, corpseItem.Name()) then
        return true
    end
    
    return false
end

-- ============================================================================
-- Corpse Management Module
-- ============================================================================
local CorpseManager = {}

function CorpseManager.getCorpseTable(numCorpses)
    local corpseTable = {}
    
    for i = 1, numCorpses do
        local spawn = mq.TLO.NearestSpawn(i, "npccorpse radius 200 zradius 10")
        local corpse = {
            ID = spawn.ID(),
            Name = spawn.Name(),
            Distance = spawn.Distance(),
            DistanceZ = spawn.DistanceZ(),
            X = spawn.X(),
            Y = spawn.Y(),
            Z = spawn.Z()
        }
        table.insert(corpseTable, corpse)
    end
    
    return corpseTable
end

function CorpseManager.getNearestCorpse(corpseTable)
    if #corpseTable == 0 then
        return nil, corpseTable
    end
    
    local nearestIndex = 0
    local nearestDistance = 9999
    
    for i = 1, #corpseTable do
        local corpse = corpseTable[i]
        local distance = mq.TLO.Math.Distance(corpse.Y, corpse.X)()
        if distance < nearestDistance then
            nearestIndex = i
            nearestDistance = distance
        end
    end
    
    local nearest = table.remove(corpseTable, nearestIndex)
    return nearest, corpseTable
end

-- ============================================================================
-- Loot Manager Module
-- ============================================================================
local LootManager = {}
LootManager.multipleUseTable = {}
LootManager.myQueuedItems = {}
LootManager.listboxSelectedOption = {}
LootManager.lootedCorpses = {}

function LootManager.isLooted(corpseId)
    return Utils.contains(LootManager.lootedCorpses, corpseId)
end

function LootManager.lootCorpse(corpseObject, isMaster)
    mq.cmdf("/target id %d", corpseObject.ID)

    if((mq.TLO.Target.ID() or 0)==0) then
        table.insert(LootManager.lootedCorpses, corpseObject.ID)
        return
    end
    mq.cmdf("/loot")
    
    mq.delay("5s", function() return mq.TLO.Window("LootWnd").Open() end)
    
    local retryCount = 0
    local maxRetries = 3

    if (not mq.TLO.Window("LootWnd").Open()) then
        while retryCount < maxRetries do
            mq.cmdf("/g Could not loot targeted corpse id(%d), retrying.", corpseObject.ID)
            mq.cmdf("/squelch /say #corpsefix")
            mq.delay(500)
            --mq.cmdf("/warp t %d", corpseObject.ID)
            mq.cmdf("/warp loc %f %f %f", corpseObject.Y, corpseObject.X, corpseObject.Z)
            retryCount = retryCount + 1
            
            -- Check if the loot window opened after the retry
            if mq.TLO.Window("LootWnd").Open() then
                break
            end
        end
        
        -- Optional: Handle the case where all retries failed
        if retryCount >= maxRetries and not mq.TLO.Window("LootWnd").Open() then
            mq.cmdf("/g Failed to loot corpse id(%d) after %d attempts.", corpseObject.ID, maxRetries)
            return
        end
    end

    local itemCount = tonumber(mq.TLO.Corpse.Items()) or 0
    
    if itemCount == 0 then
        LootManager.closeLootWindow()
        return
    end
    
    for i = 1, itemCount do
        LootManager.checkInventorySpace()
        
        mq.delay("3s", function() return mq.TLO.Corpse.Item(i).ID() end)
        local corpseItem = mq.TLO.Corpse.Item(i)
        local isSharedItem = Utils.contains(Config.itemsToShare, corpseItem.Name())

        if ItemEvaluator.shouldLoot(corpseItem) and (not isSharedItem) then
            LootManager.lootItem(corpseItem, i)
        else
            if (ItemEvaluator.groupMembersCanUse(corpseItem) > 1 or isSharedItem) and (not ItemEvaluator.skipItem(corpseItem)) then
                mq.cmdf("/squelch /g mlsi %d %d \"%s\"", corpseObject.ID, corpseItem.ID(), corpseItem.Name())
            end
        end
        
        if mq.TLO.Cursor then
            mq.cmdf("/autoinventory")
        end
    end
    
    table.insert(LootManager.lootedCorpses, corpseObject.ID)
    LootManager.closeLootWindow()
    return true
end

function LootManager.lootItem(corpseItem, slotIndex)
    mq.cmdf('/g ' .. corpseItem.ItemLink('CLICKABLE')())
    mq.cmdf("/shift /itemnotify loot%d rightmouseup", slotIndex)
    mq.delay(300)
    
    if mq.TLO.Window("QuantityWnd").Open() then
        mq.cmdf("/notify QuantityWnd QTYW_Accept_Button leftmouseup")
        mq.delay(250)
    end
end

function LootManager.checkInventorySpace()
    local slotsRemaining = mq.TLO.Me.FreeInventory() - Config.defaultSlotsToKeepFree
    
    if slotsRemaining < 1 then
        mq.cmdf("/beep")
        mq.cmdf('/g ' .. mq.TLO.Me.Name() .. " inventory is Full!")
    end
end

function LootManager.closeLootWindow()
    if mq.TLO.Window("LootWnd").Open() then
        mq.cmdf("/notify LootWnd LW_DoneButton leftmouseup")
        mq.delay(100)
    end
end

function LootManager.shareLootItem(line, pCorpseId, pItemId, pItemName)
    local item = {
        corpseId = pCorpseId,
        itemId = pItemId,
        itemName = pItemName,
        itemObject = {}
    }

    if next(LootManager.listboxSelectedOption) == nil then
        LootManager.listboxSelectedOption = {
            corpseId = pCorpseId,
            itemId = pItemId,
            itemName = pItemName
        }
    end
    
    Utils.multimapInsert(LootManager.multipleUseTable, pCorpseId, item)
end

function LootManager.addToMultipleUseTable(corpseObject, corpseItem)
    local item = {
        corpseId = corpseObject.ID,
        itemId = corpseItem.ID(),
        itemName = corpseItem.Name(),
        itemObject = corpseItem
    }

    if next(LootManager.listboxSelectedOption) == nil then
        LootManager.listboxSelectedOption = {
            corpseId = corpseObject.ID,
            itemId = corpseItem.ID(),
            itemName = corpseItem.Name()
        }
    end
    
    Utils.multimapInsert(LootManager.multipleUseTable, corpseObject.ID, item)
end

function LootManager.printMultipleUseItems()
    if LootManager.multipleUseTable == nil then
        return
    end

    mq.cmdf('/g *** Multi Class No Drop/No Trade Items ***')
    print('*** Multi Class No Drop/No Trade Items ***')
    
    for _, items in pairs(LootManager.multipleUseTable) do
        for _, tbl in ipairs(items) do
            if tbl.itemObject then
                local success, itemLink = pcall(function() 
                    return tbl.itemObject.ItemLink('CLICKABLE')
                end)
                
                if success and itemLink and type(itemLink) == 'function' then
                    local clickableLink = itemLink()
                    if clickableLink and clickableLink ~= '' then
                        mq.cmdf('/g  ' .. clickableLink)
                        print(clickableLink)
                    end
                end
            end 
        end
    end
end

function LootManager.lootQueuedItems()
    local idx, items = next(LootManager.myQueuedItems)
    
    while idx do
        local nextIdx = next(LootManager.myQueuedItems, idx)
        
        if not LootManager.openCorpse(idx) then
            idx = nextIdx
            if idx then
                items = LootManager.myQueuedItems[idx]
            end
            goto continue
        end
        
        local corpseItemCount = tonumber(mq.TLO.Corpse.Items()) or 0
        
        if corpseItemCount == 0 then
            LootManager.closeLootWindow()
            idx = nextIdx
            if idx then
                items = LootManager.myQueuedItems[idx]
            end
            goto continue
        end

        LootManager.processQueuedItemsInCorpse(items, corpseItemCount)
        LootManager.closeLootWindow()
        
        print("Removing corpse idx: " .. tostring(idx))
        LootManager.myQueuedItems[idx] = nil
        
        idx = nextIdx
        if idx then
            items = LootManager.myQueuedItems[idx]
        end
        
        ::continue::
    end
end

function LootManager.openCorpse(corpseId)
    mq.cmd("/say #corpsefix")
    mq.delay(300)
    mq.cmdf("/target id %d", corpseId)
    if((mq.TLO.Target.ID() or 0)==0) then
        return
    end

    if Config.useWarp then
        --mq.cmdf("/squelch /warp t")
        mq.cmdf("/warp loc %f %f %f", mq.TLO.Target.Y(), mq.TLO.Target.X(), mq.TLO.Target.Z())
    else
        mq.cmdf("/squelch /nav  target")
    end
    
    mq.delay(300)
    mq.cmdf("/loot")
    
    local retryCount = 0
    local retryMax = 5

    while not mq.TLO.Window("LootWnd").Open() and (retryCount < retryMax) do
        mq.cmdf("/squelch /say #corpsefix")
        mq.delay(300)
        if Config.useWarp then
            --mq.cmdf("/squelch /warp t")
            mq.cmdf("/warp loc %f %f %f", mq.TLO.Target.Y(), mq.TLO.Target.X(), mq.TLO.Target.Z())
        else
            mq.cmdf("/squelch /nav  target")
        end
        mq.delay(300)
        retryCount = retryCount + 1
    end

    if retryCount >= retryMax then
        mq.cmdf("/g Could not loot targeted corpse, skipping.")
        return false
    end
    
    return true
end

function LootManager.processQueuedItemsInCorpse(items, corpseItemCount)
    for i = 1, corpseItemCount do
        local idx2, tbl = next(items)
        
        while idx2 do
            local nextIdx2 = next(items, idx2)
            
            LootManager.checkInventorySpace()
            
            mq.delay("3s", function() return mq.TLO.Corpse.Item(i).ID() end)
            local corpseItem = mq.TLO.Corpse.Item(i)
            local localItemId = corpseItem.ID()
            
            if tostring(localItemId) == tostring(tbl.itemId) then
                LootManager.lootItem(corpseItem, i)
                
                if mq.TLO.Cursor then
                    mq.cmdf("/autoinventory")
                end

                print("Removing queued item idx2: " .. tostring(idx2))
                items[idx2] = nil
                mq.delay(300)
            end
            
            idx2 = nextIdx2
            if idx2 then
                tbl = items[idx2]
            end
        end
    end
end

function LootManager.doLoot(isMaster)
    local startingLocation = {
        X = mq.TLO.Me.X(),
        Y = mq.TLO.Me.Y(),
        Z = mq.TLO.Me.Z(),
        timeToWait = "2s",
        arrivalDistance = 5
    }
    
    local stickState = false
    LootManager.multipleUseTable = {}
    LootManager.myQueuedItems = {}
    LootManager.listboxSelectedOption = {}

    mq.cmdf("/g " .. mq.TLO.Me.Name() .. " has started looting")
    
    if mq.TLO.Stick.Active() then
        stickState = true
        mq.cmdf("/stick off")
    end
    
    mq.delay(500)
    
    -- Main looting loop
    local corpseTable = CorpseManager.getCorpseTable(mq.TLO.SpawnCount("npccorpse radius 200 zradius 10")())

    for i = 1, #corpseTable do
        local currentCorpse = corpseTable[i]
        
        if currentCorpse and not LootManager.isLooted(currentCorpse.ID) then
            Navigation.navigateToLocation(
                math.floor(currentCorpse.X),
                math.floor(currentCorpse.Y),
                math.floor(currentCorpse.Z)
            )
            
            if Config.useWarp then
                mq.delay(500)
            else
                mq.delay("2s")
            end
            LootManager.lootCorpse(currentCorpse, isMaster)
        end
    end
    
    -- Return to starting location
    Navigation.navigateToLocation(startingLocation.X, startingLocation.Y, startingLocation.Z)
    mq.delay(startingLocation.timeToWait)
    
    -- LootManager.printMultipleUseItems()
    
    mq.cmdf("/g " .. mq.TLO.Me.Name() .. " is done Looting")
end

function LootManager.queueItem(line, groupMemberName, corpseId, itemId)
    local myName = tostring(mq.TLO.Me.Name())
    
    if groupMemberName ~= myName then
        return
    end
    
    mq.cmdf("/g " .. myName .. " is adding itemId(" .. itemId .. ") and corpseId(" .. corpseId .. ") to my loot queue")
    
    local queuedItem = {
        corpseId = corpseId,
        itemId = itemId
    }

    Utils.multimapInsert(LootManager.myQueuedItems, corpseId, queuedItem)

    -- Remove from multiple use table
    for idx, items in pairs(LootManager.multipleUseTable) do
        if tostring(idx) == tostring(corpseId) then
            for idx2, tbl in pairs(items) do
                if tostring(tbl.itemId) == tostring(itemId) then
                    table.remove(items, idx2)
                end
            end
        end
    end
end

-- ============================================================================
-- GUI Module
-- ============================================================================
local GUI = {}
GUI.radioSelectedOption = 0
GUI.groupMemberSelected = mq.TLO.Me.Name()

function GUI.createGUI()
    return function(open)
        local main_viewport = imgui.GetMainViewport()
        imgui.SetNextWindowPos(main_viewport.WorkPos.x + 800, main_viewport.WorkPos.y + 20, ImGuiCond.Once)
        imgui.SetNextWindowSize(475, 245, ImGuiCond.Always)
        
        local show
        open, show = imgui.Begin("Master Looter", open)
        
        if not show then
            imgui.End()
            return open
        end
        
        GUI.initializeDefaults()
        
        imgui.PushItemWidth(imgui.GetFontSize() * -12)

        GUI.renderActionButtons()
        imgui.Separator()
        GUI.renderGroupMemberSelection()
        imgui.Separator()
        GUI.renderItemListBox()


        imgui.SameLine()
        imgui.Spacing()
        imgui.PopItemWidth()
        imgui.End()
        
        return open
    end
end

function GUI.initializeDefaults()
    if GUI.radioSelectedOption == nil then
        GUI.radioSelectedOption = 0
        local firstMember = mq.TLO.Group.Member(0).Name()
        if firstMember then
            GUI.groupMemberSelected = firstMember
        end
    end
    
    if LootManager.listboxSelectedOption == nil and next(LootManager.multipleUseTable) ~= nil then
        LootManager.listboxSelectedOption = {}
    end
end

function GUI.renderActionButtons()
    ImGui.SetWindowFontScale(0.7)
    -- if imgui.Button("Master Loot") then
    --     mq.cmdf("/mlml")
    -- end
    
    -- imgui.SameLine()
    if imgui.Button("Loot") then
        GUI.executePeerLoot()
    end
    
    imgui.SameLine()
    if imgui.Button("Queue Shared Item") then
        GUI.executeQueueItem()
    end

    imgui.SameLine()
    if imgui.Button("Get Shared Item(s)") then
        GUI.executeLootItems()
    end
    
    imgui.SameLine()
    if imgui.Button("Reload INI") then
        INIManager.reloadConfig()
    end

    imgui.SameLine()
    local warpLabel = Config.useWarp and "Use Warp (ON)" or "Use Nav (OFF)"
    if imgui.Button(warpLabel) then
        Config.useWarp = not Config.useWarp
        INIManager.saveSettings()
        local mode = Config.useWarp and "WARP" or "NAV"
        print("Navigation mode changed to: " .. mode)
        mq.cmdf("/g Navigation mode: " .. mode)
    end

    imgui.SameLine()
    if imgui.Button("Clear Shared List") then
        LootManager.multipleUseTable = {}
    end
    ImGui.SetWindowFontScale(1.0)
end

function GUI.executePeerLoot()
    if GUI.groupMemberSelected == tostring(mq.TLO.Me.Name()) then
        mq.cmdf("/say #corpsefix")
        mq.cmdf("/mlml")
    else
        mq.cmdf("/dex %s /say #corpsefix", GUI.groupMemberSelected)
        mq.cmdf("/dex %s /mlml", GUI.groupMemberSelected)
    end
end

function GUI.executeQueueItem()
    -- Check if a valid item is selected
    if not LootManager.listboxSelectedOption or 
       not LootManager.listboxSelectedOption.corpseId or 
       not LootManager.listboxSelectedOption.itemId then
        print("No item selected to queue")
        return
    end
    
    mq.cmdf("/g mlqi %s %d %d", 
        GUI.groupMemberSelected, 
        LootManager.listboxSelectedOption.corpseId, 
        LootManager.listboxSelectedOption.itemId)

    -- Remove from multiple use table
    for idx, items in pairs(LootManager.multipleUseTable) do
        if tostring(idx) == tostring(LootManager.listboxSelectedOption.corpseId) then
            for idx2, tbl in pairs(items) do
                if tostring(tbl.itemId) == tostring(LootManager.listboxSelectedOption.itemId) then
                    table.remove(items, idx2)
                end
            end
        end
    end
end

function GUI.executeLootItems()
    if GUI.groupMemberSelected == tostring(mq.TLO.Me.Name()) then
        mq.cmdf("/say #corpsefix")
        mq.cmdf("/mlli")
    else
        mq.cmdf("/dex %s /say #corpsefix", GUI.groupMemberSelected)
        mq.cmdf("/dex %s /mlli", GUI.groupMemberSelected)
    end
end

function GUI.renderGroupMemberSelection()
    local groupSize = (mq.TLO.Group.GroupSize() or 0) - 1

    if groupSize >= 0 then
        for i = 0, groupSize do
            local memberName = mq.TLO.Group.Member(i).Name()
            local isActive = (GUI.radioSelectedOption == i)
            
            ImGui.SetWindowFontScale(0.7)
            if imgui.RadioButton(memberName, isActive) then
                GUI.radioSelectedOption = i
                GUI.groupMemberSelected = memberName
            end
            ImGui.SetWindowFontScale(1.0)
            if i < groupSize then
                imgui.SameLine()
            end
        end
    end
end

function GUI.renderItemListBox()
    imgui.SetNextItemWidth(300)

    -- Get the height of one item and subtract it
    local itemHeight = imgui.GetTextLineHeightWithSpacing()
    local height = -itemHeight*2  -- Negative value means "use remaining space minus this amount"

    if imgui.BeginListBox("", 0, height) then
        for idx, items in pairs(LootManager.multipleUseTable) do
            for idx2, tbl in ipairs(items) do
                local isSelected = false
                
                if LootManager.listboxSelectedOption == nil then
                    isSelected = true
                    LootManager.listboxSelectedOption = tbl
                else
                    isSelected = (LootManager.listboxSelectedOption.itemId == tbl.itemId) and 
                                (LootManager.listboxSelectedOption.corpseId == idx) 
                end

                local selectableText = string.format("%s (%d)", tbl.itemName, idx)
                if imgui.Selectable(selectableText, isSelected) then
                    LootManager.listboxSelectedOption = tbl
                end
                
                if isSelected then
                    imgui.SetItemDefaultFocus()
                end
            end
        end
        imgui.EndListBox()
    end
end

-- ============================================================================
-- Command Handlers
-- ============================================================================
local Commands = {}
Commands.loopBoolean = true

function Commands.stopScript()
    Commands.loopBoolean = false
end

function Commands.ReportUnlootedCorpses(line)
    -- Get all corpses within radius
    local nearbyCorpses = CorpseManager.getCorpseTable(mq.TLO.SpawnCount("npccorpse radius 200 zradius 10")())
    
    -- Find corpses that are NOT in the looted list
    local unlootedCorpses = {}
    for i, corpse in ipairs(nearbyCorpses) do
        local isLooted = false
        for j, lootedCorpse in ipairs(LootManager.lootedCorpses) do
            if corpse.ID == lootedCorpse then
                isLooted = true
                break
            end
        end
        
        if not isLooted then
            table.insert(unlootedCorpses, corpse)
        end
    end
    
    -- Print unlooted corpses
    mq.cmdf("/g "..mq.TLO.Me.Name().." unlooted corpses: " .. #unlootedCorpses)
    for i, corpse in ipairs(unlootedCorpses) do
        mq.cmdf("/g "..mq.TLO.Me.Name().."'s unlooted corpse: " .. tostring(corpse.ID))
    end
end

function Commands.testItem()
    print("Testing looted corpses")
    print("Number of looted corpses: " .. #LootManager.lootedCorpses)
    
    -- Get all corpses within radius
    local nearbyCorpses = CorpseManager.getCorpseTable(mq.TLO.SpawnCount("npccorpse radius 200 zradius 10")())

    print("Number of nearby corpses: " .. #nearbyCorpses)
    
    -- Find corpses that are NOT in the looted list
    local unlootedCorpses = {}
    for i, corpse in ipairs(nearbyCorpses) do
        local isLooted = false
        for j, lootedCorpse in ipairs(LootManager.lootedCorpses) do
            if corpse.ID == lootedCorpse then
                isLooted = true
                break
            end
        end
        
        if not isLooted then
            table.insert(unlootedCorpses, corpse)
        end
    end
    
    -- Print unlooted corpses
    print("Number of unlooted corpses: " .. #unlootedCorpses)
    for i, corpse in ipairs(unlootedCorpses) do
        print("Unlooted corpse: " .. tostring(corpse.ID))
    end
end

function Commands.masterLoot()
    LootManager.multipleUseTable = {}
    LootManager.doLoot(true)
end

function Commands.peerLoot()
    LootManager.doLoot(false)
end

-- ============================================================================
-- Main Script
-- ============================================================================
local openGUI = true

print("LootUtil has been started")
print("INI file location: " .. Config.iniFile)

-- Load configuration from INI
INIManager.loadConfig()

mq.cmdf("/lootnodrop never")

-- Register commands
mq.bind("/mlml", Commands.masterLoot)
mq.bind("/mlli", LootManager.lootQueuedItems)
mq.bind("/mlsl", Commands.stopScript)
mq.bind("/ti", Commands.testItem)
mq.bind("/mlrc", INIManager.reloadConfig)
mq.bind("/mlru", Commands.ReportUnlootedCorpses)

-- Register events
mq.event('peerLootItem', "#*#mlqi #1# #2# #3#'", LootManager.queueItem)
mq.event('shareLootItem', "#*#mlsi #1# #2# \"#3#\"'", LootManager.shareLootItem)
mq.event('reportUnlooted', '#*#mlru#*#', Commands.ReportUnlootedCorpses)
-- Register GUI
ImGui.Register('masterLootGui', GUI.createGUI())

-- Main loop
while openGUI do
    mq.doevents()
    mq.delay(1)
end
