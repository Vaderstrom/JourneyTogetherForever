-- Toasts: a banner on the screen (SPEC §5). They show at any time, also during combat, at the place the
-- player chose (Settings → Toast position). Adapted from GuildHall_Core/Util.lua (AH:Toast).
local _, ns = ...
local L = ns.L
local UI, Theme, Combat, Settings = ns.UI, ns.Theme, ns.Combat, ns.Settings
local T = { shownCount = 0, exampleN = 0, moving = false }
ns.Toasts = T

-- Settings → "Show an example toast" goes through these in turn (from the mockup; the clear with its picture, U7).
T.EXAMPLES = {
  { "chapter", L.EX_CHAPTER_TITLE, L.EX_CHAPTER_TEXT }, { "floor", L.EX_FLOOR_TITLE, L.EX_FLOOR_TEXT },
  { "clear", L.EX_CLEAR_TITLE, L.EX_CLEAR_TEXT, { dungeon = "stocks", kicker = L.TOAST_CLEARED, who = L.EX_CLEAR_WHO } },
  { "heroFloor", L.EX_HEROFLOOR_TITLE, L.EX_HEROFLOOR_TEXT },
  { "heroCap", L.EX_HEROCAP_TITLE, L.EX_HEROCAP_TEXT }, { "overCap", L.EX_OVERCAP_TITLE, L.EX_OVERCAP_TEXT },
}

-- Small caps line above the title: the toast's own (own), else the event's name, or the addon's name.
function T:Kicker(kind, own)
  local label = own or (kind and L["TOAST_" .. kind:upper()])
  return (label or L.ADDON_NAME):upper()
end

-- Returns "off" (Reduce effects or this event turned off) or "shown". page (optional): the book's page a click opens.
-- more (optional): { dungeon = key (its picture on the left), kicker = text, who = a line under the text,
-- solemn = true (a Fallen, the last shared life: darker, slower, with a bell; SPEC §9), icon = a path of ns.ICONS (in
-- place of its kind's: a challenge's own) }.
function T:Push(kind, title, text, page, more)
  if Settings:Get("reduce") or (kind and not Settings:ToastOn(kind)) then return "off" end
  more = more or {}
  local t = { kind = kind, title = title, text = text, page = page, dungeon = more.dungeon, kicker = more.kicker, who = more.who,
    solemn = more.solemn, icon = more.icon }
  -- The banner is made at login. Only after a /reload during combat can it be missing: then it shows after combat.
  if not self.frame and Combat:InCombat() then
    Combat:AfterCombat(function() T:Show(t) end)
  else
    self:Show(t)
  end
  return "shown"
end

function ns:Toast(kind, title, text, page, more) return T:Push(kind, title, text, page, more) end

