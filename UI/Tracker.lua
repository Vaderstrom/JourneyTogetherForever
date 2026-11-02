-- The tracker (M22, SPEC §5): a small panel on the screen, outside the book, like the game's quest tracker. It shows
-- the chapter, its status, where you stand, the next step, who is online and the next Gathering, so the book need
-- not be opened to know what to do. Drag it by its title; click the title to fold it to one line; click a line to
-- open the book there. Settings → Tracker turns it off. Built at login, out of combat (it is not a secure frame,
-- so it shows and updates during combat too).
-- Under the game's quest tracker (Settings, on by default; the owner, 2 Nov 2026): one more section under the
-- game's quest list, with the game's own section header and fold button, its fonts and its background. A real
-- section of the game's tracker would taint it (its quest item buttons then fail in combat), so this is our own
-- frame anchored under it and following it with hooks only: nothing of the game's tracker is changed.
local _, ns = ...
local L = ns.L
local UI, Theme, Combat, Settings = ns.UI, ns.Theme, ns.Combat, ns.Settings
-- 280 wide and a short title ("II · The Wailing and the Wolf"): "Chapter 2: The Wailing and th..." was cut off.
local TK = { WIDTH = 280, EVERY = 30, SOON = 24 * 3600 }
ns.Tracker = TK
-- Each line's icon (U13): the book's own painted icons for what the line is about.
TK.ICON = 14
TK.LINE_ICONS = { status = "chapter", you = "heroes", next = "overview", clears = "toast_clear", run = "raids",
  quests = "quests", online = "characters", gather = "gatherings", duel = "tourney", inbox = "inbox" }
-- Docked under the game's tracker: the game's section header (26 high), how far its background reaches left of its
-- sections (when the game cannot say), how dark our background is at the game's Opacity 100%, and the game's line
-- colours, one step brighter so they read over the world without a background (the owner, 2 Nov 2026: the grey and
-- the blue were hard to see over grass): white lines, light grey for the quieter ones, gold lines in the game's gold.
TK.DOCK_TEMPLATE, TK.DOCK_HEAD, TK.DOCK_X, TK.DOCK_SHADE = "ObjectiveTrackerModuleHeaderTemplate", 26, 30, 0.75
TK.DOCK_COLORS = { toastText = { 1, 1, 1 }, muted = { 0.8, 0.8, 0.8 }, goldText = { 1, 0.82, 0 } }
-- The chapter's status in the game's own bright colours, by stage (the book's are dark, for its paper; its blue was
-- hard to read over the world): the game's yellow while levelling together, orange below the floor, green when the
-- dungeons are open or the chapter is done, grey before it starts.
TK.STATUS_COLORS = { level = { 1, 0.82, 0 }, milestones = { 1, 0.82, 0 }, floor = { 1, 0.5, 0.25 }, run = { 0.25, 1, 0.25 },
  done = { 0.25, 1, 0.25 }, ["end"] = { 0.25, 1, 0.25 }, later = { 0.75, 0.75, 0.75 } }

local function place(f)
  f:ClearAllPoints()
  local p = ns.char.trackerPos
  if p and p.point then f:SetPoint(p.point, UIParent, p.rel or p.point, p.x or 0, p.y or 0)
  -- Under the minimap's height: at -260 it lay over the minimap's left edge (seen in the check, 29 Oct 2026).
  else f:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -240, -390) end
end

