--[[
    ItemScore.lua
    
    This script evaluates items and compares them to currently equipped items.
    It uses class-specific stat weights to determine if items are upgrades.
    
    Usage:
        1. /lua run ItemScore - Start the script
        2. /itemscore - Evaluate item in DisplayItem window
        3. /findupgrades - Scan all bags for upgrades
        4. /findupgrades # - Scan specific bag (1-10)
        5. /findupgrades #-# - Scan bag range (e.g., 2-4)
        6. /findupgrades #,#,# - Scan specific bags (e.g., 2,4,6)
--]]

local mq = require('mq')

-- Color codes for highlighting
local GREEN = '\ag'
local YELLOW = '\ay'
local WHITE = '\ax'
local CYAN = '\at'
local RED = '\ar'

-- Slot ID to friendly name mapping
local SLOT_NAMES = {
    [0] = 'Charm',
    [1] = 'Left Ear',
    [2] = 'Head',
    [3] = 'Face',
    [4] = 'Right Ear',
    [5] = 'Neck',
    [6] = 'Shoulder',
    [7] = 'Arms',
    [8] = 'Back',
    [9] = 'Left Wrist',
    [10] = 'Right Wrist',
    [11] = 'Ranged',
    [12] = 'Hands',
    [13] = 'Main Hand',
    [14] = 'Off Hand',
    [15] = 'Left Finger',
    [16] = 'Right Finger',
    [17] = 'Chest',
    [18] = 'Legs',
    [19] = 'Feet',
    [20] = 'Waist',
    [21] = 'Power Source',
    [22] = 'Ammo'
}

