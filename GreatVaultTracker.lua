local addonName, ns = ...

ns.Core = {}
local Core = ns.Core
local C = ns.Constants
local L = ns.L
local Data = ns.Data

local eventFrame = CreateFrame("Frame", "GreatVaultTrackerEventFrame")

-- Converts the list of up to 3 activity tables returned by
-- C_WeeklyRewards.GetActivities into the compact structure we persist.
local function NormalizeCategory(activities)
    local result = {
        progress    = 0,
        slots       = { false, false, false },
        thresholds  = { 0, 0, 0 },
    }
    if type(activities) ~= "table" then return result end

    for i = 1, C.SLOT_COUNT do
        local a = activities[i]
        if a then
            local threshold = a.threshold or 0
            local progress  = a.progress  or 0
            result.thresholds[i] = threshold
            if progress > result.progress then
                result.progress = progress
            end
            if threshold > 0 and progress >= threshold then
                result.slots[i] = true
            end
        end
    end
    return result
end

-- Returns true if we were able to collect and persist data; false if the API
-- wasn't ready yet (we'll retry on the next WEEKLY_REWARDS_UPDATE).
function Core.CollectVaultData()
    if not C_WeeklyRewards or not C_WeeklyRewards.GetActivities then
        return false
    end

    -- Fetch all three type buckets, then route each result to its storage key
    -- by looking up the `.type` the API reports against the enum's *named*
    -- fields. Enum integer values have shifted between patches — but the names
    -- haven't — so mapping by name keeps us correct regardless of the current
    -- integer scheme. We deliberately do NOT route via C.CATEGORIES.*, because
    -- those fall back to hardcoded integers when a field is missing from the
    -- enum, and the fallback can collide with the API's actual `.type` values
    -- (e.g. Raid fallback=1 collides with Activities=1, causing M+ data to be
    -- shown on the Raid line).
    local WRCTT = (Enum and Enum.WeeklyRewardChestThresholdType) or {}
    local typeToStorageKey = {}
    if WRCTT.Raid       then typeToStorageKey[WRCTT.Raid]       = "raid"       end
    if WRCTT.MythicPlus then typeToStorageKey[WRCTT.MythicPlus] = "mythicPlus" end
    if WRCTT.Activities then typeToStorageKey[WRCTT.Activities] = "mythicPlus" end
    if WRCTT.Dungeon    then typeToStorageKey[WRCTT.Dungeon]    = "mythicPlus" end
    if WRCTT.RankedPvP  then typeToStorageKey[WRCTT.RankedPvP]  = "pvp"        end
    if WRCTT.World      then typeToStorageKey[WRCTT.World]      = "pvp"        end

    local collected = { raid = nil, mythicPlus = nil, pvp = nil }
    local anyData = false
    for typeId = 1, 3 do
        local acts = C_WeeklyRewards.GetActivities(typeId)
        if type(acts) == "table" then
            anyData = true
            local reportedType = acts[1] and acts[1].type
            local storageKey = typeToStorageKey[reportedType] or typeToStorageKey[typeId]
            if storageKey and collected[storageKey] == nil then
                collected[storageKey] = acts
            end
        end
    end

    if not anyData then return false end

    local raid  = collected.raid       or {}
    local mplus = collected.mythicPlus or {}
    local pvp   = collected.pvp        or {}

    local _, class = UnitClass("player")
    local key = Data.GetCurrentKey()
    local entry = Data.GetChar(key) or {}
    entry.name        = UnitName("player")
    entry.realm       = GetRealmName()
    entry.class       = class
    entry.lastSeen    = time()
    entry.weeklyReset = Data.GetWeeklyResetTime()
    entry.vault = {
        raid        = NormalizeCategory(raid),
        mythicPlus  = NormalizeCategory(mplus),
        pvp         = NormalizeCategory(pvp),
    }
    Data.SetChar(key, entry)

    if ns.UI and ns.UI.Refresh then ns.UI.Refresh() end
    Core.UpdateMinimapBadge()
    return true
end

-- Total number of unlocked vault slots across all non-stale characters.
function Core.TotalUnlockedSlots()
    local total = 0
    for _, char in pairs(Data.AllChars()) do
        if not Data.IsStale(char) and char.vault then
            for _, cat in pairs(char.vault) do
                if cat and cat.slots then
                    for _, unlocked in ipairs(cat.slots) do
                        if unlocked then total = total + 1 end
                    end
                end
            end
        end
    end
    return total
end

function Core.UpdateMinimapBadge()
    if ns.UI and ns.UI.UpdateMinimapBadge then
        ns.UI.UpdateMinimapBadge(Core.TotalUnlockedSlots())
    end
end

local function OnPlayerLogin()
    Data.Init()
    if Data.CheckSeasonRollover() then
        print(L.SEASON_RESET)
    end

    eventFrame:RegisterEvent("WEEKLY_REWARDS_UPDATE")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("CHALLENGE_MODE_COMPLETED")
    eventFrame:RegisterEvent("BAG_UPDATE_DELAYED")

    if ns.UI and ns.UI.Init then ns.UI.Init() end

    -- Request a first pass after the login storm settles. If the API isn't
    -- ready yet we'll catch it on WEEKLY_REWARDS_UPDATE.
    C_Timer.After(1, function() Core.CollectVaultData() end)
    C_Timer.After(5, function() Core.CollectVaultData() end)
end

eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        Data.Init()
    elseif event == "PLAYER_LOGIN" then
        OnPlayerLogin()
    elseif event == "WEEKLY_REWARDS_UPDATE" then
        if not Core.CollectVaultData() then
            C_Timer.After(2, function() Core.CollectVaultData() end)
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- GetOwnedKeystoneLevel may return nil at login, so schedule a retry.
        if ns.Keystone then
            ns.Keystone.Collect()
            C_Timer.After(3, function()
                if ns.Keystone then ns.Keystone.Collect() end
            end)
        end
    elseif event == "CHALLENGE_MODE_COMPLETED" then
        -- Run just ended. Key may not be updated in bag yet — BAG_UPDATE_DELAYED
        -- follows up once the new key appears.
        if ns.Keystone then ns.Keystone.Collect() end
    elseif event == "BAG_UPDATE_DELAYED" then
        if ns.Keystone then ns.Keystone.CollectIfChanged() end
    end
end)

-- --------------------------------------------------------------------------
-- Slash commands
-- --------------------------------------------------------------------------

StaticPopupDialogs["GVT_RESET_CONFIRM"] = {
    text = L.RESET_CONFIRM,
    button1 = YES,
    button2 = NO,
    OnAccept = function()
        Data.ResetAll()
        print(L.RESET_DONE)
        if ns.UI and ns.UI.Refresh then ns.UI.Refresh() end
        Core.UpdateMinimapBadge()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

SLASH_GREATVAULTTRACKER1 = "/gvt"
SlashCmdList["GREATVAULTTRACKER"] = function(msg)
    msg = (msg or ""):lower():match("^%s*(.-)%s*$") or ""
    if msg == "" then
        if ns.UI then ns.UI.Toggle() end
    elseif msg == "show" then
        if ns.UI then ns.UI.Show() end
    elseif msg == "hide" then
        if ns.UI then ns.UI.Hide() end
    elseif msg == "reset" then
        StaticPopup_Show("GVT_RESET_CONFIRM")
    elseif msg == "keystonereset" then
        local n = Data.ResetKeystones()
        print(L.KEYSTONE_RESET_DONE:format(n))
        if ns.Keystone then ns.Keystone.Collect() end
        if ns.UI and ns.UI.Refresh then ns.UI.Refresh() end
    elseif msg == "keystonedebug" then
        -- Show the keystone tooltip scan result and the raw tooltip lines so
        -- we can verify what the game exposes for this character's key.
        if not ns.Keystone then
            print("|cffff2020Keystone module not loaded.|r")
        else
            local K = ns.Keystone
            print("|cff1eff00GVT keystone debug|r — character: " .. UnitName("player"))
            print(("  FloorByTooltip() = %s"):format(tostring(K.FloorByTooltip())))

            -- Dump the keystone tooltip lines so we can see what text the
            -- game actually exposes (useful if the parser misses something).
            local keystoneBag, keystoneSlot
            if C_Container and C_Container.GetContainerNumSlots then
                for bag = 0, 4 do
                    local slots = C_Container.GetContainerNumSlots(bag)
                    for slot = 1, slots do
                        local info = C_Container.GetContainerItemInfo(bag, slot)
                        if info and info.itemID == K.KEYSTONE_ITEM_ID then
                            keystoneBag, keystoneSlot = bag, slot
                            break
                        end
                    end
                    if keystoneBag then break end
                end
            end
            if not keystoneBag then
                print("  No keystone item found in bags.")
            elseif C_TooltipInfo and C_TooltipInfo.GetBagItem then
                local data = C_TooltipInfo.GetBagItem(keystoneBag, keystoneSlot)
                if data and data.lines then
                    print(("  Keystone tooltip (bag %d, slot %d):"):format(keystoneBag, keystoneSlot))
                    for i, line in ipairs(data.lines) do
                        print(("    [%d] %s"):format(i, tostring(line.leftText)))
                    end
                else
                    print("  Keystone tooltip data unavailable.")
                end
            else
                print("  C_TooltipInfo.GetBagItem not available on this client.")
            end
        end
    elseif msg == "prune" then
        local n = Data.Prune()
        print(L.PRUNE_DONE:format(n))
        if ns.UI and ns.UI.Refresh then ns.UI.Refresh() end
        Core.UpdateMinimapBadge()
    elseif msg == "debug" then
        local WRCTT = (Enum and Enum.WeeklyRewardChestThresholdType) or {}
        print("|cff1eff00GVT debug|r — Enum.WeeklyRewardChestThresholdType:")
        print(("  Raid=%s  MythicPlus=%s  Activities=%s  Dungeon=%s  RankedPvP=%s  World=%s"):format(
            tostring(WRCTT.Raid), tostring(WRCTT.MythicPlus), tostring(WRCTT.Activities),
            tostring(WRCTT.Dungeon), tostring(WRCTT.RankedPvP), tostring(WRCTT.World)))
        for t = 1, 3 do
            local acts = C_WeeklyRewards and C_WeeklyRewards.GetActivities and C_WeeklyRewards.GetActivities(t)
            print(("GetActivities(%d) -> %s entries"):format(t, acts and #acts or "nil"))
            if type(acts) == "table" then
                for i, a in ipairs(acts) do
                    print(("  [%d] type=%s level=%s threshold=%s progress=%s"):format(
                        i, tostring(a.type), tostring(a.level), tostring(a.threshold), tostring(a.progress)))
                end
            end
        end
        -- Also dump what we have stored for the current char
        local entry = Data.GetChar(Data.GetCurrentKey())
        if entry and entry.vault then
            for k, v in pairs(entry.vault) do
                print(("Stored %s: progress=%s thresholds=%s/%s/%s"):format(k,
                    tostring(v.progress),
                    tostring(v.thresholds and v.thresholds[1]),
                    tostring(v.thresholds and v.thresholds[2]),
                    tostring(v.thresholds and v.thresholds[3])))
            end
        end
    else
        print(L.UNKNOWN_CMD)
    end
end
