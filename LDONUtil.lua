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
    self.ConfigurationSettings.InvalidSpawns = "a frozen table,A Dark Coffin,A Bitten Victim,A Dark Chest,A Wooden Barrel,a hollow tree,a creaking crate,an orcish chest,a petrified colossal tree,a hollow tree,a menacing tree spirit"
    -- The maximum distance for an xtarget hater to be considered in combat.   Mobs outside of this distance will not consider you in combat.
    self.ConfigurationSettings.CombatRadius = 200
    -- Should we loot?
    self.ConfigurationSettings.LootEnabled = true
    -- Maximum radius to look for and loot corpses
    self.ConfigurationSettings.LootRadius = 75
    -- When members are further than this distance we will pause and wait for them to catch up 
    self.ConfigurationSettings.MaxFollowDistance = 250
    -- When paused, we resume navigation when team members are within this range
    self.ConfigurationSettings.MinFollowDistance = 50
    
    -- Character Level Settings
    -- This is the pull size to stop and fight.  This does not guarantee this pull size, only says that when we get a minimum of this many mobs on xtarget haters list, in combat range, we stop and fight
    self.ConfigurationSettings.PullSize = 3
    -- Minimum mana needed to fight, otherwise we med after fights
    self.ConfigurationSettings.MinMana = 50
    -- Amount of mana you will med up to when you stop to med
    self.ConfigurationSettings.MedMana = 90
    -- If you're not in combat and navigating to a mob, you will stop and fight if anyone in the group drops below this hit point threshold
    self.ConfigurationSettings.MinHealth = 70
    --- COTH item/spell if group members get stuck.  Leave blank to not use Coth
    self.ConfigurationSettings.COTH = ""
    -- Character to COTH with.  If empty, it defaults to the character you're running the script with
    self.ConfigurationSettings.COTHCharacter = ""
    -- This command will get run before you start.  I use it to remove lev which is troublesome in the LDON dungeons
    self.ConfigurationSettings.OnStart = "/bcga //removelev"
    -- This command will get run when you're finished.  Port out, alt activate 331, whatever you want.
    self.ConfigurationSettings.OnFinish = "/bcga //say I can run a command when I finish"
    -- Do you want to continue killing mobs after your adventure is complete?
    self.ConfigurationSettings.ContinueAfterComplete = true

    function self.createIniDefaults()
        if not mq.TLO.Ini.File(self.INI).Exists() then
            mq.cmdf('/ini "%s" "%s" "%s" "%s"', self.INI, "General", "Invalid Spawns", self.ConfigurationSettings.InvalidSpawns)
            mq.cmdf('/ini "%s" "%s" "%s" "%s"', self.INI, "General", "Combat Radius", self.ConfigurationSettings.CombatRadius)
            mq.cmdf('/ini "%s" "%s" "%s" "%s"', self.INI, "General", "Loot Enabled", self.ConfigurationSettings.LootEnabled)
            mq.cmdf('/ini "%s" "%s" "%s" "%s"', self.INI, "General", "Loot Radius", self.ConfigurationSettings.LootRadius)
            mq.cmdf('/ini "%s" "%s" "%s" "%s"', self.INI, "General", "Maximum Follow Distance", self.ConfigurationSettings.MaxFollowDistance)
            mq.cmdf('/ini "%s" "%s" "%s" "%s"', self.INI, "General", "Minimum Follow Distance", self.ConfigurationSettings.MinFollowDistance)
            mq.cmdf('/ini "%s" "%s" "%s" "%s"', self.INI, "General", "Continue After Complete", self.ConfigurationSettings.ContinueAfterComplete)

            mq.cmdf('/ini "%s" "%s" "%s" "%s"', self.INI, mq.TLO.Me.Name(), "Pull Size", self.ConfigurationSettings.PullSize)
            mq.cmdf('/ini "%s" "%s" "%s" "%s"', self.INI, mq.TLO.Me.Name(), "Minimum Mana", self.ConfigurationSettings.MinMana)
            mq.cmdf('/ini "%s" "%s" "%s" "%s"', self.INI, mq.TLO.Me.Name(), "Meditation Mana", self.ConfigurationSettings.MedMana)
            mq.cmdf('/ini "%s" "%s" "%s" "%s"', self.INI, mq.TLO.Me.Name(), "Minimum Health", self.ConfigurationSettings.MinHealth)
            mq.cmdf('/ini "%s" "%s" "%s" "%s"', self.INI, mq.TLO.Me.Name(), "COTH", self.ConfigurationSettings.COTH)
            mq.cmdf('/ini "%s" "%s" "%s" "%s"', self.INI, mq.TLO.Me.Name(), "COTH", self.ConfigurationSettings.COTHCharacter)
            mq.cmdf('/ini "%s" "%s" "%s" "%s"', self.INI, mq.TLO.Me.Name(), "On Start", self.ConfigurationSettings.OnStart)
            mq.cmdf('/ini "%s" "%s" "%s" "%s"', self.INI, mq.TLO.Me.Name(), "On Finish", self.ConfigurationSettings.OnFinish)


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
        local stringtoboolean={ ["true"]=true, ["false"]=false }

        if not mq.TLO.Ini.File(self.INI).Exists() then
            self.createIniDefaults()
        else
            self.ConfigurationSettings.InvalidSpawns = getKey(self.INI, "General", "Invalid Spawns", self.ConfigurationSettings.InvalidSpawns)
            self.ConfigurationSettings.CombatRadius = tonumber(getKey(self.INI, "General", "Combat Radius", self.ConfigurationSettings.CombatRadius))
            self.ConfigurationSettings.LootEnabled = stringtoboolean[getKey(self.INI, "General", "Loot Enabled", self.ConfigurationSettings.LootEnabled)]
            self.ConfigurationSettings.LootRadius = tonumber(getKey(self.INI, "General", "Loot Radius", self.ConfigurationSettings.LootRadius))
            self.ConfigurationSettings.MaxFollowDistance = tonumber(getKey(self.INI, "General", "Maximum Follow Distance", self.ConfigurationSettings.MaxFollowDistance))
            self.ConfigurationSettings.MinFollowDistance = tonumber(getKey(self.INI, "General", "Minimum Follow Distance", self.ConfigurationSettings.MinFollowDistance))
            self.ConfigurationSettings.ContinueAfterComplete = stringtoboolean[getKey(self.INI, "General", "Continue After Complete", self.ConfigurationSettings.ContinueAfterComplete)]
        end

        if not mq.TLO.Ini.File(self.INI).Section(mq.TLO.Me.Name()).Exists() then
            mq.cmdf('/ini "%s" "%s" "%s" "%s"', self.INI, mq.TLO.Me.Name(), "Pull Size", self.ConfigurationSettings.PullSize)
            mq.cmdf('/ini "%s" "%s" "%s" "%s"', self.INI, mq.TLO.Me.Name(), "Minimum Mana", self.ConfigurationSettings.MinMana)
            mq.cmdf('/ini "%s" "%s" "%s" "%s"', self.INI, mq.TLO.Me.Name(), "Meditation Mana", self.ConfigurationSettings.MedMana)
            mq.cmdf('/ini "%s" "%s" "%s" "%s"', self.INI, mq.TLO.Me.Name(), "Minimum Health", self.ConfigurationSettings.MinHealth)
            mq.cmdf('/ini "%s" "%s" "%s" "%s"', self.INI, mq.TLO.Me.Name(), "COTH", self.ConfigurationSettings.COTH)
            mq.cmdf('/ini "%s" "%s" "%s" "%s"', self.INI, mq.TLO.Me.Name(), "COTH Character", self.ConfigurationSettings.COTHCharacter)
            mq.cmdf('/ini "%s" "%s" "%s" "%s"', self.INI, mq.TLO.Me.Name(), "On Start", self.ConfigurationSettings.OnStart)
            mq.cmdf('/ini "%s" "%s" "%s" "%s"', self.INI, mq.TLO.Me.Name(), "On Finish", self.ConfigurationSettings.OnFinish)
        else
            self.ConfigurationSettings.PullSize = tonumber(getKey(self.INI, mq.TLO.Me.Name(), "Pull Size", self.ConfigurationSettings.LootRadius))
            self.ConfigurationSettings.MinMana = tonumber(getKey(self.INI, mq.TLO.Me.Name(), "Minimum Mana", self.ConfigurationSettings.MinMana))
            self.ConfigurationSettings.MedMana = tonumber(getKey(self.INI, mq.TLO.Me.Name(), "Meditation Mana", self.ConfigurationSettings.MedMana))
            self.ConfigurationSettings.MinHealth = tonumber(getKey(self.INI, mq.TLO.Me.Name(), "Minimum Health", self.ConfigurationSettings.MinHealth))
            self.ConfigurationSettings.COTH = getKey(self.INI, mq.TLO.Me.Name(), "COTH", self.ConfigurationSettings.COTH)
            self.ConfigurationSettings.COTHCharacter = getKey(self.INI, mq.TLO.Me.Name(), "COTH Character", self.ConfigurationSettings.COTHCharacter)
            self.ConfigurationSettings.OnStart = getKey(self.INI, mq.TLO.Me.Name(), "On Start", self.ConfigurationSettings.OnStart)
            self.ConfigurationSettings.OnFinish = getKey(self.INI, mq.TLO.Me.Name(), "On Finish", self.ConfigurationSettings.OnFinish)
            
        end
    end

    function self.spawnFilter(spawn)
        return (spawn.Type() == "NPC") and (not invalidSpawn(spawn)) and spawn.Targetable() and (not spawn.Dead()) and (not spawn.Trader())
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
        local filteredSpawns = mq.getFilteredSpawns(self.spawnFilter)

        for index, spawn in ipairs(filteredSpawns) do
            table.insert(self.EntireZoneTable, spawn.ID())
            if not self.DistinctMobsTable[spawn.CleanName()] then
                self.DistinctMobsTable[spawn.CleanName()] = spawn
            end
        end
    end

    function self.adventureComplete()
    
        if self.ConfigurationSettings.ContinueAfterComplete then
            return false
        end

        local progressText = mq.TLO.Window("AdventureRequestWnd").Child("AdvRqst_ProgressTextLabel").Text()
        local progressTable = {}
    
        print(string.format("%d of %d", self.AdventerTotal, self.AdventureTotalNeeded))
    
        while(string.len(progressText)==0) do
            mq.cmdf("/keypress alt+v")
            progressText = mq.TLO.Window("AdventureRequestWnd").Child("AdvRqst_ProgressTextLabel").Text()
            mq.cmdf("/keypress alt+v")
            mq.delay(1000)
        end

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
            mq.TLO.Window("AdventureRequestWnd").DoOpen()
            progressText = mq.TLO.Window("AdventureRequestWnd").Child("AdvRqst_ProgressTextLabel").Text()
            mq.TLO.Window("AdventureRequestWnd").DoClose()

            for progress in string.gmatch(progressText, '([^of]+)') do
                table.insert(progressTable, tonumber(progress))
            end
            if(self.AdventureTotalNeeded == -1) then
                self.AdventureTotalNeeded = progressTable[2]
            end
    
            self.AdventerTotal = progressTable[1]

            return (tonumber(progressTable[1]) == self.AdventureTotalNeeded)
        end
        
        return false
    end
    
    function self.xTargetHaters()
        
        local haterCount = 0

        local haters = mq.TLO.SpawnCount("xtarhater")()
        for i=1,haters do
            local currentSpawn = mq.TLO.NearestSpawn(i, "xtarhater")
            if not invalidSpawn(currentSpawn) then
                haterCount = haterCount + 1
            end
        end

        return haterCount
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
    
    function self.needToMed(minimumMana)
        -- check for slowed because Stonewall Discipline triggers and messes me up
        return (mq.TLO.Group.LowMana(minimumMana)() > 0)
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

    function self.COTH(maxDistance)
        local castoruse = "useitem"

        if self.ConfigurationSettings.COTH ~= "" then
            i,j = string.find(string.upper("Call of the Heroes"), string.upper(self.ConfigurationSettings.COTH))
            if i then
                castoruse = "cast"
            end

            local groupSize = mq.TLO.Group.GroupSize() -1
            for i=1,groupSize do
                if mq.TLO.Group.Member(i).Spawn.Distance() > maxDistance then
                    local memberNameToCoth = mq.TLO.Group.Member(i).Name()
                    local memberIdToCoth = mq.TLO.Group.Member(i).Spawn.ID()

                    if self.ConfigurationSettings.COTHCharacter == "" or string.upper(self.ConfigurationSettings.COTHCharacter) == string.upper(mq.TLO.Me.Name()) then
                        -- Perform COTH yourself
                        mq.cmdf("/target id %d", memberIdToCoth)
                        mq.delay(100)
                        mq.cmdf('/%s "%s"',castoruse, self.ConfigurationSettings.COTH)
                        mq.delay("16s")
                    else
                        -- /bct character to coth
                        if string.upper(memberNameToCoth) ~= string.upper(self.ConfigurationSettings.COTHCharacter) and mq.TLO.Group.Member(self.ConfigurationSettings.COTHCharacter).Spawn.Distance() < maxDistance then
                            mq.cmdf("/bct %s //target id %d", self.ConfigurationSettings.COTHCharacter, memberIdToCoth)
                            mq.delay(100)
                            mq.cmdf('/bct %s //%s "%s"', self.ConfigurationSettings.COTHCharacter, castoruse, self.ConfigurationSettings.COTH)
                            mq.delay("16s")
                        end
                    end
                end
            end
        end
    end

    function self.ldonBind(...)
        local arg = {...}
        local stringtoboolean={ ["true"]=true, ["false"]=false }

        if #arg > 0 then
            if string.upper(arg[1]) == "PMIZ" then
                self.printMobsInZone()
            elseif string.upper(arg[1]) == "AC" then
                self.adventureComplete()
            elseif string.upper(arg[1]) == "RELOAD" then
                self.getIniSettings()
            elseif string.upper(arg[1]) == "X" then
                print(string.format("xtarget %d - mycalc %d", mq.TLO.Me.XTarget(), instance.xTargetHaters()))
            elseif string.upper(arg[1]) == "PULLSIZE" then
                if arg[2] then
                    self.ConfigurationSettings.PullSize = tonumber(arg[2])
                end
                print(string.format("Pullsize is %d", self.ConfigurationSettings.PullSize))
            elseif string.upper(arg[1]) == "LOOT" then
                if arg[2] then
                    self.ConfigurationSettings.LootEnabled = stringtoboolean[string.lower(arg[2])]
                end
                print(string.format("Loot Enabled is set to %s", self.ConfigurationSettings.LootEnabled))
            elseif string.upper(arg[1]) == "CAC" then
                if arg[2] then
                    local cacBool = stringtoboolean[string.lower(arg[2])]
                    self.ConfigurationSettings.ContinueAfterComplete = cacBool
                else
                    self.ConfigurationSettings.ContinueAfterComplete = not self.ConfigurationSettings.ContinueAfterComplete
                end
                print(string.format("Continue After Complete is set to %s", self.ConfigurationSettings.ContinueAfterComplete))
            end
        else
            print("LDONUtility usage:")
            print('/ldu pmiz - print mobs in zone.  Mostly for debugging to make sure your Invalid Spawns are being applied correctly')
            print("/ldu ac - shows adventure complete status")
            print("/ldu cac [true/false] - without [true/false] this will toggle continue after complete, otherwise it forces it to true/false")
            print("/ldu pullsize # - sets the pullsize so you can change while you're running")
            print("/ldu loot [true/false] - set looting on(true) or off(false)")
            print("/ldu reload - reload INI settings")
        end
    end

    return self