-- Class-specific stat weights
local CLASS_WEIGHTS = {
    Warrior = {
        AC = 10, HP = 8, Attack = 8, Haste = 6, HeroicSTR = 9, HeroicSTA = 8,
        STR = 4, STA = 4, Avoidance = 6, Shielding = 5, StunResist = 4,
        DamageShieldMitigation = 3, AGI = 3, HeroicAGI = 10, DEX = 2, HeroicDEX = 7,
        Endurance = 3, EnduranceRegen = 3, HPRegen = 4, DamageRatio = 100, DMGBonus = 8
    },
    Cleric = {
        Mana = 10, ManaRegen = 9, WIS = 8, HeroicWIS = 8, AC = 5, HP = 5,
        HealAmount = 7, SpellDamage = 3, Haste = 2, HeroicSTA = 6, HeroicWIS = 5, STA = 3,
        Shielding = 4, svMagic = 3, HeroicSvMagic = 3, Clairvoyance = 6, DamageRatio = 50
    },
    Paladin = {
        AC = 8, HP = 7, Mana = 6, ManaRegen = 5, STR = 5, HeroicSTR = 7,
        STA = 5, HeroicSTA = 7, WIS = 4, HeroicWIS = 6, Attack = 8, Haste = 5,
        Shielding = 5, HealAmount = 4, Avoidance = 4, Endurance = 4, EnduranceRegen = 4, 
        DamageRatio = 90, DMGBonus = 8, HeroicDEX = 6, HeroicAGI = 8
    },
    Ranger = {
        STR = 6, HeroicSTR = 6, DEX = 5, HeroicDEX = 7, Attack = 7, Haste = 6,
        Accuracy = 5, HP = 6, AC = 5, STA = 5, HeroicSTA = 5, AGI = 4, HeroicAGI = 8,
        WIS = 3, HeroicWIS = 3, Mana = 4, ManaRegen = 3, Avoidance = 4,
        Endurance = 5, EnduranceRegen = 5, DamageRatio = 120, DMGBonus = 8
    },
    Shadowknight = {
        AC = 8, HP = 7, STR = 6, HeroicSTR = 7, STA = 5, HeroicSTA = 5,
        Attack = 6, Haste = 5, INT = 4, HeroicINT = 4, Mana = 5, ManaRegen = 4,
        Shielding = 5, SpellDamage = 3, Avoidance = 4, Endurance = 4, EnduranceRegen = 4, 
        DamageRatio = 90, DMGBonus = 8, HeroicDEX = 6, HeroicAGI = 8
    },
    Druid = {
        Mana = 10, ManaRegen = 9, WIS = 8, HeroicWIS = 8, HP = 4, AC = 3,
        HealAmount = 6, SpellDamage = 5, Haste = 2, STA = 3, HeroicSTA = 5,
        svMagic = 3, HeroicSvMagic = 3, Clairvoyance = 6, DamageRatio = 40,
        HeroicDEX = 6, HeroicAGI = 8
    },
    Monk = {
        STR = 6, HeroicSTR = 7, DEX = 5, HeroicDEX = 7, Attack = 8, Haste = 7,
        HP = 6, AC = 4, STA = 5, HeroicSTA = 6, AGI = 7, HeroicAGI = 9,
        Avoidance = 6, Accuracy = 5, StrikeThrough = 5, Endurance = 6, EnduranceRegen = 6, 
        DamageRatio = 120, DMGBonus = 8
    },
    Bard = {
        Mana = 7, ManaRegen = 6, CHA = 5, HeroicCHA = 4, HP = 5, AC = 4,
        STR = 4, DEX = 4, AGI = 4, Haste = 5, Attack = 5, STA = 4,
        Avoidance = 4, Endurance = 5, EnduranceRegen = 5, svMagic = 3, 
        DamageRatio = 80, DMGBonus = 5, HeroicDEX = 7, HeroicAGI = 8, HeroicSTR = 7
    },
    Rogue = {
        STR = 6, HeroicSTR = 8, DEX = 8, HeroicDEX = 8, AGI = 7, HeroicAGI = 7,
        Attack = 8, Haste = 7, Accuracy = 6, HP = 6, AC = 4, STA = 5, HeroicSTA = 5,
        Avoidance = 5, StrikeThrough = 6, Endurance = 6, EnduranceRegen = 6, 
        DamageRatio = 120, DMGBonus = 8
    },
    Shaman = {
        Mana = 10, ManaRegen = 9, WIS = 8, HeroicWIS = 8, HP = 5, AC = 4,
        HealAmount = 6, SpellDamage = 5, STA = 4, HeroicSTA = 4, Haste = 3,
        Shielding = 3, svMagic = 3, HeroicSvMagic = 3, Clairvoyance = 6, DamageRatio = 50,
        HeroicWIS = 5
    },
    Necromancer = {
        Mana = 10, ManaRegen = 9, INT = 8, HeroicINT = 8, HP = 4, AC = 2,
        SpellDamage = 7, STA = 3, HeroicSTA = 5, Haste = 2, svMagic = 3,
        HeroicSvMagic = 3, Clairvoyance = 6, DoTShielding = 4, DamageRatio = 20
    },
    Wizard = {
        Mana = 10, ManaRegen = 9, INT = 8, HeroicINT = 8, HP = 3, AC = 2,
        SpellDamage = 8, STA = 3, HeroicSTA = 5, Haste = 2, svMagic = 3,
        HeroicSvMagic = 3, Clairvoyance = 7, DamageRatio = 20
    },
    Magician = {
        Mana = 10, ManaRegen = 9, INT = 8, HeroicINT = 8, HP = 3, AC = 2,
        SpellDamage = 7, STA = 3, HeroicSTA = 5, Haste = 2, svMagic = 3,
        HeroicSvMagic = 3, Clairvoyance = 6, DamageRatio = 20
    },
    Enchanter = {
        Mana = 10, ManaRegen = 9, INT = 8, HeroicINT = 8, CHA = 6, HeroicCHA = 6,
        HP = 3, AC = 2, SpellDamage = 5, STA = 3, HeroicSTA = 5, Haste = 2,
        svMagic = 3, HeroicSvMagic = 3, Clairvoyance = 7, DamageRatio = 20
    },
    Beastlord = {
        STR = 5, HeroicSTR = 5, DEX = 4, HeroicDEX = 4, Attack = 6, Haste = 5,
        HP = 6, AC = 5, STA = 5, HeroicSTA = 5, WIS = 6, HeroicWIS = 6,
        Mana = 7, ManaRegen = 6, AGI = 5, HeroicAGI = 6, Avoidance = 4,
        HealAmount = 4, Endurance = 5, EnduranceRegen = 5, DamageRatio = 70, DMGBonus = 6
    },
    Berserker = {
        STR = 7, HeroicSTR = 8, DEX = 6, HeroicDEX = 7, Attack = 8, Haste = 7,
        HP = 7, AC = 6, STA = 6, HeroicSTA = 6, AGI = 5, HeroicAGI = 9,
        Avoidance = 4, Accuracy = 6, StrikeThrough = 6, Endurance = 7, EnduranceRegen = 7, 
        DamageRatio = 120, DMGBonus = 8
    },
    Default = {
        HP = 5, AC = 5, Mana = 3, STR = 3, STA = 3, AGI = 3, DEX = 3,
        WIS = 3, INT = 3, CHA = 3, HeroicSTR = 3, HeroicSTA = 3, HeroicAGI = 3,
        HeroicDEX = 3, HeroicWIS = 3, HeroicINT = 3, HeroicCHA = 3,
        Attack = 4, Haste = 4, DamageRatio = 80
    }
}

