--[[
    Master Loot Utilities
    LUA utilities to help manage group looting with multi-class item distribution

    See the README for usage https://github.com/CerveloFellow/MQ-Next-Utilities/blob/main/README.md
]]

local mq = require('mq')
local imgui = require('ImGui')

-- ============================================================================
-- LootUtil Class
-- ============================================================================
LootUtil = {}

function LootUtil.new()
    local self = {}
    
    -- Configuration
    self.chatConfig = "/djoin classLoot"
    self.chatChannel = "/dgtell classLoot "
    self.defaultAllowCombatLooting = false
    self.defaultSlotsToKeepFree = 2
    self.lootRadius = 50
    
    -- State
    self.loopBoolean = true
    self.currentCorpseTable = {}
    self.multipleUseTable = {}
    self.myQueuedItems = {}
    
    -- GUI State
    self.radioSelectedOption = 0
    self.groupMemberSelected = mq.TLO.Me.Name()
    self.listboxSelectedOption = {}
    self.listboxSelectedOption.corpseId = 0
    self.listboxSelectedOption.itemId = 0
    self.listboxSelectedOption.itemName = ""
    
    -- ========================================================================
    -- Utility Functions
    -- ========================================================================
    
    local function chatMessage(message)
        return string.format("%s %s", self.chatChannel, message)
    end
    
    local function ownItem(itemName)
        local itemCount = mq.TLO.FindItemCount('=' .. itemName)()
        return (itemCount > 0)
    end
    
    local function contains(tab, val)
        for index, value in ipairs(tab) do
            if value == val then
                return true
            end
        end
        return false
    end
    
    function multimap_insert(map, key, value)
        -- Check if the key already has a table value
        if map[key] == nil then
            -- If not, initialize it with a new empty table (array syntax {})
            map[key] = {}
        end
        
        -- Check if the value already exists in the table
        for _, v in pairs(map[key]) do
            if v.itemId == value.itemId then
                -- Value already exists, don't insert
                return false
            end
        end
        
        -- Insert the new value into the inner table
        table.insert(map[key], value)
        return true
    end

    function printTable(tbl, indent)
        if not indent then
            indent = 0
        end
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
                toprint = toprint .. printTable(v, indent + 2) .. ",\n"
            elseif type(v) == "string" then
                toprint = toprint .. "\"" .. v .. "\",\n"
            else
                toprint = toprint .. tostring(v) .. ",\n"
            end
        end

        toprint = toprint .. string.rep(" ", indent - 2) .. "}"
        return toprint
    end
    -- ========================================================================
    -- Item Evaluation Functions
    -- ========================================================================
    
    local function groupMembersCanUse(corpseItem)
        local returnCount = 0
        
        if corpseItem.NoDrop() or corpseItem.NoTrade() then
            for i = 1, corpseItem.Classes() do
                for j = 0, mq.TLO.Group.Members() do
                    if corpseItem.Class(i).Name() == mq.TLO.Group.Member(j).Class() then
                        returnCount = returnCount + 1
                    end
                end
            end
        end

        return returnCount
    end
    
    local function shouldLoot(corpseItem)
        return false
    end

    local function shouldILoot(corpseItem)
        local itemsToKeep = {
            'Green Stone of Minor Advancement',
            'Frosty Stone of Hearty Advancement',
            'Fiery Stone of Incredible Advancement',
            'Moneybags - Bag of Platinum Pieces',
            'Moneybags - Heavy Bag of Platinum!',
            "Unidentified Item",
            "Epic Gemstone of Immortality"
        }
        local itemName = corpseItem.Name()

        -- Check if I can use it
        if corpseItem.CanUse() then
            -- If it's lore and I already own it, skip
            if corpseItem.Lore() and ownItem(corpseItem.Name()) then
                --print(itemName.." not looting due to Lore and I already own it.")
                return false
            end
            
            -- Check if multiple group members can use it
            if corpseItem.NoDrop() or corpseItem.NoTrade() then
                for i = 0, corpseItem.Classes() do
                    for j = 0, mq.TLO.Group.Members() do
                        if corpseItem.Class(i).Name() == mq.TLO.Group.Member(j).Class() then
                            mq.cmdf('/g ***' .. corpseItem.ItemLink('CLICKABLE')() .. '*** can be used by multiple classes')
                            --print(itemName.." not looting due No Drop/No Trade and multiple classes can use it")
                            return false
                        end
                    end
                end
            end
            
            -- Check if it's a wearable item
            for i = 1, corpseItem.WornSlots() do
                if corpseItem.WornSlot(i).ID() < 23 then
                    --print(itemName.." is wearable, so should loot.")
                    return true
                end
            end
        end
        
        -- Check item value
        if (corpseItem.Value() or 0) > 1000 then
            --print(itemName.." exceeds unstacked threshold of 1000("..(corpseItem.Value() or 0)..")")
            return true
        elseif corpseItem.Stackable() and (corpseItem.Value() or 0) >= 100 then
            --print(itemName.." exceeds stackable threshold of 100("..(corpseItem.Value() or 0)..")")
            return true
        else
            --print(itemName.." is low value "..(corpseItem.Value() or 0))
        end
        
        -- Check if it's in the keep list
        if contains(itemsToKeep, corpseItem.Name()) then
            --print(itemName.." is in the keep list")
            return true
        end
        
        return false
    end
    
    -- ========================================================================
    -- Corpse Management Functions
    -- ========================================================================
    
    local function getCorpseTable(numCorpses)
        local corpseTable = {}
        
        for i = 1, numCorpses do
            local tempSpawn = mq.TLO.NearestSpawn(i, "npccorpse radius 200")
            local corpse = {
                ID = tempSpawn.ID(),
                Name = tempSpawn.Name(),
                Distance = tempSpawn.Distance(),
                DistanceZ = tempSpawn.DistanceZ(),
                X = tempSpawn.X(),
                Y = tempSpawn.Y(),
                Z = tempSpawn.Z()
            }
            table.insert(corpseTable, corpse)
        end
        
        self.currentCorpseTable = corpseTable
    end
    
    local function getNearestCorpse()
        if #self.currentCorpseTable == 0 then
            return nil
        end
        
        local nearestCorpseIndex = 0
        local nearestCorpseDistance = 9999
        
        for i = 1, #self.currentCorpseTable do
            local c = self.currentCorpseTable[i]
            local distance = mq.TLO.Math.Distance(c.Y, c.X)()
            if distance < nearestCorpseDistance then
                nearestCorpseIndex = i
                nearestCorpseDistance = distance
            end
        end
        
        return table.remove(self.currentCorpseTable, nearestCorpseIndex)
    end
    
    -- ========================================================================
    -- Looting Functions
    -- ========================================================================
    
    local function lootCorpse(corpseObject, isMaster)
        mq.cmdf("/target id %d", corpseObject.ID)
        mq.cmdf("/loot")
        
        -- Wait for the LootWnd window to open
        mq.delay("5s", function() return mq.TLO.Window("LootWnd").Open() end)
        
        if not mq.TLO.Window("LootWnd").Open() then
            mq.cmdf("/g Could not loot targeted corpse, skipping.")
            return
        end
        
        local corpseItemCount = tonumber(mq.TLO.Corpse.Items()) or 0
        
        if corpseItemCount == 0 then
            if mq.TLO.Window("LootWnd").Open() then
                mq.cmdf("/notify LootWnd LW_DoneButton leftmouseup")
                mq.delay(100)
            end
            return
        end
        
        for i = 1, corpseItemCount do
            local inventorySlotsRemaining = mq.TLO.Me.FreeInventory() - self.defaultSlotsToKeepFree
            
            if inventorySlotsRemaining < 1 then
                mq.cmdf("/beep")
                mq.cmdf('/g ' .. mq.TLO.Me.Name() .. " inventory is Full!")
            end
            
            -- Wait for items to appear on the corpse
            mq.delay("3s", function() return mq.TLO.Corpse.Item(i).ID() end)
            local corpseItem = mq.TLO.Corpse.Item(i)

            if shouldILoot(corpseItem) then
                mq.cmdf('/g ' .. corpseItem.ItemLink('CLICKABLE')())
                mq.cmdf("/shift /itemnotify loot%d rightmouseup", i)
                mq.delay(500)
                
                if mq.TLO.Window("QuantityWnd").Open() then
                    mq.cmdf("/notify QuantityWnd QTYW_Accept_Button leftmouseup")
                    mq.delay(300)
                end
            else
                -- If multiple group members can use it, add to table
                if isMaster and (groupMembersCanUse(corpseItem) > 1) then
                    local tempUseTable = {
                        corpseId = corpseObject.ID,
                        itemId = corpseItem.ID(),
                        itemName = corpseItem.Name(),
                        itemObject = corpseItem
                    }

                    if(next(self.listboxSelectedOption) == nil) then
                        self.listboxSelectedOption = {}
                        self.listboxSelectedOption.corpseId = corpseObject.ID
                        self.listboxSelectedOption.itemId = corpseItem.ID()
                        self.listboxSelectedOption.itemName = corpseItem.Name()
                    end
                    multimap_insert(self.multipleUseTable, corpseObject.ID, tempUseTable)
                end
            end
            
            -- Try to auto-inventory any cursor items
            if mq.TLO.Cursor then
                mq.cmdf("/autoinventory")
            end
        end
        
        if mq.TLO.Window("LootWnd").Open() then
            mq.cmdf("/notify LootWnd LW_DoneButton leftmouseup")
            mq.delay(100)
        end
    end
    
    local function printMultipleUseItems()
        if self.multipleUseTable == nil then
            return
        end

        mq.cmdf('/g *** Multi Class No Drop/No Trade Items ***')
        print('*** Multi Class No Drop/No Trade Items ***')
        
        for idx, items in pairs(self.multipleUseTable) do
            for idx2, tbl in ipairs(items) do
                mq.cmdf('/g  ' .. tbl.itemObject.ItemLink('CLICKABLE')())
                print(tbl.itemObject.ItemLink('CLICKABLE')())
            end
        end
    end
    
    -- ========================================================================
    -- Public API Functions
    -- ========================================================================
    
    function self.stopScript(line)
        self.loopBoolean = false
    end

    function self.lootItemById()
        local idx, items = next(self.myQueuedItems)
        
        while idx do
            -- Store next key before potential removal
            local nextIdx = next(self.myQueuedItems, idx)
            
            mq.cmd("/say #corpsefix")
            mq.delay(500)
            mq.cmdf("/target id %d", idx)
            mq.cmdf("/warp t")
            mq.delay(500)
            mq.cmdf("/loot")
            
            --mq.delay("5s", function() return mq.TLO.Window("LootWnd").Open() end)
            
            local retryCountMax = 5
            local retryCount = 0

            while not mq.TLO.Window("LootWnd").Open() and (retryCount < retryCountMax) do
                mq.cmdf("/squelch /say #corpsefix")
                mq.delay(500)
                retryCount = retryCount + 1
            end

            if(retryCount >= retryCountMax) then
                mq.cmdf("/g Could not loot targeted corpse, skipping.")
                return
            end
            
            local corpseItemCount = tonumber(mq.TLO.Corpse.Items()) or 0
            
            if corpseItemCount == 0 then
                if mq.TLO.Window("LootWnd").Open() then
                    mq.cmdf("/notify LootWnd LW_DoneButton leftmouseup")
                    mq.delay(100)
                end
                return
            end

            local i = 1
            while i <= corpseItemCount do
                local idx2, tbl = next(items)
                
                while idx2 do
                    -- Store next key before potential removal
                    local nextIdx2 = next(items, idx2)
                    
                    local inventorySlotsRemaining = mq.TLO.Me.FreeInventory() - self.defaultSlotsToKeepFree
                    
                    if inventorySlotsRemaining < 1 then
                        mq.cmdf("/beep")
                        mq.cmdf('/g ' .. mq.TLO.Me.Name() .. " inventory is Full!")
                    end
                    
                    mq.delay("3s", function() return mq.TLO.Corpse.Item(i).ID() end)
                    local corpseItem = mq.TLO.Corpse.Item(i)
                    local localItemId = corpseItem.ID()
                    
                    if tostring(localItemId) == tostring(tbl.itemId) then
                        mq.cmdf('/g ' .. corpseItem.ItemLink('CLICKABLE')())
                        mq.cmdf("/shift /itemnotify loot%d rightmouseup", i)
                        mq.delay(500)
                        
                        if mq.TLO.Window("QuantityWnd").Open() then
                            mq.cmdf("/notify QuantityWnd QTYW_Accept_Button leftmouseup")
                            mq.delay(300)
                        end
                        
                        if mq.TLO.Cursor then
                            mq.cmdf("/autoinventory")
                        end

                        print("Removing idx2: " .. tostring(idx2))
                        items[idx2] = nil  -- Remove by setting to nil
                        mq.delay(500)
                    end
                    
                    -- Use the stored next key
                    idx2 = nextIdx2
                    if idx2 then
                        tbl = items[idx2]
                    end
                end
                
                i = i + 1
            end

            if mq.TLO.Window("LootWnd").Open() then
                mq.cmdf("/notify LootWnd LW_DoneButton leftmouseup")
                mq.delay(100)
            end
            
            print("Removing idx: " .. tostring(idx))
            self.myQueuedItems[idx] = nil  -- Remove by setting to nil
            
            -- Use the stored next key
            idx = nextIdx
            if idx then
                items = self.myQueuedItems[idx]
            end
        end
    end
    
    function self.doLoot(isMaster)
        local startingLocation = {
            X = mq.TLO.Me.X(),
            Y = mq.TLO.Me.Y(),
            Z = mq.TLO.Me.Z(),
            timeToWait = "2s",
            arrivalDistance = 5
        }
        
        local stickState = false
        self.multipleUseTable = {}
        self.myQueuedItems = {}
        self.listboxSelectedOption = {}

        mq.cmdf("/g " .. mq.TLO.Me.Name() .. " has started looting")
        --mq.cmdf("/squelch /e3p off")
        
        if mq.TLO.Stick.Active() then
            stickState = true
            mq.cmdf("/stick off")
        end
        
        mq.delay(500)
        
        ::corpseCount::
        getCorpseTable(mq.TLO.SpawnCount("npccorpse radius 200")())
        local currentCorpse = getNearestCorpse()
        
        while currentCorpse do
            mq.cmdf("/squelch /hidecor looted")
            local moveProps = {
                Y = math.floor(currentCorpse.Y),
                X = math.floor(currentCorpse.X),
                Z = math.floor(currentCorpse.Z),
                timeToWait = "2s",
                arrivalDistance = 8
            }
            
            mq.cmdf("/warp loc %d %d %d", moveProps.Y, moveProps.X, moveProps.Z)
            mq.delay(moveProps.timeToWait)
            lootCorpse(currentCorpse, isMaster)
            currentCorpse = getNearestCorpse()
        end
        
        if mq.TLO.SpawnCount("npccorpse radius 200")() > 0 then
            goto corpseCount
        end
        
        mq.cmdf("/warp loc %d %d %d", startingLocation.Y, startingLocation.X, startingLocation.Z)
        mq.delay(startingLocation.timeToWait)
        
        printMultipleUseItems()
        
        mq.cmdf("/g " .. mq.TLO.Me.Name() .. " is done Looting")
        --mq.cmdf("/squelch /e3p on")
    end
    
    function self.peerLoot()
        self.doLoot(false)
    end
    
    function self.masterLoot()
        self.multipleUseTable = {}
        self.doLoot(true)
    end
    
    function self.queueItem(line, groupMemberName, corpseId, itemId)
        local myName = tostring(mq.TLO.Me.Name())
        
        if groupMemberName == myName then
            mq.cmdf("/g " .. myName .. " is adding itemId(" .. itemId .. ") and corpseId(" .. corpseId .. ") to my loot queue")
            
            local tempUseTable = {
                corpseId = corpseId,
                itemId = itemId
            }

            multimap_insert(self.myQueuedItems, corpseId, tempUseTable)

            for idx, items in pairs(self.multipleUseTable) do
                if(tostring(idx) == tostring(corpseId)) then
                    for idx2, tbl in pairs(items) do
                        if((tostring(tbl.itemId)==tostring(itemId)) and tostring(idx)==tostring(corpseId)) then
                            table.remove(items, idx2)
                        end
                    end
                end
            end
        end
    end
    
    function self.testItem()
        print(printTable(self.myQueuedItems))
    end
    
    function self.testEvent(line, groupMemberName, corpseId, itemId)
        local myName = tostring(mq.TLO.Me.Name())
        
        if groupMemberName == myName then
            mq.cmdf("/g " .. myName .. " is adding itemId(" .. itemId .. ") and corpseId(" .. corpseId .. ") to my loot queue")
            local tempUseTable = {
                corpseId = corpseId,
                itemId = itemId
            }
            table.insert(self.myQueuedItems, tempUseTable)
        end
    end
    
    -- ========================================================================
    -- GUI Function
    -- ========================================================================
    
    function self.createGUI()
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
            
            -- Initialize defaults on first render
            if self.radioSelectedOption == nil then
                self.radioSelectedOption = 0
                local firstMember = mq.TLO.Group.Member(0).Name()
                if firstMember then
                    self.groupMemberSelected = firstMember
                end
            end
            
            if self.listboxSelectedOption == nil and #self.multipleUseTable > 0 then
                self.listboxSelectedOption = {}
            end
            
            imgui.PushItemWidth(imgui.GetFontSize() * -12)
            
            -- Buttons
            if imgui.Button("Master Loot") then
                mq.cmdf("/mlml")
            end
            
            imgui.SameLine()
            if imgui.Button("Peer Loot") then
                if self.groupMemberSelected == tostring(mq.TLO.Me.Name()) then
                    mq.cmdf("#corpsefix")
                    mq.cmdf("/hidecorpse none")
                    mq.cmdf("/mlpl")
                else
                    mq.cmdf("/dex %s #corpsefix", self.groupMemberSelected)
                    mq.cmdf("/dex %s /hidecorpse none", self.groupMemberSelected)
                    mq.cmdf("/dex %s /mlpl", self.groupMemberSelected)
                end
            end
            
            imgui.SameLine()
            if imgui.Button("Queue Item") then
                mq.cmdf("/g mlqi %s %d %d", self.groupMemberSelected, self.listboxSelectedOption.corpseId, self.listboxSelectedOption.itemId)

                for idx, items in pairs(self.multipleUseTable) do
                if(tostring(idx) == tostring(self.listboxSelectedOption.corpseId)) then
                    for idx2, tbl in pairs(items) do
                        if((tostring(tbl.itemId)==tostring(self.listboxSelectedOption.itemId)) and tostring(idx)==tostring(self.listboxSelectedOption.corpseId)) then
                            table.remove(items, idx2)
                        end
                    end
                end
            end
            end

            imgui.SameLine()
            if imgui.Button("Loot Item(s)") then
                if self.groupMemberSelected == tostring(mq.TLO.Me.Name()) then
                    mq.cmdf("#corpsefix")
                    mq.cmdf("/hidecorpse none")
                    mq.cmdf("/mlli")
                else
                    mq.cmdf("/dex %s #corpsefix", self.groupMemberSelected)
                    mq.cmdf("/dex %s /hidecorpse none", self.groupMemberSelected)
                    mq.cmdf("/dex %s /mlli", self.groupMemberSelected)
                end
            end
            
            imgui.Separator()
            

            -- Group member radio buttons
            local groupMembersCount = ((mq.TLO.Group.GroupSize()) or 0) - 1

            if groupMembersCount >= 0 then
                for i = 0, groupMembersCount do
                    local memberName = mq.TLO.Group.Member(i).Name()
                    local isActive = (self.radioSelectedOption == i)
                    
                    if imgui.RadioButton(memberName, isActive) then
                        self.radioSelectedOption = i
                        self.groupMemberSelected = memberName
                    end

                    if i < groupMembersCount then
                        imgui.SameLine()
                    end
                end
            end
            imgui.Separator()
            imgui.SetNextItemWidth(300)

            -- Item listbox
            if imgui.BeginListBox("") then
                for idx, items in pairs(self.multipleUseTable) do
                    for idx2, tbl in ipairs(items) do
                        local isSelected = false
                        if(self.listboxSelectedOption == nil) then
                            isSelected = true
                            self.listboxSelectedOption = tbl
                        else
                            isSelected = (self.listboxSelectedOption.itemId == tbl.itemId) and (self.listboxSelectedOption.corpseId == idx) 
                        end

                        selectableText = string.format("%s (%d)", tbl.itemName, idx)
                        if imgui.Selectable(selectableText, isSelected) then
                            self.listboxSelectedOption = tbl
                        end
                        
                        if isSelected then
                            imgui.SetItemDefaultFocus()
                        end
                    end
                end
                imgui.EndListBox()
            end
            
            imgui.SameLine()
            imgui.Spacing()
            imgui.PopItemWidth()
            imgui.End()
            
            return open
        end
    end
    
    return self
end

-- ============================================================================
-- Main Script
-- ============================================================================

local instance = LootUtil.new()
local openGUI = true

print("LootUtil has been started")

-- Bind commands
mq.bind("/mlml", instance.masterLoot)
mq.bind("/mlpl", instance.peerLoot)
mq.bind("/mlli", instance.lootItemById)
mq.bind("/mlsl", instance.stopScript)
mq.bind("/ti", instance.testItem)

-- Register events
mq.event('peerLootItem', "#*#mlqi #1# #2# #3#'", instance.queueItem)
mq.event('testEventItem', "#*#abcd #1# #2# #3#'", instance.testEvent)

-- Join chat channel
mq.cmdf(instance.chatConfig)

-- Register GUI
ImGui.Register('masterLootGui', instance.createGUI())

-- Main loop
while openGUI do
    mq.doevents()
    mq.delay(1)
end

print("MasterLoot is exiting.")
