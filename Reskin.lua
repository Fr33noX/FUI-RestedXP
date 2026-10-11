-- FUI-RestedXP: the RestedXP guide window reskin engine.
-- Layout and arrow styling originally adapted from Jo's LiteTweaks 1.46
-- (RestedXP.lua), with permission sought per its distribution terms.
-- Six of our own layouts (the Layout setting) plus RestedXP's
-- own window (DEFAULT):
--   FRAMELESS: no panel at all, outlined text straight on the world: the
--     zone with its level range and the guide's %, the current steps on
--     dark cards (instruction, objectives with a thin bar, notes marked
--     "i" / "!"), then the next steps, fading out.
--   TIMELINE: a panel with a navy header fading into it (zone, level pill,
--     "Step 12 of 84", the guide's % on the right), the current steps on a
--     faint blue band, then the next steps in grey; each step marked by its
--     number on a line running between them.
--   COMPACT: a solid window with a title bar ("‹ 2/189 ›" step buttons),
--     each line carrying RestedXP's own icon, and a progress bar along the
--     bottom.
--   ZYGOR: the Zygor-style window: a tab, a step row ("← 14 →"), goals to
--     do on a red band, done ones greyed, a green progress bar.
--   BIT8: the 8-Bit quest log: pixel fonts (Silkscreen / VT323), a block
--     progress bar, CRT scanlines, "◀ B / A ▶" step buttons.
--   RAIL: a vertical rail down the left with one marker per step: the
--     current steps on a filled accent marker, the upcoming ones hollow
--     with their number at the right. No panel, the rail carries the
--     structure.
-- (Three more layouts were prototyped alongside it -- Cards, Minimal and
-- Journal -- and taken back out for now; the shared helpers below are
-- what they were built on, so another one is a renderer away.)
-- In every layout: click a current step to skip it (it wipes green and
-- slides off; a step done ticks and folds away), right-click it to go back
-- a step (it comes back tagged "Back"); the mouse wheel scrolls the step
-- list; double-click a listed step to go to it; right-click for RestedXP's
-- menu. RestedXP's window stays alive underneath (invisible and
-- click-through) and ours reads its steps after each of its updates.
-- The waypoint arrow is picked by the Arrow Style setting, in every layout:
-- one chevron, the engine's card, its shaded Classic arrow, its Zygor-style
-- arrowhead, TomTom's real arrow or Zygor's Stealth arrow (a sprite sheet
-- of pre-drawn angles), or the layout's own. RestedXP's own arrow
-- underneath still points, moves and hides itself.
--
-- RestedXP's files are never touched. Turning the reskin off gives RestedXP
-- its own window, arrow and boxes back straight away (the boxes stay where
-- they were placed until a /reload).
local ADDON, ns = ...
local IsSecret = ns.IsSecret

local R = {}
ns.RestedXP = R
ns.modules.restedxp = R

local function DB() return ns.DB() end

local WHITE = "Interface\\Buttons\\WHITE8X8"
-- A leaving step card: the tick badge, and how long each animation runs.
local CHECK = "Interface\\AddOns\\" .. ADDON .. "\\Textures\\rxp-check.png"
local BACK = "Interface\\AddOns\\" .. ADDON .. "\\Textures\\rxp-back.png"
local DONE_TIME, SKIP_TIME, BACK_TIME = 0.68, 1.06, 1
local FLAT = { bgFile = WHITE, edgeFile = WHITE, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } }

local function Enabled()
    local db = DB()
    return db and db.rxpEnabled and _G.RXPFrame ~= nil
end

-- The layout: FRAMELESS (the default), TIMELINE, COMPACT, ZYGOR, BIT8, or DEFAULT
-- (RestedXP's own window). Each of ours has its own APPEARANCE settings.
local LAYOUTS = { FRAMELESS = "rxpFl", TIMELINE = "rxpTl", COMPACT = "rxpCp", ZYGOR = "rxpZg", BIT8 = "rxpBt", RAIL = "rxpRl", DEFAULT = "rxpFl" }
local function Layout()
    local l = DB().rxpLayout
    return LAYOUTS[l] and l or "FRAMELESS"
end

-- "5/10 Cactus Apple": the first a/b in the objective's plain text.
local function Plain(text)
    return (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", ""):gsub("|A.-|a", ""))
end
local function Count(text)
    if type(text) ~= "string" or IsSecret(text) then return nil end
    local cur, max = Plain(text):match("(%d+)%s*/%s*(%d+)")
    cur, max = tonumber(cur), tonumber(max)
    if cur and max and max > 0 then return math.min(cur, max), max end
end

-- What an objective's label keeps when the count is drawn on its own at the
-- right of the line. The guide's text carries the count inside it -- leading
-- ("10/12 Name") or trailing with the quest log's words after it
-- ("Name : 10/12 personnages tués") -- and printing it as well would show the
-- number twice. Everything from the count on is the count and its boilerplate.
local function ObjLabel(text)
    local s = Plain(text)
    s = s:gsub("^%s*%d+%s*/%s*%d+%s*", "")
    s = s:gsub("%s*:?%s*%d+%s*/%s*%d+.*$", "")
    s = s:gsub("%s*[-:]%s*$", "")
    return (s:gsub("%s+$", ""))
end

local function Bar(parent, holder)
    if holder.ltBar then return holder.ltBar end
    local bg = parent:CreateTexture(nil, "ARTWORK")
    bg:SetTexture(WHITE)
    local fill = parent:CreateTexture(nil, "ARTWORK", nil, 1)
    fill:SetTexture(WHITE)
    fill:SetPoint("TOPLEFT", bg, "TOPLEFT")
    fill:SetPoint("BOTTOMLEFT", bg, "BOTTOMLEFT")
    holder.ltBar = { bg = bg, fill = fill }
    return holder.ltBar
end

-- Timeline: an objective's bar height.
local BAR_H = 3

-- =====================================================================
-- The window
-- =====================================================================
-- RestedXP's window: invisible and click-through while ours shows (it keeps
-- running: its steps are what we draw). Everything we switch off is
-- remembered so turning the reskin off can switch it back on.
local silenced = setmetatable({}, { __mode = "k" })
local function Silence(frame)
    local locked = InCombatLockdown() and frame.IsProtected and frame:IsProtected()
    if not locked then
        if frame.IsMouseEnabled and frame:IsMouseEnabled() and pcall(frame.EnableMouse, frame, false) then
            silenced[frame] = true
        end
        if frame.IsMouseWheelEnabled and frame:IsMouseWheelEnabled() and pcall(frame.EnableMouseWheel, frame, false) then
            silenced[frame] = true
        end
    end
    for _, child in ipairs({ frame:GetChildren() }) do Silence(child) end
end

-- The full walk over RestedXP's frames is the expensive part, so it runs at
-- most once a second (its step boxes are silenced again right after each of
-- its own layouts, in the UpdateText hook).
local lastSilence = 0
local function HideRXP(on)
    local f = _G.RXPFrame
    if on then
        f:SetAlpha(0)
        local now = GetTime()
        if now - lastSilence > 1 then
            lastSilence = now
            Silence(f)
        end
    elseif next(silenced) or f:GetAlpha() == 0 then
        f:SetAlpha(1)
        lastSilence = 0
        for frame in pairs(silenced) do
            pcall(frame.EnableMouse, frame, true)
            silenced[frame] = nil
        end
        local sf = f.ScrollFrame
        if sf then pcall(sf.EnableMouseWheel, sf, true) end
    end
end

-- RestedXP's own window is the frame World of Warcraft clamps to the screen
-- while the header is dragged, and it is also what the drag handler moves.
-- With a reskin layout up, what is on screen is our own (narrower) window,
-- but RestedXP's frame keeps its stock width, so the drag stops exactly where
-- that wider width would end and the tracker never reaches the right edge.
-- Hand RestedXP's frame the width that is really on screen: its contents stay
-- hidden and click-through, so nothing else about it changes, and the clamp
-- finally matches the visible window. The stock width is remembered once and
-- given back when the reskin goes off (or on RestedXP's own DEFAULT layout).
local function FitRXPWidth(width)
    local rxp = _G.RXPFrame
    if not (rxp and type(width) == "number") then return end
    if not rxp.ltStockWidth then rxp.ltStockWidth = rxp:GetWidth() end
    local w = math.floor(width + 0.5)
    if w > 0 and rxp:GetWidth() ~= w then rxp:SetWidth(w) end
end

local function RestoreRXPWidth()
    local rxp = _G.RXPFrame
    if rxp and rxp.ltStockWidth and rxp:GetWidth() ~= rxp.ltStockWidth then
        rxp:SetWidth(rxp.ltStockWidth)
    end
end

local W   -- the window
local pools = { text = {}, bar = {}, hit = {}, tex = {}, num = {}, seg = {} }
local used

-- ---------------- Collapse (click the zone name) ----------------
-- A left click on the window's header (the zone-name strip, every layout)
-- collapses the body under it: the window folds down to the header alone,
-- then unfolds back. One state and one animation for every layout, because
-- all six render into the same W and end their pass with a height:
-- their SetHeight goes through R.SetBodyHeight here, which reports the
-- body's full height first (the collapse reads it) and then clamps the
-- frame to header + body*(1-fold). The extra W.content clip keeps the
-- body's pooled pieces (textures pinned to the frame's TOPLEFT) inside the
-- visible layout while the frame is tall again during the animation.
-- The 0.22s ease-out is the same curve the step cards use.
local Ease
Ease = function(p) return 1 - (1 - p) * (1 - p) end   -- forward decl; the card
                     -- transitions' own copy below stays the single truth
R.collapsed = false
R.collapseFold = 0          -- 0 open .. 1 collapsed
local collapseAnim          -- OnUpdate driver while a fold runs
local collapseClickAt       -- mouse-down time: a click, not a drag
local collapseDownX, collapseDownY  -- window's corner at the down (drag check)
local collapseBodyH = 0     -- last reported body height (0 = never drawn)
local COLLAPSE_L = 22       -- left reserve for the +/- switch: 18px button + 4 margin

local function CollapseHeaderH()
    -- The header's own height band: the click-catcher covers it (each
    -- renderer sets W.header:SetHeight), so its height IS the answer.
    if W and W.header and W.header.GetHeight then return W.header:GetHeight() or 0 end
    return 0
end

-- The +/- switch: a click target on the header's left end, right before
-- the zone text, so the fold has an obvious handle in every layout (the
-- header itself keeps the click toggle too). Built once, repositioned per
-- pass; every renderer leaves it a COLLAPSE_L reserve. The
-- label is a plain hyphen: the prettier minus sign U+2212 has no glyph in
-- the client's fonts and rendered as nothing. The label gets a real font
-- here -- a FontString without SetFont shows no text at all, which left
-- the button invisible (no Normal texture to fall back on).
local function CollapseButton()
    if not W then return nil end
    if W.collapseBtn then return W.collapseBtn end
    local b = CreateFrame("Button", nil, W.header)
    b:SetSize(18, 18)
    b:SetFrameLevel((W.header:GetFrameLevel() or 0) + 3)   -- over the drag strip
    b:RegisterForClicks("LeftButtonUp")
    b.label = b:CreateFontString(nil, "OVERLAY")
    b.label:SetAllPoints()
    b.label:SetJustifyH("CENTER")
    b.label:SetJustifyV("MIDDLE")
    ns.ApplyFont(b.label, nil, 15, "OUTLINE")
    b.label:SetTextColor(1, 1, 1, 1)
    b.label:SetShadowOffset(1, -1)
    b.label:SetShadowColor(0, 0, 0, 0.8)
    b:SetHighlightTexture("Interface\\Buttons\\WHITE8X8")
    b:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.15)
    b:SetScript("OnClick", function() R.ToggleCollapse() end)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(R.collapsed and "Show the guide" or "Hide the guide")
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b.label:SetText(R.collapsed and "+" or "-")
    b.label:Show()
    W.collapseBtn = b
    return b
end

local function PlaceCollapseButton()
    local b = CollapseButton()
    if not (b and W and W.header) then return end
    -- Left end, before the zone text (which every renderer starts past
    -- COLLAPSE_L), centred on the title itself: each renderer hands its
    -- title string over in W.collapseAnchorFs, so the switch sits on the
    -- text's middle whatever the header band around it holds (Frameless'
    -- underline, Rail's padding). Without an anchor (Zygor's centred
    -- title) it parks top-left, centred on the header band instead.
    b:ClearAllPoints()
    local anchor = W.collapseAnchorFs
    if anchor and anchor.IsShown and anchor:IsShown() then
        b:SetPoint("RIGHT", anchor, "LEFT", -4, 0)
    else
        local header = CollapseHeaderH()
        b:SetPoint("TOPLEFT", W, "TOPLEFT", 2, -math.max(2, (header - 18) / 2))
    end
    b:SetShown(W:IsShown())
    if b.label:GetText() ~= (R.collapsed and "+" or "-") then
        b.label:SetText(R.collapsed and "+" or "-")
    end
end

function R.SetBodyHeight(h)
    -- A persisted "collapsed" state is only a wish until the first pass
    -- confirms it: the fold starts fully closed if no animation is running,
    -- so a /reload reopens nothing and the next click unfolds.
    if R.collapsed and R.collapseFold < 1 and not R.collapseAnimating then
        R.collapseFold = 1
    end
    local header = CollapseHeaderH()
    if R.collapseFold > 0 and header > 0 and h and h > 0 then
        -- Remember the FULL height this pass reports: it is the unfold
        -- animation's target. It must never be confused with the height we
        -- render, or a collapsed window would report a zero body and the
        -- unfold click would do nothing (that was the "nothing happens").
        collapseBodyH = math.max(h, collapseBodyH)
        local shown = math.max(1, header + (h - header) * (1 - R.collapseFold))
        W:SetHeight(shown)
    elseif h and h > 0 then
        collapseBodyH = h
        W:SetHeight(h)
    else
        collapseBodyH = 0
        W:SetHeight(h or 0)
    end
    -- Keep the pooled body pieces (pinned to the frame's TOP corners)
    -- inside the frame while it folds: a clip, not a hide, so the fold
    -- reads as a curtain falling rather than pieces popping out.
    if W.content and W.content.SetClipsChildren then
        W.content:SetClipsChildren(R.collapseFold > 0)
    end
    PlaceCollapseButton()
end
local function CollapseApply()
    -- Re-render into the current fold (the renderers read it for their
    -- heights and alphas); re-drawing is what animates, as for the cards.
    R.Skin()
end

function R.ToggleCollapse()
    local header = CollapseHeaderH()
    if not (W and W:IsShown() and header and header > 0 and collapseBodyH > 0) then return end
    R.collapsed = not R.collapsed
    local db = DB()
    if db then db.rxpWindowCollapsed = R.collapsed end
    local from, to = R.collapseFold, R.collapsed and 1 or 0
    if from ~= to then
        -- The fold follows a GetTime clock, Ease curve in: re-rendering on
        -- every frame is what animates, exactly like a leaving step card.
        R.collapseAnimating = true
        local t0 = GetTime()
        R.anim = R.anim or CreateFrame("Frame")
        R.anim:SetScript("OnUpdate", function(self)
            local k = math.min(1, (GetTime() - t0) / 0.22)
            R.collapseFold = from + (to - from) * Ease(k)
            if k >= 1 then
                R.collapseFold = to
                self:SetScript("OnUpdate", nil)
                R.collapseAnimating = nil
            end
            R.Skin()
        end)    else
        CollapseApply()
    end
end

-- Collapse internals for /status: collapsed wish, fold 0..1, the header's
-- own height band and the last full body height reported. A fold that
-- never moves with a body of 0 means the renderers never complete a pass
-- (their SetBodyHeight is the last call); a header of 0 means the click
-- catcher has no band to catch with.
function R.CollapseState()
    return R.collapsed, R.collapseFold, CollapseHeaderH(), collapseBodyH
end

local function Take(kind, make)
    used[kind] = (used[kind] or 0) + 1
    local pool = pools[kind]
    local item = pool[used[kind]]
    if not item then
        item = make()
        pool[used[kind]] = item
    end
    return item
end

local function Text(font, size, r, g, b, a)
    local fs = Take("text", function()
        local t = W.content:CreateFontString(nil, "OVERLAY")
        t:SetJustifyH("LEFT")
        t:SetJustifyV("TOP")
        t:SetWordWrap(true)
        t:SetShadowOffset(1, -1)
        t:SetShadowColor(0, 0, 0, 0.8)
        return t
    end)
    ns.ApplyFont(fs, font, size, "OUTLINE")   -- slug outline (ApplyFont adds SLUG)
    fs:SetTextColor(r, g, b, a or 1)
    fs:ClearAllPoints()
    fs:SetSpacing(0)                  -- pooled: Frameless changes these
    fs:SetWordWrap(true)
    fs:SetShadowOffset(1, -1)
    fs:SetShadowColor(0, 0, 0, 0.8)
    fs:SetAlpha(1)
    fs:Show()
    return fs
end

-- Timeline: the padding inside its panel.
local TL_PAD = 9

-- A step number on the line (col: { r, g, b, a }).
local function Num(index, font, size, col)
    local fs = Take("num", function()
        local t = W.content:CreateFontString(nil, "OVERLAY")
        t:SetJustifyH("CENTER")
        t:SetWidth(30)
        t:SetShadowOffset(1, -1)
        t:SetShadowColor(0, 0, 0, 0.8)
        return t
    end)
    ns.ApplyFont(fs, font, size, "OUTLINE")
    fs:SetTextColor(col[1], col[2], col[3], col[4] or 1)
    fs:SetText(index)
    fs:ClearAllPoints()
    fs:SetAlpha(1)
    fs:Show()
    return fs
end

-- One piece of the line at x, between two numbers.
local function Segment(x, top, bottom, col)
    local t = Take("seg", function()
        local l = W.content:CreateTexture(nil, "ARTWORK", nil, 1)
        l:SetTexture(WHITE)
        l:SetWidth(1)
        return l
    end)
    t:SetVertexColor(col[1], col[2], col[3], 0.5 * (col[4] or 1))
    t:ClearAllPoints()
    t:SetPoint("TOP", W, "TOPLEFT", x, top)
    t:SetPoint("BOTTOM", W, "TOPLEFT", x, bottom)
    t:Show()
end

-- Click areas: a current step's card (skip it, right-click: back a step) and
-- upcoming lines (menu).
-- exact: the highlight covers just the area (a card); otherwise it reaches
-- 4 px past each side (a line of text).
local function Hit(exact)
    local h = Take("hit", function()
        local b = CreateFrame("Button", nil, W.content)
        b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        b:SetScript("OnClick", function(self, button)
            if self.onClick then self.onClick(button) end
        end)
        b:SetScript("OnDoubleClick", function(self, button)
            if self.onDouble then self.onDouble(button) end
        end)
        b:SetScript("OnEnter", function(self) if self.onEnter then self.onEnter() end end)
        b:SetScript("OnLeave", function(self) if self.onLeave then self.onLeave() end end)
        b:SetScript("OnMouseDown", function(self, button) if self.onDown then self.onDown(button) end end)
        b:SetScript("OnMouseUp", function(self, button) if self.onUp then self.onUp(button) end end)
        -- Hover feedback: a faint white wash over the step (shows by itself
        -- while the mouse is on it).
        b.hl = b:CreateTexture(nil, "HIGHLIGHT")
        b.hl:SetColorTexture(1, 1, 1, 0.1)
        return b
    end)
    h.hl:ClearAllPoints()
    h.hl:SetColorTexture(1, 1, 1, 0.1)
    local ix, iy = exact and 0 or 4, exact and 0 or 1
    h.hl:SetPoint("TOPLEFT", h, "TOPLEFT", -ix, iy)
    h.hl:SetPoint("BOTTOMRIGHT", h, "BOTTOMRIGHT", ix, -iy)
    h:ClearAllPoints()
    h.onClick, h.onDouble, h.onEnter, h.onLeave, h.onDown, h.onUp = nil, nil, nil, nil, nil, nil
    h:Show()
    return h
end

-- Skip a current step (a click on its card): RestedXP goes to the step
-- after it, as its own "go to step" does; a sticky step is marked skipped
-- the way RestedXP marks one done. Every step it passes is remembered as
-- skipped for a moment (its card leaves with the skip animation).
local function SkipStep(stepframe)
    local A, step = _G.RXP, stepframe and stepframe.step
    local index = stepframe and (stepframe.index or (step and step.index))
    if not (A and A.SetStep and index) then return end
    R.skipped = R.skipped or {}
    local from = A.GetGuideProgress and A.GetGuideProgress() or index
    for i = math.min(from, index), index do R.skipped[i] = GetTime() end
    if step and step.sticky and _G.RXPCData and RXPCData.stepSkip then
        RXPCData.stepSkip[index] = true
        A.SetStep(from)
    else
        A.SetStep(index + 1)
    end
end

-- Back one step (a right-click on a current card): the step before the
-- guide's current one, passing over sticky steps (RestedXP moves straight
-- on from those). Its card comes back with the back animation.
local function BackStep(stepframe)
    local A = _G.RXP
    local guide = A and A.currentGuide
    local index = stepframe and (stepframe.index or (stepframe.step and stepframe.step.index))
    if not (A and A.SetStep and guide and guide.steps and index) then return end
    local n = (A.GetGuideProgress and A.GetGuideProgress() or index) - 1
    while n >= 1 and guide.steps[n] and guide.steps[n].sticky do n = n - 1 end
    if n < 1 then return end
    R.backTo = R.backTo or {}
    R.backTo[n] = GetTime()
    A.SetStep(n)
end

-- RestedXP's quest marker for a step line. The guide DATA is the source of
-- truth: each element carries the "|T...|t" string and its tag says which
-- marker it is ("accept" is the "!", "complete" the "?"), and for those two
-- the step frame does not always draw its own copy -- which is why reading
-- only the frame left them blank here. RXP's own paths, used when the
-- element carries no icon of its own.
local QUEST_ICON = {
    accept = "|TInterface/GossipFrame/AvailableQuestIcon:0|t",
    acceptmultiple = "|TInterface/GossipFrame/AvailableQuestIcon:0|t",
    complete = "|TInterface/GossipFrame/ActiveQuestIcon:0|t",
    turnin = "|TInterface/GossipFrame/ActiveQuestIcon:0|t",
    turninmultiple = "|TInterface/GossipFrame/ActiveQuestIcon:0|t",
}

-- The icon of one line: the data element's, the frame's own FontString, or
-- the marker its tag names. `de` is only trusted when it is the element this
-- line actually came from (same text), so a frame that packs its elements
-- differently can never borrow another line's icon.
local function LineIcon(de, frameEl, text)
    local icon
    if de and de.text and type(de.text) == "string" and Plain(de.text) == Plain(text or "") then
        icon = de.icon
    end
    if (type(icon) ~= "string" or icon == "" or IsSecret(icon)) then
        local f = frameEl and frameEl.icon
        if f and f.IsShown and f:IsShown() then icon = f:GetText() end
        if type(icon) ~= "string" or icon == "" or IsSecret(icon) then icon = nil end
    end
    return icon or QUEST_ICON[type(de and de.tag) == "string" and de.tag or ""]
end

-- The guide's data for step `index` (its elements carry the icons).
local function StepData(index)
    local A = _G.RXP
    local guide = A and A.currentGuide
    local step = guide and guide.steps and guide.steps[index]
    return (step and step.elements) or nil
end

-- The inline icon at the front of RestedXP's own text ("|T...|t"), if any:
-- what Compact shows at the left of each of its lines.
local function LeadIcon(text)
    if type(text) ~= "string" or IsSecret(text) then return nil end
    return text:match("^%s*(|T.-|t)")
end

-- First line of a step list row: no leading spaces or icon.
local function RowLine(text)
    if type(text) ~= "string" or IsSecret(text) or text == "" then return nil end
    local line = text:match("^[^\n]*") or ""
    line = line:gsub("^%s+", ""):gsub("^|T.-|t", ""):gsub("^%s+", "")
    if line == "" then return nil end
    return line
end

