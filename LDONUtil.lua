local mq = require('mq')
--[[
    LDON Utility to help automate running LDON collect/kill adventures.

    Runs on the MQ Next version of E3 and required the MQ2Nav plugin.

    A modification to the /clearxtargets is needed so you can force it on.  Grab the version of e3_ClearXTargets.inc in this repo.

    For collect adventures you need to have your auto loot set up to pick up the LDON collect items automatically.  /bc loot on is called after combat to make your mobs loot. 
]]
LDONUtil = {}

function LDONUtil.new()
    local self = {}
    self.Paused = false
    self.LoopBoolean = true
    self.AdventerTotal = -1
    self.AdventureTotalNeeded = -1
    self.RemainingCount = 99999
    self.EntireZoneTable = {}
    self.DistinctMobsTable = {}
    self.INI = mq.TLO.MacroQuest.Path("Config")().."\\LDONUtil.ini"
    self.ConfigurationSettings = {}
    -- General Settings
    -- This is a list of spawns to ignore if you come across them
    self.ConfigurationSettings.InvalidSpawns = "A Dark Coffin,A Bitten Victim,A Dark Chest,A Wooden Barrel,a hollow tree,a creaking crate,an orcish chest,a petrified colossal tree,a hollow tree,a menacing tree spirit"
    -- The maximum distance for an xtarget hater to be considered in combat.   Mobs outside of this distance will not consider you in combat.
    self.ConfigurationSettings.CombatRadius = 200
    -- Should we loot?
    self.ConfigurationSettings.LootEnabled = true
    -- Maximum radius to look for and loot corpses
    self.ConfigurationSettings.LootRadius = 50
    -- When members are further than this distance we will pause and wait for them to catch up 
    self.ConfigurationSettings.MaxFollowDistance = 250
    -- When paused, we resume navigation when team members are within this range
    self.ConfigurationSettings.MinFollowDistance = 50
    
    -- Character Level Settings
    -- This is the pull size to stop and fight.  This does not guarantee this pull size, only says that when we get a minimum of this many mobs on xtarget haters list, in combat range, we stop and fight
    self.ConfigurationSettings.PullSize = 3
    -- Minimum mana needed to fight, otherwise we med after fights
    self.ConfigurationSettings.MinMana = 50
    -- If you're not in combat and navigating to a mob, you will stop and fight if anyone in the group drops below this hit point threshold
    self.ConfigurationSettings.MinHealth = 70

    function self.createIniDefaults()
        if not mq.TLO.Ini.File(self.INI).Exists() then
            mq.cmdf('/ini "%s" "%s" "%s" "%s"', self.INI, "General", "Invalid Spawns", self.ConfigurationSettings.InvalidSpawns)
            mq.cmdf('/ini "%s" "%s" "%s" "%s"', self.INI, "General", "Combat Radius", self.ConfigurationSettings.CombatRadius)
            mq.cmdf('/ini "%s" "%s" "%s" "%s"', self.INI, "General", "Loot Enabled", self.ConfigurationSettings.LootEnabled)
            mq.cmdf('/ini "%s" "%s" "%s" "%s"', self.INI, "General", "Loot Radius", self.ConfigurationSettings.LootRadius)
            mq.cmdf('/ini "%s" "%s" "%s" "%s"', self.INI, "General", "Maximum Follow Distance", self.ConfigurationSettings.MaxFollowDistance)
            mq.cmdf('/ini "%s" "%s" "%s" "%s"', self.INI, "General", "Minimum Follow Distance", self.ConfigurationSettings.MinFollowDistance)

            mq.cmdf('/ini "%s" "%s" "%s" "%s"', self.INI, mq.TLO.Me.Name(), "Pull Size", self.ConfigurationSettings.PullSize)
            mq.cmdf('/ini "%s" "%s" "%s" "%s"', self.INI, mq.TLO.Me.Name(), "Minimum Mana", self.ConfigurationSettings.MinMana)
            mq.cmdf('/ini "%s" "%s" "%s" "%s"', self.INI, mq.TLO.Me.Name(), "Minimum Health", self.ConfigurationSettings.MinHealth)

        end
    end

    function getKey(file, section, key, defaultValue)
        local returnValue = defaultValue

        if mq.TLO.Ini.File(file).Section(section).Key(key).Exists() then
            returnValue = mq.TLO.Ini.File(file).Section(section).Key(key).Value()
        else
            mq.cmdf('/ini "%s" "%s" "%s" "%s"', file, section, key, defaultValue)
        end

        return returnValue
    end

    function self.getIniSettings()
        stringtoboolean={ ["true"]=true, ["false"]=false }

        if not mq.TLO.Ini.File(self.INI).Exists() then
            self.createIniDefaults()
        else
            self.ConfigurationSettings.InvalidSpawns = getKey(self.INI, "General", "Invalid Spawns", self.ConfigurationSettings.InvalidSpawns)
            self.ConfigurationSettings.CombatRadius = tonumber(getKey(self.INI, "General", "Combat Radius", self.ConfigurationSettings.CombatRadius))
            self.ConfigurationSettings.LootEnabled = stringtoboolean[getKey(self.INI, "General", "Loot Enabled", self.ConfigurationSettings.LootEnabled)]
            self.ConfigurationSettings.LootRadius = tonumber(getKey(self.INI, "General", "Loot Radius", self.ConfigurationSettings.LootRadius))
            self.ConfigurationSettings.MaxFollowDistance = tonumber(getKey(self.INI, "General", "Maximum Follow Distance", self.ConfigurationSettings.MaxFollowDistance))
            self.ConfigurationSettings.MinFollowDistance = tonumber(getKey(self.INI, "General", "Minimum Follow Distance", self.ConfigurationSettings.MinFollowDistance))
        end

        if not mq.TLO.Ini.File(self.INI).Section(mq.TLO.Me.Name()).Exists() then
            mq.cmdf('/ini "%s" "%s" "%s" "%s"', self.INI, mq.TLO.Me.Name(), "Pull Size", self.ConfigurationSettings.PullSize)
            mq.cmdf('/ini "%s" "%s" "%s" "%s"', self.INI, mq.TLO.Me.Name(), "Minimum Mana", self.ConfigurationSettings.MinMana)
            mq.cmdf('/ini "%s" "%s" "%s" "%s"', self.INI, mq.TLO.Me.Name(), "Minimum Health", self.ConfigurationSettings.MinHealth)
        else
            self.ConfigurationSettings.PullSize = tonumber(getKey(self.INI, mq.TLO.Me.Name(), "Pull Size", self.ConfigurationSettings.LootRadius))
            self.ConfigurationSettings.MinMana = tonumber(getKey(self.INI, mq.TLO.Me.Name(), "Minimum Mana", self.ConfigurationSettings.MinMana))
            self.ConfigurationSettings.MinHealth = tonumber(getKey(self.INI, mq.TLO.Me.Name(), "Minimum Health", self.ConfigurationSettings.MinHealth))
        end
    end

    function spawnFilter(spawn)
        return (spawn.Type() == "NPC") and (not invalidSpawn(spawn)) and spawn.Targetable() and not spawn.Dead() and not spawn.Trader()
    end

    function invalidSpawn(spawn)
    
        for invalidSpawn in string.gmatch(self.ConfigurationSettings.InvalidSpawns, '([^,]+)') do
            local currentSpawnName = string.upper(spawn.CleanName())
            local comparisonSpawnName = string.upper(invalidSpawn)
            if currentSpawnName == comparisonSpawnName then
                return true
            end
        end
        return false
    end

    function self.printMobsInZone()
        local sortedTable = {}
        for k,v in pairs(self.DistinctMobsTable) do
            table.insert(sortedTable, k)
        end
        table.sort(sortedTable)
        for _, k in ipairs(sortedTable) do print(k) end
    end

    function self.initZone()
        local filteredSpawns = mq.getFilteredSpawns(spawnFilter)

        for index, spawn in ipairs(filteredSpawns) do
            table.insert(self.EntireZoneTable, spawn.ID())
            if not self.DistinctMobsTable[spawn.CleanName()] then
                self.DistinctMobsTable[spawn.CleanName()] = spawn
            end
        end
    end

    function self.adventureComplete()
    
        local progressText = mq.TLO.Window("AdventureRequestWnd").Child("AdvRqst_ProgressTextLabel").Text()
        local progressTable = {}
    
        print(string.format("%d of %d", self.AdventerTotal, self.AdventureTotalNeeded))
    
        if string.len(progressText) > 0 then
            for progress in string.gmatch(progressText, '([^of]+)') do
                table.insert(progressTable, tonumber(progress))
            end
            if(self.AdventureTotalNeeded == -1) then
                self.AdventureTotalNeeded = progressTable[2]
            end
    
            self.AdventerTotal = progressTable[1]
    
            self.RemainingCount = self.AdventureTotalNeeded - self.AdventerTotal
    
            return (progressTable[1] == progressTable[2])
        else
            if self.AdventerTotal > 0 then
                return true
            end
        end
        
        return false
    end
    
    function self.inCombat()
        local invalidSpawnCount = 0
        local spawnCount = mq.TLO.SpawnCount(string.format("xtarhater radius %d", self.ConfigurationSettings.CombatRadius))()
        local xTargetCount = mq.TLO.Me.XTarget()
    
        for i=1,xTargetCount do
            local xTargetId = mq.TLO.Me.XTarget(i).ID()
            if(xTargetId > 0) then
                local spawn = mq.TLO.Spawn(string.format("id %d", xTargetId))
                if invalidSpawn(spawn) then
                    invalidSpawnCount = invalidSpawnCount + 1
                end
            end
        end
        
        return (spawnCount>invalidSpawnCount)
    end
    
    function self.needToMed()
        -- check for slowed because Stonewall Discipline triggers and messes me up
        return (mq.TLO.Group.LowMana(self.ConfigurationSettings.MinMana)() > 0)
    end
    
    function self.everyoneHere(distance)
        if mq.TLO.Me.Grouped() then
            return (mq.TLO.SpawnCount(string.format("group radius %d", distance))() == mq.TLO.Group.GroupSize())
        else
            return true
        end
    end
    
    function self.anyMobsToLoot()
        if self.ConfigurationSettings.LootEnabled then
            return (mq.TLO.SpawnCount(string.format("npc corpse zradius 50 radius %d", self.ConfigurationSettings.LootRadius))() > 0)
        else
            return false
        end
    end
    
    function self.anyoneInjured(healthPercent)
        if mq.TLO.Me.Grouped() then
            return mq.TLO.Group.Injured(healthPercent)() > 0
        else
            return mq.TLO.Me.PctHPs() < healthPercent
        end
    end
    
    function spawnFilter(spawn)
        return (spawn.Type() == "NPC") and (not invalidSpawn(spawn)) and spawn.Targetable() and not spawn.Dead() and not spawn.Trader()
    end

    function self.pause()
        if (not mq.TLO.Navigation.Paused()) then
            mq.cmdf("/squelch /nav pause")
        end
        self.Paused = true
    end
    
    function self.unpause()
        if (mq.TLO.Navigation.Paused()) then
            mq.cmdf("/squelch /nav pause")
        end
        self.Paused = false
    end

    return self
