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

    -- Fetch all three type buckets, then route each result by its own `.type`
    -- field rather than trusting the type ID we passed. The enum integers have
    -- shifted between patches and even between regions — this makes us correct
    -- no matter what the current mapping is.
    local buckets = { [C.CATEGORIES.RAID] = nil, [C.CATEGORIES.MYTHIC_PLUS] = nil, [C.CATEGORIES.PVP] = nil }
    local anyData = false
    for typeId = 1, 3 do
        local acts = C_WeeklyRewards.GetActivities(typeId)
        if type(acts) == "table" then
            anyData = true
            -- Use the reported `.type` on the first activity as the canonical
            -- category. Fall back to the requested typeId if the list is empty.
            local reportedType = (acts[1] and acts[1].type) or typeId
            if buckets[reportedType] == nil then
                buckets[reportedType] = acts
            end
        end
    end

    if not anyData then return false end

    local raid  = buckets[C.CATEGORIES.RAID]        or {}
    local mplus = buckets[C.CATEGORIES.MYTHIC_PLUS] or {}
    local pvp   = buckets[C.CATEGORIES.PVP]         or {}

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
    elseif msg == "prune" then
        local n = Data.Prune()
        print(L.PRUNE_DONE:format(n))
        if ns.UI and ns.UI.Refresh then ns.UI.Refresh() end
        Core.UpdateMinimapBadge()
    elseif msg == "debug" then
        local WRCTT = (Enum and Enum.WeeklyRewardChestThresholdType) or {}
        print("|cff1eff00GVT debug|r — Enum.WeeklyRewardChestThresholdType:")
        print(("  Raid=%s  MythicPlus=%s  Activities=%s  RankedPvP=%s  World=%s"):format(
            tostring(WRCTT.Raid), tostring(WRCTT.MythicPlus), tostring(WRCTT.Activities),
            tostring(WRCTT.RankedPvP), tostring(WRCTT.World)))
        print(("Addon mapping: RAID=%d  MYTHIC_PLUS=%d  PVP=%d"):format(
            C.CATEGORIES.RAID, C.CATEGORIES.MYTHIC_PLUS, C.CATEGORIES.PVP))
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