end

local startTime = os.clock()
local args = {...}

local instance = LDONUtil.new()

instance.getIniSettings()

-- You can override your pull size by doing /lua run LDONUtil.lua <pullsize>.
if(#args > 0) then
    instance.ConfigurationSettings.PullSize = tonumber(args[1])
end

instance.initZone()

-- set up bind for ldon utlity with /ldu
-- /ldu pmiz -- print mobs in zone
-- /ldu ac -- print adventure complete status
-- /ldu cac true/false set continue after complete to true/false
mq.bind("/ldu", instance.ldonBind)

if #instance.ConfigurationSettings.OnStart > 0 then
    for token in string.gmatch(instance.ConfigurationSettings.OnStart, "[^;]+") do
        if string.sub(string.upper(token), 1, 5) == "DELAY" then
            local delay = string.sub(token, 7,#token)
            mq.delay(delay)
        else
            mq.cmdf(token)
            mq.delay(200)
        end
    end
end

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
    if(mq.TLO.Navigation.PathExists(string.format("id %d", closestId))() and not instance.adventureComplete()) then
        mq.cmdf("/squelch /target id %d", closestId)
        mq.delay(100)
        mq.cmdf("/squelch /nav id %d", closestId)
        mq.delay(100)
        while(not instance.Paused and mq.TLO.Navigation.Active())
        do
            if instance.xTargetHaters() >= instance.ConfigurationSettings.PullSize then
                instance.pause()
            elseif not instance.everyoneHere(instance.ConfigurationSettings.MaxFollowDistance) and mq.TLO.Me.XTarget() >= math.ceil(instance.ConfigurationSettings.PullSize / 2) then
                instance.pause()
            elseif instance.anyoneInjured(instance.ConfigurationSettings.MinHealth) then
                instance.pause()
            elseif not instance.everyoneHere(instance.ConfigurationSettings.MaxFollowDistance) then
                instance.pause()
                mq.cmdf("/squelch /bcg //nav id %d", mq.TLO.Me.ID())
                mq.delay("8s", function() return instance.everyoneHere(instance.ConfigurationSettings.MinFollowDistance) end)
                if not instance.everyoneHere(instance.ConfigurationSettings.MinFollowDistance) then
                    instance.COTH(instance.ConfigurationSettings.MinFollowDistance)
                end
                mq.cmdf("/followme")
                mq.delay(500)
                instance.unpause()
            end
        end

        -- If we're not active or paused check conditions to see if we need combat, looting or med
        while(instance.Paused)
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
                mq.cmdf("/clearxtargets ForceOff")
                mq.delay(200)
                mq.cmdf("/squelch /bc loot on")
                mq.delay("15s", function() return (instance.inCombat() or (not instance.anyMobsToLoot())) end)
            elseif instance.needToMed(instance.ConfigurationSettings.MinMana) and instance.LoopBoolean then
                print("Done Looting, we need to med!")
                mq.cmdf("/clearxtargets ForceOff")
                mq.delay(200)
                mq.cmdf("/squelch /stop")
                mq.delay(500)
                mq.cmdf("/squelch /medon")
                mq.delay("120s", function() return (instance.inCombat() or (not instance.needToMed(instance.ConfigurationSettings.MedMana))) end)
                if not instance.needToMed(instance.ConfigurationSettings.MinMana) then
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
local currentScore = math.ceil(os.clock() - startTime)
print(string.format("Run time was %d seconds", currentScore))

if #instance.ConfigurationSettings.OnFinish > 0 then
    for token in string.gmatch(instance.ConfigurationSettings.OnFinish, "[^;]+") do
        if string.sub(string.upper(token), 1, 5) == "DELAY" then
            local delay = string.sub(token, 7,#token)
            mq.delay(delay)
        else
            mq.cmdf(token)
            mq.delay(200)
        end
    end
end