end
local args = {...}

local instance = LDONUtil.new()

instance.getIniSettings()

-- You can override your pull size by doing /lua run LDONUtil.lua <pullsize>.
if(#args > 0) then
    instance.ConfigurationSettings.PullSize = tonumber(args[1])
end

instance.initZone()

-- Set up binds
-- check adventure complete status
mq.bind("/ac", instance.adventureComplete)
-- print mobs in zone
mq.bind("/pmiz", instance.printMobsInZone)

mq.cmdf("/bc loot on")
mq.delay(500)
mq.cmdf("/lootall")
mq.delay(500)
mq.cmdf("/followme")
mq.delay(500)

while (#instance.EntireZoneTable > 0 and instance.LoopBoolean)
do
    local pathLength = 999999
    local npcDistance = 99999
    local spawnId = 0
    local tablePosition = 0

    for i=1, #instance.EntireZoneTable do
        local npcPathLength = mq.TLO.Navigation.PathLength(string.format("id %d", instance.EntireZoneTable[i]))()
        if(npcPathLength < pathLength) then
            spawnId = instance.EntireZoneTable[i]
            pathLength = npcPathLength
            tablePosition = i
        end
    end
    
    local closestId = table.remove(instance.EntireZoneTable, tablePosition)
    if(mq.TLO.Navigation.PathExists(string.format("id %d", closestId))()) then
        mq.cmdf("/squelch /target id %d", closestId)
        mq.delay(500)
        mq.cmdf("/squelch /nav id %d", closestId)
        mq.delay(500)
        while(not mq.TLO.Navigation.Paused() and mq.TLO.Navigation.Active() and mq.TLO.Me.XTarget() < instance.ConfigurationSettings.PullSize)
        do
            if mq.TLO.Me.XTarget() >= instance.ConfigurationSettings.PullSize then
                instance.pause()
            elseif not instance.everyoneHere(instance.ConfigurationSettings.MaxFollowDistance) and mq.TLO.Me.XTarget() >= (instance.ConfigurationSettings.PullSize / 2) then
                instance.pause()
            elseif instance.anyoneInjured(instance.ConfigurationSettings.MinHealth) then
                instance.pause()
            elseif not instance.everyoneHere(instance.ConfigurationSettings.MaxFollowDistance) then
                instance.pause()
                mq.cmdf("/squelch /bcg //nav id %d", mq.TLO.Me.ID())
                mq.delay("8s", function() return instance.everyoneHere(instance.ConfigurationSettings.MinFollowDistance) end)
                mq.cmdf("/followme")
                mq.delay(500)
                instance.unpause()
            end
        end

        -- If we're not active or paused check conditions to see if we need combat, looting or med
        while(mq.TLO.Navigation.Paused())
        do
            if(instance.inCombat()) then
                print("In Combat... start fighting!")
                mq.cmdf("/squelch /medoff")
                mq.delay(500)
                mq.cmdf("/squelch /bcg //nav id %d", mq.TLO.Me.ID())
                mq.delay("3s", function() return instance.everyoneHere(instance.ConfigurationSettings.MinFollowDistance) end)
                mq.cmdf("/clearxtargets ForceOn")
                mq.delay("5s", function() return (not instance.inCombat()) end)
            elseif instance.anyMobsToLoot() then
                print("Combat finished, time to loot!")
                mq.cmdf("/squelch /bc loot on")
                mq.delay("15s", function() return (instance.inCombat() or (not instance.anyMobsToLoot())) end)
            elseif instance.needToMed() and instance.LoopBoolean then
                print("Done Looting, we need to med!")
                mq.cmdf("/squelch /stop")
                mq.delay(500)
                mq.cmdf("/squelch /medon")
                mq.delay("20s", function() return (instance.inCombat() or (not instance.needToMed())) end)
                if not instance.needToMed() then
                    mq.cmdf("/squelch /followme")
                    mq.delay(500)
                    mq.cmdf("/squelch /medoff")
                    mq.delay(500)
                end
            else
                print("Resume play.")
                if not instance.everyoneHere(instance.ConfigurationSettings.MinFollowDistance * 2) then
                    mq.delay(500)
                    mq.cmdf("/squelch /bcg //nav id %d", mq.TLO.Me.ID())
                    mq.delay("15s", function() return instance.everyoneHere(instance.ConfigurationSettings.MinFollowDistance * 2) end)
                    mq.cmdf("/squelch /followme")                    
                end
                instance.unpause()
            end

            if instance.adventureComplete() then
                instance.LoopBoolean = false
                break
            end
        end
    end

    if instance.adventureComplete() then
        instance.LoopBoolean = false
        break
    end
end

mq.cmdf("/bcga //nav stop")
mq.delay(500)

while(instance.inCombat()) do
    print("In Combat... start fighting!")
    mq.cmdf("/squelch /medoff")
    mq.delay(500)
    mq.cmdf("/squelch /bcg //nav id %d", mq.TLO.Me.ID())
    mq.delay("3s", function() return instance.everyoneHere(instance.ConfigurationSettings.MinFollowDistance) end)
    mq.cmdf("/clearxtargets ForceOn")
    mq.delay("5s", function() return (not instance.inCombat()) end)
end

print("Playback ended!")


