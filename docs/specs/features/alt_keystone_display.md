# Feature Spec: Alt Keystone Display

**Addon:** Great Vault Tracker
**Type:** Additive feature — no breaking changes to existing data or UI

---

## What This Adds

A `Key:` line in each character's row in the existing GVT panel, showing the dungeon name, current key level, and — if the character has earned a *Resilient Keystone* achievement this season — the floor level below which the key will not deplete.

```
[Class Icon] CharName-Realm         Last seen: Today
  Raid:      [■][■][□]   3 / 7 bosses
  Mythic+:   [■][□][□]   1 / 8 dungeons
  PvP:       [□][□][□]   0 / 10 wins
  Key:       [Dungeon Icon] Ara-Kara  +12  🛡 Resilient (Floor +12)
```

- A character with no Resilient Keystone achievement earned shows `— Standard`.
- A character with an earned achievement shows `🛡 Resilient (Floor +N)`, where `N` is the achievement's floor level.

---

## Background: what "Resilient Keystone" actually means in WoW

*Resilient Keystone* is **not** a per-run bounce-back mechanic. It is a **season-long achievement reward**:

- Complete every seasonal Mythic+ dungeon timed at the achievement's threshold (e.g. +12 for *TWW Season 2: Resilient Keystone 12*, achievement ID **41724**).
- From that point on, **the character's keystone cannot deplete below that threshold for the rest of the season.**

Refs:

- [Resilient Keystones (spell 1220643)](https://www.wowhead.com/spell=1220643/resilient-keystones)
- [TWW S2: Resilient Keystone 12 (achievement 41724)](https://www.wowhead.com/achievement=41724)
- [TWW S3: Resilient Keystone 12 (achievement 42149)](https://www.wowhead.com/achievement=42149)
- [TWW S3: Resilient Keystone 16 (achievement 42153)](https://www.wowhead.com/achievement=42153)

**Detection is by scanning the owned keystone's item tooltip.** The game writes the resilient-floor information directly into the tooltip text when a floor is active for the current season. This is inherently per-character (each character has their own keystone) and inherently season-aware (the game stops writing it when the season ends).

Other approaches were tried and discarded:

- **Achievement completion** (`GetAchievementInfo`) — season-agnostic; a character that earned a previous season's Resilient Keystone keeps `completed=true` forever even after the floor expires. Account-shared achievements also inherit to alts. The `wasEarnedByMe` flag was not reliable in practice.
- **Hidden aura** (spell `1220643`) — did not detect reliably on the user's client.

Only tooltip-based detection remains in production.

---

## Data Changes

Add a `keystone` sub-table to each existing character entry in `VaultTrackerDB`:

```lua
keystone = {
  hasKey      = true,         -- false if character holds no key this week
  dungeonID   = 1234,         -- MapChallengeModeID, used to resolve icon & name at render time
  dungeonName = "Ara-Kara",   -- cached localized name
  level       = 12,           -- current key level
  floor       = 12,           -- highest floor from any earned Resilient Keystone
                              -- achievement; 0 if none earned
},
```

When `hasKey = false` (no key this week), `dungeonID`, `dungeonName`, and `level` are omitted, but `floor` is still tracked so the UI can show it next to "No key".

---

## Detection (in `Keystone.lua`)

The floor is read by locating the Mythic Keystone item (`itemID = 180653`) in the player's bags and scanning its tooltip via `C_TooltipInfo.GetBagItem(bag, slot)`. We look for the word "Resilient" in any tooltip line, then extract the highest `+N` number we see on those lines.

```lua
function K.FloorByTooltip()
  local bag, slot = FindKeystoneBagSlot()
  if not bag or not slot then return 0 end
  local data = C_TooltipInfo.GetBagItem(bag, slot)
  if not data or not data.lines then return 0 end

  local hasResilient, level = false, 0
  for _, line in ipairs(data.lines) do
    local text = line.leftText
    if text then
      if text:lower():find("resilient") then hasResilient = true end
      for n in text:gmatch("%+(%d+)") do
        local v = tonumber(n)
        if v and v > level then level = v end
      end
    end
  end
  if hasResilient and level > 0 then return level end
  if hasResilient then return 12 end  -- fallback when level isn't parseable
  return 0
end

function K.GetKeystoneFloor() return K.FloorByTooltip() end
```

Diagnostic command `/gvt keystonedebug` dumps the raw tooltip lines so you can verify the text the game is exposing on a given character.

---

## Event Changes

Register three events in `GreatVaultTracker.lua`:

| Event | Action |
|---|---|
| `PLAYER_ENTERING_WORLD` | Call `Collect()` (with a 3s retry — API may return nil at login). |
| `CHALLENGE_MODE_COMPLETED` | Call `Collect()` — level may change after a run. |
| `BAG_UPDATE_DELAYED` | Call `CollectIfChanged()` — catches new keys from the vault, and tooltip changes on season rollover. |

---

## UI Changes

In `UI.lua`, append a `Key:` line after the PvP row in each character block.

**Display rules:**

- Show `[Dungeon Icon] DungeonName  +N` with the current level colored green (≥ 10), yellow (5–9), or grey (1–4).
- If `floor > 0`, append `🛡 Resilient (Floor +F)` in gold. Tooltip: *"Resilient Keystone achievement earned — keys on this character will not deplete below +F this season."*
- If `floor = 0`, append `— Standard` in grey.
- If `hasKey = false` and `floor = 0`, show `— No key this week` in grey.
- If `hasKey = false` and `floor > 0`, show `— No key   🛡 Floor +F` so the earned floor is still visible.
- If the weekly reset is within 24 hours and the character still holds a key, show an amber clock icon. Tooltip: *"Key resets in Xh Ym — log in to use it!"*
- Dungeon icon is resolved via `C_ChallengeMode.GetMapUIInfo(dungeonID)` at render time, not stored.

---

## Edge Cases

- **`GetOwnedKeystoneLevel()` returns nil at login** — retry on a short timer.
- **No key held** — set `hasKey = false`, still store `floor`.
- **`GetAchievementInfo(id)` errors on an invalid ID** — wrap in `pcall` so future patches that remove an achievement don't break the addon.
- **Achievement earned mid-session** — `ACHIEVEMENT_EARNED` event triggers a refresh.
- **New season** — add the season's achievement(s) to `C.RESILIENT_ACHIEVEMENTS`. Older-season achievements remain earned but their floor no longer applies in-game; this is a natural limitation of per-ID detection, and is acceptable since the UI shows only the best current-season floor once it's entered in the list.
