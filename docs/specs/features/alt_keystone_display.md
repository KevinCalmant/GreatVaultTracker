# Feature Spec: Alt Keystone Display
**Addon:** Great Vault Tracker
**Type:** Additive feature — no breaking changes to existing data or UI

---

## What This Adds

A `Key:` line in each character's row in the existing GVT panel, showing the dungeon name, key level, and whether the key is intact or depleted.

```
[Class Icon] CharName-Realm         Last seen: Today
  Raid:      [■][■][□]   3 / 7 bosses
  Mythic+:   [■][□][□]   1 / 8 dungeons
  PvP:       [□][□][□]   0 / 10 wins
  Key:       [Dungeon Icon] Ara-Kara  +12  ✔ Intact
```

---

## Data Changes

Add a `keystone` sub-table to each existing character entry in `VaultTrackerDB`. No existing fields are modified.

```lua
-- New addition to the existing per-character entry
keystone = {
  hasKey      = true,       -- false if character holds no key this week
  dungeonID   = 1234,       -- MapChallengeModeID, used to resolve icon & name at render time
  dungeonName = "Ara-Kara", -- cached localized name
  level       = 12,         -- key level
  depleted    = false,      -- true if key was downgraded after last run
},
```

---

## New File

**`Keystone.lua`** — handles all collection and depletion detection. Add it to the `.toc` after `Data.lua`.

```lua
-- Collect keystone data for the current character and save to VaultTrackerDB.
function GVT.CollectKeystoneData()
  local level = C_MythicPlus.GetOwnedKeystoneLevel()
  local mapID = C_MythicPlus.GetOwnedKeystoneChallengeMapID()

  if not level or level == 0 then
    GVT.currentChar.keystone = { hasKey = false }
    return
  end

  local name = C_ChallengeMode.GetMapUIInfo(mapID) or "Unknown"
  local depleted = GVT.keystoneLevelBeforeRun and (level < GVT.keystoneLevelBeforeRun) or false

  GVT.currentChar.keystone = {
    hasKey      = true,
    dungeonID   = mapID,
    dungeonName = name,
    level       = level,
    depleted    = depleted,
  }
end
```

Store `GVT.keystoneLevelBeforeRun = C_MythicPlus.GetOwnedKeystoneLevel()` at `PLAYER_ENTERING_WORLD` so it's available when `CHALLENGE_MODE_COMPLETED` fires.

---

## Event Changes

Register two additional events in `GreatVaultTracker.lua`:

| Event | Action |
|---|---|
| `CHALLENGE_MODE_COMPLETED` | Call `CollectKeystoneData()` — picks up new level and depletion status after a run |
| `BAG_UPDATE_DELAYED` | Call `CollectKeystoneData()` — catches keys awarded mid-session (e.g. from vault); only persist if data changed |

---

## UI Changes

In `UI.lua`, append a `Key:` line after the PvP row in each character block.

**Display rules:**
- Show `[Dungeon Icon] DungeonName  +N` with the level colored green (≥ 10), yellow (5–9), or grey (1–4).
- Append `✔ Intact` in green or `✘ Depleted` in red. Depleted tooltip: *"Key was downgraded after the last run."*
- If `hasKey = false`, show `— No key this week` in grey.
- If the weekly reset is within 24 hours and the character still holds a key, show an amber clock icon. Tooltip: *"Key resets in Xh Ym — log in to use it!"*
- Dungeon icon is resolved via `C_ChallengeMode.GetMapUIInfo(dungeonID)` at render time, not stored.

---

## Edge Cases

- **`GetOwnedKeystoneLevel()` returns nil at login** — defer `CollectKeystoneData()` to `PLAYER_ENTERING_WORLD` if needed.
- **No key held** — `GetOwnedKeystoneLevel()` returns `0` or nil; set `hasKey = false`.
- **Timewalking keys** — use a different `MapChallengeModeID` but the same API calls; no special handling needed.