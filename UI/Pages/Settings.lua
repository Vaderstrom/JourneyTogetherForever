-- Settings (SPEC §4.12): a page of its own on the flat sheet (29 Oct 2026; as a side panel it had grown too long to
-- use without scrolling). The left page: the book, messages, help and the commands; the right page: the progress
-- toasts and the tracker. Each explanation sits behind a "?" after its label. Shown in and outside a fellowship; the
-- header's gear opens it and closes it again (W:ToggleSettings).
local _, ns = ...
local L = ns.L
local UI, Settings = ns.UI, ns.Settings
local W = ns.Window

-- (Rows 28 high since Full screen joined The book: the left page still fits without scrolling.)
local ROW, GRID, GAP = 28, 22, 10

-- One page's column: headings, rows and grids placed from the top down.
local function column(pf, parent, width)
  local c = { y = 0 }
  function c:Head(text, help)
    local h = UI.SectionHeader(parent, width)
    h:SetPoint("TOPLEFT", 0, -self.y)
    h:SetText(text)
    if help then h:SetHelp(help) end
    self.y = self.y + 31
    return h
  end
  function c:Gap() self.y = self.y + GAP end
  -- A row: the label (and its "?") on the left, the control at the right.
  function c:Row(label, control, help)
    local r = CreateFrame("Frame", nil, parent)
    r:SetSize(width, ROW)
    r:SetPoint("TOPLEFT", 0, -self.y)
    r.label = UI.Text(r, 13, "ink")
    r.label:SetPoint("LEFT")
    r.label:SetText(label)
    if help then
      r.help = UI.HelpIcon(r)
      r.help:SetPoint("LEFT", r.label, "RIGHT", 6, 0)
      r.help:SetHelp(label, help)
    end
    control:ClearAllPoints()
    control:SetPoint("RIGHT", r, "RIGHT", 0, 0)
    pf.controls[#pf.controls + 1] = control
    self.y = self.y + ROW
    return r
  end
  -- A small checkbox with its label after it: the toasts' and the tracker's lists, two to a line.
  local function tick(label, get, set, help)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(width / 2, GRID)
    f.box = UI.Checkbox(f, get, set)
    f.box:SetSize(22, 22)
    f.box:SetPoint("LEFT", -3, 0)
    f.label = UI.Text(f, 12, "ink")
    f.label:SetPoint("LEFT", f.box, "RIGHT", 2, 0)
    f.label:SetText(label)
    if help then
      f.help = UI.HelpIcon(f)
      f.help:SetPoint("LEFT", f.label, "RIGHT", 6, 0)
      f.help:SetHelp(label, help)
    end
    pf.controls[#pf.controls + 1] = f.box
    return f
  end
  function c:Grid(items)
    local out = {}
    for i, it in ipairs(items) do
      local f = tick(it[1], it[2], it[3])
      f:SetPoint("TOPLEFT", ((i - 1) % 2) * width / 2, -(self.y + math.floor((i - 1) / 2) * GRID))
      out[it.key or i] = f
    end
    self.y = self.y + math.ceil(#items / 2) * GRID
    return out
  end
  function c:Tick(label, get, set, help)
    local f = tick(label, get, set, help)
    f:SetWidth(width)
    f:SetPoint("TOPLEFT", 0, -(self.y + 1))
    self.y = self.y + GRID + 2
    return f
  end
  return c
end

local function build(pf)
  local width = W.PAGE_W - 8
  pf.controls = {}
  local function check(key) return function() return Settings:Get(key) end, function(v) Settings:Set(key, v) end end
  local function dropdown(parent, options, key)
    return UI.Dropdown(parent, 150, options, function() return Settings:Get(key) end, function(v) Settings:Set(key, v) end)
  end
  -- Back to the page you came from (the gear does the same).
  pf.back = UI.TextButton(pf, "‹ " .. L.BACK, function() W:CloseSettings() end, "link", 13)
  -- (Over the left column, also when the full screen's wider sheet moves the columns in.)
  pf.back:SetPoint("TOPLEFT", pf.left, "TOPLEFT", 0, 52)

  -- Left: the book, messages, help and commands.
  local Lp = pf.left
  local left = column(pf, Lp, width)
  left:Head(L.SET_BOOK)
  left:Row(L.THEME, dropdown(Lp, { { L.THEME_JOURNAL, "journal" }, { L.THEME_NIGHT, "night" }, { L.THEME_FACTION, "faction" } }, "theme"), L.THEME_HINT)
  local function langNote() return Settings:Get("lang") == "sv" and L.LANG_NOTE_SV or L.LANG_NOTE_EN end
  pf.lang = left:Row(L.LANGUAGE, UI.Dropdown(Lp, 150, { { L.LANG_EN, "en" }, { L.LANG_SV, "sv" } }, function() return Settings:Get("lang") end,
    function(v) Settings:Set("lang", v); pf.lang.help:SetHelp(L.LANGUAGE, langNote()) end), langNote())
  pf.fullBox = UI.Checkbox(Lp, check("fullscreen"))
  left:Row(L.FULLSCREEN, pf.fullBox, L.FULLSCREEN_HINT)
  left:Row(L.SOUNDS, UI.Checkbox(Lp, check("sounds")), L.SOUNDS_HINT)
  left:Row(L.REDUCE_EFFECTS, UI.Checkbox(Lp, check("reduce")), L.REDUCE_EFFECTS_HINT)
  left:Gap()
  left:Head(L.SET_MESSAGES)
  left:Row(L.CHAT_MESSAGES, dropdown(Lp, { { L.CHAT_ALL, "all" }, { L.CHAT_IMPORTANT, "important" }, { L.CHAT_OFF, "off" } }, "chat"))
  -- The cap warning and when it comes, on one line: the slider, then the box that turns it on.
  local warn = CreateFrame("Frame", nil, Lp)
  warn:SetSize(206, 26)
  warn.box = UI.Checkbox(warn, check("warnCap"))
  warn.box:SetPoint("RIGHT")
  warn.slider = UI.Slider(warn, 170, 50, 95, 5, function() return Settings:Get("warnPct") end,
    function(v) Settings:SetWarn(v) end, function(v) return v .. "%" end)
  warn.slider:SetPoint("RIGHT", warn.box, "LEFT", -8, 0)
  left:Row(L.WARN_CAP, warn, L.WARN_CAP_HINT)
  -- (The box and the slider are the controls, not the line holding them; the tests go through pf.controls.)
  pf.controls[#pf.controls] = warn.box
  pf.controls[#pf.controls + 1] = warn.slider
  left:Row(L.PICTURE_PROMPT, UI.Checkbox(Lp, check("picture")), L.PICTURE_PROMPT_HINT)
  left:Gap()
  left:Head(L.SET_HELP)
  -- The setup guide and the walkthrough again (only in a fellowship: they are part of the book).
  pf.setupAgain = UI.TextButton(Lp, L.SETUP_AGAIN, function()
    if not ns.Fellowship:Current() then return end
    ns.SetupGuide:Open(W.beforeSettings)
  end, "plain")
  pf.setupAgain.Refresh = function(b) b:SetEnabled(ns.Fellowship:Current() ~= nil) end
  left:Row(L.SETUP_GUIDE, pf.setupAgain, L.SETUP_AGAIN_HINT)
  pf.walkAgain = UI.TextButton(Lp, L.WALK_AGAIN, function()
    if not ns.Fellowship:Current() then return end
    ns.Walkthrough:Start()
  end, "plain")
  pf.walkAgain.Refresh = function(b) b:SetEnabled(ns.Fellowship:Current() ~= nil) end
  left:Row(L.WALK_SETTING, pf.walkAgain, L.WALK_AGAIN_HINT)
  pf.minimapBox = UI.Checkbox(Lp, check("minimap"))
  left:Row(L.MINIMAP_BUTTON, pf.minimapBox, L.MINIMAP_HINT)
  -- The commands, two to a line: the command in the accent colour, what it does after it.
  left.y = left.y + 6
  for i, cmd in ipairs(ns.COMMANDS) do
    local x, y = ((i - 1) % 2) * width / 2, -(left.y + math.floor((i - 1) / 2) * 18)
    local code = UI.Text(Lp, 12, "accent")
    code:SetPoint("TOPLEFT", x, y)
    code:SetText(cmd[1])
    local what = UI.Text(Lp, 12, "ink2")
    what:SetPoint("LEFT", code, "RIGHT", 8, 0)
    what:SetText(cmd[2])
  end
  left.y = left.y + math.ceil(#ns.COMMANDS / 2) * 18

  -- Right: the progress toasts and the tracker.
  local Rp = pf.right
  local right = column(pf, Rp, width)
  local toasts = right:Head(L.PROGRESS_TOASTS, L.PROGRESS_TOASTS_HINT)
  pf.example = UI.TextButton(Rp, L.EXAMPLE_TOAST, function() ns.Toasts:Example() end, "link", 12)
  pf.example:SetPoint("BOTTOMRIGHT", toasts, "BOTTOMRIGHT", 0, 7)
  local items = {}
  for _, kind in ipairs(Settings.TOAST_EVENTS) do
    items[#items + 1] = { L["TOAST_" .. kind:upper()], function() return Settings:ToastOn(kind) end,
      function(v) Settings:SetToast(kind, v) end, key = kind }
  end
  pf.toastRows = {}
  for kind, f in pairs(right:Grid(items)) do pf.toastRows[kind] = f.box end
  right.y = right.y + 2
  -- Toast position: Move shows a banner to drag; Done ends it; Reset puts it back at the top.
  local place = CreateFrame("Frame", nil, Rp)
  place.move = UI.TextButton(place, L.TOAST_MOVE, function()
    if ns.Toasts.moving then ns.Toasts:StopMove() else ns.Toasts:StartMove() end
    place:Refresh()
  end, "plain")
  place.reset = UI.TextButton(place, L.TOAST_RESET, function() ns.Toasts:ResetPosition() end, "plain")
  function place:Refresh()
    self.move:SetLabel(ns.Toasts.moving and L.TOAST_DONE or L.TOAST_MOVE)
    self.move:SetHeight(28); self.reset:SetHeight(28)
    self:SetSize(self.move:GetWidth() + 4 + self.reset:GetWidth(), 28)
    self.reset:ClearAllPoints(); self.reset:SetPoint("RIGHT")
    self.move:ClearAllPoints(); self.move:SetPoint("RIGHT", self.reset, "LEFT", -4, 0)
  end
  place:Refresh()
  pf.toastPlace = place
  right:Row(L.TOAST_POSITION, place, L.TOAST_POSITION_HINT)
  right:Gap()
  -- The tracker: turned on at the heading; its lines and how it behaves under it, faded while it is off.
  local tracker = right:Head(L.TRACKER, L.TRACKER_HINT)
  pf.trackerBox = UI.Checkbox(Rp, check("tracker"))
  pf.trackerBox:SetPoint("RIGHT", tracker, "RIGHT", 3, 3)
  pf.controls[#pf.controls + 1] = pf.trackerBox
  local lines = {}
  for _, key in ipairs(Settings.TRACKER_LINES) do
    lines[#lines + 1] = { L["TRACK_LINE_" .. key:upper()], function() return Settings:TrackerLineOn(key) end,
      function(v) Settings:SetTrackerLine(key, v) end, key = key }
  end
  pf.trackerRows, pf.trackerParts = {}, {}
  for key, f in pairs(right:Grid(lines)) do pf.trackerRows[key] = f.box; pf.trackerParts[#pf.trackerParts + 1] = f end
  right.y = right.y + 4
  local function opt(label, key, help, default)
    local get = default and function() return Settings:Get(key) ~= false end or function() return Settings:Get(key) end
    local f = right:Tick(label, get, function(v) Settings:Set(key, v) end, help)
    pf.trackerParts[#pf.trackerParts + 1] = f
    return f.box
  end
  pf.trackerHover = opt(L.TRACKER_HOVER, "trackerHover", L.TRACKER_HOVER_HINT)
  pf.trackerPeek = opt(L.TRACKER_PEEK, "trackerPeek", L.TRACKER_PEEK_HINT, true)
  pf.trackerCombat = opt(L.TRACKER_HIDE_COMBAT, "trackerHideCombat")
  pf.trackerInstance = opt(L.TRACKER_HIDE_INSTANCE, "trackerHideInstance", L.TRACKER_HIDE_INSTANCE_HINT)
  pf.heights = { left = left.y, right = right.y }
end

local function refresh(pf)
  for _, c in ipairs(pf.controls) do c:Refresh() end
  pf.toastPlace:Refresh()
  pf.lang.help:SetHelp(L.LANGUAGE, Settings:Get("lang") == "sv" and L.LANG_NOTE_SV or L.LANG_NOTE_EN)
  local on = Settings:Get("tracker") and true or false
  for _, f in ipairs(pf.trackerParts) do f:SetAlpha(on and 1 or 0.45) end
end

-- Leaving the page (or closing the book) ends moving the toast.
local function leave(pf)
  if ns.Toasts.moving then ns.Toasts:StopMove() end
  pf.toastPlace:Refresh()
end

ns.Pages:Register({ id = "settings", label = L.SETTINGS, build = build, refresh = refresh, leave = leave,
  free = true, anywhere = true, flat = true, header = "both", title = function() return L.SETTINGS, L.SUB_SETTINGS end })
