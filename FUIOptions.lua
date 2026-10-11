-- FUI-RestedXP FUIOptions.lua (standalone)
-- FUI-RestedXP FUIOptions.lua (standalone)
-- The settings pages backing the standalone options window (Options.lua):
-- Reskin, Map, Theme, Changelog, plus one appearance page per active
-- layout. The theme name used here is Fr33noX-UI, and the addon is
-- FUI-RestedXP.

local ADDON_NAME, ns = ...

local MODULE_KEY = "FUI-RestedXP"
local GROUP_KEY = "fuirestedxp"

local function DB() return ns.DB() end

-- Page config for the standalone window (no outside module system).
-- cfg.pages is unused here.
local cfg
local PAGES
local UpdateMapStatus

local LAYOUT_PAGE = {
    FRAMELESS = "Frameless",
    TIMELINE = "Timeline",
    COMPACT = "Compact",
    ZYGOR = "Zygor-style",
    BIT8 = "8-Bit",
    RAIL = "Rail",
}
-- The tab bar filters on it (Options.lua ReskinTabs): pick a layout and
-- only its appearance page stays visible next to Overview.
ns.LAYOUT_PAGE = LAYOUT_PAGE

local function RefreshPageList()
    if not cfg then return end
    local db = DB()
    local layoutPage = db and db.rxpEnabled and LAYOUT_PAGE[db.rxpLayout] or nil
end

-- Standalone: these two drive the real options window (Options.lua)
-- instead of a static tab bar -- a live rebuild of whatever is on screen.
local function RebuildOurPagesNow()
    if ns.Options and ns.Options.Refresh then ns.Options.Refresh() end
end

local function RebuildTabsNow()
    if ns.Options and ns.Options.Refresh then ns.Options.Refresh() end
end

-- Every write re-applies all modules (Theme, Skin, Reskin): changes show
-- live on the guide window. Toggling the engine also shows/hides its look
-- pages in this window's tab bar (and rebuilds the tab bar, above), and
-- toggling Follow accent refreshes the Theme page's STATUS note (its
-- "Color source" is computed at build time).
local function Set(key, value)
    DB()[key] = value
    ns.Refresh()
    if key == "rxpEnabled" or key == "rxpLayout" then
        RefreshPageList()
        RebuildTabsNow()
    end
    if key == "themeFollowAccent" then
        RebuildOurPagesNow()
        -- The custom color takes the accent's place (or hands it back):
        -- fan the new effective accent out to chrome, logo and route.
        if ns.OnAccentChanged then ns.OnAccentChanged() end
    end
    if key == "uiFont" then
        -- One font for the whole interface: rows pool their fontstrings, so
        -- a page redraw alone never re-SetFonts them -- repaint every one
        -- this addon has painted, live.
        if ns.RepaintFonts then ns.RepaintFonts() end
    end
    if key == "rxpMapRoute" or key == "rxpMapFuture" or key == "rxpMiniRoute"
        or key == "rxpOverlayFarm" or key == "rxpOverlayPatrol"
        or key == "rxpOverlaySearch" or key == "rxpOverlayAlpha" then
        -- The Map page's STATUS note reports the route live. Rebuilding the
        -- whole page here (the first version did) swaps the row out from
        -- under the click; writing to the note keeps the page still.
        if UpdateMapStatus then UpdateMapStatus() end
    end
    if key == "rxpEnabled" then
        -- The Reskin page's LAYOUT / ARROW blocks hide while the engine is
        -- off: rebuild the page on screen (and the tab list, above).
        RebuildOurPagesNow()
    end
    if key == "skinForceClassic" then
        -- RestedXP's v2 wipes the legacy window's scripts (OnUpdate, mouse):
        -- flipping this back needs a /reload for a clean restore either way.
        ns.Skin:Refresh()   -- runs ForceClassicWindow when v2 is on
    end
end

-- ---------------- Row helpers (widget cfg tables) ----------------
local function Toggle(text, key, tooltip)
    return {
        type = "toggle", text = text, tooltip = tooltip,
        getValue = function() return DB()[key] and true or false end,
        setValue = function(v) Set(key, v and true or false) end,
    }
end

local function Slider(text, key, minV, maxV, step)
    return {
        type = "slider", text = text, min = minV, max = maxV, step = step or 1,
        getValue = function() return DB()[key] or minV end,
        setValue = function(v) Set(key, v) end,
    }
end

