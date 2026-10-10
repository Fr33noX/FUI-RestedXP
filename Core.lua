-- FUI-RestedXP Core.lua
-- Saved variables, the live accent color, module plumbing and
-- the slash command. Structure: a flat DB of
-- defaults, modules with a Refresh function, everything re-applied on
-- change.

local ADDON_NAME, ns = ...
ns.ADDON = ADDON_NAME

local FONT_DIR = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Fonts\\"
ns.FONT = FONT_DIR .. "Expressway.ttf"
ns.FONT_BOLD = FONT_DIR .. "ExpresswayBold.ttf"
ns.FONT_OVERPASS = FONT_DIR .. "OverpassRegular.ttf"
-- No Avant Garde: its file carried a commercial (ParaType/ITC) license
-- and no longer ships. The literal path below only serves migrating
-- saved settings that still point at it.
-- The "FUI Global Font" sentinel: follows the Theme page's Default Font
-- (the value string predates the rename and stays "euiGlobal" so saved
-- settings keep working); ns.ResolveFont turns it into the current file.
ns.FUI_FONT = "euiGlobal"

ns.IsSecret = issecretvalue or function() return false end

-- A font setting as a file: "FUI Global Font" (or none) follows the
-- Theme page's "Default Font" -- Overpass by default -- while a file
-- a look pinned (a Body/Bold you chose; 8-Bit's pixel fonts are forced in
-- the palette) returns below untouched. The EllesmereUI branch only
-- covers a DB that has not been seeded yet.
function ns.ResolveFont(font)
    if font == nil or font == ns.FUI_FONT then
        local db = ns.DB and ns.DB()
        local ui = db and db.uiFont
        if ui and ui ~= ns.FUI_FONT then return ui end
        local E = _G.EllesmereUI
        local path = E and type(E.GetFontPath) == "function" and E.GetFontPath(nil)
        return path or ns.FONT
    end
    return font
end

-- SetFont that never leaves a FontString fontless: a missing file (a font
-- from another addon that was removed) falls back to Expressway. `path`
-- may be FUI_FONT or nil: the addon's Global Font.
-- Outlines are slug outlines: the SLUG flag rides along with
-- OUTLINE/THICKOUTLINE and the string switches to per-vertex scale
-- animation, which is what actually smooths the edge on this client.
--
-- Every fontstring painted here is remembered with its arguments (weak
-- keys: a collected string drops its entry): the Theme page's "Default
-- Font" repaints them all live -- rows pool their fontstrings, so no
-- page redraw re-SetFonts them.
local fontUsers = setmetatable({}, { __mode = "k" })

local ScaleMode = Enum and Enum.FontStringScaleAnimationMode
function ns.ApplyFont(fs, path, size, flags)
    size = size or 12
    flags = flags or ""
    if flags ~= "" and flags ~= "NONE" and not flags:find("SLUG") then
        flags = flags .. "|SLUG"
    end
    fontUsers[fs] = { path = path, size = size, flags = flags }
    local ok, res = pcall(fs.SetFont, fs, ns.ResolveFont(path), size, flags)
    if not ok or res == false then
        pcall(fs.SetFont, fs, ns.FONT, size, flags)
    end
    if fs.SetScaleAnimationMode and ScaleMode then
        pcall(fs.SetScaleAnimationMode, fs, flags:find("SLUG") and ScaleMode.Vertex or ScaleMode.FontSize)
    end
end

-- Re-apply every remembered fontstring (the default-font fan-out). Safe
-- during iteration: an existing key's value is replaced, no key is added.
function ns.RepaintFonts()
    for fs, m in pairs(fontUsers) do
        ns.ApplyFont(fs, m.path, m.size, m.flags)
    end
end

-- Fire-orange accent used as fallback when EllesmereUI is absent: the
-- default that paints every slide, toggle, the active page and the logo.
ns.FALLBACK_ACCENT = {1, 0.42, 0.08} -- #FF6B14

-- Read the live accent color out of EllesmereUI without touching anything
-- else. Returns r, g, b (0-1). Safe to call at any time.
function ns.GetAccentColor()
    -- While Follow Accent is off, the Theme page's custom color IS the
    -- accent -- for everything: window chrome, logo, route, chat hex. One
    -- effective accent wherever it comes from, so a single toggle (or the
    -- custom color itself) re-paints the whole addon at once.
    local db = ns.DB and ns.DB()
    if db and db.themeFollowAccent == false then
        return db.themeR or 1, db.themeG or 0.42, db.themeB or 0.08
    end
    local suite = _G.EllesmereUI
    if suite and suite.ELLESMERE_GREEN then
        local c = suite.ELLESMERE_GREEN
        return c.r or 1, c.g or 0.42, c.b or 0.08
    end
    return ns.FALLBACK_ACCENT[1], ns.FALLBACK_ACCENT[2], ns.FALLBACK_ACCENT[3]
end

