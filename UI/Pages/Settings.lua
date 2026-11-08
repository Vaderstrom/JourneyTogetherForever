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

-- One page's column: folding sections (U10, 31 Oct 2026: the page read as a wall of checkboxes), each a heading and
-- a body of rows and grids placed from the top down. A click on a heading opens or folds its section; folded, the
-- heading says in a few words what is set ("10 of 12 on"). Sections of one group (the right page's toasts and
-- tracker) take turns: opening one folds the other, so a page never needs scrolling. What is open is kept for the
-- character (ns.char.setFold).
local FOLD_ICON = UI.FOLD_ICON
local function column(pf, parent, width)
  local c = { sections = {} }
  -- A heading with its fold button; the section's body follows. sum() gives the folded line, foldedAtFirst the start.
  function c:Head(id, text, help, opts)
    opts = opts or {}
    local h = UI.SectionHeader(parent, width)
    h:SetText(text)
    h.text:ClearAllPoints(); h.text:SetPoint("LEFT", 20, 1)
    h.icon = h:CreateTexture(nil, "ARTWORK")
    h.icon:SetSize(16, 16); h.icon:SetPoint("LEFT", 0, 1)
    if help then h:SetHelp(help) end
    h.sum = UI.Text(h, 12, "ink2")
    h.sum:SetPoint("LEFT", h.help or h.text, "RIGHT", 8, 0)
    -- The fold button covers the icon and the title (the "?" and what sits at the right keep their own clicks).
    h.click = CreateFrame("Button", nil, h)
    h.click:SetPoint("TOPLEFT"); h.click:SetPoint("BOTTOMLEFT")
    h.click:SetScript("OnClick", function() pf:Fold(id) end)
    local sec = { id = id, head = h, body = CreateFrame("Frame", nil, parent), y = 0, group = opts.group, sum = opts.sum,
      folded = opts.folded == true }
    sec.body:SetWidth(width)
    c.sections[#c.sections + 1] = sec
    pf.sections[id] = sec
    c.cur = sec
    return h
  end
  function c:Gap() self.cur.y = self.cur.y + GAP end
  -- A row: the label (and its "?") on the left, the control at the right.
  function c:Row(label, control, help)
    local sec = self.cur
    local r = CreateFrame("Frame", nil, sec.body)
    r:SetSize(width, ROW)
    r:SetPoint("TOPLEFT", 0, -sec.y)
    r.label = UI.Text(r, 13, "ink")
    r.label:SetPoint("LEFT")
    r.label:SetText(label)
    if help then
      r.help = UI.HelpIcon(r)
      r.help:SetPoint("LEFT", r.label, "RIGHT", 6, 0)
      r.help:SetHelp(label, help)
    end
    -- On the row, so it folds away with its section.
    control:SetParent(r)
    control:ClearAllPoints()
    control:SetPoint("RIGHT", r, "RIGHT", 0, 0)
    pf.controls[#pf.controls + 1] = control
    sec.y = sec.y + ROW
    return r
  end
  -- A small checkbox with its label after it: the toasts' and the tracker's lists, two to a line.
  local function tick(label, get, set, help)
    local f = CreateFrame("Frame", nil, c.cur.body)
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
    local sec, out = self.cur, {}
    for i, it in ipairs(items) do
      local f = tick(it[1], it[2], it[3])
      f:SetPoint("TOPLEFT", ((i - 1) % 2) * width / 2, -(sec.y + math.floor((i - 1) / 2) * GRID))
      out[it.key or i] = f
    end
    sec.y = sec.y + math.ceil(#items / 2) * GRID
    return out
  end
  function c:Tick(label, get, set, help)
    local sec = self.cur
    local f = tick(label, get, set, help)
    f:SetWidth(width)
    f:SetPoint("TOPLEFT", 0, -(sec.y + 1))
    sec.y = sec.y + GRID + 2
    return f
  end
  function c:Skip(n) self.cur.y = self.cur.y + n end
  -- A small heading inside a section (the toasts' three groups, U86). With get and set, a tick before it that turns
  -- the whole group on or off (U116), in line with the ticks under it.
  function c:Sub(text, get, set)
    local sec = self.cur
    local t = UI.Text(sec.body, 11, "accent", "title")
    t:SetPoint("TOPLEFT", get and 21 or 0, -(sec.y + 6)); t:SetText(text:upper())
    if get then
      t.box = UI.Checkbox(sec.body, get, set)
      t.box:SetSize(22, 22); t.box:SetPoint("RIGHT", t, "LEFT", -2, 0)
      pf.controls[#pf.controls + 1] = t.box
    end
    sec.y = sec.y + 22
    return t
  end

  local function folded(sec)
    local st = ns.char and ns.char.setFold
    if st and st[sec.id] ~= nil then return st[sec.id] end
    return sec.folded
  end
  -- Places the sections from the top down; returns the column's height.
  function c:Layout()
    local y = 0
    for i, sec in ipairs(self.sections) do
      local h, shut = sec.head, folded(sec)
      h:ClearAllPoints(); h:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -y)
      if not h.icon:SetTexture(FOLD_ICON[shut]) then h.icon:SetColorTexture(0, 0, 0, 0) end
      h.click:SetWidth(20 + h.text:GetStringWidth() + 4)
      local line = shut and sec.sum and sec.sum() or ""
      h.sum:SetText(line)
      h.sum:SetShown(line ~= "")
      y = y + 31
      sec.body:SetShown(not shut)
      if not shut then
        sec.body:ClearAllPoints(); sec.body:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -y)
        sec.body:SetHeight(math.max(1, sec.y))
        y = y + sec.y
      end
      if i < #self.sections then y = y + GAP end
    end
    self.y = y
    return y
  end
  -- The tallest this column gets: every section open, but only the tallest of a group (they take turns).
  function c:MaxHeight()
    local y, groups = 0, {}
    for i, sec in ipairs(self.sections) do
      y = y + 31 + (i < #self.sections and GAP or 0)
      if sec.group then groups[sec.group] = math.max(groups[sec.group] or 0, sec.y) else y = y + sec.y end
    end
    for _, h in pairs(groups) do y = y + h end
    return y
  end
  return c
end

local function build(pf)
  local width = W.PAGE_W - 8
  pf.controls, pf.sections = {}, {}
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
  local THEMES = { journal = L.THEME_JOURNAL, night = L.THEME_NIGHT, faction = L.THEME_FACTION }
  left:Head("book", L.SET_BOOK, nil, { sum = function() return THEMES[Settings:Get("theme")] or "" end })
  left:Row(L.THEME, dropdown(Lp, { { L.THEME_JOURNAL, "journal" }, { L.THEME_NIGHT, "night" }, { L.THEME_FACTION, "faction" } }, "theme"), L.THEME_HINT)
  local function langNote() return Settings:Get("lang") == "sv" and L.LANG_NOTE_SV or L.LANG_NOTE_EN end
  pf.lang = left:Row(L.LANGUAGE, UI.Dropdown(Lp, 150, { { L.LANG_EN, "en" }, { L.LANG_SV, "sv" } }, function() return Settings:Get("lang") end,
    function(v) Settings:Set("lang", v); pf.lang.help:SetHelp(L.LANGUAGE, langNote()) end), langNote())
  pf.fullBox = UI.Checkbox(Lp, check("fullscreen"))
  left:Row(L.FULLSCREEN, pf.fullBox, L.FULLSCREEN_HINT)
  left:Row(L.SOUNDS, UI.Checkbox(Lp, check("sounds")), L.SOUNDS_HINT)
  left:Row(L.REDUCE_EFFECTS, UI.Checkbox(Lp, check("reduce")), L.REDUCE_EFFECTS_HINT)
  local CHATS = { all = L.CHAT_ALL, important = L.CHAT_IMPORTANT, off = L.CHAT_OFF }
  left:Head("messages", L.SET_MESSAGES, nil,
    { sum = function() return L.SET_SUM_CHAT:format(CHATS[Settings:Get("chat")] or "") end })
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
  left:Head("help", L.SET_HELP)
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
  left:Row(L.KEY_PAGE, dropdown(Lp, { { L.NAV_CHAPTER, "chapter" }, { L.NAV_OVERVIEW, "overview" }, { L.NAV_HEROES, "heroes" },
    { L.NAV_QUESTS, "quests" }, { L.NAV_GATHERINGS, "gatherings" }, { L.NAV_CHRONICLE, "chronicle" }, { L.NAV_RAIDS, "raids" } },
    "keyPage"), L.KEY_PAGE_HINT)
  -- The commands, two to a line: the command in the accent colour, what it does after it.
  left:Skip(4)
  local helpSec = left.cur
  for i, cmd in ipairs(ns.COMMANDS) do
    local x, y = ((i - 1) % 2) * width / 2, -(helpSec.y + math.floor((i - 1) / 2) * 15)
    local code = UI.Text(helpSec.body, 12, "accent")
    code:SetPoint("TOPLEFT", x, y)
    code:SetText(cmd[1])
    local what = UI.Text(helpSec.body, 12, "ink2")
    what:SetPoint("LEFT", code, "RIGHT", 8, 0)
    what:SetText(cmd[2])
  end
  left:Skip(math.ceil(#ns.COMMANDS / 2) * 15)

  -- Right: the progress toasts and the tracker.
  local Rp = pf.right
  local right = column(pf, Rp, width)
  local function count(list, on)
    local n = 0
    for _, k in ipairs(list) do if on(k) then n = n + 1 end end
    return n
  end
  local toasts = right:Head("toasts", L.PROGRESS_TOASTS, L.PROGRESS_TOASTS_HINT, { group = "right", sum = function()
    local t = Settings.TOAST_EVENTS
    return L.SET_SUM_ON:format(count(t, function(k) return Settings:ToastOn(k) end), #t)
  end })
  pf.example = UI.TextButton(Rp, L.EXAMPLE_TOAST, function() ns.Toasts:Example() end, "link", 12)
  pf.example:SetPoint("BOTTOMRIGHT", toasts, "BOTTOMRIGHT", 0, 7)
  -- Under three short headings (U86): your journey, the fellowship, dungeons and raids.
  pf.toastRows, pf.toastHeads = {}, {}
  for _, g in ipairs(Settings.TOAST_GROUPS) do
    pf.toastHeads[#pf.toastHeads + 1] = right:Sub(L[g[1]], function()
      for _, kind in ipairs(g[2]) do if not Settings:ToastOn(kind) then return false end end
      return true
    end, function(v)
      for _, kind in ipairs(g[2]) do Settings:SetToast(kind, v) end
      ns.Window:Refresh()
    end)
    local items = {}
    for _, kind in ipairs(g[2]) do
      -- (Redrawn, so the group's tick and the count in the heading follow.)
      items[#items + 1] = { L["TOAST_" .. kind:upper()], function() return Settings:ToastOn(kind) end,
        function(v) Settings:SetToast(kind, v); ns.Window:Refresh() end, key = kind }
    end
    for kind, f in pairs(right:Grid(items)) do pf.toastRows[kind] = f.box end
  end
  right:Skip(2)
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
  -- The tracker: turned on at the heading; its lines and how it behaves under it, faded while it is off. Folded at
  -- first: the toasts and the tracker take turns.
  local tracker = right:Head("tracker", L.TRACKER, L.TRACKER_HINT, { group = "right", folded = true, sum = function()
    if not Settings:Get("tracker") then return L.SET_SUM_OFF end
    local t = Settings.TRACKER_LINES
    return L.SET_SUM_LINES:format(count(t, function(k) return Settings:TrackerLineOn(k) end), #t)
  end })
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
  right:Skip(4)
  local function opt(label, key, help, default)
    local get = default and function() return Settings:Get(key) ~= false end or function() return Settings:Get(key) end
    local f = right:Tick(label, get, function(v) Settings:Set(key, v) end, help)
    pf.trackerParts[#pf.trackerParts + 1] = f
    return f.box
  end
  pf.trackerDock = opt(L.TRACKER_DOCK, "trackerDock", L.TRACKER_DOCK_HINT)
  pf.trackerHover = opt(L.TRACKER_HOVER, "trackerHover", L.TRACKER_HOVER_HINT)
  pf.trackerPeek = opt(L.TRACKER_PEEK, "trackerPeek", L.TRACKER_PEEK_HINT, true)
  pf.trackerCombat = opt(L.TRACKER_HIDE_COMBAT, "trackerHideCombat")
  pf.trackerInstance = opt(L.TRACKER_HIDE_INSTANCE, "trackerHideInstance", L.TRACKER_HIDE_INSTANCE_HINT)
  -- Other addons the book opens (6 Nov 2026): whose stories the dungeons' story button tells.
  local FROM = { spoken = L.SPOKEN, lore = L.LORE_FOREVER }
  right:Head("addons", L.SET_ADDONS, nil, { sum = function() return FROM[Settings:Get("storyFrom")] or "" end })
  right:Row(L.STORY_FROM, dropdown(Rp, { { L.SPOKEN, "spoken" }, { L.LORE_FOREVER, "lore" } }, "storyFrom"), L.STORY_FROM_HINT)
  pf.heights = { left = left:MaxHeight(), right = right:MaxHeight() }
  function pf.layout() left:Layout(); right:Layout() end
  -- Opens or folds a section; opening one of a group folds the others.
  function pf:Fold(id, open)
    local sec = self.sections[id]
    if not sec or not ns.char then return end
    local st = ns.char.setFold or {}
    ns.char.setFold = st
    local shut = sec.body:IsShown()
    if open ~= nil then shut = not open end
    st[id] = shut
    if not shut and sec.group then
      for oid, other in pairs(self.sections) do if oid ~= id and other.group == sec.group then st[oid] = true end end
    end
    self.layout()
  end
  pf.layout()
end

local function refresh(pf)
  for _, c in ipairs(pf.controls) do c:Refresh() end
  pf.toastPlace:Refresh()
  pf.lang.help:SetHelp(L.LANGUAGE, Settings:Get("lang") == "sv" and L.LANG_NOTE_SV or L.LANG_NOTE_EN)
  local on = Settings:Get("tracker") and true or false
  for _, f in ipairs(pf.trackerParts) do f:SetAlpha(on and 1 or 0.45) end
  pf.layout()
end

-- Leaving the page (or closing the book) ends moving the toast.
local function leave(pf)
  if ns.Toasts.moving then ns.Toasts:StopMove() end
  pf.toastPlace:Refresh()
end

ns.Pages:Register({ id = "settings", label = L.SETTINGS, build = build, refresh = refresh, leave = leave,
  free = true, anywhere = true, flat = true, header = "both", title = function() return L.SETTINGS, L.SUB_SETTINGS end })
