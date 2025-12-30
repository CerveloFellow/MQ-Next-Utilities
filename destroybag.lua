-- MQ2 Lua script to manage bag contents
-- Usage: /printbag #  - Display bag contents (1-10 for pack1-pack10)
--        /destroybag # - Destroy all items in bag
--        /destroybag #,#,# - Destroy items in multiple bags
--        /destroybag #-# - Destroy items in a range of bags

local mq = require('mq')

-- Constants
local MIN_BAG_NUM = 1
local MAX_BAG_NUM = 10
local MIN_DESTROY_BAG = 2  -- Only allow destroying bags 2-9
local MAX_DESTROY_BAG = 9
local COMMAND_DELAY = 100
local DESTROY_DELAY = 500
local MAX_CLICK_ATTEMPTS = 5

-- Utility Functions
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

local function bagNumToSlot(bagNum)
    -- Convert bag number (1-10) to inventory slot (23-32)
    return bagNum + 22
end

local function validateBagNumberForDestroy(bagNum)
    local num = tonumber(bagNum)
    if not num or num < MIN_DESTROY_BAG or num > MAX_DESTROY_BAG then
        print(string.format("\ayInvalid bag number %s. Can only destroy bags %d-%d.", tostring(bagNum), MIN_DESTROY_BAG, MAX_DESTROY_BAG))
        return nil
    end
    return num
end

local function validateBagNumber(bagNum)
    local num = tonumber(bagNum)
    if not num or num < MIN_BAG_NUM or num > MAX_BAG_NUM then
        print(string.format("\ayInvalid bag number. Please use %d-%d.", MIN_BAG_NUM, MAX_BAG_NUM))
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

-- Parse bag arguments into a list of bag numbers
local function parseBagArguments(args)
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
            local validNum = validateBagNumberForDestroy(i)
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
            local validNum = validateBagNumberForDestroy(bagStr)
            if validNum then
                table.insert(bagList, validNum)
            else
                hasInvalid = true
            end
        end
    -- Single bag number
    else
        local validNum = validateBagNumberForDestroy(args)
        if validNum then
            table.insert(bagList, validNum)
        else
            return nil
        end
    end
    
    if hasInvalid then
        print("\ar** Note: Bags 1 and 10 are PROTECTED and were skipped **")
    end
    
    if #bagList == 0 then
        print("\ayNo valid bags to destroy.")
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

-- Command Functions
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

local function destroyBag(args)
    local bagList = parseBagArguments(args)
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

-- Bind Commands
mq.bind('/printbag', function(bagNum)
    if not bagNum or bagNum == "" then
        print(string.format("\ayUsage: /printbag <bag number %d-%d>", MIN_BAG_NUM, MAX_BAG_NUM))
        print("\ay  Example: /printbag 1 (for pack1/slot 23)")
        print("\ay           /printbag 10 (for pack10/slot 32)")
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
        print("\ar  ** Bags 1 and 10 are PROTECTED **")
        return
    end
    destroyBag(args)
end)

-- Initialization
print("\ag========================================")
print("\agBag Management Script Loaded")
print("\ag========================================")
print("\awCommands:")
print(string.format("\aw  /printbag <#>   - Display bag contents (bags %d-%d)", MIN_BAG_NUM, MAX_BAG_NUM))
print(string.format("\ar  /destroybag <spec> - Destroy items (bags %d-%d ONLY)", MIN_DESTROY_BAG, MAX_DESTROY_BAG))
print("\aw    Examples:")
print("\aw      /destroybag 5      (single bag)")
print("\aw      /destroybag 2,4,6  (multiple bags)")
print("\aw      /destroybag 2-7    (range)")
print("\ar  ** BAGS 1 & 10 ARE PROTECTED **")
print("\ag========================================")
print("\awBag Number Reference:")
print("\aw  1=pack1/slot23 [PROTECTED], 2=pack2/slot24, 3=pack3/slot25")
print("\aw  4=pack4/slot26, 5=pack5/slot27, 6=pack6/slot28")
print("\aw  7=pack7/slot29, 8=pack8/slot30, 9=pack9/slot31")
print("\aw  10=pack10/slot32 [PROTECTED]")
print("\ag========================================")

-- Main Loop
while true do
    mq.delay(1000)
end