function T:Example()
  local e = self.EXAMPLES[self.exampleN % #self.EXAMPLES + 1]
  self.exampleN = self.exampleN + 1
  return self:Push(e[1], e[2], e[3], nil, e[4])
end

---------------------------------------------------------------------------
-- Position
---------------------------------------------------------------------------
function T:Place()
  local f = self.frame
  if not f then return end
  f:ClearAllPoints()
  local p = ns.char.toastPos
  if p and p.point then f:SetPoint(p.point, UIParent, p.rel or p.point, p.x or 0, p.y or 0)
  else f:SetPoint("TOP", UIParent, "TOP", 0, -26) end
end

-- Settings → Move: a sample banner stays on screen and can be dragged until Done.
function T:StartMove()
  local f = self:Build()
  self.moving = true
  f.anim:Stop()
  self:Fill({ kind = nil, title = L.TOAST_MOVE_TITLE, text = L.TOAST_MOVE_TEXT })
  f:SetAlpha(1)
  f:Show()
end

function T:StopMove()
  self.moving = false
  if self.frame then self.frame:Hide() end
end

function T:ResetPosition()
  ns.char.toastPos = nil
  self:Place()
end

---------------------------------------------------------------------------
-- The banner
---------------------------------------------------------------------------
-- Clear messages (U7, 31 Oct 2026): the dungeon's or raid's picture on the left, the same art as the Chapter page's
-- dungeon rows and the Raids page (ns.SetDungeonArt), at 2:1 so it still reads at a glance on a 4K screen. A place
-- with no picture of its own (the game's default tile, or nothing: some of WoW Forever's own dungeons) shows the
-- message as usual, with the icon.
T.PIC_W, T.PIC_H, T.PIC_PAD = 176, 88, 10

-- The place's picture on tex. true when it has one of its own.
function T:SetPlace(tex, key)
  local inset = 2 * UI.PIC_INSET
  local ok, default = ns.SetDungeonArt(tex, key, self.PIC_W - inset, self.PIC_H - inset)
  return ok == true and not default
end

function T:Build()
  if self.frame then return self.frame end
  local f = UI.Box(UIParent, 2, nil, nil, "gold", 1)
  f:SetSize(560, 86)
  f:SetFrameStrata("DIALOG")
  f:SetClampedToScreen(true)
  f:SetMovable(true)
  local bg = UI.GradientTex(f, "BACKGROUND", "VERTICAL", { "dark", 0.97 }, { "toastTop", 0.97 })
  bg:SetPoint("TOPLEFT", 2, -2); bg:SetPoint("BOTTOMRIGHT", -2, 2)
  -- A solemn one (SPEC §9): night violet over the banner, darker at the foot.
  f.solemnBg = f:CreateTexture(nil, "BACKGROUND", nil, 1)
  f.solemnBg:SetPoint("TOPLEFT", 2, -2); f.solemnBg:SetPoint("BOTTOMRIGHT", -2, 2)
  UI.SetGradient(f.solemnBg, "VERTICAL", { 0.05, 0.03, 0.07, 0.98 }, { 0.2, 0.15, 0.27, 0.96 })
  f.solemnBg:Hide()
  -- Big moments show the chapter's picture behind the text, darker on the left where the text is.
  f.pic = f:CreateTexture(nil, "BACKGROUND", nil, 2)
  f.pic:SetPoint("TOPLEFT", 2, -2); f.pic:SetPoint("BOTTOMRIGHT", -2, 2)
  f.picFade = f:CreateTexture(nil, "BACKGROUND", nil, 3)
  f.picFade:SetAllPoints(f.pic)
  UI.SetGradient(f.picFade, "HORIZONTAL", { 0.07, 0.04, 0.02, 0.92 }, { 0.07, 0.04, 0.02, 0.25 })
  local glow = UI.Box(f, 1, nil, nil, "gold", 0.35)
  glow:SetPoint("TOPLEFT", 3, -3); glow:SetPoint("BOTTOMRIGHT", -3, 3)
  f.glow = glow
  T:BuildFrame(f)
  local disc = UI.Round(f, "ARTWORK", 54, 1)
  disc:SetPoint("LEFT", 16, 0)
  Theme:Gradient(disc, "VERTICAL", { "iconDark", 1 }, { "iconLight", 1 })
  f.icon = UI.Round(f, "ARTWORK", 36, 2)
  f.icon:SetPoint("CENTER", disc)
  f.disc = disc
  -- Big moments carry the fellowship's own crest (they showed the generic book icon; seen in the tour).
  f.crest = UI.Crest(f, 64, 64)
  f.crest:SetPoint("CENTER", disc)
  f.crest:SetFrameLevel(f:GetFrameLevel() + 3)
  f.crest:Hide()
  -- A clear's picture (U7) takes the icon's place: the dungeon's or raid's, in the book's gold picture frame.
  f.place = CreateFrame("Frame", nil, f)
  f.place:SetSize(T.PIC_W, T.PIC_H)
  f.place:SetPoint("LEFT", T.PIC_PAD, 0)
  f.place.tex = f.place:CreateTexture(nil, "ARTWORK")
  UI.FramePicture(f.place, f.place.tex)
  f.place:Hide()
  f.kicker = UI.Text(f, 11, "gold", "body")
  f.kicker:SetPoint("TOPLEFT", 86, -14)
  f.title = UI.Text(f, 20, "goldText", "title")
  f.title:SetPoint("TOPLEFT", f.kicker, "BOTTOMLEFT", 0, -3)
  f.title:SetShadowOffset(0, -1); f.title:SetShadowColor(0, 0, 0, 1)
  -- Wraps to a second line: one line cut long texts off (seen in game). Fill sizes the banner to it.
  f.text = UI.Text(f, 13, "toastText", "body")
  f.text:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -3)
  f.text:SetWordWrap(true)
  if f.text.SetMaxLines then f.text:SetMaxLines(3) end
  f.text:SetJustifyV("TOP")
  -- Who was there, under the text of a clear (U7): the names in their class colours.
  f.who = UI.Text(f, 13, "toastText", "body")
  f.who:SetPoint("TOPLEFT", f.text, "BOTTOMLEFT", 0, -4)
  f.who:SetWordWrap(true)
  if f.who.SetMaxLines then f.who:SetMaxLines(2) end
  f.who:SetJustifyV("TOP")
  f.who:Hide()
  -- Fades in, stays, fades out: 4.2 seconds in all (as in the mockup).
  local ag = f:CreateAnimationGroup()
  -- (A solemn one fades in and out slowly and stays longer: Fill sets the times.)
  local a1 = ag:CreateAnimation("Alpha"); a1:SetFromAlpha(0); a1:SetToAlpha(1); a1:SetDuration(0.35); a1:SetOrder(1)
  f.fadeIn = a1
  local a2 = ag:CreateAnimation("Alpha"); a2:SetFromAlpha(1); a2:SetToAlpha(1); a2:SetDuration(3.05); a2:SetOrder(2)
  f.hold = a2
  local a3 = ag:CreateAnimation("Alpha"); a3:SetFromAlpha(1); a3:SetToAlpha(0); a3:SetDuration(0.8); a3:SetOrder(3)
  f.fadeOut = a3
  ag:SetScript("OnFinished", function() if not T.moving then f:Hide() end end)
  f.anim = ag
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  -- A click hides a toast and opens what it is about (it only hid; seen in game); while moving, dragging places it.
  f:SetScript("OnMouseDown", function() if not T.moving then T:Click() end end)
  f:SetScript("OnDragStart", function() if T.moving then f:StartMoving() end end)
  f:SetScript("OnDragStop", function()
    f:StopMovingOrSizing()
    local point, _, rel, x, y = f:GetPoint()
    ns.char.toastPos = { point = point, rel = rel, x = x, y = y }
  end)
  f:Hide()
  self.frame = f
  self:Place()
  return f
