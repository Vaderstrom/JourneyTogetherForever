-- Chronicle (SPEC §4.7; the History page until 29 Oct 2026), the journey's story. Two tabs, each a page of its own: this
-- one and Moments (UI/Pages/Moments.lua, parent = "chronicle"). Left: filter (All, Runs, Sessions, Leader changes, Over
-- the cap) and the entries, each with an icon, text, when, and a status chip. Right: how clears are counted, totals.
local _, ns = ...
local L = ns.L
local UI, Theme = ns.UI, ns.Theme
local Cl = ns.Clears

local FILTERS = { { L.HIST_ALL, "all" }, { L.HIST_RUNS, "run" }, { L.HIST_SESSIONS, "session" },
  { L.HIST_FIRSTS, "first" }, { L.HIST_LEADER, "leader" }, { L.HIST_CAP, "cap" } }

-- The entries of a filter: the fellowship's history, and your own sessions (M25) under Sessions and in All.
local function entries(f, filter)
  if filter == "session" then return ns.Session:Entries(f) end
  if filter == "first" then return ns.Firsts:Entries(f) end
  local list = Cl:Entries(f, filter)
  if filter ~= "all" then return list end
  -- Entries of the same second keep their order (newest first): chapters unlocked together came out sorted by their
  -- text, IV, IX, V ... (seen in the check of 29 Oct 2026).
  local all, at = {}, {}
  for _, e in ipairs(list) do all[#all + 1] = e; at[e] = #all end
  for _, e in ipairs(ns.Session:Entries(f)) do all[#all + 1] = e; at[e] = #all end
  for _, e in ipairs(ns.Firsts:Entries(f)) do all[#all + 1] = e; at[e] = #all end
  -- Challenges (SPEC §9): the falls they counted (a memorial for the Fallen) and any turned off.
  for _, e in ipairs(ns.Challenges:Entries(f)) do all[#all + 1] = e; at[e] = #all end
  table.sort(all, function(a, b)
    if a.time ~= b.time then return a.time > b.time end
    return at[a] < at[b]
  end)
  return all
end

-- Chapters unlocked in a row (three or more, U15, 31 Oct 2026: nine such lines filled the page) become one line,
-- "Chapters VII to XV unlocked", that opens to show them. open[key] keeps a group open; key is its newest chapter.
-- Returns the list with { group = true, items, key, lo, hi, time } in place of each run.
function ns.ChronicleGroups(list, open)
  local out, i = {}, 1
  while i <= #list do
    local e = list[i]
    local j = i
    if e.type == "chapter" and tonumber(e.ch) then
      while list[j + 1] and list[j + 1].type == "chapter" and tonumber(list[j + 1].ch) do j = j + 1 end
    end
    if j - i + 1 >= 3 then
      local items = {}
      for k = i, j do items[#items + 1] = list[k] end
      local lo, hi = items[1].ch, items[1].ch
      for _, x in ipairs(items) do lo, hi = math.min(lo, x.ch), math.max(hi, x.ch) end
      local g = { group = true, items = items, key = "ch" .. hi .. ":" .. (items[1].time or 0), lo = lo, hi = hi,
        time = items[1].time, type = "chapter", icon = "chapter" }
      out[#out + 1] = g
      if open and open[g.key] then for _, x in ipairs(items) do out[#out + 1] = x end end
      i = j + 1
    else
      out[#out + 1] = e
      i = i + 1
    end
  end
  return out
end

-- The tab strip at the top of each tab's left page (as Manage's, UI/Pages/Manage.lua). Returns the height it takes.
-- The journey · Moments · The fellowship (U142: History is the third tab since 9 Nov 2026).
local TABS = { { "CH_TAB_LOG", "chronicle", "chronicle" }, { "CH_TAB_MOMENTS", "moments", "history" },
  { "CH_TAB_FELLOWSHIP", "history", "heroes" } }
function ns.ChronicleTabs(pf)
  local W = ns.Window
  local opts = {}
  for i, t in ipairs(TABS) do opts[i] = { L[t[1]], t[2], t[3] } end
  pf.tabs = UI.Tabs(pf.left, opts, function() return W.current end, function(id) W:ShowPage(id) end, W.PAGE_W - 8)
  pf.tabs:SetPoint("TOPLEFT", 0, 0)
  return 40
end

-- The Firsts filter as medals (SPEC §8, from the check of 1 Nov 2026): a cabinet in the order of the firsts, the
-- earned ones with who and when, then the ones nobody has yet, greyed ("Still open": something to race for).
local MEDAL_COLS, MEDAL_H, MEDAL_GAP, MEDAL_RING = 4, 100, 8, 46
-- U42: the progress ring round the next open level, as dots (lit from the top, clockwise).
local DOTS, DOT = 24, 4

local function medalIcon(tex, key)
  if not UI.SetIcon(tex, ns.ICONS["first_" .. key]) then UI.SetIcon(tex, ns.ICONS.hist_first) end
end

-- The medal's ring: gold, grey while open; silver in a violet edge for the first to fall under a survival challenge
-- (SPEC §9: honoured, not cheered).
local SILVER = "C9CBD6"
local function paintRing(m)
  m.ring:SetColorTexture(Theme:RGBA(m.open and "line" or (m.solemn and SILVER or "gold"), m.open and 0.6 or 0.95))
  m.edge:SetShown(m.solemn == true)
end

local function buildMedal(parent, w)
  local m = CreateFrame("Frame", nil, parent)
  m:SetSize(w, MEDAL_H)
  m.edge = UI.Round(m, "ARTWORK", MEDAL_RING + 6, -1)
  Theme:Fill(m.edge, ns.Hero.FALLEN, 1)
  m.ring = UI.Round(m, "ARTWORK", MEDAL_RING)
  m.ring:SetPoint("TOP", 0, -2)
  m.edge:SetPoint("CENTER", m.ring)
  Theme:Register(function() paintRing(m) end)
  m.icon = UI.Round(m, "OVERLAY", MEDAL_RING - 6)
  m.icon:SetPoint("CENTER", m.ring)
  m.dotRing = UI.DotRing(m, MEDAL_RING + 10 + DOT, DOTS, DOT)
  m.dotRing:SetPoint("CENTER", m.ring)
  m.dots = m.dotRing.dots
  for _, d in ipairs(m.dots) do d:Hide() end
  -- The newest earned medal glints once when the cabinet opens (U42): the game's cooldown star turning over its ring.
  m.star = m:CreateTexture(nil, "OVERLAY", nil, 2)
  m.star:SetSize(MEDAL_RING + 40, MEDAL_RING + 40); m.star:SetPoint("CENTER", m.ring)
  m.hasStar = m.star:SetTexture(UI.GLOW_PROBE.star) ~= false
  m.star:SetBlendMode("ADD"); m.star:SetVertexColor(1, 0.85, 0.45); m.star:SetAlpha(0)
  local ag = m.star:CreateAnimationGroup()
  local a1 = ag:CreateAnimation("Alpha"); a1:SetFromAlpha(0); a1:SetToAlpha(1); a1:SetDuration(0.25); a1:SetOrder(1)
  local turn = ag:CreateAnimation("Rotation"); turn:SetDegrees(-90); turn:SetDuration(0.9); turn:SetOrder(1)
  local a2 = ag:CreateAnimation("Alpha"); a2:SetFromAlpha(1); a2:SetToAlpha(0); a2:SetDuration(0.65); a2:SetStartDelay(0.25); a2:SetOrder(1)
  ag:SetScript("OnFinished", function() m.star:SetAlpha(0) end)
  m.glint = ag
  m.title = UI.Text(m, 12, "ink", "title", "CENTER")
  m.title:SetPoint("TOP", m.ring, "BOTTOM", 0, -5); m.title:SetWidth(w)
  m.who = UI.Text(m, 12, "ink", "body", "CENTER")
  m.who:SetPoint("TOP", m.title, "BOTTOM", 0, -2); m.who:SetWidth(w)
  m.when = UI.Text(m, 12, "ink2", "body", "CENTER")
  m.when:SetPoint("TOP", m.who, "BOTTOM", 0, -1); m.when:SetWidth(w)
  m:EnableMouse(true)
  m:SetScript("OnEnter", function()
    GameTooltip:SetOwner(m, "ANCHOR_TOP")
    GameTooltip:SetText(m.tip[1], 1, 1, 1, 1, true)
    for i = 2, #m.tip do GameTooltip:AddLine(m.tip[i], 0.85, 0.8, 0.7, true) end
    GameTooltip:Show()
  end)
  m:SetScript("OnLeave", function() GameTooltip:Hide() end)
  return m
end

-- Earned (x: { key, name, time }) or still open (x: nil). The next open level first (near: true; the lowest someone
-- is still below) names who is closest, in their class colour, faded ("Brannic / is closest (22)"), instead of "Nobody yet"; only that one (the
-- check of 1 Nov 2026, 14:32: the same name under all four open levels).
local function whoColor(fs, f, name, alpha)
  local mem = f.members[name]
  local hex = ns.ClassHex(mem and mem.class, Theme:Current().light)
  if hex then
    local r, g, b = ns.Hex(hex)
    fs:SetTextColor(r, g, b, alpha)
  else fs:SetTextColor(Theme:RGBA("ink", alpha)) end
end

-- near: { who, level } of the closest to this open level (only the next one gets it), or nil.
local function fillMedal(m, f, key, x, near)
  m.key, m.open = key, x == nil
  m.solemn = x ~= nil and key == "fall" and ns.Challenges:Ever(f) or nil
  medalIcon(m.icon, key)
  m.icon:SetDesaturated(m.open); m.icon:SetAlpha(m.open and 0.45 or 1)
  paintRing(m)
  m.title:SetText(L["FIRSTN_" .. key:upper()] or key)
  m.title:SetTextColor(Theme:RGBA(m.open and "ink2" or "ink"))
  m.closest = nil
  for _, d in ipairs(m.dots) do d:Hide() end
  if x then
    m.who:SetText(ns.Short(x.name))
    whoColor(m.who, f, x.name, 1)
    m.when:SetText(ns.TimeAgo(x.time))
    m.tip = { ns.Firsts.Text(x), ns.TimeAgo(x.time) }
    return
  end
  m.tip = { L["FIRSTN_" .. key:upper()] or key, L.FIRST_OPEN_TIP }
  local who, lvl
  if near then who, lvl = near[1], near[2] end
  if who then
    m.closest = who
    m.who:SetText(ns.Short(who))
    whoColor(m.who, f, who, 0.8)
    -- U42: "20 of 30" and the ring of dots, lit as far as their level goes towards it.
    local target = tonumber(key:match("^lvl(%d+)$")) or lvl
    m.when:SetText(L.FIRST_PROGRESS:format(lvl, target))
    m.tip[3] = L.FIRST_CLOSEST_TIP:format(ns.Short(who), lvl)
    m.dotRing:Set(lvl / target, "gold")
  else
    m.who:SetText(L.FIRST_NOBODY)
    m.who:SetTextColor(Theme:RGBA("ink2"))
    m.when:SetText("")
  end
end

-- Places the cabinet under the filter: Earned, then Still open. Returns how many medals it shows.
local function placeMedals(pf, f, s)
  local FS, n = ns.Firsts, 0
  local byKey = {}
  for _, x in ipairs(FS:List(f)) do byKey[x.key] = x end
  local earned = {}
  for _, key in ipairs(FS.KEYS) do if byKey[key] then earned[#earned + 1] = key end end
  local open = FS:Open(f)
  -- (The next open level: the lowest someone counted is still below; one everyone passed before joining is not.)
  local nextLevel, near
  for _, key in ipairs(open) do
    if key:match("^lvl") then
      local who, lvl = FS:Closest(f, key)
      if who then nextLevel, near = key, { who, lvl }; break end
    end
  end
  local function grid(keys)
    local y0 = s.y
    for i, key in ipairs(keys) do
      local m = pf.medals:Get(n + 1)
      if not m then return end
      n = n + 1
      fillMedal(m, f, key, byKey[key], key == nextLevel and near or nil)
      m:ClearAllPoints()
      m:SetPoint("TOPLEFT", pf.lscroll.child, "TOPLEFT", ((i - 1) % MEDAL_COLS) * (pf.medalW + MEDAL_GAP),
        -(y0 + math.floor((i - 1) / MEDAL_COLS) * (MEDAL_H + MEDAL_GAP)))
      m:Show()
    end
    s:Skip(math.ceil(#keys / MEDAL_COLS) * (MEDAL_H + MEDAL_GAP))
  end
  pf.earnedHead:SetShown(#earned > 0)
  if #earned > 0 then s:Place(pf.earnedHead, 29, 8); grid(earned) end
  -- U42: the newest earned medal glints once each time the cabinet opens (pf.glinted goes with the page or the
  -- filter); Reduce effects keeps it still.
  local newest
  for i, key in ipairs(earned) do
    local m = pf.medals.items[i]
    if m and (not newest or byKey[key].time > byKey[newest.key].time) then newest = m end
  end
  if newest and not pf.glinted then
    pf.glinted = newest.key
    if newest.hasStar and not ns.Settings:Get("reduce") then newest.glint:Stop(); newest.glint:Play() end
  end
  pf.openHead:SetShown(#open > 0)
  if #open > 0 then s:Skip(6); s:Place(pf.openHead, 29, 8); grid(open) end
  return n
end

-- The tallies' podium: the top three of each in gold, silver and bronze; everyone in the tooltip.
local PODIUM = { "E2B23C", "A8A8B4", "B87333" }

local function build(pf)
  local W = ns.Window
  local width = W.PAGE_W - 8
  pf.filter = "all"
  pf.open = {}

  local top = ns.ChronicleTabs(pf)
  pf.lscroll = UI.Scroll(pf.left)
  pf.lscroll:SetPoint("TOPLEFT", 0, -top); pf.lscroll:SetPoint("BOTTOMRIGHT")
  local Lc = pf.lscroll.child
  pf.days = UI.DayHeads(Lc, width)
  pf.choice = UI.Tabs(Lc, FILTERS, function() return pf.filter end, function(v) pf.filter = v; W:Refresh() end, width,
    function(v) local f = ns.Fellowship:Current(); return f and v ~= "all" and #entries(f, v) or nil end, 12)
  pf.rows = UI.Pool(function()
    local e = CreateFrame("Frame", nil, Lc)
    e:SetWidth(width)
    e.icon = e:CreateTexture(nil, "ARTWORK")
    e.icon:SetSize(18, 18); e.icon:SetPoint("TOPLEFT", 2, -1)
    e.text = UI.WrapText(e, 13, "ink", width - 32, "book")
    e.text:SetPoint("TOPLEFT", 30, 0)
    e.when = UI.Text(e, 11, "ink2")
    e.chip = UI.Box(e, 1, "card", 1, "line", 0)
    e.chip:SetHeight(16)
    e.chip.text = UI.Text(e.chip, 10, "white", "body", "CENTER")
    e.chip.text:SetPoint("CENTER")
    e.chip:SetPoint("LEFT", e.when, "RIGHT", 8, 0)
    -- A group's line opens and folds on a click.
    e:SetScript("OnMouseUp", function(self)
      if not self.groupKey then return end
      pf.open[self.groupKey] = not pf.open[self.groupKey] or nil
      W:Refresh()
    end)
    e.line = UI.Solid(e, "ARTWORK", "line", 0.6)
    e.line:SetHeight(1); e.line:SetPoint("BOTTOMLEFT"); e.line:SetPoint("BOTTOMRIGHT")
    return e
  end)
  pf.empty = UI.EmptyState(Lc, width)
  pf.medalW = math.floor((width - (MEDAL_COLS - 1) * MEDAL_GAP) / MEDAL_COLS)
  pf.earnedHead = UI.SectionHeader(Lc, width)
  pf.earnedHead:SetText(L.FIRSTS_EARNED)
  pf.openHead = UI.SectionHeader(Lc, width)
  pf.openHead:SetText(L.FIRSTS_OPEN)
  pf.medals = UI.Pool(function() return buildMedal(Lc, pf.medalW) end)
  -- (Hidden with the page: the newest medal glints again when it opens.)
  local watch = CreateFrame("Frame", nil, Lc)
  watch:SetScript("OnHide", function() pf.glinted = nil end)

  pf.rscroll = UI.Scroll(pf.right)
  pf.rscroll:SetAllPoints()
  local R = pf.rscroll.child
  -- The right page is the tallies (SPEC §8): who has fallen most, run most dungeons, turned in most quests. How clears
  -- are counted, and that the Leader's changes to them are written here, are behind the "?" by its title (U203, the
  -- owner, 14 Nov 2026: two headings and a line between them).
  pf.head = UI.Heading(R, width, L.HIST_TALLIES, nil, 20)
  pf.head:SetHelp("") -- the "?" made now, not during combat
  -- (No number tiles since U198, the owner, 14 Nov 2026: each count is on its filter on the left, "Runs 1", and each
  -- run says whether it counted. The journey's dungeons so far left this page on 10 Nov 2026, U170: who cleared what
  -- is on the Chapter page and the Dungeons page.)
  pf.none = UI.WrapText(R, 12, "ink2", width, "book")
  pf.none:SetText(L.HIST_TALLIES_NONE)
  pf.tRows = UI.Pool(function()
    local d = CreateFrame("Frame", nil, R)
    d:SetSize(width, 42)
    d.what = UI.Text(d, 13, "ink")
    d.what:SetPoint("TOPLEFT", 4, -2)
    -- The podium: three places side by side under the label.
    d.places = {}
    local pw = math.floor((width - 4) / 3)
    for k = 1, 3 do
      local pl = CreateFrame("Frame", nil, d)
      pl:SetSize(pw, 20)
      pl:SetPoint("TOPLEFT", 4 + (k - 1) * pw, -20)
      pl.rank = UI.Round(pl, "ARTWORK", 16)
      pl.rank:SetPoint("LEFT")
      pl.rank:SetColorTexture(ns.Hex(PODIUM[k]))
      pl.n = UI.Text(pl, 10, "000000", "title", "CENTER")
      pl.n:SetPoint("CENTER", pl.rank)
      pl.n:SetText(k)
      pl.name = UI.Text(pl, 13, "ink", "title")
      pl.name:SetPoint("LEFT", pl.rank, "RIGHT", 5, 0)
      pl.name:SetWidth(pw - 24)
      d.places[k] = pl
    end
    d:EnableMouse(true)
    d:SetScript("OnEnter", function()
      if not d.all then return end
      GameTooltip:SetOwner(d, "ANCHOR_LEFT")
      GameTooltip:SetText(d.what:GetText(), 1, 1, 1)
      for i, x in ipairs(d.all) do GameTooltip:AddLine(L.TALLY_RANK:format(i, ns.Short(x.name), x.n), 0.85, 0.8, 0.7) end
      GameTooltip:Show()
    end)
    d:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return d
  end)
end

local function refresh(pf, ctx)
  local f = ctx.f
  if not f then return end

  pf.tabs:Refresh()
  -- Opened at a filter (the session recap's toast: "chronicle#session").
  if ns.Window.tab then pf.filter = ns.Window.tab; ns.Window.tab = nil end
  local s = UI.Stack(pf.lscroll.child)
  pf.choice:Refresh()
  s:Place(pf.choice, pf.choice:GetHeight(), 10)
  local gallery = pf.filter == "first"
  local list = gallery and {} or ns.ChronicleGroups(entries(f, pf.filter), pf.open)
  local shown = 0
  pf.days:Start()
  for i, entry in ipairs(list) do
    local e = pf.rows:Get(i)
    if not e then break end
    shown = i
    pf.days:Place(s, entry.time)
    UI.SetIcon(e.icon, ns.ICONS[Cl.ICON[entry.icon] or "hist_run"])
    e.groupKey = entry.group and entry.key or nil
    e:EnableMouse(entry.group == true)
    if entry.group then
      local J = ns.Journey
      e.text:SetText(L.HIST_CH_GROUP:format(J.Roman(entry.lo), J.Roman(entry.hi), #entry.items)
        .. "  " .. (pf.open[entry.key] and L.HIST_CH_FOLD or L.HIST_CH_OPEN))
    else
      e.text:SetText(Cl:Text(entry))
    end
    e.when:ClearAllPoints(); e.when:SetPoint("TOPLEFT", e.text, "BOTTOMLEFT", 0, -4)
    e.when:SetText(ns.TimeAgo(entry.time))
    local status, color = Cl:Status(entry)
    e.chip:SetShown(status ~= nil)
    if status then
      e.chip.text:SetText(status)
      e.chip:SetWidth(e.chip.text:GetStringWidth() + 14)
      e.chip:SetBackdropColor(Theme:RGBA(color))
    end
    local h = e.text:GetStringHeight() + 30
    e:SetHeight(h)
    s:Place(e, h, 4)
  end
  pf.rows:HideFrom(shown + 1)
  pf.days:Done()
  local medals = 0
  pf.earnedHead:SetShown(false); pf.openHead:SetShown(false)
  if gallery then medals = placeMedals(pf, f, s) else pf.glinted = nil end
  pf.medals:HideFrom(medals + 1)
  pf.empty:SetShown(#list == 0 and not gallery)
  if #list == 0 and not gallery then
    s:Skip(20)
    local sessions = pf.filter == "session"
    s:Place(pf.empty, pf.empty:Set(sessions and ns.ICONS.hist_session or ns.ICONS.hist_run,
      sessions and L.HIST_EMPTY_SESSIONS or L.HIST_EMPTY, sessions and L.HIST_EMPTY_SESSIONS_TEXT or L.HIST_EMPTY_TEXT,
      nil, nil, "EmptyHistory"), 4)
  end
  pf.lscroll:SetContentHeight(s.y + 8)

  local r = UI.Stack(pf.rscroll.child)
  pf.head:SetHelp(L.HIST_HOW .. "\n" .. L.HIST_RULE:format(f.rules.minHeroes) .. "\n\n" .. L.HIST_NOTE)
  r:Place(pf.head, pf.head:GetHeight(), 8)
  -- The tallies, once someone has a count.
  local tallies = ns.Firsts:Tallies(f)
  pf.none:SetShown(#tallies == 0)
  if #tallies == 0 then r:Place(pf.none, pf.none:GetStringHeight(), 4) end
  if #tallies > 0 then
    local light = Theme:Current().light
    for i, t in ipairs(tallies) do
      local row = pf.tRows:Get(i)
      if not row then break end
      row.what:SetText(L["TALLY_" .. t.kind:upper()])
      row.all = t.all
      for k, pl in ipairs(row.places) do
        local x = t.top[k]
        pl:SetShown(x ~= nil)
        if x then
          local m = f.members[x.name]
          local hex = ns.ClassHex(m and m.class, light)
          local name = ns.Short(x.name)
          pl.name:SetText(L.TALLY_LINE:format(hex and ("|cff" .. hex .. name .. "|r") or name, x.n))
        end
      end
      r:Place(row, 42, 4)
    end
  end
  pf.tRows:HideFrom(#tallies + 1)
  pf.rscroll:SetContentHeight(r.y + 8)
end

ns.Pages:Register({ id = "chronicle", label = L.NAV_CHRONICLE, build = build, refresh = refresh,
  title = function() return L.TITLE_CHRONICLE, L.SUB_CHRONICLE end })
