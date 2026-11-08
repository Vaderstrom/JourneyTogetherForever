-- The Dungeon page (U96, the owner's grilling of 8 Nov 2026): one page per dungeon and raid, opened from the Chapter
-- page, the Overview, Journey Admin, the Quests page's Dungeon quests and the Endgame. Left: its picture, our own story
-- (Locales: STORY_<key>; the owner reads them before they ship) with Read more in Lore Forever or Spoken, its bosses
-- with how many Adventurers were there for each, and who cleared it; at the foot Find group, Waypoint (its entrance,
-- Fellowship/Entrances.lua) and the Dungeon Journal. Right: the room for the dungeon quests (U78), Who is ready
-- (U98-U100, Fellowship/Ready.lua) and the quests under three headings in the order you act: 1. Start early, 2. Pick
-- up before you go, 3. Starts inside (an empty one is left out). A click on an Adventurer's row shows the quests with
-- their status. ‹ Back returns to the page it came from, as it was.
local _, ns = ...
local L = ns.L
local UI, Theme = ns.UI, ns.Theme
local OA = ns.OtherAddons
local DP = {}
ns.DungeonPage = DP

local PIC_H, FOOT_H, READY_H = 150, 34, 36
-- The headings: the kind, its words, its picture (an hourglass of the game's, a scroll, the map's dungeon door).
DP.GROUPS = {
  { "earlier", "DQ_EARLIER_HEAD", "|TInterface\\Icons\\INV_Misc_PocketWatch_01:16:16|t" },
  { "pick", "DQ_PICK_HEAD", "|TInterface\\Icons\\INV_Scroll_03:16:16|t" },
  { "inside", "DQ_INSIDE_HEAD", "|A:Dungeon:16:16|a" },
}
local READY_TEX = "Interface\\RaidFrame\\ReadyCheck-Ready"

-- Opens the page at a dungeon or raid; Back returns to the page shown before (kept as it was).
function DP:Open(key)
  local W = ns.Window
  -- (Journey Admin's rows open it too while a fellowship is being founded: there is no page yet.)
  if not ns.Dungeon(key) or not ns.Fellowship:Current() then return end
  local from = W:IsOpen() and W.current or nil
  if from and from ~= "dungeon" then W.dungeonBack = from end
  W.dungeon = key
  local pf = W.pageFrames and W.pageFrames.dungeon
  if pf then pf.who = nil; UI.ScrollsToTop(pf) end
  if W:IsOpen() then
    local turned = W.current ~= "dungeon"
    W.page = "dungeon"
    W:Refresh()
    if turned then W:TurnPage() end
  else
    W:Open("dungeon")
  end
end

function DP:Back()
  local W = ns.Window
  W.page = W.dungeonBack or "chapter"
  W:Refresh()
  W:TurnPage()
end

-- Where the dungeon is in the journey: { n (chapter), role, early } from its chapter's list, or nil (a raid, or a
-- dungeon outside the journey).
function DP.Placed(f, key)
  for _, x in ipairs(ns.QuestDungeons.List(f)) do
    if x.key == key then return x end
  end
  return nil
end

function DP.Titles(ctx)
  local key, f = ns.Window.dungeon, ctx.f
  local d = key and ns.Dungeon(key)
  if not d then return L.NAV_QUESTS, "" end
  local raid = ns.Raid(ns.BaseKey(key))
  if raid then return d[2], L.DG_RAID_SUB:format(raid[4], raid[3]) end
  local J = ns.Journey
  local x = f and DP.Placed(f, key)
  local levels = L.CH_LEVELS:format(d[3], d[4])
  if not x then return d[2], levels end
  local role = x.role == "b" and L.ROLE_BRIDGE or (x.role == "o" and L.ROLE_OPTIONAL or L.ROLE_MANDATORY)
  local color = (J.ROLE_COLOR[x.role] or J.ROLE_COLOR.m)[1]
  local sub = ("|cff%s%s|r  ·  %s  ·  %s"):format(Theme:HexFor(color), role, L.CHAPTER_ROMAN:format(J.Roman(x.n)), levels)
  -- Its share of the room for the dungeon quests (U78): its quests and mobs in levels, for you (the review of 8 Nov
  -- 2026: it went with the old Dungeons tab's title).
  local me = ns.Self()
  local sh = ns.Room:Share(f, key, me)
  local lv = ns.Room:Levels(f, me, sh.quests + (sh.mobs or 0))
  if lv and lv >= 0.05 then sub = sub .. "  ·  " .. L.ROOM_SHARE:format(ns.Room.One(lv)) end
  return d[2], sub
end

local function questCard(R, width)
  local p = CreateFrame("Frame", nil, R)
  p:SetWidth(width)
  p.title = UI.WrapText(p, 13, "ink", width - 30, "title")
  p.title:SetPoint("TOPLEFT")
  p.where = UI.WrapText(p, 11, "ink2", width - 30)
  p.status = UI.WrapText(p, 11, "ink2", width - 30)
  p.steps = UI.WrapText(p, 11, "ink2", width - 30)
  p.pin = UI.RoundButton(p, 22, "quests", function() if p.id then ns.QuestLists:Pin(p.id) end end)
  p.pin:SetPoint("TOPRIGHT")
  UI.Tooltip(p.pin, function()
    return ns.Quests:QuestieState() == "on" and L.DQ_PIN_TIP_QUESTIE or L.DQ_PIN_TIP
  end)
  return p
end

local function readyRow(pf, R, width)
  local W = ns.Window
  local r = CreateFrame("Button", nil, R)
  r:SetSize(width, READY_H)
  r.sel = r:CreateTexture(nil, "BACKGROUND", nil, 1)
  r.sel:SetAllPoints(); r.sel:SetColorTexture(0.72, 0.53, 0.18, 0.22)
  local hl = r:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints(); hl:SetColorTexture(1, 0.9, 0.6, 0.12)
  r.ring = UI.DotRing(r, 22, 12, 3)
  r.ring:SetPoint("LEFT", 8, 0)
  r.check = r:CreateTexture(nil, "OVERLAY")
  r.check:SetSize(13, 13); r.check:SetPoint("CENTER", r.ring); r.check:SetTexture(READY_TEX)
  r.line = UI.Text(r, 12, "ink")
  r.line:SetPoint("TOPLEFT", 40, -4); r.line:SetWordWrap(false)
  r.sub = UI.Text(r, 11, "ink2")
  r.sub:SetPoint("TOPLEFT", r.line, "BOTTOMLEFT", 0, -2); r.sub:SetWordWrap(false)
  r.remind = UI.TextButton(r, L.REMIND, function()
    if r.name and DP.key then ns.Ready:Remind(r.name, DP.key); W:Refresh() end
  end, "plain", 11)
  r.remind:SetPoint("RIGHT", -2, 0)
  UI.Tooltip(r.remind, L.REMIND_TIP)
  r:SetScript("OnClick", function() pf.who = r.name ~= ns.Me() and r.name or nil; W:Refresh() end)
  return r
end

local function build(pf)
  local W = ns.Window
  local width = W.PAGE_W - 8
  -- Left page: Back, then what the dungeon is; the three buttons at the foot.
  pf.back = UI.TextButton(pf.left, L.DG_BACK, function() DP:Back() end, "link", 13)
  pf.back:SetPoint("TOPLEFT")
  pf.lscroll = UI.Scroll(pf.left)
  pf.lscroll:SetPoint("TOPLEFT", 0, -26); pf.lscroll:SetPoint("BOTTOMRIGHT", 0, FOOT_H + 6)
  local Lc = pf.lscroll.child
  pf.pic = CreateFrame("Frame", nil, Lc)
  pf.pic:SetSize(width, PIC_H)
  pf.pic.tex = pf.pic:CreateTexture(nil, "ARTWORK")
  UI.FramePicture(pf.pic, pf.pic.tex)
  pf.story = UI.WrapText(Lc, 13, "ink", width, "book")
  pf.more = UI.TextButton(Lc, "", function() if DP.key then OA:Lore(DP.key) end end, "link", 12)
  pf.bossHead = UI.SectionHeader(Lc, width)
  pf.bossHead:SetText(L.DG_BOSSES)
  pf.bosses = UI.Pool(function()
    local b = CreateFrame("Frame", nil, Lc)
    b:SetSize(width, 18)
    b.mark = UI.Mark(b, 12)
    b.mark:SetPoint("LEFT", 2, 0)
    b.name = UI.Text(b, 12, "ink")
    b.name:SetPoint("LEFT", 20, 0); b.name:SetWidth(width - 110); b.name:SetWordWrap(false)
    b.n = UI.Text(b, 11, "ink2", "body", "RIGHT")
    b.n:SetPoint("RIGHT", -2, 0)
    return b
  end)
  pf.bossNone = UI.WrapText(Lc, 12, "ink2", width)
  pf.bossNone:SetText(L.DG_BOSSES_NONE)
  pf.clearHead = UI.SectionHeader(Lc, width)
  pf.clearHead:SetText(L.DG_CLEARED)
  pf.cleared = UI.WrapText(Lc, 12, "ink2", width)
  pf.group = UI.TextButton(pf.left, L.FIND_GROUP, function()
    local f, key = ns.Fellowship:Current(), DP.key
    if not (f and key) then return end
    if ns.Raid(ns.BaseKey(key)) then ns.Endgame:FindGroup(f, key) else ns.Together:FindGroup(f, key) end
  end, "primary", 12)
  pf.group:SetPoint("BOTTOMLEFT", 0, 2)
  pf.way = UI.TextButton(pf.left, L.DG_WAYPOINT, function()
    local f = ns.Fellowship:Current()
    if f and DP.key then ns.Entrances:Waypoint(f, DP.key) end
  end, "plain", 12)
  UI.Tooltip(pf.way, function() return pf.wayTip end)
  pf.dj = UI.TextButton(pf.left, L.DUNGEON_JOURNAL, function() if DP.key then W:DungeonJournal(DP.key) end end, "plain", 12)

  -- Right page: the room, who is ready, the quests.
  pf.rscroll = UI.Scroll(pf.right)
  pf.rscroll:SetAllPoints()
  local R = pf.rscroll.child
  ns.QuestDungeons.BuildRoom(pf, R, width)
  pf.readyHead = UI.SectionHeader(R, width)
  pf.readyHead:SetText(L.RD_HEAD)
  pf.readyRows = UI.Pool(function() return readyRow(pf, R, width) end)
  pf.whoNote = UI.WrapText(R, 11, "ink2", width)
  pf.secs = {}
  for i = 1, #DP.GROUPS do pf.secs[i] = UI.SectionHeader(R, width) end
  pf.quests = UI.Pool(function() return questCard(R, width) end)
  pf.none = UI.SketchLine(R, width, "EmptySince")
end

-- Left page: picture, story, bosses, who cleared it, and the foot.
local function refreshLeft(pf, f, key, ctx)
  local J, Cl = ns.Journey, ns.Clears
  local width = ns.Window.PAGE_W - 8
  local s = UI.Stack(pf.lscroll.child)
  local ok, default = ns.SetDungeonArt(pf.pic.tex, key, width - 2 * UI.PIC_INSET, PIC_H - 2 * UI.PIC_INSET)
  if default or not ok then
    ns.Pages:SetChapterArt(pf.pic.tex, (DP.Placed(f, key) or {}).n or 1, width - 2 * UI.PIC_INSET, PIC_H - 2 * UI.PIC_INSET, 0.5)
  end
  s:Place(pf.pic, PIC_H, 10)
  local story = rawget(L, "STORY_" .. ns.BaseKey(key):upper()) -- (L gives back the key for a missing text)
  pf.story:SetShown(story ~= nil)
  if story then
    pf.story:SetText(story)
    s:Place(pf.story, pf.story:GetStringHeight(), 4)
  end
  local from = OA:StoryFrom(key)
  pf.more:SetLabel(from == "spoken" and L.DG_MORE_SPOKEN or (from == "lore" and L.DG_MORE_LORE or L.DG_MORE_NONE))
  s:Place(pf.more, pf.more:GetHeight(), 8)
  -- The bosses, each with how many Adventurers counted for the journey were there for it.
  s:Place(pf.bossHead, 29, 4)
  local counted = J:Counted(f)
  local bosses = Cl:Bosses(key)
  for i, b in ipairs(bosses) do
    local row = pf.bosses:Get(i)
    if not row then break end
    local n = 0
    for _, name in ipairs(counted) do if Cl:Killed(f, key, name)[b.tok] then n = n + 1 end end
    row.mark:SetMark(n > 0 and "done" or nil)
    row.name:SetText(b.name)
    row.name:SetTextColor(Theme:RGBA(n > 0 and "ink" or "ink2"))
    row.n:SetText(n > 0 and L.DG_BOSS_KILLS:format(n, #counted) or L.DQ_NOT_YET)
    s:Place(row, 18, 2)
  end
  pf.bosses:HideFrom(#bosses + 1)
  pf.bossNone:SetShown(#bosses == 0)
  if #bosses == 0 then s:Place(pf.bossNone, pf.bossNone:GetStringHeight(), 2) end
  s:Skip(8)
  s:Place(pf.clearHead, 29, 4)
  local who = {}
  for name in pairs(J:ClearedBy(f, key)) do who[#who + 1] = name end
  table.sort(who)
  pf.cleared:SetText(#who > 0 and J.Names(f, who) or L.DG_CLEARED_NONE)
  s:Place(pf.cleared, pf.cleared:GetStringHeight(), 6)
  pf.lscroll:SetContentHeight(s.y + 8)
  -- The foot: Find group (not while watching), Waypoint (only where the entrance is known), the Dungeon Journal.
  pf.group:SetShown(not ctx.watching)
  local e = ns.Entrances:Get(f, key)
  pf.way:SetEnabled(e ~= nil)
  pf.wayTip = e and (e.learned and L.DG_WAY_LEARNED or L.DG_WAY_TIP) or L.DG_WAY_NONE
  pf.way:ClearAllPoints()
  if pf.group:IsShown() then pf.way:SetPoint("LEFT", pf.group, "RIGHT", 6, 0) else pf.way:SetPoint("BOTTOMLEFT", 0, 2) end
  pf.dj:ClearAllPoints(); pf.dj:SetPoint("LEFT", pf.way, "RIGHT", 6, 0)
end

-- Who is ready: one row per Adventurer counted for the chapter, you first.
local function refreshReady(pf, f, key, ctx, r)
  local Rd, Hr = ns.Ready, ns.Hero
  local width = ns.Window.PAGE_W - 8
  local rows = Rd:Rows(f, key)
  local any = false
  for _, x in ipairs(rows) do if x.r then any = true end end
  pf.readyHead:SetShown(any)
  if not any then pf.readyRows:HideFrom(1) return end
  r:Skip(6)
  r:Place(pf.readyHead, 29, 4)
  for i, x in ipairs(rows) do
    local row = pf.readyRows:Get(i)
    if not row then break end
    row.name = x.name
    local share = Rd.Share(x.r)
    local ready = x.r and x.r.ready
    row.ring:Set(share, ready and "gold" or "B8742A")
    row.check:SetShown(ready == true)
    row.line:SetText(Rd.Line(x.name, x.r))
    local subs = {}
    if not x.online then subs[1] = L.RD_AS_OF:format(ns.TimeAgo(Hr:LastSeen(f, x.name))) end
    local rem = Rd:Reminded(f, x.name, key)
    if rem then subs[#subs + 1] = L.RD_REMINDED:format(ns.Short(rem.by)) end
    row.sub:SetText(table.concat(subs, "  ·  "))
    row.sub:SetShown(#subs > 0)
    local why = Rd:CanRemind(f, x.name, key)
    row.remind:SetShown(not ctx.watching and (why == nil or why == "off"))
    local textW = width - 40 - (row.remind:IsShown() and row.remind:GetWidth() + 8 or 4)
    row.line:SetWidth(textW); row.sub:SetWidth(textW)
    row.sel:SetShown(x.name == (pf.who or ns.Me()))
    r:Place(row, READY_H, 2)
  end
  pf.readyRows:HideFrom(#rows + 1)
end

-- The quests under their headings, with the chosen Adventurer's status.
local function refreshQuests(pf, f, key, r)
  local QL = ns.QuestLists
  local me = ns.Me()
  local who = pf.who and f.members[pf.who] and pf.who or me
  local g = QL:Groups(f, key, who)
  pf.whoNote:SetShown(g ~= nil and who ~= me)
  if g and who ~= me then
    pf.whoNote:SetText(L.RD_SHOWING:format(ns.Short(who)))
    r:Place(pf.whoNote, pf.whoNote:GetStringHeight(), 4)
  end
  pf.none:SetShown(g == nil)
  if not g then
    local raid = ns.Raid(ns.BaseKey(key))
    pf.none:SetText(raid and L.DG_RAID_NONE or (ns.DUNGEON_QUESTS[ns.BaseKey(key)] and L.DQ_OTHER_SIDE_LONG or L.DQ_NO_LIST_LONG))
    r:Skip(6)
    r:Place(pf.none, pf.none.h, 8)
  end
  local nq, shown = 0, 0
  for i, grp in ipairs(DP.GROUPS) do
    local quests = g and g[grp[1]] or {}
    pf.secs[i]:SetShown(#quests > 0)
    if #quests > 0 then
      shown = shown + 1
      pf.secs[i]:SetText(("%s  %d. %s"):format(grp[3], shown, L[grp[2]]))
      r:Skip(4)
      r:Place(pf.secs[i], 29, 4)
    end
    for _, q in ipairs(quests) do
      local p = pf.quests:Get(nq + 1)
      if not p then break end
      nq = nq + 1
      p.id = q.id
      p.title:SetText(q.name)
      p.where:SetText(QL.WhereText(q.start))
      local parts = {}
      if q.start.lvl then parts[1] = L.DQ_LEVEL:format(q.start.lvl) end
      parts[#parts + 1] = QL.StatusText(q.status, who ~= me and q.status == "log" and L.DQ_IN_LOG_OF:format(ns.Short(who)) or nil)
      if #q.others > 0 then
        local names = {}
        for _, n in ipairs(q.others) do names[#names + 1] = n == me and L.YOU_LABEL or ns.Short(n) end
        parts[#parts + 1] = L.DQ_ALSO:format(table.concat(names, ", "))
      end
      p.status:SetText(table.concat(parts, "  ·  "))
      local steps = {}
      for k, x in ipairs(q.steps or {}) do
        local line = x.lvl and L.DQ_STEP_LVL:format(k, x.name, x.lvl) or L.DQ_STEP:format(k, x.name)
        local s = x.start
        if s.by or s.item or s.zone or s.inside then line = line .. "  ·  " .. QL.WhereText(s) end
        steps[k] = line .. "  ·  " .. QL.StatusText(x.status, who ~= me and x.status == "log" and L.DQ_IN_LOG_OF:format(ns.Short(who)) or nil)
      end
      p.steps:SetText(table.concat(steps, "\n"))
      p.steps:SetShown(#steps > 0)
      p.pin:SetShown(QL:CanPin(q.start))
      p.where:ClearAllPoints(); p.where:SetPoint("TOPLEFT", p.title, "BOTTOMLEFT", 0, -2)
      p.status:ClearAllPoints(); p.status:SetPoint("TOPLEFT", p.where, "BOTTOMLEFT", 0, -2)
      p.steps:ClearAllPoints(); p.steps:SetPoint("TOPLEFT", p.status, "BOTTOMLEFT", 0, -3)
      local h = p.title:GetStringHeight() + p.where:GetStringHeight() + p.status:GetStringHeight() + 6
        + (#steps > 0 and p.steps:GetStringHeight() + 3 or 0)
      h = math.max(h, 24)
      p:SetHeight(h)
      r:Place(p, h, 8)
    end
  end
  pf.quests:HideFrom(nq + 1)
end

local function refresh(pf, ctx)
  local f, key = ctx.f, ns.Window.dungeon
  if not f or not key or not ns.Dungeon(key) then return end
  DP.key = key
  if pf.who and not f.members[pf.who] then pf.who = nil end
  refreshLeft(pf, f, key, ctx)
  local r = UI.Stack(pf.rscroll.child)
  ns.QuestDungeons.RefreshRoom(pf, f, ctx.me, r)
  refreshReady(pf, f, key, ctx, r)
  refreshQuests(pf, f, key, r)
  pf.rscroll:SetContentHeight(r.y + 8)
end

-- On the flat sheet (the owner, 8 Nov 2026): its title runs across both halves, so one paper with no spine, as
-- Journey Admin and Settings.
ns.Pages:Register({ id = "dungeon", label = L.NAV_QUESTS, icon = "quests", free = true, header = "both", flat = true,
  -- In the sidebar as the page it was opened from.
  parent = function() return ns.Window.dungeonBack end,
  build = build, refresh = refresh, news = { quests = true },
  title = function(ctx) return DP.Titles(ctx) end })
