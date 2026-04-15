local _, ns = ...

ns.Keystone = {}
local K = ns.Keystone
local Data = ns.Data

local function ReadApi()
    local level = C_MythicPlus and C_MythicPlus.GetOwnedKeystoneLevel
        and C_MythicPlus.GetOwnedKeystoneLevel()
    local mapID = C_MythicPlus and C_MythicPlus.GetOwnedKeystoneChallengeMapID
        and C_MythicPlus.GetOwnedKeystoneChallengeMapID()
    return level, mapID
end

local function ResolveName(mapID)
    if not mapID or mapID == 0 then return nil end
    if C_ChallengeMode and C_ChallengeMode.GetMapUIInfo then
        local name = C_ChallengeMode.GetMapUIInfo(mapID)
        if name and name ~= "" then return name end
    end
    return nil
end

-- Mythic Keystone item ID (the wrapper item that holds the key data).
K.KEYSTONE_ITEM_ID = 180653

-- Locate the keystone in the player's bags. Returns bag, slot or nil.
local function FindKeystoneBagSlot()
    if not C_Container or not C_Container.GetContainerNumSlots then return nil end
    for bag = 0, 4 do
        local slots = C_Container.GetContainerNumSlots(bag)
        for slot = 1, slots do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.itemID == K.KEYSTONE_ITEM_ID then
                return bag, slot
            end
        end
    end
    return nil
end

-- Localized keywords that indicate a resilient-floor line in the keystone
-- tooltip. `string.find` is used with `plain=true` so these are matched as
-- UTF-8 byte sequences — Lua 5.1 (WoW) doesn't do Unicode case-folding,
-- so we store them already lowercased and lowercase the tooltip line with
-- `string.lower` (which only touches ASCII, leaving accented chars alone).
--
-- Add more languages as users report their tooltip text via /gvt keystonedebug.
K.RESILIENT_KEYWORDS = {
    "resilient",     -- English ("Resilient")
    "résistance",    -- French ("Niveau de résistance")
}

-- Returns the keystone floor by scanning the owned keystone's item tooltip.
-- The game updates this tooltip live when a Resilient Keystone floor is in
-- effect for the current season, so it's inherently season-aware and
-- per-character. Returns 0 when the item isn't found or the text isn't
-- recognized.
--
-- The scan only extracts numbers from lines that MATCH a resilience keyword,
-- so unrelated numbers elsewhere in the tooltip (like the current key level)
-- don't contaminate the result. The number may appear with or without a `+`
-- prefix depending on locale ("+12" vs "13").
function K.FloorByTooltip()
    local bag, slot = FindKeystoneBagSlot()
    if not bag or not slot then return 0 end
    if not C_TooltipInfo or not C_TooltipInfo.GetBagItem then return 0 end
    local data = C_TooltipInfo.GetBagItem(bag, slot)
    if not data or not data.lines then return 0 end

    local foundKeyword = false
    local best = 0

    for _, line in ipairs(data.lines) do
        local text = line.leftText
        if text then
            local lower = text:lower()
            local lineMatched = false
            for _, kw in ipairs(K.RESILIENT_KEYWORDS) do
                if lower:find(kw, 1, true) then
                    lineMatched = true
                    foundKeyword = true
                    break
                end
            end
            if lineMatched then
                for n in text:gmatch("%d+") do
                    local v = tonumber(n)
                    if v and v > best then best = v end
                end
            end
        end
    end

    if foundKeyword and best > 0 then return best end
    if foundKeyword then return 12 end  -- keyword found but no level parseable
    return 0
end

function K.GetKeystoneFloor()
    return K.FloorByTooltip()
end

-- Collect and persist keystone state for the current character.
function K.Collect()
    if not C_MythicPlus or not C_MythicPlus.GetOwnedKeystoneLevel then
        return false
    end

    local level, mapID = ReadApi()
    local key = Data.GetCurrentKey()
    local entry = Data.GetChar(key) or {}

    -- Base identity fields (in case this runs before vault collection).
    entry.name     = UnitName("player")
    entry.realm    = GetRealmName()
    local _, class = UnitClass("player")
    entry.class    = class
    entry.lastSeen = time()

    if not level or level == 0 or not mapID or mapID == 0 then
        entry.keystone = {
            hasKey = false,
            floor  = K.GetKeystoneFloor(),
        }
        Data.SetChar(key, entry)
        if ns.UI and ns.UI.Refresh then ns.UI.Refresh() end
        return true
    end

    entry.keystone = {
        hasKey      = true,
        dungeonID   = mapID,
        dungeonName = ResolveName(mapID)
            or (entry.keystone and entry.keystone.dungeonName)
            or "Unknown",
        level       = level,
        floor       = K.GetKeystoneFloor(),
    }
    Data.SetChar(key, entry)

    if ns.UI and ns.UI.Refresh then ns.UI.Refresh() end
    return true
end

-- Triggered by BAG_UPDATE_DELAYED. Only persists when something actually
-- changed (key gained, lost, different dungeon / level, floor change).
function K.CollectIfChanged()
    if not C_MythicPlus or not C_MythicPlus.GetOwnedKeystoneLevel then
        return false
    end

    local level, mapID = ReadApi()
    local hasKeyNow = (level and level > 0 and mapID and mapID ~= 0) and true or false

    local entry = Data.GetChar(Data.GetCurrentKey())
    local prev = entry and entry.keystone
    local hadKey    = prev and prev.hasKey  or false
    local prevLevel = prev and prev.level   or 0
    local prevMap   = prev and prev.dungeonID or 0
    local prevFloor = prev and prev.floor   or 0

    if hasKeyNow == hadKey
        and (level or 0) == prevLevel
        and (mapID or 0) == prevMap
        and K.GetKeystoneFloor() == prevFloor
    then
        return false
    end
    return K.Collect()
end
