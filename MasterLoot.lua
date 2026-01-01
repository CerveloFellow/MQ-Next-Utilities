local mq = require('mq')
local imgui = require('ImGui')
local actors = require('actors')

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
-- Actor Module
-- ============================================================================
local ActorManager = {}
ActorManager.actorMailbox = nil
ActorManager.handleShareItem = nil

-- ============================================================================
-- Loot Manager Module (Declaration - moved up)
-- ============================================================================
local LootManager = {}
LootManager.multipleUseTable = {}
LootManager.myQueuedItems = {}
LootManager.listboxSelectedOption = {}
LootManager.lootedCorpses = {}

function ActorManager.broadcastClearSharedList()
    local groupSize = (mq.TLO.Group.GroupSize() or 0) - 1
    
    if groupSize >= 0 then
        for i = 0, groupSize do
            local memberName = mq.TLO.Group.Member(i).Name()
            
            if memberName and memberName ~= mq.TLO.Me.Name() then
                local message = {
                    type = 'clearSharedList'
                }
                
                if ActorManager.actorMailbox then
                    ActorManager.actorMailbox:send({to=memberName}, message)
                end
            end
        end
    end
end

function ActorManager.initialize()
    ActorManager.actorMailbox = actors.register('masterloot', function(message)
        local actualMessage = message
        if type(message) == "userdata" then
            local success, result = pcall(function() return message() end)
            if success and type(result) == "table" then
                actualMessage = result
            else
                return
            end
        end
        
        if type(actualMessage) == "table" then
            if actualMessage.type == 'shareItem' then
                if ActorManager.handleShareItem then
                    ActorManager.handleShareItem(actualMessage)
                end
            elseif actualMessage.type == 'clearSharedList' then
                -- Clear the local shared list
                LootManager.multipleUseTable = {}
                LootManager.listboxSelectedOption = {}
                print(mq.TLO.Me.Name()..": Shared loot list cleared by group leader")
            end
        end
    end)
    
    if ActorManager.actorMailbox then
        print("Actor mailbox registered: masterloot")
    end
end

function ActorManager.setHandleShareItem(handlerFunc)
    ActorManager.handleShareItem = handlerFunc
end

function ActorManager.broadcastShareItem(corpseId, itemId, itemName, itemLink)
    local groupSize = (mq.TLO.Group.GroupSize() or 0) - 1
    
    if groupSize >= 0 then
        for i = 0, groupSize do
            local memberName = mq.TLO.Group.Member(i).Name()
            
            if memberName and memberName ~= mq.TLO.Me.Name() then
                local message = {
                    type = 'shareItem',
                    corpseId = corpseId,
                    itemId = itemId,
                    itemName = itemName,
                    itemLink = itemLink
                }
                
                if ActorManager.actorMailbox then
                    ActorManager.actorMailbox:send({to=memberName}, message)
                end
            end
        end
    end
end

-- ============================================================================
-- INI Management Module
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
    -- Validate coordinates before attempting navigation
    if not x or not y or not z then
        print("ERROR: Invalid coordinates - x:" .. tostring(x) .. " y:" .. tostring(y) .. " z:" .. tostring(z))
        return false
    end
    
    if Config.useWarp then
        mq.cmdf("/warp loc %f %f %f", y, x, z)
    else
        mq.cmdf("/squelch /nav locxyz %d %d %d", x, y, z)
    end
    
    return true
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
    return false  -- Add this line
end

