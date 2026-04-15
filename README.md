# Great Vault Tracker

A World of Warcraft addon that shows Great Vault completion progress for every character on your account.

See [docs/specs/great_vault.md](docs/specs/great_vault.md) for the full specification.

---

## Build / Install

WoW addons are Lua files interpreted by the game client — there is no compile step. "Building" means placing the addon folder where the game can find it.

### 1. Copy the addon folder

Copy the [GreatVaultTracker/](GreatVaultTracker/) folder (not the repo root — the subfolder) into your WoW AddOns directory:

| OS | Default path |
|---|---|
| Windows | `C:\Program Files (x86)\World of Warcraft\_retail_\Interface\AddOns\` |
| macOS | `/Applications/World of Warcraft/_retail_/Interface/AddOns/` |

Result:

```
_retail_/Interface/AddOns/GreatVaultTracker/
  GreatVaultTracker.toc
  GreatVaultTracker.lua
  Constants.lua
  Data.lua
  UI.lua
  Locales/enUS.lua
```

### 2. (Optional) Install libraries for the minimap button

The minimap button uses [LibDBIcon-1.0](https://www.curseforge.com/wow/addons/libdbicon-1-0). Without it, a plain fallback button is created instead — the addon still works.

If you want LibDBIcon:

1. Download these libraries and place them under [GreatVaultTracker/libs/](GreatVaultTracker/libs/):
   - `LibStub/LibStub.lua`
   - `CallbackHandler-1.0/CallbackHandler-1.0.lua`
   - `LibDataBroker-1.1/LibDataBroker-1.1.lua`
   - `LibDBIcon-1.0/LibDBIcon-1.0.lua`
2. Uncomment the four `libs\...` lines in [GreatVaultTracker/GreatVaultTracker.toc](GreatVaultTracker/GreatVaultTracker.toc).

### 3. Enable in-game

Launch WoW → character select → **AddOns** button (bottom-left) → tick **Great Vault Tracker** → **Okay**.

### Syncing during development

If you're editing the files in this repo, symlink or junction the `GreatVaultTracker/` folder into `Interface/AddOns/` so edits are reflected immediately. On Windows:

```bash
# Run from an elevated shell, paths adjusted to your install
mklink /J "C:\Program Files (x86)\World of Warcraft\_retail_\Interface\AddOns\GreatVaultTracker" "e:\dev_repo\addon_great_vault_and_key_infos\GreatVaultTracker"
```

After editing a Lua file, type `/reload` in-game to pick up the change.

---

## Pre-flight checks (optional, before loading in-game)

### Lua syntax check

`luac -p` parses each file without executing it — catches typos, unbalanced `end`s, etc. It does **not** know about WoW globals (`CreateFrame`, `UnitName`, …) so semantic bugs still need an in-game test.

```bash
# From the repo root (needs Lua 5.1+ on PATH — WoW uses Lua 5.1)
luac -p GreatVaultTracker/*.lua GreatVaultTracker/Locales/*.lua
```

A clean run prints nothing. Any message indicates a syntax error with a file and line number.

### Static analysis (optional)

[luacheck](https://github.com/lunarmodules/luacheck) with a WoW globals config catches undeclared globals and unused locals. Install via LuaRocks:

```bash
luarocks install luacheck
luacheck GreatVaultTracker/ --globals LibStub UnitName UnitClass GetRealmName C_WeeklyRewards C_DateAndTime C_MythicPlus C_Timer CreateFrame UIParent GameTooltip GameTooltip_Hide RAID_CLASS_COLORS CLASS_ICON_TCOORDS StaticPopup_Show StaticPopupDialogs SlashCmdList SLASH_GREATVAULTTRACKER1 VaultTrackerDB YES NO Minimap time
```

---

## Testing

### Enable verbose error output

In-game once, then persisted:

```
/console scriptErrors 1
```

Optionally install [BugSack](https://www.curseforge.com/wow/addons/bugsack) + [!BugGrabber](https://www.curseforge.com/wow/addons/bug-grabber) for a proper error log. Vanilla scriptErrors only shows the most recent error in a small popup.

### Smoke test

1. **Load the addon.** Log into any character. No red error popup should appear.
2. **Open the UI.** Type `/gvt`. A frame appears titled *Great Vault Tracker*, showing the current character at the top.
3. **Trigger data collection.** Open Great Vault (in any major city). That fires `WEEKLY_REWARDS_UPDATE`, and your row should populate with raid / Mythic+ / PvP slots and progress numbers.
4. **Verify persistence.**
   ```
   /dump VaultTrackerDB.chars
   ```
   You should see your character's key (`Realm-CharName`) with a `vault` sub-table.
5. **Test the alt flow.** Log out, log into a second character, wait for the Great Vault data to populate (or open the vault frame), `/reload`, `/gvt`. Both characters should now be listed.
6. **Test staleness.** (Optional — hard to simulate without waiting a week.) Manually force it:
   ```
   /run VaultTrackerDB.chars[next(VaultTrackerDB.chars)].weeklyReset = 0
   /reload
   /gvt
   ```
   The affected row should be dimmed with *Needs Login*.
7. **Test commands.**
   - `/gvt show` / `/gvt hide` — toggles window
   - `/gvt prune` — prints `removed N stale characters` (0 on a fresh install)
   - `/gvt reset` — opens confirmation popup; confirming wipes the table

### Event tracing

Blizzard ships a built-in event log — handy for confirming `WEEKLY_REWARDS_UPDATE` is firing:

```
/eventtrace
```

Filter for `WEEKLY_REWARDS_UPDATE`. You should see it fire on login and each time you interact with the vault.

### Inspecting live state

```
/dump VaultTrackerDB                     -- whole saved table
/dump C_WeeklyRewards.GetActivities(1)   -- raw raid activities from the API
/dump C_WeeklyRewards.GetActivities(3)   -- raw mythic+ activities
/dump C_WeeklyRewards.GetActivities(2)   -- raw rated-PvP activities
/dump C_MythicPlus.GetCurrentSeason()    -- season ID used for rollover detection
```

### Where SavedVariables lives on disk

If you want to diff persistence across sessions:

```
<WoW install>/_retail_/WTF/Account/<ACCOUNT>/SavedVariables/GreatVaultTracker.lua
```

It is written on `/reload` and on clean logout — **killing the client skips the write**, so always `/reload` or log out cleanly when testing persistence.

---

## Edge cases to manually verify

| Scenario | Expected behavior |
|---|---|
| Fresh character with no vault activity | Shown with `0 / N` across all three categories, not hidden |
| Character not logged in this week | Dimmed row with "Needs Login" badge |
| No characters tracked yet | Empty-state message inside the frame |
| New M+ season started | On first login after rollover, data is reset and you see *new season detected* in chat |
| Window resized | Rows stretch; content re-lays out on mouse-up |
| Right-click minimap button | Window hides |
| `/gvt reset` cancelled | Data untouched |
