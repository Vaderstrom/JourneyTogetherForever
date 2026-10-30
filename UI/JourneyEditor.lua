-- The journey editor (SPEC §4.11; 28 Oct 2026): one editor for Create a Fellowship ("Your own journey") and Journey
-- Admin. Left page: the road, a ruler of every chapter's levels with a gold mark between each two chapters (drag it
-- to move the level they share), Split / Merge / Remove, and a row per chapter with its dungeons as chips. Right
-- page, in tabs: the chosen chapter (name, floor and cap, its dungeons with role and bosses), the shelf of every
-- dungeon, and the whole journey (Start over, Import). Drag a dungeon from the shelf or a chapter onto a chapter row (or onto this chapter's list) to put it
-- there; drag it onto the shelf to take it out. Everything can also be done with clicks.
-- The editor changes a journey only through its source (see JED.New): Create edits its own copy, Journey Admin a
-- draft. Every frame is made when the page is built, so nothing is created during combat (the drag ghost too).
local _, ns = ...
local L = ns.L
local UI, Theme = ns.UI, ns.Theme
local JE = ns.JourneyEdit

local JED = {}
ns.JourneyEditor = JED

local FLAT = { bgFile = ns.WHITE, edgeFile = ns.WHITE, edgeSize = 1 }
local ROLE_NAME = { m = "ROLE_MANDATORY", b = "ROLE_BRIDGE", o = "ROLE_OPTIONAL" }
-- A chip's look by the dungeon's role: Mandatory in dark leather with gold, Bridge with a blue edge, Optional pale.
local ROLE_LOOK = { m = { "band2", 1, "goldText", "goldText" }, b = { "band2", 0.8, "2E6FA8", "chipText" },
  o = { "page2", 0.95, "line", "ink2" } }

local function cursor(frame)
  local x, y = GetCursorPosition()
  local s = frame:GetEffectiveScale()
  return x / s, y / s
end

local function paint(b, bg, bgA, border, text)
  b:SetBackdropColor(Theme:RGBA(bg, bgA)); b:SetBackdropBorderColor(Theme:RGBA(border)); b.text:SetTextColor(Theme:RGBA(text))
end

-- A text's whole width, also where SetWidth cuts it.
local function full(fs) return fs.GetUnboundedStringWidth and fs:GetUnboundedStringWidth() or fs:GetStringWidth() end

-- A dungeon chip: drag it somewhere, or click it. b.item = { base = key } (on the shelf) or { key = placement }.
local function chip(parent, ed, onClick)
  local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
  b:SetBackdrop(FLAT)
  b:SetHeight(20)
  b.text = UI.Text(b, 12, nil, "body")
  b.text:SetPoint("LEFT", 6, 0)
  local hl = b:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints(); hl:SetColorTexture(1, 0.85, 0.45, 0.18)
  b:RegisterForDrag("LeftButton")
  b:SetScript("OnDragStart", function() ed:BeginDrag(b.item, b.text:GetText()) end)
  b:SetScript("OnDragStop", function() ed:EndDrag() end)
  b:SetScript("OnClick", function() if onClick then onClick(b) end end)
  b:SetScript("OnEnter", function()
    if ed.drag or not b.tip then return end
    GameTooltip:SetOwner(b, "ANCHOR_TOP")
    GameTooltip:SetText(b.tip[1])
    for i = 2, #b.tip do GameTooltip:AddLine(b.tip[i], 1, 1, 1, true) end
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  return b
end

-- Builds the editor on two frames, `left` and `right` (each a page's area for it, lw and rw wide).
-- src = {
--   journey() -> the journey to show, edit(fn, quiet) -> fn(journey) on the editable copy, then a redraw unless quiet,
--   replace(journey) -> a whole new journey (Start over, Import), sel() / setSel(i) -> the chosen chapter,
--   importHint (optional), afterChapter(stack) and afterJourney(stack) (optional: more in the This chapter and Whole
--   journey tabs, Journey Admin's milestones and Export; their frames go on ed.panes.chapter and ed.panes.journey),
-- }
-- src.spread: the ruler runs across both pages (Journey Admin, 28 Oct 2026: wider, easier to drag), and the right
-- page's content starts under it.
local SPINE = 52 -- between the left page's area and the right page's (each page keeps a 26 margin)
local GAP = 14 -- between the ruler's plate and the right page's content
-- The right page's tabs (30 Oct 2026: it was one long scroll, and Journey Admin's Publish lay under every dungeon).
local TABS = { "chapter", "shelf", "journey" }
local TABS_H = 28 + 10 -- the tabs and the room under them

-- The tabs at the right page's top (under the plate across both pages), the scrolling tab under them.
local function placeRight(ed)
  ed.tabs:ClearAllPoints(); ed.tabs:SetPoint("TOPLEFT", ed.rightPage, "TOPLEFT", 0, -ed.drop)
  ed.rscroll:ClearAllPoints()
  ed.rscroll:SetPoint("TOPLEFT", 0, -(ed.drop + TABS_H)); ed.rscroll:SetPoint("BOTTOMRIGHT")
end

-- The ruler's look (29 Oct 2026; Create's journey views use it too). It lies on one of the book's cards (UI.Card,
-- the rounded frame of the Overview and the dungeon cards: the leather plate looked out of place inside the book).
-- Across both pages the card bends with the fold: p:SetFold(x) shades it there like the pages. The track is the
-- book's bar (UI.Bar): dark and inset with a thin gold edge; each chapter's part has a highlight along its top
-- (JED.Shine). plate.ruler is the track, `width` - 2 * PLATE_PAD wide.
local PLATE_PAD, PLATE_TOP, PLATE_BELOW = 12, 12, 26 -- PLATE_BELOW: room for the level numbers under the track
local FOLD_W = 14 -- each side of the fold's shade
JED.PLATE_PAD = PLATE_PAD

-- The ruler's last level: the game's cap (Forever 60, retail 80), or the journey's last cap when it reaches higher
-- (a Leader whose account has a higher cap).
function JED.RulerTop(j)
  local last = j.chapters[#j.chapters]
  return math.max(ns.LevelCap(), last and last.cap or 0)
end

function JED.Plate(parent, width, rulerH)
  local p = UI.Card(parent)
  p:SetSize(width, PLATE_TOP + rulerH + PLATE_BELOW)
  local r = CreateFrame("Frame", nil, p)
  r:SetSize(width - 2 * PLATE_PAD, rulerH)
  r:SetPoint("TOPLEFT", PLATE_PAD, -PLATE_TOP)
  local edge = UI.Solid(r, "BACKGROUND", "B8903C", 1, -2)
  edge:SetPoint("TOPLEFT", -1, 1); edge:SetPoint("BOTTOMRIGHT", 1, -1)
  UI.Solid(r, "BACKGROUND", "2A1C10", 1, -1):SetAllPoints()
  p.ruler = r
  -- A new width for the plate; returns the track's.
  function p:Fit(w)
    self:SetWidth(w); r:SetWidth(w - 2 * PLATE_PAD)
    return w - 2 * PLATE_PAD
  end
  -- The fold's shade (hidden until p:SetFold(x), `x` from the plate's left edge).
  p.fold = {
    UI.GradientTex(p, "BORDER", "HORIZONTAL", { "dark", 0 }, { "dark", 0.22 }),
    UI.GradientTex(p, "BORDER", "HORIZONTAL", { "dark", 0.22 }, { "dark", 0 }),
  }
  for _, t in ipairs(p.fold) do t:SetWidth(FOLD_W); t:Hide() end
  -- (nil: no fold under it, on the flat sheet.)
  function p:SetFold(x)
    local a, b = self.fold[1], self.fold[2]
    a:SetShown(x ~= nil); b:SetShown(x ~= nil)
    if not x then return end
    a:ClearAllPoints(); a:SetPoint("TOPRIGHT", self, "TOPLEFT", x, -3); a:SetPoint("BOTTOMRIGHT", self, "BOTTOMLEFT", x, 3)
    b:ClearAllPoints(); b:SetPoint("TOPLEFT", self, "TOPLEFT", x, -3); b:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", x, 3)
  end
  return p
end

-- A chapter's part of the ruler: on `owner`, over the texture `fill`, a highlight along its top third and a dark
-- inset line at its edge (as on UI.Bar). Returns both, to be shown and hidden with the part.
function JED.Shine(owner, fill, height)
  local shine = owner:CreateTexture(nil, "ARTWORK", nil, 2)
  shine:SetColorTexture(1, 1, 1, 0.28)
  shine:SetPoint("TOPLEFT", fill, "TOPLEFT", 0, -1); shine:SetPoint("TOPRIGHT", fill, "TOPRIGHT", 0, -1)
  shine:SetHeight(math.max(1, math.floor((height - 2) / 3)))
  local shade = owner:CreateTexture(nil, "ARTWORK", nil, 3)
  shade:SetColorTexture(0, 0, 0, 0.4)
  shade:SetPoint("TOPLEFT", fill); shade:SetPoint("TOPRIGHT", fill); shade:SetHeight(1)
  return shine, shade
end

local RULER_H = 20
local PLATE_H = PLATE_TOP + RULER_H + PLATE_BELOW
local TOOLS_Y = PLATE_H + 12 -- Split / Merge / Remove, under the plate

function JED.New(left, right, lw, rw, src)
  local W = ns.Window
  local ed = { src = src, lw = lw, rw = rw, spread = src.spread, leftPage = left, rightPage = right }

  ---------------------------------------------------------------------------
  -- Left page: the ruler on its plate, Split / Merge / Remove, the chapters.
  ---------------------------------------------------------------------------
  ed.plate = JED.Plate(left, src.spread and (lw + rw + SPINE) or lw, RULER_H)
  ed.plate:SetPoint("TOPLEFT", 0, -2)
  ed.ruler = ed.plate.ruler
  ed.rulerW = ed.ruler:GetWidth()
  ed.segs = {}
  for i = 1, ns.Journey.MAX_CHAPTERS do
    local seg = CreateFrame("Button", nil, ed.ruler)
    -- The chosen chapter: a bright edge around its part.
    seg.ring = UI.Solid(seg, "BACKGROUND", "FFE08A")
    seg.ring:SetPoint("TOPLEFT", -1, 1); seg.ring:SetPoint("BOTTOMRIGHT", 1, -1)
    seg.tex = seg:CreateTexture(nil, "ARTWORK")
    seg.tex:SetAllPoints(); seg.tex:SetTexture(ns.WHITE)
    JED.Shine(seg, seg.tex, RULER_H)
    -- The chapter's number in its part of the ruler, where there is room.
    seg.n = UI.Text(seg, 11, "white", "title", "CENTER")
    seg.n:SetPoint("CENTER", 0, 0)
    seg:SetScript("OnClick", function() src.setSel(seg.i) end)
    ed.segs[i] = seg
  end
  -- Level marks under the ruler: a short one every 5 levels, a long one every 10, up to the game's cap (30 Oct 2026:
  -- Forever 60, retail 80; marks past the ruler's end are hidden).
  ed.marks = {}
  for v = 5, ns.HighestLevel(), 5 do
    local m = UI.Solid(ed.ruler, "BORDER", "ink2", 0.7)
    m:SetWidth(1); m:SetHeight(v % 10 == 0 and 6 or 3)
    ed.marks[#ed.marks + 1] = { tex = m, v = v }
  end
  -- The marks between chapters: drag one to move the level two chapters share.
  ed.handles = {}
  for i = 1, ns.Journey.MAX_CHAPTERS - 1 do
    local h = CreateFrame("Button", nil, ed.ruler)
    h:SetSize(14, 30)
    h:SetFrameLevel(ed.ruler:GetFrameLevel() + 5)
    local bar = UI.Solid(h, "ARTWORK", "goldText")
    bar:SetSize(4, 30); bar:SetPoint("CENTER")
    local edge = UI.Solid(h, "BORDER", "dark", 0.8)
    edge:SetSize(6, 32); edge:SetPoint("CENTER")
    local gem = UI.Solid(h, "OVERLAY", "goldText")
    gem:SetSize(9, 9); gem:SetPoint("CENTER", 0, 0); gem:SetRotation(math.rad(45))
    local hl = h:CreateTexture(nil, "HIGHLIGHT")
    hl:SetSize(14, 30); hl:SetPoint("CENTER"); hl:SetColorTexture(1, 0.9, 0.5, 0.35)
    h:RegisterForDrag("LeftButton")
    h:SetScript("OnDragStart", function() ed:BeginDrag({ boundary = h.i }) end)
    h:SetScript("OnDragStop", function() ed:EndDrag() end)
    h:SetScript("OnEnter", function() ed:HandleTip(h) end)
    h:SetScript("OnLeave", function() if not ed.drag then GameTooltip:Hide() end end)
    ed.handles[i] = h
  end
  -- The levels: every 10 (10, 20 ... the cap), and where the journey starts (1 with the Prologue).
  ed.ticks = {}
  for v = 0, ns.HighestLevel(), 10 do
    local t = UI.Text(ed.plate, 11, "ink2", "body", "CENTER")
    t:SetText(v)
    ed.ticks[#ed.ticks + 1] = { fs = t, v = v }
  end
  local function act(fn) return function() src.edit(function(j) fn(j, src.sel()) end) end end
  ed.split = UI.TextButton(left, L.ED_SPLIT, function()
    local n
    src.edit(function(j) n = JE.Split(j, src.sel()) end)
    if n then src.setSel(n) end
  end, "plain", 12)
  ed.split:SetPoint("TOPLEFT", 0, -TOOLS_Y)
  ed.merge = UI.TextButton(left, L.ED_MERGE, act(JE.Merge), "plain", 12)
  ed.merge:SetPoint("LEFT", ed.split, "RIGHT", 4, 0)
  ed.remove = UI.TextButton(left, L.ED_REMOVE, function()
    src.edit(function(j) JE.RemoveChapter(j, src.sel()) end)
    src.setSel(math.max(1, src.sel() - 1))
  end, "danger", 12)
  ed.remove:SetPoint("LEFT", ed.merge, "RIGHT", 4, 0)
  ed.hint = UI.WrapText(left, 12, "ink2", lw, "book")
  ed.hint:SetPoint("TOPLEFT", 0, -(TOOLS_Y + 34))
  ed.hint:SetText(L.ED_HINT)
  ed.list = UI.Scroll(left)
  ed.list:SetPoint("TOPLEFT", 0, -(TOOLS_Y + 38 + math.max(16, ed.hint:GetStringHeight()) + 6)); ed.list:SetPoint("BOTTOMRIGHT")
  ed.rows = UI.Pool(function()
    local row = CreateFrame("Button", nil, ed.list.child)
    row:SetWidth(lw - 10)
    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints(); row.bg:SetTexture(ns.WHITE)
    local line = UI.Solid(row, "BORDER", "line", 0.6)
    line:SetHeight(1); line:SetPoint("BOTTOMLEFT"); line:SetPoint("BOTTOMRIGHT")
    row.sw = row:CreateTexture(nil, "ARTWORK")
    row.sw:SetSize(10, 10); row.sw:SetPoint("TOPLEFT", 4, -7); row.sw:SetTexture(ns.WHITE)
    row.n = UI.Text(row, 12, "ink2")
    row.n:SetPoint("TOPLEFT", 20, -5)
    row.name = UI.Text(row, 13, "ink")
    row.name:SetPoint("TOPLEFT", 52, -4); row.name:SetWidth(lw - 150)
    row.range = UI.Text(row, 12, "ink2", "body", "RIGHT")
    row.range:SetPoint("TOPRIGHT", -6, -5)
    row.none = UI.Text(row, 12, "ink2")
    row.none:SetPoint("TOPLEFT", 52, -24); row.none:SetText(L.ED_NO_DUNGEONS)
    row.chips = UI.Pool(function() return chip(row, ed, function() src.setSel(row.i) end) end)
    row:SetScript("OnClick", function() src.setSel(row.i) end)
    return row
  end)

  ---------------------------------------------------------------------------
  -- Right page, in three tabs: This chapter (its name, floor and cap, its dungeons, and what the source adds), Every
  -- dungeon (the shelf) and Whole journey (Start over, Import, and what the source adds). Each tab is a pane in the
  -- scrolling area; only the open one shows.
  ---------------------------------------------------------------------------
  ed.tab = "chapter"
  ed.tabs = UI.Tabs(right, { { L.ED_TAB_CHAPTER, "chapter" }, { L.ED_SHELF, "shelf" }, { L.ED_TAB_JOURNEY, "journey" } },
    function() return ed.tab end, function(v) ed:ShowTab(v) end, rw)
  ed.rscroll = UI.Scroll(right)
  ed.drop = src.spread and (PLATE_H + GAP) or 0
  placeRight(ed)
  ed.panes = {}
  for _, k in ipairs(TABS) do
    local p = CreateFrame("Frame", nil, ed.rscroll.child)
    p:SetPoint("TOPLEFT"); p:SetSize(rw, 1)
    ed.panes[k] = p
  end
  local R, S, J = ed.panes.chapter, ed.panes.shelf, ed.panes.journey
  ed.chHead = UI.SectionHeader(R, rw)
  ed.nameLabel = UI.Text(R, 13, "ink2")
  ed.nameLabel:SetText(L.CHAPTER_NAME)
  ed.name = UI.EditBox(R, rw, 48, "")
  ed.name.edit:HookScript("OnTextChanged", function(eb, user)
    if user then src.edit(function(j) JE.Rename(j, src.sel(), eb:GetText()) end, true) end
  end)
  ed.name.edit:HookScript("OnEditFocusLost", function() W:Refresh() end)
  local function bound(setter, dir)
    return function()
      src.edit(function(j)
        local i = src.sel()
        local c = j.chapters[i]
        setter(j, i, (setter == JE.SetFloor and c.floor or c.cap) + dir)
      end)
    end
  end
  local function current(key) return function() local j = src.journey(); local c = j and j.chapters[src.sel()]; return c and c[key] or "" end end
  ed.floorLabel = UI.Text(R, 13, "ink2"); ed.floorLabel:SetText(L.FLOOR)
  ed.floor = UI.Stepper(R, bound(JE.SetFloor, -1), bound(JE.SetFloor, 1), current("floor"))
  ed.capLabel = UI.Text(R, 13, "ink2"); ed.capLabel:SetText(L.CAP)
  ed.cap = UI.Stepper(R, bound(JE.SetCap, -1), bound(JE.SetCap, 1), current("cap"))
  ed.issues = UI.Pool(function() return UI.WrapText(R, 12, "B0321E", rw) end)
  -- This chapter's dungeons: also a place to drop a dungeon.
  ed.dropHere = CreateFrame("Frame", nil, R)
  ed.dropHere:SetWidth(rw)
  ed.dropHere.bg = ed.dropHere:CreateTexture(nil, "BACKGROUND")
  ed.dropHere.bg:SetAllPoints(); ed.dropHere.bg:SetTexture(ns.WHITE)
  ed.dHead = UI.SectionHeader(R, rw)
  ed.dHead:SetText(L.DUNGEONS_IN_CHAPTER)
  ed.drows = UI.Pool(function()
    local c = UI.Card(R, "line", "Button")
    c:SetSize(rw, 58)
    c.name = UI.Text(c, 14, "ink")
    c.name:SetPoint("TOPLEFT", 10, -8)
    c.levels = UI.Text(c, 12, "ink2")
    c.levels:SetPoint("LEFT", c.name, "RIGHT", 8, 0)
    c.x = CreateFrame("Button", nil, c, "UIPanelCloseButton")
    c.x:SetSize(24, 24)
    c.x:SetPoint("TOPRIGHT", -2, -2)
    c.x:SetScript("OnClick", function() src.edit(function(j) JE.Unplace(j, c.key) end) end)
    c.roles = UI.Choice(c, { { L.ROLE_MANDATORY, "m" }, { L.ROLE_BRIDGE, "b" }, { L.ROLE_OPTIONAL, "o" } },
      function() local j = src.journey(); local p = j and j.place[c.key]; return p and p.role end,
      function(v) src.edit(function(j) JE.SetRole(j, c.key, v) end) end)
    c.roles:SetPoint("TOPLEFT", 10, -28)
    -- Which bosses are needed for a clear (every boss until it is chosen).
    c.bosses = UI.TextButton(c, "", function() ed:PickBosses(c.key) end, "plain", 11)
    c.bosses:SetPoint("TOPLEFT", c.roles, "TOPRIGHT", 8, 1)
    c:RegisterForDrag("LeftButton")
    c:SetScript("OnDragStart", function() ed:BeginDrag({ key = c.key }, c.name:GetText()) end)
    c:SetScript("OnDragStop", function() ed:EndDrag() end)
    return c
  end)
  ed.empty = UI.WrapText(R, 13, "ink2", rw, "book")
  ed.empty:SetText(L.ADMIN_NO_DUNGEONS)
  -- The shelf: every dungeon by level; the ones that fit the chosen chapter in gold. Also where a dungeon is dropped
  -- to take it out of its chapter. (Its tab is its heading.)
  ed.shelfHint = UI.WrapText(S, 12, "ink2", rw, "book")
  ed.shelf = CreateFrame("Frame", nil, S)
  ed.shelf:SetWidth(rw)
  ed.shelf.bg = ed.shelf:CreateTexture(nil, "BACKGROUND")
  ed.shelf.bg:SetAllPoints(); ed.shelf.bg:SetTexture(ns.WHITE)
  -- By level; where the game has dungeons of several expansions (retail's Adventure Guide, 30 Oct 2026), grouped by
  -- expansion under its name (the game's own text).
  local list, exps = {}, {}
  local function exp(d) return ns.EXPANSION[d[1]] or 0 end
  for _, d in ipairs(ns.DUNGEONS) do list[#list + 1] = d; exps[exp(d)] = true end
  table.sort(list, function(a, b)
    if exp(a) ~= exp(b) then return exp(a) < exp(b) end
    if a[3] ~= b[3] then return a[3] < b[3] end
    return a[2] < b[2]
  end)
  local grouped = next(exps, next(exps)) ~= nil
  ed.shelfChips, ed.shelfBy, ed.shelfHeads = {}, {}, {}
  local cw = math.floor((rw - 6) / 2)
  local y, col, group = 4, 0, nil
  for i, d in ipairs(list) do
    if grouped and exp(d) ~= group then
      if col == 1 then y, col = y + 26, 0 end
      group = exp(d)
      local head = UI.SectionHeader(ed.shelf, rw)
      head:SetPoint("TOPLEFT", 0, -y)
      head:SetText(_G["EXPANSION_NAME" .. group] or L.ED_EXPANSION:format(group + 1))
      ed.shelfHeads[#ed.shelfHeads + 1] = head
      y = y + 29 + 4
    end
    local b = chip(ed.shelf, ed, function(self) ed:AddHere(self.item.base) end)
    b:SetSize(cw, 22)
    b:SetPoint("TOPLEFT", col * (cw + 6), -y)
    b.text:SetText(d[2]); b.text:SetWidth(cw - 60)
    b.sub = UI.Text(b, 12, "ink2", "body", "RIGHT")
    b.sub:SetPoint("RIGHT", -6, 0); b.sub:SetText(d[3] .. "-" .. d[4])
    b.check = UI.Check(b, 14)
    b.check:SetPoint("RIGHT", b.sub, "LEFT", -4, 0)
    b.item, b.d = { base = d[1] }, d
    ed.shelfChips[i] = b
    ed.shelfBy[d[1]] = b
    if col == 1 then y = y + 26 end
    col = 1 - col
  end
  if col == 1 then y = y + 26 end
  ed.shelf:SetHeight(y + 4)
  -- Whole journey: each preset, and Import, on a line of its own with what it does (the buttons wrapped, Import
  -- alone on the second line, and Create's tab looked empty; check of 30 Oct 2026).
  ed.startLabel = UI.Text(J, 13, "ink2")
  ed.startLabel:SetText(L.START_OVER)
  ed.presets, ed.whole = {}, {}
  for _, key in ipairs(ns.PRESET_ORDER) do
    local b = UI.TextButton(J, ns.PRESETS[key].title, function() src.replace(ns.BuildJourney(key)) end, "plain", 12)
    ed.presets[#ed.presets + 1] = b
    ed.whole[#ed.whole + 1] = { b = b, about = ns.PRESETS[key].text }
  end
  ed.import = UI.TextButton(J, L.IMPORT, function()
    local dlg
    dlg = W:TextDialog(L.IMPORT_TITLE, src.importHint or L.IMPORT_HINT_NEW, "", L.IMPORT, function(text)
      local j = ns.Journey.Import(text)
      if not j then dlg.hint:SetText(L.IMPORT_BAD); dlg.hint:SetTextColor(Theme:RGBA("B0321E")); return end
      dlg:Hide()
      src.replace(j)
    end)
  end, "plain", 12)
  ed.whole[#ed.whole + 1] = { b = ed.import, about = L.IMPORT_TEXT }
  -- The buttons in one column as wide as the widest, what each does beside it.
  ed.wholeW = 0
  for _, w in ipairs(ed.whole) do ed.wholeW = math.max(ed.wholeW, w.b:GetWidth()) end
  for _, w in ipairs(ed.whole) do
    w.b:SetWidth(ed.wholeW)
    w.text = UI.WrapText(J, 12, "ink2", rw - ed.wholeW - 10, "book")
    w.text:SetText(w.about)
  end

  -- The ghost that follows the cursor while something is dragged, above everything in the book.
  ed.ghost = UI.Box(W.frame and W.frame.area or left, 1, "band2", 0.95, "goldText", 1)
  ed.ghost:SetFrameStrata("TOOLTIP")
  ed.ghost:SetSize(120, 24)
  ed.ghost.text = UI.Text(ed.ghost, 12, "goldText", "body", "CENTER")
  ed.ghost.text:SetPoint("CENTER")
  ed.ghost:Hide()
  ed.driver = CreateFrame("Frame", nil, left)
  ed.driver:SetSize(1, 1); ed.driver:SetPoint("TOPLEFT")

  return setmetatable(ed, { __index = JED })
end

---------------------------------------------------------------------------
-- Clicks
---------------------------------------------------------------------------
-- A shelf dungeon clicked: into the chosen chapter.
function JED:AddHere(base)
  local src = self.src
  src.edit(function(j) JE.Add(j, base, src.sel()) end)
end

-- Which bosses a dungeon's clear needs in its chapter (every boss until chosen).
function JED:PickBosses(key)
  local src = self.src
  local j = src.journey()
  local d, p = ns.Dungeon(key), j and j.place[key]
  if not d or not p then return end
  local list = ns.Clears:Bosses(key)
  if #list == 0 then return end
  local needed, items = p.bosses or ns.Clears:DefaultNeeded(key), {}
  for i, b in ipairs(list) do
    local on = false
    for _, tok in ipairs(needed) do if tok == b.tok then on = true end end
    items[i] = { text = b.name, on = on }
  end
  ns.Window:PickMany(L.ADMIN_BOSSES_TITLE:format(d[2]), items, function(ons)
    src.edit(function(jj)
      local toks = {}
      for i, b in ipairs(list) do if ons[i] then toks[#toks + 1] = b.tok end end
      if jj.place[key] then jj.place[key].bosses = toks end
    end)
  end)
end

-- Opens a tab of the right page, at its top. The tab stays open when another chapter is chosen (add dungeons to one
-- chapter after another).
function JED:ShowTab(tab)
  self.tab = tab
  self:Refresh()
  self.rscroll:ToTop()
end

-- The Every dungeon tab (the tour's screenshots).
function JED:ScrollToShelf() self:ShowTab("shelf") end

-- The tooltip on a mark between two chapters: the two chapters' levels.
function JED:HandleTip(h)
  local j = self.src.journey()
  local a, b = j and j.chapters[h.i], j and j.chapters[h.i + 1]
  if not a or not b then return end
  GameTooltip:SetOwner(h, "ANCHOR_TOP")
  GameTooltip:SetText(L.ED_TIP:format(ns.Journey.Roman(h.i), a.floor, a.cap, ns.Journey.Roman(h.i + 1), b.floor, b.cap))
  if not self.drag then GameTooltip:AddLine(L.ED_HANDLE, 1, 1, 1, true) end
  GameTooltip:Show()
end

---------------------------------------------------------------------------
-- Dragging: a dungeon ({ base } from the shelf, { key } a placement) or a mark ({ boundary = i }).
---------------------------------------------------------------------------
function JED:BeginDrag(item, label)
  if self.drag or not item then return end
  self.drag = item
  GameTooltip:Hide()
  if not item.boundary then
    self.ghost.text:SetText(label or "")
    self.ghost:SetWidth(self.ghost.text:GetStringWidth() + 20)
    self.ghost:Show()
  end
  self.driver:SetScript("OnUpdate", function() self:DragUpdate() end)
  self:DragUpdate()
end

-- What is under the cursor: { kind = "chapter", i, frame } or { kind = "shelf", frame }.
function JED:Target()
  local j = self.src.journey()
  if not j then return nil end
  if self.list:IsMouseOver() then
    for i = 1, #j.chapters do
      local row = self.rows.items[i]
      if row and row:IsShown() and row:IsMouseOver() then return { kind = "chapter", i = i, frame = row } end
    end
  end
  -- (Visible: only the open tab's drop place counts.)
  if self.rscroll:IsMouseOver() then
    if self.dropHere:IsVisible() and self.dropHere:IsMouseOver() then return { kind = "chapter", i = self.src.sel(), frame = self.dropHere } end
    if self.shelf:IsVisible() and self.shelf:IsMouseOver() then return { kind = "shelf", frame = self.shelf } end
  end
end

function JED:DragUpdate()
  local item = self.drag
  if not item then return end
  -- (A missed drag stop must not leave the ghost on the screen.)
  if IsMouseButtonDown and not IsMouseButtonDown("LeftButton") then return self:EndDrag() end
  if item.boundary then
    -- The level under the cursor, on the ruler's scale.
    local j = self.src.journey()
    local a = j and j.chapters[item.boundary]
    if not a then return end
    local lo = j.chapters[1].floor
    local x = cursor(self.ruler) - (self.ruler:GetLeft() or 0)
    local level = math.floor(lo + x / self.rulerW * math.max(1, JED.RulerTop(j) - lo) + 0.5)
    if level ~= a.cap then self.src.edit(function(jj) JE.SetBoundary(jj, item.boundary, level) end) end
    local h = self.handles[item.boundary]
    if h then self:HandleTip(h) end
    return
  end
  local x, y = cursor(self.ghost)
  self.ghost:ClearAllPoints()
  self.ghost:SetPoint("LEFT", UIParent, "BOTTOMLEFT", x + 14, y)
  local t = self:Target()
  local frame = t and t.frame
  if frame ~= self.hover then
    self.hover = frame
    self:Paint()
  end
end

function JED:EndDrag()
  local item = self.drag
  if not item then return end
  local target = not item.boundary and self:Target() or nil
  self.drag, self.hover = nil, nil
  self.ghost:Hide()
  self.driver:SetScript("OnUpdate", nil)
  GameTooltip:Hide()
  if target then self:Drop(item, target) else self:Paint() end
end

-- A dungeon dropped on a chapter or on the shelf. (Dropping does not change the chosen chapter, so a row of
-- dungeons can be dragged in one after another.)
function JED:Drop(item, target)
  local src = self.src
  if target.kind == "chapter" then
    if item.key then src.edit(function(j) JE.Move(j, item.key, target.i) end)
    elseif item.base then src.edit(function(j) JE.Add(j, item.base, target.i) end) end
  elseif target.kind == "shelf" and item.key then
    src.edit(function(j) JE.Unplace(j, item.key) end)
  end
end

---------------------------------------------------------------------------
-- Drawing
---------------------------------------------------------------------------
-- The chapter rows' backgrounds and the drop places: the chosen chapter tinted, the one under a dragged dungeon
-- brighter.
function JED:Paint()
  local sel = self.src.sel()
  for i, row in ipairs(self.rows.items) do
    if row:IsShown() then
      local hover = self.hover == row
      row.bg:SetVertexColor(Theme:RGBA(hover and "gold" or "accent", hover and 0.45 or (i == sel and 0.16 or 0)))
    end
  end
  local dragging = self.drag ~= nil and not self.drag.boundary
  self.dropHere.bg:SetVertexColor(Theme:RGBA("gold", self.hover == self.dropHere and 0.35 or (dragging and 0.1 or 0)))
  self.shelf.bg:SetVertexColor(Theme:RGBA("B0321E", self.hover == self.shelf and 0.2 or 0))
end

-- Draws everything. The right page's tabs' stacks are handed to src.afterChapter and src.afterJourney, which place
-- their own frames on self.panes.chapter and self.panes.journey; the editor then sets the open tab's scroll height.
function JED:Refresh()
  local src = self.src
  local j = src.journey()
  if not j then return end
  local lw, rw = self.lw, self.rw
  local n = #j.chapters
  local sel = ns.Clamp(src.sel() or 1, 1, n)
  if sel ~= src.sel() then src.setSel(sel); return end
  local ch = j.chapters[sel]
  local per = {}
  for i = 1, n do per[i] = JE.InChapter(j, i) end

  -- Across both pages: as wide as the two pages are in the game; the right page's content starts under the plate,
  -- and the plate is shaded where it crosses the fold.
  if self.spread then
    local l, r = self.leftPage:GetLeft(), self.rightPage:GetRight()
    self.rulerW = self.plate:Fit((l and r and r - l > lw) and (r - l) or (lw + rw + SPINE))
    local top, bottom = self.rightPage:GetTop(), self.plate:GetBottom()
    local drop = (top and bottom and top - bottom > 0) and math.floor(top - bottom + GAP) or (PLATE_H + GAP)
    if drop ~= self.drop then
      self.drop = drop
      placeRight(self)
    end
    local pl, lr, rl = self.plate:GetLeft(), self.leftPage:GetRight(), self.rightPage:GetLeft()
    local fold = (pl and lr and rl and rl > lr) and ((lr + rl) / 2 - pl) or (lw + SPINE / 2)
    -- On the flat sheet (Journey Admin since 29 Oct 2026) there is no fold to bend over.
    self.plate:SetFold(not ns.Window:IsFlat() and fold or nil)
  end
  local rulerW = self.rulerW

  -- The ruler: every chapter from the first floor to the game's cap, the chosen one in the Leader colour; the marks
  -- between.
  local lo, top = j.chapters[1].floor, JED.RulerTop(j)
  local span = math.max(1, top - lo)
  local function xOf(level) return (ns.Clamp(level, lo, top) - lo) / span * rulerW end
  for i, seg in ipairs(self.segs) do
    local c = j.chapters[i]
    seg:SetShown(c ~= nil)
    if c then
      seg.i = i
      -- A chapter of one level (60-60) still gets a part to click, inside the ruler (it had none; seen in the check
      -- of 29 Oct 2026).
      local w = math.max(10, xOf(c.cap) - xOf(c.floor) - 1)
      seg:ClearAllPoints(); seg:SetPoint("TOPLEFT", self.ruler, "TOPLEFT", math.min(xOf(c.floor), rulerW - w), 0)
      seg:SetSize(w, RULER_H)
      seg.n:SetText(w >= 22 and ns.Journey.Roman(i) or "")
      -- Dark numbers on the pale chapters, white on the chosen one (white on yellow could not be read; 28 Oct 2026).
      -- The chosen one lies above its neighbours, so its bright edge shows on both sides.
      seg:SetFrameLevel(self.ruler:GetFrameLevel() + (i == sel and 2 or 1))
      seg.ring:SetShown(i == sel)
      if i == sel then
        seg.tex:SetVertexColor(ns.Hex(Theme.ACCENT.leader)); seg.tex:SetAlpha(1)
        seg.n:SetTextColor(1, 1, 1); seg.n:SetShadowColor(0, 0, 0, 0.8)
      else
        seg.tex:SetVertexColor(ns.Hex(c.color or "E2B857")); seg.tex:SetAlpha(0.85)
        seg.n:SetTextColor(ns.Hex("2A1C10")); seg.n:SetShadowColor(1, 1, 1, 0.35)
      end
      seg.n:SetShadowOffset(1, -1)
    end
  end
  for _, m in ipairs(self.marks) do
    m.tex:SetShown(m.v > lo and m.v <= top)
    m.tex:ClearAllPoints(); m.tex:SetPoint("TOP", self.ruler, "BOTTOMLEFT", xOf(m.v), 0)
  end
  for i, h in ipairs(self.handles) do
    h:SetShown(i < n)
    if i < n then
      h.i = i
      h:ClearAllPoints(); h:SetPoint("CENTER", self.ruler, "LEFT", xOf(j.chapters[i].cap), 0)
    end
  end
  -- The first label is where the journey starts (1 with the Prologue); then every 10 levels, where there is room.
  for i, t in ipairs(self.ticks) do
    local v = i == 1 and lo or t.v
    local shown = i == 1 or (t.v > lo and t.v <= top and xOf(t.v) - xOf(lo) >= 16)
    t.fs:SetShown(shown)
    if shown then
      t.fs:SetText(v)
      local point = i == 1 and "TOPLEFT" or (t.v == top and "TOPRIGHT" or "TOP")
      t.fs:ClearAllPoints(); t.fs:SetPoint(point, self.ruler, "BOTTOMLEFT", xOf(v), -7)
    end
  end
  self.split:SetEnabled(ch.floor < ch.cap and n < ns.Journey.MAX_CHAPTERS)
  self.merge:SetEnabled(sel < n)
  self.remove:SetEnabled(n > 1)

  -- The chapters, each with its dungeons as chips (in the colour of their role).
  local s = UI.Stack(self.list.child)
  local rowW = lw - 10
  for i, c in ipairs(j.chapters) do
    local row = self.rows:Get(i)
    if not row then break end
    row.i = i
    row.sw:SetVertexColor(ns.Hex(c.color or "E2B857"))
    row.n:SetText(ns.Journey.Roman(i))
    row.name:SetText(c.name)
    row.range:SetText(c.floor .. "-" .. c.cap)
    local x, y, shown = 52, 24, 0
    for k, pl in ipairs(per[i]) do
      local b = row.chips:Get(k)
      if not b then break end
      shown = k
      local p = j.place[pl.key]
      b.item = { key = pl.key }
      b.text:SetText(pl.d[2])
      local w = math.ceil(b.text:GetStringWidth()) + 14
      b:SetWidth(w)
      if x > 52 and x + w > rowW - 4 then x, y = 52, y + 22 end
      b:ClearAllPoints(); b:SetPoint("TOPLEFT", row, "TOPLEFT", x, -y)
      b:Show()
      x = x + w + 4
      local look = ROLE_LOOK[p.role] or ROLE_LOOK.m
      paint(b, look[1], look[2], look[3], look[4])
      b.tip = { pl.d[2], L[ROLE_NAME[p.role] or "ROLE_MANDATORY"] .. "  ·  " .. pl.d[3] .. "-" .. pl.d[4], L.ED_CHIP_TIP }
    end
    row.chips:HideFrom(shown + 1)
    row.none:SetShown(shown == 0)
    local h = shown == 0 and 46 or (y + 26)
    row:SetHeight(h)
    if i == sel then row.top, row.h = s.y, h end
    s:Place(row, h, 0)
  end
  self.rows:HideFrom(n + 1)
  self.list:SetContentHeight(s.y)
  -- A newly chosen chapter (on the ruler, or at the start) comes into view in the list; the list stays where it is
  -- while that chapter is edited.
  local chosen = self.rows:Get(sel)
  if sel ~= self.revealed and chosen and chosen.top and self.list:Reveal(chosen.top, chosen.h) then
    self.revealed = sel
  end

  -- Right page, This chapter: the chosen chapter.
  local C = self.panes.chapter
  local r = UI.Stack(C)
  self.chHead:SetText(L.CHAPTER_ROMAN:format(ns.Journey.Roman(sel)))
  r:Place(self.chHead, 29, 8)
  r:Place(self.nameLabel, 16, 2)
  if not self.name.edit:HasFocus() then self.name:SetText(ch.name) end
  r:Place(self.name, 26, 10)
  local fy = r.y
  r:Place(self.floorLabel, 16, 2)
  r:Place(self.floor, 26, 10)
  self.capLabel:ClearAllPoints(); self.capLabel:SetPoint("TOPLEFT", C, "TOPLEFT", rw / 2, -fy)
  self.cap:ClearAllPoints(); self.cap:SetPoint("TOPLEFT", C, "TOPLEFT", rw / 2, -(fy + 18))
  self.floor:Refresh(); self.cap:Refresh()
  local issues = ns.Journey.Issues(j, sel)
  for i, text in ipairs(issues) do
    local fs = self.issues:Get(i)
    if not fs then break end
    fs:SetText(text)
    r:Place(fs, fs:GetStringHeight(), 4)
  end
  self.issues:HideFrom(#issues + 1)
  r:Skip(6)
  local dy = r.y
  r:Place(self.dHead, 29, 6)
  local shown = 0
  for i, pl in ipairs(per[sel]) do
    local c = self.drows:Get(i)
    if not c then break end
    shown = i
    c.key = pl.key
    c.name:SetText(pl.d[2])
    c.levels:SetText(pl.d[3] .. "-" .. pl.d[4])
    c.roles:Refresh()
    local bosses = ns.Clears:Bosses(pl.key)
    local p = j.place[pl.key]
    c.bosses:SetLabel(#bosses > 0 and L.ADMIN_BOSSES:format(#(p.bosses or ns.Clears:DefaultNeeded(pl.key)), #bosses) or L.ADMIN_BOSSES_NONE)
    c.bosses:SetEnabled(#bosses > 0)
    r:Place(c, 58, 6)
  end
  self.drows:HideFrom(shown + 1)
  self.empty:SetShown(shown == 0)
  if shown == 0 then r:Place(self.empty, self.empty:GetStringHeight(), 6) end
  self.dropHere:ClearAllPoints(); self.dropHere:SetPoint("TOPLEFT", C, "TOPLEFT", 0, -dy)
  self.dropHere:SetHeight(math.max(30, r.y - dy))
  r:Skip(12)
  if src.afterChapter then src.afterChapter(r) end
  local heights = { chapter = r.y }

  -- Every dungeon: the shelf.
  r = UI.Stack(self.panes.shelf)
  self.shelfHint:SetText(L.ED_SHELF_HINT:format(ns.Journey.Roman(sel)))
  r:Place(self.shelfHint, self.shelfHint:GetStringHeight(), 6)
  for _, b in ipairs(self.shelfChips) do
    local base, d = b.item.base, b.d
    local chs = JE.ChaptersOf(j, base)
    local here, mid = false, (d[3] + d[4]) / 2
    for _, c in ipairs(chs) do if c == sel then here = true end end
    local fits = mid >= ch.floor and mid < math.max(ch.cap, ch.floor + 1)
    if here then paint(b, "page2", 0.6, "line", "ink2")
    elseif fits then paint(b, "gold", 0.3, "gold", "ink")
    else paint(b, "page2", 0.95, "bookEdge", #chs > 0 and "ink2" or "ink") end
    b.check:SetShown(here)
    -- The name gets the room the check does not take. A name still too long (retail's "Dire Maul - Warpwood
    -- Quarter", check of 30 Oct 2026, 22:00) takes the level range's room too: the tooltip has both.
    local room = b:GetWidth() - 12 - (here and 18 or 0)
    local long = full(b.text) > room - full(b.sub) - 4
    b.sub:SetShown(not long)
    b.check:ClearAllPoints()
    if long then b.check:SetPoint("RIGHT", -6, 0) else b.check:SetPoint("RIGHT", b.sub, "LEFT", -4, 0) end
    b.text:SetWidth(long and room or room - full(b.sub) - 4)
    local romans = {}
    for _, c in ipairs(chs) do romans[#romans + 1] = ns.Journey.Roman(c) end
    b.tip = { d[2], d[3] .. "-" .. d[4] .. "  ·  " .. (#chs > 0 and L.ED_SHELF_IN:format(table.concat(romans, ", ")) or L.ED_SHELF_FREE), L.ED_SHELF_TIP }
  end
  r:Place(self.shelf, self.shelf:GetHeight(), 12)
  heights.shelf = r.y

  -- Whole journey: start over from a preset, or Import; a line each, the button and its text centred on each other.
  local J = self.panes.journey
  r = UI.Stack(J)
  r:Place(self.startLabel, 16, 6)
  for _, w in ipairs(self.whole) do
    local th = w.text:GetStringHeight()
    local h = math.max(28, th)
    w.b:ClearAllPoints(); w.b:SetPoint("TOPLEFT", J, "TOPLEFT", 0, -(r.y + (h - 28) / 2))
    w.text:ClearAllPoints(); w.text:SetPoint("TOPLEFT", J, "TOPLEFT", self.wholeW + 10, -(r.y + (h - th) / 2))
    r:Skip(h + 6)
  end
  r:Skip(6)
  if src.afterJourney then src.afterJourney(r) end
  heights.journey = r.y

  for k, p in pairs(self.panes) do
    p:SetHeight(math.max(1, heights[k]))
    p:SetShown(k == self.tab)
  end
  self.tabs:Refresh()
  self.rscroll:SetContentHeight(heights[self.tab] + 8)
  self:Paint()
end
