local mq = require('mq')
local imgui = require('ImGui')

-- ============================================================================
-- Configuration
-- ============================================================================
local Config = {
    chatConfig = "/djoin classLoot",
    chatChannel = "/dgtell classLoot ",
    defaultAllowCombatLooting = false,
    defaultSlotsToKeepFree = 2,
    lootRadius = 50,
    useWarp = false,
    itemsToKeep = {
        'Green Stone of Minor Advancement',
        'Frosty Stone of Hearty Advancement',
        'Fiery Stone of Incredible Advancement',
        'Moneybags - Bag of Platinum Pieces',
        'Moneybags - Heavy Bag of Platinum!',
        "Unidentified Item",
        "Epic Gemstone of Immortality"
    },
    itemsToShare = {
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
}

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

function Utils.chatMessage(message)
    return string.format("%s %s", Config.chatChannel, message)
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
        mq.cmdf("/warp loc %d %d %d", y, x, z)
    else
        mq.cmdf("/nav locxyz %d %d %d", x, y, z)
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

function ItemEvaluator.shouldLoot(corpseItem)
    -- Check if player can use the item
    if corpseItem.CanUse() then
        -- Skip lore items we already own
        if corpseItem.Lore() and Utils.ownItem(corpseItem.Name()) then
            print("Item is Lore and I already own one, skipping.")
            return false
        end
        
        -- Skip No Drop/No Trade items multiple group members can use
        if (corpseItem.NoDrop() or corpseItem.NoTrade()) and 
           (ItemEvaluator.groupMembersCanUse(corpseItem) > 1) then
            print("Item is No Drop/No Trade and multiple group members can use, skipping.")
            mq.cmdf('/g ***' .. corpseItem.ItemLink('CLICKABLE')() .. '*** can be used by multiple classes')
            return false
        end
        
        -- Loot wearable items
        for i = 1, corpseItem.WornSlots() do
            if corpseItem.WornSlot(i).ID() < 23 then
                print("Item is wearable and usable, looting.")
                return true
            end
        end
    end
    
    -- Loot valuable items
    if (corpseItem.Value() or 0) > 1000 then
        print("Value > 1000, looting.")
        return true
    end
    
    -- Loot valuable stackables
    if corpseItem.Stackable() and (corpseItem.Value() or 0) >= 100 then
        print("Stackable and value >= 100, looting.")
        return true
    end
    
    -- Check items to keep list
    if Utils.contains(Config.itemsToKeep, corpseItem.Name()) then
        print("Item is in keep list, looting.")
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
        local spawn = mq.TLO.NearestSpawn(i, "npccorpse radius 200")
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

function LootManager.lootCorpse(corpseObject, isMaster)
    mq.cmdf("/target id %d", corpseObject.ID)
    mq.cmdf("/loot")
    
    mq.delay("5s", function() return mq.TLO.Window("LootWnd").Open() end)
    
    if not mq.TLO.Window("LootWnd").Open() then
        mq.cmdf("/g Could not loot targeted corpse, skipping.")
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

        if ItemEvaluator.shouldLoot(corpseItem) and not isSharedItem then
            LootManager.lootItem(corpseItem, i)
        else
            if isMaster and (ItemEvaluator.groupMembersCanUse(corpseItem) > 1 or isSharedItem) then
                LootManager.addToMultipleUseTable(corpseObject, corpseItem)
            end
        end
        
        if mq.TLO.Cursor then
            mq.cmdf("/autoinventory")
        end
    end
    
    LootManager.closeLootWindow()
end

function LootManager.lootItem(corpseItem, slotIndex)
    mq.cmdf('/g ' .. corpseItem.ItemLink('CLICKABLE')())
    mq.cmdf("/shift /itemnotify loot%d rightmouseup", slotIndex)
    mq.delay(500)
    
    if mq.TLO.Window("QuantityWnd").Open() then
        mq.cmdf("/notify QuantityWnd QTYW_Accept_Button leftmouseup")
        mq.delay(300)
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

function LootManager.printMultipleUseItems()
    if LootManager.multipleUseTable == nil then
        return
    end

    mq.cmdf('/g *** Multi Class No Drop/No Trade Items ***')
    print('*** Multi Class No Drop/No Trade Items ***')
    
    for _, items in pairs(LootManager.multipleUseTable) do
        for _, tbl in ipairs(items) do
            mq.cmdf('/g  ' .. tbl.itemObject.ItemLink('CLICKABLE')())
            print(tbl.itemObject.ItemLink('CLICKABLE')())
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
    mq.delay(500)
    mq.cmdf("/target id %d", corpseId)
    
    if Config.useWarp then
        mq.cmdf("/warp t")
    else
        mq.cmdf("/nav target")
    end
    
    mq.delay(500)
    mq.cmdf("/loot")
    
    local retryCount = 0
    local retryMax = 5

    while not mq.TLO.Window("LootWnd").Open() and (retryCount < retryMax) do
        mq.cmdf("/squelch /say #corpsefix")
        mq.delay(500)
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
                mq.delay(500)
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
    repeat
        local corpseTable = CorpseManager.getCorpseTable(mq.TLO.SpawnCount("npccorpse radius 200")())
        local currentCorpse
        currentCorpse, corpseTable = CorpseManager.getNearestCorpse(corpseTable)
        
        while currentCorpse do
            mq.cmdf("/squelch /hidecor looted")
            
            Navigation.navigateToLocation(
                math.floor(currentCorpse.X),
                math.floor(currentCorpse.Y),
                math.floor(currentCorpse.Z)
            )
            
            mq.delay("2s")
            LootManager.lootCorpse(currentCorpse, isMaster)
            currentCorpse, corpseTable = CorpseManager.getNearestCorpse(corpseTable)
        end
    until mq.TLO.SpawnCount("npccorpse radius 200")() == 0
    
    -- Return to starting location
    Navigation.navigateToLocation(startingLocation.X, startingLocation.Y, startingLocation.Z)
    mq.delay(startingLocation.timeToWait)
    
    LootManager.printMultipleUseItems()
    
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
        imgui.SetNextWindowPos(main_viewport.WorkPos.x + 650, main_viewport.WorkPos.y + 20, ImGuiCond.Once)
        imgui.SetNextWindowSize(500, 300, ImGuiCond.Once)
        
        local show
        open, show = imgui.Begin("Master Looter", open)
        
        if not show then
            imgui.End()
            return open
        end
        
        GUI.initializeDefaults()
        
        imgui.PushItemWidth(imgui.GetFontSize() * -12)
        
        GUI.renderNavigationToggle()
        imgui.Separator()
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

function GUI.renderNavigationToggle()
    local warpLabel = Config.useWarp and "Use Warp (ON)" or "Use Nav (OFF)"
    if imgui.Button(warpLabel) then
        Config.useWarp = not Config.useWarp
        local mode = Config.useWarp and "WARP" or "NAV"
        print("Navigation mode changed to: " .. mode)
        mq.cmdf("/g Navigation mode: " .. mode)
    end
end

function GUI.renderActionButtons()
    if imgui.Button("Master Loot") then
        mq.cmdf("/mlml")
    end
    
    imgui.SameLine()
    if imgui.Button("Peer Loot") then
        GUI.executePeerLoot()
    end
    
    imgui.SameLine()
    if imgui.Button("Queue Item") then
        GUI.executeQueueItem()
    end

    imgui.SameLine()
    if imgui.Button("Loot Item(s)") then
        GUI.executeLootItems()
    end
end

function GUI.executePeerLoot()
    if GUI.groupMemberSelected == tostring(mq.TLO.Me.Name()) then
        mq.cmdf("/say #corpsefix")
        mq.cmdf("/hidecorpse none")
        mq.cmdf("/mlpl")
    else
        mq.cmdf("/dex %s /say #corpsefix", GUI.groupMemberSelected)
        mq.cmdf("/dex %s /hidecorpse none", GUI.groupMemberSelected)
        mq.cmdf("/dex %s /mlpl", GUI.groupMemberSelected)
    end
end

function GUI.executeQueueItem()
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
        mq.cmdf("/hidecorpse none")
        mq.cmdf("/mlli")
    else
        mq.cmdf("/dex %s /say #corpsefix", GUI.groupMemberSelected)
        mq.cmdf("/dex %s /hidecorpse none", GUI.groupMemberSelected)
        mq.cmdf("/dex %s /mlli", GUI.groupMemberSelected)
    end
end

function GUI.renderGroupMemberSelection()
    local groupSize = (mq.TLO.Group.GroupSize() or 0) - 1

    if groupSize >= 0 then
        for i = 0, groupSize do
            local memberName = mq.TLO.Group.Member(i).Name()
            local isActive = (GUI.radioSelectedOption == i)
            
            if imgui.RadioButton(memberName, isActive) then
                GUI.radioSelectedOption = i
                GUI.groupMemberSelected = memberName
            end

            if i < groupSize then
                imgui.SameLine()
            end
        end
    end
end

function GUI.renderItemListBox()
    imgui.SetNextItemWidth(300)

    if imgui.BeginListBox("") then
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

function Commands.testItem()
    print("Testing Item: " .. mq.TLO.Cursor.Name())
    local result = ItemEvaluator.shouldLoot(mq.TLO.Cursor)
    print("Result: " .. tostring(result))
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

-- Register commands
mq.bind("/mlml", Commands.masterLoot)
mq.bind("/mlpl", Commands.peerLoot)
mq.bind("/mlli", LootManager.lootQueuedItems)
mq.bind("/mlsl", Commands.stopScript)
mq.bind("/ti", Commands.testItem)

-- Register events
mq.event('peerLootItem', "#*#mlqi #1# #2# #3#'", LootManager.queueItem)

-- Join chat channel
mq.cmdf(Config.chatConfig)

-- Register GUI
ImGui.Register('masterLootGui', GUI.createGUI())

-- Main loop
while openGUI do
    mq.doevents()
    mq.delay(1)
end

print("MasterLoot is exiting.")