function ItemEvaluator.shouldLoot(corpseItem, debug)
    debug = debug or false
    
    if debug then print("=== Evaluating item: " .. corpseItem.Name() .. " ===") end
    
    -- Check if it's a shared item
    if Config.itemsToShare and Utils.contains(Config.itemsToShare, corpseItem.Name()) then
        if debug then print("Item to share - Skip: " .. corpseItem.Name()) end
        return false
    else
        if debug then print("Item not in share list - Continue") end
    end

    -- Check if player can use the item
    if Config.itemsToIgnore and Utils.contains(Config.itemsToIgnore, corpseItem.Name()) then
        if debug then print("Item to ignore - Skip: " .. corpseItem.Name()) end
        return false
    else
        if debug then print("Item not in ignore list - Continue") end
    end

    if corpseItem.CanUse() then
        if debug then print("Player can use this item - Continue") end
        
        -- Skip lore items we already own
        if corpseItem.Lore() and Utils.ownItem(corpseItem.Name()) then
            if debug then print("Lore Item and I own it - Skip: " .. corpseItem.Name()) end
            return false
        else
            if debug then 
                if corpseItem.Lore() then
                    print("Lore item but don't own it - Continue")
                else
                    print("Not a lore item - Continue")
                end
            end
        end
        
        -- Skip No Drop/No Trade items multiple group members can use
        if (corpseItem.NoDrop() or corpseItem.NoTrade()) and 
           (ItemEvaluator.groupMembersCanUse(corpseItem) > 1) then
            if debug then print("Item is No Drop/No Trade and multiple group members can use, skipping: " .. corpseItem.Name()) end
            mq.cmdf('/g ***' .. corpseItem.ItemLink('CLICKABLE')() .. '*** can be used by multiple classes')
            return false
        else
            if debug then 
                if corpseItem.NoDrop() or corpseItem.NoTrade() then
                    print("Item is No Drop/No Trade but only usable by this player - Continue")
                else
                    print("Item is tradeable - Continue")
                end
            end
        end
        
        -- Loot wearable items
        if corpseItem.WornSlots() > 0 then
            if debug then print("Item has " .. corpseItem.WornSlots() .. " worn slot(s) - Checking slots") end
            for i = 1, corpseItem.WornSlots() do
                if corpseItem.WornSlot(i).ID() < 23 then
                    if debug then print("Item is wearable slot item (Slot ID: " .. corpseItem.WornSlot(i).ID() .. ") - Looting: " .. corpseItem.Name()) end
                    return true
                else
                    if debug then print("Worn slot " .. i .. " ID (" .. corpseItem.WornSlot(i).ID() .. ") >= 23 - Continue") end
                end
            end
            if debug then print("No valid worn slots found - Continue") end
        else
            if debug then print("Item has no worn slots - Continue") end
        end
    else
        if debug then print("Player cannot use this item - Continue") end
    end
    
    -- Loot valuable items
    if (corpseItem.Value() or 0) > Config.lootSingleMinValue then
        if debug then print("Value greater than single item min value - Looting: " .. corpseItem.Name() .. " (Value: " .. (corpseItem.Value() or 0) .. ", Min: " .. Config.lootSingleMinValue .. ")") end
        return true
    else
        if debug then print("Value (" .. (corpseItem.Value() or 0) .. ") not greater than min value (" .. Config.lootSingleMinValue .. ") - Continue") end
    end
    
    -- Loot valuable stackables
    if corpseItem.Stackable() then
        if debug then print("Item is stackable - Checking value") end
        if (corpseItem.Value() or 0) >= Config.lootSingleMinValue then
            if debug then print("Value greater than or equal to stacked item min value - Looting: " .. corpseItem.Name() .. " (Value: " .. (corpseItem.Value() or 0) .. ", Min: " .. Config.lootSingleMinValue .. ")") end
            return true
        else
            if debug then print("Stackable value (" .. (corpseItem.Value() or 0) .. ") less than min value (" .. Config.lootSingleMinValue .. ") - Continue") end
        end
    else
        if debug then print("Item is not stackable - Continue") end
    end
    
    -- Check items to keep list
    if Utils.contains(Config.itemsToKeep, corpseItem.Name()) then
        if debug then print("Item in keep list - Looting: " .. corpseItem.Name()) end
        return true
    else
        if debug then print("Item not in keep list - Continue") end
    end
    
    if debug then print("No matching criteria - Skip: " .. corpseItem.Name()) end
    if debug then print("=== End evaluation ===") end
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
        
        -- Validate spawn exists and has valid coordinates
        if spawn and spawn.ID() and spawn.ID() > 0 then
            local x, y, z = spawn.X(), spawn.Y(), spawn.Z()
            
            if x and y and z then
                local corpse = {
                    ID = spawn.ID(),
                    Name = spawn.Name(),
                    Distance = spawn.Distance(),
                    DistanceZ = spawn.DistanceZ(),
                    X = x,
                    Y = y,
                    Z = z
                }
                table.insert(corpseTable, corpse)
            end
        end
    end
    
    return corpseTable
end

