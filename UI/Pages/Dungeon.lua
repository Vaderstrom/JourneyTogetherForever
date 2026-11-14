-- The Dungeon page (U96, the owner's grilling of 8 Nov 2026; since U141 the only home of a dungeon's preparation): one
-- page per dungeon and raid, opened from the Chapter page's To do, the Overview, Journey Admin and the Raids page.
-- Left: its picture, our own story (Locales: STORY_<key>; the owner reads them before they ship) with Read more in
-- Lore Forever or Spoken, its bosses with how many Adventurers were there for each, and who cleared it; at the foot
-- Find group and Waypoint (to its entrance, from our data: the owner, 10 Nov 2026; raids have none). Right: the room for its quests
-- as the answer (U78, U145) with Count the mobs' XP and Show everyone, Who is ready folded to a row of rings (U126;
-- U98-U100, Fellowship/Ready.lua) and the quests under three headings in the order you act: 1. Prequest chains, 2. Pick up
-- before you go, 3. Starts inside (an empty one is left out), each a short row: its status (U125), level and how far
-- along its chain; where it starts and the steps on a click (U185). A later dungeon (U137, U138) says when it comes instead of the room and Who is
-- ready. A click on an Adventurer's row shows the quests with their status. ‹ Back returns to the page it came from.
local _, ns = ...
local L = ns.L
local UI, Theme = ns.UI, ns.Theme
local OA = ns.OtherAddons
local DP = {}
ns.DungeonPage = DP

