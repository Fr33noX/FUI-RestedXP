-- FUI-RestedXP Options.lua
-- The options window, with its own shell: a sidebar (logo, page
-- search, page nav, version), a top bar (Reload UI, close), then
-- a title, a tab row and a scrolling content area drawn by
-- the row engine.
--
-- The pages themselves are the addon's own cfg sections (FUIOptions.lua,
-- exported as ns.FUIPages): this file translates them into engine rows
-- and owns the shell around them. One section = a label plus rows; rows
-- come in pairs (two columns) unless a row marks itself `buttons` and
-- claims the full width.
--
-- Every write goes through FUIOptions' Set(), which re-applies all
-- modules and asks this window for a live rebuild when a page's shape
-- depends on the key (engine on/off, layout, theme source).

local ADDON_NAME, ns = ...

ns.Options = ns.Options or {}

local B = ns.ViewBits

local WHITE = "Interface\\Buttons\\WHITE8X8"

local WIN_W, WIN_H = 980, 640 -- the right block carries long labels + toggles
local SIDE_W = 210
local PAD = 16
local GUTTER = 20 -- room for the scrollbar inside the content
-- The page's designed width at the default window size: a wider window
-- stretches every row full-bleed (label left, control right, the gap
-- between them growing) instead of leaving void on the right.

local BG    = { 0.045, 0.047, 0.055 }
local SIDE  = { 0.030, 0.031, 0.037 }
local PANEL = { 0.075, 0.078, 0.088 }

local W, view, SIDEBAR

local function DB() return ns.DB() end

-- ---------------- The pages (from FUIOptions) ----------------
local function FindPage(name)
    for _, p in ipairs(ns.FUIPages or {}) do
        if p.name == name then return p end
    end
end

local SIDEBAR_DEF = {
    { key = "Reskin",
      subtitle = "The engine, its layouts, the arrow and every look.",
      terms = "reskin layout arrow engine look window frameless timeline compact zygor bit rail" },
    { key = "Map",
      subtitle = "Route, overlays and the world-map tooltip.",
      terms = "map route overlay world minimap tooltip chain markers" },
    { key = "Theme",
      subtitle = "Colors, accent, and the theme's home in RestedXP.",
      terms = "theme color accent custom activate follow" },
    { key = "Changelog",
      subtitle = "What changed, newest first.",
      terms = "changelog version patch notes history" },
}

local function BuildSidebarList()
    SIDEBAR = {}
    for _, def in ipairs(SIDEBAR_DEF) do
        SIDEBAR[#SIDEBAR + 1] = {
            key = def.key,
            terms = def.terms,
            subtitle = def.subtitle,
            page = FindPage(def.key),
        }
    end
end