local function BuildWindow()
    W = CreateFrame("Frame", "FUIRestedXPTimeline", UIParent, "BackdropTemplate")
    W:SetBackdrop(FLAT)
    W.content = CreateFrame("Frame", nil, W)
    W.content:SetAllPoints()
    -- Timeline's pieces:
    -- Current step band: faint blue fill + a 2px blue edge on the left.
    W.band = W.content:CreateTexture(nil, "BACKGROUND")
    W.band:SetTexture(WHITE)
    W.bandEdge = W.content:CreateTexture(nil, "BACKGROUND", nil, 1)
    W.bandEdge:SetTexture(WHITE)
    W.bandEdge:SetWidth(2)
    W.name = W.content:CreateFontString(nil, "OVERLAY")
    W.name:SetJustifyH("LEFT")
    W.name:SetWordWrap(false)
    W.progress = W.content:CreateFontString(nil, "OVERLAY")
    W.progress:SetJustifyH("LEFT")
    -- The guide's % done, big on the header's right.
    W.percent = W.content:CreateFontString(nil, "OVERLAY")
    W.percent:SetJustifyH("RIGHT")
    -- Level range pill ("6-10") next to the zone name.
    W.pill = W.content:CreateTexture(nil, "ARTWORK")
    W.pill:SetTexture(WHITE)
    W.pillText = W.content:CreateFontString(nil, "OVERLAY")
    W.pillText:SetPoint("CENTER", W.pill, "CENTER", 0, 0)
    -- Header background: navy at the top fading out into the window.
    W.headBg = W.content:CreateTexture(nil, "BACKGROUND", nil, -1)
    W.headBg:SetTexture(WHITE)
    -- Header: RestedXP's own handlers (move, Alt+drag resize, right-click menu).
    W.header = CreateFrame("Frame", nil, W)
    W.header:EnableMouse(true)
    W.header:HookScript("OnMouseDown", function(_, button)
        if button ~= "LeftButton" then return end
        collapseClickAt = GetTime()
        collapseDownX, collapseDownY = W:GetLeft(), W:GetTop()
    end)
    W.header:HookScript("OnMouseUp", function(_, button)
        if button ~= "LeftButton" or not collapseClickAt then return end
        local dt = GetTime() - collapseClickAt
        local moved = false
        if collapseDownX then
            local nx, ny = W:GetLeft(), W:GetTop()
            moved = math.abs((nx or 0) - collapseDownX) > 0.5 or math.abs((ny or 0) - collapseDownY) > 0.5
        end
        if dt < 0.28 and not moved and W.header:IsMouseOver() then
            R.ToggleCollapse()
        end
        collapseClickAt, collapseDownX, collapseDownY = nil, nil, nil
    end)
    W.header:SetScript("OnMouseDown", function(_, button)
        local rxp = _G.RXPFrame
        if button == "RightButton" then
            if rxp.DropDownMenu then rxp.DropDownMenu() end
        elseif rxp.OnMouseDown then
            R.dragging = true   -- no redraws until it's let go
            rxp.OnMouseDown(rxp, button)
        end
    end)
    W.header:SetScript("OnMouseUp", function(_, button)
        local rxp = _G.RXPFrame
        R.dragging = false
        if button ~= "RightButton" and rxp.OnMouseUp then rxp.OnMouseUp(rxp, button) end
        R.Queue()   -- the window moved: bring the Active Targets / Items along
    end)
    -- Mouse wheel: scroll the step list (clicks still pass through the panel).
    W:EnableMouseWheel(true)
    W:SetScript("OnMouseWheel", function(_, delta)
        R.offset = (R.offset or 0) - delta
        R.Skin()
    end)
    -- Follow RestedXP's window: shown, hidden, resized.
    local rxp = _G.RXPFrame
    rxp:HookScript("OnShow", function() if Enabled() then R.Queue() end end)
    rxp:HookScript("OnHide", function() if W then W:Hide() end end)
    rxp:HookScript("OnSizeChanged", function() if Enabled() then R.Queue() end end)
end

