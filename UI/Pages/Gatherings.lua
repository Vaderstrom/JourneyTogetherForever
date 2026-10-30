-- Gatherings (SPEC §6): its own page since 27 Oct 2026 (the Overview's section was crowded; the Overview keeps one
-- line about the next one). Left: Schedule and the upcoming Gatherings, each answered with Yes / Maybe / No. Right:
-- the chosen Gathering: its picture, who set it up, who is coming, who has not answered, and how the reminder and
-- the invites work. The data and ops are in Fellowship/Gatherings.lua.
local _, ns = ...
local L = ns.L
local UI, Theme = ns.UI, ns.Theme
local G = ns.Gatherings

local PIC_H = 112

-- "Brannic, You, Elyra" or "Nobody".
local function names(list, me)
  if #list == 0 then return L.G_NOBODY end
  local out = {}
  for _, n in ipairs(list) do
    if n == me then table.insert(out, 1, L.YOU_LABEL) else out[#out + 1] = ns.Short(n) end -- you first
  end
  return table.concat(out, ", ")
end

-- Who answered what: { yes = {}, maybe = {}, no = {}, none = {} }, names sorted.
local function answers(f, g)
  local out = { yes = {}, maybe = {}, no = {}, none = {} }
  for name in pairs(f.members) do
    local a = g.answers[name]
    table.insert(out[a or "none"] or out.none, name)
  end
  for _, l in pairs(out) do table.sort(l) end
  return out
end

local function build(pf)
  local W = ns.Window
  local width = W.PAGE_W - 8
  pf.lscroll = UI.Scroll(pf.left)
  pf.lscroll:SetAllPoints()
  pf.art = UI.PageArt(pf.lscroll, "Gatherings")
  local Lc = pf.lscroll.child
  pf.new = UI.TextButton(Lc, L.G_SCHEDULE, function() ns.GatherForm:Open() end, "primary")
  pf.head = UI.SectionHeader(Lc, width)
  pf.head:SetText(L.G_UPCOMING)
  pf.rows = UI.Pool(function()
    -- Each Gathering looks like a row of the game's Achievements window: its gold parchment, a framed picture (the
    -- dungeon, or a campfire) and the text beside it. The game's own files, in Forever too. A click chooses it.
    local r = UI.Card(Lc, "bookEdge", "Button")
    r:SetWidth(width)
    r.bg = r:CreateTexture(nil, "BACKGROUND", nil, 1)
    r.bg:SetPoint("TOPLEFT", 3, -3); r.bg:SetPoint("BOTTOMRIGHT", -3, 3)
    r.bg:SetTexture("Interface\\AchievementFrame\\UI-Achievement-Parchment-Horizontal")
    r.bg:SetTexCoord(0, 1, 0, 0.6)
    Theme:Register(function() r.bg:SetVertexColor(unpack(Theme.PAPER_TINT[Theme:Key()] or Theme.PAPER_TINT.journal)) end)
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(44, 44); r.icon:SetPoint("TOPLEFT", 14, -12)
    r.iconFrame = r:CreateTexture(nil, "OVERLAY")
    r.iconFrame:SetSize(64, 64); r.iconFrame:SetPoint("CENTER", r.icon, "CENTER", -1, 1)
    r.iconFrame:SetTexture("Interface\\AchievementFrame\\UI-Achievement-IconFrame")
    r.iconFrame:SetTexCoord(0, 0.5625, 0, 0.5625)
    r.what = UI.WrapText(r, 13, "ink", width - 84, "title")
    r.what:SetPoint("TOPLEFT", 70, -10)
    r.line = UI.Text(r, 11, "ink2")
    r.answer = UI.Choice(r, { { L.G_YES, "yes" }, { L.G_MAYBE, "maybe" }, { L.G_NO, "no" } },
      function() return r.g and r.g.answers[ns.Me()] end,
      function(v) if r.g then G:Answer(r.g.id, v) end end)
    local hl = r:CreateTexture(nil, "HIGHLIGHT")
    hl:SetPoint("TOPLEFT", 3, -3); hl:SetPoint("BOTTOMRIGHT", -3, 3); hl:SetColorTexture(1, 0.9, 0.6, 0.08)
    -- The chosen one: a gold glow and a gold bar on the left (the card's own selected border hides under the
    -- parchment).
    r.glow = r:CreateTexture(nil, "ARTWORK", nil, -1)
    r.glow:SetPoint("TOPLEFT", 3, -3); r.glow:SetPoint("BOTTOMRIGHT", -3, 3); r.glow:SetColorTexture(1, 0.82, 0.35, 0.22)
    r.bar = r:CreateTexture(nil, "OVERLAY")
    r.bar:SetPoint("TOPLEFT", 1, -1); r.bar:SetPoint("BOTTOMLEFT", 1, 1); r.bar:SetWidth(4)
    Theme:Register(function() r.bar:SetColorTexture(Theme:RGBA("gold")) end)
    r:SetScript("OnClick", function() if r.g then pf.gid = r.g.id; W:Refresh() end end)
    return r
  end)
  pf.none = UI.SketchLine(Lc, width, "EmptyGatherings")
  pf.none:SetText(L.G_NONE)

  pf.rscroll = UI.Scroll(pf.right)
  pf.rscroll:SetAllPoints()
  local R = pf.rscroll.child
  -- The chosen Gathering: its picture with what and when on it.
  local band = CreateFrame("Frame", nil, R)
  band:SetSize(width, PIC_H)
  band.art = band:CreateTexture(nil, "ARTWORK")
  local fade = band:CreateTexture(nil, "ARTWORK", nil, 2)
  UI.FramePicture(band, band.art, fade)
  UI.SetGradient(fade, "VERTICAL", { 0.055, 0.03, 0.01, 0.9 }, { 0.055, 0.03, 0.01, 0.05 })
  band.when = UI.Text(band, 12, "E8C878")
  band.when:SetPoint("BOTTOMLEFT", 14, 34)
  band.what = UI.Text(band, 19, "goldText", "title")
  band.what:SetPoint("BOTTOMLEFT", 14, 10); band.what:SetWidth(width - 28)
  band.what:SetShadowOffset(0, -1); band.what:SetShadowColor(0, 0, 0, 1)
  pf.band = band
  pf.by = UI.WrapText(R, 13, "ink", width, "book")
  pf.answer = UI.Choice(R, { { L.G_YES, "yes" }, { L.G_MAYBE, "maybe" }, { L.G_NO, "no" } },
    function() return pf.g and pf.g.answers[ns.Me()] end,
    function(v) if pf.g then G:Answer(pf.g.id, v) end end)
  pf.cancel = UI.TextButton(R, L.CANCEL, function()
    local g = pf.g
    if g then W:Confirm(L.G_CANCEL_CONFIRM:format(G.What(g)), L.CANCEL, function() G:Cancel(g.id) end) end
  end, "link", 12)
  pf.whoHead = UI.SectionHeader(R, width)
  pf.whoHead:SetText(L.G_WHO_HEAD)
  pf.who = {}
  for i, key in ipairs({ "yes", "maybe", "no", "none" }) do
    local row = CreateFrame("Frame", nil, R)
    row:SetWidth(width)
    row.k = UI.Text(row, 13, "ink", "title")
    row.k:SetPoint("TOPLEFT")
    row.v = UI.WrapText(row, 13, "ink", width - 120, "book")
    row.v:SetPoint("TOPLEFT", 120, 0)
    row.key = key
    pf.who[i] = row
  end
  -- The week ahead (M25; the right page was bare with no Gatherings): each day with its Gatherings, or Schedule.
  pf.weekHead = UI.SectionHeader(R, width)
  pf.weekHead:SetText(L.G_WEEK_HEAD)
  pf.week = {}
  for i = 1, ns.GatherForm.DAYS_SHOWN do
    local row = CreateFrame("Frame", nil, R)
    row:SetSize(width, 28)
    row.n = i - 1
    row.day = UI.Text(row, 13, "ink", "title")
    row.day:SetPoint("LEFT", 2, 0)
    row.what = UI.Text(row, 13, "ink")
    row.what:SetPoint("LEFT", 110, 0)
    row.what:SetWidth(width - 112); row.what:SetWordWrap(false)
    row.add = UI.TextButton(row, L.G_SCHEDULE, function() ns.GatherForm:Open(row.n) end, "link", 12)
    row.add:SetPoint("LEFT", 104, 0)
    row.line = UI.Solid(row, "BACKGROUND", "line", 0.5)
    row.line:SetHeight(1); row.line:SetPoint("BOTTOMLEFT"); row.line:SetPoint("BOTTOMRIGHT")
    pf.week[i] = row
  end
  pf.howHead = UI.SectionHeader(R, width)
  pf.howHead:SetText(L.G_HOW_HEAD)
  pf.how = UI.WrapText(R, 13, "ink2", width, "book")
