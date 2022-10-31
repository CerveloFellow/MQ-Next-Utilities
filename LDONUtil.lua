local mq = require('mq')

local combatRadius = 200
local loopBoolean = true
local pullSize = {}
local distinctMobsTable = {}
local paused = false
local adventureTotalNeeded = -1
local adventureTotal = -1
local entireZoneTable = {}
local spawnCount = 0
local totalSpawnLevel = 0
local remainingCount = 999

pullSize["Blorb"] = 7
pullSize["Aezorn"] = 5
pullSize["Aroxin"] = 5

function printMobsInZone()
    local sortedTable = {}
    for k,v in pairs(distinctMobsTable) do
        table.insert(sortedTable, k)
    end
    table.sort(sortedTable)
    for _, k in ipairs(sortedTable) do print(k) end
end

function isNumeric(n)
    return (type(n) == "number") and (math.floor(n) == n)
  end

function pause()
    if (not mq.TLO.Navigation.Paused()) then
        mq.cmdf("/squelch /nav pause")
    end
    paused = true
end

function unpause()
    if (mq.TLO.Navigation.Paused()) then
        mq.cmdf("/squelch /nav pause")
    end
    paused = false
end

function invalidSpawn(spawn)
    local invalidSpawns = {
        "A Dark Coffin", "A Bitten Victim", "A Dark Chest", "A Wooden Barrel", "a hollow tree", "a creaking crate", "an orcish chest", "a petrified colossal tree", "a hollow tree", "a menacing tree spirit"
    }

    for j=1, #invalidSpawns do
        local currentSpawnName = string.upper(spawn.CleanName())
        local comparisonSpawnName = string.upper(invalidSpawns[j])
        if currentSpawnName == comparisonSpawnName then
            return true
        end
    end
    return false
end

function inCombat()
    local invalidSpawnCount = 0
    local spawnCount = mq.TLO.SpawnCount(string.format("xtarhater radius %d", combatRadius))()
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

function needToMed()
    -- check for slowed because Stonewall Discipline triggers and messes me up
    return (mq.TLO.Group.LowMana(25)() > 0)
end

function everyoneHere(distance)
    if mq.TLO.Me.Grouped() then
        return (mq.TLO.SpawnCount(string.format("group radius %d", distance))() == mq.TLO.Group.GroupSize())
    else
        return true
    end
end

function anyMobsToLoot()
    return (mq.TLO.SpawnCount("npc corpse zradius 50 radius 50")() > 0)
end

function anyoneInjured(healthPercent)
    if mq.TLO.Me.Grouped() then
        return mq.TLO.Group.Injured(healthPercent)() > 0
    else
        return mq.TLO.Me.PctHPs() < healthPercent
    end
end

function spawnFilter(spawn)
    return (spawn.Type() == "NPC") and (not invalidSpawn(spawn)) and spawn.Targetable() and not spawn.Dead() and not spawn.Trader()
end

function adventureComplete()
    
    local progressText = mq.TLO.Window("AdventureRequestWnd").Child("AdvRqst_ProgressTextLabel").Text()
    local progressTable = {}

    print(string.format("%d of %d", adventureTotal, adventureTotalNeeded))


    if string.len(progressText) > 0 then
        for progress in string.gmatch(progressText, '([^of]+)') do
            table.insert(progressTable, tonumber(progress))
        end
        if(adventureTotalNeeded == -1) then
            adventureTotalNeeded = progressTable[2]
        end

        adventureTotal = progressTable[1]

        remainingCount = adventureTotalNeeded - adventureTotal

        return (progressTable[1] == progressTable[2])
    else
        if adventureTotal > 0 then
            return true
        end
    end
    
    return false
end

function getPullSize()
    local minPullSize = pullSize[mq.TLO.Me.Name()] or 3
    if minPullSize > remainingCount then
        minPullSize = math.ceil(remainingCount * 1.5)
    end

    if minPullSize > (pullSize[mq.TLO.Me.Name()] or 3) then
        minPullSize = (pullSize[mq.TLO.Me.Name()] or 3)
    end
    
    --return minPullSize
    return pullSize[mq.TLO.Me.Name()] or 3
end

local args = {...}

