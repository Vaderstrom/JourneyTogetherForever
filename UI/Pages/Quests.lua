-- Quests (SPEC §4.6). Together (U263-U264): left the quests to do with other Adventurers in three sections, Do
-- together now, You could join and They could join you, by zone, a short row each with the faces of who has it; right
-- the chosen one: the answer (what to do together), the buttons, the map in the book (U267) and where everyone
-- stands (a chain's step track). Then the dungeon quest log (U213) and Attunements & keys.
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
-- p:SetQuest(ids) shows it on every step done by a quest, Spoken or not (a click without it says to install it),
-- and the text makes room for it.
local function addListen(p, width)
  p.listen = UI.RoundButton(p, 22, "listen", function() if p.qids then OA:Listen(p.qids) end end)
  p.listen:SetPoint("TOPRIGHT", 0, 0)
  UI.Tooltip(p.listen, L.LISTEN_TIP)
  function p:SetQuest(ids)
    if type(ids) == "table" and #ids == 0 then ids = nil end
    self.qids = ids
    self.listen:SetShown(ids ~= nil)
    local w = width - 34 - (ids and 28 or 0)
    self.title:SetWidth(w); self.heroes:SetWidth(w)
  end
end

local function inkFor(f, name)
  local _, token = Hr:ClassName(f, name)
  local ink = ns.ClassHex(token, Theme:Current().light)
  if ink then return ns.Hex(ink) end
  return Theme:RGBA("ink")
end

-- A Together row's height (short rows, U263).
local ROW_H = 26

-- Names like Upper Blackrock Spire need about 180 pixels (they were cut off at 120; seen in the tour).
local ATT_COLS, ATT_NAME_W, ATT_ROW_H = 5, 210, 32
-- A step's box: the room inside its edge, and the line down to the next box (U214).
local ATT_PAD, ATT_GAP = 7, 12

-- The Attunements tab (SPEC §6): left a grid of attunements × Heroes, right the chosen one's steps.
local function buildAttune(pf, width)
  local W = ns.Window
  pf.alscroll = UI.Scroll(pf.left)
  pf.alscroll:SetPoint("TOPLEFT", 0, -34); pf.alscroll:SetPoint("BOTTOMRIGHT")
  local Lc = pf.alscroll.child
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
    r:SetSize(width, ATT_ROW_H)
    -- Every other row a faint band, so a row reads across to its Adventurers (6 Nov 2026: clearer, bolder).
    r.stripe = UI.Solid(r, "BACKGROUND", "line", 0.25)
    r.stripe:SetAllPoints()
    r.sel = r:CreateTexture(nil, "BACKGROUND", nil, 1)
    r.sel:SetAllPoints(); r.sel:SetColorTexture(0.72, 0.53, 0.18, 0.25)
    r.icon = UI.Round(r, "ARTWORK", 22)
    r.icon:SetPoint("LEFT", 4, 0)
    r.name = UI.Text(r, 14, "ink", "title")
    r.name:SetPoint("LEFT", 32, 0); r.name:SetWidth(ATT_NAME_W - 34)
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
  -- Each step a box, joined to the next by a line, as the Attune addon draws a chain (U214, the owner, 15 Nov 2026:
  -- "Build it for attunements"): done in green, the step you are on in gold, the rest plain. Coloured at refresh by
  -- its state, so it has no theme painter that would reset it.
  pf.aSteps = UI.Pool(function()
    local p = CreateFrame("Frame", nil, R, "BackdropTemplate")
    p:SetBackdrop({ bgFile = ns.WHITE, edgeFile = ns.WHITE, edgeSize = 1 })
    p:SetWidth(width)
    p.link = p:CreateTexture(nil, "BACKGROUND")
    p.link:SetWidth(2); p.link:SetHeight(ATT_GAP); p.link:SetPoint("TOP", p, "BOTTOM")
    p.ring = UI.Round(p, "ARTWORK", 22)
    p.ring:SetPoint("TOPLEFT", ATT_PAD, -ATT_PAD)
    p.check = UI.Check(p, 18)
    p.check:SetTexture(ns.MARKS.done)
    p.check:SetPoint("CENTER", p.ring, "CENTER")
    p.n = UI.Text(p, 12, "white", "title", "CENTER")
    p.n:SetPoint("CENTER", p.ring, "CENTER")
    p.title = UI.WrapText(p, 13, "ink", width - 34 - 2 * ATT_PAD, "book")
    p.title:SetPoint("TOPLEFT", 32 + ATT_PAD, -ATT_PAD - 2)
    p.heroes = UI.WrapText(p, 11, "ink2", width - 34 - 2 * ATT_PAD)
    addListen(p, width - 2 * ATT_PAD)
    p.listen:SetPoint("TOPRIGHT", -ATT_PAD, -ATT_PAD)
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
    UI.SetIcon(r.icon, ns.ICONS[a.kind == "raid" and "raids" or "bn_locked"])
    r.stripe:SetShown(i % 2 == 0)
    r.sel:SetShown(i == pf.attSel)
    for c, t in ipairs(r.cells) do
      local n = heroes[c]
      if n then
        local p = QL:Progress(f, a, n)
        t:SetText(a.drop and not p.done and L.ATT_NONE or QL:Cell(p))
        t:SetTextColor(Theme:RGBA(p.done and "3E7A3A" or ((p.n > 0 or p.at) and "amberText" or "ink2")))
      else
        t:SetText("")
      end
    end
    s:Place(r, ATT_ROW_H, 2)
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
        local gold = light and "B8742A" or "D8A850"
        p.ring:SetColorTexture(ns.Hex(here and gold or (ok and "3E7A3A" or "7A6A55")))
        p:SetBackdropColor(Theme:RGBA(here and gold or "3E7A3A", (here or ok) and 0.16 or 0))
        p:SetBackdropBorderColor(Theme:RGBA(here and gold or (ok and "3E7A3A" or "line"), here and 1 or 0.9))
        p.link:SetColorTexture(Theme:RGBA(ok and "3E7A3A" or "line", 0.9))
        p.link:SetShown(i < #a.steps)
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
          + 2 * ATT_PAD
        p:SetHeight(h)
        r:Place(p, h, ATT_GAP)
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

-- The Dungeon quests tab (U213, the owner, 15 Nov 2026): the dungeon quest log, the chapter to finish first on the left
-- page and Start early on the right (QL:Plan; the owner, 17 Nov 2026: it was Under way and Open now, "I don't
-- understand this layout"). Each quest the Dungeon page's row (U258, the owner, 18 Nov 2026: "the same structure as in
-- the dungeons page"), open: where it starts and its chain's steps, each with Show on map (U259); a click folds it in
-- place, on the tab and in the Overview's panel alike (one log). Its dungeon's heading opens the Dungeon page.
local logOpen = { opened = {}, openDefault = true }

-- A dungeon's heading over its rows (U230: its name and chapter were on every row); a click opens its Dungeon page.
local function logHead(parent, width)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(width, 20)
  local hl = b:CreateTexture(nil, "HIGHLIGHT")
  hl:SetPoint("TOPLEFT", -4, 2); hl:SetPoint("BOTTOMRIGHT", 4, -2); hl:SetColorTexture(1, 0.9, 0.6, 0.12)
  b.text = UI.Text(b, 13, "accentText", "title")
  b.text:SetPoint("LEFT")
  b:SetScript("OnClick", function() if b.key then ns.Window:HidePanels(); ns.DungeonPage:Open(b.key) end end)
  UI.Tooltip(b, L.DQL_HEAD_TIP)
  return b
end

-- One part of the log in c (1: First, 2: Start early): its heading, its empty line, its dungeons' headings and rows.
local function newPart(c, width, i)
  local part = { head = UI.SectionHeader(c, width), none = UI.SketchLine(c, width, "EmptyQuests"),
    rows = UI.Pool(function() return ns.DungeonPage.QuestRow(c, width, logOpen) end),
    heads = UI.Pool(function() return logHead(c, width) end) }
  part.head:SetHelp(i == 1 and L.DQL_FIRST_HELP or L.DQL_EARLY_HELP)
  return part
end

local function buildLog(pf, width)
  pf.log = {}
  for i, side in ipairs({ pf.left, pf.right }) do
    local sc = UI.Scroll(side)
    if i == 1 then sc:SetPoint("TOPLEFT", 0, -34); sc:SetPoint("BOTTOMRIGHT") else sc:SetAllPoints() end
    pf.log[i] = newPart(sc.child, width, i)
    pf.log[i].scroll = sc
  end
end

-- Places part i of the plan (QL:Plan) of who, with its rows, on the stack s. Part 1's heading names its chapter, so
-- its dungeons' do not.
local function placePart(s, part, i, plan, who)
  local J = ns.Journey
  local list = i == 1 and plan.first or plan.early
  part.head:SetText((i == 1 and L.DQL_FIRST_PART:format(L.CHAPTER_ROMAN:format(J.Roman(plan.n))) or L.DQL_EARLY)
    .. (#list > 0 and ("  ·  " .. #list) or ""))
  s:Place(part.head, 29, 6)
  part.none:SetShown(#list == 0)
  if #list == 0 then
    part.none:SetText(i == 1 and L.DQL_FIRST_NONE or L.DQL_EARLY_NONE)
    s:Place(part.none, part.none.h, 8)
  end
  local n, nh, last = 0, 0, nil
  for _, row in ipairs(list) do
    local r = part.rows:Get(n + 1)
    if not r then break end
    -- (The log comes in the journey's order: a dungeon's rows follow each other.)
    if row.key ~= last then
      local hd = part.heads:Get(nh + 1)
      if not hd then break end
      nh, last = nh + 1, row.key
      local d = ns.Dungeon(row.key)
      hd.key = row.key
      hd.text:SetText((d and d[2] or row.key) .. (i == 1 and "" or "  ·  " .. L.CHAPTER_ROMAN:format(J.Roman(row.n))))
      if nh > 1 then s:Skip(4) end
      s:Place(hd, 20, 4)
    end
    n = n + 1
    -- (The log's own word last: the Dungeon page has Who is ready for it. The icon is the next step's, so a chain
    -- under way does not look untouched.)
    local word = row.what == "run" and L.DQL_RUN or (row.what == "log" and L.DQL_IN_RUN or nil)
    s:Place(r, ns.DungeonPage.FillQuest(r, row.q, who, false, nil, word), 10)
    r.icon:SetTexture((ns.QuestLists.STATUS[row.status] or ns.QuestLists.STATUS.no)[1])
  end
  part.rows:HideFrom(n + 1)
  part.heads:HideFrom(nh + 1)
end

local function refreshLog(pf, f, me)
  local plan = ns.QuestLists:Plan(f, me)
  for i, part in ipairs(pf.log) do
    local s = UI.Stack(part.scroll.child)
    placePart(s, part, i, plan, me)
    part.scroll:SetContentHeight(s.y + 8)
  end
end

-- The Overview's side panel (U215, the owner, 15 Nov 2026: "kinda like a 'right side' menu on the overview page"):
-- the same log, First above Start early. (Registered once loaded: Window.lua loads after this file; the window is
-- built at login.)
ns:On("DB_READY", function() ns.Window:RegisterPanel("dquests", { title = L.TAB_DQUESTS, icon = "dungeons",
  build = function(p) p.parts = { newPart(p.body, p.width, 1), newPart(p.body, p.width, 2) } end,
  refresh = function(p)
    local ctx = ns.Pages:Context()
    local plan = ctx.f and ns.QuestLists:Plan(ctx.f, ctx.me) or { n = 1, first = {}, early = {} }
    local s = UI.Stack(p.body)
    s:Skip(6)
    placePart(s, p.parts[1], 1, plan, ctx.me)
    s:Skip(8)
    placePart(s, p.parts[2], 2, plan, ctx.me)
    p.scroll:SetContentHeight(s.y + 10)
  end }) end)

local function build(pf)
  local W = ns.Window
  local width = W.PAGE_W - 8

  -- Tabs (U263, the owner's grilling of 19 Nov 2026; U141 before): Together · Dungeon quests · Attunements & keys,
  -- with icons (U102). A dungeon's quests are on its Dungeon page; the Dungeon quests tab is their log (U213).
  pf.tab = "quests"
  pf.tabs = UI.Tabs(pf.left, { { L.TAB_QUESTS, "quests", "quests" },
    { L.TAB_DQUESTS, "dungeons", "dungeons" }, { L.TAB_ATTUNE, "attune", "toast_attune" } },
    function() return pf.tab end, function(v) pf.tab = v; pf.sel = nil; W:Refresh() end, width,
    function(v)
      local f = ns.Fellowship:Current()
      if not f or v ~= "quests" then return nil end
      -- (They could join you is left out: it would count most of your log; U264.)
      local n = 0
      for _, x in ipairs(Q:Items(f)) do
        if (x.together or x.join) and not Q.Finished(x, ns.Me()) then n = n + 1 end
      end
      return n
    end)
  pf.tabs:SetPoint("TOPLEFT")
  pf.lscroll = UI.Scroll(pf.left)
  pf.lscroll:SetPoint("TOPLEFT", 0, -34); pf.lscroll:SetPoint("BOTTOMRIGHT")
  local Lc = pf.lscroll.child
  pf.showAll = UI.TextButton(Lc, "", function() pf.all = not pf.all; W:Refresh() end, "link", 12)
  pf.showDone = UI.TextButton(Lc, "", function() pf.history = not pf.history; W:Refresh() end, "link", 12)
  -- Questie, the companion for quest chains (docs/QUEST-CHAINS.md): a note at the foot while it does not run (U195).
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
  -- Three sections, each a book heading with its count and a "?" (U264).
  pf.secs = {}
  for i, key in ipairs({ "MINE", "OTHERS", "BRING" }) do
    local s = { head = UI.SectionHeader(Lc, width), key = key }
    s.head:SetText(L["Q_SECTION_" .. key]); s.head:SetHelp(L["Q_SECTION_" .. key .. "_HELP"])
    pf.secs[i] = s
  end
  pf.empty = UI.Text(Lc, 12, "ink2")
  pf.empty:SetText(L.Q_NOTHING)
  -- A zone's heading: its name, and on the right how close it is (You are here, Nearby).
  pf.groupLabels = UI.Pool(function()
    local g = CreateFrame("Frame", nil, Lc)
    g:SetSize(width, 20)
    g.text = UI.Text(g, 13, "accentText", "title")
    g.text:SetPoint("BOTTOMLEFT", 2, 3)
    g.tag = UI.Text(g, 11, "ink2", "body", "RIGHT")
    g.tag:SetPoint("BOTTOMRIGHT", -2, 4)
    g.pin = g:CreateTexture(nil, "ARTWORK")
    g.pin:SetSize(14, 14); g.pin:SetPoint("RIGHT", g.tag, "LEFT", -3, 0)
    g.pin:SetTexture(ns.MARKS.current)
    function g:GetText() return self.text:GetText() end
    return g
  end)
  -- A quest or chain as a short row (U263): its icon, name, level or step, and the faces of who has it.
  pf.rows = UI.Pool(function()
    local r = CreateFrame("Button", nil, Lc)
    r:SetSize(width, ROW_H)
    r.sel = r:CreateTexture(nil, "BACKGROUND", nil, 1)
    r.sel:SetAllPoints(); r.sel:SetColorTexture(0.72, 0.53, 0.18, 0.22)
    local hl = r:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints(); hl:SetColorTexture(1, 0.9, 0.6, 0.12)
    r.icon = UI.Round(r, "ARTWORK", 18)
    r.icon:SetPoint("LEFT", 4, 0)
    r.faces = UI.Faces(r, 18)
    r.faces:SetPoint("RIGHT", -2, 0)
    r.info = UI.Text(r, 11, "ink2", "body", "RIGHT")
    r.info:SetPoint("RIGHT", r.faces, "LEFT", -8, 0)
    r.name = UI.Text(r, 13, "ink", "title")
    r.name:SetPoint("LEFT", 28, 0); r.name:SetPoint("RIGHT", r.info, "LEFT", -6, 0)
    r.name:SetWordWrap(false)
    function r:SetSelected(on) self.sel:SetShown(on) end
    r:SetScript("OnClick", function() pf.sel = r.id; W:Refresh() end)
    return r
  end)

  -- Right: the quest's page (U264): name, zone and type, the answer, the buttons, the map, where everyone stands.
  pf.rscroll = UI.Scroll(pf.right)
  pf.rscroll:SetAllPoints()
  pf.qArt = UI.PageArt(pf.rscroll, "Quest")
  local R = pf.rscroll.child
  pf.none = UI.EmptyState(R, width)
  pf.head = UI.Heading(R, width, "", nil, 20)
  -- The answer: a line each with a gold dot.
  pf.tips = UI.Pool(function()
    local t = CreateFrame("Frame", nil, R)
    t:SetWidth(width)
    t.dot = UI.Round(t, "ARTWORK", 7)
    t.dot:SetPoint("TOPLEFT", 3, -5)
    Theme:Fill(t.dot, "gold", 1)
    t.text = UI.WrapText(t, 13, "ink", width - 18, "book")
    t.text:SetPoint("TOPLEFT", 16, 0)
    return t
  end)
  pf.ask = UI.TextButton(R, L.ASK_GROUP, function() if pf.item then Q:AskGroup(pf.item) end end, "primary")
  pf.inviteQ = UI.TextButton(R, L.INVITE_TO_GROUP, function() if pf.item then Q:InviteFor(pf.item) end end, "plain")
  pf.share = UI.TextButton(R, L.SHARE_QUEST, function() if pf.item then Q:Share(pf.item) end end, "plain")
  pf.listen = UI.TextButton(R, L.LISTEN, function() if pf.listenID then OA:Listen(pf.listenID) end end, "plain")
  UI.Tooltip(pf.listen, L.LISTEN_TIP)
  pf.shareWhy = UI.WrapText(R, 12, "ink2", width)
  pf.map = ns.BookMap.New(R, width)
  -- A single quest: where everyone stands, you first: name, the quest's bar, "3 / 8".
  pf.stands = UI.Pool(function()
    local o = CreateFrame("Frame", nil, R)
    o:SetSize(width, 22)
    o.name = UI.Text(o, 13, "ink", "title")
    o.name:SetPoint("LEFT"); o.name:SetWidth(110); o.name:SetWordWrap(false)
    o.bar = bar(o)
    o.bar:SetPoint("LEFT", 116, 0)
    o.text = UI.Text(o, 12, "ink", "body", "RIGHT")
    o.text:SetPoint("RIGHT")
    return o
  end)
  -- A chain: the step track (U264), each step a ring joined to the next by the book's bar (U262), the faces at its
  -- right, and Listen in Spoken where the step is a quest.
  pf.steps = UI.Pool(function()
    local p = CreateFrame("Frame", nil, R)
    p:SetWidth(width)
    p.link = UI.Bar(p, 8, true)
    p.link.shine:SetAlpha(0)
    p.ring = UI.Round(p, "ARTWORK", 22)
    p.ring:SetPoint("TOPLEFT", 0, 0)
    p.check = UI.Check(p, 18)
    p.check:SetTexture(ns.MARKS.done)
    p.check:SetPoint("CENTER", p.ring, "CENTER")
    p.n = UI.Text(p, 12, "white", "title", "CENTER")
    p.n:SetPoint("CENTER", p.ring, "CENTER")
    p.faces = UI.Faces(p, 18)
    p.faces:SetPoint("TOPRIGHT", 0, -2)
    p.listen = UI.RoundButton(p, 22, "listen", function() if p.qid then OA:Listen(p.qid) end end)
    UI.Tooltip(p.listen, L.LISTEN_TIP)
    p.title = UI.WrapText(p, 13, "ink", width - 34, "book")
    p.title:SetPoint("TOPLEFT", 32, -3)
    return p
  end)
  buildAttune(pf, width)
  buildLog(pf, width)
end

-- Together: single quests near your level (from 5 under it, where a quest turns grey; to join, up to what you can pick
-- up; unknown levels too), unless Show all. Chains and quests you are on have no upper limit.
local function nearChapter(_, x)
  if not x.level or x.level == 0 then return true end
  -- (Q.viewLevel: /jtf tour looks as a higher character would, as QuestLists.viewLevel does for attunements.)
  local lvl = Q.viewLevel or UnitLevel("player") or 0
  if x.level < lvl - Q.GREY_BELOW then return false end
  return not x.join or x.level <= lvl + Q.JOIN_BELOW
end

-- A row's right-hand words: "Step 2 of 5" (a chain you are on), "5 steps", "Level 8", "Finished".
local function rowInfo(x, me)
  if Q.Finished(x, me) then return L.Q_ROW_DONE end
  if x.chain then
    if x.at[me] then return L.Q_ROW_STEP:format(x.at[me] + 1, #x.steps) end
    return L.Q_ROW_STEPS:format(#x.steps)
  end
  return (x.level or 0) > 0 and L.Q_ROW_LEVEL:format(x.level) or ""
end

-- The section an item is in (U264): the first that fits.
local function section(x) return x.together and 1 or (x.join and 2 or (x.bring and 3 or nil)) end

-- The left page: the three sections by zone, Show all, History, the Questie note. Returns the items shown and how many
-- are finished (History's count).
local function refreshList(pf, f, me)
  local items, hidden, done = {}, 0, 0
  for _, x in ipairs(Q:Items(f)) do
    if section(x) then
      local fin = Q.Finished(x, me)
      local sel = x.id == pf.sel -- (Open in the book's quest shows, grey or finished too)
      if x.chain or pf.all or sel or nearChapter(f, x) then
        if fin then done = done + 1 end
        if pf.history or not fin or sel then items[#items + 1] = x end
      elseif pf.history or not fin then
        hidden = hidden + 1
      end
    end
  end
  local s = UI.Stack(pf.lscroll.child)
  local where = Q:Whereabouts()
  local RANK = { here = 0, near = 1 }
  local nRows, nLabels = 0, 0
  pf.zoneOrder = {}
  pf.empty:SetShown(#items == 0)
  if #items == 0 then s:Place(pf.empty, 16, 10) end
  for i, sec in ipairs(pf.secs) do
    local groups, byZone, count = {}, {}, 0
    for _, x in ipairs(items) do
      if section(x) == i then
        count = count + 1
        local z = x.zone or ""
        if not byZone[z] then
          byZone[z] = { label = z, rows = {}, near = Q:Nearness(z, where) }
          groups[#groups + 1] = byZone[z]
        end
        x.faces = Q:Faces(f, x)
        x.live = false
        for _, e in ipairs(x.faces) do x.live = x.live or e.online end
        table.insert(byZone[z].rows, x)
      end
    end
    table.sort(groups, function(a, b)
      local ra, rb = RANK[a.near] or (a.label == "" and 3 or 2), RANK[b.near] or (b.label == "" and 3 or 2)
      if ra ~= rb then return ra < rb end
      return a.label < b.label
    end)
    sec.head:SetShown(count > 0)
    if count > 0 then
      sec.head:SetText(L["Q_SECTION_" .. sec.key] .. "  ·  " .. count)
      s:Place(sec.head, 29, 6)
    end
    for _, g in ipairs(groups) do
      local lab = pf.groupLabels:Get(nLabels + 1)
      if not lab then break end
      nLabels = nLabels + 1
      lab.text:SetText(g.label ~= "" and g.label or L.Q_ZONE_UNKNOWN)
      lab.tag:SetText(g.near == "here" and L.Q_ZONE_HERE or (g.near == "near" and L.Q_ZONE_NEAR or ""))
      lab.tag:SetTextColor(Theme:RGBA(g.near == "here" and "3E7A3A" or "ink2"))
      lab.pin:SetShown(g.near == "here")
      pf.zoneOrder[#pf.zoneOrder + 1] = { sec = i, near = g.near }
      s:Place(lab, 20, 3)
      -- In a zone, a quest with an Adventurer online first, then by name.
      table.sort(g.rows, function(a, b)
        if a.live ~= b.live then return a.live end
        if a.name ~= b.name then return a.name < b.name end
        return a.id < b.id
      end)
      for _, x in ipairs(g.rows) do
        local r = pf.rows:Get(nRows + 1)
        if not r then break end
        nRows = nRows + 1
        r.id = x.id
        UI.SetIcon(r.icon, ns.ICONS[x.chain and "bn_chain" or "bn_quest"])
        r.name:SetText(x.name)
        r.info:SetText(rowInfo(x, me))
        r.faces:Set(x.faces)
        s:Place(r, ROW_H, 2)
      end
      s:Skip(6)
    end
    if count > 0 then s:Skip(8) end
  end
  pf.rows:HideFrom(nRows + 1)
  pf.groupLabels:HideFrom(nLabels + 1)
  -- Quests far from your level: Show all / Show only quests near your level.
  local toggle = hidden > 0 or pf.all
  pf.showAll:SetShown(toggle)
  if toggle then
    pf.showAll:SetLabel(pf.all and L.Q_SHOW_NEAR or L.Q_SHOW_ALL:format(hidden))
    s:Place(pf.showAll, 20, 4)
  end
  -- What you have finished: History / Hide history (U188), only while there is some.
  pf.showDone:SetShown(done > 0)
  if done > 0 then
    pf.showDone:SetLabel(pf.history and L.Q_HIDE_DONE or L.Q_SHOW_DONE:format(done))
    s:Place(pf.showDone, 20, 4)
  end
  -- (No note while Questie runs, U195.)
  local state = Q:QuestieState()
  local note = state ~= "on" and not ns.db.questieHintHidden and (state == "off" and L.Q_QUESTIE_OFF or L.Q_QUESTIE_GET)
  pf.questie:SetShown(note ~= false)
  if note then
    pf.questie.text:SetText(note)
    local h = math.max(22, pf.questie.text:GetStringHeight())
    pf.questie:SetHeight(h)
    s:Skip(6)
    s:Place(pf.questie, h, 10)
  end
  pf.lscroll:SetContentHeight(s.y + 8)
  return items, done
end

-- A chain's step track on the stack r (U264): rings joined by the book's bar, green up to your step.
local STEP_GAP = 8
local function placeSteps(pf, r, f, x, d, width)
  local light = Theme:Current().light
  for i, st in ipairs(d.steps) do
    local p = pf.steps:Get(i)
    if not p then break end
    p.ring:SetColorTexture(ns.Hex(st.you and (light and "B8742A" or "D8A850") or (st.done and "3E7A3A" or "7A6A55")))
    p.check:SetShown(st.done); p.n:SetShown(not st.done)
    p.n:SetText(st.n)
    local faces = {}
    for _, name in ipairs(st.on) do faces[#faces + 1] = Q:Face(f, name, x.zone) end
    for _, name in ipairs(st.could) do faces[#faces + 1] = Q:Face(f, name, x.zone, true) end
    local fw = p.faces:Set(faces)
    local room = fw > 0 and fw + 6 or 0
    p.qid = st.id
    p.listen:SetShown(st.id ~= nil)
    p.listen:ClearAllPoints(); p.listen:SetPoint("TOPRIGHT", -room, 0)
    p.title:SetWidth(width - 32 - room - (st.id and 28 or 0))
    p.title:SetText(st.title)
    local h = math.max(24, p.title:GetStringHeight() + 6)
    p:SetHeight(h)
    p.link:SetShown(i < #d.steps)
    if i < #d.steps then
      p.link:ClearAllPoints(); p.link:SetPoint("TOP", p.ring, "BOTTOM", 0, 1)
      p.link:SetHeight(h - 22 + STEP_GAP + 2)
      p.link:SetColor("3E7A3A")
      p.link:Set(8, st.done and 1 or 0)
    end
    r:Place(p, h, STEP_GAP)
  end
  pf.steps:HideFrom(#d.steps + 1)
end

-- Places the buttons in one row, wrapping, on the stack r.
local function placeButtons(pf, r, buttons, width)
  if #buttons == 0 then return end
  local x, rowY = 0, r.y
  for _, b in ipairs(buttons) do
    if x > 0 and x + b:GetWidth() > width then x, rowY = 0, rowY + 34 end
    b:ClearAllPoints(); b:SetPoint("TOPLEFT", pf.rscroll.child, "TOPLEFT", x, -rowY)
    x = x + b:GetWidth() + 8
  end
  r.y = rowY + 32
end

local function refresh(pf, ctx)
  local f = ctx.f
  if not f then return end
  local width = ns.Window.PAGE_W - 8
  local me = ctx.me
  pf.tabs:Refresh()
  local attune, log = pf.tab == "attune", pf.tab == "dungeons"
  pf.lscroll:SetShown(not attune and not log); pf.rscroll:SetShown(not attune and not log)
  pf.alscroll:SetShown(attune); pf.arscroll:SetShown(attune)
  pf.log[1].scroll:SetShown(log); pf.log[2].scroll:SetShown(log)
  if attune then return refreshAttune(pf, f, me) end
  if log then return refreshLog(pf, f, me) end
  local items, done = refreshList(pf, f, me)
  -- The chosen item: the one clicked (or opened from the game's quest log, U268), else the first done together, else
  -- the first.
  local pick
  for _, x in ipairs(items) do if x.id == pf.sel then pick = x end end
  if not pick then for _, x in ipairs(items) do if x.together and not pick then pick = x end end end
  pick = pick or items[1]
  pf.item = pick
  for _, row in ipairs(pf.rows.items) do row:SetSelected(pick ~= nil and row.id == pick.id) end

  local r = UI.Stack(pf.rscroll.child)
  local show = pick ~= nil
  pf.none:SetShown(not show); pf.head:SetShown(show)
  local nTips, mapH = 0, 0
  if not show then
    pf.ask:Hide(); pf.inviteQ:Hide(); pf.share:Hide(); pf.shareWhy:Hide(); pf.listen:Hide(); pf.map:Hide()
    pf.stands:HideFrom(1); pf.steps:HideFrom(1)
    r:Skip(60)
    -- All of it near your level finished, under History; one far from your level waits under Show all.
    local fin = done > 0
    r:Place(pf.none, pf.none:Set(ns.ICONS.bn_quest, fin and L.Q_ALL_DONE or L.Q_NONE,
      fin and L.Q_ALL_DONE_TEXT or L.Q_EMPTY_TEXT, nil, nil, "EmptyQuests"), 4)
  else
    local d = Q:Detail(pick)
    -- (A chain may have no zone: no "·" in front of its type then.)
    pf.head:Set(d.title, ((d.line or "") ~= "" and (d.line .. "  ·  ") or "") .. d.type)
    r:Place(pf.head, pf.head:GetHeight(), 2)
    -- The answer.
    for i, text in ipairs(d.tips) do
      local t = pf.tips:Get(i)
      if not t then break end
      nTips = i
      t.text:SetText(text)
      local h = t.text:GetStringHeight() + 4
      t:SetHeight(h)
      r:Place(t, h, 4)
    end
    -- Ask to group up and Invite to group (others on it, else who could join you), Share quest (in my log), Listen.
    local buttons, ask, invite = {}, #Q.AskList(pick) > 0, #pick.others > 0
    pf.ask:SetShown(ask); pf.inviteQ:SetShown(invite)
    if ask then buttons[#buttons + 1] = pf.ask end
    if invite then buttons[#buttons + 1] = pf.inviteQ end
    local share = Q:ShareState(pick)
    pf.share:SetShown(share ~= nil)
    pf.share:SetEnabled(share == "ok")
    if share then buttons[#buttons + 1] = pf.share end
    pf.listenID = Q.QuestID(pick)
    pf.listen:SetShown(pf.listenID ~= nil)
    if pf.listenID then buttons[#buttons + 1] = pf.listen end
    if #buttons > 0 then r:Skip(6) end
    placeButtons(pf, r, buttons, width)
    pf.shareWhy:SetShown(share == "group" or share == "no")
    if pf.shareWhy:IsShown() then
      pf.shareWhy:SetText(share == "group" and L.SHARE_WHY_GROUP or L.SHARE_WHY_NO)
      r:Place(pf.shareWhy, pf.shareWhy:GetStringHeight(), 2)
    end
    -- The map (U267): none where the game has no art for the zone.
    local plan = Q:MapPlan(pick)
    mapH = plan and pf.map:Fill({ map = plan.map, title = pick.name, marks = plan.marks, who = plan.who,
      target = plan.target }) or 0
    if mapH > 0 then r:Skip(10); r:Place(pf.map, mapH, 4) else pf.map:Hide() end
    -- Where everyone stands.
    r:Skip(10)
    if d.chain then
      pf.stands:HideFrom(1)
      placeSteps(pf, r, f, pick, d, width)
    else
      pf.steps:HideFrom(1)
      for i, o in ipairs(d.rows) do
        local row = pf.stands:Get(i)
        if not row then break end
        row.name:SetText(o.name == me and L.YOU_LABEL or ns.Short(o.name))
        row.name:SetTextColor(inkFor(f, o.name))
        local goal = o.goal or 0
        row.bar:Set(width - 116 - 60, goal > 0 and o.have / goal or 0, goal > 0 and o.have >= goal,
          goal > 0 and goal <= UI.BAR_PIPS_MAX and goal or nil)
        row.text:SetText(goal > 0 and (o.have .. " / " .. goal) or "")
        r:Place(row, 22, 4)
      end
      pf.stands:HideFrom(#d.rows + 1)
    end
  end
  pf.tips:HideFrom(nTips + 1)
  pf.rscroll:SetContentHeight(r.y + 8)
  -- The page's drawing at the foot only where no map shows (U267; the empty state has its own sketch).
  pf.qArt:Fit((show and mapH == 0) and r.y or math.huge)
end

-- Titled Quests, with no line under it (U146).
ns.Pages:Register({ id = "quests", label = L.NAV_QUESTS, build = build, refresh = refresh, news = { quests = true },
  title = function() return L.TITLE_QUESTS, "" end })
