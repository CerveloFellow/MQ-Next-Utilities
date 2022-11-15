local mq = require('mq')
SpawnWatch = {}

function SpawnWatch.new()
    local self = {}
    self.INI = mq.TLO.MacroQuest.Path("Config")().."\\SpawnWatch.ini"
    self.ConfigurationSettings = {}
    self.ConfigurationSettings.WindowWidth = 300
    self.ConfigurationSettings.WindowHeight = 200
    -- The listbox displaying the spawns is sorted by these fields
    -- distance - the distance from you
    -- name - alphabetically
    -- levelhigh - level from high to low
    -- levellow - level from low to hight
    self.ConfigurationSettings.Sort = "distance"

    self.SpawnTable = {}
    self.WatchTable = {}
    self.openGUI = true
    self.CurrentIndex = 0
    self.LoadedZone = mq.TLO.Zone.ShortName()

    function getKey(file, section, key, defaultValue)
        local returnValue = defaultValue

        if mq.TLO.Ini.File(file).Section(section).Key(key).Exists() then
            returnValue = mq.TLO.Ini.File(file).Section(section).Key(key).Value()
        else
            mq.cmdf('/ini "%s" "%s" "%s" "%s"', file, section, key, defaultValue)
        end

        return returnValue
    end

    function self.createIniDefaults()
        if not mq.TLO.Ini.File(self.INI).Exists() then
            mq.cmdf('/ini "%s" "%s" "%s" "%s"', self.INI, "General", "WindowWidth", self.ConfigurationSettings.WindowWidth)
            mq.cmdf('/ini "%s" "%s" "%s" "%s"', self.INI, "General", "WindowHeight", self.ConfigurationSettings.WindowHeight)
            mq.cmdf('/ini "%s" "%s" "%s" "%s"', self.INI, "General", "Sort", self.ConfigurationSettings.Sort)
        end
    end

    function self.getIniSettings()
        stringtoboolean={ ["true"]=true, ["false"]=false }

        if not mq.TLO.Ini.File(self.INI).Exists() then
            self.createIniDefaults()
        else
            self.ConfigurationSettings.WindowWidth = tonumber(getKey(self.INI, "General", "WindowWidth", self.ConfigurationSettings.WindowWidth))
            self.ConfigurationSettings.WindowHeight = tonumber(getKey(self.INI, "General", "WindowHeight", self.ConfigurationSettings.WindowHeight))
            self.ConfigurationSettings.Sort = getKey(self.INI, "General", "Sort", self.ConfigurationSettings.Sort)
            
        end

        if not mq.TLO.Ini.File(self.INI).Section(mq.TLO.Me.Name()).Exists() then
            mq.cmdf('/ini "%s" "%s" "%s" "%s"', self.INI, "General", "WindowWidth", self.ConfigurationSettings.WindowWidth)
            mq.cmdf('/ini "%s" "%s" "%s" "%s"', self.INI, "General", "WindowHeight", self.ConfigurationSettings.WindowHeight)
            mq.cmdf('/ini "%s" "%s" "%s" "%s"', self.INI, "General", "Sort", self.ConfigurationSettings.Sort)
        else
            self.ConfigurationSettings.WindowWidth = tonumber(getKey(self.INI, "General", "WindowWidth", self.ConfigurationSettings.WindowWidth))
            self.ConfigurationSettings.WindowHeight = tonumber(getKey(self.INI, "General", "WindowHeight", self.ConfigurationSettings.WindowHeight))
            self.ConfigurationSettings.Sort = getKey(self.INI, "General", "Sort", self.ConfigurationSettings.Sort)
        end
    end

    function self.getWatchList()
        local zoneShortName = mq.TLO.Zone.ShortName()
        if mq.TLO.Ini.File(self.INI).Section(zoneShortName).Exists() then
            print(string.format("%s exists",zoneShortName))
        else
            print(string.format("%s does not exists", zoneShortName))
        end
    end

    function spawnExists(zoneShortName, spawnName)
        local spawnCount = mq.TLO.Ini.File(self.INI).Section(zoneShortName).Key.Count()
        local i

        for i=0,spawnCount do
            local spawnString = string.format("spawn%d", i)
            local value = mq.TLO.Ini.File(self.INI).Section(zoneShortName).Key(spawnString).Value()
            if value == spawnName then
                return true
            end
        end

        return false
    end

    function self.AddSpawn(spawnName)
        if #spawnName > 0 then
            local zoneShortName = mq.TLO.Zone.ShortName()
            local spawnCount = mq.TLO.Ini.File(self.INI).Section(zoneShortName).Key.Count()
            local spawnString = string.format("spawn%d", spawnCount)

            -- don't add the spawn if it's already in the list
            if not spawnExists(zoneShortName, spawnName) then
                mq.cmdf('/ini "%s" "%s" "%s" "%s"', self.INI, zoneShortName, spawnString, spawnName)
            end
        else
            print("You must supply a spawn name when adding a spawn.")
        end
    end

    function self.GetWatchTable()
        local zoneShortName = mq.TLO.Zone.ShortName()
        local spawnCount = mq.TLO.Ini.File(self.INI).Section(zoneShortName).Key.Count() - 1
        local i

        self.WatchTable = {}

        for i=0,spawnCount do
            local spawnString = string.format("spawn%d", i)
            local value = mq.TLO.Ini.File(self.INI).Section(zoneShortName).Key(spawnString).Value()
            table.insert(self.WatchTable, value)
        end
    end

    function spawnFilter(spawn)
        local returnVal = false
        for key, value in pairs(self.WatchTable) do
            i,j = string.find(string.upper(spawn.CleanName()), string.upper(value))
            if i then
                returnVal = true and (spawn.Type() == "NPC") and not spawn.Dead()
            end
        end
        return returnVal
    end

    function sortingFunction(spawn1, spawn2)
        if string.upper(self.ConfigurationSettings.Sort) == "NAME" then
            return spawn1.Name() < spawn2.Name()
        elseif string.upper(self.ConfigurationSettings.Sort) == "LEVELLOW" then
            return spawn1.Level() < spawn2.Level()
        elseif string.upper(self.ConfigurationSettings.Sort) == "LEVELHIGH" then
            return spawn1.Level() > spawn2.Level()
        else
            return spawn1.Distance() < spawn2.Distance()
        end
    end

    function self.GetSpawnTable()
        local filteredSpawns = mq.getFilteredSpawns(spawnFilter)
        local tempTable = {}

        for index, spawn in ipairs(filteredSpawns) do
            table.insert(tempTable, spawn)
        end

        table.sort(tempTable, sortingFunction)

        self.SpawnTable = {}
        for key, value in ipairs(tempTable) do
            table.insert(self.SpawnTable, value)
        end
    end

    function selectFirstEntry()
        if #self.SpawnTable > 0 then
            mq.cmdf("/target id %d", self.SpawnTable[1].ID())
        end
    end

    function self.DrawMainWindow()
        if not self.openGUI then return end
        if not mq.TLO.Zone.ShortName() == self.LoadedZone then
            self.GetWatchTable()
        end
        self.GetSpawnTable()

        self.openGUI, self.shouldDrawGUI = ImGui.Begin(mq.TLO.Zone.Name(), self.openGUI )
    
        if ImGui.ListBoxHeader("", self.ConfigurationSettings.WindowWidth, self.ConfigurationSettings.WindowHeight) then
            local lbSize = #self.SpawnTable
            for i=1,lbSize do
                local ls = self.SpawnTable[i]

                local selectableText = string.format("%s(%d) - %d", ls.Name(), ls.Level(), ls.Distance())
                if ImGui.Selectable(selectableText, false) then
                    self.CurrentIndex = i
                    mq.cmdf("/target id %d", self.SpawnTable[self.CurrentIndex].ID())
                end
            end
            ImGui.ListBoxFooter()
        end
    
        if ImGui.Button("Reload") then
            self.GetWatchTable()
        end
        ImGui.SameLine()
        if ImGui.Button("Add Target") then
           self.AddSpawn(mq.TLO.Target.CleanName())
        end
        ImGui.SameLine()
        if ImGui.Button("Select First Entry") then
            selectFirstEntry()
        end
        ImGui.End()
    end

    function self.spawnWatchBind(...)
        local arg={...}

        if #arg > 0 then
            if string.upper(arg[1]) == "TARGET" then
                if mq.TLO.Target() then
                    self.AddSpawn(mq.TLO.Target.CleanName())
                else
                    print("Target a mob to add it.")
                end
            elseif string.upper(arg[1]) == "RELOAD" then
                self.GetWatchTable()
            elseif string.upper(arg[1]) == "FIRST" then
                selectFirstEntry()
            end
        else
            print("spawnwatch usage:")
            print('/spawnwatch target - adds the targeted spawn to your spawnwatch list')
            print("/spawnwatch reload - reloads the watch table from the INI")
            print("/spawnwatch first - targets the first entry in the list")
        end
        local printMode = #arg > 0 and (string.lower(arg[1]) == "print") and true or false
    end

    return self
end

local args = {...}

local instance = SpawnWatch.new()
instance.getIniSettings()

mq.bind("/spawnwatch", instance.spawnWatchBind)

if(#args > 0) then
    -- override config settings here
end

instance.GetWatchTable()

mq.imgui.init('Spawn Watch', instance.DrawMainWindow)

while(instance.openGUI) do
    mq.delay(1000)
end


