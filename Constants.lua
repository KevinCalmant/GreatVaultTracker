local _, ns = ...

ns.Constants = {}
local C = ns.Constants

-- Resolved from Enum.WeeklyRewardChestThresholdType at load time. If the enum
-- exists and the named fields are present, we use them — that's the only
-- authoritative source. If the enum is missing or uses a different schema on
-- the user's client, we fall back to the values observed on current retail
-- (Raid=1, PvP/World=2, MythicPlus/Activities=3). Because CollectVaultData()
-- routes by each activity's own `.type` field, these values only matter for
-- the storage-key and display-order lookup — not for what data ends up where.
local WRCTT = (Enum and Enum.WeeklyRewardChestThresholdType) or {}
C.CATEGORIES = {
    RAID        = WRCTT.Raid                                            or 1,
    PVP         = WRCTT.RankedPvP  or WRCTT.World                       or 2,
    MYTHIC_PLUS = WRCTT.MythicPlus or WRCTT.Activities or WRCTT.Dungeon or 3,
}

-- Order used when rendering a character row: Raid, then Mythic+, then PvP.
C.CATEGORY_ORDER = {
    C.CATEGORIES.RAID,
    C.CATEGORIES.MYTHIC_PLUS,
    C.CATEGORIES.PVP,
}

C.CATEGORY_LABEL_KEY = {
    [C.CATEGORIES.RAID]         = "CATEGORY_RAID",
    [C.CATEGORIES.MYTHIC_PLUS]  = "CATEGORY_MPLUS",
    [C.CATEGORIES.PVP]          = "CATEGORY_PVP",
}

C.CATEGORY_PROGRESS_KEY = {
    [C.CATEGORIES.RAID]         = "PROGRESS_RAID",
    [C.CATEGORIES.MYTHIC_PLUS]  = "PROGRESS_MPLUS",
    [C.CATEGORIES.PVP]          = "PROGRESS_PVP",
}

C.CATEGORY_TOOLTIP_KEY = {
    [C.CATEGORIES.RAID]         = "TOOLTIP_RAID",
    [C.CATEGORIES.MYTHIC_PLUS]  = "TOOLTIP_MPLUS",
    [C.CATEGORIES.PVP]          = "TOOLTIP_PVP",
}

-- Storage key for per-category vault data in the SavedVariables entry.
C.VAULT_KEY = {
    [C.CATEGORIES.RAID]         = "raid",
    [C.CATEGORIES.MYTHIC_PLUS]  = "mythicPlus",
    [C.CATEGORIES.PVP]          = "pvp",
}

C.SLOT_COUNT            = 3
C.MAX_CHAR_AGE_DAYS     = 28                 -- /gvt prune cutoff
C.SECONDS_PER_DAY       = 86400
C.MINIMAP_ICON          = "Interface\\Icons\\INV_Misc_Bag_07_Green"

-- UI colors
C.COLOR_SLOT_UNLOCKED   = { 1.0, 0.82, 0.0, 1.0 }  -- gold
C.COLOR_SLOT_LOCKED     = { 0.25, 0.25, 0.25, 1.0 }
C.COLOR_SLOT_BORDER     = { 0.0, 0.0, 0.0, 0.8 }
