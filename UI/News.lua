-- What's New (the check of 1 Nov 2026, 14:32; the owner chose it): the layout of the game's own "What's New" built
-- from our art, over the book. The book's parchment in its frame, a gold title, the update's big news as a round
-- picture in the Adventure Guide's gold ring, and two picture cards with dungeons' loading screens. (The game's own
-- splash is painted anew for every patch and shows retail's places, so it is not used.)
-- It shows once after each update (a new N.ID), the first time the book opens with a fellowship, or when one is
-- founded; never over the setup guide or a walkthrough or its offer (it waits for them: the owner, 8 Nov 2026, it
-- covered the tour), never while the self-test, the developer's tour or a check runs. /jtf news shows it again.
local _, ns = ...
local L = ns.L
local UI = ns.UI
local N = {}
ns.News = N

-- This update's news: a new ID shows the screen once more on every account. art: a dungeon's key (its picture).
-- pic (U44): the item's own picture, a file in Media: NewsBig (512 x 512), NewsA and NewsB (1024 x 512), made in the
-- Gemini app from art/prompts/news-art.json and converted by tools/convert-art.ps1 -Only news. Without the file the
-- dungeon's loading screen shows, as before.
N.ID = "1.2"
N.BIG = { art = "dm", title = "NEWS_BIG_TITLE", text = "NEWS_BIG_TEXT" }
N.CARDS = {
  { art = "wc", title = "NEWS_A_TITLE", text = "NEWS_A_TEXT" },
  { art = "bfd", title = "NEWS_B_TITLE", text = "NEWS_B_TEXT" },
}

local BOX_W, BOX_H = 800, 510
local PIC = 150 -- the round picture
local RING_ATLAS = "adventureguide-ring"
local CARD_W, CARD_H, CARD_GAP = 370, 170, 14

-- An item's picture on tex, w x h: its own (pic, a picture aspect wide to 1 high, cut to fill), else its dungeon's.
-- true when it is its own.
function N.Art(tex, item, w, h, aspect)
  if item.pic and tex:SetTexture(ns.MEDIA .. item.pic) ~= false then
    local a = w / h
    if a > aspect then local v = aspect / a; tex:SetTexCoord(0, 1, (1 - v) / 2, (1 + v) / 2)
    else local u = a / aspect; tex:SetTexCoord((1 - u) / 2, (1 + u) / 2, 0, 1) end
    return true
  end
  ns.SetDungeonArt(tex, item.art, w, h)
  return false
end

-- Not seen on this account yet, and in a fellowship (the news is about fellowships).
function N:Due()
  return ns.db ~= nil and ns.db.newsSeen ~= self.ID and ns.Fellowship:Current() ~= nil
end
-- The self-test, the developer's tour or a check runs (nothing may cover their pictures or start by itself).
function N.Dev()
  return (ns.SelfTest and ns.SelfTest.running) or (ns.Tour and ns.Tour.running) or (ns.Check and ns.Check.running) or false
end
-- Something else comes first: the setup guide, a walkthrough or its offer (Stop, Later and the guide's end ask again).
function N:Busy()
  local WK = ns.Walkthrough
  return ns.Window.current == "setup" or ns.SetupGuide:Pending() or WK.on or WK.offer ~= nil
end
-- Due, and nothing first.
function N:Pending() return not self.Dev() and not self:Busy() and self:Due() end
-- On the screen now.
function N:Showing()
  local o = ns.Window.overlays and ns.Window.overlays.news
  return o ~= nil and o:IsShown()
end

-- Made the first time it shows (never during combat): an overlay of the book (W:Overlay) with our parts.
function N:Build()
  local W = ns.Window
  local o = W:Overlay("news", BOX_W, BOX_H)
  if o.big then return o end
  local box = o.box
  o.title:SetText("")
  o.close:Hide()
  o.head = UI.Text(box, 30, UI.TILE_GOLD, "fancy", "CENTER")
  o.head:SetPoint("TOP", 0, -20); o.head:SetWidth(BOX_W - 40)
  o.head:SetShadowOffset(1, -1); o.head:SetShadowColor(0, 0, 0, 1)
  o.sub = UI.Text(box, 13, "ink2", "book", "CENTER")
  o.sub:SetPoint("TOP", o.head, "BOTTOM", 0, -4)
  local div = UI.Divider(box)
  div:SetPoint("TOPLEFT", 40, -78); div:SetPoint("TOPRIGHT", -40, -78)
  -- Left: the big news. The picture round in the gold ring (at the ring's own size its hole is 58 for 94), or a gold
  -- disc round it where the client has no ring.
  local left = CreateFrame("Frame", nil, box)
  left:SetPoint("TOPLEFT", 24, -96); left:SetSize(BOX_W - 24 - CARD_W - 24 - 30, BOX_H - 96 - 56)
  local lw = left:GetWidth()
  o.disc = UI.Round(left, "BORDER", PIC + 8)
  o.disc:SetPoint("TOP", 0, -46)
  ns.Theme:Fill(o.disc, "gold", 0.9)
  o.pic = UI.Round(left, "ARTWORK", PIC)
  o.pic:SetPoint("CENTER", o.disc)
  local ok = C_Texture ~= nil and C_Texture.GetAtlasInfo ~= nil and C_Texture.GetAtlasInfo(RING_ATLAS) ~= nil
  if ok then
    o.ring = left:CreateTexture(nil, "OVERLAY")
    o.ring:SetAtlas(RING_ATLAS)
    o.ring:SetSize(math.floor(PIC * 94 / 58), math.floor(PIC * 95 / 58))
    o.ring:SetPoint("CENTER", o.disc)
    o.disc:Hide()
  end
  o.bigTitle = UI.WrapText(left, 20, "ink", lw, "title")
  o.bigTitle:SetJustifyH("CENTER")
  o.bigTitle:SetPoint("TOP", o.disc, "BOTTOM", 0, -48)
  o.bigText = UI.WrapText(left, 14, "ink", lw - 10, "book")
  o.bigText:SetJustifyH("CENTER")
  o.bigText:SetPoint("TOP", o.bigTitle, "BOTTOM", 0, -8)
  o.big = left
  -- Right: two picture cards.
  o.cards = {}
  for i, c in ipairs(self.CARDS) do
    local card = UI.PictureTile(box, CARD_W, CARD_H, function(tex, w, h) N.Art(tex, c, w, h, 2) end)
    card:SetPoint("TOPRIGHT", -24, -96 - (i - 1) * (CARD_H + CARD_GAP))
    card:EnableMouse(false)
    o.cards[i] = card
  end
  o.ok = UI.TextButton(box, L.CONTINUE, function() o:Hide() end, "primary", 14)
  o.ok:SetPoint("BOTTOM", 0, 18)
  return o
end

-- Shows it now (marks it seen). False when the book is not made yet or during combat.
function N:Show()
  local W = ns.Window
  if not W.frame or ns.Combat:InCombat() then return false end
  local o = self:Build()
  o.head:SetText(L.NEWS_TITLE)
  o.sub:SetText(L.NEWS_SUB)
  N.Art(o.pic, self.BIG, PIC, PIC, 1)
  o.bigTitle:SetText(L[self.BIG.title])
  o.bigText:SetText(L[self.BIG.text])
  for i, c in ipairs(self.CARDS) do o.cards[i]:Set(L[c.title], L[c.text]) end
  o:Show()
  if ns.db then ns.db.newsSeen = self.ID end
  return true
end

-- /jtf news: opens the book and shows it, seen or not. In combat it waits until combat ends, as the toasts do
-- (only if the book is still open then).
function N:Open()
  local W = ns.Window
  W:WhenBuilt(function()
    W:Open()
    ns.Combat:AfterCombat(function() if W:IsOpen() then N:Show() end end)
  end)
end

-- When it is due: the book opened, or a fellowship was founded.
function N:ShowIfDue() if self:Pending() then return self:Show() end return false end
