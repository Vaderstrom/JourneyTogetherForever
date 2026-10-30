-- Chapter (SPEC §4.5). Left: chapter number with previous/next, name, levels, the stage track with one line of
-- What's next, the stage (a waiting box while below the floor, else the status banner), an over-the-cap warning and
-- the dungeons as rows (Dungeon Journal, Find group, Mark cleared, Undo clear), or the chapter's picture when it has
-- none. Right: where the Heroes stand and the Dungeon clears table (Hero × dungeon; the leader clicks a cell to
-- change it).
local _, ns = ...
local L = ns.L
local UI, Theme = ns.UI, ns.Theme
local J, Hr, P, Cl = ns.Journey, ns.Hero, ns.Permissions, ns.Clears
local OA = ns.OtherAddons

local CELL_W, NAME_W, HEAD_H = 34, 110, 32
-- A dungeon row and its picture: five rows fit on the page without scrolling (28 Oct 2026).
local ROW_H, THUMB_W, THUMB_H = 50, 66, 40
local BIG_PIC_H = 170 -- the chapter's picture when it has no dungeons
local TRACK_H, NODE_W = 48, 124 -- the stage track and one node in it (four fit the page)
-- Node colours: done, still to do (the current one takes the banner's colour).
local NODE_DONE, NODE_TODO = "3E7A3A", "line"

-- The mockup's short column names: "The Deadmines" → "Deadmines", "SM: Library" → "Library".
local function short(name)
  local s = name:gsub("^The ", ""):gsub("^SM: ", ""):gsub("^Blackrock Depths: ", "")
  return s:match("^[^ :]+") or s
end

local function build(pf)
  local W = ns.Window
  local width = W.PAGE_W - 8

  pf.lscroll = UI.Scroll(pf.left)
  pf.lscroll:SetAllPoints()
  local Lc = pf.lscroll.child
  pf.nav = CreateFrame("Frame", nil, Lc)
  pf.nav:SetSize(width, 26)
  pf.prev = CreateFrame("Button", nil, pf.nav)
  pf.prev:SetSize(26, 26); pf.prev:SetPoint("LEFT")
  pf.prev:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up")
  pf.prev:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Down")
  pf.prev:SetDisabledTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Disabled")
  pf.prev:SetScript("OnClick", function() pf.sel = (pf.shown or 1) - 1; W:Refresh() end)
  pf.num = UI.Text(pf.nav, 12, "ink2", "body", "CENTER")
  pf.num:SetPoint("CENTER")
  pf.next = CreateFrame("Button", nil, pf.nav)
  pf.next:SetSize(26, 26); pf.next:SetPoint("RIGHT")
  pf.next:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
  pf.next:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Down")
  pf.next:SetDisabledTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Disabled")
  pf.next:SetScript("OnClick", function() pf.sel = (pf.shown or 1) + 1; W:Refresh() end)
  pf.name = UI.Text(Lc, 22, "ink", "title", "CENTER")
  pf.name:SetWidth(width)
  pf.line = UI.WrapText(Lc, 12, "ink2", width) -- wraps: the run rule made it too long for one line
  pf.line:SetJustifyH("CENTER")
  pf.banner = UI.StatusBanner(Lc, width)
  pf.over = UI.Card(Lc, "C0392B")
  pf.over:SetWidth(width)
  pf.overText = UI.WrapText(pf.over, 13, "B0321E", width - 24)
  pf.overText:SetPoint("TOPLEFT", 12, -9)
  -- The stage track (28 Oct 2026, from the in-game test: the stage should be the centre of the page): every stage of
  -- the chapter as a node, done ones ticked, the current one in the banner's colour.
  pf.track = CreateFrame("Frame", nil, Lc)
  pf.track:SetSize(width, TRACK_H)
  pf.nodes = UI.Pool(function()
    local n = CreateFrame("Frame", nil, pf.track)
    n:SetSize(NODE_W, TRACK_H)
    -- The stage the chapter is at has a soft halo in its colour (the visual pass, 28 Oct 2026).
    n.glow = UI.Round(n, "BACKGROUND", 34)
    n.ring = UI.Round(n, "ARTWORK", 26)
    n.ring:SetPoint("TOP", 0, -2)
    n.glow:SetPoint("CENTER", n.ring)
    n.inner = UI.Round(n, "ARTWORK", 22, 1)
    n.inner:SetPoint("CENTER", n.ring)
    n.num = UI.Text(n, 12, "white", "title", "CENTER")
    n.num:SetPoint("CENTER", n.ring, "CENTER", 0, 0)
    n.check = UI.Check(n, 18)
    n.check:SetPoint("CENTER", n.ring)
    -- One line: a second one ran into the line under the track ("Run the / dungeons"; seen in game, 28 Oct 2026).
    n.label = UI.Text(n, 11, "ink2", "body", "CENTER")
    n.label:SetWidth(NODE_W - 4)
    n.label:SetWordWrap(false)
    n.label:SetPoint("TOP", n.ring, "BOTTOM", 0, -4)
    return n
  end)
  pf.links = UI.Pool(function() local t = pf.track:CreateTexture(nil, "BORDER"); t:SetHeight(2); return t end)
  -- One line from What's next, under the track (the list stays on the Overview; the stage and the dungeon rows say
  -- the rest).
  pf.nextLine = CreateFrame("Frame", nil, Lc)
  pf.nextLine:SetWidth(width)
  pf.nextLine.icon = UI.Round(pf.nextLine, "ARTWORK", 16)
  pf.nextLine.icon:SetPoint("TOPLEFT", 2, 0)
  pf.nextLine.text = UI.WrapText(pf.nextLine, 13, "ink", width - 28, "book")
  pf.nextLine.text:SetPoint("TOPLEFT", 26, -1)
  -- While waiting for the floor: a box in the middle with who is below it, their level and how far they have to go.
  pf.wait = UI.Card(Lc, "B8742A")
  pf.wait:SetWidth(width)
  pf.wait.title = UI.Text(pf.wait, 16, "B8742A", "title", "CENTER")
  pf.wait.title:SetPoint("TOP", 0, -10)
  pf.wait.title:SetText(L.BN_WAITING)
  pf.wait.rows = UI.Pool(function()
    local r = CreateFrame("Frame", nil, pf.wait)
    r:SetSize(width - 40, 36)
    r.name = UI.Text(r, 13, "ink", "title")
    r.name:SetPoint("TOPLEFT", 0, 0)
    r.lvl = UI.Text(r, 12, "ink2", "body", "RIGHT")
    r.lvl:SetPoint("TOPRIGHT", 0, -1)
    r.bar = UI.Bar(r, 8)
    r.bar:SetPoint("TOPLEFT", 0, -16)
    r.bar:SetColor("D88A2E")
    r.far = UI.Text(r, 11, "ink2")
    r.far:SetPoint("TOPLEFT", 0, -26)
    r.far:SetWidth(width - 40); r.far:SetWordWrap(false)
    return r
  end)
  pf.wait.more = UI.Text(pf.wait, 12, "ink2", "body", "CENTER")
  pf.wait.help = UI.WrapText(pf.wait, 12, "ink2", width - 40, "book")
  pf.wait.help:SetJustifyH("CENTER")
  pf.wait.help:SetText(L.CH_WAIT_HELP)
  pf.div = UI.Divider(Lc)
  pf.dHead = UI.Text(Lc, 12, "ink2")
  -- A dungeon as one row (28 Oct 2026: the picture cards took a page each and the dungeons had to be scrolled): a
  -- small picture, name, kind and levels, and at the right its state or Find group. The rest is in the tooltip.
  pf.rows = UI.Pool(function()
    local c = UI.Card(Lc)
    c:SetSize(width, ROW_H)
    c:EnableMouse(true)
    -- The role's colour down the row's left edge (and its border): mandatory, bridge, optional at a glance.
    c.stripe = c:CreateTexture(nil, "ARTWORK", nil, 3)
    c.stripe:SetPoint("TOPLEFT", 1, -1); c.stripe:SetPoint("BOTTOMLEFT", 1, 1); c.stripe:SetWidth(4)
    -- The dungeon's picture (its loading screen); a click opens the DungeonJournal addon.
    c.pic = CreateFrame("Button", nil, c)
    c.pic:SetSize(THUMB_W, THUMB_H); c.pic:SetPoint("LEFT", 9, 0)
    c.pic.bg = c.pic:CreateTexture(nil, "BACKGROUND")
    c.pic.bg:SetAllPoints(); c.pic.bg:SetColorTexture(0.1, 0.07, 0.04, 1)
    c.pic.tex = c.pic:CreateTexture(nil, "ARTWORK")
    c.pic.tex:SetAllPoints()
    local phl = c.pic:CreateTexture(nil, "HIGHLIGHT")
    phl:SetAllPoints(); phl:SetColorTexture(1, 0.9, 0.6, 0.15)
    c.pic:SetScript("OnClick", function() W:DungeonJournal(c.key) end)
    c.mark = UI.Mark(c.pic, 14)
    c.mark:SetPoint("BOTTOMLEFT", 2, 2)
    c.name = UI.Text(c, 14, "ink", "title")
    c.name:SetPoint("TOPLEFT", THUMB_W + 18, -9)
    c.name:SetWordWrap(false)
    c.sub = UI.Text(c, 11, "ink2")
    c.sub:SetPoint("TOPLEFT", c.name, "BOTTOMLEFT", 0, -3)
    c.sub:SetWordWrap(false)
    c.state = UI.Text(c, 12, nil, "body", "RIGHT")
    -- Everything else about the dungeon on hover: who ran it, what is missing, quests picked up.
    c:SetScript("OnEnter", function()
      GameTooltip:SetOwner(c, "ANCHOR_RIGHT")
      for i, line in ipairs(c.tip or {}) do
        if i == 1 then GameTooltip:SetText(line) else GameTooltip:AddLine(line, 0.9, 0.85, 0.7, true) end
      end
      GameTooltip:Show()
    end)
    c:SetScript("OnLeave", function() GameTooltip:Hide() end)
    -- The Dungeon Journal as a book icon (a symbol, as in the first mockup; the text button was wide).
    c.dj = UI.RoundButton(c, 26, "journal", function() W:DungeonJournal(c.key) end)
    UI.Tooltip(c.dj, L.DUNGEON_JOURNAL)
    -- The dungeon's story in Lore Forever, while it runs (UI/OtherAddons.lua).
    c.lore = UI.RoundButton(c, 26, "lore", function() OA:Lore(c.key) end)
    UI.Tooltip(c.lore, L.LORE_TIP)
    c.group = UI.TextButton(c, L.FIND_GROUP, function()
      local f = ns.Fellowship:Current()
      if f and c.key then ns.Together:FindGroup(f, c.key) end
    end, "primary", 12)
    -- Mark cleared and Undo clear (leader, or officers if allowed) in a "⋯" menu: the card keeps one main button.
    c.menu = UI.MenuButton(c, function()
      local f, list = ns.Fellowship:Current(), {}
      if not f or not c.key or not P.Can(f, ns.Me(), "clears") then return list end
      if J:DungeonState(f, nil, { key = c.key }) ~= "cleared" then list[#list + 1] = { L.MARK_CLEARED, function() Cl:Mark(c.key) end } end
      if next(J:ClearedBy(f, c.key)) then
        list[#list + 1] = { L.UNDO_CLEAR, function()
          local name = ns.Dungeon(c.key)[2]
          -- The leader's undo of a clear an earlier chapter needs reopens that chapter: the question says so.
          local back = f.leader == ns.Me() and J:ReopensChapter(f, c.key)
          local text = back and L.UNDO_CONFIRM_REOPEN:format(name, J.Roman(back), f.journey.chapters[back].name) or L.UNDO_CONFIRM:format(name)
          W:Confirm(text, L.UNDO_CLEAR, function() Cl:Undo(c.key) end)
        end, true }
      end
      return list
    end)
    return c
  end)
  -- A chapter without dungeons (the Prologue): its picture fills the place of the dungeons (the page was empty; seen
  -- in the in-game test).
  pf.none = CreateFrame("Frame", nil, Lc)
  pf.none:SetSize(width, BIG_PIC_H)
  pf.none.bg = pf.none:CreateTexture(nil, "BACKGROUND")
  pf.none.bg:SetAllPoints(); pf.none.bg:SetColorTexture(0.1, 0.07, 0.04, 1)
  pf.none.pic = pf.none:CreateTexture(nil, "ARTWORK")
  pf.none.pic:SetPoint("TOPLEFT", 2, -2); pf.none.pic:SetPoint("BOTTOMRIGHT", -2, 2)
  local fade = pf.none:CreateTexture(nil, "ARTWORK", nil, 2)
  fade:SetPoint("BOTTOMLEFT", 2, 2); fade:SetPoint("BOTTOMRIGHT", -2, 2); fade:SetHeight(math.floor(BIG_PIC_H * 0.5))
  UI.SetGradient(fade, "VERTICAL", { 0.05, 0.03, 0.01, 0.92 }, { 0.05, 0.03, 0.01, 0 })
  pf.none.border = UI.Box(pf.none, 2, nil, nil, "gold", 0.85)
  pf.none.border:SetAllPoints()
  pf.none.text = UI.WrapText(pf.none, 14, "chipText", width - 28, "book")
  pf.none.text:SetPoint("BOTTOMLEFT", 14, 12)
  pf.none.text:SetShadowOffset(1, -1); pf.none.text:SetShadowColor(0, 0, 0, 1)
  -- Milestones (Rules/Milestones.lua): each with its mark, Required or Optional, how far, and Tick off by hand.
  pf.msHead = UI.SectionHeader(Lc, width)
  pf.msHead:SetText(L.MS_HEAD)
  pf.msHelp = UI.WrapText(Lc, 12, "ink2", width)
  pf.msHelp:SetText(L.MS_HEAD_HELP)
  pf.msRows = UI.Pool(function()
    local r = CreateFrame("Frame", nil, Lc)
    r:SetSize(width, 40)
    r.mark = UI.Mark(r, 14)
    r.mark:SetPoint("TOPLEFT", 2, -3)
    r.name = UI.WrapText(r, 13, "ink", width - 120, "title")
    r.name:SetPoint("TOPLEFT", 22, 0)
    r.sub = UI.Text(r, 11, "ink2")
    r.tick = UI.TextButton(r, L.MS_TICK, function()
      local f = ns.Fellowship:Current()
      if f and r.id then ns.Fellowship:Tick(r.id, not r.done) end
    end, "plain", 12)
    r.tick:SetPoint("TOPRIGHT", 0, 0)
    return r
  end)

  pf.rscroll = UI.Scroll(pf.right)
  pf.rscroll:SetAllPoints()
  local R = pf.rscroll.child
  pf.head = UI.Heading(R, width, L.WHERE_STAND, nil)
  pf.stand = UI.Standings(R, width)

  -- Dungeon clears: a card with a header row (Hero, dungeons) and one row per Hero.
  pf.mTitle = UI.SectionHeader(R, width)
  pf.mTitle:SetText(L.CLEARS_TABLE)
  pf.matrix = UI.Card(R)
  pf.matrix:SetWidth(width)
  local M = pf.matrix
  M.headBg = UI.Solid(M, "BORDER", "line", 0.25)
  M.headBg:SetPoint("TOPLEFT", 3, -3); M.headBg:SetPoint("TOPRIGHT", -3, -3); M.headBg:SetHeight(HEAD_H)
  M.heroHead = UI.Text(M, 12, "ink2")
  M.heroHead:SetPoint("TOPLEFT", 10, -(HEAD_H / 2 - 3))
  M.heroHead:SetText(L.MATRIX_HERO)
  -- Column heads: each dungeon's picture in a small gold ring (cut names like "Dea..." said little; seen in the
  -- tour). The name is in the tooltip.
  M.cols = UI.Pool(function()
    local b = CreateFrame("Button", nil, M)
    b:SetSize(CELL_W, HEAD_H)
    b.ring = UI.Round(b, "ARTWORK", 26)
    b.ring:SetPoint("CENTER"); Theme:Fill(b.ring, "gold", 0.9)
    b.pic = UI.Round(b, "OVERLAY", 22)
    b.pic:SetPoint("CENTER")
    b.text = UI.Text(b, 11, "ink2", "body", "CENTER")
    b.text:SetPoint("CENTER")
    b:SetScript("OnEnter", function()
      GameTooltip:SetOwner(b, "ANCHOR_TOP")
      GameTooltip:SetText(b.full or "")
      GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return b
  end)
  M.rows = UI.Pool(function()
    local r = CreateFrame("Frame", nil, M)
    r:SetSize(width - 6, 24)
    r.line = UI.Solid(r, "BORDER", "line", 0.5)
    r.line:SetHeight(1); r.line:SetPoint("TOPLEFT"); r.line:SetPoint("TOPRIGHT")
    r.name = UI.Text(r, 13, "ink", "title")
    r.name:SetPoint("LEFT", 7, 0)
    r.name:SetWidth(NAME_W - 10)
    r.cells = UI.Pool(function()
      local b = CreateFrame("Button", nil, r)
      b:SetSize(CELL_W, 22)
      b.check = UI.Check(b, 16)
      b.check:SetTexture(ns.MARKS.cleared)
      b.check:SetPoint("CENTER")
      -- Not cleared: an empty ring (a dot was nearly invisible; seen in the UI tour).
      b.dot = CreateFrame("Frame", nil, b)
      b.dot:SetSize(12, 12); b.dot:SetPoint("CENTER")
      local ring = UI.Round(b.dot, "ARTWORK", 12)
      ring:SetPoint("CENTER"); Theme:Fill(ring, "ink2", 0.7)
      local hole = UI.Round(b.dot, "OVERLAY", 8)
      hole:SetPoint("CENTER"); Theme:Fill(hole, "page1", 1)
      b.hl = b:CreateTexture(nil, "HIGHLIGHT")
      b.hl:SetAllPoints(); b.hl:SetColorTexture(1, 0.9, 0.6, 0.15)
      b:SetScript("OnClick", function() if b.can then Cl:Toggle(b.key, b.name) end end)
      b:SetScript("OnEnter", function()
        GameTooltip:SetOwner(b, "ANCHOR_TOP")
        GameTooltip:SetText(b.label or "")
        GameTooltip:Show()
      end)
      b:SetScript("OnLeave", function() GameTooltip:Hide() end)
      return b
    end)
    return r
  end)
  pf.mKey = UI.Pool(function()
    local k = CreateFrame("Frame", nil, R)
    k:SetHeight(20)
    k.ring = UI.Round(k, "ARTWORK", 20)
    k.ring:SetPoint("LEFT", 6, 0); Theme:Fill(k.ring, "gold", 0.9)
    k.pic = UI.Round(k, "OVERLAY", 16)
    k.pic:SetPoint("CENTER", k.ring)
    k.name = UI.Text(k, 12, "ink2")
    k.name:SetPoint("LEFT", 32, 0); k.name:SetPoint("RIGHT")
    return k
  end)
  pf.mHelp = UI.WrapText(R, 12, "ink2", width)
end

-- The Dungeon clears table for the dungeons in list (Heroes by level, highest first).
local function refreshMatrix(pf, ctx, list, r, width)
  local f = ctx.f
  local M = pf.matrix
  local show = #list > 0
  pf.mTitle:SetShown(show); M:SetShown(show); pf.mHelp:SetShown(show)
  if not show then pf.mKey:HideFrom(1) return end
  local light = Theme:Current().light
  -- Watching an alt's fellowship (Fellowship/Watch.lua): to read, not to change.
  local can = P.Can(f, ctx.me, "clears") and not ctx.watching
  local cw = math.min(CELL_W, math.floor((width - NAME_W - 8) / #list))
  r:Skip(8)
  r:Place(pf.mTitle, 29, 6)
  local nCols = 0
  for i, x in ipairs(list) do
    local col = M.cols:Get(i)
    if not col then break end
    nCols = i
    col:SetWidth(cw)
    -- Narrow columns cut the name short instead of running into the next one; the full name is in the tooltip.
    col.text:SetWidth(cw - 2)
    local ok = ns.SetDungeonArt(col.pic, x.key, 22, 22)
    col.pic:SetShown(ok); col.ring:SetShown(ok)
    col.text:SetText(ok and "" or short(x.d[2]))
    col.full = x.d[2]
    col:ClearAllPoints(); col:SetPoint("TOPLEFT", M, "TOPLEFT", NAME_W + (i - 1) * cw, -3)
    col:Show()
  end
  M.cols:HideFrom(nCols + 1)
  local heroes = {}
  for name in pairs(f.members) do heroes[#heroes + 1] = name end
  table.sort(heroes, function(a, b)
    local la, lb = Hr:Level(f, a), Hr:Level(f, b)
    if la ~= lb then return la > lb end
    return a < b
  end)
  local y, nRows = HEAD_H + 3, 0
  for i, name in ipairs(heroes) do
    local row = M.rows:Get(i)
    if not row then break end
    nRows = i
    row:ClearAllPoints(); row:SetPoint("TOPLEFT", M, "TOPLEFT", 3, -y); row:Show()
    row.name:SetText(ns.Short(name))
    local _, token = Hr:ClassName(f, name)
    local ink = ns.ClassHex(token, light)
    if ink then row.name:SetTextColor(ns.Hex(ink)) else row.name:SetTextColor(Theme:RGBA("ink")) end
    local nCells = 0
    for k, x in ipairs(list) do
      local b = row.cells:Get(k)
      if not b then break end
      nCells = k
      local has = J:ClearedBy(f, x.key)[name] ~= nil
      b:SetWidth(cw)
      b.check:SetShown(has); b.dot:SetShown(not has)
      b.key, b.name, b.can = x.key, name, can
      b.label = (has and L.CELL_CLEARED or L.CELL_NOT):format(ns.Short(name), x.d[2])
      b:EnableMouse(true)
      b.hl:SetShown(can)
      b:ClearAllPoints(); b:SetPoint("LEFT", row, "LEFT", NAME_W - 3 + (k - 1) * cw, 0); b:Show()
    end
    row.cells:HideFrom(nCells + 1)
    y = y + 24
  end
  M.rows:HideFrom(nRows + 1)
  M:SetHeight(y + 4)
  r:Place(M, y + 4, 6)
  -- The key under the table: each column's picture with its name, two to a line (the pictures alone needed a
  -- mouse-over to tell which dungeon is which; seen in the tour).
  local half, nKey = math.floor(width / 2), 0
  for i, x in ipairs(list) do
    local k = pf.mKey:Get(i)
    if not k then break end
    nKey = i
    k:SetWidth(half - 4)
    local ok = ns.SetDungeonArt(k.pic, x.key, 18, 18)
    k.pic:SetShown(ok); k.ring:SetShown(ok)
    k.name:SetText(x.d[2])
    r:Place(k, 0, 0, (i % 2 == 0) and half or 0)
    if i % 2 == 0 or i == #list then r:Skip(22) end
  end
  pf.mKey:HideFrom(nKey + 1)
  r:Skip(4)
  pf.mHelp:SetText(can and L.MATRIX_HELP or (ctx.watching and L.MATRIX_HELP_WATCH or L.MATRIX_HELP_NO))
  r:Place(pf.mHelp, pf.mHelp:GetStringHeight(), 4)
end

-- The stage track: nodes spread across the page, centred, joined by lines.
local function layoutTrack(pf, nodes, color, width)
  local n = #nodes
  local nodeW = math.min(NODE_W, math.floor(width / math.max(1, n)))
  local x0 = math.floor((width - nodeW * n) / 2)
  for i, x in ipairs(nodes) do
    local node = pf.nodes:Get(i)
    if not node then break end
    node:SetWidth(nodeW)
    node.label:SetWidth(nodeW - 4)
    node:ClearAllPoints(); node:SetPoint("TOPLEFT", pf.track, "TOPLEFT", x0 + (i - 1) * nodeW, 0)
    local ring = x.state == "done" and NODE_DONE or (x.state == "current" and color or NODE_TODO)
    node.ring:SetColorTexture(Theme:RGBA(ring, x.state == "todo" and 0.8 or 1))
    node.glow:SetShown(x.state == "current")
    if x.state == "current" then node.glow:SetColorTexture(Theme:RGBA(ring, 0.28)) end
    node.inner:SetColorTexture(Theme:RGBA(x.state == "todo" and "card" or ring, 1))
    node.check:SetShown(x.state == "done")
    node.num:SetShown(x.state ~= "done")
    node.num:SetText(tostring(i))
    node.num:SetTextColor(Theme:RGBA(x.state == "todo" and "ink2" or "white"))
    node.label:SetText(x.label)
    node.label:SetTextColor(Theme:RGBA(x.state == "current" and "ink" or "ink2", x.state == "todo" and 0.8 or 1))
    node.state = x.state
    node:Show()
    -- The line to the next node, from ring edge to ring edge; green once this stage is done.
    if i < n then
      local link = pf.links:Get(i)
      if link then
        local cx = x0 + (i - 1) * nodeW + nodeW / 2
        link:ClearAllPoints(); link:SetPoint("TOPLEFT", pf.track, "TOPLEFT", cx + 16, -14)
        link:SetWidth(nodeW - 32)
        link:SetColorTexture(Theme:RGBA(x.state == "done" and NODE_DONE or NODE_TODO, 0.9))
        link:SetHeight(x.state == "done" and 3 or 2)
        link:Show()
      end
    end
  end
  pf.nodes:HideFrom(n + 1)
  pf.links:HideFrom(math.max(1, n))
end

-- The waiting box: who is below the floor (two with a bar and how far they are, the rest on one line).
-- Returns its height.
local function fillWait(pf, f, ch, below, width)
  local box = pf.wait
  local fl = J:FloorLevel(f, ch)
  local y, shown = 34, 0
  for i, name in ipairs(below) do
    if i > 2 then break end
    local r = box.rows:Get(i)
    if not r then break end
    shown = i
    local h = Hr:Get(f, name) or {}
    local lvl = Hr:Level(f, name)
    local part = (tonumber(h.xp) and tonumber(h.xpMax) and h.xpMax > 0) and (h.xp / h.xpMax) or 0
    r.name:SetText(name == ns.Me() and (L.NAME_YOU:gsub("^%l", string.upper)) or ns.Short(name))
    r.lvl:SetText(L.CH_WAIT_LEVEL:format(lvl, fl))
    r.bar:Set(width - 40, ns.Clamp((lvl + part) / fl, 0, 1))
    r.far:SetText(ns.Together.HowFar(f, name, fl, name == ns.Me()))
    r:ClearAllPoints(); r:SetPoint("TOP", box, "TOP", 0, -y)
    r:Show()
    y = y + 40
  end
  box.rows:HideFrom(shown + 1)
  box.more:SetShown(#below > 2)
  if #below > 2 then
    local rest = {}
    for i = 3, #below do
      local name = below[i]
      rest[#rest + 1] = ("%s (%d)"):format(name == ns.Me() and L.NAME_YOU or ns.Short(name), Hr:Level(f, name))
    end
    box.more:SetText(L.CH_WAIT_MORE:format(table.concat(rest, ", ")))
    box.more:ClearAllPoints(); box.more:SetPoint("TOP", box, "TOP", 0, -y)
    y = y + 20
  end
  box.help:ClearAllPoints(); box.help:SetPoint("TOP", box, "TOP", 0, -(y + 2))
  y = y + 2 + box.help:GetStringHeight() + 10
  box:SetHeight(y)
  return y
end

-- The one line of What's next under the track: the first step the stage and the dungeon rows do not already say.
local SAID = { waiting = true, level = true, dungeon = true, done = true }
local function nextStep(f)
  for _, step in ipairs(J:NextSteps(f)) do
    if not SAID[step.kind] then return step end
  end
end

-- A dungeon's short state for its row ("4 of 7 bosses", "2 still need it") and the lines of its tooltip.
local function rowTexts(f, x, st, roleText, counted)
  local who = J:ClearedBy(f, x.key)
  local missing, ran, best, of = {}, false, 0, 0
  for _, name in ipairs(counted) do
    if who[name] then ran = true else missing[#missing + 1] = name end
    local n, total = Cl:Progress(f, x.key, name)
    if n > best then best = n end
    of = total
  end
  local brief
  if st ~= "cleared" then
    if ran then brief = #missing == 1 and L.CH_ROW_NEED_1 or L.CH_ROW_NEED_N:format(#missing)
    elseif best > 0 then brief = L.CH_ROW_BOSSES:format(best, of) end
  end
  local whoText = st == "cleared" and L.WHO_DONE or (ran and L.WHO_MISSING:format(J.Names(f, missing))
    or (best > 0 and L.WHO_PARTIAL:format(best, of) or L.WHO_NOBODY))
  local tip = { x.d[2], roleText .. "  ·  " .. L.CH_LEVELS:format(x.d[3], x.d[4]), whoText }
  if x.early then tip[#tip + 1] = L.EARLY_BRIDGE_LINE:format(J.Roman(x.early)) end
  -- A dungeon over several chapters (Blackrock Depths): which part of its bosses counts here.
  if #Cl:Placements(f, ns.BaseKey(x.key)) > 1 then
    tip[#tip + 1] = L.CH_PART_BOSSES:format(#Cl:Needed(f, x.key), #Cl:Bosses(x.key))
  end
  -- The dungeon's quests (our own list): how many each Hero has picked up of the ones they still need.
  local dq = st ~= "cleared" and ns.QuestLists:DungeonLine(f, x.key) or nil
  if dq then tip[#tip + 1] = dq end
  tip[#tip + 1] = L.CH_ROW_JOURNAL
  return brief, tip
end

local function refresh(pf, ctx)
  local f = ctx.f
  if not f then return end
  local width = ns.Window.PAGE_W - 8
  local cur = J:CurrentIndex(f)
  local count = #f.journey.chapters
  local maxView = J:MaxView(f, ctx.me)
  local view = ns.Clamp(pf.sel or math.min(cur, count), 1, math.max(1, maxView))
  pf.shown = view
  local ch = f.journey.chapters[view]

  local s = UI.Stack(pf.lscroll.child)
  pf.prev:SetEnabled(view > 1)
  pf.next:SetEnabled(view < maxView)
  pf.num:SetText(L.CHAPTER_ROMAN:format(J.Roman(view)))
  s:Place(pf.nav, 26, 2)
  pf.name:SetText(ch and ch.name or "")
  s:Place(pf.name, 26, 2)
  local unlocked = J:Unlocked(f)
  -- (A chapter without dungeons, such as the Prologue, said "Dungeons open"; seen in the check run.)
  local open = #J:InChapter(f, view) > 0 and L.CH_STATE_OPEN or L.CH_STATE_LEVEL
  local state = view == cur and (unlocked and open or L.CH_STATE_WAIT) or (view < cur and L.CH_STATE_DONE or L.CH_STATE_NOT)
  -- (The run rule moved to the dungeons' heading: the line wrapped to two in game and pushed the rows down.)
  pf.line:SetText(ch and (L.CH_LEVELS:format(ch.floor, ch.cap) .. state) or "")
  s:Place(pf.line, math.max(16, pf.line:GetStringHeight()), 8)
  -- The stage track, centred, then one line of What's next.
  local nodes, b = J:Stages(f, view)
  pf.track:SetShown(#nodes > 0)
  if #nodes > 0 then
    layoutTrack(pf, nodes, b.color, width)
    s:Place(pf.track, TRACK_H, 6)
  end
  -- (Not while the chapter waits for the floor: the waiting box says it, and the line pointed at a milestone; M25.)
  local step = view == cur and b.stage ~= "floor" and nextStep(f) or nil
  pf.nextLine:SetShown(step ~= nil)
  if step then
    UI.SetIcon(pf.nextLine.icon, ns.ICONS["bn_" .. step.icon] or ns.ICONS.bn_done)
    pf.nextLine.text:SetText(step.text)
    local sh = math.max(20, pf.nextLine.text:GetStringHeight() + 4)
    pf.nextLine:SetHeight(sh)
    s:Place(pf.nextLine, sh, 6)
  end
  -- The stage: while below the floor the waiting box with who and how far, else the banner (the track shows the
  -- step, so the banner's step line is left out).
  local waiting = b.stage == "floor" and ch ~= nil
  pf.wait:SetShown(waiting)
  pf.banner:SetShown(not waiting)
  if waiting then
    s:Place(pf.wait, fillWait(pf, f, ch, b.below or {}, width), 8)
  else
    local shownBanner = {}
    for k, v in pairs(b) do shownBanner[k] = v end
    if #nodes > 0 then shownBanner.step = "" end
    s:Place(pf.banner, pf.banner:Set(shownBanner), 8)
  end
  local over = view == cur and J:OverCap(f) or {}
  pf.over:SetShown(#over > 0)
  if #over > 0 then
    pf.overText:SetText((#over == 1 and L.OVER_CAP_1 or L.OVER_CAP_N):format(J.Names(f, over)))
    pf.over:SetHeight(pf.overText:GetStringHeight() + 18)
    s:Place(pf.over, pf.over:GetHeight(), 8)
  end
  s:Skip(2)
  pf.div:ClearAllPoints()
  pf.div:SetPoint("TOPLEFT", pf.lscroll.child, "TOPLEFT", 0, -s.y); pf.div:SetPoint("TOPRIGHT", pf.lscroll.child, "TOPRIGHT", 0, -s.y)
  s:Skip(14)

  -- Dungeons, one row each.
  local counted = J:Counted(f)
  local list = ch and J:ChapterList(f, view) or {}
  pf.dHead:SetShown(#list > 0)
  if #list > 0 then
    pf.dHead:SetText(waiting and L.CH_DUNGEONS_WAIT:format(J:FloorLevel(f, ch))
      or (L.CH_DUNGEONS .. (view == cur and L.WHO_RUN_COUNTS:format(f.rules.minHeroes) or "")))
    s:Place(pf.dHead, 16, 4)
  end
  local shown = 0
  for i, x in ipairs(list) do
    local c = pf.rows:Get(i)
    if not c then break end
    shown = i
    local st = J:DungeonState(f, view, x)
    c.mark:SetMark(st)
    c.name:SetText(x.d[2])
    local color = J.ROLE_COLOR[x.role] or J.ROLE_COLOR.m
    local roleText = x.early and L.ROLE_BRIDGE_EARLY:format(J.Roman(x.early))
      or (x.role == "b" and L.ROLE_BRIDGE or (x.role == "o" and L.ROLE_OPTIONAL or L.ROLE_MANDATORY))
    c.stripe:SetColorTexture(ns.Hex(color[1]))
    c.borderRole = color[1]; c:Paint()
    local brief, tip = rowTexts(f, x, st, roleText, counted)
    c.tip, c.roleText = tip, roleText
    -- The kind in its colour, then the levels and how far it is.
    local function sub(levels) return ("|cff%s%s|r  ·  %s%s"):format(Theme:HexFor(color[1]), roleText, levels, brief and ("  ·  " .. brief) or "") end
    c.sub:SetText(sub(L.CH_LEVELS:format(x.d[3], x.d[4])))
    -- At the right: Find group when it is open (the main action), else its state; the Dungeon Journal; and for the
    -- leader a "⋯" menu with Mark cleared and Undo clear.
    c.key = x.key
    c.group:SetShown(st == "open" and not ctx.watching)
    c.menu:Update()
    if ctx.watching then c.menu:Hide() end
    c.state:SetShown(st ~= "open")
    c.state:SetText(st == "cleared" and L.STATE_CLEARED or L.STATE_LOCKED)
    c.state:SetTextColor(Theme:RGBA(st == "cleared" and "3E7A3A" or "ink2"))
    c.lore:SetShown(OA:HasLore())
    local rx = width - 8
    for _, w in ipairs({ c.menu, c.group, c.state, c.dj, c.lore }) do
      if w:IsShown() then
        local ww = w.GetStringWidth and w:GetStringWidth() or w:GetWidth()
        w:ClearAllPoints(); w:SetPoint("RIGHT", c, "LEFT", rx, 0)
        rx = rx - ww - 6
      end
    end
    local textW = rx - (THUMB_W + 18) - 4
    c.name:SetWidth(textW); c.sub:SetWidth(textW)
    -- Next to Find group the line can be too long ("Mandatory · Level 18-21 · 2/5 bo..", seen in the check of 29 Oct
    -- 2026): the levels without "Level" then.
    if c.sub:GetStringWidth() > textW then c.sub:SetText(sub(L.CH_LEVELS_SHORT:format(x.d[3], x.d[4]))) end
    local ok, default = ns.SetDungeonArt(c.pic.tex, x.key, THUMB_W, THUMB_H)
    -- No picture of its own (only the game's blurry default tile): the chapter's illustration instead.
    if default then ns.Pages:SetChapterArt(c.pic.tex, ns.Pages:ArtOf(f, view), THUMB_W, THUMB_H, 0.6); ok = true end
    c.pic.tex:SetShown(ok)
    -- Locked rows are dimmed while the fellowship waits for the floor: the stage above is what matters now.
    c:SetAlpha(st == "locked" and 0.6 or 1)
    s:Place(c, ROW_H, 4)
  end
  pf.rows:HideFrom(shown + 1)
  pf.none:SetShown(ch ~= nil and #list == 0)
  if ch and #list == 0 then
    ns.Pages:SetChapterArt(pf.none.pic, ns.Pages:ArtOf(f, view), width - 4, BIG_PIC_H - 4, 0.5)
    pf.none.text:SetText(L.CH_NO_DUNGEONS_PIC:format(ch.cap))
    s:Place(pf.none, BIG_PIC_H, 6)
  end
  -- Milestones of this chapter.
  local MS = ns.Milestones
  local ms = ch and MS:List(f, view) or {}
  pf.msHead:SetShown(#ms > 0); pf.msHelp:SetShown(#ms > 0)
  if #ms > 0 then
    s:Skip(8)
    s:Place(pf.msHead, 29, 2)
    s:Place(pf.msHelp, pf.msHelp:GetStringHeight(), 6)
  end
  local canTick = P.Can(f, ns.Me(), "clears") and not ctx.watching
  for i, m in ipairs(ms) do
    local r = pf.msRows:Get(i)
    if not r then break end
    local p = MS:Progress(f, m)
    r.id, r.done = m.id, p.done
    r.mark:SetMark(p.done and "cleared" or "open")
    r.name:SetText(m.name)
    r.sub:SetText((m.req and L.MS_REQUIRED or L.MS_OPTIONAL) .. "  ·  " .. MS:ProgressText(f, m))
    r.sub:ClearAllPoints(); r.sub:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -2)
    r.tick:SetShown(m.kind == "tick" and canTick)
    r.tick:SetLabel(p.done and L.MS_UNTICK or L.MS_TICK)
    local h = r.name:GetStringHeight() + 18
    r:SetHeight(h)
    s:Place(r, h, 6)
  end
  pf.msRows:HideFrom(#ms + 1)
  pf.lscroll:SetContentHeight(s.y + 8)

  -- Where the Heroes stand.
  local r = UI.Stack(pf.rscroll.child)
  r:Place(pf.head, pf.head:GetHeight(), 4)
  pf.stand:Set(f, view, r)
  refreshMatrix(pf, ctx, list, r, width)
  pf.rscroll:SetContentHeight(r.y + 8)
end

ns.Pages:Register({ id = "chapter", label = L.NAV_CHAPTER, header = "none", build = build, refresh = refresh,
  title = function(ctx)
    local ch = ctx.chapter
    if ch then return L.TITLE_CHAPTER:format(J.Roman(ch.n)), ch.name or "" end
    return L.NAV_CHAPTER, ""
  end })
