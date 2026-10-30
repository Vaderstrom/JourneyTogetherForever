-- Quests (SPEC §4.6). Left: Your quests (in your log) and Other Heroes' quests (they have it, you do not); in
-- each, quest chains first, then single quests by zone; your rows have a coloured edge. Right: the chosen quest or
-- chain: type, badge, your progress (bar, or the chain's parts with You are here), the other Heroes' progress, What
-- you can do, and Ask to group up.
local _, ns = ...
local L = ns.L
local UI, Theme = ns.UI, ns.Theme
local Q, Hr = ns.Quests, ns.Hero
local OA = ns.OtherAddons

-- A quest's progress (UI.Bar): gold, green when done; a pip per item or kill when the goal is small (3 of 7).
-- (The flat bar's empty track could hardly be seen on parchment; 28 Oct 2026.)
local function bar(parent)
  local b = UI.Bar(parent, 10)
  local set = b.Set
  function b:Set(width, pct, done, goal)
    self:SetColor(done and "3E9A4E" or "E2B23C")
    self:SetPips(goal)
    set(self, width, pct)
  end
  return b
end

-- A step's Listen button (Spoken, UI/OtherAddons.lua) at its right, for an attunement's steps and a chain's parts.
-- p:SetQuest(ids) shows it when Spoken has one of the quests, and the text makes room for it.
local function addListen(p, width)
  p.listen = UI.RoundButton(p, 22, "listen", function() if p.qid then OA:Listen(p.qid) end end)
  p.listen:SetPoint("TOPRIGHT", 0, 0)
  UI.Tooltip(p.listen, L.LISTEN_TIP)
  function p:SetQuest(ids)
    self.qid = OA:SpokenQuest(ids)
    self.listen:SetShown(self.qid ~= nil)
    local w = width - 34 - (self.qid and 28 or 0)
    self.title:SetWidth(w); self.heroes:SetWidth(w)
  end
end

local function inkFor(f, name)
  local _, token = Hr:ClassName(f, name)
  local ink = ns.ClassHex(token, Theme:Current().light)
  if ink then return ns.Hex(ink) end
  return Theme:RGBA("ink")
end

-- Names like Upper Blackrock Spire need about 180 pixels (they were cut off at 120; seen in the tour).
local ATT_COLS, ATT_NAME_W = 5, 190

-- The Attunements tab (SPEC §6): left a grid of attunements × Heroes, right the chosen one's steps.
local function buildAttune(pf, width)
  local W = ns.Window
  pf.alscroll = UI.Scroll(pf.left)
  pf.alscroll:SetPoint("TOPLEFT", 0, -34); pf.alscroll:SetPoint("BOTTOMRIGHT")
  local Lc = pf.alscroll.child
  pf.aHelp = UI.WrapText(Lc, 12, "ink2", width)
  pf.aHelp:SetText(L.ATT_HELP)
  pf.aNone = UI.SketchLine(Lc, width, "EmptySince")
  local colW = (width - ATT_NAME_W) / ATT_COLS
  pf.aHead = CreateFrame("Frame", nil, Lc)
  pf.aHead:SetSize(width, 18)
  pf.aHead.cols = {}
  for i = 1, ATT_COLS do
    local t = UI.Text(pf.aHead, 11, "ink2", "body", "CENTER")
    t:SetWidth(colW - 2)
    t:SetPoint("LEFT", ATT_NAME_W + (i - 1) * colW, 0)
    pf.aHead.cols[i] = t
  end
  pf.aRows = UI.Pool(function()
    local r = CreateFrame("Button", nil, Lc)
    r:SetSize(width, 26)
    r.sel = r:CreateTexture(nil, "BACKGROUND")
    r.sel:SetAllPoints(); r.sel:SetColorTexture(0.72, 0.53, 0.18, 0.2)
    r.name = UI.Text(r, 13, "ink", "title")
    r.name:SetPoint("LEFT", 4, 0); r.name:SetWidth(ATT_NAME_W - 6)
    r.cells = {}
    for i = 1, ATT_COLS do
      local t = UI.Text(r, 12, "ink", "body", "CENTER")
      t:SetWidth(colW - 2)
      t:SetPoint("LEFT", ATT_NAME_W + (i - 1) * colW, 0)
      r.cells[i] = t
    end
    local hl = r:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints(); hl:SetColorTexture(1, 0.9, 0.6, 0.12)
    r:SetScript("OnClick", function() pf.attSel = r.index; W:Refresh() end)
    return r
  end)
  pf.aMore = UI.Text(Lc, 11, "ink2")

  pf.arscroll = UI.Scroll(pf.right)
  pf.arscroll:SetAllPoints()
  pf.aArt = UI.PageArt(pf.arscroll, "Attune")
  local R = pf.arscroll.child
  pf.aTitle = UI.Heading(R, width, "", nil, 20)
  pf.aKey = UI.WrapText(R, 12, "ink2", width)
  pf.aStepsHead = UI.SectionHeader(R, width)
  pf.aStepsHead:SetText(L.ATT_STEPS)
  pf.aSteps = UI.Pool(function()
    local p = CreateFrame("Frame", nil, R)
    p:SetWidth(width)
    p.ring = UI.Round(p, "ARTWORK", 22)
    p.ring:SetPoint("TOPLEFT", 0, 0)
    p.check = UI.Check(p, 18)
    p.check:SetTexture(ns.MARKS.done)
    p.check:SetPoint("CENTER", p.ring, "CENTER")
    p.n = UI.Text(p, 12, "white", "title", "CENTER")
    p.n:SetPoint("CENTER", p.ring, "CENTER")
    p.title = UI.WrapText(p, 13, "ink", width - 34, "book")
    p.title:SetPoint("TOPLEFT", 32, -2)
    p.heroes = UI.WrapText(p, 11, "ink2", width - 34)
    addListen(p, width)
    return p
  end)
  pf.aDrop = UI.WrapText(R, 13, "ink", width, "book")
  pf.aOpen = UI.TextButton(R, L.OPEN_ATTUNE, function() ns.QuestLists:OpenAttune() end, "plain")
  -- With none open yet: what opens when (every attunement and key for this side, by start level).
  pf.aSoon = UI.Pool(function()
    local p = CreateFrame("Frame", nil, R)
    p:SetSize(width, 34)
    p.lvl = UI.Text(p, 15, "ink", "title", "CENTER")
    p.lvl:SetPoint("TOPLEFT", 0, -2); p.lvl:SetWidth(36)
    p.name = UI.WrapText(p, 13, "ink", width - 46, "title")
    p.name:SetPoint("TOPLEFT", 46, 0)
    p.how = UI.WrapText(p, 11, "ink2", width - 46)
    return p
  end)
end

-- Heroes for the grid: me first, then the others by level (away Heroes left out).
local function gridHeroes(f, me)
  local list = { me }
  local others = {}
  for name in pairs(f.members) do
    if name ~= me and not ns.Journey:Away(f, name) then others[#others + 1] = name end
  end
  table.sort(others, function(a, b)
    local la, lb = Hr:Level(f, a), Hr:Level(f, b)
    if la ~= lb then return la > lb end
    return a < b
  end)
  for _, n in ipairs(others) do list[#list + 1] = n end
  return list
end

local function refreshAttune(pf, f, me)
  local QL = ns.QuestLists
  -- Only the attunements you can work on now (from their start level, or already started).
  local list = QL:Attunements(f, me)
  local heroes = gridHeroes(f, me)
  local s = UI.Stack(pf.alscroll.child)
  s:Place(pf.aHelp, pf.aHelp:GetStringHeight(), 8)
  pf.aNone:SetShown(#list == 0); pf.aHead:SetShown(#list > 0)
  if #list == 0 then
    -- Which one opens first, from the list (it was a fixed text that named Blackrock Depths).
    local nxt = ns.QuestLists:Next(f, ns.Me())
    pf.aNone:SetText(nxt and L.ATT_NONE_YET:format(nxt.name, nxt.level) or L.ATT_NONE_LEFT)
    s:Place(pf.aNone, pf.aNone.h, 8)
  else
    -- (Placing the header shows it: only with rows under it. The tour showed the names over an empty grid.)
    for i, t in ipairs(pf.aHead.cols) do
      local n = heroes[i]
      t:SetText(n and (n == me and L.YOU_LABEL or ns.Short(n)) or "")
      if n then t:SetTextColor(inkFor(f, n)) end
    end
    s:Place(pf.aHead, 18, 2)
  end
  pf.attSel = ns.Clamp(pf.attSel or 1, 1, math.max(1, #list))
  local shown = 0
  for i, a in ipairs(list) do
    local r = pf.aRows:Get(i)
    if not r then break end
    shown = i
    r.index = i
    -- Without the "(Armory and Cathedral)" part in the grid (cut off even at 190 pixels); the steps page has it.
    r.name:SetText((a.name:gsub("%s*%(.-%)$", "")))
    r.sel:SetShown(i == pf.attSel)
    for c, t in ipairs(r.cells) do
      local n = heroes[c]
      if n then
        local p = QL:Progress(f, a, n)
        t:SetText(a.drop and not p.done and L.ATT_NONE or QL:Cell(p))
        t:SetTextColor(Theme:RGBA(p.done and "3E7A3A" or ((p.n > 0 or p.at) and "B8742A" or "ink2")))
      else
        t:SetText("")
      end
    end
    s:Place(r, 26, 2)
  end
  pf.aRows:HideFrom(shown + 1)
  pf.aMore:SetShown(#heroes > ATT_COLS)
  if #heroes > ATT_COLS then
    pf.aMore:SetText(L.ATT_MORE:format(#heroes - ATT_COLS))
    s:Place(pf.aMore, 14, 4)
  end
  pf.alscroll:SetContentHeight(s.y + 8)

  -- The chosen attunement: its steps, and who has done each.
  local a = list[pf.attSel]
  local r = UI.Stack(pf.arscroll.child)
  local nSteps, nSoon = 0, 0
  pf.aKey:SetShown(a ~= nil); pf.aDrop:SetShown(a ~= nil and a.drop == true)
  pf.aStepsHead:SetShown(a ~= nil and #a.steps > 0)
  if not a then
    -- Nothing open yet: what opens when, so the levels are plain to see.
    pf.aTitle:Set(L.ATT_SOON_TITLE, L.ATT_SOON_SUB)
    r:Place(pf.aTitle, pf.aTitle:GetHeight(), 10)
    for i, x in ipairs(QL:Attunements(f)) do
      local p = pf.aSoon:Get(i)
      if not p then break end
      nSoon = i
      p.lvl:SetText(x.level or "")
      p.name:SetText(x.name)
      local d = x.from and ns.Dungeon(x.from)
      p.how:SetText(d and L.ATT_SOON_DROP:format(d[2]) or (x.kind == "raid" and L.ATT_RAID or L.ATT_KEY))
      p.how:ClearAllPoints(); p.how:SetPoint("TOPLEFT", p.name, "BOTTOMLEFT", 0, -2)
      local h = p.name:GetStringHeight() + p.how:GetStringHeight() + 8
      p:SetHeight(h)
      r:Place(p, h, 4)
    end
  end
  pf.aSoon:HideFrom(nSoon + 1)
  if a then
    pf.aTitle:Set(a.name, a.kind == "raid" and L.ATT_RAID or L.ATT_KEY)
    r:Place(pf.aTitle, pf.aTitle:GetHeight(), 6)
    local mine = QL:Progress(f, a, me)
    local done, missing = {}, {}
    for _, n in ipairs(heroes) do
      local p = QL:Progress(f, a, n)
      if p.done then done[#done + 1] = n == me and L.YOU_LABEL or ns.Short(n) else missing[#missing + 1] = n == me and L.YOU_LABEL or ns.Short(n) end
    end
    pf.aKey:SetText((#done > 0 and L.ATT_HAVE:format(table.concat(done, ", ")) or L.ATT_HAVE_NONE)
      .. (#missing > 0 and ("  " .. L.ATT_MISSING:format(table.concat(missing, ", "))) or ""))
    r:Place(pf.aKey, pf.aKey:GetStringHeight(), 10)
    pf.aDrop:SetShown(a.drop == true)
    pf.aStepsHead:SetShown(#a.steps > 0)
    if a.drop then
      local from = a.from and ns.Dungeon(a.from)
      pf.aDrop:SetText(from and L.ATT_DROP_IN:format(from[2]) or L.ATT_DROP)
      r:Place(pf.aDrop, pf.aDrop:GetStringHeight(), 10)
    else
      r:Place(pf.aStepsHead, 29, 4)
      local light = Theme:Current().light
      for i, st in ipairs(a.steps) do
        local p = pf.aSteps:Get(i)
        if not p then break end
        nSteps = i
        local ok, here = mine.steps[i], mine.at == i
        p.ring:SetColorTexture(ns.Hex(here and (light and "B8742A" or "D8A850") or (ok and "3E7A3A" or "7A6A55")))
        p.check:SetShown(ok); p.n:SetShown(not ok); p.n:SetText(i)
        p:SetQuest(st[1])
        p.title:SetText(st[2] .. (here and ("  ·  " .. L.Q_YOU_ARE_HERE) or ""))
        local on = {}
        for _, n in ipairs(heroes) do
          if n ~= me then
            local hp = QL:Progress(f, a, n)
            if hp.at == i then on[#on + 1] = ns.Short(n) end
          end
        end
        p.heroes:SetText(#on > 0 and L.ATT_ON_IT:format(table.concat(on, ", ")) or "")
        p.heroes:ClearAllPoints(); p.heroes:SetPoint("TOPLEFT", p.title, "BOTTOMLEFT", 0, -2)
        local h = math.max(24, p.title:GetStringHeight() + (#on > 0 and p.heroes:GetStringHeight() + 4 or 0) + 4)
        p:SetHeight(h)
        r:Place(p, h, 4)
      end
    end
  end
  pf.aSteps:HideFrom(nSteps + 1)
  r:Skip(8)
  pf.aOpen:SetShown(QL:AttuneCommand() ~= nil)
  if pf.aOpen:IsShown() then r:Place(pf.aOpen, 24, 4) end
  pf.arscroll:SetContentHeight(r.y + 8)
  pf.aArt:Fit(r.y)
end

local function build(pf)
  local W = ns.Window
  local width = W.PAGE_W - 8

  -- Tabs: Chains · Quests · Attunements (Quests first shown).
  pf.tab = "quests"
  pf.tabs = UI.Tabs(pf.left, { { L.TAB_CHAINS, "chains" }, { L.TAB_QUESTS, "quests" }, { L.TAB_ATTUNE, "attune" } },
    function() return pf.tab end, function(v) pf.tab = v; pf.sel = nil; W:Refresh() end, width,
    function(v)
      local f = ns.Fellowship:Current()
      if not f or v == "attune" then return nil end
      local n = 0
      for _, x in ipairs(Q:Items(f)) do
        if (v == "chains") == (x.chain == true) and (x.together or x.join) then n = n + 1 end
      end
      return n
    end)
  pf.tabs:SetPoint("TOPLEFT")
  pf.lscroll = UI.Scroll(pf.left)
  pf.lscroll:SetPoint("TOPLEFT", 0, -34); pf.lscroll:SetPoint("BOTTOMRIGHT")
  local Lc = pf.lscroll.child
  pf.showAll = UI.TextButton(Lc, "", function() pf.all = not pf.all; W:Refresh() end, "link", 12)
  -- Questie is the recommended companion for quest chains (docs/QUEST-CHAINS.md): a note on top, until hidden;
  -- with Questie running, a short line saying where the chains come from.
  pf.questie = CreateFrame("Frame", nil, Lc)
  pf.questie:SetWidth(width)
  pf.questie.icon = UI.Round(pf.questie, "ARTWORK", 20)
  pf.questie.icon:SetPoint("TOPLEFT", 0, -1)
  UI.SetIcon(pf.questie.icon, ns.ICONS.bn_chain)
  pf.questie.text = UI.WrapText(pf.questie, 12, "ink2", width - 28 - 44)
  pf.questie.text:SetPoint("TOPLEFT", 28, 0)
  pf.questie.hide = UI.TextButton(pf.questie, L.Q_QUESTIE_HIDE, function()
    ns.db.questieHintHidden = true; W:Refresh()
  end, "link", 12)
  pf.questie.hide:SetPoint("TOPRIGHT", 0, 2)
  pf.secs = {}
  for i = 1, 2 do
    local s = {}
    s.title = UI.Text(Lc, 17, "ink", "title")
    s.help = UI.WrapText(Lc, 12, "ink2", width)
    s.empty = UI.Text(Lc, 12, "ink2")
    s.empty:SetText(L.Q_NOTHING)
    pf.secs[i] = s
  end
  pf.secs[1].title:SetText(L.Q_SECTION_MINE); pf.secs[1].help:SetText(L.Q_SECTION_MINE_HELP)
  pf.secs[2].title:SetText(L.Q_SECTION_OTHERS); pf.secs[2].help:SetText(L.Q_SECTION_OTHERS_HELP)
  pf.groupLabels = UI.Pool(function()
    local t = UI.Text(Lc, 12, "accent", "title")
    return t
  end)
  pf.rows = UI.Pool(function()
    local r = CreateFrame("Button", nil, Lc)
    r:SetSize(width, 38)
    r.sel = r:CreateTexture(nil, "BACKGROUND")
    r.sel:SetAllPoints(); r.sel:SetColorTexture(0.72, 0.53, 0.18, 0.2)
    r.edge = UI.Solid(r, "ARTWORK", "accent", 1)
    r.edge:SetWidth(3); r.edge:SetPoint("TOPLEFT"); r.edge:SetPoint("BOTTOMLEFT")
    r.name = UI.Text(r, 13, "ink", "title")
    r.name:SetPoint("TOPLEFT", 10, -5)
    r.name:SetWidth(width - 16)
    r.sub = UI.Text(r, 11, "ink2")
    r.sub:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -3)
    r.sub:SetWidth(width - 16)
    local hl = r:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints(); hl:SetColorTexture(1, 0.9, 0.6, 0.12)
    r:SetScript("OnClick", function() pf.sel = r.id; W:Refresh() end)
    return r
  end)

  pf.rscroll = UI.Scroll(pf.right)
  pf.rscroll:SetAllPoints()
  pf.qArt = UI.PageArt(pf.rscroll, "Quest")
  local R = pf.rscroll.child
  pf.none = UI.EmptyState(R, width)
  pf.head = UI.Heading(R, width, "", nil, 20)
  pf.badge = UI.Box(R, 1, nil, nil, nil, nil)
  pf.badge:SetHeight(18)
  pf.badge.text = UI.Text(pf.badge, 11, "white", "body", "CENTER")
  pf.badge.text:SetPoint("CENTER")
  pf.youHead = UI.SectionHeader(R, width)
  pf.youHead:SetText(L.Q_YOUR_PROGRESS)
  pf.youText = UI.WrapText(R, 13, "ink", width, "book")
  pf.youBar = bar(R)
  pf.youCount = UI.Text(R, 12, "ink2", "body", "RIGHT")
  pf.partsHint = UI.WrapText(R, 12, "ink2", width)
  pf.partsHint:SetText(L.Q_PARTS_HINT)
  pf.parts = UI.Pool(function()
    local p = CreateFrame("Frame", nil, R)
    p:SetWidth(width)
    p.ring = UI.Round(p, "ARTWORK", 22)
    p.ring:SetPoint("TOPLEFT", 0, 0)
    p.check = UI.Check(p, 18)
    p.check:SetTexture(ns.MARKS.done)
    p.check:SetPoint("CENTER", p.ring, "CENTER")
    p.n = UI.Text(p, 12, "white", "title", "CENTER")
    p.n:SetPoint("CENTER", p.ring, "CENTER")
    p.title = UI.WrapText(p, 13, "ink", width - 34, "book")
    p.title:SetPoint("TOPLEFT", 32, -2)
    p.heroes = UI.WrapText(p, 11, "ink2", width - 34)
    addListen(p, width)
    return p
  end)
  pf.othersHead = UI.SectionHeader(R, width)
  pf.othersHead:SetText(L.Q_OTHER_HEROES)
  pf.others = UI.Pool(function()
    local o = CreateFrame("Frame", nil, R)
    o:SetSize(width, 36)
    o.name = UI.Text(o, 13, "ink", "title")
    o.name:SetPoint("TOPLEFT", 0, -2)
    o.name:SetWidth(110)
    o.bar = bar(o)
    o.bar:SetPoint("TOPLEFT", 116, -5)
    o.text = UI.Text(o, 12, "ink", "body", "RIGHT")
    o.text:SetPoint("TOPRIGHT", 0, -2)
    o.rel = UI.Text(o, 11, "ink2")
    o.rel:SetPoint("TOPLEFT", 116, -20)
    return o
  end)
  pf.tipsHead = UI.SectionHeader(R, width)
  pf.tipsHead:SetText(L.Q_WHAT_YOU_CAN_DO)
  pf.tips = UI.Pool(function()
    local t = CreateFrame("Frame", nil, R)
    t:SetWidth(width)
    t.icon = t:CreateTexture(nil, "ARTWORK")
    t.icon:SetSize(12, 12); t.icon:SetPoint("TOPLEFT", 2, -2)
    t.icon:SetTexture(ns.MARKS.current)
    t.text = UI.WrapText(t, 13, "ink", width - 22, "book")
    t.text:SetPoint("TOPLEFT", 20, 0)
    return t
  end)
  pf.ask = UI.TextButton(R, L.ASK_GROUP, function() if pf.item then Q:AskGroup(pf.item) end end, "primary")
  pf.inviteQ = UI.TextButton(R, L.INVITE_TO_GROUP, function() if pf.item then Q:InviteFor(pf.item) end end, "plain")
  pf.share = UI.TextButton(R, L.SHARE_QUEST, function() if pf.item then Q:Share(pf.item) end end, "plain")
  pf.listen = UI.TextButton(R, L.LISTEN, function() if pf.listenID then OA:Listen(pf.listenID) end end, "plain")
  UI.Tooltip(pf.listen, L.LISTEN_TIP)
  pf.shareWhy = UI.WrapText(R, 12, "ink2", width)
  buildAttune(pf, width)
end

-- Quests tab: quests near this chapter's levels first (from 3 below the floor to 3 over the cap; unknown levels too).
-- Near your own level (the chapter's range hid quests that fit you; seen in the tour): from 5 under it, where a
-- quest turns grey; to join, up to what you can pick up. Quests you are already on have no upper limit.
Q.GREY_BELOW = 5
local function nearChapter(_, x)
  if not x.level or x.level == 0 then return true end
  -- (Q.viewLevel: /jtf tour looks as a higher character would, as QuestLists.viewLevel does for attunements.)
  local lvl = Q.viewLevel or UnitLevel("player") or 0
  if x.level < lvl - Q.GREY_BELOW then return false end
  return not x.join or x.level <= lvl + Q.JOIN_BELOW
end

local function rowSub(x, me)
  local n = #x.others
  local others = n == 0 and L.Q_SUB_ONLY_YOU or (n == 1 and L.Q_SUB_OTHERS_1 or L.Q_SUB_OTHERS_N:format(n))
  if x.mine then
    if x.chain then
      local at = x.at[me]
      return (at >= #x.steps and L.Q_SUB_FINISHED or L.Q_SUB_PART:format(at + 1, #x.steps)) .. others
    end
    return L.Q_SUB_HAVE:format(x.have[me], x.goal) .. others
  end
  return (n == 1 and L.Q_SUB_HAS or L.Q_SUB_HAVE_IT):format(Q.NameList(x.others))
end

local function refresh(pf, ctx)
  local f = ctx.f
  if not f then return end
  local width = ns.Window.PAGE_W - 8
  local me = ctx.me
  pf.tabs:Refresh()
  local attune = pf.tab == "attune"
  pf.lscroll:SetShown(not attune); pf.rscroll:SetShown(not attune)
  pf.alscroll:SetShown(attune); pf.arscroll:SetShown(attune)
  if attune then
    refreshAttune(pf, f, me)
    return
  end
  -- The items of this tab: chains, or single quests (near this chapter's levels unless Show all). Only what is about
  -- playing together: quests you share with others, and quests you could join (Fellowship/Quests.lua, Classify).
  local items, hidden = {}, 0
  for _, x in ipairs(Q:Items(f)) do
    if x.together or x.join then
      if pf.tab == "chains" then
        if x.chain then items[#items + 1] = x end
      elseif not x.chain then
        if pf.all or nearChapter(f, x) then items[#items + 1] = x else hidden = hidden + 1 end
      end
    end
  end
  -- The chosen item: the one clicked, else the first done together, else the first.
  local pick
  for _, x in ipairs(items) do if x.id == pf.sel then pick = x end end
  if not pick then for _, x in ipairs(items) do if x.together and not pick then pick = x end end end
  pick = pick or items[1]
  pf.item = pick

  -- Left: the note about Questie, then the two sections, chains first, then quests by zone.
  local s = UI.Stack(pf.lscroll.child)
  local state = Q:QuestieState()
  local note = state == "on" and L.Q_QUESTIE_ON or (not ns.db.questieHintHidden and (state == "off" and L.Q_QUESTIE_OFF or L.Q_QUESTIE_GET))
  pf.questie:SetShown(note ~= nil and note ~= false)
  if note then
    pf.questie.text:SetText(note)
    pf.questie.hide:SetShown(state ~= "on")
    local h = math.max(22, pf.questie.text:GetStringHeight())
    pf.questie:SetHeight(h)
    s:Place(pf.questie, h, 10)
  end
  local nRows, nLabels = 0, 0
  for i, sec in ipairs(pf.secs) do
    s:Place(sec.title, 22, 2)
    s:Place(sec.help, sec.help:GetStringHeight(), 6)
    local groups, byZone, zones = {}, {}, {}
    for _, x in ipairs(items) do
      if (i == 1 and x.together) or (i == 2 and x.join) then
        if x.chain then
          if not groups[1] or groups[1].label ~= L.Q_CHAINS then table.insert(groups, 1, { label = L.Q_CHAINS, rows = {} }) end
          table.insert(groups[1].rows, x)
        else
          if not byZone[x.zone] then byZone[x.zone] = { label = x.zone, rows = {} }; zones[#zones + 1] = x.zone end
          table.insert(byZone[x.zone].rows, x)
        end
      end
    end
    table.sort(zones)
    for _, z in ipairs(zones) do groups[#groups + 1] = byZone[z] end
    sec.empty:SetShown(#groups == 0)
    if #groups == 0 then s:Place(sec.empty, 16, 10) end
    for _, g in ipairs(groups) do
      local lab = pf.groupLabels:Get(nLabels + 1)
      if not lab then break end
      nLabels = nLabels + 1
      lab:SetText(g.label ~= "" and g.label or "-")
      s:Place(lab, 18, 2)
      for _, x in ipairs(g.rows) do
        local r = pf.rows:Get(nRows + 1)
        if not r then break end
        nRows = nRows + 1
        r.id = x.id
        r.name:SetText(x.name)
        r.sub:SetText(rowSub(x, me))
        r.sel:SetShown(pick ~= nil and x.id == pick.id)
        r.edge:SetShown(x.mine)
        s:Place(r, 38, 2)
      end
    end
    s:Skip(10)
  end
  pf.rows:HideFrom(nRows + 1)
  pf.groupLabels:HideFrom(nLabels + 1)
  -- Quests far from this chapter's levels: Show all / Only this chapter's levels.
  local toggle = pf.tab == "quests" and (hidden > 0 or pf.all)
  pf.showAll:SetShown(toggle)
  if toggle then
    pf.showAll:SetLabel(pf.all and L.Q_SHOW_NEAR or L.Q_SHOW_ALL:format(hidden))
    s:Place(pf.showAll, 20, 4)
  end
  pf.lscroll:SetContentHeight(s.y + 8)

  -- Right: the chosen quest or chain.
  local r = UI.Stack(pf.rscroll.child)
  local show = pick ~= nil
  pf.none:SetShown(not show)
  for _, w in ipairs({ pf.head, pf.badge, pf.youHead, pf.youText, pf.youBar, pf.youCount, pf.partsHint, pf.othersHead, pf.tipsHead, pf.ask }) do w:SetShown(show) end
  local nParts, nOthers, nTips = 0, 0, 0
  if not show then
    pf.inviteQ:Hide(); pf.share:Hide(); pf.shareWhy:Hide(); pf.listen:Hide()
    r:Skip(60)
    local chains = pf.tab == "chains"
    r:Place(pf.none, pf.none:Set(ns.ICONS[chains and "bn_chain" or "bn_quest"], chains and L.Q_EMPTY_CHAINS or L.Q_NONE,
      chains and L.Q_EMPTY_CHAINS_TEXT or L.Q_EMPTY_TEXT, nil, nil, "EmptyQuests"), 4)
  else
    local d = Q:Detail(pick)
    -- (A chain may have no zone: no "·" in front of its type then; seen in the tour.)
    pf.head:Set(d.title, ((d.line or "") ~= "" and (d.line .. "  ·  ") or "") .. d.type)
    r:Place(pf.head, pf.head:GetHeight(), 2)
    pf.badge.text:SetText(d.badge)
    pf.badge:SetWidth(pf.badge.text:GetStringWidth() + 16)
    pf.badge:SetBackdropColor(ns.Hex(d.mine and "2E7A3E" or "7A6A55"))
    r:Place(pf.badge, 18, 10, (width - pf.badge:GetWidth()) / 2)
    -- Your progress.
    local you = d.mine and d.youText ~= nil
    pf.youHead:SetShown(you); pf.youText:SetShown(you)
    pf.youBar:SetShown(you and not d.chain); pf.youCount:SetShown(you and not d.chain)
    if you then
      r:Place(pf.youHead, 29, 4)
      pf.youText:SetText(d.youText)
      r:Place(pf.youText, pf.youText:GetStringHeight(), 6)
      if not d.chain then
        pf.youBar:Set(width - 70, d.youPct, d.youPct >= 1, d.youGoal)
        pf.youCount:SetText(d.youCount)
        r:Place(pf.youBar, 10, 10)
        -- The count level with the bar (it sat lower, under the bar's end; seen in the check).
        pf.youCount:ClearAllPoints(); pf.youCount:SetPoint("RIGHT", pf.youBar, "RIGHT", 70, 0)
      end
    end
    -- A chain's parts.
    pf.partsHint:SetShown(d.chain)
    if d.chain then
      r:Place(pf.partsHint, pf.partsHint:GetStringHeight(), 6)
      local light = Theme:Current().light
      for i, part in ipairs(d.parts) do
        local p = pf.parts:Get(i)
        if not p then break end
        nParts = i
        p.ring:SetColorTexture(ns.Hex(part.you and (light and "B8742A" or "D8A850") or (part.done and "3E7A3A" or "7A6A55")))
        p.check:SetShown(part.done); p.n:SetShown(not part.done)
        p.n:SetText(part.n)
        p:SetQuest(part.id)
        p.title:SetText(part.title .. (part.you and ("  ·  " .. L.Q_YOU_ARE_HERE) or ""))
        local names = {}
        for k, n in ipairs(part.heroes) do names[k] = ns.Short(n) end
        p.heroes:SetText(table.concat(names, ", "))
        p.heroes:ClearAllPoints(); p.heroes:SetPoint("TOPLEFT", p.title, "BOTTOMLEFT", 0, -2)
        local h = math.max(24, p.title:GetStringHeight() + (#names > 0 and p.heroes:GetStringHeight() + 4 or 0) + 4)
        p:SetHeight(h)
        r:Place(p, h, 4)
      end
    end
    -- The other Heroes.
    pf.othersHead:SetShown(#d.others > 0)
    if #d.others > 0 then r:Place(pf.othersHead, 29, 4) end
    for i, o in ipairs(d.others) do
      local row = pf.others:Get(i)
      if not row then break end
      nOthers = i
      row.name:SetText(ns.Short(o.name))
      row.name:SetTextColor(inkFor(f, o.name))
      row.bar:Set(width - 116 - 70, o.pct, o.pct >= 1, o.goal)
      row.text:SetText(o.text)
      row.rel:SetText(o.rel)
      r:Place(row, 36, 2)
    end
    -- What you can do.
    pf.tipsHead:SetShown(#d.tips > 0)
    if #d.tips > 0 then r:Skip(6); r:Place(pf.tipsHead, 29, 4) end
    for i, text in ipairs(d.tips) do
      local t = pf.tips:Get(i)
      if not t then break end
      nTips = i
      t.text:SetText(text)
      local h = t.text:GetStringHeight() + 4
      t:SetHeight(h)
      r:Place(t, h, 4)
    end
    -- Ask to group up and Invite to group (others on it), Share quest (in my log, in a group): one row, wrapping.
    local buttons = {}
    pf.ask:SetShown(#pick.others > 0); pf.inviteQ:SetShown(#pick.others > 0)
    if #pick.others > 0 then buttons[#buttons + 1] = pf.ask; buttons[#buttons + 1] = pf.inviteQ end
    -- Share quest: shown for a quest in my log, greyed with the reason when it cannot be shared now.
    local share = Q:ShareState(pick)
    pf.share:SetShown(share ~= nil)
    pf.share:SetEnabled(share == "ok")
    if share then buttons[#buttons + 1] = pf.share end
    -- Listen in Spoken: a quest whose words Spoken shows (a chain has the button on each of its parts).
    pf.listenID = not pick.chain and OA:SpokenQuest(tonumber(tostring(pick.id):match("^q:(%d+)$"))) or nil
    pf.listen:SetShown(pf.listenID ~= nil)
    if pf.listenID then buttons[#buttons + 1] = pf.listen end
    if #buttons > 0 then
      r:Skip(6)
      local x, rowY = 0, r.y
      for _, b in ipairs(buttons) do
        if x > 0 and x + b:GetWidth() > width then x, rowY = 0, rowY + 34 end
        b:ClearAllPoints(); b:SetPoint("TOPLEFT", pf.rscroll.child, "TOPLEFT", x, -rowY)
        x = x + b:GetWidth() + 8
      end
      r.y = rowY + 32
    end
    pf.shareWhy:SetShown(share == "group" or share == "no")
    if pf.shareWhy:IsShown() then
      pf.shareWhy:SetText(share == "group" and L.SHARE_WHY_GROUP or L.SHARE_WHY_NO)
      r:Place(pf.shareWhy, pf.shareWhy:GetStringHeight(), 2)
    end
  end
  pf.parts:HideFrom(nParts + 1)
  pf.others:HideFrom(nOthers + 1)
  pf.tips:HideFrom(nTips + 1)
  pf.rscroll:SetContentHeight(r.y + 8)
  -- Under a quest's details (the empty state has its own sketch).
  pf.qArt:Fit(show and r.y or math.huge)
end

ns.Pages:Register({ id = "quests", label = L.NAV_QUESTS, build = build, refresh = refresh,
  title = function() return L.TITLE_QUESTS, L.SUB_QUESTS end })