local PIC_H, FOOT_H, READY_H, RING = 150, 34, 36, 22
-- Its entrance, from our data (the owner, 10 Nov 2026: "if we have a waypoint to the quests, let's have a waypoint to the
-- dungeons"), as a quest start for the pin; nil for a raid.
function DP.Entrance(key)
  local e, d = ns.DUNGEON_ENTRANCES[ns.BaseKey(key)], ns.Dungeon(key)
  return e and { by = d and d[2] or key, zone = e.zone, map = e.map, x = e.x, y = e.y } or nil
end
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
  if pf then pf.who = nil; pf.opened = {}; UI.ScrollsToTop(pf) end -- (its rows folded each time, U185)
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
  -- Where it starts and the steps open on a click on the row (U185; the check of 12 Nov 2026: a link under each row
  -- made it three lines), what opens in its tooltip.
  local p = CreateFrame("Button", nil, R)
  p:SetWidth(width)
  p:SetScript("OnClick", function()
    pf.opened[p.id] = not pf.opened[p.id] or nil
    if GameTooltip:IsOwned(p) then GameTooltip:Hide() end -- (it said what the click did)
    ns.Window:Refresh()
  end)
  UI.Tooltip(p, function() return p.tip end)
  local hl = p:CreateTexture(nil, "HIGHLIGHT")
  hl:SetPoint("TOPLEFT", -4, 3); hl:SetPoint("BOTTOMRIGHT", 4, -3); hl:SetColorTexture(1, 0.9, 0.6, 0.12)
  -- Its status first (U125): done, in your log, not yet.
  p.icon = p:CreateTexture(nil, "ARTWORK")
  p.icon:SetSize(14, 14); p.icon:SetPoint("TOPLEFT", 0, -1)
  p.title = UI.WrapText(p, 13, "ink", width - 70, "title")
  p.title:SetPoint("TOPLEFT", 20, 0)
  -- Folded, its status, level and how far; opened, where it starts too (U160: on one line, they were two).
  p.where = UI.WrapText(p, 11, "ink2", width - 30)
  p.steps = UI.WrapText(p, 11, "ink2", width - 30)
  p.pin = UI.RoundButton(p, 22, "quests", function() if p.st then ns.QuestLists:Pin(p.st) end end)
  p.pin:SetPoint("TOPRIGHT")
  p.fold = p:CreateTexture(nil, "ARTWORK")
  p.fold:SetSize(14, 14); p.fold:SetPoint("TOPRIGHT", p.pin, "TOPLEFT", -6, -1)
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
  pf.way = UI.TextButton(pf.left, L.DG_WAYPOINT, function()
    local st = DP.key and DP.Entrance(DP.key)
    if st then ns.QuestLists:Pin(st, L.DG_WAY_ASK) end
  end, "plain", 12)
  UI.Tooltip(pf.way, function() return pf.wayTip end)

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
  pf.pickLine = UI.WrapText(R, 12, "ink", width) -- only quests to pick up are left (U177)
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
  pf.opened = {}
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
  -- Read more where an addon tells more, or the line to install one; none where Spoken runs and has nothing on the
  -- place (The Drowned City said "in Spoken or Lore Forever": the check of 10 Nov 2026, 22:46).
  local from = OA:StoryFrom(key)
  pf.more:SetShown(from ~= nil or not OA:HasSpoken())
  if pf.more:IsShown() then
    pf.more:SetLabel(from == "spoken" and L.DG_MORE_SPOKEN or (from == "lore" and L.DG_MORE_LORE or L.DG_MORE_NONE))
    s:Place(pf.more, pf.more:GetHeight(), 8)
  end
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
  local who = {}
  for name in pairs(J:ClearedBy(f, key)) do if not ns.Fellowship:IsFriend(f, name) then who[#who + 1] = name end end
  -- Who cleared it: not before the dungeon opens (a later chapter's), unless someone has (U184, the owner, 12 Nov
  -- 2026: "It would appear once the dungeon's chapter opens").
  local later = DP.Later(f, DP.Placed(f, key))
  local showWho = #who > 0 or J:Open(f, key)
  pf.clearHead:SetShown(showWho); pf.cleared:SetShown(showWho)
  if showWho then
    s:Place(pf.clearHead, 29, 4)
    table.sort(who)
    pf.cleared:SetText(#who > 0 and J.Names(f, who) or L.DG_CLEARED_NONE)
    s:Place(pf.cleared, pf.cleared:GetStringHeight(), 6)
  end
  pf.lscroll:SetContentHeight(s.y + 8)
  -- The foot: Find group (not while watching, nor for a later dungeon), Waypoint where the entrance is known.
  pf.group:SetShown(not ctx.watching and not later)
  local e = DP.Entrance(key)
  pf.way:SetShown(e ~= nil)
  pf.wayTip = e and L.DG_WAY_TIP:format(L.DQ_AT:format(e.zone, e.x, e.y))
  pf.way:ClearAllPoints()
  if pf.group:IsShown() then pf.way:SetPoint("LEFT", pf.group, "RIGHT", 6, 0) else pf.way:SetPoint("BOTTOMLEFT", 0, 2) end
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
  local ready = Rd.Tally(rows)
  local any = ready ~= nil
  local pick = any and Rd.PickLine(rows) or nil
  pf.readyHead:SetShown(any); pf.rings:SetShown(any); pf.pickLine:SetShown(pick ~= nil)
  if not any then pf.readyRows:HideFrom(1) return end
  r:Skip(6)
  r:Place(pf.readyHead, 29, 4)
  if pick then pf.pickLine:SetText(pick); r:Place(pf.pickLine, pf.pickLine:GetStringHeight(), 6) end
  local made = 0
  for i, x in ipairs(rows) do
    local g = pf.rings.pool:Get(i)
    if not g then break end
    made = i
    local ok = x.r and x.r.ready
    g:Set(Rd.Share(x.r), ok and "gold" or "B8742A")
    g.check:SetShown(ok == true)
    local shares = Rd.Shares(x.r)
    g.tip = Rd.Line(x.name, x.r) .. (shares and "\n" .. shares or "")
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
    local subs = { Rd.Shares(x.r) }
    if not x.online then subs[#subs + 1] = L.RD_AS_OF:format(ns.TimeAgo(Hr:LastSeen(f, x.name))) end
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

-- Its level, with the level it can be taken from: "Level 17" alone read as "not before 17" (the owner, 10 Nov 2026).
-- Not for a quest that starts inside: it is taken in the run (the owner, 12 Nov 2026: "Only chains").
local function levelText(st, inside)
  if not st.lvl then return nil end
  return not inside and st.min and st.min < st.lvl and L.DQ_LEVEL_FROM:format(st.lvl, st.min) or L.DQ_LEVEL:format(st.lvl)
end

-- Your status in words, or the chosen Adventurer's.
local function statusText(QL, q, who, me)
  return QL.StatusText(q.status, who ~= me and q.status == "log" and L.DQ_IN_LOG_OF:format(ns.Short(who)) or nil)
end

-- A quest's line, opened: its status first (the answer; its icon is before the name), where it starts, its level, and
-- who else has it in their log.
local function questLine(QL, q, who, me, inside)
  local parts = { statusText(QL, q, who, me), QL.WhereText(q.start) }
  parts[#parts + 1] = levelText(q.start, inside)
  if #q.others > 0 then
    local names = {}
    for _, n in ipairs(q.others) do names[#names + 1] = n == me and L.YOU_LABEL or ns.Short(n) end
    parts[#parts + 1] = L.DQ_ALSO:format(table.concat(names, ", "))
  end
  return table.concat(parts, "  ·  ")
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
    local inside = grp[1] == "inside"
    for _, q in ipairs(quests) do
      local p = pf.quests:Get(nq + 1)
      if not p then break end
      nq = nq + 1
      p.id = q.id
      p.icon:SetTexture((QL.STATUS[q.status] or QL.STATUS.no)[1])
      local st = q.start
      local all = q.steps or {}
      local nextK
      for k, x in ipairs(all) do if not nextK and x.status ~= "done" then nextK = k end end
      -- (A quest that starts inside has nothing more to open: its heading says where.)
      local canOpen = #all > 0 or not st.inside
      local open = canOpen and pf.opened[q.id]
      p.title:SetText(q.name)
      -- Short rows (U185, the owner, 12 Nov 2026): folded, a row says your status, its level and how far along the
      -- chain; where it starts and every step open on a click.
      local steps = {}
      if not open then
        local parts = { statusText(QL, q, who, me), levelText(st, inside) }
        -- (A chain of one quest says nothing until it is done: "Step 1 of 1" read as noise, the check of 12 Nov 2026.)
        if #all > 1 then parts[#parts + 1] = nextK and L.DG_STEP_OF:format(nextK, #all) or L.DG_STEPS_DONE:format(#all)
        elseif #all == 1 and not nextK then parts[#parts + 1] = L.DG_STEP_1_DONE end
        p.where:SetText(table.concat(parts, "  ·  "))
      else
        p.where:SetText(questLine(QL, q, who, me, inside))
      end
      -- The chain's steps (U123), each with where it starts.
      if open then for k, x in ipairs(all) do steps[k] = stepLine(QL, k, x, nextK) end end
      p.steps:SetText(table.concat(steps, "\n"))
      p.steps:SetShown(#steps > 0)
      local label = #all > 1 and L.DG_SHOW_STEPS:format(#all) or (#all == 1 and L.DG_SHOW_STEP_1 or L.DG_SHOW_WHERE)
      p:EnableMouse(canOpen)
      p.fold:SetShown(canOpen)
      p.fold:SetTexture(UI.FOLD_ICON[not open])
      p.tip = canOpen and (open and L.DG_HIDE_STEPS or label) or nil
      -- The pin: where you pick up first, a chain's next step where its spot is known, else the quest's own giver
      -- (the owner, 10 Nov 2026: "Waypoint to where you pickup quests").
      local nx = nextK and all[nextK]
      p.st = nx and nx.start.x and nx.start.y and nx.start or st
      p.spot = p.st.zone and p.st.x and L.DQ_AT:format(p.st.zone, p.st.x, p.st.y) or nil
      p.pin:SetShown(QL:CanPin(p.st))
      p.where:ClearAllPoints(); p.where:SetPoint("TOPLEFT", p.title, "BOTTOMLEFT", 0, -2)
      p.steps:ClearAllPoints(); p.steps:SetPoint("TOPLEFT", p.where, "BOTTOMLEFT", 0, -3)
      local h = p.title:GetStringHeight() + p.where:GetStringHeight() + 4
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
  local x = DP.Placed(f, key)
  local later = DP.Later(f, x)
  -- A later dungeon (U137, U138): when it comes, and how many of its prequests are in your To do now.
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
  if later then pf.readyHead:Hide(); pf.rings:Hide(); pf.pickLine:Hide(); pf.readyRows:HideFrom(1)
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
