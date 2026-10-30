-- History (SPEC §4.8a, 29 Oct 2026): the fellowship's own story, in the Fellowship section (the journey's is the
-- Chronicle). Left: filter (All, Adventurers, Rules and votes, Events) and the chronicle's lines (Fellowship.lua,
-- F:Log), each with an icon and when. Right: the fellowship so far: when it was founded, numbers, its Leaders.
local _, ns = ...
local L = ns.L
local UI = ns.UI
local F = ns.Fellowship

local FILTERS = { { L.HI_ALL, "all" }, { L.HI_MEMBERS, "members" }, { L.HI_RULES, "rules" }, { L.HI_EVENTS, "events" } }
-- The icon of each kind of line (older lines without a kind: the page's own).
local ICON = {
  founded = "toast_chapter", invited = "inbox", joined = "heroes", swap = "heroes", left = "bn_away", removed = "bn_away",
  leads = "manage", swapleader = "manage", takeover = "manage",
  rules = "rules", journey = "admin", renamed = "rules", vote = "rules", votepassed = "rules",
  gather = "gatherings", gathercancel = "gatherings", tstart = "tourney", champion = "tourney", tcancel = "tourney",
  marked = "hist_mark", undid = "hist_undo", reopened = "hist_undo", ticked = "hist_mark", unticked = "hist_undo",
}
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

local function build(pf)
  local W = ns.Window
  local width = W.PAGE_W - 8
  pf.filter = "all"

  pf.lscroll = UI.Scroll(pf.left)
  pf.lscroll:SetAllPoints()
  local Lc = pf.lscroll.child
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
  pf.stats = {}
  for i = 1, 4 do
    local box = UI.Card(R)
    box:SetSize((width - 8) / 2, 58)
    box.v = UI.Text(box, 22, "ink", "title", "CENTER")
    box.v:SetPoint("TOP", 0, -8)
    box.k = UI.Text(box, 12, "ink2", "body", "CENTER")
    box.k:SetPoint("TOP", box.v, "BOTTOM", 0, -4)
    box.k:SetText(L["HI_STAT_" .. i])
    pf.stats[i] = box
  end
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
  pf.div = UI.Divider(R)
  pf.note = UI.WrapText(R, 12, "ink2", width, "book")
  pf.note:SetText(L.HI_NOTE)
  pf.open = UI.TextButton(R, L.HI_OPEN_CHRONICLE, function() W:ShowPage("chronicle") end, "plain", 12)
end

local function refresh(pf, ctx)
  local f = ctx.f
  if not f then return end
  local width = ns.Window.PAGE_W - 8

  local s = UI.Stack(pf.lscroll.child)
  pf.choice:Refresh()
  s:Place(pf.choice, pf.choice:GetHeight(), 10)
  local list = entries(f, pf.filter)
  local shown = 0
  for i, entry in ipairs(list) do
    local e = pf.rows:Get(i)
    if not e then break end
    shown = i
    UI.SetIcon(e.icon, ns.ICONS[ICON[entry.k] or "history"])
    e.text:SetText(entry.text)
    e.when:ClearAllPoints(); e.when:SetPoint("TOPLEFT", e.text, "BOTTOMLEFT", 0, -4)
    e.when:SetText(ns.TimeAgo(entry.time))
    local h = e.text:GetStringHeight() + 26
    e:SetHeight(h)
    s:Place(e, h, 4)
  end
  pf.rows:HideFrom(shown + 1)
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
  for i, box in ipairs(pf.stats) do
    box.v:SetText(n[i])
    box:ClearAllPoints()
    box:SetPoint("TOPLEFT", pf.rscroll.child, "TOPLEFT", ((i - 1) % 2) * ((width - 8) / 2 + 8), -(y + math.floor((i - 1) / 2) * 66))
    box:Show()
  end
  r:Skip(132 + 10)
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
  r:Skip(12)
  pf.div:ClearAllPoints()
  pf.div:SetPoint("TOPLEFT", pf.rscroll.child, "TOPLEFT", 0, -r.y); pf.div:SetPoint("TOPRIGHT", pf.rscroll.child, "TOPRIGHT", 0, -r.y)
  r:Skip(20)
  r:Place(pf.note, pf.note:GetStringHeight(), 8)
  r:Place(pf.open, 24, 8)
  pf.rscroll:SetContentHeight(r.y + 8)
end

ns.Pages:Register({ id = "history", label = L.NAV_HISTORY, build = build, refresh = refresh,
  title = function() return L.TITLE_HISTORY, L.SUB_HISTORY end })
