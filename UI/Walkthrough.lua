-- Show me around (27 Oct 2026): a walkthrough of the book for your rank. A guide card beside the book says what one
-- part is for, with Back, Next and Skip; that part has a gold frame with sparks (UI/Glow.lua) and the rest of the book
-- is dimmed and cannot be clicked. The book shows a sample fellowship meanwhile (Fellowship/Sample.lua), drawn as
-- you with the tour's rank (Watch.demo), so every page has something to show and nothing real changes.
-- Two tours: Leader and Adventurer (two ranks since 27 Oct 2026). Offered once after the setup guide; Settings runs it again; a promotion
-- offers a short tour of only what is new for you.
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
  { id = "STAND", ranks = ALL, page = "overview", target = function() return pf("overview").you end },
  { id = "STANDINGS", ranks = ALL, page = "overview", target = function() return pf("overview").right end },
  { id = "CHAPTER", ranks = ALL, page = "chapter", target = function() return pf("chapter").rows.items[1] end },
  { id = "CLEARS", ranks = ALL, page = "chapter", target = function() return pf("chapter").matrix end },
  { id = "QUESTS", ranks = ALL, page = "quests", target = function() return pf("quests").left end },
  { id = "HISTORY", ranks = ALL, page = "chronicle", target = function() return pf("chronicle").left end },
  { id = "COMPANIONS", ranks = ALL, page = "heroes", target = function() return pf("heroes").listR end },
  { id = "YOURSELF", ranks = ALL, page = "heroes", before = function() pf("heroes").sel = ns.Me() end,
    target = function() return pf("heroes").insR end },
  { id = "GATHERINGS", ranks = ALL, page = "gatherings", target = function() return pf("gatherings").left end },
  { id = "INVITE", ranks = ALL, page = "heroes", target = function() return pf("heroes").invHead, pf("heroes").send end },
  -- The rulebook, then the Leader's Manage with its Rules tab, one after the other; Journey Admin last before the
  -- end (the tour went Manage, Rules, Journey Admin, Rules tab: back and forth; 28 Oct 2026).
  { id = "RULES", ranks = ALL, page = "rules", target = function() return pf("rules").left end },
  { id = "MANAGE", ranks = { leader = true }, page = "manage", target = function() return pf("manage").left end },
  { id = "RULESADMIN", ranks = { leader = true }, page = "rulesadmin", target = function() return pf("rulesadmin").left end },
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

-- Your rank in your own fellowship: "leader" or "member" (nil outside one).
function WK:MyRank()
  local f = ns.Fellowship:Current()
  return f and ns.Permissions.Rank(f, ns.Me()) or nil
end

-- The steps of a tour: every step of that rank, or (since = an earlier rank) only what is new since that rank.
function WK:Steps(rank, since)
  local out = {}
  for _, s in ipairs(self.STEPS) do
    local new = not since or not s.ranks[since] or s.id == "DONE"
    if s.ranks[rank] and new then out[#out + 1] = s end
  end
  if since then table.insert(out, 1, { id = "NEW", ranks = ALL, page = "overview" }) end
  return out
end

local function text(step, rank, part)
  local key = "WALK_" .. step.id .. (part or "")
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
  c.skip = UI.TextButton(c, L.WALK_SKIP, function() WK:Stop() end, "link", 12)
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
  c.kicker:SetText(L["WALK_TOUR_" .. rank:upper()]:upper())
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
-- rank: the tour's rank (default: yours); since: only what is new since that rank (after a promotion).
function WK:Start(rank, since)
  if not ns.Fellowship:Current() then return false end
  rank = rank or self:MyRank() or "member"
  build()
  self.rank, self.since = rank, since
  self.steps = self:Steps(rank, since)
  self.i, self.on, self.offer = 1, true, nil
  self.card.back:SetLabel(L.WALK_BACK)
  local Wt = ns.Watch
  Wt.demo, Wt.as, Wt.fid, Wt.active = ns.Sample:Build(rank), ns.Self(), nil, true
  W():HidePanels()
  W():Open("overview")
  W():WhenBuilt(function() WK:Go(1) end)
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
    WK.glow:Around(first, last, step.outside)
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
  c.next:SetLabel(step.id == "DONE" and L.WALK_FINISH or L.WALK_NEXT)
  c.skip:SetShown(step.id ~= "DONE")
  c:Show()
  place()
  -- Places again once the frames have their final positions.
  C_Timer.After(0, function() if WK.on then place() end end)
end

function WK:Next() if self.offer then return self:Start(self.offer.rank, self.offer.since) end self:Go(self.i + 1) end
function WK:Back() if self.offer then return self:Later() end self:Go(math.max(1, self.i - 1)) end

-- Ends the tour (done = it went to the end); your own fellowship shows again.
function WK:Stop(done)
  local was = self.on
  self.on, self.offer = false, nil
  if self.card then self.card:Hide() end
  if self.glow then self.glow:Off() end
  if self.dim then self.dim:Hide() end
  local Wt = ns.Watch
  if Wt.demo then Wt.demo, Wt.as, Wt.active = nil, nil, false end
  if was and ns.char then
    ns.char.walk = ns.char.walk or {}
    ns.char.walk[self.rank or "member"] = done and "done" or "skipped"
  end
  if was and W():IsOpen() then
    local hp = pf("heroes")
    if hp then hp.sel = nil end
    W():ShowPage("overview")
  end
end

---------------------------------------------------------------------------
-- Offers
---------------------------------------------------------------------------
-- The card alone: "Show me around?" with Show me around / Later.
function WK:Offer(rank, since)
  if self.on or not ns.Fellowship:Current() or not W():IsOpen() then return false end
  build()
  self.offer = { rank = rank, since = since }
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

function WK:Later()
  self.offer = nil
  if self.card then self.card:Hide() end
  self.card.back:SetLabel(L.WALK_BACK)
  if ns.char then
    ns.char.walk = ns.char.walk or {}
    ns.char.walk[self:MyRank() or "member"] = ns.char.walk[self:MyRank() or "member"] or "later"
  end
end

-- After the setup guide: once per character and rank.
function WK:OfferOnce()
  local rank = self:MyRank()
  if not rank or (ns.char.walk and ns.char.walk[rank]) then return false end
  return self:Offer(rank)
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
