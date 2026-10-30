-- Chronicle (SPEC §4.7; the History page until 29 Oct 2026), the journey's story. Two tabs, each a page of its own: this
-- one and Moments (UI/Pages/Moments.lua, parent = "chronicle"). Left: filter (All, Runs, Sessions, Leader changes, Over
-- the cap) and the entries, each with an icon, text, when, and a status chip. Right: how clears are counted, totals.
local _, ns = ...
local L = ns.L
local UI, Theme = ns.UI, ns.Theme
local Cl = ns.Clears

local FILTERS = { { L.HIST_ALL, "all" }, { L.HIST_RUNS, "run" }, { L.HIST_SESSIONS, "session" },
  { L.HIST_LEADER, "leader" }, { L.HIST_CAP, "cap" } }

-- The entries of a filter: the fellowship's history, and your own sessions (M25) under Sessions and in All.
local function entries(f, filter)
  if filter == "session" then return ns.Session:Entries(f) end
  local list = Cl:Entries(f, filter)
  if filter ~= "all" then return list end
  -- Entries of the same second keep their order (newest first): chapters unlocked together came out sorted by their
  -- text, IV, IX, V ... (seen in the check of 29 Oct 2026).
  local all, at = {}, {}
  for _, e in ipairs(list) do all[#all + 1] = e; at[e] = #all end
  for _, e in ipairs(ns.Session:Entries(f)) do all[#all + 1] = e; at[e] = #all end
  table.sort(all, function(a, b)
    if a.time ~= b.time then return a.time > b.time end
    return at[a] < at[b]
  end)
  return all
end

-- The tab strip at the top of each tab's left page (as Manage's, UI/Pages/Manage.lua). Returns the height it takes.
local TABS = { { "CH_TAB_LOG", "chronicle" }, { "CH_TAB_MOMENTS", "moments" } }
function ns.ChronicleTabs(pf)
  local W = ns.Window
  local opts = {}
  for i, t in ipairs(TABS) do opts[i] = { L[t[1]], t[2] } end
  pf.tabs = UI.Tabs(pf.left, opts, function() return W.current end, function(id) W:ShowPage(id) end, W.PAGE_W - 8)
  pf.tabs:SetPoint("TOPLEFT", 0, 0)
  return 40
end

local function build(pf)
  local W = ns.Window
  local width = W.PAGE_W - 8
  pf.filter = "all"

  local top = ns.ChronicleTabs(pf)
  pf.lscroll = UI.Scroll(pf.left)
  pf.lscroll:SetPoint("TOPLEFT", 0, -top); pf.lscroll:SetPoint("BOTTOMRIGHT")
  local Lc = pf.lscroll.child
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
    e.line = UI.Solid(e, "ARTWORK", "line", 0.6)
    e.line:SetHeight(1); e.line:SetPoint("BOTTOMLEFT"); e.line:SetPoint("BOTTOMRIGHT")
    return e
  end)
  pf.empty = UI.EmptyState(Lc, width)

  pf.rscroll = UI.Scroll(pf.right)
  pf.rscroll:SetAllPoints()
  local R = pf.rscroll.child
  pf.head = UI.Heading(R, width, L.HIST_HOW, nil, 20)
  pf.head:SetHelp("") -- the "?" made now, not during combat
  pf.rule = UI.WrapText(R, 14, "ink", width, "book")
  pf.stats = {}
  for i = 1, 4 do
    local box = UI.Card(R)
    box:SetSize((width - 8) / 2, 58)
    box.v = UI.Text(box, 22, "ink", "title", "CENTER")
    box.v:SetPoint("TOP", 0, -8)
    box.k = UI.Text(box, 12, "ink2", "body", "CENTER")
    box.k:SetPoint("TOP", box.v, "BOTTOM", 0, -4)
    box.k:SetText(L["HIST_STAT_" .. i])
    pf.stats[i] = box
  end
  pf.div = UI.Divider(R)
  pf.note = UI.WrapText(R, 12, "ink2", width, "book")
  pf.note:SetText(L.HIST_NOTE)
  -- The journey's dungeons so far (M21; the page was half empty): each with its picture and how many Heroes have
  -- cleared it, the cleared ones marked.
  pf.clHead = UI.SectionHeader(R, width)
  pf.clHead:SetText(L.HIST_DUNGEONS)
  pf.clRows = UI.Pool(function()
    local d = CreateFrame("Frame", nil, R)
    d:SetSize(width, 30)
    d.ring = UI.Round(d, "ARTWORK", 26)
    d.ring:SetPoint("LEFT"); Theme:Fill(d.ring, "gold", 0.9)
    d.pic = UI.Round(d, "OVERLAY", 22)
    d.pic:SetPoint("CENTER", d.ring)
    d.name = UI.Text(d, 13, "ink")
    d.name:SetPoint("LEFT", 34, 0)
    d.n = UI.Text(d, 12, "ink2", "body", "RIGHT")
    d.n:SetPoint("RIGHT", -20, 0)
    d.mark = UI.Mark(d, 14)
    d.mark:SetPoint("RIGHT")
    return d
  end)
