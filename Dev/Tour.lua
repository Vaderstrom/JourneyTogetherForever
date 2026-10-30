-- /jtf tour: a screenshot of every page, tab, overlay, panel, state, toast, theme and size, as a player would see
-- them, for a review of the UI (docs/TEST-COVERAGE.md lists every feature with its shot). Runs on a character without a fellowship, like /jtf selftest: it visits Welcome,
-- Found a fellowship and Join, joins a pretend fellowship as a member, then founds a "Tour" fellowship with pretend
-- Heroes and goes through everything as the leader, and disbands it at the end. Nothing reaches real players.
-- Each screenshot is listed in JourneyTogetherForeverDB.tour.shots (number, id, title, what it shows, time), saved
-- with the next /reload; tools/tour-manifest.lua prints the list with the matching screenshot files.
local _, ns = ...
local L = ns.L
local TR = { SETTLE = 0.7, GAP = 1.3, SKIP = 0.25 } -- SKIP: a shot of another area (its screen, no picture)
ns.Tour = TR

local PRETEND = { "Brannic", "Elyra", "Corwin" }
-- The fellowship the tour founds: its name, banner colour and emblem (nil: your side's). /jtf brand gives it a name
-- and a banner that look well in the README's pictures.
TR.TOUR_LOOK = { name = "Tour", color = ns.BANNERS[3] and ns.BANNERS[3][2] }
TR.look = TR.TOUR_LOOK
local W = function() return ns.Window end
local function cur() return ns.Fellowship:Current() end
local function dev(cmd) ns.Dev:Command(cmd) end
local function full(name) return ns.FullName(name) end
local function page(id) W():ShowPage(id) end
local function pf(id) return W().pageFrames[id] end

-- Scrolls a scroll frame to its end. Returns "same" when there is nothing to scroll (the shot would repeat the one
-- before it, which looked like a skipped picture; seen in a review).
local function bottom(sf)
  if not sf then return "same" end
  local to = math.max(0, (sf.contentHeight or 0) - (sf:GetHeight() or 0))
  if to < 4 then return "same" end
  sf:SetVerticalScroll(to)
  local wheel = sf:GetScript("OnMouseWheel")
  if wheel then wheel(sf, 0) end
end
local function top(sf) if sf then sf:SetVerticalScroll(0) end end

local function hideOverlays()
  local w = W()
  for _, o in pairs(w.overlays or {}) do o:Hide() end
  if w.confirm then w.confirm:Hide() end
  if w.emblemPicker then w.emblemPicker:Hide() end
  if GameTooltip then GameTooltip:Hide() end
end

---------------------------------------------------------------------------
-- The shots: { id, title, what, fn (sets the screen up), toast = keep the toast, wait = extra seconds before }
---------------------------------------------------------------------------
local shots = {}
TR.shots = shots -- for /jtf check and tests/test_check.lua (every shot belongs to a feature area: Dev/Areas.lua)
local function shot(id, title, what, fn, opts)
  opts = opts or {}
  shots[#shots + 1] = { id = id, title = title, what = what, fn = fn, toast = opts.toast, wait = opts.wait }
end
-- A step without a screenshot (setting things up).
local function prep(fn, wait) shots[#shots + 1] = { fn = fn, wait = wait, prep = true } end

-- Phase A: no fellowship.
shot("welcome", "Welcome", "No fellowship: logo, features, Found / Join, Your characters", function()
  W().startView = "welcome"; W():Open(); W():Refresh()
end)
shot("controls-gallery", "The game's button art (gallery)", "Every candidate template and texture for WoW-style buttons; missing ones say so", function()
  ns.Gallery:Show()
end)
prep(function() ns.Gallery:Hide() end)
shot("characters-panel", "Your characters panel", "The header's characters button: every character with its fellowship", function()
  W():OpenPanel("characters")
end)
shot("create-1", "Create: step 1 (empty)", "Name, role and four size cards; on the right your banner, its colour and every emblem", function()
  W():HidePanels(); ns.CreateState:Reset(); W().startView = "create"; W():Refresh()
end)
shot("create-1-filled", "Create: step 1 (filled)", "With a name and the Tank role", function()
  local C = ns.CreateState
  C.name, C.role, C.color = TR.look.name, TR.look.role or "Tank", TR.look.color or C.color
  C.emblem = TR.look.emblem or C.emblem
  W():Refresh()
end)
shot("emblem-picker", "Emblem picker", "Picture crests and the 16 heraldic emblems", function()
  local C = ns.CreateState
  W():PickEmblem(C.color, C.emblem, function(e) C.emblem = e end)
end)
shot("create-2", "Create: step 2 (play style)", "Relaxed / Together / Strict with their level strips; the chosen one's levels, key and rules in words", function()
  hideOverlays(); ns.CreateState.step = 2; ns.CreateState.fine = false; W():Refresh()
end)
shot("create-2-fine", "Create: step 2 (fine-tune)", "Every rule, left and right page, and the way back to the styles", function()
  ns.CreateState.fine = true; W():Refresh()
end)
shot("create-3", "Create: step 3 (journey)", "The journey tiles with their chapters; the chosen journey's chapters on the right page", function()
  ns.CreateState.fine = false; ns.CreateState.step = 3; W():Refresh()
end)
shot("create-3-own", "Create: step 3 (your own journey)", "Your own journey chosen: five steps, its chapters (a copy of Classic) on the right", function()
  ns.CreateState:ChooseOwn(); W():Refresh()
end)
shot("create-chapters", "Create: Chapters (the journey editor)", "The ruler with its gold marks, Split / Merge / Remove, chapters with dungeon chips; chapter II and its dungeons", function()
  local C = ns.CreateState
  C:Goto("chapters"); C.sel = 2; W():Refresh(); pf("create").editor:ShowTab("chapter")
end)
shot("create-chapters-shelf", "Create: Chapters (Every dungeon)", "The Every dungeon tab: every dungeon by level, gold where it fits chapter II", function()
  pf("create").editor:ScrollToShelf()
end)
shot("create-chapters-journey", "Create: Chapters (Whole journey)", "The Whole journey tab: Start over from a preset, Import", function()
  pf("create").editor:ShowTab("journey")
end)
shot("create-4", "Create: review", "The fellowship and the rules as rows (Change), the journey's chapters, Create the fellowship", function()
  ns.CreateState:Goto("review"); W():Refresh()
end)
shot("join-empty", "Join (no invitations)", "How to join", function() W().startView = "join"; W():Refresh() end)
shot("join-invite", "Join (an invitation)", "An invitation with Accept / Decline and the role", function()
  ns.Dev:Invite()
end, { wait = 0.5 })
shot("inbox-invite", "Inbox (an invitation)", "The header's inbox with the invitation", function() W():OpenPanel("inbox") end)

-- Phase B: a member of a pretend fellowship.
prep(function()
  W():HidePanels()
  ns.Fellowship:AcceptInvite(ns.Dev.TEST_ID, "Healer")
end, 1.5)
-- The welcome card: the pages this character visited in the test fellowship on an earlier run are forgotten (it
-- was gone from the shot; seen in the check of 29 Oct 2026).
shot("member-overview", "Member: Overview", "As a new member: the welcome card, no Manage or Leader pages", function()
  local f = cur()
  if f and type(ns.char.started) == "table" then ns.char.started[f.id] = nil end
  W():Open("overview"); page("overview")
end)
shot("member-chapter", "Member: Chapter", "As a member: no Mark cleared", function() page("chapter") end)
shot("member-heroes", "Member: Heroes", "The Hero list as a member", function() page("heroes") end)
shot("member-rules", "Member: Rules", "The rulebook (numbered articles, values in colour); Change a rule on the right: open votes, Propose", function() page("rules") end)
shot("member-rules-propose", "Member: Rules, proposing a change", "Another rule chosen, its values without today's, Propose", function()
  local p = pf("rules")
  p.pkey, p.pval = "minHeroes", nil
  W():Refresh()
end)
prep(function() pf("rules").pkey, pf("rules").pval = "floorTol", nil; ns.Fellowship:Leave() end, 1)

-- Phase C: the leader of a new fellowship (empty states).
prep(function()
  ns.Fellowship:Create({ name = TR.look.name, role = TR.look.role or "Tank", preset = "classic", color = TR.look.color, emblem = TR.look.emblem })
  W():Open("overview")
end, 0.5)
-- The setup guide a new Companion sees once (the tour marks it seen, so here it is opened by hand).
shot("setup-1", "Setup guide: Look", "The theme as picture tiles; the book changes at once", function() ns.SetupGuide:Open("overview") end)
shot("setup-2", "Setup guide: While you play", "Tracker, banners, chat messages and sounds", function()
  ns.SetupGuide.step = 2; W():Refresh()
end)
shot("setup-3", "Setup guide: Reminders", "Cap warning, picture moment, minimap button; Start the journey", function()
  ns.SetupGuide.step = 3; W():Refresh()
end)
shot("leader-overview-new", "Overview (new fellowship)", "Alone: Where you stand, Getting started, no Gatherings", function() page("overview") end)
shot("leader-chapter-new", "Chapter (new fellowship)", "The Prologue: the stage track and its picture in place of dungeons", function() page("chapter") end)
shot("leader-quests-empty", "Quests (alone)", "No shared quests", function() page("quests") end)
-- The Chronicle at All (the self-test leaves it at Sessions; seen in the check of 29 Oct 2026).
local function chronicle(filter) page("chronicle"); pf("chronicle").filter = filter; W():Refresh() end
shot("leader-chronicle-empty", "Chronicle (empty)", "Nothing yet, totals at zero; the Chronicle and Moments tabs", function() chronicle("all") end)
shot("leader-moments-empty", "Moments (empty)", "No moments yet: what the tab keeps", function() page("moments") end)
shot("leader-history-alone", "History (new fellowship)", "The fellowship's own story: founded, the numbers, its Leader", function()
  page("history"); pf("history").filter = "all"; W():Refresh()
end)
shot("leader-heroes-alone", "Heroes (alone)", "One Hero", function() page("heroes") end)
shot("leader-manage-alone", "Manage (alone)", "Its three tabs; the Adventurers tab: you, the invite box", function() page("manage") end)
shot("leader-rules", "Rules (leader)", "The rulebook; no votes yet; the Leader changes the rules in Manage", function() page("rules") end)
shot("leader-admin", "Journey Admin", "The journey editor: the ruler with its gold marks, chapters with dungeon chips, the This chapter tab; the bar at the bottom (Everything is published)", function()
  page("admin"); pf("admin").editor:ShowTab("chapter")
end)

-- Phase D: pretend Heroes, levels, runs, quests, votes, Gatherings, the tournament.
shot("manage-invite-open", "Manage (an open invite)", "Invite sent, received, waiting for an answer", function()
  page("manage")
  for _, n in ipairs(PRETEND) do ns.Dev:Fake(n) end
  ns.Fellowship:Invite("Brannic")
end, { wait = 0.3 })
prep(function()
  for _, n in ipairs(PRETEND) do dev("hero " .. n .. " accept") end
  -- /jtf brand: roles that fit their classes (they all join as DPS).
  for n, role in pairs(TR.look.roles or {}) do ns.Fellowship:SetRoles(full(n), role) end
  -- Everyone through the Prologue together first (levels 1-15): straight to 17 while the others were still at their
  -- own level put three "over the cap" lines in History (seen in the check run).
  dev("level 15")
  for _, n in ipairs(PRETEND) do dev("hero " .. n .. " level 15") end
  for _, n in ipairs(PRETEND) do dev("hero " .. n .. " level 17") end
  dev("pace 1800"); dev("level 18")
end, 0.5)
shot("overview-ready", "Overview (ready)", "Where you stand: the steps, your level between floor and cap, your next steps, the counts; where the Adventurers stand", function() page("overview") end)
shot("overview-catchup", "Overview (catch-up)", "You below the floor: catch-up with estimate and rested", function()
  dev("level 13"); page("overview")
end)
shot("chapter-waiting", "Chapter (waiting for the floor)", "The stage track; the waiting box with who is below the floor and how far; the dungeons dimmed below", function()
  page("chapter"); top(pf("chapter").lscroll)
end)
shot("overview-behind", "Overview (someone behind)", "The ones ahead see who is behind", function()
  dev("level 19"); dev("hero Corwin level 12"); page("overview")
end)
shot("overview-future", "Overview (a later chapter)", "Contents: a chapter ahead chosen", function()
  local p = pf("overview"); p.sel = 4; W():Refresh()
end)
shot("overview-left-bottom", "Overview (left page, scrolled)", "Contents and the chronicle", function()
  local p = pf("overview"); p.sel = nil; W():Refresh(); return bottom(p.lscroll)
end)
shot("since", "Since you were last here", "What changed, who levelled, where the fellowship stands now", function()
  ns.Since:Mark(); dev("hero Elyra level 19"); dev("hero Brannic level 20")
  ns.Since.current = ns.Since:Digest(cur()); page("since")
end)
shot("chapter", "Chapter", "The stage track, the banner, every dungeon as a row without scrolling, where the Adventurers stand", function()
  dev("hero Corwin level 17"); page("chapter"); top(pf("chapter").lscroll)
end)
-- M25: everyone at the floor and online: Play now names the dungeon two of you need.
shot("overview-playnow", "Overview (Play now)", "Play now: the one best thing to do with who is online, with one button", function()
  local p = pf("overview"); p.sel = nil; page("overview"); top(p.lscroll)
end)
-- (The Chapter page fits without scrolling since 28 Oct 2026: no scrolled shots of it.) The next three open the
-- Chapter page themselves: since Play now's shot came before them, they showed the Overview (check of 29 Oct 2026).
shot("chapter-tooltip", "Chapter (clears table tooltip)", "A column's full dungeon name", function()
  pf("chapter").sel = nil; page("chapter"); top(pf("chapter").lscroll)
  local col = pf("chapter").matrix.cols.items[3] or pf("chapter").matrix.cols.items[1]
  local enter = col and col:GetScript("OnEnter")
  if enter then enter(col) end
end)
-- (Chapter numbers count the Prologue, chapter I, since 27 Oct 2026.)
shot("chapter-next", "Chapter (next, not started)", "A chapter that is not open yet", function()
  if GameTooltip then GameTooltip:Hide() end
  -- The chapter after opening the page: ShowPage starts it at the current one (both shots showed Chapter III; check
  -- of 29 Oct 2026).
  local p = pf("chapter"); page("chapter"); p.sel = ns.Journey:CurrentIndex(cur()) + 1; W():Refresh()
  top(p.lscroll); top(p.rscroll)
end)
shot("chapter-later", "Chapter XIII (later, Blackrock Depths)", "Opens after Chapter XII, where the fellowship is now; one Blackrock Depths with 10 of its 21 bosses", function()
  local p = pf("chapter"); page("chapter"); p.sel = 13; W():Refresh(); top(p.lscroll); top(p.rscroll)
end)
shot("find-group", "Find group", "The toast after Find group", function()
  local p = pf("chapter"); p.sel = nil; W():Refresh()
  ns.Together:FindGroup(cur(), "dm")
end, { toast = true })
prep(function()
  for _, n in ipairs(PRETEND) do dev("group " .. n) end
  dev("kill dm 2")
end, 0.5)
shot("chapter-partial", "Chapter (a dungeon partly done)", "The Deadmines' row after two kills: how many bosses (the clears table shows only whole clears)", function()
  page("chapter"); top(pf("chapter").lscroll)
end)
shot("chronicle", "Chronicle (all)", "Runs with counted / not counted, the journey's dungeons so far", function() chronicle("all") end)
shot("chronicle-runs", "Chronicle (runs filter)", "Only runs", function()
  local p = pf("chronicle"); p.filter = "run"; W():Refresh()
end)
-- M25: a session recap kept for this character (a pretend one with Brannic and Elyra), as the toast's click opens it.
shot("chronicle-sessions", "Chronicle (Sessions)", "Your session recaps: how long, with whom, levels, dungeons, bosses, quests", function()
  local f, me = cur(), ns.Me()
  table.insert(ns.Session:List(), 1, { fid = f.id, start = time() - 5400, stop = time() - 300,
    with = { full("Brannic"), full("Elyra") }, levels = { { me, 18, 19 }, { full("Brannic"), 19, 20 } },
    quests = 6, bosses = 5, runs = { { key = "dm", cleared = false } }, chapters = {} })
  W():Open("chronicle#session")
end)
-- M25: an invite that got no answer from the player's addon (pretend: the no-answer path as after the wait).
shot("share-window", "Share the addon (no answer)", "Kim did not answer: the addon's page to copy and Whisper the link", function()
  page("heroes")
  ns.Share:Open(full("Kim"), true)
end)
shot("chapter-unlocked", "Chapter unlocked (big moment)", "The large banner over the book", function()
  hideOverlays()
  pf("chronicle").filter = "all"
  dev("kill dm")
  local f = cur()
  for _, x in ipairs(ns.Journey:Required(f, ns.Journey:CurrentIndex(f))) do if not ns.Journey:Cleared(f, x.key) then ns.Clears:Mark(x.key) end end
  dev("group off")
  ns.Picture:Hide() -- it has its own shot later
  page("overview")
end, { toast = true })
shot("undo-reopen-confirm", "Undo clear in an earlier chapter (leader)", "The question says the chapter opens again", function()
  page("chapter")
  local d, n = ns.Dungeon("dm"), cur().journey.place.dm and cur().journey.place.dm.ch or 2
  W():Confirm(L.UNDO_CONFIRM_REOPEN:format(d[2], ns.Journey.Roman(n), cur().journey.chapters[n].name), L.UNDO_CLEAR, function() end)
end)
-- Moments after the chapter: the chapter that began and the first clears, with a picture taken in The Deadmines.
shot("moments", "Moments", "The journey's moments as picture tiles; the chosen one large: what happened, who was there, your pictures", function()
  hideOverlays()
  ns.Moments:Picture(cur(), "dm")
  pf("moments").sel = nil
  page("moments")
end)
-- The group photo (UI/Photo.lua): you standing in for the pretend Adventurers, over the world, then in the studio
-- with poses and one chosen.
shot("group-photo", "Group photo (the world)", "The interface hidden; everyone side by side at true size, names under their feet, the crest and name top left, the controls at the bottom", function()
  hideOverlays()
  ns.Photo:Open({ standIns = true })
end, { wait = 0.8 })
shot("group-photo-studio", "Group photo (studio, poses)", "The studio backdrop; everyone cheering, the second one chosen (gold name) and saluting", function()
  local PH = ns.Photo
  PH:SetBackdrop("studio")
  PH:Choose(nil)
  PH:StepPose(2)
  if PH.cast[2] then PH:Choose(2); PH:StepPose(1) end
end, { wait = 0.8 })
shot("group-photo-twelve", "Group photo (twelve)", "Two rows of six, the back row between the heads in front; the camera a little higher; names under the front row's feet and over the back row's heads", function()
  local PH = ns.Photo
  PH:Close()
  PH.backdrop = "studio"
  PH:Open({ standIns = true, extra = ns.Dev:Crowd(cur(), 12) })
end, { wait = 0.8 })
shot("group-photo-look", "Group photo (look around)", "Over the world in first person, the controls gone; the hint and Back to the photo at the bottom", function()
  local PH = ns.Photo
  PH:SetBackdrop("world")
  PH:Look(true)
end, { wait = 1.5 }) -- the game's camera glides into first person (the check caught it on the way)
prep(function() ns.Photo:Close() end)
prep(function() hideOverlays() end)
prep(function()
  for _, n in ipairs(PRETEND) do dev("hero " .. n .. " level 22") end
  dev("level 22")
  dev("hero Brannic quests")
  local f = cur()
  ns.Comm:Inject(full("Elyra"), "QUESTS", { fid = f.id, q = { [5121] = { t = "High Chief Winterfall", z = "Winterspring", l = 56, h = 2, g = 8, k = true, o = "Winterfall Shaman slain" } },
    d = { 7848 }, ln = {}, t = time() })
end, 0.5)
shot("quests", "Quests (Quests tab)", "The Questie line; Together and You could join; your quest's details: progress, others, what you can do", function()
  page("quests"); local p = pf("quests"); p.tabs.buttons[2]:Click()
end)
shot("quests-join", "Quests (a quest you could join)", "Another Hero's quest you have not done: who has it, how to join", function()
  local p = pf("quests")
  for _, x in ipairs(ns.Quests:Items(cur())) do
    if x.join and not x.chain then p.sel = x.id; break end
  end
  W():Refresh()
end)
-- (No separate "quest chosen" shot: the Quests tab opens on your own quest's details, the "quests" shot.)
-- As a level 22 character: the level 2 quests are far off, hidden until Show all (on this low character there were
-- none, and the shot looked like the one before).
shot("quests-showall", "Quests (Show all)", "Far-off quests included, and the way back to near ones", function()
  ns.Quests.viewLevel = 22
  local p = pf("quests"); p.all = nil; p.sel = nil; W():Refresh()
  if p.showAll:IsShown() then p.showAll:Click() end
end)
shot("quests-chains", "Quests (Chains tab)", "Learned chains (often empty at first)", function()
  ns.Quests.viewLevel = nil
  local p = pf("quests"); p.all = nil; p.tabs.buttons[1]:Click()
end)
shot("quests-attune-none", "Quests (Attunements, level 30)", "None open yet: when the first one opens", function()
  ns.QuestLists.viewLevel = 30
  local p = pf("quests"); p.sel = nil; p.tabs.buttons[3]:Click()
end)
-- The row of an attunement on the Attunements tab, by its key (the list is sorted by start level).
local function attRow(key)
  for i, a in ipairs(ns.QuestLists:Attunements(ns.Fellowship:Current(), ns.Me())) do if a.key == key then return i end end
end
shot("quests-attune", "Quests (Attunements tab)", "The grid and Molten Core's steps (as seen at level 60)", function()
  ns.QuestLists.viewLevel = 60
  pf("quests").attSel = attRow("mc"); W():Refresh()
end)
shot("quests-attune-ony", "Quests (Onyxia's steps)", "A long attunement chain", function()
  pf("quests").attSel = attRow("ony"); W():Refresh()
end)
shot("heroes", "Adventurers", "Banner, stats, every Adventurer with a 3D head (yours) or class crest, status and XP", function()
  ns.QuestLists.viewLevel = nil
  local p = pf("quests"); p.attSel = nil; p.tabs.buttons[2]:Click(); page("heroes")
end)
-- Presence and versions (28 Oct 2026): Brannic's addon is older than Elyra's and not heard (the game still shows him
-- online), Elyra is AFK, Corwin offline. Brannic keeps his old version for the rest of the tour (Needs attention).
shot("heroes-presence", "Adventurers (presence, old addon)", "Invite on top; green ring and Old addon (Brannic), yellow AFK (Elyra), red Offline (Corwin), green Online (you)", function()
  dev("hero Brannic version 0.9.0"); dev("hero Elyra version 0.9.2")
  dev("hero Brannic quiet"); dev("hero Elyra afk"); dev("hero Corwin offline")
  page("heroes"); top(pf("heroes").scroll)
end)
shot("heroes-old-yours", "Adventurers (your addon is old)", "The toast Update the addon, and the line at the top of the page", function()
  -- A development copy is never old: pretend this one is 0.9.1 for the shot (put back right after).
  TR.realVersion = ns.VERSION
  ns.VERSION, ns.Hero.toldNewer = "0.9.1", nil
  dev("hero Elyra version 0.9.2")
  W():Refresh()
end, { toast = true })
prep(function()
  ns.VERSION = TR.realVersion
  for _, name in ipairs(PRETEND) do dev("hero " .. name .. " online") end
  W():Refresh()
end)
shot("inspect", "Inspect an Adventurer", "Gear at the edges like the character sheet, the class crest (pretend Adventurers cannot be drawn), XP, facts, Whisper / Invite", function()
  -- Brannic shares gear (your items as a stand-in), so the slots and their tooltips (Shift compares) show.
  dev("hero Brannic gear")
  local p = pf("heroes"); p.sel = full("Brannic"); W():Refresh()
end)
shot("inspect-me", "Inspect yourself", "You in 3D between your gear; role, secondary role, I'm away, how to play another character", function()
  local p = pf("heroes"); p.sel = ns.Me(); W():Refresh()
end)
shot("inspect-me-bottom", "Inspect yourself (scrolled)", "How to play another character here (from that character)", function() return bottom(pf("heroes").iscroll) end)
shot("manage", "Manage: Adventurers", "Needs attention, every Adventurer with a menu, invites", function()
  pf("heroes").sel = nil; dev("hero Corwin level 18"); page("manage")
end)
shot("manage-fellowship", "Manage: The fellowship", "Name, banner colour, every emblem; your banner as the others see it; Leave (hands over)", function()
  page("managefellowship")
end)
shot("manage-rules", "Manage: Rules", "The rules as a draft: size, play style, every rule; Publish", function()
  page("rulesadmin")
end)
shot("leave-confirm", "Leave as the leader (asks first)", "Who leads after you", function()
  W():Confirm(ns.Fellowship:LeaveQuestion(cur()), L.LEAVE_SHORT, function() end)
end)
shot("rules-vote", "Rules (an open vote)", "Brannic's proposal with Yes / No on the right page; the rulebook on the left", function()
  hideOverlays(); dev("hero Brannic propose"); page("rules"); top(pf("rules").lscroll); top(pf("rules").rscroll)
end)
shot("rules-vote-passed", "Rules (a passed vote)", "Passed, the rule changed", function()
  dev("hero Elyra vote yes"); dev("hero Corwin vote yes"); W():Refresh()
end, { toast = true })
shot("gatherings-empty", "Gatherings (none yet)", "Schedule, and how Gatherings work", function()
  hideOverlays(); page("gatherings")
end)
shot("gather-form", "Schedule a Gathering", "The form", function()
  ns.GatherForm:Open()
end)
shot("gatherings", "Gatherings", "Upcoming Gatherings with answers; the chosen one with who is coming", function()
  hideOverlays()
  ns.Gatherings:Schedule("wc", "bring potions", time() + 26 * 3600)
  ns.Dev:Hero("Brannic", "gather", TR.look.gather)
  page("gatherings")
end)
shot("overview-gatherings", "Overview (the next Gathering)", "One line about the next Gathering; it opens the page", function()
  page("overview")
end)
shot("inbox-full", "Inbox (several items)", "A Gathering, a vote, an ask to group up", function()
  dev("hero Corwin propose"); dev("hero Elyra ask")
  W():OpenPanel("inbox")
end, { wait = 0.3 })
-- The fellowship outgrew its rules' size: Duo rules with four companions (put back right after).
local tourRules
shot("inbox-size", "Inbox (a new size)", "Use the rules for a party? Use them / Keep mine (and the toast)", function()
  local f = cur()
  tourRules = f.rules
  ns.Fellowship:SetRules(ns.Rules.WithSize(f.rules, "duo"))
  ns:Fire("FELLOWSHIP")
  W():OpenPanel("inbox")
end, { toast = true, wait = 0.3 })
shot("admin-chapter-2", "Journey Admin (chapter 2)", "Another chapter selected, its dungeons", function()
  if tourRules then ns.Fellowship:SetRules(tourRules); tourRules = nil end
  if ns.char.sizeToasted then ns.char.sizeToasted[cur().id] = nil end
  W():HidePanels(); local A = ns.AdminDraft; A.sel = 2; page("admin"); pf("admin").editor:ShowTab("chapter")
end)
shot("admin-bosses", "Journey Admin (boss picker)", "Which bosses a clear needs", function()
  ns.AdminDraft:PickBosses(cur(), "dm")
end)
shot("admin-shelf", "Journey Admin (Every dungeon)", "The Every dungeon tab: every dungeon by level, the ones that fit chapter 2 in gold, to drag onto a chapter", function()
  hideOverlays(); pf("admin").editor:ScrollToShelf()
end)
shot("admin-add-again", "Journey Admin (a dungeon again)", "Chapter XV: Blackrock Depths clicked in from the shelf, its third placement (also in XIII, XIV)", function()
  hideOverlays()
  local A = ns.AdminDraft
  A.sel = 15; W():Refresh()
  local ed = pf("admin").editor
  ed:AddHere("brd")
  ed:ShowTab("chapter")
end)
shot("admin-journey", "Journey Admin (Whole journey)", "The Whole journey tab: Start over, Import, Export; the bar in gold with Discard and Publish", function()
  pf("admin").editor:ShowTab("journey")
end)
shot("admin-export", "Journey Admin (export)", "The journey string to copy", function()
  ns.AdminDraft.sel = 1
  hideOverlays(); local p = pf("admin"); p.export:Click()
end)
shot("admin-milestone-form", "Journey Admin (add a milestone)", "Kind, value, name, Required or Optional", function()
  hideOverlays(); ns.AdminDraft:MilestoneForm(cur())
end)
shot("admin-one-level", "Journey Admin (a 60-60 chapter)", "A one-level chapter added at the end, ready to publish", function()
  hideOverlays()
  local A, f, JE = ns.AdminDraft, cur(), ns.JourneyEdit
  -- (Split the last chapter, then drag the mark to 60: 58-60 and 60-60.)
  A:Edit(f, function(j) local n = JE.Split(j, #j.chapters); if n then JE.SetBoundary(j, n - 1, 60) end end)
  A.sel = #A:Journey(f).chapters
  page("admin"); pf("admin").editor:ShowTab("chapter")
end)
shot("chapter-milestones", "Chapter (milestones)", "A Required level milestone and an Optional one ticked by hand", function()
  hideOverlays(); ns.AdminDraft:Discard()
  local f = cur()
  local j = ns.Journey.Clean(f.journey)
  local n = ns.Journey:CurrentIndex(f)
  j.chapters[n].milestones = {
    { id = "tour1", kind = "level", value = j.chapters[n].cap, name = ns.Milestones.DefaultName("level", j.chapters[n].cap), req = true },
    { id = "tour2", kind = "tick", name = "Kill Hogger together", req = false },
  }
  ns.Fellowship:PublishJourney(j)
  ns.Fellowship:Tick("tour2", true)
  pf("chapter").sel = nil; page("chapter"); return bottom(pf("chapter").lscroll)
end)
-- The Endgame, as if the journey were complete (only for this shot; no "Endgame is open" toast).
local tourReached
shot("raids", "Raids (the Endgame)", "Each raid with its picture, attunement and boss progress", function()
  local f = cur()
  ns.char.endgameSeen = ns.char.endgameSeen or {}
  ns.char.endgameSeen[f.id] = time()
  tourReached = f.reached
  f.reached = #f.journey.chapters + 1
  page("raids")
end)
shot("raids-mc", "Raids (Molten Core chosen)", "Boss progress after two kills, who is attuned, Find group for a raid", function()
  for _, n in ipairs(PRETEND) do dev("group " .. n) end
  dev("kill mc 2")
  dev("group off")
  ns.Picture:Hide()
  page("raids")
  pf("raids").raid = "mc"; W():Refresh()
  ns.Endgame:FindGroup(cur(), "mc")
end, { toast = true })
prep(function() local f = cur(); if f then f.reached = tourReached end; ns.Picture:Hide(); page("overview") end, 0.3)
prep(function() hideOverlays(); dev("tourney start") end, 0.3)
shot("tourney-signup", "Tournament (sign-up)", "Sign-up open, entrants and seeds, schedule", function()
  ns.Tourney:SignUp(true)
  for _, n in ipairs(PRETEND) do dev("hero " .. n .. " signup") end
  page("tourney")
end)
shot("tourney-bracket", "Tournament (bracket running)", "Semifinals joined to the final by bracket lines, your next duel", function() dev("tourney next"); W():Refresh() end)
shot("tourney-champion", "Tournament (over)", "The winner and the hand-over", function()
  local f = cur()
  for _ = 1, 4 do
    local t = f.tourney
    if not t or t.phase ~= "running" then break end
    dev("tourney next")
  end
  W():Refresh()
end)
shot("history", "History (the fellowship's story)", "Joined, rules, votes, Gatherings and the tournament; founded, numbers and Leaders", function()
  page("history"); pf("history").filter = "all"; W():Refresh()
end)
local function format(fmt)
  return function()
    local f = cur()
    local r = {}
    for k, v in pairs(f.rules) do r[k] = v end
    r.tFormat = fmt
    ns.Fellowship:SetRules(r)
    dev("tourney start"); ns.Tourney:SignUp(true)
    for _, n in ipairs(PRETEND) do dev("hero " .. n .. " signup") end
    dev("tourney next")
    page("tourney")
  end
end
shot("tourney-double", "Tournament (double elimination)", "Winners and losers brackets", format("double"))
shot("tourney-groups", "Tournament (groups, then knockout)", "Group tables and the knockout", format("groups"))
shot("tourney-rr", "Tournament (round robin)", "Standings and schedule", format("rr"))
shot("tourney-20", "Tournament (20 entrants)", "Round by round: round 1's winners and byes, round 2 as cards with You, later rounds", function()
  dev("tourney big"); page("tourney")
end)
prep(function() dev("tourney big off") end)
shot("settings", "Settings", "The whole page: the book, messages, help, toasts and the tracker", function()
  ns.AdminDraft:Discard(); W():OpenSettings()
end)
shot("settings-tracker-off", "Settings (tracker off)", "The tracker's lines fade while it is off", function()
  W():OpenSettings(); ns.Settings:Set("tracker", false); W():Refresh()
end)
shot("toast-move", "Toast position (move mode)", "The sample banner to drag", function()
  ns.Settings:Set("tracker", true); W():OpenSettings(); ns.Toasts:StartMove()
end)

-- Toasts on their own (the book closed).
local function toast(kind, title, text)
  return function() ns.Toasts:StopMove(); W():Close(); ns.Toasts:Push(kind, title, text) end
end
shot("toast-clear", "Toast: dungeon cleared", "A normal toast", toast("clear", L.TOAST_CLEARED, L.TOAST_CLEARED_TEXT:format("The Deadmines")), { toast = true })
shot("toast-hero-floor", "Toast: a Hero reaches the floor", "A normal toast", toast("heroFloor", L.T_HERO_FLOOR:format("Brannic"), L.T_HERO_FLOOR_TEXT:format(21, "Corwin")), { toast = true })
shot("toast-chapter", "Toast: chapter unlocked (big)", "The big banner", toast("chapter", L.T_CHAPTER:format("IV"), L.T_CHAPTER_TEXT:format("Chains and Tides", 25, 29)), { toast = true })
shot("toast-journey", "Toast: journey complete (big)", "The biggest moment", toast("journey", L.T_JOURNEY, L.T_JOURNEY_TEXT:format("Tour")), { toast = true })
shot("toast-gathering", "Toast: a Gathering soon", "The reminder", toast("gathering", L.G_SOON, L.G_SOON_TEXT:format("The Deadmines", "20:00")), { toast = true })
shot("toast-ahead", "Toast: you pull ahead", "Two or more levels above an Adventurer", toast("ahead", L.T_AHEAD:format(3, "Corwin"),
  L.T_AHEAD_TEXT:format("Corwin")), { toast = true })
shot("toast-session", "Toast: session recap (big)", "After playing together: how long, with whom, what you did", function()
  ns.Toasts:StopMove(); W():Close()
  ns.Session:Toast({ start = time() - 5100, stop = time(), with = { full("Brannic"), full("Elyra") },
    levels = { { ns.Me(), 20, 22 }, { full("Brannic"), 21, 22 } }, runs = { { key = "dm", cleared = true } }, bosses = 7,
    quests = 9, chapters = { 3 } })
end, { toast = true })
shot("toast-long", "Toast: a long text", "Wraps to more lines; the banner grows", toast("clear", L.TOAST_CLEARED,
  L.TOAST_CLEARED_FOR:format("The Deadmines", "Brannic, Elyra, Corwin and you") .. " " .. L.TOAST_ENDGAME_TEXT), { toast = true })
shot("toast-attune", "Toast: an attunement opens", "At the level where it can be started", toast("attune",
  L.TOAST_ATTUNE_TITLE:format("Molten Core"), L.TOAST_ATTUNE_RAID), { toast = true })
shot("toast-endgame", "Toast: the Endgame is open (big)", "After the journey: the raids", toast("journey", L.TOAST_ENDGAME,
  L.TOAST_ENDGAME_TEXT), { toast = true })
shot("tracker", "The tracker on the screen", "Chapter, status, XP bar, you, the next step, dungeons cleared, who is online, a Gathering soon", function()
  ns.Toasts.frame:Hide(); W():Close(); ns.Tracker:SetFolded(false); ns.Tracker:Refresh()
end)
shot("tracker-all", "The tracker, every line on", "Also shared quests, your next duel and the inbox (Settings)", function()
  local S = ns.Settings
  TR.savedLines = {}
  for _, key in ipairs(S.TRACKER_LINES) do TR.savedLines[key] = S:TrackerLineOn(key); S:SetTrackerLine(key, true) end
  dev("hero Brannic propose")
  ns.Tracker:Refresh()
end)
shot("tracker-hidden", "The tracker, hidden", "Nothing on the screen until pointed at; it shows for a moment when something changes", function()
  for key, on in pairs(TR.savedLines or {}) do ns.Settings:SetTrackerLine(key, on) end
  ns.Settings:Set("trackerHover", true)
  -- The lines just changed, so the first refresh starts a peek; the second one, after it is cleared, hides it (the
  -- shot showed the whole tracker; seen in the seventh check).
  ns.Tracker:Refresh()
  ns.Tracker.frame.peekUntil = nil; ns.Tracker:Refresh()
end)
shot("picture-moment", "Picture after the final boss", "Take a picture, Without the interface, Done", function()
  ns.Settings:Set("trackerHover", false)
  ns.Picture:Offer("dm")
end)
shot("minimap-tooltip", "Minimap button", "The button and its tooltip", function()
  ns.Picture:Hide()
  local b = ns.MinimapButton.button
  local enter = b and b:GetScript("OnEnter")
  if enter then enter(b) end
end)

-- Show me around (UI/Walkthrough.lua): the offer, then steps of the three tours on the sample fellowship.
local function walk(rank, id)
  local WK = ns.Walkthrough
  if not WK.on or WK.rank ~= rank then WK:Stop(); WK:Start(rank) end
  for i, s in ipairs(WK.steps) do if s.id == id then WK:Go(i) return end end
end
shot("walk-offer", "Show me around? (the offer)", "After the setup guide: the card beside the book, Show me around / Later", function()
  ns.Picture:Hide(); hideOverlays(); W():Open("overview"); ns.Walkthrough:Offer("leader")
end)
shot("walk-intro", "Walkthrough: Welcome", "The sample fellowship in the header, framed; the rest dimmed", function() walk("leader", "INTRO") end)
shot("walk-stand", "Walkthrough: Where you stand", "The Overview card framed with sparks; the guide card level with it", function() walk("leader", "STAND") end)
shot("walk-chapter", "Walkthrough: Dungeons", "The first dungeon card; the Leader's text about marking a clear", function() walk("leader", "CHAPTER") end)
shot("walk-manage", "Walkthrough: Manage (Leader)", "Its Adventurers tab on the sample", function() walk("leader", "MANAGE") end)
shot("walk-header", "Walkthrough: header buttons", "Your characters, inbox and settings framed together", function() walk("leader", "HEADER") end)
shot("walk-tracker", "Walkthrough: the tracker", "Outside the book: the tracker framed, the book dimmed", function() walk("leader", "TRACKER") end)
shot("walk-rulesadmin", "Walkthrough: the Rules tab (Leader)", "The draft and Publish", function() walk("leader", "RULESADMIN") end)
shot("walk-member-invite", "Walkthrough: Invite (Adventurer)", "Everyone invites on the Adventurers page", function() walk("member", "INVITE") end)
shot("walk-member-rules", "Walkthrough: Rules (Adventurer)", "Propose and vote; the sample's open vote", function() walk("member", "RULES") end)
shot("walk-done", "Walkthrough: the end", "Done; Start the tour again from Settings", function() walk("member", "DONE") end)
prep(function() ns.Walkthrough:Stop() end)

-- Following another character's fellowship (Fellowship/Watch.lua): the pretend alt "Altara" (/jtf debug watch).
prep(function() ns.Picture:Hide(); hideOverlays(); W():Open(); dev("watch") end, 1.5)
shot("watch-overview", "Following an alt's fellowship: Overview", "The bar says whose fellowship and how fresh; Back to your own; nothing to act on", function()
  page("overview")
end)
shot("watch-chapter", "Following: Chapter", "Dungeons and clears to read; no Find group, no Mark cleared", function() page("chapter") end)
shot("watch-heroes", "Following: Adventurers", "Levels as the Adventurers sent them; Altara offline; no Leave", function() page("heroes") end)
shot("watch-rules", "Following: Rules", "Its rulebook as of the last news; Brannic's vote without Yes / No; no Propose", function()
  -- (An open vote in the pretend fellowship, gone with it at the end.)
  local f, now = ns.Fellowship:Get(ns.Dev.WATCH_ID), time()
  if f then
    f.votes = { tour = { id = "tour", by = full("Brannic"), key = "awayDays", value = 7, old = f.rules.awayDays, t = now,
      ends = now + 2 * 86400, ballots = { [full("Brannic")] = true } } }
  end
  page("rules")
end)
shot("watch-inspect", "Following: inspect an Adventurer", "No Whisper or Invite: they are not in your group", function()
  page("heroes"); pf("heroes").sel = full("Brannic"); W():Refresh()
end)
shot("watch-characters", "Your characters: Follow this fellowship", "Another character's fellowship, followed live, with the Follow button", function()
  pf("heroes").sel = nil
  ns.Watch:Close()
  W():OpenPanel("characters")
  local p = W().panels.characters
  if p and p.list then p.list.selected = full(ns.Dev.WATCH_ALT); W():Refresh() end
end)
prep(function() W():HidePanels(); ns.Dev:WatchForget() end)

-- Newcomers, trial accounts and a restore (27 Oct 2026).
shot("chapter-catching", "Chapter: a newcomer catching up", "Fenna joined far below the floor: listed as catching up, not holding the dungeons", function()
  hideOverlays(); W():Open()
  local f = cur()
  if not f then return end
  local fen = full("Fenna")
  if not f.members[fen] then
    ns.Dev:Fake("Fenna")
    ns.Fellowship:Do({ k = "invite", name = fen })
    ns.Comm:Inject(fen, "ACC", { fid = f.id, role = "DPS", class = "DRUID", level = 2 })
  end
  -- (Past the first real chapter she is marked at once; earlier the tour marks her so the screen shows it, and
  -- tells the tracker.)
  if f.members[fen] then f.members[fen].catching = true end
  ns.Fellowship:Changed()
  page("chapter")
end)
prep(function() local f = cur(); if f and f.members[full("Fenna")] then ns.Fellowship:Remove(full("Fenna")) end end)
shot("trial-bar", "Trial account warning", "A red bar across the book: the game blocks this account's addon messages", function()
  ns.Dev.pretendTrial = true; page("overview")
end)
prep(function() ns.Dev.pretendTrial = false; W():Refresh() end)
shot("sync-restore", "Restore a lost fellowship", "The question after the saved data was lost and an Adventurer still lists you", function()
  local f = cur()
  W():Confirm(L.RESTORE_Q:format("Brannic", f and f.name or TR.look.name), L.RESTORE_OK, function() end)
end)
prep(function() hideOverlays() end)

-- Themes and sizes.
local function themed(theme, id, pageId, label)
  shot(id, label, "The " .. pageId .. " page in this theme", function()
    if GameTooltip then GameTooltip:Hide() end
    -- The faction themes are forced, so a Horde character's tour also shows the Alliance theme (and the other way).
    ns.Theme.forceKey = (theme == "horde" or theme == "alliance") and theme or nil
    ns.Settings:Set("theme", ns.Theme.forceKey and "faction" or theme)
    ns.Theme:Apply()
    W():Open(); W():HidePanels(); page(pageId)
  end)
end
for _, p in ipairs({ "overview", "chapter", "quests", "heroes", "manage" }) do themed("night", "night-" .. p, p, "Night theme: " .. p) end
for _, p in ipairs({ "overview", "chapter", "heroes" }) do themed("alliance", "alliance-" .. p, p, "Alliance theme: " .. p) end
-- The Horde: every page with Horde header art (roster, council, board) and the chapters' pictures.
for _, p in ipairs({ "overview", "chapter", "heroes", "manage", "chronicle", "quests" }) do themed("horde", "horde-" .. p, p, "Horde theme: " .. p) end
shot("size-80", "Book at 80%", "The smallest size", function()
  ns.Theme.forceKey = nil; ns.Settings:Set("theme", "journal"); ns.Theme:Apply()
  ns.Settings:Set("size", 0.8); page("overview")
end)
shot("size-120", "Book at 120%", "The largest size (no bigger than the screen allows)", function() ns.Settings:Set("size", 1.2); page("overview") end)
shot("fullscreen", "Full screen", "The book fills the whole screen, its leather at the edges; the logo in the header; each page as wide as in a window, in the middle of its half; taller pages", function()
  ns.Settings:Set("size", 1); ns.Settings:Set("fullscreen", true); page("overview")
end)
shot("fullscreen-settings", "Full screen: Settings", "The flat sheet in full screen: both columns together in the middle, Back over the left one; the condense button beside Close; the Full screen box ticked", function()
  W():OpenSettings()
end)
shot("fullscreen-heroes", "Full screen: Adventurers", "A long list on the taller page; the crest and name right of the logo", function()
  W():CloseSettings(); page("heroes")
end)
shot("fullscreen-admin", "Full screen: Journey Admin", "The flat sheet's ruler and chapter plate across both halves, in the middle", function()
  page("admin")
end)
prep(function() ns.Settings:Set("fullscreen", false) end)

---------------------------------------------------------------------------
-- Running
---------------------------------------------------------------------------
local function trace(err) return tostring(err) .. "\n" .. (debugstack and debugstack(2, 10, 0) or "") end

-- /jtf brand hides the game's interface (chat, bars, the minimap: UIParent faded out) and keeps the addon's own
-- frames on the screen: the book and the toasts, and the tracker only in its own picture (behind the book, a strip
-- of it showed past the book's edge; seen in the brand run of 30 Oct 2026).
local function keepOurs(on, tracker)
  for _, f in ipairs({ W().frame or false, ns.Toasts.frame or false }) do
    if f and f.SetIgnoreParentAlpha then f:SetIgnoreParentAlpha(on) end
  end
  local t = ns.Tracker.frame
  if t and t.SetIgnoreParentAlpha then t:SetIgnoreParentAlpha(on and tracker or false) end
end
function TR:HideGameUI()
  self.uiAlpha = UIParent:GetAlpha() or 1
  UIParent:SetAlpha(0)
  keepOurs(true)
end
function TR:ShowGameUI()
  if not self.uiAlpha then return end
  keepOurs(false)
  UIParent:SetAlpha(self.uiAlpha)
  self.uiAlpha = nil
end

function TR:Finish(keep)
  local r = ns.db.tour
  self:ShowGameUI()
  hideOverlays()
  ns.Toasts:StopMove()
  ns.Theme.forceKey = nil
  for k, v in pairs(self.saved or {}) do ns.Settings:Set(k, v) end
  ns.Theme:Apply()
  ns.char.setupDone = self.savedSetup
  dev("pace off"); dev("level off"); dev("group off"); dev("tourney off")
  ns.Dev:WatchForget()
  ns.Dev.pretendTrial = nil
  if ns.Walkthrough then ns.Walkthrough:Stop() end
  ns.quiet = nil
  -- The pretend Heroes go, then you leave: alone, leaving ends the fellowship.
  local f = cur()
  if not keep and f and f.name == TR.look.name then
    -- The pretend session recap and pictures go with it.
    ns.Moments:Forget(f.id)
    local sessions = ns.Session:List()
    for i = #sessions, 1, -1 do if sessions[i].fid == f.id then table.remove(sessions, i) end end
    for name in pairs(f.members) do if name ~= ns.Me() then ns.Fellowship:Remove(name) end end
    ns.Fellowship:Leave()
  end
  r.finished = time()
  self.running = false
  ns:Print((self.brand and L.BRAND_DONE or L.TOUR_DONE):format(#r.shots), true)
  self.brand, self.look = nil, self.TOUR_LOOK
  local done = self.onDone
  self.onDone = nil
  if done then done() end
end

-- Is this shot taken in this run? opts.areas (a set of area keys): only theirs; opts.ids (shot ids, /jtf brand):
-- only those. The other shots still set their screen up (the next ones build on it), quickly and without a picture.
local function wanted(s, areas, ids)
  if ids then return ids[s.id] ~= nil end
  if not areas then return true end
  local area = ns.CheckAreas and ns.CheckAreas:ForShot(s.id)
  return area ~= nil and areas[area] == true
end

-- opts: { areas = { key = true } or nil for all, ids = { [shot id] = its entry of TR.BRAND } (only these),
-- brand = a look (TR.BRAND_LOOK: the founded fellowship and the theme; the game's interface hidden),
-- onDone = function }.
function TR:Run(arg, opts)
  if self.running then return end
  if ns.Combat:InCombat() then ns:Print(L.SELFTEST_COMBAT, true) return end
  if cur() then ns:Print(L.SELFTEST_IN_FELLOWSHIP, true) return end
  local keep = arg == "keep"
  opts = opts or {}
  local areas, ids = opts.areas, opts.ids
  self.look, self.brand = opts.brand or self.TOUR_LOOK, opts.brand
  self.onDone = opts.onDone
  self.running = true
  self.saved = { theme = ns.Settings:Get("theme"), size = ns.Settings:Get("size"), chat = ns.Settings:Get("chat"),
    trackerHover = ns.Settings:Get("trackerHover"), fullscreen = ns.Settings:Get("fullscreen") }
  -- The setup guide would take over after joining and founding: seen for the tour, as it was afterwards.
  self.savedSetup = ns.char.setupDone
  ns.char.setupDone = true
  ns.db.tour = { started = time(), shots = {}, problems = {}, areas = areas, brand = opts.brand and true or nil }
  if opts.brand then
    ns:Print(L.BRAND_START:format(TR:Count(areas, ids)), true)
    -- One theme from the first picture to the last.
    ns.Settings:Set("theme", opts.brand.theme)
    ns.Theme:Apply()
    self:HideGameUI()
  else
    ns:Print(L.TOUR_START:format(TR:Count(areas)), true)
  end
  ns.Settings:Set("chat", "off")
  ns.quiet = true
  -- The pages as a full account sees them (on an account without game time the warning bar covered every shot); the
  -- "trial-bar" shot shows it on its own.
  ns.Dev.pretendTrial = false
  -- With ids, the run ends after the last of them.
  local last = #shots
  if ids then
    last = 0
    for k, s in ipairs(shots) do if not s.prep and wanted(s, areas, ids) then last = k end end
  end
  local i, n = 0, 0
  local function nextShot()
    i = i + 1
    local s = shots[i]
    if not s or i > last then return TR:Finish(keep) end
    local res
    local ok, err = xpcall(function() res = s.fn() end, trace)
    if not ok then
      local list = ns.db.tour.problems
      list[#list + 1] = { id = s.id or "prep", err = err }
      ns:LogError("tour", s.id or "prep", err)
    end
    if s.prep then return C_Timer.After(s.wait or 0.3, nextShot) end
    if not wanted(s, areas, ids) then return C_Timer.After(TR.SKIP + (s.wait or 0), nextShot) end
    -- /jtf brand: the README file this picture becomes and the part of the screen it keeps.
    local b = ids and ids[s.id]
    if TR.brand then keepOurs(true, type(b) == "table" and b.crop == "tracker") end -- (the toasts' frame is made by the first toast)
    -- No picture when the screen could not be set up, or would be the same as the one before: the report says so
    -- (both made pictures that looked like a skipped shot; seen in a review).
    if not ok or res == "same" then
      local list = ns.db.tour.shots
      list[#list + 1] = { id = s.id, title = s.title, what = s.what, t = time(), area = ns.CheckAreas and ns.CheckAreas:ForShot(s.id),
        none = ok and "same" or "error" }
      return C_Timer.After(TR.SKIP, nextShot)
    end
    C_Timer.After(TR.SETTLE + (s.wait or 0), function()
      if not s.toast and ns.Toasts.frame and not ns.Toasts.moving then ns.Toasts.frame:Hide() end
      n = n + 1
      -- The game's error window covered 118 of 147 pictures on 29 Oct 2026: it is closed before each one (what it
      -- said is in the error log, and the shot notes that it was open).
      local errWin = ScriptErrorsFrame and ScriptErrorsFrame:IsShown() or nil
      if errWin then ScriptErrorsFrame:Hide() end
      -- The layout check (Dev/Layout.lua): what the game measures on this screen, before the picture.
      local okScan, layout = pcall(ns.Layout.Scan, ns.Layout)
      local okCrop, crop = true, nil
      if type(b) == "table" then okCrop, crop = pcall(TR.CropFor, TR, b) end
      if Screenshot then Screenshot() end
      local list = ns.db.tour.shots
      list[#list + 1] = { n = n, id = s.id, title = s.title, what = s.what, t = time(),
        area = ns.CheckAreas and ns.CheckAreas:ForShot(s.id), layout = okScan and #layout > 0 and layout or nil,
        errWin = errWin, file = type(b) == "table" and b.file or nil, kind = type(b) == "table" and (b.crop or "book") or nil,
        crop = okCrop and crop or nil }
      C_Timer.After(TR.GAP - TR.SETTLE, nextShot)
    end)
  end
  ns.Window:WhenBuilt(nextShot)
end

-- How many screenshots the tour takes (for the start message and tests).
function TR:Count(areas, ids)
  local c = 0
  for _, s in ipairs(shots) do if not s.prep and wanted(s, areas, ids) then c = c + 1 end end
  return c
end

---------------------------------------------------------------------------
-- /jtf brand: the README's pictures (.github/screenshots)
---------------------------------------------------------------------------
-- The tour's shots the README shows, the file each becomes, and what of the screen it keeps (the book with what hangs
-- outside it, the default; the toast, the tracker, or the whole screen). Plain pictures: the walkthrough's gold frame
-- around each subject was tried and dropped (30 Oct 2026). tools/brand-shots.lua cuts them.
TR.BRAND = {
  { id = "create-2", file = "play-style" },
  { id = "create-chapters", file = "journey-editor" },
  { id = "overview-ready", file = "overview" },
  { id = "chapter", file = "chapter" },
  { id = "moments", file = "moments" },
  { id = "group-photo", file = "group-photo", crop = "screen" },
  { id = "quests-attune", file = "attunements" },
  { id = "heroes", file = "adventurers" },
  { id = "rules-vote", file = "rules" },
  { id = "gatherings", file = "gatherings" },
  { id = "raids", file = "raids" },
  { id = "tourney-bracket", file = "tournament" },
  { id = "toast-chapter", file = "chapter-unlocked", crop = "toast" },
  { id = "tracker", file = "tracker", crop = "tracker" },
}
-- The Journal theme on an Alliance character (chosen 30 Oct 2026): the Alliance's header art and blue icons, and a
-- fellowship with a blue banner and the lion. Only an Alliance character takes them (your name and model are in some).
-- Roles that fit the classes (you DPS, Brannic the Warrior tanks, Elyra the Priest heals) and a Gathering with a
-- player's name for it, instead of the tour's Tank leader, no healer and "Testing together" (30 Oct 2026).
TR.BRAND_LOOK = { name = L.SAMPLE_NAME, color = ns.BANNERS[1][2], emblem = "Her_Lion", theme = "journal",
  role = "DPS", roles = { Brannic = "Tank", Elyra = "Healer" }, gather = L.BRAND_GATHER_TEXT }
-- Room around what a picture keeps, in UIParent units.
TR.BRAND_PAD = { book = 4, toast = 28, tracker = 14 }

function TR:Brand()
  if UnitFactionGroup("player") ~= "Alliance" then ns:Print(L.BRAND_FACTION, true) return end
  local ids = {}
  for _, b in ipairs(self.BRAND) do ids[b.id] = b end
  self:Run(nil, { ids = ids, brand = self.BRAND_LOOK })
end

-- A part of the screen in the screenshot's pixels, from UIParent units (left, bottom, right, top) with room around
-- it: { x, y (from the top), w, h, sw, sh (the screen's size) }.
function TR:PixelRect(l, b, r, t, pad)
  local uw, uh = UIParent:GetWidth(), UIParent:GetHeight()
  local sw, sh
  if GetPhysicalScreenSize then sw, sh = GetPhysicalScreenSize() end
  if not sw or not sh or sh <= 0 then sw, sh = uw, uh end
  local k, fl = sh / uh, math.floor
  pad = pad or 0
  l, b = math.max(0, l - pad), math.max(0, b - pad)
  r, t = math.min(uw, r + pad), math.min(uh, t + pad)
  return { x = fl(l * k + 0.5), y = fl((uh - t) * k + 0.5), w = fl((r - l) * k + 0.5), h = fl((t - b) * k + 0.5), sw = sw, sh = sh }
end

-- A shown frame's or text's rectangle in UIParent units: left, bottom, right, top.
local function uiRect(f)
  if not f or not f.IsShown or not f:IsShown() then return nil end
  local l, b = f:GetLeft(), f:GetBottom()
  if not l or not b then return nil end
  local es = f.GetEffectiveScale and f:GetEffectiveScale() or f:GetParent():GetEffectiveScale()
  local s = es / UIParent:GetEffectiveScale()
  return l * s, b * s, (l + f:GetWidth()) * s, (b + f:GetHeight()) * s
end

-- What a branding picture keeps (nil: the whole screen).
function TR:CropFor(b)
  local kind = b.crop or "book"
  local l, bo, r, t
  if kind == "book" then l, bo, r, t = W():Extents()
  elseif kind == "toast" then l, bo, r, t = uiRect(ns.Toasts.frame)
  elseif kind == "tracker" then l, bo, r, t = uiRect(ns.Tracker.frame) end
  if not l then return nil end
  return self:PixelRect(l, bo, r, t, self.BRAND_PAD[kind])
end
