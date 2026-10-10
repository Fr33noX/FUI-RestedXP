-- FUI-RestedXP OptionsView.lua (standalone)
-- The row engine the options window draws with, and the three kinds every
-- page starts from: a section title, a note, and a card.
--
-- Shape: a kind is { New(view) -> frame, made ONCE; Set(row, ...) -> height }.
-- A view draws a page as: self:Clear(), the rows, then self:Fit(events).
-- Redraw() comes from the mixin passed to View.New -- the engine never
-- draws on its own. Rows are pooled per kind, so a redraw never creates
-- frames: it reuses them, which is what keeps a rebuild cheap.
--
-- Redraws are throttled: QueueRedraw coalesces a burst (events, a setter
-- firing several times) into one draw REDRAW_DELAY later, and only while
-- the view is shown; a redraw asked for while hidden runs on the next show.
--
-- The view is a plain frame the window gives its points: Clear reads its
-- width, so give the view its anchors before the first draw. The window
-- may build the first page itself (view:Redraw()); whatever is not drawn
-- yet draws on the first show. While a draw runs, a row reads its view
-- (row:GetParent()): view.left and view.width are where rows go (inside
-- a card, its inside), view.cursor is how far down the page has come.

local ADDON_NAME, ns = ...

local REDRAW_DELAY = 0.15 -- seconds: a burst of events makes one redraw

-- Metrics in pixels: a section title over its line, notes indented with
-- the section text, a card's pad and the space under its last row.
local SECTION_H = 28
local SECTION_TIGHT_H = 20
local INDENT = 20
local NOTE_PAD = 6
local CARD_PAD = 10
local CARD_BOTTOM = 6
local CHEVRON = 12 -- the section's open/close arrow

-- Colours: the window's text, secondary text and hairlines are fixed;
-- the accent is read live from Core on every Set, so a new accent shows
-- on the next redraw without a reload.
local FG_R, FG_G, FG_B = 0.85, 0.87, 0.90
local MUTED_R, MUTED_G, MUTED_B = 0.60, 0.62, 0.65
local LINE_R, LINE_G, LINE_B = 0.28, 0.29, 0.32
local CARD_FILL = 0.025 -- the card's fill: the text colour, this faint

local CHEVRON_TEX = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Textures\\rxp-chevron.png"

-- ---------------- Small drawing helpers ----------------

