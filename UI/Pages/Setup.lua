-- The setup guide (SPEC §4.14, 27 Oct 2026): once per character, the first time the book opens in a fellowship.
-- Three short steps: Look (theme), While you play (tracker, banners, chat, sounds), Reminders (cap warning, picture
-- moment, minimap button). Every choice is an existing setting and changes at once; Settings can run it again.
local _, ns = ...
local L = ns.L
local UI, Theme, Settings = ns.UI, ns.Theme, ns.Settings

local G = { step = 1 }
ns.SetupGuide = G

-- Shown when this character has not seen it yet (only in a fellowship).
function G:Pending() return ns.char ~= nil and not ns.char.setupDone and ns.Fellowship:Current() ~= nil end

-- Opens the guide from the start; after it the book goes to `after` (default: the Overview).
function G:Open(after)
  self.step, self.after = 1, after
  ns.Window:Open("setup")
end

-- Done, Skip or Use the defaults: the guide is over for this character.
function G:Finish()
  ns.char.setupDone = true
  local after = self.after or "overview"
  self.after = nil
  ns.Window:ShowPage(after)
  -- Then, once: Show me around? (UI/Walkthrough.lua)
  if ns.Walkthrough then C_Timer.After(0.4, function() ns.Walkthrough:OfferOnce() end) end
end

-- The settings the guide offers, back to their defaults.
function G:Defaults()
  local D = Settings.DEFAULTS
  for _, key in ipairs({ "theme", "chat", "sounds", "warnCap", "picture", "minimap" }) do Settings:Set(key, D[key]) end
  Settings:SetTrackerMode("always")
  Settings:SetToastMode("all")
end

local THEME_ART = { journal = 1, night = 9 }

