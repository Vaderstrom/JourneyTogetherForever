-- Building blocks for the book. Sizes are in mockup pixels (the window is scaled as a whole).
-- Buttons, input boxes and frames use the game's own templates and textures, so the book looks finished and
-- like the rest of WoW. Adapted from reference/old-addons/GuildHall_Core/UI/Widgets.lua and Flyout.lua.
local _, ns = ...
local UI = {}
ns.UI = UI
local Theme = ns.Theme

local FONT = { title = "FONT_TITLE", book = "FONT_BOOK", body = "FONT_BODY", fancy = "FONT_FANCY" }

-- Text. font: "title" (headings), "book" (prose on the pages), "fancy" (gold titles on pictures, like the Adventure
-- Guide's) or "body" (everything else). role: a colour role.
-- The type scale (M20): title 20, heading 15–17, body 13, hint 12. Secondary text (ink2, muted) is never smaller
-- than 12: 11 px grey on parchment was hard to read (seen in the tour). Size 10 stays for the tiniest labels.
UI.HINT_MIN = 12
function UI.Text(parent, size, role, font, justify, layer)
  local fs = parent:CreateFontString(nil, layer or "OVERLAY")
  size = size or 13
  if size == 11 and (role == "ink2" or role == "muted") then size = UI.HINT_MIN end
  fs:SetFont(Theme[FONT[font] or "FONT_BODY"], size, "")
  if not fs:GetFont() then fs:SetFont(Theme.FONT_TITLE, size, "") end -- a font file this client does not have
  fs:SetJustifyH(justify or "LEFT")
  fs:SetWordWrap(false)
  if role then Theme:TextColor(fs, role) end
  return fs
end

-- Text that wraps within width.
function UI.WrapText(parent, size, role, width, font)
  local fs = UI.Text(parent, size, role, font)
  fs:SetWordWrap(true)
  fs:SetJustifyV("TOP")
  fs:SetSpacing(2) -- lines no longer touch (seen in the UI tour)
  fs:SetWidth(width)
  return fs
end

-- A texture in one colour role.
function UI.Solid(parent, layer, role, alpha, sublevel)
  local t = parent:CreateTexture(nil, layer or "ARTWORK", nil, sublevel)
  Theme:Fill(t, role, alpha)
  return t
end

-- Colour fade. Supports the current and the older API.
function UI.SetGradient(tex, orientation, c1, c2)
  tex:SetTexture(ns.WHITE)
  tex:SetVertexColor(1, 1, 1, 1)
  if CreateColor and pcall(tex.SetGradient, tex, orientation, CreateColor(c1[1], c1[2], c1[3], c1[4]), CreateColor(c2[1], c2[2], c2[3], c2[4])) then return end
  if tex.SetGradientAlpha then tex:SetGradientAlpha(orientation, c1[1], c1[2], c1[3], c1[4], c2[1], c2[2], c2[3], c2[4]) end
end

function UI.GradientTex(parent, layer, orientation, c1, c2, sublevel)
  local t = parent:CreateTexture(nil, layer or "ARTWORK", nil, sublevel)
  Theme:Gradient(t, orientation, c1, c2)
  return t
end

-- A frame with a plain background and a sharp border (the window's gold trim, badges).
function UI.Box(parent, edge, bgRole, bgAlpha, borderRole, borderAlpha)
  local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  f:SetBackdrop({ bgFile = ns.WHITE, edgeFile = ns.WHITE, edgeSize = edge or 1 })
  Theme:Register(function()
    if bgRole then f:SetBackdropColor(Theme:RGBA(bgRole, bgAlpha)) else f:SetBackdropColor(0, 0, 0, 0) end
    if borderRole then f:SetBackdropBorderColor(Theme:RGBA(borderRole, borderAlpha)) else f:SetBackdropBorderColor(0, 0, 0, 0) end
  end)
  return f
end

-- A card: soft background with the game's rounded tooltip border. :SetSelected(on) marks it chosen: lighter than
-- the others with a warm glow from the top, a gold border and a gold rim round it. (It was a gold wash, darker than
-- the other cards: on the paper it read as faded into the page, 29 Oct 2026.) A card with .strong set before it is
-- first chosen glows over its whole height: a bar that says something waits (Journey Admin's Publish bar was too pale
-- to notice; check of 30 Oct 2026).
local CARD = { bgFile = ns.WHITE, edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12,
  insets = { left = 3, right = 3, top = 3, bottom = 3 } }
local function chosenMarks(f)
  local m = {}
  for i, side in ipairs({ { "TOPLEFT", "TOPRIGHT", -1, 1, 1, 1 }, { "BOTTOMLEFT", "BOTTOMRIGHT", -1, -1, 1, -1 },
    { "TOPLEFT", "BOTTOMLEFT", -1, 1, -1, -1 }, { "TOPRIGHT", "BOTTOMRIGHT", 1, 1, 1, -1 } }) do
    local t = f:CreateTexture(nil, "OVERLAY", nil, 6)
    t:SetPoint(side[1], side[3], side[4]); t:SetPoint(side[2], side[5], side[6])
    if i <= 2 then t:SetHeight(2) else t:SetWidth(2) end
    m[i] = t
  end
  m.glow = f:CreateTexture(nil, "BORDER", nil, -1)
  m.glow:SetPoint("TOPLEFT", 3, -3); m.glow:SetPoint("TOPRIGHT", -3, -3)
  if f.strong then m.glow:SetPoint("BOTTOM", 0, 3) else m.glow:SetHeight(26) end
  return m
end
function UI.Card(parent, borderRole, frameType)
  local f = CreateFrame(frameType or "Frame", nil, parent, "BackdropTemplate")
  f:SetBackdrop(CARD)
  f.borderRole = borderRole or "line"
  f.surface = true -- a scroll in it fades into its plain colour (UI.Scroll)
  function f:Paint()
    if self.selected then
      if Theme:Current().light then self:SetBackdropColor(1, 0.97, 0.86, 0.97) else self:SetBackdropColor(Theme:RGBA("gold", 0.24)) end
      self:SetBackdropBorderColor(Theme:RGBA("gold"))
      self.marks = self.marks or chosenMarks(self)
      for i = 1, 4 do self.marks[i]:SetColorTexture(Theme:RGBA("gold")) end
      UI.SetGradient(self.marks.glow, "VERTICAL", { 0.85, 0.69, 0.38, self.strong and 0.22 or 0 }, { 0.85, 0.69, 0.38, self.strong and 0.5 or 0.28 })
    else
      self:SetBackdropColor(Theme:RGBA(self.bgRole or "card")); self:SetBackdropBorderColor(Theme:RGBA(self.borderRole))
    end
    if self.marks then
      for i = 1, 4 do self.marks[i]:SetShown(self.selected) end
      self.marks.glow:SetShown(self.selected)
    end
  end
  function f:SetSelected(on) self.selected = on and true or false; self:Paint() end
  Theme:Register(function() f:Paint() end)
  return f
end

-- The gold check mark used for chosen things.
function UI.Check(parent, size)
  local t = parent:CreateTexture(nil, "OVERLAY")
  t:SetSize(size or 16, size or 16)
  t:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
  return t
end

-- Round texture (a circle, cut out with the game's portrait mask).
function UI.Round(parent, layer, size, sublevel)
  local t = parent:CreateTexture(nil, layer or "ARTWORK", nil, sublevel)
  t:SetSize(size, size)
  local mask = parent:CreateMaskTexture()
  mask:SetTexture(ns.CIRCLE_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
  mask:SetAllPoints(t)
  t:AddMaskTexture(mask)
  return t
end

-- A ring of n round dots (U42's medal ring; U98's ready ring), lit from the top clockwise. ring:Set(share, role)
-- lights that share of them in the role's colour and shows them all; ring.dots for callers that hide them.
function UI.DotRing(parent, size, n, dot)
  local ring = CreateFrame("Frame", nil, parent)
  ring:SetSize(size, size)
  ring.dots = {}
  local rad = (size - dot) / 2
  for i = 1, n do
    local d = UI.Round(ring, "OVERLAY", dot)
    local a = math.rad(90 - (i - 1) * 360 / n)
    d:SetPoint("CENTER", ring, "CENTER", rad * math.cos(a), rad * math.sin(a))
    ring.dots[i] = d
  end
  function ring:Set(share, role)
    local lit = math.floor(n * math.max(0, math.min(1, share or 0)) + 0.5)
    for i, d in ipairs(self.dots) do
      d:SetColorTexture(Theme:RGBA(i <= lit and role or "line", i <= lit and 1 or 0.5))
      d:Show()
    end
  end
  return ring
end

-- Icon in a texture: shows the middle of a game icon (without its frame).
-- Every icon of our set is remembered and drawn again when the theme changes (the Horde set is red).
-- Returns false when the game does not have the file (SetTexture says so for game icons).
UI.icons = setmetatable({}, { __mode = "k" })
function UI.SetIcon(tex, path)
  local file, l, r, t, b = ns.IconArt(path)
  local found = tex:SetTexture(file)
  tex:SetTexCoord(l, r, t, b)
  UI.icons[tex] = path
  return found ~= false
end
Theme:Register(function() for tex, path in pairs(UI.icons) do local file, l, r, t, b = ns.IconArt(path); tex:SetTexture(file); tex:SetTexCoord(l, r, t, b) end end)

-- Round header button (40px): gold ring, dark inside, icon in the middle.
-- iconKey "close" draws a ✕ in crossRole instead of an icon.
function UI.RoundButton(parent, size, iconKey, onClick, ringRole, innerRole, crossRole)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(size, size)
  local ring = UI.Round(b, "BACKGROUND", size)
  ring:SetPoint("CENTER")
  Theme:Fill(ring, ringRole or "gold")
  local inner = UI.Round(b, "BORDER", size - 4)
  inner:SetPoint("CENTER")
  Theme:Fill(inner, innerRole or "shade", innerRole and 1 or 0.85)
  if iconKey == "close" then
    b.cross = UI.Cross(b, math.floor(size * 0.42), crossRole or "goldText")
  else
    b.icon = UI.Round(b, "ARTWORK", math.floor(size * 0.5))
    b.icon:SetPoint("CENTER")
    UI.SetIcon(b.icon, ns.ICONS[iconKey])
  end
  local hl = UI.Round(b, "HIGHLIGHT", size - 4)
  hl:SetPoint("CENTER")
  hl:SetColorTexture(1, 1, 1, 0.12)
  b:SetScript("OnClick", onClick)
  return b
end

-- A large picture tile, like the Adventure Guide's dungeon buttons: the picture across the tile, a dark fade at the
-- bottom with a gold title and a line of text, a gold border that glows on hover, and a "chosen" state (thicker gold
-- border and a gold glow) for choices. art(tex, w, h) puts the picture on the texture. :Set(title, text),
-- :SetChosen(on).
-- small: a card of a row of four (Create's challenges): the title smaller and on up to two lines, the text smaller.
function UI.PictureTile(parent, w, h, art, onClick, small)
  local t = CreateFrame("Button", nil, parent)
  t:SetSize(w, h)
  t.bg = t:CreateTexture(nil, "BACKGROUND")
  t.bg:SetAllPoints(); t.bg:SetColorTexture(0.1, 0.07, 0.04, 1)
  t.pic = t:CreateTexture(nil, "ARTWORK")
  t.pic:SetPoint("TOPLEFT", 2, -2); t.pic:SetPoint("BOTTOMRIGHT", -2, 2)
  if art then art(t.pic, w - 4, h - 4) end
  local fade = t:CreateTexture(nil, "ARTWORK", nil, 2)
  fade:SetPoint("BOTTOMLEFT", 2, 2); fade:SetPoint("BOTTOMRIGHT", -2, 2); fade:SetHeight(math.floor(h * 0.7))
  UI.SetGradient(fade, "VERTICAL", { 0.05, 0.03, 0.01, 0.94 }, { 0.05, 0.03, 0.01, 0 })
  t.title = small and UI.WrapText(t, 15, "goldText", w - 20, "fancy") or UI.Text(t, 22, "goldText", "fancy")
  t.title:SetShadowOffset(1, -1); t.title:SetShadowColor(0, 0, 0, 1)
  t.text = UI.WrapText(t, small and 11 or 13, "chipText", w - (small and 20 or 28), "book")
  t.text:SetShadowOffset(1, -1); t.text:SetShadowColor(0, 0, 0, 1)
  t.text:SetPoint("BOTTOMLEFT", small and 10 or 14, small and 9 or 12)
  t.title:SetPoint("BOTTOMLEFT", t.text, "TOPLEFT", 0, small and 3 or 4)
  t.border = UI.Box(t, 2, nil, nil, "gold", 0.85)
  t.border:SetAllPoints()
  t.glow = t:CreateTexture(nil, "OVERLAY")
  t.glow:SetPoint("TOPLEFT", 2, -2); t.glow:SetPoint("BOTTOMRIGHT", -2, 2)
  t.glow:SetColorTexture(1, 0.85, 0.45, 0.12); t.glow:Hide()
  t.chosenEdge = UI.Box(t, 4, nil, nil, "goldText", 1)
  t.chosenEdge:SetAllPoints(); t.chosenEdge:Hide()
  t.check = UI.Check(t, 22)
  t.check:SetPoint("TOPRIGHT", -8, -8); t.check:Hide()
  t:SetScript("OnEnter", function() t.glow:Show() end)
  t:SetScript("OnLeave", function() if not t.chosen then t.glow:Hide() end end)
  if onClick then t:SetScript("OnClick", function() ns.Sound("choose"); onClick() end) end
  function t:Set(title, text) self.title:SetText(title); self.text:SetText(text or "") end
  function t:SetChosen(on)
    self.chosen = on and true or false
    self.chosenEdge:SetShown(self.chosen); self.check:SetShown(self.chosen); self.glow:SetShown(self.chosen)
  end
  return t
end

-- The picture tiles' frame for any picture on a frame: a dark ground, the picture 2 pixels in and a 2-pixel gold
-- edge round it, so no picture lies bare on the page (the Overview's, the Gathering's and the dungeon thumbnails were
-- pasted on without one; check of 30 Oct 2026). The textures given (the picture and its fades) are moved in.
UI.PIC_INSET = 2
function UI.FramePicture(f, ...)
  local bg = f:CreateTexture(nil, "BACKGROUND", nil, -8)
  bg:SetAllPoints(); bg:SetColorTexture(0.1, 0.07, 0.04, 1)
  local p = UI.PIC_INSET
  for i = 1, select("#", ...) do
    local t = select(i, ...)
    t:ClearAllPoints(); t:SetPoint("TOPLEFT", p, -p); t:SetPoint("BOTTOMRIGHT", -p, p)
  end
  f.edge = UI.Box(f, p, nil, nil, "gold", 0.85)
  f.edge:SetAllPoints()
  return f.edge
end

-- A number tile (U6, 31 Oct 2026; SPEC §4), like the game's achievement summary: the number large in the game's
-- gold and the title font, over a small round icon and its label. A dark ground with the picture tiles' gold edge,
-- the same in every theme, so the gold reads on parchment and at night alike. The Adventurers page, Inspect,
-- History and the Chronicle use it. :Set(value): a number or a short word; one too wide is drawn smaller, and only
-- cut when even 12 is too wide. :SetIcon(path): an icon of ns.ICONS; a file the game does not have leaves the label
-- alone, centred. .v is the number, .k the label, .icon the icon.
UI.TILE_GOLD = "FFD100" -- the game's own gold (its normal font colour)
local TILE_PAD, TILE_GAP = 6, 5
function UI.NumberTile(parent, w, h, label, icon)
  local t = CreateFrame("Frame", nil, parent)
  t:SetSize(w, h)
  t.bg = t:CreateTexture(nil, "BACKGROUND")
  t.bg:SetAllPoints(); t.bg:SetColorTexture(0.1, 0.07, 0.04, 1)
  -- A warm light from the top, as on the game's achievement rows.
  t.sheen = t:CreateTexture(nil, "BORDER")
  t.sheen:SetPoint("TOPLEFT", UI.PIC_INSET, -UI.PIC_INSET); t.sheen:SetPoint("BOTTOMRIGHT", -UI.PIC_INSET, UI.PIC_INSET)
  UI.SetGradient(t.sheen, "VERTICAL", { 0.85, 0.69, 0.38, 0 }, { 0.85, 0.69, 0.38, 0.16 })
  t.edge = UI.Box(t, UI.PIC_INSET, nil, nil, "gold", 0.85)
  t.edge:SetAllPoints()
  local big = h >= 58
  t.size = big and 22 or 20
  local ring = big and 22 or 20
  t.v = UI.Text(t, t.size, UI.TILE_GOLD, "title", "CENTER")
  t.v:SetShadowOffset(1, -1); t.v:SetShadowColor(0, 0, 0, 1)
  t.v:SetPoint("TOP", 0, -TILE_PAD)
  t.k = UI.Text(t, 12, "muted", "body", "LEFT")
  t.ring = UI.Round(t, "ARTWORK", ring)
  Theme:Fill(t.ring, "gold", 0.9)
  t.icon = UI.Round(t, "OVERLAY", ring - 4)
  t.icon:SetPoint("CENTER", t.ring)
  -- (From the tile's width as it is now: the rulebook widens an odd last tile to fill its row, U46.)
  local function room() return t:GetWidth() - 2 * TILE_PAD end

  -- The label and its icon side by side in the middle of the bottom row.
  function t:Place()
    local withIcon = self.ring:IsShown()
    local shift = withIcon and (ring + TILE_GAP) or 0
    self.k:SetWidth(0)
    if self.k:GetStringWidth() > room() - shift then self.k:SetWidth(room() - shift) end
    self.k:ClearAllPoints(); self.k:SetPoint("CENTER", self, "BOTTOM", shift / 2, TILE_PAD + ring / 2 - 1)
    self.ring:ClearAllPoints(); self.ring:SetPoint("RIGHT", self.k, "LEFT", -TILE_GAP, 0)
  end
  function t:SetLabel(text) self.k:SetText(text or ""); self:Place() end
  function t:SetIcon(path)
    local found = path ~= nil and UI.SetIcon(self.icon, path)
    self.ring:SetShown(found); self.icon:SetShown(found)
    self:Place()
  end
  function t:Set(value)
    local size = self.size
    self.v:SetWidth(0)
    self.v:SetFont(Theme.FONT_TITLE, size, "")
    self.v:SetText(value ~= nil and tostring(value) or "-")
    while self.v:GetStringWidth() > room() and size > 12 do
      size = size - 1
      self.v:SetFont(Theme.FONT_TITLE, size, "")
    end
    if self.v:GetStringWidth() > room() then self.v:SetWidth(room()) end
  end
  t.k:SetText(label or "")
  t:SetIcon(icon)
  return t
end

-- Shared lives as a row of candles (SPEC §9; the Overview, the rulebook, Create): the lives left lit in the gold ring,
-- the spent ones snuffed (grey and faint). More rows when they do not fit. :Set(total, left) returns the height;
-- :SetTip(title, lines) is what the tooltip says. The candle is the first one the game has (ns.CANDLES). Bigger, with
-- a thinner ring, since the check of 1 Nov 2026, 11:30 (at 22 they read as small white dots).
-- Candles that live (the check of 1 Nov 2026, 11:30): a warm halo round each lit one that flickers softly, and a
-- candle that went out since you last looked goes dark with a curl of smoke (:Snuff). Reduce effects keeps the halo
-- still and the smoke away. The halo is the game's soft glow; without it, a faint disc.
UI.LIFE = 26
local LIFE_GAP = 5
UI.SOFT_GLOW = { "Interface\\GLUES\\Models\\UI_Draenei\\GenericGlow64" }
local function soft(tex)
  for _, path in ipairs(UI.SOFT_GLOW) do if tex:SetTexture(path) ~= false then return true end end
  tex:SetTexture(ns.CIRCLE_MASK)
  return false
end
UI.HALO = 0.45 -- a lit candle's halo, at rest
local function alphaTo(region, from, to, duration, delay)
  local a = region.anim:CreateAnimation("Alpha")
  a:SetFromAlpha(from); a:SetToAlpha(to); a:SetDuration(duration)
  if delay then a:SetStartDelay(delay) end
  if a.SetSmoothing then a:SetSmoothing("IN_OUT") end
  return a
end
local function animated(region, looping)
  region.anim = region:CreateAnimationGroup()
  if looping then region.anim:SetLooping(looping) end
  return region.anim
end
function UI.Lives(parent, width)
  local w = CreateFrame("Frame", nil, parent)
  w:SetSize(width, UI.LIFE)
  w.items = {}
  local function candle(i)
    if w.items[i] then return w.items[i] end
    local c = CreateFrame("Frame", nil, w)
    c:SetSize(UI.LIFE, UI.LIFE)
    c.halo = c:CreateTexture(nil, "BACKGROUND")
    c.halo:SetSize(UI.LIFE + 18, UI.LIFE + 18)
    c.halo:SetPoint("CENTER", 0, 2)
    soft(c.halo)
    c.halo:SetBlendMode("ADD")
    c.halo:SetVertexColor(1, 0.72, 0.32)
    c.halo:SetAlpha(0)
    -- Each candle at its own pace, so the row never pulses as one.
    c.flicker = animated(c.halo, "BOUNCE")
    alphaTo(c.halo, 0.6, 0.25, 1.05 + ((i * 7) % 5) * 0.14)
    c.ring = UI.Round(c, "ARTWORK", UI.LIFE)
    c.ring:SetPoint("CENTER")
    Theme:Register(function() c.ring:SetColorTexture(Theme:RGBA(c.lit == false and "line" or "gold", c.lit == false and 0.5 or 1)) end)
    c.icon = UI.Round(c, "OVERLAY", UI.LIFE - 2)
    c.icon:SetPoint("CENTER")
    for _, path in ipairs(ns.CANDLES) do if UI.SetIcon(c.icon, path) then break end end
    -- Going out: the flame dims and greys, then a wisp of smoke rises from it, grows and fades.
    c.out = animated(c.icon)
    alphaTo(c.icon, 1, 0.35, 0.7)
    c.out:SetScript("OnFinished", function() c.icon:SetDesaturated(true) end)
    c.dim = animated(c.halo)
    alphaTo(c.halo, 0.8, 0, 0.6)
    c.smoke = c:CreateTexture(nil, "OVERLAY", nil, 7)
    c.smoke:SetSize(16, 16)
    c.smoke:SetPoint("BOTTOM", c, "TOP", 0, -12)
    soft(c.smoke)
    c.smoke:SetVertexColor(0.78, 0.76, 0.74)
    c.smoke:SetAlpha(0)
    c.smoking = animated(c.smoke)
    local up = c.smoking:CreateAnimation("Translation")
    up:SetOffset(4, 20); up:SetDuration(1.7); up:SetStartDelay(0.3)
    local grow = c.smoking:CreateAnimation("Scale")
    if grow.SetScaleTo then grow:SetScaleFrom(0.8, 0.8); grow:SetScaleTo(1.9, 2.2) else grow:SetScale(2, 2.4) end
    grow:SetDuration(1.7); grow:SetStartDelay(0.3)
    alphaTo(c.smoke, 0, 0.7, 0.3, 0.3)
    alphaTo(c.smoke, 0.7, 0, 1.4, 0.6)
    w.items[i] = c
    return c
  end
  function w:Set(total, left)
    total, left = total or 0, left or 0
    local per = math.max(1, math.floor((width + LIFE_GAP) / (UI.LIFE + LIFE_GAP)))
    for i = 1, total do
      local c = candle(i)
      c.lit = i <= left
      c:ClearAllPoints()
      c:SetPoint("TOPLEFT", ((i - 1) % per) * (UI.LIFE + LIFE_GAP), -math.floor((i - 1) / per) * (UI.LIFE + LIFE_GAP))
      c.ring:SetColorTexture(Theme:RGBA(c.lit and "gold" or "line", c.lit and 1 or 0.5))
      c.icon:SetDesaturated(not c.lit)
      c.icon:SetAlpha(c.lit and 1 or 0.35)
      -- The halo: still with Reduce effects, else flickering.
      c.halo:SetAlpha(c.lit and UI.HALO or 0)
      c.flickering = c.lit and not ns.Settings:Get("reduce")
      if c.flickering then
        if not c.flicker:IsPlaying() then c.flicker:Play() end
      else c.flicker:Stop() end
      c:Show()
    end
    for i = total + 1, #self.items do self.items[i]:Hide() end
    self.total, self.left = total, math.min(left, total)
    self.used = math.min(total, per) * (UI.LIFE + LIFE_GAP) - LIFE_GAP -- how wide the candles are drawn
    local rows = math.max(1, math.ceil(total / per))
    local h = rows * UI.LIFE + (rows - 1) * LIFE_GAP
    self:SetHeight(h)
    return h
  end
  function w:Lit()
    local n = 0
    for i = 1, self.total or 0 do if self.items[i].lit then n = n + 1 end end
    return n
  end
  -- The candles that went out since this row was last seen (from lit, to lit now): each goes out with a short snuff
  -- and a curl of smoke. Call after :Set. Nothing with Reduce effects. w.snuffed: which ones, for the tests.
  function w:Snuff(from, to)
    self.snuffed = {}
    if ns.Settings:Get("reduce") then return end
    for i = to + 1, math.min(from, self.total or 0) do
      local c = self.items[i]
      self.snuffed[#self.snuffed + 1] = i
      c.icon:SetDesaturated(false)
      c.out:Stop(); c.out:Play()
      c.dim:Stop(); c.dim:Play()
      c.smoking:Stop(); c.smoking:Play()
    end
  end
  function w:SetTip(title, lines) self.tipTitle, self.tipLines = title, lines end
  -- The tooltip needs the mouse; a click goes on to w.onClick (the Overview's row opens the rulebook).
  w:EnableMouse(true)
  w:SetScript("OnMouseUp", function() if w.onClick then w.onClick() end end)
  w:SetScript("OnEnter", function()
    if not w.tipTitle then return end
    GameTooltip:SetOwner(w, "ANCHOR_TOP")
    GameTooltip:SetText(w.tipTitle, 1, 1, 1)
    for _, line in ipairs(w.tipLines or {}) do GameTooltip:AddLine(line, 0.85, 0.8, 0.7, true) end
    GameTooltip:Show()
  end)
  w:SetScript("OnLeave", function() GameTooltip:Hide() end)
  return w
end

-- A one-line tooltip on hover (icon buttons say what they do).
-- A function may return nil: no tooltip then.
function UI.Tooltip(frame, text)
  frame:HookScript("OnEnter", function()
    local t = type(text) == "function" and text() or text
    if not t then return end
    GameTooltip:SetOwner(frame, "ANCHOR_TOP"); GameTooltip:SetText(t, nil, nil, nil, nil, true); GameTooltip:Show()
  end)
  frame:HookScript("OnLeave", function() GameTooltip:Hide() end)
end

-- A dungeon's or raid's picture shown large while the mouse is on its small one (U64), as the Adventure Guide does.
-- keyOf(frame) gives the place's key; nothing shows for one without a picture of its own. One frame for all, made at
-- the first hover out of combat.
UI.PICTIP_W, UI.PICTIP_H = 384, 192
function UI.PictureTip(frame, keyOf)
  frame:HookScript("OnEnter", function()
    local key = keyOf(frame)
    local t = UI.pictureTip
    if not key or (not t and InCombatLockdown()) then return end
    if not t then
      t = CreateFrame("Frame", nil, UIParent)
      t:SetSize(UI.PICTIP_W, UI.PICTIP_H); t:SetFrameStrata("TOOLTIP"); t:SetClampedToScreen(true)
      t.tex = t:CreateTexture(nil, "ARTWORK")
      UI.FramePicture(t, t.tex)
      local fade = t:CreateTexture(nil, "ARTWORK", nil, 2)
      fade:SetPoint("BOTTOMLEFT", UI.PIC_INSET, UI.PIC_INSET); fade:SetPoint("BOTTOMRIGHT", -UI.PIC_INSET, UI.PIC_INSET)
      fade:SetHeight(math.floor(UI.PICTIP_H * 0.4))
      UI.SetGradient(fade, "VERTICAL", { 0.05, 0.03, 0.01, 0.92 }, { 0.05, 0.03, 0.01, 0 })
      t.name = UI.Text(t, 16, "goldText", "fancy")
      t.name:SetPoint("BOTTOMLEFT", 12, 10)
      t.name:SetShadowOffset(1, -1); t.name:SetShadowColor(0, 0, 0, 1)
      UI.pictureTip = t
    end
    local p = UI.PIC_INSET
    local ok, default = ns.SetDungeonArt(t.tex, key, UI.PICTIP_W - 2 * p, UI.PICTIP_H - 2 * p)
    if not ok or default then t:Hide() return end
    local d = ns.Dungeon(key) or ns.Raid(key)
    t.name:SetText(d and d[2] or "")
    t:ClearAllPoints(); t:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 0, 6)
    t.key = key
    t:Show()
  end)
  frame:HookScript("OnLeave", function() if UI.pictureTip then UI.pictureTip:Hide() end end)
end

-- Small badge with a number (inbox count).
function UI.Badge(parent)
  local f = UI.Box(parent, 1, "badge", 1, "goldText", 1)
  f:SetSize(18, 18)
  f.text = UI.Text(f, 10, "white", "body", "CENTER")
  f.text:SetPoint("CENTER")
  function f:SetCount(n)
    self.text:SetText(n)
    self:SetWidth(math.max(18, self.text:GetStringWidth() + 8))
    self:SetShown(n > 0)
  end
  return f
end

-- The label of a button made from a game template (its own font string; one of ours if it has none).
local function buttonText(b, size)
  local fs = b.GetFontString and b:GetFontString()
  if not fs then
    fs = b:CreateFontString(nil, "OVERLAY")
    fs:SetFont(Theme.FONT_BODY, size or 12, "")
    fs:SetPoint("CENTER")
  end
  return fs
end

-- A flat parchment button (the secondary style, segmented choices, menu rows): a thin gold border on a light wash,
-- ink text. :SetOn(true) marks a chosen option: dark leather with gold text and a bright gold border, so red stays
-- the colour of the one main action (chosen options in red looked like more red buttons; M20).
-- kind "danger": red text and border (destructive actions).
local FLAT = { bgFile = ns.WHITE, edgeFile = ns.WHITE, edgeSize = 1 }
local function flatButton(parent, size, kind)
  local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
  b:SetBackdrop(FLAT)
  b.text = UI.Text(b, size or 12, nil, "body", "CENTER")
  b.text:SetPoint("CENTER")
  local hl = b:CreateTexture(nil, "HIGHLIGHT")
  hl:SetPoint("TOPLEFT", 1, -1); hl:SetPoint("BOTTOMRIGHT", -1, 1)
  hl:SetColorTexture(1, 0.85, 0.45, 0.18)
  function b:Paint()
    local enabled = self:IsEnabled() ~= false
    if self.on then
      self:SetBackdropColor(Theme:RGBA("band2", enabled and 1 or 0.5)); self:SetBackdropBorderColor(Theme:RGBA("goldText", enabled and 1 or 0.5))
      self.text:SetTextColor(Theme:RGBA("goldText", enabled and 1 or 0.6))
    else
      -- The page's darker parchment tone (near-white looked like a web page; seen in the second tour).
      self:SetBackdropColor(Theme:RGBA("page2", 0.95)); self:SetBackdropBorderColor(Theme:RGBA(kind == "danger" and "B0321E" or "bookEdge", enabled and 0.9 or 0.4))
      self.text:SetTextColor(Theme:RGBA(kind == "danger" and "B0321E" or "ink", enabled and 1 or 0.45))
    end
  end
  function b:SetOn(on) self.on = on and true or false; self:Paint() end
  b:HookScript("OnEnable", function() b:Paint() end)
  b:HookScript("OnDisable", function() b:Paint() end)
  Theme:Register(function() b:Paint() end)
  return b
end
UI.FlatButton = flatButton

---------------------------------------------------------------------------
-- WoW-style controls (27 Oct 2026): the game's own art, chosen from the button gallery (Dev/Gallery.lua, seen in
-- game). Each falls back to the flat parchment look above when the art is missing.
---------------------------------------------------------------------------
local function atlasOK(name) return C_Texture ~= nil and C_Texture.GetAtlasInfo ~= nil and C_Texture.GetAtlasInfo(name) ~= nil end
local PANEL = "Interface\\Buttons\\UI-Panel-Button-"
local PANEL_SLICES = { { 0, 0.09375, 12 }, { 0.09375, 0.53125 }, { 0.53125, 0.625, 12 } } -- left, middle, right
UI.art = {}
function UI.ArtReady()
  if UI.art.checked then return UI.art end
  local probe = UIParent:CreateTexture()
  UI.art.panel = probe:SetTexture(PANEL .. "Disabled") ~= false
  UI.art.list = atlasOK("PetList-ButtonBackground") and atlasOK("PetList-ButtonSelect")
  UI.art.roles = atlasOK("UI-LFG-RoleIcon-Tank") and atlasOK("checkmark-minimal")
  probe:Hide()
  UI.art.checked = true
  return UI.art
end

-- Three slices of a UI-Panel-Button file on button b (the shape of the game's red button).
local function panelSlices(b, file, layer, sub)
  local t = {}
  for i, s in ipairs(PANEL_SLICES) do
    local tex = b:CreateTexture(nil, layer, nil, sub)
    tex:SetTexture(PANEL .. file)
    tex:SetTexCoord(s[1], s[2], 0, 0.6875)
    t[i] = tex
  end
  t[1]:SetPoint("TOPLEFT"); t[1]:SetPoint("BOTTOMLEFT"); t[1]:SetWidth(PANEL_SLICES[1][3])
  t[3]:SetPoint("TOPRIGHT"); t[3]:SetPoint("BOTTOMRIGHT"); t[3]:SetWidth(PANEL_SLICES[3][3])
  t[2]:SetPoint("TOPLEFT", t[1], "TOPRIGHT"); t[2]:SetPoint("BOTTOMRIGHT", t[3], "BOTTOMLEFT")
  return t
end

-- The secondary button: the red button's shape in the game's dark (disabled) art with gold text, so red stays the
-- one main action and every other button still looks like the game's. kind "danger": light red text.
local function gameButton(parent, size, kind)
  if not UI.ArtReady().panel then return flatButton(parent, size, kind) end
  local b = CreateFrame("Button", nil, parent)
  panelSlices(b, "Disabled", "BACKGROUND", 0)
  local hl = panelSlices(b, "Highlight", "HIGHLIGHT", 0)
  for _, t in ipairs(hl) do t:SetBlendMode("ADD"); t:SetAlpha(0.7) end
  b.text = UI.Text(b, size or 12, nil, "body", "CENTER")
  b.text:SetPoint("CENTER", 0, 1)
  b.text:SetShadowOffset(1, -1); b.text:SetShadowColor(0, 0, 0, 1)
  b:SetScript("OnMouseDown", function() if b:IsEnabled() then b.text:SetPoint("CENTER", 1, 0) end end)
  b:SetScript("OnMouseUp", function() b.text:SetPoint("CENTER", 0, 1) end)
  function b:Paint()
    local enabled = self:IsEnabled() ~= false
    local c = kind == "danger" and "F07A64" or "goldText"
    self.text:SetTextColor(Theme:RGBA(c, enabled and 1 or 0.45))
  end
  function b:SetOn() end
  b:HookScript("OnEnable", function() b:Paint() end)
  b:HookScript("OnDisable", function() b:Paint() end)
  b:Paint()
  return b
end
UI.GameButton = gameButton

-- A choice in a row (Duo / Party, Yes / No, 0 1 2 3): the game's collection-list buttons. Dark, light text; the chosen
-- one has the gold selection rim and gold text, as a chosen pet or mount in the Collections window.
local function choiceButton(parent, size)
  if not UI.ArtReady().list then return flatButton(parent, size) end
  local b = CreateFrame("Button", nil, parent)
  b.bg = b:CreateTexture(nil, "BACKGROUND")
  b.bg:SetAllPoints(); b.bg:SetAtlas("PetList-ButtonBackground")
  b.sel = b:CreateTexture(nil, "OVERLAY")
  b.sel:SetPoint("TOPLEFT", -1, 1); b.sel:SetPoint("BOTTOMRIGHT", 1, -1); b.sel:SetAtlas("PetList-ButtonSelect")
  -- The rim alone was hard to see (seen in game): the chosen one also glows warm gold inside.
  b.glow = b:CreateTexture(nil, "ARTWORK")
  b.glow:SetPoint("TOPLEFT", 3, -3); b.glow:SetPoint("BOTTOMRIGHT", -3, 3)
  UI.SetGradient(b.glow, "VERTICAL", { 0.85, 0.6, 0.15, 0.45 }, { 1, 0.85, 0.4, 0.2 })
  local hl = b:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints(); hl:SetAtlas("PetList-ButtonSelect"); hl:SetAlpha(0.35)
  b.text = UI.Text(b, size or 12, nil, "body", "CENTER")
  b.text:SetPoint("CENTER")
  b.text:SetShadowOffset(1, -1); b.text:SetShadowColor(0, 0, 0, 1)
  function b:Paint()
    local enabled = self:IsEnabled() ~= false
    self.sel:SetShown(self.on == true); self.glow:SetShown(self.on == true)
    self.text:SetTextColor(Theme:RGBA(self.on and "white" or "chipText", enabled and (self.on and 1 or 0.7) or 0.4))
    self.bg:SetAlpha(enabled and 1 or 0.5)
  end
  function b:SetOn(on) self.on = on and true or false; self:Paint() end
  b:HookScript("OnEnable", function() b:Paint() end)
  b:HookScript("OnDisable", function() b:Paint() end)
  b:Paint()
  return b
end

-- Button with text. style: "primary" (the game's red panel button: the one main action of a card), "plain" (the
-- game's dark panel button: everything else), "danger" (dark, light red text: destructive, asks first), "link"
-- (text only).
function UI.TextButton(parent, label, onClick, style, size)
  local b
  if style == "link" then
    b = CreateFrame("Button", nil, parent)
    b.text = UI.Text(b, size or 13, "ink2", "body", "CENTER")
    b.text:SetPoint("CENTER")
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints(); hl:SetColorTexture(1, 1, 1, 0.08)
  elseif style == "primary" then
    b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b.text = buttonText(b, size)
  else
    b = gameButton(parent, size, style == "danger" and "danger" or nil)
  end
  function b:SetLabel(text)
    if self.SetText then self:SetText(text) end
    self.text:SetText(text)
    -- Primary and plain are the same height, so a row of them lines up.
    local tall = style ~= "link"
    self:SetSize(self.text:GetStringWidth() + (style == "link" and 4 or 30), tall and 28 or 24)
  end
  b:SetLabel(label)
  b:SetScript("OnClick", onClick)
  return b
end

-- A row of choices (the mockup's "seg"): flat buttons; the chosen one is dark leather with gold text.
-- maxWidth (optional): buttons that do not fit go on the next line.
function UI.Choice(parent, options, getValue, onPick, maxWidth)
  local row = CreateFrame("Frame", nil, parent)
  row.buttons = {}
  -- Places the buttons by their texts (again after a text changed: the Gathering form's day names change daily).
  function row:Layout()
    local x, y, widest = 0, 0, 0
    for _, b in ipairs(self.buttons) do
      local w = math.max(36, b.text:GetStringWidth() + 26)
      b:SetSize(w, 26)
      if maxWidth and x > 0 and x + w > maxWidth then x, y = 0, y + 30 end
      b:ClearAllPoints(); b:SetPoint("TOPLEFT", self, "TOPLEFT", x, -y)
      x = x + w + 4
      widest = math.max(widest, x - 3)
    end
    self:SetSize(widest, y + 26)
  end
  for i, opt in ipairs(options) do
    local b = choiceButton(row, 12)
    b.text:SetText(opt[1])
    b.value = opt[2]
    b:SetScript("OnClick", function()
      if getValue() ~= opt[2] then ns.Sound("choose") end
      onPick(opt[2]); row:Refresh()
    end)
    row.buttons[i] = b
  end
  row:Layout()
  function row:SetEnabled(on)
    for _, b in ipairs(self.buttons) do b:SetEnabled(on); b:Paint() end
  end
  function row:Refresh()
    local v = getValue()
    for _, b in ipairs(self.buttons) do b:SetOn(b.value == v) end
  end
  row:Refresh()
  return row
end

-- The role picker, like the Dungeon Finder's: Tank, Healer and DPS as the game's round role icons; the chosen one in
-- full colour with a gold check, the others dimmed and grey. Same interface as UI.Choice (buttons, Refresh,
-- SetEnabled), so it replaces a Choice of roles. Without the art: a Choice of the role names.
local ROLE_ATLAS = { Tank = "UI-LFG-RoleIcon-Tank", Healer = "UI-LFG-RoleIcon-Healer", DPS = "UI-LFG-RoleIcon-DPS" }
function UI.RoleChoice(parent, options, getValue, onPick)
  if not UI.ArtReady().roles then return UI.Choice(parent, options, getValue, onPick) end
  local ICON, W = 34, 64
  local row = CreateFrame("Frame", nil, parent)
  row.buttons = {}
  for i, opt in ipairs(options) do
    local b = CreateFrame("Button", nil, row)
    b:SetSize(W, ICON + 16)
    b:SetPoint("TOPLEFT", (i - 1) * (W + 4), 0)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(ICON, ICON); b.icon:SetPoint("TOP")
    b.icon:SetAtlas(ROLE_ATLAS[opt[2]] or ROLE_ATLAS.DPS)
    b.check = b:CreateTexture(nil, "OVERLAY")
    b.check:SetSize(18, 18); b.check:SetPoint("BOTTOMRIGHT", b.icon, "BOTTOMRIGHT", 5, -3)
    b.check:SetAtlas("checkmark-minimal")
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetSize(ICON + 6, ICON + 6); hl:SetPoint("CENTER", b.icon)
    hl:SetTexture("Interface\\Buttons\\UI-Quickslot-Depress"); hl:SetBlendMode("ADD"); hl:SetAlpha(0.5)
    b.text = UI.Text(b, 12, nil, "body", "CENTER")
    b.text:SetPoint("TOP", b.icon, "BOTTOM", 0, -2)
    b.text:SetText(opt[1])
    b.value = opt[2]
    b:SetScript("OnClick", function()
      if getValue() ~= opt[2] then ns.Sound("choose") end
      onPick(opt[2]); row:Refresh()
    end)
    function b:SetOn(on)
      self.on = on
      local enabled = self:IsEnabled() ~= false
      self.icon:SetDesaturated(not on)
      self.icon:SetAlpha(on and 1 or (enabled and 0.55 or 0.3))
      self.check:SetShown(on)
      self.text:SetTextColor(Theme:RGBA(on and "ink" or "ink2", enabled and 1 or 0.5))
    end
    row.buttons[i] = b
  end
  row:SetSize(#options * (W + 4) - 4, ICON + 16)
  function row:SetEnabled(on) for _, b in ipairs(self.buttons) do b:SetEnabled(on); b:SetOn(b.on) end end
  function row:Refresh()
    local v = getValue()
    for _, b in ipairs(self.buttons) do b:SetOn(b.value == v) end
  end
  row:Refresh()
  return row
end

-- Tabs (Quests, History filters): words on a line; the chosen one is ink with a gold bar under it. Same interface as
-- UI.Choice (buttons, Refresh, SetEnabled). counts(value) may return a number shown after the label. size: the words'
-- size (14; smaller, 24 high, for a filter under a page's own tabs: the Chronicle's).
-- A page's own tabs give each option an icon (opt[3]; U102): the book's folder tabs, the icon before the words, in
-- the theme's colours. The chosen one is the page's own paper, taller, with a gold edge and open to the page below;
-- the others a darker paper behind the line. (The game's character-frame tabs were black on the parchment and their
-- words ran past them: the check of 8 Nov 2026.) Their words always fit: less room around them first, then no icons.
local TAB_ICON, TAB_PAD, TAB_DROP = 14, 12, 4
local function folderTab(b)
  b.fill = b:CreateTexture(nil, "BACKGROUND")
  b.edges = {}
  for i = 1, 3 do b.edges[i] = b:CreateTexture(nil, "BORDER") end
  b.edges[1]:SetPoint("TOPLEFT", b.fill); b.edges[1]:SetPoint("TOPRIGHT", b.fill); b.edges[1]:SetHeight(1)
  b.edges[2]:SetPoint("TOPLEFT", b.fill); b.edges[2]:SetPoint("BOTTOMLEFT", b.fill); b.edges[2]:SetWidth(1)
  b.edges[3]:SetPoint("TOPRIGHT", b.fill); b.edges[3]:SetPoint("BOTTOMRIGHT", b.fill); b.edges[3]:SetWidth(1)
end
local function paintTab(b, on)
  b.fill:ClearAllPoints()
  b.fill:SetPoint("TOPLEFT", 0, on and 0 or -TAB_DROP)
  -- (The chosen one covers the line under it: it is open to the page.)
  b.fill:SetPoint("BOTTOMRIGHT", 0, on and -1 or 0)
  b.fill:SetColorTexture(Theme:RGBA(on and "page1" or "page2", 1))
  for _, e in ipairs(b.edges) do e:SetColorTexture(Theme:RGBA(on and "gold" or "line", 1)) end
  b.edges[1]:SetHeight(on and 2 or 1)
end
function UI.Tabs(parent, options, getValue, onPick, width, counts, size)
  size = size or 14
  local game = options[1] and options[1][3] ~= nil
  local rowH = game and 32 or (size < 14 and 24 or 28)
  local row = CreateFrame("Frame", nil, parent)
  row:SetSize(width, rowH)
  local base = UI.Solid(row, "BACKGROUND", "line", 0.9)
  base:SetHeight(1); base:SetPoint("BOTTOMLEFT"); base:SetPoint("BOTTOMRIGHT")
  row.buttons = {}
  for i, opt in ipairs(options) do
    local b = CreateFrame("Button", nil, row)
    b.text = UI.Text(b, size, nil, "title", "CENTER")
    b.text:SetPoint("CENTER", 0, 1)
    b.bar = UI.Solid(b, "ARTWORK", "gold", 1)
    b.bar:SetHeight(3); b.bar:SetPoint("BOTTOMLEFT", 4, 0); b.bar:SetPoint("BOTTOMRIGHT", -4, 0)
    if game then
      folderTab(b)
      b.icon = b:CreateTexture(nil, "ARTWORK")
      b.icon:SetSize(TAB_ICON, TAB_ICON)
      UI.SetIcon(b.icon, ns.ICONS[opt[3]])
      b.bar:Hide()
    end
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints(b.fill or b); hl:SetColorTexture(1, 0.85, 0.45, 0.1)
    b.value, b.label = opt[2], opt[1]
    b:SetScript("OnClick", function() onPick(opt[2]); row:Refresh() end)
    row.buttons[i] = b
  end
  function row:SetEnabled(on) for _, b in ipairs(self.buttons) do b:SetEnabled(on) end end
  function row:Refresh()
    local v, x, total = getValue(), 0, 0
    local n = #self.buttons
    local function measure(sz)
      total = 0
      for _, b in ipairs(self.buttons) do
        local file = b.text:GetFont()
        b.text:SetFont(file, sz, "")
        total = total + b.text:GetStringWidth() + 2
      end
    end
    for _, b in ipairs(self.buttons) do
      local k = counts and counts(b.value)
      b.text:SetText(k and k > 0 and (b.label .. "  " .. k) or b.label)
    end
    measure(size)
    -- Still too long with the least room around the words: a size smaller (two-digit counts on four tabs), never under
    -- the hint size (the Chronicle's filters are 12 already).
    local small = math.max(UI.HINT_MIN, size - 2)
    if total + n * 8 > width and small < size then measure(small) end
    -- The icons only while the words fit with them (four tabs with long names on a narrow page).
    local icons = game and total + n * (TAB_ICON + 4 + 8) <= width
    if icons then total = total + n * (TAB_ICON + 4) end
    -- 24 around each label; less when the row would not fit its width (History's five tabs with counts).
    local pad = math.max(8, math.min(game and 2 * TAB_PAD or 24, math.floor((width - total) / n)))
    for _, b in ipairs(self.buttons) do
      local extra = icons and TAB_ICON + 4 or 0
      local w = b.text:GetStringWidth() + extra + pad
      b:SetSize(w, rowH)
      b:ClearAllPoints(); b:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", x, 0)
      x = x + w + 2
      local on = b.value == v
      if game then
        paintTab(b, on)
        local dy = on and 0 or -TAB_DROP / 2
        b.icon:SetShown(icons)
        b.icon:ClearAllPoints(); b.icon:SetPoint("LEFT", math.floor(pad / 2), dy)
        b.icon:SetDesaturated(not on); b.icon:SetAlpha(on and 1 or 0.75)
        b.text:ClearAllPoints()
        if icons then b.text:SetPoint("LEFT", b.icon, "RIGHT", 4, 0) else b.text:SetPoint("CENTER", 0, dy) end
        b.text:SetTextColor(Theme:RGBA(on and "ink" or "ink2"))
      else
        b.bar:SetShown(on)
        b.text:SetTextColor(Theme:RGBA(on and "ink" or "ink2"))
      end
    end
  end
  Theme:Register(function() row:Refresh() end)
  return row
end

-- A "⋯" button that opens a small menu of actions. items() returns { { label, fn, danger } } (empty: no button).
-- One menu is open at a time; it belongs to the window, so a scrolling page never cuts it off.
UI.menu = nil
function UI.MenuButton(parent, items)
  local b = gameButton(parent, 14)
  -- Three gold dots (the text "..." read as a stray button; seen in the tour).
  b.text:SetText("")
  b:SetSize(34, 28)
  for i = -1, 1 do
    local dot = UI.Round(b, "ARTWORK", 5)
    dot:SetPoint("CENTER", i * 7, 1)
    Theme:Fill(dot, UI.ArtReady().panel and "goldText" or "bookEdge", 1)
  end
  b.items = items
  b:SetScript("OnClick", function()
    local m = UI.menu
    if m and m:IsShown() and m.owner == b then m:Hide() return end
    if not m then
      local owner = ns.Window.frame or UIParent
      m = UI.Card(owner, "gold")
      m.bgRole = "page1"
      m:Paint()
      m:SetFrameLevel(owner:GetFrameLevel() + 120)
      m:EnableMouse(true)
      m.rows = {}
      UI.menu = m
    end
    m.owner = b
    local list = items()
    local w = 120
    for i, it in ipairs(list) do
      local r = m.rows[i]
      if not r then
        r = CreateFrame("Button", nil, m)
        r.text = UI.Text(r, 13, nil, "body")
        r.text:SetPoint("LEFT", 10, 0)
        local hl = r:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints(); hl:SetColorTexture(1, 0.85, 0.45, 0.2)
        r:SetScript("OnClick", function() m:Hide(); if r.fn then r.fn() end end)
        m.rows[i] = r
      end
      r.fn, r.label = it[2], it[1]
      r.text:SetText(it[1])
      r.text:SetTextColor(Theme:RGBA(it[3] and "B0321E" or "ink"))
      w = math.max(w, r.text:GetStringWidth() + 24)
      r:ClearAllPoints(); r:SetPoint("TOPLEFT", m, "TOPLEFT", 4, -4 - (i - 1) * 24)
      r:Show()
    end
    for i = #list + 1, #m.rows do m.rows[i]:Hide() end
    for i = 1, #list do m.rows[i]:SetSize(w - 8, 24) end
    m:SetSize(w, #list * 24 + 8)
    m:ClearAllPoints(); m:SetPoint("TOPRIGHT", b, "BOTTOMRIGHT", 0, -2)
    m:Show()
  end)
  -- Shown only when there is something to do.
  function b:Update() self:SetShown(#items() > 0) end
  return b
end

-- Our ink sketches are drawn on parchment: tinted like the pages' paper, so on the Night theme's dark pages they are
-- not bright beige squares (seen in the seventh check).
function UI.PaperTint(tex)
  Theme:Register(function() tex:SetVertexColor(unpack(Theme.PAPER_TINT[Theme:Key()] or Theme.PAPER_TINT.journal)) end)
  return tex
end

-- An empty state (seen in the UI tour: empty pages said one grey line): a picture in a ring, a title, a sentence on
-- what will appear and how, and an optional button. :Set(icon, title, text, label, fn, sketch) returns its height.
function UI.EmptyState(parent, width)
  local f = CreateFrame("Frame", nil, parent)
  f:SetWidth(width)
  f.ring = UI.Round(f, "BORDER", 64)
  f.ring:SetPoint("TOP", 0, -8)
  Theme:Fill(f.ring, "gold", 0.55)
  f.pic = UI.Round(f, "ARTWORK", 58)
  f.pic:SetPoint("CENTER", f.ring, "CENTER")
  -- The Adventure Guide's gold ring (its Suggested Content) around the picture where the client has it, in place of
  -- the gold disc. At its own size its hole is the picture's size.
  f.gameRing = atlasOK("adventureguide-ring") and f:CreateTexture(nil, "OVERLAY") or nil
  if f.gameRing then
    f.gameRing:SetAtlas("adventureguide-ring")
    f.gameRing:SetSize(94, 95); f.gameRing:SetPoint("CENTER", f.ring, "CENTER")
  end
  f.title = UI.Text(f, 16, "ink", "title", "CENTER")
  f.title:SetPoint("TOP", f.ring, "BOTTOM", 0, -12)
  f.title:SetWidth(width - 20)
  f.text = UI.WrapText(f, 13, "ink2", width - 40, "book")
  f.text:SetJustifyH("CENTER")
  f.text:SetPoint("TOP", f.title, "BOTTOM", 0, -6)
  f.button = UI.TextButton(f, "", nil, "plain", 12)
  -- One of our ink sketches (sketch = "EmptyQuests" ...: Media\EmptyQuests) takes the place of the icon in its ring.
  f.sketch = UI.PaperTint(f:CreateTexture(nil, "ARTWORK"))
  f.sketch:SetSize(120, 120)
  f.sketch:SetPoint("TOP", 0, -4)
  function f:Set(icon, title, text, label, fn, sketch)
    local drawn = sketch and self.sketch:SetTexture(ns.MEDIA .. sketch) and true or false
    self.sketch:SetShown(drawn)
    self.ring:SetShown(not drawn and not self.gameRing); self.pic:SetShown(not drawn)
    if self.gameRing then self.gameRing:SetShown(not drawn) end
    UI.SetIcon(self.pic, icon or ns.ICONS.bn_done)
    local top = drawn and 4 + 120 or 8 + 64
    self.title:ClearAllPoints(); self.title:SetPoint("TOP", self, "TOP", 0, -(top + 12))
    self.title:SetText(title)
    self.text:SetText(text or "")
    local h = top + 12 + 18 + 6 + self.text:GetStringHeight()
    self.button:SetShown(label ~= nil)
    if label then
      self.button:SetLabel(label)
      self.button:SetScript("OnClick", fn)
      self.button:ClearAllPoints(); self.button:SetPoint("TOP", self.text, "BOTTOM", 0, -12)
      h = h + 12 + 24
    end
    self:SetHeight(h + 12)
    return h + 12
  end
  return f
end

-- A short empty line inside a section (no Gatherings, no votes): a small ink sketch with the sentence beside it.
-- Without the sketch file only the sentence shows. :SetText(t); .h is the height to place it with.
function UI.SketchLine(parent, width, sketch)
  local f = CreateFrame("Frame", nil, parent)
  f:SetWidth(width)
  f.pic = UI.PaperTint(f:CreateTexture(nil, "ARTWORK"))
  f.pic:SetSize(48, 48); f.pic:SetPoint("LEFT")
  local drawn = f.pic:SetTexture(ns.MEDIA .. sketch) and true or false
  f.pic:SetShown(drawn)
  f.text = UI.WrapText(f, 12, "ink2", width - (drawn and 58 or 0), "book")
  f.text:SetPoint("LEFT", drawn and 58 or 0, 0)
  function f:SetText(t)
    self.text:SetText(t)
    self.h = math.max(drawn and 48 or 0, self.text:GetStringHeight())
    self:SetHeight(self.h)
  end
  return f
end

-- ‹ value › with the spellbook's page arrows (window size, days, durations).
function UI.Stepper(parent, onDown, onUp, getText)
  local row = CreateFrame("Frame", nil, parent)
  row:SetSize(26 + 4 + 84 + 4 + 26, 26)
  local function arrow(kind, fn)
    local b = CreateFrame("Button", nil, row)
    b:SetSize(26, 26)
    b:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-" .. kind .. "-Up")
    b:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-" .. kind .. "-Down")
    b:SetDisabledTexture("Interface\\Buttons\\UI-SpellbookIcon-" .. kind .. "-Disabled")
    b:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    b:SetScript("OnClick", function() fn(); row:Refresh() end)
    return b
  end
  row.down = arrow("PrevPage", onDown)
  row.down:SetPoint("LEFT")
  row.value = UI.Text(row, 13, "ink", "body", "CENTER")
  row.value:SetWidth(84)
  row.value:SetPoint("LEFT", row.down, "RIGHT", 4, 0)
  row.up = arrow("NextPage", onUp)
  row.up:SetPoint("LEFT", row.value, "RIGHT", 4, 0)
  function row:Refresh() self.value:SetText(getText()) end
  row:Refresh()
  return row
end

---------------------------------------------------------------------------
-- Controls like the game's settings menu: checkbox, slider, dropdown.
---------------------------------------------------------------------------
function UI.Checkbox(parent, getValue, setValue)
  local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
  cb:SetSize(26, 26)
  cb:SetScript("OnClick", function(self) setValue(self:GetChecked() and true or false) end)
  function cb:Refresh() self:SetChecked(getValue() and true or false) end
  cb:Refresh()
  return cb
end

-- A checkbox with its words beside it, and a tooltip (tip, wrapped) on both. Height 24; :Refresh().
function UI.LabeledCheck(parent, width, label, tip, getValue, setValue)
  local f = CreateFrame("Frame", nil, parent)
  f:SetSize(width, 24)
  f.box = UI.Checkbox(f, getValue, setValue)
  f.box:SetPoint("LEFT", -3, 0)
  f.label = UI.Text(f, 13, "ink")
  f.label:SetPoint("LEFT", f.box, "RIGHT", 2, 0)
  f.label:SetText(label)
  local function show(owner)
    if not tip then return end
    GameTooltip:SetOwner(owner, "ANCHOR_TOP")
    GameTooltip:SetText(label, 1, 1, 1)
    GameTooltip:AddLine(tip, 0.85, 0.8, 0.7, true)
    GameTooltip:Show()
  end
  f:EnableMouse(true)
  f:SetScript("OnEnter", show)
  f:SetScript("OnLeave", function() GameTooltip:Hide() end)
  f:SetScript("OnMouseUp", function() f.box:Click() end)
  f.box:HookScript("OnEnter", show)
  f.box:HookScript("OnLeave", function() GameTooltip:Hide() end)
  function f:Refresh() self.box:Refresh() end
  return f
end

-- A slider from min to max in steps; the value is shown on the right (format(value) gives the text).
function UI.Slider(parent, width, min, max, step, getValue, setValue, format)
  local f = CreateFrame("Frame", nil, parent)
  f:SetSize(width, 26)
  local s = CreateFrame("Slider", nil, f, "BackdropTemplate")
  s:SetOrientation("HORIZONTAL")
  s:SetSize(width - 52, 17)
  s:SetPoint("LEFT")
  s:SetBackdrop({ bgFile = "Interface\\Buttons\\UI-SliderBar-Background", edgeFile = "Interface\\Buttons\\UI-SliderBar-Border",
    tile = true, tileSize = 8, edgeSize = 8, insets = { left = 3, right = 3, top = 6, bottom = 6 } })
  s:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
  s:SetMinMaxValues(min, max)
  s:SetValueStep(step)
  s:SetObeyStepOnDrag(true)
  f.value = UI.Text(f, 13, "ink", "body", "RIGHT")
  f.value:SetPoint("RIGHT")
  f.value:SetWidth(48)
  s:SetScript("OnValueChanged", function(_, v)
    if f.updating then return end
    v = math.floor(v / step + 0.5) * step
    setValue(v)
    f.value:SetText(format(getValue()))
  end)
  function f:Refresh()
    self.updating = true
    s:SetValue(getValue())
    self.updating = false
    self.value:SetText(format(getValue()))
  end
  f.slider = s
  f:Refresh()
  return f
end

-- A dropdown: shows the chosen option; a click opens the list. options = { { label, value }, ... }.
-- The list belongs to the window (not the panel), so a scrolling panel cannot cut it off.
UI.DROPDOWN_ROWS = 12
function UI.Dropdown(parent, width, options, getValue, setValue)
  local dd = UI.Card(parent, "line", "Button")
  dd:SetSize(width, 26)
  dd.text = UI.Text(dd, 13, "ink")
  dd.text:SetPoint("LEFT", 10, 0)
  -- Long choices (quest names) end in "..." instead of running past the box.
  dd.text:SetWidth(width - 36); dd.text:SetWordWrap(false)
  local arrow = dd:CreateTexture(nil, "OVERLAY")
  arrow:SetSize(14, 14)
  arrow:SetPoint("RIGHT", -8, 0)
  arrow:SetTexture("Interface\\ChatFrame\\ChatFrameExpandArrow")
  arrow:SetRotation(-math.pi / 2)
  local owner = ns.Window.frame or parent
  local menu = UI.Card(owner, "gold")
  menu.bgRole = "page1"
  menu:Paint()
  menu:SetPoint("TOPLEFT", dd, "BOTTOMLEFT", 0, -2)
  menu:SetFrameLevel(owner:GetFrameLevel() + 100)
  menu:Hide()
  dd.menu = menu
  dd.items = {}
  -- Long lists (every dungeon and raid for a Gathering) scroll: at most DROPDOWN_ROWS rows show at once.
  local list = UI.Scroll(menu)
  list:SetPoint("TOPLEFT", 4, -4); list:SetPoint("BOTTOMRIGHT", -8, 4)
  dd.list = list
  local function row(i)
    local b = CreateFrame("Button", nil, list.child)
    b:SetSize(width - 12, 22)
    b:SetPoint("TOPLEFT", 0, -(i - 1) * 22)
    b.check = UI.Check(b, 14)
    b.check:SetPoint("LEFT", 4, 0)
    b.text = UI.Text(b, 13, "ink")
    b.text:SetPoint("LEFT", 22, 0)
    b.text:SetWidth(width - 40); b.text:SetWordWrap(false)
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints(); hl:SetColorTexture(1, 0.9, 0.6, 0.2)
    dd.items[i] = b
    return b
  end
  local function size(n)
    menu:SetSize(width, math.min(n, UI.DROPDOWN_ROWS) * 22 + 8)
    list:SetContentHeight(n * 22, true)
  end
  for i, opt in ipairs(options) do
    local b = row(i)
    b.text:SetText(opt[1])
    b:SetScript("OnClick", function() menu:Hide(); setValue(opt[2]); dd:Refresh() end)
    b.value = opt[2]
  end
  size(#options)
  dd:SetScript("OnClick", function() menu:SetShown(not menu:IsShown()) end)
  dd:SetScript("OnHide", function() menu:Hide() end)
  function dd:Refresh()
    local v = getValue()
    for i, opt in ipairs(options) do
      if opt[2] == v then self.text:SetText(opt[1]) end
      self.items[i].check:SetShown(opt[2] == v)
    end
  end
  -- New options (the Gathering form's dungeons change with the journey). Rows are made as needed.
  function dd:SetOptions(opts)
    options = opts
    for i, opt in ipairs(opts) do
      local b = self.items[i] or row(i)
      b.text:SetText(opt[1])
      b:SetScript("OnClick", function() menu:Hide(); setValue(opt[2]); dd:Refresh() end)
      b:Show()
    end
    for i = #opts + 1, #self.items do self.items[i]:Hide() end
    size(#opts)
    self:Refresh()
  end
  dd:Refresh()
  return dd
end

-- A value shown on the right of a settings row (window size).
function UI.ValueText(parent, getText)
  local f = CreateFrame("Frame", nil, parent)
  f:SetSize(76, 28)
  f.text = UI.Text(f, 14, "ink", "body", "RIGHT")
  f.text:SetPoint("RIGHT")
  function f:Refresh() self.text:SetText(getText()) end
  f:Refresh()
  return f
end

-- ✕ drawn with two thin bars, so it stays sharp at any size.
function UI.Cross(parent, size, role)
  local bars = {}
  for i, angle in ipairs({ 45, -45 }) do
    local t = UI.Solid(parent, "ARTWORK", role, 1, 3)
    t:SetSize(size, 2)
    t:SetPoint("CENTER")
    t:SetRotation(math.rad(angle))
    bars[i] = t
  end
  return bars
end

-- The ❦ divider under a page title: two fading lines and a small diamond.
-- Anchor it left and right; it stretches.
local INK_DIVIDER = "adventureguide-tutorial-divider"
function UI.Divider(parent)
  local f = CreateFrame("Frame", nil, parent)
  f:SetHeight(12)
  local l = UI.GradientTex(f, "ARTWORK", "HORIZONTAL", { "line", 0 }, { "line", 1 })
  l:SetHeight(1); l:SetPoint("LEFT"); l:SetPoint("RIGHT", f, "CENTER", -10, 0)
  local r = UI.GradientTex(f, "ARTWORK", "HORIZONTAL", { "line", 1 }, { "line", 0 })
  r:SetHeight(1); r:SetPoint("LEFT", f, "CENTER", 10, 0); r:SetPoint("RIGHT")
  local d = UI.Solid(f, "ARTWORK", "line")
  d:SetSize(6, 6); d:SetPoint("CENTER"); d:SetRotation(math.rad(45))
  -- On light pages, the Adventure Guide's ink divider (its Tutorials, 29 Oct 2026): a brown line with a curl at one
  -- end, drawn twice and mirrored so the curls meet under a centred title. Brown ink is lost on the Night theme,
  -- which keeps the drawn line, as does a client without the art.
  local info = atlasOK(INK_DIVIDER) and C_Texture.GetAtlasInfo(INK_DIVIDER)
  local file = info and (info.file or info.filename)
  if file then
    local il = f:CreateTexture(nil, "ARTWORK")
    il:SetTexture(file); il:SetTexCoord(info.rightTexCoord, info.leftTexCoord, info.topTexCoord, info.bottomTexCoord)
    il:SetHeight(6); il:SetPoint("LEFT"); il:SetPoint("RIGHT", f, "CENTER", -1, 0)
    local ir = f:CreateTexture(nil, "ARTWORK")
    ir:SetAtlas(INK_DIVIDER)
    ir:SetHeight(6); ir:SetPoint("LEFT", f, "CENTER", 1, 0); ir:SetPoint("RIGHT")
    Theme:Register(function()
      local ink = Theme:Current().light == true
      il:SetShown(ink); ir:SetShown(ink)
      l:SetShown(not ink); r:SetShown(not ink); d:SetShown(not ink)
    end)
  end
  return f
end

-- Scrolling area (mouse wheel) with a thin position bar. Put content in .child and call :SetContentHeight(h).
function UI.Scroll(parent)
  local sf = CreateFrame("ScrollFrame", nil, parent)
  local child = CreateFrame("Frame", nil, sf)
  child:SetSize(1, 1)
  sf:SetScrollChild(child)
  sf.child = child
  sf.contentHeight = 0
  local thumb = UI.Solid(sf, "OVERLAY", "line", 0.9)
  thumb:SetWidth(3)
  -- While there is more below, the lower edge fades into the page (M25: no half-cut lines). On a frame of its own
  -- above the content: the scroll frame's own textures draw under its child. Only a little above it: at +40 the
  -- Welcome list's fade drew over the Your characters panel (check of 30 Oct 2026; the layers: ns.Window.LAYER).
  local fade = CreateFrame("Frame", nil, sf)
  fade:SetFrameLevel(sf:GetFrameLevel() + 20)
  fade:SetPoint("BOTTOMLEFT"); fade:SetPoint("BOTTOMRIGHT")
  fade:SetHeight(UI.SCROLL_FADE)
  fade:SetClipsChildren(true)
  fade.copies = {}
  -- The plain fade, until the copy of the paper is made (it is not made during combat).
  fade.plain = UI.GradientTex(fade, "OVERLAY", "VERTICAL", { "page1", 0.9 }, { "page1", 0 })
  fade.plain:SetAllPoints()
  fade:Hide()
  sf.fade = fade
  local function update()
    local view = sf:GetHeight()
    local max = math.max(0, sf.contentHeight - view)
    local pos = ns.Clamp(sf:GetVerticalScroll(), 0, max)
    sf:SetVerticalScroll(pos)
    fade:SetShown(max > 0 and pos < max - 2)
    if fade:IsShown() then UI.PaintFade(fade) end
    thumb:SetShown(max > 0)
    if max > 0 then
      local h = math.max(20, view * view / sf.contentHeight)
      thumb:SetHeight(h)
      thumb:ClearAllPoints()
      thumb:SetPoint("TOPRIGHT", sf, "TOPRIGHT", 6, -(view - h) * pos / max)
    end
  end
  sf:EnableMouseWheel(true)
  sf:SetScript("OnMouseWheel", function(_, delta) sf:SetVerticalScroll(sf:GetVerticalScroll() - delta * 40); update() end)
  sf:SetScript("OnSizeChanged", function() child:SetWidth(sf:GetWidth()); update() end)
  -- (The book turns between its open pages and the flat sheet while the page is hidden.)
  fade:SetScript("OnShow", function() UI.PaintFade(fade) end)
  -- Room at the end, so the last line is never cut by the page edge (seen in the UI tour); exact for menus.
  function sf:SetContentHeight(h, exact)
    if not exact then h = h + 24 end
    self.contentHeight = h; child:SetHeight(h); update()
  end
  function sf:ToTop() self:SetVerticalScroll(0); update() end
  -- Scrolls the least so the part from top down h is in view, clear of the fade (Journey Admin's chosen chapter
  -- stayed out of sight; check of 30 Oct 2026). False while the scroll has no size yet.
  function sf:Reveal(top, h)
    local view, pos = self:GetHeight(), self:GetVerticalScroll()
    if view <= UI.SCROLL_FADE then return false end
    -- (A row taller than the view shows its top, where its name is.)
    if top < pos or h > view - UI.SCROLL_FADE then pos = top
    elseif top + h > pos + view - UI.SCROLL_FADE then pos = top + h - view + UI.SCROLL_FADE end
    self:SetVerticalScroll(pos); update()
    return true
  end
  UI.scrolls[#UI.scrolls + 1] = sf
  return sf
end
UI.scrolls = {}
UI.SCROLL_FADE = 30
UI.FADE_MASK = ns.MEDIA .. "FadeMask" -- clear at the top, solid at the bottom

-- What a scroll's lower edge fades into: the nearest parent that says what it is drawn on. A frame with paper (a
-- book page, the flat sheet, an insert) has .paper(t), which draws that paper again on frame t and returns its
-- textures, and .paperShown() when it only sometimes shows (the open pages and the flat sheet take turns). A card
-- or a menu has .surface: its plain colour.
local function surfaceOf(f)
  local p = f:GetParent()
  while p do
    if p.paper and (not p.paperShown or p.paperShown()) then return p end
    if p.surface then return p end
    p = p:GetParent()
  end
end

-- Paints the fade: a copy of the paper under it, cut to the fade's strip and faded in towards the bottom
-- (Media\FadeMask), so the last lines run out into the page itself. (A plain colour showed as a light band on the
-- darker parchment; seen in the seventh check.) On a plain colour (a card, a menu), the plain fade.
function UI.PaintFade(fade)
  local s = surfaceOf(fade:GetParent())
  if s == fade.on then return end
  local c = s and s.paper and fade.copies[s]
  if s and s.paper and not c then
    -- Made the first time it shows, never during combat: the plain fade meanwhile.
    if ns.Combat:InCombat() then
      if not fade.waiting then
        fade.waiting = true
        ns.Combat:AfterCombat(function() fade.waiting = nil; UI.PaintFade(fade) end)
      end
      s, c = nil, nil
    else
      c = CreateFrame("Frame", nil, fade)
      c:SetAllPoints(s)
      local mask = c:CreateMaskTexture()
      mask:SetTexture(UI.FADE_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
      mask:SetAllPoints(fade)
      for _, t in ipairs(s.paper(c)) do t:AddMaskTexture(mask) end
      fade.copies[s] = c
    end
  end
  fade.on = s
  for _, other in pairs(fade.copies) do other:SetShown(other == c) end
  fade.plain:SetShown(c == nil)
end

-- Every scrolling area inside root back to the top: a page turned to starts at its top (the Overview opened
-- half-scrolled after a chapter unlocked; seen in the tour).
-- A page's halves hang off the book, not off the page frame (UI/Window.lua), so root.left and root.right count as
-- roots too (only root itself was looked for, and no page ever went back to its top; seen in the tour).
function UI.ScrollsToTop(root)
  local roots = { root, root.left, root.right }
  for _, sf in ipairs(UI.scrolls) do
    local p, hit = sf:GetParent(), false
    while p and not hit do
      for _, r in ipairs(roots) do if p == r then hit = true end end
      p = p:GetParent()
    end
    if hit then sf:ToTop() end
  end
end

-- A page vignette (Media\Page<name>: a 2:1 journal sketch) at the bottom of a page or scrolling area, filling the
-- empty parchment under short content (pages were half bare; seen in the tour). It sits behind the content and does
-- not scroll. :Fit(used) shows it only when the area has room below the used height; it shrinks to fit, down to
-- PAGE_ART_MIN high, and otherwise hides.
UI.PAGE_ART_W, UI.PAGE_ART_MIN = 400, 110
function UI.PageArt(area, name)
  local art = area:CreateTexture(nil, "BACKGROUND", nil, 2)
  art.ok = art:SetTexture(ns.MEDIA .. "Page" .. name) ~= false
  art:SetPoint("BOTTOM", area, "BOTTOM", 0, 10)
  -- Tinted like the paper: on the Night theme's dark pages an engraving, not a bright beige sketch (at half strength
  -- it still stood out; seen in the seventh check).
  UI.PaperTint(art)
  art:SetAlpha(0.9)
  art:Hide()
  function art:Fit(used)
    local room = area:GetHeight() - (used or 0) - 24
    local w = math.min(UI.PAGE_ART_W, area:GetWidth() - 20)
    local h = math.min(w / 2, room)
    local show = self.ok and h >= UI.PAGE_ART_MIN
    self:SetShown(show)
    if show then self:SetSize(h * 2, h) end
    return show
  end
  return art
end

-- Rows created on demand. Get(i) returns nil instead of creating a frame during combat; callers show what
-- they have and refresh again after combat.
function UI.Pool(create)
  local pool = { items = {} }
  function pool:Get(i)
    if not self.items[i] then
      if ns.Combat:InCombat() then
        if not self.waiting then
          self.waiting = true
          ns.Combat:AfterCombat(function() pool.waiting = false; ns.Window:Refresh() end)
        end
        return nil
      end
      self.items[i] = create(i)
    end
    return self.items[i]
  end
  function pool:HideFrom(i) for k = i, #self.items do self.items[k]:Hide() end end
  return pool
end

-- Places frames below each other: stack:Place(frame, height, gapAfter, x).
function UI.Stack(parent)
  local s = { y = 0 }
  function s:Place(f, h, gap, x)
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", parent, "TOPLEFT", x or 0, -self.y)
    f:Show()
    self.y = self.y + (h or f:GetHeight()) + (gap or 0)
  end
  function s:Skip(n) self.y = self.y + n end
  return s
end

-- A day as a heading (U132): Today, Yesterday, 7 Nov.
function UI.DayLabel(t)
  local L, now = ns.L, time()
  local day = date("%Y-%m-%d", t)
  if day == date("%Y-%m-%d", now) then return L.G_TODAY end
  if day == date("%Y-%m-%d", now - 86400) then return L.DAY_YESTERDAY end
  return L.DAY_HEAD:format(tonumber(date("%d", t)), date("%b", t))
end

-- Day headings in a list of entries, newest first (U132): heads:Start(), then heads:Place(stack, time) before each
-- entry puts a heading before the first of each day; heads:Done() hides the rest. Days by this PC's calendar (each
-- line's time is its writer's clock: one written near midnight on a PC whose clock is off may fall under the next day).
function UI.DayHeads(parent, width)
  local pool = UI.Pool(function()
    local h = UI.Text(parent, 12, "accent", "title")
    h:SetWidth(width)
    return h
  end)
  local o = { n = 0 }
  function o:Start() self.n, self.day = 0, nil end
  function o:Place(s, t)
    local day = t and date("%Y-%m-%d", t)
    if not day or day == self.day then return end
    self.day = day
    local h = pool:Get(self.n + 1)
    if not h then return end
    self.n = self.n + 1
    h:SetText(UI.DayLabel(t):upper())
    if self.n > 1 then s:Skip(6) end
    s:Place(h, 16, 4)
  end
  function o:Done() pool:HideFrom(self.n + 1) end
  o.pool = pool
  return o
end

-- A heading with an optional line under it (in the book font) and the ❦ divider (the mockup's h2 blocks).
function UI.Heading(parent, width, text, sub, size)
  local f = CreateFrame("Frame", nil, parent)
  f:SetWidth(width)
  f.title = UI.Text(f, size or 17, "ink", "title", "CENTER")
  f.title:SetPoint("TOP")
  f.title:SetWidth(width)
  f.sub = UI.WrapText(f, 12, "ink2", width, "book")
  f.sub:SetJustifyH("CENTER")
  f.sub:SetPoint("TOP", f.title, "BOTTOM", 0, -3)
  f.divider = UI.Divider(f)
  function f:Set(t, s)
    self.title:SetText(t)
    self.sub:SetText(s or "")
    self.sub:SetShown(s ~= nil and s ~= "")
    local h = (size or 17) + 4 + (self.sub:IsShown() and (self.sub:GetStringHeight() + 3) or 0)
    self.divider:ClearAllPoints()
    self.divider:SetPoint("TOPLEFT", 0, -(h + 4)); self.divider:SetPoint("TOPRIGHT", 0, -(h + 4))
    self:SetHeight(h + 20)
    if self.help then
      self.help:ClearAllPoints()
      self.help:SetPoint("LEFT", self.title, "CENTER", self.title:GetStringWidth() / 2 + 8, 0)
      self.help.title = t
    end
  end
  -- The explanation behind a "?" after the centred title.
  function f:SetHelp(helpText)
    self.help = self.help or UI.HelpIcon(self)
    self.help:SetHelp(self.title:GetText(), helpText)
    self:Set(self.title:GetText(), self.sub:IsShown() and self.sub:GetText() or nil)
  end
  f:Set(text, sub)
  return f
end

-- One-line text box (the game's input box). onEnter(text) runs on Enter.
function UI.EditBox(parent, width, maxLetters, placeholder, onEnter)
  local box = CreateFrame("Frame", nil, parent)
  box:SetSize(width, 26)
  local eb = CreateFrame("EditBox", nil, box, "InputBoxTemplate")
  eb:SetPoint("TOPLEFT", 6, 0); eb:SetPoint("BOTTOMRIGHT", 0, 0)
  eb:SetFont(Theme.FONT_BODY, 13, "")
  eb:SetAutoFocus(false)
  eb:SetMaxLetters(maxLetters or 48)
  -- The game's input box is dark: light text on it (dark ink could not be read while typing; seen in game).
  Theme:TextColor(eb, "chipText")
  -- The selected part (the rest of a name filled in as you type) in the list's gold: the game's grey hardly showed on
  -- the dark box (check of 6 Nov 2026, 17:50).
  eb:SetHighlightColor(1, 0.82, 0.4, 0.35)
  -- On the edit box itself, above the box's art (on the holder it was drawn under it and cut off; seen in game).
  local ph = UI.Text(eb, 13, "muted", "body")
  ph:SetDrawLayer("OVERLAY")
  ph:SetPoint("LEFT", box, "LEFT", 8, 0)
  ph:SetText(placeholder or "")
  ph:SetAlpha(0.75)
  local function update() ph:SetShown((eb:GetText() or "") == "") end
  eb:SetScript("OnTextChanged", update)
  eb:SetScript("OnEscapePressed", function() eb:ClearFocus() end)
  eb:SetScript("OnEnterPressed", function() eb:ClearFocus(); if onEnter then onEnter(eb:GetText() or "") end end)
  box.edit = eb
  function box:GetText() return eb:GetText() or "" end
  function box:SetText(t) eb:SetText(t or ""); update() end
  update()
  return box
end

-- Suggestions under an EditBox while it has focus. source(text) returns { { text, sub, online }, ... };
-- onPick(entry) when one is clicked or taken. Rows are made at once (never during combat). The list belongs to the
-- window, not to the (scrolling) page, so it is never cut off.
-- Like the game's mail box (the owner, 6 Nov 2026: "only type the first characters, then a list pops up"): as you
-- type, the rest of the first name is filled in, highlighted, so typing on replaces it; Tab or Enter takes it (Enter
-- then does not send yet), Escape takes it back; the arrow keys move through the list.
function UI.Autocomplete(box, width, source, onPick, rows)
  local owner = ns.Window.frame or box
  local list = UI.Card(owner, "gold")
  list.bgRole = "page1"
  list:Paint()
  list:SetPoint("TOPLEFT", box, "BOTTOMLEFT", 0, -2)
  list:SetWidth(width)
  list:SetFrameLevel(owner:GetFrameLevel() + 100)
  list:Hide()
  list.rows, list.entries, list.typed = {}, {}, ""
  local eb = box.edit
  for i = 1, rows or 8 do
    local r = CreateFrame("Button", nil, list)
    r:SetSize(width - 8, 22)
    r:SetPoint("TOPLEFT", 4, -4 - (i - 1) * 22)
    r.chosen = r:CreateTexture(nil, "BACKGROUND")
    r.chosen:SetAllPoints(); r.chosen:SetColorTexture(1, 0.82, 0.4, 0.28); r.chosen:Hide()
    r.dot = r:CreateTexture(nil, "ARTWORK")
    r.dot:SetSize(8, 8); r.dot:SetPoint("LEFT", 4, 0); r.dot:SetTexture(ns.WHITE)
    r.name = UI.Text(r, 13, "ink")
    r.name:SetPoint("LEFT", 18, 0)
    r.sub = UI.Text(r, 11, "ink2", "body", "RIGHT")
    r.sub:SetPoint("RIGHT", -4, 0)
    local hl = r:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints(); hl:SetColorTexture(1, 0.9, 0.6, 0.2)
    r:SetScript("OnClick", function() list.pending = nil; list:Hide(); onPick(r.entry) end)
    list.rows[i] = r
  end
  local function mark()
    for i, r in ipairs(list.rows) do r.chosen:SetShown(i == list.sel) end
  end
  -- The name e in the box, the part not typed yet highlighted after the cursor; the game's soft list click when the
  -- name in the box changes (list.shown: the one filled in now).
  local function fill(e)
    if e.text ~= list.shown then ns.Sound("fill"); list.shown = e.text end
    local typed = list.typed
    local same = e.text:sub(1, #typed):lower() == typed:lower()
    eb:SetText(e.text) -- in its own capitals, like the mail box
    eb:HighlightText(same and #typed or 0, -1)
    eb:SetCursorPosition(same and #typed or #e.text)
    list.pending = (e.text:lower() ~= typed:lower()) and e or nil
  end
  -- Takes the filled-in name: the whole name in the box, the list closed.
  local function take()
    local e = list.pending
    list.pending, list.sel = nil, nil
    list:Hide()
    eb:HighlightText(0, 0)
    eb:SetCursorPosition(#e.text)
    onPick(e)
  end
  function list:Update(typing)
    local text = box:GetText()
    local grew = typing and #text > #self.typed
    if typing or self.typed == "" then self.typed = text end
    self.pending, self.sel = nil, nil
    self.entries = source(self.typed)
    local n = math.min(#self.entries, #self.rows)
    for i, r in ipairs(self.rows) do
      local e = self.entries[i]
      r:SetShown(e ~= nil)
      if e then
        r.entry = e
        -- e.icon: a class token, its round icon before the name (U65: the class reads without the colour).
        local icon = e.icon and ns.ClassIconMarkup(e.icon, 14) or ""
        r.name:SetText((icon ~= "" and icon .. " " or "") .. (e.hex and ("|cff" .. e.hex .. e.text .. "|r") or e.text))
        r.sub:SetText(e.sub or "")
        r.dot:SetVertexColor(e.online and 0.25 or 0.5, e.online and 0.8 or 0.5, e.online and 0.3 or 0.5, 1)
      end
    end
    mark()
    self:SetHeight(n * 22 + 8)
    self:SetShown(n > 0 and eb:HasFocus())
    -- Only while letters are added: after a Backspace the name is not filled in again.
    local first = self.entries[1]
    if grew and first and self.typed ~= "" and first.text:sub(1, #self.typed):lower() == self.typed:lower() then
      self.sel = 1; mark()
      fill(first)
    else
      self.shown = nil
    end
  end
  eb:HookScript("OnEditFocusGained", function() list.typed = box:GetText(); list:Update(false) end)
  eb:HookScript("OnTextChanged", function(_, user) if user then list:Update(true) end end)
  eb:HookScript("OnEditFocusLost", function() C_Timer.After(0.2, function() list:Hide() end) end)
  eb:SetScript("OnArrowPressed", function(_, key)
    if not list:IsShown() or (key ~= "UP" and key ~= "DOWN") then return end
    local n = math.min(#list.entries, #list.rows)
    if n == 0 then return end
    list.sel = ((list.sel or (key == "DOWN" and 0 or 1)) + (key == "DOWN" and 1 or -1) - 1) % n + 1
    mark()
    fill(list.entries[list.sel])
  end)
  eb:SetScript("OnTabPressed", function() if list.pending then take() end end)
  local enter, escape = eb:GetScript("OnEnterPressed"), eb:GetScript("OnEscapePressed")
  eb:SetScript("OnEnterPressed", function(self, ...)
    if list.pending then take() return end
    if enter then enter(self, ...) end
  end)
  eb:SetScript("OnEscapePressed", function(self, ...)
    if list.pending then
      eb:SetText(list.typed); eb:SetCursorPosition(#list.typed)
      list.pending, list.sel = nil, nil
      list:Hide()
      return
    end
    if escape then escape(self, ...) end
  end)
  box:HookScript("OnHide", function() list:Hide() end)
  return list
end

-- The invite box of the Adventurers page and Manage (one, so a change reaches both; ponytail audit, 6 Nov 2026): the
-- name box with names filled in as you type, Send invite, Invite as a Friend of the fellowship (SPEC §1.1) and the share
-- window for friends without the addon (M25). Fills pf.invite, pf.suggest, pf.send, pf.asFriend and pf.share; the
-- page places them.
function UI.InviteBox(pf, parent, boxW, checkW)
  local L, F = ns.L, ns.Fellowship
  local function send()
    if F:Invite(pf.invite:GetText(), pf.asFriendOn) == "sent" then
      pf.invite:SetText(""); pf.asFriendOn = nil; pf.asFriend:Refresh(); ns.Window:Refresh()
    end
  end
  pf.invite = UI.EditBox(parent, boxW, 48, L.INVITE_NAME, send)
  -- Friends, Battle.net friends, guild members and the game's own names whose name starts with what is typed; online
  -- ones in their class colour, with the level where the game's lists give it (the owner, 6 Nov 2026).
  pf.suggest = UI.Autocomplete(pf.invite, boxW, function(text)
    local f, out = F:Current(), {}
    local skip = function(name) return f ~= nil and (f.members[name] ~= nil or f.invites[name] ~= nil) end
    local light = ns.Theme:Current().light
    for _, e in ipairs(ns.Friends:Suggest(text, skip, 8)) do
      local src = ns.Friends:SourceText(e)
      out[#out + 1] = { text = ns.Display(e.name), sub = e.level and L.SRC_WITH_LEVEL:format(e.level, src) or src,
        online = e.online, hex = e.online and ns.ClassHex(e.class, light) or nil, icon = e.online and e.class or nil }
    end
    return out
  end, function(e) pf.invite:SetText(e.text) end)
  pf.invite.edit:HookScript("OnEditFocusGained", function() ns.Friends:Request() end)
  pf.send = UI.TextButton(parent, L.SEND_INVITE, send, "primary", 13)
  pf.asFriend = UI.LabeledCheck(parent, checkW, L.INVITE_AS_FRIEND, L.INVITE_AS_FRIEND_TIP,
    function() return pf.asFriendOn end, function(on) pf.asFriendOn = on or nil end)
  pf.share = UI.TextButton(parent, L.SHARE_ADDON, function() ns.Share:Open(pf.invite:GetText()) end, "plain", 12)
end

-- Role icons from the game's group finder (Tank, Healer, DPS).
local ROLE_TC = { Tank = { 0, 19 / 64, 22 / 64, 41 / 64 }, Healer = { 20 / 64, 39 / 64, 1 / 64, 20 / 64 }, DPS = { 20 / 64, 39 / 64, 22 / 64, 41 / 64 } }
function UI.RoleIcon(parent, size)
  local t = parent:CreateTexture(nil, "ARTWORK")
  t:SetSize(size, size)
  t:SetTexture("Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES")
  return t
end
function UI.SetRole(tex, role)
  local tc = ROLE_TC[role]
  if tc then tex:SetTexCoord(tc[1], tc[2], tc[3], tc[4]); tex:Show() else tex:Hide() end
end

-- An emblem (a game icon, see ns.Emblems) in a thin gold frame. Returns an object with :Set(key) (nil hides it).
function UI.Emblem(parent, size, layer)
  local e = {}
  local holder = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  holder:SetSize(size, size)
  holder:SetBackdrop({ edgeFile = ns.WHITE, edgeSize = 1 })
  holder:SetBackdropBorderColor(0.85, 0.69, 0.38, 0.9)
  e.frame = holder
  e.icon = holder:CreateTexture(nil, layer or "ARTWORK")
  e.icon:SetPoint("TOPLEFT", 1, -1); e.icon:SetPoint("BOTTOMRIGHT", -1, 1)
  e.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  function e:Set(key)
    local ok = key ~= nil and ns.Emblems:Has(key)
    holder:SetShown(ok)
    if not ok then return end
    -- Our own art (heraldry, a picture crest): no frame line.
    local own = ns.Emblems:Own(key)
    self.icon:SetTexture(ns.Emblems:Texture(key))
    self.icon:SetTexCoord(ns.Emblems:Coords(key))
    holder:SetBackdropBorderColor(0.85, 0.69, 0.38, own and 0 or 0.9)
  end
  return e
end

-- A Companion's class crest: the class icon (the game's class circles) inside the medallion ring. Shown where their
-- 3D model is not loaded yet (UI/Models.lua). :Set(class token).
function UI.ClassCrest(parent, size)
  local c = CreateFrame("Frame", nil, parent)
  c:SetSize(size, size)
  c.icon = UI.Round(c, "ARTWORK", math.floor(size * 0.6))
  c.icon:SetPoint("CENTER")
  c.ring = c:CreateTexture(nil, "OVERLAY")
  c.ring:SetAllPoints()
  c.ring:SetShown(c.ring:SetTexture(ns.MEDIA .. "MedallionRing") == true)
  function c:Set(token)
    if not ns.SetClassIcon(self.icon, token) then UI.SetIcon(self.icon, ns.ICONS.heroes) end
  end
  return c
end

-- Fellowship crest: a medallion (our art, Media\MedallionRing: a rune ring with four points) around a disc in the
-- banner colour with the emblem; square, as wide as it is high. Without the ring file: a shield in the banner colour
-- with the emblem. A picture crest shows on its own instead, larger and on a transparent background.
local RING_DISC, RING_EMBLEM, RING_ICON = 0.62, 0.46, 0.38 -- shares of the medallion: disc, heraldry, game icon
function UI.Crest(parent, w, h)
  local c = UI.Box(parent, 2, nil, nil, "gold", 1)
  c:SetSize(w, h)
  c.fill = c:CreateTexture(nil, "BACKGROUND")
  c.fill:SetPoint("TOPLEFT", 2, -2); c.fill:SetPoint("BOTTOMRIGHT", -2, 2)
  local small = math.floor(math.min(w, h) * 0.72)
  c.emblem = UI.Emblem(c, small)
  c.emblem.frame:SetPoint("CENTER")
  -- The medallion: the disc under the emblem, the ring on a layer above it.
  local s = math.max(w, h)
  c.top = CreateFrame("Frame", nil, c)
  c.top:SetAllPoints()
  c.top:SetFrameLevel(c.emblem.frame:GetFrameLevel() + 2)
  c.ring = c.top:CreateTexture(nil, "OVERLAY")
  c.ring:SetSize(s, s); c.ring:SetPoint("CENTER")
  c.medal = c.ring:SetTexture(ns.MEDIA .. "MedallionRing") == true
  c.ring:SetShown(c.medal)
  c.disc = UI.Round(c, "BACKGROUND", math.floor(s * RING_DISC))
  c.disc:SetPoint("CENTER")
  c.disc:SetShown(c.medal)
  if c.medal then c:SetSize(s, s) end
  -- The square gold frame only for the plain shield; a theme change painted it back around medallions and pictures
  -- (a square around the tracker's crest after the tour switched themes; seen in game).
  local function frame(self) self:SetBackdropBorderColor(Theme:RGBA("gold", self.round and 0 or 1)) end
  Theme:Register(function() frame(c) end)
  function c:Set(color, emblem)
    local pic = emblem ~= nil and ns.Emblems:Picture(emblem) ~= nil and ns.Emblems:Has(emblem)
    local medal = self.medal and not pic
    self.fill:SetShown(not pic and not medal)
    self.disc:SetShown(medal); self.ring:SetShown(medal)
    self.round = pic or medal
    frame(self)
    local size = small
    if pic then size = math.floor(s * 1.5)
    elseif medal then size = math.floor(s * (ns.Emblems:Heraldry(emblem) and RING_EMBLEM or RING_ICON)) end
    self.emblem.frame:SetSize(size, size)
    local r, g, b = ns.Hex(color or ns.BANNERS[1][2])
    UI.SetGradient(self.fill, "VERTICAL", { r * 0.45, g * 0.45, b * 0.45, 1 }, { r, g, b, 1 })
    UI.SetGradient(self.disc, "VERTICAL", { r * 0.45, g * 0.45, b * 0.45, 1 }, { r, g, b, 1 })
    self.emblem:Set(emblem)
  end
  return c
end

-- The six banner colours. The chosen one has a gold frame and a check mark. pick(hex) when one is clicked.
function UI.Swatches(parent, getValue, pick)
  local row = CreateFrame("Frame", nil, parent)
  row.buttons = {}
  for i, b in ipairs(ns.BANNERS) do
    local s = CreateFrame("Button", nil, row, "BackdropTemplate")
    s:SetSize(32, 32)
    s:SetPoint("LEFT", (i - 1) * 38, 0)
    s:SetBackdrop(CARD)
    s:SetBackdropColor(ns.Hex(b[2]))
    s.check = UI.Check(s, 20)
    s.check:SetPoint("CENTER")
    s.value = b[2]
    s:SetScript("OnClick", function() pick(b[2]); row:Refresh() end)
    s:SetScript("OnEnter", function() GameTooltip:SetOwner(s, "ANCHOR_TOP"); GameTooltip:SetText(ns.L[b[1]]); GameTooltip:Show() end)
    s:SetScript("OnLeave", function() GameTooltip:Hide() end)
    row.buttons[i] = s
  end
  row:SetSize(#ns.BANNERS * 38 - 6, 32)
  function row:Refresh()
    local v = getValue()
    for _, s in ipairs(self.buttons) do
      local on = s.value == v
      s.check:SetShown(on)
      s:SetBackdropBorderColor(Theme:RGBA(on and "goldText" or "line"))
    end
  end
  Theme:Register(function() row:Refresh() end)
  return row
end

-- Every emblem to choose from (Emblems:Sections: crests, heraldry or the game's icons) as a scrolling grid of cells in
-- the banner colour, the chosen one framed in gold: on the right page of Create a Fellowship's first step (28 Oct
-- 2026) and on Manage. onPick(n) on a click; :Refresh(color, chosen). Build it out of combat: it
-- probes the emblem files once.
function UI.EmblemGrid(parent, width, onPick)
  local g = UI.Scroll(parent)
  g.cells = {}
  local E = ns.Emblems
  local per = math.max(1, math.floor((width + 4) / 52))
  local y, placed = 0, {}
  for _, sec in ipairs(E:Sections(E:Scan())) do
    if #sec[2] > 0 then
      local head = UI.Text(g.child, 13, "ink2", "title")
      head:SetPoint("TOPLEFT", 0, -y)
      head:SetText(sec[1])
      y = y + 20
      for k, n in ipairs(sec[2]) do
        placed[#placed + 1] = { n = n, x = ((k - 1) % per) * 52, y = y + math.floor((k - 1) / per) * 52 }
      end
      y = y + math.ceil(#sec[2] / per) * 52 + 8
    end
  end
  for i, at in ipairs(placed) do
    local cell = UI.Card(g.child, "line", "Button")
    cell:SetSize(48, 48)
    cell:SetPoint("TOPLEFT", at.x, -at.y)
    cell.fill = cell:CreateTexture(nil, "ARTWORK")
    cell.fill:SetPoint("TOPLEFT", 4, -4); cell.fill:SetPoint("BOTTOMRIGHT", -4, 4)
    cell.emblem = UI.Emblem(cell, 34, "OVERLAY")
    cell.emblem.frame:SetPoint("CENTER")
    cell.emblem.frame:SetFrameLevel(cell:GetFrameLevel() + 1)
    cell.emblem:Set(at.n)
    cell.n = at.n
    cell:SetScript("OnClick", function() onPick(at.n) end)
    g.cells[i] = cell
  end
  g.height = y
  g:SetContentHeight(y)
  function g:Refresh(color, current)
    local r, gr, b = ns.Hex(color or ns.BANNERS[1][2])
    for _, cell in ipairs(self.cells) do
      cell.fill:SetColorTexture(r * 0.8, gr * 0.8, b * 0.8, 1)
      cell.fill:SetShown(E:Picture(cell.n) == nil) -- a picture crest is shown on its own
      cell:SetSelected(cell.n == current)
    end
  end
  return g
end

-- A progress bar, the same everywhere in the book (the visual pass, 28 Oct 2026; there were four flat ones): a dark
-- inset track with a thin edge (gold for the large ones), the fill with a highlight line along its top and a bright
-- spark at its end, an optional pale band ahead of it (rested XP), notches, and pips for small goals.
--   :Set(width, value, ahead)   value and ahead as fractions (0-1); ahead is drawn after the fill
--   :SetColor(c)                a colour role or hex for the fill
--   :SetNotches(list)           fractions where a thin notch is drawn (levels, floor and cap)
--   :SetPips(n)                 n equal pips instead of one fill (a quest's 3 of 7); nil or 0: a fill again
-- The fill glides to a new value (about a third of a second); with Reduce effects it jumps.
UI.BAR_GLIDE = 0.3
UI.BAR_PIPS_MAX = 20
function UI.Bar(parent, height, gold)
  local b = UI.Box(parent, 1, "2A1C10", 0.82, gold and "B8903C" or "1A1008", 1)
  b:SetHeight(height)
  local inner = CreateFrame("Frame", nil, b)
  inner:SetPoint("TOPLEFT", 1, -1); inner:SetPoint("BOTTOMRIGHT", -1, 1)
  b.inner = inner
  -- The inset: a dark line along the top of the track.
  local shade = UI.Solid(inner, "BACKGROUND", "000000", 0.45, 1)
  shade:SetHeight(1); shade:SetPoint("TOPLEFT"); shade:SetPoint("TOPRIGHT")
  b.ahead = inner:CreateTexture(nil, "BORDER"); b.ahead:SetTexture(ns.WHITE)
  b.ahead:SetPoint("TOP"); b.ahead:SetPoint("BOTTOM")
  b.fill = inner:CreateTexture(nil, "ARTWORK"); b.fill:SetTexture(ns.WHITE)
  b.fill:SetPoint("TOPLEFT"); b.fill:SetPoint("BOTTOMLEFT")
  b.shine = inner:CreateTexture(nil, "ARTWORK", nil, 2); b.shine:SetTexture(ns.WHITE)
  b.shine:SetVertexColor(1, 1, 1, 0.3)
  b.shine:SetPoint("TOPLEFT", 0, -1); b.shine:SetHeight(math.max(1, math.floor((height - 2) / 3)))
  b.spark = inner:CreateTexture(nil, "OVERLAY"); b.spark:SetTexture(ns.WHITE)
  b.spark:SetVertexColor(1, 0.95, 0.72, 0.95); b.spark:SetWidth(2)
  b.spark:SetPoint("TOP"); b.spark:SetPoint("BOTTOM")
  b.notches, b.pips = {}, {}
  b.value, b.drawn, b.aheadV, b.width, b.color = 0, 0, 0, 100, "E2B23C"

  -- Draws the fill at fraction v (the glide calls this every frame).
  function b:Draw(v)
    self.drawn = v
    local w = math.max(0, self.width - 2)
    local fw = w * ns.Clamp(v, 0, 1)
    local pips = self.pipN and self.pipN > 0
    self.fill:SetShown(not pips and fw >= 1)
    self.shine:SetShown(not pips and fw >= 1)
    self.spark:SetShown(not pips and fw >= 1 and v < 1)
    if not pips and fw >= 1 then
      self.fill:SetWidth(fw); self.shine:SetWidth(fw)
      self.spark:ClearAllPoints(); self.spark:SetPoint("TOP", self.inner, "TOPLEFT", fw, 0)
      self.spark:SetPoint("BOTTOM", self.inner, "BOTTOMLEFT", fw, 0)
    end
    local aw = w * ns.Clamp(self.aheadV, 0, 1 - ns.Clamp(v, 0, 1))
    self.ahead:SetShown(not pips and aw >= 1)
    if not pips and aw >= 1 then
      self.ahead:ClearAllPoints()
      self.ahead:SetPoint("TOPLEFT", self.inner, "TOPLEFT", fw, 0); self.ahead:SetPoint("BOTTOMLEFT", self.inner, "BOTTOMLEFT", fw, 0)
      self.ahead:SetWidth(aw)
    end
  end

  function b:SetColor(c)
    self.color = c
    -- (After a theme change the box paints its track again: pips keep it clear.)
    if self.pipN then self:SetBackdropColor(0, 0, 0, 0); self:SetBackdropBorderColor(0, 0, 0, 0) end
    self.fill:SetColorTexture(Theme:RGBA(c))
    self.ahead:SetColorTexture(Theme:RGBA("4D8ECB", 0.4))
    for i, p in ipairs(self.pips) do p.fill:SetColorTexture(Theme:RGBA(c)); p.fill:SetShown(i <= (self.pipHave or 0)) end
  end

  function b:Set(width, value, ahead)
    self.width = width or self.width
    self:SetWidth(self.width)
    self.aheadV = ahead or 0
    local to = ns.Clamp(value or 0, 0, 1)
    self.value = to
    if self.pipN and self.pipN > 0 then
      self:LayoutPips(math.floor(to * self.pipN + 0.5))
      return self:Draw(to)
    end
    -- Glide from what is drawn now, only while it is on the screen and Reduce effects is off.
    local glide = UI.BAR_GLIDE > 0 and self:IsVisible() and not (ns.Settings and ns.Settings:Get("reduce"))
      and math.abs(to - self.drawn) > 0.002
    if not glide then self:SetScript("OnUpdate", nil); return self:Draw(to) end
    local from, t = self.drawn, 0
    self:SetScript("OnUpdate", function(s, elapsed)
      t = t + (elapsed or 0)
      local k = math.min(1, t / UI.BAR_GLIDE)
      k = 1 - (1 - k) * (1 - k) * (1 - k) -- ease out
      s:Draw(from + (to - from) * k)
      if k >= 1 then s:SetScript("OnUpdate", nil) end
    end)
  end

  function b:SetNotches(list)
    local w = math.max(0, self.width - 2)
    for i, x in ipairs(list or {}) do
      local n = self.notches[i]
      if not n then
        if ns.Combat:InCombat() then list = { unpack(list, 1, i - 1) } break end -- none made during combat
        n = self.inner:CreateTexture(nil, "OVERLAY", nil, 1); n:SetTexture(ns.WHITE); n:SetWidth(1)
        self.notches[i] = n
      end
      n:SetVertexColor(0, 0, 0, 0.45)
      n:ClearAllPoints()
      n:SetPoint("TOP", self.inner, "TOPLEFT", w * ns.Clamp(x, 0, 1), 0); n:SetPoint("BOTTOM", self.inner, "BOTTOMLEFT", w * ns.Clamp(x, 0, 1), 0)
      n:Show()
    end
    for i = #(list or {}) + 1, #self.notches do self.notches[i]:Hide() end
  end

  -- Pips: the track's frame gives way to n small boxes, the first `have` filled.
  function b:SetPips(n)
    self.pipN = (n and n > 0 and n <= UI.BAR_PIPS_MAX) and n or nil
    -- Pips not made yet are not made during combat: a plain fill until then.
    if self.pipN and #self.pips < self.pipN and ns.Combat:InCombat() then self.pipN = nil end
    local on = self.pipN ~= nil
    self:SetBackdropColor(Theme:RGBA("2A1C10", on and 0 or 0.82))
    self:SetBackdropBorderColor(Theme:RGBA(gold and "B8903C" or "1A1008", on and 0 or 1))
    shade:SetShown(not on)
    if not on then for _, p in ipairs(self.pips) do p:Hide() end end
  end

  function b:LayoutPips(have)
    self.pipHave = have
    local n, gap = self.pipN, 3
    local pw = (self.width - gap * (n - 1)) / n
    for i = 1, n do
      local p = self.pips[i]
      if not p then
        p = UI.Box(self, 1, "2A1C10", 0.82, "1A1008", 1)
        p.fill = p:CreateTexture(nil, "ARTWORK"); p.fill:SetTexture(ns.WHITE)
        p.fill:SetPoint("TOPLEFT", 1, -1); p.fill:SetPoint("BOTTOMRIGHT", -1, 1)
        p.shine = p:CreateTexture(nil, "ARTWORK", nil, 2); p.shine:SetTexture(ns.WHITE); p.shine:SetVertexColor(1, 1, 1, 0.3)
        p.shine:SetPoint("TOPLEFT", 1, -1); p.shine:SetPoint("TOPRIGHT", -1, -1); p.shine:SetHeight(math.max(1, math.floor((height - 2) / 3)))
        self.pips[i] = p
      end
      p:SetSize(math.max(2, pw), height)
      p:ClearAllPoints(); p:SetPoint("TOPLEFT", self, "TOPLEFT", (i - 1) * (pw + gap), 0)
      p.fill:SetColorTexture(Theme:RGBA(self.color))
      p.fill:SetShown(i <= have); p.shine:SetShown(i <= have)
      p:Show()
    end
    for i = n + 1, #self.pips do self.pips[i]:Hide() end
  end

  b:SetColor(b.color)
  Theme:Register(function() b:SetColor(b.color) end)
  return b
end

-- A small state mark (cleared, open, locked, ...) from ns.MARKS. :SetMark(kind) (nil hides it).
function UI.Mark(parent, size)
  local t = parent:CreateTexture(nil, "OVERLAY")
  t:SetSize(size or 14, size or 14)
  function t:SetMark(kind)
    local path = kind and ns.MARKS[kind]
    self:SetShown(path ~= nil)
    if path then self:SetTexture(path) end
  end
  return t
end

-- The presence mark (SPEC §4.8, Hero:Presence): a round dot in the friends list's colours with a dark rim, so it
-- reads on parchment and at night; "quiet" (online in the game, addon not heard) is a green ring. :Set(kind) (nil
-- hides it). UI.PRESENCE_TEXT colours the word beside it; UI.PRESENCE_LC is the word inside a line of text.
UI.PRESENCE = { online = "3E9A52", quiet = "3E9A52", afk = "E0A526", offline = "C0392B", away = "9A9285" }
UI.PRESENCE_TEXT = { online = "3E9A52", quiet = "3E9A52", afk = "A87A12", offline = "B0321E", away = "ink2" }
UI.PRESENCE_LC = { online = "ONLINE_LC", quiet = "ONLINE_LC", afk = "AFK_LC", offline = "OFFLINE_LC", away = "AWAY_LC" }
function UI.Presence(parent, size)
  size = size or 10
  local f = CreateFrame("Frame", nil, parent)
  f:SetSize(size, size)
  f.rim = UI.Round(f, "ARTWORK", size, 1)
  f.rim:SetPoint("CENTER")
  f.rim:SetColorTexture(0.08, 0.06, 0.04, 0.55)
  f.dot = UI.Round(f, "ARTWORK", size - 2, 2)
  f.dot:SetPoint("CENTER")
  f.hole = UI.Round(f, "ARTWORK", math.max(2, size - 6), 3)
  f.hole:SetPoint("CENTER")
  f.hole:SetColorTexture(0.08, 0.06, 0.04, 0.85)
  function f:Set(kind)
    self.kind = kind
    self:SetShown(UI.PRESENCE[kind] ~= nil)
    if not UI.PRESENCE[kind] then return end
    self.dot:SetColorTexture(Theme:RGBA(UI.PRESENCE[kind]))
    self.hole:SetShown(kind == "quiet")
  end
  return f
end

-- Crop a picture so it covers a w×h area. aspect = picture width / height; focusY = which part stays in view.
-- box = { left, right, top, bottom }: the part of the file that is the picture (default the whole file).
function UI.Cover(tex, aspect, w, h, focusY, box)
  local l, r, t, b = 0, 1, 0, 1
  if box then l, r, t, b = box[1], box[2], box[3], box[4] end
  local area = w / h
  if area > aspect then
    local show = aspect / area
    local top = ns.Clamp((focusY or 0.5) - show / 2, 0, 1 - show)
    tex:SetTexCoord(l, r, t + (b - t) * top, t + (b - t) * (top + show))
  else
    local show = area / aspect
    local left = (1 - show) / 2
    tex:SetTexCoord(l + (r - l) * left, l + (r - l) * (left + show), t, b)
  end
end

-- Our dialog frame (Media\DialogFrame: leather with gold corners around parchment) behind a box, reaching out
-- past its edges so what the box holds keeps its place. Nine pieces of one picture; tinted like the paper in the
-- Night theme. Returns false when the file is missing (the box keeps its own look).
-- opts (the book's window): { on = a frame to draw on (above the box's children), corner, out, border = true (only
-- the frame: no parchment middle, and the box keeps its own background), file (another picture of the same shape:
-- Media\WindowFrame, the frame without its parchment) }.
local FRAME_CUT, FRAME_CORNER, FRAME_OUT = 40 / 256, 34, 14
function UI.DialogFrame(box, opts)
  opts = opts or {}
  local on = opts.on or box
  local layer = opts.on and "ARTWORK" or "BACKGROUND"
  local file = ns.MEDIA .. (opts.file or "DialogFrame")
  local probe = on:CreateTexture(nil, layer, nil, 1)
  if not probe:SetTexture(file) then probe:Hide(); return false end
  local c = FRAME_CUT
  local cuts = { { 0, c }, { c, 1 - c }, { 1 - c, 1 } }
  local p = {}
  for row = 1, 3 do
    for col = 1, 3 do
      local t = (row == 1 and col == 1) and probe or on:CreateTexture(nil, layer, nil, 1)
      t:SetTexture(file)
      t:SetTexCoord(cuts[col][1], cuts[col][2], cuts[row][1], cuts[row][2])
      p[row * 10 + col] = t
    end
  end
  local o, k = opts.out or FRAME_OUT, opts.corner or FRAME_CORNER
  for _, corner in ipairs({ { 11, "TOPLEFT", -o, o }, { 13, "TOPRIGHT", o, o }, { 31, "BOTTOMLEFT", -o, -o },
    { 33, "BOTTOMRIGHT", o, -o } }) do
    local t = p[corner[1]]
    t:SetSize(k, k); t:SetPoint(corner[2], box, corner[2], corner[3], corner[4])
  end
  local function span(t, a, pa, b, pb) t:SetPoint("TOPLEFT", a, pa); t:SetPoint("BOTTOMRIGHT", b, pb) end
  span(p[12], p[11], "TOPRIGHT", p[13], "BOTTOMLEFT"); span(p[32], p[31], "TOPRIGHT", p[33], "BOTTOMLEFT")
  span(p[21], p[11], "BOTTOMLEFT", p[31], "TOPRIGHT"); span(p[23], p[13], "BOTTOMLEFT", p[33], "TOPRIGHT")
  span(p[22], p[11], "BOTTOMRIGHT", p[33], "TOPLEFT")
  Theme:Register(function()
    local r, g, b = unpack(Theme.PAPER_TINT[Theme:Key()] or Theme.PAPER_TINT.journal)
    for _, t in pairs(p) do t:SetVertexColor(r, g, b) end
  end)
  box.framePieces = p
  if opts.border then p[22]:Hide(); return true end
  -- The box's own background and border give way to the frame.
  function box:Paint() self:SetBackdropColor(0, 0, 0, 0); self:SetBackdropBorderColor(0, 0, 0, 0) end
  box:Paint()
  return true
end

-- A section header written like a heading in a book: dark ink on the page with a thin gold rule under it and a
-- small gold diamond at its start. :SetText(t). (Bands behind the heading, the guide's paper band, a leather
-- gradient and leather art, all looked out of place on the page; seen in game.)
function UI.SectionHeader(parent, width)
  local f = CreateFrame("Frame", nil, parent)
  f:SetSize(width, 29)
  local rule = UI.Solid(f, "BORDER", "gold", 0.75)
  rule:SetHeight(1); rule:SetPoint("BOTTOMLEFT", 0, 3); rule:SetPoint("BOTTOMRIGHT", 0, 3)
  local fade = UI.Solid(f, "BORDER", "line", 0.5)
  fade:SetHeight(1); fade:SetPoint("TOPLEFT", rule, "BOTTOMLEFT", 0, -1); fade:SetPoint("TOPRIGHT", rule, "BOTTOMRIGHT", 0, -1)
  local gem = UI.Solid(f, "ARTWORK", "gold", 1)
  gem:SetSize(5, 5); gem:SetPoint("CENTER", rule, "LEFT", 0, 0); gem:SetRotation(math.rad(45))
  f.text = UI.Text(f, 15, "ink", "title")
  f.text:SetPoint("LEFT", 0, 1)
  function f:SetText(t) self.text:SetText(t) end
  -- The explanation behind a "?" after the title instead of a paragraph under it.
  function f:SetHelp(text)
    self.help = self.help or UI.HelpIcon(self)
    self.help:ClearAllPoints(); self.help:SetPoint("LEFT", self.text, "RIGHT", 6, 0)
    self.help:SetHelp(self.text:GetText(), text)
  end
  return f
end

-- A section header that folds what is under it (the game's plus and minus buttons before the title, as on the
-- Settings page): a click on the icon or the title calls onClick; :SetOpen(open) shows which.
UI.FOLD_ICON = { [true] = "Interface\\Buttons\\UI-PlusButton-Up", [false] = "Interface\\Buttons\\UI-MinusButton-Up" }
function UI.FoldHeader(parent, width, onClick)
  local h = UI.SectionHeader(parent, width)
  h.text:ClearAllPoints(); h.text:SetPoint("LEFT", 20, 1)
  h.icon = h:CreateTexture(nil, "ARTWORK")
  h.icon:SetSize(16, 16); h.icon:SetPoint("LEFT", 0, 1)
  h.click = CreateFrame("Button", nil, h)
  h.click:SetAllPoints()
  h.click:SetScript("OnClick", onClick)
  function h:SetOpen(open) self.open = open == true; self.icon:SetTexture(UI.FOLD_ICON[not open]) end
  h:SetOpen(false)
  return h
end
-- The same plus or minus before a link's words (Show who, All chapters; ▾ and ▴ are not in the game's font).
function UI.FoldLabel(text, open) return ("|T%s:14:14|t %s"):format(UI.FOLD_ICON[not open], text) end

-- A small round "?" that explains on mouse-over (long help texts read like a manual on the page; seen in the
-- tour). :SetHelp(title, text).
function UI.HelpIcon(parent)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(16, 16)
  local ring = UI.Round(b, "ARTWORK", 16)
  ring:SetPoint("CENTER"); Theme:Fill(ring, "gold", 0.9)
  local hole = UI.Round(b, "OVERLAY", 13)
  hole:SetPoint("CENTER"); Theme:Fill(hole, "page1", 1)
  local q = UI.Text(b, 11, "ink", "title", "CENTER")
  q:SetPoint("CENTER", 0, 0); q:SetText("?")
  function b:SetHelp(title, text) self.title, self.text = title, text end
  b:SetScript("OnEnter", function()
    GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
    GameTooltip:SetText(b.title or "", 1, 0.82, 0)
    GameTooltip:AddLine(b.text or "", 1, 1, 1, true)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  return b
end

-- The level track (GLOSSARY.md; Chapter and Adventurers pages): the chapter's line from its floor to its cap with
-- every counted Adventurer on it, a notch per level, each marker their class's face. Adventurers at one level share
-- one marker with their number on a badge,
-- and a line under the track names them ("22: Brannic, Elyra"): the Overview's old track, a name per dot, was
-- cluttered when many shared a level (the owner, 31 Oct 2026). :Set(f, n, maxLines) returns its height.
-- dark: on a dark picture (the Overview's banner, U158): light lines and words in every theme, a lighter red.
local LT_LINE_Y, LT_TEXT_Y, LT_PAD = 24, 54, 14
function UI.LevelTrack(parent, width, dark)
  local C = dark and { line = "muted", mark = "chipText", text = "chipText", card = "chipText", red = Theme.DARK_LIFT.B0321E }
    or { line = "line", mark = "ink2", text = "ink", card = "card", red = "B0321E" }
  local function lift(fs)
    if dark then fs:SetShadowOffset(1, -1); fs:SetShadowColor(0, 0, 0, 1) end
    return fs
  end
  local t = CreateFrame("Frame", nil, parent)
  t:SetWidth(width)
  t.band = UI.Solid(t, "BORDER", "3E7A3A", dark and 0.5 or 0.22)
  t.band:SetHeight(10)
  t.line = UI.Solid(t, "ARTWORK", C.line, 1)
  t.line:SetHeight(2)
  t.line:SetPoint("TOPLEFT", LT_PAD, -LT_LINE_Y); t.line:SetPoint("TOPRIGHT", -LT_PAD, -LT_LINE_Y)
  t.notches = UI.Pool(function()
    local n = UI.Solid(t, "ARTWORK", C.line, 0.9)
    n:SetSize(1, 6)
    return n
  end)
  t.marks = {}
  for i = 1, 2 do
    local m = UI.Solid(t, "ARTWORK", C.mark, 1)
    m:SetSize(2, 16)
    m.label = lift(UI.Text(t, 11, C.mark, "body", "CENTER"))
    t.marks[i] = m
  end
  t.markers = UI.Pool(function()
    local d = CreateFrame("Frame", nil, t)
    d:SetSize(20, 20)
    d:SetFrameLevel(t:GetFrameLevel() + 2)
    d.ring = UI.Round(d, "ARTWORK", 14)
    d.ring:SetPoint("CENTER")
    d.dot = UI.Round(d, "OVERLAY", 10)
    d.dot:SetPoint("CENTER")
    -- The class's own face (the game's class circles) instead of a dot; several at one level: the first one's, with
    -- how many on a small badge (the owner's pick of 9 Nov 2026: a "3" on a dot said nothing at a glance).
    d.face = d:CreateTexture(nil, "OVERLAY", nil, 1)
    d.face:SetSize(16, 16); d.face:SetPoint("CENTER")
    d.badge = UI.Round(d, "OVERLAY", 13, 2)
    d.badge:SetPoint("CENTER", d, "BOTTOMRIGHT", -2, 3)
    d.n = UI.Text(d, 10, "white", "title", "CENTER")
    d.n:SetDrawLayer("OVERLAY", 7)
    d.n:SetPoint("CENTER", d.badge, "CENTER", 0, 0)
    d.n:SetShadowOffset(1, -1); d.n:SetShadowColor(0, 0, 0, 1)
    -- On the marker, so it goes with it: on the track it stayed behind when fewer levels were left (check, 31 Oct).
    d.lv = lift(UI.Text(d, 11, C.text, "title", "CENTER"))
    d:EnableMouse(true)
    d:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_TOP")
      GameTooltip:SetText(self.tip or "", 1, 1, 1, 1, true)
      GameTooltip:Show()
    end)
    d:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return d
  end)
  -- The room's stop point (U82): a red tick with its level and percent.
  t.stop = UI.Solid(t, "OVERLAY", C.red, 1)
  t.stop:SetSize(3, 18)
  t.stopLabel = lift(UI.Text(t, 11, C.red, "title", "CENTER"))
  t.lines = UI.Pool(function() return lift(UI.WrapText(t, 12, C.text, width, "book")) end)
  t.more = lift(UI.Text(t, 11, C.mark))

  -- stopAt (optional): the level to stop questing at (ns.Room), shown as a red tick.
  function t:Set(f, n, maxLines, stopAt)
    local J, Hr, L = ns.Journey, ns.Hero, ns.L
    local tr = J:TrackLevels(f, n)
    if not tr then self:Hide(); return 0 end
    local light = not dark and Theme:Current().light -- (class colours for a light page, or bright ones on the dark)
    local span = math.max(1, tr.hi - tr.lo)
    local function x(v) return LT_PAD + (v - tr.lo) / span * (width - 2 * LT_PAD) end
    self.band:ClearAllPoints()
    self.band:SetPoint("LEFT", self, "TOPLEFT", x(tr.floor), -LT_LINE_Y - 1)
    self.band:SetWidth(math.max(1, x(tr.cap) - x(tr.floor)))
    -- A notch per level; every fifth when the track spans more than 40 levels (a level-2 newcomer in chapter XV).
    local step = span > 40 and 5 or 1
    local k = 0
    for v = tr.lo, tr.hi, step do
      k = k + 1
      local notch = self.notches:Get(k)
      if notch then
        notch:ClearAllPoints(); notch:SetPoint("TOP", self, "TOPLEFT", x(v), -LT_LINE_Y + 2); notch:Show()
      end
    end
    self.notches:HideFrom(k + 1)
    for i, v in ipairs({ tr.floor, tr.cap }) do
      local m = self.marks[i]
      m:ClearAllPoints(); m:SetPoint("CENTER", self, "TOPLEFT", x(v), -LT_LINE_Y - 1)
      m.label:SetText((i == 1 and L.TRACK_FLOOR or L.TRACK_CAP):format(v))
      m.label:ClearAllPoints(); m.label:SetPoint("TOP", m, "BOTTOM", 0, -2)
      m.label:Show()
    end
    -- Floor and cap close together (a chapter far ahead, the track stretched to reach it): one label between them
    -- ("floor 54 and cap 56" overlapped in the check of 31 Oct 2026).
    local fl, cp = self.marks[1].label, self.marks[2].label
    local labelX = { x(tr.floor), x(tr.cap) }
    if x(tr.cap) - x(tr.floor) < (fl:GetStringWidth() + cp:GetStringWidth()) / 2 + 8 then
      fl:SetText(L.TRACK_BOTH:format(tr.floor, tr.cap))
      fl:ClearAllPoints(); fl:SetPoint("TOP", self, "TOPLEFT", (x(tr.floor) + x(tr.cap)) / 2, -LT_LINE_Y - 12)
      local half = fl:GetStringWidth() / 2
      local cx = ns.Clamp((x(tr.floor) + x(tr.cap)) / 2, half, math.max(half, width - half))
      fl:ClearAllPoints(); fl:SetPoint("TOP", self, "TOPLEFT", cx, -LT_LINE_Y - 12)
      cp:Hide()
      labelX = { cx }
    end
    -- The stop point: under the line with the floor and cap, or above it where it would touch one of their names.
    local stop = stopAt and stopAt > tr.lo and stopAt < tr.hi and stopAt or nil
    self.stop:SetShown(stop ~= nil); self.stopLabel:SetShown(stop ~= nil)
    if stop then
      local sx = x(stop)
      self.stop:ClearAllPoints(); self.stop:SetPoint("CENTER", self, "TOPLEFT", sx, -LT_LINE_Y - 1)
      self.stopLabel:SetText(ns.Room.StopAt(stop, true))
      local w = self.stopLabel:GetStringWidth()
      local cx = ns.Clamp(sx, w / 2, math.max(w / 2, width - w / 2))
      local clash = false
      for i, lx in ipairs(labelX) do
        local lw = self.marks[i].label:GetStringWidth()
        if math.abs(cx - lx) < (w + lw) / 2 + 6 then clash = true end
      end
      self.stopLabel:ClearAllPoints()
      if clash then self.stopLabel:SetPoint("BOTTOM", self, "TOPLEFT", cx, -LT_LINE_Y + 11)
      else self.stopLabel:SetPoint("TOP", self, "TOPLEFT", cx, -LT_LINE_Y - 11) end
    end
    -- One marker per level, lowest first, so a level number that would touch the one before it is left out (the
    -- lines under the track give every level anyway).
    local lastX = -100
    for i = #tr.levels, 1, -1 do
      local e = tr.levels[i]
      local d = self.markers:Get(#tr.levels - i + 1)
      if not d then break end
      local many = #e.names > 1
      local below = e.level < tr.floor
      local _, token = Hr:ClassName(f, e.names[1])
      local hasFace = ns.SetClassIcon(d.face, token)
      d.face:SetShown(hasFace); d.dot:SetShown(not hasFace)
      local big = hasFace or many
      d.ring:SetSize(big and 20 or 14, big and 20 or 14)
      d.dot:SetSize(many and 16 or 10, many and 16 or 10)
      d.ring:SetColorTexture(Theme:RGBA(below and C.red or C.card))
      if many then
        d.dot:SetColorTexture(Theme:RGBA(below and C.red or C.text))
      else
        d.dot:SetColorTexture(ns.Hex(ns.ClassHex(token, light) or "7A6A55"))
      end
      d.badge:SetShown(many)
      d.badge:SetColorTexture(Theme:RGBA(below and C.red or "dark"))
      d.n:SetText(many and #e.names or "")
      local cx = x(e.level)
      d:ClearAllPoints(); d:SetPoint("CENTER", self, "TOPLEFT", cx, -LT_LINE_Y - 1); d:Show()
      d.lv:SetText(e.level)
      d.lv:ClearAllPoints(); d.lv:SetPoint("BOTTOM", d, "TOP", 0, 0)
      d.lv:SetShown(cx - lastX >= 18)
      if d.lv:IsShown() then lastX = cx end
      local short = {}
      for j, name in ipairs(e.names) do short[j] = ns.Short(name) end
      d.tip = L.TRACK_LINE:format(e.level, table.concat(short, ", "))
    end
    self.markers:HideFrom(#tr.levels + 1)
    -- The lines: one per level, highest first, each name in dark ink after its class icon (class colours were faint
    -- on parchment, the warrior's brown above all; U12, 31 Oct 2026).
    local y = LT_TEXT_Y
    -- (maxLines 0: no lines, the names only on hover: the Overview's Where we stand, U139.)
    local shown = math.min(#tr.levels, maxLines or 8)
    if shown > 0 and shown < #tr.levels then shown = shown - 1 end
    for i = 1, shown do
      local e = tr.levels[i]
      local names = {}
      for j, name in ipairs(e.names) do
        local _, token = Hr:ClassName(f, name)
        local icon = ns.ClassIconMarkup(token, 13)
        names[j] = (icon ~= "" and (icon .. " ") or "") .. ns.Short(name)
      end
      local fs = self.lines:Get(i)
      if not fs then break end
      fs:SetText(L.TRACK_LINE:format(e.level, table.concat(names, ", ")))
      fs:ClearAllPoints(); fs:SetPoint("TOPLEFT", 0, -y); fs:Show()
      y = y + fs:GetStringHeight() + 3
    end
    self.lines:HideFrom(shown + 1)
    local rest = 0
    if maxLines ~= 0 then for i = shown + 1, #tr.levels do rest = rest + #tr.levels[i].names end end
    self.more:SetShown(rest > 0)
    if rest > 0 then
      self.more:SetText(L.TRACK_MORE_LOWER:format(rest))
      self.more:ClearAllPoints(); self.more:SetPoint("TOPLEFT", 0, -y)
      y = y + 16
    end
    self:SetHeight(y)
    self:Show()
    return y
  end
  return t
end

-- Where the Companions stand (Chapter and Overview pages): a section per group (below the floor, ready, at the cap,
-- over the cap, away) with its Companions under it; groups with nobody fold into one line at the end.
-- :Set(f, n, stack) places it on a UI.Stack.
function UI.Standings(parent, width)
  local s = { groups = {} }
  for i = 1, 5 do
    local g = UI.SectionHeader(parent, width)
    g.dot = UI.Round(g, "ARTWORK", 10)
    g.dot:SetPoint("LEFT", 12, 0)
    g.label = g.text
    g.label:ClearAllPoints(); g.label:SetPoint("LEFT", 28, 0)
    g.range = UI.Text(g, 12, "ink2")
    g.range:SetPoint("LEFT", g.label, "RIGHT", 8, 0)
    g.n = UI.Text(g, 14, nil, "title", "RIGHT")
    g.n:SetPoint("RIGHT", -14, 0)
    s.groups[i] = g
  end
  s.nobody = UI.WrapText(parent, 12, "ink2", width - 8, "book")
  s.rows = UI.Pool(function()
    local r = CreateFrame("Frame", nil, parent)
    r:SetSize(width, 22)
    r.dot = UI.Round(r, "ARTWORK", 8)
    r.dot:SetPoint("LEFT", 18, 0)
    r.name = UI.Text(r, 13, nil)
    r.name:SetPoint("LEFT", 32, 0)
    -- The Ring-bearer: the ring after the name (U55).
    r.ring = UI.Round(r, "ARTWORK", 14)
    r.ring:SetPoint("LEFT", r.name, "RIGHT", 4, 0)
    UI.SetIcon(r.ring, ns.ICONS.chal_ring)
    -- Online, AFK, offline or away: the mark of the Adventurers page, and its word.
    r.presence = UI.Presence(r, 8)
    r.presence:SetPoint("LEFT", r.name, "RIGHT", 6, 0)
    r.status = UI.Text(r, 11, "ink2")
    r.status:SetPoint("LEFT", r.presence, "RIGHT", 4, 0)
    r.level = UI.Text(r, 13, "ink", "title", "RIGHT")
    r.level:SetPoint("RIGHT", -2, 0)
    r.note = UI.Text(r, 12, "ink2", "body", "RIGHT")
    r.note:SetPoint("RIGHT", r.level, "LEFT", -10, 0)
    return r
  end)

  function s:Hide()
    for _, g in ipairs(self.groups) do g:Hide() end
    self.nobody:Hide()
    self.rows:HideFrom(1)
  end

  function s:Set(f, n, stack)
    local J, Hr, L = ns.Journey, ns.Hero, ns.L
    local light = Theme:Current().light
    local rowN, nobody = 0, {}
    for i, g in ipairs(J:Groups(f, n)) do
      local gf = self.groups[i]
      if #g.rows == 0 then
        gf:Hide()
        nobody[#nobody + 1] = g.label:lower()
      else
        local cr, cg, cb = Theme:RGBA(g.color)
        gf.dot:SetColorTexture(cr, cg, cb, 1)
        gf.label:SetText(g.label)
        gf.range:SetText(g.range)
        gf.n:SetText(#g.rows)
        gf.n:SetTextColor(Theme:RGBA(g.color))
        stack:Place(gf, 29, 2)
        for _, row in ipairs(g.rows) do
          local hr = self.rows:Get(rowN + 1)
          if not hr then break end
          rowN = rowN + 1
          local _, token = Hr:ClassName(f, row.name)
          -- The ink colour on parchment (a priest's white dot vanished there; seen in the tour).
          local ink = ns.ClassHex(token, light)
          hr.dot:SetColorTexture(ns.Hex(ink or "999999"))
          hr.name:SetText(ns.Short(row.name))
          local ring = ns.Challenges ~= nil and ns.Challenges:Bearer(f, row.name)
          hr.ring:SetShown(ring)
          hr.presence:ClearAllPoints()
          hr.presence:SetPoint("LEFT", ring and hr.ring or hr.name, "RIGHT", 6, 0)
          if ink then hr.name:SetTextColor(ns.Hex(ink)) else hr.name:SetTextColor(Theme:RGBA("ink")) end
          local kind = Hr:Presence(f, row.name)
          hr.presence:Set(kind)
          hr.status:SetText(L[UI.PRESENCE_LC[kind]])
          hr.note:SetText(row.note)
          hr.level:SetText(Hr:Level(f, row.name))
          hr:SetAlpha(J:Away(f, row.name) and 0.6 or 1)
          stack:Place(hr, 22, 0)
        end
        stack:Skip(8)
      end
    end
    self.rows:HideFrom(rowN + 1)
    self.nobody:SetShown(#nobody > 0)
    if #nobody > 0 then
      local text = #nobody == 1 and nobody[1] or (table.concat(nobody, ", ", 1, #nobody - 1) .. L.OR .. nobody[#nobody])
      self.nobody:SetText(L.GRP_NOBODY:format(text))
      stack:Place(self.nobody, self.nobody:GetStringHeight(), 10, 4)
    end
  end
  return s
end