-- BuffBot.lua - MacroQuest 2 Buff Request Handler
-- Responds to tells and casts buffs with cooldown tracking
-- Version 2.1

local mq = require('mq')

-- Configuration path - hardcoded absolute path (UPDATE THIS TO MATCH YOUR SETUP)
local configFile = "C:\\ProFusion\\MQ-ROF2-E3\\config\\BuffBot_" .. mq.TLO.Me.Name() .. ".ini"

local buffKeywords = {}
local lastMovementTime = os.time()
local antiAFKEnabled = false

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

-- Parse time string (e.g., "30s", "5m", "2h") to seconds
local function parseTimeToSeconds(timeStr)
    if not timeStr then return 0 end
    local num, unit = timeStr:match("^(%d+)([smh])$")
    if not num then return 0 end
    
    num = tonumber(num)
    if unit == 's' then return num
    elseif unit == 'm' then return num * 60
    elseif unit == 'h' then return num * 3600
    end
    return 0
end

-- Format seconds to human-readable time
local function formatTime(seconds)
    if seconds >= 3600 then
        return string.format("%.1f hours", seconds / 3600)
    elseif seconds >= 60 then
        return string.format("%.1f minutes", seconds / 60)
    else
        return string.format("%d seconds", seconds)
    end
end

-- ============================================================================
-- CONFIGURATION
-- ============================================================================

-- Create default INI file if it doesn't exist
local function createDefaultINI()
    print("Creating default INI file: " .. configFile)
    
    -- Create with multiple settings to ensure file is substantial
    mq.cmdf('/ini "%s" "settings" "AntiAFK" "false"', configFile)
    mq.delay(100)
    
    -- Add a test buff to verify it works
    mq.cmdf('/ini "%s" "belt" "Buff" "Test Spell"', configFile)
    mq.delay(100)
    mq.cmdf('/ini "%s" "belt" "CharacterRecast" "30m"', configFile)
    mq.delay(100)
    mq.cmdf('/ini "%s" "belt" "BuffCoolDownMessage" "Cooldown"', configFile)
    mq.delay(100)
    mq.cmdf('/ini "%s" "belt" "BuffRecastMessage" "Wait"', configFile)
    mq.delay(100)
    mq.cmdf('/ini "%s" "belt" "BuffCastCompleteMessage" "Done"', configFile)
    mq.delay(500)
    
    print("Default INI file created successfully")
    print("File location: " .. configFile)
    return true
end

-- Load configuration from INI file
local function loadConfig()
    print("Loading configuration from: " .. configFile)
    
    -- Check if INI file exists
    if not mq.TLO.Ini(configFile)() then
        print("INI file not found, creating default configuration")
        if not createDefaultINI() then
            return
        end
        mq.delay(1000)
    end
    
    -- Load AntiAFK setting
    local antiAFKStr = mq.TLO.Ini(configFile, "settings", "AntiAFK")()
    antiAFKEnabled = antiAFKStr and antiAFKStr:lower() == 'true'
    print("Anti-AFK: " .. tostring(antiAFKEnabled))
    
    -- Read INI file to get all sections
    local file = io.open(configFile, "r")
    if not file then
        print("ERROR: Unable to read INI file")
        return
    end
    
    local sections = {}
    for line in file:lines() do
        local section = line:match("^%[(.+)%]$")
        if section then
            -- Skip settings and waitlist sections
            if section ~= 'settings' and not section:find('_waitlist') then
                table.insert(sections, section)
            end
        end
    end
    file:close()
    
    -- Load each keyword section
    print("Checking for buff keywords in INI file...")
    for _, keyword in ipairs(sections) do
        local buffName = mq.TLO.Ini(configFile, keyword, "Buff")()
        
        -- Check if the value is valid
        if buffName and buffName ~= '' then
            local recastTime = mq.TLO.Ini(configFile, keyword, "CharacterRecast")()
            local cooldownMsg = mq.TLO.Ini(configFile, keyword, "BuffCoolDownMessage")()
            local recastMsg = mq.TLO.Ini(configFile, keyword, "BuffRecastMessage")()
            local completeMsg = mq.TLO.Ini(configFile, keyword, "BuffCastCompleteMessage")()
            
            local lowerKeyword = string.lower(keyword)
            buffKeywords[lowerKeyword] = {
                keyword = keyword,
                buff = buffName,
                recastSeconds = parseTimeToSeconds(recastTime),
                cooldownMsg = cooldownMsg or "That buff is on cooldown, please wait",
                recastMsg = recastMsg or "You must wait before requesting this buff again.",
                completeMsg = completeMsg or "Buff cast successfully!",
                waitlistSection = keyword .. '_waitlist'
            }
            print("Loaded buff keyword: " .. keyword .. " -> " .. buffName)
        end
    end
end

-- ============================================================================
-- WAITLIST MANAGEMENT
-- ============================================================================

