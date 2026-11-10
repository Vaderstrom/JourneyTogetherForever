-- The Dungeon page (U96, the owner's grilling of 8 Nov 2026; since U141 the only home of a dungeon's preparation): one
-- page per dungeon and raid, opened from the Chapter page's To do, the Overview, Journey Admin and the Raids page.
-- Left: its picture, our own story (Locales: STORY_<key>; the owner reads them before they ship) with Read more in
-- Lore Forever or Spoken, its bosses with how many Adventurers were there for each, and who cleared it; at the foot
-- Find group (Waypoint and the Dungeon Journal went on 10 Nov 2026: each quest's pin is the waypoint). Right: the room for its quests
-- as the answer (U78, U145) with Count the mobs' XP and Show everyone, Who is ready folded to a row of rings (U126;
-- U98-U100, Fellowship/Ready.lua) and the quests under three headings in the order you act: 1. Prequest chains, 2. Pick up
-- before you go, 3. Starts inside (an empty one is left out), each line starting with its status (U125), a long chain
-- folded to its next step (U127). A later dungeon (U137, U138) says when it comes instead of the room and Who is
-- ready. A click on an Adventurer's row shows the quests with their status. ‹ Back returns to the page it came from.
local _, ns = ...
local L = ns.L
local UI, Theme = ns.UI, ns.Theme
local OA = ns.OtherAddons
local DP = {}
ns.DungeonPage = DP

local PIC_H, FOOT_H, READY_H, RING = 150, 34, 36, 22
local STEPS_SHOWN = 5 -- a chain with more steps shows only its next one until opened (U127)
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

