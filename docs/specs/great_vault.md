# Great Vault Tracker — WoW Addon Spec

## Overview

A World of Warcraft addon that displays the **Great Vault completion progress** for every eligible character on the player's account, across all relevant activity categories (Raids, Mythic+, PvP). The goal is a single, at-a-glance panel showing how many of the 9 weekly unlock slots each character has filled.

---

## Goals

- Show Great Vault progress for all characters that have logged in on the current WoW account.
- Display progress per category: **Raid**, **Mythic+**, and **PvP**, with the 3 thresholds per category (1/2/3 activities unlocked).
- Update data live for the currently logged-in character; persist saved data for alts.
- Provide a compact UI that is unobtrusive but accessible from any screen.

---

## Non-Goals

- Tracking gear item level or specific vault reward choices.
- Cross-account or cross-realm data sync (account-wide only).
- Mobile or web companion features.

---

## Data Model

### Per-Character Saved Data

Stored in `VaultTrackerDB` (SavedVariables), keyed by `realmName-characterName`.

```lua
VaultTrackerDB = {
  ["Realm-CharName"] = {
    name        = "CharName",
    realm       = "Realm",
    class       = "WARRIOR",          -- for class color in UI
    lastSeen    = 1713000000,          -- Unix timestamp
    weeklyReset = 1713000000,          -- timestamp of the reset this data belongs to
    vault = {
      raid = {
        progress = 3,                  -- bosses killed (max relevant: 9 for 3 slots)
        slots    = { true, true, false } -- which thresholds are met (1/3/7 kills)
      },
      mythicPlus = {
        progress = 2,                  -- M+ dungeons completed this week
        slots    = { true, false, false } -- thresholds: 1/4/8 completions
      },
      pvp = {
        progress = 0,                  -- rated PvP wins
        slots    = { false, false, false } -- thresholds: 3/6/10 wins (approx)
      },
    },
  },
}
```

> **Note:** Vault threshold values (e.g., 1/3/7 raid bosses) should be defined as constants and verified against the current patch's `C_WeeklyRewards` API output at runtime.

---

## Addon Architecture

```
GreatVaultTracker/
├── GreatVaultTracker.toc
├── GreatVaultTracker.lua          -- Core init, event handling, data collection
├── UI.lua                         -- Frame creation and rendering
├── Data.lua                       -- SavedVariables helpers, stale data pruning
├── Constants.lua                  -- Threshold values, class colors, category labels
└── Locales/
    └── enUS.lua                   -- All user-facing strings
```

---

## Core WoW API Usage

| Purpose | API |
|---|---|
| Enumerate vault activities | `C_WeeklyRewards.GetActivities(type)` |
| Activity types | `Enum.WeeklyRewardChestThresholdType` (Raid = 1, RankedPvP = 2, MythicPlus = 3) |
| Detect weekly reset | `C_WeeklyRewards.HasAvailableRewards()` + timestamp comparison |
| Character identity | `UnitName("player")`, `GetRealmName()`, `UnitClass("player")` |
| Trigger on login/reload | `PLAYER_LOGIN` event |
| Trigger after data is ready | `WEEKLY_REWARDS_UPDATE` event |

---

## Event Flow

```
PLAYER_LOGIN
  └─► RegisterEvent(WEEKLY_REWARDS_UPDATE)
  └─► Load saved data for current character

WEEKLY_REWARDS_UPDATE
  └─► CollectVaultData()
       ├─► C_WeeklyRewards.GetActivities(Raid)
       ├─► C_WeeklyRewards.GetActivities(MythicPlus)
       └─► C_WeeklyRewards.GetActivities(RankedPvP)
  └─► SaveToVaultTrackerDB()
  └─► RefreshUI()
```

---

## UI Specification

### Main Window

- A **movable, resizable frame** (default: 320×260 px).
- Opened via `/gvt` slash command or a **minimap button** (LibDBIcon-compatible).
- Sections for each character, sorted by: **current character first**, then **most recently seen**.
- Stale characters (data from a previous weekly reset) are **visually dimmed** with a "Needs Login" note.

### Per-Character Row

```
[Class Icon] CharName-Realm         Last seen: Today
  Raid:      [■][■][□]   3 / 7 bosses
  Mythic+:   [■][□][□]   1 / 8 dungeons
  PvP:       [□][□][□]   0 / 10 wins
```

- Each `[■]` is a filled slot (threshold met); `[□]` is unfilled.
- Slot icons use **gold** when unlocked, **grey** when locked.
- Class name is colored with the official WoW class color.
- Hovering a slot shows a **tooltip** with the exact threshold: e.g. *"Defeat 3 raid bosses to unlock this slot."*

### Minimap Button Indicator

- Shows a **badge count** (0–9) representing total unlocked slots across all tracked characters for the current week.

---

## Slash Commands

| Command | Action |
|---|---|
| `/gvt` | Toggle the main window |
| `/gvt show` | Open the main window |
| `/gvt hide` | Close the main window |
| `/gvt reset` | Clear all saved data (with confirmation dialog) |
| `/gvt prune` | Remove characters not seen in > 4 weeks |

---

## Weekly Reset Handling

- On each `PLAYER_LOGIN`, compare the saved `weeklyReset` timestamp against the current reset timestamp (derivable from `C_WeeklyRewards` or `GetQuestResetTime()`).
- If the reset has passed, **mark the character's data as stale** without deleting it.
- Stale data is replaced when that character logs in and new data is collected.

---

## Libraries & Dependencies

| Library | Purpose |
|---|---|
| **LibStub** | Addon library loading |
| **LibDBIcon-1.0** | Minimap button |
| **AceDB-3.0** *(optional)* | SavedVariables management with profile/reset support |

All libraries should be embedded in a `/libs` folder and listed in the `.toc`.

---

## TOC File

```toc
## Interface: 110100
## Title: Great Vault Tracker
## Notes: Track Great Vault completion across all your characters.
## Author: YourName
## Version: 1.0.0
## SavedVariables: VaultTrackerDB

libs\LibStub\LibStub.lua
libs\LibDBIcon-1.0\LibDBIcon-1.0.lua

Constants.lua
Data.lua
GreatVaultTracker.lua
UI.lua
Locales\enUS.lua
```

---

## Edge Cases & Notes

- **Fresh characters** with no vault activity should show `0` progress across all categories, not be hidden.
- **Season transitions**: Clear all data when a new PvP/M+ season starts, as vault thresholds may change. Detect via a stored season ID if the API exposes one.
- **Raid type changes**: Some patches alter which raid difficulties count. Use the activity type returned by `C_WeeklyRewards` directly rather than hardcoding difficulty names.
- **Data integrity**: If `GetActivities()` returns nil (e.g., called too early), defer collection to the next `WEEKLY_REWARDS_UPDATE` fire.

---

## Out-of-Scope for v1.0

- Showing which specific items are available as vault rewards.
- Filtering by realm or faction.
- Export to clipboard or WeakAuras integration.

These can be addressed in a future version once the core tracking loop is stable.