local _, ns = ...

ns.UI = {}
local UI = ns.UI
local C = ns.Constants
local L = ns.L
local Data = ns.Data

local ROW_HEIGHT            = 88  -- header + 3 category lines + 1 key line + padding
local ROW_SPACING           = 4
local HEADER_HEIGHT         = 18
local CATEGORY_LINE_HEIGHT  = 16
local SLOT_SIZE             = 14
local SLOT_SPACING          = 3
local LABEL_WIDTH           = 60
local SIDE_PAD              = 6

local mainFrame
local scrollFrame
local scrollChild
local emptyLabel
local rowPool = {}

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

local function GetClassColor(class)
    local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if c then return c.r, c.g, c.b end
    return 1, 1, 1
end

local function SetClassIcon(tex, class)
    tex:SetTexture("Interface\\TargetingFrame\\UI-Classes-Circles")
    local coords = class and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[class]
    if coords then
        tex:SetTexCoord(unpack(coords))
    else
        tex:SetTexCoord(0, 1, 0, 1)
    end
end

local function FormatLastSeen(ts)
    if not ts or ts == 0 then return "—" end
    local diff = time() - ts
    if diff < C.SECONDS_PER_DAY then
        return L.TODAY
    elseif diff < (2 * C.SECONDS_PER_DAY) then
        return L.YESTERDAY
    else
        return L.DAYS_AGO:format(math.floor(diff / C.SECONDS_PER_DAY))
    end
end

local function CategoryData(vault, catKey)
    if not vault then return nil end
    return vault[C.VAULT_KEY[catKey]]
end

-- ---------------------------------------------------------------------------
-- Row construction
-- ---------------------------------------------------------------------------

local function CreateSlot(parent)
    local slot = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    slot:SetSize(SLOT_SIZE, SLOT_SIZE)
    if slot.SetBackdrop then
        slot:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        slot:SetBackdropBorderColor(unpack(C.COLOR_SLOT_BORDER))
    end
    slot:EnableMouse(true)
    slot:SetScript("OnEnter", function(self)
        if not self.tooltipText then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.tooltipText, 1, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    slot:SetScript("OnLeave", GameTooltip_Hide)
    return slot
end

local function CreateCategoryLine(parent, index)
    local line = CreateFrame("Frame", nil, parent)
    line:SetHeight(CATEGORY_LINE_HEIGHT)
    line:SetPoint("TOPLEFT",  parent, "TOPLEFT",  SIDE_PAD, -HEADER_HEIGHT - (index - 1) * CATEGORY_LINE_HEIGHT)
    line:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -SIDE_PAD, -HEADER_HEIGHT - (index - 1) * CATEGORY_LINE_HEIGHT)

    line.label = line:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    line.label:SetPoint("LEFT", 0, 0)
    line.label:SetWidth(LABEL_WIDTH)
    line.label:SetJustifyH("LEFT")

    line.slots = {}
    for s = 1, C.SLOT_COUNT do
        local slot = CreateSlot(line)
        slot:SetPoint("LEFT", line.label, "RIGHT", (s - 1) * (SLOT_SIZE + SLOT_SPACING), 0)
        line.slots[s] = slot
    end

    line.progress = line:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    line.progress:SetPoint("LEFT", line.slots[C.SLOT_COUNT], "RIGHT", 8, 0)
    line.progress:SetJustifyH("LEFT")

    return line
end