function TK:Build()
  if self.frame then return self.frame end
  local f = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
  f:SetWidth(self.WIDTH)
  f:SetFrameStrata("MEDIUM")
  f:SetClampedToScreen(true)
  f:SetMovable(true)
  f:SetBackdrop({ bgFile = ns.WHITE, edgeFile = ns.WHITE, edgeSize = 1 })
  Theme:Backdrop(f, "dark", 0.72, "gold", 0.55)
  -- The title bar: crest, chapter, fold mark. Drag to move, click to fold.
  local bar = CreateFrame("Button", nil, f)
  bar:SetPoint("TOPLEFT"); bar:SetPoint("TOPRIGHT"); bar:SetHeight(30)
  bar:RegisterForDrag("LeftButton")
  bar:SetScript("OnDragStart", function() f:StartMoving() end)
  bar:SetScript("OnDragStop", function()
    f:StopMovingOrSizing()
    local point, _, rel, x, y = f:GetPoint()
    ns.char.trackerPos = { point = point, rel = rel, x = x, y = y }
  end)
  bar:SetScript("OnClick", function() TK:SetFolded(not ns.char.trackerFolded) end)
  local shade = UI.GradientTex(bar, "BACKGROUND", "VERTICAL", { "band2", 0.9 }, { "band1", 0.9 })
  shade:SetPoint("TOPLEFT", 1, -1); shade:SetPoint("BOTTOMRIGHT", -1, 0)
  f.crest = UI.Crest(bar, 20, 24)
  f.crest:SetPoint("LEFT", 6, 0)
  f.title = UI.Text(bar, 13, "goldText", "title")
  f.title:SetPoint("LEFT", 36, 0); f.title:SetWidth(self.WIDTH - 60)
  f.title:SetShadowOffset(1, -1); f.title:SetShadowColor(0, 0, 0, 1)
  f.fold = UI.Text(bar, 13, "gold", "title", "CENTER")
  f.fold:SetPoint("RIGHT", -8, 0)
  f.bar = bar
  -- Your XP toward the next level: a slim bar under the title (Settings: "Your XP bar").
  f.xp = CreateFrame("StatusBar", nil, f)
  f.xp:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", 1, 0); f.xp:SetPoint("TOPRIGHT", bar, "BOTTOMRIGHT", -1, 0)
  f.xp:SetHeight(3)
  f.xp:SetStatusBarTexture(ns.WHITE)
  f.xp:SetMinMaxValues(0, 1)
  Theme:Register(function() f.xp:SetStatusBarColor(Theme:RGBA("gold", 0.9)) end)
  f.xp.bg = f.xp:CreateTexture(nil, "BACKGROUND")
  f.xp.bg:SetAllPoints(); f.xp.bg:SetColorTexture(0, 0, 0, 0.6)
  -- The lines: { key, size, role, page }. A click opens the book on the page the line is about.
  f.lines = {}
  for i, spec in ipairs({ { "status", 12, nil, "chapter" }, { "you", 12, "toastText", "overview" },
    { "next", 12, "toastText", "overview" }, { "clears", 11, "toastText", "chapter" }, { "run", 12, "goldText", "chapter" },
    { "quests", 11, "toastText", "quests" }, { "online", 11, "muted", "heroes" }, { "gather", 11, "muted", "gatherings" },
    { "duel", 11, "goldText", "tourney" }, { "inbox", 11, "goldText", "inbox" } }) do
    local b = CreateFrame("Button", nil, f)
    b:SetWidth(self.WIDTH - 20)
    -- Each line's small round icon in front (U13, 31 Oct 2026: the tracker read as a block of small text).
    b.icon = UI.Round(b, "ARTWORK", TK.ICON)
    b.icon:SetPoint("TOPLEFT", 0, -1)
    b.hasIcon = UI.SetIcon(b.icon, ns.ICONS[TK.LINE_ICONS[spec[1]] or "toast_default"])
    b.icon:SetShown(b.hasIcon)
    local indent = b.hasIcon and TK.ICON + 6 or 0
    b.text = UI.WrapText(b, spec[2], spec[3], self.WIDTH - 20 - indent, "body")
    b.text:SetPoint("TOPLEFT", indent, 0)
    b.key, b.page, b.role, b.font = spec[1], spec[4], spec[3], { b.text:GetFont() }
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints(); hl:SetColorTexture(1, 0.85, 0.45, 0.08)
    b:SetScript("OnClick", function()
      if b.page == "inbox" then ns.Window:OpenPanel("inbox") else ns.Window:Open(b.page) end
    end)
    f.lines[i] = b
  end
  -- Under "you": a little bar to the floor (below it, red) or from the floor to the cap (U13).
  f.floorBar = UI.Bar(f, 6)
  f.floorBar:Hide()
  -- Hidden mode (Settings): a light check of whether the mouse is over the tracker's place, a few times a second
  -- (its lines take the mouse too, so OnEnter/OnLeave of the frame alone flicker; and an invisible tracker takes no
  -- clicks, so the mouse falls through to the world).
  f.hoverCheck = 0
  f:SetScript("OnUpdate", function(_, elapsed)
    if not Settings:Get("trackerHover") then return end
    f.hoverCheck = f.hoverCheck + elapsed
    if f.hoverCheck < 0.1 then return end
    f.hoverCheck = 0
    local over = f:IsMouseOver() and true or false
    if over ~= f.over then f.over = over; TK:Refresh() end
  end)
  f:Hide()
  self.frame = f
  place(f)
  -- After the panel's colours above (painters run in order): docked, its own look comes back after every repaint.
  Theme:Register(function() TK:PaintDocked() end)
  if Settings:Get("trackerDock") then self:BuildDock() end
  return f
