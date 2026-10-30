-- Moments (SPEC §4.7, 29 Oct 2026): the Chronicle's second tab (parent = "chronicle"), the journey's big moments
-- (Fellowship/Moments.lua). Left: a picture tile for each moment, newest first, with its day and the pictures you took
-- then. Right: the chosen moment large, what happened, who was there with their levels, and your pictures. An addon
-- cannot show the game's screenshots (they are in its Screenshots folder), so each moment shows its chapter's or
-- dungeon's own picture; the screenshots themselves go to Discord (Fellowship/Board.lua).
local _, ns = ...
local L = ns.L
local UI, Theme, P = ns.UI, ns.Theme, ns.Pages
local Mo = ns.Moments

local GAP = 10

-- The picture of a moment: the dungeon for a clear, the arena for the champion, else its chapter (the journey's
-- landscape when the journey is complete).
local function setArt(tex, f, m, w, h)
  if m.k == "clear" and m.key and ns.SetDungeonArt(tex, m.key, w, h) then return end
  if m.k == "champion" then
    local a = (Theme:Horde() and P.ART_HORDE or P.ART).arena
    if tex:SetTexture(ns.MEDIA .. a[1]) then UI.Cover(tex, a[2], w, h, 0.4) return end
  end
  P:SetChapterArt(tex, m.k ~= "end" and P:ArtOf(f, m.ch) or nil, w, h, 0.4)
end