-- Key line: label + content fontstring (name, +level, status) + amber clock
-- icon (shown only when the weekly reset is imminent AND a key is held).
-- Tooltip is attached to an invisible hover frame covering the content area.
local function CreateKeyLine(parent, index)
    local line = CreateFrame("Frame", nil, parent)
    line:SetHeight(CATEGORY_LINE_HEIGHT)
    line:SetPoint("TOPLEFT",  parent, "TOPLEFT",  SIDE_PAD, -HEADER_HEIGHT - (index - 1) * CATEGORY_LINE_HEIGHT)
    line:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -SIDE_PAD, -HEADER_HEIGHT - (index - 1) * CATEGORY_LINE_HEIGHT)

    line.label = line:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    line.label:SetPoint("LEFT", 0, 0)
    line.label:SetWidth(LABEL_WIDTH)
    line.label:SetJustifyH("LEFT")
    line.label:SetText(L.KEY_LABEL)

    line.content = line:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    line.content:SetPoint("LEFT", line.label, "RIGHT", 4, 0)
    line.content:SetJustifyH("LEFT")
    line.content:SetWordWrap(false)

    line.clock = line:CreateTexture(nil, "OVERLAY")
    line.clock:SetSize(14, 14)
    line.clock:SetPoint("LEFT", line.content, "RIGHT", 4, 0)
    line.clock:SetTexture(C.KEY_RESET_ICON)
    line.clock:SetVertexColor(1, 0.75, 0)
    line.clock:Hide()

    -- Invisible hover area for tooltips (depleted reason or reset-soon warning).
    line.hover = CreateFrame("Frame", nil, line)
    line.hover:SetPoint("LEFT", line.content, "LEFT", 0, 0)
    line.hover:SetPoint("RIGHT", line, "RIGHT", 0, 0)
    line.hover:SetPoint("TOP", line, "TOP", 0, 0)
    line.hover:SetPoint("BOTTOM", line, "BOTTOM", 0, 0)
    line.hover:EnableMouse(true)
    line.hover:SetScript("OnEnter", function(self)
        if not self.tooltipText then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.tooltipText, 1, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    line.hover:SetScript("OnLeave", GameTooltip_Hide)

    return line
end

local function CreateRow(parent)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(ROW_HEIGHT)

    -- Header: class icon + "Name-Realm" + last-seen on the right
    row.classIcon = row:CreateTexture(nil, "ARTWORK")
    row.classIcon:SetSize(16, 16)
    row.classIcon:SetPoint("TOPLEFT", SIDE_PAD, -2)

    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.name:SetPoint("LEFT", row.classIcon, "RIGHT", 6, 0)

    row.lastSeen = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.lastSeen:SetPoint("TOPRIGHT", -SIDE_PAD, -4)

    row.stale = row:CreateFontString(nil, "OVERLAY", "GameFontRedSmall")
    row.stale:SetPoint("RIGHT", row.lastSeen, "LEFT", -8, 0)
    row.stale:SetText(L.NEEDS_LOGIN)
    row.stale:Hide()

    row.categories = {}
    for i = 1, #C.CATEGORY_ORDER do
        row.categories[i] = CreateCategoryLine(row, i)
    end

    -- Key line sits directly below the last category line.
    row.keyLine = CreateKeyLine(row, #C.CATEGORY_ORDER + 1)

    -- Bottom separator
    row.sep = row:CreateTexture(nil, "BACKGROUND")
    row.sep:SetColorTexture(1, 1, 1, 0.08)
    row.sep:SetHeight(1)
    row.sep:SetPoint("BOTTOMLEFT",  SIDE_PAD, 0)
    row.sep:SetPoint("BOTTOMRIGHT", -SIDE_PAD, 0)

    return row
end

local function AcquireRow(parent)
    for _, r in ipairs(rowPool) do
        if not r:IsShown() then
            r:SetParent(parent)
            return r
        end
    end
    local r = CreateRow(parent)
    table.insert(rowPool, r)
    return r
end

local function ReleaseAllRows()
    for _, r in ipairs(rowPool) do
        r:Hide()
        r:ClearAllPoints()
    end
end

-- ---------------------------------------------------------------------------
-- Row population
-- ---------------------------------------------------------------------------

local function LevelColorHex(level)
    if level >= C.KEY_LEVEL_HIGH then return C.KEY_COLOR_HIGH_HEX
    elseif level >= C.KEY_LEVEL_MID then return C.KEY_COLOR_MID_HEX
    else return C.KEY_COLOR_LOW_HEX end
end

-- Resolves the dungeon icon at render time — per spec, we store only the
-- MapChallengeModeID and look up the texture each refresh.
local function DungeonIconEscape(dungeonID)
    if not dungeonID or dungeonID == 0 then return "" end
    if C_ChallengeMode and C_ChallengeMode.GetMapUIInfo then
        local _, _, _, texture = C_ChallengeMode.GetMapUIInfo(dungeonID)
        if texture and texture ~= "" then
            return ("|T%s:14:14|t "):format(texture)
        end
    end
    return ""
end

local function FillKeyLine(line, keystone)
    if not keystone or not keystone.hasKey then
        -- No key this week. If the character has a Resilient Keystone floor
        -- earned, show it alongside — it still applies to next week's key.
        local floor = keystone and keystone.floor or 0
        if floor > 0 then
            line.content:SetText(L.KEY_NO_KEY_WITH_FLOOR:format(floor))
            line.hover.tooltipText = L.TOOLTIP_FLOOR:format(floor)
        else
            line.content:SetText(L.KEY_NO_KEY)
            line.hover.tooltipText = nil
        end
        line.clock:Hide()
        return
    end

    local level = keystone.level or 0
    local hex   = LevelColorHex(level)
    local icon  = DungeonIconEscape(keystone.dungeonID)
    local name  = keystone.dungeonName or "Unknown"

    -- "Resilient Keystone" in WoW is an achievement-based season-long floor.
    -- If the character has earned one, display the floor level and flag the
    -- key as resilient. Otherwise show it as standard.
    local floor = keystone.floor or 0
    local statusText = (floor > 0)
        and L.KEY_FLOOR:format(floor)
        or  L.KEY_STANDARD

    line.content:SetText(("%s%s  %s+%d|r  %s"):format(icon, name, hex, level, statusText))

    local tooltip
    if floor > 0 then
        tooltip = L.TOOLTIP_FLOOR:format(floor)
    end

    -- Amber clock when the weekly reset is imminent and the player still holds
    -- an unused key (i.e., a refresh is about to wipe this level).
    local secsUntilReset = 0
    if C_DateAndTime and C_DateAndTime.GetSecondsUntilWeeklyReset then
        secsUntilReset = C_DateAndTime.GetSecondsUntilWeeklyReset() or 0
    end
    if secsUntilReset > 0 and secsUntilReset < C.KEY_RESET_WARNING_SECONDS then
        line.clock:Show()
        local hours = math.floor(secsUntilReset / 3600)
        local minutes = math.floor((secsUntilReset % 3600) / 60)
        tooltip = L.TOOLTIP_RESET_SOON:format(hours, minutes)
    else
        line.clock:Hide()
    end

    line.hover.tooltipText = tooltip
end

local function FillRow(row, char)
    row.name:SetText(("%s-%s"):format(char.name or "?", char.realm or "?"))
    row.name:SetTextColor(GetClassColor(char.class))
    SetClassIcon(row.classIcon, char.class)
    row.lastSeen:SetText(("%s: %s"):format(L.LAST_SEEN, FormatLastSeen(char.lastSeen)))

    local stale = Data.IsStale(char)
    row.stale:SetShown(stale)
    row:SetAlpha(stale and 0.45 or 1.0)

    for i, catKey in ipairs(C.CATEGORY_ORDER) do
        local line = row.categories[i]
        local data = CategoryData(char.vault, catKey)
            or { slots = { false, false, false }, progress = 0, thresholds = { 0, 0, 0 } }

        line.label:SetText(L[C.CATEGORY_LABEL_KEY[catKey]])

        local tooltipFmt = L[C.CATEGORY_TOOLTIP_KEY[catKey]]
        for s = 1, C.SLOT_COUNT do
            local slot = line.slots[s]
            local unlocked = data.slots and data.slots[s]
            local color = unlocked and C.COLOR_SLOT_UNLOCKED or C.COLOR_SLOT_LOCKED
            if slot.SetBackdropColor then
                slot:SetBackdropColor(unpack(color))
            end
            local threshold = data.thresholds and data.thresholds[s] or 0
            if threshold > 0 then
                slot.tooltipText = tooltipFmt:format(threshold)
            else
                slot.tooltipText = L.TOOLTIP_UNKNOWN
            end
        end

        local maxThreshold = (data.thresholds and data.thresholds[C.SLOT_COUNT]) or 0
        local progressFmt  = L[C.CATEGORY_PROGRESS_KEY[catKey]]
        line.progress:SetText(progressFmt:format(data.progress or 0, maxThreshold))
    end

    FillKeyLine(row.keyLine, char.keystone)
end

-- ---------------------------------------------------------------------------
-- Main frame
-- ---------------------------------------------------------------------------

local function CreateMainFrame()
    local f = CreateFrame("Frame", "GreatVaultTrackerFrame", UIParent, "BasicFrameTemplateWithInset")
    f:SetSize(360, 400)
    f:SetPoint("CENTER")
    f:SetMovable(true)
    f:SetResizable(true)
    if f.SetResizeBounds then f:SetResizeBounds(300, 200, 700, 900) end
    f:EnableMouse(true)
    f:SetClampedToScreen(true)
    f:SetFrameStrata("MEDIUM")
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop",  f.StopMovingOrSizing)

    if f.TitleText then
        f.TitleText:SetText(L.ADDON_NAME)
    else
        local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        title:SetPoint("TOP", 0, -5)
        title:SetText(L.ADDON_NAME)
    end

    -- Resize grip
    local grip = CreateFrame("Button", nil, f)
    grip:SetSize(16, 16)
    grip:SetPoint("BOTTOMRIGHT", -4, 4)
    grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    grip:SetScript("OnMouseDown", function() f:StartSizing("BOTTOMRIGHT") end)
    grip:SetScript("OnMouseUp",   function() f:StopMovingOrSizing(); UI.Refresh() end)

    -- Footer tip explaining that alt data requires an in-game login (WoW API
    -- limitation — C_WeeklyRewards only returns data for the current char).
    f.footer = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.footer:SetPoint("BOTTOMLEFT",  10, 8)
    f.footer:SetPoint("BOTTOMRIGHT", -10, 8)
    f.footer:SetJustifyH("LEFT")
    f.footer:SetJustifyV("TOP")
    f.footer:SetWordWrap(true)
    f.footer:SetHeight(28)
    f.footer:SetText(L.ALT_TIP)

    -- Scroll area (leave room above footer)
    local sf = CreateFrame("ScrollFrame", "GreatVaultTrackerScroll", f, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT",     8,   -28)
    sf:SetPoint("BOTTOMRIGHT", -28, 40)
    local sc = CreateFrame("Frame", nil, sf)
    sc:SetSize(1, 1)
    sf:SetScrollChild(sc)
    sf:SetScript("OnSizeChanged", function(self, w)
        sc:SetWidth(w or 1)
        UI.Refresh()
    end)

    emptyLabel = sc:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    emptyLabel:SetPoint("TOP", 0, -20)
    emptyLabel:SetWidth(280)
    emptyLabel:SetText(L.NO_DATA)
    emptyLabel:Hide()

    scrollFrame = sf
    scrollChild = sc
    mainFrame   = f
    f:Hide()
    return f
end

-- ---------------------------------------------------------------------------
-- Refresh (full re-layout)
-- ---------------------------------------------------------------------------

function UI.Refresh()
    if not mainFrame then return end
    ReleaseAllRows()

    local width = math.max(scrollFrame:GetWidth(), 1)
    scrollChild:SetWidth(width)

    -- Sort: current character first, then by lastSeen descending.
    local currentKey = Data.GetCurrentKey()
    local list = {}
    for key, char in pairs(Data.AllChars()) do
        list[#list + 1] = { key = key, char = char }
    end
    table.sort(list, function(a, b)
        if a.key == currentKey then return true end
        if b.key == currentKey then return false end
        return (a.char.lastSeen or 0) > (b.char.lastSeen or 0)
    end)

    if #list == 0 then
        emptyLabel:Show()
        scrollChild:SetHeight(60)
        return
    end
    emptyLabel:Hide()

    local prev
    for _, item in ipairs(list) do
        local row = AcquireRow(scrollChild)
        row:SetWidth(width)
        if prev then
            row:SetPoint("TOPLEFT",  prev, "BOTTOMLEFT",  0, -ROW_SPACING)
            row:SetPoint("TOPRIGHT", prev, "BOTTOMRIGHT", 0, -ROW_SPACING)
        else
            row:SetPoint("TOPLEFT",  scrollChild, "TOPLEFT",  0, 0)
            row:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", 0, 0)
        end
        FillRow(row, item.char)
        row:Show()
        prev = row
    end
    scrollChild:SetHeight(#list * (ROW_HEIGHT + ROW_SPACING))
end

-- ---------------------------------------------------------------------------
-- Show / hide / toggle
-- ---------------------------------------------------------------------------

function UI.Show()
    if not mainFrame then CreateMainFrame() end
    mainFrame:Show()
    UI.Refresh()
end

function UI.Hide()
    if mainFrame then mainFrame:Hide() end
end

function UI.Toggle()
    if not mainFrame then CreateMainFrame() end
    if mainFrame:IsShown() then mainFrame:Hide() else UI.Show() end
end

-- ---------------------------------------------------------------------------
-- Minimap button (LibDBIcon if present, otherwise a plain button)
-- ---------------------------------------------------------------------------

local minimapButton
local ldbObject

local function BuildLdbTooltip(tt)
    tt:AddLine(L.MINIMAP_TITLE)
    tt:AddLine(L.MINIMAP_HINT, 1, 1, 1)
    tt:AddLine(" ")
    tt:AddLine(L.MINIMAP_UNLOCKED:format(ns.Core and ns.Core.TotalUnlockedSlots() or 0), 1, 0.82, 0)
end

local function TryInitLibDBIcon()
    local LibStub = _G.LibStub
    if not LibStub then return false end
    local ldb  = LibStub("LibDataBroker-1.1", true)
    local ldbi = LibStub("LibDBIcon-1.0", true)
    if not ldb or not ldbi then return false end

    ldbObject = ldb:NewDataObject("GreatVaultTracker", {
        type    = "launcher",
        label   = L.ADDON_NAME,
        text    = "0",
        icon    = C.MINIMAP_ICON,
        OnClick = function(_, button)
            if button == "RightButton" then UI.Hide() else UI.Toggle() end
        end,
        OnTooltipShow = BuildLdbTooltip,
    })
    ldbi:Register("GreatVaultTracker", ldbObject, VaultTrackerDB.minimap)
    return true
end

local function InitFallbackMinimapButton()
    if minimapButton then return end
    local b = CreateFrame("Button", "GreatVaultTrackerMinimapButton", Minimap)
    b:SetFrameStrata("MEDIUM")
    b:SetSize(28, 28)
    b:SetFrameLevel(8)
    b:SetPoint("CENTER", Minimap, "CENTER", 52, -52)

    local icon = b:CreateTexture(nil, "BACKGROUND")
    icon:SetTexture(C.MINIMAP_ICON)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    icon:SetPoint("TOPLEFT",     5,  -5)
    icon:SetPoint("BOTTOMRIGHT", -5, 5)

    local border = b:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(54, 54)
    border:SetPoint("TOPLEFT")

    b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    b.badge = b:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    b.badge:SetPoint("BOTTOMRIGHT", -2, 2)
    b.badge:SetTextColor(1, 0.82, 0)

    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:SetScript("OnClick", function(_, button)
        if button == "RightButton" then UI.Hide() else UI.Toggle() end
    end)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        BuildLdbTooltip(GameTooltip)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", GameTooltip_Hide)

    minimapButton = b
end

function UI.InitMinimap()
    if not TryInitLibDBIcon() then
        InitFallbackMinimapButton()
    end
end

function UI.UpdateMinimapBadge(count)
    count = count or 0
    if ldbObject then
        ldbObject.text = tostring(count)
    end
    if minimapButton and minimapButton.badge then
        minimapButton.badge:SetText(count > 0 and tostring(count) or "")
    end
end

-- ---------------------------------------------------------------------------
-- Entry point
-- ---------------------------------------------------------------------------

function UI.Init()
    if not mainFrame then CreateMainFrame() end
    UI.InitMinimap()
    UI.Refresh()
end
