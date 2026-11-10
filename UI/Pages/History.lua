-- History (SPEC §4.7, 29 Oct 2026): the fellowship's own story, the Chronicle's third tab The fellowship since U142
-- (9 Nov 2026; parent = "chronicle"), its lines under day headings (U132). Left: filter (All, Adventurers, Rules and
-- votes, Events) and the chronicle's lines (Fellowship.lua, F:Log), each with an icon and when. Right: the fellowship so far: when it was founded, numbers, its Leaders.
local _, ns = ...
local L = ns.L
local UI = ns.UI
local F, J, Theme = ns.Fellowship, ns.Journey, ns.Theme

local FILTERS = { { L.HI_ALL, "all" }, { L.HI_MEMBERS, "members" }, { L.HI_RULES, "rules" }, { L.HI_EVENTS, "events" } }
local LEADS = { founded = true, leads = true, swapleader = true, takeover = true }
local ALL = 1000

local function entries(f, filter) return F:ChronicleView(f, ALL, filter ~= "all" and filter or nil) end

-- Who has led the fellowship, oldest first: { who, time } (the last is the Leader now).
local function leaders(f)
  local out = {}
  for i = #f.chronicle, 1, -1 do
    local e = f.chronicle[i]
    if LEADS[e.k] and e.who and (not out[#out] or out[#out].who ~= e.who) then out[#out + 1] = { who = e.who, time = e.time } end
  end
  if not out[#out] or out[#out].who ~= f.leader then out[#out + 1] = { who = f.leader } end
  return out
end

-- When the fellowship was founded, and by whom: its "founded" line, else the time in its id.
local function founded(f)
  for i = #f.chronicle, 1, -1 do
    local e = f.chronicle[i]
    if e.k == "founded" then return e.time, e.who end
  end
  return tonumber(tostring(f.id):match("%-(%d+)$")), nil
end

-- The chapters reached so far and the day each began (U9, 31 Oct 2026): the first chapter when the fellowship was
-- founded, every later one at its first "chapter" line in the journey's History (a chapter opened again after an Undo
-- keeps its first day). Oldest first: { { n, name, time } }; time nil when no line says.
function ns.HistoryChapters(f, foundedAt)
  local chapters = f.journey and f.journey.chapters or {}
  local cur = math.min(ns.Journey:CurrentIndex(f), #chapters)
  local first = {}
  for _, e in ipairs(f.history or {}) do
    local n = e.type == "chapter" and tonumber(e.ch)
    if n and (not first[n] or e.time < first[n]) then first[n] = e.time end
  end
  local out = {}
  for n = 1, cur do
    out[#out + 1] = { n = n, name = chapters[n] and chapters[n].name or "", time = n == 1 and foundedAt or first[n] }
  end
  return out
end

local function build(pf)
  local W = ns.Window
  local width = W.PAGE_W - 8
  pf.filter = "all"

  local top = ns.ChronicleTabs(pf)
  pf.lscroll = UI.Scroll(pf.left)
  pf.lscroll:SetPoint("TOPLEFT", 0, -top); pf.lscroll:SetPoint("BOTTOMRIGHT")
  local Lc = pf.lscroll.child
  pf.days = UI.DayHeads(Lc, width)
  pf.choice = UI.Tabs(Lc, FILTERS, function() return pf.filter end, function(v) pf.filter = v; W:Refresh() end, width,
    function(v) local f = F:Current(); return f and v ~= "all" and #entries(f, v) or nil end)
  pf.rows = UI.Pool(function()
    local e = CreateFrame("Frame", nil, Lc)
    e:SetWidth(width)
    e.icon = e:CreateTexture(nil, "ARTWORK")
    e.icon:SetSize(18, 18); e.icon:SetPoint("TOPLEFT", 2, -1)
    e.text = UI.WrapText(e, 13, "ink", width - 32, "book")
    e.text:SetPoint("TOPLEFT", 30, 0)
    e.when = UI.Text(e, 11, "ink2")
    e.line = UI.Solid(e, "ARTWORK", "line", 0.6)
    e.line:SetHeight(1); e.line:SetPoint("BOTTOMLEFT"); e.line:SetPoint("BOTTOMRIGHT")
    return e
  end)
  pf.empty = UI.EmptyState(Lc, width)

  pf.rscroll = UI.Scroll(pf.right)
  pf.rscroll:SetAllPoints()
  local R = pf.rscroll.child
  pf.head = UI.Heading(R, width, L.HI_SO_FAR, nil, 20)
  pf.founded = UI.WrapText(R, 14, "ink", width, "book")
  pf.founded:SetJustifyH("CENTER")
  -- Number tiles (U6, UI.NumberTile): Adventurers now, have joined (the invitation), have left, Gatherings.
  pf.stats = {}
  for i, icon in ipairs({ "heroes", "inbox", "bn_away", "gatherings" }) do
    pf.stats[i] = UI.NumberTile(R, (width - 8) / 2, 58, L["HI_STAT_" .. i], ns.ICONS[icon])
  end
  -- The chapters so far (U9): a line down the left with a gold dot per chapter, its name and the day it began.
  pf.chHead = UI.SectionHeader(R, width)
  pf.chHead:SetText(L.HI_CHAPTERS)
  pf.chRows = UI.Pool(function()
    local d = CreateFrame("Frame", nil, R)
    d:SetSize(width, 22)
    d.stem = UI.Solid(d, "BORDER", "gold", 0.6)
    d.stem:SetWidth(2); d.stem:SetPoint("TOP", d, "TOPLEFT", 10, 0); d.stem:SetPoint("BOTTOM", d, "BOTTOMLEFT", 10, 0)
    d.dot = UI.Round(d, "ARTWORK", 10)
    d.dot:SetPoint("CENTER", d, "LEFT", 10, 0)
    d.n = UI.Text(d, 12, "ink2", "title")
    d.n:SetPoint("LEFT", 26, 0)
    d.name = UI.Text(d, 13, "ink")
    d.name:SetPoint("LEFT", d.n, "RIGHT", 6, 0)
    d.day = UI.Text(d, 12, "ink2", "body", "RIGHT")
    d.day:SetPoint("RIGHT")
    return d
  end)
  pf.leadHead = UI.SectionHeader(R, width)
  pf.leadHead:SetText(L.HI_LEADERS)
  pf.leads = UI.Pool(function()
    local d = CreateFrame("Frame", nil, R)
    d:SetSize(width, 24)
    d.icon = UI.Round(d, "ARTWORK", 18)
    d.icon:SetPoint("LEFT", 2, 0)
    UI.SetIcon(d.icon, ns.ICONS.manage)
    d.name = UI.Text(d, 13, "ink")
    d.name:SetPoint("LEFT", 28, 0)
    d.since = UI.Text(d, 12, "ink2", "body", "RIGHT")
    d.since:SetPoint("RIGHT")
    return d
  end)
end

local function refresh(pf, ctx)
  local f = ctx.f
  if not f then return end
  local width = ns.Window.PAGE_W - 8

  pf.tabs:Refresh()
  local s = UI.Stack(pf.lscroll.child)
  pf.choice:Refresh()
  s:Place(pf.choice, pf.choice:GetHeight(), 10)
  local list = entries(f, pf.filter)
  local shown = 0
  pf.days:Start()
  for i, entry in ipairs(list) do
    local e = pf.rows:Get(i)
    if not e then break end
    shown = i
    pf.days:Place(s, entry.time)
    UI.SetIcon(e.icon, ns.ICONS[F.LOG_ICON[entry.k] or "history"])
    e.text:SetText(entry.text)
    e.when:ClearAllPoints(); e.when:SetPoint("TOPLEFT", e.text, "BOTTOMLEFT", 0, -4)
    e.when:SetText(ns.TimeAgo(entry.time))
    local h = e.text:GetStringHeight() + 26
    e:SetHeight(h)
    s:Place(e, h, 4)
  end
  pf.rows:HideFrom(shown + 1)
  pf.days:Done()
  pf.empty:SetShown(#list == 0)
  if #list == 0 then
    s:Skip(20)
    s:Place(pf.empty, pf.empty:Set(ns.ICONS.history, L.HI_EMPTY, L.HI_EMPTY_TEXT, nil, nil, "EmptyHistory"), 4)
  end
  pf.lscroll:SetContentHeight(s.y + 8)

  -- Right: the fellowship so far.
  local r = UI.Stack(pf.rscroll.child)
  r:Place(pf.head, pf.head:GetHeight(), 4)
  local t, by = founded(f)
  pf.founded:SetShown(t ~= nil)
  if t then
    pf.founded:SetText(by and L.HI_FOUNDED:format(ns.Moments.Day(t), ns.Short(by)) or L.HI_FOUNDED_0:format(ns.Moments.Day(t)))
    r:Place(pf.founded, pf.founded:GetStringHeight(), 12)
  end
  local n = { F:Count(f), 0, 0, 0 }
  for _, e in ipairs(f.chronicle) do
    if e.k == "joined" then n[2] = n[2] + 1
    elseif e.k == "left" or e.k == "removed" then n[3] = n[3] + 1
    elseif e.k == "gather" then n[4] = n[4] + 1 end
  end
  local y = r.y
  for i, tile in ipairs(pf.stats) do
    tile:Set(n[i])
    tile:ClearAllPoints()
    tile:SetPoint("TOPLEFT", pf.rscroll.child, "TOPLEFT", ((i - 1) % 2) * ((width - 8) / 2 + 8), -(y + math.floor((i - 1) / 2) * 66))
    tile:Show()
  end
  r:Skip(132 + 10)
  -- The chapters so far: the current one in gold with "now".
  local chs = ns.HistoryChapters(f, t)
  r:Place(pf.chHead, 29, 6)
  for i, c in ipairs(chs) do
    local d = pf.chRows:Get(i)
    if not d then break end
    local now = i == #chs
    d.n:SetText(J.Roman(c.n))
    d.name:SetText(c.name)
    d.day:SetText(now and L.HI_CH_NOW:format(c.time and ns.Moments.Day(c.time) or "-") or (c.time and ns.Moments.Day(c.time) or ""))
    Theme:Fill(d.dot, now and "gold" or "line", 1)
    d.name:SetTextColor(Theme:RGBA(now and "accentText" or "ink"))
    -- The line joins the dots: from the first dot down to the last.
    d.stem:ClearAllPoints()
    d.stem:SetPoint("TOP", d, "TOPLEFT", 10, i == 1 and -11 or 0)
    d.stem:SetPoint("BOTTOM", d, "BOTTOMLEFT", 10, now and 11 or -2)
    d.stem:SetShown(#chs > 1)
    r:Place(d, 22, 2)
  end
  pf.chRows:HideFrom(#chs + 1)
  r:Skip(10)
  r:Place(pf.leadHead, 29, 6)
  local led = leaders(f)
  local nl = 0
  for i, l in ipairs(led) do
    local d = pf.leads:Get(i)
    if not d then break end
    nl = i
    local m = f.members[l.who]
    local hex = ns.ClassHex(m and m.class, true)
    d.name:SetText(hex and ("|cff" .. hex .. ns.Short(l.who) .. "|r") or ns.Short(l.who))
    d.since:SetText(i == #led and L.HI_LEADER_NOW or (l.time and L.HI_LEADER_FROM:format(ns.Moments.Day(l.time)) or ""))
    r:Place(d, 24, 2)
  end
  pf.leads:HideFrom(nl + 1)
  pf.rscroll:SetContentHeight(r.y + 8)
end

ns.Pages:Register({ id = "history", label = L.CH_TAB_FELLOWSHIP, icon = "chronicle", parent = "chronicle", build = build,
  refresh = refresh, title = function() return L.TITLE_CHRONICLE, L.SUB_HISTORY end })