local function build(pf)
  local W = ns.Window
  -- The guide shows in a fellowship, beside the sidebar: the narrower page width (the wide one of Welcome and Found
  -- ran over the spine and the right page's edge; seen in the tour).
  local width = W.PAGE_W - 8
  local left, right = pf.left, pf.right
  local head = UI.Heading(left, width, L.SETUP_TITLE, L.SETUP_SUB, 20)
  head:SetPoint("TOPLEFT")
  -- Step strip, like founding a fellowship.
  pf.steps = {}
  for i, label in ipairs({ L.SETUP_STEP_LOOK, L.SETUP_STEP_PLAY, L.SETUP_STEP_REMIND }) do
    local s = CreateFrame("Button", nil, left)
    s:SetSize(width / 3, 24)
    s:SetPoint("TOPLEFT", (i - 1) * width / 3, -(head:GetHeight() + 4))
    s.disc = UI.Round(s, "ARTWORK", 22)
    s.disc:SetPoint("LEFT")
    s.n = UI.Text(s, 12, "white", "body", "CENTER", "OVERLAY")
    s.n:SetPoint("CENTER", s.disc); s.n:SetText(i)
    s.label = UI.Text(s, 13, nil, "body")
    s.label:SetPoint("LEFT", s.disc, "RIGHT", 6, 0); s.label:SetText(label)
    s:SetScript("OnClick", function() G.step = i; W:Refresh() end)
    pf.steps[i] = s
  end
  local top = head:GetHeight() + 40
  pf.body = {}
  for i = 1, 3 do
    local b = CreateFrame("Frame", nil, left)
    b:SetPoint("TOPLEFT", 0, -top); b:SetPoint("BOTTOMRIGHT", 0, 44)
    pf.body[i] = b
  end
  pf.controls = {}

  -- Step 1: the theme as picture tiles (the book changes at once), and how to size the book.
  local b1 = pf.body[1]
  pf.themes = {}
  local horde = Theme:Horde()
  for i, key in ipairs({ "journal", "night", "faction" }) do
    local tile = UI.PictureTile(b1, width, 96, function(tex, w, h)
      if THEME_ART[key] then ns.Pages:SetChapterArt(tex, THEME_ART[key], w, h, 0.5)
      else
        local hall = (horde and ns.Pages.ART_HORDE or ns.Pages.ART).hall
        tex:SetTexture(ns.MEDIA .. hall[1]); UI.Cover(tex, hall[2], w, h, 0.5)
      end
      if key == "night" then tex:SetVertexColor(0.45, 0.5, 0.65) end
    end, function() Settings:Set("theme", key) end)
    tile:Set(L["THEME_" .. key:upper()], L["SETUP_THEME_" .. key:upper()])
    tile:SetPoint("TOPLEFT", 0, -(i - 1) * 104)
    tile.key = key
    pf.themes[i] = tile
  end
  local size = UI.WrapText(b1, 12, "ink2", width, "book")
  size:SetPoint("TOPLEFT", 0, -(3 * 104 + 4))
  size:SetText(L.SETUP_SIZE_HINT)

  -- Step 2: one choice per row, with a line on what it is.
  local b2 = pf.body[2]
  local y = 0
  local function choiceRow(label, hint, options, get, set)
    local t = UI.Text(b2, 15, "ink", "title")
    t:SetPoint("TOPLEFT", 0, -y); t:SetText(label)
    local h = UI.WrapText(b2, 12, "ink2", width, "book")
    h:SetPoint("TOPLEFT", 0, -(y + 20)); h:SetText(hint)
    local c = UI.Choice(b2, options, get, set)
    c:SetPoint("TOPLEFT", 0, -(y + 24 + h:GetStringHeight()))
    pf.controls[#pf.controls + 1] = c
    y = y + 24 + h:GetStringHeight() + 40
    return c, h
  end
  pf.tracker = choiceRow(L.SETUP_TRACKER, L.SETUP_TRACKER_HINT,
    { { L.SETUP_ALWAYS, "always" }, { L.SETUP_HOVER, "hover" }, { L.SETUP_OFF, "off" } },
    function() return Settings:TrackerMode() end, function(v) Settings:SetTrackerMode(v) end)
  pf.toasts, pf.toastsHint = choiceRow(L.SETUP_TOASTS, L.SETUP_TOASTS_HINT,
    { { L.SETUP_ALL, "all" }, { L.SETUP_BIG, "big" }, { L.SETUP_OFF, "off" } },
    function() return Settings:ToastMode() end, function(v) Settings:SetToastMode(v) end)
  pf.chat = choiceRow(L.CHAT_MESSAGES, L.SETUP_CHAT_HINT,
    { { L.CHAT_ALL, "all" }, { L.CHAT_IMPORTANT, "important" }, { L.CHAT_OFF, "off" } },
    function() return Settings:Get("chat") end, function(v) Settings:Set("chat", v) end)
  pf.sounds = choiceRow(L.SOUNDS, L.SOUNDS_HINT, { { L.SETUP_ON, true }, { L.SETUP_OFF, false } },
    function() return Settings:Get("sounds") end, function(v) Settings:Set("sounds", v) end)

  -- Step 3: reminders, as checkboxes with a line each.
  local b3 = pf.body[3]
  y = 0
  local function checkRow(label, hint, key)
    local c = UI.Checkbox(b3, function() return Settings:Get(key) end, function(v) Settings:Set(key, v) end)
    c:SetPoint("TOPLEFT", 0, -y)
    local t = UI.Text(b3, 15, "ink", "title")
    t:SetPoint("TOPLEFT", 36, -(y + 4)); t:SetText(label)
    local h = UI.WrapText(b3, 12, "ink2", width - 36, "book")
    h:SetPoint("TOPLEFT", 36, -(y + 24)); h:SetText(hint)
    pf.controls[#pf.controls + 1] = c
    y = y + 24 + h:GetStringHeight() + 22
    return c
  end
  pf.warnCap = checkRow(L.WARN_CAP, L.WARN_CAP_HINT, "warnCap")
  pf.picture = checkRow(L.PICTURE_PROMPT, L.PICTURE_PROMPT_HINT, "picture")
  pf.minimap = checkRow(L.MINIMAP_BUTTON, L.SETUP_MINIMAP_HINT, "minimap")

  -- Footer: Skip, Back, Next / Start the journey.
  pf.skip = UI.TextButton(left, L.SETUP_SKIP, function() G:Finish() end, "link", 13)
  pf.skip:SetPoint("BOTTOMLEFT", 0, 4)
  pf.next = UI.TextButton(left, L.NEXT, function() G.step = math.min(3, G.step + 1); W:Refresh() end, "primary", 14)
  pf.next:SetPoint("BOTTOMRIGHT", 0, 0)
  pf.done = UI.TextButton(left, L.SETUP_DONE, function() G:Finish() end, "primary", 14)
  pf.done:SetPoint("BOTTOMRIGHT", 0, 0)
  pf.prev = UI.TextButton(left, L.BACK, function() G.step = math.max(1, G.step - 1); W:Refresh() end, "plain", 14)

  -- Right page: what this is, that it can all change later, and the defaults in one click.
  local rh = UI.Heading(right, width, L.SETUP_RIGHT_TITLE, nil, 18)
  rh:SetPoint("TOPLEFT")
  pf.later = UI.WrapText(right, 14, "ink", width, "book")
  pf.later:SetPoint("TOPLEFT", 0, -(rh:GetHeight() + 6))
  pf.later:SetText(L.SETUP_LATER)
  pf.ready = UI.WrapText(right, 14, "ink", width, "book")
  pf.ready:SetPoint("TOPLEFT", pf.later, "BOTTOMLEFT", 0, -14)
  pf.ready:SetText(L.SETUP_READY)
  pf.defaults = UI.TextButton(right, L.SETUP_DEFAULTS, function() G:Defaults(); G:Finish() end, "plain", 13)
  pf.art = UI.PageArt(right, "Companions")
end

local function refresh(pf)
  -- Seen once is enough: closing the book counts as Skip (Settings can run it again).
  if ns.char then ns.char.setupDone = true end
  local step = G.step
  for i, s in ipairs(pf.steps) do
    s.disc:SetColorTexture(Theme:RGBA(i <= step and "B8742A" or "line"))
    s.label:SetTextColor(Theme:RGBA(i == step and "ink" or "ink2"))
  end
  for i, b in ipairs(pf.body) do b:SetShown(i == step) end
  local theme = Settings:Get("theme")
  for _, tile in ipairs(pf.themes) do tile:SetChosen(tile.key == theme) end
  for _, c in ipairs(pf.controls) do c:Refresh() end
  -- Toasts set one by one in Settings: none of the three is chosen, and the hint says so.
  pf.toastsHint:SetText(Settings:ToastMode() == "custom" and L.SETUP_TOASTS_CUSTOM or L.SETUP_TOASTS_HINT)
  pf.next:SetShown(step < 3); pf.done:SetShown(step == 3)
  pf.prev:SetShown(step > 1)
  pf.prev:ClearAllPoints(); pf.prev:SetPoint("RIGHT", step < 3 and pf.next or pf.done, "LEFT", -8, 0)
  pf.ready:SetShown(step == 3)
  pf.defaults:ClearAllPoints()
  pf.defaults:SetPoint("TOPLEFT", step == 3 and pf.ready or pf.later, "BOTTOMLEFT", 0, -16)
  local used = pf.later:GetStringHeight() + (step == 3 and pf.ready:GetStringHeight() + 14 or 0) + 110
  pf.art:Fit(used)
end

-- Not in the sidebar: the book opens it by itself.
ns.Pages:Register({ id = "setup", label = L.SETUP_TITLE, free = true, header = "none", build = build, refresh = refresh,
  title = function() return L.SETUP_TITLE, L.ADDON_NAME end })
