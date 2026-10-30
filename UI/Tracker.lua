-- The tracker (M22, SPEC §5): a small panel on the screen, outside the book, like the game's quest tracker. It shows
-- the chapter, its status, where you stand, the next step, who is online and the next Gathering, so the book need
-- not be opened to know what to do. Drag it by its title; click the title to fold it to one line; click a line to
-- open the book there. Settings → Tracker turns it off. Built at login, out of combat (it is not a secure frame,
-- so it shows and updates during combat too).
local _, ns = ...
local L = ns.L
local UI, Theme, Combat, Settings = ns.UI, ns.Theme, ns.Combat, ns.Settings
-- 280 wide and a short title ("II · The Wailing and the Wolf"): "Chapter 2: The Wailing and th..." was cut off.
local TK = { WIDTH = 280, EVERY = 30, SOON = 24 * 3600 }
ns.Tracker = TK

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
    b.text = UI.WrapText(b, spec[2], spec[3], self.WIDTH - 20, "body")
    b.text:SetPoint("TOPLEFT")
    b.key, b.page = spec[1], spec[4]
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints(); hl:SetColorTexture(1, 0.85, 0.45, 0.08)
    b:SetScript("OnClick", function()
      if b.page == "inbox" then ns.Window:OpenPanel("inbox") else ns.Window:Open(b.page) end
    end)
    f.lines[i] = b
  end
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
  return f
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
  return {
    title = ch and L.TRACKER_TITLE:format(ns.Journey.Roman(cur), ch.name) or L.BN_JOURNEY_DONE,
    status = status, statusColor = banner.color,
    you = you.head, next = nextText, clears = clears, run = run, quests = quests,
    online = #online > 0 and L.TRACK_ONLINE:format(#online, table.concat(online, ", ")) or L.TRACK_NOBODY,
    gather = gather, duel = duel, inbox = waiting > 0 and (waiting == 1 and L.TRACK_INBOX_1 or L.TRACK_INBOX_N:format(waiting)) or nil,
    xp = pct, color = f.color, emblem = f.emblem,
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
  fr.crest:Set(c.color, c.emblem)
  fr.title:SetText(c.title)
  local folded = ns.char.trackerFolded == true
  fr.fold:SetText(folded and "+" or "-")
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
  for _, b in ipairs(fr.lines) do b:EnableMouse(not invisible) end
  fr.invisible = invisible
  local showBar = not folded and Settings:TrackerLineOn("bar") and c.xp ~= nil
  fr.xp:SetShown(showBar)
  if showBar then fr.xp:SetValue(c.xp) end
  local y = showBar and 38 or 34
  for _, b in ipairs(fr.lines) do
    local text = not folded and Settings:TrackerLineOn(b.key) and c[b.key] or nil
    b:SetShown(text ~= nil)
    if text then
      b.text:SetText(text)
      if b.key == "status" then b.text:SetTextColor(ns.Hex(c.statusColor or "D8B060")) end
      local h = b.text:GetStringHeight()
      b:SetHeight(h)
      b:ClearAllPoints(); b:SetPoint("TOPLEFT", fr, "TOPLEFT", 10, -y)
      y = y + h + 5
    end
  end
  fr:SetHeight((folded or y <= 38) and (showBar and 34 or 30) or y + 4)
  fr:Show()
end

function TK:SetFolded(on)
  ns.char.trackerFolded = on and true or nil
  self:Refresh()
end

function TK:ResetPosition()
  ns.char.trackerPos = nil
  if self.frame then place(self.frame) end
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
