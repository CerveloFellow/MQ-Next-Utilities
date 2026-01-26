--[[
    BagManager.lua
    
    Combined bag management and item scoring script.
    
    Commands:
        /printbag #       - Display bag contents (see MIN_BAG_NUM to MAX_BAG_NUM)
        /destroybag <spec> - Destroy items in allowed bags (see MIN_DESTROY_BAG to MAX_DESTROY_BAG)
        /sellbag <spec>   - Sell items in allowed bags (see MIN_SELL_BAG to MAX_SELL_BAG)
        /itemscore        - Evaluate item in DisplayItem window
        /augmentscore     - Compare augment in DisplayItem window
        /findupgrades     - Scan bags for equipment upgrades
        /itemdebug        - Toggle debug logging for item scoring
        
    Bag Specification Formats:
        Single bag:  5
        Multiple:    2,4,6
        Range:       2-7
        
    Note: Some bags are PROTECTED from destroy/sell operations (configured via constants).
--]]

local mq = require('mq')

-- =============================================================================
-- Debug Logging
-- =============================================================================

local DEBUG_ENABLED = false

local function DebugLog(message, ...)
    if not DEBUG_ENABLED then return end
    local formatted = string.format(message, ...)
    print(string.format('\ao[DEBUG] %s\ax', formatted))
end

local function ToggleDebug()
    DEBUG_ENABLED = not DEBUG_ENABLED
    if DEBUG_ENABLED then
        print('\agItem scoring debug logging ENABLED\ax')
        print('\aoUse /itemdebug to toggle off\ax')
    else
        print('\arItem scoring debug logging DISABLED\ax')
    end
end

-- =============================================================================
-- Constants
-- =============================================================================

-- Bag limits
local MIN_BAG_NUM = 1
local MAX_BAG_NUM = 10
local MIN_DESTROY_BAG = 1  -- Bags 9 and 10 are protected
local MAX_DESTROY_BAG = 8
local MIN_SELL_BAG = 1     -- Bags 9 and 10 are protected
local MAX_SELL_BAG = 8

