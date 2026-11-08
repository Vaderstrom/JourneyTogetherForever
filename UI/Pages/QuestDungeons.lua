-- The Quests page's Dungeon quests tab (U79, SPEC §4.6; the first and default tab). Since U101 (the owner's grilling of
-- 8 Nov 2026) a list of the journey's dungeons: picture, chapter and levels, your ring (Who is ready, U98), how many of
-- its quests you still have to pick up or start early (on a scroll), a door when every quest starts inside. It opens
-- at your chapter, whose rows have a thin gold edge; a row opens the Dungeon page (UI/Pages/Dungeon.lua), where the
-- quests are. Right: the room for the dungeon quests (U78), what the three headings mean, and your chapter's dungeons
-- with how many are ready (U112: without the room the page was nearly empty), the companions' sketch under them.
local _, ns = ...
local L = ns.L
local UI, Theme = ns.UI, ns.Theme
local QD = {}
ns.QuestDungeons = QD

local ROW_H, THUMB_W, THUMB_H, READY_H = 56, 72, 44, 34
local READY_TEX = "Interface\\RaidFrame\\ReadyCheck-Ready"
-- A list that holds only the other faction's quests (The Drowned City is the Horde's): said so, not "no list yet".
local function otherSide(key) return ns.DUNGEON_QUESTS[ns.BaseKey(key)] ~= nil end

-- Room for the dungeon quests (U78): your chapter's total, the mobs option, and Show everyone (off by default). Here
-- and on the Dungeon page; each page keeps its own Show everyone.
function QD.BuildRoom(pf, R, width)
  local W = ns.Window
  pf.dRoomHead = UI.SectionHeader(R, width)
  pf.dRoomHead:SetText(L.ROOM_TITLE)
  pf.dRoomText = UI.WrapText(R, 12, "ink", width, "book")
  pf.dRoomMobs = UI.LabeledCheck(R, width, L.ROOM_MOBS_CHECK, L.ROOM_MOBS_TIP,
    function() return ns.Settings:Get("roomMobs") ~= false end, function(v) ns.Settings:Set("roomMobs", v); W:Refresh() end)
  pf.dRoomAll = UI.LabeledCheck(R, width, L.ROOM_EVERYONE, L.ROOM_EVERYONE_TIP,
    function() return pf.dEveryone end, function(v) pf.dEveryone = v; W:Refresh() end)
  pf.dRoomHeroes = UI.WrapText(R, 12, "ink2", width)
end

