--[[
    Sell Utilities
    LUA set of utilities to help manage Loot Settings and autoselling

    *** Be sure to set your Inventory Util INI location correctly with this line ***
    *** LUA uses \ as escape, so don't forget to \\ your paths
    self.INVUTILINI = "C:\\E3_RoF2\\config\\InvUtil.ini"

    You may also want to edit your default Loot Settings file location.  This can be updated in the Inventory Util INI file at any time.
    self.defaultLootSettingsIni = "C:\\E3_RoF2\\Macros\\e3 Macro Inis\\Loot Settings.ini"

    See the README for usage https://github.com/CerveloFellow/MQ-Next-Utilities/blob/main/README.md
]]

local mq = require('mq')
require('MoveUtil')
require('LootSettingUtil')

LootUtil = { }

function LootUtil.new()
    local self = {}
    
    self.LOOTUTILINI = "C:\\E3_RoF2\\config\\LootUtil.ini"
    self.SELL = "Keep,Sell"
    self.SKIP = "Skip"
    self.DESTROY = "Destroy"
    self.KEEP = "Keep"
    self.BANK = "Keep,Bank"
    self.defaultLootSettingsIni = "C:\\E3_RoF2\\Macros\\e3 Macro Inis\\Loot Settings.ini"
    self.defaultAllowCombatLooting = false
    self.defaultSlotsToKeepFree = 2
    self.loopBoolean = true
    self.lootRadius = 50
    self.currentCorpseTable = {}

    function self.stopScript(line)
        self.loopBoolean = false
    end

    function shouldILoot(corpseItem)
        if(corpseItem.Item.NoDrop()) then
            return false
        end

        if(corpseItem.Item.NoTrade()) then
            return false
        end

        if(corpseItem.Item.Lore()) then
            -- put code in here to see if I have the item.
            return false
        end
        return true
    end

    function lootCorpse(corpseID)
        mq.cmdf("/bc Looting Corpse ID %d", corpseID)
        mq.cmdf("/target id %d", corpseID)
        mq.cmdf("/loot")
        -- wait for the LootWnd window to open up to 5s.  Callback exits the delay early if it opens
        mq.delay("5s", function() return windowOpenCallback("LootWnd") end)
        if (not mq.TLO.Window("LootWnd").Open() ) then
            mq.cmdf("/bc Could not loot targeted corpse, skipping.")
            return
        end

        local corpseItemCount = tonumber(mq.TLO.Corpse.Items()) or 0

        if(corpseItemCount == 0) then
            if(mq.TLO.Window("LootWnd").Open()) then
                mq.cmdf("/notify LootWnd LW_DoneButton leftmouseup")
                mq.delay(100)
            end
            return
        end

        for i=1, corpseItemCount do
            local inventorySlotsRemaining = mq.TLO.Me.FreeInventory()-self.slotsToKeepFree
            if(inventorySlotsRemaining < 1) then
                mq.cmdf("/beep")
                mq.cmdf("/bc Inventory is Full!")
            end

            -- Wait for items to appear on the corpse.  Latency sometimes returns this as nil
            mq.delay("3s", function() return mq.TLO.Corpse.Item(i).ID() end)
            local corpseItem = mq.TLO.Corpse.Item(i)

            if(shouldILoot(corpseItem)) then
                mq.cmdf("/shift /itemnotify loot%d rightmouseup", i)
                mq.delay(500)
                if(mq.TLO.Window("QuantityWnd").Open()) then
                    mq.cmdf("/notify QuantityWnd QTYW_Accept_Button leftmouseup")
                    mq.delay(300)
                end
            else
                mq.cmdf("/bc Something said I shouldn't loot this.")
            end

            -- is something on the cursor?  try /autoinventory
            if(mq.TLO.Cursor) then
                mq.cmdf("/autoinventory")
            end
        end
        if(mq.TLO.Window("LootWnd").Open()) then
            mq.cmdf("/notify LootWnd LW_DoneButton leftmouseup")
            mq.delay(100)
        end
    end

    function getCorpseTable(numCorpses)
        local corpseTable = {}

        for i=1, numCorpses do
            local tempSpawn = mq.TLO.NearestSpawn(i, string.format("npc corpse zradius 50 radius %d", self.lootRadius))
            local corpse = {}
            corpse.ID = tempSpawn.ID()
            corpse.Name = tempSpawn.Name()
            corpse.Distance = tempSpawn.Distance()
            corpse.DistanceZ = tempSpawn.DistanceZ()
            corpse.X = tempSpawn.X()
            corpse.Y = tempSpawn.Y()
            corpse.Z = tempSpawn.Z()
            table.insert(corpseTable, corpse)
        end

        self.currentCorpseTable = corpseTable
    end

    function getNearestCorpse()
        local nearestCorpseIndex = 0
        local nearestCorpseDistance = 9999
        local nearestCorpse = {}

        if(#self.currentCorpseTable==0) then
            return nil
        end

        for i=1, #self.currentCorpseTable do
            local c = self.currentCorpseTable[i]
            local distance = mq.TLO.Math.Distance(c.Y, c.X)()
            nearestCorpseIndex = (distance < nearestCorpseDistance) and i or nearestCorpseIndex
            nearestCorpseDistance = (distance < nearestCorpseDistance) and distance or nearestCorpseDistance
        end

        return table.remove(self.currentCorpseTable, nearestCorpseIndex)
    end 

    function self.lootArea()
        local remainingCorpses = numCorpses
        local currentCorpse = {}
        local startingLocation = {}
        local twistState = false
        local followState = false
        local stickState = false
        local attempts = 0

        startingLocation.X = mq.TLO.Me.X()
        startingLocation.Y = mq.TLO.Me.Y()
        startingLocation.Z = mq.TLO.Me.Z()
        startingLocation.timeToWait="5s"
        startingLocation.arrivalDistance=5

        if(mq.TLO.Twist.Twisting and mq.TLO.Me.Class.ShortName() == "BRD") then
            twistState = true
            mq.cmdf("/twist stop")
        end

        if(mq.TLO.AdvPath.Active()) then
            followState = true
            mq.cmdf("/squelch /afollow off")
        end

        if(mq.TLO.Stick.Active()) then
            stickState = true
            mq.cmdf("/stick off")
        end

        mq.delay(500)
        ::corpseCount::
        getCorpseTable(mq.TLO.SpawnCount(string.format("npc corpse zradius 50 radius %d", self.lootRadius))())
        currentCorpse = getNearestCorpse()

        while(currentCorpse)
        do
            mq.cmdf("/squelch /hidecor looted")
            local moveProps = { Y=currentCorpse.Y, X=currentCorpse.X, Z=currentCorpse.Z, timeToWait="2s", arrivalDistance=8}
            local moveUtilInstance = MoveUtil.new(moveProps)
            moveUtilInstance.moveToLocation()        
            mq.delay(moveProps.timeToWait, moveUtilInstance.atDestion)
            if (moveUtilInstance.atDestion()) then
                lootCorpse(currentCorpse.ID)
            else
                print("You couldn't get to your target, moving on to next one.")
            end
            mq.delay(500)
            currentCorpse = getNearestCorpse()
        end

        if(mq.TLO.SpawnCount(string.format("npc corpse zradius 50 radius %d", self.lootRadius))() > 0) then
            goto corpseCount
        end

        local m1 = MoveUtil.new(startingLocation)
        m1.moveToLocation()

        if(twistState) then
            mq.cmdf("/twist start")
        end

        if(followState) then
            --reacquire follow
        end

        if(stickState) then
            -- restick
        end
    end

    --Making this a function so I can easily change how in combat is figured out.  Many of the methods seem unreliable.
    function inCombat()
        mq.delay("1s")
        local spawnCount = mq.TLO.SpawnCount(string.format("xtarhater radius %d", self.lootRadius))()
        return (spawnCount>0)
    end

    function self.npcKilled(line)
        mq.cmdf("/bc EVENT npcKilled triggered")
        if( self.combatLooting or not inCombat()) then
            self.lootArea()
        end
    end

    function createIniDefaults()
        mq.cmdf('/ini "%s" "%s" "%s" "%s"', self.LOOTUTILINI, "Settings", "Loot Settings File", self.defaultLootSettingsIni)
        mq.cmdf('/ini "%s" "%s" "%s" "%s"', self.LOOTUTILINI, "Settings", "Allow Combat Looting(true\\false)", self.defaultAllowCombatLooting)
        mq.cmdf('/ini "%s" "%s" "%s" "%s"', self.LOOTUTILINI, "Settings", "Slots To Keep Free", self.defaultSlotsToKeepFree)
    end

    function self.getIniSettings()
        stringtoboolean={ ["true"]=true, ["false"]=false }

        if(mq.TLO.Ini(self.LOOTUTILINI)()) then
            tempString = mq.TLO.Ini(self.LOOTUTILINI,"Settings", "Loot Settings File")()
            if(tempString) then
                self.lootSettingsIni = tempString
            else
                mq.cmdf('/ini "%s" "%s" "%s" "%s"', self.LOOTUTILINI, "Settings", "Loot Settings File", self.defaultLootSettingsIni)
            end

            tempString = mq.TLO.Ini(self.LOOTUTILINI,"Settings", "Allow Combat Looting(true\\false)")()
            if(tempString) then
                self.allowCombatLooting = tempString
            else
                mq.cmdf('/ini "%s" "%s" "%s" "%s"', self.LOOTUTILINI, "Settings", "Allow Combat Looting(true\\false)", self.defaultAllowCombatLooting)
            end

            tempString = mq.TLO.Ini(self.LOOTUTILINI,"Settings", "Slots To Keep Free")()
            if(tempString) then
                self.slotsToKeepFree = tempString
            else
                mq.cmdf('/ini "%s" "%s" "%s" "%s"', self.LOOTUTILINI, "Settings", "Slots To Keep Free", self.defaultSlotsToKeepFree)
            end
        else
            print("No LootUtil.ini is present.  Creating one and exiting.  Please edit the file and re-run the script.")
            createIniDefaults()
            os.exit()
        end

        function windowOpenCallback(windowName)
            return mq.TLO.Window(windowName).Open()
        end

        function self.testWindowCallback()
            local windowName ="InventoryWindow"
            mq.delay("10s", function() return mq.TLO.Cursor.ID() end)

            if(mq.TLO.Window(windowName).Open()) then
                print("Window is open!")
            else
                print("Window is NOT open!")
            end 
        end
    end

    return self
end

local instance = LootUtil.new()
local loopBoolean = true
instance.getIniSettings()

print("LootUtil has been started")

mq.bind("/wo", instance.testWindowCallback)
mq.bind("/la", instance.lootArea)
mq.bind("/stopLootUtil", instance.stopScript)

mq.event('event_npcKilled', '#*#has been slain by#*#', instance.npcKilled)
mq.event('event_npcKilled', 'You have slain #*#', instance.npcKilled)
mq.event('event_npcKilled', 'You have gained #*#', instance.npcKilled)
mq.event('event_npcKilled', '#*# party experience!', instance.npcKilled)
mq.event('event_npcKilled', 'You gained raid experience!', instance.npcKilled)

while(instance.loopBoolean)
do
    mq.doevents()
    mq.delay(1) -- just yield the frame every loop
end

print("LootUtil is exiting.")