end

local function refresh(pf, ctx)
  local f = ctx.f
  if not f then return end
  local width = ns.Window.PAGE_W - 8
  local me = ctx.me
  local list = G:Upcoming(f)

  -- Left: Schedule, then the upcoming Gatherings.
  local s = UI.Stack(pf.lscroll.child)
  s:Place(pf.new, 30, 12)
  s:Place(pf.head, 29, 6)
  local chosen
  local n = 0
  for i, g in ipairs(list) do
    local r = pf.rows:Get(i)
    if not r then break end
    n = i
    r.g = g
    if g.id == pf.gid then chosen = g end
    r.what:SetText(L.G_WHEN_WHAT:format(G.When(g.at), G.What(g)))
    if not (g.key and ns.SetDungeonArt(r.icon, g.key, 44, 44)) then
      r.icon:SetTexture("Interface\\Icons\\Spell_Fire_Fire"); r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end
    local top = 10 + r.what:GetStringHeight() + 2
    r.line:ClearAllPoints(); r.line:SetPoint("TOPLEFT", 70, -top)
    r.line:SetText(G.Line(g))
    r.answer:ClearAllPoints(); r.answer:SetPoint("TOPLEFT", 70, -(top + 16))
    r.answer:Refresh()
    local h = math.max(68, top + 16 + 26 + 8)
    r:SetHeight(h)
    s:Place(r, h, 8)
  end
  pf.rows:HideFrom(n + 1)
  pf.none:SetShown(#list == 0)
  if #list == 0 then s:Place(pf.none, pf.none.h, 4) end
  pf.lscroll:SetContentHeight(s.y + 8)
  -- Under a short list, and with none (the empty line's sketch is only an icon; both pages were bare in the tour).
  pf.art:Fit(s.y)

  -- Right: the chosen Gathering, or how Gatherings work. Only a click remembers one (pf.gid); otherwise it is the
  -- soonest, also when an earlier one arrives later (the tour showed a later one while an earlier one was listed).
  chosen = chosen or list[1]
  pf.g = chosen
  for _, r in ipairs(pf.rows.items) do
    local on = r:IsShown() and chosen ~= nil and r.g == chosen
    r.glow:SetShown(on); r.bar:SetShown(on)
  end
  local r = UI.Stack(pf.rscroll.child)
  local has = chosen ~= nil
  pf.band:SetShown(has); pf.by:SetShown(has); pf.answer:SetShown(has); pf.whoHead:SetShown(has)
  for _, row in ipairs(pf.who) do row:SetShown(has) end
  pf.cancel:SetShown(has and G:CanCancel(f, chosen))
  if has then
    local pw, ph = width - 2 * UI.PIC_INSET, PIC_H - 2 * UI.PIC_INSET
    local ok = chosen.key and ns.SetDungeonArt(pf.band.art, chosen.key, pw, ph)
    if not ok then ns.Pages:SetChapterArt(pf.band.art, ns.Pages:ArtOf(f, ns.Journey:CurrentIndex(f)), pw, ph, 0.5) end
    pf.band.when:SetText(G.When(chosen.at))
    pf.band.what:SetText(G.What(chosen))
    r:Place(pf.band, PIC_H, 10)
    pf.by:SetText(L.G_BY:format(chosen.by == me and L.YOU_LABEL or ns.Short(chosen.by)))
    r:Place(pf.by, pf.by:GetStringHeight(), 8)
    pf.answer:Refresh()
    r:Place(pf.answer, 26, 4)
    pf.cancel:ClearAllPoints(); pf.cancel:SetPoint("LEFT", pf.answer, "RIGHT", 10, 0)
    r:Skip(10)
    r:Place(pf.whoHead, 29, 6)
    local a = answers(f, chosen)
    local label = { yes = L.G_COMING, maybe = L.G_MAYBE, no = L.G_NOT_COMING, none = L.G_NOT_ANSWERED }
    for _, row in ipairs(pf.who) do
      row.k:SetText(label[row.key])
      row.v:SetText(names(a[row.key], me))
      local h = math.max(18, row.v:GetStringHeight())
      row:SetHeight(h)
      r:Place(row, h, 6)
    end
    r:Skip(8)
  end
  -- The week ahead.
  r:Place(pf.weekHead, 29, 4)
  local GF = ns.GatherForm
  local byDay = {}
  for _, g in ipairs(list) do
    local d = GF.DayOf(g.at)
    if d then byDay[d] = byDay[d] or {}; table.insert(byDay[d], L.G_WEEK_ITEM:format(date("%H:%M", g.at), G.What(g))) end
  end
  for _, row in ipairs(pf.week) do
    row.day:SetText(GF.DayText(row.n))
    local items = byDay[row.n]
    row.what:SetShown(items ~= nil); row.add:SetShown(items == nil)
    if items then row.what:SetText(table.concat(items, ";  ")) end
    r:Place(row, 28, 0)
  end
  r:Skip(14)
  r:Place(pf.howHead, 29, 6)
  local host = has and G:Host(f, chosen)
  local how = L.G_HOW_NONE
  if has then how = host == me and L.G_HOW_YOU or L.G_HOW:format(host and ns.Short(host) or L.G_HOST_NONE) end
  pf.how:SetText(how)
  r:Place(pf.how, pf.how:GetStringHeight(), 8)
  pf.rscroll:SetContentHeight(r.y + 8)
end

ns.Pages:Register({ id = "gatherings", label = L.NAV_GATHERINGS, build = build, refresh = refresh,
  title = function() return L.TITLE_GATHERINGS, L.SUB_GATHERINGS end })