function QD.RefreshRoom(pf, f, me, r)
  local Room = ns.Room
  local mine = Room:Chapter(f, me)
  local others = {}
  if pf.dEveryone then
    for _, n in ipairs(ns.Fellowship:Members(f)) do
      local x = n ~= me and not ns.Journey:Away(f, n) and Room:Chapter(f, n)
      if x then
        others[#others + 1] = x.stop and L.ROOM_HERO_STOP:format(ns.Short(n), Room.One(x.to), Room.StopAt(x.stop))
          or L.ROOM_HERO:format(ns.Short(n), Room.One(x.to))
      end
    end
  end
  local show = mine ~= nil or pf.dEveryone
  for _, w in ipairs({ pf.dRoomHead, pf.dRoomMobs, pf.dRoomAll }) do w:SetShown(show) end
  pf.dRoomText:SetShown(show and mine ~= nil)
  pf.dRoomHeroes:SetShown(show and #others > 0)
  if not show then return end
  r:Place(pf.dRoomHead, 29, 4)
  if mine then
    local main, stop, notes = Room.Lines(mine)
    pf.dRoomText:SetText(main .. (stop and ("  |cffB0321E" .. stop .. "|r") or "") .. "\n" .. notes)
    r:Place(pf.dRoomText, pf.dRoomText:GetStringHeight(), 6)
  end
  pf.dRoomMobs:Refresh(); pf.dRoomAll:Refresh()
  r:Place(pf.dRoomMobs, 24, 2)
  r:Place(pf.dRoomAll, 24, 4)
  if #others > 0 then
    pf.dRoomHeroes:SetText(table.concat(others, "\n"))
    r:Place(pf.dRoomHeroes, pf.dRoomHeroes:GetStringHeight(), 6)
  end
end

function QD.Build(pf, width)
  pf.dlscroll = UI.Scroll(pf.left)
  pf.dlscroll:SetPoint("TOPLEFT", 0, -34); pf.dlscroll:SetPoint("BOTTOMRIGHT")
  local Lc = pf.dlscroll.child
  pf.dHelp = UI.WrapText(Lc, 12, "ink2", width)
  pf.dHelp:SetText(L.DQ_HELP)
  pf.dRows = UI.Pool(function()
    local r = CreateFrame("Button", nil, Lc)
    r:SetSize(width, ROW_H)
    r.stripe = UI.Solid(r, "BACKGROUND", "line", 0.25)
    r.stripe:SetAllPoints()
    -- Your chapter's dungeons: a thin gold edge.
    r.edge = UI.Solid(r, "ARTWORK", "gold", 1)
    r.edge:SetPoint("TOPLEFT"); r.edge:SetPoint("BOTTOMLEFT"); r.edge:SetWidth(3)
    r.pic = CreateFrame("Frame", nil, r)
    r.pic:SetSize(THUMB_W, THUMB_H); r.pic:SetPoint("LEFT", 8, 0)
    r.pic.tex = r.pic:CreateTexture(nil, "ARTWORK")
    UI.FramePicture(r.pic, r.pic.tex)
    r.name = UI.Text(r, 14, "ink", "title")
    r.name:SetPoint("TOPLEFT", THUMB_W + 16, -5); r.name:SetWordWrap(false)
    r.sub = UI.Text(r, 11, "ink2")
    r.sub:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -2); r.sub:SetWordWrap(false)
    r.count = UI.Text(r, 11, "ink2")
    r.count:SetPoint("TOPLEFT", r.sub, "BOTTOMLEFT", 0, -2); r.count:SetWordWrap(false)
    -- At the right: your ring, the quests left on a scroll, a door when they all start inside.
    r.ring = UI.DotRing(r, 22, 12, 3)
    r.ring:SetPoint("RIGHT", -10, 0)
    r.check = r:CreateTexture(nil, "OVERLAY")
    r.check:SetSize(13, 13); r.check:SetPoint("CENTER", r.ring); r.check:SetTexture(READY_TEX)
    r.scroll = r:CreateTexture(nil, "ARTWORK")
    r.scroll:SetSize(22, 22); r.scroll:SetTexture("Interface\\Icons\\INV_Scroll_03")
    r.scroll:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    r.n = UI.Text(r, 11, "white", "title", "CENTER")
    r.n:SetPoint("BOTTOMRIGHT", r.scroll, "BOTTOMRIGHT", 3, -2)
    r.n:SetShadowOffset(1, -1); r.n:SetShadowColor(0, 0, 0, 1)
    r.door = r:CreateTexture(nil, "ARTWORK")
    r.door:SetSize(20, 20)
    local hl = r:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints(); hl:SetColorTexture(1, 0.9, 0.6, 0.12)
    r:SetScript("OnClick", function() if r.key then ns.DungeonPage:Open(r.key) end end)
    UI.Tooltip(r, function() return r.tip end)
    return r
  end)
  -- Opened (or its tab chosen): the list shows your chapter.
  pf:HookScript("OnShow", function() pf.dReveal = true end)

  pf.drscroll = UI.Scroll(pf.right)
  pf.drscroll:SetAllPoints()
  local R = pf.drscroll.child
  QD.BuildRoom(pf, R, width)
  pf.dHowHead = UI.SectionHeader(R, width)
  pf.dHowHead:SetText(L.DQ_HOW_HEAD)
  pf.dHow = UI.WrapText(R, 12, "ink", width, "book")
  local G = ns.DungeonPage.GROUPS
  pf.dHow:SetText(("%s  %s\n\n%s  %s\n\n%s  %s"):format(G[1][3], L.DQ_HOW_EARLY, G[2][3], L.DQ_HOW_PICK, G[3][3], L.DQ_HOW_INSIDE))
  pf.dReadyHead = UI.SectionHeader(R, width)
  pf.dReadyRows = UI.Pool(function()
    local b = CreateFrame("Button", nil, R)
    b:SetSize(width, READY_H)
    b.name = UI.Text(b, 13, "ink", "title")
    b.name:SetPoint("TOPLEFT", 4, -3); b.name:SetWidth(width - 8); b.name:SetWordWrap(false)
    b.sub = UI.Text(b, 11, "ink2")
    b.sub:SetPoint("TOPLEFT", b.name, "BOTTOMLEFT", 0, -2)
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints(); hl:SetColorTexture(1, 0.9, 0.6, 0.12)
    b:SetScript("OnClick", function() if b.key then ns.DungeonPage:Open(b.key) end end)
    UI.Tooltip(b, function() return b.tip end)
    return b
  end)
  pf.dArt = UI.PageArt(pf.drscroll, "Companions")
end

-- Your chapter's dungeons not cleared yet, each with how many Adventurers are ready (who and how far on hover).
function QD.RefreshReady(pf, f, r)
  local Ready, J = ns.Ready, ns.Journey
  local list = Ready:Watched(f)
  pf.dReadyHead:SetShown(#list > 0)
  if #list > 0 then
    r:Skip(8)
    pf.dReadyHead:SetText(L.DQ_READY_HEAD:format(J.Roman(J:CurrentIndex(f))))
    r:Place(pf.dReadyHead, 29, 4)
  end
  local shown = 0
  for i, x in ipairs(list) do
    local b = pf.dReadyRows:Get(i)
    if not b then break end
    shown = i
    local rows, ready, lines = Ready:Rows(f, x.key), 0, { x.d[2] }
    for _, row in ipairs(rows) do
      if row.r and row.r.ready then ready = ready + 1 end
      lines[#lines + 1] = Ready.Line(row.name, row.r)
    end
    b.key = x.key
    b.name:SetText(x.d[2])
    -- (Nothing to get ready is the same for everyone: the quests are the dungeon's.)
    b.sub:SetText(rows[1] and rows[1].r and L.DQ_READY_N:format(ready, #rows) or L.RD_NOTHING)
    b.tip = table.concat(lines, "\n") .. "\n" .. L.DQ_ROW_TIP
    r:Place(b, READY_H, 2)
  end
  pf.dReadyRows:HideFrom(shown + 1)
end

-- Every dungeon of the journey once, in its order (a bridge shown early stays in its own chapter).
function QD.List(f)
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

function QD.Refresh(pf, f, me)
  local QL, J = ns.QuestLists, ns.Journey
  local list = QD.List(f)
  local cur = J:CurrentIndex(f)
  local s = UI.Stack(pf.dlscroll.child)
  s:Place(pf.dHelp, pf.dHelp:GetStringHeight(), 8)
  local shown, reveal = 0, nil
  local width = ns.Window.PAGE_W - 8
  for i, x in ipairs(list) do
    local r = pf.dRows:Get(i)
    if not r then break end
    shown = i
    r.key = x.key
    r.name:SetText(x.d[2])
    r.sub:SetText(L.DQ_ROW_SUB:format(J.Roman(x.n), L.CH_LEVELS:format(x.d[3], x.d[4])))
    local line, pick, earlier, inside, outside, open = QL:CountLine(f, x.key)
    -- Ruins of Lordaeron's Alliance quests all start inside: "All its quests done" was wrong (the check of 7 Nov 2026).
    local allInside = pick ~= nil and outside == 0
    if not line and allInside and inside > 0 then line = inside == 1 and L.DQ_INSIDE_1 or L.DQ_INSIDE_N:format(inside) end
    local done = pick and (open > 0 and L.DQ_ALL_PICKED or L.DQ_ALL_DONE)
    r.count:SetText(line or done or (otherSide(x.key) and L.DQ_OTHER_SIDE or L.DQ_NO_LIST))
    r.count:SetTextColor(Theme:RGBA(line and not allInside and "B8742A" or "ink2"))
    r.tip = x.d[2] .. "\n" .. (line or "") .. "\n" .. L.DQ_ROW_TIP
    ns.SetDungeonArt(r.pic.tex, x.key, THUMB_W - 2 * UI.PIC_INSET, THUMB_H - 2 * UI.PIC_INSET)
    -- The right side, from the edge inwards: ring, scroll with the count, door.
    local mine = QL:Ready(f, x.key, me)
    r.ring:SetShown(mine ~= nil)
    if mine then r.ring:Set(ns.Ready.Share(mine), mine.ready and "gold" or "B8742A") end
    r.check:SetShown(mine ~= nil and mine.ready)
    local left = pick and pick + earlier or 0
    local rx = mine and -40 or -10
    r.scroll:SetShown(left > 0); r.n:SetShown(left > 0)
    if left > 0 then
      r.n:SetText(left)
      r.scroll:ClearAllPoints(); r.scroll:SetPoint("RIGHT", rx, 0)
      rx = rx - 28
    end
    r.door:SetShown(allInside and r.door:SetAtlas("Dungeon") ~= false)
    if r.door:IsShown() then r.door:ClearAllPoints(); r.door:SetPoint("RIGHT", rx, 0); rx = rx - 26 end
    local textW = width + rx - (THUMB_W + 16) - 4
    r.name:SetWidth(textW); r.sub:SetWidth(textW); r.count:SetWidth(textW)
    r.edge:SetShown(x.n == cur)
    r.stripe:SetShown(i % 2 == 0)
    if x.n == cur and not reveal then reveal = s.y end
    s:Place(r, ROW_H, 2)
  end
  pf.dRows:HideFrom(shown + 1)
  pf.dlscroll:SetContentHeight(s.y + 8)
  -- Your chapter in view, once each time the list is opened.
  if pf.dReveal and reveal and pf.dlscroll:Reveal(reveal, ROW_H) then pf.dReveal = nil end

  local r = UI.Stack(pf.drscroll.child)
  QD.RefreshRoom(pf, f, me, r)
  r:Skip(8)
  r:Place(pf.dHowHead, 29, 4)
  r:Place(pf.dHow, pf.dHow:GetStringHeight(), 6)
  QD.RefreshReady(pf, f, r)
  pf.drscroll:SetContentHeight(r.y + 8)
  pf.dArt:Fit(r.y)
end
