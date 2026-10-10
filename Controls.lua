-- FUI-RestedXP Controls.lua
-- The control kinds the options page rows up: toggle, slider, dropdown,
-- colorpicker and button. Same shape as the three base kinds in
-- OptionsView.lua -- { New(view) made once, Set(row, ...) -> height } --
-- and the same rule that makes pooling pay: a control is re-pointed at
-- its get/set through FIELDS, so a reused row never keeps an old
-- callback.
--
-- Interaction rule: a control paints itself the instant it is touched
-- and lets set() queue the page-wide redraw, which the engine
-- coalesces 0.15s later -- a slider drag is never interrupted by its
-- own redraw.
--
-- The dropdown opens the addon's OWN list on click -- the same dark
-- panel + hairline edges as the row tip, one row per value, anchored
-- under the button, wheeled for long lists. No Blizzard Menu anywhere:
-- the game's own list look never shows. If the list itself cannot be
-- built, the button steps to the next value instead, so it never sits
-- empty and inert.

local ADDON_NAME, ns = ...

local B = ns.ViewBits
local K = ns.Kinds

local WHITE = "Interface\\Buttons\\WHITE8X8"
local TEX = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Textures\\"
local TRACK_TEX = TEX .. "fui-toggle-track.png"  -- our own pill art, 2:1
local KNOB_TEX = TEX .. "fui-toggle-knob.png"    -- our own circle art

local ROW_H = B.ROW_H
local TRACK_W = B.TRACK_W
local TOGGLE_H = 20
local KNOB = 14       -- 70% of the track height
local KNOB_INSET = 3  -- 15% of it, never under 2
local DROP_W, DROP_H = 150, 24 -- the fallback width; DropFit resizes it
local DROP_PX = 7             -- a character at this size, the fit's fallback ruler
local DROP_FIT_PAD = 30       -- label inset + chevron + its gap: the whole frame
local DROP_FIT_MIN = 40       -- never a narrower button than this
local DROP_FIT_GAP = 12       -- the room the button leaves the row's own label
B.DROP_PX, B.DROP_FIT_PAD, B.DROP_FIT_MIN, B.DROP_FIT_GAP =
    DROP_PX, DROP_FIT_PAD, DROP_FIT_MIN, DROP_FIT_GAP
local SWATCH_W, SWATCH_H = 46, 22
local EMPTY = {}

-- Toward white, for hover states (the kit lifts colours the same way).
local function Lighten(r, g, b, k)
    return r + (1 - r) * k, g + (1 - g) * k, b + (1 - b) * k
end

-- Tooltips: every row carries its documentation on THIS addon's own
-- tip frame (not GameTooltip) -- the frame is built below, next to Box,
-- which it wears as its panel.

-- A flat panel: a fill plus a 1px black edge on all four sides. The new
-- look never uses SetBackdrop; two-corner edge anchors mean the panel
-- resizes with its frame and needs no rebuild.
local function Box(frame, r, g, b, a)
    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetColorTexture(r, g, b, a or 1)
    bg:SetAllPoints()
    local edges = {
        B.Edge(frame, "TOPLEFT", "TOPRIGHT", true),
        B.Edge(frame, "BOTTOMLEFT", "BOTTOMRIGHT", true),
        B.Edge(frame, "TOPLEFT", "BOTTOMLEFT", false),
        B.Edge(frame, "TOPRIGHT", "BOTTOMRIGHT", false),
    }
    return bg, edges
end

-- Pixel snapping throws away the art's antialiasing, which is what
-- makes a switch look jagged: both toggle pieces opt out of it.
local function Smooth(tex)
    if tex.SetTexelSnappingBias then tex:SetTexelSnappingBias(0) end
    if tex.SetSnapToPixelGrid then tex:SetSnapToPixelGrid(false) end
end

-- ---------------- The row tip ----------------
-- A dark panel with the kit's hairline edges, wrapped at TIP_W in
-- TIP_SIZE -- the options' own quiet size -- riding ABOVE the cursor,
-- so it never hides the row it documents. NOT GameTooltip: its yellow
-- border is Blizzard's, and writing our font into it leaked that font
-- onto every other addon's tooltip.
local TIP_W, TIP_SIZE = 400, 11
local Tip = CreateFrame("Frame", "FUIRestedXPTip", UIParent)
Tip:SetFrameStrata("TOOLTIP")
Tip.bg, Tip.edges = Box(Tip, 0.045, 0.047, 0.055, 0.99)
for i = 1, #(Tip.edges or {}) do
    Tip.edges[i]:SetColorTexture(B.LINE[1], B.LINE[2], B.LINE[3], 1)
end
Tip.text = B.Font(Tip, TIP_SIZE, B.FG[1], B.FG[2], B.FG[3])
Tip.text:SetPoint("TOPLEFT", Tip, "TOPLEFT", 12, -12)
Tip.text:SetWidth(TIP_W)
Tip:Hide()

local TipPlace -- forward: TipEnter shows above the cursor; placed below
local function TipEnter(target)
    if not target or not target.__tip then return end
    Tip.text:SetText(target.__tip)
    -- The Theme page's "Default Font", live: the tip repaints with it.
    local use = (ns.ResolveFont and ns.ResolveFont(nil))
        or select(1, Tip.text:GetFont())
    Tip.text:SetFont(use, TIP_SIZE, "")
    Tip:SetWidth(TIP_W + 24)
    Tip:SetHeight((Tip.text:GetStringHeight() or 14) + 24)
    TipPlace(target)
    Tip:Show()
end

-- Above the pointer, right of it so it never covers the row: below it
-- when the top edge is near, slid left when the right edge is near.
-- Without a cursor API (tests) it falls back beside the row, as before.
function TipPlace(target)
    local w = Tip:GetWidth() or (TIP_W + 24)
    local h = Tip:GetHeight() or 40
    local uw = (UIParent and UIParent:GetWidth()) or 0
    local uh = (UIParent and UIParent:GetHeight()) or 0
    if GetCursorPosition and UIParent and UIParent.GetEffectiveScale then
        local scale = UIParent:GetEffectiveScale() or 1
        if scale == 0 then scale = 1 end
        local cx, cy = GetCursorPosition()
        if cx and cy then
            local x, y = cx / scale, cy / scale
            local point, dx, dy = "BOTTOMLEFT", x + 16, y + 24
            if uh > 0 and y + 24 + h > uh - 8 then
                -- Near the top: hang below the pointer instead.
                point, dy = "TOPLEFT", y - 16
            end
            if uw > 0 and x + 16 + w > uw - 8 then
                -- Near the right edge: slide left, still above/below.
                dx = math.max(8, uw - 8 - w)
            end
            Tip:ClearAllPoints()
            Tip:SetPoint(point, UIParent, "BOTTOMLEFT", dx, dy)
            return
        end
    end
    Tip:ClearAllPoints()
    Tip:SetPoint("TOPLEFT", target, "TOPRIGHT", 10, 0)
    local right = Tip:GetRight()
    if right and UIParent and (UIParent:GetWidth() or 0) > 0
        and right > UIParent:GetWidth() - 8 then
        -- The row sits near the right edge: flip to its left side.
        Tip:ClearAllPoints()
        Tip:SetPoint("TOPRIGHT", target, "TOPLEFT", -10, 0)
    end
