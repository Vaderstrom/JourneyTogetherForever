-- /jtf lab: the test lab, a menu for the developer (not in /jtf help or /jtf debug help; 28 Oct 2026). A card beside
-- the book with four tabs:
--   Checks     /jtf check: everything, checks only, screenshots only, or one feature area (Dev/Areas.lua)
--   Scenarios  the book in a state to look at by hand: a Lab fellowship with pretend Adventurers (Brannic, Elyra,
--              Corwin) on a character without a fellowship. End the lab removes it all again.
--   Events     one pretend Adventurer does one thing now (only in the Lab or the Test fellowship), and the client's
--              switches: pretend combat, held messages, a toast, the sync line
--   Tests      the in-game tests card (/jtf tests): how far it is, open it at any section, restart
-- Developer text (like the check's and the in-game tests' steps), so it lives here and not in Locales.
local _, ns = ...
local UI = ns.UI
local Lab = { tab = "scenarios" }
ns.Lab = Lab

local CARD_W, CARD_H, PAD = 560, 560, 16
local PRETEND = { "Brannic", "Elyra", "Corwin" }

local function cur() return ns.Fellowship:Current() end
local function full(name) return ns.FullName(name) end
local function dev(cmd) ns.Dev:Command(cmd) end
local function say(text) ns:Print("Lab: " .. text, true) end
local function open(page) ns.Window:Open(page) end

---------------------------------------------------------------------------
-- The Lab fellowship
---------------------------------------------------------------------------
-- The Lab fellowship, when it is the current one (or the Test fellowship joined in "Getting started as an Adventurer").
function Lab:Fellowship()
  local f, lab = cur(), ns.db and ns.db.lab
  return f and type(lab) == "table" and f.id == lab.fid and f or nil
end

-- May pretend Adventurers act here? In the Lab, the Test fellowship (/jtf debug invite) or the self-test's.
function Lab:Pretend()
  local f = cur()
  return f ~= nil and (self:Fellowship() == f or f.id == ns.Dev.TEST_ID or f.name == "Selftest")
end

-- Everything the lab changed, back as it was: your level and pace, the group, the pretend switches; the Lab
-- fellowship ends (the pretend Adventurers go first, so you leave alone).
function Lab:End(quiet)
  dev("level off"); dev("pace off"); dev("group off"); dev("tourney off")
  if ns.Comm.encounter then dev("hold off") end
  if ns.Combat.simulated then ns.Combat:SetSimulated(false) end
  ns.Dev:WatchForget()
  if ns.Walkthrough then ns.Walkthrough:Stop() end
  local f = self:Fellowship()
  if f then
    if f.leader ~= ns.Me() then
      ns.Comm:Inject(f.leader, "OP", { fid = f.id, v = f.v + 1, op = { k = "lead", name = ns.Me() }, t = time() })
    end
    for name in pairs(f.members) do if name ~= ns.Me() then ns.Fellowship:Remove(name) end end
    ns.Fellowship:Leave()
  end
  -- An invitation from the getting-started scenarios that was never answered, or a join still on its way.
  if ns.char and ns.char.invites then ns.char.invites[ns.Dev.TEST_ID] = nil end
  ns.Fellowship.pendingJoin[ns.Dev.TEST_ID] = nil
  ns.db.lab = nil
  if not quiet then say("ended; everything is as it was.") end
  self:Refresh()
end

-- A new Lab fellowship (the last one ended first), with the pretend Adventurers unless alone.
local function fresh(alone)
  if Lab:Fellowship() then Lab:End(true) end
  ns.Fellowship.pendingJoin[ns.Dev.TEST_ID] = nil -- a getting-started join still on its way would land in this one
  local f = cur()
  if f then say(("you are in %s. Scenarios make a Lab fellowship: use a character without one."):format(f.name)) return nil end
  if ns.Combat:InCombat() then say("not during combat.") return nil end
  f = ns.Fellowship:Create({ name = "Lab", role = "Tank", preset = "classic" })
  if not f then return nil end
  ns.db.lab = { fid = f.id, started = time() }
  if not alone then
    for _, n in ipairs(PRETEND) do ns.Dev:Fake(n); dev("hero " .. n .. " accept") end
  end
  return f
end

