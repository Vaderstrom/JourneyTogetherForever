-- The Quests page's Dungeons tab (U79, SPEC §4.6; the first and default tab). Left: every dungeon of the journey in
-- its order, with how many of its quests you still have to pick up or start earlier. Right: the chosen dungeon's
-- quests for your side in three groups (Pick up before you go, Start earlier, Starts inside), each with its level,
-- where it starts, your status, who else has it, and Pin on map.
local _, ns = ...
local L = ns.L
local UI, Theme = ns.UI, ns.Theme
local QD = {}
ns.QuestDungeons = QD

local ROW_H = 52
-- Not yet: in the line's own colour (a theme role is no hex: "|cffink2Not yet" showed in the check of 7 Nov 2026).
local STATUS = { done = { L.DQ_DONE, "3E7A3A" }, log = { L.DQ_IN_LOG, "B8742A" }, no = { L.DQ_NOT_YET } }
local GROUPS = { { "pick", L.DQ_PICK_HEAD }, { "earlier", L.DQ_EARLIER_HEAD }, { "inside", L.DQ_INSIDE_HEAD } }
-- A list that holds only the other faction's quests (The Drowned City is the Horde's): said so, not "no list yet".
local function otherSide(key) return ns.DUNGEON_QUESTS[ns.BaseKey(key)] ~= nil end

function QD.Build(pf, width)
  local W = ns.Window
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
    r.sel = r:CreateTexture(nil, "BACKGROUND", nil, 1)
    r.sel:SetAllPoints(); r.sel:SetColorTexture(0.72, 0.53, 0.18, 0.25)
    r.name = UI.Text(r, 14, "ink", "title")
    r.name:SetPoint("TOPLEFT", 8, -5); r.name:SetWidth(width - 16); r.name:SetWordWrap(false)
    r.sub = UI.Text(r, 11, "ink2")
    r.sub:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -2)
    r.count = UI.Text(r, 11, "ink2")
    r.count:SetPoint("TOPLEFT", r.sub, "BOTTOMLEFT", 0, -2)
    local hl = r:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints(); hl:SetColorTexture(1, 0.9, 0.6, 0.12)
    r:SetScript("OnClick", function() pf.dSel = r.key; W:Refresh() end)
    return r
  end)

  pf.drscroll = UI.Scroll(pf.right)
  pf.drscroll:SetAllPoints()
  local R = pf.drscroll.child
  pf.dTitle = UI.Heading(R, width, "", nil, 20)
  pf.dNone = UI.SketchLine(R, width, "EmptySince")
  pf.dSecs = {}
  for i, g in ipairs(GROUPS) do
    pf.dSecs[i] = UI.SectionHeader(R, width)
    pf.dSecs[i]:SetText(g[2])
  end
  pf.dQuests = UI.Pool(function()
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
  end)
  -- Room for the dungeon quests (U78): your chapter's total, the mobs option, and Show everyone (off by default).
  pf.dRoomHead = UI.SectionHeader(R, width)
  pf.dRoomHead:SetText(L.ROOM_TITLE)
  pf.dRoomText = UI.WrapText(R, 12, "ink", width, "book")
  pf.dRoomMobs = UI.LabeledCheck(R, width, L.ROOM_MOBS_CHECK, L.ROOM_MOBS_TIP,
    function() return ns.Settings:Get("roomMobs") ~= false end, function(v) ns.Settings:Set("roomMobs", v); W:Refresh() end)
  pf.dRoomAll = UI.LabeledCheck(R, width, L.ROOM_EVERYONE, L.ROOM_EVERYONE_TIP,
    function() return pf.dEveryone end, function(v) pf.dEveryone = v; W:Refresh() end)
  pf.dRoomHeroes = UI.WrapText(R, 12, "ink2", width)
end

