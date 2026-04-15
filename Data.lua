local _, ns = ...

ns.Data = {}
local Data = ns.Data
local C = ns.Constants

local function GetCharKey(name, realm)
    return (realm or "") .. "-" .. (name or "")
end

-- Initializes the SavedVariables layout and returns the root table.
function Data.Init()
    VaultTrackerDB = VaultTrackerDB or {}
    VaultTrackerDB.chars = VaultTrackerDB.chars or {}
    VaultTrackerDB.minimap = VaultTrackerDB.minimap or { hide = false }
    VaultTrackerDB.season = VaultTrackerDB.season or nil
    return VaultTrackerDB
end

function Data.GetCurrentKey()
    return GetCharKey(UnitName("player"), GetRealmName())
end

function Data.GetCharKey(name, realm)
    return GetCharKey(name, realm)
end

function Data.GetChar(key)
    return VaultTrackerDB and VaultTrackerDB.chars and VaultTrackerDB.chars[key]
end

function Data.SetChar(key, data)
    VaultTrackerDB.chars[key] = data
end

function Data.AllChars()
    return VaultTrackerDB and VaultTrackerDB.chars or {}
end

function Data.ResetAll()
    if VaultTrackerDB then
        VaultTrackerDB.chars = {}
    end
end

function Data.Prune()
    local cutoff = time() - (C.MAX_CHAR_AGE_DAYS * C.SECONDS_PER_DAY)
    local removed = 0
    for key, char in pairs(Data.AllChars()) do
        if (char.lastSeen or 0) < cutoff then
            VaultTrackerDB.chars[key] = nil
            removed = removed + 1
        end
    end
    return removed
end

-- Server-anchored timestamp of the next weekly reset. Used to detect staleness:
-- if the stored `weeklyReset` is <= now, the data belongs to a previous week.
function Data.GetWeeklyResetTime()
    if C_DateAndTime and C_DateAndTime.GetSecondsUntilWeeklyReset then
        local secs = C_DateAndTime.GetSecondsUntilWeeklyReset()
        if secs and secs > 0 then
            return time() + secs
        end
    end
    -- Fallback: assume 7 days from now. Better than 0 (which would mark fresh
    -- data as stale immediately).
    return time() + (7 * C.SECONDS_PER_DAY)
end

function Data.IsStale(char)
    if not char or not char.weeklyReset then return true end
    return char.weeklyReset <= time()
end

-- Season ID helpers. We reset all data when the Mythic+ season changes, since
-- thresholds and activity types can shift.
function Data.GetCurrentSeason()
    if C_MythicPlus and C_MythicPlus.GetCurrentSeason then
        return C_MythicPlus.GetCurrentSeason() or 0
    end
    return 0
end

function Data.CheckSeasonRollover()
    local current = Data.GetCurrentSeason()
    if current == 0 then return false end
    local stored = VaultTrackerDB.season
    VaultTrackerDB.season = current
    if stored and stored ~= current then
        Data.ResetAll()
        return true
    end
    return false
end
