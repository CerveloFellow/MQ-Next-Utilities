--[[
    LootSettingsUtil.lua

    This script provides some utilities to get and set values from the Loot Settings.ini table

    *** Note ***
    I've come across two different algorithms for writing entries to the Loot Settings.ini file. As such, when calls are made to getItemValue, a table is returned with both values so that a lookup for all 
    values can be done.

    Algorithm 1:
        Returns #p#g#s#g and and will omit zero values.  
        Examples: 
            321 will return 3g2s1c
            301 will return 3g1c
            7654321 will return 7654p3g2s1c
    
    Algorithm 12
        Returns only the highest non-zero coin amount
        Examples: 
            321 will return 3g
            301 will return 3g
            7654321 will return 7654p
    
]]--
local mq = require('mq')

LootSettingUtil = { }

function LootSettingUtil.new(pathToIniFile)
    local self = {}
    local lootSettingsIni

    self.lootSettingsIni = pathToIniFile

    -- gets an item value in 1p1g1s1c format
    function getItemValue(value)
        local stringlen = string.len(value)
        local copper = ""
        local silver = ""
        local gold = ""
        local plat = ""
        local temp = ""
        local highestValue = ""
        local tbl = {}

        -- copper
        if ( stringlen > 0 ) then
            temp = string.sub(value,stringlen)
            copper = ((temp=="0" or string.len(temp)==0) and "" or temp.."c")
            if string.len(copper) > 0 then
                highestValue = copper
            end
        end
        -- silver
        if ( stringlen > 1 ) then
            temp = string.sub(value,stringlen-1,stringlen-1)
            silver = ((temp=="0" or string.len(temp)==0) and "" or temp.."s")
            if string.len(silver) > 0 then
                highestValue = silver
            end
        end
        -- gold
        if ( stringlen > 2 ) then
            temp = string.sub(value,stringlen-2,stringlen-2)
            gold = ((temp=="0" or string.len(temp)==0) and "" or temp.."g")
            if string.len(gold) > 0 then
                highestValue = gold
            end
        end
        -- plat
        if ( stringlen > 3 ) then
            temp = string.sub(value,1,stringlen-3)
            plat = ((temp=="0" or string.len(temp)==0) and "" or temp.."p")
            if string.len(plat) > 0 then
                highestValue = plat
            end
        end
        
        table.insert(tbl,plat..gold..silver..copper)
        table.insert(tbl, highestValue)
        return tbl
    end

    function getItemAttributes(itemStackSize, itemNoDrop, itemLore)
        local returnValue = ""
        
        if( tonumber(itemStackSize) > 0 ) then
            returnValue = "("..itemStackSize..")"
        end
        
        if( itemNoDrop ) then
            returnValue = returnValue.."(ND)"
        end 
        
        if( itemLore ) then
            returnValue = returnValue.."(L)"
        end 
        
        return returnValue
    end

    -- would love to pass am mq.TLO.Item in here, but can't figure out how to convert the table to the user defined object.
    -- therefore have to pass in all of the needed parms as simple parameters
    function self.getIniKey(itemName, itemValue, itemStackSize, itemNoDrop, itemLore)
        local tblKey = {}
        local tblValue = {}

        -- replace : with ; and remove commas
        local itemName = itemName:gsub(":",";"):gsub(",","")
        tblValue = getItemValue(itemValue)
        local itemAttributes = getItemAttributes(itemStackSize, itemNoDrop, itemLore)
        local itemKey = string.sub(itemName,1,1)
        for i=1,#tblValue do
            table.insert(tblKey, itemName.." "..tblValue[i]..itemAttributes)
        end

        return tblKey
    end

    function self.getIniValue(itemName)
        return mq.TLO.Ini(self.lootSettingsIni, string.sub(itemName,1,1), itemName)()
    end

    function self.setIniValue(itemKey, itemValue)
        mq.cmdf('/ini "%s" "%s" "%s" "%s"', self.lootSettingsIni, string.sub(itemKey,1,1), itemKey, itemValue)
    end

    return self
end