-- Room for the dungeon quests on the right page, under the dungeon's quests.
local function refreshRoom(pf, f, me, r)
  local Room = ns.Room
  local mine = Room:Chapter(f, me)
  local others = {}
  if pf.dEveryone then
    for _, n in ipairs(ns.Fellowship:Members(f)) do
      local x = n ~= me and not ns.Journey:Away(f, n) and Room:Chapter(f, n)
      if x then
        others[#others + 1] = x.stop and L.ROOM_HERO_STOP:format(ns.Short(n), Room.One(x.to), Room.One(math.max(x.stop, 1)))
          or L.ROOM_HERO:format(ns.Short(n), Room.One(x.to))
      end
    end
  end
  local show = mine ~= nil or pf.dEveryone
  for _, w in ipairs({ pf.dRoomHead, pf.dRoomMobs, pf.dRoomAll }) do w:SetShown(show) end
  pf.dRoomText:SetShown(show and mine ~= nil)
  pf.dRoomHeroes:SetShown(show and #others > 0)
  if not show then return end
  r:Skip(6)
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

-- Every dungeon of the journey once, in its order (a bridge shown early stays in its own chapter).
function QD.List(f)
  local J, list, seen = ns.Journey, {}, {}
  for n = 1, #f.journey.chapters do
    for _, x in ipairs(J:ChapterList(f, n)) do
      if not x.early and not seen[x.key] then
        seen[x.key] = true
        list[#list + 1] = { key = x.key, d = x.d, n = n }
      end
    end
  end
  return list
end

-- The dungeon shown first: the current chapter's recommended next, else its first not cleared, else the first.
local function firstPick(f, list)
  local J = ns.Journey
  local cur = J:CurrentIndex(f)
  local nxt = f.journey.chapters[cur] and J:NextDungeon(f, cur)
  if nxt then return nxt end
  for _, x in ipairs(list) do if x.n == cur and not J:Cleared(f, x.key) then return x.key end end
  for _, x in ipairs(list) do if x.n >= cur then return x.key end end
  return list[1] and list[1].key
end

local function names(list, me)
  local out = {}
  for _, n in ipairs(list) do out[#out + 1] = n == me and L.YOU_LABEL or ns.Short(n) end
  return table.concat(out, ", ")
end

function QD.Refresh(pf, f, me)
  local QL, J = ns.QuestLists, ns.Journey
  local list = QD.List(f)
  local found
  for _, x in ipairs(list) do if x.key == pf.dSel then found = true end end
  if not found then pf.dSel = firstPick(f, list) end

  local s = UI.Stack(pf.dlscroll.child)
  s:Place(pf.dHelp, pf.dHelp:GetStringHeight(), 8)
  local shown, pick = 0, nil
  for i, x in ipairs(list) do
    local r = pf.dRows:Get(i)
    if not r then break end
    shown = i
    r.key = x.key
    r.name:SetText(x.d[2])
    r.sub:SetText(L.DQ_ROW_SUB:format(J.Roman(x.n), L.CH_LEVELS:format(x.d[3], x.d[4])))
    local line, listed, _, inside = QL:CountLine(f, x.key)
    -- Ruins of Lordaeron's Alliance quests all start inside: "All its quests done" was wrong (the check of 7 Nov 2026).
    if not line and inside and inside > 0 then line = inside == 1 and L.DQ_INSIDE_1 or L.DQ_INSIDE_N:format(inside) end
    r.count:SetText(line or (listed and L.DQ_ALL_DONE or (otherSide(x.key) and L.DQ_OTHER_SIDE or L.DQ_NO_LIST)))
    r.count:SetTextColor(Theme:RGBA(line and "B8742A" or "ink2"))
    r.stripe:SetShown(i % 2 == 0)
    r.sel:SetShown(x.key == pf.dSel)
    if x.key == pf.dSel then pick = x end
    s:Place(r, ROW_H, 2)
  end
  pf.dRows:HideFrom(shown + 1)
  pf.dlscroll:SetContentHeight(s.y + 8)

  -- Right: the chosen dungeon's quests in their three groups.
  local r = UI.Stack(pf.drscroll.child)
  local g = pick and QL:Groups(f, pick.key)
  -- Its share of the room for the dungeon quests (U78): its quests and mobs in levels, for you.
  local sub = pick and L.CH_LEVELS:format(pick.d[3], pick.d[4]) or ""
  if pick then
    local sh = ns.Room:Share(f, pick.key, me)
    local lv = ns.Room:Levels(f, me, sh.quests + (sh.mobs or 0))
    if lv and lv >= 0.05 then sub = sub .. "  ·  " .. L.ROOM_SHARE:format(ns.Room.One(lv)) end
  end
  pf.dTitle:Set(pick and pick.d[2] or "", sub)
  r:Place(pf.dTitle, pf.dTitle:GetHeight(), 10)
  pf.dNone:SetShown(g == nil)
  if not g then
    pf.dNone:SetText(pick and otherSide(pick.key) and L.DQ_OTHER_SIDE_LONG or L.DQ_NO_LIST_LONG)
    r:Place(pf.dNone, pf.dNone.h, 8)
  end
  local nq = 0
  for i, grp in ipairs(GROUPS) do
    local quests = g and g[grp[1]] or {}
    pf.dSecs[i]:SetShown(#quests > 0)
    if #quests > 0 then r:Place(pf.dSecs[i], 29, 4) end
    for _, q in ipairs(quests) do
      local p = pf.dQuests:Get(nq + 1)
      if not p then break end
      nq = nq + 1
      p.id = q.id
      p.title:SetText(q.name)
      p.where:SetText(QL.WhereText(q.start))
      local st = STATUS[q.status]
      local parts = {}
      if q.start.lvl then parts[1] = L.DQ_LEVEL:format(q.start.lvl) end
      parts[#parts + 1] = st[2] and ("|cff%s%s|r"):format(Theme:HexFor(st[2]), st[1]) or st[1]
      if #q.others > 0 then parts[#parts + 1] = L.DQ_ALSO:format(names(q.others, me)) end
      p.status:SetText(table.concat(parts, "  ·  "))
      local steps = {}
      for k, x in ipairs(q.steps or {}) do
        local line = x.lvl and L.DQ_STEP_LVL:format(k, x.name, x.lvl) or L.DQ_STEP:format(k, x.name)
        steps[k] = line .. "  ·  " .. STATUS[x.status][1]
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
  pf.dQuests:HideFrom(nq + 1)
  refreshRoom(pf, f, me, r)
  pf.drscroll:SetContentHeight(r.y + 8)
end