-- Reskin's tabs: its own overview plus ONLY the picked layout's look page
-- while the engine is on (the look pages carry engine = true) -- every
-- other layout's page hides until its layout is picked. DEFAULT has no
-- page of its own (it hands the window back to RestedXP): Overview alone.
local function ReskinTabs()
    local db = DB()
    local picked
    if db and db.rxpEnabled and ns.LAYOUT_PAGE then
        picked = ns.LAYOUT_PAGE[db.rxpLayout]
    end
    local tabs = {}
    for _, p in ipairs(ns.FUIPages or {}) do
        if p.name == "Reskin" or (p.engine and picked and p.name == picked) then
            tabs[#tabs + 1] = p
        end
    end
    return tabs
end

local function TabLabel(p)
    if p.name == "Reskin" then return "Overview" end
    return p.name
end

local function CurrentEntry()
    for _, e in ipairs(SIDEBAR or {}) do
        if e.key == W.page then return e end
    end
    return SIDEBAR and SIDEBAR[1]
end

local function CurrentBuild()
    local e = CurrentEntry()
    if not e or not e.page then return nil end
    if e.key ~= "Reskin" then
        return e.page.build, nil, nil
    end
    local tabs = ReskinTabs()
    local idx = W.tabIdx or 1
    -- The tab the index pointed at left the bar with its layout: land on
    -- Overview rather than silently on whatever now sits at that index.
    if idx > #tabs then idx = 1 W.tabIdx = idx end
    local tab = tabs[idx]
    return tab and tab.build, tabs, tab
end

-- ---------------- The translator: cfg -> engine rows ----------------
local SPACER = { type = "spacer" }

local function DrawRow(view, row)
    local t = row.type
    if t == "spacer" then
        view:Space(8)
    elseif t == "toggle" then
        view:Add("toggle", row.text,
            { get = row.getValue, set = row.setValue, tooltip = row.tooltip })
    elseif t == "slider" then
        view:Add("slider", row.text, {
            min = row.min, max = row.max, step = row.step,
            get = row.getValue, set = row.setValue, tooltip = row.tooltip,
        })
    elseif t == "dropdown" then
        local values = {}
        for _, v in ipairs(row.order or {}) do
            values[#values + 1] = { label = row.values[v], value = v }
        end
        view:Add("dropdown", row.text, {
            values = values, get = row.getValue, set = row.setValue,
            tooltip = row.tooltip,
        })
    elseif t == "colorpicker" then
        view:Add("colorpicker", row.text, {
            get = row.getValue, set = row.setValue, tooltip = row.tooltip,
            hasAlpha = row.hasAlpha,
        })
    elseif t == "button" then
        view:Add("button", row.text, {
            onCall = row.onClick,
            width = row.width,
            danger = tostring(row.text or ""):find("Reset") ~= nil,
            tooltip = row.tooltip,
        })
    elseif t == "note" or row.wrapnote then
        view:Add("note", row.text, { indent = row.indent })
    end
end

-- ---------------- Search: pages AND their rows ----------------
-- The box used to filter page names only. Now a page also matches when
-- any of its rows does (label + tooltip, dropdown options included),
-- and the open page draws only its matching rows.
local function SearchQuery()
    if not (W and W.search and W.search.GetText) then return "" end
    return (W.search:GetText() or ""):lower()
end

local function RowText(row)
    if type(row) ~= "table" then return "" end
    local parts = { row.text or "", row.tooltip or "" }
    if row.type == "dropdown" then
        for _, v in ipairs(row.order or {}) do
            parts[#parts + 1] = (row.values and row.values[v]) or ""
        end
    end
    return table.concat(parts, " "):lower()
end

local function RowMatches(row, q)
    if q == "" then return true end
    if type(row) ~= "table" or row.type == "spacer" then return false end
    return RowText(row):find(q, 1, true) ~= nil
end

local function FilterRows(rows, q)
    local out = {}
    for _, row in ipairs(rows) do
        if RowMatches(row, q) then out[#out + 1] = row end
    end
    return out
end

-- True when any row of the section matches; `whole` when the header
-- itself matches (then the section draws unfiltered).
local function SectionMatches(sec, q)
    if q == "" then return true, true end
    if type(sec) ~= "table" then return false end
    if type(sec[1]) == "string" and sec[1]:lower():find(q, 1, true) then
        return true, true
    end
    local l, r = sec.left or {}, sec.right or {}
    if sec.left or sec.right then
        for i = 1, math.max(#l, #r) do
            if RowMatches(l[i], q) or RowMatches(r[i], q) then
                return true, false
            end
        end
    else
        local first = type(sec[1]) == "string" and 2 or 1
        for i = first, #sec do
            if RowMatches(sec[i], q) then return true, false end
        end
    end
    return false
end

-- A tab's built sections, or nil when the build throws: search never
-- breaks the window, a failing page simply does not match.
local function TabSections(tab)
    if not (tab and tab.build) then return nil end
    local ok, sections = pcall(tab.build)
    if ok then return sections end
    return nil
end

local function TabMatches(tab, q)
    local sections = TabSections(tab)
    if not sections then return false end
    for _, sec in ipairs(sections) do
        if SectionMatches(sec, q) then return true end
    end
    return false
end

local function EntryTabs(entry)
    if not entry then return {} end
    if entry.key == "Reskin" then return ReskinTabs() end
    if entry.page then return { entry.page } end
    return {}
end

local function EntryMatches(entry, q)
    if q == "" then return true end
    if not entry then return false end
    if tostring(entry.key .. " " .. (entry.terms or "")):lower():find(q, 1, true) then
        return true
    end
    if entry.subtitle and entry.subtitle:lower():find(q, 1, true) then
        return true
    end
    for _, tab in ipairs(EntryTabs(entry)) do
        if TabMatches(tab, q) then return true end
    end
    return false
end

-- Rows pair up into two columns; a `buttons` row claims its own line.
local function DrawRows(view, rows)
    local i = 1
    while i <= #rows do
        local a = rows[i]
        if a == nil then break end
        if a.buttons then
            DrawRow(view, a)
            i = i + 1
        else
            local b = rows[i + 1]
            if b then
                view:Columns(
                    function() DrawRow(view, a) end,
                    function() DrawRow(view, b) end)
            else
                DrawRow(view, a)
            end
            i = i + 2
        end
    end
end

-- One section's rows after the search filter, or nil when the section
-- holds no match. Mirrors the row assembly DrawSections uses, so the
-- single-page pass and the global pass can never drift apart.
local function SectionRows(sec, q)
    local show, whole = SectionMatches(sec, q)
    if not show then return nil end
    local hasHeader = type(sec[1]) == "string"
    local rows = {}
    if sec.left or sec.right then
        local l, r = sec.left or {}, sec.right or {}
        for i = 1, math.max(#l, #r) do
            rows[#rows + 1] = l[i] or SPACER
            rows[#rows + 1] = r[i] or SPACER
        end
    else
        local first = hasHeader and 2 or 1
        for i = first, #sec do rows[#rows + 1] = sec[i] end
    end
    if q ~= "" and not whole then rows = FilterRows(rows, q) end
    if #rows == 0 then return nil end
    return rows, hasHeader
end

local function DrawSections(view, sections)
    local q = SearchQuery()
    for _, sec in ipairs(sections or {}) do
        -- A title, when there is one, owns slot 1; a section may also ship
        -- without one (the Reskin page's master switch) and then every
        -- element is a row. While searching, a section with no matching
        -- row is skipped outright; a header hit shows the whole section.
        local rows, hasHeader = SectionRows(sec, q)
        if rows then
            if hasHeader then
                view:Add("label", sec[1], { color = sec.accent })
            end
            DrawRows(view, rows)
        end
    end
end

-- Global search: every visible page/tab holding a match, grouped under
-- "Page / Tab" headers. Rows stay live: toggles, sliders, dropdowns
-- and pickers write through the same closures as on their own page,
-- so a setting can change right from the results.
local function DrawGlobalResults(view, q)
    local total = 0
    for _, entry in ipairs(SIDEBAR or {}) do
        for _, tab in ipairs(EntryTabs(entry)) do
            local sections = TabSections(tab)
            if sections then
                local groups = {}
                for _, sec in ipairs(sections) do
                    local rows, hasHeader = SectionRows(sec, q)
                    if rows then
                        groups[#groups + 1] = {
                            header = hasHeader and sec[1] or nil,
                            accent = sec.accent,
                            rows = rows,
                        }
                        for _, r in ipairs(rows) do
                            if type(r) == "table" and r.type ~= "spacer" then
                                total = total + 1
                            end
                        end
                    end
                end
                if #groups > 0 then
                    local tl = TabLabel(tab)
                    local origin = (tl == entry.key)
                        and entry.key
                        or (entry.key .. " / " .. tl)
                    view:Add("label", origin)
                    for _, g in ipairs(groups) do
                        if g.header then
                            view:Add("label", g.header, { color = g.accent })
                        end
                        DrawRows(view, g.rows)
                    end
                end
            end
        end
    end
    if total == 0 then
        view:Add("note", "No settings match \"" .. q .. "\".")
    end
    return total
end

-- ---------------- The page drawn in the view ----------------
local function CreateTab()
    local b = CreateFrame("Button", nil, W)
    b:SetHeight(24)
    b.text = B.Font(b, 12, B.MUTED[1], B.MUTED[2], B.MUTED[3])
    b.text:SetPoint("LEFT", 10, 0)
    b.underline = B.Solid(b, "OVERLAY", 0, 0, 0, 1)
    b.underline:SetPoint("BOTTOMLEFT", 4, 0)
    b.underline:SetPoint("BOTTOMRIGHT", -4, 0)
    b.underline:SetHeight(2)
    b.underline:Hide()
    b:SetScript("OnEnter", function(btn)
        if not btn.__active then
            btn.text:SetTextColor(B.FG[1], B.FG[2], B.FG[3], 1)
        end
    end)
    b:SetScript("OnLeave", function(btn)
        if not btn.__active then
            btn.text:SetTextColor(B.MUTED[1], B.MUTED[2], B.MUTED[3], 1)
        end
    end)
    b:SetScript("OnClick", function(btn)
        if W.tabIdx == btn.__idx then return end
        W.tabIdx = btn.__idx
        W.RefreshValues()
    end)
    return b
end

local function DrawTabs(tabs)
    local n = tabs and #tabs or 0
    local ar, ag, ab = ns.GetAccentColor()
    for i = 1, math.max(n, #W.tabPool) do
        local b = W.tabPool[i]
        if not b and i <= n then
            b = CreateTab()
            W.tabPool[i] = b
        end
        if b then
            if i <= n then
                b:Show()
                b.text:SetText(TabLabel(tabs[i]))
                local active = i == (W.tabIdx or 1)
                b.__active = active
                b.__idx = i
                b:SetSize(math.ceil(b.text:GetStringWidth()) + 24, 24)
                b:ClearAllPoints()
                if i == 1 then
                    b:SetPoint("TOPLEFT", W.tabsRow, "TOPLEFT", 0, 0)
                else
                    b:SetPoint("LEFT", W.tabPool[i - 1], "RIGHT", 0, 0)
                    b:SetPoint("TOP", W.tabsRow, "TOP", 0, 0)
                end
                if active then
                    b.text:SetTextColor(ar, ag, ab, 1)
                    b.underline:SetColorTexture(ar, ag, ab, 1)
                    b.underline:Show()
                else
                    b.text:SetTextColor(B.MUTED[1], B.MUTED[2], B.MUTED[3], 1)
                    b.underline:Hide()
                end
            else
                b:Hide()
            end
        end
    end
end

local function UpdateScrollbar(v)
    local sb, scroll = W.scrollbar, W.scroll
    if not sb then return end
    local range = v:GetHeight() - (scroll:GetHeight() or 0)
    if range < 1 then range = 0 end
    sb:SetMinMaxValues(0, range)
    sb:SetShown(range > 0)
    if range == 0 then scroll:SetVerticalScroll(0) end
end

local page = {}

function page:Redraw()
    local v = self
    v:Clear()

    local q = SearchQuery()
    if q == "" then W.searchScope = nil end
    -- No pinned page: one grouped results list across every visible
    -- page/tab. Typing returns here; clicking a sidebar page pins it
    -- (single-page filtered pass below) until the next keystroke.
    if q ~= "" and not W.searchScope then
        W.title:SetText("Search results")
        W.subtitle:SetText("Matching every page for \"" .. q .. "\"")
        DrawTabs({})
        local ok, total = pcall(DrawGlobalResults, v, q)
        if ok then
            ns.lastDrawError = nil
            W.subtitle:SetText(string.format(
                "%d result(s) for \"%s\" -- change directly here, or pick a page to narrow.",
                total, q))
        else
            ns.lastDrawError = tostring(total)
            print(ns.AccentHex() .. "FUI-RestedXP|r: search draw failed: " .. tostring(total))
            v:Add("note", "Search failed to draw: " .. tostring(total))
        end
        v:Fit()
        UpdateScrollbar(v)
        return
    end

    local build, tabs, active = CurrentBuild()
    local e = CurrentEntry()
    W.title:SetText(e and e.key or "")
    W.subtitle:SetText(e and e.subtitle or "")
    DrawTabs(tabs)

    if build then
        local ok, sections = pcall(build)
        if ok then
            local drew, err = pcall(DrawSections, v, sections)
            if drew then
                ns.lastDrawError = nil
            else
                ns.lastDrawError = tostring(err)
                print(ns.AccentHex() .. "FUI-RestedXP|r: page draw failed: " .. tostring(err))
                v:Space(8)
                v:Add("note", "This page failed to draw: " .. tostring(err))
            end
        else
            ns.lastDrawError = tostring(sections)
            print(ns.AccentHex() .. "FUI-RestedXP|r: page failed: " .. tostring(sections))
            v:Space(8)
            v:Add("note", "This page failed to build. See the error above.")
        end
    end
    v:Fit()
    UpdateScrollbar(v)
end

-- ---------------- Sidebar ----------------
local function PaintNav()
    if not ns.GetAccentColor then return end
    local r, g, b = ns.GetAccentColor()
    for _, nb in ipairs(W.nav) do
        local active = nb.__key == W.page
        nb.__active = active
        if active then
            nb.bg:SetColorTexture(r, g, b, 0.15)
            if not B.AccentSoft then return end
            local ar, ag, ab = B.AccentSoft()
            nb.text:SetTextColor(ar, ag, ab, 1)
        elseif nb.__hover then
            nb.bg:SetColorTexture(1, 1, 1, 0.05)
            nb.text:SetTextColor(B.FG[1], B.FG[2], B.FG[3], 1)
        else
            nb.bg:SetColorTexture(0, 0, 0, 0)
            nb.text:SetTextColor(B.MUTED[1], B.MUTED[2], B.MUTED[3], 1)
        end
    end
end
-- The visible nav items stack compactly under the search box, which sits
-- under the logo: each item anchors TOPLEFT+TOPRIGHT to the SEARCH box
-- itself -- chrome with an explicit 26px height between the same insets --
-- so the chain logo -> search -> items can never ride over the banner.
-- An item is only re-anchored when its y really changes, so a measurement
-- right after this never reads stale points.
local function LayoutNav()
    local q = SearchQuery()
    local y = 0
    for _, nb in ipairs(W.nav) do
        local match = EntryMatches(nb.__entry, q)
        if match then
            nb:Show()
            if nb.__y ~= y then
                nb:ClearAllPoints()
                nb:SetPoint("TOPLEFT", W.search, "BOTTOMLEFT", -4, -8 + y)
                nb:SetPoint("TOPRIGHT", W.search, "BOTTOMRIGHT", 4, -8 + y)
                nb.__y = y
            end
            y = y - 28
        else
            nb:Hide()
            nb.__y = nil
        end
    end
end

local function PanelBox(f, r, g, b)
    f.bg = B.Solid(f, "BACKGROUND", r, g, b, 1)
    f.bg:SetAllPoints()
    f.edges = {
        B.Edge(f, "TOPLEFT", "TOPRIGHT", true),
        B.Edge(f, "BOTTOMLEFT", "BOTTOMRIGHT", true),
        B.Edge(f, "TOPLEFT", "BOTTOMLEFT", false),
        B.Edge(f, "TOPRIGHT", "BOTTOMRIGHT", false),
    }
    for i = 1, #f.edges do
        f.edges[i]:SetColorTexture(B.LINE[1], B.LINE[2], B.LINE[3], 1)
    end
    return f.bg
end

-- The chrome BuildWindow makes ONCE (the Reload button, the window's own
-- scrollbar) has no redraw pass of its own, so the accent repaints it
-- here: called at the end of the build, and again from the accent fan-out.
local function PaintAccentChrome()
    if not W then return end
    local r, g, b = ns.GetAccentColor()
    if W.reload and W.reload.edges then
        for i = 1, #W.reload.edges do
            W.reload.edges[i]:SetColorTexture(r, g, b, 1)
        end
        if W.reload.label then W.reload.label:SetTextColor(r, g, b, 1) end
    end
    if W.sbTrack then
        W.sbTrack:SetColorTexture(r, g, b, 1)
        W.sbTrack:SetVertexColor(1, 1, 1, 0.30)
    end
    if W.sbThumb then
        W.sbThumb:SetVertexColor(r, g, b, 1)
    end
end


-- ---------------- Window ----------------
local function BuildWindow()
    BuildSidebarList()

    W = CreateFrame("Frame", "FUIRestedXPOptions", UIParent)
    W:SetSize(WIN_W, WIN_H)
    W:SetPoint("CENTER")
    W:SetFrameStrata("DIALOG")
    W:SetMovable(true)
    if type(W.SetResizable) == "function" then W:SetResizable(true) end
    W:EnableMouse(true)
    W:RegisterForDrag("LeftButton")
    W:SetScript("OnDragStart", W.StartMoving)
    W:SetScript("OnDragStop", W.StopMovingOrSizing)
    -- Open dropdown and color picker belong to the window: hide them
    -- with it (the picker restores the opening colour: a dismissal
    -- that was not OK keeps nothing half-applied).
    W:SetScript("OnHide", function()
        if ns.CloseDropList then ns.CloseDropList() end
        if ns.CloseColorPicker then ns.CloseColorPicker() end
    end)
    W:SetClampedToScreen(true)
    -- The window opens at its kept scale (the sidebar slider below).
    do
        local db = DB()
        W:SetScale((db and db.optionsScale) or 1)
    end
    tinsert(UISpecialFrames, "FUIRestedXPOptions")
    W.page = SIDEBAR[1].key
    W.tabIdx = nil
    W.searchScope = nil -- pinned sidebar page while searching; nil = every page
    W.nav, W.tabPool = {}, {}

    -- Chrome: near-black panel with hairline edges.
    W.bg = B.Solid(W, "BACKGROUND", BG[1], BG[2], BG[3], 0.97)
    W.bg:SetAllPoints()
    W.edges = {
        B.Edge(W, "TOPLEFT", "TOPRIGHT", true),
        B.Edge(W, "BOTTOMLEFT", "BOTTOMRIGHT", true),
        B.Edge(W, "TOPLEFT", "BOTTOMLEFT", false),
        B.Edge(W, "TOPRIGHT", "BOTTOMRIGHT", false),
    }
    for i = 1, #W.edges do
        W.edges[i]:SetColorTexture(B.LINE[1], B.LINE[2], B.LINE[3], 1)
    end

    -- Sidebar column.
    W.side = CreateFrame("Frame", nil, W)
    W.side:SetPoint("TOPLEFT", W, "TOPLEFT", 0, 0)
    W.side:SetPoint("BOTTOMLEFT", W, "BOTTOMLEFT", 0, 0)
    W.side:SetWidth(SIDE_W)
    W.side.bg = B.Solid(W.side, "BACKGROUND", SIDE[1], SIDE[2], SIDE[3], 1)
    W.side.bg:SetAllPoints()
    local sep = W.side:CreateTexture(nil, "BORDER")
    sep:SetColorTexture(B.LINE[1], B.LINE[2], B.LINE[3], 1)
    sep:SetPoint("TOPRIGHT", W.side, "TOPRIGHT", 0, 0)
    sep:SetPoint("BOTTOMRIGHT", W.side, "BOTTOMRIGHT", 0, 0)
    sep:SetWidth(1)

    -- Logo: a TGA texture that spans the full sidebar width, sitting
    -- above the search box. The image is parented to W.side and anchored
    -- TOP-LEFT (14px inset) to TOP-RIGHT (-14px inset), so it stretches
    -- across the banner exactly like the search box below it.
    W.logo = W.side:CreateTexture(nil, "OVERLAY")
    W.logo:SetTexture([[Interface\AddOns\FUI-RestedXP\Resources\FUI-logo.tga]])
    W.logo:SetPoint("TOPLEFT", W.side, "TOPLEFT", 14, -16)
    W.logo:SetPoint("TOPRIGHT", W.side, "TOPRIGHT", -14, -16)
    -- Let WoW keep the image aspect ratio; the texture is anchored to fill
    -- the full sidebar width and scales proportionally (no SetHeight/
    -- SetWidth distortion).
    W.logo:SetWidth(182)
    -- DrawLayer level keeps the logo above the sidebar background but below
    -- the nav buttons and search box chrome; 7 (TOP) is the highest legal
    -- sublevel and still clears the editbox panel the image sits over.
    W.logo:SetDrawLayer("OVERLAY", 7)
    local r, g, b = ns.GetAccentColor()
    -- The art is white/grey: multiplied by the accent it renders in the
    -- accent's own colour, so the banner colours with every accent change.
    W.logo:SetVertexColor(r, g, b)

    -- Search box: filters the page list. Anchored to the LOGO's bottom
    -- edge (the banner is 16..169 on the current art), so it can never
    -- land on top of the image no matter how tall the texture renders.
    local search = CreateFrame("EditBox", nil, W.side)
    search:SetHeight(26)
    search:SetPoint("TOPLEFT", W.logo, "BOTTOMLEFT", -4, -8)
    search:SetPoint("TOPRIGHT", W.logo, "BOTTOMRIGHT", 4, -8)
    ns.ApplyFont(search, nil, 12)
    search:SetAutoFocus(false)
    PanelBox(search, PANEL[1], PANEL[2], PANEL[3])
    local hint = B.Font(search, 11, B.MUTED[1], B.MUTED[2], B.MUTED[3])
    hint:SetPoint("LEFT", search, "LEFT", 8, 0)
    hint:SetText("Search settings")
    W.search = search
    local function UpdHint()
        hint:SetShown((search:GetText() or "") == "" and not search:HasFocus())
    end        search:SetScript("OnTextChanged", function()
            UpdHint()
            -- Every keystroke returns to the global results list; a
            -- sidebar click below pins one page until the next key.
            W.searchScope = nil
            LayoutNav()
            -- Row filtering lives in the draw pass: repaint so the
            -- results follow every keystroke too.
            if W.RefreshValues then W.RefreshValues() end
        end)
    search:SetScript("OnEditFocusGained", UpdHint)
    search:SetScript("OnEditFocusLost", UpdHint)
    search:SetScript("OnEscapePressed", function() search:ClearFocus() end)

    -- The nav list region, below the search. It carries an EXPLICIT size:
    -- with only two top anchors this frame had no height to resolve, the
    -- client reported it 0x0 / GetRect nil, and every item anchored on it
    -- collapsed to width 0 -- nothing appeared on the banner. One point
    -- plus a size is complete geometry: it can no longer fail to resolve.
    W.sideList = CreateFrame("Frame", nil, W.side)
    W.sideList:SetPoint("TOPLEFT", W.search, "BOTTOMLEFT", -4, -8)
    W.sideList:SetSize(SIDE_W - 12, #SIDEBAR * 28)

    for _, def in ipairs(SIDEBAR) do
        -- Parented straight to the sidebar (like the tabs are to the
        -- window) and anchored by LayoutNav to the search box, on the same
        -- two-anchor pattern that box uses -- a pattern that renders.
        local nb = CreateFrame("Button", nil, W.side)
        nb:SetHeight(26)
        nb.bg = B.Solid(nb, "BACKGROUND", 0, 0, 0, 0)
        nb.bg:SetAllPoints()
        nb.text = B.Font(nb, 12, B.MUTED[1], B.MUTED[2], B.MUTED[3])
        nb.text:SetPoint("LEFT", nb, "LEFT", 12, 0)
        nb.text:SetText(def.key)
        -- Well above every region of the sidebar (a screenshot showed the
        -- labels painted behind the banner): the sidebar's level + 5 puts
        -- the items over any background or border the sidebar owns.
        nb:SetFrameLevel(W.side:GetFrameLevel() + 5)
        nb.__key = def.key
        nb.__terms = (def.key .. " " .. def.terms):lower()
        nb.__entry = def
        nb:SetScript("OnEnter", function(x) x.__hover = true PaintNav() end)
        nb:SetScript("OnLeave", function(x) x.__hover = false PaintNav() end)
        nb:SetScript("OnClick", function(x)
            local q = SearchQuery()
            -- While searching, clicking the current page still matters:
            -- it pins the global list down to that page.
            if x.__key == W.page and (q == "" or W.searchScope) then return end
            W.page = x.__key
            W.tabIdx = nil
            -- While searching, pin to this page and land on its first
            -- tab holding a match instead of the default first tab.
            if q ~= "" then
                W.searchScope = x.__key
                local tabs = EntryTabs(x.__entry)
                for i, tab in ipairs(tabs) do
                    if TabMatches(tab, q) then W.tabIdx = i break end
                end
            else
                W.searchScope = nil
            end
            PaintNav()
            if W.RefreshValues then W.RefreshValues() end
        end)
        W.nav[#W.nav + 1] = nb
    end

    -- Window scale, bottom of the sidebar over the version: the same
    -- rail as the option sliders (accent fill, thumb), 60%..130% in
    -- 5% steps, applied live to the whole window and kept in the DB.
    -- Narrow enough to share the corner with the version tag.
    local SC_MIN, SC_MAX, SC_STEP = 0.6, 1.3, 0.05
    local function ScaleGet()
        local db = DB()
        return (db and db.optionsScale) or 1
    end
    local scaleBox = CreateFrame("Frame", nil, W.side)
    scaleBox:SetPoint("BOTTOMLEFT", W.side, "BOTTOMLEFT", 14, 34)
    scaleBox:SetPoint("BOTTOMRIGHT", W.side, "BOTTOMRIGHT", -14, 34)
    scaleBox:SetHeight(38)
    local scaleLab = B.Font(scaleBox, 11, B.MUTED[1], B.MUTED[2], B.MUTED[3])
    scaleLab:SetPoint("TOPLEFT", scaleBox, "TOPLEFT", 0, 0)
    scaleLab:SetText("Échelle")
    local scaleVal = B.Font(scaleBox, 11, B.FG[1], B.FG[2], B.FG[3])
    scaleVal:SetPoint("TOPRIGHT", scaleBox, "TOPRIGHT", 0, 0)
    local scaleRail = CreateFrame("Frame", nil, scaleBox)
    scaleRail:SetPoint("TOPLEFT", scaleBox, "TOPLEFT", 0, -18)
    scaleRail:SetPoint("TOPRIGHT", scaleBox, "TOPRIGHT", 0, -18)
    scaleRail:SetHeight(14)
    scaleRail.track = B.Solid(scaleRail, "BACKGROUND",
        B.LINE[1], B.LINE[2], B.LINE[3], 1)
    scaleRail.track:SetPoint("LEFT", scaleRail, "LEFT", 0, 0)
    scaleRail.track:SetPoint("RIGHT", scaleRail, "RIGHT", 0, 0)
    scaleRail.track:SetHeight(4)
    scaleRail.fill = B.Solid(scaleRail, "BORDER", 0, 0, 0, 1)
    scaleRail.fill:SetPoint("LEFT", scaleRail.track, "LEFT", 0, 0)
    scaleRail.fill:SetHeight(4)
    scaleRail.thumb = scaleRail:CreateTexture(nil, "ARTWORK")
    scaleRail.thumb:SetTexture(WHITE)
    scaleRail.thumb:SetSize(8, 14)
    local function ScalePaint()
        local v = ScaleGet()
        local pct = (v - SC_MIN) / (SC_MAX - SC_MIN)
        if pct < 0 then pct = 0 elseif pct > 1 then pct = 1 end
        local ar, ag, ab = ns.GetAccentColor()
        scaleRail.track:SetColorTexture(ar, ag, ab, 1)
        scaleRail.track:SetVertexColor(1, 1, 1, 0.30)
        scaleRail.fill:SetColorTexture(ar, ag, ab, 1)
        local tw = scaleRail.track:GetWidth() or 0
        local px = math.floor(pct * tw + 0.5)
        scaleRail.fill:SetWidth(px)
        local tx = px
        if tx < 4 then tx = 4 elseif tx > tw - 4 then tx = tw - 4 end
        scaleRail.thumb:ClearAllPoints()
        scaleRail.thumb:SetPoint("LEFT", scaleRail.track, "LEFT", tx - 4, 0)
        scaleRail.thumb:SetVertexColor(B.FG[1], B.FG[2], B.FG[3], 1)
        scaleVal:SetText(math.floor(v * 100 + 0.5) .. "%")
    end
    local function ScaleSet(raw)
        local v = (math.floor((raw - SC_MIN) / SC_STEP + 0.5) * SC_STEP) + SC_MIN
        if v < SC_MIN then v = SC_MIN elseif v > SC_MAX then v = SC_MAX end
        v = math.floor(v * 1e6 + 0.5) / 1e6
        local db = DB()
        if db then db.optionsScale = v end
        W:SetScale(v)
        ScalePaint()
    end
    local function ScaleFromCursor()
        if not GetCursorPosition then return end
        -- Frozen drag geometry (captured on mouse down, see below).
        local g = scaleRail.__g
        local scale, left, width
        if g then
            scale, left, width = g.scale, g.left, g.width
        else
            scale = scaleRail:GetEffectiveScale()
            left, width = scaleRail.track:GetLeft(), scaleRail.track:GetWidth()
        end
        if not scale or scale == 0 or not left or not width or width == 0 then return end
        local pct = (GetCursorPosition() / scale - left) / width
        if pct < 0 then pct = 0 elseif pct > 1 then pct = 1 end
        ScaleSet(SC_MIN + pct * (SC_MAX - SC_MIN))
    end
    scaleRail._get, scaleRail._set = ScaleGet, ScaleSet
    scaleRail:EnableMouse(true)
    scaleRail:SetScript("OnMouseDown", function(_, btn)
        -- Right click snaps back to 100%: the way out if a drag ever
        -- leaves the window at an extreme.
        if btn == "RightButton" then ScaleSet(1) return end
        if btn ~= "LeftButton" or not GetCursorPosition then return end
        -- Freeze the geometry for the whole drag: every applied scale
        -- moves the rail under the cursor, and reading the moving rail
        -- feeds back until the value slams to an end. Frozen, the drag
        -- stays smooth no matter how the window rescales beneath it.
        scaleRail.__g = {
            scale = scaleRail:GetEffectiveScale(),
            left = scaleRail.track:GetLeft(),
            width = scaleRail.track:GetWidth(),
        }
        scaleRail.__drag = true
        ScaleFromCursor()
    end)
    scaleRail:SetScript("OnUpdate", function()
        if scaleRail.__drag then ScaleFromCursor() end
    end)
    scaleRail:SetScript("OnMouseUp", function()
        scaleRail.__drag = false
        scaleRail.__g = nil
    end)
    W.scaleSlider = scaleRail
    ScalePaint()
    -- Paint again on every show: at build time the rail has no width
    -- yet, so the thumb would rest at the left edge whatever the value.
    W:SetScript("OnShow", function() ScalePaint() end)

    local version = B.Font(W.side, 10, B.MUTED[1], B.MUTED[2], B.MUTED[3])
    version:SetPoint("BOTTOMLEFT", W.side, "BOTTOMLEFT", 14, 14)
    version:SetText("v" .. ns.InstalledVersion())

    -- Top bar: Reload UI + close, top right.
    local close = CreateFrame("Button", nil, W)
    close:SetSize(26, 26)
    close:SetPoint("TOPRIGHT", W, "TOPRIGHT", -8, -8)
    close.text = B.Font(close, 16, B.MUTED[1], B.MUTED[2], B.MUTED[3])
    close.text:SetPoint("CENTER")
    close.text:SetText("×")
    close:SetScript("OnClick", function() W:Hide() end)
    close:SetScript("OnEnter", function()
        close.text:SetTextColor(B.FG[1], B.FG[2], B.FG[3], 1)
    end)
    close:SetScript("OnLeave", function()
        close.text:SetTextColor(B.MUTED[1], B.MUTED[2], B.MUTED[3], 1)
    end)

    local reload = CreateFrame("Button", nil, W)
    reload:SetSize(96, 26)
    reload:SetPoint("RIGHT", close, "LEFT", -8, 0)
    PanelBox(reload, PANEL[1], PANEL[2], PANEL[3])
    reload.label = B.Font(reload, 11, B.FG[1], B.FG[2], B.FG[3])
    reload.label:SetPoint("CENTER")
    reload.label:SetText("Reload UI")
    reload:SetScript("OnClick", function() ReloadUI() end)
    reload:SetScript("OnEnter", function()
        reload.bg:SetColorTexture(PANEL[1] + 0.05, PANEL[2] + 0.05, PANEL[3] + 0.05, 1)
    end)
    reload:SetScript("OnLeave", function()
        reload.bg:SetColorTexture(PANEL[1], PANEL[2], PANEL[3], 1)
    end)
    W.reload = reload

    -- Header: title, subtitle, tabs. The page path ("Reskin / Overview")
    -- that used to sit above the title is gone on the user's ask: the
    -- title alone names the page, the sidebar and tabs carry the rest.
    local cx = SIDE_W + PAD
    W.title = B.Font(W, 20, B.FG[1], B.FG[2], B.FG[3])
    W.title:SetPoint("TOPLEFT", W, "TOPLEFT", cx, -62)
    W.subtitle = B.Font(W, 11, B.MUTED[1], B.MUTED[2], B.MUTED[3])
    W.subtitle:SetPoint("TOPLEFT", W, "TOPLEFT", cx, -92)
    W.tabsRow = CreateFrame("Frame", nil, W)
    W.tabsRow:SetPoint("TOPLEFT", W, "TOPLEFT", cx, -112)
    W.tabsRow:SetPoint("TOPRIGHT", W, "TOPRIGHT", -(PAD + GUTTER), -112)
    W.tabsRow:SetHeight(26)

    -- Content: a scroll frame holding the view, scrollbar in the gutter.
    local scroll = CreateFrame("ScrollFrame", nil, W)
    scroll:SetPoint("TOPLEFT", W, "TOPLEFT", cx, -148)
    -- y is +PAD here, NOT -PAD: +y is up in WoW, so a negative offset on a
    -- BOTTOM point pushes the frame BELOW the window edge (the rail hung
    -- 16px outside the panel). Positive = inside, in px above the edge.
    scroll:SetPoint("BOTTOMRIGHT", W, "BOTTOMRIGHT", -(PAD + GUTTER), PAD)
    W.scroll = scroll

    local sb = CreateFrame("Slider", nil, W)
    sb:SetOrientation("VERTICAL")
    sb:SetPoint("TOPRIGHT", W, "TOPRIGHT", -(PAD + 5), -152)
    sb:SetPoint("BOTTOMRIGHT", W, "BOTTOMRIGHT", -(PAD + 5), PAD)
    sb:SetWidth(6)
    local sbTrack = sb:CreateTexture(nil, "BACKGROUND")
    sbTrack:SetColorTexture(SIDE[1], SIDE[2], SIDE[3], 1)
    sbTrack:SetAllPoints()
    local sbThumb = sb:CreateTexture(nil, "ARTWORK")
    sbThumb:SetTexture(WHITE)
    sbThumb:SetVertexColor(0.35, 0.36, 0.40, 1)
    sb:SetThumbTexture(sbThumb)
    W.sbTrack, W.sbThumb = sbTrack, sbThumb
    sb:SetScript("OnValueChanged", function(_, val)
        scroll:SetVerticalScroll(val or 0)
    end)
    -- Raised well above the window's own chrome: the user reports the
    -- scrollbar sticking out of the panel -- level first; geometry is
    -- measured by /fuirxp debug (its rect vs the window's).
    sb:SetFrameLevel(W:GetFrameLevel() + 10)
    W.scrollbar = sb

    -- Minimum size, measured by the MIN_FIT harness check across every
    -- page: the widest row pair (Map's Chain Visibility slider beside
    -- Upcoming Markers) needs 700px of content; plus the sidebar, pad
    -- and gutter chrome. Below this, labels ride over their controls
    -- (the byte ruler slightly overcounts accented labels, so a few
    -- pixels of air come free). Grow beyond is free.
    local MIN_CONTENT = 700
    local MIN_W = SIDE_W + PAD + GUTTER + MIN_CONTENT -- 946
    local MIN_H = 640
    -- SetMinResize/SetMaxResize are gone on current clients (replaced by
    -- SetResizeBounds): a missing method here aborted the whole build, so
    -- pick whichever API the client exposes and skip when it has neither.
    if type(W.SetResizeBounds) == "function" then
        W:SetResizeBounds(MIN_W, MIN_H, 10000, 10000)
    elseif type(W.SetMinResize) == "function" then
        W:SetMinResize(MIN_W, MIN_H)
    end
    W.__minW, W.__minH = MIN_W, MIN_H

    -- Resize grip, bottom-right: the kit's own chevron turned into the
    -- corner, dragging the window's BOTTOMRIGHT edge, accent on hover.
    -- The client clamps the drag to the minimums above, so the columns
    -- can never overlap or clip; the scroll area stretches with the
    -- window and the view follows through OnSizeChanged. Tucked left
    -- of the scrollbar rail, clear of the content and the version tag.
    local grip = CreateFrame("Button", nil, W)
    grip:SetSize(20, 20)
    grip:SetPoint("BOTTOMRIGHT", W, "BOTTOMRIGHT", -4, 4)
    grip:SetFrameLevel(W:GetFrameLevel() + 5)
    grip.chevron = grip:CreateTexture(nil, "OVERLAY")
    grip.chevron:SetTexture(B.CHEVRON_TEX)
    grip.chevron:SetSize(B.CHEVRON, B.CHEVRON)
    grip.chevron:SetPoint("CENTER")
    -- The art points up: three quarters clockwise faces it into the
    -- corner (negative is clockwise on screen, like the section
    -- chevrons: -pi/2 points right, so -3pi/4 points down-right).
    grip.chevron:SetRotation(-math.pi * 0.75)
    local function GripPaint()
        if grip.__hover then
            local ar, ag, ab = ns.GetAccentColor()
            grip.chevron:SetVertexColor(ar, ag, ab, 1)
        else
            grip.chevron:SetVertexColor(B.MUTED[1], B.MUTED[2], B.MUTED[3], 1)
        end
    end
    grip:SetScript("OnEnter", function(g) g.__hover = true GripPaint() end)
    grip:SetScript("OnLeave", function(g) g.__hover = false GripPaint() end)
    grip:SetScript("OnMouseDown", function(_, btn)
        if btn == "LeftButton" and type(W.StartSizing) == "function" then
            -- Sizing from a corner walks the opposite corner: record the
            -- center so the drag below can hold it (void grows on both
            -- sides instead of shoving the content sideways).
            grip.__cx, grip.__cy = W:GetCenter()
            grip.__sizing = true
            W:StartSizing("BOTTOMRIGHT")
        end
    end)
    grip:SetScript("OnMouseUp", function()
        grip.__sizing = false
        if type(W.StopMovingOrSizing) == "function" then
            W:StopMovingOrSizing()
        end
    end)
    -- While sizing, every size change shifts the window back onto the
    -- recorded center (single CENTER anchor only: never fight a layout
    -- that pinned the window elsewhere). Moving the frame changes no
    -- size, so this cannot loop.
    W:SetScript("OnSizeChanged", function()
        if not grip.__sizing then return end
        local cx, cy = W:GetCenter()
        if not (cx and grip.__cx) then return end
        local p, _, rp, x, y = W:GetPoint(1)
        if p ~= "CENTER" then return end
        x, y = x or 0, y or 0
        W:ClearAllPoints()
        W:SetPoint("CENTER", UIParent, "CENTER",
            x + (grip.__cx - cx), y + (grip.__cy - cy))
    end)
    GripPaint()
    W.grip = grip

    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(_, dir)
        local range = (view and view:GetHeight() or 0) - (scroll:GetHeight() or 0)
        if range < 1 then return end
        local cur = scroll:GetVerticalScroll() or 0
        cur = cur - (dir or 1) * 40
        if cur < 0 then cur = 0 elseif cur > range then cur = range end
        scroll:SetVerticalScroll(cur)
        sb:SetValue(cur)
    end)
    scroll:SetScript("OnSizeChanged", function(_)
        local w = scroll:GetWidth() or 0
        local h = scroll:GetHeight() or 0
        -- No cap: the page always takes the full scroll width, so wide
        -- windows stretch the rows (the engine reads __pad/__contentW
        -- in Clear). Labels stay left, controls stick right.
        local repad = view
            and ((view.__pad or 0) ~= 0 or view.__contentW ~= w)
        if view then view.__pad, view.__contentW = 0, w end
        if view and (repad or view:GetWidth() ~= w or view:GetHeight() ~= h) then
            view:SetWidth(w)
            view:SetHeight(h)
            view:QueueRedraw()
        end
        UpdateScrollbar(view)
    end)

    view = ns.View.New(scroll, nil, page)
    scroll:SetScrollChild(view)

    W.RefreshValues = function()
        if view then view:QueueRedraw() end
    end

    PaintNav()
    LayoutNav()
    UpdHint()
    PaintAccentChrome()

    -- The window builds its first page itself (the view's contract);
    -- from here on the engine owns hide/show and events.
    -- First draw: the view needs a real size to compute scroll range.
    -- LayoutNav() has already fixed the nav positions, so the scroll
    -- range is correct on the first show.
    view:Redraw()
    view:SetWidth(W.scroll:GetWidth() or 658)
    view:SetHeight(W.scroll:GetHeight() or 492)
    view.dirty = false

    W:Hide()
    W.__built = true

    -- Defer the first scrollbar update until after layout has resolved,
    -- because the view's size may not be final at build time (hidden
    -- frame, no layout pass yet).
    if C_Timer and C_Timer.After then
        C_Timer.After(0, function()
            if W and W:IsShown() and view then
                UpdateScrollbar(view)
            end
        end)
    end
end

-- Called by the accent fan-out (Core.lua) when the looks change live.
function ns.Options:OnAccentChanged()
    -- Built, shown or not: the logo and the nav would keep their old tint
    -- while the window sits closed, and opening it must not show stale
    -- colours. A half-built window has nothing consistent to repaint.
    if not (W and W.__built) then return end
    local r, g, b = ns.GetAccentColor()
    if W.logo then W.logo:SetVertexColor(r, g, b) end
    PaintNav()
    PaintAccentChrome()
    if W.RefreshValues then W.RefreshValues() end
end

-- The pages ask for a live rebuild through this door (FUIOptions.lua).
function ns.Options.Refresh()
    if W and W.RefreshValues then W.RefreshValues() end
end

-- Build once, loudly: a build that throws leaves a half window, so the
-- error is captured (and printed) instead of vanishing into the slash
-- handler, and the next open starts from a clean slate.
local function BuildIfNeeded()
    if W and W.__built then return true end
    if W and not W.__built then
        W:Hide()
        W = nil
    end
    local ok, err = pcall(BuildWindow)
    if not ok then
        ns.lastBuildError = tostring(err)
        print(ns.AccentHex() .. "FUI-RestedXP|r: options build failed: " .. tostring(err))
    end
    return W ~= nil and W.__built == true
end

-- Re-checked on every show, because a screenshot proved these fragile:
-- nav labels stay positioned, the view stays attached to the scroll
-- frame, a zero width gets the scroll frame's, and one redraw runs a
-- frame later, once the layout is resolved.
local function EnsureLayout()
    if not W then return end
    LayoutNav()
    if W.scroll and view then
        if W.scroll:GetScrollChild() ~= view then
            local ok, err = pcall(W.scroll.SetScrollChild, W.scroll, view)
            if not ok then
                ns.lastDrawError = "SetScrollChild: " .. tostring(err)
            end
        end
        local w = view:GetWidth()
        if (not w or w < 1) and (W.scroll:GetWidth() or 0) > 1 then
            view:SetWidth(W.scroll:GetWidth())
        end
    end
    if C_Timer and C_Timer.After and view then
        C_Timer.After(0.05, function()
            if W and W:IsShown() and view and view.QueueRedraw then
                view:QueueRedraw()
            end
        end)
    end
end

-- Everything a screenshot cannot tell us, readable in chat after
-- /fuirxp debug: sizes, attachment, positions, the last errors.
function ns.Options.Debug()
    BuildIfNeeded()
    if not W then
        print(ns.AccentHex() .. "FUI-RestedXP|r: no window: "
            .. tostring(ns.lastBuildError or "?"))
        return
    end
    -- Measured SHOWN: hidden frames report no rect (GetLeft nil, widths
    -- from points 0), which made the first dump unreadable.
    W:Show()
    EnsureLayout()
    local function dims(f)
        if not f then return "nil" end
        local ok, w, h = pcall(f.GetSize, f)
        if ok and w and h then return ("%.0fx%.0f"):format(w, h) end
        return "?"
    end
    -- Four labelled edges instead of GetRect: left/top/right/bottom can
    -- never be misread again (top > bottom in this client's y-up world),
    -- and a frame whose layout has not resolved says UNRESOLVED instead
    -- of hiding behind "?".
    local function box(f)
        if not f then return "nil" end
        local okL, l = pcall(f.GetLeft, f)
        local okT, t = pcall(f.GetTop, f)
        local okR, r = pcall(f.GetRight, f)
        local okB, b = pcall(f.GetBottom, f)
        if okL and okT and okR and okB and l and t and r and b then
            return ("l=%.0f,t=%.0f..r=%.0f,b=%.0f"):format(l, t, r, b)
        end
        return "UNRESOLVED"
    end
    print(ns.AccentHex() .. "FUI-RestedXP|r debug:")
    print("  build err: " .. tostring(ns.lastBuildError or "none"))
    print("  draw err: " .. tostring(ns.lastDrawError or "none"))
    print("  window: shown=" .. tostring(W:IsShown()) .. " size=" .. dims(W)
        .. " strata=" .. tostring(W:GetFrameStrata() or "?"))
    print("  scroll: size=" .. dims(W.scroll)
        .. " child=" .. ((W.scroll and W.scroll:GetScrollChild()) and "attached" or "MISSING"))
    local dirty = view and view.dirty
    print("  view: size=" .. dims(view)
        .. " cursor=" .. tostring(view and view.cursor or "?")
        .. " dirty=" .. (dirty == nil and "?" or tostring(dirty)))
    local rows = 0
    if view and view.pools then
        for _, pool in pairs(view.pools) do rows = rows + (pool.used or 0) end
    end
    print("  rows: " .. rows)
    -- Does anything hang BELOW the window's bottom edge? The scroll frame
    -- and the track once did: their bottom anchors used -PAD, a downward
    -- offset on a BOTTOM point. Positive = inside, in px above the edge.
    local function vsBottom(child)
        if not child then return "nil" end
        local okC, cb = pcall(child.GetBottom, child)
        local okT, wt = pcall(W.GetTop, W)
        local okB, wb = pcall(W.GetBottom, W)
        if not (okC and okT and okB and cb and wt and wb) then return "?" end
        -- Window bottom is the reference; child.bottom inside = positive.
        -- Use GetTop too, to confirm y-axis ordering (top > bottom) before
        -- trusting the subtraction: stale sizes can make the math lie.
        if not (wt > wb) then return "UNORDERED" end
        local d = wb - cb
        if d >= 0 then return ("inside +%.0f"):format(d) end
        return ("%.0f BELOW"):format(-d)
    end
    local function lvl(f)
        if f and f.GetFrameLevel then
            local ok, v = pcall(f.GetFrameLevel, f)
            if ok and v then return tostring(v) end
        end
        return "?"
    end
    local sl = W.sideList
    print(("  sideList: size=%s shown=%s vis=%s pts=%s box=%s lvl=%s"):format(
        dims(sl), tostring(sl and sl:IsShown()), tostring(sl and sl:IsVisible()),
        tostring(sl and sl:GetNumPoints() or 0), box(sl), lvl(sl)))
    print("  side: box=" .. box(W.side) .. " search=" .. box(W.search)
        .. " sb: shown=" .. tostring(W.scrollbar and W.scrollbar:IsShown())
        .. " size=" .. dims(W.scrollbar) .. " box=" .. box(W.scrollbar)
        .. " lvl=" .. lvl(W.scrollbar))
    print("  bottom edge: scroll=" .. vsBottom(W.scroll)
        .. " sb=" .. vsBottom(W.scrollbar)
        .. " (vs the window's bottom edge)")
    local nav = W.nav or {}
    print("  nav: " .. #nav)
    for i = 1, #nav do
        local nb = nav[i]
        local fontsz = "?"
        local t = nb.text
        if t and t.GetFont then
            local ok, _, sz = pcall(t.GetFont, t)
            if ok and sz then fontsz = tostring(sz) else fontsz = "NOFONT" end
        end
        print(("    %s text=%s vis=%s size=%s box=%s textBox=%s lvl=%s font=%s a=%s pts=%s"):format(
            tostring(nb.__key),
            tostring(t and t:GetText() or "nil"),
            tostring(nb:IsVisible()),
            dims(nb), box(nb), box(t), lvl(nb), fontsz,
            tostring((t and t.GetAlpha and t:GetAlpha()) or "?"),
            tostring((nb.GetNumPoints and nb:GetNumPoints()) or 0)))
    end
    print("  window box=" .. box(W) .. " scroll=" .. box(W.scroll)
        .. " view=" .. box(view))
    local tb = W.tabPool and W.tabPool[1]
    print("  control: side=" .. lvl(W.side) .. " W=" .. lvl(W)
        .. " scroll=" .. lvl(W.scroll) .. " view=" .. lvl(view)
        .. " tab=" .. lvl(tb) .. " tabTextFont="
        .. ((tb and tb.text and tb.text.GetFont)
            and (select(2, pcall(tb.text.GetFont, tb.text)) and "ok" or "NOFONT")
            or "?"))
    -- The minimap's SURFACE, when the complaint is "the glass is blank":
    -- every texture at least 60% of the disc, WITH ITS FILE PATH -- the
    -- path names the addon that put it there, and a solid full-disc
    -- texture is exactly what a gray minimap looks like. Children are
    -- walked too: a holder frame's background lives on the child, not on
    -- Minimap itself. This file never draws a background there, so the
    -- dump is what turns "still broken" into a name.
    local mm = _G.Minimap
    if mm then
        local okW, mw = pcall(mm.GetWidth, mm)
        local okH, mh = pcall(mm.GetHeight, mm)
        mw = (okW and mw) or 0
        mh = (okH and mh) or 0
        local okT, mtex = pcall(mm.GetTexture, mm)
        local okZ, zoom = pcall(mm.GetZoom, mm)
        local okM, mask = pcall(mm.GetMaskTexture, mm)
        print("  minimap: " .. ("%.0fx%.0f"):format(mw, mh)
            .. " shown=" .. tostring(mm:IsShown())
            .. " zoom=" .. (okZ and tostring(zoom) or "?")
            .. " ownTexture=" .. tostring(okT and mtex or "?")
            .. " mask=" .. (okM and tostring(mask) or "?"))
        local function bigRegions(host, tag)
            local okN, n = pcall(host.GetNumRegions, host)
            if not okN or type(n) ~= "number" then return end
            for i = 1, n do
                local r = select(i, host:GetRegions())
                if r and (not r.IsShown or r:IsShown()) then
                    local rw = (r.GetWidth and r:GetWidth()) or 0
                    local rh = (r.GetHeight and r:GetHeight()) or 0
                    if rw >= mw * 0.6 and rh >= mh * 0.6 then
                        local tex = (r.GetTexture and r:GetTexture()) or "?"
                        print(("    cover %s #%d %s %.0fx%.0f a=%s tex=%s"):format(
                            tag, i, tostring(r:GetObjectType()), rw, rh,
                            tostring((r.GetAlpha and r:GetAlpha()) or "?"),
                            tostring(tex)))
                    end
                end
            end
        end
        bigRegions(mm, "minimap")
        local okC, cn = pcall(mm.GetNumChildren, mm)
        if okC and type(cn) == "number" then
            for i = 1, cn do
                local c = select(i, mm:GetChildren())
                if c and (not c.IsShown or c:IsShown()) then
                    local nm = c.GetName and c:GetName() or "?"
                    bigRegions(c, "child:" .. tostring(nm))
                end
            end
        end
    else
        print("  minimap: NO Minimap frame")
    end
end

function ns.Options.Toggle()
    BuildIfNeeded()
    if not W then return false end
    if W:IsShown() then
        W:Hide()
        return false
    end
    W:ClearAllPoints()
    W:SetPoint("CENTER")
    W:Show()
    EnsureLayout()
    return true
end

function ns.Options.Show()
    BuildIfNeeded()
    if not W then return end
    W:Show()
    EnsureLayout()
end