-- The installed version, read the same way everywhere. The global
-- GetAddOnMetadata does not exist on every client (this one has neither it
-- nor its C_AddOns form), so a lookup that only tries the APIs answers "?"
-- forever; falling back to the .toc keeps /fuirxp status and the Changelog
-- page honest. Returns "?" only if nothing at all answers.
function ns.InstalledVersion()
    -- ADDON_NAME is the folder name too, so it doubles as the .toc path.
    local key = (type(ADDON_NAME) == "string" and ADDON_NAME ~= "") and ADDON_NAME or ns.ADDON
    local apis = {}
    if C_AddOns and C_AddOns.GetAddOnMetadata then apis[#apis + 1] = C_AddOns.GetAddOnMetadata end
    if GetAddOnMetadata then apis[#apis + 1] = GetAddOnMetadata end
    for _, api in ipairs(apis) do
        if type(key) == "string" and key ~= "" then
            local ok, v = pcall(api, key, "Version")
            if ok and type(v) == "string" and v ~= "" then return (v:gsub("%s+$", "")) end
        end
    end
    if type(key) == "string" and key ~= "" then
        local toc = "Interface\\AddOns\\" .. key .. "\\" .. key .. ".toc"
        local ok, fh = pcall(io.open, toc, "r")
        if ok and fh then
            local found = tostring(fh:read("*a") or ""):match("##[ \t]*Version:%s*([^\r\n]+)")
            pcall(fh.close, fh)
            if found and found ~= "" then return (found:gsub("%s+$", "")) end
        end
    end
    return "?"
end

-- Hex prefix (|cffRRGGBB) for the live accent.
function ns.AccentHex()
    local r, g, b = ns.GetAccentColor()
    return ("|cff%02x%02x%02x"):format(
        math.floor(r * 255 + 0.5),
        math.floor(g * 255 + 0.5),
        math.floor(b * 255 + 0.5))
end

-- Per-component DB color lookup with fallback:
-- Color("rxpBg", 0.05, 0.05, 0.05, 0.7) reads rxpBgR/G/B/A).
function ns.Color(prefix, r, g, b, a)
    local db = ns.DB()
    return db[prefix .. "R"] or r, db[prefix .. "G"] or g,
        db[prefix .. "B"] or b, db[prefix .. "A"] or a
end

-- The single color source shared by the RXP theme and the classic reskin:
-- the live accent when Follow Accent is on (the default), else the
-- custom color from the Theme page.
function ns.ThemeAccent()
    -- The branch lives in GetAccentColor now: one source, so the theme and
    -- the chrome can never disagree about which colour is the accent.
    return ns.GetAccentColor()
end

-- The built-in files (Overpass first: what "Default Font" and every
-- look's "FUI Global Font" resolve to); GetFontOptions puts the sentinel
-- before these and appends whatever LibSharedMedia knows (other addons'
-- fonts).
ns.BUILTIN_FONTS = {
    -- The font everything defaults to (the Theme page's Default Font),
    -- shipped in our own Fonts folder.
    { label = "Overpass",        value = ns.FONT_OVERPASS },
    { label = "Expressway",      value = ns.FONT },
    { label = "Expressway Bold", value = ns.FONT_BOLD },
    { label = "Overpass",        value = ns.FONT_OVERPASS },
}

-- `noGlobal` leaves the "FUI Global Font" sentinel out: the Theme page's
-- own "Default Font" row offers real files only -- setting the global
-- font to "the global font" would be a loop -- while every other font
-- list keeps the entry, where it means "follow the Theme's Default Font".
function ns.GetFontOptions(noGlobal)
    local options, seen = {}, {}
    if not noGlobal then
        options[#options + 1] = { label = "FUI Global Font", value = ns.FUI_FONT, font = ns.ResolveFont() }
    end
    for _, f in ipairs(ns.BUILTIN_FONTS) do
        options[#options + 1] = { label = f.label, value = f.value, font = f.value }
        seen[f.value] = true
    end
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    if LSM then
        local extra = {}
        for name, path in pairs(LSM:HashTable("font")) do
            if type(path) == "string" and not seen[path] then
                seen[path] = true
                extra[#extra + 1] = { label = name, value = path, font = path }
            end
        end
        table.sort(extra, function(a, b) return a.label < b.label end)
        for _, o in ipairs(extra) do options[#options + 1] = o end
    end
    return options
end

ns.defaults = {
    -- Keep RXP's classic guide window available for the engine: RXP's own
    -- "Guide Window v2" (Interface V2, Beta) hides that window entirely --
    -- there would be nothing to read. Off means "let RXP's v2 run".
    skinForceClassic = true,
    -- RXP theme: follow the accent live (0) or use the custom color.
    themeFollowAccent = true,
    themeR = 1, themeG = 0.42, themeB = 0.08, -- #FF6B14, matches the accent
    -- The interface font (the Theme page's "Default Font"): every font the
    -- addon leaves unset -- this window, the arrow, guide-window looks on
    -- "FUI Global Font" -- resolves to it. Overpass ships as the value.
    uiFont = ns.FONT_OVERPASS,
    -- The options window's own scale (its sidebar slider, next to the
    -- version): 1 ships, the window reads it on every build.
    optionsScale = 1,

    -- =================================================================
    -- RestedXP guide window reskin (the reskin engine, see
    -- Reskin.lua). All colors stored per component as R/G/B(/A) keys.
    -- =================================================================
    rxpEnabled = true,
    rxpNoAnnounce = true,               -- keep RestedXP's chat announcements off
    rxpLayout = "FRAMELESS",            -- FRAMELESS, TIMELINE, COMPACT, ZYGOR, BIT8, RAIL or DEFAULT (the engine's set)
    -- Timeline: its APPEARANCE copy (the 1.4 Timeline's look: Expressway,
    -- blue, a 60% black panel with a black border and a navy header).
    rxpTlZoneR = 1, rxpTlZoneG = 1, rxpTlZoneB = 1, rxpTlZoneA = 1,
    rxpTlHeadBgR = 0.05, rxpTlHeadBgG = 0.13, rxpTlHeadBgB = 0.28, rxpTlHeadBgA = 1,
    rxpTlBorderR = 0, rxpTlBorderG = 0, rxpTlBorderB = 0, rxpTlBorderA = 1,
    rxpTlTrackR = 1, rxpTlTrackG = 1, rxpTlTrackB = 1, rxpTlTrackA = 0.22,
    rxpTlStepLabel = true, rxpTlListNums = true,
    rxpTlBackdrop = true, rxpTlBackdropA = 60, rxpTlObjectives = true,
    rxpTlFont = ns.FUI_FONT, rxpTlFontSemi = ns.FUI_FONT, rxpTlFontBold = ns.FUI_FONT, -- follows the Default Font like every look (old Expressway pin migrates at login)
    rxpTlWidth = 235, rxpTlNumCol = 20,
    rxpTlZoneSize = 14, rxpTlHeadSize = 10, rxpTlCurSize = 12, rxpTlTextSize = 12,
    rxpTlNumSize = 11, rxpTlObjSize = 11,
    rxpTlArrowSize = 40, rxpTlDistSize = 14, rxpTlArrowTextSize = 13,
    rxpTlFadeStep = 16, rxpTlFadeMin = 15,
    rxpTlAccentR = 0.35, rxpTlAccentG = 0.65, rxpTlAccentB = 1, rxpTlAccentA = 1,
    rxpTlCurR = 0.35, rxpTlCurG = 0.65, rxpTlCurB = 1, rxpTlCurA = 1,
    rxpTlStepColR = 0.35, rxpTlStepColG = 0.65, rxpTlStepColB = 1, rxpTlStepColA = 1,
    rxpTlPctColR = 1, rxpTlPctColG = 1, rxpTlPctColB = 1, rxpTlPctColA = 1,
    rxpTlCardA = 12,
    rxpTlArrowR = 0.35, rxpTlArrowG = 0.65, rxpTlArrowB = 1, rxpTlArrowA = 1,
    rxpTlDoneColR = 0.37, rxpTlDoneColG = 0.88, rxpTlDoneColB = 0.48, rxpTlDoneColA = 1,
    rxpTlEnemyR = 1, rxpTlEnemyG = 0.341, rxpTlEnemyB = 0.133, rxpTlEnemyA = 1,
    rxpTlTextR = 0.62, rxpTlTextG = 0.62, rxpTlTextB = 0.62, rxpTlTextA = 1,
    rxpTlNumR = 0.62, rxpTlNumG = 0.62, rxpTlNumB = 0.62, rxpTlNumA = 1,
    rxpTlMutedR = 0.78, rxpTlMutedG = 0.78, rxpTlMutedB = 0.78, rxpTlMutedA = 1,
    -- Compact (Zygor-like): its APPEARANCE copy.
    rxpCpBackdrop = true, rxpCpBackdropA = 90, rxpCpObjectives = true,
    rxpCpFont = ns.FUI_FONT, rxpCpFontSemi = ns.FUI_FONT, rxpCpFontBold = ns.FUI_FONT,
    rxpCpWidth = 250, rxpCpNumCol = 20,
    rxpCpZoneSize = 13, rxpCpHeadSize = 11, rxpCpCurSize = 12, rxpCpTextSize = 12,
    rxpCpNumSize = 11, rxpCpObjSize = 11,
    rxpCpArrowSize = 34, rxpCpDistSize = 14, rxpCpArrowTextSize = 13,
    rxpCpFadeStep = 12, rxpCpFadeMin = 45,
    rxpCpAccentR = 0.91, rxpCpAccentG = 0.76, rxpCpAccentB = 0.35, rxpCpAccentA = 1,
    rxpCpCurR = 1, rxpCpCurG = 1, rxpCpCurB = 1, rxpCpCurA = 1,
    rxpCpStepColR = 0.24, rxpCpStepColG = 0.86, rxpCpStepColB = 0.42, rxpCpStepColA = 1,
    rxpCpPctColR = 0.81, rxpCpPctColG = 0.84, rxpCpPctColB = 0.86, rxpCpPctColA = 1,
    rxpCpCardA = 18,
    rxpCpArrowR = 0.24, rxpCpArrowG = 0.86, rxpCpArrowB = 0.42, rxpCpArrowA = 1,
    rxpCpDoneColR = 0.24, rxpCpDoneColG = 0.86, rxpCpDoneColB = 0.42, rxpCpDoneColA = 1,
    rxpCpEnemyR = 1, rxpCpEnemyG = 0.341, rxpCpEnemyB = 0.133, rxpCpEnemyA = 1,
    rxpCpTextR = 0.84, rxpCpTextG = 0.87, rxpCpTextB = 0.89, rxpCpTextA = 1,
    rxpCpNumR = 0.6, rxpCpNumG = 0.64, rxpCpNumB = 0.68, rxpCpNumA = 1,
    rxpCpMutedR = 0.73, rxpCpMutedG = 0.76, rxpCpMutedB = 0.8, rxpCpMutedA = 1,
    rxpCpZoneR = 1, rxpCpZoneG = 1, rxpCpZoneB = 1, rxpCpZoneA = 1,
    rxpCpHeadBgR = 0.13, rxpCpHeadBgG = 0.15, rxpCpHeadBgB = 0.17, rxpCpHeadBgA = 1,
    rxpCpBorderR = 0.17, rxpCpBorderG = 0.19, rxpCpBorderB = 0.21, rxpCpBorderA = 1,
    rxpCpTrackR = 0.17, rxpCpTrackG = 0.19, rxpCpTrackB = 0.21, rxpCpTrackA = 1,
    rxpCpStepLabel = true, rxpCpListNums = false,
    -- Zygor-style: its APPEARANCE copy (a dark window, red goal bands, green progress).
    rxpZgBackdrop = true, rxpZgBackdropA = 92, rxpZgObjectives = true,
    rxpZgFont = ns.FUI_FONT, rxpZgFontSemi = ns.FUI_FONT, rxpZgFontBold = ns.FUI_FONT,
    rxpZgWidth = 280, rxpZgNumCol = 20,
    rxpZgZoneSize = 15, rxpZgHeadSize = 12, rxpZgCurSize = 14, rxpZgTextSize = 13,
    rxpZgNumSize = 15, rxpZgObjSize = 12,
    rxpZgArrowSize = 44, rxpZgDistSize = 14, rxpZgArrowTextSize = 15,
    rxpZgFadeStep = 12, rxpZgFadeMin = 45,
    rxpZgAccentR = 0.3, rxpZgAccentG = 0.85, rxpZgAccentB = 0.3, rxpZgAccentA = 1,
    rxpZgCurR = 1, rxpZgCurG = 1, rxpZgCurB = 1, rxpZgCurA = 1,
    rxpZgStepColR = 0.47, rxpZgStepColG = 0.1, rxpZgStepColB = 0.1, rxpZgStepColA = 1,
    rxpZgPctColR = 0.85, rxpZgPctColG = 0.85, rxpZgPctColB = 0.85, rxpZgPctColA = 1,
    rxpZgCardA = 90,
    rxpZgArrowR = 0.3, rxpZgArrowG = 0.85, rxpZgArrowB = 0.3, rxpZgArrowA = 1,
    rxpZgDoneColR = 0.3, rxpZgDoneColG = 0.85, rxpZgDoneColB = 0.3, rxpZgDoneColA = 1,
    rxpZgEnemyR = 1, rxpZgEnemyG = 0.341, rxpZgEnemyB = 0.133, rxpZgEnemyA = 1,
    rxpZgTextR = 0.9, rxpZgTextG = 0.9, rxpZgTextB = 0.9, rxpZgTextA = 1,
    rxpZgNumR = 0.6, rxpZgNumG = 0.6, rxpZgNumB = 0.6, rxpZgNumA = 1,
    rxpZgMutedR = 0.72, rxpZgMutedG = 0.72, rxpZgMutedB = 0.72, rxpZgMutedA = 1,
    rxpZgZoneR = 1, rxpZgZoneG = 1, rxpZgZoneB = 1, rxpZgZoneA = 1,
    rxpZgLineR = 0.3, rxpZgLineG = 0.3, rxpZgLineB = 0.31, rxpZgLineA = 1,
    rxpZgHeadBgR = 0.07, rxpZgHeadBgG = 0.07, rxpZgHeadBgB = 0.08, rxpZgHeadBgA = 1,
    rxpZgBorderR = 0.22, rxpZgBorderG = 0.22, rxpZgBorderB = 0.23, rxpZgBorderA = 1,
    rxpZgTrackR = 0.25, rxpZgTrackG = 0.25, rxpZgTrackB = 0.26, rxpZgTrackA = 1,
    rxpZgStepLabel = true, rxpZgListNums = false,
    -- 8-Bit: its APPEARANCE copy (the handoff's palette; fonts locked to Silkscreen / VT323).
    rxpBtBackdrop = true, rxpBtBackdropA = 100, rxpBtObjectives = true, rxpBtShowDone = true, rxpBtScan = true,
    rxpBtWidth = 336, rxpBtNumCol = 30,
    rxpBtZoneSize = 15, rxpBtHeadSize = 10, rxpBtCurSize = 22, rxpBtTextSize = 19,
    rxpBtNumSize = 18, rxpBtObjSize = 17,
    rxpBtArrowSize = 34, rxpBtDistSize = 18, rxpBtArrowTextSize = 19,
    rxpBtAccentR = 1, rxpBtAccentG = 0.824, rxpBtAccentB = 0.247, rxpBtAccentA = 1,           -- #FFD23F
    rxpBtCurR = 0.91, rxpBtCurG = 0.902, rxpBtCurB = 0.961, rxpBtCurA = 1,                    -- #E8E6F5
    rxpBtStepColR = 1, rxpBtStepColG = 0.365, rxpBtStepColB = 0.451, rxpBtStepColA = 1,       -- #FF5D73
    rxpBtArrowR = 1, rxpBtArrowG = 0.824, rxpBtArrowB = 0.247, rxpBtArrowA = 1,
    rxpBtDoneColR = 0.49, rxpBtDoneColG = 1, rxpBtDoneColB = 0.416, rxpBtDoneColA = 1,        -- #7DFF6A
    rxpBtEnemyR = 1, rxpBtEnemyG = 0.365, rxpBtEnemyB = 0.451, rxpBtEnemyA = 1,               -- #FF5D73
    rxpBtItemR = 0.247, rxpBtItemG = 0.816, rxpBtItemB = 1, rxpBtItemA = 1,                   -- #3FD0FF
    rxpBtNpcR = 0.49, rxpBtNpcG = 1, rxpBtNpcB = 0.416, rxpBtNpcA = 1,                        -- #7DFF6A
    rxpBtVerbR = 1, rxpBtVerbG = 0.824, rxpBtVerbB = 0.247, rxpBtVerbA = 1,                   -- #FFD23F
    rxpBtTextR = 0.91, rxpBtTextG = 0.902, rxpBtTextB = 0.961, rxpBtTextA = 1,                -- #E8E6F5
    rxpBtNumR = 0.643, rxpBtNumG = 0.624, rxpBtNumB = 0.78, rxpBtNumA = 1,                    -- #A49FC7
    rxpBtMutedR = 0.643, rxpBtMutedG = 0.624, rxpBtMutedB = 0.78, rxpBtMutedA = 1,            -- #A49FC7
    rxpBtZoneR = 0.949, rxpBtZoneG = 0.941, rxpBtZoneB = 1, rxpBtZoneA = 1,                   -- #F2F0FF
    rxpBtBgR = 0.051, rxpBtBgG = 0.043, rxpBtBgB = 0.102, rxpBtBgA = 1,                       -- #0D0B1A
    rxpBtHeadBgR = 0.137, rxpBtHeadBgG = 0.118, rxpBtHeadBgB = 0.239, rxpBtHeadBgA = 1,       -- #231E3D
    rxpBtBorderR = 0.949, rxpBtBorderG = 0.941, rxpBtBorderB = 1, rxpBtBorderA = 1,           -- #F2F0FF
    rxpBtTrackR = 0.11, rxpBtTrackG = 0.094, rxpBtTrackB = 0.188, rxpBtTrackA = 1,            -- #1C1830
    rxpBtStepLabel = true, rxpBtListNums = true,
    -- Frameless layout (defaults = the design handoff)
    rxpFlBackdrop = false, rxpFlBackdropA = 14,      -- optional black backdrop, %
    rxpFlObjectives = true,             -- objective lines ("0/8 Canvas Scraps") under the current step
    rxpFlFont = ns.FUI_FONT, rxpFlFontSemi = ns.FUI_FONT, rxpFlFontBold = ns.FUI_FONT,
    rxpFlWidth = 256, rxpFlNumCol = 20,
    rxpFlZoneSize = 16, rxpFlHeadSize = 12, rxpFlCurSize = 13, rxpFlTextSize = 12,
    rxpFlNumSize = 11, rxpFlObjSize = 12,
    rxpFlArrowSize = 32, rxpFlDistSize = 14, rxpFlArrowTextSize = 14,
    rxpFlFadeStep = 12, rxpFlFadeMin = 0,  -- % dimmer per step ahead; lowest %
    rxpFlAccentR = 0.94, rxpFlAccentG = 0.83, rxpFlAccentB = 0.42, rxpFlAccentA = 1,  -- #EFD36C
    rxpFlCurR = 1, rxpFlCurG = 1, rxpFlCurB = 1, rxpFlCurA = 1,                       -- current step: white
    rxpFlStepColR = 0.91, rxpFlStepColG = 0.64, rxpFlStepColB = 0.24, rxpFlStepColA = 1, -- "STEP 7", "!"
    rxpFlPctColR = 0.31, rxpFlPctColG = 0.76, rxpFlPctColB = 0.97, rxpFlPctColA = 1,     -- header %, "i"
    rxpFlCardA = 65,                    -- current step card background, %
    rxpFlZoneR = 1, rxpFlZoneG = 1, rxpFlZoneB = 1, rxpFlZoneA = 1,                  -- zone name
    rxpFlLineR = 1, rxpFlLineG = 1, rxpFlLineB = 1, rxpFlLineA = 0.55,               -- line under the header
    rxpFlBorderR = 1, rxpFlBorderG = 1, rxpFlBorderB = 1, rxpFlBorderA = 0.07,       -- card border
    rxpFlTrackR = 1, rxpFlTrackG = 1, rxpFlTrackB = 1, rxpFlTrackA = 0.12,           -- bar track
    rxpFlStepLabel = true, rxpFlListNums = true,                                      -- "STEP 7", list numbers
    rxpFlArrowR = 0, rxpFlArrowG = 0.85, rxpFlArrowB = 1, rxpFlArrowA = 1,      -- arrow, same yellow
    rxpFlDoneColR = 0.37, rxpFlDoneColG = 0.88, rxpFlDoneColB = 0.48, rxpFlDoneColA = 1,  -- finished objective bars
    rxpFlEnemyR = 0, rxpFlEnemyG = 0.511, rxpFlEnemyB = 0.6, rxpFlEnemyA = 1,       -- enemy names (RestedXP's #FF5722)
    rxpFlTextR = 0.475, rxpFlTextG = 0.475, rxpFlTextB = 0.475, rxpFlTextA = 1,          -- #F0F0F0
    rxpFlNumR = 0.475, rxpFlNumG = 0.475, rxpFlNumB = 0.475, rxpFlNumA = 1,              -- #BBBBBB
    rxpFlMutedR = 0.87, rxpFlMutedG = 0.87, rxpFlMutedB = 0.87, rxpFlMutedA = 1,      -- #DDDDDD
    -- Rail layout (a vertical rail on the left, one marker per step)
    rxpRlBackdrop = false, rxpRlBackdropA = 0, rxpRlObjectives = true,
    rxpRlFont = ns.FUI_FONT, rxpRlFontSemi = ns.FUI_FONT, rxpRlFontBold = ns.FUI_FONT,
    rxpRlWidth = 300, rxpRlNumCol = 26,
    rxpRlZoneSize = 15, rxpRlHeadSize = 11, rxpRlCurSize = 14, rxpRlTextSize = 12,
    rxpRlNumSize = 11, rxpRlObjSize = 11,
    rxpRlArrowSize = 36, rxpRlDistSize = 15, rxpRlArrowTextSize = 13,
    rxpRlFadeStep = 14, rxpRlFadeMin = 25,  -- % dimmer per step ahead; lowest %
    rxpRlAccentR = 0.35, rxpRlAccentG = 0.75, rxpRlAccentB = 0.95, rxpRlAccentA = 1,  -- the rail's markers
    rxpRlCurR = 1, rxpRlCurG = 1, rxpRlCurB = 1, rxpRlCurA = 1,                       -- current step: white
    rxpRlStepColR = 0.35, rxpRlStepColG = 0.75, rxpRlStepColB = 0.95, rxpRlStepColA = 1,  -- "STEP 7", "!"
    rxpRlPctColR = 0.75, rxpRlPctColG = 0.78, rxpRlPctColB = 0.82, rxpRlPctColA = 1,  -- header %, "i"
    rxpRlCardA = 0,                       -- no card panel in this layout
    rxpRlZoneR = 1, rxpRlZoneG = 1, rxpRlZoneB = 1, rxpRlZoneA = 1,                  -- zone name
    rxpRlLineR = 1, rxpRlLineG = 1, rxpRlLineB = 1, rxpRlLineA = 0.35,
    rxpRlBorderR = 1, rxpRlBorderG = 1, rxpRlBorderB = 1, rxpRlBorderA = 0.1,
    rxpRlTrackR = 1, rxpRlTrackG = 1, rxpRlTrackB = 1, rxpRlTrackA = 0.25,           -- the rail line, bars
    rxpRlStepLabel = true, rxpRlListNums = true,                                      -- "STEP 7", list numbers
    rxpRlArrowR = 0.35, rxpRlArrowG = 0.75, rxpRlArrowB = 0.95, rxpRlArrowA = 1,      -- arrow, the rail's blue
    rxpRlDoneColR = 0.3, rxpRlDoneColG = 0.85, rxpRlDoneColB = 0.4, rxpRlDoneColA = 1,  -- finished objective bars
    rxpRlEnemyR = 0, rxpRlEnemyG = 0.511, rxpRlEnemyB = 0.6, rxpRlEnemyA = 1,       -- enemy names
    rxpRlTextR = 0.82, rxpRlTextG = 0.85, rxpRlTextB = 0.88, rxpRlTextA = 1,           -- upcoming steps
    rxpRlNumR = 0.5, rxpRlNumG = 0.55, rxpRlNumB = 0.6, rxpRlNumA = 1,                -- upcoming numbers
    rxpRlMutedR = 0.62, rxpRlMutedG = 0.66, rxpRlMutedB = 0.7, rxpRlMutedA = 1,       -- markers, counter, notes
    rxpFade = true,                     -- fade the upcoming steps the further ahead they are
    rxpUpcoming = 6,                    -- steps listed under the current ones
    rxpArrow = true,                    -- reskin the waypoint arrow
    rxpBoxLock = true,                   -- true: the objective icon boxes stay glued under the guide window; false: drag them anywhere
    rxpArrowStyle = "LAYOUT",           -- LAYOUT (the layout's own), CHEVRON, CARD, CLASSIC, ZYGOR, RAIL or RAILC
    rxpMeters = false,                  -- the arrow's distance in "m" (1 yd = 1 m in WoW: same number)
    rxpArrowETA = true,                 -- every custom arrow shows the time to the waypoint (x:xx / xx s)
    rxpArrowShadow = false,             -- a soft blurred shadow around the arrow's icon (ARROW block)
    rxpArrowShadowSize = 6,             -- how far it spreads AND feathers (the blur), on every side (px)
    rxpArrowShadowR = 0, rxpArrowShadowG = 0, rxpArrowShadowB = 0, rxpArrowShadowA = 0.75,  -- its colour
    -- Route (MapRoute.lua): a bearing line to the guide's target, in the
    -- accent color, plus the next few steps -- on the world map, and on the
    -- minimap under its own switch. BOTH OFF by default: they draw on the
    -- two surfaces this addon does not own (a UI suite may style both),
    -- and nothing
    -- else here depends on them.
    rxpMapRoute = false,
    rxpMiniRoute = false,               -- the same route on the minimap, switch of its own (ROUTE block)
    rxpMapFuture = 0,                   -- extra markers drawn on the map, after the current target (0..6)
    rxpMapChainAlpha = 0.55,            -- how present the chain of upcoming steps is against the current target
    rxpMapFlowSpeed = 0.5,              -- chevron travel along the route (0 = still), the value this route was drawn against
    rxpMapThickness = 1.0,              -- line weight on BOTH surfaces (1 = the route exactly as it ships)
    -- The guide's own shapes (MapRoute.lua): farming circuits (#loop),
    -- patrol paths and search areas, drawn as their own layer UNDER the
    -- route -- the sublevels see to that, so the bearing always reads on
    -- top. Three kinds, one opacity. OFF by default, like the route:
    -- they draw on the two surfaces this addon does not own.
    rxpOverlayFarm = false,             -- mint circuit from #loop steps, a node on each corner
    rxpOverlayPatrol = false,           -- dashed amber path: something walks here
    rxpOverlaySearch = false,           -- pale blue area: soft fill plus contour
    rxpOverlayAlpha = 0.8,              -- one opacity for every overlay (0.20..1)
    -- One color per kind, each on its own row of the Map page (the same
    -- suffix scheme the 8-Bit look page uses). They are deliberately NOT
    -- the Theme page's color: the route takes that one, the shapes take
    -- these -- so a mint farm circuit stays mint on an amber theme.
    rxpOverlayFarmR = 0.42, rxpOverlayFarmG = 1.00, rxpOverlayFarmB = 0.70, rxpOverlayFarmA = 1,     -- mint
    rxpOverlayPatrolR = 1.00, rxpOverlayPatrolG = 0.82, rxpOverlayPatrolB = 0.34, rxpOverlayPatrolA = 1, -- amber
    rxpOverlaySearchR = 0.58, rxpOverlaySearchG = 0.88, rxpOverlaySearchB = 1.00, rxpOverlaySearchA = 1, -- pale blue
    -- Marker tooltips (MapRoute.lua): one switch per group of lines the
    -- hover shows, plus the master. All on by default -- the tooltip is the
    -- map's own explanation of a marker -- and a key missing from an older
    -- saved-variable file reads as ON there too.
    rxpTipOn = true,                    -- every group below, or no tooltip at all
    rxpTipHeader = true,                -- "Current target" / "Next +2", with the step number
    rxpTipTitle = true,                 -- the step's own title, when the guide gives it one
    rxpTipText = true,                  -- the instruction lines: what the step asks you to do
    rxpTipTarget = true,                -- the named NPC or item
    rxpTipType = true,                  -- the step type, with RestedXP's icon for it
    rxpTipNav = true,                   -- distance, direction, arrival time
    rxpTipQuest = true,                 -- quest title, level, status, objectives, id
    rxpTipZone = true,                  -- the instance and the zone
    -- One-time migrations for older installs: a new install starts past them.
    rxpTallV1 = true, rxpTallV2 = true, rxpFlCardV1 = true,
}

function ns.DB() return FUIRestedXPCache end

-- Fan-out when the accent changes live: re-derive the
-- RXP theme, re-tint the classic reskin, refresh the standalone window.
-- Debounced: several changes can land in one burst.
local accentQueued
function ns.OnAccentChanged()
    if accentQueued then return end
    accentQueued = true
    C_Timer.After(0, function()
        accentQueued = false
        if not ns.IsReady() then return end
        if ns.Theme and ns.Theme.Refresh then ns.Theme:Refresh() end
        if ns.Skin and ns.Skin.Refresh then ns.Skin:Refresh() end
        -- The map route is drawn in the accent color, so it has to be told
        -- about the change: it is not a module Refresh fans out on its own.
        if ns.MapRoute and ns.MapRoute.Refresh then ns.MapRoute.Refresh() end
        if ns.Options and ns.Options.OnAccentChanged then ns.Options:OnAccentChanged() end
    end)
end

-- ---------------- Modules / lifecycle ----------------
ns.modules = {}   -- name -> { Refresh = fn }
ns.onLogin = {}   -- fns run once the DB is ready

function ns.Refresh()
    for _, m in pairs(ns.modules) do
        if m.Refresh then m.Refresh() end
    end
    ns.WarnLiteTweaksReskin()
    ns.WarnArrowHidden()
end

-- Reset every setting to its default value (the slash command and the
-- options buttons both come through here): layout, arrow style and
-- colors, opacity, theme color source, step numbers, listed steps, sizes,
-- fonts, distance unit. Also puts RXP's window scale back to 100% through
-- the ported engine's accessor when available. RXP's own settings (window
-- position, dragged size, guides) are untouched.
function ns.ResetAll()
    local db = ns.DB()
    if db then
        for k, v in pairs(ns.defaults) do db[k] = v end
    end
    if ns.RestedXP and ns.RestedXP.SetScale then
        pcall(ns.RestedXP.SetScale, 1)
    end
    ns.Refresh()
    -- Defaults restore the accent source too (Follow Accent on): fan the
    -- accent back out so chrome, logo and route repaint live.
    ns.OnAccentChanged()
end

-- One-time migration for the default-font move: "Default Font" now ships
-- as Overpass and every look follows it through the FUI Global Font
-- sentinel, so values still equal to the OLD defaults are converted at
-- first login (a deliberately picked value that happens to be the old
-- default converts too -- one dropdown puts it back). Idempotent. Saved
-- settings still pointing at the withdrawn Avant Garde file move to
-- Overpass the same way.
function ns.MigrateFontDefaults()
    local db = ns.DB and ns.DB()
    if not db then return end
    local withdrawn = FONT_DIR .. "AvantGarde.ttf"
    if db.uiFont == ns.FUI_FONT then db.uiFont = ns.FONT_OVERPASS end
    if db.uiFont == withdrawn then db.uiFont = ns.FONT_OVERPASS end
    if db.rxpTlFont == ns.FONT then db.rxpTlFont = ns.FUI_FONT end
    if db.rxpTlFontSemi == ns.FONT then db.rxpTlFontSemi = ns.FUI_FONT end
    if db.rxpTlFontBold == ns.FONT_BOLD then db.rxpTlFontBold = ns.FUI_FONT end
end

local loginDone = false

-- True once the DB is seeded and module login fns have run.
function ns.IsReady() return loginDone end

-- Run once at PLAYER_LOGIN: seed the DB, run module login fns, then watch
-- for RXPGuides loading. Load order versus RXP is not guaranteed, so both
-- directions are handled.
local init = CreateFrame("Frame")
init:RegisterEvent("PLAYER_LOGIN")
init:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")
    if type(FUIRestedXPCache) ~= "table" then FUIRestedXPCache = {} end
    for k, v in pairs(ns.defaults) do
        if FUIRestedXPCache[k] == nil then FUIRestedXPCache[k] = v end
    end
    ns.MigrateFontDefaults()
    loginDone = true
    for _, fn in ipairs(ns.onLogin) do fn() end
    -- LiteTweaks' reskin fights ours: one warning at login when both are on
    -- (its saved variables are flat and loaded by then). Same for anything
    -- holding the frame our arrow lives in transparent.
    ns.WarnLiteTweaksReskin()
    ns.WarnArrowHidden()

    -- Late accent changes from EllesmereUI have no public event, so the
    -- theme reads the live color on every refresh and the skin re-tints on
    -- RXP repaints; nothing polls.
end)

-- The real RestedXP addon object. The _G.RXPGuides global is only an
-- empty placeholder table RXP fills with guide data; the AceAddon object
-- carries RegisterTheme / settings / v2 / RenderFrame and is not global.
function ns.GetRXP()
    local Ace = LibStub and LibStub("AceAddon-3.0", true)
    if Ace then
        local ok, a = pcall(Ace.GetAddon, Ace, "RXPGuides", true)
        if ok and a then return a end
    end
    return nil
end

-- True once RXP's frames and APIs exist.
function ns.RXPReady()
    return ns.GetRXP() ~= nil and _G.RXPFrame ~= nil
end

-- Jo's LiteTweaks (a quality-of-life addon) ships a reskin of the very
-- same RestedXP guide window: with both engines on they repaint the same
-- frames and fight. Its DB is flat (LiteTweaksDB.rxpEnabled, default true)
-- and its saved variables survive an uninstall, so the addon must actually
-- be loaded too. With his blessing, we warn rather than fight silently.
function ns.LiteTweaksReskin()
    local db = _G.LiteTweaksDB
    local loaded = (C_AddOns and C_AddOns.IsAddOnLoaded or _G.IsAddOnLoaded)
    return not not (db and db.rxpEnabled ~= false
        and loaded and loaded("LiteTweaks"))
end

-- One warning per session, at the first refresh while both engines are on
-- (login covers the usual case; flipping our Reskin toggle re-runs Refresh).
-- The warning carries a clickable action that turns OUR reskin off on the
-- spot -- the other side (LiteTweaks) keeps its own /lt toggle.
local liteTweaksWarned
function ns.WarnLiteTweaksReskin()
    if liteTweaksWarned then return end
    local db = ns.DB()
    if not (ns.LiteTweaksReskin() and db and db.rxpEnabled) then return end
    liteTweaksWarned = true
    print(ns.AccentHex() .. "FUI-RestedXP|r: LiteTweaks' RestedXP reskin is on"
        .. " too -- both would repaint the same guide window. Turn one off:")
    print("  " .. ns.AccentHex() .. "|Hfuirxp:off|h[disable this addon's reskin]|h|r"
        .. "   or   " .. ns.AccentHex()
        .. "|Hfuirxp:ltoff|h[disable LiteTweaks' reskin]|h|r")
    -- And a real prompt once the UI has settled (login popups race the
    -- loading screen): three answers, no typing. Escape = keep both.
    C_Timer.After(4, function()
        StaticPopup_Show("FUIRESTEDXP_CONFLICT")
    end)
end

-- The login prompt itself. button1/2 map to OnAccept / OnButton2; on a
-- client whose popup template lacks a third button, that answer simply
-- isn't shown -- the chat links above still carry every action, and
-- Escape (hideOnEscape) keeps both reskins untouched.
StaticPopupDialogs["FUIRESTEDXP_CONFLICT"] = {
    text = "LiteTweaks' RestedXP reskin and FUI-RestedXP's are both on --\nthey would repaint the same guide window. Turn one off?",
    button1 = "Disable LiteTweaks' reskin",
    button2 = "Disable FUI-RestedXP's reskin",
    button3 = "Keep both",
    OnAccept = function()
        -- Jo's own request: flip LiteTweaksDB.rxpEnabled. His hooks re-check
        -- the flag on their next repaint, so a reload restores cleanly.
        local lt = _G.LiteTweaksDB
        if lt then lt.rxpEnabled = false end
        ns.Refresh()
        StaticPopup_Show("FUIRESTEDXP_LT_RELOAD")
    end,
    OnButton2 = function()
        -- Our reskin: the options toggle's exact path, no reload needed.
        local db = ns.DB()
        if not db then return end
        db.rxpEnabled = false
        ns.Refresh()
        if ns.FUIOptionsChanged then ns.FUIOptionsChanged() end
        print(ns.AccentHex() .. "FUI-RestedXP|r: reskin disabled -- RestedXP's own"
            .. " window is back (re-enable it on the Reskin options page).")
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
    showAlert = true,
}

-- The "disable LiteTweaks' reskin" action: Jo asked for exactly this
-- (a prompt flipping LiteTweaksDB.rxpEnabled). His engine has no public
-- refresh and its hooks re-check the flag on their next repaint, so the
-- clean restore is one /reload -- offered through a standard popup.
StaticPopupDialogs["FUIRESTEDXP_LT_RELOAD"] = {
    text = "LiteTweaks' RestedXP reskin is off. Reload the UI to finish the restore?",
    button1 = RELOADUI,
    button2 = CANCEL,
    OnAccept = function() ReloadUI() end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

-- Our arrow card is a CHILD of RestedXP's own arrow frame, and alpha is
-- inherited by children: anything that keeps that frame up but holds its
-- alpha at 0 -- re-applying it every half second from its own OnUpdate --
-- takes our arrow with it, and no setting of ours can out-race a loop like
-- that. This never names, touches or disables whatever is doing it: the
-- SYMPTOM alone is reported, once, and only while it lasts.
-- The frame being DOWN is a normal state -- no arrow step to point at --
-- so the symptom is the frame UP and fully transparent.
local function ArrowFrameState()
    local f = _G.RXPG_ARROW
    if not f then return "not created" end
    if f.IsShown and not f:IsShown() then return "down" end
    local a = f.GetAlpha and f:GetAlpha() or 1
    if a < 0.05 then return "up but transparent" end
    return "ok"
end

-- One warning per session, on the same cadence as the LiteTweaks one:
-- checked whenever the addon refreshes, and once more five seconds after
-- login -- a sample taken at login can land before the loop that holds the
-- frame down has run once. Nothing is warned when our own arrow is off:
-- there is then nothing for that alpha to erase.
local arrowWarned, arrowScheduled
local function sampleArrowFrame()
    if arrowWarned then return end
    local db = ns.DB()
    if not (db and db.rxpEnabled and db.rxpArrow ~= false) then return end
    if ArrowFrameState() ~= "up but transparent" then return end
    arrowWarned = true
    print(ns.AccentHex() .. "FUI-RestedXP|r: RestedXP's arrow frame is up but fully"
        .. " transparent -- our arrow is drawn inside that frame, so nothing of it"
        .. " can appear. Something outside this addon is holding the frame down;"
        .. " the reskin, the map route and the rest of this addon are unaffected."
        .. " /fuirxp status reports the frame while it lasts.")
end

function ns.WarnArrowHidden()
    sampleArrowFrame()
    if arrowWarned or arrowScheduled then return end
    arrowScheduled = true
    C_Timer.After(5, function()
        arrowScheduled = false
        sampleArrowFrame()
    end)
end

-- The click behind that link (a custom chat hyperlink, same mechanism as
-- item links). One left-click flips rxpEnabled off through the exact path
-- the options toggle uses: DB, module refresh, then the pages rebuild
-- so the Reskin page and the tab bar follow immediately.
hooksecurefunc("SetItemRef", function(link, _, button)
    if type(link) ~= "string" or button ~= "LeftButton" then return end
    local action = link:match("^fuirxp:(%a+)$")
    if not action then return end
    local db = ns.DB()
    if not db then return end
    if action == "off" then
        -- Our reskin: same path as the options toggle (DB, module refresh,
        -- pages rebuild) -- no reload needed.
        db.rxpEnabled = false
        ns.Refresh()
        if ns.FUIOptionsChanged then ns.FUIOptionsChanged() end
        print(ns.AccentHex() .. "FUI-RestedXP|r: reskin disabled -- RestedXP's own"
            .. " window is back (re-enable it on the Reskin options page).")
    elseif action == "ltoff" then
        -- LiteTweaks' reskin: flip his flag (his hooks re-check it), then a
        -- popup offers the reload that restores the stock window cleanly.
        local lt = _G.LiteTweaksDB
        if lt then lt.rxpEnabled = false end
        ns.Refresh()
        StaticPopup_Show("FUIRESTEDXP_LT_RELOAD")
    end
end)

-- Run fn once RXPGuides is fully loaded (frames and APIs created). RXP is
-- in our OptionalDeps, so it loads before us and its ADDON_LOADED has
-- usually already fired: poll readiness instead of waiting on events.
function ns.OnRXPLoaded(fn)
    if type(fn) ~= "function" then return end
    if ns.RXPReady() then
        fn()
        return
    end
    local tries = 0
    local t = C_Timer.NewTicker(0.25, function()
        tries = tries + 1
        if ns.RXPReady() or tries > 120 then
            t:Cancel()
            if ns.RXPReady() then fn() end
        end
    end)
end

-- ---------------- Slash ----------------
SLASH_FUIHELPEDXP1 = "/fuirxp"
SLASH_FUIHELPEDXP2 = "/fui restedxp"
SlashCmdList["FUIHELPEDXP"] = function(msg)
    msg = strtrim(msg or ""):lower()
    if msg == "reset" then
        ns.ResetAll()
        print(ns.AccentHex() .. "FUI-RestedXP|r: settings reset to defaults.")
        return
    end
    if msg == "debug" then
        if ns.Options and ns.Options.Debug then
            ns.Options.Debug()
        else
            print(ns.AccentHex() .. "FUI-RestedXP|r: options not loaded.")
        end
        return
    end
    if msg == "status" then
        local db = ns.DB()
        local RXP = ns.GetRXP()
        local theme = RXP and RXP.settings and RXP.settings.profile
            and RXP.settings.profile.activeTheme or "?"
        local on = db.rxpEnabled and true or false
        -- One variable per line. The chat frame has no width worth designing
        -- for: a "|"-joined line simply wraps into an unreadable block. With
        -- the engine off the layout and the custom arrow are inert -- we are
        -- not drawing anything -- so they are not listed at all. Meters still
        -- applies either way, which is why it stays.
        print(ns.AccentHex() .. "FUI-RestedXP|r v" .. ns.InstalledVersion())
        print("  engine: " .. (on and "on" or "off"))
        if on then
            print("  layout: " .. tostring(db.rxpLayout))
            -- Only while the engine is on: R.AttachTargets places those boxes
            -- itself and does nothing at all otherwise, which is also why the
            -- matching option is hidden from the page in that state.
            print("  glue objective icons: " .. (db.rxpBoxLock ~= false and "on" or "off"))
        end
        print("  theme in RXP: " .. tostring(theme))
        print("  follow accent: " .. (db.themeFollowAccent and "on" or "off"))
        print("  accent: " .. ("%.2f %.2f %.2f"):format(ns.GetAccentColor()))
        print("  meters: " .. (db.rxpMeters and "on" or "off"))
        if on then
            print("  custom arrow: " .. (db.rxpArrow and "on (" .. tostring(db.rxpArrowStyle) .. ")" or "off"))
            print("  eta: " .. (db.rxpArrowETA ~= false and "on" or "off"))
            print("  arrow shadow: " .. (db.rxpArrowShadow
                and ("on (" .. tostring(db.rxpArrowShadowSize or 6) .. " px)") or "off"))
        end
        local tint = (ns.Skin and ns.Skin.TintState) and ns.Skin:TintState() or nil
        if type(tint) == "table" then
            for _, k in ipairs({ "theme", "frame", "engineArrow", "accent", "tint" }) do
                print("  arrow tint " .. k .. ": " .. tostring(tint[k]))
            end
        else
            print("  arrow tint: ?")
        end
        print("  lt reskin: " .. (ns.LiteTweaksReskin() and "ON (conflict)" or "off"))
        print("  arrow frame: " .. ArrowFrameState())
        print("  map route: " .. ((db.rxpMapRoute and "on (markers: "
            .. tostring(db.rxpMapFuture or 0) .. ")") or "off"))
        -- Only while it is on, and only with the map open: this is the
        -- single line that says WHICH stage the drawing stopped at.
        if db.rxpMapRoute and ns.MapRoute and ns.MapRoute.Diagnose
            and _G.WorldMapFrame and _G.WorldMapFrame:IsShown() then
            print("  map draw:  " .. ns.MapRoute.Diagnose())
        end
        print("  minimap route: " .. (db.rxpMiniRoute and "on" or "off"))
        -- The minimap pass runs whether the map is open or not, so this one
        -- always answers -- and says WHICH stage its own drawing stopped at.
        if db.rxpMiniRoute and ns.MapRoute and ns.MapRoute.MiniDiagnose then
            print("  minimap draw: " .. ns.MapRoute.MiniDiagnose())
        end
        -- The overlay layer (farm / patrol / search shapes), with the same
        -- honesty as the rest: WHICH kinds are on, and -- while the world
        -- map is open with the route on -- how many shapes it actually drew.
        do
            local ov = {}
            if db.rxpOverlayFarm then ov[#ov + 1] = "farm" end
            if db.rxpOverlayPatrol then ov[#ov + 1] = "patrol" end
            if db.rxpOverlaySearch then ov[#ov + 1] = "search" end
            if #ov == 0 then
                print("  overlays: off")
            else
                local drawn = ns.MapRoute and ns.MapRoute.overlayDrawn
                print("  overlays: " .. table.concat(ov, ", ") .. ", alpha "
                    .. tostring(db.rxpOverlayAlpha or 0.8)
                    .. (drawn and (" (drawn: " .. tostring(drawn) .. ")") or ""))
            end
        end
        return
    end
    -- Anything else (including no argument) opens the settings in the
    -- standalone window (Options.lua).
    if ns.OpenSettings and ns.OpenSettings() then return end
    if ns.Options and ns.Options.Show then
        ns.Options.Show()
        return
    end
    print(ns.AccentHex() .. "FUI-RestedXP|r: commands: /fuirxp (options),"
        .. " /fuirxp status, /fuirxp reset, /fuirxp debug.")
end