end

local function TipLeave()
    Tip:Hide()
end

-- ---------------- Toggle ----------------
local function TogglePaint(row)
    local on = row._get and row._get() or false
    local hover = row.__hover
    local r, g, b
    if on then
        if hover then
            r, g, b = B.AccentSoft()
        else
            r, g, b = ns.GetAccentColor()
        end
    else
        r, g, b = B.LINE[1], B.LINE[2], B.LINE[3]
        if hover then r, g, b = Lighten(r, g, b, 0.20) end
    end
    row.track:SetVertexColor(r, g, b, 1)
    if on then
        row.knob:SetVertexColor(0.96, 0.97, 0.98, 1)
    else
        row.knob:SetVertexColor(B.MUTED[1], B.MUTED[2], B.MUTED[3], 1)
    end
    row.knob:ClearAllPoints()
    if on then
        row.knob:SetPoint("RIGHT", row.track, "RIGHT", -KNOB_INSET, 0)
    else
        row.knob:SetPoint("LEFT", row.track, "LEFT", KNOB_INSET, 0)
    end
end

K.toggle = {
    New = function(view)
        local row = CreateFrame("Frame", nil, view)
        row.text = B.Font(row, 12, B.FG[1], B.FG[2], B.FG[3])
        row.text:SetPoint("LEFT", 0, 0)
        row.track = row:CreateTexture(nil, "ARTWORK")
        row.track:SetTexture(TRACK_TEX)
        row.track:SetSize(40, TOGGLE_H)
        row.track:SetPoint("RIGHT", -2, 0)
        Smooth(row.track)
        row.knob = row:CreateTexture(nil, "OVERLAY")
        row.knob:SetTexture(KNOB_TEX)
        row.knob:SetSize(KNOB, KNOB)
        Smooth(row.knob)
        row:EnableMouse(true)
        row:SetScript("OnEnter", function(r) r.__hover = true TogglePaint(r) TipEnter(r) end)
        row:SetScript("OnLeave", function(r) r.__hover = false TogglePaint(r) TipLeave() end)
        row:SetScript("OnMouseUp", function(r)
            if not r._get or not r._set then return end
            r._set(not r._get())
            TogglePaint(r) -- the knob moves at once; the page follows later
        end)
        return row
    end,
    Set = function(row, label, opts)
        opts = opts or {}
        row._get, row._set = opts.get, opts.set
        row.__tip = opts.tooltip
        row.text:SetText(label)
        TogglePaint(row)
        return ROW_H
    end,
}

-- ---------------- Slider ----------------
-- A rail, a fill and a thumb, dragged by hand -- no stock Slider, no
-- OnValueChanged round-trip: a fractional step (0.05) is shown and
-- stored exactly, never rounded away on the way in.
local function SliderFormat(v, step)
    if step and step < 1 then return string.format("%.2f", v) end
    return tostring(math.floor(v + 0.5))
end

local function SliderSnap(minV, maxV, step, raw)
    local v = minV + math.floor((raw - minV) / step + 0.5) * step
    if v < minV then v = minV elseif v > maxV then v = maxV end
    return math.floor(v * 1e6 + 0.5) / 1e6
end

local function SliderPaint(row)
    local v = (row._get and row._get()) or row._min
    local span = row._max - row._min
    local pct = span > 0 and (v - row._min) / span or 0
    if pct < 0 then pct = 0 elseif pct > 1 then pct = 1 end
    local ar, ag, ab = ns.GetAccentColor()
    -- The whole rail family wears the accent: the track at a low alpha,
    -- the fill at full strength on top of it, the thumb lifted toward
    -- white so it reads against both. SetColorTexture, not SetVertexColor
    -- on the fill: it was a BLACK solid tinted by the accent, and black
    -- times any colour is black -- which is exactly why the bar never
    -- showed its colour.
    row.track:SetColorTexture(ar, ag, ab, 1)
    row.track:SetVertexColor(1, 1, 1, 0.30)
    row.fill:SetColorTexture(ar, ag, ab, 1)
    local tr, tg, tb = Lighten(ar, ag, ab, 0.35)
    row.thumb:SetVertexColor(tr, tg, tb, 1)
    -- The rail stretches with wide rows: fill and thumb measure the
    -- rail it actually has, not the 140px minimum.
    local railW = row.track:GetWidth() or TRACK_W
    local px = math.floor(pct * railW + 0.5)
    row.fill:SetWidth(px)
    local tx = px
    if tx < 4 then tx = 4 elseif tx > railW - 4 then tx = railW - 4 end
    row.thumb:ClearAllPoints()
    row.thumb:SetPoint("LEFT", row.track, "LEFT", tx - 4, 0)
    row.value:SetText(SliderFormat(v, row._step))
end

local function SliderFromCursor(row)
    if not GetCursorPosition then return end
    local scale = row:GetEffectiveScale()
    local left, width = row.track:GetLeft(), row.track:GetWidth()
    if not scale or scale == 0 or not left or not width or width == 0 then return end
    local pct = (GetCursorPosition() / scale - left) / width
    if pct < 0 then pct = 0 elseif pct > 1 then pct = 1 end
    local v = SliderSnap(row._min, row._max, row._step,
        row._min + pct * (row._max - row._min))
    if v == row.__last then return end
    row.__last = v
    if row._set then row._set(v) end
    SliderPaint(row)
end

K.slider = {
    New = function(view)
        local row = CreateFrame("Frame", nil, view)
        row.text = B.Font(row, 12, B.FG[1], B.FG[2], B.FG[3])
        row.text:SetPoint("LEFT", 0, 0)
        row.value = B.Font(row, 11, B.MUTED[1], B.MUTED[2], B.MUTED[3])
        row.value:SetPoint("RIGHT", -2, 0)
        -- A FIXED-width value box, right-aligned: the rail anchors to this
        -- box's left edge, so every slider's rail starts and ends at the
        -- same x whatever the value's digit count ("0" vs "0.55" used to
        -- move the whole rail by ~20px, so no two rails lined up).
        row.value:SetWidth(36)
        row.value:SetJustifyH("RIGHT")
        row.track = B.Solid(row, "BACKGROUND", B.LINE[1], B.LINE[2], B.LINE[3], 1)
        row.track:SetSize(TRACK_W, 4)
        row.track:SetPoint("RIGHT", row.value, "LEFT", -10, 0)
        row.fill = B.Solid(row, "BORDER", 0, 0, 0, 1)
        row.fill:SetPoint("LEFT", row.track, "LEFT", 0, 0)
        row.fill:SetHeight(4)
        row.thumb = row:CreateTexture(nil, "ARTWORK")
        row.thumb:SetTexture(WHITE)
        row.thumb:SetSize(8, 14)
        row:EnableMouse(true)
        row:SetScript("OnMouseDown", function(r, btn)
            if btn ~= "LeftButton" or not GetCursorPosition then return end
            r.__drag = true
            r.__last = nil
            SliderFromCursor(r)
        end)
        row:SetScript("OnUpdate", function(r)
            if r.__drag then SliderFromCursor(r) end
        end)
        row:SetScript("OnMouseUp", function(r) r.__drag = false end)
        row:SetScript("OnEnter", function(r) TipEnter(r) end)
        row:SetScript("OnLeave", function() TipLeave() end)
        return row
    end,
    Set = function(row, label, opts)
        opts = opts or {}
        row._get, row._set = opts.get, opts.set
        row._min = opts.min or 0
        row._max = opts.max or 1
        row._step = opts.step or 1
        row.__last = nil
        row.__tip = opts.tooltip
        row.text:SetText(label)
        -- The rail fills the room between the label and the value box:
        -- wide rows stretch it, narrow ones keep the 140px minimum.
        local railW = (row:GetWidth() or 0)
            - (row.text:GetStringWidth() or 0) - 12 - 36 - 10
        if railW < TRACK_W then railW = TRACK_W end
        row.track:SetSize(railW, 4)
        SliderPaint(row)
        return ROW_H
    end,
}

