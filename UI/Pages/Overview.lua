-- Overview (SPEC §4.4, §6). Left: Where you stand (the chapter's state and steps, your level between floor and cap,
-- your next steps, who is online, the counts), Getting started, the next Gathering, the contents (every chapter:
-- done, current or yet to be revealed) and the chronicle.
-- Right: the chapter chosen in the contents: picture, where the Companions stand (the current chapter) or its status
-- (another one), its dungeons, buttons.
local _, ns = ...
local L = ns.L
local UI, Theme = ns.UI, ns.Theme
local J, Hr = ns.Journey, ns.Hero

-- Where you stand (27 Oct 2026, the review "a quick look at where we are"): one card at the top of the left page with
-- the chapter's state, its three steps, your level between floor and cap, your next steps, who is online, and how
-- many Companions are below the floor, ready, at the cap, over the cap and away. It replaced the You card, the
-- status banner, What's next, the four count boxes and the level track (What's next is on the Chapter page now).
local SEG_H, BAR_H = 26, 12
local SEG_STYLE = { done = { "3E7A3A", 0.18 }, now = { "B8742A", 0.24 }, later = { "ink2", 0.10 } }

local function buildYou(parent, width)
  local c = UI.Card(parent)
  c:SetWidth(width)
  local inner = width - 24
  c.label = UI.Text(c, 11, "accent", "title")
  c.label:SetPoint("TOPLEFT", 12, -10)
  c.state = UI.WrapText(c, 16, "ink", inner, "title")
  c.state:SetPoint("TOPLEFT", 12, -26)
  -- The chapter's steps: reach the floor, the dungeons (or the cap), the next chapter.
  c.segs = {}
  local segW = (inner - 12) / 3
  for i = 1, 3 do
    -- Each step with a thin edge in its state's colour (the visual pass, 28 Oct 2026: flat tints read as unfinished).
    local s = CreateFrame("Frame", nil, c, "BackdropTemplate")
    s:SetSize(segW, SEG_H)
    s:SetBackdrop({ bgFile = ns.WHITE, edgeFile = ns.WHITE, edgeSize = 1 })
    s.text = UI.Text(s, 12, nil, "body", "CENTER")
    s.text:SetPoint("CENTER")
    s.text:SetWidth(segW - 6)
    s.check = UI.Check(s, 12)
    c.segs[i] = s
  end
  -- Your level on a line from the floor to the cap.
  c.lvl = UI.Text(c, 24, "ink", "title", "CENTER")
  c.lvl:SetWidth(44)
  c.lvlKey = UI.Text(c, 11, "ink2", "body", "CENTER")
  c.lvlKey:SetText(L.YOU_KEY)
  -- (UI.Bar with a gold edge and a notch per level; the floor and the cap stand out above and below it.)
  c.bar = UI.Bar(c, BAR_H, true)
  c.bar:SetWidth(inner - 56)
  c.ticks = CreateFrame("Frame", nil, c.bar)
  c.ticks:SetAllPoints()
  c.ticks:SetFrameLevel(c.bar:GetFrameLevel() + 5)
  c.flTick = UI.Solid(c.ticks, "OVERLAY", "ink", 0.85)
  c.flTick:SetSize(2, BAR_H + 6)
  c.capTick = UI.Solid(c.ticks, "OVERLAY", "ink", 0.85)
  c.capTick:SetSize(2, BAR_H + 6)
  c.lo = UI.Text(c, 11, "ink2")
  c.hi = UI.Text(c, 11, "ink2")
  c.say = UI.Text(c, 13, "ink", "title")
  -- Your next steps (the You lines), who is online, Invite to group.
  c.lines = UI.Pool(function()
    local l = CreateFrame("Frame", nil, c)
    l:SetWidth(inner)
    l.icon = UI.Round(l, "ARTWORK", 16)
    l.icon:SetPoint("TOPLEFT", 0, 0)
    l.text = UI.WrapText(l, 13, "ink", inner - 26, "book")
    l.text:SetPoint("TOPLEFT", 24, -1)
    return l
  end)
  c.div = UI.Solid(c, "ARTWORK", "line", 0.6)
  c.div:SetHeight(1)
  c.online = UI.WrapText(c, 12, "ink2", inner)
  c.invite = UI.TextButton(c, L.INVITE_TO_GROUP, function() ns.Together:Invite(c.names or {}) end, "primary", 12)
  -- Play now (M25): the one best thing to do together right now, in a gold-edged box with its button.
  c.play = UI.Card(c, "gold")
  c.play:SetWidth(inner)
  c.play.label = UI.Text(c.play, 11, "accentText", "title")
  c.play.label:SetPoint("TOPLEFT", 10, -12)
  c.play.label:SetText(L.PLAY_NOW:upper())
  c.play.text = UI.WrapText(c.play, 13, "ink", inner - 20, "book")
  c.play.text:SetPoint("TOPLEFT", 10, -24)
  c.play.go = UI.TextButton(c.play, L.INVITE_TO_GROUP, function()
    local f = ns.Fellowship:Current()
    if f then ns.Together:DoPlayNow(f) end
  end, "primary", 12)
  c.play.grouped = UI.Text(c.play, 12, "3E7A3A", "body")
  c.play.grouped:SetText(L.PLAY_GROUPED)
  c.more = UI.TextButton(c, L.MORE_IN_CHAPTER, function() ns.Window:ShowPage("chapter") end, "link", 12)
  -- The counts: below the floor, ready, at the cap, over the cap, away.
  c.counts = {}
  local cw = inner / 5
  for i = 1, 5 do
    local k = CreateFrame("Frame", nil, c)
    k:SetSize(cw, 36)
    k.v = UI.Text(k, 16, nil, "title", "CENTER")
    k.v:SetPoint("TOP", 0, 0)
    k.k = UI.Text(k, 10, "ink2", "body", "CENTER")
    k.k:SetPoint("TOP", k.v, "BOTTOM", 0, -2)
    k.k:SetWidth(cw - 2)
    c.counts[i] = k
  end
  return c