end

-- Big moments (SPEC §6): a chapter unlocks, the journey is complete, and the session recap (M25). A larger banner
-- that stays longer; the first two with a sound (a fanfare after the group parted would be out of place).
T.BIG = { chapter = true, journey = true, session = true }
T.BIG_SOUND = 888 -- the game's level-up fanfare
T.SOUND = { chapter = true, journey = true }
-- A solemn banner (a Fallen, the last shared life; SPEC §9): violet and silver instead of gold, a slower fade, longer
-- on screen, and the bell (ns.Sound).
T.SOLEMN = { hold = 5.5, fadeIn = 1, fadeOut = 2.2, edge = "8C7AA6", kicker = "B9AECB", title = "E8E2F0" }

-- The big moments' gold and leather frame (our art, Media\MomentFrame, A9): one picture about 3.2 wide to 1 high,
-- stored stretched in a 1024 x 512 file. Drawn in five pieces across, so the corners and the gem keep their shape
-- and only the plain stretches between them grow: left corner, stretch, gem, stretch, right corner. Its opening (the
-- part between the borders) holds the banner; the borders lie over the banner's edge by OVERLAP pixels.
local FRAME = { aspect = 3.204, cuts = { 0, 0.12, 0.40, 0.60, 0.88, 1 }, top = 0.266, bottom = 0.75, left = 0.086,
  right = 0.906, OVERLAP = 10 }
