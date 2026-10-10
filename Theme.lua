-- FUI-RestedXP Theme.lua (standalone)
-- A RestedXP theme whose colors follow the live accent color chosen by
-- the standalone options, or a fixed custom color. Registered through the
-- official channels: direct RegisterTheme when RXP is already up, else the
-- RXPGuides_Themes global that RXP's ImportCustomThemes consumes right
-- after it loads. Structure: rebuild on every Refresh, never paint once.

local ADDON_NAME, ns = ...

ns.Theme = ns.Theme or {}
ns.modules.theme = ns.Theme
local THEME_NAME = "Fr33noX-UI"
ns.Theme.name = THEME_NAME

-- The accent the theme derives from: the shared color source in Core
-- (live accent when Follow Accent is on, else the custom color).
local function Accent()
    return ns.ThemeAccent()
end

-- Derive every RXP theme color from a single accent (r, g, b, 0-1 floats).
-- Backgrounds are tinted toward the accent instead of pure black so the
-- guide window picks up the suite identity without hurting readability.
local function BuildTheme()
    local r, g, b = Accent()

    -- Mix accent into dark backgrounds: 10-16% keeps text readable.
    local function tint(k)
        return 0.05 + r * k, 0.05 + g * k, 0.07 + b * k, 1
    end

    local br, bg, bb = tint(0.10)
    local fr, fg, fb = tint(0.16)

    return {
        name = THEME_NAME,
        -- Shown in the RXP dropdown as "Fr33noX-UI by FUI-RestedXP"
        displayName = "Fr33noX-UI",
        author = "FUI-RestedXP",
        applicable = true,
        -- Declare V2 parity so RXP's ConvertThemes re-converts on every
        -- Refresh (its guard skips sources older than the converted copy).
        version = 2,

        -- V1 theme keys (LoadActiveTheme), converted to V2 by
        -- addon.v2:ConvertThemes when the V2 guide window is enabled.
        background = {br, bg, bb},
        bottomFrameBG = {fr, fg, fb},
        bottomFrameHighlight = {r, g, b, 128 / 255},

        -- Map pin color: bright accent, opaque
        mapPins = {r, g, b, 1},

        -- Colored text prefix
        tooltip = ("|cff%02x%02x%02x"):format(
            math.floor(r * 255 + 0.5),
            math.floor(g * 255 + 0.5),
            math.floor(b * 255 + 0.5)),

        -- Reuse the stock DarkMode texture set inside RXPGuides itself:
        -- this theme changes colors, it ships no textures.
        texturePath = "Interface/AddOns/RXPGuides/Textures/DarkMode/",
        headerTexture = "rxp-banner",

        -- White text keeps maximum readability on the tinted backdrop
        textColor = {1, 1, 1},

        font = _G.GameFontNormal and _G.GameFontNormal:GetFont(),
    }
end

-- Publish through the RXPGuides_Themes global (consumed by RXP's
-- ImportCustomThemes when it loads after us).
local function PublishToGlobal()
    local channel = _G.RXPGuides_Themes
    if not channel then
        channel = {}
        _G.RXPGuides_Themes = channel
    end
    channel[THEME_NAME] = BuildTheme()
end

-- Direct registration through RXP's API (RXP already loaded).
local function RegisterDirect()
    local RXP = ns.GetRXP()
    if not (RXP and RXP.RegisterTheme) then return false end
    RXP:RegisterTheme(BuildTheme())
    return true
end

function ns.Theme:Apply()
    if not RegisterDirect() then
        PublishToGlobal()
    end
end

-- Rebuild against the current accent and re-render RXP windows. Re-renders
-- only when the user actually picked our theme; switching to another RXP
-- theme is never overridden.
function ns.Theme:Refresh()
    if not ns.IsReady() then return end
    local RXP = ns.GetRXP()
    if not RXP then return end

    if RXP.themes then
        RXP.themes[THEME_NAME] = BuildTheme()
    end
    -- Keep the converted V2 theme table in sync when the V2 window is on.
    if RXP.v2 and RXP.v2.ConvertThemes then
        RXP.v2:ConvertThemes()
    end
    local profile = RXP.settings and RXP.settings.profile
    if profile and profile.activeTheme == THEME_NAME
        and RXP.RenderFrame then
        RXP.RenderFrame(true)
    end
end

-- Register at our own load time through the global channel (RXP is in
-- our OptionalDeps and has usually loaded before us, but it wipes the
-- RXPGuides_Themes global right after importing it -- the direct
-- RegisterTheme below is what keeps the theme applied).
ns.Theme:Apply()
table.insert(ns.onLogin, function()
    ns.Theme:Apply()
    ns.Theme:Refresh()
end)
ns.OnRXPLoaded(function()
    ns.Theme:Apply()
    ns.Theme:Refresh()
end)