-- A tile: the picture in a gold edge, the title and a line over a dark fade at its foot (as UI.PictureTile, smaller
-- words for the left page's two columns).
local function tile(parent, w, h, titleSize, onClick)
  local t = CreateFrame("Button", nil, parent)
  t:SetSize(w, h)
  t.w, t.h = w, h
  t.bg = t:CreateTexture(nil, "BACKGROUND")
  t.bg:SetAllPoints(); t.bg:SetColorTexture(0.1, 0.07, 0.04, 1)
  t.pic = t:CreateTexture(nil, "ARTWORK")
  t.pic:SetPoint("TOPLEFT", 2, -2); t.pic:SetPoint("BOTTOMRIGHT", -2, 2)
  local fade = t:CreateTexture(nil, "ARTWORK", nil, 2)
  fade:SetPoint("BOTTOMLEFT", 2, 2); fade:SetPoint("BOTTOMRIGHT", -2, 2); fade:SetHeight(math.floor(h * 0.75))
  UI.SetGradient(fade, "VERTICAL", { 0.05, 0.03, 0.01, 0.94 }, { 0.05, 0.03, 0.01, 0 })
  t.text = UI.Text(t, titleSize > 16 and 13 or 11, "chipText", "body")
  t.text:SetShadowOffset(1, -1); t.text:SetShadowColor(0, 0, 0, 1)
  t.text:SetPoint("BOTTOMLEFT", 10, 8); t.text:SetWidth(w - 20); t.text:SetJustifyH("LEFT")
  t.title = UI.WrapText(t, titleSize, "goldText", w - 20, "title")
  t.title:SetShadowOffset(1, -1); t.title:SetShadowColor(0, 0, 0, 1)
  t.title:SetPoint("BOTTOMLEFT", t.text, "TOPLEFT", 0, 3)
  t.border = UI.Box(t, 2, nil, nil, "gold", 0.85)
  t.border:SetAllPoints()
  t.glow = t:CreateTexture(nil, "OVERLAY")
  t.glow:SetPoint("TOPLEFT", 2, -2); t.glow:SetPoint("BOTTOMRIGHT", -2, 2)
  t.glow:SetColorTexture(1, 0.85, 0.45, 0.12); t.glow:Hide()
  t.chosenEdge = UI.Box(t, 3, nil, nil, "goldText", 1)
  t.chosenEdge:SetAllPoints(); t.chosenEdge:Hide()
  if onClick then
    t:SetScript("OnEnter", function() t.glow:Show() end)
    t:SetScript("OnLeave", function() if not t.chosen then t.glow:Hide() end end)
    t:SetScript("OnClick", function() ns.Sound("choose"); onClick(t) end)
  end
  function t:SetChosen(on)
    self.chosen = on and true or false
    self.chosenEdge:SetShown(self.chosen); self.glow:SetShown(self.chosen)
  end
  return t
end

local function countText(n) return n == 1 and L.MO_COUNT_1 or L.MO_COUNT:format(n) end

local function build(pf)
  local W = ns.Window
  local width = W.PAGE_W - 8
  local top = ns.ChronicleTabs(pf)
  pf.lscroll = UI.Scroll(pf.left)
  pf.lscroll:SetPoint("TOPLEFT", 0, -top); pf.lscroll:SetPoint("BOTTOMRIGHT")
  local Lc = pf.lscroll.child
  pf.intro = UI.WrapText(Lc, 13, "ink2", width, "book")
  pf.intro:SetText(L.MO_INTRO)
  local tw = math.floor((width - GAP) / 2)
  pf.tiles = UI.Pool(function()
    return tile(Lc, tw, math.floor(tw / 2), 14, function(t) pf.sel = t.id; W:Refresh() end)
  end)
  pf.empty = UI.EmptyState(Lc, width)

  pf.rscroll = UI.Scroll(pf.right)
  pf.rscroll:SetAllPoints()
  local R = pf.rscroll.child
  pf.big = tile(R, width, math.floor(width / 2), 22)
  pf.what = UI.WrapText(R, 14, "ink", width, "book")
  pf.whoHead = UI.SectionHeader(R, width)
  pf.whoHead:SetText(L.MO_WHO)
  pf.who = UI.WrapText(R, 13, "ink", width, "book")
  pf.picHead = UI.SectionHeader(R, width)
  pf.picHead:SetText(L.MO_PICTURES)
  pf.pics = UI.WrapText(R, 13, "ink", width, "book")
end

local function refresh(pf, ctx)
  local f = ctx.f
  if not f then return end
  pf.tabs:Refresh()

  local list = Mo:List(f)
  local chosen
  for _, m in ipairs(list) do if m.id == pf.sel then chosen = m end end
  chosen = chosen or list[1]
  pf.sel = chosen and chosen.id

  -- Left: the tiles, two to a row.
  local s = UI.Stack(pf.lscroll.child)
  s:Place(pf.intro, pf.intro:GetStringHeight(), 12)
  local shown, y0 = 0, s.y
  for i, m in ipairs(list) do
    local t = pf.tiles:Get(i)
    if not t then break end
    shown = i
    t.id = m.id
    setArt(t.pic, f, m, t.w - 4, t.h - 4)
    t.title:SetText(Mo:Title(m))
    local n = #Mo:PicturesOf(f, m)
    t.text:SetText(n > 0 and (Mo.Day(m.time) .. "  ·  " .. countText(n)) or Mo.Day(m.time))
    t:SetChosen(m == chosen)
    t:ClearAllPoints()
    t:SetPoint("TOPLEFT", pf.lscroll.child, "TOPLEFT", ((i - 1) % 2) * (t.w + GAP), -(y0 + math.floor((i - 1) / 2) * (t.h + GAP)))
    t:Show()
  end
  pf.tiles:HideFrom(shown + 1)
  if shown > 0 then
    local th = pf.tiles.items[1].h
    s:Skip(math.ceil(shown / 2) * (th + GAP))
  end
  pf.empty:SetShown(#list == 0)
  if #list == 0 then
    s:Skip(10)
    s:Place(pf.empty, pf.empty:Set(ns.ICONS.toast_chapter, L.MO_EMPTY, L.MO_EMPTY_TEXT, nil, nil, "EmptyHistory"), 4)
  end
  pf.lscroll:SetContentHeight(s.y + 8)

  -- Right: the chosen moment. None yet: how pictures join the moments (the page was bare; seen in the seventh check).
  local r = UI.Stack(pf.rscroll.child)
  for _, w in ipairs({ pf.big, pf.what, pf.whoHead, pf.who }) do w:SetShown(chosen ~= nil) end
  if not chosen then
    r:Place(pf.picHead, 29, 6)
    pf.pics:SetText(L.MO_PICS_NONE)
    r:Place(pf.pics, pf.pics:GetStringHeight(), 8)
  end
  if chosen then
    setArt(pf.big.pic, f, chosen, pf.big.w - 4, pf.big.h - 4)
    pf.big.title:SetText(Mo:Title(chosen))
    pf.big.text:SetText(Mo.When(chosen.time))
    r:Place(pf.big, pf.big.h, 12)
    pf.what:SetText(Mo:Text(f, chosen))
    r:Place(pf.what, pf.what:GetStringHeight(), 14)
    r:Place(pf.whoHead, 29, 6)
    local who = Mo:Who(f, chosen, true)
    pf.who:SetText(who ~= "" and who or L.MO_WHO_NONE)
    pf.who:SetTextColor(Theme:RGBA(who ~= "" and "ink" or "ink2"))
    r:Place(pf.who, pf.who:GetStringHeight(), 14)
    r:Place(pf.picHead, 29, 6)
    local pics, at = Mo:PicturesOf(f, chosen), {}
    for i, p in ipairs(pics) do at[i] = Mo.Clock(p.time) end
    local times = #at <= 1 and (at[1] or "") or (table.concat(at, ", ", 1, #at - 1) .. L.AND .. at[#at])
    pf.pics:SetText(#pics == 0 and L.MO_PICS_0 or #pics == 1 and L.MO_PICS_1:format(times) or L.MO_PICS_N:format(#pics, times))
    r:Place(pf.pics, pf.pics:GetStringHeight(), 8)
  end
  pf.rscroll:SetContentHeight(r.y + 8)
end

ns.Pages:Register({ id = "moments", label = L.CH_TAB_MOMENTS, icon = "chronicle", parent = "chronicle", build = build, refresh = refresh,
  title = function() return L.TITLE_MOMENTS, L.SUB_MOMENTS end })
