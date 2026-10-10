-- FUI-RestedXP Skin.lua (standalone)
-- The addon's own skin lives on the Theme page only: the RestedXP theme
-- "Fr33noX-UI by FUI-RestedXP", whose colors follow the live accent (or the
-- custom color). Everything else on the guide window is the reskin engine
-- (Reskin.lua) -- untouched.
--
-- One functional job remains here: RestedXP's own "Guide Window v2"
-- (Interface V2, Beta) hides and disables the legacy guide window entirely
-- (v2:DisableLegacyGuideWindow), so the engine would have no steps to read
-- and nothing to draw. Unless the user asks for v2 (the "Classic Guide
-- Window" toggle off), v2 is turned back off and the classic window shown
-- again; a /reload finishes the restore.

local ADDON_NAME, ns = ...

ns.Skin = ns.Skin or {}
ns.modules.skin = ns.Skin

local function DB() return ns.DB() end

-- RXP's "Guide Window v2" state. Unless the user asks for v2
-- (skinForceClassic off), we report v2 as off and turn its two profile keys
-- back off (see ForceClassicWindow).
function ns.V2GuideWindow()
    local db = DB()
    if db and db.skinForceClassic == false then return false end
    local RXP = ns.GetRXP()
    return not not (RXP and RXP.v2 and RXP.v2.IsGuideWindowEnabled
        and RXP.v2:IsGuideWindowEnabled())
end

-- Turn RXP's Guide Window v2 off and bring the legacy window back. Each
-- Show is pcall'd: a protected frame refuses during combat and the
-- regen-end watcher below retries.
function ns.Skin:ForceClassicWindow()
    if not ns.V2GuideWindow() then return end
    local RXP = ns.GetRXP()
    local profile = RXP and RXP.settings and RXP.settings.profile
    if not profile then return end
    profile.enableV2Interface = false
    profile.enableBetaFeatures = false
    local legacy = _G.RXPFrame
    if legacy then
        pcall(legacy.Show, legacy)
        for _, f in ipairs({ legacy.BottomFrame, legacy.GuideName, legacy.Footer,
            legacy.CurrentStepFrame, legacy.ScrollFrame, legacy.ScrollChild }) do
            if f then pcall(f.Show, f) end
        end
    end
    print(ns.AccentHex() .. "FUI-RestedXP|r: RestedXP's Guide Window v2 is off"
        .. " (it hides the window the reskin works on). /reload to finish.")
end

-- True when the user picked our theme in RXP's own settings (its dropdown).
local function ThemeIsOurs()
    local RXP = ns.GetRXP()
    local profile = RXP and RXP.settings and RXP.settings.profile
    if not profile then return false end
    return profile.activeTheme == ns.Theme.name
end

function ns.Skin:IsThemeActive()
    return ThemeIsOurs()
end

-- Why the tint is or is not on the arrow right now (shown by /euirxp
-- status): the theme RXP currently has selected, the arrow frame, whether
-- the engine's arrow card is drawing (its own distance colors win), the
-- color source, and the resulting gate.-- The arrow tint, as a table of pairs rather than a "|"-joined string:
  -- /euirxp status prints one variable per line, and a joined line wrapped
  -- into an unreadable block in the chat frame. The caller fixes the order,
  -- a hash table has none of its own.
  function ns.Skin:TintState()
      local RXP = ns.GetRXP()
      local profile = RXP and RXP.settings and RXP.settings.profile
      local theme = profile and profile.activeTheme or "?"
      local af = _G.RXPG_ARROW
      local owns = ns.RestedXP and ns.RestedXP.ArrowOwnsText and ns.RestedXP.ArrowOwnsText()
      local r, g, b = ns.ThemeAccent()
      local gated = ns.IsReady() and self:IsThemeActive()
      return {
          theme = tostring(theme),
          frame = af and "yes" or "NO",
          engineArrow = owns and "on (custom arrow)" or "off",
          accent = ("%.2f/%.2f/%.2f"):format(r, g, b),
          tint = gated and "ON" or "OFF",
      }
  end

-- One-click activation from our Theme options page: select the theme in
-- RXP's settings, re-render, and re-tint the arrow right away (nothing else
-- repaints the arrow on a plain theme switch).
function ns.Skin:ActivateTheme()
    local RXP = ns.GetRXP()
    local profile = RXP and RXP.settings and RXP.settings.profile
    if not (profile and ns.Theme) then return false end
    profile.activeTheme = ns.Theme.name
    if RXP.RenderFrame then
        RXP.RenderFrame(true)
    end
    self:Refresh()
    return true
end