end

-- The game's quest tracker (Blizzard_ObjectiveTracker, the same in Forever), when it has the parts we sit under: its
-- background (NineSlice) and its header. nil in a client without them: the panel then stays where it is.
function TK:GameTracker()
  local ot = ObjectiveTrackerFrame
  if type(ot) == "table" and ot.NineSlice and ot.Header and ot.IsCollapsed then return ot end
  return nil
end

-- Our section's header: our own copy of the game's section header. Made the first time it is wanted, out of combat;
-- then the hooks that follow the game's tracker (observed only: it is never written to).
function TK:BuildDock()
  local fr, ot = self.frame, self:GameTracker()
  if not fr or fr.dock or fr.noDock or not ot or (InCombatLockdown and InCombatLockdown()) then return end
  if not (C_XMLUtil and C_XMLUtil.GetTemplateInfo and C_XMLUtil.GetTemplateInfo(self.DOCK_TEMPLATE)) then return end
  local head = CreateFrame("Frame", nil, fr, self.DOCK_TEMPLATE)
  head:Hide()
  -- A header made differently: the panel stays, and no new header is made at every refresh (code review, 2 Nov 2026).
  if not (head.Text and head.MinimizeButton and head.SetCollapsed) then fr.noDock = true return end
  head:SetPoint("TOPLEFT")
  local function fold() TK:SetFolded(not ns.char.trackerFolded) end
  head.MinimizeButton:SetScript("OnClick", fold)
  -- The title folds it too, like the panel's title bar.
  head.click = CreateFrame("Button", nil, head)
  head.click:SetPoint("TOPLEFT"); head.click:SetPoint("BOTTOMRIGHT", -24, 0)
  head.click:SetScript("OnClick", fold)
  fr.dock = head
  local function follow() if TK:Docked() then TK:Place() end end
  hooksecurefunc(ot, "SetCollapsed", function() if TK:Docked() then TK:Refresh() end end)
  ot:HookScript("OnShow", follow); ot:HookScript("OnHide", follow)
  ot.NineSlice:HookScript("OnShow", follow); ot.NineSlice:HookScript("OnHide", follow)
  -- Edit Mode's Opacity and Text Size for the game's tracker: ours follows them (the lines' heights change with the
  -- text size).
  for _, method in ipairs({ "SetOpacity", "SetTextSize" }) do
    if ObjectiveTrackerManager and ObjectiveTrackerManager[method] then
      hooksecurefunc(ObjectiveTrackerManager, method, function() if TK:Docked() then TK:Refresh() end end)
    end
  end
end

-- Under the game's quest tracker now: asked for in Settings, and the game's tracker is there to sit under.
function TK:Docked()
  return Settings:Get("trackerDock") == true and self.frame ~= nil and self.frame.dock ~= nil and self:GameTracker() ~= nil
end

function TK:DockWidth()
  local w = self:GameTracker():GetWidth()
  return (w and w >= 200 and w <= 400) and math.floor(w + 0.5) or 260
end

-- Where the tracker is: its own place, or docked right under the game's quest list (where its background ends; under
-- its header when the list is empty, as in Edit Mode; in its place when the game's tracker is hidden). Anchored to
-- the game's tracker, so it follows it as it grows, shrinks and moves.
function TK:Place()
  local fr = self.frame
  if not fr then return end
  if not self:Docked() then place(fr) return end
  local ot = self:GameTracker()
  fr:ClearAllPoints()
  if not ot:IsVisible() then
    fr:SetPoint("TOPLEFT", ot, "TOPLEFT")
  elseif ot.NineSlice:IsShown() then
    local a, b = ot:GetLeft(), ot.NineSlice:GetLeft()
    fr:SetPoint("TOPLEFT", ot.NineSlice, "BOTTOMLEFT", (a and b) and (a - b) or self.DOCK_X, 0)
  else
    fr:SetPoint("TOPLEFT", ot.Header, "BOTTOMLEFT", 0, -4)
  end
end