end

-- The three steps of the current chapter: { text, state = "done" | "now" | "later" }.
local function chapterSteps(f, n, count)
  local below = J:Below(f, n)
  local req = J:Required(f, n)
  local open = ns.Milestones:OpenRequired(f, n)
  local goal = J:GoalDone(f, n)
  local out = {}
  out[1] = #below == 0 and { text = L.STRIP_FLOOR, state = "done" } or { text = L.STRIP_FLOOR_N:format(#below), state = "now" }
  local text
  if goal and #open > 0 then text = L.STRIP_MILESTONES:format(#open)
  elseif #req > 0 then
    local done = 0
    for _, x in ipairs(req) do if J:Cleared(f, x.key) then done = done + 1 end end
    text = L.STRIP_DUNGEONS:format(done, #req)
  else
    local counted, there = J:Counted(f), 0
    for _, name in ipairs(counted) do if Hr:Level(f, name) >= f.journey.chapters[n].cap then there = there + 1 end end
    text = L.STRIP_LEVEL:format(there, #counted)
  end
  out[2] = { text = text, state = (goal and #open == 0) and "done" or (#below == 0 and "now" or "later") }
  out[3] = { text = n < count and L.STRIP_NEXT:format(J.Roman(n + 1)) or L.STRIP_END, state = "later" }
  return out
end

local function refreshYou(c, f, watching)
  local width = c:GetWidth()
  local inner = width - 24
  local y = ns.Together:You(f)
  local ch = J:Current(f)
  local cur, count = J:CurrentIndex(f), #f.journey.chapters
  local bn = J:Banner(f, math.min(cur, count + 1))
  c.label:SetText((ch and L.STAND_LABEL:format(J.Roman(ch.n), ch.name) or L.BN_JOURNEY_DONE):upper())
  c.state:SetText(bn.title)
  c.state:SetTextColor(Theme:RGBA(bn.color or "ink"))
  local top = 26 + c.state:GetStringHeight() + 10
  -- Steps, your level and the counts: only while a chapter is going on.
  for _, s in ipairs(c.segs) do s:SetShown(ch ~= nil) end
  for _, w in ipairs({ c.lvl, c.lvlKey, c.bar, c.lo, c.hi, c.say }) do w:SetShown(ch ~= nil) end
  for _, k in ipairs(c.counts) do k:SetShown(ch ~= nil) end
  if ch then
    local segW = (inner - 12) / 3
    for i, st in ipairs(chapterSteps(f, ch.n, count)) do
      local s = c.segs[i]
      local style = SEG_STYLE[st.state]
      local r, g, b = Theme:RGBA(style[1])
      s:SetBackdropColor(r, g, b, style[2])
      s:SetBackdropBorderColor(r, g, b, st.state == "now" and 0.75 or 0.4)
      s.text:SetText(st.text)
      s.text:SetTextColor(r, g, b, 1)
      s.check:SetShown(st.state == "done")
      s.check:ClearAllPoints(); s.check:SetPoint("LEFT", 6, 0)
      s:ClearAllPoints(); s:SetPoint("TOPLEFT", c, "TOPLEFT", 12 + (i - 1) * (segW + 6), -top)
    end
    top = top + SEG_H + 14
    -- Your level: a line from the floor to the cap with your mark and the line filled up to it. Below the floor the
    -- line starts a level under you and the floor gets a tick, so you see how far it is (it sat empty with the mark
    -- at the edge; seen in the tour); over the cap, the same at the other end.
    local me = ns.Me()
    local lvl = Hr:Level(f, me)
    local h = Hr:Get(f, me) or {}
    local frac = (h.xpMax and h.xpMax > 0) and ns.Clamp((h.xp or 0) / h.xpMax, 0, 0.99) or 0
    local fl, cap = J:FloorLevel(f, ch), ch.cap
    local lo, hi = math.min(fl, math.max(1, lvl - 1)), math.max(cap, lvl + 1 > cap and lvl + 1 or cap)
    if hi <= lo then hi = lo + 1 end
    local function at(v) return ns.Clamp((v - lo) / (hi - lo), 0, 1) end
    local p = at(lvl + frac)
    local color = lvl < fl and "B0321E" or (lvl > cap + f.rules.capTol and "C0392B" or (lvl >= cap and "B8742A" or "2E7A3E"))
    c.lvl:SetText(lvl)
    c.lvl:ClearAllPoints(); c.lvl:SetPoint("TOPLEFT", c, "TOPLEFT", 12, -(top - 2))
    c.lvlKey:ClearAllPoints(); c.lvlKey:SetPoint("TOP", c.lvl, "BOTTOM", 0, -1)
    local bw = inner - 56
    c.say:SetText(y.state or "")
    c.say:SetTextColor(Theme:RGBA(color))
    c.say:ClearAllPoints(); c.say:SetPoint("TOPLEFT", c, "TOPLEFT", 68, -top)
    c.bar:ClearAllPoints(); c.bar:SetPoint("TOPLEFT", c, "TOPLEFT", 68, -(top + 20))
    c.bar:SetColor(color)
    c.bar:Set(bw, p)
    local notches = {}
    for v = lo + 1, hi - 1 do notches[#notches + 1] = at(v) end
    c.bar:SetNotches(notches)
    -- Floor and cap: a tick each, the name under it (kept inside the line at its ends). Close together (far over
    -- the cap or under the floor) the floor's name ends at its tick and the cap's starts at its; closer still, one
    -- name for both (they were printed over each other; seen in the check, 29 Oct 2026).
    local xf, xc = bw * at(fl), bw * at(cap)
    c.flTick:ClearAllPoints(); c.flTick:SetPoint("CENTER", c.bar, "LEFT", xf, 0)
    c.capTick:ClearAllPoints(); c.capTick:SetPoint("CENTER", c.bar, "LEFT", xc, 0)
    c.lo:SetText(L.TRACK_FLOOR:format(fl)); c.hi:SetText(L.TRACK_CAP:format(cap))
    local wl, wh = c.lo:GetStringWidth(), c.hi:GetStringWidth()
    local function inside(x, w) return ns.Clamp(x, 0, math.max(0, bw - w)) end
    local ll, hl = inside(xf - wl / 2, wl), inside(xc - wh / 2, wh)
    if ll + wl + 8 > hl then ll, hl = inside(xf - wl, wl), inside(xc, wh) end
    if ll + wl + 8 > hl then
      c.lo:SetText(L.TRACK_BOTH:format(fl, cap)); c.hi:SetText("")
      wl = c.lo:GetStringWidth()
      ll = inside((xf + xc) / 2 - wl / 2, wl)
    end
    c.lo:ClearAllPoints(); c.lo:SetPoint("TOPLEFT", c.bar, "BOTTOMLEFT", ll, -5)
    c.hi:ClearAllPoints(); c.hi:SetPoint("TOPLEFT", c.bar, "BOTTOMLEFT", hl, -5)
    top = top + 48  end
  -- Your next steps (at most three; the rest of what's next is on the Chapter page).
  c.div:ClearAllPoints()
  c.div:SetPoint("TOPLEFT", c, "TOPLEFT", 12, -top); c.div:SetPoint("TOPRIGHT", c, "TOPRIGHT", -12, -top)
  top = top + 4
  -- Play now (below) says what to do with who is online: then the card leaves out the group-up step and the Online
  -- now line, which said the same again (the card grew to 422; seen in the check of 29 Oct 2026).
  -- Watching an alt's fellowship (Fellowship/Watch.lua): its Companions are not in your group to invite.
  local play = not watching and ns.Together:PlayNow(f) or nil
  local n = 0
  for _, line in ipairs(y.lines) do
    if n >= 3 then break end
    if not (play and line.icon == "group") then
      local l = c.lines:Get(n + 1)
      if not l then break end
      n = n + 1
      UI.SetIcon(l.icon, ns.ICONS["bn_" .. line.icon] or ns.ICONS.bn_done)
      l.text:SetText(line.text)
      local h = math.max(18, l.text:GetStringHeight() + 2)
      l:SetHeight(h)
      l:ClearAllPoints(); l:SetPoint("TOPLEFT", c, "TOPLEFT", 12, -(top + 6)); l:Show()
      top = top + 6 + h
    end
  end
  c.lines:HideFrom(n + 1)
  local names = {}
  for i, name in ipairs(y.online) do
    names[i] = L.ONLINE_HERO:format(ns.Short(name), L["ROLE_" .. ((f.members[name].role or "DPS"):upper())] or f.members[name].role or "", Hr:Level(f, name))
  end
  c.names = y.online
  c.online:SetText(#names > 0 and L.ONLINE_NOW:format(table.concat(names, ", ")) or L.ONLINE_NONE)
  c.online:SetShown(not play)
  if not play then
    c.online:ClearAllPoints(); c.online:SetPoint("TOPLEFT", c, "TOPLEFT", 12, -(top + 10))
    top = top + 10 + c.online:GetStringHeight()
  end
  -- Play now: with others online, the best thing to do together, and its button (in place of Invite to group). The
  -- button (or "in your group") sits on the label's row, so the box is no taller than its text (the card was 400
  -- high while catching up; seen in the check of 29 Oct 2026).
  c.play:SetShown(play ~= nil)
  if play then
    c.play.text:SetText(play.text)
    local textTop = play.grouped and 30 or 38
    c.play.text:ClearAllPoints(); c.play.text:SetPoint("TOPLEFT", 10, -textTop)
    local h = textTop + c.play.text:GetStringHeight() + 10
    c.play.go:SetShown(not play.grouped)
    c.play.grouped:SetShown(play.grouped)
    if play.grouped then
      c.play.grouped:ClearAllPoints(); c.play.grouped:SetPoint("TOPRIGHT", -10, -12)
    else
      c.play.go:SetLabel(play.action == "find" and L.PLAY_FIND or L.INVITE_TO_GROUP)
      c.play.go:ClearAllPoints(); c.play.go:SetPoint("TOPRIGHT", -8, -6)
    end
    c.play:SetHeight(h)
    c.play:ClearAllPoints(); c.play:SetPoint("TOPLEFT", c, "TOPLEFT", 12, -(top + 8))
    top = top + 8 + h
  end
  local invite = #names > 0 and not watching and not play
  c.invite:SetShown(invite)
  c.more:SetShown(ch ~= nil)
  -- Without Invite to group, What's next takes a short line, not a button's height (an empty row; seen in the tour).
  if invite then
    c.invite:ClearAllPoints(); c.invite:SetPoint("TOPLEFT", c, "TOPLEFT", 12, -(top + 8))
    c.more:ClearAllPoints(); c.more:SetPoint("TOPRIGHT", c, "TOPRIGHT", -12, -(top + 12))
    top = top + 8 + c.invite:GetHeight()
  elseif ch then
    c.more:ClearAllPoints(); c.more:SetPoint("TOPRIGHT", c, "TOPRIGHT", -12, -(top + 4))
    top = top + 22
  end
  -- The counts.
  if ch then
    top = top + 10
    local cw = inner / 5
    for i, k in ipairs(c.counts) do
      local cnt = J:Counts(f, ch.n)[i]
      k.v:SetText(cnt[2])
      k.v:SetTextColor(Theme:RGBA(cnt[2] > 0 and cnt[3] or "ink2"))
      k.k:SetText(cnt[1])
      k:ClearAllPoints(); k:SetPoint("TOPLEFT", c, "TOPLEFT", 12 + (i - 1) * cw, -top)
    end
    top = top + 36
  end
  c:SetHeight(top + 12)
  return top + 12
end
-- Getting started (leader of a new fellowship): steps with a check mark when done, and Hide.
local function buildStart(parent, width)
  local c = UI.Card(parent)
  c:SetWidth(width)
  c.label = UI.Text(c, 11, "accent", "title")
  c.label:SetPoint("TOPLEFT", 12, -10)
  c.label:SetText(L.START_LABEL:upper())
  c.hide = UI.TextButton(c, L.START_HIDE, function() ns.Together:HideStarted() end, "link", 12)
  c.hide:SetPoint("TOPRIGHT", -8, -6)
  c.lines = {}
  for i = 1, 4 do
    local l = CreateFrame("Frame", nil, c)
    l:SetSize(width - 24, 18)
    l.check = UI.Check(l, 14)
    l.check:SetPoint("TOPLEFT", 0, 1)
    l.dot = UI.Solid(l, "ARTWORK", "ink2", 1)
    l.dot:SetSize(5, 5); l.dot:SetPoint("TOPLEFT", 5, -6)
    -- Wraps instead of cutting a long step short (seen in the UI tour).
    l.text = UI.WrapText(l, 13, "ink", width - 46, "book")
    l.text:SetPoint("TOPLEFT", 20, 0)
    c.lines[i] = l
  end
  return c
end

-- Places the steps under each other; returns the card's height.
local function refreshStart(c, steps, label)
  c.label:SetText((label or L.START_LABEL):upper())
  local y = 28
  for i, l in ipairs(c.lines) do
    local st = steps[i]
    l:SetShown(st ~= nil)
    if st then
    l.check:SetShown(st.done); l.dot:SetShown(not st.done)
    l.text:SetText(st.text)
    l.text:SetTextColor(Theme:RGBA(st.done and "ink2" or "ink"))
    local h = math.max(18, l.text:GetStringHeight() + 2)
    l:SetHeight(h)
    l:ClearAllPoints(); l:SetPoint("TOPLEFT", c, "TOPLEFT", 12, -y)
    y = y + h + 4
    end
  end
  c:SetHeight(y + 8)
  return y + 8
end

-- Gatherings: one line about the next one; a click opens the Gatherings page (UI/Pages/Gatherings.lua). The whole
-- list here crowded the Overview (in-game run, 27 Oct 2026).
local function buildGatherings(parent, width)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(width, 30)
  b.icon = UI.Round(b, "ARTWORK", 22)
  b.icon:SetPoint("TOPLEFT", 0, -2)
  UI.SetIcon(b.icon, ns.ICONS.gatherings)
  -- A link like "All 14 chapters ›" (the accent colour was too pale on parchment).
  b.more = UI.TextButton(b, L.G_OPEN, function() ns.Window:ShowPage("gatherings") end, "link", 13)
  b.more:SetPoint("TOPRIGHT", 0, -2)
  b.text = UI.WrapText(b, 13, "ink", width - 30 - 90, "book")
  b.text:SetPoint("TOPLEFT", 30, -5)
  local hl = b:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints(); hl:SetColorTexture(1, 0.9, 0.6, 0.1)
  b:SetScript("OnClick", function() ns.Window:ShowPage("gatherings") end)
  return b
end

local function refreshGatherings(b, f, stack)
  local G = ns.Gatherings
  local list = G:Upcoming(f)
  local g = list[1]
  if g then
    b.text:SetText(L.G_NEXT:format(G.When(g.at), G.What(g), G.Counts(g).yes)
      .. (#list > 1 and L.G_NEXT_MORE:format(#list - 1) or ""))
  else
    b.text:SetText(L.G_NEXT_NONE)
  end
  local h = math.max(30, b.text:GetStringHeight() + 10)
  b:SetHeight(h)
  stack:Place(b, h, 6)
end

local function build(pf)
  local W = ns.Window
  local width = W.PAGE_W - 8

  -- Left: the You card, contents and chronicle.
  pf.lscroll = UI.Scroll(pf.left)
  pf.lscroll:SetAllPoints()
  local Lc = pf.lscroll.child
  pf.you = buildYou(Lc, width)
  pf.start = buildStart(Lc, width)
  pf.gather = buildGatherings(Lc, width)
  pf.contents = UI.Text(Lc, 12, "ink2")
  pf.contents:SetText(L.CONTENTS)
  pf.tocDone = UI.TextButton(Lc, "", function() pf.allCh = true; W:Refresh() end, "link", 13)
  pf.tocAll = UI.TextButton(Lc, "", function() pf.allCh = not pf.allCh; W:Refresh() end, "link", 13)
  pf.toc = UI.Pool(function()
    local b = CreateFrame("Button", nil, Lc)
    b:SetSize(width, 24)
    b.bg = b:CreateTexture(nil, "BACKGROUND")
    b.bg:SetAllPoints()
    b.bg:SetColorTexture(0.72, 0.53, 0.18, 0.2)
    b.num = UI.Text(b, 13, nil, "title")
    b.num:SetPoint("LEFT", 6, 0)
    b.num:SetWidth(34)
    b.name = UI.Text(b, 14, nil, "title")
    b.name:SetPoint("LEFT", 42, 0)
    b.name:SetWidth(width - 140)
    b.mark = UI.Mark(b, 14)
    b.mark:SetPoint("RIGHT", -4, 0)
    b.range = UI.Text(b, 12, "ink2", "body", "RIGHT")
    b.range:SetPoint("RIGHT", b.mark, "LEFT", -6, 0)
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints(); hl:SetColorTexture(1, 0.9, 0.6, 0.12)
    b:SetScript("OnClick", function() pf.sel = b.n; W:Refresh() end)
    return b
  end)
  pf.feedDiv = UI.Divider(Lc)
  pf.feedHead = UI.Text(Lc, 17, "ink", "title")
  pf.feedHead:SetText(L.CHRONICLE)
  pf.feed = {}
  for i = 1, 6 do
    local e = CreateFrame("Frame", nil, Lc)
    e:SetSize(width, 30)
    e.text = UI.WrapText(e, 13, "ink", width, "book")
    e.text:SetPoint("TOPLEFT")
    e.when = UI.Text(e, 11, "ink2")
    e.line = UI.Solid(e, "ARTWORK", "line", 0.6)
    e.line:SetHeight(1); e.line:SetPoint("BOTTOMLEFT"); e.line:SetPoint("BOTTOMRIGHT")
    pf.feed[i] = e
  end

  -- Right: the chosen chapter.
  pf.rscroll = UI.Scroll(pf.right)
  pf.rscroll:SetAllPoints()
  local R = pf.rscroll.child
  local band = CreateFrame("Frame", nil, R)
  band:SetSize(width, 112)
  pf.band = band
  band.art = band:CreateTexture(nil, "BACKGROUND")
  band.art:SetAllPoints()
  band.w = width
  local fade = band:CreateTexture(nil, "BORDER")
  fade:SetAllPoints()
  UI.SetGradient(fade, "VERTICAL", { 0.055, 0.03, 0.01, 0.88 }, { 0.055, 0.03, 0.01, 0.05 })
  band.num = UI.Text(band, 11, "E8C878")
  band.num:SetPoint("BOTTOMLEFT", 14, 50)
  band.title = UI.Text(band, 20, "goldText", "title")
  band.title:SetPoint("BOTTOMLEFT", 14, 28)
  band.title:SetShadowOffset(0, -1); band.title:SetShadowColor(0, 0, 0, 1)
  band.line = UI.Text(band, 12, "chipText")
  band.line:SetPoint("BOTTOMLEFT", 14, 10)
  -- Another chapter chosen in the contents: its status. The current one: where the Companions stand (the grouped
  -- list of the Chapter page; it was a level track with dots).
  pf.banner = UI.StatusBanner(R, width)
  pf.standHead = UI.Text(R, 17, "ink", "title")
  pf.standHead:SetText(L.WHERE_STAND)
  pf.stand = UI.Standings(R, width)
  pf.dungHead = UI.Text(R, 17, "ink", "title")
  pf.dungHead:SetText(L.OV_DUNGEONS)
  pf.dungeons = UI.Pool(function()
    local d = CreateFrame("Frame", nil, R)
    d:SetSize(width, 22)
    d.mark = UI.Mark(d, 14)
    d.mark:SetPoint("LEFT")
    d.name = UI.Text(d, 13, "ink")
    d.name:SetPoint("LEFT", 20, 0)
    d.note = UI.Text(d, 12, "ink2", "body", "RIGHT")
    d.note:SetPoint("RIGHT")
    return d
  end)
  pf.noDungeons = UI.WrapText(R, 13, "ink2", width, "book")
  pf.noDungeons:SetText(L.OV_NO_DUNGEONS)
  pf.back = UI.TextButton(R, L.BACK_TO_CURRENT, function() pf.sel = nil; W:Refresh() end, "plain")
  pf.open = UI.TextButton(R, L.OPEN_CHAPTER, function()
    local chapter = W.pageFrames.chapter
    if chapter then chapter.sel = pf.shown end
    W.page = "chapter"
    W:Refresh()
  end, "primary")
end

local function refresh(pf, ctx)
  local f = ctx.f
  if not f then return end
  local cur = J:CurrentIndex(f)
  local maxView = J:MaxView(f, ctx.me)
  local count = #f.journey.chapters
  local sel = ns.Clamp(pf.sel or math.min(cur, count), 1, math.max(1, maxView))
  pf.shown = sel

  -- The You card, then the contents.
  local s = UI.Stack(pf.lscroll.child)
  s:Place(pf.you, refreshYou(pf.you, f, ctx.watching), 10)
  local steps, label
  if not ctx.watching then steps, label = ns.Together:Started(f) end
  pf.start:SetShown(steps ~= nil)
  if steps then
    s:Place(pf.start, refreshStart(pf.start, steps, label), 10)
  end
  pf.gather:SetShown(not ctx.watching)
  if not ctx.watching then refreshGatherings(pf.gather, f, s) end
  s:Skip(10)
  s:Place(pf.contents, 16, 4)
  -- Done chapters fold into one line and only the next few show, unless the player opens them all (fourteen rows
  -- pushed everything below the fold; seen in the UI tour). A chapter chosen to read always shows.
  local function visible(n) return pf.allCh or (n >= cur and n <= cur + 3) or n == sel end
  local folded = 0
  for n = 1, count do if not visible(n) then folded = folded + 1 end end
  pf.tocDone:SetShown(not pf.allCh and cur > 1 and cur <= count + 1)
  if pf.tocDone:IsShown() then
    local last = math.min(cur - 1, count)
    pf.tocDone:SetLabel(last == 1 and L.TOC_DONE_1 or L.TOC_DONE_N:format(J.Roman(1), J.Roman(last)))
    s:Place(pf.tocDone, 22, 2, 4)
  end
  for n, ch in ipairs(f.journey.chapters) do
    local b = pf.toc:Get(n)
    if not b then break end
    if not visible(n) then b:Hide() else
    local hidden, done, now = n > maxView, n < cur, n == cur
    b.n = n
    b.num:SetText(J.Roman(n))
    b.name:SetText(hidden and L.HIDDEN_CHAPTER or ch.name)
    b.range:SetText(hidden and "" or (ch.floor .. "–" .. ch.cap))
    b.mark:SetMark(done and "done" or (now and "current" or (hidden and "locked" or nil)))
    local color = done and "3E7A3A" or (now and "B8742A" or "ink2") -- (pale "accent" was hard to read)
    b.num:SetTextColor(Theme:RGBA(color)); b.name:SetTextColor(Theme:RGBA(color))
    b.bg:SetShown(n == sel)
    b:SetEnabled(not hidden)
    s:Place(b, 24, 0)
    end
  end
  pf.toc:HideFrom(count + 1)
  pf.tocAll:SetShown(folded > 0 or pf.allCh)
  if pf.tocAll:IsShown() then
    pf.tocAll:SetLabel(pf.allCh and L.TOC_FEWER or L.TOC_ALL:format(count))
    s:Place(pf.tocAll, 22, 2, 4)
  end
  s:Skip(8)
  pf.feedDiv:ClearAllPoints()
  pf.feedDiv:SetPoint("TOPLEFT", pf.lscroll.child, "TOPLEFT", 0, -s.y); pf.feedDiv:SetPoint("TOPRIGHT", pf.lscroll.child, "TOPRIGHT", 0, -s.y)
  s:Skip(20)
  s:Place(pf.feedHead, 22, 6)
  local chron = ns.Fellowship:ChronicleView(f, #pf.feed)
  for i, e in ipairs(pf.feed) do
    local entry = chron[i]
    e:SetShown(entry ~= nil)
    if entry then
      e.text:SetText(entry.text)
      e.when:ClearAllPoints(); e.when:SetPoint("TOPLEFT", e.text, "BOTTOMLEFT", 0, -2)
      e.when:SetText(ns.TimeAgo(entry.time))
      local h = e.text:GetStringHeight() + 20
      e:SetHeight(h)
      s:Place(e, h, 4)
    end
  end
  pf.lscroll:SetContentHeight(s.y + 8)

  -- The chosen chapter.
  local ch = f.journey.chapters[sel]
  local r = UI.Stack(pf.rscroll.child)
  ns.Pages:SetChapterArt(pf.band.art, ns.Pages:ArtOf(f, sel), pf.band.w, 112, 0.55)
  pf.band.num:SetText(L.CHAPTER_ROMAN:format(J.Roman(sel)):upper())
  pf.band.title:SetText(ch and ch.name or L.BN_JOURNEY_DONE)
  pf.band.line:SetText(ch and J:LevelsLine(f, ch) or "")
  r:Place(pf.band, 112, 10)
  local isCurrent = sel == math.min(cur, count) and cur <= count
  pf.banner:SetShown(not isCurrent)
  pf.standHead:SetShown(isCurrent and ch ~= nil)
  if isCurrent and ch then
    r:Place(pf.standHead, 22, 6)
    pf.stand:Set(f, sel, r)
  else
    pf.stand:Hide()
    r:Place(pf.banner, pf.banner:Set(J:Banner(f, sel)), 10)
  end
  pf.dungHead:SetShown(ch ~= nil)
  if ch then r:Place(pf.dungHead, 22, 6) end
  local list = ch and J:ChapterList(f, sel) or {}
  local shown = 0
  for i, x in ipairs(list) do
    local d = pf.dungeons:Get(i)
    if not d then break end
    shown = i
    local state = J:DungeonState(f, sel, x)
    d.mark:SetMark(state)
    d.name:SetText(x.d[2])
    -- Open in a dark amber ("accent" is pale gold, and the lighter amber B8742A was still hard to read on parchment;
    -- seen in the tour and the check of 29 Oct 2026).
    d.name:SetTextColor(Theme:RGBA(state == "cleared" and "3E7A3A" or (state == "open" and "8C5A14" or "ink2")))
    -- The role in its colour (Rules/Journey.lua, ROLE_COLOR), and the next chapter's bridges with their chapter.
    local role = x.early and L.NOTE_BRIDGE_EARLY:format(J.Roman(x.early))
      or (x.role == "b" and L.NOTE_BRIDGE or (x.role == "o" and L.NOTE_OPTIONAL or L.NOTE_MANDATORY))
    d.note:SetText(role .. L.NOTE_LEVELS:format(x.d[3], x.d[4]))
    d.note:SetTextColor(Theme:RGBA((J.ROLE_COLOR[x.role] or J.ROLE_COLOR.m)[1]))
    r:Place(d, 22, 2)
  end
  pf.dungeons:HideFrom(shown + 1)
  pf.noDungeons:SetShown(ch ~= nil and #list == 0)
  if ch and #list == 0 then r:Place(pf.noDungeons, pf.noDungeons:GetStringHeight(), 4) end
  r:Skip(10)
  pf.back:SetShown(sel ~= math.min(cur, count))
  local by = r.y
  pf.open:SetShown(ch ~= nil)
  pf.open:ClearAllPoints(); pf.open:SetPoint("TOPRIGHT", pf.rscroll.child, "TOPRIGHT", 0, -by)
  pf.back:ClearAllPoints(); pf.back:SetPoint("TOPLEFT", pf.rscroll.child, "TOPLEFT", 0, -by)
  r:Skip(40)
  pf.rscroll:SetContentHeight(r.y + 8)
end

ns.Pages:Register({ id = "overview", label = ns.L.NAV_OVERVIEW, build = build, refresh = refresh,
  title = function() return L.TITLE_OVERVIEW, L.SUB_OVERVIEW end })
