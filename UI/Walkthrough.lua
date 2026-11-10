-- Show me around (27 Oct 2026): a walkthrough of the book for your rank. A guide card beside the book says what one
-- part is for, with Back, Next and Skip; that part has a gold frame with sparks (UI/Glow.lua) and the rest of the book
-- is dimmed and cannot be clicked. The book shows a sample fellowship meanwhile (Fellowship/Sample.lua), drawn as
-- you with the tour's rank (Watch.demo), so every page has something to show and nothing real changes.
-- Two tours: Leader and Adventurer (two ranks since 27 Oct 2026). Offered once after the setup guide as a short first
-- tour (the Overview and what you see first; the owner, 8 Nov 2026: the whole book at once was too long); a page's
-- own help is its "?" (About this page). Settings runs the whole tour; a promotion offers a short tour of only what is
-- new for you.
local _, ns = ...
local L = ns.L
local UI = ns.UI
local WK = { on = false, i = 1, steps = {} }
ns.Walkthrough = WK

local RANKS = { member = 1, leader = 2 }
local ALL = { member = true, leader = true }
local CARD_W, GAP = 330, 18

local function W() return ns.Window end
local function pf(id) return W().pageFrames[id] end

-- The steps: page to open, what to frame (one frame, or two: from the first's top left to the second's bottom right),
-- which ranks see it, and what to set up first. Texts: WALK_<ID>_T and WALK_<ID> (or WALK_<ID>_<RANK> for one rank).
WK.STEPS = {
  { id = "INTRO", ranks = ALL, page = "overview", target = function() return W().frame.header end },
  { id = "NAV", ranks = ALL, page = "overview", target = function() return W().frame.nav end },
  -- The Overview's three parts, then Where we stand (U146, the rebuild of 9 Nov 2026).
  { id = "FOCUS", ranks = ALL, page = "overview", target = function() return pf("overview").focus end },
  { id = "SINCE", ranks = ALL, page = "overview", target = function() return pf("overview").since end },
  { id = "COMING", ranks = ALL, page = "overview", target = function() return pf("overview").coming end },
  { id = "STAND", ranks = ALL, page = "overview", target = function() return pf("overview").pic, pf("overview").stand end },
  -- Your To do: its heading to the first dungeon.
  { id = "CHAPTER", ranks = ALL, page = "chapter", target = function()
    local p = pf("chapter")
    return p.todoHead, p.rows.items[1]
  end },
  { id = "CLEARS", ranks = ALL, page = "chapter", target = function() return pf("chapter").matrix end },
  -- A dungeon's page: the chapter's first.
  { id = "DUNGEON", ranks = ALL, page = "dungeon", before = function()
    local x = (pf("chapter").rows.items[1] or {}).key
    if x then W().dungeon = x end
  end, target = function() return pf("dungeon").right end },
  { id = "QUESTS", ranks = ALL, page = "quests", target = function() return pf("quests").left end },
  { id = "HISTORY", ranks = ALL, page = "chronicle", target = function() return pf("chronicle").left end },
  { id = "COMPANIONS", ranks = ALL, page = "heroes", target = function() return pf("heroes").listR end },
  { id = "YOURSELF", ranks = ALL, page = "heroes", before = function() pf("heroes").sel = ns.Me() end,
    target = function() return pf("heroes").insR end },
  { id = "GATHERINGS", ranks = ALL, page = "gatherings", target = function() return pf("gatherings").left end },
  { id = "INVITE", ranks = ALL, page = "heroes", before = function() pf("heroes").invOpen = true end, target = function() return pf("heroes").invHead, pf("heroes").send end },
  -- The rulebook (where the Leader edits it, U143), then the Leader's Manage; Journey Admin last before the end (the
  -- tour went back and forth between them; 28 Oct 2026).
  { id = "RULES", ranks = ALL, page = "rules", target = function() return pf("rules").left end },
  { id = "MANAGE", ranks = { leader = true }, page = "manage", target = function() return pf("manage").left end },
  { id = "HEADER", ranks = ALL, target = function()
    local h = W().frame.header
    return h.chars, h.settings
  end },
  { id = "TRACKER", ranks = ALL, outside = true, target = function()
    local t = ns.Tracker and ns.Tracker.frame
    return t and t:IsShown() and t or nil
  end },
  { id = "ADMIN", ranks = { leader = true }, page = "admin", target = function() return pf("admin").left end },
  { id = "DONE", ranks = ALL },
}