T.FRAME = FRAME

function T:BuildFrame(f)
  local probe = f:CreateTexture(nil, "OVERLAY")
  if not probe:SetTexture(ns.MEDIA .. "MomentFrame") then probe:Hide(); return end
  f.frame = {}
  for i = 1, 5 do
    local t = i == 1 and probe or f:CreateTexture(nil, "OVERLAY")
    t:SetTexture(ns.MEDIA .. "MomentFrame")
    t:SetTexCoord(FRAME.cuts[i], FRAME.cuts[i + 1], 0, 1)
    t:Hide()
    f.frame[i] = t
  end
end

-- Lays the frame around a banner h high (or hides it). Returns true when it shows.
function T:LayoutFrame(f, show, h)
  if not f.frame then return false end
  for _, t in ipairs(f.frame) do t:SetShown(show) end
  if not show then f:SetClampRectInsets(0, 0, 0, 0); return false end
  local o, c = FRAME.OVERLAP, FRAME.cuts
  local H = (h - 2 * o) / (FRAME.bottom - FRAME.top)
  local unit = FRAME.aspect * H -- screen width of the whole picture at its own shape
  local up = FRAME.top * H - o
  local p = f.frame
  local function w(i) return (c[i + 1] - c[i]) * unit end
  for _, i in ipairs({ 1, 3, 5 }) do p[i]:SetSize(w(i), H) end
  p[1]:ClearAllPoints(); p[1]:SetPoint("TOPLEFT", f, "TOPLEFT", o - FRAME.left * unit, up)
  p[5]:ClearAllPoints(); p[5]:SetPoint("TOPRIGHT", f, "TOPRIGHT", (1 - FRAME.right) * unit - o, up)
  p[3]:ClearAllPoints(); p[3]:SetPoint("TOP", f, "TOP", 0, up)
  p[2]:ClearAllPoints(); p[2]:SetPoint("TOPLEFT", p[1], "TOPRIGHT"); p[2]:SetPoint("BOTTOMRIGHT", p[3], "BOTTOMLEFT")
  p[4]:ClearAllPoints(); p[4]:SetPoint("TOPLEFT", p[3], "TOPRIGHT"); p[4]:SetPoint("BOTTOMRIGHT", p[5], "BOTTOMLEFT")
  -- The banner stays on screen with its frame.
  local side = FRAME.left * unit - o
  f:SetClampRectInsets(-side, side, up, -((1 - FRAME.bottom) * H - o))
  return true
end