-- =====================================================================
-- Frameless: outlined text straight on the world (design handoff 2c)
-- =====================================================================
-- The APPEARANCE settings (RXP tab): each layout has its own copy, the
-- same list under its own prefix (Frameless "rxpFl", Timeline "rxpTl").
-- Missing values: the layout's own look (Frameless: the handoff's yellows;
-- Timeline: the 1.4 Timeline's blue).
local LOOK = {
    rxpFl = { width = 310, numCol = 30, zone = 24, head = 15, cur = 19, text = 15, num = 12, obj = 14,
        accent = { 0.94, 0.83, 0.42 }, current = { 1, 1, 1 }, stepCol = { 0.91, 0.64, 0.24 },
        pctCol = { 0.31, 0.76, 0.97 }, cardA = 35, arrowCol = { 0.95, 0.85, 0.47 }, done = { 0.37, 0.88, 0.48 },
        textCol = { 0.94, 0.94, 0.94 }, numCol_ = { 0.73, 0.73, 0.73 }, muted = { 0.87, 0.87, 0.87 },
        fadeStep = 9, fadeMin = 35, backdropA = 25, arrow = 34, dist = 18, arrowText = 14,
        zoneCol = { 1, 1, 1 }, line = { 1, 1, 1, 0.55 }, headBg = { 0, 0, 0, 0 }, border = { 1, 1, 1, 0.07 },
        track = { 1, 1, 1, 0.12 } },
    rxpTl = { width = 235, numCol = 20, zone = 14, head = 10, cur = 12, text = 12, num = 11, obj = 11,
        accent = { 0.35, 0.65, 1 }, current = { 0.35, 0.65, 1 }, stepCol = { 0.35, 0.65, 1 },
        pctCol = { 1, 1, 1 }, cardA = 12, arrowCol = { 0.35, 0.65, 1 }, done = { 0.37, 0.88, 0.48 },
        textCol = { 0.62, 0.62, 0.62 }, numCol_ = { 0.62, 0.62, 0.62 }, muted = { 0.78, 0.78, 0.78 },
        fadeStep = 16, fadeMin = 15, backdropA = 60, arrow = 40, dist = 14, arrowText = 13,
        zoneCol = { 1, 1, 1 }, line = { 1, 1, 1, 0.55 }, headBg = { 0.05, 0.13, 0.28, 1 }, border = { 0, 0, 0, 1 },
        track = { 1, 1, 1, 0.22 } },
    rxpCp = { width = 250, numCol = 20, zone = 13, head = 11, cur = 12, text = 12, num = 11, obj = 11,
        accent = { 0.91, 0.76, 0.35 }, current = { 1, 1, 1 }, stepCol = { 0.24, 0.86, 0.42 },
        pctCol = { 0.81, 0.84, 0.86 }, cardA = 18, arrowCol = { 0.24, 0.86, 0.42 }, done = { 0.24, 0.86, 0.42 },
        textCol = { 0.84, 0.87, 0.89 }, numCol_ = { 0.6, 0.64, 0.68 }, muted = { 0.73, 0.76, 0.8 },
        fadeStep = 12, fadeMin = 45, backdropA = 90, arrow = 34, dist = 14, arrowText = 13,
        zoneCol = { 1, 1, 1 }, line = { 1, 1, 1, 0.55 }, headBg = { 0.13, 0.15, 0.17, 1 },
        border = { 0.17, 0.19, 0.21, 1 }, track = { 0.17, 0.19, 0.21, 1 } },
    rxpZg = { width = 280, numCol = 20, zone = 15, head = 12, cur = 14, text = 13, num = 15, obj = 12,
        accent = { 0.3, 0.85, 0.3 }, current = { 1, 1, 1 }, stepCol = { 0.47, 0.1, 0.1 },
        pctCol = { 0.85, 0.85, 0.85 }, cardA = 90, arrowCol = { 0.3, 0.85, 0.3 }, done = { 0.3, 0.85, 0.3 },
        textCol = { 0.9, 0.9, 0.9 }, numCol_ = { 0.6, 0.6, 0.6 }, muted = { 0.72, 0.72, 0.72 },
        fadeStep = 12, fadeMin = 45, backdropA = 92, arrow = 44, dist = 14, arrowText = 15,
        zoneCol = { 1, 1, 1 }, line = { 0.3, 0.3, 0.31, 1 }, headBg = { 0.07, 0.07, 0.08, 1 },
        border = { 0.22, 0.22, 0.23, 1 }, track = { 0.25, 0.25, 0.26, 1 } },
    -- 8-Bit (design handoff "8-Bit Quest Log"): track is the current card /
    -- hover purple, stepCol the red first blocks, done the green chip and pips.
    rxpBt = { width = 336, numCol = 30, zone = 15, head = 10, cur = 22, text = 19, num = 18, obj = 17,
        accent = { 1, 0.824, 0.247 }, current = { 0.91, 0.902, 0.961 }, stepCol = { 1, 0.365, 0.451 },
        pctCol = { 1, 0.824, 0.247 }, cardA = 100, arrowCol = { 1, 0.824, 0.247 }, done = { 0.49, 1, 0.416 },
        textCol = { 0.91, 0.902, 0.961 }, numCol_ = { 0.643, 0.624, 0.78 }, muted = { 0.643, 0.624, 0.78 },
        fadeStep = 12, fadeMin = 32, backdropA = 100, arrow = 34, dist = 18, arrowText = 19,
        zoneCol = { 0.949, 0.941, 1 }, line = { 0.949, 0.941, 1, 1 }, headBg = { 0.137, 0.118, 0.239, 1 },
        border = { 0.949, 0.941, 1, 1 }, track = { 0.11, 0.094, 0.188, 1 },
        bg = { 0.051, 0.043, 0.102 }, item = { 0.247, 0.816, 1 }, npc = { 0.49, 1, 0.416 }, verb = { 1, 0.824, 0.247 } },
    -- RAIL: the rail line and its markers (steel blue), no panel at all.
    rxpRl = { width = 300, numCol = 26, zone = 15, head = 11, cur = 14, text = 12, num = 11, obj = 11,
        accent = { 0.35, 0.75, 0.95 }, current = { 1, 1, 1 }, stepCol = { 0.35, 0.75, 0.95 },
        pctCol = { 0.75, 0.78, 0.82 }, cardA = 0, arrowCol = { 0.35, 0.75, 0.95 }, done = { 0.3, 0.85, 0.4 },
        textCol = { 0.82, 0.85, 0.88 }, numCol_ = { 0.5, 0.55, 0.6 }, muted = { 0.62, 0.66, 0.7 },
        fadeStep = 14, fadeMin = 25, backdropA = 0, arrow = 36, dist = 15, arrowText = 13,
        zoneCol = { 1, 1, 1 }, line = { 1, 1, 1, 0.35 }, headBg = { 0, 0, 0, 0 }, border = { 1, 1, 1, 0.1 },
        track = { 1, 1, 1, 0.25 } },
}
-- 8-Bit's pixel fonts: its font settings are locked to these.
local SILK = "Interface\\AddOns\\" .. ADDON .. "\\Fonts\\Silkscreen-Regular.ttf"
local SILK_BOLD = "Interface\\AddOns\\" .. ADDON .. "\\Fonts\\Silkscreen-Bold.ttf"
local VT323 = "Interface\\AddOns\\" .. ADDON .. "\\Fonts\\VT323-Regular.ttf"
local function Cfg(p)
    local db, d = DB(), LOOK[p]
    local function col(k, def) return { db[p .. k .. "R"] or def[1], db[p .. k .. "G"] or def[2], db[p .. k .. "B"] or def[3] } end
    local function col4(k, def)
        local t = col(k, def)
        -- Looks whose palette predates alpha have no 4th default: opaque.
        t[4] = db[p .. k .. "A"] or def[4] or 1
        return t
    end
    local t = {
        width = db[p .. "Width"] or d.width, numCol = db[p .. "NumCol"] or d.numCol,
        body = ns.ResolveFont(db[p .. "Font"]),   -- fonts: EllesmereUI's Global Font when unset
        semi = ns.ResolveFont(db[p .. "FontSemi"]),
        bold = ns.ResolveFont(db[p .. "FontBold"]),
        zone = db[p .. "ZoneSize"] or d.zone, head = db[p .. "HeadSize"] or d.head,
        cur = db[p .. "CurSize"] or d.cur, text = db[p .. "TextSize"] or d.text,
        num = db[p .. "NumSize"] or d.num, obj = db[p .. "ObjSize"] or d.obj,
        accent = col4("Accent", d.accent),     -- level range, progress (Timeline: its line too)
        current = col4("Cur", d.current),      -- the current step's instruction
        stepCol = col4("StepCol", d.stepCol),  -- "STEP 7" / the current step's number, warning "!"
        pctCol = col4("PctCol", d.pctCol),     -- header %, info "i"
        cardA = (db[p .. "CardA"] or d.cardA) / 100,   -- current step card (Timeline: band)
        arrowCol = col4("Arrow", d.arrowCol),  -- the arrow (Timeline: its card's text)
        done = col4("DoneCol", d.done),        -- finished objective bars, the tick
        textCol = col4("Text", d.textCol),     -- upcoming steps
        numCol_ = col4("Num", d.numCol_),      -- upcoming numbers
        muted = col4("Muted", d.muted),        -- counter, objectives, arrow text
        fadeStep = (db[p .. "FadeStep"] or d.fadeStep) / 100, fadeMin = (db[p .. "FadeMin"] or d.fadeMin) / 100,
        backdrop = db[p .. "Backdrop"] and (db[p .. "BackdropA"] or d.backdropA) / 100 or 0,
        objectives = db[p .. "Objectives"] ~= false,
        arrow = db[p .. "ArrowSize"] or d.arrow, dist = db[p .. "DistSize"] or d.dist,
        arrowText = db[p .. "ArrowTextSize"] or d.arrowText,
        zoneCol = col4("Zone", d.zoneCol),     -- the zone's name
        line = col4("Line", d.line),            -- Frameless: the line under the header
        headBg = col4("HeadBg", d.headBg),      -- Timeline: the header's background
        border = col4("Border", d.border),      -- Frameless: card border; Timeline: panel border
        track = col4("Track", d.track),         -- an objective bar's empty track
        stepLabel = db[p .. "StepLabel"] ~= false,   -- "STEP 7" / the current step's number
        listNums = db[p .. "ListNums"] ~= false,     -- the upcoming steps' numbers
        -- 8-Bit's own:
        bg = d.bg and col4("Bg", d.bg),        -- the window
        item = d.item and col4("Item", d.item),  -- item names (alpha via KeyAlpha escapes)
        npc = d.npc and col4("Npc", d.npc),      -- NPC names (alpha via KeyAlpha escapes)
        verb = d.verb and col4("Verb", d.verb), -- "Kill", "Loot", "Talk to"...
        showDone = db[p .. "ShowDone"] ~= false,     -- the step before the current one
        scan = db[p .. "Scan"] ~= false,             -- the CRT scanlines
    }
    if p == "rxpBt" then t.body, t.semi, t.bold = VT323, SILK, SILK_BOLD end   -- pixel fonts only
    return t
end
local function FLCfg() return Cfg("rxpFl") end
local function TLCfg() return Cfg("rxpTl") end
local function LayoutCfg() return Cfg(LAYOUTS[Layout()]) end

-- The height of one line of `fs` (its first line, for multi-line text).
local function LineHeight(fs, size)
    local h = fs.GetLineHeight and fs:GetLineHeight()
    return (type(h) == "number" and h > 0) and h or size
end

-- A pooled plain texture (the current step cards' panels).
local function Tex()
    local t = Take("tex", function() return W.content:CreateTexture(nil, "OVERLAY") end)
    t:ClearAllPoints()
    -- The white default, always: a Texture with no texture assigned draws
    -- nothing. The Rail's rail line and its markers went through here without
    -- ever setting one, so they only showed while a pooled texture still
    -- carried the white texture of another renderer -- visible or not
    -- depending on which layout had been drawn before.
    t:SetTexture(WHITE)
    t:SetVertexColor(1, 1, 1, 1)
    t:SetTexCoord(0, 1, 0, 1)
    t:SetAlpha(1)
    t:SetDrawLayer("OVERLAY", 0)
    t:Show()
    return t
end

-- RestedXP colours enemy names |cFFFF5722 (orange-red): swap in the
-- "Enemy Names" colour.
-- RestedXP's inline icons (|Tpath:0|t): 90% of the text size, nudged down
-- so they sit centred on the line instead of riding high.
local function SmallIcons(text, size)
    if type(text) ~= "string" or IsSecret(text) then return text end
    local px = math.max(8, math.floor(size * 0.9 + 0.5))
    local down = -math.floor(size * 0.12 + 0.5)
    return (text:gsub("|T([^|]-)|t", function(spec)
        local parts = {}
        for part in (spec .. ":"):gmatch("([^:]*):") do parts[#parts + 1] = part end
        parts[2], parts[3] = px, px            -- height, width
        parts[4] = parts[4] or 0               -- x offset
        parts[5] = down                        -- y offset
        return "|T" .. table.concat(parts, ":") .. "|t"
    end))
end

-- RestedXP's live settings profile: the one its own AceDB database has
-- loaded (found through AceDB's registry). Its profile name can't be rebuilt
-- by hand: AceDB reads the realm name at load, when it can differ from
-- GetRealmName() later ("Jo - PvE" vs "Jo - Classic Beta PvE 2").
local function RXPProfile()
    local sv = _G.RXPSettings
    if type(sv) ~= "table" then return nil end
    local AceDB = LibStub and LibStub("AceDB-3.0", true)
    if AceDB and AceDB.db_registry then
        for db in pairs(AceDB.db_registry) do
            if type(db) == "table" and db.sv == sv and type(db.profile) == "table" then
                return db.profile
            end
        end
    end
    -- RestedXP not initialised yet: its saved table, by the same name AceDB uses.
    local charKey = (UnitName("player") or "") .. " - " .. (GetRealmName() or "")
    local name = (sv.profileKeys and sv.profileKeys[charKey]) or charKey
    sv.profiles = sv.profiles or {}
    sv.profiles[name] = sv.profiles[name] or {}
    return sv.profiles[name]
end

-- The layout's colour setting `key` as RRGGBB (def: { r, g, b } when unset).
local function SettingHex(key, def)
    local c, p = DB(), LAYOUTS[Layout()]
    return ("%02x%02x%02x"):format(
        math.floor((c[p .. key .. "R"] or def[1]) * 255 + 0.5),
        math.floor((c[p .. key .. "G"] or def[2]) * 255 + 0.5),
        math.floor((c[p .. key .. "B"] or def[3]) * 255 + 0.5))
end

-- The "Enemy Names" colour as RRGGBB.
local function EnemyHex() return SettingHex("Enemy", { 1, 0.341, 0.133 }) end

-- The "Friendly Names" colour (friendly NPC and unit names, RestedXP's
-- green #00FF25) as RRGGBB. 8-Bit keeps its own NPC colour for these.
local function FriendlyHex()
    if Layout() == "BIT8" then return SettingHex("Npc", { 0.49, 1, 0.416 }) end
    return SettingHex("Friendly", { 0, 1, 0.145 })
end

-- The "Notes & Warnings" colour (RestedXP's yellow #FCDC00) as RRGGBB.
local function WarnHex() return SettingHex("Warn", { 0.988, 0.863, 0 }) end

-- A colour code pattern for RRGGBB, any letter case.
local function HexPattern(hex)
    return "|c%x%x" .. hex:gsub("%a", function(ch) return "[" .. ch:upper() .. ch:lower() .. "]" end)
end

-- Enemy and item names: RestedXP colours enemies, items to loot and items
-- to pick up with its own colours (#FF5722, #00BCD4, #DB2EEF by default),
-- friendlies green (#00FF25) and warnings yellow (#FCDC00). Each layout's
-- own colours are written into all five settings (so RestedXP's own text
-- uses them after a /reload), and swapped in live meanwhile. Entries
-- without their own `hex` share the "Enemy & Item Names" colour.
local NAME_COLORS = {
    { key = "textEnemyColor", default = "ff5722" },
    { key = "textLootColor", default = "00bcd4" },
    { key = "textPickColor", default = "db2eef" },
    { key = "textFriendlyColor", default = "00ff25", hex = FriendlyHex },
    { key = "textWarnColor", default = "fcdc00", hex = WarnHex },
}
local rxpHex = {}   -- what RestedXP's text uses this session, per setting

-- What a name colour setting becomes: the enemy colour (8-Bit: items have
-- their own), the friendly colour for friendly names, the warn colour for
-- notes and warnings.
local function KeyHex(key)
    if key == "textFriendlyColor" then return FriendlyHex() end
    if key == "textWarnColor" then return WarnHex() end
    if Layout() == "BIT8" and key ~= "textEnemyColor" then return SettingHex("Item", { 0.247, 0.816, 1 }) end
    return EnemyHex()
end

-- The stored alpha of a name colour as a 2-digit hex byte, for the live
-- 8-digit escapes below. Display only: RestedXP's profile stays 6-digit
-- with its own "ff", and an unset alpha reads "ff" -- identical output.
local function KeyAlpha(key)
    local c, p = DB(), LAYOUTS[Layout()]
    local prefix = p .. "Enemy"
    if key == "textFriendlyColor" then
        prefix = (Layout() == "BIT8") and (p .. "Npc") or (p .. "Friendly")
    elseif key == "textWarnColor" then
        prefix = p .. "Warn"
    elseif Layout() == "BIT8" and key ~= "textEnemyColor" then
        prefix = p .. "Item"
    end
    return ("%02x"):format(math.floor((c[prefix .. "A"] or 1) * 255 + 0.5))
end

function R.SyncEnemyColor()
    local profile = RXPProfile()
    if not profile then return end
    for _, nc in ipairs(NAME_COLORS) do
        if not rxpHex[nc.key] then
            local current = type(profile[nc.key]) == "string" and profile[nc.key]:sub(-6)
            rxpHex[nc.key] = (current or nc.default):lower()
        end
        profile[nc.key] = "ff" .. (nc.hex and nc.hex() or KeyHex(nc.key))
    end
end

local function EnemyColor(text)
    if type(text) ~= "string" or IsSecret(text) then return text end
    -- Both RestedXP's default colour and whatever its setting held when it
    -- loaded: its guide text can carry either.
    for _, nc in ipairs(NAME_COLORS) do
        local to = "|c" .. KeyAlpha(nc.key) .. KeyHex(nc.key)
        text = text:gsub(HexPattern(nc.default), to)
        if rxpHex[nc.key] and rxpHex[nc.key] ~= nc.default then
            text = text:gsub(HexPattern(rxpHex[nc.key]), to)
        end
    end
    -- Friendly names and warnings ride the main loop above (KeyHex points
    -- them at their own colours, 8-Bit names at its NPC colour).
    return text
end

-- The name-colour swap alone (no icon resizing), for text leaving this
-- window: WaypointUI's waypoint label. RestedXP parses its guide text
-- once, so without this the pushed label keeps yesterday's colours until
-- a /reload; swapped here it follows the options live, like our window.
function R.RecolorNames(text) return EnemyColor(text) end

-- Every text: black outline plus a soft shadow straight down.
local function FLText(font, size, r, g, b, a)
    local fs = Text(font, size, r, g, b, a)
    fs:SetShadowOffset(0, -1)
    fs:SetShadowColor(0, 0, 0, 1)
    fs:SetSpacing(0)
    return fs
end

local function FLPieces()
    if W.fl then return W.fl end
    local fl = {}
    local function FS(justify)
        local t = W.content:CreateFontString(nil, "OVERLAY")
        t:SetJustifyH(justify)
        t:SetWordWrap(false)
        t:SetShadowOffset(0, -1)
        t:SetShadowColor(0, 0, 0, 1)
        return t
    end
    local function Tex(layer, sub)
        local t = W.content:CreateTexture(nil, layer, nil, sub)
        t:SetTexture(WHITE)
        return t
    end
    fl.zone, fl.level, fl.count = FS("LEFT"), FS("LEFT"), FS("RIGHT")
    fl.trackShadow = Tex("ARTWORK", 0)
    fl.track = Tex("ARTWORK", 1)
    fl.fill = Tex("ARTWORK", 2)
    W.fl = fl
    return fl
end

-- Current rows, briefly flashed (alpha 0.6 -> 1) when the step moves on.
local flash = {}
local function StartFlash()
    local t0 = GetTime()
    W:SetScript("OnUpdate", function(self)
        local k = (GetTime() - t0) / 0.2
        for _, fs in ipairs(flash) do fs:SetAlpha(0.6 + 0.4 * math.min(1, k)) end
        if k >= 1 then self:SetScript("OnUpdate", nil) end
    end)
end

-- =====================================================================
-- Both layouts: step cards leaving and coming back
-- =====================================================================
-- A step that just left stays a moment: done, a green tick pops in at its
-- right and it greys out, then it folds away (what's under it slides up);
-- skipped (a click on it), a green wash wipes across with "Skipped", it
-- slides off to the left, then folds. A step brought back (a right-click)
-- fades in as its space opens, with an amber wash and "Back" that fade out.
-- Ease re-declared here would shadow the collapse block's forward one;
-- keep the card transitions reading the SAME curve.
local function Overshoot(p) local q = p - 1; return 1 + 2.70158 * q * q * q + 1.70158 * q * q end
local function Span(a, from, len) return math.min(1, math.max(0, (a - from) / len)) end

-- Where a card's animation is: content alpha, fold (0-1), slide (px), the
-- skip wash (0-1), the tick (0-1), "Skipped" (0-1), the back wash (0-1).
local function AnimState(e, slideW)
    local st = { alpha = 1, fold = 0, dx = 0, wash = 0, tick = 0, tag = 0, back = 0 }
    local a = e.anim
    if e.enter then
        st.fold = 1 - Ease(Span(e.enter, 0, 0.25))
        st.alpha = Span(e.enter, 0, 0.3)
        st.back = st.alpha * (1 - Span(e.enter, 0.65, 0.35))
    elseif a and e.skipped then
        st.wash = Ease(Span(a, 0, 0.3))
        st.tag = Span(a, 0.2, 0.2)
        local slide = Ease(Span(a, 0.56, 0.3))
        st.dx = -math.floor(slide * (slideW + 20) + 0.5)
        st.alpha = 1 - slide
        st.fold = Ease(Span(a, 0.86, 0.2))
    elseif a then
        st.tick = Overshoot(Span(a, 0, 0.22))
        st.fold = Ease(Span(a, 0.42, 0.26))
        st.alpha = (1 - 0.55 * Span(a, 0, 0.2)) * (1 - math.min(1, st.fold * 2))
    end
    return st
end

-- This pass's current steps against the last pass's (models: this pass's
-- step models by index): steps that left (up to two at once: more is a
-- jump in the guide, not a step done) and steps brought back, drawn a
-- while longer. Returns everything to draw, in step order.
local function Transitions(current, models, minIndex, layout)
    local now = GetTime()
    local guide = _G.RXP and _G.RXP.currentGuide
    R.leaving, R.entering = R.leaving or {}, R.entering or {}
    local seen = {}
    for _, step in ipairs(current) do seen[step.index] = true end
    if R.cardsGuide == guide and R.cardsLayout == layout and R.cardModels then
        if minIndex then
            local gone = {}
            for index in pairs(R.cardModels) do
                if not seen[index] and index < minIndex and not R.leaving[index] then gone[#gone + 1] = index end
            end
            if #gone <= 2 then
                for _, index in ipairs(gone) do
                    local at = R.skipped and R.skipped[index]
                    R.leaving[index] = { model = R.cardModels[index], t0 = now, skipped = at and now - at < 3 }
                end
            end
        end
        for index in pairs(seen) do
            local at = R.backTo and R.backTo[index]
            if not R.cardModels[index] and at and now - at < 3 and not R.entering[index] then R.entering[index] = now end
        end
    else
        wipe(R.leaving)
        wipe(R.entering)
    end
    R.cardsGuide, R.cardsLayout, R.cardModels = guide, layout, models
    local cards = {}
    for index, e in pairs(R.leaving) do
        local a = now - e.t0
        if a >= (e.skipped and SKIP_TIME or DONE_TIME) then
            R.leaving[index] = nil
        else
            cards[#cards + 1] = { model = e.model, anim = a, skipped = e.skipped }
        end
    end
    for _, step in ipairs(current) do
        local t0 = R.entering[step.index]
        if t0 and now - t0 >= BACK_TIME then R.entering[step.index], t0 = nil, nil end
        cards[#cards + 1] = { model = models[step.index], frame = step, enter = t0 and now - t0 }
    end
    table.sort(cards, function(a, b) return a.model.index < b.model.index end)
    return cards
end

-- While a card leaves or comes back, the window redraws every frame.
local function Animate()
    if not (next(R.leaving) or next(R.entering)) then return end
    R.anim = R.anim or CreateFrame("Frame")
    R.anim:SetScript("OnUpdate", function(self)
        if next(R.leaving) or next(R.entering) then R.Skin() else self:SetScript("OnUpdate", nil) end
    end)
end

-- The animation's pieces over a card (x0..x0 + w across, top down h, its
-- middle at mid, pad in from the right edge), in the layout's settings c.
local function Overlay(c, st, x0, top, w, h, mid, pad)
    local function Wash(col, alpha, width)
        local t = Tex()
        t:SetTexture(WHITE); t:SetDrawLayer("BACKGROUND", 2)
        t:SetPoint("TOPLEFT", W, "TOPLEFT", x0, top)
        t:SetSize(math.max(1, width), math.max(1, h))
        t:SetVertexColor(col[1], col[2], col[3], (alpha or 1) * (col[4] or 1))
    end
    local function Icon(tex, size, x, col, alpha)
        local t = Tex()
        t:SetTexture(tex)
        t:SetDrawLayer("OVERLAY", 2)
        t:SetSize(size, size)
        t:SetPoint("CENTER", W, "TOPLEFT", x, mid)
        t:SetVertexColor(col[1], col[2], col[3], (alpha or 1) * (col[4] or 1))
    end
    local function Tag(text, rightX, col, alpha)
        local s = FLText(c.bold, c.obj, col[1], col[2], col[3], col[4])
        s:SetWordWrap(false)
        s:SetWidth(0)
        s:SetText(text)
        s:SetPoint("RIGHT", W, "TOPLEFT", rightX, mid)
        s:SetAlpha(alpha)
    end
    local right = x0 + w - pad
    local size = math.floor(c.obj * 1.1 + 0.5)
    if st.back > 0 then
        -- Brought back: an amber wash, "Back" and its arrow, fading out.
        Wash(c.stepCol, 0.28 * st.back, w)
        Icon(BACK, size, right - size / 2, c.stepCol, st.back)
        Tag("Back", right - size - 4, c.stepCol, st.back)
    end
    if st.wash > 0 then
        -- Skipped: the green wash, then "Skipped" and a small tick.
        Wash(c.done, 0.3 * st.alpha, w * st.wash)
        if st.tag > 0 then
            Icon(CHECK, size, right - size / 2, c.done, st.tag * st.alpha)
            Tag("Skipped", right - size - 5, c.done, st.tag * st.alpha)
        end
    elseif st.tick > 0 then
        -- Done: the tick pops in at the right.
        Icon(CHECK, math.max(1, 22 * st.tick), right - 11, c.done, 1 - st.fold)
    end
end

function R.RenderFrameless()
    local rxp = _G.RXPFrame
    local c = FLCfg()
    local FL_W, FL_NUM = c.width, c.numCol
    if not W then BuildWindow() end
    if not rxp:IsShown() then W:Hide(); return end
    HideRXP(true)
    W:Show()
    W:SetScale(rxp:GetScale() or 1)
    W:SetFrameStrata(rxp:GetFrameStrata())
    W:SetFrameLevel(rxp:GetFrameLevel() + 20)
    W:ClearAllPoints()
    W:SetPoint("TOPLEFT", rxp, "TOPLEFT", 0, 0)
    W:SetWidth(FL_W)
    FitRXPWidth(FL_W)
    local db = DB()
    -- No panel; an optional 25% black backdrop for bright ground.
    W:SetBackdropColor(0, 0, 0, c.backdrop)
    W:SetBackdropBorderColor(0, 0, 0, 0)
    -- The Timeline's own pieces stay out of this layout.
    W.name:Hide(); W.progress:Hide(); W.percent:Hide(); W.pill:Hide(); W.pillText:Hide()
    W.headBg:Hide(); W.band:Hide(); W.bandEdge:Hide()

    used = {}
    local fl = FLPieces()
    local y = 0

    -- The guide: current steps, the step list and its last step.
    local current = {}
    for _, step in pairs(rxp.CurrentStepFrame and rxp.CurrentStepFrame.framePool or {}) do
        if step:IsShown() and step.step and step.index then current[#current + 1] = step end
    end
    table.sort(current, function(a, b) return a.index < b.index end)
    local minIndex, maxIndex = nil, 0
    for _, step in ipairs(current) do
        maxIndex = math.max(maxIndex, step.index)
        minIndex = minIndex and math.min(minIndex, step.index) or step.index
    end
    local rows, lastIndex = {}, 0
    for _, row in pairs(rxp.ScrollChild and rxp.ScrollChild.framePool or {}) do
        if row:IsShown() and row.index then
            if row.index > lastIndex then lastIndex = row.index end
            if row.index > maxIndex and row.text then
                local line = RowLine(row.text:GetText())
                if line then rows[#rows + 1] = { row = row, line = line } end
            end
        end
    end
    table.sort(rows, function(a, b) return a.row.index < b.row.index end)

    -- Header: "Tirisfal" (bold) with "10-12" in yellow after it, "7/20 · 35%"
    -- on the right (the % in blue), a thin line under it all.
    local nameText = rxp.GuideName and rxp.GuideName.text and rxp.GuideName.text:GetText()
    if type(nameText) ~= "string" or IsSecret(nameText) then nameText = "" end
    nameText = nameText:match("^[^\n]*") or ""
    local levels, zone = nameText:match("^(%d+%s*%-%s*%d+)%s+(.+)$")
    zone = zone or nameText
    local pct = (minIndex and lastIndex > 0) and math.min(1, minIndex / lastIndex) or 0
    ns.ApplyFont(fl.count, c.body, c.head, "OUTLINE")
    fl.count:SetTextColor(c.muted[1], c.muted[2], c.muted[3], c.muted[4])
    if minIndex and lastIndex > 0 then
        fl.count:SetText(("%d/%d \194\183 |c%02x%02x%02x%02x%d%%|r"):format(minIndex, lastIndex,
            math.floor((c.muted[4] or 1) * 255 + 0.5),
            math.floor(c.pctCol[1] * 255 + 0.5), math.floor(c.pctCol[2] * 255 + 0.5),
            math.floor(c.pctCol[3] * 255 + 0.5), math.floor(pct * 100 + 0.5)))
    else
        fl.count:SetText("")
    end
    ns.ApplyFont(fl.level, c.bold, c.head, "OUTLINE")
    fl.level:SetTextColor(c.accent[1], c.accent[2], c.accent[3], c.accent[4])
    fl.level:SetText(levels or "")
    ns.ApplyFont(fl.zone, c.bold, c.zone, "OUTLINE")
    fl.zone:SetTextColor(c.zoneCol[1], c.zoneCol[2], c.zoneCol[3], c.zoneCol[4])
    fl.zone:SetText(zone)
    local countW = (fl.count:GetStringWidth() or 0) + 8
    local levelW = levels and ((fl.level:GetStringWidth() or 0) + 5) or 0
    fl.zone:SetWidth(math.max(20, math.min((fl.zone:GetStringWidth() or 0) + 2, FL_W - COLLAPSE_L - countW - levelW)))
    local zoneH = fl.zone:GetStringHeight() or c.zone
    fl.zone:ClearAllPoints()
    fl.zone:SetPoint("TOPLEFT", W, "TOPLEFT", COLLAPSE_L, y)
    W.collapseAnchorFs = fl.zone   -- the switch centres on this title
    fl.level:ClearAllPoints()
    fl.level:SetPoint("BOTTOMLEFT", fl.zone, "BOTTOMRIGHT", 5, 2)   -- same baseline
    fl.count:ClearAllPoints()
    fl.count:SetPoint("BOTTOMRIGHT", W, "TOPRIGHT", 0, y - zoneH + 2)
    for _, piece in ipairs({ fl.zone, fl.level, fl.count }) do piece:Show() end
    y = y - zoneH - 6
    -- The line under the header.
    fl.track:ClearAllPoints()
    fl.track:SetPoint("TOPLEFT", W, "TOPLEFT", 0, y)
    fl.track:SetSize(FL_W, 1)
    fl.track:SetVertexColor(c.line[1], c.line[2], c.line[3], c.line[4])
    fl.trackShadow:ClearAllPoints()
    fl.trackShadow:SetPoint("TOPLEFT", W, "TOPLEFT", 0, y - 1)
    fl.trackShadow:SetSize(FL_W, 1)
    fl.trackShadow:SetVertexColor(0, 0, 0, 0.6)
    fl.track:Show(); fl.trackShadow:Show(); fl.fill:Hide()
    y = y - 1 - 10

    -- Header: RestedXP's handlers (drag, Alt+drag resize, right-click menu).
    W.header:ClearAllPoints()
    W.header:SetPoint("TOPLEFT", W, "TOPLEFT", 0, 0)
    W.header:SetPoint("TOPRIGHT", W, "TOPRIGHT", 0, 0)
    W.header:SetHeight(-y)

    -- Hovering the list shows every row at full alpha.
    local function Hover(on)
        return function()
            if R.hover ~= on then R.hover = on; R.RenderFrameless() end
        end
    end

    -- Without the list's numbers, its text starts at the left edge.
    if not c.listNums then FL_NUM = 0 end
    local textW = FL_W - FL_NUM


    -- Current steps, each on a card (a light dark panel):
    --   "STEP 7" (small, orange)
    --   the instruction (white, big), names in their colours
    --   objectives: label on the left, "8/12" on the right, a thin bar under
    --     it (yellow while going, green and greyed out when done)
    --   notes: other lines, "i" in blue for tips, "!" in orange for warnings
    -- A click on a card skips that step, a right-click goes back one; steps
    -- leaving and coming back animate (Transitions, above).
    wipe(flash)
    local PAD = 10
    local inner = FL_W - PAD * 2

    -- What a card shows, read from RestedXP's step frame now (it reuses the
    -- frame for the next step straight away, so a leaving card is drawn
    -- from this copy).
    local function Model(step)
        local m = { index = step.index, lines = {} }
        local instructed = false
        for _, el in ipairs(step.elements or {}) do
            local t = el.text and el.text:GetText()
            if el:IsShown() and el:GetAlpha() > 0 and type(t) == "string" and not IsSecret(t) and t ~= "" and t ~= " " then
                local cur, max = Count(t)
                if cur then
                    if c.objectives then
                        m.lines[#m.lines + 1] = { kind = "obj", cur = cur, max = max, icon = icon,
                            finished = cur >= max or (el.button and el.button:GetChecked() and true) or false,
                            name = ObjLabel(t) }
                    end
                elseif not instructed then
                    m.lines[#m.lines + 1] = { kind = "inst", text = t, icon = icon }
                    instructed = true
                else
                    m.lines[#m.lines + 1] = { kind = "note", text = t, icon = icon,
                        warn = t:find(HexPattern("fcdc00")) ~= nil }
                end
            end
        end
        return m
    end
    local models = {}
    for _, step in ipairs(current) do models[step.index] = Model(step) end

    for _, e in ipairs(Transitions(current, models, minIndex, "FRAMELESS")) do
        local m, a = e.model, e.anim
        local st = AnimState(e, FL_W)
        local dx, alpha = st.dx, st.alpha
        local top = y
        local function Show(fs)
            fs:SetAlpha(alpha)
            if not a then flash[#flash + 1] = fs end
        end
        y = y - PAD
        -- The panel behind it (drawn once its height is known).
        local edge, panel = Tex(), Tex()
        edge:SetTexture(WHITE); edge:SetDrawLayer("BACKGROUND", 0)
        panel:SetTexture(WHITE); panel:SetDrawLayer("BACKGROUND", 1)
        if c.stepLabel then
            local label = FLText(c.bold, c.num, c.stepCol[1], c.stepCol[2], c.stepCol[3], c.stepCol[4])
            label:SetWordWrap(false)
            label:SetWidth(inner)
            label:SetText("STEP " .. m.index)
            label:SetPoint("TOPLEFT", W, "TOPLEFT", PAD + dx, y)
            Show(label)
            y = y - LineHeight(label, c.num) - 6
        end
        for _, line in ipairs(m.lines) do
            if line.kind == "obj" then
                -- "8/12 Necrotic Crystal Fragment" -> label + count.
                local lr, lg, lb = 1, 1, 1
                if line.finished then lr, lg, lb = 0.55, 0.55, 0.55 end
                local count = FLText(c.body, c.obj, lr, lg, lb)
                count:SetWordWrap(false)
                count:SetWidth(0)
                count:SetText(line.cur .. "/" .. line.max)
                count:SetPoint("TOPRIGHT", W, "TOPLEFT", FL_W - PAD + dx, y)
                local fs = FLText(c.body, c.obj, lr, lg, lb)
                fs:SetWordWrap(false)
                fs:SetWidth(inner - (count:GetStringWidth() or 30) - 8)
                fs:SetText(line.name)
                fs:SetPoint("TOPLEFT", W, "TOPLEFT", PAD + dx, y)
                Show(fs); Show(count)
                y = y - LineHeight(fs, c.obj) - 3
                local b = Take("bar", function() return Bar(W.content, {}) end)
                b.bg:ClearAllPoints()
                b.bg:SetPoint("TOPLEFT", W, "TOPLEFT", PAD + dx, y)
                b.bg:SetSize(inner, 2)
                b.bg:SetVertexColor(c.track[1], c.track[2], c.track[3], c.track[4])
                b.fill:SetWidth(math.max(0.01, inner * (line.finished and 1 or line.cur / line.max)))
                local col = line.finished and c.done or c.accent
                b.fill:SetVertexColor(col[1], col[2], col[3], col[4] or 1)
                b.bg:SetAlpha(alpha); b.fill:SetAlpha(alpha)
                b.bg:Show(); b.fill:Show()
                y = y - 2 - 7
            elseif line.kind == "inst" then
                -- The instruction.
                local fs = FLText(c.bold, c.cur, c.current[1], c.current[2], c.current[3], c.current[4])
                fs:SetSpacing(math.floor(c.cur * 0.15 + 0.5))
                fs:SetWidth(inner - (st.tick > 0 and 30 or 0))   -- room for the tick
                fs:SetText(SmallIcons(EnemyColor(line.text), c.cur))
                fs:SetPoint("TOPLEFT", W, "TOPLEFT", PAD + dx, y)
                Show(fs)
                y = y - (fs:GetStringHeight() or c.cur) - 8
            else
                -- A note: "!" for warnings (RestedXP's yellow warning text),
                -- "i" for tips.
                local col = line.warn and c.stepCol or c.pctCol
                local mark = FLText(c.bold, c.obj, col[1], col[2], col[3], col[4])
                mark:SetWordWrap(false)
                mark:SetWidth(10)
                mark:SetText(line.warn and "!" or "i")
                mark:SetPoint("TOPLEFT", W, "TOPLEFT", PAD + dx, y)
                local fs = FLText(c.body, c.obj, c.muted[1], c.muted[2], c.muted[3], c.muted[4])
                fs:SetWidth(inner - 14)
                fs:SetText(SmallIcons(EnemyColor(line.text), c.obj))
                fs:SetPoint("TOPLEFT", W, "TOPLEFT", PAD + 14 + dx, y)
                Show(mark); Show(fs)
                y = y - (fs:GetStringHeight() or c.obj) - 5
            end
        end
        y = y - PAD + 5
        local full = top - y
        local h = math.max(2, math.floor(full * (1 - st.fold) + 0.5))
        local panelA = e.enter and alpha or (a and (e.skipped and alpha or (1 - st.fold)) or 1)
        edge:SetPoint("TOPLEFT", W, "TOPLEFT", dx, top)
        edge:SetSize(FL_W, h)
        edge:SetVertexColor(c.border[1], c.border[2], c.border[3], c.border[4] * panelA)
        panel:SetPoint("TOPLEFT", W, "TOPLEFT", 1 + dx, top - 1)
        panel:SetSize(FL_W - 2, h - 2)
        panel:SetVertexColor(0, 0, 0, c.cardA * panelA)
        Overlay(c, st, 1 + dx, top - 1, FL_W - 2, h - 2, top - math.min(full, h) / 2, PAD - 1)
        if not a then
            -- A click on the card skips the step, a right-click goes back one.
            local hit = Hit(true)
            hit:SetPoint("TOPLEFT", W, "TOPLEFT", 0, top)
            hit:SetSize(FL_W, full)
            hit.onClick = function(button)
                if button == "LeftButton" then SkipStep(e.frame)
                elseif button == "RightButton" then BackStep(e.frame) end
            end
        end
        y = top - h - math.floor(12 * (1 - st.fold) + 0.5)
    end
    Animate()
    if R.flashFor and R.flashFor ~= maxIndex then StartFlash() end
    R.flashFor = maxIndex

    -- Upcoming steps (completed ones aren't shown): number 12 grey (2px
    -- down), text 15 near-white, alpha max(0.35, 1 - i * 0.09); hover or
    -- "Fade Upcoming Steps" off = all at full alpha. The mouse wheel moves
    -- the list forward through the guide.
    if R.shownFor ~= maxIndex then R.shownFor, R.offset = maxIndex, 0 end
    local count = db.rxpUpcoming or 8
    R.offset = math.max(0, math.min(R.offset or 0, math.max(0, #rows - count)))
    local fade = db.rxpFade ~= false and not R.hover
    for i = 1 + R.offset, math.min(#rows, R.offset + count) do
        local row = rows[i].row
        local a = fade and math.max(c.fadeMin, 1 - (i - 1 - R.offset) * c.fadeStep) or 1
        local fs = FLText(c.body, c.text, c.textCol[1], c.textCol[2], c.textCol[3], c.textCol[4])
        fs:SetSpacing(math.floor(c.text * 0.25 + 0.5))   -- line-height 1.25
        fs:SetWidth(textW)
        fs:SetText(Plain(rows[i].line))
        fs:SetPoint("TOPLEFT", W, "TOPLEFT", FL_NUM, y)
        fs:SetAlpha(a)
        if c.listNums then
            local num = FLText(c.body, c.num, c.numCol_[1], c.numCol_[2], c.numCol_[3], c.numCol_[4])
            num:SetWidth(FL_NUM)
            num:SetText(row.index)
            num:SetPoint("LEFT", W, "TOPLEFT", 0, y - LineHeight(fs, c.text) / 2)   -- on the text's first line
            num:SetAlpha(a)
        end
        local h = fs:GetStringHeight() or c.text
        local hit = Hit()
        hit:SetPoint("TOPLEFT", W, "TOPLEFT", 0, y + 1)
        hit:SetSize(FL_W, h + 2)
        hit.onEnter, hit.onLeave = Hover(true), Hover(false)
        hit.onClick = function(button)
            local down = row:GetScript("OnMouseDown")   -- RestedXP's row menu
            if button == "RightButton" and down then down(row, "RightButton") end
        end
        hit.onDouble = function(button)
            local go = rxp.bottomMenu and rxp.bottomMenu[1] and rxp.bottomMenu[1].func
            if button == "LeftButton" and go then go(row.index) end   -- "Go to step"
        end
        y = y - h - 3
    end

    -- Hide what this pass didn't use.
    for kind, pool in pairs(pools) do
        for i = (used[kind] or 0) + 1, #pool do
            local item = pool[i]
            if kind == "bar" then item.bg:Hide(); item.fill:Hide()
            else item:Hide() end
        end
    end
    R.SetBodyHeight(-y)
    R.AttachTargets()
end

-- =====================================================================
-- RAIL: a vertical rail down the left, one marker per step
-- =====================================================================
-- Its own look copy of the APPEARANCE settings, prefix "rxpRl". Same step
-- reading, animations, click handling and fade as the Frameless layout
-- (Transitions / Overlay / Hit are shared): what changes is the shape. A 2px
-- rail runs down the left edge, each current step gets a filled accent
-- marker on it and each upcoming one a hollow marker, the text starting
-- clear of the rail at PAD. No card panels: the rail is the structure.
function R.RenderRail()
    local c = Cfg("rxpRl")
    local RL_W = c.width
    local rxp = R.OpenWindow(RL_W, c.backdrop)
    if not rxp then return end
    local db = DB()
    local st = R.WalkSteps()
    local RAIL_X = 4      -- the rail's centre line, from the window's left edge
    local PAD = 16        -- the text starts here, clear of the markers
    local inner = RL_W - PAD - 12
    -- RestedXP's own icon at the front of a line (Compact's leading icon).
    local ICON_W = math.floor(c.cur * 1.1 + 0.5)

    -- Header: the guide's zone and progress (GuideHeader). No line under it:
    -- the rail does that job.
    local y = R.GuideHeader(c, st, RL_W, PAD + COLLAPSE_L, 0)
    R.Header(y)

    local function Hover(on)
        return function()
            if R.hover ~= on then R.hover = on; R.RenderRail() end
        end
    end

    -- The rail: a 2px line from the header down to the last step (its
    -- height is only known at the end of the pass).
    local rail = Tex()
    rail:SetDrawLayer("BACKGROUND", 0)
    rail:SetPoint("TOPLEFT", W, "TOPLEFT", RAIL_X - 1, 0)
    rail:SetSize(2, 1)
    rail:SetVertexColor(c.track[1], c.track[2], c.track[3], math.max(0.25, c.track[4]))

    -- One marker on the rail, centred on it at `top`: filled for a current
    -- step, hollow for an upcoming one.
    local function Marker(top, size, filled, col, alpha)
        local t = Tex()
        t:SetDrawLayer(filled and "OVERLAY" or "BACKGROUND", 1)
        t:SetPoint("CENTER", W, "TOPLEFT", RAIL_X, top)
        t:SetSize(size, size)
        t:SetVertexColor(col[1], col[2], col[3], (filled and alpha or 0.9 * alpha) * (col[4] or 1))
    end

    -- Current steps: the instruction, its objectives (label, count, thin
    -- bar) and its notes, all to the right of the rail on a filled marker.
    -- Click skips the step, right-click goes back one; steps leaving and
    -- coming back animate (Transitions / Overlay, shared with Frameless).
    wipe(flash)
    local models = {}
    for _, step in ipairs(st.current) do models[step.index] = R.StepModel(step, c) end

    for _, e in ipairs(Transitions(st.current, models, st.minIndex, "RAIL")) do
        local m, a = e.model, e.anim
        local st = AnimState(e, RL_W)
        local dx, alpha = st.dx, st.alpha
        local top = y
        local function Show(fs)
            fs:SetAlpha(alpha)
            if not a then flash[#flash + 1] = fs end
        end
        local markSize = math.max(6, math.floor(c.cur * 0.55 + 0.5))
        local markMid   -- the marker's height: the middle of the step's first line
        if c.stepLabel then
            local label = FLText(c.bold, c.num, c.stepCol[1], c.stepCol[2], c.stepCol[3], c.stepCol[4])
            label:SetWordWrap(false)
            label:SetWidth(inner)
            label:SetText("STEP " .. m.index)
            label:SetPoint("TOPLEFT", W, "TOPLEFT", PAD + dx, y)
            Show(label)
            markMid = (m.lines[1] and m.lines[1].kind == "inst")
                and nil or (y - LineHeight(label, c.num) / 2)
            y = y - LineHeight(label, c.num) - 6
        end
        for _, line in ipairs(m.lines) do
            -- On a note, the "!" / "i" marker leads and the icon sits after
            -- it; on the other lines the icon leads and there is no marker.
            local lead = line.kind == "note" and 14 or 0
            -- RestedXP's own icon for this line, when it has one.
            local iw = 0
            if line.icon then
                iw = ICON_W + 4
                local ic = FLText(c.body, line.kind == "inst" and c.cur or c.obj, 1, 1, 1)
                ic:SetWordWrap(false)
                ic:SetWidth(ICON_W)
                ic:SetText(SmallIcons(line.icon, line.kind == "inst" and c.cur or c.obj))
                ic:SetPoint("TOPLEFT", W, "TOPLEFT", PAD + lead + dx, y)
                Show(ic)
            end
            if line.kind == "obj" then
                -- "8/12 Necrotic Crystal Fragment": label left, count right.
                local lr, lg, lb = 1, 1, 1
                if line.finished then lr, lg, lb = 0.55, 0.55, 0.55 end
                local count = FLText(c.body, c.obj, lr, lg, lb)
                count:SetWordWrap(false)
                count:SetWidth(0)
                count:SetText(line.cur .. "/" .. line.max)
                count:SetPoint("TOPRIGHT", W, "TOPLEFT", RL_W - 10 + dx, y)
                local fs = FLText(c.body, c.obj, lr, lg, lb)
                fs:SetWordWrap(false)
                fs:SetWidth(math.max(20, inner - iw - (count:GetStringWidth() or 30) - 8))
                fs:SetText(line.name)
                fs:SetPoint("TOPLEFT", W, "TOPLEFT", PAD + iw + dx, y)
                Show(fs); Show(count)
                markMid = markMid or (y - LineHeight(fs, c.obj) / 2)
                y = y - LineHeight(fs, c.obj) - 3
                local b = Take("bar", function() return Bar(W.content, {}) end)
                b.bg:ClearAllPoints()
                b.bg:SetPoint("TOPLEFT", W, "TOPLEFT", PAD + dx, y)
                b.bg:SetSize(inner, 2)
                b.bg:SetVertexColor(c.track[1], c.track[2], c.track[3], c.track[4])
                b.fill:SetWidth(math.max(0.01, inner * (line.finished and 1 or line.cur / line.max)))
                local col = line.finished and c.done or c.accent
                b.fill:SetVertexColor(col[1], col[2], col[3], col[4] or 1)
                b.bg:SetAlpha(alpha); b.fill:SetAlpha(alpha)
                b.bg:Show(); b.fill:Show()
                y = y - 2 - 7
            elseif line.kind == "inst" then
                -- The instruction.
                local fs = FLText(c.bold, c.cur, c.current[1], c.current[2], c.current[3], c.current[4])
                fs:SetSpacing(math.floor(c.cur * 0.15 + 0.5))
                fs:SetWidth(math.max(20, inner - iw - (st.tick > 0 and 30 or 0)))   -- room for the tick
                fs:SetText(SmallIcons(EnemyColor(line.text), c.cur))
                fs:SetPoint("TOPLEFT", W, "TOPLEFT", PAD + iw + dx, y)
                Show(fs)
                markMid = markMid or (y - (fs:GetStringHeight() or c.cur) / 2)
                y = y - (fs:GetStringHeight() or c.cur) - 8
            else
                -- A note: "!" for warnings, "i" for tips.
                local col = line.warn and c.stepCol or c.pctCol
                local mark = FLText(c.bold, c.obj, col[1], col[2], col[3], col[4])
                mark:SetWordWrap(false)
                mark:SetWidth(10)
                mark:SetText(line.warn and "!" or "i")
                -- The marker leads on a note, then the icon, then the text.
                mark:SetPoint("TOPLEFT", W, "TOPLEFT", PAD + dx, y)
                local fs = FLText(c.body, c.obj, c.muted[1], c.muted[2], c.muted[3], c.muted[4])
                fs:SetWidth(math.max(20, inner - 14 - iw))
                fs:SetText(SmallIcons(EnemyColor(line.text), c.obj))
                fs:SetPoint("TOPLEFT", W, "TOPLEFT", PAD + lead + iw + dx, y)
                Show(mark); Show(fs)
                markMid = markMid or (y - (fs:GetStringHeight() or c.obj) / 2)
                y = y - (fs:GetStringHeight() or c.obj) - 5
            end
        end
        local full = top - y + 10
        local h = math.max(2, math.floor(full * (1 - st.fold) + 0.5))
        Marker(markMid or (top - 4), markSize, true, c.accent, alpha)
        Overlay(c, st, PAD + dx, top, inner, h, top - math.min(full, h) / 2, 6)
        if not a then
            -- A click on the step skips it, a right-click goes back one.
            local hit = Hit(true)
            hit:SetPoint("TOPLEFT", W, "TOPLEFT", 0, top)
            hit:SetSize(RL_W, full)
            hit.onClick = function(button)
                if button == "LeftButton" then SkipStep(e.frame)
                elseif button == "RightButton" then BackStep(e.frame) end
            end
        end
        y = top - h - 10
    end
    Animate()
    if R.flashFor and R.flashFor ~= st.maxIndex then StartFlash() end
    R.flashFor = st.maxIndex

    -- Upcoming steps on a hollow marker, their number at the right edge,
    -- the text fading out the further ahead it is. The wheel moves through
    -- the guide.
    if R.shownFor ~= st.maxIndex then R.shownFor, R.offset = st.maxIndex, 0 end
    local count = db.rxpUpcoming or 8
    R.offset = math.max(0, math.min(R.offset or 0, math.max(0, #st.rows - count)))
    local fade = db.rxpFade ~= false and not R.hover
    for i = 1 + R.offset, math.min(#st.rows, R.offset + count) do
        local row = st.rows[i].row
        local a = fade and math.max(c.fadeMin, 1 - (i - 1 - R.offset) * c.fadeStep) or 1
        local iw = 0
        if st.rows[i].icon then
            -- The row's own icon, like Compact.
            iw = ICON_W + 4
            local ic = FLText(c.body, c.text, 1, 1, 1)
            ic:SetWordWrap(false)
            ic:SetWidth(ICON_W)
            ic:SetText(SmallIcons(st.rows[i].icon, c.text))
            ic:SetPoint("TOPLEFT", W, "TOPLEFT", PAD, y)
            ic:SetAlpha(a)
        end
        local fs = FLText(c.body, c.text, c.textCol[1], c.textCol[2], c.textCol[3], c.textCol[4])
        fs:SetSpacing(math.floor(c.text * 0.25 + 0.5))   -- line-height 1.25
        fs:SetWidth(inner)
        fs:SetText(Plain(st.rows[i].line))
        fs:SetPoint("TOPLEFT", W, "TOPLEFT", PAD + iw, y)
        fs:SetAlpha(a)
        local h = fs:GetStringHeight() or c.text
        Marker(y - h / 2, math.max(5, math.floor(c.num * 0.55 + 0.5)), false, c.muted, a)
        if c.listNums then
            local num = FLText(c.body, c.num, c.numCol_[1], c.numCol_[2], c.numCol_[3], c.numCol_[4])
            num:SetWordWrap(false)
            num:SetWidth(0)
            num:SetText(row.index)
            num:SetPoint("RIGHT", W, "TOPLEFT", RL_W - 8, y)
            num:SetAlpha(a)
            local nw = (num:GetStringWidth() or 0) + 10
            if nw > 34 then fs:SetWidth(math.max(20, inner - iw - nw)) end
        end
        local hit = Hit()
        hit:SetPoint("TOPLEFT", W, "TOPLEFT", 0, y + 1)
        hit:SetSize(RL_W, h + 2)
        hit.onEnter, hit.onLeave = Hover(true), Hover(false)
        hit.onClick = function(button)
            local down = row:GetScript("OnMouseDown")   -- RestedXP's row menu
            if button == "RightButton" and down then down(row, "RightButton") end
        end
        hit.onDouble = function(button)
            local go = rxp.bottomMenu and rxp.bottomMenu[1] and rxp.bottomMenu[1].func
            if button == "LeftButton" and go then go(row.index) end   -- "Go to step"
        end
        y = y - h - 4
    end

    rail:SetHeight(math.max(2, -y))

    R.Finish(y)
end

-- =====================================================================
-- Shared by the layouts added after Frameless (Rail): the same window
-- walk, step reading and header, so another layout is one renderer away.
-- =====================================================================
-- Our own window over RestedXP's: it stays alive underneath (invisible and
-- click-through) and we read its steps after each of its updates. `width`
-- is the width on screen; `backdrop` its panel opacity (0 = no panel).
function R.OpenWindow(width, backdrop)
    local rxp = _G.RXPFrame
    if not W then BuildWindow() end
    if not rxp:IsShown() then W:Hide(); return nil end
    HideRXP(true)
    W:Show()
    W:SetScale(rxp:GetScale() or 1)
    W:SetFrameStrata(rxp:GetFrameStrata())
    W:SetFrameLevel(rxp:GetFrameLevel() + 20)
    W:ClearAllPoints()
    W:SetPoint("TOPLEFT", rxp, "TOPLEFT", 0, 0)
    W:SetWidth(width)
    FitRXPWidth(width)
    W:SetBackdropColor(0, 0, 0, backdrop or 0)
    W:SetBackdropBorderColor(0, 0, 0, 0)
    -- The Timeline's own pieces stay out of these layouts.
    W.name:Hide(); W.progress:Hide(); W.percent:Hide(); W.pill:Hide(); W.pillText:Hide()
    W.headBg:Hide(); W.band:Hide(); W.bandEdge:Hide()
    used = {}
    return rxp
end

-- What one step shows, read from RestedXP's step frame now (it reuses the
-- frame for the next step straight away, so a leaving step is drawn from
-- this copy): its instruction, its objectives and its notes.
function R.StepModel(step, c)
    local m = { index = step.index, lines = {} }
    local instructed = false
    local data = StepData(step.index)
    for i, el in ipairs(step.elements or {}) do
        local t = el.text and el.text:GetText()
        if el:IsShown() and el:GetAlpha() > 0 and type(t) == "string" and not IsSecret(t) and t ~= "" and t ~= " " then
            -- RestedXP's own icon for this line (Compact's leading icon),
            -- quest marker included.
            local icon = LineIcon(data and data[i], el, t)
            local cur, max = Count(t)
            if cur then
                if c.objectives then
                    m.lines[#m.lines + 1] = { kind = "obj", cur = cur, max = max, icon = icon,
                        finished = cur >= max or (el.button and el.button:GetChecked() and true) or false,
                        name = ObjLabel(t) }
                end
            elseif not instructed then
                m.lines[#m.lines + 1] = { kind = "inst", text = t, icon = icon }
                instructed = true
            else
                m.lines[#m.lines + 1] = { kind = "note", text = t, icon = icon,
                    warn = t:find(HexPattern("fcdc00")) ~= nil }
            end
        end
    end
    return m
end

-- RestedXP's window read once: the current steps, the rows listed after
-- the last one, and the guide's zone, level range, count and % done.
function R.WalkSteps()
    local rxp = _G.RXPFrame
    local current = {}
    for _, step in pairs(rxp.CurrentStepFrame and rxp.CurrentStepFrame.framePool or {}) do
        if step:IsShown() and step.step and step.index then current[#current + 1] = step end
    end
    table.sort(current, function(a, b) return a.index < b.index end)
    local minIndex, maxIndex = nil, 0
    for _, step in ipairs(current) do
        maxIndex = math.max(maxIndex, step.index)
        minIndex = minIndex and math.min(minIndex, step.index) or step.index
    end
    local rows, lastIndex = {}, 0
    for _, row in pairs(rxp.ScrollChild and rxp.ScrollChild.framePool or {}) do
        if row:IsShown() and row.index then
            if row.index > lastIndex then lastIndex = row.index end
            if row.index > maxIndex and row.text then
                local raw = row.text:GetText()
                local line = RowLine(raw)
                if line then
                    -- The listed step's own icon: an inline "|T...|t" at the
                    -- front of its text, else the marker its data element
                    -- names (a listed "Turn in"/"Accept" step keeps its ? / !).
                    local de = StepData(row.index)
                    rows[#rows + 1] = { row = row, line = line,
                        icon = LeadIcon(raw) or LineIcon(de and de[1], row, raw) }
                end
            end
        end
    end
    table.sort(rows, function(a, b) return a.row.index < b.row.index end)
    local nameText = rxp.GuideName and rxp.GuideName.text and rxp.GuideName.text:GetText()
    if type(nameText) ~= "string" or IsSecret(nameText) then nameText = "" end
    nameText = nameText:match("^[^\n]*") or ""
    local levels, zone = nameText:match("^(%d+%s*%-%s*%d+)%s+(.+)$")
    return {
        rxp = rxp, current = current, rows = rows,
        minIndex = minIndex, maxIndex = maxIndex, lastIndex = lastIndex,
        zone = zone or nameText, levels = levels,
        pct = (minIndex and lastIndex > 0) and math.min(1, minIndex / lastIndex) or 0,
    }
end

-- The guide's header on the line at `y`: "Tirisfal" with its level range
-- after it, "7/20 · 35%" on the right (the % in its own colour). `pad` is
-- where the text starts, `width` the window's. Returns the next y.
function R.GuideHeader(c, st, width, pad, y)
    local fl = FLPieces()
    ns.ApplyFont(fl.count, c.body, c.head, "OUTLINE")
    fl.count:SetTextColor(c.muted[1], c.muted[2], c.muted[3], c.muted[4])
    if st.minIndex and st.lastIndex > 0 then
        fl.count:SetText(("%d/%d \194\183 |c%02x%02x%02x%02x%d%%|r"):format(st.minIndex, st.lastIndex,
            math.floor((c.muted[4] or 1) * 255 + 0.5),
            math.floor(c.pctCol[1] * 255 + 0.5), math.floor(c.pctCol[2] * 255 + 0.5),
            math.floor(c.pctCol[3] * 255 + 0.5), math.floor(st.pct * 100 + 0.5)))
    else
        fl.count:SetText("")
    end
    ns.ApplyFont(fl.level, c.bold, c.head, "OUTLINE")
    fl.level:SetTextColor(c.accent[1], c.accent[2], c.accent[3], c.accent[4])
    fl.level:SetText(st.levels or "")
    ns.ApplyFont(fl.zone, c.bold, c.zone, "OUTLINE")
    fl.zone:SetTextColor(c.zoneCol[1], c.zoneCol[2], c.zoneCol[3], c.zoneCol[4])
    fl.zone:SetText(st.zone)
    local countW = (fl.count:GetStringWidth() or 0) + 8
    local levelW = st.levels and ((fl.level:GetStringWidth() or 0) + 5) or 0
    fl.zone:SetWidth(math.max(20, math.min((fl.zone:GetStringWidth() or 0) + 2, width - countW - levelW - pad)))
    local zoneH = fl.zone:GetStringHeight() or c.zone
    fl.zone:ClearAllPoints()
    fl.zone:SetPoint("TOPLEFT", W, "TOPLEFT", pad, y)
    W.collapseAnchorFs = fl.zone   -- the switch centres on this title
    fl.level:ClearAllPoints()
    fl.level:SetPoint("BOTTOMLEFT", fl.zone, "BOTTOMRIGHT", 5, 2)   -- same baseline
    fl.count:ClearAllPoints()
    fl.count:SetPoint("BOTTOMRIGHT", W, "TOPRIGHT", 0, y - zoneH + 2)
    for _, piece in ipairs({ fl.zone, fl.level, fl.count }) do piece:Show() end
    fl.track:Hide(); fl.trackShadow:Hide(); fl.fill:Hide()
    return y - zoneH - 8
end

-- RestedXP's handlers on the header strip (drag, Alt+drag resize,
-- right-click menu), and the end of a pass: the pooled pieces this pass
-- didn't use, the window's height and the Active Targets / Items boxes.
function R.Header(y)
    W.header:ClearAllPoints()
    W.header:SetPoint("TOPLEFT", W, "TOPLEFT", 0, 0)
    W.header:SetPoint("TOPRIGHT", W, "TOPRIGHT", 0, 0)
    W.header:SetHeight(-y)
end
function R.Finish(y)
    for kind, pool in pairs(pools) do
        for i = (used[kind] or 0) + 1, #pool do
            local item = pool[i]
            if kind == "bar" then item.bg:Hide(); item.fill:Hide()
            else item:Hide() end
        end
    end
    R.SetBodyHeight(-y)
    R.AttachTargets()
end

-- =====================================================================
-- Timeline: our own window, with its steps on a numbered line
-- =====================================================================
-- Its look is its own copy of the APPEARANCE settings (TLCfg): the
-- defaults are the 1.4 Timeline's (Expressway, blue, a 60% black panel).
function R.RenderTimeline()
    local rxp = _G.RXPFrame
    local c = TLCfg()
    if not W then BuildWindow() end
    if not rxp:IsShown() then W:Hide(); return end
    HideRXP(true)
    W:Show()
    W:SetScript("OnUpdate", nil)
    W.name:Show(); W.progress:Show(); W.percent:Show(); W.headBg:Show()
    for _, piece in pairs(W.fl or {}) do piece:Hide() end
    W:SetScale(rxp:GetScale() or 1)
    W:SetFrameStrata(rxp:GetFrameStrata())
    W:SetFrameLevel(rxp:GetFrameLevel() + 20)
    W:ClearAllPoints()
    W:SetPoint("BOTTOMLEFT", rxp, "BOTTOMLEFT", 0, 0)
    local width = c.width
    W:SetWidth(width)
    FitRXPWidth(width)
    -- The panel (Backdrop): black at its opacity, and its 1px border.
    W:SetBackdropColor(0, 0, 0, c.backdrop)
    W:SetBackdropBorderColor(c.border[1], c.border[2], c.border[3], c.border[4])

    used = {}
    local db = DB()
    -- Number Column: the numbers' column, the text after it; the line runs
    -- down the column's middle.
    local textX = (c.stepLabel or c.listNums) and (c.numCol + 14) or TL_PAD   -- no numbers: no column
    local lineX = math.floor(textX / 2 + 0.5)
    local textW = width - textX - TL_PAD
    local y = -TL_PAD

    -- Header: "6-10 Durotar" split into the zone (bold) and a level pill
    -- (a name that doesn't start with a level range is shown whole), then
    -- "Step 12 of 84" on the line under (its text is set further down, once
    -- the steps are known), the guide's % big on the right.
    local nameText = rxp.GuideName and rxp.GuideName.text and rxp.GuideName.text:GetText()
    if type(nameText) ~= "string" or IsSecret(nameText) then nameText = "" end
    nameText = nameText:match("^[^\n]*") or ""
    local levels, zone = nameText:match("^(%d+%s*%-%s*%d+)%s+(.+)$")
    zone = zone or nameText
    local acc = c.accent
    ns.ApplyFont(W.name, c.bold, c.zone, "OUTLINE")
    W.name:SetTextColor(c.zoneCol[1], c.zoneCol[2], c.zoneCol[3], c.zoneCol[4])
    W.name:SetText(zone)
    local pillW = 0
    if levels then
        ns.ApplyFont(W.pillText, c.body, c.head, "OUTLINE")
        W.pillText:SetTextColor(acc[1], acc[2], acc[3], acc[4] or 1)
        W.pillText:SetText(levels)
        pillW = (W.pillText:GetStringWidth() or 20) + 10
    end
    W.name:ClearAllPoints()
    W.name:SetPoint("TOPLEFT", W, "TOPLEFT", TL_PAD + COLLAPSE_L, y)
    W.collapseAnchorFs = W.name   -- the switch centres on this title
    ns.ApplyFont(W.percent, c.bold, c.zone + 1, "OUTLINE")
    W.percent:SetTextColor(c.pctCol[1], c.pctCol[2], c.pctCol[3], c.pctCol[4])
    W.percent:SetText("100%")   -- widest, to keep room for it
    local pctW = (W.percent:GetStringWidth() or 40) + 8
    W.name:SetWidth(math.max(20, math.min((W.name:GetStringWidth() or 0) + 2, width - TL_PAD * 2 - COLLAPSE_L - pillW - 6 - pctW)))
    W.pill:SetShown(levels ~= nil)
    W.pillText:SetShown(levels ~= nil)
    if levels then
        W.pill:ClearAllPoints()
        W.pill:SetPoint("LEFT", W.name, "RIGHT", 6, 0)
        W.pill:SetSize(pillW, c.head + 4)
        W.pill:SetVertexColor(acc[1], acc[2], acc[3], 0.2 * (acc[4] or 1))
    end
    ns.ApplyFont(W.progress, c.body, c.head, "OUTLINE")
    W.progress:SetTextColor(c.muted[1], c.muted[2], c.muted[3], c.muted[4])
    W.progress:SetText("Step")   -- for its height; the real text comes below
    W.progress:ClearAllPoints()
    W.progress:SetPoint("TOPLEFT", W.name, "BOTTOMLEFT", 0, -2)
    local headerH = (W.name:GetStringHeight() or c.zone) + 2 + (W.progress:GetStringHeight() or c.head)
    W.percent:ClearAllPoints()
    W.percent:SetPoint("RIGHT", W, "TOPRIGHT", -TL_PAD, y - headerH / 2)
    local hr, hg, hb, ha = c.headBg[1], c.headBg[2], c.headBg[3], c.headBg[4]
    W.headBg:ClearAllPoints()
    W.headBg:SetPoint("TOPLEFT", W, "TOPLEFT", 1, -1)
    W.headBg:SetPoint("BOTTOMRIGHT", W, "TOPRIGHT", -1, y - headerH - 9)
    -- Solid at the top, still two-thirds there at the bottom edge.
    W.headBg:SetGradient("VERTICAL", CreateColor(hr, hg, hb, ha * 0.65), CreateColor(hr, hg, hb, ha))
    W.header:ClearAllPoints()
    W.header:SetPoint("TOPLEFT", W, "TOPLEFT", 0, 0)
    W.header:SetPoint("TOPRIGHT", W, "TOPRIGHT", 0, 0)
    W.header:SetHeight(TL_PAD + headerH + 6)
    y = y - headerH - 6 - 1 - 8

    -- Step numbers, top to bottom (their centre y), for the line after.
    local marks = {}

    -- Current steps (on the band). A click anywhere on one skips it, a
    -- right-click goes back a step; steps leaving and coming back animate.
    local bandTop = y + 5
    local current = {}
    for _, step in pairs(rxp.CurrentStepFrame and rxp.CurrentStepFrame.framePool or {}) do
        if step:IsShown() and step.step and step.index then current[#current + 1] = step end
    end
    table.sort(current, function(a, b) return a.index < b.index end)
    local minIndex, maxIndex = nil, 0
    for _, step in ipairs(current) do
        maxIndex = math.max(maxIndex, step.index)
        minIndex = minIndex and math.min(minIndex, step.index) or step.index
    end
    -- What a step shows, read now (RestedXP reuses its frame at once, so a
    -- leaving step is drawn from this copy): the instruction, notes, and
    -- objectives ("5/10 Cactus Apple") with a bar.
    local function Model(step)
        local m = { index = step.index, lines = {} }
        for _, el in ipairs(step.elements or {}) do
            local t = el.text and el.text:GetText()
            if el:IsShown() and el:GetAlpha() > 0 and type(t) == "string" and not IsSecret(t) and t ~= "" and t ~= " " then
                local cur, max = Count(t)
                if not cur then
                    m.lines[#m.lines + 1] = { text = t }
                elseif c.objectives then
                    m.lines[#m.lines + 1] = { text = t, cur = cur, max = max,
                        finished = cur >= max or (el.button and el.button:GetChecked() and true) or false }
                end
            end
        end
        return m
    end
    local models = {}
    for _, step in ipairs(current) do models[step.index] = Model(step) end
    for _, e in ipairs(Transitions(current, models, minIndex, "TIMELINE")) do
        local m = e.model
        local st = AnimState(e, width)
        local top = y
        local first, instructed = true, false
        for _, line in ipairs(m.lines) do
            local fs, size
            if line.cur or instructed then
                size = c.obj
                fs = Text(c.body, size, c.muted[1], c.muted[2], c.muted[3], c.muted[4])
            else
                size = c.cur
                fs = Text(c.semi, size, c.current[1], c.current[2], c.current[3], c.current[4])
                instructed = true
            end
            fs:SetWidth(textW - (st.tick > 0 and 26 or 0))   -- room for the tick
            fs:SetText(SmallIcons(EnemyColor(line.text), size))
            fs:SetPoint("TOPLEFT", W, "TOPLEFT", textX + st.dx, y)
            fs:SetAlpha(st.alpha)
            if first and c.stepLabel then
                -- Its number on the line (not counted into the line while it leaves).
                local cy = y - LineHeight(fs, size) / 2
                local n = Num(m.index, c.body, c.num, c.stepCol)
                n:SetPoint("CENTER", W, "TOPLEFT", lineX + st.dx, cy)
                n:SetAlpha(st.alpha)
                if not e.anim then marks[#marks + 1] = cy end
            end
            first = false
            y = y - (fs:GetStringHeight() or size) - 2
            if line.cur then
                local b = Take("bar", function() return Bar(W.content, {}) end)
                b.bg:ClearAllPoints()
                b.bg:SetPoint("TOPLEFT", W, "TOPLEFT", textX + st.dx, y - 1)
                b.bg:SetSize(textW, BAR_H)
                b.bg:SetVertexColor(c.track[1], c.track[2], c.track[3], c.track[4])   -- shows even at 0/1
                b.fill:SetWidth(math.max(0.01, textW * (line.finished and 1 or line.cur / line.max)))
                local col = line.finished and c.done or acc
                b.fill:SetVertexColor(col[1], col[2], col[3], col[4] or 1)
                b.bg:SetAlpha(st.alpha); b.fill:SetAlpha(st.alpha)
                b.bg:Show(); b.fill:Show()
                y = y - BAR_H - 3
            end
        end
        if first then y = y - c.cur end   -- a step with nothing to show still takes a line
        y = y - 6
        local full = top - y
        local h = math.max(2, math.floor(full * (1 - st.fold) + 0.5))
        Overlay(c, st, 1 + st.dx, top + 3, width - 2, h, top + 3 - math.min(full, h) / 2, TL_PAD - 1)
        if not e.anim then
            local hit = Hit(true)
            hit:SetPoint("TOPLEFT", W, "TOPLEFT", 0, top + 3)
            hit:SetSize(width, full)
            hit.onClick = function(button)
                if button == "LeftButton" then SkipStep(e.frame)
                elseif button == "RightButton" then BackStep(e.frame) end
            end
        end
        y = top - h
    end
    Animate()
    local bandBottom = y + 2
    if bandBottom < bandTop - 4 then
        W.band:SetVertexColor(acc[1], acc[2], acc[3], c.cardA * (acc[4] or 1))
        W.band:ClearAllPoints()
        W.band:SetPoint("TOPLEFT", W, "TOPLEFT", 1, bandTop)
        W.band:SetPoint("BOTTOMRIGHT", W, "TOPRIGHT", -1, bandBottom)
        W.band:Show()
        W.bandEdge:SetVertexColor(acc[1], acc[2], acc[3], acc[4] or 1)
        W.bandEdge:ClearAllPoints()
        W.bandEdge:SetPoint("TOPLEFT", W.band, "TOPLEFT")
        W.bandEdge:SetPoint("BOTTOMLEFT", W.band, "BOTTOMLEFT")
        W.bandEdge:Show()
        y = y - 4
    else
        W.band:Hide(); W.bandEdge:Hide()
    end

    -- The step list: RestedXP's rows, from the step after the current ones.
    -- The mouse wheel moves that start (R.offset) forward through the guide
    -- or back to earlier steps; it goes back to 0 when the step changes.
    local rows, lastIndex = {}, 0
    for _, row in pairs(rxp.ScrollChild and rxp.ScrollChild.framePool or {}) do
        if row:IsShown() and row.index then
            if row.index > lastIndex then lastIndex = row.index end
            if row.text and (row.index < (minIndex or 0) or row.index > maxIndex) then
                local line = RowLine(row.text:GetText())
                if line then rows[#rows + 1] = { row = row, line = line } end
            end
        end
    end
    table.sort(rows, function(a, b) return a.row.index < b.row.index end)
    if R.shownFor ~= maxIndex then R.shownFor, R.offset = maxIndex, 0 end
    local start = #rows + 1
    for i, r in ipairs(rows) do
        if r.row.index > maxIndex then start = i; break end
    end
    local count = db.rxpUpcoming or 8
    local upper = math.max(0, #rows - start - count + 1)
    R.offset = math.max(1 - start, math.min(R.offset or 0, upper))
    local from = start + R.offset
    for i = from, math.min(#rows, from + count - 1) do
        local row = rows[i].row
        local done = row.index < (minIndex or 0)
        -- Earlier steps (scrolled back to) a dimmer grey.
        local k = done and 0.72 or 1            local fs = Text(c.body, c.text, c.textCol[1] * k, c.textCol[2] * k, c.textCol[3] * k, c.textCol[4])
        -- Further from the current step = dimmer (the next one is full).
        local away = (i >= start) and (i - start) or (start - i - 1)
        local fade = db.rxpFade == false and 1 or math.max(c.fadeMin, 1 - away * c.fadeStep)
        fs:SetAlpha(fade)
        fs:SetWidth(textW)
        fs:SetText(Plain(rows[i].line))
        fs:SetPoint("TOPLEFT", W, "TOPLEFT", textX, y)
        local h = fs:GetStringHeight() or c.text
        if c.listNums then
            local cy = y - LineHeight(fs, c.text) / 2
            local n = Num(row.index, c.body, c.num, { c.numCol_[1] * k, c.numCol_[2] * k, c.numCol_[3] * k, c.numCol_[4] })
            n:SetPoint("CENTER", W, "TOPLEFT", lineX, cy)
            n:SetAlpha(fade)
            marks[#marks + 1] = cy
        end
        local hit = Hit()
        hit:SetPoint("TOPLEFT", W, "TOPLEFT", 0, y + 2)
        hit:SetSize(width, h + 4)
        hit.onClick = function(button)
            -- RestedXP's own row menu ("Go to step", feedback).
            local down = row:GetScript("OnMouseDown")
            if button == "RightButton" and down then down(row, "RightButton") end
        end
        hit.onDouble = function(button)
            -- RestedXP's own "Go to step".
            local go = rxp.bottomMenu and rxp.bottomMenu[1] and rxp.bottomMenu[1].func
            if button == "LeftButton" and go then go(row.index) end
        end
        y = y - h - 8
    end

    if minIndex and lastIndex > 0 then
        W.progress:SetText(("Step %d of %d"):format(minIndex, lastIndex))
        W.percent:SetText(math.floor(minIndex / lastIndex * 100 + 0.5) .. "%")
    else
        W.progress:SetText("")
        W.percent:SetText("")
    end

    -- The line: a piece between each pair of numbers, stopping short of both.
    table.sort(marks, function(a, b) return a > b end)
    local gap = c.num * 0.4 + 2   -- just clear of the digits
    for i = 1, #marks - 1 do
        local top, bottom = marks[i] - gap, marks[i + 1] + gap
        if top > bottom then Segment(lineX, top, bottom, acc) end
    end

    -- Hide what this pass didn't use.
    for kind, pool in pairs(pools) do
        for i = (used[kind] or 0) + 1, #pool do
            local item = pool[i]
            if kind == "bar" then item.bg:Hide(); item.fill:Hide()
            else item:Hide() end
        end
    end
    R.SetBodyHeight(-y)
    R.AttachTargets()
end

-- =====================================================================
-- Compact (Zygor-like): a solid window, a title bar with step buttons
-- =====================================================================
-- A title bar (the zone, the level range, "‹ 2/189 ›": ‹ goes back a step,
-- › skips one), the current step tinted with an edge on its left, each line
-- with RestedXP's own icon for it (accept, turn in, kill, loot, go to...),
-- objectives with a bar and "3/8" on the right, the next steps with their
-- icons, fading, and the guide's progress as a thin bar along the bottom.
-- Its look is its own copy of the APPEARANCE settings (prefix "rxpCp").
local PREV_TEX = "Interface\\AddOns\\" .. ADDON .. "\\Textures\\rxp-prev.png"
local NEXT_TEX = "Interface\\AddOns\\" .. ADDON .. "\\Textures\\rxp-next.png"

-- RestedXP's icon at the start of a line ("|Tpath:0|t"), if any.
function R.RenderCompact()
    local rxp = _G.RXPFrame
    local c = Cfg("rxpCp")
    if not W then BuildWindow() end
    if not rxp:IsShown() then W:Hide(); return end
    HideRXP(true)
    W:Show()
    W:SetScript("OnUpdate", nil)
    -- The other layouts' own pieces stay out of this one.
    W.name:Hide(); W.progress:Hide(); W.percent:Hide(); W.pill:Hide(); W.pillText:Hide()
    W.headBg:Hide(); W.band:Hide(); W.bandEdge:Hide()
    for _, piece in pairs(W.fl or {}) do piece:Hide() end
    W:SetScale(rxp:GetScale() or 1)
    W:SetFrameStrata(rxp:GetFrameStrata())
    W:SetFrameLevel(rxp:GetFrameLevel() + 20)
    W:ClearAllPoints()
    W:SetPoint("TOPLEFT", rxp, "TOPLEFT", 0, 0)
    local width = c.width
    W:SetWidth(width)
    FitRXPWidth(width)
    W:SetBackdropColor(0, 0, 0, c.backdrop)
    W:SetBackdropBorderColor(c.border[1], c.border[2], c.border[3], c.border[4])

    used = {}
    local db = DB()
    local PADX = 8
    local function Fill(layer, sub, x, top, w, h, col, alpha)
        local t = Tex()
        t:SetTexture(WHITE)
        t:SetDrawLayer(layer, sub)
        t:SetPoint("TOPLEFT", W, "TOPLEFT", x, top)
        t:SetSize(math.max(1, w), math.max(1, h))
        t:SetVertexColor(col[1], col[2], col[3], (alpha or 1) * (col[4] or 1))
        return t
    end

    -- The steps: the current ones, the list and its last step.
    local current = {}
    for _, step in pairs(rxp.CurrentStepFrame and rxp.CurrentStepFrame.framePool or {}) do
        if step:IsShown() and step.step and step.index then current[#current + 1] = step end
    end
    table.sort(current, function(a, b) return a.index < b.index end)
    local minIndex, maxIndex = nil, 0
    for _, step in ipairs(current) do
        maxIndex = math.max(maxIndex, step.index)
        minIndex = minIndex and math.min(minIndex, step.index) or step.index
    end
    local rows, lastIndex = {}, 0
    for _, row in pairs(rxp.ScrollChild and rxp.ScrollChild.framePool or {}) do
        if row:IsShown() and row.index then
            if row.index > lastIndex then lastIndex = row.index end
            if row.index > maxIndex and row.text then
                local raw = row.text:GetText()
                local line = RowLine(raw)
                if line then rows[#rows + 1] = { row = row, line = line, icon = LeadIcon(raw) } end
            end
        end
    end
    table.sort(rows, function(a, b) return a.row.index < b.row.index end)

    -- Title bar: the zone (bold) and its level range; on the right
    -- "‹ 2/189 ›" (Show Current Step Number). Dragging it moves the window.
    local titleH = math.max(c.zone, c.head) + 12
    local mid = -1 - titleH / 2
    Fill("BACKGROUND", 1, 1, -1, width - 2, titleH, c.headBg)
    Fill("BACKGROUND", 2, 1, -1 - titleH, width - 2, 1, c.border)
    local nameText = rxp.GuideName and rxp.GuideName.text and rxp.GuideName.text:GetText()
    if type(nameText) ~= "string" or IsSecret(nameText) then nameText = "" end
    nameText = nameText:match("^[^\n]*") or ""
    local levels, zone = nameText:match("^(%d+%s*%-%s*%d+)%s+(.+)$")
    zone = zone or nameText
    W.header:ClearAllPoints()
    W.header:SetPoint("TOPLEFT", W, "TOPLEFT", 0, 0)
    W.header:SetPoint("TOPRIGHT", W, "TOPRIGHT", 0, 0)
    W.header:SetHeight(titleH + 1)
    local x = width - PADX
    local first = current[1]
    if c.stepLabel and minIndex and lastIndex > 0 then
        local btn = math.floor(c.head * 1.3 + 0.5)
        local function Button(tex, onClick)
            local t = Tex()
            t:SetTexture(tex)
            t:SetDrawLayer("OVERLAY", 2)
            t:SetSize(btn, btn)
            t:SetPoint("RIGHT", W, "TOPLEFT", x, mid)
            t:SetVertexColor(c.pctCol[1], c.pctCol[2], c.pctCol[3], c.pctCol[4])
            local hit = Hit(true)
            hit:SetPoint("CENTER", t, "CENTER", 0, 0)
            hit:SetSize(btn + 6, titleH)
            hit:SetFrameLevel(W.header:GetFrameLevel() + 2)   -- over the drag area
            hit.onClick = function(button) if button == "LeftButton" then onClick() end end
            x = x - btn - 2
        end
        Button(NEXT_TEX, function() if first then SkipStep(first) end end)
        local count = FLText(c.body, c.head, c.pctCol[1], c.pctCol[2], c.pctCol[3], c.pctCol[4])
        count:SetWordWrap(false)
        count:SetWidth(0)
        count:SetText(minIndex .. "/" .. lastIndex)
        count:SetPoint("RIGHT", W, "TOPLEFT", x, mid)
        x = x - (count:GetStringWidth() or 30) - 2
        Button(PREV_TEX, function() if first then BackStep(first) end end)
    end
    local lvl = FLText(c.body, c.head, c.accent[1], c.accent[2], c.accent[3], c.accent[4])
    lvl:SetWordWrap(false)
    lvl:SetWidth(0)
    lvl:SetText(levels or "")
    local lvlW = levels and ((lvl:GetStringWidth() or 0) + 5) or 0
    local name = FLText(c.bold, c.zone, c.zoneCol[1], c.zoneCol[2], c.zoneCol[3], c.zoneCol[4])
    name:SetWordWrap(false)
    name:SetText(zone)
    name:SetWidth(math.max(20, math.min((name:GetStringWidth() or 0) + 2, x - PADX - COLLAPSE_L - lvlW - 6)))
    name:SetPoint("LEFT", W, "TOPLEFT", PADX + COLLAPSE_L, mid)
    W.collapseAnchorFs = name   -- the switch centres on this title
    lvl:SetPoint("LEFT", name, "RIGHT", 5, 0)
    local y = -1 - titleH - 1 - 5

    -- Current steps: tinted, an edge on the left, a line per instruction /
    -- note / objective with its icon. A click skips the step, a right-click
    -- goes back one; steps leaving and coming back animate.
    local iconW = math.floor(c.cur * 1.1 + 0.5)
    local function Model(step)
        local m = { index = step.index, lines = {} }
        for _, el in ipairs(step.elements or {}) do
            local t = el.text and el.text:GetText()
            if el:IsShown() and el:GetAlpha() > 0 and type(t) == "string" and not IsSecret(t) and t ~= "" and t ~= " " then
                local icon = el.icon and el.icon.IsShown and el.icon:IsShown() and el.icon:GetText()
                if type(icon) ~= "string" or IsSecret(icon) or icon == "" then icon = nil end
                local cur, max = Count(t)
                if not cur then
                    m.lines[#m.lines + 1] = { text = t, icon = icon }
                elseif c.objectives then
                    m.lines[#m.lines + 1] = { text = ObjLabel(t), icon = icon,
                        cur = cur, max = max, finished = cur >= max or (el.button and el.button:GetChecked() and true) or false }
                end
            end
        end
        return m
    end
    local models = {}
    for _, step in ipairs(current) do models[step.index] = Model(step) end
    for _, e in ipairs(Transitions(current, models, minIndex, "COMPACT")) do
        local m = e.model
        local st = AnimState(e, width)
        local top = y
        y = y - 5
        local lead = true
        for _, line in ipairs(m.lines) do
            local main = lead and not line.cur
            local size = main and c.cur or c.obj
            local col = main and c.current or c.muted
            local tx = PADX + 4 + st.dx
            if line.icon then
                local ic = FLText(c.body, size, 1, 1, 1)
                ic:SetWordWrap(false)
                ic:SetWidth(iconW)
                ic:SetText(SmallIcons(line.icon, size))
                ic:SetPoint("TOPLEFT", W, "TOPLEFT", tx, y)
                ic:SetAlpha(st.alpha)
            end
            tx = tx + iconW + 4
            local right = width - PADX - 4 + st.dx - (st.tick > 0 and 24 or 0)   -- room for the tick
            local countW = 0
            if line.cur then
                local cnt = FLText(c.body, c.obj, c.muted[1], c.muted[2], c.muted[3], c.muted[4])
                cnt:SetWordWrap(false)
                cnt:SetWidth(0)
                cnt:SetText(line.cur .. "/" .. line.max)
                cnt:SetPoint("TOPRIGHT", W, "TOPLEFT", right, y)
                cnt:SetAlpha(st.alpha)
                countW = (cnt:GetStringWidth() or 20) + 6
            end
            local fs = FLText(main and c.semi or c.body, size, col[1], col[2], col[3], col[4])
            fs:SetWidth(math.max(20, right - tx - countW))
            fs:SetText(SmallIcons(EnemyColor(line.text), size))
            fs:SetPoint("TOPLEFT", W, "TOPLEFT", tx, y)
            fs:SetAlpha(st.alpha)
            y = y - (fs:GetStringHeight() or size) - 3
            if line.cur then
                local bw = right - tx
                Fill("ARTWORK", 0, tx, y, bw, 3, c.track, st.alpha)
                local done = line.finished and c.done or c.accent
                Fill("ARTWORK", 1, tx, y, bw * (line.finished and 1 or line.cur / line.max), 3, done, st.alpha)
                y = y - 3 - 4
            end
            lead = false
        end
        if lead then y = y - c.cur end   -- a step with nothing to show still takes a line
        y = y - 5
        local full = top - y
        local h = math.max(2, math.floor(full * (1 - st.fold) + 0.5))
        local panelA = e.enter and st.alpha or (e.anim and (e.skipped and st.alpha or (1 - st.fold)) or 1)
        Fill("BACKGROUND", 3, 4 + st.dx, top, width - 8, h, c.stepCol, c.cardA * panelA)
        Fill("BACKGROUND", 4, 4 + st.dx, top, 2, h, c.stepCol, panelA)
        Overlay(c, st, 4 + st.dx, top, width - 8, h, top - math.min(full, h) / 2, 4)
        if not e.anim then
            local hit = Hit(true)
            hit:SetPoint("TOPLEFT", W, "TOPLEFT", 4, top)
            hit:SetSize(width - 8, full)
            hit.onClick = function(button)
                if button == "LeftButton" then SkipStep(e.frame)
                elseif button == "RightButton" then BackStep(e.frame) end
            end
        end
        y = top - h - math.floor(3 * (1 - st.fold) + 0.5)
    end
    Animate()

    -- The next steps: icon and text (and the number, Show List Numbers),
    -- fading the further ahead. The mouse wheel moves the list forward.
    y = y - 3
    if R.shownFor ~= maxIndex then R.shownFor, R.offset = maxIndex, 0 end
    local count = db.rxpUpcoming or 8
    R.offset = math.max(0, math.min(R.offset or 0, math.max(0, #rows - count)))
    local fade = db.rxpFade ~= false
    for i = 1 + R.offset, math.min(#rows, R.offset + count) do
        local row = rows[i].row
        local a = fade and math.max(c.fadeMin, 1 - (i - 1 - R.offset) * c.fadeStep) or 1
        local tx = PADX + 4
        if c.listNums then
            local num = FLText(c.body, c.num, c.numCol_[1], c.numCol_[2], c.numCol_[3], c.numCol_[4])
            num:SetWordWrap(false)
            num:SetWidth(0)
            num:SetText(row.index)
            num:SetPoint("TOPLEFT", W, "TOPLEFT", tx, y - 1)
            num:SetAlpha(a)
            tx = tx + math.max(c.numCol, (num:GetStringWidth() or 0) + 4)
        end
        if rows[i].icon then
            local ic = FLText(c.body, c.text, 1, 1, 1)
            ic:SetWordWrap(false)
            ic:SetWidth(iconW)
            ic:SetText(SmallIcons(rows[i].icon, c.text))
            ic:SetPoint("TOPLEFT", W, "TOPLEFT", tx, y)
            ic:SetAlpha(a)
        end
        tx = tx + iconW + 4
        local fs = FLText(c.body, c.text, c.textCol[1], c.textCol[2], c.textCol[3], c.textCol[4])
        fs:SetWidth(math.max(20, width - PADX - 4 - tx))
        fs:SetText(Plain(rows[i].line))
        fs:SetPoint("TOPLEFT", W, "TOPLEFT", tx, y)
        fs:SetAlpha(a)
        local h = fs:GetStringHeight() or c.text
        local hit = Hit()
        hit:SetPoint("TOPLEFT", W, "TOPLEFT", 4, y + 1)
        hit:SetSize(width - 8, h + 2)
        hit.onClick = function(button)
            local down = row:GetScript("OnMouseDown")   -- RestedXP's row menu
            if button == "RightButton" and down then down(row, "RightButton") end
        end
        hit.onDouble = function(button)
            local go = rxp.bottomMenu and rxp.bottomMenu[1] and rxp.bottomMenu[1].func
            if button == "LeftButton" and go then go(row.index) end   -- "Go to step"
        end
        y = y - h - 5
    end

    -- The guide's progress: a thin bar along the bottom.
    y = y - 3
    local pct = (minIndex and lastIndex > 0) and math.min(1, minIndex / lastIndex) or 0
    Fill("ARTWORK", 0, 1, y, width - 2, 3, c.track)
    Fill("ARTWORK", 1, 1, y, (width - 2) * pct, 3, c.accent, 1)
    y = y - 3 - 1

    -- Hide what this pass didn't use.
    for kind, pool in pairs(pools) do
        for i = (used[kind] or 0) + 1, #pool do
            local item = pool[i]
            if kind == "bar" then item.bg:Hide(); item.fill:Hide()
            else item:Hide() end
        end
    end
    R.SetBodyHeight(-y)
    R.AttachTargets()
end

-- =====================================================================
-- Zygor-style: a dark window with a tab, step buttons and goal lines
-- =====================================================================
-- The title bar (the zone, centred), a tab with the level range, a step
-- row ("← 14 →", the guide's % on the right), then the current steps'
-- lines: each with RestedXP's icon, a goal still to do on a dark red band,
-- a finished one greyed, notes smaller and indented, a separator between
-- steps, and the guide's progress as a green bar along the bottom. Its
-- look is its own copy of the APPEARANCE settings (prefix "rxpZg").
function R.RenderZygor()
    local rxp = _G.RXPFrame
    local c = Cfg("rxpZg")
    if not W then BuildWindow() end
    if not rxp:IsShown() then W:Hide(); return end
    HideRXP(true)
    W:Show()
    W:SetScript("OnUpdate", nil)
    -- The other layouts' own pieces stay out of this one.
    W.name:Hide(); W.progress:Hide(); W.percent:Hide(); W.pill:Hide(); W.pillText:Hide()
    W.headBg:Hide(); W.band:Hide(); W.bandEdge:Hide()
    for _, piece in pairs(W.fl or {}) do piece:Hide() end
    W:SetScale(rxp:GetScale() or 1)
    W:SetFrameStrata(rxp:GetFrameStrata())
    W:SetFrameLevel(rxp:GetFrameLevel() + 20)
    W:ClearAllPoints()
    W:SetPoint("TOPLEFT", rxp, "TOPLEFT", 0, 0)
    local width = c.width
    W:SetWidth(width)
    FitRXPWidth(width)
    W:SetBackdropColor(0.1, 0.1, 0.11, c.backdrop)
    W:SetBackdropBorderColor(c.border[1], c.border[2], c.border[3], c.border[4])

    used = {}
    local PADX = 10
    local function Fill(layer, sub, x, top, w, h, col, alpha)
        local t = Tex()
        t:SetTexture(WHITE)
        t:SetDrawLayer(layer, sub)
        t:SetPoint("TOPLEFT", W, "TOPLEFT", x, top)
        t:SetSize(math.max(1, w), math.max(1, h))
        t:SetVertexColor(col[1], col[2], col[3], (alpha or 1) * (col[4] or 1))
        return t
    end

    -- The steps: the current ones and the guide's last step.
    local current = {}
    for _, step in pairs(rxp.CurrentStepFrame and rxp.CurrentStepFrame.framePool or {}) do
        if step:IsShown() and step.step and step.index then current[#current + 1] = step end
    end
    table.sort(current, function(a, b) return a.index < b.index end)
    local minIndex = current[1] and current[1].index
    local lastIndex = 0
    for _, row in pairs(rxp.ScrollChild and rxp.ScrollChild.framePool or {}) do
        if row:IsShown() and row.index and row.index > lastIndex then lastIndex = row.index end
    end
    local nameText = rxp.GuideName and rxp.GuideName.text and rxp.GuideName.text:GetText()
    if type(nameText) ~= "string" or IsSecret(nameText) then nameText = "" end
    nameText = nameText:match("^[^\n]*") or ""
    local levels, zone = nameText:match("^(%d+%s*%-%s*%d+)%s+(.+)$")
    zone = zone or nameText

    -- Title bar: the zone, bold, centred. Dragging it moves the window.
    local titleH = c.zone + 16
    Fill("BACKGROUND", 1, 1, -1, width - 2, titleH, c.headBg)
    local title = FLText(c.bold, c.zone, c.zoneCol[1], c.zoneCol[2], c.zoneCol[3], c.zoneCol[4])
    title:SetWordWrap(false)
    title:SetWidth(width - 2 * PADX - COLLAPSE_L)
    title:SetJustifyH("CENTER")
    title:SetText(zone)
    title:SetPoint("CENTER", W, "TOP", COLLAPSE_L / 2, -1 - titleH / 2)
    W.collapseAnchorFs = nil   -- centred title: the switch parks top-left
    W.header:ClearAllPoints()
    W.header:SetPoint("TOPLEFT", W, "TOPLEFT", 0, 0)
    W.header:SetPoint("TOPRIGHT", W, "TOPRIGHT", 0, 0)
    W.header:SetHeight(titleH + 1)
    local y = -1 - titleH

    -- The tab: a gold "XP" and the level range (or the zone again).
    local tabH = c.head + 12
    y = y - 2
    local badge = FLText(c.bold, math.max(8, c.head - 2), 0.98, 0.78, 0.22)
    badge:SetWordWrap(false); badge:SetWidth(0); badge:SetText("XP")
    local tabText = FLText(c.body, c.head, c.textCol[1], c.textCol[2], c.textCol[3], c.textCol[4])
    tabText:SetWordWrap(false)
    tabText:SetText(levels and ("Level " .. levels) or zone)
    local tabW = math.min(width - 2 * PADX, (badge:GetStringWidth() or 14) + (tabText:GetStringWidth() or 60) + 26)
    tabText:SetWidth(tabW - (badge:GetStringWidth() or 14) - 22)
    Fill("BACKGROUND", 1, PADX, y, tabW, tabH, c.track)
    badge:SetPoint("LEFT", W, "TOPLEFT", PADX + 8, y - tabH / 2)
    tabText:SetPoint("LEFT", badge, "RIGHT", 5, 0)
    y = y - tabH

    -- The step row: "← 14 →" (← back a step, → skip one) and the guide's %.
    local first = current[1]
    if c.stepLabel and minIndex then
        local navH = c.num + 12
        Fill("BACKGROUND", 1, 1, y, width - 2, navH, c.track)
        local mid = y - navH / 2
        local btn = math.floor(c.num * 1.2 + 0.5)
        local function Button(tex, x, onClick)
            local t = Tex()
            t:SetTexture(tex)
            t:SetDrawLayer("OVERLAY", 2)
            t:SetSize(btn, btn)
            t:SetPoint("CENTER", W, "TOPLEFT", x, mid)
            t:SetVertexColor(c.pctCol[1], c.pctCol[2], c.pctCol[3], c.pctCol[4])
            local hit = Hit(true)
            hit:SetPoint("CENTER", t, "CENTER", 0, 0)
            hit:SetSize(btn + 10, navH)
            hit.onClick = function(button) if button == "LeftButton" then onClick() end end
        end
        local numX = PADX + btn + 22
        Button(PREV_TEX, PADX + btn / 2, function() if first then BackStep(first) end end)
        local num = FLText(c.body, c.num, c.pctCol[1], c.pctCol[2], c.pctCol[3], c.pctCol[4])
        num:SetWordWrap(false)
        num:SetWidth(0)
        num:SetText(minIndex)
        num:SetPoint("CENTER", W, "TOPLEFT", numX, mid)
        Button(NEXT_TEX, numX + 22 + btn / 2, function() if first then SkipStep(first) end end)
        if lastIndex > 0 then
            local pct = FLText(c.body, c.head, c.muted[1], c.muted[2], c.muted[3], c.muted[4])
            pct:SetWordWrap(false)
            pct:SetWidth(0)
            pct:SetText(math.floor(math.min(1, minIndex / lastIndex) * 100 + 0.5) .. "%")
            pct:SetPoint("RIGHT", W, "TOPLEFT", width - PADX, mid)
        end
        y = y - navH
    end

    -- The current steps' lines. A goal still to do (a box to tick, an
    -- objective not reached) on the red band; a finished one greyed; notes
    -- (no icon, nothing to tick) smaller and indented. A click on a step
    -- skips it, a right-click goes back one; steps leaving and coming back
    -- animate.
    local iconW = math.floor(c.cur * 1.1 + 0.5)
    local function Model(step)
        local m = { index = step.index, lines = {} }
        for _, el in ipairs(step.elements or {}) do
            local t = el.text and el.text:GetText()
            if el:IsShown() and el:GetAlpha() > 0 and type(t) == "string" and not IsSecret(t) and t ~= "" and t ~= " " then
                local icon = el.icon and el.icon.IsShown and el.icon:IsShown() and el.icon:GetText()
                if type(icon) ~= "string" or IsSecret(icon) or icon == "" then icon = nil end
                local cur, max = Count(t)
                if not (cur and not c.objectives) then
                    local box = el.button and el.button:IsShown()
                    local ticked = box and el.button:GetChecked() and true or false
                    local done = ticked or (cur and cur >= max) or false
                    m.lines[#m.lines + 1] = { text = t, icon = icon, done = done,
                        goal = (box or cur) and not done or false, note = not icon and not box and not cur }
                end
            end
        end
        return m
    end
    local models = {}
    for _, step in ipairs(current) do models[step.index] = Model(step) end
    local cards = Transitions(current, models, minIndex, "ZYGOR")
    for n, e in ipairs(cards) do
        local m = e.model
        local st = AnimState(e, width)
        local top = y
        if n > 1 then Fill("ARTWORK", 0, PADX, y, width - 2 * PADX, 1, c.line, st.alpha) end
        for _, line in ipairs(m.lines) do
            local size = line.note and c.obj or c.cur
            local col = line.done and { c.muted[1] * 0.8, c.muted[2] * 0.8, c.muted[3] * 0.8, c.muted[4] } or (line.note and c.muted or c.current)
            local tx = PADX + (line.note and iconW + 4 or 0) + st.dx
            if line.icon then
                local ic = FLText(c.body, size, 1, 1, 1)
                ic:SetWordWrap(false)
                ic:SetWidth(iconW)
                ic:SetText(SmallIcons(line.icon, size))
                ic:SetPoint("TOPLEFT", W, "TOPLEFT", tx, y - 4)
                ic:SetAlpha(st.alpha * (line.done and 0.6 or 1))
                tx = tx + iconW + 4
            elseif not line.note then
                tx = tx + iconW + 4
            end
            local fs = FLText(c.body, size, col[1], col[2], col[3], col[4])
            fs:SetWidth(math.max(20, width - PADX - tx + st.dx - (st.tick > 0 and 24 or 0)))
            fs:SetText(SmallIcons(EnemyColor(line.text), size))
            fs:SetPoint("TOPLEFT", W, "TOPLEFT", tx, y - 4)
            fs:SetAlpha(st.alpha)
            local h = (fs:GetStringHeight() or size) + 8
            if line.goal then
                Fill("BACKGROUND", 3, 1 + st.dx, y, width - 2, h, c.stepCol, c.cardA * st.alpha)
            end
            y = y - h
        end
        if #m.lines == 0 then y = y - c.cur - 8 end   -- a step with nothing to show still takes a line
        local full = top - y
        local h = math.max(2, math.floor(full * (1 - st.fold) + 0.5))
        Overlay(c, st, 1 + st.dx, top, width - 2, h, top - math.min(full, h) / 2, PADX - 1)
        if not e.anim then
            local hit = Hit(true)
            hit:SetPoint("TOPLEFT", W, "TOPLEFT", 1, top)
            hit:SetSize(width - 2, full)
            hit.onClick = function(button)
                if button == "LeftButton" then SkipStep(e.frame)
                elseif button == "RightButton" then BackStep(e.frame) end
            end
        end
        y = top - h
    end
    Animate()

    -- The guide's progress: a green bar along the bottom.
    y = y - 8
    local pct = (minIndex and lastIndex > 0) and math.min(1, minIndex / lastIndex) or 0
    Fill("ARTWORK", 0, PADX, y, width - 2 * PADX, 7, c.track)
    Fill("ARTWORK", 1, PADX, y, math.max(3, (width - 2 * PADX) * pct), 7, c.accent, 1)
    y = y - 7 - 8

    -- Hide what this pass didn't use.
    for kind, pool in pairs(pools) do
        for i = (used[kind] or 0) + 1, #pool do
            local item = pool[i]
            if kind == "bar" then item.bg:Hide(); item.fill:Hide()
            else item:Hide() end
        end
    end
    R.SetBodyHeight(-y)
    R.AttachTargets()
end

-- =====================================================================
-- 8-Bit: a pixel-art quest log (design handoff "8-Bit Quest Log")
-- =====================================================================
-- A stepped white pixel border with notched corners around a dark window,
-- CRT scanlines over it. Header: the zone in capitals, a green "LV1-6"
-- chip, the % in yellow, a 20-block bar (the first two red), "QUEST 9/52".
-- Then the step before the current one (struck through), the current steps
-- on yellow-bordered cards with a ▶ cursor, "QUEST 9", the step text and
-- objectives as pips, then the next steps, fading. Footer: "◀ B" (back a
-- step) and "A ▶" (skip one). Pixel fonts only (Silkscreen and VT323: the
-- font settings don't apply), and no animations: it changes instantly.
-- Click a listed step to go to it, right-click it for RestedXP's menu;
-- click a current card to skip it, right-click to go back a step.
local BIT_FADE = { 1, 0.85, 0.72, 0.6, 0.5, 0.42, 0.36, 0.32 }   -- by distance from the current step
-- The handoff's sizes (a 336px window) drawn at 75%: about as big as the
-- other layouts (Compact 250, Zygor-style 280) before RestedXP's scale.
local BIT_SCALE = 0.75
local TRI = "Interface\\AddOns\\" .. ADDON .. "\\Textures\\rxp-tri.png"

-- Action words at the start of a sentence, in the verb colour.
local VERBS = {
    "Talk to", "Speak to", "Accept", "Turn in", "Kill", "Loot", "Cast", "Use", "Go to", "Fly to",
    "Run to", "Travel to", "Collect", "Complete", "Deliver", "Train", "Learn", "Buy", "Sell", "Vendor",
    "Repair", "Hearth", "Grind", "Set your Hearthstone", "Open", "Click", "Equip", "Discover",
    "Enter", "Pick up", "Destroy", "Wait", "Follow", "Escort", "Target", "Interact with", "Die",
}
local function Verbs(text, hex)
    if type(text) ~= "string" or IsSecret(text) then return text end
    for _, v in ipairs(VERBS) do
        local pat = "(" .. v:gsub(" ", "%%s") .. ")%f[^%a]"
        -- hex is AARRGGBB (8-digit): the verb colour's opacity included.
        text = text:gsub("^(%s*)" .. pat, "%1|c" .. hex .. "%2|r")
        text = text:gsub("([%.!]%s+)" .. pat, "%1|c" .. hex .. "%2|r")
    end
    return text
end

local function Mix(col, to, k)
    return { col[1] + (to - col[1]) * k, col[2] + (to - col[2]) * k, col[3] + (to - col[3]) * k, col[4] }
end
local function Scale(col, k)
    return { math.min(1, col[1] * k), math.min(1, col[2] * k), math.min(1, col[3] * k), col[4] }
end

function R.RenderBit()
    local rxp = _G.RXPFrame
    local c = Cfg("rxpBt")
    if not W then BuildWindow() end
    if not rxp:IsShown() then W:Hide(); return end
    HideRXP(true)
    W:Show()
    W:SetScript("OnUpdate", nil)
    -- The other layouts' own pieces stay out of this one.
    W.name:Hide(); W.progress:Hide(); W.percent:Hide(); W.pill:Hide(); W.pillText:Hide()
    W.headBg:Hide(); W.band:Hide(); W.bandEdge:Hide()
    for _, piece in pairs(W.fl or {}) do piece:Hide() end
    W:SetScale((rxp:GetScale() or 1) * BIT_SCALE)   -- the handoff's px, at the other layouts' size
    W:SetFrameStrata(rxp:GetFrameStrata())
    W:SetFrameLevel(rxp:GetFrameLevel() + 20)
    W:ClearAllPoints()
    W:SetPoint("TOPLEFT", rxp, "TOPLEFT", 0, 0)
    -- The window is the content plus 8px round it (the border and the dark
    -- ring inside it): all drawn here, no backdrop.
    local width = c.width
    local x0, right = 8, 8 + width
    W:SetWidth(width + 16)
    FitRXPWidth((width + 16) * BIT_SCALE)   -- the window is drawn at 75%
    W:SetBackdropColor(0, 0, 0, 0)
    W:SetBackdropBorderColor(0, 0, 0, 0)

    used = {}
    local db = DB()
    local function Fill(layer, sub, x, top, w, h, col, alpha)
        local t = Tex()
        t:SetTexture(WHITE)
        t:SetDrawLayer(layer, sub)
        t:SetPoint("TOPLEFT", W, "TOPLEFT", x, top)
        t:SetSize(math.max(1, w), math.max(1, h))
        t:SetVertexColor(col[1], col[2], col[3], (alpha or 1) * (col[4] or 1))
        return t
    end
    -- Pixel text: no outline, no shadow.
    local function Pix(font, size, col, alpha)
        local fs = Text(font, size, col[1], col[2], col[3], col[4])
        ns.ApplyFont(fs, font, size, "NONE")
        fs:SetShadowOffset(0, 0)
        fs:SetShadowColor(0, 0, 0, 0)
        fs:SetAlpha(alpha or 1)
        return fs
    end
    -- The ▶ / ◀ (a pixel triangle), its left edge at x, centred on mid.
    local function Tri(x, mid, size, col, alpha, left)
        local t = Tex()
        t:SetTexture(TRI, nil, nil, "NEAREST")
        t:SetDrawLayer("OVERLAY", 1)
        t:SetSize(size, size)
        if left then t:SetTexCoord(1, 0, 0, 1) end
        t:SetPoint("LEFT", W, "TOPLEFT", x, mid)
        t:SetVertexColor(col[1], col[2], col[3], (alpha or 1) * (col[4] or 1))
        return t
    end
    local function TriSize(size) return math.max(8, 8 * math.floor(size * 0.7 / 8 + 0.5)) end
    local verbHex = ("%02x%02x%02x%02x"):format(math.floor((c.verb[4] or 1) * 255 + 0.5),
        math.floor(c.verb[1] * 255 + 0.5),
        math.floor(c.verb[2] * 255 + 0.5), math.floor(c.verb[3] * 255 + 0.5))
    -- RestedXP's names in the handoff's colours, no icons, verbs in yellow.
    local function Colored(text)
        text = EnemyColor(text)
        if type(text) ~= "string" or IsSecret(text) then return text end
        text = text:gsub("|T.-|t", ""):gsub("^%s+", "")
        return Verbs(text, verbHex)
    end

    -- The steps: the current ones, the one before, the list and its last step.
    local current = {}
    for _, step in pairs(rxp.CurrentStepFrame and rxp.CurrentStepFrame.framePool or {}) do
        if step:IsShown() and step.step and step.index then current[#current + 1] = step end
    end
    table.sort(current, function(a, b) return a.index < b.index end)
    local minIndex, maxIndex = nil, 0
    for _, step in ipairs(current) do
        maxIndex = math.max(maxIndex, step.index)
        minIndex = minIndex and math.min(minIndex, step.index) or step.index
    end
    local rows, doneRow, lastIndex = {}, nil, 0
    for _, row in pairs(rxp.ScrollChild and rxp.ScrollChild.framePool or {}) do
        if row:IsShown() and row.index then
            if row.index > lastIndex then lastIndex = row.index end
            local line = row.text and RowLine(row.text:GetText())
            if line and row.index > maxIndex then rows[#rows + 1] = { row = row, line = line } end
            if line and minIndex and row.index == minIndex - 1 then doneRow = { row = row, line = line } end
        end
    end
    table.sort(rows, function(a, b) return a.row.index < b.row.index end)
    local nameText = rxp.GuideName and rxp.GuideName.text and rxp.GuideName.text:GetText()
    if type(nameText) ~= "string" or IsSecret(nameText) then nameText = "" end
    nameText = nameText:match("^[^\n]*") or ""
    local levels, zone = nameText:match("^(%d+%s*%-%s*%d+)%s+(.+)$")
    zone = zone or nameText
    local pct = (minIndex and lastIndex > 0) and math.floor(math.min(1, minIndex / lastIndex) * 100 + 0.5) or 0

    -- Header: padding 12 / 14, the title row, the block bar, the counter.
    local y = -8
    local headTop = y
    y = y - 12
    local zoneFs = Pix(c.bold, c.zone, c.zoneCol)
    zoneFs:SetWordWrap(false)
    zoneFs:SetText(zone:upper())
    local pctFs = Pix(c.semi, c.zone, c.accent)
    pctFs:SetWordWrap(false)
    pctFs:SetWidth(0)
    pctFs:SetText(pct .. "%")
    local chipFs, chipW, chipH = nil, 0, 0
    if levels then
        chipFs = Pix(c.semi, c.head, c.bg)
        chipFs:SetWordWrap(false)
        chipFs:SetWidth(0)
        chipFs:SetText("LV" .. levels:gsub("%s", ""))
        chipW, chipH = (chipFs:GetStringWidth() or 20) + 10, (chipFs:GetStringHeight() or c.head) + 4
    end
    local rowH = math.max(zoneFs:GetStringHeight() or c.zone, pctFs:GetStringHeight() or c.zone, chipH)
    local mid = y - rowH / 2
    local zoneW = math.max(20, math.min((zoneFs:GetStringWidth() or 0) + 2,
        width - 28 - COLLAPSE_L - (pctFs:GetStringWidth() or 30) - 8 - (levels and chipW + 8 or 0)))
    zoneFs:SetWidth(zoneW)
    zoneFs:SetPoint("LEFT", W, "TOPLEFT", x0 + 14 + COLLAPSE_L, mid)
    W.collapseAnchorFs = zoneFs   -- the switch centres on this title
    if chipFs then
        local cx = x0 + 14 + COLLAPSE_L + zoneW + 8
        Fill("ARTWORK", 1, cx, mid + chipH / 2, chipW, chipH, c.done)
        chipFs:SetPoint("CENTER", W, "TOPLEFT", cx + chipW / 2, mid)
    end
    pctFs:SetPoint("RIGHT", W, "TOPLEFT", right - 14, mid)
    y = y - rowH - 8
    -- 20 blocks, one per 5%: the first two red ("low HP"), the rest yellow;
    -- empty ones the header's colour (empty slots).
    local filled = math.floor(pct / 5 + 0.5)
    local segW = (width - 28 - 38) / 20
    for i = 0, 19 do
        local col = i < filled and (i < 2 and c.stepCol or c.accent) or c.headBg
        Fill("ARTWORK", 1, x0 + 14 + i * (segW + 2), y, segW, 8, col, 1)
    end
    y = y - 8 - 8
    local counter = Pix(c.body, c.obj, c.muted)
    counter:SetWordWrap(false)
    counter:SetWidth(0)
    counter:SetText("QUEST " .. (minIndex or "-") .. "/" .. (lastIndex > 0 and lastIndex or "-"))
    counter:SetPoint("TOPLEFT", W, "TOPLEFT", x0 + 14, y)
    y = y - (counter:GetStringHeight() or c.obj) - 12
    Fill("BACKGROUND", 1, x0, headTop, width, headTop - y, c.headBg)
    Fill("ARTWORK", 0, x0, y, width, 4, c.border)
    y = y - 4
    -- Dragging the header moves the window.
    W.header:ClearAllPoints()
    W.header:SetPoint("TOPLEFT", W, "TOPLEFT", 0, 0)
    W.header:SetPoint("TOPRIGHT", W, "TOPRIGHT", 0, 0)
    W.header:SetHeight(-y)

    -- A listed step: its number and text, a click goes to it, hovering
    -- lights its row.
    local function Row(r, a, done)
        local row = r.row
        local top = y
        y = y - 4
        local tx = x0 + 12
        if c.listNums then
            local n = Pix(c.body, c.num, c.numCol_, a)
            n:SetWordWrap(false)
            n:SetWidth(0)
            n:SetText(row.index)
            n:SetPoint("TOPLEFT", W, "TOPLEFT", tx, y)
            tx = tx + c.numCol
        end
        local fs = Pix(c.body, c.text, c.textCol, a)
        fs:SetSpacing(1)
        fs:SetWidth(math.max(20, right - 14 - tx))
        fs:SetText(Colored(r.line))
        fs:SetPoint("TOPLEFT", W, "TOPLEFT", tx, y)
        local h = fs:GetStringHeight() or c.text
        if done then
            -- Struck through, line by line.
            local lh = c.text + 1
            local lines = math.max(1, math.floor(h / lh + 0.5))
            local thick = math.max(1, math.floor(c.text / 9))
            for k = 1, lines do
                local w = lines == 1 and math.min((fs:GetStringWidth() or 0), fs:GetWidth()) or fs:GetWidth()
                Fill("OVERLAY", 2, tx, y - (k - 1) * lh - math.floor(lh * 0.55), w, thick, c.textCol, a)
            end
        end
        y = y - h - 4
        local hover = Fill("BACKGROUND", 2, x0, top, width, top - y, c.track)
        local hit = Hit(true)
        hit:SetPoint("TOPLEFT", W, "TOPLEFT", x0, top)
        hit:SetSize(width, top - y)
        hit.hl:SetColorTexture(0, 0, 0, 0)
        hover:SetShown(hit:IsMouseOver())
        hit.onEnter = function() hover:Show() end
        hit.onLeave = function() hover:Hide() end
        hit.onClick = function(button)
            if button == "LeftButton" then
                local go = rxp.bottomMenu and rxp.bottomMenu[1] and rxp.bottomMenu[1].func
                if go then go(row.index) end   -- "Go to step"
            else
                local down = row:GetScript("OnMouseDown")   -- RestedXP's row menu
                if down then down(row, "RightButton") end
            end
        end
    end

    -- A current step: a card with a 3px yellow border (notched corners),
    -- the ▶ cursor, "QUEST 9", the text and the objectives as pips.
    local function Card(step)
        local cardTop = y - 4
        local cx, cw = x0 + 8, width - 16
        local tx = cx + 8 + 30
        local tw = cw - 8 - 12 - 30
        local ty = cardTop - 10
        Tri(cx + 8, ty - math.floor(c.cur / 2 + 0.5), TriSize(c.cur), c.accent)
        local first = true
        local function Gap() if not first then ty = ty - 8 end first = false end
        if c.stepLabel then
            Gap()
            local label = Pix(c.semi, c.head, c.muted)
            label:SetWordWrap(false)
            label:SetWidth(0)
            label:SetText("QUEST " .. step.index)
            label:SetPoint("TOPLEFT", W, "TOPLEFT", tx, ty)
            ty = ty - (label:GetStringHeight() or c.head)
        end
        local texts, objectives = {}, {}
        for _, el in ipairs(step.elements or {}) do
            local t = el.text and el.text:GetText()
            if el:IsShown() and el:GetAlpha() > 0 and type(t) == "string" and not IsSecret(t) and t ~= "" and t ~= " " then
                local cur, max = Count(t)
                if not cur then
                    texts[#texts + 1] = t
                elseif c.objectives then
                    local ticked = el.button and el.button:GetChecked()
                    objectives[#objectives + 1] = { label = (ObjLabel(t):gsub("^%s*%-%s*", "")),
                        cur = ticked and max or cur, max = max }
                end
            end
        end
        for i, t in ipairs(texts) do
            if i == 1 then Gap() else ty = ty - 2 end
            local fs = Pix(c.body, c.cur, c.current)
            fs:SetSpacing(1)
            fs:SetWidth(tw)
            fs:SetText(Colored(t))
            fs:SetPoint("TOPLEFT", W, "TOPLEFT", tx, ty)
            ty = ty - (fs:GetStringHeight() or c.cur)
        end
        for _, o in ipairs(objectives) do
            -- One pip per item (up to 8; more share them), the label, the count.
            Gap()
            local rh = math.max(16, c.text)
            local m = ty - rh / 2
            local pips = math.min(o.max, 8)
            local full = o.max <= 8 and o.cur or math.floor(o.cur / o.max * 8)
            local px = tx
            for i = 1, pips do
                Fill("ARTWORK", 1, px, m + 8, 16, 16, c.border)
                Fill("ARTWORK", 2, px + 2, m + 6, 12, 12, i <= full and c.done or c.track, 1)
                px = px + 16 + 6
            end
            local count = Pix(c.body, c.text, c.done)
            count:SetWordWrap(false)
            count:SetWidth(0)
            count:SetText(o.cur .. "/" .. o.max)
            count:SetPoint("RIGHT", W, "TOPLEFT", tx + tw, m)
            local lx = px + 4
            local label = Pix(c.body, c.obj, c.textCol)
            label:SetWordWrap(false)
            label:SetWidth(math.max(10, tx + tw - (count:GetStringWidth() or 20) - 6 - lx))
            label:SetText(o.label)
            label:SetPoint("LEFT", W, "TOPLEFT", lx, m)
            ty = ty - rh
        end
        ty = math.min(ty, cardTop - 10 - c.cur)   -- at least the cursor's line
        local cardH = cardTop - ty + 12
        Fill("BACKGROUND", 2, cx, cardTop, cw, cardH, c.track)
        Fill("ARTWORK", 0, cx, cardTop + 3, cw, 3, c.accent, 1)
        Fill("ARTWORK", 0, cx, cardTop - cardH, cw, 3, c.accent, 1)
        Fill("ARTWORK", 0, cx - 3, cardTop, 3, cardH, c.accent, 1)
        Fill("ARTWORK", 0, cx + cw, cardTop, 3, cardH, c.accent, 1)
        local hit = Hit(true)
        hit:SetPoint("TOPLEFT", W, "TOPLEFT", cx, cardTop)
        hit:SetSize(cw, cardH)
        hit.hl:SetColorTexture(1, 1, 1, 0.04)
        hit.onClick = function(button)
            if button == "LeftButton" then SkipStep(step)
            elseif button == "RightButton" then BackStep(step) end
        end
        y = cardTop - cardH - 4
    end

    -- The list: the step before (struck through), the current steps, the
    -- next ones fading. The mouse wheel moves the list forward.
    y = y - 8
    if doneRow and c.showDone then Row(doneRow, 0.4, true) end
    for _, step in ipairs(current) do Card(step) end
    if R.shownFor ~= maxIndex then R.shownFor, R.offset = maxIndex, 0 end
    local count = db.rxpUpcoming or 6
    R.offset = math.max(0, math.min(R.offset or 0, math.max(0, #rows - count)))
    local fade = db.rxpFade ~= false
    for i = 1 + R.offset, math.min(#rows, R.offset + count) do
        Row(rows[i], fade and BIT_FADE[math.min(i - R.offset, 8)] or 0.9)
    end
    y = y - 8

    -- Footer: "◀ B" and "A ▶", bevelled; pressed, the bevel swaps and the
    -- label moves 1px down-right.
    local footTop = y
    Fill("ARTWORK", 0, x0, y, width, 4, c.border)
    y = y - 4 - 10
    local size = c.head + 2
    local bw = (width - 24 - 10) / 2
    local probe = Pix(c.semi, size, c.border)
    probe:SetText("B")
    local bh = math.floor((probe:GetStringHeight() or size) + 12 + 0.5)
    probe:Hide()
    local first = current[1]
    local function Button(bx, text, triFirst, bg, fg, onClick)
        local hoverCol, light, dark
        if bg == c.accent then
            hoverCol, light, dark = Mix(bg, 1, 0.22), Mix(bg, 1, 0.45), Scale(bg, 0.76)
        else
            hoverCol, light, dark = Scale(bg, 1.35), Scale(bg, 1.75), c.bg
        end
        local face = Fill("ARTWORK", 1, bx, y, bw, bh, bg, 1)
        local top = Fill("ARTWORK", 2, bx, y, bw - 3, 3, light, 1)
        local left = Fill("ARTWORK", 2, bx, y, 3, bh - 3, light, 1)
        local rgt = Fill("ARTWORK", 3, bx + bw - 3, y, 3, bh, dark, 1)
        local bot = Fill("ARTWORK", 3, bx, y - bh + 3, bw, 3, dark, 1)
        local fs = Pix(c.semi, size, fg)
        fs:SetWordWrap(false)
        fs:SetWidth(0)
        fs:SetText(text)
        local ts = TriSize(size)
        local gap = math.floor(size * 0.42 + 0.5)
        local total = (fs:GetStringWidth() or 8) + gap + ts
        local lx = bx + (bw - total) / 2
        local tri = Tri(0, 0, ts, fg, 1, triFirst)
        local mid = y - bh / 2
        local function Place(d)
            tri:ClearAllPoints()
            fs:ClearAllPoints()
            if triFirst then
                tri:SetPoint("LEFT", W, "TOPLEFT", lx + d, mid - d)
                fs:SetPoint("LEFT", W, "TOPLEFT", lx + ts + gap + d, mid - d)
            else
                fs:SetPoint("LEFT", W, "TOPLEFT", lx + d, mid - d)
                tri:SetPoint("LEFT", W, "TOPLEFT", lx + total - ts + d, mid - d)
            end
        end
        local function Press(on)
            local a, b = on and dark or light, on and light or dark
            top:SetVertexColor(a[1], a[2], a[3], a[4] or 1); left:SetVertexColor(a[1], a[2], a[3], a[4] or 1)
            rgt:SetVertexColor(b[1], b[2], b[3], b[4] or 1); bot:SetVertexColor(b[1], b[2], b[3], b[4] or 1)
            Place(on and 1 or 0)
        end
        Place(0)
        local hit = Hit(true)
        hit:SetPoint("TOPLEFT", W, "TOPLEFT", bx, y)
        hit:SetSize(bw, bh)
        hit.hl:SetColorTexture(0, 0, 0, 0)
        local function Face(over)
            local col = over and hoverCol or bg
            face:SetVertexColor(col[1], col[2], col[3], col[4] or 1)
        end
        Face(hit:IsMouseOver())
        hit.onEnter = function() Face(true) end
        hit.onLeave = function() Face(false); Press(false) end
        hit.onDown = function(button) if button == "LeftButton" then Press(true) end end
        hit.onUp = function() Press(false) end
        hit.onClick = function(button) if button == "LeftButton" and first then onClick(first) end end
    end
    Button(x0 + 12, "B", true, c.headBg, c.border, BackStep)
    Button(x0 + 12 + bw + 10, "A", false, c.accent, c.bg, SkipStep)
    y = y - bh - 12

    -- The frame: the dark window (4px past the content, not at the corners),
    -- the 4px border 4px out with its corners notched in, the scanlines over
    -- everything but the footer.
    local H = -8 - y
    Fill("BACKGROUND", 0, 4, -8, width + 8, H, c.bg, c.backdrop)
    Fill("BACKGROUND", 0, 8, -4, width, 4, c.bg, c.backdrop)
    Fill("BACKGROUND", 0, 8, -8 - H, width, 4, c.bg, c.backdrop)
    Fill("ARTWORK", 0, 8, 0, width, 4, c.border)
    Fill("ARTWORK", 0, 8, -12 - H, width, 4, c.border)
    Fill("ARTWORK", 0, 0, -8, 4, H, c.border)
    Fill("ARTWORK", 0, width + 12, -8, 4, H, c.border)
    Fill("ARTWORK", 0, 4, -4, 4, 4, c.border)
    Fill("ARTWORK", 0, width + 8, -4, 4, 4, c.border)
    Fill("ARTWORK", 0, 4, -8 - H, 4, 4, c.border)
    Fill("ARTWORK", 0, width + 8, -8 - H, 4, 4, c.border)
    if c.scan then
        for sy = -8, footTop + 1, -3 do
            Fill("OVERLAY", 7, x0, sy, width, 1, { 0, 0, 0 }, 0.28)
        end
    end

    -- Hide what this pass didn't use.
    for kind, pool in pairs(pools) do
        for i = (used[kind] or 0) + 1, #pool do
            local item = pool[i]
            if kind == "bar" then item.bg:Hide(); item.fill:Hide()
            else item:Hide() end
        end
    end
    R.SetBodyHeight(H + 16)
    R.AttachTargets()
end

-- Frameless, Rail, Compact, Zygor-style and 8-Bit: the Active Targets icons sit 10px under the window, lined up
-- with its left edge, and the Active Items icons 6px under those (or under
-- the window when there are no targets). The boxes are protected (their
-- icons are secure buttons), so they're placed on the screen, not anchored
-- to the window (that would lock the window in combat), and only out of
-- combat; they catch up when combat ends.
local attachPending

-- Place box `f` so its icon row's top-left lands at screen point (x, y);
-- (insetX, insetY) is where RestedXP draws the first icon inside the box.
local function PlaceBox(f, x, y, insetX, insetY)
    local k = 1 / f:GetEffectiveScale()
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x * k - insetX, y * k + insetY)
end

-- Where the objective icon boxes live. On (the default): glued under the
-- guide window, which is what PlaceBox below does on every render. Off: they
-- are left where the player put them -- RestedXP's own frames are already
-- movable, we simply stop overriding them, and we keep the position so it
-- survives a reload. The spot is an offset from the centre of the screen: a
-- point would drift with the UI scale.
local function BoxesFree()
    return DB().rxpBoxLock == false
end

local function SaveBoxPos()
    local p = {}
    for _, f in ipairs({ _G.RXPTargetFrame, _G.RXPItemFrame }) do
        if f then
            local x, y = f:GetCenter()
            local ux, uy = UIParent:GetCenter()
            if x and y and ux and uy then
                p[f:GetName()] = { math.floor(x - ux + 0.5), math.floor(y - uy + 0.5) }
            end
        end
    end
    if next(p) then DB().rxpBoxFree = p end
end

-- Our own drag, so moving the boxes never depends on RestedXP's "lock
-- frames" setting. OnMouseUp is hooked, not replaced, so whatever RestedXP
-- does on release still runs.
local function FreeBoxDrag(f)
    if f.euiFreeDrag then return end
    f.euiFreeDrag = true
    f:EnableMouse(true)
    f:SetMovable(true)
    f:SetScript("OnMouseDown", function(self)
        if InCombatLockdown() and self:IsProtected() then return end
        self.euiDragging = true
        self:StartMoving()
    end)
    f:HookScript("OnMouseUp", function(self)
        self.euiDragging = false
        self:StopMovingOrSizing()
        SaveBoxPos()
    end)
end

function R.AttachTargets()
    local layout = Layout()
    if not (W and W:IsShown() and Enabled() and (layout == "FRAMELESS" or layout == "RAIL"
        or layout == "COMPACT" or layout == "ZYGOR" or layout == "BIT8"
        or layout == "TIMELINE")) then return end
    if InCombatLockdown() then attachPending = true; return end
    attachPending = false
    if BoxesFree() then
        -- Free placement: hand the drag over and re-assert the saved spot,
        -- but never while the player has one under the mouse or the two would
        -- fight over it.
        local saved = DB().rxpBoxFree
        for _, f in ipairs({ _G.RXPTargetFrame, _G.RXPItemFrame }) do
            if f and f:IsShown() then
                FreeBoxDrag(f)
                local s = saved and saved[f:GetName()]
                if s and not f.euiDragging and not (InCombatLockdown() and f:IsProtected()) then
                    f:ClearAllPoints()
                    f:SetPoint("CENTER", UIParent, "CENTER", s[1] or 0, s[2] or 0)
                end
            end
        end
        return
    end
    local left, bottom = W:GetLeft(), W:GetBottom()
    if not (left and bottom) then return end
    local ws = W:GetEffectiveScale()
    local x, y = left * ws, bottom * ws - 10 * ws   -- screen pixels
    local targets, items = _G.RXPTargetFrame, _G.RXPItemFrame
    if targets and targets:IsShown() then
        -- First target icon: 6px in, 12px down inside the box.
        PlaceBox(targets, x, y, 6, 12)
        local ts = targets:GetEffectiveScale()
        local rows = math.max(1, math.floor(((targets:GetHeight() or 43) - 18) / 25 + 0.5))
        y = y - rows * 25 * ts - 6 * ws
    end
    if items then
        -- Its icons sit in the box's bottom row: 4px in, 16px down from the top.
        PlaceBox(items, x, y, 4, 16)
    end
end

do
    local ev = CreateFrame("Frame")
    ev:RegisterEvent("PLAYER_REGEN_ENABLED")
    ev:SetScript("OnEvent", function() if attachPending then R.AttachTargets() end end)
end

-- =====================================================================
-- ARROW: RestedXP's waypoint arrow in one of our styles (Arrow Style)
-- =====================================================================
-- Chevron: one chevron turning toward the waypoint, the yards and the
-- step's text centred under it. Card: a slim card with "22 · step" over a
-- big flat arrow, arrow and yards red over 100 yd, yellow from 100, green
-- under 30. Classic (TomTom-like): a shaded 3D arrow, green while you face
-- the waypoint, yellow side-on, red facing away. Zygor-style: a broad
-- green arrowhead, the step under it, then the yards (coloured by distance)
-- and the time to get there. "Layout's own": Chevron for Frameless and
-- Compact, Card for Timeline, Zygor-style for Zygor-style, RestedXP's arrow
-- for the RestedXP layout. It's RestedXP's own arrow underneath (it still points,
-- moves and hides itself).
local CHEVRON = "Interface\\AddOns\\" .. ADDON .. "\\Textures\\rxp-chevron.png"
local CHEVRON_EDGE = "Interface\\AddOns\\" .. ADDON .. "\\Textures\\rxp-chevron-outline.png"
local ARROW = "Interface\\AddOns\\" .. ADDON .. "\\Textures\\rxp-arrow.png"
local CLASSIC = "Interface\\AddOns\\" .. ADDON .. "\\Textures\\rxp-classic.png"
local ZYGOR = "Interface\\AddOns\\" .. ADDON .. "\\Textures\\rxp-zygor.png"
local RAILP = "Interface\\AddOns\\" .. ADDON .. "\\Textures\\rxp-rail.png"
local RAILC = "Interface\\AddOns\\" .. ADDON .. "\\Textures\\rxp-rail-compass.png"
local NEAR, CLOSE = 100, 30   -- Card: red above NEAR, yellow down to CLOSE, green below
local card

local function ArrowStyle()
    local layout = Layout()
    local function LayoutDefault()
        if layout == "DEFAULT" then return nil end   -- RestedXP's own
        if layout == "ZYGOR" then return "ZYGOR" end
        if layout == "RAIL" then return "RAIL" end   -- this theme's own pointer
        return layout == "TIMELINE" and "CARD" or "CHEVRON"
    end
    local s = DB().rxpArrowStyle
    if s == "WAYPOINT" then
        -- Without WaypointUI installed there is nothing external to drive:
        -- fall back to the layout's own arrow, never RestedXP's stock one.
        -- (WaypointUI arriving late re-hides the card through the ticker.)
        if ns.WaypointAvailable and ns.WaypointAvailable() then return "WAYPOINT" end
        return LayoutDefault()
    end
    if s == "CHEVRON" or s == "CARD" or s == "CLASSIC" or s == "ZYGOR" or s == "RAIL" or s == "RAILC" then return s end
    return LayoutDefault()
end

local function ArrowOn()
    return Enabled() and DB().rxpArrow ~= false and _G.RXPG_ARROW ~= nil and ArrowStyle() ~= nil
end

-- True while our arrow card draws the distance text itself (it labels the
-- unit from "Meters on the Arrow" directly): a yd->m rewrite of RestedXP's
-- own text must stand down, or the card would misparse it.
function R.ArrowOwnsText()
    return ArrowOn()
end

-- Card: far red, near yellow, close green.
local function DistColor(d)
    if d and d < CLOSE then return 0.37, 0.88, 0.48 end
    if d and d <= NEAR then return 1, 0.85, 0.29 end
    return 0.95, 0.32, 0.32
end

-- Classic: green facing the waypoint (the arrow's turn 0), yellow side-on,
-- red facing away.
local function HeadingColor(turn)
    local a = math.abs(((turn + math.pi) % (2 * math.pi)) - math.pi) / math.pi   -- 0 ahead .. 1 behind
    local g, y, r = { 0.24, 0.86, 0.35 }, { 0.95, 0.83, 0.25 }, { 0.92, 0.28, 0.24 }
    local from, to, k = g, y, a * 2
    if a > 0.5 then from, to, k = y, r, (a - 0.5) * 2 end
    return from[1] + (to[1] - from[1]) * k, from[2] + (to[2] - from[2]) * k, from[3] + (to[3] - from[3]) * k
end

-- Zygor-style: the time to the waypoint at the pace you've been closing in
-- on it (smoothed); nothing while you stand still or walk away. A jump in
-- the distance (a new waypoint) starts over.
local function ETA(d)
    local now, e = GetTime(), R.eta
    if not d then R.eta = nil; return nil end
    if not e then R.eta = { d = d, t = now, speed = 0 }; return nil end
    local dt = now - e.t
    if dt >= 0.5 then
        local v = (e.d - d) / dt
        if math.abs(v) > 60 then   -- faster than any mount: a new waypoint
            R.eta = { d = d, t = now, speed = 0 }
            return nil
        end
        e.speed = e.speed > 0 and (e.speed * 0.6 + v * 0.4) or v
        e.d, e.t = d, now
    end
    if e.speed > 1 then
        local sec = math.floor(d / e.speed + 0.5)
        -- Past the hour, the minutes-only format reads "61:01" or "137:04",
        -- which looks like a step number rather than a duration: carry the
        -- hours out ("1:01:01") the way any timer does.
        if sec >= 3600 then
            return ("%d:%02d:%02d"):format(math.floor(sec / 3600),
                math.floor(sec / 60) % 60, sec % 60)
        end
        if sec >= 60 then return ("%d:%02d"):format(math.floor(sec / 60), sec % 60) end
        return sec .. "s"
    end
end

-- The step's text as the guide window shows it (RestedXP's processed text:
-- colours and names filled in), from its current step boxes.
local function StepText(step)
    local rxp = _G.RXPFrame
    for _, frame in pairs(rxp and rxp.CurrentStepFrame and rxp.CurrentStepFrame.framePool or {}) do
        if frame.step == step then
            for _, el in ipairs(frame.elements or {}) do
                local t = el.text and el.text:GetText()
                if el:IsShown() and el:GetAlpha() > 0 and type(t) == "string" and not IsSecret(t)
                    and t ~= "" and t ~= " " and not Count(t) then
                    return t
                end
            end
        end
    end
end

-- RestedXP writes "Step 22\n(177yd)" (or a custom title) whenever the
-- distance changes: ours shows the yards and the step's text (Card: with
-- its number, and the arrow and yards coloured by distance).
local function ArrowText(text)
    if not (card and ArrowOn()) then return end
    local af = _G.RXPG_ARROW
    local style = ArrowStyle()
    if style == "WAYPOINT" then return end   -- hidden card: nothing to label
    if type(text) ~= "string" or IsSecret(text) then text = "" end
    -- The unit is yd or m (the meters option rewrites RestedXP's raw text,
    -- and a stale "m" can linger until its next distance change): the
    -- number is what matters here, the label is drawn from the setting.
    local title, dist = text:match("^(.-)\n%((%d+)%s*%a+%)$")
    if not dist then dist = text:match("^%((%d+)%s*%a+%)$") end
    title = title or (not dist and text) or ""
    local element = af.element
    local step = element and element.step
    local line = title
    if step and step.index and not element.title and not step.arrowtext then
        local what = StepText(step)
        if style == "CARD" then
            line = what and (step.index .. " \194\183 " .. what) or title
        else
            line = what or title   -- no step number
        end
    end
    local c = LayoutCfg()
    card.title:SetText(SmallIcons(EnemyColor(line), c.arrowText))
    -- Show Meters: the same number, "m" for "yd" (just the unit).
    card.dist:SetText(dist and (dist .. (DB().rxpMeters and " m" or " yd")) or "")
    if style == "ZYGOR" then
        -- The yards coloured by distance, then the time to get there in
        -- yellow ("Time to Waypoint" off: the yards alone).
        local d = tonumber(dist)
        local r, g, b = DistColor(d)
        local eta = DB().rxpArrowETA ~= false and ETA(d)
        card.dist:SetTextColor(r, g, b)
        if eta then card.dist:SetText(card.dist:GetText() .. "  |cffffd24a" .. eta .. "|r") end
        card.zygor:SetVertexColor(c.arrowCol[1], c.arrowCol[2], c.arrowCol[3], c.arrowCol[4])
    elseif style == "CARD" then
        -- The arrow and the yards coloured by distance, then the time.
        local r, g, b = DistColor(tonumber(dist))
        card.arrow:SetVertexColor(r, g, b, 1)
        card.dist:SetTextColor(r, g, b)
        local eta = DB().rxpArrowETA ~= false and ETA(tonumber(dist))
        if eta then card.dist:SetText(card.dist:GetText() .. "  |cffffd24a" .. eta .. "|r") end
    elseif style == "CLASSIC" then
        -- The yards coloured by distance (the arrow itself colors by
        -- heading), then the time.
        local r, g, b = DistColor(tonumber(dist))
        card.dist:SetTextColor(r, g, b)
        local eta = DB().rxpArrowETA ~= false and ETA(tonumber(dist))
        if eta then card.dist:SetText(card.dist:GetText() .. "  |cffffd24a" .. eta .. "|r") end
    else
        -- Chevron (and any future style): its layout colour, plus the time.
        if style == "CHEVRON" then
            card.chev:SetVertexColor(c.arrowCol[1], c.arrowCol[2], c.arrowCol[3], c.arrowCol[4])
        end
        card.dist:SetTextColor(1, 1, 1)
        local eta = DB().rxpArrowETA ~= false and ETA(tonumber(dist))
        if eta then card.dist:SetText(card.dist:GetText() .. "  |cffffd24a" .. eta .. "|r") end
    end
    card:SetWidth(math.min(340, math.max(120, (card.title:GetStringWidth() or 0) + 24)))
end

-- Layers in the arrow shadow's stack: each copy is a step bigger and a
-- step fainter than the one inside it, so the rim feathers out over the
-- spread instead of ending hard -- that falloff IS the blur (no blurred
-- texture file to ship, and it turns with the arrow for free).
local SHADOW_STEPS = 7

local function BuildCard()
    local af = _G.RXPG_ARROW
    -- Our arrow sits where RestedXP's does (its 32px frame is still the drag
    -- handle); the yards and the step's text hang below (Card: above).
    card = CreateFrame("Frame", nil, af, "BackdropTemplate")
    card:SetBackdrop(FLAT)   -- Card's panel (clear otherwise)
    -- Card: a big flat arrow, a dark copy a little bigger behind it as its outline.
    card.arrowShadow = card:CreateTexture(nil, "ARTWORK")
    card.arrowShadow:SetTexture(ARROW)
    card.arrowShadow:SetPoint("CENTER", af, "CENTER", 0, 0)
    card.arrowShadow:SetVertexColor(0, 0, 0, 0.85)
    card.arrow = card:CreateTexture(nil, "OVERLAY")
    card.arrow:SetTexture(ARROW)
    card.arrow:SetPoint("CENTER", af, "CENTER", 0, 0)
    card.title = card:CreateFontString(nil, "OVERLAY")
    card.title:SetJustifyH("CENTER")
    card.title:SetWordWrap(false)
    card.dist = card:CreateFontString(nil, "OVERLAY")
    card.dist:SetJustifyH("CENTER")
    -- Chevron (design N), a thicker black copy under it as its outline.
    card.chevEdge = card:CreateTexture(nil, "ARTWORK", nil, 1)
    card.chevEdge:SetTexture(CHEVRON_EDGE)
    card.chevEdge:SetVertexColor(0, 0, 0, 0.9)
    card.chev = card:CreateTexture(nil, "ARTWORK", nil, 2)
    card.chev:SetTexture(CHEVRON)
    card.chevEdge:SetAllPoints(card.chev)
    -- Classic: the shaded arrow (its outline is in the art).
    card.classic = card:CreateTexture(nil, "ARTWORK", nil, 2)
    card.classic:SetTexture(CLASSIC)
    card.classic:SetPoint("CENTER", af, "CENTER", 0, 4)
    -- Zygor-style: the broad arrowhead (its outline is in the art).
    card.zygor = card:CreateTexture(nil, "ARTWORK", nil, 2)
    card.zygor:SetTexture(ZYGOR)
    card.zygor:SetPoint("CENTER", af, "CENTER", 0, 4)
    -- Rail: this theme's pointer -- the folded arrowhead, its darker half
    -- giving the relief (the shading is in the art).
    card.rail = card:CreateTexture(nil, "ARTWORK", nil, 2)
    card.rail:SetTexture(RAILP)
    card.rail:SetPoint("CENTER", af, "CENTER", 0, 4)
    -- Rail Compass: the same idea as an emblem -- a flat ring around a
    -- two-facet needle. The ring barely reads at 36 px, so this one suits a
    -- stationary arrow better than a moving one.
    card.railCompass = card:CreateTexture(nil, "ARTWORK", nil, 2)
    card.railCompass:SetTexture(RAILC)
    card.railCompass:SetPoint("CENTER", af, "CENTER", 0, 4)
    -- "Arrow Shadow" (the ARROW block's option): the stack of copies under
    -- the icon -- centred, spread and coloured in ArrowShadow below, which
    -- also picks their texture from the style.
    card.shadows = {}
    for i = 1, SHADOW_STEPS do
        local sh = card:CreateTexture(nil, "ARTWORK", nil, 0)
        sh:Hide()
        card.shadows[i] = sh
    end
    -- Standing still for a moment clears the time to go (every style now
    -- carries it, so the check is "our arrow is drawn", not one style).
    card.etaWait = 0
    card:SetScript("OnUpdate", function(self, elapsed)
        self.etaWait = self.etaWait + elapsed
        if self.etaWait < 1 then return end
        self.etaWait = 0
        local e = R.eta
        if e and e.speed > 0 and GetTime() - e.t > 2 and ArrowOn() then
            e.speed, e.t = 0, GetTime()
            ArrowText(af.text:GetText())
        end
    end)
    -- Dragging the card moves RestedXP's arrow (its own handlers).
    card:EnableMouse(true)
    -- Right-click: centre the arrow across the screen (same height), saved
    -- like a drag.
    card:SetScript("OnMouseDown", function(_, button)
        if button == "RightButton" then return end
        local fn = af:GetScript("OnMouseDown")
        if fn then fn(af, button) end
    end)
    card:SetScript("OnMouseUp", function(_, button)
        if button == "RightButton" then
            local _, cy = af:GetCenter()
            if cy and not (InCombatLockdown() and af:IsProtected()) then
                af:ClearAllPoints()
                af:SetPoint("CENTER", UIParent, "BOTTOM", 0, cy)
            end
        end
        local fn = af:GetScript("OnMouseUp")   -- RestedXP saves the position
        if fn then fn(af, button) end
    end)
    -- Follow RestedXP: its rotation, its text, its art (re-set on theme changes).
    hooksecurefunc(af.texture, "SetRotation", function(_, r)
        card.chev:SetRotation(r)
        card.chevEdge:SetRotation(r)
        card.arrow:SetRotation(r)
        card.arrowShadow:SetRotation(r)
        card.classic:SetRotation(r)
        card.classic:SetVertexColor(HeadingColor(r))
        card.zygor:SetRotation(r)
        card.rail:SetRotation(r)
        card.railCompass:SetRotation(r)
        for i = 1, #(card.shadows or {}) do   -- the shadows follow the arrow
            card.shadows[i]:SetRotation(r)
        end
    end)
    hooksecurefunc(af.text, "SetText", function(_, t) ArrowText(t) end)
    if af.UpdateVisuals then hooksecurefunc(af, "UpdateVisuals", function() R.SkinArrow() end) end
end

-- "Arrow Shadow": copies of the icon the style picked, drawn dead centre
-- under it, every copy a step bigger and fainter than the one inside it,
-- so the shadow surrounds the icon on EVERY side (top, bottom, left,
-- right) and FEATHERS out over the spread -- a soft, blurred edge instead
-- of a hard rim. The ARROW block picks the spread (a slider: the blur's
-- width, growing in place) and the colour; the stack reaches exactly the
-- picked alpha next to the icon and fades to nothing at the outer edge.
-- It turns with the arrow (the rotation hook above follows it). Card
-- draws its own outline, so that style is left alone.
local function ArrowShadow(shape, size, rot)
    local pool = card and card.shadows
    if not pool or #pool == 0 then return end
    local db = DB()
    if not (shape and db.rxpArrowShadow) then
        for i = 1, #pool do pool[i]:Hide() end
        return
    end
    local spread = tonumber(db.rxpArrowShadowSize) or 6
    local base = size or 32
    local tex = shape:GetTexture()
    rot = rot or 0
    local r, g, b, a = ns.Color("rxpArrowShadow", 0, 0, 0, 0.75)
    -- Per-layer alpha: a_i = 1 - (1 - a) ^ (f_i^2 * c). With f running 1
    -- (innermost) to 1/N (outermost) and c = 1 / sum(f^2), the alphas
    -- MULTIPLY down to exactly 1 - (1 - a) -- the composite beside the
    -- icon is the picked alpha, and the falloff squares off toward the
    -- outer edge, which is what reads as blur.
    local N = #pool
    local c = 6 * N / ((N + 1) * (2 * N + 1))   -- 1 / sum of f^2, f = k/N
    for i = 1, N do
        local sh = pool[i]
        local f = (N - i + 1) / N
        sh:SetTexture(tex)
        sh:ClearAllPoints()
        sh:SetPoint("CENTER", shape, "CENTER", 0, 0)
        sh:SetSize(base + spread * i / N, base + spread * i / N)
        sh:SetRotation(rot)
        sh:SetVertexColor(r, g, b, 1 - (1 - a) ^ (f * f * c))
        sh:Show()
    end
end

function R.SkinArrow()
    local af = _G.RXPG_ARROW
    if not af then return end
    if not ArrowOn() then
        if card then
            card:Hide()
            af.texture:SetAlpha(1)
            af.text:SetAlpha(1)
        end
        if ns.WaypointTick then ns.WaypointTick() end   -- style left: take our waypoint down
        return
    end
    if ArrowStyle() == "WAYPOINT" then
        -- WaypointUI drives: no card drawn, and RestedXP's own arrow
        -- visuals hidden too (the frame itself stays: drag handle and the
        -- target source MapRouteSpot reads). Without WaypointUI installed
        -- the stock arrow is left up instead -- an arrow is never silently
        -- taken away.
        if card then card:Hide() end
        if ns.WaypointAvailable and ns.WaypointAvailable() then
            if af.texture then af.texture:SetAlpha(0) end
            if af.text then af.text:SetAlpha(0) end
            if ns.WaypointTick then ns.WaypointTick() end
        else
            if af.texture then af.texture:SetAlpha(1) end
            if af.text then af.text:SetAlpha(1) end
        end
        return
    end
    if not card then BuildCard() end
    af.texture:SetAlpha(0)   -- ours draws the arrow (same rotation)
    af.text:SetAlpha(0)      -- and the text
    local style, c = ArrowStyle(), LayoutCfg()
    -- RestedXP turns ITS arrow by rotating the texture inside RXPG_ARROW; our
    -- shapes hang off the frame, so they never followed it -- every style
    -- pointed straight up whatever the waypoint. Read the rotation RestedXP
    -- just applied and mirror it on ours (the text stays upright).
    local rot = (af.texture and af.texture.GetRotation) and af.texture:GetRotation() or 0
    if style == "CARD" then
        -- A slim card (at least 60% black) with the step over the arrow,
        -- the yards under it. Its own outline IS the shadow, so the Arrow
        -- Shadow option has nothing to add here.
        ArrowShadow(nil)
        card:SetBackdropColor(0, 0, 0, math.max(c.backdrop, 0.6))
        card:SetBackdropBorderColor(c.border[1], c.border[2], c.border[3], c.border[4])
        card:ClearAllPoints()
        card:SetPoint("BOTTOM", af, "CENTER", 0, math.floor(c.arrow * 0.65 + 0.5))
        card:SetHeight(c.arrowText + 16)
        card.arrow:Show(); card.arrowShadow:Show()
        card.arrow:SetRotation(rot); card.arrowShadow:SetRotation(rot)
        card.arrow:SetSize(c.arrow, c.arrow)
        card.arrowShadow:SetSize(c.arrow + 6, c.arrow + 6)
        card.chev:Hide(); card.chevEdge:Hide(); card.classic:Hide(); card.zygor:Hide(); card.rail:Hide(); card.railCompass:Hide()
        ns.ApplyFont(card.title, c.body, c.arrowText, "OUTLINE")
        card.title:SetShadowOffset(1, -1); card.title:SetShadowColor(0, 0, 0, 0.8)
        card.title:SetTextColor(c.arrowCol[1], c.arrowCol[2], c.arrowCol[3], c.arrowCol[4])
        card.title:ClearAllPoints()
        card.title:SetPoint("LEFT", card, "LEFT", 12, 0)
        card.title:SetPoint("RIGHT", card, "RIGHT", -12, 0)
        ns.ApplyFont(card.dist, c.body, c.dist, "OUTLINE")
        card.dist:SetShadowOffset(1, -1); card.dist:SetShadowColor(0, 0, 0, 0.8)
        card.dist:ClearAllPoints()
        card.dist:SetPoint("TOP", af, "CENTER", 0, -math.floor(c.arrow * 0.55 + 0.5))
        card:Show()
        ArrowText(af.text:GetText())
        return
    end
    -- Chevron / Classic: the arrow where RestedXP's is, turning toward the
    -- waypoint, with the yards and the step text centred under it.
    card:SetBackdropColor(0, 0, 0, 0)
    card:SetBackdropBorderColor(0, 0, 0, 0)
    card.arrow:Hide(); card.arrowShadow:Hide()
    card:ClearAllPoints()
    card:SetPoint("TOP", af, "TOP", 0, 2)
    card:SetHeight(c.arrow + c.dist + c.arrowText + 24)
    if style == "ZYGOR" then
        -- Zygor-style: the arrowhead, the step under it, then the yards and
        -- the time to go.
        card.chev:Hide(); card.chevEdge:Hide(); card.classic:Hide(); card.rail:Hide(); card.railCompass:Hide()
        card.zygor:SetSize(c.arrow, c.arrow)
        card.zygor:SetRotation(rot)
        card.zygor:Show()
        ns.ApplyFont(card.title, c.semi, c.arrowText, "OUTLINE")
        card.title:SetShadowOffset(0, -1); card.title:SetShadowColor(0, 0, 0, 1)
        card.title:SetTextColor(c.current[1], c.current[2], c.current[3], c.current[4])
        card.title:ClearAllPoints()
        card.title:SetPoint("TOP", card.zygor, "BOTTOM", 0, 2)
        ns.ApplyFont(card.dist, c.body, c.dist, "OUTLINE")
        card.dist:SetShadowOffset(0, -1); card.dist:SetShadowColor(0, 0, 0, 1)
        card.dist:ClearAllPoints()
        card.dist:SetPoint("TOP", card.title, "BOTTOM", 0, -3)
        ArrowShadow(card.zygor, c.arrow, rot)
        card:Show()
        ArrowText(af.text:GetText())
        return
    end
    card.zygor:Hide()
    local shape, shapeSize = nil, c.arrow
    if style == "CLASSIC" then
        card.chev:Hide(); card.chevEdge:Hide(); card.rail:Hide(); card.railCompass:Hide()
        card.classic:SetSize(c.arrow, c.arrow)
        card.classic:SetRotation(rot)
        card.classic:Show()
        shape = card.classic
    elseif style == "RAIL" or style == "RAILC" then
        -- This theme's pointer, the yards and the step under it.
        card.chev:Hide(); card.chevEdge:Hide(); card.classic:Hide()
        local mark = style == "RAIL" and card.rail or card.railCompass
        card.rail:Hide(); card.railCompass:Hide()
        mark:SetSize(c.arrow, c.arrow)
        mark:SetRotation(rot)
        mark:SetVertexColor(c.arrowCol[1], c.arrowCol[2], c.arrowCol[3], c.arrowCol[4])
        mark:Show()
        shape = mark
    else
        card.classic:Hide(); card.rail:Hide(); card.railCompass:Hide()
        local size = math.max(14, math.floor(c.arrow * 0.85 + 0.5))
        shapeSize = size
        card.chev:SetSize(size, size)
        card.chev:ClearAllPoints()
        card.chev:SetPoint("CENTER", af, "CENTER", 0, 4)
        card.chev:SetRotation(rot)
        card.chev:Show(); card.chevEdge:Show()
        shape = card.chev
    end
    ArrowShadow(shape, shapeSize, rot)
    ns.ApplyFont(card.dist, c.body, c.dist, "OUTLINE")
    card.dist:SetShadowOffset(0, -1); card.dist:SetShadowColor(0, 0, 0, 1)
    card.dist:ClearAllPoints()
    card.dist:SetPoint("TOP", shape, "BOTTOM", 0, 2)
    ns.ApplyFont(card.title, c.semi, c.arrowText, "OUTLINE")
    card.title:SetShadowOffset(0, -1); card.title:SetShadowColor(0, 0, 0, 1)
    card.title:SetTextColor(c.muted[1], c.muted[2], c.muted[3], c.muted[4])
    card.title:ClearAllPoints()
    card.title:SetPoint("TOP", card.dist, "BOTTOM", 0, -6)
    card:Show()
    ArrowText(af.text:GetText())
end

-- =====================================================================
-- ACTIVE TARGETS / ACTIVE ITEMS: RestedXP's icon button boxes
-- =====================================================================
-- Their buttons are secure (they target / use items), so all of this waits
-- until you're out of combat; RestedXP itself doesn't change them in combat.
local boxesPending
local hookedBoxes = {}   -- boxes we hook (HookBoxes, below)
local function SkinIconButton(btn)
    if not btn then return end
    if not btn.ltBorder then
        btn.ltBorder = btn:CreateTexture(nil, "BACKGROUND", nil, -7)
        btn.ltBorder:SetAllPoints(btn)
        btn.ltBorder:SetColorTexture(0, 0, 0, 1)
        -- A soft shadow under each icon (no box behind them).
        btn.ltShadow = btn:CreateTexture(nil, "BACKGROUND", nil, -8)
        btn.ltShadow:SetPoint("TOPLEFT", btn, "TOPLEFT", 1, -2)
        btn.ltShadow:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 1, -2)
        btn.ltShadow:SetColorTexture(0, 0, 0, 0.6)
        for _, region in ipairs({ btn:GetRegions() }) do
            if region.GetDrawLayer and region:GetDrawLayer() == "HIGHLIGHT" then btn.ltHighlight = region end
        end
    end
    btn.ltBorder:Show()
    -- The frame around each icon follows the theme: the same single accent as
    -- the RXP theme and the arrow tint (R.Refresh re-skins the boxes, so a
    -- live accent change reaches them).
    local ar, ag, ab = ns.ThemeAccent()
    btn.ltBorder:SetColorTexture(ar, ag, ab, 0.35)
    local icon = btn.icon
    if icon then
        icon:ClearAllPoints()
        icon:SetPoint("TOPLEFT", btn, "TOPLEFT", 1, -1)
        icon:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -1, 1)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end
    -- RestedXP's glossy square highlight: a flat white wash instead.
    local hl = btn.ltHighlight
    if hl then
        hl:SetTexture(WHITE)
        hl:SetVertexColor(1, 1, 1, 0.15)
        hl:SetBlendMode("BLEND")
    end
end

-- Back to RestedXP's own look (the reskin was turned off).
local function UnskinIconButton(btn)
    if not (btn and btn.ltBorder) then return end
    btn.ltBorder:Hide()
    btn.ltShadow:Hide()
    local icon = btn.icon
    if icon then
        icon:ClearAllPoints()
        icon:SetAllPoints(btn)
        icon:SetTexCoord(0, 1, 0, 1)
    end
    local hl = btn.ltHighlight
    if hl then
        hl:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
        hl:SetVertexColor(1, 1, 1, 1)
        hl:SetBlendMode("ADD")
    end
end

-- Each box and where RestedXP keeps its buttons.
local BOXES = {
    { name = "RXPTargetFrame", lists = { "enemyTargetButtons", "friendlyTargetButtons" } },
    { name = "RXPItemFrame", lists = { "buttonList" } },
}

local function SkinBox(f, lists)
    -- Frameless (design D): no box and no title, just the outlined icons
    -- (hovering one still shows its name). The title stays as an invisible
    -- drag handle. Timeline: the window's panel and a navy title tab.
    local frameless = Layout() ~= "TIMELINE"
    for _, key in ipairs(lists) do
        for _, btn in ipairs(f[key] or {}) do
            SkinIconButton(btn)
            if btn.ltShadow then btn.ltShadow:SetShown(frameless) end
        end
    end
    if not frameless then
        local c = TLCfg()
        if f.title then f.title:SetAlpha(1) end
        f:SetBackdrop(FLAT)
        f:SetBackdropColor(0, 0, 0, math.max(c.backdrop, 0.6))
        f:SetBackdropBorderColor(c.border[1], c.border[2], c.border[3], c.border[4])
        local title = f.title
        if title and title.SetBackdrop then
            title:SetBackdrop(FLAT)
            title:SetBackdropColor(c.headBg[1], c.headBg[2], c.headBg[3], c.headBg[4])
            title:SetBackdropBorderColor(c.border[1], c.border[2], c.border[3], c.border[4])
            if title.text then
                ns.ApplyFont(title.text, c.body, 10, "OUTLINE")
                title.text:SetTextColor(c.muted[1], c.muted[2], c.muted[3], c.muted[4])
                title:SetSize((title.text:GetStringWidth() or 60) + 12, 17)
            end
        end
        return
    end
    f:SetBackdrop(FLAT)
    f:SetBackdropColor(0, 0, 0, 0)
    f:SetBackdropBorderColor(0, 0, 0, 0)
    if f.title then
        f.title:SetAlpha(0)
        if f.title.SetBackdrop then f.title:SetBackdrop(nil) end
    end
end

-- R.boxesSkinned: ours are on the boxes (so handing them back happens once:
-- RestedXP's repaint runs our UpdateVisuals / size hooks again, and they
-- must not hand them back again, and again).
function R.SkinBoxes()
    if not Enabled() or R.unskinning then return end
    if Layout() == "DEFAULT" then
        if R.boxesSkinned then R.UnskinBoxes() end   -- RestedXP's own look
        return
    end
    if InCombatLockdown() then boxesPending = "skin"; return end
    boxesPending = false
    R.boxesSkinned = true
    for _, box in ipairs(BOXES) do
        local f = _G[box.name]
        if f then SkinBox(f, box.lists) end
    end
    R.AttachTargets()   -- a box appeared or changed size
end

function R.UnskinBoxes()
    if R.unskinning then return end
    if InCombatLockdown() then boxesPending = "unskin"; return end
    boxesPending = false
    R.boxesSkinned = false
    R.unskinning = true   -- RestedXP's repaints below call our hooks: they wait
    for _, box in ipairs(BOXES) do
        local f = _G[box.name]
        if f then
            for _, key in ipairs(box.lists) do
                for _, btn in ipairs(f[key] or {}) do UnskinIconButton(btn) end
            end
            if f.title then f.title:SetAlpha(1) end
            if f.UpdateVisuals then pcall(f.UpdateVisuals, f) end   -- RestedXP repaints its box
        end
    end
    R.unskinning = false
end

-- RestedXP re-applies its look in UpdateVisuals; new buttons change a
-- box's size; boxes are shown again when targets / items come back.
local function HookBoxes()
    for _, box in ipairs(BOXES) do
        local f = _G[box.name]
        if f and not hookedBoxes[f] then
            hookedBoxes[f] = true
            if f.UpdateVisuals then hooksecurefunc(f, "UpdateVisuals", function() R.SkinBoxes() end) end
            f:HookScript("OnSizeChanged", function() R.SkinBoxes() end)
            f:HookScript("OnShow", function() R.SkinBoxes() end)
            f:HookScript("OnHide", function() R.AttachTargets() end)   -- items move up
        end
    end
    if not hookedBoxes.regen then
        hookedBoxes.regen = CreateFrame("Frame")
        hookedBoxes.regen:RegisterEvent("PLAYER_REGEN_ENABLED")
        hookedBoxes.regen:SetScript("OnEvent", function()
            if boxesPending == "skin" then R.SkinBoxes()
            elseif boxesPending == "unskin" then R.UnskinBoxes() end
        end)
    end
end

-- =====================================================================
-- Refresh plumbing
-- =====================================================================
function R.Skin(force)
    if not Enabled() then return end
    -- A layout switch must not inherit the previous title's anchor.
    if W then W.collapseAnchorFs = nil end
    -- RestedXP builds its Active Targets / Items boxes during its own start-up.
    for _, box in ipairs(BOXES) do
        local f = _G[box.name]
        if f and not hookedBoxes[f] then HookBoxes(); R.SkinBoxes(); break end
    end
    local layout = Layout()
    if layout == "DEFAULT" then
        -- RestedXP's own window: ours goes, theirs comes back.
        if W then W:Hide(); W:SetScript("OnUpdate", nil) end
        if _G.RXPFrame then HideRXP(false); RestoreRXPWidth() end
    elseif layout == "TIMELINE" then
        R.RenderTimeline()
    elseif layout == "COMPACT" then
        R.RenderCompact()
    elseif layout == "ZYGOR" then
        R.RenderZygor()
    elseif layout == "BIT8" then
        R.RenderBit()
    elseif layout == "RAIL" then
        R.RenderRail()
    else
        R.RenderFrameless()
    end
end

-- RestedXP's refreshes can come in bursts (the step list's update even runs
-- every frame while the window is resized): once, on the next frame.
local queued
function R.Queue()
    -- A mouse-up that never arrived can't leave redraws paused.
    if R.dragging and not IsMouseButtonDown() then R.dragging = false end
    if queued or R.dragging then return end
    queued = true
    C_Timer.After(0, function()
        queued = false
        R.Skin()
    end)
end

local hooked
local function Hook()
    if hooked or not _G.RXPFrame then return end
    local f = _G.RXPFrame
    hooked = true
    if f.UpdateVisuals then hooksecurefunc(f, "UpdateVisuals", R.Queue) end
    if f.CurrentStepFrame and f.CurrentStepFrame.UpdateText then
        hooksecurefunc(f.CurrentStepFrame, "UpdateText", function()
            if Enabled() then
                Silence(f.CurrentStepFrame)   -- it just switched its mouse back on
                R.Queue()
            end
        end)
    end
    if f.BottomFrame and f.BottomFrame.UpdateFrame then
        hooksecurefunc(f.BottomFrame, "UpdateFrame", R.Queue)
    end
end

-- Disable Announcements: RestedXP's six "Announce ..." options (level-up
-- emote / party / guild, step completion / collection / flying timers) are
-- switched off in its settings every login, so nothing is posted to chat.
local ANNOUNCE = {
    "enableLevelUpAnnounceSolo", "enableLevelUpAnnounceGroup", "enableLevelUpAnnounceGuild",
    "enableCompleteStepAnnouncements", "enableCollectStepAnnouncements", "enableFlyStepAnnouncements",
}
function R.DisableAnnouncements()
    if not DB().rxpNoAnnounce then return end
    local profile = RXPProfile()
    if not profile then return end
    for _, key in ipairs(ANNOUNCE) do profile[key] = false end
end

-- "RXP Scale": RestedXP's own Window Scale setting, so its options and ours
-- agree. The reskinned window copies RestedXP's scale when it redraws.
function R.GetScale()
    local p = RXPProfile()
    local v = p and tonumber(p.windowScale)
    if not v and _G.RXPFrame then v = _G.RXPFrame:GetScale() end
    return v or 1
end

function R.SetScale(v)
    local p = RXPProfile()
    if p then p.windowScale = v end
    if _G.RXPFrame then _G.RXPFrame:SetScale(v) end
    R.Refresh()
end

function R.Refresh()
    R.DisableAnnouncements()
    R.SyncEnemyColor()
    if not Enabled() then
        -- Hand everything back to RestedXP: its window, arrow and boxes.
        R.SkinArrow()
        if W then W:Hide(); W:SetScript("OnUpdate", nil) end
        if _G.RXPFrame then HideRXP(false); RestoreRXPWidth() end
        if next(hookedBoxes) then R.UnskinBoxes() end
        return
    end
    Hook()
    R.Skin(true)
    R.SkinArrow()
    HookBoxes()
    R.SkinBoxes()
    -- Re-run RestedXP's own layout so its step boxes follow the settings.
    local csf = _G.RXPFrame.CurrentStepFrame
    if csf and csf.UpdateText then pcall(csf.UpdateText) end
end

table.insert(ns.onLogin, function()
    local db = DB()
    -- The collapse survives a /reload: a collapsed window stays collapsed.
    if db.rxpWindowCollapsed then R.collapsed = true end
    -- One-time: more listed steps (6, was 3).
    if not db.rxpTallV1 then
        if db.rxpUpcoming == 3 then db.rxpUpcoming = 6 end
        db.rxpTallV1 = true
    end
    -- One-time: a bit taller again (8 listed steps, was 6).
    if not db.rxpTallV2 then
        if db.rxpUpcoming == 6 then db.rxpUpcoming = 8 end
        db.rxpTallV2 = true
    end
    -- Archivo Narrow was removed: any font setting still pointing at it
    -- follows EllesmereUI's Global Font.
    for key, value in pairs(db) do
        if type(value) == "string" and value:find("ArchivoNarrow", 1, true) then
            db[key] = ns.FUI_FONT
        end
    end
    -- One-time: the card design's white instruction text (was yellow).
    if not db.rxpFlCardV1 then
        if db.rxpFlCurR == 0.95 and db.rxpFlCurG == 0.85 and db.rxpFlCurB == 0.47 then
            db.rxpFlCurR, db.rxpFlCurG, db.rxpFlCurB = 1, 1, 1
        end
        db.rxpFlCardV1 = true
    end
    -- RestedXP loads its settings during its own start-up: apply these
    -- again once it surely has.
    C_Timer.After(5, function()
        R.DisableAnnouncements()
        R.SyncEnemyColor()
    end)
    if _G.RXPFrame then
        R.Refresh()
    else
        -- RestedXP loading after us (or on demand).
        local w = CreateFrame("Frame")
        w:RegisterEvent("ADDON_LOADED")
        w:SetScript("OnEvent", function(self, _, name)
            if name == "RXPGuides" then
                self:UnregisterAllEvents()
                C_Timer.After(0, R.Refresh)
            end
        end)
    end
end)