-- About this page (the owner, 7 Nov 2026): the header's "?" walks through the page you are on, on your own fellowship
-- (no sample), so what each page does can be looked up any time without the whole tour. Two steps: its left page
-- (what the page is for) and its right page. Texts: WALK_PG_<PAGE>_T / WALK_PG_<PAGE> and WALK_PG_<PAGE>_R_T /
-- WALK_PG_<PAGE>_R. A flat sheet of parts (the Overview) goes part by part instead: WK.PARTS, WALK_PG_<PAGE>_<PART>.
WK.PAGES = { welcome = true, create = true, join = true, overview = true, chapter = true, quests = true,
  chronicle = true, moments = true, raids = true, heroes = true, gatherings = true, rules = true, history = true,
  tourney = true, settings = true, manage = true, managefellowship = true, rulesadmin = true, admin = true,
  dungeon = true, dungeons = true }
WK.PARTS = {
  overview = { { "", function(p) return p.pic, p.stand end }, { "_FOCUS", function(p) return p.focus end },
    { "_SINCE", function(p) return p.since end }, { "_COMING", function(p) return p.coming end } },
  dungeons = { { "", function(p) return p.scroll end } },
}

-- The first tour: these steps of the whole tour, then its own end (WALK_FIRSTDONE). No page shows you around by
-- itself any more (U146): help is this short tour and the ?.
WK.FIRST = { INTRO = true, NAV = true, FOCUS = true, SINCE = true, COMING = true, STAND = true, HEADER = true, TRACKER = true }

-- Your rank in your own fellowship: "leader" or "member" (nil outside one).
function WK:MyRank()
  local f = ns.Fellowship:Current()
  return f and ns.Permissions.Rank(f, ns.Me()) or nil
end