end

local function refresh(pf, ctx)
  local f = ctx.f
  if not f then return end
  local width = ns.Window.PAGE_W - 8

  pf.tabs:Refresh()
  -- Opened at a filter (the session recap's toast: "chronicle#session").
  if ns.Window.tab then pf.filter = ns.Window.tab; ns.Window.tab = nil end
  local s = UI.Stack(pf.lscroll.child)
  pf.choice:Refresh()
  s:Place(pf.choice, pf.choice:GetHeight(), 10)
  local list = entries(f, pf.filter)
  local shown = 0
  for i, entry in ipairs(list) do
    local e = pf.rows:Get(i)
    if not e then break end
    shown = i
    UI.SetIcon(e.icon, ns.ICONS[Cl.ICON[entry.icon] or "hist_run"])
    e.text:SetText(Cl:Text(entry))
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
  pf.empty:SetShown(#list == 0)
  if #list == 0 then
    s:Skip(20)
    local sessions = pf.filter == "session"
    s:Place(pf.empty, pf.empty:Set(sessions and ns.ICONS.hist_session or ns.ICONS.hist_run,
      sessions and L.HIST_EMPTY_SESSIONS or L.HIST_EMPTY, sessions and L.HIST_EMPTY_SESSIONS_TEXT or L.HIST_EMPTY_TEXT,
      nil, nil, "EmptyHistory"), 4)
  end
  pf.lscroll:SetContentHeight(s.y + 8)

  local r = UI.Stack(pf.rscroll.child)
  -- How clears are counted: behind the "?" by the title (a paragraph of rules on the page; seen in the tour).
  pf.head:SetHelp(L.HIST_RULE:format(f.rules.minHeroes))
  pf.rule:Hide()
  r:Place(pf.head, pf.head:GetHeight(), 8)
  local totals = Cl:Totals(f)
  local y = r.y
  for i, box in ipairs(pf.stats) do
    box.v:SetText(totals[i])
    box:ClearAllPoints()
    box:SetPoint("TOPLEFT", pf.rscroll.child, "TOPLEFT", ((i - 1) % 2) * ((width - 8) / 2 + 8), -(y + math.floor((i - 1) / 2) * 66))
    box:Show()
  end
  r:Skip(132 + 6)
  pf.div:ClearAllPoints()
  pf.div:SetPoint("TOPLEFT", pf.rscroll.child, "TOPLEFT", 0, -r.y); pf.div:SetPoint("TOPRIGHT", pf.rscroll.child, "TOPRIGHT", 0, -r.y)
  r:Skip(20)
  r:Place(pf.note, pf.note:GetStringHeight(), 4)
  -- The dungeons of the chapters reached so far.
  local J = ns.Journey
  local cur = math.min(J:CurrentIndex(f), #f.journey.chapters)
  local counted, n = #J:Counted(f), 0
  for chN = 1, cur do
    for _, x in ipairs(J:InChapter(f, chN)) do
      local row = pf.clRows:Get(n + 1)
      if not row then break end
      n = n + 1
      local ok = ns.SetDungeonArt(row.pic, x.key, 22, 22)
      row.pic:SetShown(ok)
      row.name:SetText(x.d[2])
      local have = 0
      for name in pairs(J:ClearedBy(f, x.key)) do if f.members[name] then have = have + 1 end end
      row.n:SetText((counted == 1 and L.HIST_CLEARED_BY_1 or L.HIST_CLEARED_BY):format(have, counted))
      row.mark:SetMark(J:Cleared(f, x.key) and "cleared" or nil)
    end
  end
  pf.clHead:SetShown(n > 0)
  if n > 0 then
    r:Skip(10)
    r:Place(pf.clHead, 29, 6)
    for i = 1, n do r:Place(pf.clRows.items[i], 30, 2) end
  end
  pf.clRows:HideFrom(n + 1)
  pf.rscroll:SetContentHeight(r.y + 8)
end

ns.Pages:Register({ id = "chronicle", label = L.NAV_CHRONICLE, build = build, refresh = refresh,
  title = function() return L.TITLE_CHRONICLE, L.SUB_CHRONICLE end })
