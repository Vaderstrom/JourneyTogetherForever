-- The book: leather frame with gold trim, header, sidebar, two parchment pages and side panels.
-- Built in mockup pixels (the mockup's 1140 × 730, widened to 1280 on 27 Oct 2026 for longer lines and less
-- scrolling) and scaled as a whole.
-- Drag, saved position, scale and the open animation are adapted from GuildHall_Core/UI/Frame.lua.
local _, ns = ...
local L = ns.L
local UI, Theme, Pages, Combat = ns.UI, ns.Theme, ns.Pages, ns.Combat
local W = { page = "overview", startView = "welcome", panels = {}, panelDefs = {}, pageFrames = {}, navItems = {}, navGroups = {} }
ns.Window = W

local WIDTH, HEIGHT, HEADER = 1280, 730, 96
-- The window's gold and leather frame (Media\WindowFrame): corner size, and how far it reaches in. Its leather is
-- the outer 15/40 of a piece (18 of 48): 16 outside the window and 2 over its edge, so frame and window meet with
-- no gap; the rest reaching in is transparent, except the gold corners over the window's corners.
local FRAME_CORNER, FRAME_IN = 48, 32
-- What hangs outside the window and stays on the screen with it (window units, also its clamp insets): the logo on
-- the left and at the top, the frame's leather on the right and at the bottom.
local OUT_L, OUT_T, OUT_R, OUT_B = 64, 54, FRAME_CORNER - FRAME_IN, FRAME_CORNER - FRAME_IN
-- The logo's size, and in full screen (where it sits inside the header) its size and how far the header's crest,
-- name and chip move right to make room for it.
local LOGO, LOGO_FULL, HEAD_SHIFT = 156, 118, 48
-- A sidebar entry's height: 46, or less when more entries are shown than fit (12 with Raids, the tournament and
-- Admin: 42; 29 Oct 2026). NAV_SPACE is the sidebar's height, GROUP_H what a group label takes with its gap.
local NAV_ROW, NAV_SPACE, GROUP_H = 46, 600, 26
local NAV_IDS = { "overview", "chapter", "raids", "quests", "chronicle", "heroes", "gatherings", "manage", "tourney", "admin",
  "rules", "history" }
W.WIDTH, W.HEIGHT = WIDTH, HEIGHT
-- Width for content on one page: with the sidebar (pages of a fellowship) and without (start pages). Half the book
-- area (window, minus frame and sidebar) minus the page's edges and margins: 414 and 497 at the mockup's 1140.
W.PAGE_W = math.floor((WIDTH - 200) / 2 - 56)
W.PAGE_W_WIDE = math.floor((WIDTH - 34) / 2 - 56)

-- Side panels (Settings, Inbox, Your characters) register here: { title, build(panel), refresh(panel) }.
function W:RegisterPanel(key, def) self.panelDefs[key] = def end

---------------------------------------------------------------------------
-- Scale and position
---------------------------------------------------------------------------
-- 100% always fits the screen, whatever the game's UI scale: the window may use 86% of the screen height and 92% of
-- its width (with the wider book, narrow screens are limited by the width). Screens are measured in the game's UI
-- units: 768 high at any resolution unless the UI scale is set lower (a 4K screen at UI scale 0.66 is about 1160
-- high), so 100% is never larger than the book was drawn (1280 x 730).
function W:BaseScale()
  local h = UIParent:GetHeight() or HEIGHT
  local w = UIParent:GetWidth() or WIDTH
  return math.min(1, h * 0.86 / HEIGHT, w * 0.92 / WIDTH)
end

-- The largest scale at which the window, with what hangs outside it, fits the screen, FIT_MARGIN of the screen
-- clear on every side. Full screen uses it; the dragged size never goes past it (120% ran off a 768-high screen).
W.FIT_MARGIN = 0.01
function W:FitScale()
  local h = UIParent:GetHeight() or HEIGHT
  local w = UIParent:GetWidth() or WIDTH
  local keep = 1 - 2 * self.FIT_MARGIN
  return math.min(h * keep / (HEIGHT + OUT_T + OUT_B), w * keep / (WIDTH + OUT_L + OUT_R))
end