-- Helper function to generate protected bags message
local function getProtectedBagsMessage()
    local protectedBags = {}
    for i = MIN_BAG_NUM, MIN_DESTROY_BAG - 1 do
        table.insert(protectedBags, tostring(i))
    end
    for i = MAX_DESTROY_BAG + 1, MAX_BAG_NUM do
        table.insert(protectedBags, tostring(i))
    end
    if #protectedBags == 0 then
        return ""
    elseif #protectedBags == 1 then
        return "Bag " .. protectedBags[1] .. " is PROTECTED"
    elseif #protectedBags == 2 then
        return "Bags " .. protectedBags[1] .. " and " .. protectedBags[2] .. " are PROTECTED"
    else
        return "Bags " .. table.concat(protectedBags, ", ", 1, #protectedBags - 1) .. ", and " .. protectedBags[#protectedBags] .. " are PROTECTED"
    end
end

-- Helper function to check if a bag is protected
local function isBagProtected(bagNum)
    return bagNum < MIN_DESTROY_BAG or bagNum > MAX_DESTROY_BAG
end

-- Helper function to print bag reference info
local function printBagReference()
    local bagsPerLine = 3
    local lineCount = 0
    local lineItems = {}
    
    for i = MIN_BAG_NUM, MAX_BAG_NUM do
        local slot = i + 22
        local protected = isBagProtected(i) and " [PROTECTED]" or ""
        table.insert(lineItems, string.format("%d=pack%d/slot%d%s", i, i, slot, protected))
        
        if #lineItems == bagsPerLine or i == MAX_BAG_NUM then
            print('\aw  ' .. table.concat(lineItems, ", "))
            lineItems = {}
        end
    end
end

-- Timing delays (ms)
local COMMAND_DELAY = 100
local DESTROY_DELAY = 500
local SELL_DELAY = 300
local MAX_CLICK_ATTEMPTS = 5
local MAX_MERCHANT_DISTANCE = 500

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

-- =============================================================================
-- Class-specific stat weights
-- =============================================================================

local CLASS_WEIGHTS = {
    Warrior = {
        AC = 10, HP = 8, Attack = 8, Haste = 6, HeroicSTR = 9, HeroicSTA = 8,
        STR = 4, STA = 4, Avoidance = 6, Shielding = 5, StunResist = 4,
        DamageShieldMitigation = 3, AGI = 3, HeroicAGI = 10, DEX = 2, HeroicDEX = 7,
        Endurance = 3, EnduranceRegen = 3, HPRegen = 4, DamageRatio = 100, DMGBonus = 8
    },
    Cleric = {
        Mana = 10, ManaRegen = 9, WIS = 8, HeroicWIS = 8, AC = 5, HP = 5,
        HealAmount = 7, SpellDamage = 3, Haste = 2, HeroicSTA = 6, STA = 3,
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
        Shielding = 3, svMagic = 3, HeroicSvMagic = 3, Clairvoyance = 6, DamageRatio = 50
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

-- =============================================================================
-- Shared Utility Functions
-- =============================================================================

local function bagNumToSlot(bagNum)
    -- Convert bag number (1-10) to inventory slot (23-32)
    return bagNum + 22
end

local function validateBagNumber(bagNum)
    local num = tonumber(bagNum)
    if not num or num < MIN_BAG_NUM or num > MAX_BAG_NUM then
        print(string.format("\ayInvalid bag number. Please use %d-%d.", MIN_BAG_NUM, MAX_BAG_NUM))
        return nil
    end
    return num
end

local function validateBagNumberForDestroy(bagNum)
    local num = tonumber(bagNum)
    if not num or num < MIN_DESTROY_BAG or num > MAX_DESTROY_BAG then
        print(string.format("\ayInvalid bag number %s. Can only destroy bags %d-%d.", tostring(bagNum), MIN_DESTROY_BAG, MAX_DESTROY_BAG))
        return nil
    end
    return num
end

local function validateBagNumberForSell(bagNum)
    local num = tonumber(bagNum)
    if not num or num < MIN_SELL_BAG or num > MAX_SELL_BAG then
        print(string.format("\ayInvalid bag number %s. Can only sell bags %d-%d.", tostring(bagNum), MIN_SELL_BAG, MAX_SELL_BAG))
        return nil
    end
    return num
end

local function getBagInfo(bagNum)
    local slotNum = bagNumToSlot(bagNum)
    local bag = mq.TLO.Me.Inventory(slotNum)
    
    if not bag() then
        print(string.format("\ayNo bag found in pack%d (slot %d)", bagNum, slotNum))
        return nil
    end
    
    local containerSize = bag.Container()
    if containerSize == 0 then
        print(string.format("\ayPack%d (slot %d) is not a container.", bagNum, slotNum))
        return nil
    end
    
    return {
        bag = bag,
        name = bag.Name(),
        size = containerSize,
        slotNum = slotNum,
        bagNum = bagNum
    }
end

local function getItemsInBag(slotNum, containerSize)
    local items = {}
    
    -- Slots in bags are 0-indexed
    for slot = 0, containerSize - 1 do
        local item = mq.TLO.Me.Inventory(slotNum).Item(slot + 1)
        if item() then
            table.insert(items, {
                slot = slot + 1,  -- Display as 1-indexed for user
                slotIndex = slot,  -- Store actual 0-indexed slot
                name = item.Name(),
                stack = item.Stack()
            })
        end
    end
    
    return items
end

local function formatItemDisplay(item)
    if item.stack > 1 then
        return string.format("\aw  Slot %d: %s (x%d)", item.slot, item.name, item.stack)
    else
        return string.format("\aw  Slot %d: %s", item.slot, item.name)
    end
end

-- Parse bag arguments into a list of bag numbers (for bag operations with validation)
local function parseBagArgumentsWithValidation(args, validationFunc)
    if not args or args == "" then
        return nil
    end
    
    local bagList = {}
    local hasInvalid = false
    
    -- Check if it's a range (contains -)
    if string.find(args, "-") then
        local startNum, endNum = string.match(args, "^(%d+)%-(%d+)$")
        if not startNum or not endNum then
            print("\ayInvalid range format. Use: #-# (e.g., 2-7)")
            return nil
        end
        
        startNum = tonumber(startNum)
        endNum = tonumber(endNum)
        
        if startNum >= endNum then
            print("\ayInvalid range. First number must be less than second number.")
            return nil
        end
        
        for i = startNum, endNum do
            local validNum = validationFunc(i)
            if validNum then
                table.insert(bagList, validNum)
            else
                hasInvalid = true
            end
        end
    -- Check if it's a comma-delimited list
    elseif string.find(args, ",") then
        for bagStr in string.gmatch(args, "([^,]+)") do
            bagStr = bagStr:match("^%s*(.-)%s*$")  -- Trim whitespace
            local validNum = validationFunc(bagStr)
            if validNum then
                table.insert(bagList, validNum)
            else
                hasInvalid = true
            end
        end
    -- Single bag number
    else
        local validNum = validationFunc(args)
        if validNum then
            table.insert(bagList, validNum)
        else
            return nil
        end
    end
    
    if hasInvalid then
        print(string.format("\ar** Note: %s and were skipped **", getProtectedBagsMessage()))
    end
    
    if #bagList == 0 then
        print("\ayNo valid bags to process.")
        return nil
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

-- Parse bag arguments for upgrade scanning (no protected bags)
local function parseBagArgumentsForUpgrades(args)
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
        
        if startNum < MIN_BAG_NUM or endNum > MAX_BAG_NUM then
            print(string.format("\ayInvalid bag numbers. Must be between %d-%d.", MIN_BAG_NUM, MAX_BAG_NUM))
            return nil
        end
        
        for i = startNum, endNum do
            table.insert(bagList, i)
        end
    elseif string.find(args, ",") then
        for bagStr in string.gmatch(args, "([^,]+)") do
            bagStr = bagStr:match("^%s*(.-)%s*$")
            local bagNum = tonumber(bagStr)
            if not bagNum or bagNum < MIN_BAG_NUM or bagNum > MAX_BAG_NUM then
                print(string.format("\ayInvalid bag number: %s. Must be %d-%d.", bagStr, MIN_BAG_NUM, MAX_BAG_NUM))
                return nil
            end
            table.insert(bagList, bagNum)
        end
    else
        local bagNum = tonumber(args)
        if not bagNum or bagNum < MIN_BAG_NUM or bagNum > MAX_BAG_NUM then
            print(string.format("\ayInvalid bag number. Must be %d-%d.", MIN_BAG_NUM, MAX_BAG_NUM))
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

local function inventoryLocationEmpty(bagNum, slot)
    local item = mq.TLO.Me.Inventory(string.format("pack%d", bagNum)).Item(slot)
    return not item.Name()
end

-- =============================================================================
-- Bag Management Functions
-- =============================================================================

local function destroySingleItem(location, maxClickAttempts)
    -- Put the item on the cursor
    mq.cmdf("/shiftkey /itemnotify %s leftmouseup", location)
    mq.delay(COMMAND_DELAY)
    
    local clickAttempts = 1
    -- If quantity window comes up, click button to close it
    while mq.TLO.Window("QuantityWnd").Open() and clickAttempts < maxClickAttempts do
        clickAttempts = clickAttempts + 1
        mq.cmdf("/notify QuantityWnd QTYW_Accept_Button leftmouseup")
        mq.delay(COMMAND_DELAY)
    end

    local attempts = 0
    while mq.TLO.Cursor.ID() ~= nil and attempts < maxClickAttempts do
        mq.cmdf("/squelch /ditem")
        mq.delay(50)
        mq.cmdf("/destroy")
        mq.delay(DESTROY_DELAY)
        attempts = attempts + 1
    end
end

local function sellSingleItem(location, maxClickAttempts)
    mq.cmdf("/itemnotify %s leftmouseup", location)
    mq.delay(COMMAND_DELAY)
    
    local itemValue = mq.TLO.Window("MerchantWnd").Child("MW_SelectedPriceLabel").Text()
    
    if mq.TLO.Window("MerchantWnd").Child("MW_Sell_Button").Enabled() and 
       mq.TLO.Window("MerchantWnd").Child("MW_SelectedPriceLabel").Text() ~= "0c" then
        mq.cmdf("/shiftkey /notify MerchantWnd MW_Sell_Button leftmouseup")
        mq.delay(COMMAND_DELAY)
        
        local clickAttempts = 1
        while mq.TLO.Window("QuantityWnd").Open() and clickAttempts < maxClickAttempts do
            clickAttempts = clickAttempts + 1
            mq.cmdf("/notify QuantityWnd QTYW_Accept_Button leftmouseup")
            mq.delay(COMMAND_DELAY)
        end
    end
    
    return itemValue
end

local function openMerchant()
    local merchant = mq.TLO.Spawn(string.format("Merchant radius %s los", MAX_MERCHANT_DISTANCE))
    local maxRetries = 8
    local attempt = 0

    if merchant.ID() == nil then
        print(string.format("\ayThere are no merchants within line of sight or %s units distance from you.", MAX_MERCHANT_DISTANCE))
        return false
    end

    if mq.TLO.Me.AutoFire() then
        mq.cmdf("/autofire")
    end

    if not mq.TLO.Window("MerchantWnd").Open() then
        while not mq.TLO.Window("MerchantWnd").Open() and attempt < maxRetries do
            mq.cmdf("/target id %d", merchant.ID())
            mq.delay(COMMAND_DELAY)
            mq.cmdf("/click right target")
            mq.delay(COMMAND_DELAY)
            attempt = attempt + 1
        end
        if attempt >= maxRetries and not mq.TLO.Window("MerchantWnd").Open() then
            return false
        end
    end

    return true
end

local function closeMerchant()
    local attempt = 0
    local maxRetries = 8

    while mq.TLO.Window("MerchantWnd").Open() and attempt < maxRetries do
        mq.cmdf("/notify MerchantWnd MW_Done_Button leftmouseup")
        mq.delay(COMMAND_DELAY)
        attempt = attempt + 1
    end
    
    if attempt >= maxRetries then
        return false
    end
    
    return true
end

local function printBag(bagNum)
    bagNum = validateBagNumber(bagNum)
    if not bagNum then return end
    
    local bagInfo = getBagInfo(bagNum)
    if not bagInfo then return end
    
    local items = getItemsInBag(bagInfo.slotNum, bagInfo.size)
    
    print("\ag========================================")
    print(string.format("\agContents of pack%d (slot %d - %s):", bagInfo.bagNum, bagInfo.slotNum, bagInfo.name))
    print("\ag========================================")
    
    if #items == 0 then
        print("\aw  (Empty)")
    else
        for _, item in ipairs(items) do
            print(formatItemDisplay(item))
        end
    end
    
    print("\ag========================================")
    print(string.format("\agTotal items: %d / %d slots", #items, bagInfo.size))
    print("\ag========================================")
end

local function destroySingleBag(bagNum)
    local bagInfo = getBagInfo(bagNum)
    if not bagInfo then return 0 end
    
    local items = getItemsInBag(bagInfo.slotNum, bagInfo.size)
    
    print(string.format("\agDestroying pack%d (slot %d - %s):", bagInfo.bagNum, bagInfo.slotNum, bagInfo.name))
    
    if #items == 0 then
        print("\aw  (Empty)")
    else
        for _, item in ipairs(items) do
            local location = string.format("in pack%d %d", bagNum, item.slot)
            print(string.format("\aw  Destroying: %s", item.name))
            destroySingleItem(location, 3)
        end
    end
    
    print(string.format("\agDestroyed %d items from pack%d", #items, bagNum))
    return #items
end

local function sellSingleBag(bagNum)
    local bagInfo = getBagInfo(bagNum)
    if not bagInfo then return 0 end
    
    local items = getItemsInBag(bagInfo.slotNum, bagInfo.size)
    
    print(string.format("\agSelling pack%d (slot %d - %s):", bagInfo.bagNum, bagInfo.slotNum, bagInfo.name))
    
    if #items == 0 then
        print("\aw  (Empty)")
        return 0
    end
    
    local itemsSold = 0
    
    for _, item in ipairs(items) do
        local location = string.format("in pack%d %d", bagNum, item.slot)
        print(string.format("\aw  Selling: %s", item.name))
        
        local attempts = 0
        while not inventoryLocationEmpty(bagNum, item.slot) and attempts < 5 do
            local merchantOffer = sellSingleItem(location, 3)
            attempts = attempts + 1
            
            if string.sub(merchantOffer, 1, 2) == "0c" then
                print(string.format("\ay    Merchant won't buy %s (0 copper offer)", item.name))
                break
            else
                -- Wait for the sale to complete
                mq.delay("5s", function() return inventoryLocationEmpty(bagNum, item.slot) end)
                if inventoryLocationEmpty(bagNum, item.slot) then
                    itemsSold = itemsSold + 1
                end
            end
        end
    end
    
    print(string.format("\agSold %d items from pack%d", itemsSold, bagNum))
    return itemsSold
end

local function destroyBag(args)
    local bagList = parseBagArgumentsWithValidation(args, validateBagNumberForDestroy)
    if not bagList then return end
    
    print("\ag========================================")
    print(string.format("\agDestroying %d bag(s):", #bagList))
    local bagListStr = table.concat(bagList, ", ")
    print(string.format("\agBags: %s", bagListStr))
    print("\ag========================================")
    
    local totalItems = 0
    for _, bagNum in ipairs(bagList) do
        local itemsDestroyed = destroySingleBag(bagNum)
        totalItems = totalItems + itemsDestroyed
        print("\ag----------------------------------------")
    end
    
    print("\ag========================================")
    print(string.format("\agSummary: Destroyed %d total items from %d bag(s)", totalItems, #bagList))
    print("\ag========================================")
end

local function sellBag(args)
    local bagList = parseBagArgumentsWithValidation(args, validateBagNumberForSell)
    if not bagList then return end
    
    -- Open merchant window
    if not openMerchant() then
        print("\arError: Unable to open trade window with merchant.")
        return
    end
    
    print("\ag========================================")
    print(string.format("\agSelling %d bag(s):", #bagList))
    local bagListStr = table.concat(bagList, ", ")
    print(string.format("\agBags: %s", bagListStr))
    print("\ag========================================")
    
    local totalItems = 0
    for _, bagNum in ipairs(bagList) do
        if mq.TLO.Window("MerchantWnd").Open() then
            local itemsSold = sellSingleBag(bagNum)
            totalItems = totalItems + itemsSold
            print("\ag----------------------------------------")
        else
            print("\arMerchant window closed unexpectedly!")
            break
        end
    end
    
    -- Close merchant window
    closeMerchant()
    
    print("\ag========================================")
    print(string.format("\agSummary: Sold %d total items from %d bag(s)", totalItems, #bagList))
    print("\ag========================================")
end

-- =============================================================================
-- Item Scoring Functions
-- =============================================================================

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
local function CalculateScore(item, weights, debugLabel)
    if not item then return 0 end
    
    local itemName = item.Name() or "Unknown"
    debugLabel = debugLabel or itemName
    
    local score = 0
    local debugContributions = {}
    
    for statName, weight in pairs(weights) do
        if statName ~= 'DamageRatio' then
            local value = GetStatValue(item, statName)
            if value > 0 then
                local contribution = value * weight
                score = score + contribution
                table.insert(debugContributions, string.format('%s: %d * %d = %.1f', statName, value, weight, contribution))
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
        table.insert(debugContributions, string.format('DmgRatio: %.2f * %d = %.1f', damageRatio, damageRatioWeight, ratioScore))
    end
    
    DebugLog('CalculateScore [%s]: %.1f', debugLabel, score)
    if DEBUG_ENABLED and #debugContributions > 0 then
        for _, contrib in ipairs(debugContributions) do
            DebugLog('  %s', contrib)
        end
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

-- Function to check if item is an augmentation
local function IsAugmentation(item)
    if not item then return false end
    
    local success, itemType = pcall(function() return item.Type() end)
    if success and itemType then
        return itemType == "Augmentation"
    end
    
    return false
end

-- Function to check if item is lore and already owned
local function IsLoreAndOwned(item)
    if not item then return false, false end
    
    -- Check if item is lore
    local loreSuccess, isLore = pcall(function() return item.Lore() end)
    if not loreSuccess or not isLore then
        return false, false
    end
    
    -- Item is lore, now check if we already have one
    -- FindItem searches inventory, bank, and equipped items
    local itemName = item.Name()
    local findSuccess, foundItem = pcall(function() return mq.TLO.FindItem(itemName)() end)
    
    if findSuccess and foundItem then
        -- We found the item somewhere, meaning we already own one
        return true, true
    end
    
    return true, false  -- Is lore, but don't own one yet
end

-- Function to check if augment type is compatible with slot type
-- augType is a bitmask, slotType is the slot's accepted type number
local function IsAugCompatible(augType, slotType)
    if not augType or not slotType or slotType == 0 then
        return false
    end
    
    -- slotType is the type number (e.g., 7)
    -- augType is the bitmask from the augment
    -- Bit positions: Type 1 = bit 0, Type 2 = bit 1, etc.
    local slotBit = bit32.lshift(1, slotType - 1)
    return bit32.band(augType, slotBit) > 0
end

-- Function to convert augment type bitmask to readable string
local function GetAugTypeString(augType)
    if not augType or augType == 0 then
        return "None"
    end
    
    local types = {}
    for i = 1, 25 do
        -- Skip Type 20 - not a valid player-usable augment slot
        if i ~= 20 then
            local bit = bit32.lshift(1, i - 1)
            if bit32.band(augType, bit) > 0 then
                table.insert(types, tostring(i))
            end
        end
    end
    
    if #types == 0 then
        return "None"
    end
    
    return table.concat(types, ", ")
end

-- =============================================================================
-- Augment Slot Comparison Functions
-- =============================================================================

-- Default average aug values by slot type (used as fallback)
local AVG_AUG_VALUE_BY_TYPE = {
    [1] = 50,    -- Type 1
    [2] = 50,    -- Type 2
    [3] = 75,    -- Type 3
    [4] = 75,    -- Type 4
    [5] = 100,   -- Type 5 (weapon)
    [6] = 100,   -- Type 6
    [7] = 150,   -- Type 7 (common)
    [8] = 175,   -- Type 8 (common)
    [9] = 75,    -- Type 9
    [10] = 75,   -- Type 10
    [11] = 100,  -- Type 11
    [12] = 100,  -- Type 12
    [13] = 125,  -- Type 13
    [14] = 125,  -- Type 14
    [15] = 125,  -- Type 15
    [16] = 125,  -- Type 16
    [17] = 125,  -- Type 17
    [18] = 150,  -- Type 18
    [19] = 150,  -- Type 19
    [21] = 200,  -- Type 21 (usually high value)
}

-- Get all augment slot types from an item
-- Returns table of {slotNum, slotType}
local function GetAugSlotInfo(item)
    local slots = {}
    if not item then return slots end
    
    local itemName = item.Name() or "Unknown"
    
    for i = 1, 6 do  -- EQ items have max 6 aug slots
        local augSlot = item.AugSlot(i)
        if augSlot then
            local slotType = augSlot.Type()
            -- Skip Type 20 - not a valid player-usable augment slot
            if slotType and slotType > 0 and slotType ~= 20 then
                table.insert(slots, {
                    slotNum = i,
                    slotType = slotType
                })
            end
        end
    end
    
    if DEBUG_ENABLED then
        local slotTypes = {}
        for _, slot in ipairs(slots) do
            table.insert(slotTypes, string.format('Slot%d=Type%d', slot.slotNum, slot.slotType))
        end
        DebugLog('GetAugSlotInfo [%s]: %d slots - %s', itemName, #slots, table.concat(slotTypes, ', '))
    end
    
    return slots
end

-- Get augment info from filled slots on an item
-- Returns table with aug details and scores
local function GetEquippedAugments(item, weights)
    local augments = {}
    if not item then return augments end
    
    local itemName = item.Name() or "Unknown"
    
    for i = 1, 6 do
        local success, aug = pcall(function() return item.Item(i) end)
        if success and aug then
            local idSuccess, augID = pcall(function() return aug.ID() end)
            if idSuccess and augID and augID > 0 then
                local augScore = 0
                local canUseSuccess, canUse = pcall(function() return aug.CanUse() end)
                if canUseSuccess and canUse then
                    augScore = CalculateScore(aug, weights, string.format('Aug: %s', aug.Name() or 'Unknown'))
                end
                
                local augType = GetStatValue(aug, 'AugType')
                local augName = aug.Name() or "Unknown"
                
                table.insert(augments, {
                    slotNum = i,
                    name = augName,
                    score = augScore,
                    augType = augType,  -- Bitmask of compatible slot types
                    item = aug
                })
                
                DebugLog('GetEquippedAugments [%s] Slot%d: %s (Score: %.1f, AugType: %d)', 
                    itemName, i, augName, augScore, augType)
            end
        end
    end
    
    DebugLog('GetEquippedAugments [%s]: Found %d augments', itemName, #augments)
    return augments
end

-- Scan all equipped items for augments compatible with a slot type
-- Returns average score of compatible augs, or default if none found
local function GetAverageEquippedAugValue(slotType, weights)
    local compatibleScores = {}
    
    -- Scan all equipment slots (0-22)
    for slotID = 0, 22 do
        local equippedItem = mq.TLO.Me.Inventory(slotID)
        if equippedItem and equippedItem.ID() then
            -- Check each aug slot on this item
            for i = 1, 6 do
                local success, aug = pcall(function() return equippedItem.Item(i) end)
                if success and aug then
                    local idSuccess, augID = pcall(function() return aug.ID() end)
                    if idSuccess and augID and augID > 0 then
                        local augType = GetStatValue(aug, 'AugType')
                        if IsAugCompatible(augType, slotType) then
                            local canUseSuccess, canUse = pcall(function() return aug.CanUse() end)
                            if canUseSuccess and canUse then
                                local augScore = CalculateScore(aug, weights)
                                if augScore > 0 then
                                    table.insert(compatibleScores, augScore)
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    
    if #compatibleScores > 0 then
        local sum = 0
        for _, score in ipairs(compatibleScores) do
            sum = sum + score
        end
        return sum / #compatibleScores, true  -- Return average and "found" flag
    end
    
    -- Fall back to static default
    return AVG_AUG_VALUE_BY_TYPE[slotType] or 100, false
end

-- Find optimal assignment of augments from equipped item to new item's slots
-- Uses greedy algorithm: assign highest scoring augs first
-- Returns: { assigned = {}, orphaned = {}, unfilledSlots = {} }
local function OptimalAugAssignment(augments, targetSlots)
    local result = {
        assigned = {},      -- Augs that can transfer
        orphaned = {},      -- Augs that can't transfer
        unfilledSlots = {}  -- Target slots with no aug assigned
    }
    
    DebugLog('OptimalAugAssignment: %d augments -> %d target slots', #augments, #targetSlots)
    
    -- Sort augments by score descending (assign best augs first)
    local sortedAugs = {}
    for _, aug in ipairs(augments) do
        table.insert(sortedAugs, aug)
    end
    table.sort(sortedAugs, function(a, b) return a.score > b.score end)
    
    if DEBUG_ENABLED then
        DebugLog('  Augments sorted by score:')
        for i, aug in ipairs(sortedAugs) do
            DebugLog('    %d. %s (Score: %.1f, AugType: %d)', i, aug.name, aug.score, aug.augType)
        end
    end
    
    -- Track which target slots are still available
    local availableSlots = {}
    for _, slot in ipairs(targetSlots) do
        availableSlots[slot.slotNum] = slot.slotType
    end
    
    if DEBUG_ENABLED then
        DebugLog('  Target slots available:')
        for slotNum, slotType in pairs(availableSlots) do
            DebugLog('    Slot%d = Type%d', slotNum, slotType)
        end
    end
    
    -- Assign each aug to best available slot
    for _, aug in ipairs(sortedAugs) do
        local assigned = false
        for slotNum, slotType in pairs(availableSlots) do
            if IsAugCompatible(aug.augType, slotType) then
                table.insert(result.assigned, {
                    aug = aug,
                    targetSlotNum = slotNum,
                    targetSlotType = slotType
                })
                DebugLog('  ASSIGNED: %s (%.1f) -> Slot%d (Type%d)', aug.name, aug.score, slotNum, slotType)
                availableSlots[slotNum] = nil  -- Slot is now taken
                assigned = true
                break
            end
        end
        
        if not assigned then
            table.insert(result.orphaned, aug)
            DebugLog('  ORPHANED: %s (%.1f, AugType: %d) - no compatible slot', aug.name, aug.score, aug.augType)
        end
    end
    
    -- Record unfilled slots
    for slotNum, slotType in pairs(availableSlots) do
        table.insert(result.unfilledSlots, {
            slotNum = slotNum,
            slotType = slotType
        })
        DebugLog('  UNFILLED: Slot%d (Type%d) - no aug assigned', slotNum, slotType)
    end
    
    DebugLog('OptimalAugAssignment Result: %d assigned, %d orphaned, %d unfilled', 
        #result.assigned, #result.orphaned, #result.unfilledSlots)
    
    return result
end

-- Check if aug slot comparison can be skipped (same count and same types)
local function CanSkipAugComparison(equippedSlots, newSlots)
    -- Different count = can't skip
    if #equippedSlots ~= #newSlots then
        return false
    end
    
    -- Same count - check if all types match (considering duplicates)
    local equippedTypes = {}
    for _, slot in ipairs(equippedSlots) do
        equippedTypes[slot.slotType] = (equippedTypes[slot.slotType] or 0) + 1
    end
    
    local newTypes = {}
    for _, slot in ipairs(newSlots) do
        newTypes[slot.slotType] = (newTypes[slot.slotType] or 0) + 1
    end
    
    -- Check equipped types exist in new with same count
    for slotType, count in pairs(equippedTypes) do
        if newTypes[slotType] ~= count then
            return false
        end
    end
    
    -- Check new types exist in equipped with same count
    for slotType, count in pairs(newTypes) do
        if equippedTypes[slotType] ~= count then
            return false
        end
    end
    
    return true
end

-- Check if new item has all of equipped item's slot types (and possibly more)
local function NewItemHasAllEquippedSlotTypes(equippedSlots, newSlots)
    -- Build a count of available slot types on new item
    local newTypeCounts = {}
    for _, slot in ipairs(newSlots) do
        newTypeCounts[slot.slotType] = (newTypeCounts[slot.slotType] or 0) + 1
    end
    
    -- Check each equipped slot type has a match in new item
    for _, eqSlot in ipairs(equippedSlots) do
        if not newTypeCounts[eqSlot.slotType] or newTypeCounts[eqSlot.slotType] <= 0 then
            return false
        end
        -- Decrement to handle multiple slots of same type
        newTypeCounts[eqSlot.slotType] = newTypeCounts[eqSlot.slotType] - 1
    end
    
    return true
end

-- Compare equipped item (with augs) vs new item
-- Returns detailed comparison info
local function CompareItemsWithAugments(equippedItem, newItem, weights)
    local equippedName = (equippedItem and equippedItem.ID()) and equippedItem.Name() or "Empty"
    local newName = newItem.Name() or "Unknown"
    
    DebugLog('========== CompareItemsWithAugments ==========')
    DebugLog('Equipped: %s', equippedName)
    DebugLog('New Item: %s', newName)
    
    local result = {
        equippedBaseScore = 0,
        equippedAugScore = 0,
        equippedTotalScore = 0,
        newBaseScore = 0,
        newTransferredAugScore = 0,
        newPotentialAugScore = 0,
        newTotalScore = 0,
        orphanedAugs = {},
        transferredAugs = {},
        unfilledSlots = {},
        comparisonType = "base_only",  -- "base_only" or "with_augments"
        equippedSlotCount = 0,
        newSlotCount = 0
    }
    
    -- Get base scores
    if equippedItem and equippedItem.ID() then
        local canUseSuccess, canUse = pcall(function() return equippedItem.CanUse() end)
        if canUseSuccess and canUse then
            result.equippedBaseScore = CalculateScore(equippedItem, weights, 'Equipped: ' .. equippedName)
        else
            DebugLog('Equipped item CanUse = false, base score = 0')
        end
    else
        DebugLog('No equipped item, base score = 0')
    end
    
    local canUseNew, canUseNewResult = pcall(function() return newItem.CanUse() end)
    if canUseNew and canUseNewResult then
        result.newBaseScore = CalculateScore(newItem, weights, 'New: ' .. newName)
    else
        DebugLog('New item CanUse = false, base score = 0')
    end
    
    DebugLog('Base Scores: Equipped=%.1f, New=%.1f', result.equippedBaseScore, result.newBaseScore)
    
    -- Get slot info
    local equippedSlots = {}
    local equippedAugs = {}
    if equippedItem and equippedItem.ID() then
        equippedSlots = GetAugSlotInfo(equippedItem)
        equippedAugs = GetEquippedAugments(equippedItem, weights)
    end
    local newSlots = GetAugSlotInfo(newItem)
    
    result.equippedSlotCount = #equippedSlots
    result.newSlotCount = #newSlots
    
    DebugLog('Slot Counts: Equipped=%d, New=%d', #equippedSlots, #newSlots)
    
    -- Determine if we can skip augment comparison
    local canSkip = false
    local skipReason = ""
    
    -- Scenario 1: Same count and same types
    if CanSkipAugComparison(equippedSlots, newSlots) then
        canSkip = true
        skipReason = "Same slot count and types"
    -- Scenario 3: Equipped has fewer slots, all types exist on new item
    elseif #equippedSlots < #newSlots and NewItemHasAllEquippedSlotTypes(equippedSlots, newSlots) then
        canSkip = true
        skipReason = "New item has all equipped slot types (and more)"
    end
    
    if canSkip then
        -- Simple comparison - base scores only
        result.comparisonType = "base_only"
        result.equippedTotalScore = result.equippedBaseScore
        result.newTotalScore = result.newBaseScore
        DebugLog('Comparison Type: base_only (%s)', skipReason)
        DebugLog('Final Scores: Equipped=%.1f, New=%.1f', result.equippedTotalScore, result.newTotalScore)
    else
        -- Full augment comparison needed
        result.comparisonType = "with_augments"
        DebugLog('Comparison Type: with_augments (aug slots differ)')
        
        -- Calculate equipped total with augs
        for _, aug in ipairs(equippedAugs) do
            result.equippedAugScore = result.equippedAugScore + aug.score
        end
        result.equippedTotalScore = result.equippedBaseScore + result.equippedAugScore
        
        DebugLog('Equipped Total: Base %.1f + Augs %.1f = %.1f', 
            result.equippedBaseScore, result.equippedAugScore, result.equippedTotalScore)
        
        -- Find optimal assignment to new item
        local assignment = OptimalAugAssignment(equippedAugs, newSlots)
        
        -- Calculate transferred aug score
        for _, assigned in ipairs(assignment.assigned) do
            result.newTransferredAugScore = result.newTransferredAugScore + assigned.aug.score
            table.insert(result.transferredAugs, assigned.aug)
        end
        
        -- Calculate potential value for unfilled slots
        for _, unfilled in ipairs(assignment.unfilledSlots) do
            local potentialValue, fromEquipped = GetAverageEquippedAugValue(unfilled.slotType, weights)
            result.newPotentialAugScore = result.newPotentialAugScore + potentialValue
            table.insert(result.unfilledSlots, {
                slotNum = unfilled.slotNum,
                slotType = unfilled.slotType,
                potentialValue = potentialValue,
                fromEquippedAvg = fromEquipped
            })
            DebugLog('Unfilled Slot%d (Type%d): Potential=%.1f (fromEquipped=%s)', 
                unfilled.slotNum, unfilled.slotType, potentialValue, tostring(fromEquipped))
        end
        
        -- Record orphaned augs
        for _, orphan in ipairs(assignment.orphaned) do
            table.insert(result.orphanedAugs, orphan)
        end
        
        result.newTotalScore = result.newBaseScore + result.newTransferredAugScore + result.newPotentialAugScore
        
        DebugLog('New Total: Base %.1f + Transferred %.1f + Potential %.1f = %.1f', 
            result.newBaseScore, result.newTransferredAugScore, result.newPotentialAugScore, result.newTotalScore)
    end
    
    local isUpgrade = result.newTotalScore > result.equippedTotalScore
    local diff = result.newTotalScore - result.equippedTotalScore
    DebugLog('RESULT: New (%.1f) vs Equipped (%.1f) = %s%.1f -> %s', 
        result.newTotalScore, result.equippedTotalScore,
        diff >= 0 and '+' or '', diff,
        isUpgrade and 'UPGRADE' or 'NOT UPGRADE')
    DebugLog('==========================================')
    
    return result
end

-- =============================================================================
-- End Augment Slot Comparison Functions
-- =============================================================================

-- Function to check if augment can be placed in a specific equipment slot
local function CanAugGoInEquipSlot(augment, equipSlotID)
    if not augment then return false end
    
    local wornSlots = augment.WornSlots()
    if not wornSlots or wornSlots == 0 then
        return false
    end
    
    for i = 1, wornSlots do
        local slotID = augment.WornSlot(i).ID()
        if slotID == equipSlotID then
            return true
        end
    end
    
    return false
end

-- Function to evaluate augment against all equipped item augment slots
-- skipLoreCheck: if true, skip the lore item check (used by FindUpgrades since items are already owned)
local function EvaluateAugment(augment, weights, skipLoreCheck)
    local results = {}
    
    if not IsAugmentation(augment) then
        return nil, "Item is not an augmentation"
    end
    
    -- Check if augment is lore and already owned (only for DisplayItem checks)
    if not skipLoreCheck then
        local isLore, alreadyOwned = IsLoreAndOwned(augment)
        if isLore and alreadyOwned then
            return nil, "Augment is LORE and you already have one"
        end
    end
    
    local augScore = CalculateScore(augment, weights)
    
    if not augment.CanUse() then
        augScore = 0
    end
    
    local augType = GetStatValue(augment, 'AugType')
    
    if augType == 0 then
        return nil, "Could not determine augment type"
    end
    
    -- Iterate through all equipped slots (0-22)
    for slotID = 0, 22 do
        local equippedItem = mq.TLO.Me.Inventory(slotID)
        
        if equippedItem and equippedItem.ID() then
            -- First check if the augment can even go in this equipment slot
            if CanAugGoInEquipSlot(augment, slotID) then
                local itemName = equippedItem.Name()
                local slotName = SLOT_NAMES[slotID] or string.format('Slot %d', slotID)
                
                -- Check each augment slot on this item (1-6)
                for augSlotNum = 1, 6 do
                    local augSlot = equippedItem.AugSlot(augSlotNum)
                    
                    if augSlot then
                        local slotType = augSlot.Type()
                        
                        -- Skip Type 20 slots - these are not valid player-usable augment slots
                        if slotType and slotType > 0 and slotType ~= 20 and IsAugCompatible(augType, slotType) then
                            -- This slot is compatible, check what's in it
                            local currentAugScore = 1  -- Default for empty slot
                            local currentAugName = "Empty"
                        
                            -- Check if there's actually an augment in this slot
                            -- Access augment via equippedItem.Item(slotNum) which returns the aug in that slot
                            local hasAug = false
                            local currentAug = nil
                            
                            -- Try to get the augment from the item's aug slot
                            local success, aug = pcall(function() return equippedItem.Item(augSlotNum) end)
                            
                            if success and aug then
                                local idSuccess, augID = pcall(function() return aug.ID() end)
                                if idSuccess and augID and augID > 0 then
                                    currentAug = aug
                                    hasAug = true
                                end
                            end
                        
                            if hasAug and currentAug then
                                local success, name = pcall(function() return currentAug.Name() end)
                                if success and name then
                                    currentAugName = name
                                end
                            
                                local canUseSuccess, canUse = pcall(function() return currentAug.CanUse() end)
                                if canUseSuccess and canUse then
                                    currentAugScore = CalculateScore(currentAug, weights)
                                end
                                -- If current aug scores 0, treat as 1 to avoid division issues
                                if currentAugScore <= 0 then
                                    currentAugScore = 1
                                end
                            end
                        
                            local improvement = ((augScore - currentAugScore) / currentAugScore) * 100
                        
                            table.insert(results, {
                                equipSlotID = slotID,
                                equipSlotName = slotName,
                                equipItemName = itemName,
                                augSlotNum = augSlotNum,
                                augSlotType = slotType,
                                currentAugName = currentAugName,
                                currentAugScore = currentAugScore,
                                newAugScore = augScore,
                                improvement = improvement,
                                isUpgrade = augScore > currentAugScore
                            })
                        end
                    end
                end
            end
        end
    end
    
    return results
end

-- Function to evaluate item against equipped items
-- skipLoreCheck: if true, skip the lore item check (used by FindUpgrades since items are already owned)
local function EvaluateItem(item, weights, skipLoreCheck)
    local results = {}
    
    if not IsWearable(item) then
        return nil, "Item is not wearable"
    end
    
    -- Check if item is lore and already owned (only for DisplayItem checks)
    if not skipLoreCheck then
        local isLore, alreadyOwned = IsLoreAndOwned(item)
        if isLore and alreadyOwned then
            return nil, "Item is LORE and you already have one"
        end
    end
    
    local newItemBaseScore = CalculateScore(item, weights)
    
    if not item.CanUse() then
        newItemBaseScore = 0
    end
    
    local is2H = IsTwoHandedWeapon(item)
    
    for i = 1, item.WornSlots() do
        local slotID = item.WornSlot(i).ID()
        
        if slotID < 23 then
            local slotName = SLOT_NAMES[slotID] or string.format('Slot %d', slotID)
            
            if is2H and slotID == 13 then
                -- Special handling for 2H weapons - compare against main + off hand combined
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
                
                local equippedScore = mainScore + offScore
                slotName = 'Main Hand + Off Hand'
                
                -- For 2H weapons, we use simple base score comparison
                -- (augment transfer from two items to one is too complex)
                local improvement = 0
                if equippedScore > 0 then
                    improvement = ((newItemBaseScore - equippedScore) / equippedScore) * 100
                elseif newItemBaseScore > 0 then
                    improvement = 999
                end
                
                if newItemBaseScore > equippedScore then
                    table.insert(results, {
                        slotID = slotID,
                        slotName = slotName,
                        newScore = newItemBaseScore,
                        equippedScore = equippedScore,
                        improvement = improvement,
                        -- No augment comparison data for 2H
                        comparisonType = "base_only",
                        augComparison = nil
                    })
                end
            else
                -- Standard slot - use full augment comparison
                local equippedItem = mq.TLO.Me.Inventory(slotID)
                
                -- Run the augment-aware comparison
                local comparison = CompareItemsWithAugments(equippedItem, item, weights)
                
                local improvement = 0
                if comparison.equippedTotalScore > 0 then
                    improvement = ((comparison.newTotalScore - comparison.equippedTotalScore) / comparison.equippedTotalScore) * 100
                elseif comparison.newTotalScore > 0 then
                    improvement = 999
                end
                
                if comparison.newTotalScore > comparison.equippedTotalScore then
                    table.insert(results, {
                        slotID = slotID,
                        slotName = slotName,
                        newScore = comparison.newTotalScore,
                        equippedScore = comparison.equippedTotalScore,
                        improvement = improvement,
                        comparisonType = comparison.comparisonType,
                        augComparison = comparison
                    })
                end
            end
        end
    end
    
    return results
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
        bagList = parseBagArgumentsForUpgrades(args)
        if not bagList then
            return
        end
    end
    
    print('========================================')
    print(string.format('Scanning bags for upgrades (%s)', playerClass))
    print('========================================')
    
    local upgradesList = {}
    local itemsScanned = 0
    local augmentsScanned = 0
    
    for _, bagNum in ipairs(bagList) do
        local slotNum = bagNum + 22
        local bag = mq.TLO.Me.Inventory(slotNum)
        
        if bag() and bag.Container() > 0 then
            local containerSize = bag.Container()
            
            for slot = 1, containerSize do
                local item = mq.TLO.Me.Inventory(slotNum).Item(slot)
                
                if item() and item.ID() then
                    -- Check if it's an augment or a regular item
                    if IsAugmentation(item) then
                        augmentsScanned = augmentsScanned + 1
                        
                        local results = EvaluateAugment(item, weights, true)
                        
                        if results and #results > 0 then
                            -- Find the best upgrade slot for this augment
                            local bestUpgrade = nil
                            for _, result in ipairs(results) do
                                if result.isUpgrade then
                                    if not bestUpgrade or result.improvement > bestUpgrade.improvement then
                                        bestUpgrade = result
                                    end
                                end
                            end
                            
                            if bestUpgrade then
                                -- Format slot name as "EquipSlot - Aug Slot #"
                                local augSlotName = string.format('%s - Aug %d', 
                                    bestUpgrade.equipSlotName, bestUpgrade.augSlotNum)
                                
                                table.insert(upgradesList, {
                                    itemName = item.Name(),
                                    slotName = augSlotName,
                                    improvement = bestUpgrade.improvement,
                                    bagNum = bagNum,
                                    slotNum = slot,
                                    isAugment = true
                                })
                            end
                        end
                    elseif IsWearable(item) then
                        itemsScanned = itemsScanned + 1
                        
                        local results = EvaluateItem(item, weights, true)
                        
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
                                    slotNum = slot,
                                    isAugment = false
                                })
                            end
                        end
                    end
                end
            end
        end
    end
    
    print(string.format('Scanned %d items, %d augments in %d bag(s)', itemsScanned, augmentsScanned, #bagList))
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
    
    print(string.format('Base Item Score: %s%.1f%s', GREEN, itemScore, WHITE))
    
    -- Show aug slot info for the new item
    local newItemSlots = GetAugSlotInfo(displayItem)
    if #newItemSlots > 0 then
        local slotTypes = {}
        for _, slot in ipairs(newItemSlots) do
            table.insert(slotTypes, tostring(slot.slotType))
        end
        print(string.format('Augment Slots: %s%d%s (Types: %s)', YELLOW, #newItemSlots, WHITE, table.concat(slotTypes, ", ")))
    else
        print(string.format('Augment Slots: %s0%s', YELLOW, WHITE))
    end
    
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
                local is2H = IsTwoHandedWeapon(displayItem)
                
                if is2H and slotID == 13 then
                    -- 2H weapon - simple comparison
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
                    
                    local equippedScore = mainScore + offScore
                    local mainName = (mainHandItem and mainHandItem.ID()) and mainHandItem.Name() or 'Empty'
                    local offName = (offHandItem and offHandItem.ID()) and offHandItem.Name() or 'Empty'
                    local equippedItemName = string.format('%s + %s', mainName, offName)
                    slotName = 'Main Hand + Off Hand'
                    
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
                        percentStr = string.format('%s(NEW - empty slot)%s', GREEN, WHITE)
                    elseif percentDiff >= 0 then
                        percentStr = string.format('%s(+%.1f%%)%s', percentColor, percentDiff, WHITE)
                    else
                        percentStr = string.format('%s(%.1f%%)%s', percentColor, percentDiff, WHITE)
                    end
                    
                    print(string.format('  %s%-20s%s', CYAN, slotName, WHITE))
                    print(string.format('    Current: %s (Score: %.1f)', equippedItemName, equippedScore))
                    print(string.format('    New:     %s%s%s (Score: %.1f) %s',
                        CYAN, itemName, WHITE, itemScore, percentStr))
                else
                    -- Standard slot - use augment comparison
                    local equippedItem = mq.TLO.Me.Inventory(slotID)
                    local equippedItemName = (equippedItem and equippedItem.ID()) and equippedItem.Name() or 'Empty'
                    
                    local comparison = CompareItemsWithAugments(equippedItem, displayItem, weights)
                    
                    local percentDiff = 0
                    local percentColor = WHITE
                    if comparison.equippedTotalScore > 0 then
                        percentDiff = ((comparison.newTotalScore - comparison.equippedTotalScore) / comparison.equippedTotalScore) * 100
                        percentColor = (percentDiff >= 0) and GREEN or RED
                    elseif comparison.newTotalScore > 0 then
                        percentDiff = 999
                        percentColor = GREEN
                    end
                    
                    local percentStr = ''
                    if percentDiff >= 999 then
                        percentStr = string.format('%s(NEW - empty slot)%s', GREEN, WHITE)
                    elseif percentDiff >= 0 then
                        percentStr = string.format('%s(+%.1f%%)%s', percentColor, percentDiff, WHITE)
                    else
                        percentStr = string.format('%s(%.1f%%)%s', percentColor, percentDiff, WHITE)
                    end
                    
                    print(string.format('  %s%-20s%s [%s]', CYAN, slotName, WHITE, comparison.comparisonType))
                    
                    -- Display equipped item score breakdown
                    if comparison.comparisonType == "with_augments" and comparison.equippedAugScore > 0 then
                        print(string.format('    Current: %s (Base: %.1f + Augs: %.1f = %.1f)',
                            equippedItemName, comparison.equippedBaseScore, comparison.equippedAugScore, comparison.equippedTotalScore))
                    else
                        print(string.format('    Current: %s (Score: %.1f)', equippedItemName, comparison.equippedTotalScore))
                    end
                    
                    -- Display new item score breakdown
                    if comparison.comparisonType == "with_augments" then
                        local newBreakdown = string.format('Base: %.1f', comparison.newBaseScore)
                        if comparison.newTransferredAugScore > 0 then
                            newBreakdown = newBreakdown .. string.format(' + Augs: %.1f', comparison.newTransferredAugScore)
                        end
                        if comparison.newPotentialAugScore > 0 then
                            newBreakdown = newBreakdown .. string.format(' + Potential: %.1f', comparison.newPotentialAugScore)
                        end
                        print(string.format('    New:     %s%s%s (%s = %.1f) %s',
                            CYAN, itemName, WHITE, newBreakdown, comparison.newTotalScore, percentStr))
                    else
                        print(string.format('    New:     %s%s%s (Score: %.1f) %s',
                            CYAN, itemName, WHITE, comparison.newTotalScore, percentStr))
                    end
                    
                    -- Show orphaned augs warning if any
                    if #comparison.orphanedAugs > 0 then
                        local orphanNames = {}
                        for _, orphan in ipairs(comparison.orphanedAugs) do
                            table.insert(orphanNames, orphan.name)
                        end
                        print(string.format('    %sNote: %d aug(s) cannot transfer: %s%s',
                            RED, #comparison.orphanedAugs, table.concat(orphanNames, ", "), WHITE))
                    end
                end
            end
        end
    else
        print(GREEN .. 'This item is an upgrade for the following slots:' .. WHITE)
        
        table.sort(results, function(a, b) return a.improvement > b.improvement end)
        
        for _, result in ipairs(results) do
            local improvementStr = ''
            
            if result.improvement >= 999 then
                improvementStr = string.format('%s(NEW - empty slot)%s', GREEN, WHITE)
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
            
            print(string.format('  %s%-20s%s [%s]', CYAN, result.slotName, WHITE, result.comparisonType or "base_only"))
            
            -- Display equipped item score breakdown
            if result.augComparison and result.comparisonType == "with_augments" and result.augComparison.equippedAugScore > 0 then
                print(string.format('    Current: %s (Base: %.1f + Augs: %.1f = %.1f)',
                    equippedItemName, result.augComparison.equippedBaseScore, result.augComparison.equippedAugScore, result.equippedScore))
            else
                print(string.format('    Current: %s (Score: %.1f)', equippedItemName, result.equippedScore))
            end
            
            -- Display new item score breakdown
            if result.augComparison and result.comparisonType == "with_augments" then
                local comp = result.augComparison
                local newBreakdown = string.format('Base: %.1f', comp.newBaseScore)
                if comp.newTransferredAugScore > 0 then
                    newBreakdown = newBreakdown .. string.format(' + Augs: %.1f', comp.newTransferredAugScore)
                end
                if comp.newPotentialAugScore > 0 then
                    newBreakdown = newBreakdown .. string.format(' + Potential: %.1f', comp.newPotentialAugScore)
                end
                print(string.format('    New:     %s%s%s (%s = %.1f) %s',
                    CYAN, itemName, WHITE, newBreakdown, result.newScore, improvementStr))
            else
                print(string.format('    New:     %s%s%s (Score: %.1f) %s',
                    CYAN, itemName, WHITE, result.newScore, improvementStr))
            end
            
            -- Show orphaned augs warning if any
            if result.augComparison and #result.augComparison.orphanedAugs > 0 then
                local orphanNames = {}
                for _, orphan in ipairs(result.augComparison.orphanedAugs) do
                    table.insert(orphanNames, orphan.name)
                end
                print(string.format('    %sNote: %d aug(s) cannot transfer: %s%s',
                    RED, #result.augComparison.orphanedAugs, table.concat(orphanNames, ", "), WHITE))
            end
        end
    end
    
    print('========================================')
end

-- Augment Score function for DisplayItem
local function AugmentScore()
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
        print('1. Right-click and inspect an augmentation')
        print('2. Run: /augmentscore')
        return
    end
    
    -- Check if it's an augmentation
    if not IsAugmentation(displayItem) then
        print(RED .. 'ERROR: Item is not an augmentation.' .. WHITE)
        print('The item in the DisplayItem window must be an augmentation.')
        print('Use /itemscore for regular equipment.')
        return
    end
    
    local playerClass = mq.TLO.Me.Class.Name()
    local weights = CLASS_WEIGHTS[playerClass] or CLASS_WEIGHTS.Default
    
    local augName = displayItem.Name()
    local augType = GetStatValue(displayItem, 'AugType')
    local augTypeStr = GetAugTypeString(augType)
    
    print('========================================')
    print(string.format('Augment Score Analysis for %s%s%s', YELLOW, playerClass, WHITE))
    print('========================================')
    print('Evaluating: ' .. CYAN .. augName .. WHITE)
    
    local augScore = CalculateScore(displayItem, weights)
    
    if not displayItem.CanUse() then
        augScore = 0
    end
    
    print(string.format('Augment Score: %s%.1f%s', GREEN, augScore, WHITE))
    print(string.format('Augment Type: %s%s%s', YELLOW, augTypeStr, WHITE))
    
    local results, errorMsg = EvaluateAugment(displayItem, weights)
    
    if not results then
        print(RED .. errorMsg .. WHITE)
        return
    end
    
    if #results == 0 then
        print(YELLOW .. 'No compatible augment slots found on equipped items.' .. WHITE)
        print('========================================')
        return
    end
    
    -- Separate upgrades from non-upgrades
    local upgrades = {}
    local nonUpgrades = {}
    
    for _, result in ipairs(results) do
        if result.isUpgrade then
            table.insert(upgrades, result)
        else
            table.insert(nonUpgrades, result)
        end
    end
    
    if #upgrades == 0 then
        print(YELLOW .. 'This augment is not an upgrade for any compatible slot.' .. WHITE)
    else
        -- Sort upgrades by improvement (descending)
        table.sort(upgrades, function(a, b) return a.improvement > b.improvement end)
        
        -- Report only the best upgrade
        local best = upgrades[1]
        
        local improvementStr = ''
        if best.currentAugName == "Empty" then
            improvementStr = string.format('%s(NEW - empty slot, +%.1f%%)%s', GREEN, best.improvement, WHITE)
        else
            improvementStr = string.format('%s(+%.1f%%)%s', GREEN, best.improvement, WHITE)
        end
        
        print('')
        print(GREEN .. 'BEST UPGRADE FOUND:' .. WHITE)
        print(string.format('  %s%s%s - Augment Slot %d (Type %d)',
            CYAN, best.equipSlotName, WHITE, best.augSlotNum, best.augSlotType))
        print(string.format('    Item: %s', best.equipItemName))
        print(string.format('    Current: %s (Score: %.1f)', best.currentAugName, best.currentAugScore))
        print(string.format('    New:     %s%s%s (Score: %.1f) %s',
            CYAN, augName, WHITE, best.newAugScore, improvementStr))
        
        -- If there are other upgrade slots, mention them
        if #upgrades > 1 then
            print('')
            print(string.format('%sOther upgrade slots available: %d%s', YELLOW, #upgrades - 1, WHITE))
        end
    end
    
    print('========================================')
end

-- =============================================================================
-- Command Bindings
-- =============================================================================

mq.bind('/printbag', function(bagNum)
    if not bagNum or bagNum == "" then
        print(string.format("\ayUsage: /printbag <bag number %d-%d>", MIN_BAG_NUM, MAX_BAG_NUM))
        print(string.format("\ay  Example: /printbag %d (for pack%d/slot %d)", MIN_BAG_NUM, MIN_BAG_NUM, MIN_BAG_NUM + 22))
        print(string.format("\ay           /printbag %d (for pack%d/slot %d)", MAX_BAG_NUM, MAX_BAG_NUM, MAX_BAG_NUM + 22))
        return
    end
    printBag(bagNum)
end)

mq.bind('/destroybag', function(args)
    if not args or args == "" then
        print(string.format("\ayUsage: /destroybag <bag specification>"))
        print("\ay  Single bag:  /destroybag 5")
        print("\ay  List:        /destroybag 2,4,6")
        print("\ay  Range:       /destroybag 2-7")
        print(string.format("\ar  ** Only bags %d-%d can be destroyed **", MIN_DESTROY_BAG, MAX_DESTROY_BAG))
        print(string.format("\ar  ** %s **", getProtectedBagsMessage()))
        return
    end
    destroyBag(args)
end)

mq.bind('/sellbag', function(args)
    if not args or args == "" then
        print(string.format("\ayUsage: /sellbag <bag specification>"))
        print("\ay  Single bag:  /sellbag 5")
        print("\ay  List:        /sellbag 2,4,6")
        print("\ay  Range:       /sellbag 2-7")
        print(string.format("\ar  ** Only bags %d-%d can be sold **", MIN_SELL_BAG, MAX_SELL_BAG))
        print(string.format("\ar  ** %s **", getProtectedBagsMessage()))
        return
    end
    sellBag(args)
end)

mq.bind('/itemscore', function()
    ItemScore()
end)

mq.bind('/augmentscore', function()
    AugmentScore()
end)

mq.bind('/findupgrades', function(args)
    FindUpgrades(args)
end)

mq.bind('/itemdebug', function()
    ToggleDebug()
end)

-- =============================================================================
-- Initialization
-- =============================================================================

print('\ag========================================')
print('\agBag Manager Script Loaded')
print('\ag========================================')
print('\awBag Management Commands:')
print(string.format('\aw  /printbag <#>      - Display bag contents (bags %d-%d)', MIN_BAG_NUM, MAX_BAG_NUM))
print(string.format('\ar  /destroybag <spec> - Destroy items (bags %d-%d ONLY)', MIN_DESTROY_BAG, MAX_DESTROY_BAG))
print(string.format('\ag  /sellbag <spec>    - Sell items (bags %d-%d ONLY)', MIN_SELL_BAG, MAX_SELL_BAG))
print('\awItem Scoring Commands:')
print('\aw  /itemscore         - Evaluate item in DisplayItem window')
print('\aw  /augmentscore      - Compare augment in DisplayItem window')
print('\aw  /findupgrades      - Scan all bags for upgrades')
print(string.format('\aw  /findupgrades #    - Scan specific bag (%d-%d)', MIN_BAG_NUM, MAX_BAG_NUM))
print('\aw  /findupgrades #-#  - Scan bag range (e.g., 2-4)')
print('\aw  /findupgrades #,#  - Scan specific bags (e.g., 2,4,6)')
print('\ao  /itemdebug         - Toggle debug logging for scoring')
print('\ag----------------------------------------')
print('\awBag Specification Examples:')
print('\aw  /destroybag 5      (single bag)')
print('\aw  /destroybag 2,4,6  (multiple bags)')
print('\aw  /destroybag 2-7    (range)')
print(string.format('\ar  ** %s **', string.upper(getProtectedBagsMessage())))
print('\ag----------------------------------------')
print('\awBag Number Reference:')
printBagReference()
print('\ag========================================')

-- =============================================================================
-- Main Loop
-- =============================================================================

while true do
    mq.delay(1000)
end