-- Check if character is eligible for buff
local function checkWaitlist(keyword, charName)
    local config = buffKeywords[keyword]
    local lastCastTime = mq.TLO.Ini(configFile, config.waitlistSection, charName)()
    
    if not lastCastTime or lastCastTime == '' then
        return true, 0
    end
    
    local lastCast = tonumber(lastCastTime)
    if not lastCast then
        return true, 0
    end
    
    local currentTime = os.time()
    local timeSinceCast = currentTime - lastCast
    
    if timeSinceCast >= config.recastSeconds then
        return true, 0
    else
        local remainingTime = config.recastSeconds - timeSinceCast
        return false, remainingTime
    end
end

-- Update waitlist with current timestamp
local function updateWaitlist(keyword, charName)
    local config = buffKeywords[keyword]
    mq.cmdf('/ini "%s" "%s" "%s" "%d"', configFile, config.waitlistSection, charName, os.time())
end

-- ============================================================================
-- BUFF CASTING LOGIC
-- ============================================================================

-- Check if buff/item is on cooldown
local function checkCooldown(buffName, isItem)
    if isItem then
        local item = mq.TLO.FindItem(buffName)
        if item and item.Spell then
            local spell = item.Spell
            if spell and spell.IsReady then
                local isReady = spell.IsReady()
                
                -- Convert string "TRUE"/"FALSE" to boolean if needed
                if type(isReady) == "string" then
                    isReady = isReady:upper() == "TRUE"
                end
                
                if not isReady then
                    local recastTime = spell.RecastTime() or 0
                    
                    -- Convert to number if it's a string
                    if type(recastTime) == "string" then
                        recastTime = tonumber(recastTime) or 0
                    end
                    
                    return false, recastTime / 1000
                end
            end
        end
    else
        local spellName = buffName:match("^(.+)/Gem|%d+$") or buffName
        local spell = mq.TLO.Spell(spellName)
        if spell and spell.IsReady then
            local isReady = spell.IsReady()
            
            -- Convert string "TRUE"/"FALSE" to boolean if needed
            if type(isReady) == "string" then
                isReady = isReady:upper() == "TRUE"
            end
            
            if not isReady then
                local recastTime = spell.RecastTime() or 0
                
                -- Convert to number if it's a string
                if type(recastTime) == "string" then
                    recastTime = tonumber(recastTime) or 0
                end
                
                return false, recastTime / 1000
            end
        end
    end
    return true, 0
end

-- Determine if buff is an item or spell
local function isBuffAnItem(buffName)
    -- Check equipped items
    for i = 0, 22 do
        local item = mq.TLO.Me.Inventory(i)
        if item and item.Name() and item.Name():lower() == buffName:lower() then
            return true
        end
    end
    
    -- Check inventory
    local item = mq.TLO.FindItem("=" .. buffName)
    if item and item() then
        return true
    end
    
    return false
end

-- Cast spell buff
local function castSpell(buffName)
    local spellName = buffName:match("^(.+)/Gem|(%d+)$")
    local specifiedGem = buffName:match("/Gem|(%d+)$")
    
    if not spellName then
        spellName = buffName
    end
    
    local targetGem = specifiedGem and tonumber(specifiedGem) or 13
    
    -- Check if spell is already memorized
    local currentSpell = mq.TLO.Me.Gem(targetGem)()
    if not currentSpell or currentSpell ~= spellName then
        print("Memorizing " .. spellName .. " in gem " .. targetGem)
        mq.cmdf('/memorize "%s" %d', spellName, targetGem)
        mq.delay(100)
        
        -- Wait for memorization
        local maxWait = 200
        while mq.TLO.Me.Gem(targetGem)() ~= spellName and maxWait > 0 do
            mq.delay(100)
            maxWait = maxWait - 1
        end
        
        if mq.TLO.Me.Gem(targetGem)() ~= spellName then
            print("Failed to memorize spell")
            return false
        end
    end
    
    -- Cast the spell
    print("Casting " .. spellName .. " from gem " .. targetGem)
    mq.cmdf('/cast %d', targetGem)
    mq.delay(100)
    
    -- Wait for casting to start
    local maxWait = 50
    while not mq.TLO.Me.Casting() and maxWait > 0 do
        mq.delay(100)
        maxWait = maxWait - 1
    end
    
    -- Wait for cast to complete
    maxWait = 200
    while mq.TLO.Me.Casting() and maxWait > 0 do
        mq.delay(100)
        maxWait = maxWait - 1
    end
    
    -- Check if cast was successful (not interrupted)
    if maxWait == 0 then
        print("Cast timed out")
        return false
    end
    
    print("Cast completed")
    return true
end

-- Activate item buff
local function activateItem(itemName)
    print("Activating item: " .. itemName)
    mq.cmdf('/useitem "%s"', itemName)
    mq.delay(100)
    
    -- Wait for casting to start
    local maxWait = 50
    while not mq.TLO.Me.Casting() and maxWait > 0 do
        mq.delay(100)
        maxWait = maxWait - 1
    end
    
    -- Wait for cast to complete
    maxWait = 200
    while mq.TLO.Me.Casting() and maxWait > 0 do
        mq.delay(100)
        maxWait = maxWait - 1
    end
    
    -- Check if cast was successful
    if maxWait == 0 then
        print("Item activation timed out")
        return false
    end
    
    print("Item activation completed")
    return true
