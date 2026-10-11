-- FUI-RestedXP WaypointBridge.lua
-- The "WaypointUI" arrow style (rxpArrowStyle == "WAYPOINT"): our arrow card
-- stays hidden, RestedXP's own arrow visuals stay hidden, and the guide's
-- current target is driven through WaypointUI's waypoint instead.
-- Runtime API calls only -- no WaypointUI code is copied here -- so this is
-- a no-op when WaypointUI is absent: the style then falls back to hiding
-- our card while RestedXP's own arrow shows (see R.SkinArrow).
local ADDON_NAME, ns = ...

local FLAG = "FUIRXP_Waypoint"   -- marks waypoints we placed (never the user's)
-- The corpse run's own waypoint visuals: the raid skull -- the SAME texture
-- MapRoute draws on the red route line (MapRoute.lua's CORPSE_SKULL) -- and
-- its blood-red tint, so every surface pointing back to the body wears the
-- run's colour. WaypointUI recolors a custom navigation that carries r/g/b
-- (its Waypoint.GetTintColorInfo recolor = requestRecolor or true), so the
-- skull goes red without any option of ours being ignored.
local CORPSE_ICON = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8"
local CORPSE_COLOR = { 0.72, 0.025, 0.025 }
-- One colour drives the icon AND the footer texts inside WaypointUI
-- (SetTint -> ContextIcon + Footer.InfoText/DistanceText/ArrivalTime):
-- pushing red makes the waypoint's words red too. The words stay "normal":
-- after every corpse push the texts are set back to white, and the 1s
-- ticker re-asserts it, because WaypointUI repaints the tint from our
-- pushed r/g/b whenever it updates (Waypoint.UpdateColor).
local CORPSE_TEXT_COLOR = { 1, 1, 1 }
local function KeepCorpseTextNormal()
    for _, frameName in ipairs({ "WUIWaypointFrame", "WUIPinpointFrame", "WUINavigatorFrame" }) do
        local frame = _G[frameName]
        local footer = frame and frame.Footer
        for _, key in ipairs({ "InfoText", "DistanceText", "ArrivalTimeText" }) do
            local text = footer and footer[key]
            if text and text.SetTextColor then
                pcall(text.SetTextColor, text,
                    CORPSE_TEXT_COLOR[1], CORPSE_TEXT_COLOR[2], CORPSE_TEXT_COLOR[3], 1)
            end
        end
    end
end
local last = { map = nil, x = nil, y = nil, src = nil }
local armed = false              -- true once we have ever pushed (then clears matter)
local ticks = 0                  -- skin passes since login (0 = never called: no RXP repaint yet)
local lastErr = nil              -- last push/spot failure, shown in /status

local function Nav()
    local api = _G.WaypointUIAPI
    local nav = api and api.Navigation
    if type(nav) ~= "table" then return nil end
    if type(nav.NewUserNavigation) ~= "function" then return nil end
    return nav
end

function ns.WaypointAvailable()
    return Nav() ~= nil
end

local function StyleOn()
    local db = ns.DB and ns.DB()
    return db and db.rxpArrow ~= false and db.rxpArrowStyle == "WAYPOINT"
end

local function ClearOurs(nav)
    if type(nav.IsUserNavigationFlagged) == "function"
        and type(nav.ClearUserNavigation) == "function" then
        local ok, flagged = pcall(nav.IsUserNavigationFlagged, FLAG)
        if ok and flagged then pcall(nav.ClearUserNavigation) end
    end
end

local function round(v)
    return math.floor((tonumber(v) or 0) * 10000 + 0.5)
end

-- Called from the arrow skin pass: pushes RestedXP's current target to
-- WaypointUI when the style is on, takes our waypoint back down otherwise.
-- Re-pushes only when the rounded target moved, so a user waypoint placed
-- over ours is left alone until the guide actually moves on.
function ns.WaypointTick()
    ticks = ticks + 1
    local nav = Nav()
    if not (nav and StyleOn() and ns.MapRouteSpot) then
        if armed then
            armed = false
            last.map, last.x, last.y, last.src, last.label = nil, nil, nil, nil, nil
            if nav then ClearOurs(nav) end
        end
        return
    end
    armed = true
    local res = { pcall(ns.MapRouteSpot) }
    local id, x, y, label, src = res[2], res[3], res[4], res[5], res[6]
    if not (res[1] and type(id) == "number" and type(x) == "number" and type(y) == "number") then
        if not res[1] then lastErr = "spot: " .. tostring(id):sub(1, 120) end
        ClearOurs(nav)
        last.map, last.x, last.y, last.src, last.label = nil, nil, nil, nil, nil
        return
    end
    local rx, ry = round(x), round(y)
    -- The live name colours: swapped here, the pushed label follows the
    -- options within a second -- no /reload. The label joins the change
    -- check, so a recolour alone re-pushes (WaypointUI only repaints its
    -- text when the pushed string actually differs).
    if type(label) == "string" and ns.RestedXP and ns.RestedXP.RecolorNames then
        label = ns.RestedXP.RecolorNames(label)
    end
    if last.map == id and last.x == rx and last.y == ry and last.label == label then return end
    last.map, last.x, last.y, last.src, last.label = id, rx, ry, src, label
    -- WaypointUI takes 0..100 here (its CreateMapPoint divides by 100;
    -- same convention as TomTom): passing our normalized 0..1 as-is
    -- lands the marker in the map's top-left corner with no error.
    -- A corpse run's push carries the death icon: the guide's pushes get
    -- no visual options at all and keep WaypointUI's own arrow icon.
    local corpsePush = (src == "corpse")
    local pok, perr = pcall(nav.NewUserNavigation,
        corpsePush and {
            name = (type(label) == "string" and label ~= "") and label or "RestedXP",
            mapID = id,
            x = x * 100,
            y = y * 100,
            flags = FLAG,
            iconTexture = CORPSE_ICON,
            r = CORPSE_COLOR[1],
            g = CORPSE_COLOR[2],
            b = CORPSE_COLOR[3],
            requestRecolor = true,
        } or {
            name = (type(label) == "string" and label ~= "") and label or "RestedXP",
            mapID = id,
            x = x * 100,
            y = y * 100,
            flags = FLAG,
        })
    if not pok then lastErr = "push: " .. tostring(perr):sub(1, 120) return end
    if corpsePush then KeepCorpseTextNormal() end
    lastErr = nil
end

-- RestedXP's repaints (which drive SkinArrow) don't fire while standing
-- still, so the style would never push until the player moves: a slow 1s
-- ticker covers login, guide loads and step changes anywhere. Gated on
-- the style itself -- one string compare per second otherwise.
local lastAvail = nil              -- WaypointUI seen on the last tick (late loads flip it)
if C_Timer and C_Timer.NewTicker then
    C_Timer.NewTicker(1, function()
        local db = ns.DB and ns.DB()
        if db and db.rxpArrowStyle == "WAYPOINT" and ns.WaypointTick then
            ns.WaypointTick()
            -- WaypointUI loading after us left the stock arrow up (SkinArrow
            -- fell back while the API was absent): once the API appears the
            -- push alone is not enough, the arrow visuals must hide too.
            local avail = Nav() ~= nil
            if avail ~= lastAvail then
                lastAvail = avail
                if ns.RestedXP and ns.RestedXP.SkinArrow then ns.RestedXP.SkinArrow() end
            end
            -- Re-assert while the corpse run lasts: a corpse push repaints
            -- the tint red (icon included) until the next tick turns the
            -- texts back; a guide push leaves WaypointUI's own colouring.
            if last.src == "corpse" then KeepCorpseTextNormal() end
        end
    end)
end

-- One line for /fuirxp status while the style is on: what WE pushed (map,
-- normalized coords, which answer it was) so a misplaced marker can be
-- told apart -- stale arrow element vs wrong step vs bad coordinates.
function ns.WaypointStatus()
    local nav = Nav()
    if not nav then return "WaypointUI not installed" end
    if lastErr then return "ERROR " .. lastErr end
    if not armed or not last.map then
        return ("idle (no target, checks=%d)"):format(ticks)
    end
    return ("pushed map %d @ %.4f, %.4f (%s)"):format(
        last.map, (last.x or 0) / 10000, (last.y or 0) / 10000,
        tostring(last.src or "?"))
end