local function Dropdown(text, key, list, tooltip)
    local values, order = {}, {}
    for _, o in ipairs(list) do
        values[o.value] = o.label
        order[#order + 1] = o.value
    end
    return {
        type = "dropdown", text = text, values = values, order = order,
        tooltip = tooltip,
        getValue = function() return DB()[key] end,
        setValue = function(v) Set(key, v) end,
    }
end

local function Fonts(text, key)
    return Dropdown(text or "Font", key, ns.GetFontOptions())
end

local function Color(text, prefix, hasAlpha, tooltip)
    return {
        type = "colorpicker", text = text, hasAlpha = hasAlpha, tooltip = tooltip,
        getValue = function()
            local d = DB()
            return d[prefix .. "R"] or 1, d[prefix .. "G"] or 1, d[prefix .. "B"] or 1,
                d[prefix .. "A"] or 1
        end,
        setValue = function(r, g, b, a)
            local d = DB()
            d[prefix .. "R"], d[prefix .. "G"], d[prefix .. "B"] = r, g, b
            if hasAlpha and a then d[prefix .. "A"] = a end
            ns.Refresh()
            -- The Theme page's custom color is the accent while Follow
            -- Accent is off: repaint everything that reads the accent,
            -- live, as the picker moves.
            if prefix == "theme" and ns.OnAccentChanged then
                ns.OnAccentChanged()
            end
        end,
    }
end

-- Sections: { "HEADER", left = {...}, right = {...} } stack each list down
-- its own side, rows pairing left-with-right.
local SPACER = { type = "spacer" }

-- The accent as a colour escape, lifted toward white the way every section
-- title wears it: the changelog's group titles and the HELP block's lead
-- words colour with the rest of the UI, live -- no hard-coded hue left to
-- drift when the accent (or the Theme page's custom colour) changes.
local function AccentTag()
    local r, g, b
    if ns.ViewBits and ns.ViewBits.AccentSoft then
        r, g, b = ns.ViewBits.AccentSoft()
    else
        r, g, b = ns.GetAccentColor()
    end
    return ("|cff%02x%02x%02x"):format(
        math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
end

local function Columns(section)
    local out = { section[1], accent = section.accent }
    local left, right = section.left or {}, section.right or {}
    for i = 1, math.max(#left, #right) do
        out[#out + 1] = left[i] or SPACER
        out[#out + 1] = right[i] or SPACER
    end
    return out
end

-- A free-text block (the changelog). A plain label is a single-line
-- FontString (SetWordWrap(false) + SetMaxLines(1)), so a paragraph in one row
-- would run off the right of the page instead of wrapping. Built here instead,
-- with the same geometry contract as a row (a TOPLEFT point at y, returns its
-- height) so Build stacks it like any other row. The text carries no "\n": it
-- wraps on its own width.
local function WrapNote(parent, y, cfg)
    local pad = 20
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(parent:GetWidth() - pad * 2, 20)
    frame:SetPoint("TOPLEFT", parent, "TOPLEFT", pad, y)
    local sz = cfg.size or 13
    local fs = frame:CreateFontString(nil, "OVERLAY")
    -- Through the shared factory: these notes used to inherit whatever
    -- font a bare FontString gets -- now the interface default, and they
    -- repaint with it like every other label.
    ns.ApplyFont(fs, nil, sz)
    local ind = cfg.indent or 0
    fs:SetPoint("TOPLEFT", frame, "TOPLEFT", ind, 0)
    fs:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    fs:SetJustifyH("LEFT")
    fs:SetJustifyV("TOP")
    fs:SetWordWrap(true)
    fs:SetText(cfg.text or "")
    local h = math.max(26, math.ceil(fs:GetStringHeight() or 20) + 12)
    frame:SetHeight(h)
    cfg._frame, cfg._fs = frame, fs
    if cfg.live then
        local acc = 0
        frame:SetScript("OnUpdate", function(_, dt)
            acc = acc + dt
            if acc < 1 then return end
            acc = 0
            if UpdateMapStatus then UpdateMapStatus() end
        end)
    end
    return frame, h
end

-- A page is a list of sections.
local function Build(W, parent, y, sections)
    if not sections then return y end
    for _, section in ipairs(sections) do
        local _, h
        if section[1] and type(section[1]) == "string" then
            h = 30
            y = y - h
        end
    end
    return y
end

-- ---------------- Pages ----------------
-- One APPEARANCE page per layout of the ported engine (the DB prefix p):
-- its fonts, sizes, fade, colors and toggles. `extra` adds layout-specific
-- sections at the end (8-Bit's pixel palette). Engine pages hide while the
-- engine is off (RefreshPageList).
local function LookPage(name, p, extra, noFonts)
    local page = { name = name, build = function()
        local fontRows = noFonts and {} or {
            Fonts("Body Font", p .. "Font"),
            Fonts("Bold Font", p .. "FontBold"),
        }
        local sections = {
            { "LAYOUT",
                left = {
                    fontRows[1] or SPACER,
                    fontRows[2] or SPACER,
                    Slider("Width", p .. "Width", 180, 600),
                    Slider("Number Column", p .. "NumCol", 12, 60),
                },
                right = {
                    Toggle("Show Objectives", p .. "Objectives",
                        "Lines like \"0/8 Canvas Scraps\" under the current step, with a thin progress bar."),
                    Toggle("Backdrop", p .. "Backdrop",
                        "The window's dark panel behind the text."),
                    Slider("Backdrop Opacity %", p .. "BackdropA", 0, 100),
                    Toggle("Step Label", p .. "StepLabel",
                        "The \"STEP 7\" label on cards, or the step row with its back / skip buttons."),
                    Toggle("List Numbers", p .. "ListNums",
                        "The upcoming steps' numbers."),
                },
            },
            { "TEXT SIZES",
                Slider("Zone Name", p .. "ZoneSize", 10, 40),
                Slider("Header", p .. "HeadSize", 8, 30),
                Slider("Current Step", p .. "CurSize", 8, 32),
                Slider("Upcoming Steps", p .. "TextSize", 8, 28),
                Slider("Step Numbers", p .. "NumSize", 6, 24),
                Slider("Objectives", p .. "ObjSize", 6, 24),
                Slider("Arrow Size", p .. "ArrowSize", 16, 64),
                Slider("Distance Text", p .. "DistSize", 8, 32),
                Slider("Arrow Text (step)", p .. "ArrowTextSize", 8, 28),
            },
            { "FADE",
                Slider("Fade per Step %", p .. "FadeStep", 0, 30),
                Slider("Faintest Step %", p .. "FadeMin", 0, 100),
            },
            { "COLORS",
                Color("Accent (levels, progress)", p .. "Accent", true),
                Color("Current Step", p .. "Cur", true),
                Color("Step Label & Warnings", p .. "StepCol", true),
                Color("Percent & Tips", p .. "PctCol", true),
                Color("Upcoming Steps", p .. "Text", true),
                Color("Step Numbers", p .. "Num", true),
                Color("Counter & Muted", p .. "Muted", true),
                Color("Zone Name", p .. "Zone", true),
                Color("Header Background", p .. "HeadBg", true),
                Color("Border", p .. "Border", true),
                Color("Bar Track", p .. "Track", true),
                Color("Arrow", p .. "Arrow", true),
                Color("Finished Bars & Tick", p .. "DoneCol", true),
                -- Enemy names: the profile write stays 6-digit hex, but
                -- the live recolour on our frames is an 8-digit escape, so
                -- the stored opacity shows there (and after /reload).
                Color("Enemy & Item Names", p .. "Enemy", true),
                -- 8-Bit edits its existing NPC colour here (same key as its
                -- 8-BIT block below used to); every other layout gets its own.
                Color("Friendly Names", (p == "rxpBt") and "rxpBtNpc" or (p .. "Friendly"), true,
                    "Friendly NPC and unit names (RestedXP's green), in this layout. Also written to RestedXP's own settings, so its window follows after a /reload."),
                Color("Notes & Warnings", p .. "Warn", true,
                    "Notes and warnings (RestedXP's yellow), in this layout. Also written to RestedXP's own settings, so its window follows after a /reload."),
            },
        }
        if extra then
            for _, s in ipairs(extra) do sections[#sections + 1] = s end
        end
        return sections
    end }
    page.engine = true   -- hidden while "Reskin RestedXP" is off
    return page
end

-- The changelog, newest first. One entry = one header row (version + date)
-- then one paragraph row. Those rows are `wrapnote` (WrapNote, above) and
-- One item per row, and the label becomes a title. The line break is a real
-- row, never a "\n": a row that carries a newline only ever showed its first
-- line, which is why the whole version used to be a single string wrapping as
-- one block. Each string below is one item; the page turns the leading
-- "Added:"/"Fixed:" into a header row and prints the rest as a bullet, so a
-- version reads as a titled list. Items are grouped by label, always in the
-- order Added, Modified, Changed, Fixed -- whatever order they were written
-- in -- and check_layouts.sh enforces both.
-- `buttons = true` is this file's own marker telling Build not to pair a row
-- with the next one (which also gives it the whole content width).
local CHANGELOG = {
    { "1.1.1", "2026-10-11",
        "Added: a +/- switch at the header's left, before the zone name, "
        .. "in every layout: minus folds the guide down to its header, plus "
        .. "unfolds it. Clicking the header itself still toggles too.",
        "Added: per-layout Friendly Names and Notes & Warnings colors, on "
        .. "each layout's COLORS page (8-Bit reuses its NPC color for the "
        .. "names). They recolor the window live and are written to "
        .. "RestedXP's own settings, so its window follows after a /reload, "
        .. "and the WaypointUI waypoint label follows them within a second.",
        "Added: WaypointUI support -- a \"WaypointUI (external arrow)\" "
        .. "style: it hides every arrow here and drives WaypointUI's "
        .. "waypoint from the guide's current step instead, with the "
        .. "waypoint label following the name colors.",
        "Changed: with that style but no WaypointUI installed, the "
        .. "layout's own arrow now shows instead of RestedXP's stock one.",
        "Changed: the route is now on by default, on the world map and "
        .. "the minimap, with 6 Upcoming Markers.",
        "Fixed: the objective icon boxes never gluing under the guide "
        .. "window on Timeline, where the glue never ran.",
        "Fixed: the stock arrow staying up next to WaypointUI's when "
        .. "WaypointUI loads after the guide.",
    },
    { "1.1.0", "2026-10-06",
        "Added: a route on the world map, on the MAP options page and off by "
        .. "default. A line from you to the guide's current target with a marker "
        .. "on it, drawn in the live accent -- so it changes color the moment "
        .. "you change the accent -- and, optionally, up to six of the following "
        .. "objectives chained after it, each one further ahead drawn smaller and "
        .. "dimmer, steps resolving to the same place sharing a single marker. It "
        .. "is a bearing, not a path: the game gives addons no roads to follow, so "
        .. "the line points at the objective rather than tracing a route to it. "
        .. "Nothing else here depends on it, and turning it off removes every "
        .. "frame it drew.",
        "Added: the same route on the minimap, under its own switch: a line "
        .. "from you to the current target with the chevrons running along it, "
        .. "the marker on the rim when the target lies off the glass, and the "
        .. "flow turning with \"Rotate minimap\". The current target is alone "
        .. "there -- the chain of following steps stays on the world map, where "
        .. "extra rings only read as noise.",
        "Added: Upcoming Markers, 0 to 6 following objectives chained behind "
        .. "the current target on the world map: each one further ahead drawn "
        .. "smaller and dimmer, steps resolving to the same place sharing one "
        .. "marker, and every marker's distance and arrival time adding up along "
        .. "the chain.",
        "Added: Chain Visibility, how present that chain is drawn against the "
        .. "current target, which always stays fully drawn.",
        "Added: Line Thickness and Flow Speed: one weight for the line on "
        .. "both surfaces at once, and how fast the chevrons travel along it.",
        "Added: the guide's own shapes drawn as an overlay layer under the "
        .. "route, each behind its own switch and color: Farm routes (a closed "
        .. "circuit with a node on every corner), Patrol paths (dashed), Search "
        .. "areas (a glow with a contour, world map only), and one Overlay "
        .. "opacity for all three.",
        "Added: marker tooltips on the world map: the step behind a marker "
        .. "with its headline and instructions, distance, direction and arrival "
        .. "time, the quest and its objectives, each line behind its own switch "
        .. "-- and off, the markers stop catching the mouse and clicks pass "
        .. "through to the map.",
        "Added: a help block on the MAP page spelling out how distance, "
        .. "direction, arrival time, units and freshness are measured.",
        "Added: a corpse run on both surfaces: dying swaps the route for a "
        .. "blood-red line back to your body with a skull on it, and the guide's "
        .. "shapes come down while you are a ghost.",
        "Added: an Arrow Shadow option in the Arrow block: a blurred copy of "
        .. "the arrow's icon under it, centred so it surrounds every side, with "
        .. "a Shadow Spread slider for the blur's width and a Shadow Color "
        .. "picker with opacity. It follows the style, turns with the arrow and "
        .. "never takes the icon's color; Card draws its own outline and is left "
        .. "alone. Off by default.",
        "Added: /fuirxp status reports the map route and how many upcoming steps "
        .. "it draws. With the map open it adds a map draw line naming every "
        .. "stage the drawing went through -- which map is shown, where the "
        .. "target was found and where it landed -- so a blank map can be "
        .. "reported without guessing.",
        "Added: a login warning when RestedXP's arrow frame is held "
        .. "transparent by something outside this addon: our arrow is drawn "
        .. "inside that frame, so while it is held down ours is simply not "
        .. "there. The warning names no one and offers no action -- it reports "
        .. "the symptom once, and /fuirxp status reports the frame itself, the "
        .. "way it already reports LiteTweaks.",
        "Modified: the OVERLAY section on the MAP page is reordered so every "
        .. "switch lines up with its own color, with the one shared opacity "
        .. "under the three.",
        "Modified: the minimap draws the current target alone -- the following "
        .. "steps no longer ring on the glass, where they read as noise in play; "
        .. "the chain lives on the world map.",
        "Modified: comments and chat lines across the addon now describe what "
        .. "happens instead of naming another addon, and /fuirxp status reports "
        .. "the arrow's frame in its own words.",
        "Changed: the old FutureSpots store was purged -- dead code from an "
        .. "earlier drawing pass; the chain draws the upcoming markers on its "
        .. "own.",
        "Fixed: an objective printed its count twice -- the guide's line "
        .. "already carries \"10/12 Name\" and the row printed the count "
        .. "again; the label now strips the embedded number so the count shows "
        .. "once.",
        "Fixed: the arrow's Time to Waypoint showed 61:01 past the hour, a "
        .. "duration that reads like a step number -- it now carries the hours "
        .. "(1:01:01), the way a timer does.",
    },
    { "1.0.3a", "2026-10-04",
        "Fixed: the bundled README described EllesmereUI as optional, while "
        .. "the TOC declared it a hard dependency. The README now states it as "
        .. "it is -- the addon had always required it. Nothing else changes.",
    },
    { "1.0.3", "2026-10-04",
        "Added: a Rail layout -- a vertical rail down the left with one marker "
        .. "per step, the guide's zone and progress at the top, and its own "
        .. "folded arrowhead whose darker half gives it relief.",
        "Added: a Rail Compass arrow style, the same shading inside a ring.",
        "Added: an option in General to keep the objective icons glued under "
        .. "the guide window or drag them anywhere; and Meters (m) on the Arrow "
        .. "is now reachable there too while the reskin is off.",
        "Added: /fuirxp status answers \"glue objective icons: on or off\", "
        .. "printed only while the reskin is on, like the other lines that "
        .. "only mean something then.",
        "Fixed: the quest icons (! and ?) never reached Rail, Compact or "
        .. "Zygor-style, and the Rail arrow ignored RestedXP's rotation.",
        "Fixed: the Rail's own line and step markers could disappear depending "
        .. "on which layout had been drawn before." },
    { "1.0.2", "2026-10-04",
        "Added: this Changelog page, with the installed version read from the addon.",
        "Fixed: the guide window can now be dragged all the way to the right "
        .. "edge of the screen, and the reskin layouts draw again after that." },
    { "1.0.1a", "2026-10-02",
        "Added: a custom 128x128 icon, a RXPGuides group, a Quests category in "
        .. "every supported language, and a localized Chinese title.",
        "Modified: RXPGuides and EllesmereUI are now hard dependencies, and the "
        .. "title is split so only \"EUI\" is colored." },
    { "1.0.1", "2026-10-01",
        "Fixed: deactivating the theme left the arrow tinted, because RestedXP "
        .. "never reset the vertex color and the active theme table still pointed "
        .. "at the old theme. Restoring now reloads the theme from the settings, "
        .. "repaints it, puts the vertex color back to white and reasserts the "
        .. "original texture (classic and V2)." },    { "1.0.0", "2026-10-01",
        "First public release on CurseForge: the RestedXP theme \"Fr33noX-UI by "
        .. "FUI-RestedXP\" derived from the accent, the reskin engine (five "
        .. "layouts plus RestedXP's own window), the navigation arrows (Chevron, "
        .. "distance-tinted Card, Classic 3D, Zygor-style) with meters and time to "
        .. "waypoint, a 256x256 high-quality arrow, /fuirxp status, the classic "
        .. "guide window option, the settings pages inside EllesmereUI and LICENSE.txt."
        ,
        "Fixed: the arrow tint no longer required the reskin, and deselecting "
        .. "the theme no longer risked a freeze." },
}

-- The version this copy reports to the client. GetAddOnMetadata is the old
-- global, which modern clients no longer expose (only C_AddOns has it there),
-- so both are tried; then the TOC is read directly; and as a last resort the
-- newest entry above. The page must never show "?".
-- The .toc / metadata lookup lives in Core (ns.InstalledVersion) so that
-- /fuirxp status and this page cannot drift apart again -- they did, and
-- status answered "?" forever. The changelog's own latest entry is the last
-- resort, for an addon whose metadata is unreadable.
local function InstalledVersion()
    local v = ns.InstalledVersion()
    if type(v) == "string" and v ~= "" and v ~= "?" then return v end
    return CHANGELOG[1][1]
end

-- The Map page's STATUS line: the switch, the slider, and what the drawing
-- pass has on the map RIGHT NOW. The last part is the reason this is a
-- function and not a string built at page-build time -- it belongs to the
-- pass, which starts and stops with the map behind this window. Read once
-- when the page was built, it would still claim "not drawn yet" with the
-- map wide open on the screen.
local mapStatusRow
local function MapStatusText()
    local db = DB() or {}
    local on = not not db.rxpMapRoute
    local mr = ns.MapRoute
    local wanted = mr and mr.chainWanted
    local drawn = mr and mr.chainDrawn
    local now
    if not on then
        now = "-"
    elseif wanted then
        now = string.format("%d/%d", drawn or 0, wanted)
        -- The setting counts markers AFTER the current target, so a number
        -- short of it has to say where the missing ones went: steps that
        -- resolve to the same spot as the one before them are ONE marker,
        -- not two stacked.
        local folded = mr.chainFolded or 0
        if folded > 0 then now = now .. " (+" .. folded .. " folded)" end
        local offMap = mr.chainOffMap or 0
        if offMap > 0 then now = now .. " (+" .. offMap .. " off map)" end
    else
        -- The route did not draw, and WHY beats "not yet": the state the
        -- last map pass ended on -- "no target yet", "no player
        -- position" -- is the answer to "why is my map blank?" while the
        -- map is open, and a map that was never opened says so itself.
        now = mr and mr.routeState and tostring(mr.routeState)
            or "not yet (open the map)"
    end
    -- The minimap half of the line, in the same breath: that pass runs
    -- whether the map is open or not, so its state IS the answer to "why
    -- is my minimap blank?" -- "drawn" means pixels are on the glass right
    -- now, and anything else is the stage the drawing stopped at.
    local mini
    if not db.rxpMiniRoute then
        mini = "off"
    elseif not (mr and mr.miniState) then
        mini = "on, not drawn yet"
    elseif mr.miniState == "drawn" then
        mini = "on, drawn"
    else
        mini = "on, " .. tostring(mr.miniState)
    end
    -- The shape layer (farm / patrol / search), in the same breath: how
    -- many shapes are on the map right now, or why none are -- switches
    -- off, the route that carries them off, or a guide without shapes.
    local ov
    local ovk = {}
    if db.rxpOverlayFarm then ovk[#ovk + 1] = "farm" end
    if db.rxpOverlayPatrol then ovk[#ovk + 1] = "patrol" end
    if db.rxpOverlaySearch then ovk[#ovk + 1] = "search" end
    if #ovk == 0 then
        ov = "off"
    elseif not on then
        ov = "on, waiting for the route"
    elseif mr and mr.overlayDrawn ~= nil then
        ov = (mr.overlayDrawn > 0) and (mr.overlayDrawn .. " drawn") or "on, none in this guide"
        -- The glass's own half, when the minimap route is on: a shape
        -- further out than the view radius is drawn on the map and left
        -- off the minimap on purpose. Saying the count here is what turns
        -- "glass 0" from "broken" into "out of reach".
        if db.rxpMiniRoute and mr.overlayMiniDrawn ~= nil then
            ov = ov .. ", glass " .. tostring(mr.overlayMiniDrawn)
        end
    else
        ov = "on, not drawn yet"
    end
    -- Four labels, each naming what it belongs to: the last one used to
    -- read "Drawn now" next to "Minimap: on, drawn", which reads as a
    -- contradiction when the map behind it is shut. It is the world map's
    -- CHAIN it is talking about, and now it says so.
    return ("|cff8c8c8cWorld map: %s|r  --  |cff8c8c8cMinimap: %s|r"
        .. "  --  |cff8c8c8cUpcoming markers: %d|r"
        .. "  --  |cff8c8c8cChain drawn: %s|r"
        .. "  --  |cff8c8c8cOverlays: %s|r"):format(
        on and "on" or "off", mini, tonumber(db.rxpMapFuture) or 0, now, ov)
end

-- Rewrite the note in place. The frame keeps its height so a longer answer
-- ("not yet (open the map)" against "-") does not hang past its row; STATUS
-- is the last row of its page, so nothing below it has to move.
UpdateMapStatus = function()
    local row = mapStatusRow
    local fs, frame = row and row._fs, row and row._frame
    if not (fs and frame) then return end
    local text = MapStatusText()
    if fs:GetText() ~= text then fs:SetText(text) end
    frame:SetHeight(math.max(26, math.ceil(fs:GetStringHeight() or 20) + 12))
end

PAGES = {   -- assigned to the local declared above (RefreshPageList closes over it)
    { name = "Reskin", build = function()
        local sections = {
            -- The master switch, alone at the top, with NO section title:
            -- the LAYOUT and ARROW blocks below only exist while it is on
            -- (Set rebuilds this page when it flips).
            {
                Toggle("Reskin RestedXP", "rxpEnabled",
                    "Master switch for the RestedXP reskin: the engine's own windows (Frameless, Timeline, Compact, Zygor-style, 8-Bit). Turning it off restores RestedXP's own look and hides the Layout and Arrow blocks here, and this addon's look pages from the tab bar."),
            },
        }
        if DB().rxpEnabled then
            sections[#sections + 1] = { "LAYOUT",
                left = {
                    Dropdown("Layout", "rxpLayout", {
                        { label = "Frameless (text on the world)", value = "FRAMELESS" },
                        { label = "Timeline (numbered line)", value = "TIMELINE" },
                        { label = "Compact (title bar, icons)", value = "COMPACT" },
                        { label = "Zygor-style (goals, tab)", value = "ZYGOR" },
                        { label = "8-Bit (pixel quest log)", value = "BIT8" },
                        { label = "Rail (vertical rail, one marker per step)", value = "RAIL" },
                        { label = "RestedXP's own window", value = "DEFAULT" },
                    }, "The guide window's look, the full layout set: Frameless, Timeline, Compact, Zygor-style and 8-Bit are the engine's own windows; DEFAULT hands everything back to RestedXP. The tab bar shows only the picked layout's appearance page."),
                    {
                        type = "slider", text = "Listed Steps", min = 0, max = 20, step = 1,
                        tooltip = "How many upcoming steps are listed under the current ones. 0 hides the list entirely -- the header's step count and percent still show where you are.",
                        getValue = function() return DB().rxpUpcoming or 8 end,
                        setValue = function(v) Set("rxpUpcoming", v) end,
                    },
                    Toggle("Fade Upcoming Steps", "rxpFade",
                        "Each step further ahead is a little dimmer (per-layout strength on its own page)."),
                },
            }
            sections[#sections + 1] = { "ARROW",
                left = {
                    Dropdown("Arrow Style", "rxpArrowStyle", {
                        { label = "Layout's own", value = "LAYOUT" },
                        { label = "Chevron", value = "CHEVRON" },
                        { label = "Card", value = "CARD" },
                        { label = "Classic (shaded 3D)", value = "CLASSIC" },
                        { label = "Zygor-style (arrowhead)", value = "ZYGOR" },
                        { label = "Rail (this theme's pointer)", value = "RAIL" },
                        { label = "Rail Compass (emblem)", value = "RAILC" },
                        { label = "WaypointUI (external arrow)", value = "WAYPOINT" },
                    }, "The waypoint arrow's look, in every layout -- changing it changes only the arrow. Layout's own: Chevron for Frameless and Compact, Card for Timeline, the Zygor-style arrowhead for Zygor-style, RestedXP's stock arrow for DEFAULT. Card and the Zygor-style arrowhead take their layout's colors; Card colors by distance (red over 100, yellow, green under 30). Rail is the default for the Rail layout: a folded arrowhead whose darker half gives it its relief. Rail Compass is the same shading wrapped in a ring -- handsome, but the ring disappears at 36 px, so it suits a still arrow better than a moving one. WaypointUI (external arrow): hides every arrow here and drives WaypointUI's waypoint from the guide's current step instead -- needs WaypointUI installed; without it the layout's own arrow shows instead."),
                    Toggle("Meters (m) on the Arrow", "rxpMeters",
                        "Rewrites the arrow's distance label from yards to meters. World of Warcraft's yard and meter are the same distance (1:1), so only the label changes, never the numbers."),
                },
                right = {
                    Toggle("Custom Arrow", "rxpArrow",
                        "The waypoint arrow drawn in the picked style. Off puts RestedXP's own arrow back (it then follows the Theme page's color)."),
                    Toggle("Time to Waypoint", "rxpArrowETA",
                        "Every custom arrow shows the time to the waypoint (\"1:23\" / \"45s\", in yellow), measured from how fast you have been closing in. Off shows the distance alone. The time only appears after you have moved toward the waypoint, and clears when you stand still. (RestedXP's stock arrow, DEFAULT layout, doesn't show it.)"),
                    Toggle("Arrow Shadow", "rxpArrowShadow",
                        "A stack of copies of the picked icon drawn under it, centred and spread past it on every side, feathering out into a soft blurred edge so the arrow reads over a bright map. It follows the style, turns with the arrow and never takes its colour. Card draws its own outline and is left alone. Off by default; the blur's width and the colour are set just below."),
                    {
                        type = "slider", text = "Shadow Spread", min = 0, max = 20, step = 1,
                        tooltip = "How far the shadow reaches past the arrow's icon on every side, in pixels -- and how wide it feathers out: the blur runs across this whole width, from solid next to the icon to nothing at the edge. 0 tucks it behind the icon, 6 (the default) is a soft rim, 15 and up is a wide blurred halo. It grows in place -- the shadow never moves off centre.",
                        getValue = function() return DB().rxpArrowShadowSize or 6 end,
                        setValue = function(v) Set("rxpArrowShadowSize", v) end,
                    },
                    Color("Shadow Color", "rxpArrowShadow", true,
                        "The shadow's colour and opacity: black at 75% by default; the stack reaches exactly this alpha beside the icon and fades to nothing at the outer edge. A dark version of the accent colour also works over bright ground. Nothing shows until the spread slider pushes the shadow out from behind the icon."),
                },
            }
        end
        -- The map route has a page of its own ("Map", below), because it is
        -- the one feature here that draws on a surface nothing else touches:
        -- Reskin drives the guide window, Theme drives the colors, and the
        -- map keeps its own switch, its own chain sizes and its own status.
        sections[#sections + 1] = { "GUIDE WINDOW",
            Toggle("Classic Guide Window", "skinForceClassic",
                "Keeps RestedXP's own Guide Window v2 (Interface V2, Beta) off: it hides and strips the classic window entirely, so every layout would have nothing to read. Turning it back on needs a /reload (RestedXP itself reloads when its own v2 toggle flips); turning it off also needs a /reload for v2 to take over."),
        }
        local general = {
            Toggle("Disable Announcements", "rxpNoAnnounce",
                "Keeps all of RestedXP's Announce options off (level ups in emote, party and guild chat; step completion, collection and flying timers), every login."),
        }
        -- Two consecutive widgets share a row (Build pairs section[i] with
        -- section[i+1]). Exactly one of these two belongs there, so the row
        -- next to "Disable Announcements" is always full and never leaves an
        -- orphan below:
        --   reskin on  -> the icon boxes are ours to place, so the glue option
        --                 is the one that has an effect (we only reposition
        --                 them while the engine is on).
        --   reskin off -> nothing places them for us, the glue option would be
        --                 inert, and the metres toggle moves in from the Arrow
        --                 block, which does not exist.
        if DB().rxpEnabled then
            general[#general + 1] = Toggle("Glue the objective icons to the guide window", "rxpBoxLock",
                "On (the default): the objective icons -- the target and item boxes -- stay glued under the guide window and follow it down the screen. Off: drag them anywhere with the left button and they stay there, in every layout and between sessions. This applies to every layout, not just Rail.")
        else
            general[#general + 1] = Toggle("Meters (m) on the Arrow", "rxpMeters",
                "Rewrites the arrow's distance label from yards to meters. World of Warcraft's yard and meter are the same distance (1:1), so only the label changes, never the numbers. Shown here because the Arrow block is hidden while the reskin is off.")
        end
        sections[#sections + 1] = { "GENERAL", unpack(general, 1, #general) }
        sections[#sections + 1] = { "RESET",
            {
                type = "button", text = "Reset to Defaults", width = 170,
                tooltip = "Restores every FUI-RestedXP setting: layout, arrow style, colors, sizes, fonts, opacity, theme color source, and RXP's window scale back to 100%. RestedXP's own settings (window position, guides) are untouched.",
                onClick = function()
                    ns.ResetAll()
                    RefreshPageList()   -- defaults have the engine on: its pages come back
                    RebuildTabsNow()
                    RebuildOurPagesNow()   -- the LAYOUT / ARROW blocks come back
                    print(ns.AccentHex() .. "FUI-RestedXP|r: settings reset to defaults.")
                end,
            },
        }
        return sections
    end },

    LookPage("Frameless", "rxpFl"),
    LookPage("Timeline", "rxpTl"),
    LookPage("Compact", "rxpCp"),
    LookPage("Zygor-style", "rxpZg"),
    LookPage("8-Bit", "rxpBt", {
        { "8-BIT",
            left = {
                Toggle("Previous Step (struck through)", "rxpBtShowDone",
                    "Shows the step before the current one, struck through."),
                Toggle("CRT Scanlines", "rxpBtScan",
                    "The CRT scanlines over the window."),
            },
            right = {
                Color("Window", "rxpBtBg", true),
                -- Item / NPC / verb names: baked into 8-digit |cAARRGGBB
                -- escapes on our frames, so the stored opacity shows.
                -- (RestedXP's own profile write stays 6-digit.)
                Color("Item Names", "rxpBtItem", true),
                Color("Verbs (Kill, Loot...)", "rxpBtVerb", true),
            },
        },
    }, true),

    LookPage("Rail", "rxpRl"),

    -- The Map page sits here on purpose: after the reskin's look page when
    -- the reskin is on, and -- RefreshPageList having dropped that page from
    -- the tab bar -- straight after Reskin when it is off. One position in
    -- this list is both orders, because the look pages live above it.
    { name = "Map", build = function()
        -- The STATUS row is handed to the ticker above, which rewrites it
        -- while the page is open: what it reports starts and stops with the
        -- map drawing behind this window.
        local statusRow = { wrapnote = true, buttons = true, live = true,
            text = MapStatusText() }
        mapStatusRow = statusRow
        return {
            { "ROUTE",
                left = {
                    Toggle("Route on the world map", "rxpMapRoute",
                        "Draws the guide's route straight on the world map: a line from you to the current target, a marker on it, and (with Upcoming Markers below) the following objectives in the chain. Everything is drawn in the color chosen on the Theme page -- the live accent while \"Follow Accent\" is on there -- so it changes when that page changes, and never with the overlay colors below. This is a bearing, not a path: the game gives addons no roads to follow, so the line points at the objective rather than tracing a route to it. On by default -- it does not touch the guide window, and turning it off removes everything it drew."),
                    {
                        type = "slider", text = "Chain Visibility", min = 0.15, max = 1, step = 0.05,
                        tooltip = "How present the chain of upcoming steps is, against the current target which is always fully drawn. The first link of the chain is drawn at this value and each following one fades towards half of it, spread over however many markers Upcoming Markers asks for -- two markers or six both start bright and end dim. A link's line, chevrons and marker all share that one alpha. Lower it to keep the route readable on busy maps, raise it when planning further ahead.",
                        getValue = function() return DB().rxpMapChainAlpha or 0.55 end,
                        setValue = function(v) Set("rxpMapChainAlpha", v) end,
                    },
                    {
                        type = "slider", text = "Line Thickness", min = 0.5, max = 2, step = 0.05,
                        tooltip = "How heavy the route's line is, on BOTH surfaces at once: the world map and the minimap draw the same weight, so one control moves the two together and they can never disagree. 1.00 is the line as it ships -- the thin style this route draws by default -- and the value multiplies the stroke and its dark outline together so they stay one pen stroke rather than a fat core with a hairline around it; the world map's zoom boost still rides on top of it. Chevrons and markers keep their own sizes: this is the line alone.",
                        getValue = function() return DB().rxpMapThickness or 1 end,
                        setValue = function(v) Set("rxpMapThickness", v) end,
                    },
                },
                right = {
                    Toggle("Route on the minimap", "rxpMiniRoute",
                        "The same route on the minimap: a line from you -- the minimap is centred on you -- to the current target, the chevrons running along it, and the marker on it. A target further out than the minimap can show puts that marker ON THE RIM, which is what a rim marker means: that way, past this edge. The upcoming steps do NOT ring here: the glass keeps the current target and nothing else -- those extra dots read as noise in play, so the chain is drawn on the world map only. Same color and same flow speed as the world map route, and it turns with the minimap when \"Rotate minimap\" is on. It draws whether the map is open or not. On by default: the minimap is a surface this addon does not own."),
                    {
                        type = "slider", text = "Upcoming Markers", min = 0, max = 6, step = 1,
                        tooltip = "How many markers to draw after the current target, on the world map, which draws the chain in full. The minimap draws the current target alone -- extra rings there read as noise -- so this setting leaves it alone. The chain looks past steps that carry no position of their own until the count is filled, so this number is what you should see on the map; a step on a map with no shared continent, and two steps resolving to the same place, still collapse into the previous marker. Each upcoming marker reports the WHOLE route to it -- its distance and its arrival time add up along the chain, the way you would actually walk them. /fuirxp status reports chain=drawn/wanted.",
                        getValue = function() return DB().rxpMapFuture or 0 end,
                        setValue = function(v) Set("rxpMapFuture", v) end,
                    },
                    {
                        type = "slider", text = "Flow Speed", min = 0, max = 1.5, step = 0.05,
                        tooltip = "How fast the chevrons travel along the route. 0 stops them and leaves a plain line; 0.5 is the value this route was drawn against; much above 1 the travel per refresh grows longer than the gap between them and the flow starts to read as stuttering.",
                        getValue = function() return DB().rxpMapFlowSpeed or 0.5 end,
                        setValue = function(v) Set("rxpMapFlowSpeed", v) end,
                    },
                },
            },
            { "OVERLAY",
                left = {
                    Toggle("Farm routes", "rxpOverlayFarm",
                        "The guide's farming circuits drawn as a mint, closed route with a small node on each corner -- where RestedXP means you to WORK an area rather than walk through it. It is the guide's own #loop data, projected by the same calls the route above it uses, and it draws UNDER the route so the bearing always stays on top. It rides the route's own life: the shapes draw while \"Route on the world map\" draws, and switch off with it. A guide with no circuits draws nothing."),
                    Toggle("Patrol paths", "rxpOverlayPatrol",
                        "Where something walks, dashed in amber: 14 px of line, a 9 px gap, repeating -- the rhythm that reads as \"a mob roams here\" rather than as another route to follow. Same data source, same pass, same rule underneath the route."),
                    Toggle("Search areas", "rxpOverlaySearch",
                        "Ground to comb, in pale blue: a soft glow filling the area's bounding box with a brighter contour around it (42 px minimum so a tight area still reads as ground). The fill stays under half opacity whatever the slider says, so the map underneath remains readable. World map only -- a fill this size would be a smudge on the minimap."),
                },
                right = {
                    -- The three colors first: each toggle on the left then
                    -- lines up with its own color on this side, and the
                    -- opacity for all of them sits under the three.
                    -- Overlay colours: per-kind opacity, multiplied with the
                    -- "Overlay Opacity" slider and the distance fade.
                    Color("Farm routes color", "rxpOverlayFarm", true,
                        "The color of the farm circuits and their corner nodes, on both surfaces. This one is yours: it does NOT follow the Theme page -- the route keeps the Theme page's color and the shapes keep these three, so the layers can be told apart on any theme. Shown live while the map draws."),
                    Color("Patrol paths color", "rxpOverlayPatrol", true,
                        "The color of the patrol dashes, on both surfaces. Independent of the Theme page's route color and of the two colors above. Shown live while the map draws."),
                    Color("Search areas color", "rxpOverlaySearch", true,
                        "The color of the search areas -- the contour and its soft fill, world map only. Independent of the Theme page's route color and of the two colors above. Shown live while the map draws."),
                    {
                        type = "slider", text = "Overlay opacity", min = 0.2, max = 1, step = 0.05,
                        tooltip = "One opacity for every overlay, both surfaces: the farm circuit and its nodes, the patrol dashes, the search contour and its fill (the fill keeps its own lower cap on top of this). The route keeps its own weight -- Line Thickness -- and its own Chain Visibility; this slider moves the shape layer alone. 0.80 ships.",
                        getValue = function() return DB().rxpOverlayAlpha or 0.8 end,
                        setValue = function(v) Set("rxpOverlayAlpha", v) end,
                    },
                },
            },
            { "TOOLTIP ON WORLD MAP",
                left = {
                    Toggle("Show marker tooltips", "rxpTipOn",
                        "The box that appears when the cursor rests on a marker: which marker it is, what the step asks for, how far away it is and the quest behind it. Off takes every group below off at once -- and the markers stop catching the mouse altogether, so a click passes straight through to the map underneath."),
                    Toggle("Step title", "rxpTipTitle",
                        "The step's HEADLINE, in pale gold: the title the guide gives it when it has one (the words RestedXP puts on its arrow), otherwise its first instruction line -- \"Kill 10 Lizards\". That line belongs to THIS switch alone: with it off, the headline disappears instead of moving into Instructions."),
                    Toggle("Instructions (what to do)", "rxpTipText",
                        "The step's instruction lines under the headline, in white (four in all, headline included). This switch never shows the headline on its own: with \"Step title\" off, the headline is not shown at all, and neither switch can print the other's line."),
                    Toggle("Distance, direction, ETA", "rxpTipNav",
                        "The navigation line: \"243 yd - NE - ETA ~35s\". The distance is measured along the ROUTE for an upcoming marker (it adds up through the steps before it), the direction is where the marker lies from you with north at the top of the map, and the arrival time is estimated at 7 yd/s on foot, 14 mounted. Coloured by distance: green under 30, yellow to 100, red beyond. The unit follows Meters (m) on the Arrow."),
                    Toggle("Quest details", "rxpTipQuest",
                        "The quest behind the marker: its title, its level in the quest log's difficulty colour, where it stands (not in the log / in the log / ready to turn in / completed), its objectives with their counters, and its id."),
                },
                right = {
                    Toggle("Marker & step header", "rxpTipHeader",
                        "The golden first line -- \"Current target\" or \"Next +2\" -- with the step number it belongs to: which marker of the chain you are pointing at."),
                    Toggle("NPC or item name", "rxpTipTarget",
                        "The NPC or the item the marker points at (\"NPC: Hogger\", \"Item: Linen Cloth\"). RestedXP only names the target of the step it is actively on, so markers further down the chain usually show no line at all."),
                    Toggle("Step type with icon", "rxpTipType",
                        "What kind of step this is, in words -- \"Type: Accept quest\" -- with RestedXP's own icon for it before the text."),
                    Toggle("Zone & instance", "rxpTipZone",
                        "The zone the marker sits in, and \"Instance: The Deadmines\" when it sits in a dungeon rather than a zone."),
                },
            },
            { "STATUS", statusRow },
            { "HELP: DISTANCE & ETA",
                { wrapnote = true, buttons = true,
                    text = AccentTag() .. "Distance|r -- a straight line, as the crow flies: the game gives an addon no roads, so every number is the length of a segment between two points, never a walking route. Both ends -- you and the marker -- are converted to world coordinates through Blizzard's own map API on the map you are looking at, which is what keeps them comparable at any zoom and on any zone." },
                { wrapnote = true, buttons = true,
                    text = AccentTag() .. "Upcoming markers|r -- the numbers ADD UP along the chain: the first marker reports the way from you to it, the second the way from you to the first plus the first to the second, and so on -- the walk you would really make. When one leg cannot be measured (a position off the map, another continent, or no player position on the displayed map) the total stops there and the markers after it fall back to their own straight line: a missing number rather than a wrong one." },
                { wrapnote = true, buttons = true,
                    text = AccentTag() .. "Direction|r -- read from the map itself (x runs east, y runs south, north at the top), so N / NE / E ... says where the marker sits FROM YOU on the screen. It is deliberately not cumulative: each marker gives its own bearing, because that is the way you turn to face it." },
                { wrapnote = true, buttons = true,
                    text = AccentTag() .. "Arrival time|r -- the distance divided by an assumed pace: 7 yd/s on foot, 14 yd/s mounted. The pace is assumed rather than measured on purpose -- GetUnitSpeed() can answer a protected number on this client, and a protected value may not be used in arithmetic. The tilde is therefore honest: an estimate, not a schedule, driven by the same distance as above (cumulative for an upcoming marker)." },
                { wrapnote = true, buttons = true,
                    text = AccentTag() .. "Unit, colour and freshness|r -- yards or metres follow Meters (m) on the Arrow: WoW's yard and metre are the same distance (1:1), so only the label changes, and above 1000 metres it reads in km. The colour is the arrow card's own scale -- green under 30, yellow to 100, red beyond. The route is redrawn ten times a second while the world map is open, so all three follow you as you move." },
            },
        }
    end },

    { name = "Theme", build = function() return {
        { "RXP THEME",
            left = {
                Dropdown("Default Font", "uiFont", ns.GetFontOptions(true),
                    "The font this whole interface follows: this window's labels, titles and buttons, the arrow cards, and every guide-window look on \"FUI Global Font\" -- their default, so one pick restyles them all. Overpass ships as this setting's value. A look that pins a file of its own keeps that choice; 8-Bit is always its pixel fonts."),
                Toggle("Follow Accent", "themeFollowAccent",
                    "When on, everything this addon colors (the RXP theme, the classic reskin panels, the arrow tint) derives from the live accent color: change the accent and the guide follows. When off, the custom color below is used instead."),
                -- The custom accent stays opaque: the accent pipeline
                -- (chat hex, logo, chrome) is RGB-only.
                Color("Custom Color", "theme"),
                {
                    type = "button", text = "Activate in RestedXP", width = 170,
                    tooltip = "Selects the theme \"Fr33noX-UI by FUI-RestedXP\" in RestedXP's settings (Guide Window > Theme). Without this, the theme tables update but RXP keeps another theme selected.",
                    onClick = function()
                        if ns.Skin and ns.Skin.ActivateTheme and ns.Skin:ActivateTheme() then
                            print(ns.AccentHex() .. "FUI-RestedXP|r: theme activated in RestedXP.")
                            RebuildOurPagesNow()
                        else
                            local rxp = ns.GetRXP and ns.GetRXP()
                            if not (rxp and rxp.settings) then
                                print(ns.AccentHex()
                                    .. "FUI-RestedXP|r: RestedXP not loaded (or its settings are not initialized yet)."
                                    .. " Open RestedXP's settings once, then retry.")
                            elseif not _G.RXPFrame then
                                print(ns.AccentHex()
                                    .. "FUI-RestedXP|r: RestedXP loaded but no guide window yet"
                                    .. " (enable the Guide Window in RXP's settings).")
                            else
                                print(ns.AccentHex()
                                    .. "FUI-RestedXP|r: could not set the theme (unknown state).")
                            end
                        end
                    end,
                },
            },
            right = {
                -- Three rows of air, then Deactivate lands ON THE SAME LINE
                -- as Activate (left row 4): both buttons side by side.
                SPACER,
                SPACER,
                SPACER,
                {
                    type = "button", text = "Deactivate in RestedXP", width = 170,
                    tooltip = "Hands the guide window back to RestedXP's own stock theme (RXP Blue). Use this to turn the skin off; the arrow tint stands down with it.",
                    onClick = function()
                        if ns.Skin and ns.Skin.DeactivateTheme and ns.Skin:DeactivateTheme() then
                            print(ns.AccentHex() .. "FUI-RestedXP|r: RestedXP's own theme restored (RXP Blue).")
                            RebuildOurPagesNow()
                        else
                            print(ns.AccentHex()
                                .. "FUI-RestedXP|r: RestedXP not loaded (or its settings are not initialized yet)."
                                .. " Open RestedXP's settings once, then retry.")
                        end
                    end,
                },
            },
        },
        { "STATUS",
            {
                type = "note",
                text = ("|cff8c8c8cTheme: %s|r -- |cff8c8c8cColor source: %s|r"):format(
                    (ns.Skin and ns.Skin.IsThemeActive and ns.Skin:IsThemeActive())
                        and "|cff00ff25active in RestedXP|r"
                        or "|cffff5722not selected in RestedXP|r",
                    DB().themeFollowAccent and "accent (live)" or "custom color"),
            },
        },
    } end },

    -- Last tab on purpose: a read-only page, nothing to set from it.
    { name = "Changelog", build = function()
        local section = { "CHANGELOG" }
        -- Two margins, one per level: a group title sits one step under the
        -- version line, a bullet one more step under its title. Values are
        -- pixels from the panel margin, so both are tunable in one place.
        local IND_TITLE, IND_ITEM = 14, 30
        -- The release number and its date get their own size, so a version is
        -- found before reading it. Everything below stays at the default 13.
        local VER_SIZE = 16
        -- Group titles wear the live accent, lifted like every section
        -- title: LABEL_HEX is AccentTag() at page-build time, so the
        -- changelog colours with the rest of the UI and cannot drift.
        local LABEL_HEX = AccentTag()
        section[#section + 1] = { wrapnote = true, buttons = true,
            text = ns.AccentHex() .. "Version installée : " .. InstalledVersion() .. "|r" }
        for _, rel in ipairs(CHANGELOG) do
            section[#section + 1] = { wrapnote = true, buttons = true,
                size = VER_SIZE,
                text = ns.AccentHex() .. rel[1] .. "|r  |cff8c8c8c" .. rel[2] .. "|r" }
            -- From 3: [1] is the version and [2] the date. Each item becomes its own
            -- row. The leading "Added:"/"Fixed:" is not printed inside the
            -- item: it becomes a header row of its own, emitted only when the
            -- label changes, so a run of items reads as a list under a single
            -- title. An item with no label (the 1.0.0 lead paragraph) is drawn
            -- as a plain paragraph, with no title and no bullet.
            local lastLabel
            for i = 3, #rel do
                local label, text = rel[i]:match("^(%a+):%s+(.*)$")
                if label then
                    if label ~= lastLabel then
                        lastLabel = label
                        section[#section + 1] = { wrapnote = true, buttons = true,
                            indent = IND_TITLE,
                            text = LABEL_HEX .. label .. "|r" }
                    end
                    section[#section + 1] = { wrapnote = true, buttons = true,
                        indent = IND_ITEM,
                        text = "|cffb0b0b0- " .. text .. "|r" }
                else
                    section[#section + 1] = { wrapnote = true, buttons = true,
                        indent = IND_TITLE,
                        text = "|cffb0b0b0" .. rel[i] .. "|r" }
                end
            end
        end
        return { section }
    end },
}

local function BuildPage(pageName, parent, yOffset)
    return 100
end

local function Config()
    cfg = {
        title = "FUI-RestedXP",
        description = "Standalone theme and reskin for RestedXP Guides: custom accent color, guide-window layouts, step animations and real navigation arrows.",
        searchTerms = { "fuirestedxp", "restedxp", "rxp", "reskin", "theme", "meters", "yards", "arrow", "frameless", "timeline", "compact", "zygor", "8-bit", "map", "world map", "route", "navigation" },
        buildPage = BuildPage,
    }
    RefreshPageList()
    return cfg
end

-- ---------------- Sidebar + registration ----------------
local function InstallSidebar()
    return false
end

local registered, ticker = false, nil

local function Register()
    if registered then return true end
    if not InstallSidebar() then
        return false
    end
    return false
end

-- /fuirxp prefers the standalone options window first.
function ns.OpenSettings()
    if ns.Options and ns.Options.Show then
        ns.Options.Show()
        return true
    end
    return false
end

-- standalone: no outside sidebar or module registration.

-- The options window (Options.lua) consumes the pages above through this
-- door: { name, build() -> sections, engine? } per page.
ns.FUIPages = PAGES

-- Exposed for the LiteTweaks conflict warning's click action (Core.lua):
-- flipping rxpEnabled from chat must rebuild the tab list and the pages
-- exactly as the options toggle does (RefreshPageList / RebuildTabsNow /
-- RebuildOurPagesNow are file-locals, so this is their one public door).
function ns.FUIOptionsChanged()
    RefreshPageList()
    RebuildTabsNow()
    RebuildOurPagesNow()
end
