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
  if GameTooltip then GameTooltip:Hide() end
  -- The minimap shot points at the button. LibDBIcon (from another addon) has a tooltip of its own that only the
  -- button's OnLeave hides: it stayed on every shot after it (check of 7 Nov 2026, 17:25).
  local b = ns.MinimapButton.button
  local leave = b and b:GetScript("OnLeave")
  if leave then leave(b) end
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
shot("welcome", "Welcome", "No fellowship: logo, features, Found / Join, Your characters (without a fellowship: hidden) with How a journey works right under it, down to the page's foot (U67)", function()
  ns.Characters.showAll = false
  W().startView = "welcome"; W():Open(); W():Refresh()
end)
shot("controls-gallery", "The game's button art (gallery)", "Every candidate template and texture for WoW-style buttons; missing ones say so", function()
  ns.Gallery:Show()
end)
prep(function() ns.Gallery:Hide() end)
shot("characters-panel", "Your characters panel", "The header's characters button: characters in a fellowship, the others behind Show", function()
  ns.Characters.showAll = false
  W():OpenPanel("characters")
end)
shot("characters-panel-all", "Your characters panel (all shown)", "After Show: the characters without a fellowship under the others, and Hide", function()
  local p = W().panels.characters
  if p and p.list and p.list.toggle:IsShown() and not ns.Characters.showAll then p.list.toggle:Click() end
end)
prep(function() ns.Characters.showAll = false end)
shot("create-1", "Create: step 1 (empty)", "Name, role and four size cards; on the right your banner, its colour and every emblem", function()
  W():HidePanels(); ns.CreateState:Reset(); W().startView = "create"; W():Refresh()
end)
shot("create-1-filled", "Create: step 1 (filled)", "With a name and the Tank role", function()
  local C = ns.CreateState
  C.name, C.role, C.color = TR.look.name, TR.look.role or "Tank", TR.look.color or C.color
  C.emblem = TR.look.emblem or C.emblem
  W():Refresh()
end)
shot("create-2", "Create: step 2 (play style)", "Relaxed / Together / Strict with their level strips; the chosen one's levels, key and rules in words", function()
  hideOverlays(); ns.CreateState.step = 2; ns.CreateState.fine = false; W():Refresh()
end)
shot("create-2-fine", "Create: step 2 (fine-tune)", "Every rule, left and right page, and the way back to the styles", function()
  ns.CreateState.fine = true; W():Refresh()
end)
shot("create-3", "Create: step 3 (journey)", "Five journey tiles (Forever, Classic, Short, Long, Your own), each with its chapters as a strip; the chosen journey's chapters on the right page", function()
  ns.CreateState.fine = false; ns.CreateState.step = 3; W():Refresh()
end)
shot("create-3-own", "Create: step 3 (your own journey)", "Your own journey chosen: six steps, its chapters (a copy of the suggested journey) on the right", function()
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
-- X1 (SPEC §9): the challenges, chosen only here; Hardcore Fellowship on a PvP realm and Shared lives together (the
-- review shows them next).
shot("create-challenges", "Create: Challenges", "Three banners side by side, every challenge in sight: Hardcore PvP Fellowship (the PvP realm tick under it renames it) and Shared lives chosen (they combine), how many lives (the size suggests it); on the right what you take on: a row for each chosen challenge, its icon and name, the rule on hover (U114), the candles for the lives", function()
  local C = ns.CreateState
  C.challenges, C.pvp = { hardcore = true, shared = true }, true
  C:Goto("challenges"); W():Refresh()
end)
-- X3-X5 (the owner, 1 Nov 2026): a challenge hovered, then many across the three banners.
shot("create-challenges-tip", "Create: Challenges (one hovered)", "Hovering Lord of the Rings in the Story and Travel banner: on the right page its icon in a gold ring, STORY AND TRAVEL, its name and its whole rule in the book's type, no tooltip; under it \"Chosen: Hardcore PvP Fellowship · Shared lives (10)\" (U45); a faint emblem low on each banner (a skull, the Ring, a coin)", function()
  local r = W().pageFrames.create.chalRows.ring
  r:GetScript("OnEnter")(r)
end)
shot("create-challenges-many", "Create: Challenges (many at once)", "Lord of the Rings and Walk everywhere; Ironman Fellowship (White gear only greyed, with it; Fellowship-crafted faded: Not with Ironman Fellowship), Pauper with its gold, One class only (your class): every row stays on its banner's cloth, and the right page holds them all above Next, one row each with its icon, no wall of rules (U114)", function()
  local r = W().pageFrames.create.chalRows.ring
  r:GetScript("OnLeave")(r)
  local C = ns.CreateState
  C.challenges.ring, C.challenges.walk, C.challenges.ironman, C.challenges.pauper, C.challenges.oneclass = true, true, true, true, true
  W():Refresh()
end)
shot("create-4", "Create: review", "The fellowship, the rules as rows and the challenges (Change), the journey's chapters, Create the fellowship", function()
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
shot("member-overview", "Member: Overview", "As a new member: Focus now with your first thing to do (no welcome card since U146), no Manage or Leader pages", function()
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
  ns.Fellowship:Create({ name = TR.look.name, role = TR.look.role or "Tank", preset = "forever", color = TR.look.color, emblem = TR.look.emblem })
  W():Open("overview")
end, 0.5)
-- The setup guide a new Companion sees once (the tour marks it seen, so here it is opened by hand).
shot("setup-1", "Setup guide: Look", "The theme as picture tiles; the book changes at once", function() ns.SetupGuide:Open("overview") end)
shot("setup-2", "Setup guide: While you play", "Tracker (Always, Hidden, Off; then Its own panel, the default, or Under the game's quest tracker), banners, chat messages and sounds; all above the footer", function()
  ns.SetupGuide.step = 2; W():Refresh()
end)
shot("setup-3", "Setup guide: Reminders", "Cap warning, picture moment, minimap button; Start the journey", function()
  ns.SetupGuide.step = 3; W():Refresh()
end)
shot("leader-overview-new", "Overview (new fellowship)", "Alone: the title Overview with no line under it (U162); the chapter's banner across the sheet with Where we stand on its dark foot in light words (U158), Focus now on its picture with your first step (Invite your Adventurers), Since last time on the notice board and Coming up (no Gatherings) on the road ahead, three cards alike with light headings; all in view (U139, U148, U149, U155)", function() page("overview") end)
shot("leader-chapter-new", "Chapter (new fellowship)", "The Prologue: your To do starts with your first steps, then the floor (U140); the stage track and its picture in place of dungeons", function() page("chapter") end)
shot("leader-quests-empty", "Quests (alone)", "No shared quests", function() page("quests") end)
-- The Chronicle at All (the self-test leaves it at Sessions; seen in the check of 29 Oct 2026).
local function chronicle(filter) page("chronicle"); pf("chronicle").filter = filter; W():Refresh() end
shot("leader-chronicle-empty", "Chronicle (empty)", "Nothing yet, totals at zero; three tabs: The journey, Moments, The fellowship (U142)", function() chronicle("all") end)
shot("leader-moments-empty", "Moments (empty)", "No moments yet: what the tab keeps", function() page("moments") end)
shot("leader-history-alone", "Chronicle: The fellowship (new fellowship)", "The Chronicle's third tab (History until U142): founded, the number tiles, its Leader", function()
  page("history"); pf("history").filter = "all"; W():Refresh()
end)
shot("leader-heroes-alone", "Heroes (alone)", "One Hero", function() page("heroes") end)
shot("leader-manage-alone", "Manage (alone)", "Its two tabs; the bar to the Rules page at the top right (U143); the Adventurers tab: you, the invite box", function() page("manage") end)
shot("leader-rules", "Rules (leader)", "The rulebook; no votes yet; Edit the rules in a gold bar on the left (U143)", function() page("rules") end)
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
shot("overview-ready", "Overview (ready)", "The chapter's banner across the sheet, its name in gold Morpheus whole; along its dark foot, in light words, Where we stand (U158): the level track with a class face on each marker (a small badge where several share a level), the red stop tick where to stop questing when the room is known, with room to spare too (U179), one line, Who stands where, the room; Focus now on its dungeon's picture: a gold headline, why in light words, one larger button, all readable; Since last time on the Chronicle's notice board and Coming up on the road ahead, the three cards alike, their headings light with a gold rule, Coming up's later dungeon in its small gold frame; all in view, nothing to scroll (U139, U148, U149, U151, U152, U155)", function() page("overview") end)
shot("overview-catchup", "Overview (catch-up)", "You below the floor: Focus now says Reach level 15, how far and about how long at your pace; the line under the track says you are below the floor", function()
  dev("level 13"); page("overview")
end)
shot("chapter-waiting", "Chapter (waiting for the floor)", "The stage track; the waiting box with who is below the floor and how far; the dungeons dimmed below, without a button, each saying what to get ready meanwhile (\"1 chain to start, 3 quests to pick up.\"), not when it opens", function()
  page("chapter"); top(pf("chapter").lscroll)
end)
shot("overview-behind", "Overview (someone behind)", "Focus now: Help Corwin to the floor, with Invite to group; the line under the track names him", function()
  dev("level 19"); dev("hero Corwin level 12"); page("overview")
end)
shot("overview-since", "Overview: Since last time", "On the Chronicle's notice board in light words: Elyra and Brannic levelled, on one line with the level's icon (U169), the only news since the book was marked just before; how long ago at the right; its link opens the Chronicle (U139, U151, U155). (More lines, each whole and the rest counted in the link: the Overview shots before it.)", function()
  ns.Since:Mark(); dev("hero Elyra level 19"); dev("hero Brannic level 20"); page("overview")
end)
-- What's New (the check of 1 Nov 2026, 14:32): once after an update, over the book.
shot("news", "What's New", "Over the book on parchment in its frame: What's New in gold, the big news (Where to stop questing, Shadowfang Keep) in a round picture inside the gold ring, two picture cards (Where to pick up quests, the Deadmines; Share at the entrance, Wailing Caverns) with loading screens, all words whole, Continue", function()
  local keep = ns.db.newsSeen
  ns.News:Show()
  ns.db.newsSeen = keep
end)
prep(function() hideOverlays() end)
shot("chapter", "Chapter", "The stage track, the banner, your To do: the floor, then every dungeon as a row with what you need under it, whole on one line (its short form, \"Nothing to get first.\", where the long one does not fit) (Find group or Get ready and ⋯ at the right; a click opens its page), For later dungeons on a gold tint, each with its next step and no countdown (\"Testing the Wells: open now.\" or \"Murloc Gills, step 2 of 10.\", U172), If you like (U140); the level track, where the Adventurers stand (no line for an empty group, U187), the room", function()
  dev("hero Corwin level 17"); page("chapter"); top(pf("chapter").lscroll)
end)
-- M25: everyone at the floor and online: Play now's pick is Focus now's (U139).
shot("overview-playnow", "Overview (Play now)", "Focus now: the one best thing to do with who is online (a dungeon two of you need), with one button", function()
  page("overview")
end)
-- (The Chapter page fits without scrolling since 28 Oct 2026: no scrolled shots of it.) The next three open the
-- Chapter page themselves: since Play now's shot came before them, they showed the Overview (check of 29 Oct 2026).
shot("chapter-tooltip", "Chapter (clears table tooltip)", "A column's full dungeon name", function()
  pf("chapter").sel = nil; page("chapter"); top(pf("chapter").lscroll)
  local col = pf("chapter").matrix.cols.items[3] or pf("chapter").matrix.cols.items[1]
  local enter = col and col:GetScript("OnEnter")
  if enter then enter(col) end
end)
shot("chapter-picture", "Chapter (a dungeon's picture on hover)", "The first dungeon's picture large over its row, with its name (U64); the game's default tile shows nothing", function()
  if GameTooltip then GameTooltip:Hide() end
  pf("chapter").sel = nil; page("chapter"); top(pf("chapter").lscroll)
  local row = pf("chapter").rows.items[1]
  local enter = row and row.pic:GetScript("OnEnter")
  if enter then enter(row.pic) end
end)
-- (Chapter numbers count the Prologue, chapter I, since 27 Oct 2026.)
shot("chapter-next", "Chapter (next, not started)", "A chapter that is not open yet", function()
  if GameTooltip then GameTooltip:Hide() end
  if ns.UI.pictureTip then ns.UI.pictureTip:Hide() end
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
shot("chapter-partial", "Chapter (a dungeon partly done)", "The Deadmines' row after two kills, hovered: its tooltip says how many bosses are down so far (the row and the clears table show only whole clears) and who is ready in one line, \"0 of 4 ready\" (U186)", function()
  page("chapter"); top(pf("chapter").lscroll)
  -- (The check of 11 Nov 2026, 23:49: the shot showed the row alone; the bosses are in its tooltip since U140.)
  -- (The Deadmines' row, else the first dungeon's: a Horde chapter may not have it.)
  local hover
  for _, r in ipairs(pf("chapter").rows.items) do
    if r:IsShown() and r.key and (r.key == "dm" or not hover) then hover = r end
  end
  if hover then hover:GetScript("OnEnter")(hover) end
end)
-- The owner, 11 Nov 2026: a dungeon you cleared while the clear rule waits for the others (put back after the shot).
local youCleared
shot("chapter-you-cleared", "Chapter (a dungeon you cleared)", "Every Adventurer must clear: the first dungeon's row says \"You cleared it. Still needed by ...\" (or \"You cleared it. 3 more must clear it.\" where the names do not fit) with Find group, not Get ready; its mark still open; Recommended next on the next mandatory dungeon; your mark in the clears table", function()
  if GameTooltip then GameTooltip:Hide() end
  local f, J = cur(), ns.Journey
  local x = J:ChapterList(f, J:CurrentIndex(f))[1]
  youCleared = x and { f = f, key = x.key, runs = f.runs[x.key], mode = f.rules.clearMode }
  if x then f.rules.clearMode, f.runs[x.key] = "all", { [ns.Me()] = time() } end
  local p = pf("chapter"); p.sel = nil; page("chapter"); W():Refresh(); top(p.lscroll)
end)
prep(function()
  local s = youCleared
  if s then s.f.runs[s.key], s.f.rules.clearMode = s.runs, s.mode end
  W():Refresh()
end)
shot("chronicle", "Chronicle (all)", "Runs with counted / not counted; chapters unlocked in a row as one line (U15); the number tiles, then the tallies: no dungeon list (U170)", function() chronicle("all") end)
shot("chronicle-runs", "Chronicle (runs filter)", "Only runs", function()
  local p = pf("chronicle"); p.filter = "run"; W():Refresh()
end)
-- F1 (SPEC §8): the pretend Adventurers' deeds a little while ago, shared as their state would carry them.
prep(function()
  local f, t = cur(), (GetServerTime and GetServerTime() or time())
  local deeds = { Brannic = { lvl10 = t - 290, fall = t - 250, rare = t - 200, mount = t - 40 },
    Elyra = { lvl10 = t - 280, lvl20 = t - 150, gold100 = t - 100 }, Corwin = { fall = t - 240, epic = t - 20 } }
  local tally = { Brannic = { falls = 3, quests = 12 }, Elyra = { falls = 1, quests = 20 }, Corwin = { falls = 1, quests = 7 } }
  for n, d in pairs(deeds) do
    local h = f.heroes and f.heroes[full(n)]
    if h then h.deeds, h.tally = d, tally[n] end
  end
  ns.Firsts:Check(f); ns.Moments:Check(f)
end)
shot("chronicle-firsts", "Chronicle (Firsts)", "The firsts as medals: Earned (who, when), then Still open, greyed (only the next open level names who is closest, 20 of 30 with a ring of dots lit that far, U42; the newest earned medal glints once as the cabinet opens); the tallies on the right as podiums, the top three in gold, silver, bronze", function()
  chronicle("first")
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
shot("share-window", "Share the addon (no answer)", "Kim did not answer: the addon's page to copy and Whisper the link; the hint names the usual causes (the latest version, a trial account; in WoW Forever their first and last name and the same ruleset)", function()
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
shot("group-photo", "Group photo (the world)", "The interface hidden; everyone side by side at true size, names under their feet (20, with class icons: U16), the crest and name top left, the controls at the bottom", function()
  hideOverlays()
  -- The photo keeps the backdrop it last had (the self-test's was the studio; seen in the check of 30 Oct 2026).
  ns.Photo.backdrop = "world"
  ns.Photo:Open({ standIns = true })
end, { wait = 0.8 })
shot("group-photo-studio", "Group photo (studio, poses)", "The studio backdrop; everyone cheering, the second one chosen (gold name) and saluting", function()
  local PH = ns.Photo
  PH:SetBackdrop("studio")
  PH:Choose(nil)
  PH:StepPose(2)
  -- The salute a moment later, as a click would set it, and close to the shot: it is short, and the shot 0.8 seconds
  -- after it showed Brannic standing again in three checks of 30 Oct 2026 (it played in the lab).
  C_Timer.After(0.5, function()
    if PH:IsOpen() and PH.cast[2] then PH:Choose(2); PH:StepPose(1) end
  end)
end, { wait = 0.9 })
shot("group-photo-twelve", "Group photo (twelve)", "Two rows of six, the back row between the heads in front; the camera a little higher; names under the front row's feet and over the back row's heads", function()
  local PH = ns.Photo
  PH:Close()
  PH.backdrop = "studio"
  PH:Open({ standIns = true, extra = ns.Dev:Crowd(cur(), 12) })
end, { wait = 1.5 }) -- six new models load for the back row (at 0.8 s only their names stood there, 31 Oct 2026)
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
-- The dungeons new in WoW Forever (the owner, 7 Nov 2026): City of Dalaran has quests for both sides.
shot("quests-dungeons-new", "Dungeon page (a dungeon new in WoW Forever)", "City of Dalaran's page: no story of ours yet (WoW Forever's own), its quests for your side under 1. Prequest chains (Heart of Disruption and Starving Arcane, one row after An Alarming Request, U171) and 2. Pick up before you go, each a short row: its status icon and word, its level, \"One chain, 2 quests\" with no step count for a chain of one quest, two lines each with a + beside the pin (U185)", function()
  page("dungeons") -- opened from the Dungeons page, so the sidebar marks Dungeons (the check of 10 Nov 2026 showed Quests)
  ns.DungeonPage:Open("dal")
end)
-- U123: a prequest chain, each step with where it starts.
shot("dungeon-page-chain", "Dungeon page (a prequest chain)", "The Deadmines (Wailing Caverns for the Horde) under 1. Prequest chains: Destruction in Deadmines opened: where it starts and its ten steps from Alba Fairmoon in Westfall to the explosives found in the run (Leaders of the Fang's five, from Tonga Runetotem in the Barrens), each step with its level where known, where it starts and your status", function()
  local horde = UnitFactionGroup("player") == "Horde"
  page("dungeons") -- opened from the Dungeons page, as a player would (the brand picture of 10 Nov 2026 showed Chronicle)
  ns.DungeonPage:Open(horde and "wc" or "dm")
  -- To the quest itself: its steps are below the page's fold (the check of 8 Nov 2026 showed none of them), and
  -- opened, as a row shows only how far until clicked (U185; the check of 12 Nov 2026 showed it folded).
  local p, want = pf("dungeon"), horde and 914 or 92819
  p.opened[want] = true
  ns.Window:Refresh()
  for _, row in ipairs(p.quests.items) do
    local _, _, _, _, y = row:GetPoint(1)
    if row.id == want and row:IsShown() and y and p.rscroll:Reveal(-y, row:GetHeight()) then return end
  end
  return bottom(p.rscroll)
end)
-- The Dungeons page (U157).
shot("dungeons", "Dungeons", "Every dungeon of the journey on the flat sheet, chapter by chapter under a heading (Chapter I · its name · Level 15-21), the current chapter's in gold; a picture tile each with its name in gold, its levels and a gold check once cleared. A chapter still hidden from Adventurers reads \"A chapter yet to be revealed\", its dungeons shown without their levels (U157); no subtitle (Show all)", function()
  ns.Settings:Set("dungeonsShow", "all"); page("dungeons"); top(pf("dungeons").scroll)
end)
shot("dungeons-open", "Dungeons (Only open ones)", "Settings → Dungeons and raids → Dungeons page set to Only open ones: the subtitle \"The dungeons open to the fellowship\", only the dungeons the fellowship may run now; put back to Show all after (U164)", function()
  ns.Settings:Set("dungeonsShow", "open"); page("dungeons"); top(pf("dungeons").scroll)
end)
prep(function() ns.Settings:Set("dungeonsShow", "all") end)
-- The Dungeon page (U96-U100).
shot("dungeon-page", "Dungeon page", "The Deadmines (Ragefire Chasm for the Horde), on one flat sheet: no spine under the title across both halves (U111). Left: its picture, our story with Read more, the bosses with how many Adventurers were there (no \"Not yet\" beside each before any fell, U161), who cleared it; Find group and Waypoint (to the entrance) at the foot. Right: the room as the answer (U145), Who is ready folded to a ring for each Adventurer, \"2 of 4 ready\" and Show who (U126); when every prequest is done, a line above the rings: \"Everyone has done the prequests. Only quests to pick up are left: 2 can be shared in the group.\" (U177), then the quests under 1. Prequest chains, 2. Pick up before you go, 3. Starts inside, each a short row (U185): your status first in words (\"Not yet\"; its icon once, before the name), its level with the level it opens at (\"Level 17, open from 14\"; under Starts inside its level alone, \"Level 22\"), how far along a chain (\"Step 1 of 10\"), two lines each with a + beside the pin to open the rest, no link line under them (the map numbers only on the pin's tooltip, U160); the Alliance's Red Silk Bandanas and The Defias Brotherhood one row, \"One chain, 2 quests\" (U171)", function()
  local p = pf("dungeon")
  if p then p.whoOpen = nil end
  ns.DungeonPage:Open(UnitFactionGroup("player") == "Horde" and "rfc" or "dm")
end)
shot("dungeon-page-forever", "Dungeon page (one of WoW Forever's own)", "The Drowned City: its picture and our own story above Read more (\"Off the coast of Stranglethorn Vale, west of Grom'gol, ...\"; U182), whole and readable; with Spoken running and no story of its own there, no Read more at all (not \"install Spoken\"); with neither addon, the line to install one; no Cleared by, as nobody can have cleared it yet (Chapter VII); its two chains short rows, \"Step 1 of 6\" each (U185)", function()
  ns.DungeonPage:Open("drown")
end)
shot("dungeon-page-who", "Dungeon page (another Adventurer's quests)", "Show who opened: a row each, saying Ready or what is still missing, \"Needs 1 prequest, 2 quests to pick up\" (U163); Brannic's row chosen: the quests with Brannic's status, \"Showing Brannic's quests\"; Remind on the rows of Adventurers online and not ready (U98, U100, U126)", function()
  ns.DungeonPage:Open(UnitFactionGroup("player") == "Horde" and "rfc" or "dm")
  local p = pf("dungeon")
  p.whoOpen = true; W():Refresh()
  local row = p.readyRows.items[2]
  if row and row:IsShown() then p.who = row.name; W():Refresh() end
end)
prep(function() local p = pf("dungeon"); p.who, p.whoOpen = nil, nil end)
-- Room for the dungeon quests (U78): a made-up chapter total stands in for this character's (its quests' XP may not
-- be known yet), put back after the three shots.
prep(function()
  local R, ch = ns.Room, ns.Journey:Current(cur())
  local cap = ch and ch.cap or 20
  local fake = { now = cap - 2, levels = 2.4, to = cap + 0.4, cap = cap, tol = 0, limit = cap, stop = cap - 2.4,
    unknown = 1, n = ch and ch.n or 0 }
  R.realChapter = R.realChapter or R.Chapter
  R.Chapter = function() return fake end
end)
shot("overview-room", "Overview (room for the dungeon quests)", "On Where we stand along the banner's dark foot, under its line, the answer in red: \"Stop questing at 26.1 to leave room for the dungeon quests.\", or with room to spare \"You have room for the dungeon quests: stop questing at ...\" (U85, U145, U174); the stop point as a red tick on the level track (U82); the figures (the level the quests take you to, the cap level left for the mobs, the quests whose XP is not known yet) only on hover", function()
  page("overview")
end)
shot("chapter-room", "Chapter (room for the dungeon quests)", "Under where the Adventurers stand: the chapter's total and, in red, where to stop questing as level and percent (U78, U85); the stop point as a red tick \"stop 26 (60%)\" on the level track (U82)", function()
  local p = pf("chapter"); p.sel = nil; page("chapter"); W():Refresh(); top(p.rscroll)
end)
shot("dungeon-page-room", "Dungeon page (the room, Show everyone)", "A dungeon of your chapter: the room as the answer at the top of the right page (\"Stop questing at ... to leave room for the dungeon quests.\" or \"You have room for this dungeon's quests.\", U174) and Show everyone ticked with each Adventurer's line (U78, U145)", function()
  local f, J = cur(), ns.Journey
  local key
  for _, x in ipairs(J:ChapterList(f, J:CurrentIndex(f))) do if not (x.early or key) then key = x.key end end
  ns.DungeonPage:Open(key or "dm")
  pf("dungeon").everyone = true; W():Refresh(); top(pf("dungeon").rscroll)
end)
prep(function()
  local R = ns.Room
  if R.realChapter then R.Chapter, R.realChapter = R.realChapter, nil end
  pf("dungeon").everyone = nil
end)
shot("quests", "Quests (Quests tab)", "Three folder tabs, each word inside its tab (U144: the Dungeon quests tab went to the Dungeon page); no line under the title; Together now and Pick up and join, each by zone (the zone you are in first, with You are here; then Nearby), quests as cards with an icon and your progress; your quest's details: progress, others and where they are, what you can do", function()
  page("quests"); local p = pf("quests"); p.tabs.buttons[1]:Click()
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
shot("quests-chains", "Quests (Quest chains tab)", "The Questie line; learned chains as cards with a pip for each part (often empty at first)", function()
  ns.Quests.viewLevel = nil
  local p = pf("quests"); p.all = nil; p.tabs.buttons[2]:Click()
end)
shot("quests-attune-none", "Quests (Attunements, level 30)", "None open yet: when the first one opens", function()
  ns.QuestLists.viewLevel = 30
  local p = pf("quests"); p.sel = nil; p.tabs.buttons[3]:Click()
end)
-- The row of an attunement on the Attunements tab, by its key (the list is sorted by start level).
local function attRow(key)
  for i, a in ipairs(ns.QuestLists:Attunements(ns.Fellowship:Current(), ns.Me())) do if a.key == key then return i end end
end
shot("quests-attune", "Quests (Attunements & keys tab)", "The grid with an icon on each row and every other row banded; Molten Core's steps (as seen at level 60)", function()
  ns.QuestLists.viewLevel = 60
  pf("quests").attSel = attRow("mc") or 1; W():Refresh() -- (WoW Forever has not announced Molten Core: the first)
end)
shot("quests-attune-ony", "Quests (Onyxia's steps)", "A long attunement chain", function()
  pf("quests").attSel = attRow("ony"); W():Refresh()
end)
shot("heroes", "Adventurers", "Banner, number tiles (a gold number over an icon), no level track (its home is the Chapter page, U168), every Adventurer with a 3D head (yours) or class crest, status and XP", function()
  ns.QuestLists.viewLevel = nil
  local p = pf("quests"); p.attSel = nil; p.tabs.buttons[1]:Click(); page("heroes")
end)
-- Presence and versions (28 Oct 2026): Brannic's addon is older than Elyra's and not heard (the game still shows him
-- online), Elyra is AFK, Corwin offline. Brannic keeps his old version for the rest of the tour (Needs attention).
shot("heroes-presence", "Adventurers (presence, old addon)", "Invite Adventurers folded on top (U108); green ring and Old addon (Brannic), yellow AFK (Elyra), red Offline (Corwin), green Online (you)", function()
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
shot("inspect", "Inspect an Adventurer", "Someone not near (pretend Adventurers cannot be drawn): a card with the class crest, class and role, item level and the worn gear as a list in quality colours, when last near (U3); no empty model box. Right: XP, the number tiles, Whisper / Invite", function()
  -- Brannic shares gear (your items as a stand-in), so the slots and their tooltips (Shift compares) show.
  dev("hero Brannic gear")
  local p = pf("heroes"); p.sel = full("Brannic"); W():Refresh()
end)
shot("inspect-me", "Inspect yourself", "You in 3D between your gear; role, secondary role, I'm away, how to play another character", function()
  local p = pf("heroes"); p.sel = ns.Me(); W():Refresh()
end)
shot("inspect-me-bottom", "Inspect yourself (scrolled)", "Friend of the fellowship (the Leader always counts), how to play another character here", function() return bottom(pf("heroes").iscroll) end)
-- A Friend of the fellowship (SPEC §1.1): Elyra becomes one for these two shots.
prep(function() dev("hero Elyra friend") end)
shot("heroes-friend-folded", "Adventurers (Friends folded)", "Friends of the fellowship (1) under the cards, closed with the game's plus button; Invite Adventurers folded on top (U108)", function()
  local p = pf("heroes"); p.sel, p.invOpen = nil, nil; ns.char.heroesOpen = nil; page("heroes"); top(p.scroll)
end)
shot("heroes-friend", "Adventurers (a Friend of the fellowship)", "Elyra under Friends of the fellowship (1), opened (U108), in teal; the Adventurers tile one fewer, \"1 Friend\" beside the roles, \"... and 1 Friend\" under the title; the invite box opened, with As a Friend of the fellowship", function()
  local p = pf("heroes"); p.sel, p.invOpen = nil, true; ns.char.heroesOpen = { friends = true }; page("heroes"); top(p.scroll)
end)
shot("inspect-friend", "Inspect a Friend of the fellowship", "Friend of the fellowship by her name, in teal", function()
  local p = pf("heroes"); p.sel = full("Elyra"); W():Refresh()
end)
prep(function() dev("hero Elyra friend off"); pf("heroes").sel, pf("heroes").invOpen = nil, nil; ns.char.heroesOpen = nil end)
-- Needs attention is in the Inbox since U144 (on Manage until the rebuild).
shot("inbox-attention", "Inbox: what needs attention (Leader)", "Corwin below the floor, Brannic on an older addon: each on a row with Their card and Seen; the count on the Inbox button (U144, U106)", function()
  pf("heroes").sel = nil; dev("hero Corwin level 18"); ns.char.inboxSeen = nil; page("manage"); W():OpenPanel("inbox")
end)
shot("inbox-attention-seen", "Inbox: a row seen", "Corwin's row after Seen: dimmed, last, without Seen; one fewer on the Inbox button (U105, U106)", function()
  for _, it in ipairs(ns.Inbox:Items()) do
    if it.key and it.key:find("^behind:") then ns.Inbox:See(it.key) break end
  end
end)
prep(function() ns.char.inboxSeen = nil; W():HidePanels() end)
shot("manage", "Manage: Adventurers", "Two tabs; the bar to the Rules page at the top right (U143); every Adventurer with a menu, invites", function()
  page("manage")
end)
-- The Leader makes a member a Friend of the fellowship and back (the owner, 10 Nov 2026): the row's menu, opened.
shot("manage-friend-menu", "Manage: a member's menu", "Elyra's ⋯ menu open: Mark away, Make a Friend of the fellowship, Make leader, Remove in red; the menu whole, over the page", function()
  page("manage")
  for _, r in ipairs(W().pageFrames.manage.rows.items) do
    if r:IsShown() and r.who == full("Elyra") then r.menu:Click() end
  end
end)
prep(function() if ns.UI.menu then ns.UI.menu:Hide() end end)
-- U51: an invite to someone offline, sent an hour ago (written straight into this copy: no whisper goes out).
shot("manage-invite-offline", "Manage: an invite waiting for someone offline", "Jtfnobodyhere: offline: it reaches them when they log in · 23 hours left, a thin bar under it nearly full (U57); the Inbox says: The invite to Jtfnobodyhere is still open: 23 hours left (U144)", function()
  local name = full("Jtfnobodyhere")
  cur().invites[name] = time() - 3600
  ns.Sync.sent[name] = { offline = true }
  page("manage")
end)
prep(function()
  local name = full("Jtfnobodyhere")
  cur().invites[name] = nil; ns.Sync.sent[name] = nil
end)
-- Names filled in as in the game's mail box (6 Nov 2026), from a pretend list of people met lately.
-- With two pretend guild members and friends online: in their class colours, with their levels (6 Nov 2026).
shot("manage-invite-suggest", "Manage: names filled in as you type", "\"Zan\" typed: Zanara Moonbrook filled in with the rest highlighted; under the box four names: Zanara (priest white, Level 23 · Guild) and Zandar (warrior brown, Level 31 · Friend) online in their class colours, then Zandor and Zandrel (Played with lately)", function()
  page("manage")
  ns.Dev.pretendNames = { "Zandrel Brightwater", "Zandor Stonefist" }
  local Fr = ns.Friends
  Fr.all, Fr.allAt, Fr.allMe = {
    { name = ns.FullName("Zanara Moonbrook"), online = true, source = "guild", class = "PRIEST", level = 23 },
    { name = ns.FullName("Zandar Flintbeard"), online = true, source = "friend", class = "WARRIOR", level = 31 },
  }, GetTime(), ns.Me()
  local p = pf("manage")
  p.invite.edit:SetFocus()
  p.invite:SetText("Zan"); p.invite.edit:GetScript("OnTextChanged")(p.invite.edit, true)
end)
prep(function()
  local p = pf("manage")
  ns.Dev.pretendNames, ns.Friends.all = nil, nil
  p.invite:SetText(""); p.invite.edit:ClearFocus(); p.suggest:Hide()
end)
shot("manage-fellowship", "Manage: The fellowship", "Name, banner colour, every emblem; the bar to the Rules page at the top right (U143); your banner as the others see it; Leave (hands over)", function()
  page("managefellowship")
end)
-- Editing the rules, from the Rules page's Edit the rules (U143; a tab of Manage until the rebuild).
shot("rules-edit", "Rules: editing (Leader)", "Rules marked in the sidebar; the rules as a draft: size, play style, every rule; at the left page's foot the bar says Everything is published, with Done", function()
  local p = pf("rulesadmin")
  if p then p.picks = nil end
  page("rules"); pf("rules").editBar.btn:Click()
end)
-- The Publish bar with a change waiting (7 Nov 2026: the owner found no Publish for the rules).
shot("rules-edit-draft", "Rules: editing (a change waiting)", "One rule changed, the left page scrolled to its foot: the bar stays in sight under it, gold, with 1 change not published, Discard and Publish (both go back to the Rules page)", function()
  local p = pf("rulesadmin")
  if not p then return end
  local ctl = p.form.controls[1]
  for _, b in ipairs(ctl.buttons) do
    if b.value ~= cur().rules.floorTol then b:GetScript("OnClick")(b) break end
  end
  p.lscroll:Reveal(p.lscroll.contentHeight or 0, 1) -- to the foot of the form
end)
prep(function()
  local p = pf("rulesadmin")
  if not p then return end
  p.picks = nil
  p.lscroll:ToTop()
  W():Refresh()
end)
-- X2 (SPEC §9): the Tour fellowship with Hardcore and ten shared lives for these shots; Brannic falls (where you are,
-- fighting a Defias Pillager). Put back after them.
prep(function()
  local f = cur()
  TR.chalKeep = { f.challenges, f.challengesOff, f.falls }
  f.challenges, f.challengesOff, f.falls = { hardcore = true, shared = 10 }, nil, nil
  dev("hero Brannic fall")
end)
shot("heroes-fallen", "Adventurers (a Fallen Adventurer)", "Hardcore: Brannic's card a memorial (greyed crest with a skull, violet, no Online), last; Fallen, with the place, day and foe on the line (his level is the card's number); 1 Fallen beside the roles; no Recent history on the left (its fall is in Since last time)", function()
  pf("heroes").sel = nil; page("heroes"); top(pf("heroes").scroll)
end)
shot("inspect-fallen", "Inspect a Fallen Adventurer (his memorial)", "In memory of Brannic: his greyed crest with a skull on the dimmed stage, where, when and fighting whom, honoured in the Chronicle; at the foot Guild Together's memorial stone with its candle, \"Candles lit by Elyra, Corwin.\" and Light a candle (U41, U48); no gear. Right: Days together, Fallen, his journey (joined, fell, dungeons, firsts), no XP or Invite", function()
  -- U41: two pretend Adventurers light a candle (once each; they go with the falls when the challenges are put back).
  local f = cur()
  ns.Fellowship:Apply(f, { k = "candle", name = full("Brannic") }, full("Elyra"), time() - 120)
  ns.Fellowship:Apply(f, { k = "candle", name = full("Brannic") }, full("Corwin"), time() - 60)
  local p = pf("heroes"); p.sel = full("Brannic"); W():Refresh()
end)
prep(function() pf("heroes").sel = nil end)
shot("chronicle-fallen", "Chronicle (a memorial)", "In memory of Brannic: level, place, day and foe; a shared life lost, 9 of 10 left; Elyra and Corwin lit a candle for Brannic, with the flame and the chip Candle (U41)", function() chronicle("all") end)
shot("chronicle-firsts-fallen", "Chronicle (Firsts, under a challenge)", "First to fall in violet with a silver ring, not gold; only the next open level medal names who is closest (\"22 of 30\" with its ring of dots, U42), the higher ones Nobody yet", function()
  chronicle("first")
end)
-- The candles as the Overview opens after Brannic's fall: his goes out now (the lives seen were 10), so the shot catches
-- the snuff: dark, with a curl of smoke above it (none with Reduce effects); the lit ones with a warm halo.
shot("overview-lives", "Overview (shared lives)", "On the banner's picture, top left, the shared lives in light words and a row of candles: 9 of 10 lit with a warm halo, Brannic's going dark with a curl of smoke; a click opens the rulebook", function()
  ns.char.livesSeen = ns.char.livesSeen or {}
  ns.char.livesSeen[cur().id] = 10
  page("overview")
end)
-- (The tiles had shots of their own, the same pictures as these: they are in sight beside the article; check of
-- 1 Nov 2026, 15:23.)
shot("rules-challenges", "Rules (the challenges)", "The rulebook's last article: a block for Hardcore and one for Shared lives, each with its icon in a gold ring, the lives left on their own line and the candles under it; the Fallen and starting anew after them. Right, under Propose a change: Where the challenges stand, tiles two to a row: Lives left 9 / 10, Rules broken 0", function()
  page("rules"); bottom(pf("rules").lscroll); bottom(pf("rules").rscroll)
end)
shot("rules-edit-challenges", "Rules: editing (challenges)", "Each challenge with Turn off (for good; it asks first), above the size and the play style", function()
  page("rulesadmin"); top(pf("rulesadmin").lscroll)
end)
-- X3-X5: Ironman Fellowship, Walk everywhere, Lord of the Rings and Race to 60; Brannic takes a flight path and trades
-- outside, and finds the Ring.
prep(function()
  local f = cur()
  f.challenges, f.falls, f.broken, f.ring, f.race = { ironman = true, hardcore = true, white = true, walk = true, ring = true, race = true }, nil, nil, nil, nil
  dev("hero Brannic break taxi")
  dev("hero Brannic break potion")
  dev("hero Brannic ring")
end)
shot("heroes-broken", "Adventurers (broken challenges, the Ring)", "Brannic's card: the Ring in a gold ring on his portrait's corner (U50); Broke 2 challenges after his roles, no Ring-bearer there", function()
  pf("heroes").sel = nil; page("heroes"); top(pf("heroes").scroll)
end)
shot("chronicle-broken", "Chronicle (broken rules, the Ring)", "Brannic took a flight path, breaking Walk everywhere; used a potion, breaking Ironman Fellowship; found the Ring", function() chronicle("all") end)
shot("rules-challenges-more", "Rules (the challenges, X3-X5)", "The article: a block for each challenge with its icon; Broken by Brannic in red under Walk everywhere and Ironman Fellowship, who carries the Ring, Race to 60's clock, each on its own line. The tiles: Race clock, Ring-bearer Brannic, Rules broken 2", function()
  page("rules"); bottom(pf("rules").lscroll); bottom(pf("rules").rscroll)
end)
-- U49: the Ring went from Brannic to Corwin (written straight into this copy; the prep after puts it back).
shot("rules-ring-road", "Rules (the Ring's road)", "Under Lord of the Rings: The Ring's road as a path, Brannic then Corwin, each with a class icon, a gold line between, the Ring on Corwin (U58); the rule ends with how the Ring passes on (U53)", function()
  local r = cur().ring
  if r then
    r.first = { who = r.who, item = r.item }
    r.passes = { { from = r.who, to = full("Corwin"), t = time() } }
    r.who, r.guid = full("Corwin"), nil
  end
  page("rules"); bottom(pf("rules").lscroll)
end)
-- U55: Corwin carries it now; the standings (on the Chapter page since U139) mark him.
shot("chapter-ring-bearer", "Chapter (the Ring-bearer)", "Where the Adventurers stand: a small ring after Corwin's name, his presence mark after it; nobody else has one (U55)", function()
  local p = pf("chapter"); p.sel = nil; page("chapter"); top(p.rscroll)
end)
shot("rules-edit-ironman", "Rules: editing (Ironman Fellowship)", "Hardcore Fellowship and White gear only: Held by Ironman Fellowship instead of Turn off", function()
  page("rulesadmin"); top(pf("rulesadmin").lscroll)
end)
prep(function()
  local f, k = cur(), TR.chalKeep
  if k then f.challenges, f.challengesOff, f.falls = k[1], k[2], k[3] end
  f.broken, f.ring, f.race = nil, nil, nil
  TR.chalKeep = nil
  top(pf("rules").lscroll)
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
shot("gatherings-empty", "Gatherings (none yet)", "Schedule, the week ahead as seven plain day cards with Schedule (U4), and how Gatherings work", function()
  hideOverlays(); page("gatherings")
end)
shot("gather-form", "Schedule a Gathering", "The form", function()
  ns.GatherForm:Open()
end)
shot("gatherings", "Gatherings", "Upcoming Gatherings with answers; the chosen one with who is coming; the week ahead as day cards, four to a row, a day with a Gathering on its dungeon's picture with the class icons of who is coming, the chosen one marked (U4)", function()
  hideOverlays()
  ns.Gatherings:Schedule("wc", "bring potions", time() + 26 * 3600)
  ns.Dev:Hero("Brannic", "gather", TR.look.gather)
  page("gatherings")
end)
shot("overview-gatherings", "Overview (the next Gathering)", "Coming up, on the road ahead: one line about the next Gathering, readable on the picture; it opens the page (U155)", function()
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
shot("admin-chapter-2", "Journey Admin (chapter 2)", "Another chapter selected, its dungeons, each with its picture small and square at the left of its card (6 Nov 2026), Bosses: … on its own line under the roles, inside the card (check of 10 Nov 2026)", function()
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
shot("admin-add-again", "Journey Admin (a dungeon again)", "Chapter XV: Blackrock Depths clicked in from the shelf, its third placement (also in XIII, XIV); XV enlarged on the ruler (U11)", function()
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
-- U165: Settings → Raids page: Show all, before the journey is complete.
shot("raids-early", "Raids (before the journey is complete)", "Settings → Dungeons and raids → Raids page set to Show all: Raids in the sidebar before the last chapter, its help saying the raids open for the fellowship when the journey is complete, each raid locked with \"After the journey\" (or its date) and no Find group; put back after (U165)", function()
  TR.raidsShow = TR.raidsShow or ns.Settings:Get("raidsShow")
  ns.Settings:Set("raidsShow", "all")
  if pf("raids") then pf("raids").raid = nil end
  page("raids")
end)
prep(function() ns.Settings:Set("raidsShow", TR.raidsShow or "open"); TR.raidsShow = nil end)
-- The Endgame, as if the journey were complete (only for this shot; no "Endgame is open" toast).
local tourReached
shot("raids", "Raids (the Endgame)", "Each raid with its picture (Barrow Deeps its own, 6 Nov 2026), attunement and boss progress; a raid not open yet: its picture large and \"Opens in N days · 9 December\" on the right page (U63), its card's ribbon \"Opens in N days\" and no date on the card (U89)", function()
  local f = cur()
  ns.char.endgameSeen = ns.char.endgameSeen or {}
  ns.char.endgameSeen[f.id] = time()
  tourReached = f.reached
  f.reached = #f.journey.chapters + 1
  -- The first raid chosen, as a player opening the page sees it (the self-test chose its own raid before, and the
  -- right page showed one far down the list; check of 30 Oct 2026, 22:00).
  if pf("raids") then pf("raids").raid = nil end
  page("raids")
end)
shot("raids-mc", "Raids (one raid chosen)", "Molten Core where the game has it: boss progress after two kills, who is attuned, Find group. In WoW Forever (no Molten Core yet) the raid with the most bosses, not open yet: 0 kills (they count from the day it opens), no Find group", function()
  -- Molten Core where the game has it; in WoW Forever (no Molten Core announced) the raid with the most bosses.
  local key = ns.Raid("mc") and "mc"
  if not key then
    local most = -1
    for _, r in ipairs(ns.RAIDS) do
      local n = #(ns.Clears:DataBosses(r[1]) or {})
      if n > most then key, most = r[1], n end
    end
  end
  for _, n in ipairs(PRETEND) do dev("group " .. n) end
  dev("kill " .. key .. " 2")
  dev("group off")
  ns.Picture:Hide()
  page("raids")
  pf("raids").raid = key; W():Refresh()
  ns.Endgame:FindGroup(cur(), key)
end, { toast = true })
prep(function() local f = cur(); if f then f.reached = tourReached end; ns.Picture:Hide(); page("overview") end, 0.3)
prep(function() hideOverlays(); dev("tourney start") end, 0.3)
shot("tourney-signup", "Tournament (sign-up)", "Sign-up open, entrants and seeds, schedule", function()
  ns.Tourney:SignUp(true)
  for _, n in ipairs(PRETEND) do dev("hero " .. n .. " signup") end
  page("tourney")
end)
shot("tourney-bracket", "Tournament (bracket running)", "Semifinals joined to the final by bracket lines, your next duel; cards 60 high with class icons and levels (U17)", function() dev("tourney next"); W():Refresh() end)
shot("inbox-notice", "Inbox (a notice)", "Your next duel with Open the tournament and Seen (U105); the Inbox button counts it", function()
  ns.char.inboxSeen = nil; W():OpenPanel("inbox")
end, { wait = 0.3 })
prep(function() W():HidePanels() end)
shot("tourney-champion", "Tournament (over)", "The winner, between two gold cups (U48), and the hand-over", function()
  local f = cur()
  for _ = 1, 4 do
    local t = f.tourney
    if not t or t.phase ~= "running" then break end
    dev("tourney next")
  end
  W():Refresh()
end)
shot("history", "Chronicle: The fellowship (its story)", "The Chronicle's third tab (U142): joined, rules, votes, Gatherings and the tournament under their days (U132); founded, the number tiles, the chapters so far (U9) and Leaders", function()
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
shot("settings", "Settings", "Folding sections (U10): the book, messages and help on the left; the toasts open on the right under three headings, Your journey, The fellowship, Dungeons and raids (U86), each heading with a tick of its own that turns its whole group on or off, in line with the ticks under it (U116), the tracker folded with what is set; Dungeons and raids folded: \"dungeons: all · raids: open ones\" (U164, U165); under help, The key opens: Chapter (U107)", function()
  ns.AdminDraft:Discard(); W():OpenSettings(); pf("settings"):Fold("toasts", true)
end)
shot("settings-tracker-off", "Settings (tracker off)", "The tracker open (the toasts fold), its lines faded while it is off", function()
  W():OpenSettings(); pf("settings"):Fold("tracker", true); ns.Settings:Set("tracker", false); W():Refresh()
end)
shot("toast-move", "Toast position (move mode)", "The sample banner to drag", function()
  ns.Settings:Set("tracker", true); W():OpenSettings(); ns.Toasts:StartMove()
end)

-- Toasts on their own (the book closed).
-- more.dungeon may be a function: the place is looked up when the shot is taken (each game has its own list).
local function toast(kind, title, text, more)
  return function()
    ns.Toasts:StopMove(); W():Close()
    local m = more and { dungeon = more.dungeon } or nil
    if m and type(m.dungeon) == "function" then m.dungeon = m.dungeon() end
    -- A text can be a function, made when the shot runs: ns.VERSION, say, is set only at ADDON_LOADED, after this file.
    ns.Toasts:Push(kind, type(title) == "function" and title() or title, type(text) == "function" and text() or text, nil, m)
  end
end
-- A clear message (U7): the place's picture on the left, its name, and who was there in their class colours.
local function cleared(key)
  return function()
    ns.Toasts:StopMove(); W():Close()
    local names = { ns.Me() }
    for _, n in ipairs(PRETEND) do names[#names + 1] = full(n) end
    local k = key()
    if k then ns.Clears:ClearedToast(cur(), k, names) end
  end
end
-- The Deadmines and Molten Core where this game has them, else its first dungeon and raid with a loading screen
-- (WoW Forever: Onyxia's Lair). Asked when the shot runs: the lists are this game's only once the addon has loaded.
local function first(list, want)
  if ns.Dungeon(want) then return want end
  for _, d in ipairs(list) do if ns.DungeonScreen(d[1]) then return d[1] end end
  return list[1] and list[1][1]
end
shot("toast-clear", "Toast: dungeon cleared", "The dungeon's picture, its name and who was there",
  cleared(function() return first(ns.DUNGEONS, "dm") end), { toast = true })
shot("toast-clear-raid", "Toast: raid cleared", "The raid's picture, its name and who was there",
  cleared(function() return first(ns.RAIDS, "mc") end), { toast = true })
shot("toast-clear-new", "Toast: a new Forever dungeon cleared", "Shaper's Terrace with its own picture (6 Nov 2026); another dungeon where this game has no Shaper's Terrace",
  cleared(function() return first(ns.DUNGEONS, "shaper") end), { toast = true })
shot("toast-hero-floor", "Toast: a Hero reaches the floor", "A normal toast", toast("heroFloor", L.T_HERO_FLOOR:format("Brannic"), L.T_HERO_FLOOR_TEXT:format(21, "Corwin")), { toast = true })
shot("toast-chapter", "Toast: chapter unlocked (big)", "The big banner in the middle of the screen, as the game's Level Up banner (U2)", toast("chapter", L.T_CHAPTER:format("IV"), L.T_CHAPTER_TEXT:format("Chains and Tides", 25, 29)), { toast = true })
shot("toast-journey", "Toast: journey complete (big)", "The biggest moment, mid-screen too (U2)", toast("journey", L.T_JOURNEY, L.T_JOURNEY_TEXT:format("Tour")), { toast = true })
shot("toast-chapter-settled", "Toast: chapter unlocked, settled", "After about three seconds the big banner has slid up to the toasts' place (U2)", toast("chapter", L.T_CHAPTER:format("IV"), L.T_CHAPTER_TEXT:format("Chains and Tides", 25, 29)), { toast = true, wait = 3.3 })
shot("toast-gathering", "Toast: a Gathering soon", "The reminder, with the dungeon's picture (U8)", toast("gathering", L.G_SOON,
  L.G_SOON_TEXT:format("The Deadmines", "20:00"), { dungeon = function() return first(ns.DUNGEONS, "dm") end }), { toast = true })
-- The version notice (6 Nov 2026): heard from someone in the guild or group with a newer version.
shot("toast-version", "Toast: a newer version is out", "Brannic has 9.9.0 (you have yours): update when you can", toast("version",
  L.TOAST_VERSION_TITLE, function() return L.TOAST_VERSION_TEXT:format("Brannic", "9.9.0",
    ns.ParseVersion(ns.VERSION) and ns.VERSION or "1.0.4") end), -- the Dev copy has no version: a pretend one
  { toast = true })
shot("toast-ahead", "Toast: you pull ahead", "Two or more levels above an Adventurer", toast("ahead", L.T_AHEAD:format(3, "Corwin"),
  L.T_AHEAD_TEXT:format("Corwin")), { toast = true })
shot("toast-session", "Toast: session recap (big)", "After playing together: how long, with whom, what you did", function()
  ns.Toasts:StopMove(); W():Close()
  ns.Session:Toast({ start = time() - 5100, stop = time(), with = { full("Brannic"), full("Elyra") },
    levels = { { ns.Me(), 20, 22 }, { full("Brannic"), 21, 22 } }, runs = { { key = "dm", cleared = true } }, bosses = 7,
    quests = 9, chapters = { 3 } })
end, { toast = true })
shot("toast-long", "Toast: a long text", "Wraps to more lines; the banner grows", toast("clear", L.TOAST_CLEARED,
  L.TOAST_CLEAR_FOR:format("Brannic, Elyra, Corwin and you") .. " " .. L.TOAST_ENDGAME_TEXT), { toast = true })
shot("toast-attune", "Toast: an attunement opens", "At the level where it can be started, with the raid's picture (U8)",
  -- The title names the raid whose picture it shows (WoW Forever has no Molten Core; check of 6 Nov 2026).
  toast("attune", function() return L.TOAST_ATTUNE_TITLE:format(ns.Raid(first(ns.RAIDS, "mc"))[2]) end, L.TOAST_ATTUNE_RAID,
    { dungeon = function() return first(ns.RAIDS, "mc") end }), { toast = true })
shot("toast-dquest", "Toast: dungeon quests to pick up", "Once per dungeon of this chapter or the next, when its first quest opens to you, with the dungeon's picture (U79)",
  toast("dquest", function() return ns.Dungeon("dm")[2] end, function()
    return L.TOAST_DQ_PICK_IN:format(L.DQ_N_QUESTS:format(3), "Westfall") .. " " .. L.TOAST_DQ_CHAIN:format("Red Silk Bandanas")
  end, { dungeon = "dm" }), { toast = true })
shot("toast-dready", "Toast: ready for a dungeon", "\"Ready for The Deadmines\": once per dungeon of your chapter, never in combat, with its picture (U98); a click opens its page",
  toast("dready", L.T_READY, function() return L.T_READY_TEXT:format(ns.Dungeon("dm")[2]) end, { dungeon = "dm" }), { toast = true })
shot("toast-dallready", "Toast: everyone is ready", "\"Everyone is ready for The Deadmines\": once per dungeon when every counted Adventurer is (U99)",
  toast("dallready", L.T_ALL_READY, function() return L.T_ALL_READY_TEXT:format(ns.Dungeon("dm")[2]) end, { dungeon = "dm" }), { toast = true })
shot("toast-dshare", "Toast: a quest to share", "In a dungeon, \"Share Collecting Memories: Pata needs it.\" with the Deadmines' picture, Share quest and Not now; it stays until answered, then the next quest (U178)", function()
  ns.Toasts:StopMove(); W():Close()
  ns.Toasts:Push("dshare", L.T_SHARE, L.T_SHARE_1:format("Collecting Memories", "Pata"), nil,
    { dungeon = "dm", actions = { { L.SHARE_QUEST, function() end }, { L.NOT_NOW, function() end } } })
end, { toast = true })
shot("toast-invite", "Toast: an invitation", "\"Lea invites you to Band.\" with Accept and Decline; it stays until answered (U109)", function()
  ns.Toasts:StopMove(); W():Close()
  ns.Toasts:Push("invite", L.T_INVITE, L.INBOX_INVITE:format("Lea", "Band"), nil,
    { icon = ns.ICONS.toast_invite, actions = { { L.ACCEPT, function() end }, { L.DECLINE, function() end } } })
end, { toast = true })
shot("toast-dremind", "Toast: a reminder", "\"Pata reminds you: 2 Deadmines quests to pick up.\" with the dungeon's picture and who sent it (U100)",
  toast("dremind", L.REMIND_TITLE, function() return L.REMIND_N:format("Pata", 2, "Deadmines") end, { dungeon = "dm", who = "Pata" }), { toast = true })
shot("toast-room", "Toast: leave room for the dungeons", "At the stop point (and half a level before it): the dungeon quests will take you to the cap, stop questing elsewhere (U78)",
  toast("room", L.TOAST_ROOM_NOW_TITLE, L.TOAST_ROOM_NOW), { toast = true })
shot("toast-first", "Toast: a fellowship first", "\"Brannic is the first to ride a mount.\"", toast("first", L.T_FIRST:format("Brannic"), L.FIRST_MOUNT:format("Brannic")), { toast = true })
shot("toast-ring-passed", "Toast: the Ring passes on", "Brannic left: the Ring passes to Corwin, shown as the two names with their class icons, Brannic » Corwin (U56), in the big moments' gold frame at the normal size, with a soft chime (U52)", function()
  ns.Toasts:StopMove(); W():Close()
  ns.Toasts:Push("challenge", L.T_RING_PASSED, ns.Challenges:HandOver(cur(), full("Brannic"), full("Corwin")), nil,
    ns.Challenges:ToastOf("ring", { framed = true, sound = "ring" }))
end, { toast = true })
shot("toast-fallen", "Toast: an Adventurer has fallen", "Hardcore: Brannic has fallen, his level, the place and the foe; honoured in the Chronicle. The big banner in violet and silver (the moment frame and the chapter picture tinted), mid-screen first, with To the memorial in its corner (U43)", function()
  ns.Toasts:StopMove(); W():Close()
  local e = { who = full("Brannic"), t = time(), lvl = ns.Hero:Level(cur(), full("Brannic")) or 22, zone = GetZoneText and GetZoneText() or nil, foe = L.DEV_FOE, fatal = true, left = 0 }
  ns.Toasts:Push("challenge", ns.Challenges:FallToast(cur(), e))
end, { toast = true })
shot("toast-broken", "Toast: a challenge is broken", "Brannic took a flight path, breaking Walk everywhere: Walk everywhere's boots, not the skull, and WALK EVERYWHERE above the title", function()
  ns.Toasts:StopMove(); W():Close()
  local e = { who = full("Brannic"), t = time(), what = "taxi", key = "walk" }
  ns.Toasts:Push("challenge", L.T_BROKE, ns.Challenges:BreakText(e), "chronicle", ns.Challenges:ToastOf("walk"))
end, { toast = true })
shot("toast-endgame", "Toast: the Endgame is open (big)", "After the journey: the raids", toast("journey", L.TOAST_ENDGAME,
  L.TOAST_ENDGAME_TEXT), { toast = true })
shot("tracker", "The tracker on the screen", "Chapter, status with the dungeons cleared on the same line (U159), XP bar, you (\"Level 18 · 2.6 to the cap\", one line) with the little bar to the floor or cap, the next step, who is online, a Gathering soon; an icon on each line (U13); the mouse on the title: \"Drag to move · Hold Ctrl to drag by any line\" (U92)", function()
  ns.Settings:Set("trackerDock", false) -- (its own panel here; docked in "tracker-docked")
  ns.Toasts.frame:Hide(); W():Close(); ns.Tracker:SetFolded(false); ns.Tracker:Refresh()
  local bar = ns.Tracker.frame.bar
  bar:GetScript("OnEnter")(bar)
end)
shot("tracker-all", "The tracker, every line on", "Also Prequest (gold, a chain step to pick up now), shared quests, your next duel and the inbox (Settings); where to stop questing in red on its own line under your little bar, not touching it", function()
  GameTooltip:Hide()
  -- A prequest to pick up (U124), made up when your log has none; put back in tracker-hidden.
  if not ns.Together:StartEarly(ns.Fellowship:Current()) then TR.groups = ns.QuestLists.Groups; ns.QuestLists.Groups = ns.Dev.FakeChain end
  local S = ns.Settings
  TR.savedLines = {}
  for _, key in ipairs(S.TRACKER_LINES) do TR.savedLines[key] = S:TrackerLineOn(key); S:SetTrackerLine(key, true) end
  dev("hero Brannic propose")
  -- Where to stop questing, in red under your little bar (made up; put back in tracker-hidden).
  local R, ch = ns.Room, ns.Journey:Current(cur())
  local cap = ch and ch.cap or 20
  local fake = { now = cap - 3, levels = 2.4, to = cap + 0.4, cap = cap, tol = 0, limit = cap, stop = cap - 2.4,
    unknown = 0, n = ch and ch.n or 0 }
  TR.roomChapter = R.Chapter
  R.Chapter = function() return fake end
  ns.Tracker:Refresh()
end)
shot("tracker-docked", "The tracker under the game's quest tracker", "Settings: one more section under the game's quest list, with the game's section header, fold button and fonts; every line on, the red stop line clear of the little bar (a client without the game's tracker keeps the panel)", function()
  ns.Settings:Set("trackerDock", true)
  ns.Tracker:Refresh()
end)
shot("tracker-hidden", "The tracker, hidden", "Nothing on the screen until pointed at; it shows for a moment when something changes", function()
  ns.Settings:Set("trackerDock", false)
  for key, on in pairs(TR.savedLines or {}) do ns.Settings:SetTrackerLine(key, on) end
  if TR.groups then ns.QuestLists.Groups, TR.groups = TR.groups, nil end
  if TR.roomChapter then ns.Room.Chapter, TR.roomChapter = TR.roomChapter, nil end
  ns.Settings:Set("trackerHover", true)
  -- The lines just changed, so the first refresh starts a peek; the second one, after it is cleared, hides it (the
  -- shot showed the whole tracker; seen in the seventh check).
  ns.Tracker:Refresh()
  ns.Tracker.frame.peekUntil = nil; ns.Tracker:Refresh()
end)
shot("picture-moment", "Picture after the final boss", "Take a picture as the one main button; Without the interface and Group photo smaller beside it (U91); Done", function()
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
shot("walk-offer", "Show me around? (the offer)", "After the setup guide: the card beside the book (right of it where the screen has room, else left; in full screen the book's lower right corner), over nothing on the page (U88); Show me around / Later", function()
  ns.Picture:Hide(); hideOverlays(); W():Open("overview"); ns.Walkthrough:Offer("leader")
end)
shot("walk-intro", "Walkthrough: Welcome", "The sample fellowship in the header, framed; the rest dimmed", function() walk("leader", "INTRO") end)
shot("walk-focus", "Walkthrough: Focus now", "Focus now framed with sparks; the guide card beside it (U146)", function() walk("leader", "FOCUS") end)
shot("walk-stand", "Walkthrough: Where we stand", "The chapter's banner framed whole, its picture and Where we stand along its foot; the guide card beside it, covering neither", function() walk("leader", "STAND") end)
shot("walk-chapter", "Walkthrough: Your To do", "The To do's heading to the first dungeon row; the Leader's text about marking a clear", function() walk("leader", "CHAPTER") end)
shot("walk-manage", "Walkthrough: Manage (Leader)", "Its Adventurers tab on the sample; two tabs, what needs you is in the Inbox", function() walk("leader", "MANAGE") end)
shot("walk-header", "Walkthrough: header buttons", "Your characters, inbox and settings framed together", function() walk("leader", "HEADER") end)
shot("walk-tracker", "Walkthrough: the tracker", "Outside the book: the tracker framed, the book dimmed", function() walk("leader", "TRACKER") end)
shot("walk-rules", "Walkthrough: Rules (Leader)", "The rulebook; you edit it here: Edit the rules, then Publish (U143)", function() walk("leader", "RULES") end)
shot("walk-member-invite", "Walkthrough: Invite (Adventurer)", "Everyone invites on the Adventurers page", function() walk("member", "INVITE") end)
shot("walk-member-rules", "Walkthrough: Rules (Adventurer)", "Propose and vote; the sample's open vote", function() walk("member", "RULES") end)
shot("walk-done", "Walkthrough: the end", "Done; Start the tour again from Settings", function() walk("member", "DONE") end)
-- The first tour (the owner, 8 Nov 2026): the Overview and what you see first; no page shows you around by itself since
-- the rebuild (U146): its ? does.
shot("walk-first", "First tour: Since last time", "The short first tour after the setup guide, 4 of 8 (after Welcome: the sidebar, Focus now, Since last time, Coming up, Where we stand, the header, the tracker)", function()
  local WK = ns.Walkthrough
  WK:Stop(); WK:Start("leader", nil, true)
  for i, s in ipairs(WK.steps) do if s.id == "SINCE" then WK:Go(i) end end
end)
shot("walk-first-done", "First tour: the end", "Have a look around: your own fellowship again, invite your Adventurers; the ? at the top explains each page; Done", function()
  local WK = ns.Walkthrough
  WK:Go(#WK.steps)
end)
prep(function() ns.Walkthrough:Stop() end)
-- About this page: the header's ? (beside Your characters) on your own fellowship.
shot("page-help", "About this page: Chapter", "After the header's ?: Chapter's left page framed, the card says what the page is for, About this page, 1 of 2, Next and Close", function()
  hideOverlays(); W():Open(); page("chapter"); ns.Walkthrough:StartPage("chapter")
end)
shot("page-help-right", "About this page: its right page", "Next: Chapter's right page framed, 2 of 2, Back and Done", function() ns.Walkthrough:Next() end)
prep(function() ns.Walkthrough:Stop() end)
-- The Overview's ? goes part by part (U146): its picture and Where we stand, Focus now, Since last time, Coming up.
shot("page-help-overview", "About this page: the Overview, part by part", "After the ?: Focus now framed, 2 of 4, what it is for; Back, Next and Close", function()
  hideOverlays(); W():Open(); page("overview"); ns.Walkthrough:StartPage("overview"); ns.Walkthrough:Next()
end)
prep(function() ns.Walkthrough:Stop() end)
-- U166: the header's bug, left of the ?.
shot("bug-report", "Report a bug", "After the header's bug (Blizzard's, as its issue reporter has it; left of the ?): Report a bug, what to send, your version and the game's, GitHub's issues and the CurseForge page's comments to copy", function()
  hideOverlays(); W():Open(); page("overview"); ns.ConflictWindow:ToggleBug()
end)
prep(function() hideOverlays() end)

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
shot("watch-characters", "Your characters: Follow this fellowship", "Another character's fellowship on top, followed live, with the Follow button; the others hidden", function()
  pf("heroes").sel = nil
  ns.Characters.showAll = false
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
-- Conflicts (3 Nov 2026): what was found, the report to copy and where to post it.
shot("sync-conflict", "Something does not match", "Two copies named other Ring-bearers: the report window; what differs one line each with its icon (U54): the One Ring, the votes; Select the report clicked, \"Selected: press Ctrl+C\" beside it (U59)", function()
  local f = cur()
  ns.ConflictWindow:Open({ t = time(), kind = "disagree", with = full("Brannic"), parts = { "ring", "votes" },
    details = { ring = { here = ns.Short(ns.Me()), theirs = "Brannic" } }, fid = f and f.id, name = f and f.name or TR.look.name,
    v = f and f.v or 1, ver = ns.VERSION, game = ns.Game() })
  ns.ConflictWindow:SelectReport()
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
shot("fullscreen", "Full screen", "The book fills the whole screen, its leather at the edges; the logo in the header; the Overview's sheet across both halves, everything in view, nothing to scroll (U139)", function()
  ns.Settings:Set("size", 1); ns.Settings:Set("fullscreen", true); page("overview")
end)
shot("fullscreen-settings", "Full screen: Settings", "The flat sheet in full screen: both columns together in the middle, Back over the left one; the condense button beside Close; the Full screen box ticked", function()
  W():OpenSettings()
end)
shot("fullscreen-heroes", "Full screen: Adventurers", "A long list on the taller page; the crest and name right of the logo", function()
  W():CloseSettings(); page("heroes")
end)
shot("fullscreen-admin", "Full screen: Journey Admin", "The ruler across the whole width, the chapter list filling the left half, the chapter's pane in the middle of the right half (U94)", function()
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

-- The game's HDR output dims every screenshot (the check of 7 Nov 2026: the parchment at about half its brightness):
-- off while the tour takes them, then as it was. The old value is kept in the saved data, so after a /reload in the
-- middle it is put back at login.
local HDR = "HDROutput"
local function cvar(k) return C_CVar and C_CVar.GetCVar and C_CVar.GetCVar(k) or nil end
function TR:HdrOff()
  local v = cvar(HDR)
  if v and v ~= "0" then
    ns.db.hdrWas = ns.db.hdrWas or v
    pcall(C_CVar.SetCVar, HDR, "0")
  end
  return v
end
function TR:HdrBack()
  if not ns.db.hdrWas then return end
  pcall(C_CVar.SetCVar, HDR, ns.db.hdrWas)
  ns.db.hdrWas = nil
end
ns:RegisterEvent("PLAYER_ENTERING_WORLD", function() if not TR.running then TR:HdrBack() end end)

function TR:Finish(keep)
  local r = self.rec
  self:ShowGameUI()
  self:HdrBack()
  hideOverlays()
  ns.Toasts:StopMove()
  ns.Theme.forceKey = nil
  for k, v in pairs(self.saved or {}) do ns.Settings:Set(k, v) end
  ns.Theme:Apply()
  ns.char.setupDone = self.savedSetup
  -- The walkthrough shots start and stop tours: what this character has seen, as it was.
  ns.char.walk = self.savedWalk.walk
  dev("pace off"); dev("level off"); dev("group off"); dev("tourney off")
  ns.Dev:WatchForget()
  ns.Dev.pretendTrial = nil
  ns.Dev.pretendNames = nil
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
  local done = self.onDone
  self.onDone = nil
  -- Within /jtf check the check says when all is done: a "Type /reload" between its tour and the README's pictures
  -- would cut them short.
  if not done then ns:Print((self.brand and L.BRAND_DONE or L.TOUR_DONE):format(#r.shots), true) end
  self.brand, self.look = nil, self.TOUR_LOOK
  if done then done(self.stopped) end
  -- Said last, after "Check done", so it is not missed.
  if self.stopped then ns:Print(L.CHECK_COVERED:format(self.stopped), true) end
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
-- only = { key = true } (areas that stand alone, Dev/Areas.lua): only their shots, nothing else set up,
-- onDone = function }.
function TR:Run(arg, opts)
  if self.running then return end
  if ns.Combat:InCombat() then ns:Print(L.SELFTEST_COMBAT, true) return end
  if cur() then ns:Print(L.SELFTEST_IN_FELLOWSHIP, true) return end
  local keep = arg == "keep"
  opts = opts or {}
  local areas, ids = opts.areas, opts.ids
  self.look, self.brand = opts.brand or self.TOUR_LOOK, opts.brand
  self.onDone, self.stopped = opts.onDone, nil
  self.running = true
  self.saved = { theme = ns.Settings:Get("theme"), size = ns.Settings:Get("size"), chat = ns.Settings:Get("chat"),
    trackerHover = ns.Settings:Get("trackerHover"), trackerDock = ns.Settings:Get("trackerDock"), fullscreen = ns.Settings:Get("fullscreen") }
  -- The setup guide would take over after joining and founding: seen for the tour, as it was afterwards.
  self.savedSetup = ns.char.setupDone
  local copy = function(t) return t and ns.Serialize.Decode(ns.Serialize.Encode(t)) end
  self.savedWalk = { walk = copy(ns.char.walk) }
  ns.char.setupDone = true
  -- A branding run keeps its own list (JourneyTogetherForeverDB.brand), so /jtf check and /jtf brand can run one
  -- after the other before a single /reload.
  local rec = { started = time(), shots = {}, problems = {}, areas = areas, brand = opts.brand and true or nil }
  self.rec = rec
  if opts.brand then ns.db.brand = rec else ns.db.tour = rec end
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
  -- HDR as it was and as it is now, for the report: was "1", now "0" when the tour turned it off.
  rec.hdr = { was = self:HdrOff(), now = cvar(HDR) }
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
    if opts.only and (s.prep or not wanted(s, areas, ids)) then return nextShot() end
    local res
    local ok, err = xpcall(function() res = s.fn() end, trace)
    if not ok then
      local list = rec.problems
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
      local list = rec.shots
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
      -- Another window over the book would be in every picture from here on (the game's Choose your Input Device
      -- window covered all 222 of the check of 10 Nov 2026, 14:31): the run stops and says which.
      local okCover, cover = pcall(TR.Covering, TR)
      if okCover and cover then
        rec.problems[#rec.problems + 1] = { id = s.id, err = "stopped: " .. cover .. " was open over the book" }
        TR.stopped = cover
        return TR:Finish(keep)
      end
      -- The layout check (Dev/Layout.lua): what the game measures on this screen, before the picture.
      local okScan, layout = pcall(ns.Layout.Scan, ns.Layout)
      local okCrop, crop = true, nil
      if type(b) == "table" then okCrop, crop = pcall(TR.CropFor, TR, b) end
      if Screenshot then Screenshot() end
      local list = rec.shots
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
-- 0.11 and after (the owner, 1 Nov 2026): the challenges, the rulebook's challenge article, the memorial page, the
-- firsts' cabinet and What's New. 1.4 (the owner, 8 Nov 2026): the Quests page and the Dungeon page with a prequest
-- chain. 1.5 (the rebuild, U144): the Quests page's shared quests, since its Dungeon quests tab went.
TR.BRAND = {
  { id = "create-2", file = "play-style" },
  { id = "create-challenges-tip", file = "challenges" },
  { id = "create-chapters", file = "journey-editor" },
  { id = "overview-ready", file = "overview" },
  { id = "chapter", file = "chapter" },
  { id = "quests", file = "quests" },
  { id = "dungeon-page-chain", file = "dungeon-page" },
  { id = "rules-challenges-more", file = "challenges-rulebook" },
  { id = "inspect-fallen", file = "memorial" },
  { id = "chronicle-firsts", file = "firsts" },
  { id = "news", file = "whats-new" },
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
  role = "DPS", roles = { Brannic = "Tank", Elyra = "Healer" }, gather = L.BRAND_GATHER_TEXT, quest = L.BRAND_QUEST_TEXT }
-- Room around what a picture keeps, in UIParent units.
TR.BRAND_PAD = { book = 4, toast = 28, tracker = 14 }

-- onDone (optional): called when the pictures are done (/jtf check takes them after its tour).
function TR:Brand(onDone)
  if UnitFactionGroup("player") ~= "Alliance" then ns:Print(L.BRAND_FACTION, true)
  else
    local ids = {}
    for _, b in ipairs(self.BRAND) do ids[b.id] = b end
    self:Run(nil, { ids = ids, brand = self.BRAND_LOOK, onDone = onDone })
  end
  -- Not started (another faction, in combat): the caller still hears that it is over.
  if not self.running and onDone then onDone() end
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

-- The name of a window over the book (over the screen's middle while the book is closed), or nil: one of the game's
-- or another addon's, named, shown, taking the mouse and drawn above the book (a strata above its HIGH, or HIGH at a
-- higher level; tooltips left out). The game's error window is not one: the tour closes it before each picture.
local ABOVE = { DIALOG = true, FULLSCREEN = true, FULLSCREEN_DIALOG = true }
-- One of UIParent's frames: its name when it covers the point x, y above the book's level, else nil.
local function covers(f, x, y, level)
  if f.IsForbidden and f:IsForbidden() then return nil end
  local name = f.GetName and f:GetName()
  local strata = name and f:GetFrameStrata()
  if name and name ~= "ScriptErrorsFrame" and not name:find("^JourneyTogetherForever") and f:IsVisible()
    and f:IsMouseEnabled() and (ABOVE[strata] or strata == "HIGH" and (f:GetFrameLevel() or 0) > level)
    and (f:GetEffectiveAlpha() or 1) > 0.5 then
    local fl, fb, fr, ft = uiRect(f)
    if fl and x > fl and x < fr and y > fb and y < ft then return name end
  end
end

function TR:Covering()
  local book = W().frame
  local l, b, r, t = uiRect(book and book:IsVisible() and book or UIParent)
  if not l then return nil end
  local x, y = (l + r) / 2, (b + t) / 2
  local level = book and book:GetFrameLevel() or 0
  for _, f in ipairs({ UIParent:GetChildren() }) do
    -- A frame the game forbids addons to read, or one whose place is secret, errors: it is left out (the first
    -- /jtf check in the game, 10 Nov 2026, stopped here without a word).
    local ok, name = pcall(covers, f, x, y, level)
    if ok and name then return name end
  end
end