-- ---------------- Dropdown ----------------
-- The button is as wide as the LONGEST value in its list, measured in
-- its own font and capped by the room left of the row's label, and the
-- value text is trimmed to what the button can show: a long current
-- value used to run past the button, over the chevron and into the
-- control beside it.
local function DropShow(btn, text)
    btn.__labelFull = text or ""
    local t = btn.__labelFull
    btn.label:SetText(t)
    local room = (btn:GetWidth() or DROP_W) - DROP_FIT_PAD
    if room <= 0 or t == "" then
        if room <= 0 then btn.label:SetText("") end
        return
    end
    local w = btn.label:GetStringWidth() or 0
    if w <= room then return end -- the whole value fits
    -- Average width of THIS text, so "..." lands where the button ends.
    local per = w > 0 and (w / #t) or DROP_PX
    local n = math.floor(room / per) - 3 -- "..." costs about 3 cells
    btn.label:SetText(n >= 1 and t:sub(1, n) .. "..." or "")
end

local function DropFit(btn)
    local row = btn:GetParent()
    if not row or not row.text or not btn._values then return end
    local best = ""
    for i = 1, #btn._values do
        local l = btn._values[i].label or ""
        if #l > #best then best = l end
    end
    btn.label:SetText(best)
    local natural = (btn.label:GetStringWidth() or 0) + DROP_FIT_PAD
    local avail = (row:GetWidth() or 320)
        - (row.text:GetStringWidth() or 0) - DROP_FIT_GAP
    -- The button never outgrows its longest value: on a wide row it
    -- sits at its natural width, right-anchored, and the gap between
    -- the label and the button is what grows.
    btn:SetWidth(math.max(DROP_FIT_MIN,
        math.min(natural, math.max(DROP_FIT_MIN, avail))))
    btn.__fit = { longest = natural, avail = avail, chars = #best }
end

local function DropPaint(btn)
    local cur = btn._get and btn._get()
    for _, v in ipairs(btn._values or EMPTY) do
        if v.value == cur then
            DropShow(btn, v.label)
            return
        end
    end
    local first = (btn._values or EMPTY)[1]
    DropShow(btn, first and first.label or "")
end

-- The list itself, in the addon's own look: one shared frame (built
-- lazily on first open), a dark Box panel with hairline edges like the
-- row tip, one button per visible value. Long lists page through a
-- wheel-driven window of DROP_MAX_ROWS; Escape closes it through
-- UISpecialFrames and an outside click through the overlay.
local DROP_LIST_NAME = "FUIRestedXPDropList"
local DROP_ITEM_H = 22
local DROP_MAX_ROWS = 14
B.DROP_ITEM_H, B.DROP_MAX_ROWS = DROP_ITEM_H, DROP_MAX_ROWS

local DropList, DropOverlay, DropState
local DropItems = {}
-- DropState = { btn = <the opener>, values = {...}, offset = <first shown> }

local function DropClose()
    if DropOverlay then DropOverlay:Hide() end
    if DropList then DropList:Hide() end
    DropState = nil
end
ns.CloseDropList = DropClose

-- The frame, the items, the open state and the overlay, for the tests:
-- they cannot enumerate frame children, so the list hands them over.
ns.DropListState = function()
    return DropList, DropItems, DropState, DropOverlay
end

local function DropItemPaint(it, selected, hover)
    if selected then
        local r, g, b = B.AccentSoft()
        it.text:SetTextColor(r, g, b, 1)
    elseif hover then
        it.text:SetTextColor(B.FG[1], B.FG[2], B.FG[3], 1)
    else
        it.text:SetTextColor(B.MUTED[1], B.MUTED[2], B.MUTED[3], 1)
    end
    if hover then
        it.bg:SetColorTexture(1, 1, 1, 0.08)
    else
        it.bg:SetColorTexture(0, 0, 0, 0)
    end
end

local function DropItem(i)
    local it = DropItems[i]
    if not it then
        it = CreateFrame("Button", nil, DropList)
        it.bg = it:CreateTexture(nil, "BACKGROUND")
        it.bg:SetAllPoints()
        it.text = B.Font(it, 12, B.MUTED[1], B.MUTED[2], B.MUTED[3])
        it.text:SetPoint("LEFT", it, "LEFT", 10, 0)
        it:SetScript("OnEnter", function(b)
            b.__hover = true
            DropItemPaint(b, b.__selected, true)
        end)
        it:SetScript("OnLeave", function(b)
            b.__hover = false
            DropItemPaint(b, b.__selected, false)
        end)
        it:SetScript("OnClick", function(b)
            local st = DropState
            local v = st and st.values[b.__idx]
            if st and st.btn and st.btn._set and v then
                st.btn._set(v.value)
                DropPaint(st.btn)
            end
            DropClose()
        end)
        DropItems[i] = it
    end
    return it
end

-- Draw the state's visible window: texts, selection, width from the
-- longest shown label (never narrower than the button), anchor under
-- the button, flipped above it when the screen bottom is near.
local function DropLayout()
    local st = DropState
    if not (st and DropList) then return end
    local values, n = st.values, #st.values
    local cur = st.btn._get and st.btn._get()
    local maxOff = math.max(0, n - DROP_MAX_ROWS)
    if st.offset > maxOff then st.offset = maxOff end
    if st.offset < 0 then st.offset = 0 end
    local shown = math.min(n, DROP_MAX_ROWS)
    local widest = 0
    for i = 1, shown do
        local it, v = DropItem(i), values[st.offset + i]
        it.__idx = st.offset + i
        it.__selected = (v.value == cur)
        it.__hover = false
        it.text:SetText(v.label)
        DropItemPaint(it, it.__selected, false)
        local w = it.text:GetStringWidth() or 0
        if w > widest then widest = w end
    end
    local listW = math.max((st.btn:GetWidth() or 150), widest + 24)
    if listW > 320 then listW = 320 end
    DropList:SetSize(listW, shown * DROP_ITEM_H + 8)
    for i = 1, shown do
        local it = DropItems[i]
        it:Show()
        it:SetSize(listW - 8, DROP_ITEM_H)
        it:ClearAllPoints()
        if i == 1 then
            it:SetPoint("TOPLEFT", DropList, "TOPLEFT", 4, -4)
        else
            it:SetPoint("TOPLEFT", DropItems[i - 1], "BOTTOMLEFT", 0, 0)
        end
    end
    for i = shown + 1, #DropItems do DropItems[i]:Hide() end
    DropList:ClearAllPoints()
    DropList:SetPoint("TOPLEFT", st.btn, "BOTTOMLEFT", 0, -2)
    local bottom = DropList:GetBottom()
    if bottom and bottom < 8 then
        -- No room below: open above the button instead.
        DropList:ClearAllPoints()
        DropList:SetPoint("BOTTOMLEFT", st.btn, "TOPLEFT", 0, 2)
    end
end

local function DropScroll(dir)
    local st = DropState
    if not st then return end
    local maxOff = math.max(0, #st.values - DROP_MAX_ROWS)
    if maxOff == 0 then return end
    if dir and dir > 0 then
        st.offset = st.offset - 3
    else
        st.offset = st.offset + 3
    end
    DropLayout()
end

local function DropBuildList()
    DropOverlay = CreateFrame("Button", nil, UIParent)
    if DropOverlay.SetAllPoints then DropOverlay:SetAllPoints(UIParent) end
    DropOverlay:SetScript("OnClick", DropClose)
    DropList = CreateFrame("Frame", DROP_LIST_NAME, UIParent)
    DropList:SetFrameStrata("TOOLTIP")
    if DropList.SetClampedToScreen then DropList:SetClampedToScreen(true) end
    DropList.bg, DropList.edges = Box(DropList, 0.045, 0.047, 0.055, 0.99)
    for i = 1, #(DropList.edges or EMPTY) do
        DropList.edges[i]:SetColorTexture(B.LINE[1], B.LINE[2], B.LINE[3], 1)
    end
    DropList:EnableMouse(true)
    DropList:EnableMouseWheel(true)
    DropList:SetScript("OnMouseWheel", function(_, dir) DropScroll(dir) end)
    -- Escape closes the list like any Blizzard panel; OnHide drops the
    -- overlay and the state with it, so no invisible catcher survives.
    DropList:SetScript("OnHide", DropClose)
    tinsert(UISpecialFrames, DROP_LIST_NAME)
end

local function DropStep(btn)
    -- The list cannot show: step to the next value instead of showing
    -- nothing -- the row stays usable everywhere.
    local values = btn._values
    if btn._get and btn._set and values and #values > 0 then
        local cur = btn._get()
        local idx = 0
        for i, v in ipairs(values) do
            if v.value == cur then idx = i break end
        end
        local next = values[idx % #values + 1]
        if next then
            btn._set(next.value)
            DropPaint(btn)
        end
    end
end

local function DropOpen(btn)
    local values = btn._values
    if not values or #values == 0 then return end
    -- A second click on the opener closes its own list.
    if DropState and DropState.btn == btn
        and DropList and DropList:IsShown() then
        DropClose()
        return
    end
    local ok = pcall(function()
        if not DropList then DropBuildList() end
        DropState = { btn = btn, values = values, offset = 0 }
        -- Scroll the current value into view on long lists.
        local cur = btn._get and btn._get()
        if cur ~= nil and #values > DROP_MAX_ROWS then
            for i, v in ipairs(values) do
                if v.value == cur then
                    local maxOff = #values - DROP_MAX_ROWS
                    local off = i - 4
                    if off < 0 then off = 0 end
                    if off > maxOff then off = maxOff end
                    DropState.offset = off
                    break
                end
            end
        end
        DropOverlay:Show()
        DropLayout()
        DropList:Show()
    end)
    if not ok then
        DropClose()
        DropStep(btn)
    end
end

K.dropdown = {
    New = function(view)
        local row = CreateFrame("Frame", nil, view)
        row.text = B.Font(row, 12, B.FG[1], B.FG[2], B.FG[3])
        row.text:SetPoint("LEFT", 0, 0)
        local btn = CreateFrame("Button", nil, row)
        btn:SetSize(DROP_W, DROP_H)
        btn:SetPoint("RIGHT", -2, 0)
        btn.bg, btn.edges = Box(btn, 0.10, 0.11, 0.12, 1)
        btn.label = B.Font(btn, 12, B.FG[1], B.FG[2], B.FG[3])
        btn.label:SetPoint("LEFT", btn, "LEFT", 8, 0)
        btn.chevron = btn:CreateTexture(nil, "OVERLAY")
        btn.chevron:SetTexture(B.CHEVRON_TEX)
        btn.chevron:SetSize(B.CHEVRON, B.CHEVRON)
        btn.chevron:SetPoint("RIGHT", btn, "RIGHT", -6, 0)
        btn.chevron:SetRotation(math.pi) -- art points up: half a turn down
        btn.chevron:SetVertexColor(B.MUTED[1], B.MUTED[2], B.MUTED[3], 1)
        -- Our own list opens on click (a second click closes it).
        btn:SetScript("OnClick", DropOpen)
        -- the tip rides both halves: the label area and the button
        row:SetScript("OnEnter", function(r) TipEnter(r) end)
        row:SetScript("OnLeave", function() TipLeave() end)
        btn:SetScript("OnEnter", function() TipEnter(row) end)
        btn:SetScript("OnLeave", function() TipLeave() end)
        row.btn = btn
        return row
    end,
    Set = function(row, label, opts)
        opts = opts or {}
        -- A redraw dismisses a stale list: its values may just have changed.
        DropClose()
        local btn = row.btn
        btn._values, btn._get, btn._set = opts.values, opts.get, opts.set
        row.__tip, btn.__tip = opts.tooltip, opts.tooltip
        row.text:SetText(label)
        DropFit(btn)   -- the width follows the longest value
        DropPaint(btn) -- then the value is shown (trimmed if it must)
        return ROW_H
    end,
}

-- ---------------- Color picker ----------------
-- The addon's OWN picker -- no Blizzard ColorPickerFrame anywhere:
-- the same dark Box panel as the row tip, a hue/saturation wheel with
-- brightness and transparency bars (like WoW's own; the transparency
-- bar stands down when the colour carries no alpha), a hex field, a
-- current/new preview, and OK / Cancel in the addon's button look.
-- Wheel, bars and hex stay in sync both ways. Changes apply live;
-- Cancel (or Escape, or hiding the options) puts back the colour the
-- swatch opened on.
local function PickerPaint(sw)
    if not sw._get then return end
    local r, g, b, a = sw._get()
    sw.bg:SetColorTexture(r or 1, g or 1, b or 1,
        (sw._hasAlpha and a) or 1)
end

-- The picker frame, its overlay and its open state (one shared picker
-- for every swatch). The state doubles as the test handle: the UI
-- scripts and the tests drive the same setChannel / setHex / ok /
-- cancel methods, so a passing test proves the live paths.
local PICKER_NAME = "FUIRestedXPColorPicker"
local PICKER_W = 300
local WHEEL = 168 -- the hue/saturation disc, square; the luma bar matches it
local WHEEL_TEX = TEX .. "fui-color-wheel.tga"
local LUMA_TEX = TEX .. "fui-color-luma.tga"
local ALPHA_TEX = TEX .. "fui-color-alpha.tga"
local CHECKER_TEX = TEX .. "fui-color-checker.tga"

-- Two-argument arctangent without math.atan2 (gone from some Lua
-- runtimes the tests run): the wheel maps it, the marker inverts it.
local function Atan2(y, x)
    if x > 0 then return math.atan(y / x) end
    if x < 0 then return math.atan(y / x) + (y >= 0 and math.pi or -math.pi) end
    if y > 0 then return math.pi / 2 end
    return -math.pi / 2
end

local function RgbToHsv(r, g, b)
    local mx, mn = math.max(r, g, b), math.min(r, g, b)
    local h, s, v = 0, 0, mx
    if mx > 0 then s = (mx - mn) / mx end
    if s > 0 then
        if mx == r then
            h = ((g - b) / (mx - mn)) / 6
        elseif mx == g then
            h = (2 + (b - r) / (mx - mn)) / 6
        else
            h = (4 + (r - g) / (mx - mn)) / 6
        end
        h = h % 1
    end
    return h, s, v
end

local function HsvToRgb(h, s, v)
    h = (h or 0) % 1
    local i = math.floor(h * 6)
    local f = h * 6 - i
    local p = v * (1 - s)
    local q = v * (1 - f * s)
    local t = v * (1 - (1 - f) * s)
    i = i % 6
    if i == 0 then return v, t, p end
    if i == 1 then return q, v, p end
    if i == 2 then return p, v, t end
    if i == 3 then return p, q, v end
    if i == 4 then return t, p, v end
    return v, p, q
end
local PickerFrame, PickerOverlay, PickerState

local function PickerClose()
    if PickerOverlay then PickerOverlay:Hide() end
    if PickerFrame then PickerFrame:Hide() end
    PickerState = nil
end
ns.CloseColorPicker = PickerClose
ns.ColorPickerState = function() return PickerFrame, PickerState end

-- Push the state's live colour through the row's own set, then repaint
-- everything showing it. The row may have been recycled by a redraw
-- while the picker stood open: only a row still bound to our set is
-- repainted directly, the redraw paints the rest.
local function PickerPush(st)
    if st.set then
        st.set(st.r, st.g, st.b, st.hasAlpha and st.a or nil)
    end
    if st.sw and st.sw._set == st.set then PickerPaint(st.sw) end
    if st.paint then st.paint() end
end

local function PickerButton(parent, text, onClick)
    local btn = CreateFrame("Button", nil, parent)
    btn.bg, btn.edges = Box(btn, 0.10, 0.11, 0.12, 1)
    btn.label = B.Font(btn, 12, B.FG[1], B.FG[2], B.FG[3])
    btn.label:SetPoint("CENTER")
    btn.label:SetText(text)
    local w = math.ceil(btn.label:GetStringWidth()) + 36
    if w < 96 then w = 96 end
    btn:SetSize(w, 24)
    local function paint()
        local ar, ag, ab = ns.GetAccentColor()
        if btn.__hover then
            btn.bg:SetColorTexture(0.15, 0.16, 0.17, 1)
        else
            btn.bg:SetColorTexture(0.10, 0.11, 0.12, 1)
        end
        for i = 1, #(btn.edges or EMPTY) do
            if btn.__hover then
                local lr, lg, lb = Lighten(ar, ag, ab, 0.30)
                btn.edges[i]:SetColorTexture(lr, lg, lb, 1)
            else
                btn.edges[i]:SetColorTexture(ar, ag, ab, 1)
            end
        end
        btn.label:SetTextColor(ar, ag, ab, 1)
    end
    btn:SetScript("OnEnter", function(b) b.__hover = true paint() end)
    btn:SetScript("OnLeave", function(b) b.__hover = false paint() end)
    btn:SetScript("OnClick", function(b) if onClick then onClick() end end)
    paint()
    return btn
end

local function PickerHex(st)
    local s = st.hexBox:GetText() or ""
    s = s:gsub("^#", ""):gsub("%s", "")
    local r, g, b, a
    if #s == 6 or (#s == 8 and st.hasAlpha) then
        r = tonumber(s:sub(1, 2), 16)
        g = tonumber(s:sub(3, 4), 16)
        b = tonumber(s:sub(5, 6), 16)
        if #s == 8 then a = tonumber(s:sub(7, 8), 16) end
    end
    if not (r and g and b) then return false end
    st.r, st.g, st.b = r / 255, g / 255, b / 255
    if a and st.hasAlpha then st.a = a / 255 end
    st.h, st.s, st.v = RgbToHsv(st.r, st.g, st.b)
    PickerPush(st)
    return true
end

-- Repaint everything showing the colour: hex field (silently), new
-- preview, wheel marker, luma and transparency bars with their thumbs.
local function PickerPaintAll(st)
    if st.wheelMarker and st.wheel then
        -- Inverse of the click mapping below: hue is the clockwise
        -- angle from the top, saturation the radius.
        local th = st.h * 2 * math.pi
        local R = WHEEL / 2
        local mx = R + st.s * math.sin(th) * R
        local my = R - st.s * math.cos(th) * R
        st.wheelMarker:ClearAllPoints()
        st.wheelMarker:SetPoint("CENTER", st.wheel, "TOPLEFT", mx, -my)
    end
    if st.lumaTex and st.lumaBar and st.lumaThumb then
        -- The bar is a white-to-black ramp: tinted with the hue at full
        -- brightness it reads as that hue's bright-to-dark scale.
        local hr, hg, hb = HsvToRgb(st.h, st.s, 1)
        st.lumaTex:SetVertexColor(hr, hg, hb, 1)
        st.lumaThumb:ClearAllPoints()
        st.lumaThumb:SetPoint("CENTER", st.lumaBar, "TOP",
            0, -(1 - st.v) * WHEEL)
    end
    if st.alphaTex and st.alphaBar and st.alphaThumb then
        -- The overlay is a white fading ramp: tinted with the live
        -- colour over the checker, it reads as that colour fading out.
        st.alphaTex:SetVertexColor(st.r, st.g, st.b, 1)
        st.alphaThumb:ClearAllPoints()
        st.alphaThumb:SetPoint("CENTER", st.alphaBar, "TOP",
            0, -(1 - st.a) * WHEEL)
    end
    st.__sync = true
    local hex = string.format("%02X%02X%02X",
        math.floor(st.r * 255 + 0.5),
        math.floor(st.g * 255 + 0.5),
        math.floor(st.b * 255 + 0.5))
    if st.hasAlpha then
        hex = hex .. string.format("%02X", math.floor(st.a * 255 + 0.5))
    end
    st.hexBox:SetText(hex)
    st.__sync = false
    st.previewNew:SetColorTexture(st.r, st.g, st.b,
        (st.hasAlpha and st.a) or 1)
end

-- Click/drag on the wheel: hue is the clockwise angle from the top
-- (red sits there, like WoW's wheel), saturation the radius. The
-- brightness the wheel shows at stays untouched.
local function PickerWheelFromCursor(btn)
    local st = PickerState
    if not st or not GetCursorPosition then return end
    local scale = btn:GetEffectiveScale() or 1
    if scale == 0 then scale = 1 end
    local left, top, size = btn:GetLeft(), btn:GetTop(), btn:GetWidth()
    if not left or not top or not size or size < 1 then return end
    local x, y = GetCursorPosition()
    x, y = x / scale, y / scale
    -- UI Y grows upward: above the center is positive, like the wheel
    -- art (red on top). The old sign read it upside down, so every
    -- click landed on the opposite colour.
    local dx, dyUp = x - (left + size / 2), y - (top - size / 2)
    local s = math.sqrt(dx * dx + dyUp * dyUp) / (size / 2)
    if s > 1 then s = 1 end
    st.h = (Atan2(dx, dyUp) / (2 * math.pi)) % 1
    st.s = s
    st.r, st.g, st.b = HsvToRgb(st.h, st.s, st.v)
    PickerPush(st)
end

-- Click/drag on the transparency bar: top is opaque, bottom is gone.
-- Hue, saturation and brightness stay untouched.
local function PickerAlphaFromCursor(bar)
    local st = PickerState
    if not st or not st.hasAlpha or not GetCursorPosition then return end
    local scale = bar:GetEffectiveScale() or 1
    if scale == 0 then scale = 1 end
    local top, height = bar:GetTop(), bar:GetHeight()
    if not top or not height or height < 1 then return end
    local _, y = GetCursorPosition()
    -- Same Y-up fix as the wheel: the opaque end is the top.
    local a = 1 - (top - y / scale) / height
    if a < 0 then a = 0 elseif a > 1 then a = 1 end
    st.a = a
    PickerPush(st)
end

-- Click/drag on the brightness bar: top is full, bottom is black.
local function PickerLumaFromCursor(bar)
    local st = PickerState
    if not st or not GetCursorPosition then return end
    local scale = bar:GetEffectiveScale() or 1
    if scale == 0 then scale = 1 end
    local top, height = bar:GetTop(), bar:GetHeight()
    if not top or not height or height < 1 then return end
    local _, y = GetCursorPosition()
    -- Same Y-up fix as the wheel: full brightness is the top.
    local v = 1 - (top - y / scale) / height
    if v < 0 then v = 0 elseif v > 1 then v = 1 end
    st.v = v
    st.r, st.g, st.b = HsvToRgb(st.h, st.s, st.v)
    PickerPush(st)
end

local function PickerBuild()
    PickerOverlay = CreateFrame("Button", nil, UIParent)
    if PickerOverlay.SetAllPoints then PickerOverlay:SetAllPoints(UIParent) end
    PickerOverlay:SetScript("OnClick", function()
        -- Outside click keeps the live colour: it is already written.
        if PickerState then PickerState.__accepted = true end
        PickerClose()
    end)
    local f = CreateFrame("Frame", PICKER_NAME, UIParent)
    f:SetFrameStrata("TOOLTIP")
    if f.SetClampedToScreen then f:SetClampedToScreen(true) end
    f.bg, f.edges = Box(f, 0.045, 0.047, 0.055, 0.99)
    for i = 1, #(f.edges or EMPTY) do
        f.edges[i]:SetColorTexture(B.LINE[1], B.LINE[2], B.LINE[3], 1)
    end
    f:EnableMouse(true)
    -- Escape (or any hide) without OK restores the opening colour:
    -- the live values never survive a dismissal that was not a choice.
    f:SetScript("OnHide", function()
        local st = PickerState
        PickerState = nil
        if PickerOverlay then PickerOverlay:Hide() end
        if st and not st.__accepted and st.set then
            st.set(st.r0, st.g0, st.b0, st.hasAlpha and st.a0 or nil)
            if st.sw and st.sw._set == st.set then PickerPaint(st.sw) end
        end
    end)
    tinsert(UISpecialFrames, PICKER_NAME)
    f.title = B.Font(f, 13, B.FG[1], B.FG[2], B.FG[3])
    f.title:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -10)
    PickerFrame = f
end

-- The preview, hex and button rows live on the frame itself: one set,
-- reused by every opening, never widowed.

-- Lay the rows top-down for this opening.
local function PickerLayout(st)
    local f = PickerFrame
    local rows = {}
    local function place(child, h)
        child:Show()
        child:ClearAllPoints()
        if #rows == 0 then
            child:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -34)
            child:SetPoint("TOPRIGHT", f, "TOPRIGHT", -12, -34)
        else
            child:SetPoint("TOPLEFT", rows[#rows], "BOTTOMLEFT", 0, -2)
            child:SetPoint("TOPRIGHT", rows[#rows], "BOTTOMRIGHT", 0, -2)
        end
        rows[#rows + 1] = child
    end
    f.title:SetText(st.title or "Color")
    -- Wheel + brightness bar, like WoW's picker: the disc first, so it
    -- reads as the picker's main control, preview and hex below it.
    if not f.wheelRow then
        local wrow = CreateFrame("Frame", nil, f)
        wrow:SetHeight(WHEEL)
        local wheel = CreateFrame("Button", nil, wrow)
        wheel:SetSize(WHEEL, WHEEL)
        wheel:SetPoint("LEFT", 0, 0)
        local wtex = wheel:CreateTexture(nil, "ARTWORK")
        wtex:SetTexture(WHEEL_TEX)
        wtex:SetAllPoints()
        wheel.__tip = "Hue and saturation -- click or drag."
        wheel:SetScript("OnEnter", function(b) TipEnter(b) end)
        wheel:SetScript("OnLeave", function() TipLeave() end)
        wheel:SetScript("OnMouseDown", function(b, btn)
            if btn ~= "LeftButton" or not GetCursorPosition then return end
            b.__drag = true
            PickerWheelFromCursor(b)
        end)
        wheel:SetScript("OnUpdate", function(b)
            if b.__drag then PickerWheelFromCursor(b) end
        end)
        wheel:SetScript("OnMouseUp", function(b) b.__drag = false end)
        -- Ring on every colour: a black plate with a white core. It never
        -- intercepts clicks -- those belong to the wheel under it.
        local marker = CreateFrame("Frame", nil, wheel)
        marker:SetSize(12, 12)
        marker:EnableMouse(false)
        local mb = marker:CreateTexture(nil, "OVERLAY")
        mb:SetColorTexture(0, 0, 0, 1)
        mb:SetAllPoints()
        local mw = marker:CreateTexture(nil, "OVERLAY", nil, 1)
        mw:SetColorTexture(1, 1, 1, 1)
        mw:SetSize(8, 8)
        mw:SetPoint("CENTER")
        local bar = CreateFrame("Button", nil, wrow)
        bar:SetSize(22, WHEEL)
        bar:SetPoint("LEFT", wheel, "RIGHT", 12, 0)
        local vtex = bar:CreateTexture(nil, "ARTWORK")
        vtex:SetTexture(LUMA_TEX)
        vtex:SetAllPoints()
        bar.__tip = "Brightness -- click or drag."
        bar:SetScript("OnEnter", function(b) TipEnter(b) end)
        bar:SetScript("OnLeave", function() TipLeave() end)
        bar:SetScript("OnMouseDown", function(b, btn)
            if btn ~= "LeftButton" or not GetCursorPosition then return end
            b.__drag = true
            PickerLumaFromCursor(b)
        end)
        bar:SetScript("OnUpdate", function(b)
            if b.__drag then PickerLumaFromCursor(b) end
        end)
        bar:SetScript("OnMouseUp", function(b) b.__drag = false end)
        local thumb = CreateFrame("Frame", nil, bar)
        thumb:SetSize(28, 10)
        thumb:EnableMouse(false)
        local tb = thumb:CreateTexture(nil, "OVERLAY")
        tb:SetColorTexture(0, 0, 0, 1)
        tb:SetAllPoints()
        local tw = thumb:CreateTexture(nil, "OVERLAY", nil, 1)
        tw:SetColorTexture(1, 1, 1, 1)
        tw:SetSize(24, 6)
        tw:SetPoint("CENTER")
        -- Transparency bar, WoW-style beside the brightness one: the
        -- checker bed with the fading colour over it. Built once, shown
        -- only while the opened colour carries an alpha.
        local abar = CreateFrame("Button", nil, wrow)
        abar:SetSize(22, WHEEL)
        abar:SetPoint("LEFT", bar, "RIGHT", 12, 0)
        local ctex = abar:CreateTexture(nil, "BACKGROUND")
        ctex:SetTexture(CHECKER_TEX)
        ctex:SetAllPoints()
        local atex = abar:CreateTexture(nil, "ARTWORK")
        atex:SetTexture(ALPHA_TEX)
        atex:SetAllPoints()
        abar.__tip = "Transparency -- click or drag."
        abar:SetScript("OnEnter", function(b) TipEnter(b) end)
        abar:SetScript("OnLeave", function() TipLeave() end)
        abar:SetScript("OnMouseDown", function(b, btn)
            if btn ~= "LeftButton" or not GetCursorPosition then return end
            b.__drag = true
            PickerAlphaFromCursor(b)
        end)
        abar:SetScript("OnUpdate", function(b)
            if b.__drag then PickerAlphaFromCursor(b) end
        end)
        abar:SetScript("OnMouseUp", function(b) b.__drag = false end)
        local athumb = CreateFrame("Frame", nil, abar)
        athumb:SetSize(28, 10)
        athumb:EnableMouse(false)
        local atb = athumb:CreateTexture(nil, "OVERLAY")
        atb:SetColorTexture(0, 0, 0, 1)
        atb:SetAllPoints()
        local atw = athumb:CreateTexture(nil, "OVERLAY", nil, 1)
        atw:SetColorTexture(1, 1, 1, 1)
        atw:SetSize(24, 6)
        atw:SetPoint("CENTER")
        f.wheelRow, f.wheel = wrow, wheel
        f.wheelMarker, f.lumaBar = marker, bar
        f.lumaTex, f.lumaThumb = vtex, thumb
        f.alphaBar, f.alphaTex, f.alphaThumb = abar, atex, athumb
    end
    st.wheel, st.wheelMarker = f.wheel, f.wheelMarker
    st.lumaBar, st.lumaTex, st.lumaThumb = f.lumaBar, f.lumaTex, f.lumaThumb
    st.alphaBar, st.alphaTex, st.alphaThumb = f.alphaBar, f.alphaTex, f.alphaThumb
    -- No alpha on this colour: the transparency bar stands down (the
    -- wheel row keeps its size, so the picker never jumps around).
    if st.hasAlpha then f.alphaBar:Show() else f.alphaBar:Hide() end
    place(f.wheelRow)
    -- Preview: the opening colour beside the live one.
    if not f.prevRow then
        local prow = CreateFrame("Frame", nil, f)
        prow:SetHeight(26)
        prow.cur = B.Solid(prow, "BACKGROUND", 1, 1, 1, 1)
        prow.cur:SetSize(SWATCH_W, SWATCH_H)
        prow.cur:SetPoint("LEFT", 0, 0)
        prow.new = B.Solid(prow, "BACKGROUND", 1, 1, 1, 1)
        prow.new:SetSize(SWATCH_W, SWATCH_H)
        prow.new:SetPoint("LEFT", prow.cur, "RIGHT", 12, 0)
        prow.hint = B.Font(prow, 11, B.MUTED[1], B.MUTED[2], B.MUTED[3])
        prow.hint:SetPoint("LEFT", prow.new, "RIGHT", 10, 0)
        prow.hint:SetText("current / new")
        f.prevRow = prow
    end
    f.prevRow.cur:SetColorTexture(st.r0, st.g0, st.b0,
        (st.hasAlpha and st.a0) or 1)
    st.previewNew = f.prevRow.new
    place(f.prevRow)
    -- Hex row: label, box, hint.
    if not f.hexRow then
        local hrow = CreateFrame("Frame", nil, f)
        hrow:SetHeight(26)
        hrow.lab = B.Font(hrow, 12, B.FG[1], B.FG[2], B.FG[3])
        hrow.lab:SetPoint("LEFT", 0, 0)
        hrow.lab:SetText("Hex")
        local box = CreateFrame("EditBox", nil, hrow)
        box:SetSize(110, 22)
        box:SetPoint("RIGHT", -2, 0)
        box:SetAutoFocus(false)
        if ns.ApplyFont then ns.ApplyFont(box, nil, 12) end
        box.bg, box.edges = Box(box, 0.10, 0.11, 0.12, 1)
        box:SetScript("OnEnterPressed", function(b)
            if PickerHex(PickerState) then b:ClearFocus() end
        end)
        box:SetScript("OnTextChanged", function()
            -- Programmatic fills (after every wheel/bar move) are not edits.
            if PickerState and not PickerState.__sync then
                PickerHex(PickerState)
            end
        end)
        box:SetScript("OnEscapePressed", function(b)
            b:ClearFocus()
            PickerClose()
        end)
        hrow.box = box
        f.hexRow = hrow
    end
    st.hexBox = f.hexRow.box
    place(f.hexRow)
    -- OK / Cancel.
    if not f.btnRow then
        local brow = CreateFrame("Frame", nil, f)
        brow:SetHeight(30)
        brow.ok = PickerButton(brow, "OK", function()
            if PickerState then PickerState.__accepted = true end
            PickerClose()
        end)
        brow.ok:SetPoint("RIGHT", brow, "RIGHT", -2, 0)
        brow.cancel = PickerButton(brow, "Cancel", function()
            PickerClose()
        end)
        brow.cancel:SetPoint("RIGHT", brow.ok, "LEFT", -8, 0)
        f.btnRow = brow
    end
    place(f.btnRow)
    st.rows = rows
    local h = 34
    for _, child in ipairs(rows) do h = h + (child:GetHeight() or 26) + 2 end
    f:SetSize(PICKER_W, h + 30 + 8)
end

local function PickerOpen(btn)
    if not btn._get then return end
    -- A second click on the opener keeps the live colour and closes.
    if PickerState and PickerState.sw == btn
        and PickerFrame and PickerFrame:IsShown() then
        PickerState.__accepted = true
        PickerClose()
        return
    end
    local ok = pcall(function()
        if not PickerFrame then PickerBuild() end
        local r, g, b, a = btn._get()
        r, g, b = r or 1, g or 1, b or 1
        a = a or 1
        local h, s, v = RgbToHsv(r, g, b)
        local st = {
            sw = btn,
            set = btn._set,
            hasAlpha = btn._hasAlpha and true or false,
            title = btn._title or "Color",
            r0 = r, g0 = g, b0 = b, a0 = a,
            r = r, g = g, b = b, a = a,
            h = h, s = s, v = v,
        }
        -- The state's own methods: the UI scripts above and the tests
        -- below drive these, never the frame children directly.
        st.setChannel = function(c, v)
            if c ~= "r" and c ~= "g" and c ~= "b" and c ~= "a" then return end
            if c == "a" and not st.hasAlpha then return end
            if type(v) ~= "number" then return end
            if v < 0 then v = 0 elseif v > 1 then v = 1 end
            st[c] = v
            st.h, st.s, st.v = RgbToHsv(st.r, st.g, st.b)
            PickerPush(st)
        end
        -- The wheel and the bars drive these: same push for every
        -- control, so each one paints every other one.
        st.setHS = function(h, s)
            if type(h) ~= "number" or type(s) ~= "number" then return end
            st.h, st.s = h % 1, math.min(1, math.max(0, s))
            st.r, st.g, st.b = HsvToRgb(st.h, st.s, st.v)
            PickerPush(st)
        end
        st.setV = function(v)
            if type(v) ~= "number" then return end
            st.v = math.min(1, math.max(0, v))
            st.r, st.g, st.b = HsvToRgb(st.h, st.s, st.v)
            PickerPush(st)
        end
        st.setHex = function(s)
            local box, keep = st.hexBox, (st.hexBox and st.hexBox:GetText())
            if box then box:SetText(s or "") end
            local good = PickerHex(st)
            if not good and box then box:SetText(keep or "") end
            return good
        end
        st.ok = function()
            st.__accepted = true
            PickerClose()
        end
        st.cancel = function()
            -- Restore here, not in OnHide: a hidden frame fires OnHide
            -- on the live client but not under every test harness.
            -- Either way the opening colour comes back exactly once.
            st.set(st.r0, st.g0, st.b0, st.hasAlpha and st.a0 or nil)
            if st.sw and st.sw._set == st.set then PickerPaint(st.sw) end
            st.__accepted = true
            PickerClose()
        end
        st.paint = function() PickerPaintAll(st) end
        PickerState = st
        PickerLayout(st)
        PickerPaintAll(st)
        PickerOverlay:Show()
        PickerFrame:ClearAllPoints()
        PickerFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        PickerFrame:Show()
    end)
    if not ok then PickerClose() end
end

K.colorpicker = {
    New = function(view)
        local row = CreateFrame("Frame", nil, view)
        row.text = B.Font(row, 12, B.FG[1], B.FG[2], B.FG[3])
        row.text:SetPoint("LEFT", 0, 0)
        local sw = CreateFrame("Button", nil, row)
        sw:SetSize(SWATCH_W, SWATCH_H)
        sw:SetPoint("RIGHT", -2, 0)
        sw.bg, sw.edges = Box(sw, 1, 1, 1, 1)
        row:SetScript("OnEnter", function(r) TipEnter(r) end)
        row:SetScript("OnLeave", function() TipLeave() end)
        sw:SetScript("OnEnter", function() TipEnter(row) end)
        sw:SetScript("OnLeave", function() TipLeave() end)
        sw:SetScript("OnClick", function(btn) PickerOpen(btn) end)
        row.sw = sw
        return row
    end,
    Set = function(row, label, opts)
        opts = opts or {}
        local sw = row.sw
        sw._get, sw._set, sw._hasAlpha = opts.get, opts.set, opts.hasAlpha
        sw._title = label
        row.__tip, sw.__tip = opts.tooltip, opts.tooltip
        row.text:SetText(label)
        -- The row's own swatch wears the alpha too: a translucent
        -- colour reads darker over the dark row -- honest.
        PickerPaint(sw)
        -- The swatch rests while another source owns the colour.
        local dim = opts.dim
        if dim then sw:Disable() else sw:Enable() end
        sw:SetAlpha(dim and 0.35 or 1)
        row.text:SetAlpha(dim and 0.35 or 1)
        return ROW_H
    end,
}

-- ---------------- Button ----------------
local function ButtonPaint(btn)
    local r, g, b = btn.__r, btn.__g, btn.__b
    local er, eg, eb = btn.__er or 0, btn.__eg or 0, btn.__eb or 0
    if btn.__hover then
        r, g, b = Lighten(r, g, b, 0.10)
        er, eg, eb = Lighten(er, eg, eb, 0.30)
    end
    btn.bg:SetColorTexture(r, g, b, 1)
    for i = 1, #(btn.edges or EMPTY) do
        btn.edges[i]:SetColorTexture(er, eg, eb, 1)
    end
end

K.button = {
    New = function(view)
        local row = CreateFrame("Frame", nil, view)
        local btn = CreateFrame("Button", nil, row)
        btn.bg, btn.edges = Box(btn, 0.10, 0.11, 0.12, 1)
        btn.__r, btn.__g, btn.__b = 0.10, 0.11, 0.12
        btn.label = B.Font(btn, 12, B.FG[1], B.FG[2], B.FG[3])
        btn.label:SetPoint("CENTER")
        btn:SetScript("OnEnter", function(b) b.__hover = true ButtonPaint(b) TipEnter(b) end)
        btn:SetScript("OnLeave", function(b) b.__hover = false ButtonPaint(b) TipLeave() end)
        btn:SetScript("OnClick", function(b)
            if b._onCall then b._onCall() end
        end)
        row.btn = btn
        return row
    end,
    Set = function(row, text, opts)
        opts = opts or {}
        local btn = row.btn
        btn._onCall = opts.onCall
        btn.__tip = opts.tooltip
        btn.label:SetText(text)
        local w = opts.width
        if not w then
            w = math.ceil(btn.label:GetStringWidth()) + 36
            if w < 120 then w = 120 end
        end
        btn:SetSize(w, 24)
        btn:ClearAllPoints()
        btn:SetPoint("CENTER", row, "CENTER", 0, 0)
        if opts.danger then
            -- Destructive actions keep their warning red: a Reset that
            -- looks like every other button is a Reset nobody expects.
            btn.__r, btn.__g, btn.__b = 0.16, 0.10, 0.10
            btn.__er, btn.__eg, btn.__eb = 0.45, 0.2, 0.2
            btn.label:SetTextColor(B.FG[1], B.FG[2], B.FG[3], 1)
        else
            btn.__r, btn.__g, btn.__b = 0.10, 0.11, 0.12
            local ar, ag, ab = ns.GetAccentColor()
            btn.__er, btn.__eg, btn.__eb = ar, ag, ab
            -- The label wears the accent too: border AND text is what
            -- makes a button read as the accent's own.
            btn.label:SetTextColor(ar, ag, ab, 1)
        end
        ButtonPaint(btn)
        return ROW_H
    end,
}

-- ---------------- Group label ----------------
-- The small caps over a block of rows (the kit's CLOCK / SIZE / TEXT).
K.label = {
    New = function(view)
        local row = CreateFrame("Frame", nil, view)
        row.text = B.Font(row, 11, B.FG[1], B.FG[2], B.FG[3])
        row.text:SetPoint("LEFT", 0, 0)
        row:SetScript("OnEnter", function(r) TipEnter(r) end)
        row:SetScript("OnLeave", function() TipLeave() end)
        return row
    end,
    Set = function(row, text, opts)
        opts = opts or {}
        row.__tip = opts.tooltip
        row.text:SetText(text)
        local c = opts.color
        if c then
            row.text:SetTextColor(c[1], c[2], c[3], 1)
        else
            local r, g, b = B.AccentSoft()
            row.text:SetTextColor(r, g, b, 1)
        end
        return 22
    end,
}
