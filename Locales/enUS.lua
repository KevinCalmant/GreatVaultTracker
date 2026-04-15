local _, ns = ...

ns.L = {
    ADDON_NAME          = "Great Vault Tracker",
    LAST_SEEN           = "Last seen",
    TODAY               = "Today",
    YESTERDAY           = "Yesterday",
    DAYS_AGO            = "%d days ago",
    NEEDS_LOGIN         = "Needs Login",
    NO_DATA             = "No data yet — log into a character to begin tracking.",
    ALT_TIP             = "|cffaaaaaaTip: log into each alt once to add them here. WoW does not expose weekly progress for characters you are not logged into.|r",

    CATEGORY_RAID       = "Raid:",
    CATEGORY_MPLUS      = "Mythic+:",
    CATEGORY_PVP        = "PvP:",

    PROGRESS_RAID       = "%d / %d bosses",
    PROGRESS_MPLUS      = "%d / %d dungeons",
    PROGRESS_PVP        = "%d / %d wins",

    TOOLTIP_RAID        = "Defeat %d raid bosses to unlock this slot.",
    TOOLTIP_MPLUS       = "Complete %d Mythic+ dungeons to unlock this slot.",
    TOOLTIP_PVP         = "Earn %d rated PvP wins to unlock this slot.",
    TOOLTIP_UNKNOWN     = "Data not yet collected — log into this character with the addon enabled.",

    KEY_LABEL                   = "Key:",
    KEY_NO_KEY                  = "|cffaaaaaa— No key this week|r",
    KEY_NO_KEY_WITH_FLOOR       = "|cffaaaaaa— No key|r   |cffffcc00🛡 Floor +%d|r",
    KEY_FLOOR                   = "|cffffcc00🛡 Resilient (Floor +%d)|r",
    KEY_STANDARD                = "|cffaaaaaa— Standard|r",
    TOOLTIP_FLOOR               = "Resilient Keystone achievement earned — keys on this character will not deplete below +%d this season.",
    TOOLTIP_RESET_SOON          = "Key resets in %dh %dm — log in to use it!",

    MINIMAP_TITLE       = "Great Vault Tracker",
    MINIMAP_HINT        = "Left-click: toggle window\nRight-click: hide",
    MINIMAP_UNLOCKED    = "Unlocked slots this week: %d",

    RESET_CONFIRM       = "Clear all Great Vault Tracker data? This cannot be undone.",
    RESET_DONE          = "|cff1eff00Great Vault Tracker:|r all data cleared.",
    PRUNE_DONE          = "|cff1eff00Great Vault Tracker:|r removed %d stale characters.",
    KEYSTONE_RESET_DONE = "|cff1eff00Great Vault Tracker:|r cleared keystone data for %d characters.",
    SEASON_RESET        = "|cff1eff00Great Vault Tracker:|r new season detected — data reset.",
    UNKNOWN_CMD         = "|cff1eff00Great Vault Tracker:|r commands: /gvt [show|hide|reset|prune|keystonereset]",
}