-- Function to get stat value from item
local function GetStatValue(item, statName)
    if not item then return 0 end
    
    local success, value = pcall(function() return item[statName]() end)
    if success and value then
        local numValue = tonumber(value)
        if numValue then
            return numValue
        end
        if value == true then
            return 1
        end
    end
    
    local success2, value2 = pcall(function() return item[statName] end)
    if success2 and value2 and type(value2) ~= "userdata" then
        local numValue = tonumber(value2)
        if numValue then
            return numValue
        end
    end
    
    return 0
end

-- Function to calculate weighted score for an item
local function CalculateScore(item, weights)
    if not item then return 0 end
    
    local score = 0
    for statName, weight in pairs(weights) do
        if statName ~= 'DamageRatio' then
            local value = GetStatValue(item, statName)
            if value > 0 then
                local contribution = value * weight
                score = score + contribution
            end
        end
    end
    
    local damage = GetStatValue(item, 'Damage')
    local delay = GetStatValue(item, 'ItemDelay')

    if damage > 0 and delay > 0 then
        local damageRatio = damage / delay
        local damageRatioWeight = weights.DamageRatio or 80
        local ratioScore = damageRatio * damageRatioWeight
        score = score + ratioScore
    end
    
    return score
end

-- Function to check if item is wearable (slots 0-22)
local function IsWearable(item)
    if not item or not item.WornSlots then return false end
    
    for i = 1, item.WornSlots() do
        if item.WornSlot(i).ID() < 23 then
            return true
        end
    end
    return false
end

-- Function to check if item skill is 2-handed
local function IsTwoHandedWeapon(item)
    if not item then return false end
    
    local success, itemType = pcall(function() return item.Type() end)
    if success and itemType then
        if string.sub(itemType, 1, 2) == "2H" then
            return true
        end
    end
    
    return false
end

-- Function to evaluate item against equipped items
local function EvaluateItem(item, weights)
    local results = {}
    
    if not IsWearable(item) then
        return nil, "Item is not wearable"
    end
    
    local newItemScore = CalculateScore(item, weights)
    
    if not item.CanUse() then
        newItemScore = 0
    end
    
    local is2H = IsTwoHandedWeapon(item)
    
    for i = 1, item.WornSlots() do
        local slotID = item.WornSlot(i).ID()
        
        if slotID < 23 then
            local slotName = SLOT_NAMES[slotID] or string.format('Slot %d', slotID)
            local equippedScore = 0
            
            if is2H and slotID == 13 then
                local mainHandItem = mq.TLO.Me.Inventory('mainhand')
                local offHandItem = mq.TLO.Me.Inventory('offhand')
                
                local mainScore = 0
                local offScore = 0
                
                if mainHandItem and mainHandItem.ID() then
                    if mainHandItem.CanUse() then
                        mainScore = CalculateScore(mainHandItem, weights)
                    end
                end
                
                if offHandItem and offHandItem.ID() then
                    if offHandItem.CanUse() then
                        offScore = CalculateScore(offHandItem, weights)
                    end
                end
                
                equippedScore = mainScore + offScore
                slotName = 'Main Hand + Off Hand'
            else
                local equippedItem = mq.TLO.Me.Inventory(slotID)
                
                if equippedItem and equippedItem.ID() then
                    if equippedItem.CanUse() then
                        equippedScore = CalculateScore(equippedItem, weights)
                    else
                        equippedScore = 0
                    end
                else
                    equippedScore = 0
                end
            end
            
            local improvement = 0
            if equippedScore > 0 then
                improvement = ((newItemScore - equippedScore) / equippedScore) * 100
            elseif newItemScore > 0 then
                improvement = 999
            end
            
            if newItemScore > equippedScore then
                table.insert(results, {
                    slotID = slotID,
                    slotName = slotName,
                    newScore = newItemScore,
                    equippedScore = equippedScore,
                    improvement = improvement
                })
            end
        end
    end
    
    return results
