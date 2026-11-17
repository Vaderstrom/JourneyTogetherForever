-- Chapter (SPEC §4.5, U140). Left: chapter number with previous/next, name, levels, the stage track, All chapters,
-- an over-the-cap warning and Your To do: the new Leader's first steps, reach the floor (with your estimate), the
-- chapter's dungeons (Find group or Get ready, Mark cleared, Undo clear), steps for later dungeons and the next
-- chapter's dungeons you may run now; the chapter's picture when it has no dungeons. Right: where the Adventurers
-- stand (the room's stop tick on the track) and the Dungeon clears table (the Leader clicks a cell to change it).
local _, ns = ...
local L = ns.L
local UI, Theme = ns.UI, ns.Theme
local J, Hr, P, Cl = ns.Journey, ns.Hero, ns.Permissions, ns.Clears

local CELL_W, NAME_W, HEAD_H = 34, 110, 32
-- A dungeon row and its picture: five rows fit on the page without scrolling (28 Oct 2026).
local ROW_H, THUMB_W, THUMB_H = 50, 66, 40
local BRIEF_H = 14 -- a row's third line, how far the dungeon is
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
  -- All chapters (U140, the Overview's contents until the rebuild): every chapter, folded until asked for.
  pf.allBtn = UI.TextButton(Lc, "", function() pf.allCh = not pf.allCh; W:Refresh() end, "link", 13)
  pf.toc = UI.Pool(function()
    local b = CreateFrame("Button", nil, Lc)
    b:SetSize(width, 24)
    b.bg = b:CreateTexture(nil, "BACKGROUND")
    b.bg:SetAllPoints()
    b.bg:SetColorTexture(0.72, 0.53, 0.18, 0.2)
    b.num = UI.Text(b, 13, nil, "title")
    b.num:SetPoint("LEFT", 6, 0)
    b.num:SetWidth(34)
    b.name = UI.Text(b, 14, nil, "title")
    b.name:SetPoint("LEFT", 42, 0)
    b.name:SetWidth(width - 140)
    b.mark = UI.Mark(b, 14)
    b.mark:SetPoint("RIGHT", -4, 0)
    b.range = UI.Text(b, 12, "ink2", "body", "RIGHT")
    b.range:SetPoint("RIGHT", b.mark, "LEFT", -6, 0)
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints(); hl:SetColorTexture(1, 0.9, 0.6, 0.12)
    b:SetScript("OnClick", function() pf.sel = b.n; W:Refresh() end)
    return b
  end)
  -- (No waiting box since U232: the right page's Below the floor says who and how far, the To do's floor line your own
  -- estimate.)
  pf.div = UI.Divider(Lc)
  pf.todoHead = UI.SectionHeader(Lc, width)
  pf.todoHead:SetText(L.TODO_HEAD)
  pf.subLike = UI.Text(Lc, 11, "ink2")
  pf.subLike:SetText(L.TODO_IF_YOU_LIKE:upper())
  -- A To do line without a dungeon (the new Leader's steps, reach the floor, the chains for later dungeons): its mark
  -- and text; a step with a page opens it (and its tab).
  pf.simple = UI.Pool(function()
    local r = CreateFrame("Button", nil, Lc)
    r:SetSize(width, 24)
    r.mark = UI.Mark(r, 14)
    r.mark:SetPoint("LEFT", 4, 0)
    r.text = UI.Text(r, 13, "ink", "body")
    r.text:SetPoint("LEFT", 26, 0)
    r.text:SetWidth(width - 30); r.text:SetWordWrap(false)
    local hl = r:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints(); hl:SetColorTexture(1, 0.9, 0.6, 0.08)
    r:SetScript("OnClick", function() if r.page then W:ShowPage(r.page, r.tab) end end)
    UI.Tooltip(r, function() return r.tip end)
    return r
  end)
  -- A dungeon as one row (28 Oct 2026: the picture cards took a page each and the dungeons had to be scrolled): a
  -- small picture, name, kind and levels, and at the right its state or Find group. The rest is in the tooltip.
  pf.rows = UI.Pool(function()
    local c = UI.Card(Lc)
    c:SetSize(width, ROW_H)
    c:EnableMouse(true)
    -- The role's colour down the row's left edge (and its border): mandatory, from the next chapter, optional at a
    -- glance.
    c.stripe = c:CreateTexture(nil, "ARTWORK", nil, 3)
    c.stripe:SetPoint("TOPLEFT", 1, -1); c.stripe:SetPoint("BOTTOMLEFT", 1, 1); c.stripe:SetWidth(4)
    -- The dungeon's picture (its loading screen); a click on it or the row opens the Dungeon page (U96).
    c.pic = CreateFrame("Button", nil, c)
    c.pic:SetSize(THUMB_W, THUMB_H); c.pic:SetPoint("LEFT", 9, 0)
    c.pic.tex = c.pic:CreateTexture(nil, "ARTWORK")
    local phl = c.pic:CreateTexture(nil, "HIGHLIGHT")
    phl:SetColorTexture(1, 0.9, 0.6, 0.15)
    UI.FramePicture(c.pic, c.pic.tex, phl)
    c.pic:SetScript("OnClick", function() if c.key then ns.DungeonPage:Open(c.key) end end)
    UI.PictureTip(c.pic, function() return c.key end) -- larger on hover (U64)
    c.mark = UI.Mark(c.pic, 14)
    c.mark:SetPoint("BOTTOMLEFT", 4, 4)
    c.name = UI.Text(c, 14, "ink", "title")
    c.name:SetPoint("TOPLEFT", THUMB_W + 18, -9)
    c.name:SetWordWrap(false)
    c.sub = UI.Text(c, 11, "ink2")
    c.sub:SetPoint("TOPLEFT", c.name, "BOTTOMLEFT", 0, -3)
    c.sub:SetWordWrap(false)
    -- What you need to do for it, on a line of its own (U140): "Ready: your 3 quests are in your log.", "Get ready:
    -- 2 chains to start, 3 quests to pick up.", "Open when everyone is level 15.", "Cleared".
    c.brief = UI.Text(c, 12, "ink")
    c.brief:SetPoint("TOPLEFT", c.sub, "BOTTOMLEFT", 0, -2)
    c.brief:SetWordWrap(false)
    c.state = UI.Text(c, 12, nil, "body", "RIGHT")
    -- Everything else about the dungeon on hover: who ran it, what is missing, quests picked up.
    c.hl = c:CreateTexture(nil, "ARTWORK", nil, 1)
    c.hl:SetAllPoints(); c.hl:SetColorTexture(1, 0.9, 0.6, 0.08); c.hl:Hide()
    c:SetScript("OnEnter", function()
      c.hl:Show()
      GameTooltip:SetOwner(c, "ANCHOR_RIGHT")
      for i, line in ipairs(c.tip or {}) do
        if i == 1 then GameTooltip:SetText(line) else GameTooltip:AddLine(line, 0.9, 0.85, 0.7, true) end
      end
      GameTooltip:Show()
    end)
    c:SetScript("OnLeave", function() c.hl:Hide(); GameTooltip:Hide() end)
    -- The row opens the Dungeon page (U96), with the story and the quests (the row's book and
    -- story buttons went there).
    c:SetScript("OnMouseUp", function(_, button)
      if button == "LeftButton" and c.key and c:IsMouseOver() then ns.DungeonPage:Open(c.key) end
    end)
    -- Find group when there is nothing to get first (its tooltip says the rule), else Get ready: the Dungeon page.
    c.group = UI.TextButton(c, L.FIND_GROUP, function()
      local f = ns.Fellowship:Current()
      if not (f and c.key) then return end
      if c.action == "ready" then ns.DungeonPage:Open(c.key) else ns.Together:FindGroup(f, c.key) end
    end, "primary", 12)
    UI.Tooltip(c.group, function()
      local f = ns.Fellowship:Current()
      return c.action ~= "ready" and f and L.TODO_FIND_TIP:format(f.rules.minHeroes) or nil
    end)
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
  -- Milestones in the To do (Rules/Milestones.lua): each with its mark, Required or Optional, how far, and Tick off.
  -- Framed like the dungeon rows (U224, the check of 15 Nov 2026): its role's colour down the left edge and its border.
  pf.msRows = UI.Pool(function()
    local r = UI.Card(Lc)
    r:SetSize(width, 40)
    r.stripe = r:CreateTexture(nil, "ARTWORK", nil, 3)
    r.stripe:SetPoint("TOPLEFT", 1, -1); r.stripe:SetPoint("BOTTOMLEFT", 1, 1); r.stripe:SetWidth(4)
    r.mark = UI.Mark(r, 14)
    r.mark:SetPoint("TOPLEFT", 12, -10)
    r.name = UI.WrapText(r, 13, "ink", width - 130, "title")
    r.name:SetPoint("TOPLEFT", 32, -8)
    r.sub = UI.Text(r, 11, "ink2")
    r.sub:SetWidth(width - 130); r.sub:SetWordWrap(false) -- (clear of Tick off: "ticked off by" a long Forever name)
    r.tick = UI.TextButton(r, L.MS_TICK, function()
      local f = ns.Fellowship:Current()
      if f and r.id then ns.Fellowship:Tick(r.id, not r.done) end
    end, "plain", 12)
    r.tick:SetPoint("RIGHT", -8, 0)
    return r
  end)

  pf.rscroll = UI.Scroll(pf.right)
  pf.rscroll:SetAllPoints()
  local R = pf.rscroll.child
  pf.head = UI.Heading(R, width, L.WHERE_STAND, nil)
  -- The level track above the list (U5, 31 Oct 2026): the chapter's floor and cap with everyone on one line.
  pf.levelTrack = UI.LevelTrack(R, width)
  pf.stand = UI.Standings(R, width)
  -- (On your own the right page was bare under the clears, the check of 17 Nov 2026: the page sketch fills it.)
  pf.art = UI.PageArt(pf.rscroll, "Since")

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
  -- The Adventurers only: a Friend's clears are never needed (the owner, 11 Nov 2026).
  local heroes = {}
  for name in pairs(f.members) do if not ns.Fellowship:IsFriend(f, name) then heroes[#heroes + 1] = name end end
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
    row.name:SetText(ns.Brief(name, f.members))
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
  -- (Viewing from another character: no line; the bar at the top says read only, U207.)
  local help = can and L.MATRIX_HELP or (not ctx.watching and L.MATRIX_HELP_NO) or nil
  pf.mHelp:SetText(help or "")
  pf.mHelp:SetShown(help ~= nil)
  if help then r:Place(pf.mHelp, pf.mHelp:GetStringHeight(), 4) end
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

-- A dungeon's short state for its row ("4 of 7 bosses", "2 still need it") and the lines of its tooltip.
local function rowTip(f, x, st, roleText, counted)
  local who = J:ClearedBy(f, x.key)
  local missing, ran, best, of = {}, false, 0, 0
  for _, name in ipairs(counted) do
    if who[name] then ran = true else missing[#missing + 1] = name end
    local n, total = Cl:Progress(f, x.key, name)
    if n > best then best = n end
    of = total
  end
  local whoText = st == "cleared" and L.WHO_DONE or (ran and L.WHO_MISSING:format(J.Names(f, missing))
    or (best > 0 and L.WHO_PARTIAL:format(best, of) or L.WHO_NOBODY))
  local tip = { x.d[2], roleText .. "  ·  " .. L.CH_LEVELS:format(x.d[3], x.d[4]), whoText }
  -- A dungeon over several chapters (Blackrock Depths): which part of its bosses counts here.
  if #Cl:Placements(f, ns.BaseKey(x.key)) > 1 then
    tip[#tip + 1] = L.CH_PART_BOSSES:format(#Cl:Needed(f, x.key), #Cl:Bosses(x.key))
  end
  -- Who is ready, in one line as the dungeon's page says it; each Adventurer's quests are there (U186).
  local rows = st ~= "cleared" and ns.Ready:Rows(f, x.key) or {}
  local ready = ns.Ready.Tally(rows)
  if ready then tip[#tip + 1] = L.DQ_READY_N:format(ready, #rows) end
  tip[#tip + 1] = L.CH_ROW_JOURNAL
  return tip
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
  local banner = J:Banner(f, view)
  -- (A chapter without dungeons, such as the Prologue, said "Dungeons open"; seen in the check run. So did one whose
  -- dungeons are cleared while Everyone to the cap first holds it, the check of 15 Nov 2026.)
  local open = (#J:InChapter(f, view) > 0 and banner.stage ~= "level") and L.CH_STATE_OPEN or (f.solo and L.CH_STATE_SOLO or L.CH_STATE_LEVEL)
  local state = view == cur and (unlocked and open or L.CH_STATE_WAIT) or (view < cur and L.CH_STATE_DONE or L.CH_STATE_NOT)
  -- (The run rule moved to the dungeons' heading: the line wrapped to two in game and pushed the rows down.)
  pf.line:SetText(ch and (L.CH_LEVELS:format(ch.floor, ch.cap) .. state) or "")
  s:Place(pf.line, math.max(16, pf.line:GetStringHeight()), 8)
  -- The stage track, centred.
  local nodes = J:Stages(f, view)
  pf.track:SetShown(#nodes > 0)
  if #nodes > 0 then
    layoutTrack(pf, nodes, banner.color, width)
    s:Place(pf.track, TRACK_H, 6)
  end
  local items = ch and ns.Together:ToDo(f, view) or {}
  -- All chapters, folded: every chapter, done, now or yet to be revealed; a click shows it here.
  pf.allBtn:SetLabel(UI.FoldLabel(pf.allCh and L.ALL_CHAPTERS_HIDE or L.ALL_CHAPTERS, pf.allCh))
  s:Place(pf.allBtn, 20, 2, math.floor((width - pf.allBtn:GetWidth()) / 2))
  local shownToc = 0
  for n, c in ipairs(pf.allCh and f.journey.chapters or {}) do
    local b = pf.toc:Get(n)
    if not b then break end
    shownToc = n
    local hidden, done, now = n > maxView, n < cur, n == cur
    b.n = n
    b.num:SetText(J.Roman(n))
    b.name:SetText(hidden and L.HIDDEN_CHAPTER or c.name)
    b.range:SetText(hidden and "" or (c.floor .. "–" .. c.cap))
    b.mark:SetMark(done and "done" or (now and "current" or (hidden and "locked" or nil)))
    local color = done and "3E7A3A" or (now and "B8742A" or "ink2") -- (pale "accent" was hard to read)
    b.num:SetTextColor(Theme:RGBA(color)); b.name:SetTextColor(Theme:RGBA(color))
    b.bg:SetShown(n == view)
    b:SetEnabled(not hidden)
    s:Place(b, 24, 0)
  end
  pf.toc:HideFrom(shownToc + 1)
  if shownToc > 0 then s:Skip(6) end
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
  s:Skip(8)

  -- Your To do: one line or row per item, in order (Together:ToDo).
  local counted = J:Counted(f)
  local list = ch and J:ChapterList(f, view) or {}
  local nextKey = J:NextDungeon(f, view, list)
  pf.todoHead:SetShown(ch ~= nil)
  if ch then s:Place(pf.todoHead, 29, 4) end
  local MS = ns.Milestones
  local canTick = P.Can(f, ns.Me(), "clears") and not ctx.watching
  local nSimple, nMs, shown, subs = 0, 0, 0, {}
  pf.subLike:Hide()
  -- The chains for later dungeons as one line (U250, the owner, 17 Nov 2026): "2 chains for later dungeons open now",
  -- each dungeon and its next step in the tooltip; a click opens the Dungeon quests tab, whose Start early is their one
  -- home (U246). They never hold the chapter back.
  -- (Chains counted, not dungeons: one dungeon can have two; code review of 2.0.)
  local laterTip, laterPlaced, chains = {}, false, 0
  for _, it in ipairs(items) do
    if it.kind == "later" then
      laterTip[#laterTip + 1] = it.x.d[2] .. "  ·  " .. (it.line or "")
      chains = chains + #it.e.steps
    end
  end
  local laterText = chains == 1 and L.TODO_LATER_CHAINS_1 or L.TODO_LATER_CHAINS_N:format(chains)
  table.insert(laterTip, 1, laterText); laterTip[#laterTip + 1] = L.TODO_LATER_CLICK
  -- (A cleared dungeon keeps its row, ticked: the owner, 17 Nov 2026, "Do not hide the dungeons we have completed";
  -- U227 and U234 folded them into one line.)
  for _, it in ipairs(items) do
    local like = it.kind == "early" or (it.kind == "milestone" and not it.req)
    local sub = like and pf.subLike or nil
    if sub and not subs[sub] then
      subs[sub] = true
      sub:Show()
      s:Skip(4)
      s:Place(sub, 14, 4)
    end
    if it.kind == "later" then
      nSimple = nSimple + (laterPlaced and 0 or 1)
      local r = not laterPlaced and pf.simple:Get(nSimple)
      laterPlaced = true
      if r then
        r.mark:SetMark("open")
        r.text:SetText(laterText)
        r.text:SetTextColor(Theme:RGBA("ink"))
        r.page, r.tab, r.tip = "quests", "dungeons", table.concat(laterTip, "\n") -- (UI.Tooltip shows text only)
        s:Place(r, 24, 2)
      end
    elseif it.kind == "start" or it.kind == "floor" or it.kind == "cap" then
      nSimple = nSimple + 1
      local r = pf.simple:Get(nSimple)
      if r then
        r.tab = nil
        r.mark:SetMark(it.done and "cleared" or "open")
        r.text:SetText(it.text)
        -- Cut to the short line where it does not fit; the whole line on hover then.
        local cut = it.short and r.text:GetStringWidth() > r.text:GetWidth() + 1
        if cut then r.text:SetText(it.short) end
        r.text:SetTextColor(Theme:RGBA(it.done and "ink2" or "ink"))
        r.page = not it.done and it.page or nil
        r.tip = cut and it.text or it.tip
        s:Place(r, 24, 2)
      end
    elseif it.kind == "milestone" then
      nMs = nMs + 1
      local r = pf.msRows:Get(nMs)
      if r then
        local m = it.m
        r.id, r.done = m.id, it.done
        r.mark:SetMark(it.done and "cleared" or "open")
        r.name:SetText(m.name)
        r.sub:SetText((m.req and L.MS_REQUIRED or L.MS_OPTIONAL) .. "  ·  " .. MS:ProgressText(f, m))
        r.sub:ClearAllPoints(); r.sub:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -2)
        r.tick:SetShown(m.kind == "tick" and canTick)
        r.tick:SetLabel(it.done and L.MS_UNTICK or L.MS_TICK)
        local color = J.ROLE_COLOR[m.req and "m" or "o"][1]
        r.stripe:SetColorTexture(ns.Hex(color))
        r.borderRole = color; r:Paint()
        local h = r.name:GetStringHeight() + 34
        r:SetHeight(h)
        s:Place(r, h, 4)
      end
    else
      local c = pf.rows:Get(shown + 1)
      if not c then break end
      shown = shown + 1
      local x = it.x
      local st = it.state
      if st then c.mark:SetMark(st) end
      c.name:SetText(x.d[2])
      -- A dungeon of the next chapter is mandatory in its own: gold there, blue ("From the next chapter") here.
      local role = it.kind == "early" and "b" or (x.role == "o" and "o" or "m")
      local color = (J.ROLE_COLOR[role] or J.ROLE_COLOR.m)[1]
      local roleText = it.kind == "early" and L.ROLE_BRIDGE or (role == "o" and L.ROLE_OPTIONAL or L.ROLE_MANDATORY)
      c.stripe:SetColorTexture(ns.Hex(color))
      c.borderRole = color; c:Paint()
      local label, tip = roleText, rowTip(f, x, st, roleText, counted)
      -- U192 (the owner, 14 Nov 2026): the next chapter's row names its chapter, not "From the next chapter" too.
      if it.kind == "early" then label = L.CHAPTER_ROMAN:format(J.Roman(x.early or view + 1)) end
      if x.key == nextKey then label = L.CH_ROW_NEXT; table.insert(tip, #tip, L.CH_ROW_NEXT_TIP) end
      c.tip, c.roleText = tip, roleText
      local function line(levels) return ("|cff%s%s|r%s"):format(Theme:HexFor(color), label, levels and ("  ·  " .. levels) or "") end
      -- (No chapter name on this chapter's own rows, U192: the page is the chapter.)
      local levels = L.CH_ROW_LEVELS:format(x.d[3], x.d[4])
      c.sub:SetText(line(levels))
      c.brief:SetText(it.line or "")
      c.brief:SetShown(true)
      c.brief:SetTextColor(Theme:RGBA(st == "cleared" and "3E7A3A" or "ink"))
      -- At the right: Find group or Get ready (not for a later dungeon or one from the next chapter), and for the
      -- Leader a "⋯" menu with Mark cleared and Undo clear.
      c.key, c.action = x.key, it.action
      -- (On your own only Get ready: there is nobody to find, U241.)
      local showGroup = it.kind == "dungeon" and it.action ~= nil and not ctx.watching and not (ctx.solo and it.action ~= "ready")
      c.group:SetShown(showGroup)
      if showGroup then c.group:SetLabel(it.action == "ready" and L.TODO_GET_READY_BUTTON or L.FIND_GROUP) end
      c.menu:Update()
      if ctx.watching then c.menu:Hide() end
      c.state:Hide()
      local rx = width - 8
      for _, w in ipairs({ c.menu, c.group }) do
        if w:IsShown() then
          local ww = w.GetStringWidth and w:GetStringWidth() or w:GetWidth()
          w:ClearAllPoints(); w:SetPoint("RIGHT", c, "LEFT", rx, 0)
          rx = rx - ww - 6
        end
      end
      local textW = rx - (THUMB_W + 18) - 4
      c.name:SetWidth(textW); c.sub:SetWidth(textW); c.brief:SetWidth(textW)
      -- Where the line does not fit beside the button, the levels drop to the tooltip; the need line takes its short
      -- form (its page has the rest).
      if c.sub:GetStringWidth() > textW then c.sub:SetText(line(nil)) end
      if it.short and c.brief:GetStringWidth() > textW then c.brief:SetText(it.short) end
      local ok, default = ns.SetDungeonArt(c.pic.tex, x.key, THUMB_W - 2 * UI.PIC_INSET, THUMB_H - 2 * UI.PIC_INSET)
      -- No picture of its own (only the game's blurry default tile): the chapter's illustration instead.
      if default then ns.Pages:SetChapterArt(c.pic.tex, ns.Pages:ArtOf(f, it.e and it.e.chapter or view), THUMB_W - 2 * UI.PIC_INSET, THUMB_H - 2 * UI.PIC_INSET, 0.6); ok = true end
      c.pic.tex:SetShown(ok)
      -- Rows that wait for the floor are dimmed: the floor line above is what matters now.
      c:SetAlpha(it.wait and 0.6 or 1)
      c:SetHeight(ROW_H + BRIEF_H)
      s:Place(c, ROW_H + BRIEF_H, 4)
    end
  end
  pf.simple:HideFrom(nSimple + 1)
  pf.msRows:HideFrom(nMs + 1)
  pf.rows:HideFrom(shown + 1)
  pf.none:SetShown(ch ~= nil and #list == 0)
  if ch and #list == 0 then
    ns.Pages:SetChapterArt(pf.none.pic, ns.Pages:ArtOf(f, view), width - 4, BIG_PIC_H - 4, 0.5)
    pf.none.text:SetText((f.solo and L.CH_NO_DUNGEONS_SOLO or L.CH_NO_DUNGEONS_PIC):format(ch.cap))
    s:Place(pf.none, BIG_PIC_H, 6)
  end
  pf.lscroll:SetContentHeight(s.y + 8)

  -- Where the Heroes stand (not on your own: U241, no floor or cap; the clears table alone).
  local r = UI.Stack(pf.rscroll.child)
  pf.head:SetShown(not ctx.solo); pf.levelTrack:SetShown(not ctx.solo)
  if ctx.solo then pf.stand:Hide() end
  if not ctx.solo then
    r:Place(pf.head, pf.head:GetHeight(), 4)
    local room = view == cur and not ctx.watching and ns.Room:Chapter(f, ns.Me()) or nil
    local th = pf.levelTrack:Set(f, view, 6, room and room.stop)
    if th > 0 then r:Place(pf.levelTrack, th, 12) end
    pf.stand:Set(f, view, r)
  end
  -- (The room's answer is on the Overview, U235: only its stop tick on the track here.)
  refreshMatrix(pf, ctx, list, r, width)
  pf.rscroll:SetContentHeight(r.y + 8)
  pf.art:Fit(r.y)
end

ns.Pages:Register({ id = "chapter", label = L.NAV_CHAPTER, header = "none", build = build, refresh = refresh,
  news = { quests = true }, -- the dungeons' "Quests picked up" lines
  title = function(ctx)
    local ch = ctx.chapter
    if ch then return L.TITLE_CHAPTER:format(J.Roman(ch.n)), ch.name or "" end
    return L.NAV_CHAPTER, ""
  end })