-- One-click deactivation (the Theme page's second button): hand the window
-- back to RestedXP's own stock theme -- "RXP Blue", its fresh-install
-- default -- and re-render. Our theme table stays registered (harmless), it
-- just is not selected; the arrow tint stands down with it (IsThemeActive).
function ns.Skin:DeactivateTheme()
    local RXP = ns.GetRXP()
    local profile = RXP and RXP.settings and RXP.settings.profile
    if not profile then return false end
    profile.activeTheme = "RXP Blue"
    if RXP.RenderFrame then
        RXP.RenderFrame(true)
    end
    -- Hands the arrow back to RestedXP's stock theme: Refresh runs
    -- SkinArrow, whose hand-back reloads RXP's theme from the profile and
    -- restores the stock texture file and vertex color (RestoreArrow).
    self:Refresh()
    return true
end

-- ---------------- Live accent follow (standalone) ----------------
-- In the standalone build the accent only changes when the user changes
-- the Theme page color, so the refresh path is the Theme page itself
-- plus ns.Refresh -- not a live callback.
-- ---------------- Distance unit (yd -> m) ----------------
-- WoW's yard and meter are the same distance (1:1), so switching unit only
-- rewrites the label. This matters while "Custom Arrow" is OFF (and with
-- RestedXP's own window): the arrow then shows RestedXP's raw "177yd" text,
-- which nothing else relabels -- the engine's arrow card only runs while the
-- custom arrow is ON, and it labels meters itself (R.ArrowOwnsText gates
-- this rewrite off then). RXP writes "Step 22\n(177yd)" whenever the
-- distance changes; the rewrite hooks that and only edits the suffix, so
-- rotation, position and hiding stay entirely RXP's.
local function UnitLabel()
    local db = DB()
    return (db and db.rxpMeters) and "m" or "yd"
end

local function RewriteDistance(text)
    -- "(177yd)" <-> "(177m)"; the number itself is never touched. Both
    -- directions: RestedXP only rewrites its arrow text when the DISTANCE
    -- changes, so a "m" we wrote lingers in its text after Meters is turned
    -- back off -- and the engine's parser accepts either unit, but the
    -- label must follow the current setting.
    local unit = UnitLabel()
    local other = unit == "m" and "yd" or "m"
    local out = (text:gsub("(%(%s*%d+)%s*" .. other .. "%)", "%1" .. unit .. ")"))
    -- Some RXP elements put a bare "120yd" on its own line. The frontier
    -- pattern keeps the unit clear of longer words (Lua has no \b).
    out = (out:gsub("(%d+)%s*" .. other .. "%f[^%a]", "%1" .. unit))
    return out
end

local arrowTextHooked
local function HookArrowText(af)
    if arrowTextHooked or not (af and af.text) then return end
    arrowTextHooked = true
    hooksecurefunc(af.text, "SetText", function(_, t)
        if type(t) ~= "string" then return end
        if ns.IsSecret and ns.IsSecret(t) then return end
        -- The engine's card owns the label while the custom arrow is on.
        if ns.RestedXP and ns.RestedXP.ArrowOwnsText and ns.RestedXP.ArrowOwnsText() then return end
        -- Only rewrite when it actually changes the text: the rewrite
        -- always removes the other unit, so the inner SetText below hits
        -- "out == t" and stops -- no recursion.
        local out = RewriteDistance(t)
        if out ~= t then
            af.text:SetText(out)
        end
    end)
end

-- Re-run the rewrite on the arrow's current text right away (so flipping
-- "Meters on the Arrow" while "Custom Arrow" is off takes effect at once,
-- in both directions; RXP refreshes the text on every distance change
-- otherwise).
local function ApplyUnitNow()
    local af = _G.RXPG_ARROW
    if not (af and af.text) then return end
    if ns.RestedXP and ns.RestedXP.ArrowOwnsText and ns.RestedXP.ArrowOwnsText() then return end
    local t = af.text:GetText()
    if type(t) ~= "string" then return end
    local out = RewriteDistance(t)
    if out ~= t then
        af.text:SetText(out)
    end
end

-- ---------------- Arrow tint (the Theme page's color) ----------------
-- Our theme declares RestedXP's DarkMode texture set, so the arrow RXP
-- resolves for it is the nearly-black DarkMode one. The readable arrow is
-- the Blue theme's (the v2 file); while our theme is selected and the
-- engine's arrow card is NOT drawing (the DEFAULT layout, or "Custom Arrow"
-- off), the arrow is switched to that file and tinted with the shared color
-- source: the live accent when "Follow Accent" is on, the custom color when
-- it is off. The engine's custom arrows keep their own color logic
-- (distance, heading) -- they are never black to begin with.
-- RXP's per-theme arrows (DarkMode's AND the Blue theme's v2 one) are
-- finished, pre-colored art: vertex-color-tinting them multiplies and stays
-- dark. So the tint paints the Blue theme's own arrow shape, rebuilt as
-- tintable art (decoded from RXP's BLP: RGB pushed to white, alpha kept --
-- Textures/rxp-arrow-v2.png): identical silhouette, any vertex color works.
local TINT_TEX = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Textures\\rxp-arrow-v2.png"

-- Put RestedXP's stock arrow back after our tint. Two things to undo: the
-- texture file we set, and the vertex color we painted it with. The file
-- RXP resolves depends on addon.activeTheme, which our hand-off has just
-- made stale (it still points at our theme table) -- reload it from the
-- profile first, then let RXP repaint, then reset the color: nothing in
-- RXP ever touches the vertex color (its DrawArrow only sets the texture
-- and the rotation), so a SetTexture alone would keep our tint on its
-- stock art.
local function RestoreArrow(af)
    local RXP = ns.GetRXP()
    if RXP and RXP.LoadActiveTheme then pcall(RXP.LoadActiveTheme, RXP) end
    if af.UpdateVisuals then pcall(af.UpdateVisuals, af) end
    af.texture:SetVertexColor(1, 1, 1, 1)
    -- Re-assert the stock file from RXP's freshly loaded theme (covers a
    -- failed UpdateVisuals and the v2 arrow, whose file lives in the v2
    -- theme table rather than behind GetV1Texture).
    local tex
    local v2 = RXP and RXP.v2
    if v2 and v2.GetTheme and v2.IsGuideWindowEnabled and v2:IsGuideWindowEnabled() then
        local ok, t = pcall(v2.GetTheme, v2)
        if ok and type(t) == "table" and type(t.navigationArrow) == "string" then
            tex = t.navigationArrow
        end
    end
    if not tex and RXP and RXP.GetV1Texture then
        local ok, t = pcall(RXP.GetV1Texture, "rxp_navigation_arrow-1")
        if ok and type(t) == "string" then tex = t end
    end
    if tex then
        af.texture:SetTexture(tex)
    elseif not RXP then
        -- RXP's object is gone (unload edge case): fall back to its stock
        -- Blue arrow file so a stale themed texture cannot linger.
        af.texture:SetTexture("Interface/AddOns/RXPGuides/Textures/rxp_navigation_arrow-1")
    end