end

-- Parse bag arguments
local function parseBagArguments(args)
    if not args or args == "" then
        return nil
    end
    
    local bagList = {}
    
    if string.find(args, "-") then
        local startNum, endNum = string.match(args, "^(%d+)%-(%d+)$")
        if not startNum or not endNum then
            print("\ayInvalid range format. Use: #-# (e.g., 2-4)")
            return nil
        end
        
        startNum = tonumber(startNum)
        endNum = tonumber(endNum)
        
        if startNum >= endNum then
            print("\ayInvalid range. First number must be less than second number.")
            return nil
        end
        
        if startNum < 1 or endNum > 10 then
            print("\ayInvalid bag numbers. Must be between 1-10.")
            return nil
        end
        
        for i = startNum, endNum do
            table.insert(bagList, i)
        end
    elseif string.find(args, ",") then
        for bagStr in string.gmatch(args, "([^,]+)") do
            bagStr = bagStr:match("^%s*(.-)%s*$")
            local bagNum = tonumber(bagStr)
            if not bagNum or bagNum < 1 or bagNum > 10 then
                print(string.format("\ayInvalid bag number: %s. Must be 1-10.", bagStr))
                return nil
            end
            table.insert(bagList, bagNum)
        end
    else
        local bagNum = tonumber(args)
        if not bagNum or bagNum < 1 or bagNum > 10 then
            print("\ayInvalid bag number. Must be 1-10.")
            return nil
        end
        table.insert(bagList, bagNum)
    end
    
    -- Remove duplicates and sort
    local uniqueBags = {}
    local seen = {}
    for _, bagNum in ipairs(bagList) do
        if not seen[bagNum] then
            seen[bagNum] = true
            table.insert(uniqueBags, bagNum)
        end
    end
    table.sort(uniqueBags)
    
    return uniqueBags
end

