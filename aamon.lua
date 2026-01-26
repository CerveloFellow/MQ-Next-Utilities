-- AA Window Monitor Lua Macro for MacroQuest
-- This script runs every 30 seconds to ensure the "Can Purchase" filter
-- is enabled on the Alternate Advancement Window
--
-- Logic:
-- - If player is "active" (combat, moving, windows open, etc): Skip this cycle
-- - If AA window is already open: Skip this cycle (don't interfere with user interaction)
-- - If AA window is closed and player is idle: Open it, enable "Can Purchase" if needed, then close it

local mq = require('mq')

-- Configuration
local CHECK_INTERVAL_SECONDS = 300
local DELAY_AFTER_BUTTON_CLICK = 200
local DELAY_AFTER_WINDOW_OPEN = 500

-- The actual control name for "Can Purchase" filter
local CAN_PURCHASE_CONTROL = "AAW_TrainFilter"

-- Flag to control the main loop
local running = true

-- Windows that indicate player is busy and should not be interrupted
local BUSY_WINDOWS = {
    "MerchantWnd",      -- Merchant
    "BankWnd",          -- Bank
    "BigBankWnd",       -- Extended bank
    "TradeskillWnd",    -- Tradeskill
    "LootWnd",          -- Looting corpse
    "AdvancedLootWnd",  -- Advanced loot
    "TradeWnd",         -- Trading with player
    "GiveWnd",          -- Giving item to NPC
    "InventoryWindow",  -- Inventory open
}

-- Function to check if player is "active" and should not be interrupted
-- Returns true if we should SKIP this cycle, false if safe to proceed
local function isActive()
    -- Check combat state
    local combatState = mq.TLO.Me.CombatState()
    if combatState == "COMBAT" then
        print("[AAMonitor] Skipping: In combat")
        return true
    end
    
    -- Check if casting (cast bar visible)
    if mq.TLO.Window('CastingWindow').Open() then
        print("[AAMonitor] Skipping: Casting")
        return true
    end
    
    -- Check if moving
    if mq.TLO.Me.Moving() then
        print("[AAMonitor] Skipping: Moving")
        return true
    end
    
    -- Check if MQ2Nav is active
    if mq.TLO.Navigation.Active() then
        print("[AAMonitor] Skipping: Navigation active")
        return true
    end
    
    -- Check if item on cursor
    if mq.TLO.Cursor() then
        print("[AAMonitor] Skipping: Item on cursor")
        return true
    end
    
    -- Check busy windows
    for _, windowName in ipairs(BUSY_WINDOWS) do
        if mq.TLO.Window(windowName).Open() then
            print(string.format("[AAMonitor] Skipping: %s is open", windowName))
            return true
        end
    end
    
    -- All checks passed, player is idle
    return false
end

-- Function to check if AA window is open
local function isAAWindowOpen()
    return mq.TLO.Window('AAWindow').Open()
end

-- Function to open the AA window
local function openAAWindow()
    if not isAAWindowOpen() then
        mq.cmd('/keypress TOGGLE_ALTADVWIN')
        mq.delay(1500, function() return isAAWindowOpen() end)
    end
    return isAAWindowOpen()
end

-- Function to close the AA window
local function closeAAWindow()
    if isAAWindowOpen() then
        mq.cmd('/keypress TOGGLE_ALTADVWIN')
        mq.delay(500, function() return not isAAWindowOpen() end)
    end
end

-- Function to check if "Can Purchase" filter is enabled
local function isCanPurchaseEnabled()
    local control = mq.TLO.Window('AAWindow').Child(CAN_PURCHASE_CONTROL)
    if control() then
        return control.Checked()
    end
    return nil -- Control not found
end

-- Function to enable "Can Purchase" filter by clicking it
local function enableCanPurchase()
    print("[AAMonitor] Clicking 'Can Purchase' filter button...")
    mq.cmdf('/notify AAWindow %s leftmouseup', CAN_PURCHASE_CONTROL)
    mq.delay(DELAY_AFTER_BUTTON_CLICK)
end

-- Main check function
local function performCheck()
    -- Check if in game
    if not mq.TLO.Me() then
        print("[AAMonitor] Not in game, skipping check")
        return
    end
    
    -- Check if player is active/busy
    if isActive() then
        return
    end
    
    -- Check if AA window is already open
    if isAAWindowOpen() then
        print("[AAMonitor] AA window is already open, skipping this cycle")
        return
    end
    
    -- AA window is closed and player is idle, safe to proceed
    print("[AAMonitor] Player idle, checking AA filter...")
    
    if not openAAWindow() then
        print("[AAMonitor] ERROR: Failed to open AA window")
        return
    end
    
    mq.delay(DELAY_AFTER_WINDOW_OPEN)
    
    -- Check the filter state
    local isEnabled = isCanPurchaseEnabled()
    
    if isEnabled == nil then
        print("[AAMonitor] WARNING: Could not find 'Can Purchase' control (AAW_TrainFilter)")
    elseif isEnabled then
        print("[AAMonitor] 'Can Purchase' filter is already enabled")
    else
        print("[AAMonitor] 'Can Purchase' filter is disabled, enabling...")
        enableCanPurchase()
        
        -- Verify it was enabled
        mq.delay(100)
        local newState = isCanPurchaseEnabled()
        if newState then
            print("[AAMonitor] 'Can Purchase' filter is now enabled")
        else
            print("[AAMonitor] WARNING: Filter may not have been enabled")
        end
    end
    
    -- Close the window
    print("[AAMonitor] Closing AA window...")
    closeAAWindow()
end

-- Bind to stop the script
local function stopScript()
    print("[AAMonitor] Stopping...")
    running = false
end

-- Register a bind command to stop the script
mq.bind('/aamonstop', stopScript)

-- Main function
local function main()
    print("===========================================")
    print("AA Window Monitor")
    print("===========================================")
    print(string.format("Check interval: %d seconds", CHECK_INTERVAL_SECONDS))
    print(string.format("Filter control: %s", CAN_PURCHASE_CONTROL))
    print("Use /aamonstop to stop this script")
    print("===========================================")
    print("Will skip checks when:")
    print("  - In combat")
    print("  - Casting")
    print("  - Moving or navigating")
    print("  - Item on cursor")
    print("  - Busy windows open (merchant, bank, loot, etc)")
    print("===========================================")
    
    while running do
        -- Perform the check
        performCheck()
        
        -- Wait for the next check interval
        -- Use a loop with short delays so we can respond to stop command
        local waitTime = CHECK_INTERVAL_SECONDS * 1000 -- Convert to milliseconds
        local elapsed = 0
        local checkInterval = 100 -- Check every 100ms if we should stop
        
        while elapsed < waitTime and running do
            mq.delay(checkInterval)
            elapsed = elapsed + checkInterval
        end
    end
    
    print("[AAMonitor] Script stopped")
    mq.unbind('/aamonstop')
end

-- Run the main function
main()