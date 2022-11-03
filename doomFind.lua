local mq = require('mq')
local loopBoolean = true
local spawnGroup = {"froglok_hunter", "Dreadlord_Dekir", "Ebon_lotus", "Ffroaak", "Harbinger_Josk", "Hierophant_Ixyl", "Keeper_Sepsis", "Knight_Dragol", 
"Master_Fasliw", "Oracle_Froskil", "Partisan_Yinlen", "Sigra", "Throkkok", "Trakanasaur_Rex", "Vessel_Fryn" }

function doomFind()
    local closestSpawnlnDistance = 999999
    local closestSpawnId = 0

    for key, value in pairs(spawnGroup) do
        if mq.TLO.SpawnCount(string.format("npc %s", value))() > 0 then
            local currentSpawn = mq.TLO.Spawn(string.format("npc %s", value))
            local currentSpawnId = currentSpawn.ID()
            local currentSpawnDistance = mq.TLO.Navigation.PathLength(string.format("id %d", currentSpawnId))()
            if currentSpawnDistance < closestSpawnlnDistance then
                closestSpawnlnDistance = currentSpawnDistance
                closestSpawnId = currentSpawnId
            end
        end
    end

    if mq.TLO.SpawnCount(string.format("npc Doom"))() > 0 then
        closestSpawnId = mq.TLO.Spawn("Doom").ID()
        mq.cmdf("/beep")
        mq.cmdf("/popup Doom is up!")
    end

    if closestSpawnId > 0 then
        mq.cmdf("/target id %d", closestSpawnId)
    else
        mq.cmdf("/bc No spawns matched.")
    end
end

function exitScript()
    loopBoolean = false
end

mq.bind("/doomexit", exitScript)
mq.bind("/doomfind", doomFind)

while(loopBoolean) do
    mq.delay(10)
end