-- Function to scan bags for upgrades
local function FindUpgrades(args)
    local playerClass = mq.TLO.Me.Class.Name()
    local weights = CLASS_WEIGHTS[playerClass] or CLASS_WEIGHTS.Default
    
    local bagList = {}
    
    if not args or args == "" then
        -- Scan all bags
        for i = 1, 10 do
            table.insert(bagList, i)
        end
    else
        bagList = parseBagArguments(args)
        if not bagList then
            return
        end
    end
    
    print('========================================')
    print(string.format('Scanning bags for upgrades (%s)', playerClass))
    print('========================================')
    
    local upgradesList = {}
    local itemsScanned = 0
    
    for _, bagNum in ipairs(bagList) do
        local slotNum = bagNum + 22
        local bag = mq.TLO.Me.Inventory(slotNum)
        
        if bag() and bag.Container() > 0 then
            local containerSize = bag.Container()
            
            for slot = 1, containerSize do
                local item = mq.TLO.Me.Inventory(slotNum).Item(slot)
                
                if item() and item.ID() then
                    itemsScanned = itemsScanned + 1
                    
                    if IsWearable(item) then
                        local results = EvaluateItem(item, weights)
                        
                        if results and #results > 0 then
                            -- Find the best upgrade slot for this item
                            local bestUpgrade = nil
                            for _, result in ipairs(results) do
                                if not bestUpgrade or result.improvement > bestUpgrade.improvement then
                                    bestUpgrade = result
                                end
                            end
                            
                            if bestUpgrade then
                                table.insert(upgradesList, {
                                    itemName = item.Name(),
                                    slotName = bestUpgrade.slotName,
                                    improvement = bestUpgrade.improvement,
                                    bagNum = bagNum,
                                    slotNum = slot
                                })
                            end
                        end
                    end
                end
            end
        end
    end
    
    print(string.format('Scanned %d items in %d bag(s)', itemsScanned, #bagList))
    print('========================================')
    
    if #upgradesList == 0 then
        print(GREEN .. 'No upgrades found.' .. WHITE)
    else
        print(string.format(GREEN .. 'Found %d upgrade(s):' .. WHITE, #upgradesList))
        print('----------------------------------------')
        
        -- Sort by improvement percentage (descending)
        table.sort(upgradesList, function(a, b) return a.improvement > b.improvement end)
        
        for _, upgrade in ipairs(upgradesList) do
            local improvementStr = ''
            if upgrade.improvement >= 999 then
                improvementStr = 'NEW/Empty'
            else
                improvementStr = string.format('+%.1f%%', upgrade.improvement)
            end
            
            print(string.format('%s%s%s -> %s%s%s (%s%s%s)',
                CYAN, upgrade.itemName, WHITE,
                YELLOW, upgrade.slotName, WHITE,
                GREEN, improvementStr, WHITE))
        end
    end
    
    print('========================================')
end

-- Original ItemScore function for DisplayItem
local function ItemScore()
    print('Scanning for open DisplayItem window...')
    
    local displayItem = nil
    local displayIndex = -1
    
    for i = 0, 10 do
        local item = mq.TLO.DisplayItem(i)
        if item and item.ID() then
            displayItem = item
            displayIndex = i
            break
        end
    end
    
    if not displayItem then
        print(RED .. 'ERROR: No DisplayItem window found.' .. WHITE)
        print('1. Right-click and inspect an item')
        print('2. Run: /itemscore')
        return
    end
    
    local playerClass = mq.TLO.Me.Class.Name()
    local weights = CLASS_WEIGHTS[playerClass] or CLASS_WEIGHTS.Default
    
    local itemName = displayItem.Name()
    
    print('========================================')
    print(string.format('Item Score Analysis for %s%s%s', YELLOW, playerClass, WHITE))
    print('========================================')
    print('Evaluating: ' .. CYAN .. itemName .. WHITE)
    
    local itemScore = CalculateScore(displayItem, weights)
    
    if not displayItem.CanUse() then
        itemScore = 0
    end
    
    print(string.format('Item Score: %s%.1f%s', GREEN, itemScore, WHITE))
    
    local results, errorMsg = EvaluateItem(displayItem, weights)
    
    if not results then
        print(RED .. errorMsg .. WHITE)
        return
    end
    
    if #results == 0 then
        print(YELLOW .. 'This item is not an upgrade for any slot.' .. WHITE)
        print('Checking all possible slots:')
        
        for i = 1, displayItem.WornSlots() do
            local slotID = displayItem.WornSlot(i).ID()
            
            if slotID < 23 then
                local slotName = SLOT_NAMES[slotID] or string.format('Slot %d', slotID)
                local equippedScore = 0
                local equippedItemName = ''
                
                local is2H = IsTwoHandedWeapon(displayItem)
                
                if is2H and slotID == 13 then
                    local mainHandItem = mq.TLO.Me.Inventory('mainhand')
                    local offHandItem = mq.TLO.Me.Inventory('offhand')
                    
                    local mainScore = 0
                    local offScore = 0
                    
                    if mainHandItem and mainHandItem.ID() then
                        if mainHandItem.CanUse() then
                            mainScore = CalculateScore(mainHandItem, weights)
                        end
                    end
                    
                    if offHandItem and offHandItem.ID() then
                        if offHandItem.CanUse() then
                            offScore = CalculateScore(offHandItem, weights)
                        end
                    end
                    
                    equippedScore = mainScore + offScore
                    local mainName = (mainHandItem and mainHandItem.ID()) and mainHandItem.Name() or 'Empty'
                    local offName = (offHandItem and offHandItem.ID()) and offHandItem.Name() or 'Empty'
                    equippedItemName = string.format('%s + %s', mainName, offName)
                    slotName = 'Main Hand + Off Hand'
                else
                    local equippedItem = mq.TLO.Me.Inventory(slotID)
                    equippedItemName = (equippedItem and equippedItem.ID()) and equippedItem.Name() or 'Empty'
                    
                    if equippedItem and equippedItem.ID() then
                        if equippedItem.CanUse() then
                            equippedScore = CalculateScore(equippedItem, weights)
                        end
                    end
                end
                
                local percentDiff = 0
                local percentColor = WHITE
                if equippedScore > 0 then
                    percentDiff = ((itemScore - equippedScore) / equippedScore) * 100
                    percentColor = (percentDiff >= 0) and GREEN or RED
                elseif itemScore > 0 then
                    percentDiff = 999
                    percentColor = GREEN
                end
                
                local percentStr = ''
                if percentDiff >= 999 then
                    percentStr = string.format('%s(NEW - empty or unusable slot)%s', GREEN, WHITE)
                elseif percentDiff >= 0 then
                    percentStr = string.format('%s(+%.1f%%)%s', percentColor, percentDiff, WHITE)
                else
                    percentStr = string.format('%s(%.1f%%)%s', percentColor, percentDiff, WHITE)
                end
                
                print(string.format('  %s%-20s%s', CYAN, slotName, WHITE))
                print(string.format('    Current: %s (Score: %.1f)', equippedItemName, equippedScore))
                print(string.format('    New:     %s%s%s (Score: %.1f) %s',
                    CYAN, itemName, WHITE, itemScore, percentStr))
            end
        end
    else
        print(GREEN .. 'This item is an upgrade for the following slots:' .. WHITE)
        
        table.sort(results, function(a, b) return a.improvement > b.improvement end)
        
        for _, result in ipairs(results) do
            local improvementStr = ''
            
            if result.improvement >= 999 then
                improvementStr = string.format('%s(NEW - empty or unusable slot)%s', GREEN, WHITE)
            else
                improvementStr = string.format('%s(+%.1f%%)%s', GREEN, result.improvement, WHITE)
            end
            
            local equippedItemName = ''
            if result.slotName == 'Main Hand + Off Hand' then
                local mainHandItem = mq.TLO.Me.Inventory('mainhand')
                local offHandItem = mq.TLO.Me.Inventory('offhand')
                local mainName = (mainHandItem and mainHandItem.ID()) and mainHandItem.Name() or 'Empty'
                local offName = (offHandItem and offHandItem.ID()) and offHandItem.Name() or 'Empty'
                equippedItemName = string.format('%s + %s', mainName, offName)
            else
                local equippedItem = mq.TLO.Me.Inventory(result.slotID)
                equippedItemName = (equippedItem and equippedItem.ID()) and equippedItem.Name() or 'Empty'
            end
            
            print(string.format('  %s%-20s%s', CYAN, result.slotName, WHITE))
            print(string.format('    Current: %s (Score: %.1f)', equippedItemName, result.equippedScore))
            print(string.format('    New:     %s%s%s (Score: %.1f) %s',
                CYAN, itemName, WHITE, result.newScore, improvementStr))
        end
    end
    
    print('========================================')
end

-- Bind Commands
mq.bind('/itemscore', function()
    ItemScore()
end)

mq.bind('/findupgrades', function(args)
    FindUpgrades(args)
end)

-- Initialization
print('\ag========================================')
print('\agItemScore Script Loaded')
print('\ag========================================')
print('\awCommands:')
print('\aw  /itemscore - Evaluate item in DisplayItem window')
print('\aw  /findupgrades - Scan all bags for upgrades')
print('\aw  /findupgrades # - Scan specific bag (1-10)')
print('\aw  /findupgrades #-# - Scan bag range (e.g., 2-4)')
print('\aw  /findupgrades #,#,# - Scan specific bags (e.g., 2,4,6)')
print('\ag========================================')

-- Main Loop
while true do
    mq.delay(1000)
end