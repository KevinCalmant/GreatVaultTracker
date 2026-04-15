local _, ns = ...

ns.Constants = {}
local C = ns.Constants

-- Logical category identifiers used as table keys for label / tooltip /
-- display-order lookups. These are NOT the API's `.type` integers — routing
-- of raw C_WeeklyRewards data into storage is done by enum name in
-- Core.CollectVaultData. We use negative sentinel values here so that if this
-- table is ever (mis)used as an API type key, it cannot collide with a real
-- `.type` value returned by the API.
C.CATEGORIES = {
    RAID        = -1,
    PVP         = -2,
    MYTHIC_PLUS = -3,
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

-- Keystone level color thresholds (inclusive lower bound → color hex).
-- Used to colorize the "+N" key-level text.
C.KEY_LEVEL_HIGH        = 10    -- green
C.KEY_LEVEL_MID         = 5     -- yellow
C.KEY_COLOR_HIGH_HEX    = "|cff1eff00"
C.KEY_COLOR_MID_HEX     = "|cffffff00"
C.KEY_COLOR_LOW_HEX     = "|cffaaaaaa"

-- Show an amber "reset soon" indicator when the weekly reset is within this
-- many seconds AND the character still has an unused key.
C.KEY_RESET_WARNING_SECONDS = 24 * 60 * 60

-- Texture for the reset-soon clock indicator — a reliably-present Blizzard icon.
C.KEY_RESET_ICON        = "Interface\\Icons\\Spell_Nature_TimeStop"

