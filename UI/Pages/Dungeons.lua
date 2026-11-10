-- Dungeons (U157, SPEC §4.5c; the owner, 9 Nov 2026: "a page for dungeons kinda like the raids tab ... In that tab
-- dungeons can be browsed by the adventurers"): every dungeon of the journey, chapter by chapter, as pictures on the
-- flat sheet, for everyone whatever the rule "Adventurers can see" says (a hidden chapter's name and levels stay hidden). A click opens
-- the dungeon's page, where everything else about it is (one home per fact); Back returns here. Settings can show only
-- the dungeons open to the fellowship (U164); the raids have their own page, with the same choice (U165).
local _, ns = ...
local L = ns.L
local UI, Theme = ns.UI, ns.Theme

local COLS, TILE_H, GAP = 4, 96, 10

local function sheetWidth() return 2 * ns.Window.PAGE_W + 52 end

local function build(pf)
  local width = sheetWidth()
  pf.scroll = UI.Scroll(pf.left)
  pf.scroll:SetPoint("TOPLEFT", pf.left, "TOPLEFT")
  pf.scroll:SetPoint("BOTTOMRIGHT", pf.right, "BOTTOMRIGHT")
  local C = pf.scroll.child
  pf.heads = UI.Pool(function() return UI.SectionHeader(C, width) end)
  local tw = math.floor((width - (COLS - 1) * GAP) / COLS)
  pf.tileW = tw
  pf.tiles = UI.Pool(function()
    local t = CreateFrame("Button", nil, C)
    t:SetSize(tw, TILE_H)
    t.tex = t:CreateTexture(nil, "ARTWORK")
    local hl = t:CreateTexture(nil, "HIGHLIGHT")
    hl:SetColorTexture(1, 0.9, 0.6, 0.12)
    UI.FramePicture(t, t.tex, hl)
    local p = UI.PIC_INSET
    local fade = t:CreateTexture(nil, "ARTWORK", nil, 2)
    fade:SetPoint("BOTTOMLEFT", p, p); fade:SetPoint("BOTTOMRIGHT", -p, p); fade:SetHeight(TILE_H * 0.65)
    UI.SetGradient(fade, "VERTICAL", { 0.05, 0.03, 0.01, 0.92 }, { 0.05, 0.03, 0.01, 0 })
    t.name = UI.Text(t, 14, "goldText", "fancy")
    -- (Two lines at most, growing upwards: "Scarlet Monastery: Cathedral" is wider than a tile.)
    t.name:SetPoint("BOTTOMLEFT", 10, 24); t.name:SetWidth(tw - 20); if t.name.SetMaxLines then t.name:SetMaxLines(2) end
    t.levels = UI.Text(t, 11, "chipText", "body")
    t.levels:SetPoint("BOTTOMLEFT", 10, 9)
    t.mark = UI.Mark(t, 14)
    t.mark:SetPoint("BOTTOMRIGHT", -10, 9)
    for _, fs in ipairs({ t.name, t.levels }) do fs:SetShadowOffset(1, -1); fs:SetShadowColor(0, 0, 0, 1) end
    t:SetScript("OnClick", function() if t.key then ns.DungeonPage:Open(t.key) end end)
    return t
  end)
  pf.none = UI.WrapText(C, 13, "ink2", width, "book")
end

-- Settings → Dungeons page (U164, the owner, 9 Nov 2026): every dungeon, or only those open to the fellowship.
local function showAll() return ns.Settings:Get("dungeonsShow") ~= "open" end

-- The groups to show: { head, gold, list = { { key, name, sub, n } } }, a chapter's dungeons each.
local function groups(f, me)
  local J, all = ns.Journey, showAll()
  local cur, view = J:CurrentIndex(f), J:MaxView(f, me)
  local byChapter, out = {}, {}
  for _, x in ipairs(ns.DungeonPage.List(f)) do
    if all or J:Open(f, x.key) then
      byChapter[x.n] = byChapter[x.n] or {}
      -- (A hidden chapter's dungeons without their levels, as its heading: the release review of 10 Nov 2026.)
      local sub = x.n > view and "" or L.CH_LEVELS:format(x.d[3], x.d[4])
      table.insert(byChapter[x.n], { key = x.key, name = x.d[2], sub = sub, n = x.n })
    end
  end
  for n, ch in ipairs(f.journey.chapters) do
    if byChapter[n] then
      -- (A chapter the rule hides: neither its name nor its levels, as on the Chapter page.)
      out[#out + 1] = { list = byChapter[n], gold = n == cur, head = n > view
        and L.DGS_CHAPTER_HIDDEN:format(J.Roman(n), L.HIDDEN_CHAPTER) or L.DGS_CHAPTER:format(J.Roman(n), ch.name, ch.floor, ch.cap) }
    end
  end
  return out
end

local function refresh(pf, ctx)
  local f = ctx.f
  if not f then return end
  local J = ns.Journey
  local s = UI.Stack(pf.scroll.child)
  local gs = groups(f, ctx.me)
  local none = #gs == 0
  pf.none:SetText(showAll() and L.DGS_NONE or L.DGS_NONE_OPEN)
  pf.none:SetShown(none)
  if none then s:Place(pf.none, pf.none:GetStringHeight(), 10) end
  local nh, nt, stop = 0, 0, false
  local tw, ih = pf.tileW, TILE_H - 2 * UI.PIC_INSET
  for _, g in ipairs(gs) do
    if stop then break end
    local head = pf.heads:Get(nh + 1)
    if not head then break end -- (in combat: made after it, UI.Pool)
    nh = nh + 1
    head:SetText(g.head)
    head.text:SetTextColor(Theme:RGBA(g.gold and "accentText" or "ink"))
    s:Skip(nh > 1 and 6 or 0)
    s:Place(head, 29, 6)
    for i, x in ipairs(g.list) do
      local t = pf.tiles:Get(nt + 1)
      -- In combat (made after it): the row so far is closed, and nothing comes under it (a heading landed on a
      -- half-drawn row; the release review of 10 Nov 2026).
      if not t then
        if (i - 1) % COLS > 0 then s:Skip(TILE_H + GAP) end
        stop = true
        break
      end
      nt = nt + 1
      t.key = x.key
      local ok, generic = ns.SetDungeonArt(t.tex, x.key, tw - 2 * UI.PIC_INSET, ih)
      if not ok or generic then
        ns.Pages:SetChapterArt(t.tex, x.n and ns.Pages:ArtOf(f, x.n), tw - 2 * UI.PIC_INSET, ih, 0.5)
      end
      t.name:SetText(x.name)
      t.levels:SetText(x.sub)
      t.mark:SetMark(J:Cleared(f, x.key) and "cleared" or nil)
      local col = (i - 1) % COLS
      t:ClearAllPoints(); t:SetPoint("TOPLEFT", col * (tw + GAP), -s.y)
      t:Show()
      if col == COLS - 1 or i == #g.list then s:Skip(TILE_H + GAP) end
    end
  end
  pf.heads:HideFrom(nh + 1)
  pf.tiles:HideFrom(nt + 1)
  pf.scroll:SetContentHeight(s.y + 8)
end

-- On the flat sheet, as the Dungeon page it opens. A subtitle only for Only open ones, saying the page shows less.
ns.Pages:Register({ id = "dungeons", label = L.NAV_DUNGEONS, header = "both", flat = true, build = build,
  refresh = refresh, title = function() return L.TITLE_DUNGEONS, showAll() and "" or L.SUB_DUNGEONS_OPEN end })