if(#args > 0) then
    pullSize[mq.TLO.Me.Name()] = tonumber(args[1])
end

local entireZoneSpawn = mq.getFilteredSpawns(spawnFilter)

for index, spawn in ipairs(entireZoneSpawn) do
    table.insert(entireZoneTable, spawn.ID())
    if not distinctMobsTable[spawn.CleanName()] then
        distinctMobsTable[spawn.CleanName()] = spawn
    end
    spawnCount = spawnCount + 1
    totalSpawnLevel = totalSpawnLevel + spawn.Level()
end

mq.bind("/ac", adventureComplete)
mq.bind("/pmiz", printMobsInZone)
mq.cmdf("/bc loot on")
mq.delay(500)
mq.cmdf("/lootall")
mq.delay(500)
mq.cmdf("/followme")
mq.delay(500)

while (#entireZoneTable > 0 and loopBoolean)
do
    local pathLength = 999999
    local npcDistance = 99999
    local spawnId = 0
    local tablePosition = 0
    for i=1, #entireZoneTable do
        local npcPathLength = mq.TLO.Navigation.PathLength(string.format("id %d", entireZoneTable[i]))()
        if(npcPathLength < pathLength) then
            spawnId = entireZoneTable[i]
            pathLength = npcPathLength
            tablePosition = i
        end
    end
    
    local closestId = table.remove(entireZoneTable, tablePosition)
    if(mq.TLO.Navigation.PathExists(string.format("id %d", closestId))()) then
        mq.cmdf("/squelch /target id %d", closestId)
        mq.cmdf("/squelch /nav id %d", closestId)
        while(not mq.TLO.Navigation.Paused() and mq.TLO.Navigation.Active())
        do
            if mq.TLO.Me.XTarget() >= getPullSize() then
                pause()
            elseif not everyoneHere(250) and mq.TLO.Me.XTarget() >= (getPullSize() / 2) then
                pause()
            elseif anyoneInjured(70) then
                pause()
            elseif not everyoneHere(250) then
                pause()
                mq.cmdf("/squelch /bcg //nav id %d", mq.TLO.Me.ID())
                mq.delay("8s", function() return everyoneHere(10) end)
                unpause()
            end
        end

        -- If we're not active or paused check conditions to see if we need combat, looting or med
        while(paused)
        do
            if(inCombat()) then
                print("In Combat... start fighting!")
                mq.cmdf("/squelch /medoff")
                mq.delay(1000)
                mq.cmdf("/clearxtargets ForceOn")
                mq.delay(500)
                mq.cmdf("/squelch /bcg //nav id %d", mq.TLO.Me.ID())
                mq.delay("5s", function() return (not inCombat()) end)
            elseif anyMobsToLoot() then
                print("Combat finished, time to loot!")
                mq.cmdf("/squelch /bc loot on")
                mq.delay("10s", function() return (inCombat() or (not anyMobsToLoot())) end)
            elseif needToMed() and loopBoolean then
                print("Done Looting, we need to med!")
                mq.delay("2s")
                mq.cmdf("/squelch /stop")
                mq.cmdf("/squelch /medon")
                mq.delay("20s", function() return (inCombat() or (not needToMed())) end)
                if not needToMed() then
                    mq.cmdf("/squelch /followme")
                    mq.cmdf("/squelch /medoff")
                end
            else
                print("Resume play.")
                if not everyoneHere(80) then
                    mq.cmdf("/squelch /bcg //nav id %d", mq.TLO.Me.ID())
                    mq.delay("15s", function() return everyoneHere(80) end)
                end
                unpause()
            end

            if adventureComplete() then
                loopBoolean = false
            end
        end
    end

    if adventureComplete() then
        loopBoolean = false
    end
end

mq.cmdf("/bcga //nav stop")
mq.delay(500)

while(inCombat()) do
    print("In Combat... start fighting!")
    mq.cmdf("/squelch /medoff")
    mq.delay(500)
    mq.cmdf("/clearxtargets ForceOn")
    mq.delay(500)
    mq.cmdf("/squelch /bcg //nav id %d", mq.TLO.Me.ID())
    mq.delay("5s", function() return (not inCombat()) end)
end

print("Playback ended!")