-- Everyone (you too) at a level, past the Prologue: chapter II (15-21) is the current chapter.
local function levels(me, others)
  for _, n in ipairs(PRETEND) do dev("hero " .. n .. " level " .. (others and others[n] or me)) end
  dev("level " .. me)
end

-- The first dungeon the current chapter needs (The Deadmines for the Alliance; the Horde's own).
local function firstDungeon(f)
  local list = ns.Journey:Required(f, ns.Journey:CurrentIndex(f))
  return list[1] and list[1].key
end

---------------------------------------------------------------------------
-- Scenarios: { title, what you should see, function }
---------------------------------------------------------------------------
-- Getting started, from before you are in a fellowship to your first steps in one (as the Leader or an Adventurer).
local function outside()
  if Lab:Fellowship() then Lab:End(true) end
  ns.Fellowship.pendingJoin[ns.Dev.TEST_ID] = nil
  local f = cur()
  if f then say(("you are in %s. Getting started needs a character without a fellowship."):format(f.name)) return false end
  return true
end

-- The start pages without a fellowship: "welcome" or "join".
local function start(view) ns.Window.startView = view; ns.Window:Open(); ns.Window:Refresh() end

-- Testleader invites you to the Test fellowship (/jtf debug invite); it waits in the inbox.
local function invited()
  if not outside() then return false end
  dev("invite")
  return true
end

-- The Overview once you are in the Test fellowship: Testleader answers the accept after a moment, and a fixed second
-- could open the book before the fellowship had come (30 Oct 2026).
local function whenJoined(tries)
  local f = cur()
  if f and f.id == ns.Dev.TEST_ID then open("overview"); Lab:Refresh() return end
  if tries <= 0 then say("Testleader did not answer the invitation: try the scenario again.") return end
  C_Timer.After(0.25, function() whenJoined(tries - 1) end)
end

Lab.SCENARIOS = {
  { "Getting started: Welcome", "No fellowship: the Welcome page, Create a Fellowship and Join, Your characters.", function()
    if outside() then start("welcome") end
  end },
  { "Getting started: an invitation", "Testleader invites you: the inbox badge, the Join page with Accept / Decline and your role.", function()
    if invited() then C_Timer.After(0.3, function() start("join") end) end
  end },
  { "Getting started as an Adventurer", "You accept the invitation as DPS: the Welcome to the fellowship card on the Overview (Chapter, rules, quests).", function()
    if not invited() then return end
    ns.db.lab = { fid = ns.Dev.TEST_ID, started = time() }
    C_Timer.After(0.3, function()
      ns.Fellowship:AcceptInvite(ns.Dev.TEST_ID, "DPS")
      whenJoined(20)
    end)
  end },
  { "Getting started as the Leader", "A new fellowship, alone: Getting started on the Overview, the Prologue on the Chapter page.", function()
    if fresh(true) then open("overview") end
  end },
  { "The setup guide", "The three steps a new fellowship shows once: Look, While you play, Reminders.", function()
    if fresh(true) and ns.SetupGuide then ns.SetupGuide:Open("overview") end
  end },
  { "Waiting for the floor", "Corwin at 13, the rest at 16: the stage track at its first stage, the waiting box.", function()
    if fresh() then levels(16, { Corwin = 13 }); open("chapter") end
  end },
  { "Dungeons open", "Everyone at 17: the dungeons open, Find group on each row.", function()
    if fresh() then levels(17); open("chapter") end
  end },
  { "A dungeon partly cleared", "One boss of the first dungeon killed with the group: partly done.", function()
    local f = fresh()
    if not f then return end
    levels(17)
    for _, n in ipairs(PRETEND) do dev("group " .. n) end
    local key = firstDungeon(f)
    if key then dev("kill " .. key .. " 1") end
    dev("group off")
    open("chapter")
  end },
  { "The next chapter unlocks", "Every dungeon marked cleared: the big banner, chapter III.", function()
    local f = fresh()
    if not f then return end
    levels(20)
    local n = ns.Journey:CurrentIndex(f)
    for _, x in ipairs(ns.Journey:Required(f, n)) do
      if not ns.Journey:Cleared(f, x.key) then ns.Clears:Mark(x.key) end
    end
    open("chapter")
  end },
  { "A newcomer catching up", "Fenna joins at level 2 in chapter III: catching up, not holding the dungeons.", function()
    local f = fresh()
    if not f then return end
    levels(22)
    f.reached = math.max(f.reached or 1, 3)
    local fen = full("Fenna")
    ns.Dev:Fake("Fenna")
    ns.Fellowship:Do({ k = "invite", name = fen })
    ns.Comm:Inject(fen, "ACC", { fid = f.id, role = "DPS", class = "DRUID", level = 2 })
    open("chapter")
  end },
  { "You over the cap", "You two levels over the cap: the warning, the inbox, the Chronicle.", function()
    local f = fresh()
    if not f then return end
    levels(17)
    local ch = ns.Journey:Current(f)
    dev("level " .. (ch.cap + 2))
    open("overview")
  end },
  { "An open vote", "Brannic proposes a change: the rulebook, the vote with Yes / No.", function()
    if fresh() then levels(17); dev("hero Brannic propose"); open("rules") end
  end },
  { "A Gathering soon", "Corwin plans one in 16 minutes: the list, the reminder after about a minute.", function()
    if fresh() then levels(17); dev("hero Corwin gather"); open("gatherings") end
  end },
  { "Presence and versions", "Brannic quiet with an old addon, Elyra AFK, Corwin offline.", function()
    if not fresh() then return end
    levels(17)
    dev("hero Elyra version 0.9.2"); dev("hero Brannic version 0.9.0")
    dev("hero Brannic quiet"); dev("hero Elyra afk"); dev("hero Corwin offline")
    open("heroes")
  end },
  { "The Endgame (raids)", "The journey done: Raids in the sidebar, Molten Core and the rest.", function()
    local f = fresh()
    if not f then return end
    levels(60)
    f.reached = #f.journey.chapters + 1
    open("raids")
  end },
  { "A tournament running", "Everyone signed up, the first round on: the bracket.", function()
    if not fresh() then return end
    levels(17)
    dev("tourney on"); dev("tourney start")
    ns.Tourney:SignUp(true)
    for _, n in ipairs(PRETEND) do dev("hero " .. n .. " signup") end
    dev("tourney next")
    open("tourney")
  end },
  { "You as an Adventurer", "Brannic leads: no Admin, the rulebook with Propose, Leave on the Adventurers page.", function()
    if not fresh() then return end
    levels(17)
    ns.Fellowship:MakeLeader(full("Brannic"))
    open("rules")
  end },
  { "Following another character", "A pretend alt's fellowship, followed live (read only).", function()
    if Lab:Fellowship() then Lab:End(true) end
    open("overview")
    dev("watch")
  end },
}

---------------------------------------------------------------------------
-- Events: one pretend Adventurer does one thing now. { label, function(name, f) }
---------------------------------------------------------------------------
local function level(f, name) return ns.Hero:Level(f, full(name)) end
local function floorOf(f) return ns.Journey:FloorLevel(f, f.journey.chapters[ns.Journey:CurrentIndex(f)] or f.journey.chapters[1]) end

Lab.EVENTS = {
  { "Level +1", function(n, f) dev(("hero %s level %d"):format(n, level(f, n) + 1)) end },
  { "To the floor", function(n, f) dev(("hero %s level %d"):format(n, floorOf(f))) end },
  { "Below the floor", function(n, f) dev(("hero %s level %d"):format(n, math.max(1, floorOf(f) - 3))) end },
  { "Online", function(n) dev("hero " .. n .. " online") end },
  { "AFK", function(n) dev("hero " .. n .. " afk") end },
  { "Quiet (addon off)", function(n) dev("hero " .. n .. " quiet") end },
  { "Offline", function(n) dev("hero " .. n .. " offline") end },
  { "Old addon", function(n) dev("hero " .. n .. " version 0.9.0") end },
  { "Proposes a vote", function(n) dev("hero " .. n .. " propose") end },
  { "Votes Yes", function(n) dev("hero " .. n .. " vote yes") end },
  { "Votes No", function(n) dev("hero " .. n .. " vote no") end },
  { "Plans a Gathering", function(n) dev("hero " .. n .. " gather") end },
  { "Asks to group up", function(n) dev("hero " .. n .. " ask") end },
  { "Shares quests", function(n) dev("hero " .. n .. " quests") end },
  { "Kills a boss", function(n, f)
    local key = firstDungeon(f)
    if key then dev("group " .. n); dev("hero " .. n .. " kill " .. key) end
  end },
  { "Away", function(n) dev("hero " .. n .. " away") end },
  { "Back", function(n) dev("hero " .. n .. " away off") end },
  { "Takes the lead", function(n) ns.Fellowship:MakeLeader(full(n)) end },
  { "Gives the lead back", function(n) dev("hero " .. n .. " lead") end },
  { "Publishes rules", function(n) dev("hero " .. n .. " rules") end },
  { "Publishes a journey", function(n) dev("hero " .. n .. " journey") end },
  { "Leaves", function(n) dev("hero " .. n .. " leave") end },
  { "Joins", function(n) ns.Dev:Fake(n); dev("hero " .. n .. " accept") end },
}

-- The client's switches (any fellowship).
Lab.SWITCHES = {
  { "Pretend combat on / off", function() dev("combat") end },
  { "Hold messages on / off", function() dev(ns.Comm.encounter and "hold off" or "hold on") end },
  { "The sync line", function() dev("sync") end },
  { "A sample toast", function() dev("toast") end },
  { "A session recap (15 min with your group)", function() dev("session") end },
  { "An invite with no answer (share window)", function() dev("share Kim") end },
  { "Since you were last here", function() dev("since") end },
  { "Show me around (Leader)", function() if ns.Walkthrough then ns.Window:Open("overview"); ns.Walkthrough:Start("leader") end end },
  { "Show me around (Adventurer)", function() if ns.Walkthrough then ns.Window:Open("overview"); ns.Walkthrough:Start("member") end end },
}

---------------------------------------------------------------------------
-- The card
---------------------------------------------------------------------------
local TABS = { { "Checks", "checks" }, { "Scenarios", "scenarios" }, { "Events", "events" }, { "Tests", "tests" } }

local function heading(parent, text, y)
  local t = UI.Text(parent, 12, "gold", "body")
  t:SetPoint("TOPLEFT", 0, -y)
  t:SetText(text:upper())
  return y + 20
end

local function note(parent, width, text, y)
  local t = UI.WrapText(parent, 12, "toastText", width, "body")
  t:SetPoint("TOPLEFT", 0, -y)
  t:SetText(text)
  return t, y + t:GetStringHeight() + 8
end

-- Buttons in rows that wrap at the width; returns the y under them.
local function flow(parent, width, y, buttons)
  local x = 0
  for _, b in ipairs(buttons) do
    local w = b:GetWidth()
    if x > 0 and x + w > width then x, y = 0, y + 30 end
    b:ClearAllPoints(); b:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
    x = x + w + 6
  end
  return y + 34
end

local function buildChecks(p, width)
  local y = 0
  local function run(text)
    return function()
      if Lab:Fellowship() then Lab:End(true) end
      SlashCmdList.JOURNEYTOGETHERFOREVER("check " .. text)
    end
  end
  p.why, y = note(p, width, "The check runs on a character without a fellowship (a Lab fellowship ends first). " ..
    "/reload when it is done, then: luajit tools/check-report.lua.", y)
  y = heading(p, "Everything", y)
  y = flow(p, width, y, {
    UI.TextButton(p, "Checks and screenshots", run(""), "primary", 12),
    UI.TextButton(p, "Checks only", run("quick"), "plain", 12),
    UI.TextButton(p, "Screenshots only", run("shots"), "plain", 12),
    UI.TextButton(p, "List the areas", function() SlashCmdList.JOURNEYTOGETHERFOREVER("check areas") end, "plain", 12),
    UI.TextButton(p, "Layout of this page", function() ns.Layout:Report() end, "plain", 12),
  })
  y = heading(p, "One area: every check, and that area's screenshots", y)
  p.areas = {}
  for _, a in ipairs(ns.CheckAreas.LIST) do
    local b = UI.TextButton(p, a.key, run(a.key), "plain", 11)
    UI.Tooltip(b, a.title)
    p.areas[#p.areas + 1] = b
  end
  return flow(p, width, y, p.areas)
end

local function buildScenarios(p, width)
  local y = 0
  p.why, y = note(p, width, "Each scenario starts a new Lab fellowship (you, Brannic, Elyra and Corwin) on a character " ..
    "without one, and opens the page to look at. End the lab (below) puts everything back.", y)
  for _, s in ipairs(Lab.SCENARIOS) do
    local b = UI.TextButton(p, s[1], function() s[3](); Lab:Refresh() end, "plain", 12)
    b:SetPoint("TOPLEFT", 0, -y)
    local d = UI.WrapText(p, 11, "toastText", width - 200, "body")
    d:SetPoint("TOPLEFT", 200, -(y + 2))
    d:SetText(s[2])
    y = y + math.max(30, d:GetStringHeight() + 12)
  end
  return y
end

local function buildEvents(p, width)
  p.why = UI.WrapText(p, 12, "toastText", width, "body")
  p.why:SetPoint("TOPLEFT", 0, 0)
  local y = heading(p, "Who", 36)
  p.who = {}
  for i = 1, 6 do
    p.who[i] = UI.TextButton(p, "", function(b) Lab.target = b.name; Lab:Refresh() end, "plain", 12)
  end
  p.whoY = y
  y = y + 34
  y = heading(p, "Does", y)
  p.events = {}
  for i, e in ipairs(Lab.EVENTS) do
    p.events[i] = UI.TextButton(p, e[1], function()
      local f = cur()
      if not Lab:Pretend() or not Lab.target or not f then return end
      e[2](Lab.target, f)
      Lab:Refresh()
    end, "plain", 11)
  end
  y = flow(p, width, y, p.events)
  y = heading(p, "The client", y)
  local sw = {}
  for i, s in ipairs(Lab.SWITCHES) do sw[i] = UI.TextButton(p, s[1], function() s[2](); Lab:Refresh() end, "plain", 11) end
  y = flow(p, width, y, sw)
  return y
end

local function buildTests(p, width)
  local M = ns.Manual
  p.progress = UI.WrapText(p, 13, "toastText", width, "body")
  p.progress:SetPoint("TOPLEFT", 0, 0)
  local y = flow(p, width, 44, {
    UI.TextButton(p, "Open the card", function() M:Open(); Lab:Refresh() end, "primary", 12),
    UI.TextButton(p, "Next unmarked step", function() M:Open(M:NextOpen(1) or 1); Lab:Refresh() end, "plain", 12),
    UI.TextButton(p, "Close the card", function() M:Close(); Lab:Refresh() end, "plain", 12),
    UI.TextButton(p, "Restart (clears the marks)", function() M:Command("restart"); Lab:Refresh() end, "danger", 12),
  })
  y = heading(p, "Open at a section", y)
  local seen = {}
  p.sections = {}
  for i, s in ipairs(ns.ManualSteps) do
    if not seen[s.section] then
      seen[s.section] = true
      p.sections[#p.sections + 1] = UI.TextButton(p, s.section, function() M:Open(i); Lab:Refresh() end, "plain", 11)
    end
  end
  y = flow(p, width, y, p.sections)
  local _, y2 = note(p, width, "The report: /reload, then luajit tools/manual-report.lua with the SavedVariables file " ..
    "and the Screenshots folder.", y)
  return y2
end

local function build()
  if Lab.card then return true end
  if ns.Combat:InCombat() then return false end
  local c = UI.Box(UIParent, 2, nil, nil, "gold", 1)
  c:SetSize(CARD_W, CARD_H)
  c:SetFrameStrata("DIALOG")
  c:SetClampedToScreen(true)
  c:EnableMouse(true)
  c:SetMovable(true)
  c:RegisterForDrag("LeftButton")
  c:SetScript("OnDragStart", function(self) self:StartMoving() end)
  c:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local p, _, rp, x, y = self:GetPoint()
    ns.db.labPos = { p, rp, x, y }
  end)
  local bg = UI.GradientTex(c, "BACKGROUND", "VERTICAL", { "dark", 0.97 }, { "toastTop", 0.97 })
  bg:SetPoint("TOPLEFT", 2, -2); bg:SetPoint("BOTTOMRIGHT", -2, 2)
  c.title = UI.Text(c, 16, "goldText", "title")
  c.title:SetPoint("TOPLEFT", PAD, -12)
  c.title:SetText("Test lab")
  c.close = UI.TextButton(c, "Close", function() Lab:Close() end, "link", 12)
  c.close:SetPoint("TOPRIGHT", -10, -9)
  -- Tabs: a word each, the chosen one with a gold bar under it.
  c.tabs = {}
  local x = PAD
  for i, t in ipairs(TABS) do
    local b = UI.TextButton(c, t[1], function() Lab.tab = t[2]; Lab:Refresh() end, "link", 13)
    b:SetPoint("TOPLEFT", x, -40)
    b.key = t[2]
    b.bar = UI.Solid(b, "ARTWORK", "gold", 1)
    b.bar:SetHeight(2); b.bar:SetPoint("BOTTOMLEFT", 0, -3); b.bar:SetPoint("BOTTOMRIGHT", 0, -3)
    c.tabs[i] = b
    x = x + b:GetWidth() + 18
  end
  local line = UI.Solid(c, "ARTWORK", "gold", 0.35)
  line:SetHeight(1); line:SetPoint("TOPLEFT", PAD, -70); line:SetPoint("TOPRIGHT", -PAD, -70)
  -- One scrolling page per tab.
  local width = CARD_W - 2 * PAD - 12
  c.pages = {}
  local builders = { checks = buildChecks, scenarios = buildScenarios, events = buildEvents, tests = buildTests }
  for _, t in ipairs(TABS) do
    local s = UI.Scroll(c)
    s:SetPoint("TOPLEFT", PAD, -80); s:SetPoint("BOTTOMRIGHT", -PAD, 52)
    s:SetContentHeight(builders[t[2]](s.child, width) + 8)
    c.pages[t[2]] = s
  end
  -- What the lab sees, and the way back.
  c.status = UI.WrapText(c, 12, "toastText", CARD_W - 2 * PAD - 150, "body")
  c.status:SetPoint("BOTTOMLEFT", PAD, 14)
  c.endLab = UI.TextButton(c, "End the lab", function() Lab:End() end, "danger", 12)
  c.endLab:SetPoint("BOTTOMRIGHT", -PAD, 12)
  c:Hide()
  Lab.card = c
  local pos = ns.db.labPos
  if type(pos) == "table" and pos[1] then c:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
  else c:SetPoint("LEFT", UIParent, "LEFT", 40, 60) end
  return true
end

function Lab:Refresh()
  local c = self.card
  if not c or not c:IsShown() then return end
  for _, b in ipairs(c.tabs) do b.bar:SetShown(b.key == self.tab) end
  for key, s in pairs(c.pages) do s:SetShown(key == self.tab) end
  local f, labF = cur(), self:Fellowship()
  -- Status.
  local lab = labF and ("Lab fellowship: chapter %d, %d Adventurers."):format(ns.Journey:CurrentIndex(labF), ns.Fellowship:Count(labF))
  c.status:SetText(lab or (f and ("You are in %s (not a Lab fellowship)."):format(f.name)) or "No fellowship on this character.")
  c.endLab:SetEnabled(true)
  -- Events: who can act, and on whom.
  local ev = c.pages.events.child
  local can = self:Pretend()
  ev.why:SetText(can and "A pretend Adventurer does one thing now, through the real messages." or
    "Pretend Adventurers act only in the Lab fellowship (Scenarios) or the Test fellowship (/jtf debug invite).")
  local names = {}
  if can then
    for _, name in ipairs(ns.Fellowship:Members(f)) do if name ~= ns.Me() then names[#names + 1] = ns.Short(name) end end
  end
  local ok = false
  for _, n in ipairs(names) do if n == self.target then ok = true end end
  if not ok then self.target = names[1] end
  local shown = {}
  for i, b in ipairs(ev.who) do
    local n = names[i]
    b:SetShown(n ~= nil)
    if n then
      b.name = n
      b:SetLabel(n == self.target and ("> " .. n .. " <") or n)
      shown[#shown + 1] = b
    end
  end
  flow(ev, CARD_W - 2 * PAD - 12, ev.whoY, shown)
  for _, b in ipairs(ev.events) do b:SetEnabled(can and self.target ~= nil) end
  -- Tests.
  local M = ns.Manual
  local okN, bad, done = M:Counts()
  c.pages.tests.child.progress:SetText(("In-game tests: %d of %d marked (%d work, %d problems).%s"):format(done, #ns.ManualSteps,
    okN, bad, M.on and " The card is open." or ""))
end

function Lab:Open()
  if not build() then say("not during combat.") return end
  self.card:Show()
  self:Refresh()
end

function Lab:Close() if self.card then self.card:Hide() end end

function Lab:Toggle()
  if self.card and self.card:IsShown() then self:Close() else self:Open() end
end

-- Pages and pretend news change what the lab shows.
ns:On("HEROES", function() Lab:Refresh() end)
ns:On("FELLOWSHIP", function() Lab:Refresh() end)