function CorpseManager.getRandomCorpse(corpseTable)
    if #corpseTable == 0 then
        return nil, corpseTable
    end
    
    local randomIndex = math.random(1, #corpseTable)
    local randomCorpse = table.remove(corpseTable, randomIndex)
    return randomCorpse, corpseTable
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

function LootManager.handleSharedItem(message)
    local item = {
        corpseId = message.corpseId,
        itemId = message.itemId,
        itemName = message.itemName,
        itemLink = message.itemLink
    }

    if next(LootManager.listboxSelectedOption) == nil then
        LootManager.listboxSelectedOption = {
            corpseId = message.corpseId,
            itemId = message.itemId,
            itemName = message.itemName
        }
    end
    
    Utils.multimapInsert(LootManager.multipleUseTable, message.corpseId, item)
end

function LootManager.printMultipleUseItems()
    mq.cmdf("/g List of items that can be used by members of your group")
    for key, valueList in pairs(LootManager.multipleUseTable) do
        print("Key:", key)
        for _, value in ipairs(valueList) do
            mq.cmdf("/g %s", value.itemLink)
        end
    end
end

function LootManager.isLooted(corpseId)
    return Utils.contains(LootManager.lootedCorpses, corpseId)
end

function LootManager.lootCorpse(corpseObject, isMaster)
    mq.cmdf("/target id %d", corpseObject.ID)

    mq.delay(300)

    mq.cmdf("/loot")
    
    mq.delay("5s", function() return mq.TLO.Window("LootWnd").Open() end)
    
    local retryCount = 0
    local maxRetries = 1

    if (not mq.TLO.Window("LootWnd").Open()) then
        while retryCount < maxRetries do
            --mq.cmdf("/g Could not loot targeted corpse id(%d), retrying.", corpseObject.ID)
            mq.cmdf("/say #corpsefix")
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
            --mq.cmdf("/g Failed to loot corpse id(%d) after %d attempts.", corpseObject.ID, maxRetries)
            return
        end
    end

    if((mq.TLO.Target.ID() or 0)==0) then
        table.insert(LootManager.lootedCorpses, corpseObject.ID)
        return
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
                -- Show the item link in group chat
                mq.cmdf("/g Shared Item: "..corpseItem.ItemLink('CLICKABLE')())
                
                -- Use actors to broadcast the item to all group members
                ActorManager.broadcastShareItem(
                    corpseObject.ID, 
                    corpseItem.ID(), 
                    corpseItem.Name(), 
                    corpseItem.ItemLink('CLICKABLE')()
                )
            else
                print("------------------------------------------")
                print(corpseItem.Name() or "nil")
                print("Number of group members that can use: "..tostring(ItemEvaluator.groupMembersCanUse(corpseItem)))
                print("Shared Item: "..tostring(isSharedItem))
                print("Skip Item: "..tostring(ItemEvaluator.skipItem(corpseItem)))
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
    mq.cmdf('/g '..mq.TLO.Me.Name().." is looting ".. corpseItem.ItemLink('CLICKABLE')())
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

function LootManager.lootQueuedItems()
    -- Ensure myQueuedItems is initialized
    if not LootManager.myQueuedItems then
        LootManager.myQueuedItems = {}
        print("No items in queue to loot")
        return
    end

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
    --mq.cmd("/say #corpsefix")
    --mq.delay(300)
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
        mq.cmdf("/say #corpsefix")
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
    --LootManager.multipleUseTable = {}
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

    while #corpseTable > 0 do
        local currentCorpse
        print("Corpses Remaining: "..tostring(#corpseTable))
        currentCorpse, corpseTable = CorpseManager.getRandomCorpse(corpseTable)
        
        if currentCorpse and not LootManager.isLooted(currentCorpse.ID) then
            local navSuccess = Navigation.navigateToLocation(
                currentCorpse.X,
                currentCorpse.Y,
                currentCorpse.Z
            )
            
            if navSuccess then
                if Config.useWarp then
                    mq.delay(500)
                else
                    mq.delay("2s")
                end
                LootManager.lootCorpse(currentCorpse, isMaster)
            else
                print("Failed to navigate to corpse ID: " .. currentCorpse.ID)
            end
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
        if firstMember and firstMember ~= "" then
            GUI.groupMemberSelected = firstMember
        else
            local myName = mq.TLO.Me.Name()
            GUI.groupMemberSelected = myName or "Unknown"
        end
    end
    
    if LootManager.listboxSelectedOption == nil and next(LootManager.multipleUseTable) ~= nil then
        LootManager.listboxSelectedOption = {}
    end
end

function GUI.renderActionButtons()
    ImGui.SetWindowFontScale(0.7)
    
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
    -- local warpLabel = Config.useWarp and "Use Warp (ON)" or "Use Nav (OFF)"
    -- if imgui.Button(warpLabel) then
    --     Config.useWarp = not Config.useWarp
    --     INIManager.saveSettings()
    --     local mode = Config.useWarp and "WARP" or "NAV"
    --     print("Navigation mode changed to: " .. mode)
    --     mq.cmdf("/g Navigation mode: " .. mode)
    -- end
    if imgui.Button("Everyone Loot") then
        GUI.everyoneLoot()
    end

    imgui.SameLine()
    if imgui.Button("Clear Shared List") then
        -- Clear locally
        LootManager.multipleUseTable = {}
        LootManager.listboxSelectedOption = {}
        
        -- Broadcast to all group members
        ActorManager.broadcastClearSharedList()
        
        mq.cmdf("/g Shared loot list cleared")
    end
    ImGui.SetWindowFontScale(1.0)
end

function GUI.everyoneLoot()
    --mq.cmdf("/dgga /say #corpsefix")
    mq.cmdf("/dgga /mlml")
end

function GUI.executePeerLoot()
    local myName = mq.TLO.Me.Name()
    if not myName then
        print("ERROR: Unable to get character name")
        return
    end
    
    if GUI.groupMemberSelected == myName then
        --mq.cmdf("/say #corpsefix")
        mq.cmdf("/mlml")
    else
        --mq.cmdf("/dex %s /say #corpsefix", GUI.groupMemberSelected)
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
    local myName = mq.TLO.Me.Name()
    if not myName then
        print("ERROR: Unable to get character name")
        return
    end
    
    if GUI.groupMemberSelected == myName then
        --mq.cmdf("/say #corpsefix")
        mq.cmdf("/mlli")
    else
        --mq.cmdf("/dex %s /say #corpsefix", GUI.groupMemberSelected)
        mq.cmdf("/dex %s /mlli", GUI.groupMemberSelected)
    end
end

function GUI.executeReportUnlootedCorpses()
    mq.cmdf("/g /mlru")
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
    
    -- Add Print Items button to the right of the listbox
    imgui.SameLine()
    ImGui.SetWindowFontScale(0.7)
    imgui.BeginGroup()
    if imgui.Button("Print Item Links") then
        LootManager.printMultipleUseItems()
    end

    if imgui.Button("Print Unlooted\nCorpses") then
        GUI.executeReportUnlootedCorpses()
    end
    imgui.EndGroup()
    ImGui.SetWindowFontScale(1.0)
end

-- ============================================================================
-- Command Handlers
-- ============================================================================
local Commands = {}
Commands.loopBoolean = true

function Commands.testShared()
    if mq.TLO.Cursor() then
        local cursorName = mq.TLO.Cursor.Name()
        if cursorName then
            result = Utils.contains(Config.itemsToShare, cursorName)
            print("Shared item status: "..tostring(result))
        end
    end
end

function Commands.testItem()
    if mq.TLO.Cursor() then
        local cursorName = mq.TLO.Cursor.Name()
        if cursorName then
            result = ItemEvaluator.shouldLoot(mq.TLO.Cursor, true)
        end
    end
end

function Commands.testCorpse()
    -- Check if loot window is open
    if not mq.TLO.Window("LootWnd").Open() then
        print("ERROR: No corpse is open for looting. Please open a corpse first.")
        mq.cmdf("/g No corpse is open for looting. Please open a corpse first.")
        return
    end
    
    local itemCount = tonumber(mq.TLO.Corpse.Items()) or 0
    
    if itemCount == 0 then
        print("Corpse has no items.")
        mq.cmdf("/g Corpse has no items.")
        return
    end
    
    print(string.format("=== Testing %d items on corpse ===", itemCount))
    mq.cmdf("/g Testing %d items on corpse", itemCount)
    
    for i = 1, itemCount do
        mq.delay("3s", function() return mq.TLO.Corpse.Item(i).ID() end)
        local corpseItem = mq.TLO.Corpse.Item(i)
        
        if corpseItem and corpseItem.ID() then
            print(string.format("\n--- Item %d/%d ---", i, itemCount))
            local shouldLoot = ItemEvaluator.shouldLoot(corpseItem, true)
            print(string.format("RESULT: %s", shouldLoot and "LOOT" or "SKIP"))
        end
    end
    
    print("=== Corpse test complete ===")
    mq.cmdf("/g Corpse test complete")
end

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
    if (#unlootedCorpses > 0) then
        mq.cmdf("/g "..mq.TLO.Me.Name().." unlooted corpses: " .. #unlootedCorpses)
    end
end

function Commands.masterLoot()
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

-- Initialize Actor System and register the handler
ActorManager.initialize()
ActorManager.setHandleShareItem(LootManager.handleSharedItem)

mq.cmdf("/lootnodrop never")

-- Register commands
mq.bind("/mlml", Commands.masterLoot)
mq.bind("/mlli", LootManager.lootQueuedItems)
mq.bind("/mlsl", Commands.stopScript)
mq.bind("/ti", Commands.testItem)
mq.bind("/tcl", Commands.testCorpse)
mq.bind("/tis", Commands.testShared)
mq.bind("/mlrc", INIManager.reloadConfig)
mq.bind("/mlru", Commands.ReportUnlootedCorpses)
mq.bind("/mlpm", LootManager.printMultipleUseItems)

-- Register events (only for queueing items)
mq.event('peerLootItem', "#*#mlqi #1# #2# #3#'", LootManager.queueItem)
mq.event('reportUnlooted', '#*#mlru#*#', Commands.ReportUnlootedCorpses)

-- Register GUI
ImGui.Register('masterLootGui', GUI.createGUI())

-- Main loop
while openGUI do
    mq.doevents()
    mq.delay(1)
end