function T:Fill(t)
  local f = self.frame
  f:SetScale(ns.Window:BaseScale())
  local big = t.kind ~= nil and self.BIG[t.kind] == true
  local pictured = not big and t.dungeon ~= nil and self:SetPlace(f.place.tex, t.dungeon)
  f.place:SetShown(pictured)
  local w = big and 680 or (pictured and 640 or 560)
  local left = pictured and (self.PIC_PAD + self.PIC_W + 16) or 86
  f.title:SetFont(Theme.FONT_TITLE, big and 28 or 20, "")
  f.text:SetFont(Theme.FONT_BODY, big and 15 or 13, "")
  -- More room on the right of a big one: its frame is thicker (the text ran into it; seen in the seventh check).
  f.text:SetWidth(w - left - (big and 52 or 22))
  f.text:SetText(t.text or "")
  f.who:SetWidth(w - left - 22)
  f.who:SetText(t.who or "")
  f.who:SetShown(t.who ~= nil)
  -- Taller when the text takes more than one line, and for the line of who was there.
  local extra = math.max(0, math.ceil((f.text:GetStringHeight() or 0) - (big and 17 or 15)))
  if t.who then extra = extra + math.ceil(f.who:GetStringHeight() or 0) + 4 end
  local h = (big and 112 or 86) + extra
  -- With a picture the banner is as tall as it with its margins, and the words sit in the middle beside it.
  local top = 14
  if pictured and h < self.PIC_H + 2 * self.PIC_PAD then
    top = top + math.floor((self.PIC_H + 2 * self.PIC_PAD - h) / 2)
    h = self.PIC_H + 2 * self.PIC_PAD
  end
  f.kicker:ClearAllPoints(); f.kicker:SetPoint("TOPLEFT", left, -top)
  f:SetSize(w, h)
  local solemn = t.solemn == true and not big
  f.hold:SetDuration(big and 6 or (solemn and T.SOLEMN.hold or 3.05))
  f.fadeIn:SetDuration(solemn and T.SOLEMN.fadeIn or 0.35)
  f.fadeOut:SetDuration(solemn and T.SOLEMN.fadeOut or 0.8)
  f.big, f.solemn = big, solemn
  -- The frame takes the place of the thin gold border on big moments only (decided 27 Oct 2026: the frame marks
  -- them as special; normal toasts keep the plain banner).
  local framed = self:LayoutFrame(f, big, h)
  f.glow:SetShown(not framed)
  local edge = solemn and T.SOLEMN.edge or "gold"
  f:SetBackdropBorderColor(Theme:RGBA(edge, framed and 0 or 1))
  f.glow:SetBackdropBorderColor(Theme:RGBA(edge, 0.35))
  f.solemnBg:SetShown(solemn)
  f.kicker:SetTextColor(Theme:RGBA(solemn and T.SOLEMN.kicker or "gold"))
  f.title:SetTextColor(Theme:RGBA(solemn and T.SOLEMN.title or "goldText"))
  f.pic:SetShown(big); f.picFade:SetShown(big)
  if big then
    local fs = ns.Fellowship:Current()
    ns.Pages:SetChapterArt(f.pic, fs and ns.Pages:ArtOf(fs, ns.Journey:CurrentIndex(fs)), 676, 108, 0.45)
  end
  -- Its own icon, else its kind's (also when the game does not have its own).
  if not (t.icon and UI.SetIcon(f.icon, t.icon)) then
    UI.SetIcon(f.icon, ns.ICONS["toast_" .. (t.kind or "default")] or ns.ICONS.toast_default)
  end
  local fs = big and ns.Fellowship:Current()
  f.crest:SetShown(fs ~= nil and fs ~= false)
  local badge = not f.crest:IsShown() and not pictured
  f.icon:SetShown(badge); f.disc:SetShown(badge)
  if f.crest:IsShown() then f.crest:Set(fs.color, fs.emblem) end
  f.kicker:SetText(self:Kicker(t.kind, t.kicker))
  f.title:SetText(t.title or "")
  f.text:SetText(t.text or "")
end

-- A click on the banner: it goes, and the book opens at its page (when it has one). page may be a function that
-- opens what the toast is about (the share window after an invite got no answer).
function T:Click()
  local f, t = self.frame, self.current
  f.anim:Stop(); f:Hide()
  if not (t and t.page and ns.Fellowship:Current()) then return end
  if type(t.page) == "function" then t.page() else ns.Window:Open(t.page) end
end

function T:Show(t)
  local f = self:Build()
  if self.moving then return end
  self:Fill(t)
  self.current = t
  self.shownCount = self.shownCount + 1
  f:SetAlpha(1)
  f:Show()
  f.anim:Stop()
  f.anim:Play()
  if f.big and T.SOUND[t.kind] and PlaySound then PlaySound(T.BIG_SOUND, "Master") end
  -- A solemn one tolls the bell once (Settings → Sounds turns it off).
  if f.solemn then ns.Sound("bell") end
end

ns:On("LOGIN", function() Combat:AfterCombat(function() T:Build() end) end)