-- The look for where it is: our panel (title bar, crest, dark box with a gold edge, the book's fonts) or the game's
-- section (its header, its fonts, no edge). Run when it moves from one to the other.
function TK:Restyle(docked)
  local fr = self.frame
  local head = docked and fr.dock or fr.bar
  fr.bar:SetShown(not docked)
  if fr.dock then fr.dock:SetShown(docked) end
  fr:SetFrameStrata(docked and "LOW" or "MEDIUM")
  fr:SetWidth(docked and self:DockWidth() or self.WIDTH)
  fr.xp:ClearAllPoints()
  fr.xp:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 1, docked and -2 or 0)
  fr.xp:SetPoint("TOPRIGHT", head, "BOTTOMRIGHT", docked and -10 or -1, docked and -2 or 0)
  -- The game's line font follows its Text Size setting; back in the panel, the book's font (without the game's shadow).
  for _, b in ipairs(fr.lines) do
    if docked and ObjectiveTrackerLineFont then
      b.text:SetFontObject(ObjectiveTrackerLineFont)
      -- A solid black shadow, so the words stand out from bright ground.
      b.text:SetShadowColor(0, 0, 0, 1); b.text:SetShadowOffset(1, -1)
    elseif not docked and b.font[1] then
      b.text:SetFont(b.font[1], b.font[2], b.font[3])
      b.text:SetShadowOffset(0, 0)
      if b.role then b.text:SetTextColor(Theme:RGBA(b.role)) end
    end
  end
  if not docked then
    fr:SetBackdropColor(Theme:RGBA("dark", 0.72)); fr:SetBackdropBorderColor(Theme:RGBA("gold", 0.55))
  end
end

-- Docked colours: a background only as dark as the game tracker's Opacity, no edge, the lines in the game's bright
-- colours (the status line has its own). Also after every repaint of the book's colours: the book repaints them when
-- its page changes (its accent), and that turned the docked tracker into the dark panel with a gold edge (a click on
-- a line opened the book; the owner's check, 2 Nov 2026).
function TK:PaintDocked()
  local fr, ot = self.frame, self:GameTracker()
  if not (fr and fr.docked and ot) then return end
  fr:SetBackdropColor(0, 0, 0, self.DOCK_SHADE * (ot.NineSlice:GetAlpha() or 0))
  fr:SetBackdropBorderColor(0, 0, 0, 0)
  for _, b in ipairs(fr.lines) do
    if b.key ~= "status" then b.text:SetTextColor(unpack(self.DOCK_COLORS[b.role] or self.DOCK_COLORS.toastText)) end
  end
end

-- What the tracker says now: { title, status, statusColor, you, next, online, gather }, or nil outside a fellowship.
function TK:Content(f)
  if not f then return nil end
  local J, T, G = ns.Journey, ns.Together, ns.Gatherings
  local cur = J:CurrentIndex(f)
  local ch = f.journey.chapters[cur]
  local banner = J:Banner(f, cur)
  local you = T:You(f)
  local steps = J:NextSteps(f)
  local online = {}
  for _, name in ipairs(T:Online(f)) do online[#online + 1] = ns.Short(name) end
  local gather
  for _, g in ipairs(G:Upcoming(f)) do
    if g.at >= time() - 3600 and g.at - time() <= self.SOON then gather = L.TRACK_GATHER:format(G.When(g.at), G.What(g)) break end
  end
  -- After the last chapter the title already says the journey is complete (the tour showed it four times): the
  -- status points at the Endgame instead, and there is no next step to repeat it.
  local status, nextText = banner.title, steps[1] and steps[1].text or nil
  -- With others online, the next step is Play now's (M25).
  local play = ch and T:PlayNow(f)
  if play then nextText = play.text end
  if not ch then status, nextText = L.TOAST_ENDGAME, nil end
  local me = ns.Me()
  -- The chapter's required dungeons cleared.
  local clears
  if ch then
    local req, done = J:Required(f, cur), 0
    for _, x in ipairs(req) do if J:Cleared(f, x.key) then done = done + 1 end end
    if #req > 0 then clears = L.TRACK_CLEARS:format(done, #req) end
  end
  -- Inside a dungeon of the journey (or a raid of the Endgame): your bosses there.
  local run
  local inside = IsInInstance()
  if inside then
    local iname, _, _, _, _, _, _, instID = GetInstanceInfo()
    for _, base in ipairs(ns.Clears:KeysHere(instID, iname)) do
      for _, key in ipairs(ns.Clears:Placements(f, base)) do
        if not run and ns.Endgame:Tracked(f, key) then
          local n, of = ns.Clears:Progress(f, key, me)
          local d = ns.Dungeon(key)
          if of > 0 then run = L.TRACK_RUN:format(d and d[2] or key, n, of) end
        end
      end
    end
  end
  -- Quests you share with others now.
  local together = {}
  for _, x in ipairs(ns.Quests:Items(f)) do if x.together and not x.chain then together[#together + 1] = x.name end end
  local quests = #together > 0 and L.TRACK_QUESTS:format(#together, together[1]) or nil
  -- The tournament: your next duel.
  local duel
  if f.tourney and f.tourney.phase == "running" then
    local m, other = ns.Tourney:MyMatch(f, me)
    if m and other then duel = L.TRACK_DUEL:format(ns.Short(other)) end
  end
  local waiting = ns.Inbox and ns.Inbox:Count() or 0
  local pct = ns.Hero:XP(f, me)
  -- The little bar under "you" (U13): below the floor, the way from the chapter before's floor to this one; else
  -- from the floor to the cap. Your XP into the level counts.
  local bar
  if ch then
    local lvl = ns.Hero:Level(f, me) + (pct or 0)
    local fl = J:FloorLevel(f, ch)
    if lvl < fl then
      local prev = cur > 1 and f.journey.chapters[cur - 1] and J:FloorLevel(f, f.journey.chapters[cur - 1]) or 1
      bar = { value = (lvl - prev) / math.max(1, fl - prev), color = "B0321E" }
    else
      bar = { value = (lvl - fl) / math.max(1, ch.cap - fl), color = lvl >= ch.cap and "D8B060" or "3E9A52" }
    end
    bar.value = ns.Clamp(bar.value, 0, 1)
  end
  return {
    title = ch and L.TRACKER_TITLE:format(ns.Journey.Roman(cur), ch.name) or L.BN_JOURNEY_DONE,
    status = status, statusColor = banner.color, stage = banner.stage,
    you = you.head, next = nextText, clears = clears, run = run, quests = quests,
    online = #online > 0 and L.TRACK_ONLINE:format(#online, table.concat(online, ", ")) or L.TRACK_NOBODY,
    gather = gather, duel = duel, inbox = waiting > 0 and (waiting == 1 and L.TRACK_INBOX_1 or L.TRACK_INBOX_N:format(waiting)) or nil,
    xp = pct, color = f.color, emblem = f.emblem, bar = bar,
  }
end

-- Is the tracker hidden now, whatever it says (Settings: in combat, inside dungeons)?
function TK:Away()
  if Settings:Get("trackerHideCombat") and (Combat:InCombat() or (InCombatLockdown and InCombatLockdown())) then return true end
  if Settings:Get("trackerHideInstance") then
    local inside, kind = IsInInstance()
    if inside and kind ~= "none" then return true end
  end
  return false
end

TK.PEEK = 6 -- seconds the hidden tracker shows itself after a change

function TK:Refresh()
  local fr = self.frame
  if not fr then return end
  local f = ns.Fellowship:Current()
  local c = Settings:Get("tracker") ~= false and not self:Away() and self:Content(f)
  if not c then fr:Hide() return end
  if Settings:Get("trackerDock") and not fr.dock then self:BuildDock() end
  local docked = self:Docked()
  if docked ~= (fr.docked or false) then
    fr.docked = docked
    self:Restyle(docked)
    self:Place()
  end
  -- Docked, it folds away with the game's tracker, like the game's own sections.
  if docked and self:GameTracker():IsCollapsed() then fr:Hide() return end
  local folded = ns.char.trackerFolded == true
  if docked then
    fr.dock.Text:SetText(c.title)
    fr.dock:SetCollapsed(folded)
    self:PaintDocked()
  else
    fr.crest:Set(c.color, c.emblem)
    fr.title:SetText(c.title)
    fr.fold:SetText(folded and "+" or "-")
  end
  -- Hidden mode: completely invisible (and letting clicks through) until pointed at; when something in it changes,
  -- it shows itself for PEEK seconds (Settings), then goes again. (It used to stay as a faint title bar.)
  local parts = {}
  for _, b in ipairs(fr.lines) do parts[#parts + 1] = tostring(Settings:TrackerLineOn(b.key) and c[b.key] or "") end
  local sig = c.title .. "|" .. table.concat(parts, "|")
  local hiddenMode = Settings:Get("trackerHover") == true
  if hiddenMode and Settings:Get("trackerPeek") ~= false and fr.sig and sig ~= fr.sig then
    fr.peekUntil = GetTime() + self.PEEK
    C_Timer.After(self.PEEK + 0.1, function() TK:Refresh() end)
  end
  fr.sig = sig
  local peeking = fr.peekUntil and GetTime() < fr.peekUntil
  local invisible = hiddenMode and not fr.over and not peeking
  fr:SetAlpha(invisible and 0 or 1)
  fr.bar:EnableMouse(not invisible)
  if fr.dock then fr.dock.click:EnableMouse(not invisible); fr.dock.MinimizeButton:EnableMouse(not invisible) end
  for _, b in ipairs(fr.lines) do b:EnableMouse(not invisible) end
  fr.invisible = invisible
  local showBar = not folded and Settings:TrackerLineOn("bar") and c.xp ~= nil
  fr.xp:SetShown(showBar)
  if showBar then fr.xp:SetValue(c.xp) end
  -- Docked: the line icons stand where the game's quest map buttons do, the words in line with its quest titles.
  local top, left = docked and self.DOCK_HEAD or 30, docked and 0 or 10
  local width = docked and self:DockWidth() or self.WIDTH
  local y = top + (showBar and 8 or 4)
  fr.floorBar:Hide()
  for _, b in ipairs(fr.lines) do
    local text = not folded and Settings:TrackerLineOn(b.key) and c[b.key] or nil
    b:SetShown(text ~= nil)
    if text then
      local indent = b.hasIcon and self.ICON + 6 or 0
      b:SetWidth(width - left - 10); b.text:SetWidth(width - left - 10 - indent)
      b.text:SetText(text)
      local bright = b.key == "status" and self.STATUS_COLORS[c.stage]
      if bright then b.text:SetTextColor(unpack(bright))
      elseif b.key == "status" then b.text:SetTextColor(ns.Hex(c.statusColor or "D8B060")) end
      local h = math.max(b.text:GetStringHeight(), b.hasIcon and self.ICON or 0)
      b:SetHeight(h)
      b:ClearAllPoints(); b:SetPoint("TOPLEFT", fr, "TOPLEFT", left, -y)
      y = y + h + 5
      if b.key == "you" and c.bar then
        local bw = width - left - 10 - indent
        fr.floorBar:ClearAllPoints(); fr.floorBar:SetPoint("TOPLEFT", fr, "TOPLEFT", left + indent, -(y - 2))
        fr.floorBar:SetColor(c.bar.color)
        fr.floorBar:Set(bw, c.bar.value)
        fr.floorBar:Show()
        y = y + 8
      end
    end
  end
  fr:SetHeight((folded or y <= top + 8) and (showBar and top + 4 or top) or y + 4)
  fr:Show()
end

function TK:SetFolded(on)
  ns.char.trackerFolded = on and true or nil
  self:Refresh()
end

function TK:ResetPosition()
  ns.char.trackerPos = nil
  self:Place()
end

ns:On("LOGIN", function()
  Combat:AfterCombat(function()
    TK:Build(); TK:Refresh()
    C_Timer.NewTicker(TK.EVERY, function() TK:Refresh() end)
  end)
end)
-- Like the book: one redraw per burst of news from other Heroes.
function TK:RefreshSoon()
  if self.soon or not self.frame then return end
  self.soon = true
  C_Timer.After(ns.Window.SOON, function() self.soon = nil; self:Refresh() end)
end

for _, event in ipairs({ "FELLOWSHIP", "JOINED" }) do ns:On(event, function() TK:Refresh() end) end
ns:On("HEROES", function(now) if now then TK:Refresh() else TK:RefreshSoon() end end)
ns:On("SETTING", function(key) if key == "theme" or key == "toasts" or tostring(key):find("^tracker") then TK:Refresh() end end)
-- Combat, entering and leaving dungeons (hide there), and XP and the inbox (its lines).
for _, event in ipairs({ "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA",
  "PLAYER_XP_UPDATE" }) do
  ns:RegisterEvent(event, function() TK:RefreshSoon() end)
end