end

local arrowHooked
local arrowWasOurs
local function SkinArrow()
    local af = _G.RXPG_ARROW
    if not (af and af.texture) then return end
    -- The engine's arrow card draws its own arrow (distance colors):
    -- stand down while it does.
    if ns.RestedXP and ns.RestedXP.ArrowOwnsText and ns.RestedXP.ArrowOwnsText() then return end
    if not arrowHooked then
        arrowHooked = true
        -- RestedXP repaints the arrow on theme changes and window
        -- re-renders (SetTexture swaps the file and keeps whatever vertex
        -- color is set): re-apply the tint after each of its repaints.
        if af.UpdateVisuals then
            hooksecurefunc(af, "UpdateVisuals", function() SkinArrow() end)
        end
    end
    -- The theme owns the arrow whenever it is selected in RXP's settings --
    -- whether or not the reskin engine is on (the engine's arrow card, when
    -- it draws, stands this down above). Picking another theme stands the
    -- tint down: the hand-back below restores RestedXP's own texture.
    local tint = ns.IsReady() and ns.Skin:IsThemeActive()
    if tint then
        -- The tintable arrow shape (the Blue theme's silhouette, rebuilt
        -- white from RXP's BLP), in the Theme page's color. The tint (a
        -- vertex-color multiply) goes after SetTexture so it colors the
        -- file just set.
        af.texture:SetTexture(TINT_TEX)
        local r, g, b = ns.ThemeAccent()
        af.texture:SetVertexColor(r, g, b, 1)
    elseif arrowWasOurs then
        -- Our theme was just deselected: hand the arrow back -- reload
        -- RXP's own theme, restore its stock texture file and clear our
        -- tint. Clear the flag BEFORE the call: RestoreArrow runs
        -- UpdateVisuals, which re-enters this function through the hook
        -- above, and with the flag still set the hand-back would call
        -- itself forever (client freeze).
        arrowWasOurs = false
        RestoreArrow(af)
    end
    arrowWasOurs = tint
end

-- ---------------- Module refresh ----------------
function ns.Skin:Refresh()
    if not ns.IsReady() then return end
    -- RXP's Guide Window v2 hides the legacy window (nothing for the
    -- engine to read): turn it back off unless the user asked for it.
    if ns.V2GuideWindow() then
        ns.Skin:ForceClassicWindow()
    end
    -- The unit rewrite installs its one hook and gates itself, so it keeps
    -- working whatever the layout, reskin or arrow settings.
    local af = _G.RXPG_ARROW
    if af then HookArrowText(af) end
    ApplyUnitNow()
    -- The arrow tint: live on accent changes (the fan-out calls this) and
    -- on custom-color changes (ns.Refresh does).
    SkinArrow()
end

-- ---------------- Login ----------------
table.insert(ns.onLogin, function()
    -- A RestedXP update or profile import can turn v2 back on mid-session:
    -- retry at the end of every combat (protected frames then allow Show).
    local w = CreateFrame("Frame")
    w:RegisterEvent("PLAYER_REGEN_ENABLED")
    w:SetScript("OnEvent", function()
        if ns.V2GuideWindow() then pcall(ns.Skin.ForceClassicWindow, ns.Skin) end
    end)
    ns.Skin:Refresh()
    -- RestedXP loading after us: its arrow frame does not exist yet, so the
    -- tint (and the unit rewrite) need one more pass once it is up.
    ns.OnRXPLoaded(function() ns.Skin:Refresh() end)
end)
