-- FUI-RestedXP About.lua (standalone)
-- The addon's own page in the game's Options > Add-ons list: logo,
-- name, version, what it does, and a button opening the full
-- settings -- the same door as /fuirxp. Static content otherwise.

local ADDON_NAME, ns = ...

local LOGO = [[Interface\AddOns\FUI-RestedXP\Resources\FUI-logo.tga]]

local function OpenSettings()
    -- Same chain as /fuirxp with no argument (Core.lua).
    if ns.OpenSettings and ns.OpenSettings() then return end
    if ns.Options and ns.Options.Show then ns.Options.Show() end
end

local frame = CreateFrame("Frame")
frame.name = "FUI-RestedXP"
frame:Hide()

-- Logo, top left. Same file as the options window's sidebar banner, at
-- its native 182x153 pixels: 1:1, never stretched. If the art changes,
-- keep SetSize on the file's own dimensions.
local logo = frame:CreateTexture(nil, "ARTWORK")
logo:SetTexture(LOGO)
logo:SetSize(182, 153)
logo:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -16)

local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", logo, "BOTTOMLEFT", 0, -12)
title:SetText((ns.AccentHex and ns.AccentHex() or "|cffff6b14")
    .. "FUI-RestedXP|r")

local version = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
version:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
version:SetText("v" .. ns.InstalledVersion())

local about = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
about:SetPoint("TOPLEFT", version, "BOTTOMLEFT", 0, -12)
about:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -24, -12)
about:SetJustifyH("LEFT")
about:SetJustifyV("TOP")
about:SetWordWrap(true)
about:SetText("Thème et reskin pour RestedXP Guides : 6 looks de fenêtre "
    .. "de guide, flèche de navigation personnalisée, route sur la carte "
    .. "du monde et la minicarte, overlays de farm / patrouille / fouille, "
    .. "et des couleurs entièrement réglables.\n\n"
    .. "FUI-RestedXP a sa propre fenêtre de paramètres. Cliquez ci-dessous "
    .. "ou utilisez /fuirxp pour l'ouvrir.")

local open = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
open:SetSize(220, 26)
open:SetPoint("TOPLEFT", about, "BOTTOMLEFT", 0, -16)
open:SetText("Ouvrir les paramètres")
open:SetScript("OnClick", OpenSettings)

local hint = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
hint:SetPoint("TOPLEFT", open, "BOTTOMLEFT", 0, -8)
hint:SetText("/fuirxp  •  /fuirxp status  •  /fuirxp reset")

-- Live status line (engine + layout), refreshed whenever the page shows.
local status = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
status:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -12)
local function RefreshStatus()
    local db = ns.DB and ns.DB()
    if not db then
        status:SetText("")
        return
    end
    status:SetText("Moteur : " .. (db.rxpEnabled and "activé" or "coupé")
        .. "  •  Look : " .. tostring(db.rxpLayout or "?"))
end
frame:SetScript("OnShow", RefreshStatus)

ns.About = { frame = frame, open = OpenSettings, status = RefreshStatus }

if Settings and Settings.RegisterCanvasLayoutCategory
        and Settings.RegisterAddOnCategory then
    local category = Settings.RegisterCanvasLayoutCategory(frame, "FUI-RestedXP")
    Settings.RegisterAddOnCategory(category)
    ns.About.category = category
elseif InterfaceOptions_AddCategory then
    -- Pre-Settings clients: the legacy door.
    InterfaceOptions_AddCategory(frame)
end