-- Full screen (Settings, or the button beside Close): the book fills the whole screen, its frame's leather reaching
-- the screen's edges, with the logo inside the header. Per character, like the book's place and size.
-- The room the screen has beyond the window is shared: the book is drawn bigger by half of it and its pages grow
-- taller by the other half, so long lists show more before they scroll (29 Oct 2026; it was only drawn bigger, the
-- same lines in larger print). The scale is between the window's and the largest that fits (their geometric mean).
-- It is as wide as the screen too (it kept the window's width, with dimmed gaps at the sides; 29 Oct 2026): every
-- page keeps the width it was laid out for, in the middle of its half of the book (W:PlaceTitle).
function W:IsFullscreen() return ns.Settings:Get("fullscreen") == true end
function W:SetFullscreen(on) ns.Settings:Set("fullscreen", on and true or false) end
function W:ToggleFullscreen() self:SetFullscreen(not self:IsFullscreen()) end

function W:WindowScale() return math.min(self:BaseScale() * ns.Settings:Get("size"), self:FitScale()) end
function W:FullScale() return math.sqrt(self:WindowScale() * self:FitScale()) end

-- The book's size in full screen at scale s: the whole screen less the frame's leather, which hangs outside it on
-- every side; never smaller than it was drawn.
function W:FullSize(s)
  s = s or self:FullScale()
  local w = UIParent:GetWidth() or WIDTH
  local h = UIParent:GetHeight() or HEIGHT
  return math.max(WIDTH, math.floor(w / s) - 2 * OUT_R), math.max(HEIGHT, math.floor(h / s) - 2 * OUT_B)
end

-- What hangs outside the book: left, top, right, bottom (window units). In full screen only the frame's leather;
-- the logo is inside.
function W:Outside()
  if self:IsFullscreen() then return OUT_R, OUT_B, OUT_R, OUT_B end
  return OUT_L, OUT_T, OUT_R, OUT_B
end

-- How far the header's crest, name and chip sit to the right of where they were drawn (full screen: of the logo).
function W:HeaderShift() return self:IsFullscreen() and HEAD_SHIFT or 0 end

function W:Scale()
  if self:IsFullscreen() then return self:FullScale() end
  return self:WindowScale()
end

local function savePosition(f)
  local point, _, rel, x, y = f:GetPoint()
  ns.char.window = { point = point, rel = rel, x = x, y = y }
end

local function placeFrame(f)
  f:ClearAllPoints()
  local p = ns.char.window
  if W:IsFullscreen() then
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  elseif p and p.point then f:SetPoint(p.point, UIParent, p.rel or p.point, p.x or 0, p.y or 0)
  else f:SetPoint("CENTER", UIParent, "CENTER", 0, 0) end
end

-- The logo: a seal on the window's top-left corner, the middle of its ring on the corner stud; in full screen inside
-- the header (the corner is at the screen's edge). The window stays on the screen with what hangs outside it.
local function placeLogo(f, full)
  local logo = f.logo
  logo:ClearAllPoints()
  if full then
    logo:SetSize(LOGO_FULL, LOGO_FULL)
    logo:SetPoint("CENTER", f, "TOPLEFT", 72, -49)
  else
    logo:SetSize(LOGO, LOGO)
    logo:SetPoint("CENTER", f, "TOPLEFT", 0, 2)
  end
  local l, t, r, b = W:Outside()
  f:SetClampRectInsets(-l, r, t, -b)
end

-- The window's scale, size and place for the screen and the mode, the logo, the corner grip and the dimmed screen
-- behind it. (The pages' scrolling lists follow the size: they are anchored to the pages.)
function W:ApplyScale()
  local f = self.frame
  if not f then return end
  local full = self:IsFullscreen()
  local s = self:Scale()
  local width, height = WIDTH, HEIGHT
  if full then width, height = self:FullSize(s) end
  local resized = width ~= f:GetWidth() or height ~= f:GetHeight()
  f:SetSize(width, height)
  f:SetScale(s)
  placeFrame(f)
  placeLogo(f, full)
  f.grip:SetShown(not full)
  f.backdrop:SetShown(full and f:IsShown())
  f.header.full:Paint()
  -- The header's art, the sidebar and where the pages sit follow the size.
  if resized and f:IsShown() then self:Refresh() end
end

-- The window's rectangle on the screen with what hangs outside it, in UIParent units: left, bottom, right, top (for
-- the self-test and the tests: it must lie on the screen).
function W:Extents()
  local f = self.frame
  if not f then return nil end
  local s = f:GetScale()
  local l, b = f:GetLeft(), f:GetBottom()
  if not l or not b then return nil end
  l, b = l * s, b * s
  local ol, ot, orr, ob = self:Outside()
  return l - ol * s, b - ob * s, l + f:GetWidth() * s + orr * s, b + f:GetHeight() * s + ot * s
end

-- Resizing: dragging the bottom-right corner scales the whole book (80% to 120%); the top-left corner stays put.
-- Positions here are in UIParent units.
function W:ResizeTo(cursorX, cursorY)
  local f, r = self.frame, self.resizing
  local ratio = math.max((cursorX - r.left) / WIDTH, (r.top - cursorY) / HEIGHT)
  local S = ns.Settings
  local most = math.max(S.SIZE_MIN, math.min(S.SIZE_MAX, self:FitScale() / self:BaseScale()))
  local size = ns.Clamp(math.floor(ratio / self:BaseScale() * 100 + 0.5) / 100, S.SIZE_MIN, most)
  local scale = self:BaseScale() * size
  f:SetScale(scale)
  f:ClearAllPoints()
  f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", r.left / scale, r.top / scale)
  r.size = size
end

function W:StartResize()
  local f = self.frame
  local s = f:GetEffectiveScale() / UIParent:GetEffectiveScale()
  self.resizing = { left = f:GetLeft() * s, top = f:GetTop() * s, size = ns.Settings:Get("size") }
  f.grip:SetScript("OnUpdate", function()
    local cx, cy = GetCursorPosition()
    local ui = UIParent:GetEffectiveScale()
    W:ResizeTo(cx / ui, cy / ui)
  end)
end

function W:StopResize()
  local r = self.resizing
  if not r then return end
  self.frame.grip:SetScript("OnUpdate", nil)
  self.resizing = nil
  savePosition(self.frame)
  ns.Settings:SetSize(r.size)
end

---------------------------------------------------------------------------
-- Parts of the window
---------------------------------------------------------------------------
local function buildFrame()
  -- Named so that ESC can close it (UISpecialFrames needs a frame name).
  local f = CreateFrame("Frame", "JourneyTogetherForeverFrame", UIParent, "BackdropTemplate")
  f:SetSize(WIDTH, HEIGHT)
  f:SetFrameStrata("HIGH")
  f:SetToplevel(true)
  f:SetClampedToScreen(true)
  f:SetMovable(true)
  f:EnableMouse(true)
  f:SetBackdrop({ bgFile = ns.WHITE, edgeFile = ns.WHITE, edgeSize = 2 })
  tinsert(UISpecialFrames, "JourneyTogetherForeverFrame")
  -- Background picture, faint.
  f.bgArt = f:CreateTexture(nil, "BACKGROUND", nil, 2)
  f.bgArt:SetPoint("TOPLEFT", 2, -2); f.bgArt:SetPoint("BOTTOMRIGHT", -2, 2)
  f.bgArt:SetAlpha(0.16)
  -- The frame: the dialogs' and big moments' gold and leather (Media\DialogFrame), mostly outside the window so it
  -- covers only its edge, drawn above the header so the corners show. (It was a thin gold line with tilted squares
  -- on the corners, which did not fit the book; seen in game, 27 Oct 2026.) Without the file: the thin line, plus
  -- a dark inner line.
  local frameArt = CreateFrame("Frame", nil, f)
  frameArt:SetAllPoints()
  frameArt:SetFrameLevel(f:GetFrameLevel() + 30)
  f.frameArt = frameArt
  local framed = UI.DialogFrame(f, { on = frameArt, corner = FRAME_CORNER, out = FRAME_CORNER - FRAME_IN, border = true,
    file = "WindowFrame" })
  Theme:Backdrop(f, "frame", 1, "gold", framed and 0 or 1)
  if not framed then
    local inner = UI.Box(f, 3, nil, nil, "dark", 1)
    inner:SetPoint("TOPLEFT", 2, -2); inner:SetPoint("BOTTOMRIGHT", -2, 2)
  end
  -- Resize grip in the bottom-right corner.
  local grip = CreateFrame("Button", nil, f)
  grip:SetSize(18, 18)
  grip:SetPoint("BOTTOMRIGHT", -9, 9)
  grip:SetFrameLevel(f:GetFrameLevel() + 35)
  grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
  grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
  grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
  grip:SetScript("OnMouseDown", function() if not W:IsFullscreen() then W:StartResize() end end)
  grip:SetScript("OnMouseUp", function() W:StopResize() end)
  f.grip = grip
  -- Opening: fades and grows in (not with Reduce effects).
  local ag = f:CreateAnimationGroup()
  local fade = ag:CreateAnimation("Alpha"); fade:SetFromAlpha(0); fade:SetToAlpha(1); fade:SetDuration(0.18)
  local grow = ag:CreateAnimation("Scale"); grow:SetDuration(0.18)
  if grow.SetScaleFrom then grow:SetScaleFrom(0.96, 0.96); grow:SetScaleTo(1, 1) end
  f.openAnim = ag
  f.backdrop = W:BuildBackdrop()
  return f
end

-- Full screen: the screen behind the book dimmed, darker towards its edges. On the screen rather than on the book
-- (the book's open animation would shrink it with the book), under the book and over the game's bars and the
-- tracker. Clicks on it go nowhere; Esc and Close close the book as always.
function W:BuildBackdrop()
  local bd = CreateFrame("Frame", nil, UIParent)
  bd:SetAllPoints(UIParent)
  bd:SetFrameStrata("MEDIUM")
  bd:SetFrameLevel(5000)
  bd:EnableMouse(true)
  local dim = bd:CreateTexture(nil, "BACKGROUND")
  dim:SetAllPoints(); dim:SetColorTexture(0, 0, 0, 0.78)
  for _, side in ipairs({ "LEFT", "RIGHT", "TOP", "BOTTOM" }) do
    local across = side == "LEFT" or side == "RIGHT"
    local t = bd:CreateTexture(nil, "BORDER")
    t:SetPoint(side)
    if across then t:SetPoint("TOP"); t:SetPoint("BOTTOM"); t:SetWidth(220) else t:SetPoint("LEFT"); t:SetPoint("RIGHT"); t:SetHeight(160) end
    local dark, clear = { 0, 0, 0, 0.6 }, { 0, 0, 0, 0 }
    -- (A gradient runs left to right, or bottom to top.)
    local first = (side == "LEFT" or side == "BOTTOM") and dark or clear
    UI.SetGradient(t, across and "HORIZONTAL" or "VERTICAL", first, first == dark and clear or dark)
  end
  local ag = bd:CreateAnimationGroup()
  local a = ag:CreateAnimation("Alpha"); a:SetFromAlpha(0); a:SetToAlpha(1); a:SetDuration(0.25)
  bd:SetScript("OnShow", function() if not ns.Settings:Get("reduce") then ag:Stop(); ag:Play() end end)
  bd:Hide()
  return bd
end

local function buildHeader(f)
  local h = CreateFrame("Frame", nil, f)
  h:SetPoint("TOPLEFT", 2, -2); h:SetPoint("TOPRIGHT", -2, -2); h:SetHeight(HEADER - 2)
  h:EnableMouse(true)
  h:RegisterForDrag("LeftButton")
  -- (Full screen stays in the middle.)
  h:SetScript("OnDragStart", function() if not W:IsFullscreen() then f:StartMoving() end end)
  h:SetScript("OnDragStop", function() f:StopMovingOrSizing(); if not W:IsFullscreen() then savePosition(f) end end)
  h.art = h:CreateTexture(nil, "BACKGROUND", nil, 1)
  h.art:SetAllPoints()
  -- Dark fade from the left, over the picture (or over the frame colour).
  local split = math.floor((WIDTH - 4) * 0.38)
  local shade1 = UI.GradientTex(h, "BACKGROUND", "HORIZONTAL", { "shade", 0.95 }, { "shade", 0.70 }, 2)
  shade1:SetPoint("TOPLEFT"); shade1:SetPoint("BOTTOMLEFT"); shade1:SetWidth(split)
  local shade2 = UI.GradientTex(h, "BACKGROUND", "HORIZONTAL", { "shade", 0.70 }, { "shade", 0.05 }, 2)
  shade2:SetPoint("TOPLEFT", shade1, "TOPRIGHT"); shade2:SetPoint("BOTTOMRIGHT")
  local line = UI.Solid(h, "BORDER", "gold")
  line:SetPoint("BOTTOMLEFT"); line:SetPoint("BOTTOMRIGHT"); line:SetHeight(2)

  -- Logo, a seal on the top-left corner (placeLogo). Logo.tga is square with the ring in the middle: 156 wide shows
  -- the logo about 117 high.
  local logo = CreateFrame("Frame", nil, f)
  logo:SetSize(LOGO, LOGO)
  logo:SetPoint("CENTER", f, "TOPLEFT", 0, 2)
  logo:SetFrameLevel(f:GetFrameLevel() + 40)
  f.logo = logo
  f:SetClampRectInsets(-OUT_L, OUT_R, OUT_T, -OUT_B)
  local lt = logo:CreateTexture(nil, "ARTWORK")
  lt:SetAllPoints()
  lt:SetTexture(ns.MEDIA .. "Logo")

  -- Fellowship crest, name and chip.
  h.crest = UI.Crest(h, 30, 38)
  h.crest:SetPoint("TOPLEFT", h, "TOPLEFT", 96, -17)
  h.name = UI.Text(h, 26, "goldText", "title")
  h.name:SetShadowOffset(0, -2); h.name:SetShadowColor(0, 0, 0, 1)
  h.chip = UI.Box(h, 1, "000000", 0.45, "gold", 0.5)
  h.chip:SetHeight(20)
  h.chip.text = UI.Text(h.chip, 12, "chipText", "body", "CENTER")
  h.chip.text:SetPoint("CENTER")

  -- Buttons on the right: Your characters, Inbox, Settings, Close.
  -- Close: the game's own close button (the red cross every window has), in the window's top-right corner over the
  -- frame, as on the game's windows (it sat in the header row and read as one more round button; seen in game).
  h.close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  h.close:SetPoint("TOPRIGHT", f, "TOPRIGHT", 6, 6)
  h.close:SetFrameLevel(f:GetFrameLevel() + 45)
  h.close:SetScript("OnClick", function() W:Close() end)
  h.full = W:BuildFullButton(f, h.close)
  h.settings = UI.RoundButton(h, 40, "settings", function() W:ToggleSettings() end)
  h.settings:SetPoint("RIGHT", h, "RIGHT", -24, 0)
  h.inbox = UI.RoundButton(h, 40, "inbox", function() W:TogglePanel("inbox") end)
  h.inbox:SetPoint("RIGHT", h.settings, "LEFT", -8, 0)
  h.inbox.badge = UI.Badge(h.inbox)
  h.inbox.badge:SetPoint("TOPRIGHT", 4, 4)
  h.inbox.badge:SetFrameLevel(h.inbox:GetFrameLevel() + 5)
  h.chars = UI.RoundButton(h, 40, "characters", function() W:TogglePanel("characters") end)
  h.chars:SetPoint("RIGHT", h.inbox, "LEFT", -8, 0)
  for key, b in pairs({ chars = h.chars, inbox = h.inbox, settings = h.settings, close = h.close }) do
    local label = ({ chars = L.YOUR_CHARACTERS, inbox = L.INBOX, settings = L.SETTINGS, close = L.CLOSE })[key]
    b:SetScript("OnEnter", function() GameTooltip:SetOwner(b, "ANCHOR_BOTTOM"); GameTooltip:SetText(label); GameTooltip:Show() end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  end
  return h
end

-- Full screen on and off: the game's red expand and condense buttons beside Close, as on its world map. Without
-- that art: the older game's bigger and smaller buttons; without those, a plain button.
local BIG, SMALL = "Interface\\Buttons\\UI-Panel-BiggerButton-", "Interface\\Buttons\\UI-Panel-SmallerButton-"
function W:BuildFullButton(f, close)
  local atlas = C_Texture ~= nil and C_Texture.GetAtlasInfo ~= nil and C_Texture.GetAtlasInfo("RedButton-Expand") ~= nil
    and C_Texture.GetAtlasInfo("RedButton-Condense") ~= nil
  local probe = f:CreateTexture()
  local files = not atlas and probe:SetTexture(BIG .. "Up") ~= false and probe:SetTexture(SMALL .. "Up") ~= false
  probe:Hide()
  local b
  if atlas or files then
    b = CreateFrame("Button", nil, f)
    local w, h = close:GetSize()
    b:SetSize((w or 0) > 0 and w or 24, (h or 0) > 0 and h or 24)
    if atlas then b:SetHighlightAtlas("RedButton-Highlight", "ADD")
    else b:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight", "ADD") end
    function b:Paint()
      local on = W:IsFullscreen()
      if atlas then
        self:SetNormalAtlas(on and "RedButton-Condense" or "RedButton-Expand")
        self:SetPushedAtlas(on and "RedButton-Condense-Pressed" or "RedButton-Expand-Pressed")
      else
        self:SetNormalTexture((on and SMALL or BIG) .. "Up")
        self:SetPushedTexture((on and SMALL or BIG) .. "Down")
      end
    end
  else
    b = UI.TextButton(f, L.FULLSCREEN, nil, "plain", 12)
    function b:Paint() self:SetLabel(W:IsFullscreen() and L.FULLSCREEN_LEAVE or L.FULLSCREEN) end
  end
  b:SetPoint("RIGHT", close, "LEFT", -2, 0)
  b:SetFrameLevel(close:GetFrameLevel())
  b:SetScript("OnClick", function() W:ToggleFullscreen() end)
  b:SetScript("OnEnter", function()
    GameTooltip:SetOwner(b, "ANCHOR_BOTTOM")
    GameTooltip:SetText(W:IsFullscreen() and L.FULLSCREEN_LEAVE or L.FULLSCREEN)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  b:Paint()
  return b
end

-- Sidebar: one button per page that can appear, and up to three group labels.
local function buildNav(body)
  local nav = CreateFrame("Frame", nil, body)
  nav:SetPoint("TOPLEFT", 0, -4); nav:SetPoint("BOTTOMLEFT"); nav:SetWidth(178)
  for i = 1, 3 do
    local g = CreateFrame("Frame", nil, nav)
    g:SetSize(178, 14)
    g.text = UI.Text(g, 10, "gold", "body")
    g.text:SetPoint("LEFT", 14, 0)
    g.line = UI.Solid(g, "ARTWORK", "gold", 0.35)
    g.line:SetHeight(1)
    g.line:SetPoint("LEFT", g.text, "RIGHT", 6, 0); g.line:SetPoint("RIGHT", g, "RIGHT", 0, 0)
    W.navGroups[i] = g
  end
  for _, id in ipairs(NAV_IDS) do
    local b = CreateFrame("Button", nil, nav)
    -- Larger icons (28 in a 36 ring; they were 18 and hard to see, with room to spare in the sidebar; seen in game).
    b:SetSize(180, NAV_ROW)
    b.ribbon = UI.GradientTex(b, "BACKGROUND", "HORIZONTAL", { "ribbon1", 1 }, { "ribbon2", 1 })
    b.ribbon:SetAllPoints()
    b.edge = UI.Box(b, 1, nil, nil, "gold", 0.8)
    b.edge:SetAllPoints()
    b.redEdge = UI.Solid(b, "BORDER", "ribbon2")
    b.redEdge:SetPoint("TOPLEFT", b, "TOPRIGHT", 0, 0); b.redEdge:SetPoint("BOTTOMLEFT", b, "BOTTOMRIGHT", 0, 0); b.redEdge:SetWidth(3)
    local ring = UI.Round(b, "ARTWORK", 36, 1)
    ring:SetPoint("LEFT", 10, 0)
    Theme:Fill(ring, "gold", 0.6)
    local hole = UI.Round(b, "ARTWORK", 33, 2)
    hole:SetPoint("CENTER", ring)
    Theme:Fill(hole, "000000", 0.6)
    b.icon = UI.Round(b, "ARTWORK", 28, 3)
    b.icon:SetPoint("CENTER", ring)
    UI.SetIcon(b.icon, ns.ICONS[id] or ns.ICONS.rules)
    b.label = UI.Text(b, 15, nil, "title")
    b.label:SetPoint("LEFT", ring, "RIGHT", 10, 0)
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints(); hl:SetColorTexture(1, 1, 1, 0.06)
    b:SetScript("OnClick", function() W:ShowPage(id) end)
    -- A count on the bookmark (Manage: things that need attention).
    b.badge = UI.Badge(b)
    b.badge:SetPoint("RIGHT", -10, 0)
    b.badge:SetCount(0)
    b.id = id
    W.navItems[id] = b
  end
  return nav
end

local SHEET_W = (WIDTH - 18 - 182 - 8) / 2 -- one page of the book

-- One page's paper on frame t: the theme's colours, the game's parchment over them, tinted per theme, a wash and a
-- shadow towards the spine. The Journal theme uses the Adventure Guide's book instead (its left or right half), when
-- the game has it. Drawn on the page, and again on the copies its scrolling lists fade into (UI.Scroll).
-- book: the book of a page (its paper hides on the flat sheet); nil for a copy. Returns the textures to hide on the
-- flat sheet, every texture, and the painter.
local function pagePaper(t, left, book)
  local outer = math.floor(SHEET_W * 0.16)
  local inner = math.floor(SHEET_W * 0.11)
  local mid = UI.Solid(t, "BACKGROUND", "page1")
  local out = UI.GradientTex(t, "BACKGROUND", "HORIZONTAL", left and { "page2", 1 } or { "page1", 1 }, left and { "page1", 1 } or { "page2", 1 })
  local spine = UI.GradientTex(t, "BACKGROUND", "HORIZONTAL", left and { "page1", 1 } or { "page2", 1 }, left and { "page2", 1 } or { "page1", 1 })
  local bg = { mid, out, spine }
  out:SetWidth(outer); spine:SetWidth(inner)
  if left then
    out:SetPoint("TOPLEFT"); out:SetPoint("BOTTOMLEFT")
    spine:SetPoint("TOPRIGHT"); spine:SetPoint("BOTTOMRIGHT")
    mid:SetPoint("TOPLEFT", out, "TOPRIGHT"); mid:SetPoint("BOTTOMRIGHT", spine, "BOTTOMLEFT")
  else
    out:SetPoint("TOPRIGHT"); out:SetPoint("BOTTOMRIGHT")
    spine:SetPoint("TOPLEFT"); spine:SetPoint("BOTTOMLEFT")
    mid:SetPoint("TOPLEFT", spine, "TOPRIGHT"); mid:SetPoint("BOTTOMRIGHT", out, "BOTTOMLEFT")
  end
  local paper = t:CreateTexture(nil, "BACKGROUND", nil, 2)
  paper:SetAllPoints()
  local guide = t:CreateTexture(nil, "BACKGROUND", nil, 2)
  guide:SetAllPoints()
  local b = ns.EJ_BOOK_BOX
  local half = (b[1] + b[2]) / 2
  local hasGuide = guide:SetTexture(ns.EJ_BOOK) ~= false
  if left then guide:SetTexCoord(b[1], half, b[3], b[4]) else guide:SetTexCoord(half, b[2], b[3], b[4]) end
  guide:Hide()
  local all, paint = { mid, out, spine, paper, guide }, nil
  if ns.SetPaper(paper) or hasGuide then
    paint = function()
      local useGuide = hasGuide and Theme:Key() == "journal"
      local flat = book ~= nil and book.flat
      guide:SetShown(useGuide and not flat); paper:SetShown(not useGuide and not flat)
      paper:SetVertexColor(unpack(Theme.PAPER_TINT[Theme:Key()] or Theme.PAPER_TINT.journal))
    end
    Theme:Register(paint)
    local wash = UI.Solid(t, "BACKGROUND", "page1", Theme.PAPER_WASH, 3)
    wash:SetAllPoints()
    local shade = UI.GradientTex(t, "BACKGROUND", "HORIZONTAL", left and { "000000", 0 } or { "000000", 0.28 },
      left and { "000000", 0.28 } or { "000000", 0 }, 4)
    shade:SetWidth(inner)
    if left then shade:SetPoint("TOPRIGHT"); shade:SetPoint("BOTTOMRIGHT") else shade:SetPoint("TOPLEFT"); shade:SetPoint("BOTTOMLEFT") end
    bg[#bg + 1] = wash; bg[#bg + 1] = shade
    all[#all + 1] = wash; all[#all + 1] = shade
  else
    paper:Hide()
  end
  return bg, all, paint
end

-- The flat sheet's paper on frame t (the book, or a copy of it). Returns its textures and whether the game had the
-- parchment.
local function sheetPaper(t, sublevel)
  local smid = UI.Solid(t, "ARTWORK", "page1", 1, sublevel)
  smid:SetPoint("TOPLEFT", 3, -3); smid:SetPoint("BOTTOMRIGHT", -3, 3)
  local spaper = t:CreateTexture(nil, "ARTWORK", nil, sublevel + 1)
  spaper:SetAllPoints(smid)
  local hasPaper = ns.SetPaper(spaper)
  if not hasPaper then spaper:Hide() end
  local swash = UI.Solid(t, "ARTWORK", "page1", Theme.PAPER_WASH, sublevel + 2)
  swash:SetAllPoints(smid)
  local edge = math.floor(SHEET_W * 0.16)
  local sl = UI.GradientTex(t, "ARTWORK", "HORIZONTAL", { "page2", 1 }, { "page1", 0 }, sublevel + 3)
  sl:SetPoint("TOPLEFT", smid); sl:SetPoint("BOTTOMLEFT", smid); sl:SetWidth(edge)
  local sr = UI.GradientTex(t, "ARTWORK", "HORIZONTAL", { "page1", 0 }, { "page2", 1 }, sublevel + 3)
  sr:SetPoint("TOPRIGHT", smid); sr:SetPoint("BOTTOMRIGHT", smid); sr:SetWidth(edge)
  Theme:Register(function() spaper:SetVertexColor(unpack(Theme.PAPER_TINT[Theme:Key()] or Theme.PAPER_TINT.journal)) end)
  return { smid, spaper, swash, sl, sr }, hasPaper
end

-- An insert's paper on frame t (the insert, or a copy of it): a light-to-dark sheet with the game's parchment.
local function insertPaper(t)
  local bg = UI.GradientTex(t, "BACKGROUND", "VERTICAL", { "page2", 1 }, { "page1", 1 })
  bg:SetPoint("TOPLEFT", 2, -2); bg:SetPoint("BOTTOMRIGHT", -2, 2)
  local paper = t:CreateTexture(nil, "BACKGROUND", nil, 2)
  paper:SetAllPoints(bg)
  if ns.SetPaper(paper) then
    Theme:Register(function() paper:SetVertexColor(unpack(Theme.PAPER_TINT[Theme:Key()] or Theme.PAPER_TINT.journal)) end)
    local wash = UI.Solid(t, "BACKGROUND", "page1", Theme.PAPER_WASH, 3)
    wash:SetAllPoints(bg)
    return { bg, paper, wash }
  end
  paper:Hide()
  return { bg, paper }
end

-- Two parchment pages with a darker edge and a spine in the middle.
local function buildBook(area)
  local book = UI.Box(area, 3, nil, nil, "bookEdge", 1)
  book:SetAllPoints()
  local function page(left)
    local p = CreateFrame("Frame", nil, book)
    local bg, _, paint = pagePaper(p, left, book)
    p.bg, p.paint = bg, paint -- p.bg: the page's own paper, hidden on the flat sheet (book:SetFlat)
    -- What the lower edge of a scrolling list fades into (UI.Scroll): this paper, while the book is open.
    p.paper = function(t) return select(2, pagePaper(t, left)) end
    p.paperShown = function() return not book.flat end
    return p
  end
  book.left, book.right = page(true), page(false)
  book.left:SetPoint("TOPLEFT", 3, -3); book.left:SetPoint("BOTTOMRIGHT", book, "BOTTOM", -1, 3)
  book.right:SetPoint("TOPLEFT", book, "TOP", 1, -3); book.right:SetPoint("BOTTOMRIGHT", -3, 3)
  local fold = book:CreateTexture(nil, "ARTWORK")
  fold:SetColorTexture(0, 0, 0, 0.25)
  fold:SetPoint("TOPLEFT", book.left, "TOPRIGHT"); fold:SetPoint("BOTTOMRIGHT", book.right, "BOTTOMLEFT")

  -- The flat sheet: one paper over the whole book, no spine and no fold, for the pages that are tools rather than
  -- reading (Journey Admin, Settings; decided 29 Oct 2026, after the fold cut through Journey Admin's ruler like a
  -- black string). On the book frame, under the pages, whose own paper hides meanwhile.
  local sheet, hasPaper = sheetPaper(book, -8)
  local spaper = sheet[2]
  for _, t in ipairs(sheet) do t:Hide() end
  book.paper = function(t) return (sheetPaper(t, -8)) end
  book.paperShown = function() return book.flat end
  function book:SetFlat(on)
    on = on and true or false
    if self.flat == on then return end
    self.flat = on
    for _, t in ipairs(sheet) do t:SetShown(on and (t ~= spaper or hasPaper)) end
    fold:SetShown(not on)
    for _, p in ipairs({ self.left, self.right }) do
      for _, t in ipairs(p.bg) do t:SetShown(not on) end
      if p.paint then p.paint() end
    end
  end
  book.flat = false
  -- Page title (shared by every page), at the top of the left page: the title on the paper, the subtitle and a
  -- divider under it. (Nothing behind the title: the guide's dark smear and our parchment plate both covered text
  -- and looked out of place; seen in game.)
  book.title = UI.Text(book.left, 20, "ink", "title", "CENTER")
  book.title:SetPoint("TOP", 0, -22)
  book.sub = UI.Text(book.left, 12, "ink2", "body", "CENTER")
  book.sub:SetPoint("TOP", book.title, "BOTTOM", 0, -4)
  book.divider = UI.Divider(book.left)
  book.divider:SetPoint("TOPLEFT", 26, -66); book.divider:SetPoint("TOPRIGHT", -26, -66)
  return book
end

-- Frame levels over the book's area: the pages (a list's fade is 20 over its scroll frame, UI.Scroll), the panels
-- laid over them, and the questions and overlays over everything in the book. A panel's own list fade drew over the
-- question at +60 (30 Oct 2026).
W.LAYER = { panel = 40, overlay = 100 }

-- A side panel as a bookmarked insert: a loose sheet laid over the right page, a little in from the book's edges,
-- with a drop shadow, and a ribbon with the panel's icon hanging over its top edge like a bookmark (29 Oct 2026; it
-- was a strip glued to the book's right edge). It slides in as it opens.
local function buildPanel(area, key, def)
  local p = UI.Box(area, 2, nil, nil, "gold", 1)
  p.layoutCover = true -- hides the page under it (Dev/Layout.lua)
  p:SetPoint("TOPRIGHT", -22, -20); p:SetPoint("BOTTOMRIGHT", -22, 16); p:SetWidth(380)
  p:SetFrameLevel(area:GetFrameLevel() + W.LAYER.panel)
  p:EnableMouse(true)
  insertPaper(p)
  p.paper = insertPaper
  -- The shadow it casts on the page: to the left and below (the light comes from the top right).
  local shadow = UI.GradientTex(p, "BACKGROUND", "HORIZONTAL", { "000000", 0 }, { "000000", 0.45 }, -8)
  shadow:SetPoint("TOPRIGHT", p, "TOPLEFT", 0, -8); shadow:SetPoint("BOTTOMRIGHT", p, "BOTTOMLEFT", 0, -10); shadow:SetWidth(16)
  local under = UI.GradientTex(p, "BACKGROUND", "VERTICAL", { "000000", 0 }, { "000000", 0.4 }, -8)
  under:SetPoint("TOPLEFT", p, "BOTTOMLEFT", 0, 0); under:SetPoint("TOPRIGHT", p, "BOTTOMRIGHT", -8, 0); under:SetHeight(10)
  -- The bookmark: the sidebar's ribbon colours, gold edges, the icon, and a swallowtail cut in its end
  -- (Media\RibbonMask; it was a square of page colour turned on its corner, which showed as a white diamond on the
  -- parchment; seen in the seventh check).
  local RIB_W, RIB_H, CUT = 34, 66, 12.4
  local rib = CreateFrame("Frame", nil, p)
  rib:SetSize(RIB_W, RIB_H)
  rib:SetPoint("TOPLEFT", p, "TOPLEFT", 16, 14)
  rib:SetFrameLevel(p:GetFrameLevel() + 6)
  local cloth = UI.GradientTex(rib, "BACKGROUND", "HORIZONTAL", { "ribbon1", 1 }, { "ribbon2", 1 })
  cloth:SetAllPoints()
  local mask = rib:CreateMaskTexture()
  mask:SetTexture(ns.MEDIA .. "RibbonMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
  mask:SetAllPoints()
  cloth:AddMaskTexture(mask)
  for _, side in ipairs({ "LEFT", "RIGHT" }) do
    local e = UI.Solid(rib, "BORDER", "gold", 0.85)
    e:SetWidth(1); e:SetPoint("TOP" .. side); e:SetPoint("BOTTOM" .. side)
  end
  -- Gold along the cut too, from each lower corner up to the middle.
  local len, angle = math.sqrt((RIB_W / 2) ^ 2 + CUT ^ 2), math.atan2(CUT, RIB_W / 2)
  for _, side in ipairs({ -1, 1 }) do
    local e = UI.Solid(rib, "BORDER", "gold", 0.85)
    e:SetSize(len, 1)
    e:SetPoint("CENTER", rib, "BOTTOM", side * RIB_W / 4, CUT / 2)
    e:SetRotation(-side * angle)
  end
  local ribShadow = UI.GradientTex(rib, "BACKGROUND", "HORIZONTAL", { "000000", 0.35 }, { "000000", 0 }, -8)
  ribShadow:SetPoint("TOPLEFT", rib, "TOPRIGHT"); ribShadow:SetPoint("BOTTOMLEFT", rib, "BOTTOMRIGHT", 0, 12); ribShadow:SetWidth(5)
  rib.icon = UI.Round(rib, "OVERLAY", 22)
  rib.icon:SetPoint("TOP", 0, -24)
  UI.SetIcon(rib.icon, ns.ICONS[def.icon or key])
  p.ribbon = rib
  p.title = UI.Text(p, 19, "ink", "title")
  p.title:SetPoint("TOPLEFT", 62, -16)
  p.title:SetText(def.title)
  p.close = UI.RoundButton(p, 30, "close", function() W:TogglePanel(key) end, "line", "page1", "ink2")
  p.close:SetPoint("TOPRIGHT", -14, -10)
  -- Sliding in from the right as it opens (not with Reduce effects; W:TogglePanel plays it).
  local ag = p:CreateAnimationGroup()
  local at = ag:CreateAnimation("Translation"); at:SetOffset(40, 0); at:SetDuration(0); at:SetOrder(1)
  local hidden = ag:CreateAnimation("Alpha"); hidden:SetFromAlpha(0); hidden:SetToAlpha(0); hidden:SetDuration(0); hidden:SetOrder(1)
  local slide = ag:CreateAnimation("Translation"); slide:SetOffset(-40, 0); slide:SetDuration(0.2); slide:SetOrder(2)
  if slide.SetSmoothing then slide:SetSmoothing("OUT") end
  local fade = ag:CreateAnimation("Alpha"); fade:SetFromAlpha(0); fade:SetToAlpha(1); fade:SetDuration(0.2); fade:SetOrder(2)
  p.slideIn = ag
  p.scroll = UI.Scroll(p)
  p.scroll:SetPoint("TOPLEFT", 18, -66); p.scroll:SetPoint("BOTTOMRIGHT", -18, 16)
  p.body = p.scroll.child
  p.body:SetWidth(344)
  p.width = 344
  p.key = key
  if def.build then def.build(p) end
  p:Hide()
  return p
end

---------------------------------------------------------------------------
-- Build (out of combat only) and show
---------------------------------------------------------------------------
function W:Build()
  if self.frame then return self.frame end
  local f = buildFrame()
  self.frame = f
  f.header = buildHeader(f)
  local body = CreateFrame("Frame", nil, f)
  body:SetPoint("TOPLEFT", 2, -(HEADER + 14)); body:SetPoint("BOTTOMRIGHT", -16, 16)
  body:SetSize(WIDTH - 18, HEIGHT - HEADER - 30)
  f.body = body
  f.nav = buildNav(body)
  f.area = CreateFrame("Frame", nil, body)
  f.area:SetPoint("TOPRIGHT"); f.area:SetPoint("BOTTOMRIGHT")
  f.area:SetSize(WIDTH - 18 - 178 - 4, HEIGHT - HEADER - 30)
  f.book = buildBook(f.area)
  -- Every page gets its frame now, so nothing is created later (for example during combat).
  for id, def in pairs(Pages.pages) do
    local pf = CreateFrame("Frame", nil, f.book)
    pf:SetAllPoints()
    pf.left = CreateFrame("Frame", nil, f.book.left)
    pf.left:SetPoint("TOPLEFT", 26, -78); pf.left:SetPoint("BOTTOMRIGHT", -26, 22)
    pf.right = CreateFrame("Frame", nil, f.book.right)
    pf.right:SetPoint("TOPLEFT", 26, -22); pf.right:SetPoint("BOTTOMRIGHT", -26, 22)
    if def.build then def.build(pf) end
    pf:Hide(); pf.left:Hide(); pf.right:Hide()
    self.pageFrames[id] = pf
  end
  for key, def in pairs(self.panelDefs) do self.panels[key] = buildPanel(f.area, key, def) end
  self:BuildConfirm(f.area)
  placeFrame(f)
  self:ApplyScale()
  f:Hide()
  f:SetScript("OnShow", function()
    f.backdrop:SetShown(W:IsFullscreen())
    if not ns.Settings:Get("reduce") then f.openAnim:Stop(); f.openAnim:Play() end
    ns.Sound("open")
    W:Refresh()
  end)
  f:SetScript("OnHide", function()
    f.backdrop:Hide()
    W:HidePanels(); ns.Sound("close")
    W:LeavePage(W.current)
    -- Closing the book ends watching another character's fellowship; it opens on your own next time.
    -- Closing it also ends the walkthrough (UI/Walkthrough.lua).
    local WT = ns.Watch
    if WT and WT.active then WT.active, WT.fid, WT.as, WT.demo = false, nil, nil, nil end
    if ns.Walkthrough and ns.Walkthrough.on then ns.Walkthrough:Stop() end
  end)
  -- A page turn (M20): the pages fade in from half when another page opens (not with Reduce effects).
  f.turn = {}
  for _, side in ipairs({ "left", "right" }) do
    local ag = f.book[side]:CreateAnimationGroup()
    local a = ag:CreateAnimation("Alpha"); a:SetFromAlpha(0.25); a:SetToAlpha(1); a:SetDuration(0.22)
    if a.SetSmoothing then a:SetSmoothing("OUT") end
    f.turn[side] = ag
  end
  return f
end

-- Plays the page turn: the sound, and the pages fading in.
function W:TurnPage()
  local f = self.frame
  if not f or not f:IsShown() then return end
  ns.Sound("page")
  if ns.Settings:Get("reduce") then return end
  for _, ag in pairs(f.turn or {}) do ag:Stop(); ag:Play() end
end

-- A question in the book with two buttons (for example before disbanding).
function W:BuildConfirm(area)
  local c = CreateFrame("Frame", nil, area)
  c:SetAllPoints()
  c:SetFrameLevel(area:GetFrameLevel() + W.LAYER.overlay)
  c:EnableMouse(true)
  local dim = c:CreateTexture(nil, "BACKGROUND")
  dim:SetAllPoints(); dim:SetColorTexture(0, 0, 0, 0.45)
  local box = UI.Card(c, "gold")
  box.bgRole = "page1"
  box:Paint()
  UI.DialogFrame(box)
  box:SetSize(400, 150)
  box:SetPoint("CENTER")
  c.box = box
  c.text = UI.WrapText(box, 15, "ink", 360, "book")
  c.text:SetJustifyH("CENTER")
  c.text:SetPoint("TOP", 0, -26)
  c.ok = UI.TextButton(box, "", function() c:Hide(); if c.onOk then c.onOk() end end, "danger")
  c.ok:SetPoint("BOTTOMRIGHT", -20, 18)
  c.cancel = UI.TextButton(box, L.CANCEL, function() c:Hide() end, "plain")
  c.cancel:SetPoint("RIGHT", c.ok, "LEFT", -8, 0)
  c:Hide()
  self.confirm = c
end

-- Every emblem in a grid; the banner colour behind each. onPick(key) when one is clicked.
-- Built the first time it is opened (never during combat).
function W:PickEmblem(color, current, onPick)
  if not self.frame or ns.Combat:InCombat() then return end
  local p = self.emblemPicker
  if not p then
    p = CreateFrame("Frame", nil, self.frame.area)
    p:SetAllPoints()
    p:SetFrameLevel(self.frame.area:GetFrameLevel() + W.LAYER.overlay)
    p:EnableMouse(true)
    local dim = p:CreateTexture(nil, "BACKGROUND")
    dim:SetAllPoints(); dim:SetColorTexture(0, 0, 0, 0.45)
    local box = UI.Card(p, "gold")
    box.bgRole = "page1"
    box:Paint()
    UI.DialogFrame(box)
    box:SetSize(560, 470)
    box:SetPoint("CENTER")
    local title = UI.Text(box, 17, "ink", "title")
    title:SetPoint("TOPLEFT", 16, -14)
    title:SetText(L.CHOOSE_EMBLEM)
    local close = UI.TextButton(box, L.CLOSE, function() p:Hide() end, "plain")
    close:SetPoint("TOPRIGHT", -12, -10)
    p.scroll = UI.EmblemGrid(box, 526, function(n) p:Hide(); if p.onPick then p.onPick(n) end end)
    p.scroll:SetPoint("TOPLEFT", 16, -44); p.scroll:SetPoint("BOTTOMRIGHT", -18, 14)
    p.cells = p.scroll.cells
    -- Sized to its emblems (it was 470 high around two short rows; seen in the tour), at most 470.
    box:SetHeight(math.min(470, p.scroll.height + 44 + 14 + 12))
    self.emblemPicker = p
  end
  p.scroll:Refresh(color, current)
  p.onPick = onPick
  p:Show()
end

-- An overlay in the book: dimmed background and a card. Returns the overlay (with .box). Built once per key.
function W:Overlay(key, width, height)
  self.overlays = self.overlays or {}
  local o = self.overlays[key]
  if o then return o end
  o = CreateFrame("Frame", nil, self.frame.area)
  o:SetAllPoints()
  o:SetFrameLevel(self.frame.area:GetFrameLevel() + W.LAYER.overlay)
  o:EnableMouse(true)
  local dim = o:CreateTexture(nil, "BACKGROUND")
  dim:SetAllPoints(); dim:SetColorTexture(0, 0, 0, 0.45)
  o.box = UI.Card(o, "gold")
  o.box.bgRole = "page1"
  o.box:Paint()
  UI.DialogFrame(o.box)
  o.box:SetSize(width, height)
  o.box:SetPoint("CENTER")
  o.title = UI.Text(o.box, 17, "ink", "title")
  o.title:SetPoint("TOPLEFT", 16, -14)
  o.close = UI.TextButton(o.box, L.CLOSE, function() o:Hide() end, "plain")
  o.close:SetPoint("TOPRIGHT", -12, -10)
  o:Hide()
  self.overlays[key] = o
  return o
end

-- A list to choose from: items = { { text, sub, highlight } }; onPick(i) with the item's number.
function W:PickFromList(title, items, onPick)
  if not self.frame or ns.Combat:InCombat() then return end
  local o = self:Overlay("list", 460, 470)
  if not o.scroll then
    o.scroll = UI.Scroll(o.box)
    o.scroll:SetPoint("TOPLEFT", 16, -46); o.scroll:SetPoint("BOTTOMRIGHT", -18, 14)
    o.rows = UI.Pool(function()
      local r = CreateFrame("Button", nil, o.scroll.child)
      r:SetSize(418, 24)
      r.text = UI.Text(r, 13, "ink")
      r.text:SetPoint("LEFT", 6, 0)
      r.sub = UI.Text(r, 12, "ink2", "body", "RIGHT")
      r.sub:SetPoint("RIGHT", -6, 0)
      r.mark = UI.Check(r, 14)
      r.mark:SetPoint("RIGHT", r.sub, "LEFT", -6, 0)
      local hl = r:CreateTexture(nil, "HIGHLIGHT")
      hl:SetAllPoints(); hl:SetColorTexture(1, 0.9, 0.6, 0.2)
      r:SetScript("OnClick", function() o:Hide(); if o.onPick then o.onPick(r.i) end end)
      return r
    end)
  end
  o.title:SetText(title)
  o.onPick = onPick
  local stack = UI.Stack(o.scroll.child)
  local shown = 0
  for i, item in ipairs(items) do
    local r = o.rows:Get(i)
    if not r then break end
    shown = i
    r.i = i
    r.text:SetText(item.text)
    r.sub:SetText(item.sub or "")
    r.mark:SetShown(item.highlight == true)
    stack:Place(r, 24, 0)
  end
  o.rows:HideFrom(shown + 1)
  o.scroll:SetContentHeight(stack.y)
  -- As tall as the list needs, up to the book's height (one dungeon showed in a box for twenty).
  o.box:SetHeight(math.min(470, 46 + stack.y + 30))
  o:Show()
end

-- A list to tick several things in: items = { { text, on } }; onDone(ons) with on/off per item number when Done
-- is clicked.
function W:PickMany(title, items, onDone)
  if not self.frame or ns.Combat:InCombat() then return end
  local o = self:Overlay("many", 460, 470)
  if not o.scroll then
    o.scroll = UI.Scroll(o.box)
    o.scroll:SetPoint("TOPLEFT", 16, -46); o.scroll:SetPoint("BOTTOMRIGHT", -18, 52)
    o.rows = UI.Pool(function()
      local r = CreateFrame("Button", nil, o.scroll.child)
      r:SetSize(418, 24)
      r.box = r:CreateTexture(nil, "ARTWORK")
      r.box:SetSize(20, 20); r.box:SetPoint("LEFT", 2, 0)
      r.box:SetTexture("Interface\\Buttons\\UI-CheckBox-Up")
      r.mark = UI.Check(r, 20)
      r.mark:SetPoint("LEFT", 2, 0)
      r.text = UI.Text(r, 13, "ink")
      r.text:SetPoint("LEFT", 28, 0)
      local hl = r:CreateTexture(nil, "HIGHLIGHT")
      hl:SetAllPoints(); hl:SetColorTexture(1, 0.9, 0.6, 0.2)
      r:SetScript("OnClick", function() o.ons[r.i] = not o.ons[r.i]; r.mark:SetShown(o.ons[r.i]) end)
      return r
    end)
    o.done = UI.TextButton(o.box, L.TOAST_DONE, function() o:Hide(); if o.onDone then o.onDone(o.ons) end end, "primary")
    o.done:SetPoint("BOTTOMRIGHT", -16, 14)
  end
  o.title:SetText(title)
  o.onDone = onDone
  o.ons = {}
  local stack = UI.Stack(o.scroll.child)
  local shown = 0
  for i, item in ipairs(items) do
    local r = o.rows:Get(i)
    if not r then break end
    shown = i
    r.i = i
    o.ons[i] = item.on == true
    r.text:SetText(item.text)
    r.mark:SetShown(o.ons[i])
    stack:Place(r, 24, 0)
  end
  o.rows:HideFrom(shown + 1)
  o.scroll:SetContentHeight(stack.y)
  o.box:SetHeight(math.min(470, 46 + stack.y + 30 + 52))
  o:Show()
  return o
end

-- A text box to copy from or paste into. text = what to show (selected for copying); onOk(text) when okLabel
-- is clicked (nil: only Close). Returns the overlay (its .hint can show a problem).
function W:TextDialog(title, hint, text, okLabel, onOk)
  if not self.frame or ns.Combat:InCombat() then return end
  local o = self:Overlay("text", 520, 300)
  if not o.edit then
    o.hint = UI.WrapText(o.box, 12, "ink2", 488)
    o.hint:SetPoint("TOPLEFT", 16, -44)
    local holder = UI.Card(o.box)
    holder:SetPoint("TOPLEFT", 16, -82); holder:SetPoint("BOTTOMRIGHT", -16, 52)
    o.scroll = CreateFrame("ScrollFrame", nil, holder)
    o.scroll:SetPoint("TOPLEFT", 8, -8); o.scroll:SetPoint("BOTTOMRIGHT", -8, 8)
    o.edit = CreateFrame("EditBox", nil, o.scroll)
    o.edit:SetMultiLine(true)
    o.edit:SetAutoFocus(false)
    o.edit:SetFont(Theme.FONT_BODY, 12, "")
    o.edit:SetWidth(460)
    Theme:TextColor(o.edit, "ink")
    o.edit:SetScript("OnEscapePressed", function() o:Hide() end)
    o.scroll:SetScrollChild(o.edit)
    o.ok = UI.TextButton(o.box, "", function() if o.onOk then o.onOk(o.edit:GetText() or "") end end, "primary")
    o.ok:SetPoint("BOTTOMRIGHT", -16, 14)
  end
  o.title:SetText(title)
  o.hint:SetText(hint)
  o.hint:SetTextColor(Theme:RGBA("ink2"))
  o.edit:SetText(text or "")
  o.onOk = onOk
  o.ok:SetShown(onOk ~= nil)
  if okLabel then o.ok:SetLabel(okLabel) end
  o:Show()
  o.edit:SetFocus()
  if text and text ~= "" then o.edit:HighlightText() end
  return o
end

-- The DungeonJournal addon's chat command (/dj), when it is installed: its function in SlashCmdList, or nil.
function W:JournalCommand() return ns.SlashCommand("/dj", "/dungeonjournal") end

-- Dungeon Journal: a shortcut to the DungeonJournal addon (loot, quests and where to find them), with the dungeon's
-- name; without the addon, a toast says where to get it. Returns true when it opened.
function W:DungeonJournal(key)
  local d = ns.Dungeon(key)
  if not d then return false end
  local open = self:JournalCommand()
  if not open then
    ns:Toast(nil, L.DUNGEON_JOURNAL, L.DJ_MISSING)
    return false
  end
  open(d[2])
  return true
end

function W:Confirm(text, okLabel, onOk)
  local c = self.confirm
  if not c then return end
  c.text:SetText(text)
  c.ok:SetLabel(okLabel)
  c.onOk = onOk
  -- As tall as the question needs (it was a fixed box with empty space; seen in the UI tour).
  c.box:SetHeight(26 + c.text:GetStringHeight() + 24 + 24 + 18)
  c:Show()
end

-- Build when allowed: right away, or after combat. then() runs once it is built.
function W:WhenBuilt(andThen)
  if self.frame then return andThen() end
  self.afterBuild = andThen
  if self.buildQueued then return end
  self.buildQueued = true
  Combat:AfterCombat(function()
    W.buildQueued = false
    W:Build()
    local fn = W.afterBuild
    W.afterBuild = nil
    if fn then fn() end
  end)
end

function W:IsOpen() return self.frame ~= nil and self.frame:IsShown() end

function W:Open(page)
  self:WhenBuilt(function()
    W.openedThisSession = true
    -- The first time the book opens in a session: what changed since you were last here (if anything did).
    -- Before that, once per character: the setup guide (UI/Pages/Setup.lua).
    if not page and ns.SetupGuide and ns.SetupGuide:Pending() then page = "setup"; ns.SetupGuide.step = 1 end
    if not page and ns.Since and ns.Fellowship:Current() and ns.Since:Pending() then page = "since" end
    if page then
      -- "chronicle#session": a page and the tab it opens at (the session recap's toast); the page takes W.tab when
      -- it refreshes.
      local tab
      page, tab = page:match("^([^#]+)#?(.*)$")
      W.tab = tab ~= "" and tab or nil
      -- Opened to a page (a toast, a big moment, the minimap): from its top, also when it was the page already
      -- open (the Overview stayed half-scrolled after a chapter unlocked; seen in the tour).
      W.page = page
      local pf = W.pageFrames[page]
      if pf then pf.sel = nil end
      if pf then UI.ScrollsToTop(pf) end
    end
    if W.frame:IsShown() then W:Refresh() else W.frame:Show() end
    -- A fellowship found again after lost saved data (Fellowship/Sync.lua): ask now.
    if ns.Sync and ns.Sync.restore then ns.Sync:OfferRestore() end
  end)
end

function W:Close() if self.frame then self.frame:Hide() end end

function W:Toggle()
  if self:IsOpen() then self:Close() else self:Open() end
end

-- Opening a page from the sidebar starts it fresh (for example the Hero list, not the last inspected Hero).
function W:ShowPage(id)
  local turned = id ~= self.current
  self.page = id
  local pf = self.pageFrames[id]
  if pf then pf.sel = nil end
  if pf and turned then UI.ScrollsToTop(pf) end
  self:Refresh()
  if turned then self:TurnPage() end
end

-- A page that keeps something going while it shows (Settings: moving the toast) ends it when another page opens or
-- the book closes.
function W:LeavePage(id)
  local def = id and Pages:Get(id)
  if def and def.leave and self.pageFrames[id] then def.leave(self.pageFrames[id]) end
end

-- Settings is a page (29 Oct 2026; it was a side panel): the gear opens it and, pressed again, goes back to the page
-- you came from, as the page's Back does.
function W:OpenSettings()
  self:HidePanels()
  if self.current ~= "settings" then self.beforeSettings = self.page end
  if self:IsOpen() then self:ShowPage("settings") else self:Open("settings") end
end

function W:CloseSettings()
  local back = self.beforeSettings
  self.beforeSettings = nil
  self:ShowPage(back ~= "settings" and back or "overview")
end

function W:ToggleSettings()
  if self:IsOpen() and self.current == "settings" then self:CloseSettings() else self:OpenSettings() end
end

function W:HidePanels()
  for key, p in pairs(self.panels) do
    if p:IsShown() then
      p:Hide()
      local def = self.panelDefs[key]
      if def.hide then def.hide(p) end
    end
  end
  self.openPanel = nil
end

-- Opens a side panel (only one at a time); the same button closes it again.
function W:TogglePanel(key, forceOpen)
  local open = self.openPanel == key and not forceOpen
  self:HidePanels()
  if open then return end
  local p = self.panels[key]
  if not p then return end
  self.openPanel = key
  p:Show()
  if not ns.Settings:Get("reduce") then p.slideIn:Stop(); p.slideIn:Play() end
  local def = self.panelDefs[key]
  if def.refresh then def.refresh(p) end
end

function W:OpenPanel(key)
  self:Open()
  self:WhenBuilt(function() W:TogglePanel(key, true) end)
end

---------------------------------------------------------------------------
-- Refresh: puts the current state into the window
---------------------------------------------------------------------------
function W:RefreshHeader(ctx)
  local h = self.frame.header
  local name, chip = Pages:Header(ctx)
  local dx = self:HeaderShift()
  h.crest:ClearAllPoints()
  h.crest:SetPoint("TOPLEFT", h, "TOPLEFT", 96 + dx, -17)
  h.crest:SetShown(ctx.inFellow)
  if ctx.inFellow then h.crest:Set(ctx.color, ctx.emblem) end
  h.name:ClearAllPoints()
  -- A picture crest is wider than the shield: the name keeps clear of it.
  local pic = ctx.inFellow and ns.Emblems:Picture(ctx.emblem) ~= nil and ns.Emblems:Has(ctx.emblem)
  if ctx.inFellow then h.name:SetPoint("LEFT", h.crest, "RIGHT", pic and 24 or 10, 0) else h.name:SetPoint("TOPLEFT", h, "TOPLEFT", 98 + dx, -20) end
  h.name:SetWidth(520)
  h.name:SetText(name)
  h.chip.text:SetText(chip)
  h.chip:SetWidth(h.chip.text:GetStringWidth() + 20)
  h.chip:ClearAllPoints()
  h.chip:SetPoint("TOPLEFT", h, "TOPLEFT", (ctx.inFellow and 96 or 98) + dx, ctx.inFellow and -58 or -54)
  local n = ns.Inbox and ns.Inbox:Count() or 0
  h.inbox.badge:SetCount(n)
end

function W:RefreshNav(ctx, page)
  local f = self.frame
  local nav = Pages:Nav(ctx)
  f.nav:SetShown(#nav > 0)
  f.area:ClearAllPoints()
  f.area:SetPoint("TOPRIGHT"); f.area:SetPoint("BOTTOMRIGHT")
  f.area:SetPoint("LEFT", f.body, "LEFT", #nav > 0 and (178 + 4) or 16, 0)
  for _, b in pairs(self.navItems) do b:Hide() end
  for _, g in ipairs(self.navGroups) do g:Hide() end
  local y, count = 0, 0
  for _, group in ipairs(nav) do count = count + #group.items end
  -- (A taller book in full screen has a taller sidebar.)
  local space = NAV_SPACE + math.max(0, f:GetHeight() - HEIGHT)
  local rowH = math.min(NAV_ROW, math.floor((space - #nav * GROUP_H + 9) / math.max(1, count)) - 2)
  for gi, group in ipairs(nav) do
    local g = self.navGroups[gi]
    g:ClearAllPoints(); g:SetPoint("TOPLEFT", f.nav, "TOPLEFT", 0, y); g:Show()
    g.text:SetText(group.label)
    y = y - 17
    for _, id in ipairs(group.items) do
      local b = self.navItems[id]
      local def = Pages:Get(id)
      b.label:SetText(def and def.label or id)
      b.badge:SetCount(def and def.badge and def.badge(ctx) or 0)
      b:SetHeight(rowH)
      b:ClearAllPoints(); b:SetPoint("TOPLEFT", f.nav, "TOPLEFT", 0, y); b:Show()
      -- A tab of a page (Manage's) marks the page's entry.
      local active = id == Pages:NavItem(page)
      b.ribbon:SetShown(active); b.edge:SetShown(active); b.redEdge:SetShown(active)
      b.label:SetTextColor(Theme:RGBA(active and "goldText" or "sideInk"))
      y = y - (rowH + 2)
    end
    y = y - 9
  end
end

function W:RefreshArt(page)
  local f = self.frame
  local head, bg = Pages:Art(page, Theme:Horde())
  local h = f.header
  local w = f:GetWidth() - 4
  h.art:SetShown(head ~= nil)
  if head == Pages.ART.land then
    -- The journey pages show the current chapter's own picture.
    local fs = ns.Fellowship:Current()
    Pages:SetChapterArt(h.art, fs and Pages:ArtOf(fs, ns.Journey:CurrentIndex(fs)), w, HEADER - 2, 0.4)
  elseif head then
    h.art:SetTexture(ns.MEDIA .. head[1])
    UI.Cover(h.art, head[2], w, HEADER - 2, 0.4)
  end
  f.bgArt:SetShown(bg ~= nil)
  if bg then
    f.bgArt:SetTexture(ns.MEDIA .. bg[1])
    UI.Cover(f.bgArt, bg[2], w, f:GetHeight() - 4, 0.5)
  end
end

-- The shared page title sits on the left page ("left"), the right page ("right"), across the whole sheet ("both",
-- for the flat tool pages) or is hidden ("none") when the page draws its own headings (as Welcome, Create, Join and
-- Manage do in the mockup).
-- A book wider than drawn (full screen) keeps each page at the width it was laid out for: the extra width is margin,
-- on both sides of each page of the open book; on the flat sheet the two halves stay together in its middle (Journey
-- Admin's chapter plate runs across both).
function W:PlaceTitle(page, mode, ctx)
  local book, pf = self.frame.book, self.pageFrames[page]
  local side = mode == "right" and book.right or book.left
  local title, sub = Pages:Titles(page, ctx)
  book.title:SetText(title)
  book.sub:SetText(sub or "")
  for _, t in ipairs({ book.title, book.sub, book.divider }) do t:SetShown(mode ~= "none") end
  -- The insets of the left page (outer, at the spine) and of the right page (at the spine, outer).
  local lo, li, ri, ro = self:PageInsets()
  book.title:ClearAllPoints()
  book.divider:ClearAllPoints()
  if mode == "both" then
    book.title:SetPoint("TOP", book, "TOP", 0, -25)
    book.divider:SetPoint("TOPLEFT", book.left, "TOPLEFT", lo, -66); book.divider:SetPoint("TOPRIGHT", book.right, "TOPRIGHT", -ro, -66)
  else
    local right = mode == "right"
    book.title:SetPoint("TOP", side, "TOP", 0, -22)
    book.divider:SetPoint("TOPLEFT", side, "TOPLEFT", right and ri or lo, -66)
    book.divider:SetPoint("TOPRIGHT", side, "TOPRIGHT", -(right and ro or li), -66)
  end
  if pf then
    pf.left:ClearAllPoints()
    pf.left:SetPoint("TOPLEFT", book.left, "TOPLEFT", lo, (mode == "left" or mode == "both") and -78 or -22)
    pf.left:SetPoint("BOTTOMRIGHT", book.left, "BOTTOMRIGHT", -li, 22)
    pf.right:ClearAllPoints()
    pf.right:SetPoint("TOPLEFT", book.right, "TOPLEFT", ri, (mode == "right" or mode == "both") and -78 or -22)
    pf.right:SetPoint("BOTTOMRIGHT", book.right, "BOTTOMRIGHT", -ro, 22)
  end
end

-- The pages' insets in the book: left page outer and at the spine, right page at the spine and outer. 26 as drawn;
-- a wider book (full screen) adds its extra width.
function W:PageInsets()
  local e = math.max(0, math.floor((self.frame:GetWidth() - WIDTH) / 2))
  if self.frame.book.flat then return 26 + e, 26, 26, 26 + e end
  local a, b = math.floor(e / 2), math.ceil(e / 2)
  return 26 + a, 26 + b, 26 + b, 26 + a
end

-- The current page lies on the flat sheet (a tool page: Journey Admin, Settings).
function W:IsFlat() return self.frame ~= nil and self.frame.book.flat == true end

function W:Refresh()
  if not self:IsOpen() then return end
  -- Watching another character's fellowship: the pages draw as that character (Fellowship/Watch.lua). The side
  -- panels (settings, inbox, characters) stay yours.
  local WT = ns.Watch
  if WT and WT.active and WT:Fellowship() then
    WT.rendering = true
    local ok, err = pcall(self.Draw, self)
    WT.rendering = false
    if not ok then error(err, 0) end
  else
    if WT and WT.active then WT.active, WT.fid, WT.as, WT.demo = false, nil, nil, nil end
    self:Draw()
  end
  self:RefreshWatchBar()
  self:RefreshTrialBar()
  if self.openPanel then
    local pdef = self.panelDefs[self.openPanel]
    if pdef.refresh then pdef.refresh(self.panels[self.openPanel]) end
  end
end

-- The bar across the header while watching: whose fellowship, how fresh, and the way back.
function W:RefreshWatchBar()
  local WT, h = ns.Watch, self.frame and self.frame.header
  -- (Not for the walkthrough's sample fellowship: the guide card says what it is.)
  local on = WT and WT.active and not WT.demo and WT:Fellowship() ~= nil
  local bar = self.watchBar
  if not bar then
    if not on or Combat:InCombat() then return end
    bar = UI.Box(h, 1, "dark", 0.82, "gold", 0.9)
    bar:SetSize(470, 46)
    bar:SetPoint("TOP", h, "TOP", 60, -12)
    bar:SetFrameLevel(h:GetFrameLevel() + 20)
    bar.title = UI.Text(bar, 11, "gold", "body")
    bar.title:SetPoint("TOPLEFT", 12, -8)
    bar.line = UI.Text(bar, 12, "chipText", "body")
    bar.line:SetPoint("TOPLEFT", bar.title, "BOTTOMLEFT", 0, -3)
    bar.back = UI.TextButton(bar, L.WATCH_BACK, function() ns.Watch:Close() end, "plain", 12)
    bar.back:SetPoint("RIGHT", -8, 0)
    -- The line stops before the button (it ran under it; seen in the tour).
    bar.line:SetPoint("RIGHT", bar.back, "LEFT", -8, 0)
    bar.line:SetJustifyH("LEFT")
    self.watchBar = bar
  end
  bar:SetShown(on)
  if on then
    local f = WT:Fellowship()
    bar.title:SetText(L.WATCH_TITLE:format(ns.Short(WT.as)):upper())
    bar.line:SetText(WT:Freshness(f))
  end
end

-- The warning across the header on a trial account in a fellowship (ns.Trial): the others will not hear this one.
function W:RefreshTrialBar()
  local h = self.frame and self.frame.header
  local on = ns.Trial() and ns.Fellowship:Current() ~= nil and not (self.watchBar and self.watchBar:IsShown())
  local bar = self.trialBar
  if not bar then
    if not on or Combat:InCombat() then return end
    bar = UI.Box(h, 1, "dark", 0.82, "B0321E", 0.9)
    bar:SetSize(470, 58)
    bar:SetPoint("TOP", h, "TOP", 60, -8)
    bar:SetFrameLevel(h:GetFrameLevel() + 20)
    bar.title = UI.Text(bar, 11, "gold", "body")
    bar.title:SetPoint("TOPLEFT", 12, -8)
    bar.title:SetText(L.TRIAL_T:upper())
    bar.line = UI.WrapText(bar, 12, "chipText", 446, "body")
    bar.line:SetPoint("TOPLEFT", bar.title, "BOTTOMLEFT", 0, -3)
    bar.line:SetText(L.TRIAL_BAR)
    self.trialBar = bar
  end
  bar:SetShown(on)
end

function W:Draw()
  local ctx = Pages:Context()
  local page = Pages:Resolve(self.page, self.startView, ctx)
  if self.current and self.current ~= page then self:LeavePage(self.current) end
  self.current = page
  if ns.Together then ns.Together:Visited(page) end
  Theme:SetAccent(Pages:Accent(page, ctx))
  self:RefreshHeader(ctx)
  self:RefreshNav(ctx, page)
  self:RefreshArt(page)
  local def = Pages:Get(page)
  local header = def and def.header or "left"
  if type(header) == "function" then header = header(self.pageFrames[page]) end
  self.frame.book:SetFlat(def and def.flat)
  self:PlaceTitle(page, header, ctx)
  for id, pf in pairs(self.pageFrames) do
    local show = id == page
    pf:SetShown(show); pf.left:SetShown(show); pf.right:SetShown(show)
  end
  if self.confirm and self.confirm.page ~= page then
    self.confirm:Hide()
    if self.emblemPicker then self.emblemPicker:Hide() end
    for _, o in pairs(self.overlays or {}) do o:Hide() end
  end
  if self.confirm then self.confirm.page = page end
  if def and def.refresh then def.refresh(self.pageFrames[page], ctx) end
end

-- Other Heroes' news arrives in bursts (a login, a heartbeat round, a quest log): one redraw for the whole burst.
-- HEROES fired with `now` (the player clicked something) redraws at once.
W.SOON = 0.25
function W:RefreshSoon()
  if self.soon or not self:IsOpen() then return end
  self.soon = true
  C_Timer.After(self.SOON, function() self.soon = nil; self:Refresh() end)
end

---------------------------------------------------------------------------
ns:On("LOGIN", function() W:WhenBuilt(function() end) end)
ns:On("SETTING", function(key)
  if key == "size" or key == "fullscreen" then W:ApplyScale()
  elseif key == "theme" then W:Refresh() end
end)
-- Joining, leaving, being removed or a disband: outside a fellowship the book always opens on Welcome.
-- Levels decide the current chapter, standings and the header chip: every page can change.
ns:On("HEROES", function(now) if now then W:Refresh() else W:RefreshSoon() end end)
ns:On("LOGIN", function() W.wasInFellow = ns.Fellowship:Current() ~= nil end)
ns:On("FELLOWSHIP", function()
  local inFellow = ns.Fellowship:Current() ~= nil
  -- Only a real change (an invitation arriving is a FELLOWSHIP event too, and it sent the Join page back to
  -- Welcome while wasInFellow was still unknown; seen in the tour).
  if W.wasInFellow ~= nil and inFellow ~= W.wasInFellow then W.startView = "welcome" end
  -- Just founded or joined: the setup guide first, then the page the book was going to.
  local G = ns.SetupGuide
  if W.wasInFellow == false and inFellow and G and G:Pending() then
    G.step, G.after = 1, W.page ~= "setup" and W.page or nil
    W.page = "setup"
  end
  W.wasInFellow = inFellow
  W:Refresh()
end)
ns:RegisterEvent("UI_SCALE_CHANGED", function() W:ApplyScale() end)
ns:RegisterEvent("DISPLAY_SIZE_CHANGED", function() W:ApplyScale() end)