-- A colour escape, for text inside a line (a count after a title).
local function Code(r, g, b)
    return ("|cff%02x%02x%02x"):format(
        math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
end

-- The accent lifted a third of the way to white: what a section title
-- wears. Read on every Set, never cached in a row.
local function AccentSoft()
    local r, g, b = ns.GetAccentColor()
    return r + (1 - r) / 3, g + (1 - g) / 3, b + (1 - b) / 3
end

local function Font(parent, size, r, g, b)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    ns.ApplyFont(fs, nil, size)
    fs:SetTextColor(r, g, b, 1)
    return fs
end

local function Solid(parent, layer, r, g, b, a)
    local t = parent:CreateTexture(nil, layer or "BACKGROUND")
    t:SetColorTexture(r, g, b, a or 1)
    return t
end

-- One side of a card's 1px edge: both its points are corners of the
-- card, so it stretches with the card and a resize needs nothing.
local function Edge(card, a1, a2, horiz)
    local t = card:CreateTexture(nil, "BORDER")
    t:SetColorTexture(0, 0, 0, 1)
    t:SetPoint(a1)
    t:SetPoint(a2)
    if horiz then t:SetHeight(1) else t:SetWidth(1) end
    return t
end

-- ---------------- The three kinds ----------------

local Kinds = {}

local function SectionClicked(row)
    if row.onToggle then row.onToggle() end
end

local function SectionEnter(row)
    if not row.onToggle then return end
    row.text:SetTextColor(FG_R, FG_G, FG_B, 1)
    row.chevron:SetVertexColor(FG_R, FG_G, FG_B, 1)
end

local function SectionLeave(row)
    local r, g, b = AccentSoft()
    row.text:SetTextColor(r, g, b, 1)
    row.chevron:SetVertexColor(r, g, b, 1)
end

local function LinkColor(link, r, g, b)
    link.text:SetTextColor(r, g, b, 1)
    link.underline:SetColorTexture(r, g, b, 1)
end

local function LinkEnter(link)
    if link.disabled then return end
    LinkColor(link, FG_R, FG_G, FG_B)
    link.underline:Show()
end

local function LinkLeave(link)
    link.underline:Hide()
    if link.disabled then
        LinkColor(link, MUTED_R, MUTED_G, MUTED_B)
    else
        local r, g, b = AccentSoft()
        LinkColor(link, r, g, b)
    end
end

local function LinkClicked(link)
    local row = link:GetParent()
    if not link.disabled and row.onLink then
        row.onLink(row.linkArg, link)
    end
end

-- A title over a line: a muted count after it, a chevron when it opens
-- and closes on a click anywhere on the row, and an optional link at its
-- right. Height: SECTION_H, or SECTION_TIGHT_H on a tight view.
Kinds.section = {
    New = function(view)
        local row = CreateFrame("Frame", nil, view)
        row.text = Font(row, 12, AccentSoft())
        row.text:SetPoint("BOTTOMLEFT", 0, 5)
        -- The chevron art points UP: closed turns it a quarter turn
        -- clockwise (it points right), open a half turn (it points down).
        row.chevron = row:CreateTexture(nil, "ARTWORK")
        row.chevron:SetTexture(CHEVRON_TEX)
        row.chevron:SetSize(CHEVRON, CHEVRON)
        row.chevron:SetPoint("BOTTOMLEFT", -2, 5)
        row.line = Solid(row, "ARTWORK", LINE_R, LINE_G, LINE_B, 1)
        row.line:SetPoint("BOTTOMLEFT")
        row.line:SetPoint("BOTTOMRIGHT")
        row.line:SetHeight(1)
        row.link = CreateFrame("Button", nil, row)
        row.link:SetHeight(16)
        row.link:SetPoint("BOTTOMRIGHT", 0, 4)
        row.link.text = Font(row.link, 12, MUTED_R, MUTED_G, MUTED_B)
        row.link.text:SetPoint("CENTER")
        row.link.underline = Solid(row.link, "ARTWORK", MUTED_R, MUTED_G, MUTED_B, 1)
        row.link.underline:SetPoint("BOTTOMLEFT", 1, 0)
        row.link.underline:SetPoint("BOTTOMRIGHT", -1, 0)
        row.link.underline:SetHeight(1)
        row.link.underline:Hide()
        row.link:SetScript("OnEnter", LinkEnter)
        row.link:SetScript("OnLeave", LinkLeave)
        row.link:SetScript("OnClick", LinkClicked)
        row:SetScript("OnMouseUp", SectionClicked)
        row:SetScript("OnEnter", SectionEnter)
        row:SetScript("OnLeave", SectionLeave)
        return row
    end,
    ---@param title string
    ---@param opts? { count: any, open: boolean, onToggle: fun(),
    ---               linkText: string, onLink: fun(arg: any, link: Frame), linkArg: any }
    Set = function(row, title, opts)
        opts = opts or {}
        local view = row:GetParent()
        local toggles = opts.onToggle ~= nil
        row.onToggle, row.onLink, row.linkArg = opts.onToggle, opts.onLink, opts.linkArg
        row:EnableMouse(toggles)
        row.chevron:SetShown(toggles)
        if toggles then
            row.chevron:SetRotation(opts.open and math.pi or -math.pi / 2)
        end
        local ar, ag, ab = AccentSoft()
        row.chevron:SetVertexColor(ar, ag, ab, 1)
        row.text:SetTextColor(ar, ag, ab, 1)
        row.text:ClearAllPoints()
        row.text:SetPoint("BOTTOMLEFT", toggles and 14 or 0, 5)
        if opts.count ~= nil then
            title = title .. " " .. Code(MUTED_R, MUTED_G, MUTED_B) .. tostring(opts.count) .. "|r"
        end
        row.text:SetText(title)
        local link = row.link
        link:SetShown(opts.linkText ~= nil)
        if opts.linkText then
            link.text:SetText(opts.linkText)
            link:SetWidth(math.ceil(link.text:GetStringWidth()) + 8)
            link.disabled = opts.onLink == nil
            local r, g, b
            if link.disabled then
                r, g, b = MUTED_R, MUTED_G, MUTED_B
            else
                r, g, b = ar, ag, ab
            end
            LinkColor(link, r, g, b)
            link.underline:Hide()
        end
        return view.tightTitles and SECTION_TIGHT_H or SECTION_H
    end,
}

-- A paragraph of muted text, indented with the section text above it:
-- as tall as it wraps. Set the width BEFORE the text, or the measurement
-- is of the last row's width.
Kinds.note = {
    New = function(view)
        local row = CreateFrame("Frame", nil, view)
        row.text = Font(row, 11, MUTED_R, MUTED_G, MUTED_B)
        row.text:SetPoint("TOPLEFT", INDENT, -2)
        row.text:SetJustifyH("LEFT")
        row.text:SetWordWrap(true)
        return row
    end,
    Set = function(row, text, opts)
        local indent = (opts and opts.indent) or INDENT
        row.text:ClearAllPoints()
        row.text:SetPoint("TOPLEFT", indent, -2)
        row.text:SetWidth(row:GetWidth() - indent)
        row.text:SetText(text)
        return math.ceil(row.text:GetStringHeight()) + NOTE_PAD
    end,
}

-- A faint panel with a 1px black edge. It has no Set: a card is only
-- placed (view:OpenCard / CloseCard), and the rows drawn after OpenCard
-- go inside it.
Kinds.card = {
    New = function(view)
        local card = CreateFrame("Frame", nil, view)
        card.fill = Solid(card, "BACKGROUND", FG_R, FG_G, FG_B, CARD_FILL)
        card.fill:SetAllPoints()
        card.edges = {
            Edge(card, "TOPLEFT", "TOPRIGHT", true),
            Edge(card, "BOTTOMLEFT", "BOTTOMRIGHT", true),
            Edge(card, "TOPLEFT", "BOTTOMLEFT", false),
            Edge(card, "TOPRIGHT", "BOTTOMRIGHT", false),
        }
        -- For a card that marks something (a picked one): its edge in the
        -- accent instead of black. Call before the rows go inside.
        function card:SetEdgeColor(r, g, b, a)
            for i = 1, #self.edges do
                self.edges[i]:SetColorTexture(r, g, b, a or 1)
            end
        end
        return card
    end,
}

-- ---------------- The engine ----------------

local Engine = {}

-- The pooled row for this kind: created once, then re-shown and
-- re-anchored at the cursor on every draw. Sized now, not only anchored,
-- so a note wraps at the width it will have.
function Engine:Acquire(kind)
    local def = self.kinds[kind]
    assert(def, "OptionsView: unknown kind '" .. tostring(kind) .. "'")
    local pool = self.pools[kind]
    if not pool then
        pool = { used = 0 }
        self.pools[kind] = pool
    end
    pool.used = pool.used + 1
    local row = pool[pool.used]
    if not row then
        row = self.kinds[kind].New(self)
        pool[pool.used] = row
    end
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", self.left, -self.cursor)
    row.top = self.cursor -- for a future scroll-to-row
    row:SetWidth(self.width)
    -- One level over the view: a card is placed AT the view's level, so
    -- every row draws on top of the card it sits in.
    row:SetFrameLevel(self:GetFrameLevel() + 1)
    row:Show()
    return row
end

function Engine:Add(kind, ...)
    local row = self:Acquire(kind)
    local set = self.kinds[kind].Set
    assert(set, "OptionsView: kind '" .. tostring(kind) .. "' is placed, not added")
    local height = set(row, ...)
    assert(type(height) == "number",
        "OptionsView: " .. tostring(kind) .. ".Set must return a height")
    row:SetHeight(height)
    self.cursor = self.cursor + height
    return row
end

function Engine:Space(height)
    self.cursor = self.cursor + height
end

-- Sugar for the kinds every page uses.
function Engine:Section(title, opts)
    return self:Add("section", title, opts)
end

function Engine:Note(text)
    return self:Add("note", text)
end

-- A card at x, width w, from the cursor; the rows added after go inside
-- it (view.left / view.width are the card's inside until CloseCard).
-- Returns the card -- CloseCard reads its top back.
function Engine:OpenCard(x, w)
    self.left, self.width = x, w
    local card = self:Acquire("card")
    card:SetFrameLevel(self:GetFrameLevel()) -- under the rows: they draw on top
    self.left, self.width = x + CARD_PAD, w - CARD_PAD * 2
    return card
end

-- Ends the card OpenCard returned: space under its last row, back to the
-- page's full width, and the card as tall as everything since OpenCard.
function Engine:CloseCard(card)
    self:Space(CARD_BOTTOM)
    self.left, self.width = self.__pad or 0, self.__contentW or self:GetWidth()
    local height = self.cursor - card.top
    card:SetHeight(height)
    return card, height
end

-- Two columns side by side: draw the left half, rewind, draw the right
-- half, then sit below the taller of the two -- so a pair stays aligned
-- even when one side of it is only a spacer. The right block of the pair
-- runs wider than the left: its labels sit beside their toggles and run
-- long ("Glue the objective icons to the guide window"), while the left
-- pairs labels with sliders and dropdowns.
local RIGHT_BIAS = 40

function Engine:Columns(drawLeft, drawRight)
    local y0 = self.cursor
    local savedLeft, savedWidth = self.left, self.width
    local gap = 16
    local half = math.floor((savedWidth - gap) / 2)
    local right = half + RIGHT_BIAS
    local left = savedWidth - gap - right
    self.left, self.width = savedLeft, left
    self.cursor = y0
    if drawLeft then drawLeft() end
    local leftEnd = self.cursor
    self.left, self.width = savedLeft + left + gap, right
    self.cursor = y0
    if drawRight then drawRight() end
    local rightEnd = self.cursor
    self.left, self.width = savedLeft, savedWidth
    self.cursor = math.max(leftEnd, rightEnd)
end

-- ---------------- A draw: Clear, the rows, Fit ----------------

-- A wide host may center a capped page: __pad/__contentW carry the
-- centering (set by the owner on resize, 0/full width when absent),
-- so rows never stretch past the designed width.
function Engine:Clear()
    self.cursor, self.left, self.width =
        0, self.__pad or 0, self.__contentW or self:GetWidth()
    for _, pool in pairs(self.pools) do
        for i = 1, pool.used do
            pool[i]:Hide()
        end
        pool.used = 0
    end
end

-- As tall as what it drew, listening to the events in the list: each one
-- queues a redraw, and the queue makes a burst one draw.
function Engine:Fit(events)
    self:SetHeight(math.max(self.cursor, 1))
    self:UnregisterAllEvents()
    if events then
        for i = 1, #events do
            self:RegisterEvent(events[i])
        end
    end
end

-- ---------------- The throttle ----------------

function Engine:QueueRedraw()
    self.dirty = true
    if self.flushQueued then return end
    self.flushQueued = true
    C_Timer.After(REDRAW_DELAY, self.flushFn)
end

function Engine:Flush()
    self.flushQueued = false
    if not self.dirty or not self:IsVisible() then return end
    self.dirty = false
    self:Redraw()
end

function Engine:OnEvent()
    self:QueueRedraw()
end

function Engine:OnHide()
    self:UnregisterAllEvents()
    self.dirty = true -- events need re-registering: redraw on show
end

function Engine:OnShow()
    if not self.dirty then return end
    self.dirty = false
    self:Redraw()
end

-- ---------------- The view ----------------

local View = {}

-- A module's own kinds, falling back on the shared three.
function View.NewKinds()
    return setmetatable({}, { __index = Kinds })
end

---@param parent frame where the view lives (the window's content area)
---@param kinds? table the module's kinds; nil is the shared three
---@param mixin table the page's drawing: Redraw(self) rebuilds the page
---@return table view
function View.New(parent, kinds, mixin)
    assert(mixin and type(mixin.Redraw) == "function",
        "OptionsView: a view mixin needs a Redraw(self)")
    local view = CreateFrame("Frame", nil, parent)
    for k, v in pairs(Engine) do view[k] = v end
    for k, v in pairs(mixin) do view[k] = v end
    view.kinds = kinds or View.NewKinds()
    view.pools = {}
    view.cursor, view.left, view.width = 0, 0, 0
    view.dirty = true -- the first show draws whatever was not drawn yet
    view.flushFn = function() view:Flush() end
    -- Engine first, then the mixin's own, if it hooks one.
    view:SetScript("OnEvent", function(f, event, ...)
        Engine.OnEvent(f, event, ...)
        if mixin.OnEvent then mixin.OnEvent(f, event, ...) end
    end)
    view:SetScript("OnShow", function(f)
        Engine.OnShow(f)
        if mixin.OnShow then mixin.OnShow(f) end
    end)
    view:SetScript("OnHide", function(f)
        Engine.OnHide(f)
        if mixin.OnHide then mixin.OnHide(f) end
    end)
    return view
end

ns.View = View
ns.Kinds = Kinds

-- Shared drawing bits for the control kinds (Controls.lua): the same
-- fonts and colours the three base kinds use, so a control row reads
-- like a section row, plus the metrics a control needs.
ns.ViewBits = {
    Font = Font,
    Solid = Solid,
    Edge = Edge,
    AccentSoft = AccentSoft,
    Code = Code,
    FG = { FG_R, FG_G, FG_B },
    MUTED = { MUTED_R, MUTED_G, MUTED_B },
    LINE = { LINE_R, LINE_G, LINE_B },
    ROW_H = 30,       -- a row holding a control
    CHEVRON = CHEVRON,
    CHEVRON_TEX = CHEVRON_TEX,
    TRACK_W = 140,    -- the slider rail's width
    RIGHT_BIAS = RIGHT_BIAS, -- how much wider the right block runs
}