-- The steps of a tour: every step of that rank, or (since = an earlier rank) only what is new since that rank, or
-- (first) the first tour's.
function WK:Steps(rank, since, first)
  local out = {}
  for _, s in ipairs(self.STEPS) do
    local new = not since or not s.ranks[since] or s.id == "DONE"
    if s.ranks[rank] and new and (not first or self.FIRST[s.id]) then out[#out + 1] = s end
  end
  if first then out[#out + 1] = { id = "DONE", key = "FIRSTDONE", ranks = ALL } end
  if since then table.insert(out, 1, { id = "NEW", ranks = ALL, page = "overview" }) end
  return out
end

local function text(step, rank, part)
  local key = "WALK_" .. (step.key or step.id) .. (part or "")
  return L[key .. "_" .. rank:upper()] ~= key .. "_" .. rank:upper() and L[key .. "_" .. rank:upper()] or L[key]
end
WK.Text = text

---------------------------------------------------------------------------
-- The card, the dimming and the highlight
---------------------------------------------------------------------------
local function build()
  if WK.card then return end
  -- On the book (its scale, so the text is the book's size; it was on the screen and small; seen in the tour).
  local c = UI.Box(W().frame, 2, nil, nil, "gold", 1)
  c.layoutCover = true -- hides the page under it (Dev/Layout.lua)
  c.layoutBeside = true -- and may sit beside the book (the offer, U88)
  c:SetSize(CARD_W, 150)
  c:SetFrameStrata("FULLSCREEN_DIALOG")
  c:SetFrameLevel(W().frame:GetFrameLevel() + 500)
  c:SetClampedToScreen(true)
  c:EnableMouse(true)
  local bg = UI.GradientTex(c, "BACKGROUND", "VERTICAL", { "dark", 1 }, { "toastTop", 1 }) -- solid: a red button showed through (seen in the seventh check)
  bg:SetPoint("TOPLEFT", 2, -2); bg:SetPoint("BOTTOMRIGHT", -2, 2)
  local inner = UI.Box(c, 1, nil, nil, "gold", 0.35)
  inner:SetPoint("TOPLEFT", 3, -3); inner:SetPoint("BOTTOMRIGHT", -3, 3)
  c.kicker = UI.Text(c, 12, "gold", "body")
  c.kicker:SetPoint("TOPLEFT", 16, -14)
  c.count = UI.Text(c, 12, "gold", "body", "RIGHT")
  c.count:SetPoint("TOPRIGHT", -16, -14)
  -- Progress: a thin line, filled up to this step.
  c.track = UI.Solid(c, "ARTWORK", "gold", 0.25)
  c.track:SetPoint("TOPLEFT", 16, -32); c.track:SetPoint("TOPRIGHT", -16, -32); c.track:SetHeight(3)
  c.fill = UI.Solid(c, "OVERLAY", "F2C25B", 1)
  c.fill:SetPoint("TOPLEFT", c.track, "TOPLEFT"); c.fill:SetHeight(3)
  -- The title wraps (a long one was cut short; seen in the tour).
  c.title = UI.WrapText(c, 19, "goldText", CARD_W - 32, "title")
  c.title:SetPoint("TOPLEFT", 16, -44)
  c.title:SetShadowOffset(0, -1); c.title:SetShadowColor(0, 0, 0, 1)
  c.text = UI.WrapText(c, 14, "toastText", CARD_W - 32, "body")
  c.text:SetPoint("TOPLEFT", c.title, "BOTTOMLEFT", 0, -6)
  c.next = UI.TextButton(c, L.WALK_NEXT, function() WK:Next() end, "primary", 13)
  c.back = UI.TextButton(c, L.WALK_BACK, function() WK:Back() end, "plain", 13)
  c.skip = UI.TextButton(c, L.WALK_SKIP, function() WK:Stop(false) end, "link", 12)
  c:Hide()
  WK.card = c
  WK.glow = UI.Highlight(UIParent)
  -- A small pointer from the card to the framed part.
  c.arrow = c:CreateTexture(nil, "OVERLAY")
  c.arrow:SetSize(26, 26)
  if not (c.arrow.SetAtlas and C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo("NPE_ArrowDown")) then c.arrow:Hide() c.arrow.none = true
  else c.arrow:SetAtlas("NPE_ArrowDown") end
end

-- The dark veil over the book, with a window where the highlight is; it also keeps the book from being clicked.
local function veil()
  if WK.dim then return WK.dim end
  local win = W().frame
  local d = CreateFrame("Frame", nil, win)
  d:SetAllPoints(win)
  d:SetFrameLevel(win:GetFrameLevel() + 400)
  d:EnableMouse(true)
  d.parts = {}
  for i = 1, 4 do
    local t = d:CreateTexture(nil, "OVERLAY")
    t:SetColorTexture(0, 0, 0, 0.55)
    d.parts[i] = t
  end
  WK.dim = d
  return d
end

-- Around the highlight h (inside the book), or the whole book (h nil, or the target is outside it).
local function shade(h)
  local d, win = veil(), W().frame
  local p = d.parts
  for _, t in ipairs(p) do t:ClearAllPoints() end
  if not h then
    p[1]:SetAllPoints(win)
    for i = 2, 4 do p[i]:Hide() end
    p[1]:Show()
    d:Show()
    return
  end
  -- Above, below, left of and right of the frame.
  p[1]:SetPoint("TOPLEFT", win, "TOPLEFT"); p[1]:SetPoint("TOPRIGHT", win, "TOPRIGHT"); p[1]:SetPoint("BOTTOM", h, "TOP")
  p[2]:SetPoint("BOTTOMLEFT", win, "BOTTOMLEFT"); p[2]:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT"); p[2]:SetPoint("TOP", h, "BOTTOM")
  p[3]:SetPoint("LEFT", win, "LEFT"); p[3]:SetPoint("TOP", h, "TOP"); p[3]:SetPoint("BOTTOM", h, "BOTTOM"); p[3]:SetPoint("RIGHT", h, "LEFT")
  p[4]:SetPoint("RIGHT", win, "RIGHT"); p[4]:SetPoint("TOP", h, "TOP"); p[4]:SetPoint("BOTTOM", h, "BOTTOM"); p[4]:SetPoint("LEFT", h, "RIGHT")
  for _, t in ipairs(p) do t:Show() end
  d:Show()
end

-- Scrolls a page so the target is in view (its scroll frame is a parent with a .child).
local function reveal(target)
  local sf = target and target:GetParent()
  while sf and not (sf.child and sf.SetVerticalScroll) do sf = sf:GetParent() end
  if not sf then return end
  local top, ct = target:GetTop(), sf.child:GetTop()
  if not top or not ct then return end
  sf:SetVerticalScroll(math.max(0, (ct - top) - 12))
  local wheel = sf:GetScript("OnMouseWheel")
  if wheel then wheel(sf, 0) end
end

-- The card beside the framed part, inside the dimmed book: right of it when there is room, else left, else under or
-- over it (it was outside the book and covered the logo; seen in the tour). Without a frame: in the middle.
local function place()
  local c, win = WK.card, W().frame
  local h = WK.glow:IsShown() and WK.glow or nil
  c:ClearAllPoints()
  if c.arrow and not c.arrow.none then c.arrow:Hide() end
  -- The offer: beside the book, right of it where the screen has room, else left of it, else in the book's lower
  -- right corner; never over Focus now, the first thing a new Leader looks at (U88).
  if WK.offer then
    local ui, ws = UIParent:GetEffectiveScale() or 1, win:GetEffectiveScale() or 1
    local need = (CARD_W + GAP + 8) * ws / ui
    local right = (UIParent:GetRight() or 0) - (win:GetRight() or 0) * ws / ui
    local left = (win:GetLeft() or 0) * ws / ui
    if right >= need then c:SetPoint("TOPLEFT", win, "TOPRIGHT", GAP, -60)
    elseif left >= need then c:SetPoint("TOPRIGHT", win, "TOPLEFT", -GAP, -60)
    else c:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -28, 28) end
    return
  end
  if not h or WK.steps[WK.i] and WK.steps[WK.i].outside then
    c:SetPoint("CENTER", win, "CENTER", 0, 20)
    return
  end
  local ws, hs = win:GetEffectiveScale(), h:GetEffectiveScale()
  local function x(v) return v and v * hs / ws or 0 end
  local wl, wr, wt, wb = win:GetLeft() or 0, win:GetRight() or 0, win:GetTop() or 0, win:GetBottom() or 0
  local hl, hr, ht, hb = x(h:GetLeft()), x(h:GetRight()), x(h:GetTop()), x(h:GetBottom())
  local ch = c:GetHeight()
  local function arrow(rot, ...)
    if c.arrow.none then return end
    c.arrow:ClearAllPoints(); c.arrow:SetPoint(...)
    c.arrow:SetRotation(rot); c.arrow:Show()
  end
  local top = math.min(ht, wt - 20) - wb
  top = math.max(top, ch + 20)
  if wr - hr >= CARD_W + GAP + 16 then
    c:SetPoint("TOPLEFT", win, "BOTTOMLEFT", hr - wl + GAP, top)
    arrow(-math.pi / 2, "RIGHT", c, "LEFT", 2, 0)
  elseif hl - wl >= CARD_W + GAP + 16 then
    c:SetPoint("TOPRIGHT", win, "BOTTOMLEFT", hl - wl - GAP, top)
    arrow(math.pi / 2, "LEFT", c, "RIGHT", -2, 0)
  elseif hb - wb >= ch + GAP + 16 then
    c:SetPoint("TOP", win, "BOTTOMLEFT", (hl + hr) / 2 - wl, hb - wb - GAP)
    arrow(math.pi, "BOTTOM", c, "TOP", 0, -2)
  else
    c:SetPoint("BOTTOM", win, "BOTTOMLEFT", (hl + hr) / 2 - wl, math.min(ht - wb + GAP, wt - wb - ch - 8))
    arrow(0, "TOP", c, "BOTTOM", 0, 2)
  end
end
local function fill(step, n, of, rank)
  local c = WK.card
  c.kicker:SetText((WK.page and L.WALK_PAGE or L["WALK_TOUR_" .. rank:upper()]):upper())
  c.count:SetText(n and L.WALK_COUNT:format(n, of) or "")
  c.track:SetShown(n ~= nil); c.fill:SetShown(n ~= nil)
  if n then c.fill:SetWidth(math.max(3, (CARD_W - 32) * n / of)) end
  c.title:SetText(text(step, rank, "_T"))
  c.text:SetText(text(step, rank))
  local h = 44 + c.title:GetStringHeight() + 6 + c.text:GetStringHeight() + 16
  c.next:ClearAllPoints(); c.next:SetPoint("TOPRIGHT", c, "TOPRIGHT", -16, -h)
  c.back:ClearAllPoints(); c.back:SetPoint("RIGHT", c.next, "LEFT", -8, 0)
  c.skip:ClearAllPoints(); c.skip:SetPoint("LEFT", c, "TOPLEFT", 16, -(h + 14))
  c:SetHeight(h + 44)
end

---------------------------------------------------------------------------
-- Running a tour
---------------------------------------------------------------------------
-- Frames are made out of combat only: a start in combat before the card exists waits for the combat to end.
local function later(fn)
  if WK.card or not ns.Combat:InCombat() then return false end
  ns.Combat:AfterCombat(fn)
  return true
end

-- rank: the tour's rank (default: yours); since: only what is new since that rank (after a promotion); first: the
-- first tour.
function WK:Start(rank, since, first)
  if not ns.Fellowship:Current() then return false end
  if later(function() WK:Start(rank, since, first) end) then return false end
  rank = rank or self:MyRank() or "member"
  build()
  self.rank, self.since, self.first = rank, since, first
  self.steps = self:Steps(rank, since, first)
  self.page = nil
  self.i, self.on, self.offer = 1, true, nil
  self.card.back:SetLabel(L.WALK_BACK)
  self.card.skip:SetLabel(L.WALK_SKIP)
  local Wt = ns.Watch
  Wt.demo, Wt.as, Wt.fid, Wt.active = ns.Sample:Build(rank), ns.Self(), nil, true
  W():HidePanels()
  W():Open("overview")
  W():WhenBuilt(function() WK:Go(1) end)
  return true
end

function WK:HasHelp(id) return id ~= nil and self.PAGES[id] == true end

-- About this page: its left page, then its right page (a half that does not show is passed over by Go: the card then
-- sits in the middle). Stays on the page and changes nothing.
function WK:StartPage(id)
  id = id or W().current
  if self.on or not self:HasHelp(id) then return false end
  if later(function() if W().frame:IsShown() then WK:StartPage() end end) then return false end
  build()
  local key = "PG_" .. id:upper()
  self.rank, self.since, self.first, self.page = self:MyRank() or "member", nil, nil, id
  self.steps = {
    { id = key, target = function() return pf(id) and pf(id).left end },
    { id = key .. "_R", target = function() return pf(id) and pf(id).right end },
  }
  if self.PARTS[id] then
    self.steps = {}
    for i, part in ipairs(self.PARTS[id]) do
      self.steps[i] = { id = key .. part[1], target = function() return pf(id) and part[2](pf(id)) end }
    end
  end
  self.i, self.on, self.offer = 1, true, nil
  self.card.back:SetLabel(L.WALK_BACK)
  self.card.skip:SetLabel(L.WALK_CLOSE)
  W():HidePanels()
  self:Go(1)
  return true
end

function WK:Go(i)
  if not self.on then return end
  local step = self.steps[i]
  if not step then return self:Stop(true) end
  self.i = i
  local win = W()
  if step.page then win:ShowPage(step.page) end
  if step.before then step.before() end
  win:Refresh()
  -- What to frame (the rendering swap is over: frames are drawn, and targets are read from them).
  local first, last = nil, nil
  if step.target then first, last = step.target() end
  local shown = first and first:IsVisible()
  WK.glow:Off()
  if shown then
    reveal(first)
    shown = WK.glow:Around(first, last, step.outside)
  end
  shade((shown and not step.outside) and WK.glow or nil)
  local n = step.id ~= "DONE" and step.id ~= "INTRO" and step.id ~= "NEW"
  local count, of = 0, 0
  for k, s in ipairs(self.steps) do
    if s.id ~= "DONE" and s.id ~= "INTRO" and s.id ~= "NEW" then of = of + 1; if k <= i then count = count + 1 end end
  end
  fill(step, n and count or nil, of, self.rank)
  local c = self.card
  c.back:SetShown(i > 1)
  c.next:SetLabel((step.id == "DONE" or (self.page and i == #self.steps)) and L.WALK_FINISH or L.WALK_NEXT)
  c.skip:SetShown(step.id ~= "DONE" and not (self.page and i == #self.steps))
  c:Show()
  place()
  -- Places again once the frames have their final positions.
  C_Timer.After(0, function() if WK.on then place() end end)
end

function WK:Next() if self.offer then return self:Start(self.offer.rank, self.offer.since, self.offer.first) end self:Go(self.i + 1) end
function WK:Back() if self.offer then return self:Later() end self:Go(math.max(1, self.i - 1)) end

-- Ends the tour (done = it went to the end; false = Skip); your own fellowship shows again.
function WK:Stop(done)
  local was = self.on
  local page = self.page
  self.page = nil
  self.on, self.offer = false, nil
  if self.card then self.card:Hide() end
  if self.glow then self.glow:Off() end
  if self.dim then self.dim:Hide() end
  local Wt = ns.Watch
  if Wt.demo then Wt.demo, Wt.as, Wt.active = nil, nil, false end
  if was and ns.char and not page then
    ns.char.walk = ns.char.walk or {}
    ns.char.walk[self.rank or "member"] = done and "done" or "skipped"
  end
  if was and page and W():IsOpen() then W():Refresh() end
  if was and not page and W():IsOpen() then
    local hp = pf("heroes")
    if hp then hp.sel, hp.invOpen = nil, nil end -- (the Invite step opened its box)
    W():ShowPage("overview")
  end
  -- What's New waited for the tour (UI/News.lua).
  if was and W():IsOpen() then ns.News:ShowIfDue() end
end

---------------------------------------------------------------------------
-- Offers
---------------------------------------------------------------------------
-- The card alone: "Show me around?" with Show me around / Later.
function WK:Offer(rank, since, first)
  if self.on or not ns.Fellowship:Current() or not W():IsOpen() then return false end
  build()
  self.offer = { rank = rank, since = since, first = first }
  local step = { id = since and "OFFER_NEW" or "OFFER" }
  fill(step, nil, 1, rank)
  local c = self.card
  c.next:SetLabel(L.WALK_START)
  c.back:SetLabel(L.WALK_LATER)
  c.back:SetShown(true); c.skip:Hide()
  WK.glow:Off()
  c:Show()
  place()
  return true
end

-- Later: What's New may come now.
function WK:Later()
  self.offer = nil
  if self.card then self.card:Hide() end
  self.card.back:SetLabel(L.WALK_BACK)
  if ns.char then
    ns.char.walk = ns.char.walk or {}
    ns.char.walk[self:MyRank() or "member"] = ns.char.walk[self:MyRank() or "member"] or "later"
  end
  if W():IsOpen() then ns.News:ShowIfDue() end
end

-- After the setup guide: the first tour, once per character and rank. Until it is answered (Show me around, Later),
-- the book asks again each time it opens (walkOffer; it was lost when the book closed or the game reloaded first).
function WK:OfferOnce()
  local rank = self:MyRank()
  if not rank or (ns.char.walk and ns.char.walk[rank]) then ns.char.walkOffer = nil return false end
  ns.char.walkOffer = self:Offer(rank, nil, true) or ns.char.walkOffer
  return ns.char.walkOffer == true and self.offer ~= nil
end

-- A promotion (an Adventurer becomes the Leader): a short tour of what is new, when an earlier tour was seen.
function WK:CheckPromotion()
  local rank = self:MyRank()
  local walk = ns.char and ns.char.walk
  if self.on or not rank or not walk or walk[rank] then return false end
  local best
  for r, v in pairs(walk) do
    if (v == "done" or v == "skipped") and RANKS[r] < RANKS[rank] and (not best or RANKS[r] > RANKS[best]) then best = r end
  end
  if not best then return false end
  walk[rank] = "offered"
  return self:Offer(rank, best)
end

ns:On("FELLOWSHIP", function()
  if WK.on or not W() or not W():IsOpen() then return end
  C_Timer.After(0.5, function() WK:CheckPromotion() end)
end)