end

-- ============================================================================
-- BUFF REQUEST HANDLER
-- ============================================================================

-- Handle buff request from a player
local function handleBuffRequest(sender, keyword, isTestMode)
    keyword = keyword:lower()
    local config = buffKeywords[keyword]
    
    if not config then
        print("Unknown keyword: " .. keyword)
        return
    end
    
    print("Buff request from " .. sender .. " for keyword: " .. keyword)
    
    -- Helper function to send response
    local function sendResponse(message)
        if isTestMode then
            print("RESPONSE: " .. message)
        else
            mq.cmdf('/tell %s %s', sender, message)
        end
    end
    
    -- Check waitlist eligibility
    local eligible, waitTime = checkWaitlist(keyword, sender)
    if not eligible then
        local message = config.recastMsg .. " Time remaining: " .. formatTime(waitTime)
        sendResponse(message)
        print("Denied - waitlist: " .. sender)
        return
    end
    
    -- Determine if item or spell
    local buffName = config.buff
    local isItem = isBuffAnItem(buffName)
    
    -- Check cooldown
    local ready, cooldownTime = checkCooldown(buffName, isItem)
    if not ready then
        local message = config.cooldownMsg .. " Time remaining: " .. formatTime(cooldownTime)
        sendResponse(message)
        print("Denied - cooldown: " .. buffName)
        return
    end
    
    -- Target the requester
    mq.cmdf('/target %s', sender)
    mq.delay(100)
    
    -- Wait for target
    local maxWait = 50
    while (not mq.TLO.Target() or mq.TLO.Target.Name() ~= sender) and maxWait > 0 do
        mq.delay(100)
        maxWait = maxWait - 1
    end
    
    if not mq.TLO.Target() or mq.TLO.Target.Name() ~= sender then
        sendResponse("Unable to target you for buff")
        print("Failed to target: " .. sender)
        return
    end
    
    -- Cast the buff
    local success = false
    if isItem then
        success = activateItem(buffName)
    else
        success = castSpell(config.buff)
    end
    
    if success then
        updateWaitlist(keyword, sender)
        sendResponse(config.completeMsg)
        print("Buff cast complete for " .. sender)
    else
        sendResponse("Failed to cast buff")
        print("Failed to cast buff for " .. sender)
    end
end

-- Event handler for tells
local function onTell(line, sender, message)
    message = message:lower():gsub("^%s*(.-)%s*$", "%1")
    
    for keyword, _ in pairs(buffKeywords) do
        if message == keyword then
            handleBuffRequest(sender, keyword)
            return
        end
    end
end

-- ============================================================================
-- ANTI-AFK
-- ============================================================================

local function doAntiAFK()
    if not antiAFKEnabled then return end
    
    local currentTime = os.time()
    if currentTime - lastMovementTime >= 120 then
        print("Performing anti-AFK movement")
        mq.cmd('/keypress forward hold')
        mq.delay(500)
        mq.cmd('/keypress forward')
        mq.delay(100)
        mq.cmd('/keypress back hold')
        mq.delay(500)
        mq.cmd('/keypress back')
        lastMovementTime = currentTime
    end
end

-- ============================================================================
-- MAIN
-- ============================================================================

local function main()
    print("=== BuffBot Macro Started (Version 2.1) ===")
    
    loadConfig()
    
    -- Register tell event
    mq.event('tell', '#1# tells you, #2#', onTell)
    
    -- Bind command for testing buffs on yourself
    mq.bind('/buffbot', function(keyword)
        if not keyword or keyword == '' then
            print("Usage: /buffbot <keyword>")
            print("Available keywords:")
            for kw, _ in pairs(buffKeywords) do
                print("  - " .. kw)
            end
            return
        end
        
        keyword = keyword:lower()
        if not buffKeywords[keyword] then
            print("Unknown keyword: " .. keyword)
            print("Available keywords:")
            for kw, _ in pairs(buffKeywords) do
                print("  - " .. kw)
            end
            return
        end
        
        print("Testing buff: " .. keyword .. " on yourself")
        handleBuffRequest(mq.TLO.Me.Name(), keyword, true)  -- true = test mode
    end)
    
    print("Listening for buff requests...")
    print("Registered keywords: ")
    for keyword, config in pairs(buffKeywords) do
        print("  - " .. keyword .. " (" .. config.buff .. ")")
    end
    
    if next(buffKeywords) == nil then
        print("")
        print("*** NO BUFF KEYWORDS LOADED ***")
        print("Add buff configurations to: " .. configFile)
        print("")
        print("Example configuration:")
        print("[belt]")
        print("Buff=Girdle of Stability")
        print("CharacterRecast=30m")
        print("BuffCoolDownMessage=Belt on cooldown")
        print("BuffRecastMessage=Wait before requesting again")
        print("BuffCastCompleteMessage=Buff complete!")
        print("")
    end
    
    print("Use /buffbot <keyword> to test buffs on yourself")
    
    while true do
        mq.doevents()
        doAntiAFK()
        mq.delay(100)
    end
end

main()