-- Every dungeon of the journey once, in its order (a bridge shown early stays in its own chapter): { key, d, n, role }.
function DP.List(f)
  local J, list, seen = ns.Journey, {}, {}
  for n = 1, #f.journey.chapters do
    for _, x in ipairs(J:ChapterList(f, n)) do
      if not x.early and not seen[x.key] then
        seen[x.key] = true
        list[#list + 1] = { key = x.key, d = x.d, n = n, role = x.role }
      end
    end
  end
  return list
end

-- Where the dungeon is in the journey: { key, d, n (chapter), role }, or nil (a raid, or a dungeon outside it).
function DP.Placed(f, key)
  for _, x in ipairs(DP.List(f)) do
    if x.key == key then return x end
  end
  return nil
end

-- A later dungeon (U137): of a chapter after yours, and not one of the next chapter's you may run now.
function DP.Later(f, x)
  local J = ns.Journey
  local cur = J:CurrentIndex(f)
  if not x or x.n <= cur then return false end
  for _, b in ipairs(J:EarlyBridges(f, cur)) do if b.key == x.key then return false end end
  return true
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
  -- (A dungeon of the next chapter is mandatory in its own: "From the next chapter" is said only from the chapter before.)
  local role = x.role == "o" and L.ROLE_OPTIONAL or L.ROLE_MANDATORY
  local color = J.ROLE_COLOR[x.role == "o" and "o" or "m"][1]
  local head = ("|cff%s%s|r  ·  %s"):format(Theme:HexFor(color), role, L.CHAPTER_ROMAN:format(J.Roman(x.n)))
  -- (A chapter the rule hides: not its levels, as on the Dungeons page; the release review of 10 Nov 2026.)
  if x.n > J:MaxView(f, ctx.me or ns.Me()) then return d[2], head end
  return d[2], head .. "  ·  " .. levels
end

local function questCard(pf, R, width)
  local p = CreateFrame("Frame", nil, R)
  p:SetWidth(width)
  -- Its status first (U125): done, in your log, not yet.
  p.icon = p:CreateTexture(nil, "ARTWORK")
  p.icon:SetSize(14, 14); p.icon:SetPoint("TOPLEFT", 0, -1)
  p.title = UI.WrapText(p, 13, "ink", width - 50, "title")
  p.title:SetPoint("TOPLEFT", 20, 0)
  p.more = UI.TextButton(p, "", function()
    pf.openSteps[p.id] = not pf.openSteps[p.id] or nil
    ns.Window:Refresh()
  end, "link", 11)
  -- Where it starts, its level and status on one line (U160: they were two).
  p.where = UI.WrapText(p, 11, "ink2", width - 30)
  p.steps = UI.WrapText(p, 11, "ink2", width - 30)
  p.pin = UI.RoundButton(p, 22, "quests", function() if p.st then ns.QuestLists:Pin(p.st) end end)
  p.pin:SetPoint("TOPRIGHT")
  -- The spot's numbers only here (U160: they filled the page's lines).
  UI.Tooltip(p.pin, function()
    return p.spot and L.DQ_PIN_TIP_AT:format(p.spot) or L.DQ_PIN_TIP_QUESTIE
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
  -- Left page: Back, then what the dungeon is; Find group at the foot.
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

  -- Right page: the room for its quests (or when a later dungeon comes), who is ready, the quests.
  pf.rscroll = UI.Scroll(pf.right)
  pf.rscroll:SetAllPoints()
  local R = pf.rscroll.child
  pf.later = UI.WrapText(R, 14, "ink", width, "book")
  pf.room = CreateFrame("Frame", nil, R)
  pf.room:SetSize(width, 20)
  pf.room.text = UI.WrapText(pf.room, 14, "ink", width, "title")
  pf.room.text:SetPoint("TOPLEFT")
  UI.Tooltip(pf.room, function() return pf.room.tip end)
  pf.roomAll = UI.LabeledCheck(R, width, L.ROOM_EVERYONE, L.ROOM_EVERYONE_TIP,
    function() return pf.everyone end, function(v) pf.everyone = v; W:Refresh() end)
  pf.roomHeroes = UI.WrapText(R, 12, "ink2", width)
  pf.readyHead = UI.SectionHeader(R, width)
  pf.readyHead:SetText(L.RD_HEAD)
  -- Folded (U126): a ring for each Adventurer, you first, "2 of 4 ready" and Show who.
  pf.rings = CreateFrame("Frame", nil, R)
  pf.rings:SetSize(width, RING + 4)
  -- Made out of combat like every row (UI.Pool; the review of 9 Nov 2026).
  pf.rings.pool = UI.Pool(function(i)
    local g = UI.DotRing(pf.rings, RING, 12, 3)
    g.check = g:CreateTexture(nil, "OVERLAY")
    g.check:SetSize(12, 12); g.check:SetPoint("CENTER"); g.check:SetTexture(READY_TEX)
    g:SetPoint("LEFT", (i - 1) * (RING + 6), 0)
    UI.Tooltip(g, function() return g.tip end)
    return g
  end)
  pf.rings.items = pf.rings.pool.items
  pf.rings.n = UI.Text(pf.rings, 12, "ink", "body")
  pf.showWho = UI.TextButton(pf.rings, "", function() pf.whoOpen = not pf.whoOpen; W:Refresh() end, "link", 12)
  pf.showWho:SetPoint("RIGHT", -2, 0)
  pf.readyRows = UI.Pool(function() return readyRow(pf, R, width) end)
  pf.whoNote = UI.WrapText(R, 11, "ink2", width)
  pf.secs = {}
  for i = 1, #DP.GROUPS do pf.secs[i] = UI.SectionHeader(R, width) end
  pf.openSteps = {}
  pf.quests = UI.Pool(function() return questCard(pf, R, width) end)
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
  local kills, any = {}, false
  for i, b in ipairs(bosses) do
    local n = 0
    for _, name in ipairs(counted) do if Cl:Killed(f, key, name)[b.tok] then n = n + 1 end end
    kills[i], any = n, any or n > 0
  end
  for i, b in ipairs(bosses) do
    local row = pf.bosses:Get(i)
    if not row then break end
    local n = kills[i]
    row.mark:SetMark(n > 0 and "done" or nil)
    row.name:SetText(b.name)
    row.name:SetTextColor(Theme:RGBA(n > 0 and "ink" or "ink2"))
    -- U161: "Not yet" only beside bosses still standing once some fell; before any, Who cleared it says so once.
    row.n:SetText(n > 0 and L.DG_BOSS_KILLS:format(n, #counted) or (any and L.DQ_NOT_YET or ""))
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
  -- The foot: Find group (not while watching, nor for a later dungeon).
  pf.group:SetShown(not ctx.watching and not DP.Later(f, DP.Placed(f, key)))
end

-- The room for its quests as the answer (U145; the figures on hover), for a dungeon of your chapter; Show everyone
-- (each other Adventurer's line, away ones left out).
local function refreshRoom(pf, f, me, r, ours)
  local Room = ns.Room
  local mine = ours and Room:Chapter(f, me) or nil
  local others = {}
  if ours and pf.everyone then
    for _, n in ipairs(ns.Fellowship:Members(f)) do
      local x = n ~= me and not ns.Journey:Away(f, n) and Room:Chapter(f, n)
      if x then
        others[#others + 1] = x.stop and L.ROOM_HERO_STOP:format(ns.Short(n), Room.One(x.to), Room.StopAt(x.stop))
          or L.ROOM_HERO:format(ns.Short(n), Room.One(x.to))
      end
    end
  end
  local show = mine ~= nil or (ours and pf.everyone)
  -- (No heading: the answer is the heading, GLOSSARY "Stop questing".)
  pf.roomAll:SetShown(show)
  pf.room:SetShown(show and mine ~= nil)
  pf.roomHeroes:SetShown(show and #others > 0)
  if not show then return end
  if mine then
    local text, color, tip = Room.Answer(mine)
    -- With room to spare, this dungeon's quests fit: said so (its own figures are in the tooltip with the chapter's).
    if not mine.stop and mine.now < mine.stopAt then text = L.DG_ROOM_HAVE end
    pf.room.text:SetText(text)
    pf.room.text:SetTextColor(Theme:RGBA(color))
    pf.room.tip = tip
    local h = pf.room.text:GetStringHeight()
    pf.room:SetHeight(h)
    r:Place(pf.room, h, 6)
  end
  pf.roomAll:Refresh()
  r:Place(pf.roomAll, 24, 4)
  if #others > 0 then
    pf.roomHeroes:SetText(table.concat(others, "\n"))
    r:Place(pf.roomHeroes, pf.roomHeroes:GetStringHeight(), 6)
  end
end

-- Who is ready (U126): folded, one ring per Adventurer counted for the chapter (you first), "2 of 4 ready" and Show
-- who; opened, one row each with Remind.
local function refreshReady(pf, f, key, ctx, r)
  local Rd, Hr = ns.Ready, ns.Hero
  local width = ns.Window.PAGE_W - 8
  local rows = Rd:Rows(f, key)
  local any, ready = false, 0
  for _, x in ipairs(rows) do
    if x.r then any = true end
    if x.r and x.r.ready then ready = ready + 1 end
  end
  pf.readyHead:SetShown(any); pf.rings:SetShown(any)
  if not any then pf.readyRows:HideFrom(1) return end
  r:Skip(6)
  r:Place(pf.readyHead, 29, 4)
  local made = 0
  for i, x in ipairs(rows) do
    local g = pf.rings.pool:Get(i)
    if not g then break end
    made = i
    local ok = x.r and x.r.ready
    g:Set(Rd.Share(x.r), ok and "gold" or "B8742A")
    g.check:SetShown(ok == true)
    g.tip = Rd.Line(x.name, x.r)
    g:Show()
  end
  pf.rings.pool:HideFrom(made + 1)
  pf.rings.n:ClearAllPoints(); pf.rings.n:SetPoint("LEFT", made * (RING + 6) + 4, 0)
  pf.rings.n:SetText(L.DQ_READY_N:format(ready, #rows))
  pf.showWho:SetLabel(UI.FoldLabel(pf.whoOpen and L.RD_HIDE_WHO or L.RD_SHOW_WHO, pf.whoOpen))
  r:Place(pf.rings, RING + 4, 4)
  local shown = 0
  for i, x in ipairs(pf.whoOpen and rows or {}) do
    local row = pf.readyRows:Get(i)
    if not row then break end
    shown = i
    row.name = x.name
    local ok = x.r and x.r.ready
    row.ring:Set(Rd.Share(x.r), ok and "gold" or "B8742A")
    row.check:SetShown(ok == true)
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
  pf.readyRows:HideFrom(shown + 1)
end

-- A theme colour as hex, for a colour code inside a line of text.
local function hexOf(role)
  local r, g, b = Theme:RGBA(role)
  return ("%02X%02X%02X"):format(r * 255, g * 255, b * 255)
end

-- A step of a chain in one line: its number, name and level, where it starts; done grey, the next gold (U125).
local function stepLine(QL, k, x, nextK)
  local line = x.lvl and L.DQ_STEP_LVL:format(k, x.name, x.lvl) or L.DQ_STEP:format(k, x.name)
  local s = x.start
  if s.by or s.item or s.zone or s.inside then line = line .. "  ·  " .. QL.WhereText(s) end
  local color = k == nextK and x.status ~= "done" and Theme:HexFor("B8742A") or hexOf(x.status == "done" and "ink2" or "ink")
  return ("|T%s:12:12|t |cff%s%s|r"):format((QL.STATUS[x.status] or QL.STATUS.no)[1], color, line)
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
      p.icon:SetTexture((QL.STATUS[q.status] or QL.STATUS.no)[1])
      p.title:SetText(q.name)
      local st = q.start
      local parts = { QL.WhereText(st) }
      if st.lvl then parts[#parts + 1] = L.DQ_LEVEL:format(st.lvl) end
      parts[#parts + 1] = QL.StatusText(q.status, who ~= me and q.status == "log" and L.DQ_IN_LOG_OF:format(ns.Short(who)) or nil)
      if #q.others > 0 then
        local names = {}
        for _, n in ipairs(q.others) do names[#names + 1] = n == me and L.YOU_LABEL or ns.Short(n) end
        parts[#parts + 1] = L.DQ_ALSO:format(table.concat(names, ", "))
      end
      p.where:SetText(table.concat(parts, "  ·  "))
      -- The chain's steps (U123); more than five fold to the next one (U127).
      local all = q.steps or {}
      local nextK
      for k, x in ipairs(all) do if not nextK and x.status ~= "done" then nextK = k end end
      local fold = #all > STEPS_SHOWN and not pf.openSteps[q.id]
      local steps = {}
      if fold then
        local x = nextK and all[nextK]
        steps[1] = x and L.DG_STEP_OF:format(nextK, #all, x.name .. ((x.start.by or x.start.zone) and (", " .. QL.WhereText(x.start)) or ""))
          or L.DG_STEPS_DONE:format(#all)
      else
        for k, x in ipairs(all) do steps[k] = stepLine(QL, k, x, nextK) end
      end
      p.steps:SetText(table.concat(steps, "\n"))
      p.steps:SetShown(#steps > 0)
      p.more:SetShown(#all > STEPS_SHOWN)
      p.more:SetLabel(UI.FoldLabel(fold and L.DG_SHOW_STEPS:format(#all) or L.DG_HIDE_STEPS, not fold))
      -- The pin: where you pick up first, a chain's next step where its spot is known, else the quest's own giver
      -- (the owner, 10 Nov 2026: "Waypoint to where you pickup quests").
      local nx = nextK and all[nextK]
      p.st = nx and nx.start.x and nx.start.y and nx.start or st
      p.spot = p.st.zone and p.st.x and L.DQ_AT:format(p.st.zone, p.st.x, p.st.y) or nil
      p.pin:SetShown(QL:CanPin(p.st))
      p.where:ClearAllPoints(); p.where:SetPoint("TOPLEFT", p.title, "BOTTOMLEFT", 0, -2)
      p.steps:ClearAllPoints(); p.steps:SetPoint("TOPLEFT", p.where, "BOTTOMLEFT", 0, -3)
      p.more:ClearAllPoints(); p.more:SetPoint("TOPLEFT", p.steps, "BOTTOMLEFT", -4, 0)
      local h = p.title:GetStringHeight() + p.where:GetStringHeight() + 4
        + (#steps > 0 and p.steps:GetStringHeight() + 3 or 0) + (p.more:IsShown() and 18 or 0)
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
  local x = DP.Placed(f, key)
  local later = DP.Later(f, x)
  -- A later dungeon (U137, U138): when it comes, and how many of its quests open now (they are in the To do).
  pf.later:SetShown(later)
  if later then
    local open = 0
    for _, e in ipairs(ns.QuestLists:Later(f, ns.Journey:CurrentIndex(f))) do
      if ns.BaseKey(e.x.key) == ns.BaseKey(key) then open = e.open end
    end
    local text = L.DG_LATER:format(ns.Journey.Roman(x.n))
    if open > 0 then text = text .. "\n" .. (open == 1 and L.DG_LATER_OPEN_1 or L.DG_LATER_OPEN_N:format(open)) end
    pf.later:SetText(text)
    r:Place(pf.later, pf.later:GetStringHeight(), 8)
  end
  refreshRoom(pf, f, ctx.me, r, x ~= nil and x.n == ns.Journey:CurrentIndex(f))
  if later then pf.readyHead:Hide(); pf.rings:Hide(); pf.readyRows:HideFrom(1)
  else refreshReady(pf, f, key, ctx, r) end
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
