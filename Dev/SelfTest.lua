-- /jtf selftest: runs through the in-game checklist by itself on a character without a fellowship. It walks through
-- Create a Fellowship and the journey editor, then founds a "Selftest" fellowship with pretend Heroes (nothing is
-- whispered to real players, no real group invites), and checks every feature: the art, crests, invites, levels and
-- catch-up, Since, chapters and clears, the picture moment, milestones, the Endgame and raids, quests and
-- attunements, Gatherings, votes, the inbox, ranks, away, presence and versions, takeover, Journey Admin, History,
-- the cap, toasts, the tournament, the book in combat, the Discord board, settings. At the end it removes the pretend Heroes and
-- leaves, which ends the fellowship ("/jtf selftest keep" keeps it). Screenshots are the tour's: /jtf check runs
-- both (Dev/Check.lua); Dev/Areas.lua puts every step and shot in a feature area.
-- The report goes to JourneyTogetherForeverDB.selftest; it reaches the disk with the next /reload or logout.
local _, ns = ...
local L = ns.L
local ST = { WAIT = 0.6 }
ns.SelfTest = ST

local PRETEND = { "Brannic", "Elyra", "Corwin" }

local function report() return ns.db.selftest end

local function add(name, ok, detail, ms)
  local r = report()
  local areas = ns.CheckAreas and ns.CheckAreas:ForStep(name) or {}
  r.steps[#r.steps + 1] = { name = name, ok = ok and true or false, detail = detail, area = areas[1], ms = ms }
  if ok then r.passed = r.passed + 1 else r.failed = r.failed + 1 end
end

local function cur() return ns.Fellowship:Current() end

-- Did a toast of this kind (and with this text) show during the run?
local function toastSeen(kind, text)
  for _, t in ipairs(report().toasts) do
    if (not kind or t.kind == kind) and (not text or (t.text or ""):find(text, 1, true)) then return true end
  end
  return false
end

-- Does this client say whether a file exists (the game: true / false)? The unit-test harness answers nothing, so
-- checks of our art and of drawn sizes only count in the game.
local function inGame()
  local t = UIParent:CreateTexture()
  local r = t:SetTexture(ns.MEDIA .. "Logo")
  t:Hide()
  return r ~= nil
end
local function dev(cmd) ns.Dev:Command(cmd) end
local function full(name) return ns.FullName(name) end
local function click(b) b:GetScript("OnClick")(b) end

-- Checks inside a step: each records its own line; a step fails when any check failed.
local Check = {}
Check.__index = Check
function Check:That(cond, what) self.lines[#self.lines + 1] = (cond and "ok: " or "FAIL: ") .. what; if not cond then self.bad = true end return cond end
function Check:Eq(got, want, what) return self:That(got == want, ("%s (got %s, want %s)"):format(what, tostring(got), tostring(want))) end
function Check:Has(text, part, what) return self:That(type(text) == "string" and text:find(part, 1, true) ~= nil, ("%s (%s)"):format(what, tostring(text))) end
-- Gives the game a frame before going on: a long step does its work in parts, so no part runs past the game's time
-- limit for addon code ("exceeded its execution time limit", 29 Oct 2026). Outside the game's runner it does nothing.
function Check:Yield() if self.co and coroutine.running() == self.co then coroutine.yield() end end

---------------------------------------------------------------------------
-- Steps
---------------------------------------------------------------------------
local steps = {}
ST.steps = steps -- for /jtf check and tests/test_check.lua (every step belongs to a feature area: Dev/Areas.lua)
local function step(name, fn, wait) steps[#steps + 1] = { name = name, fn = fn, wait = wait } end
-- Opens a page between checks (the screenshots are the tour's now: /jtf check takes them all in one place).
local function shot(name, show)
  steps[#steps + 1] = { name = "show: " .. name, fn = function(c)
    if show then show() end
    c:That(ns.Window:IsOpen(), "the book is open")
  end }
end

-- The game and character the report comes from (also when only an area that stands alone runs).
function ST.Env()
  return { version = ns.VERSION, build = select(4, GetBuildInfo()), faction = (UnitFactionGroup("player")),
    level = UnitLevel("player"), locale = GetLocale and GetLocale() }
end

-- What the game offers (the parts we could not check outside the game).
step("game APIs", function(c)
  local r = report()
  r.env = ST.Env()
  local apis = {
    InviteUnit = (C_PartyInfo and C_PartyInfo.InviteUnit) or InviteUnit, QuestLogPushQuest = QuestLogPushQuest,
    IsPushableQuest = C_QuestLog and C_QuestLog.IsPushableQuest, SendTell = (ChatFrameUtil and ChatFrameUtil.SendTell) or ChatFrame_SendTell,
    GetItemCount = C_Item and C_Item.GetItemCount, UnitIsAFK = UnitIsAFK, Screenshot = Screenshot,
    InChatMessagingLockdown = C_ChatInfo and C_ChatInfo.InChatMessagingLockdown,
  }
  -- Trial and lapsed accounts cannot send addon messages in Forever (ns.Trial): what this account is.
  r.trial = { trial = IsTrialAccount and IsTrialAccount() or false, veteran = IsVeteranTrialAccount and IsVeteranTrialAccount() or false }
  r.apis = {}
  for k, v in pairs(apis) do r.apis[k] = v ~= nil end
  c:That(apis.InviteUnit ~= nil, "a group invite function exists")
  c:That(apis.SendTell ~= nil, "whisper box function exists")
end)

-- Icons and art: which of our textures the client has.
step("textures", function(c)
  local t = UIParent:CreateTexture()
  local missing = {}
  for key, path in pairs(ns.ICONS) do
    if t:SetTexture(path) == false then missing[#missing + 1] = key end
  end
  -- Every dungeon and raid: a picture of its own (the game's loading screen or our tile), not the default tile.
  local defaults = {}
  for _, d in ipairs(ns.DUNGEONS) do
    local ok, default = ns.SetDungeonArt(t, d[1], 352, 104)
    if not ok then missing[#missing + 1] = "dungeon art " .. d[1] elseif default then defaults[#defaults + 1] = d[1] end
  end
  for _, r in ipairs(ns.RAIDS) do
    local ok, default = ns.SetDungeonArt(t, r[1], 352, 104)
    if not ok then missing[#missing + 1] = "raid art " .. r[1] elseif default then defaults[#defaults + 1] = r[1] end
  end
  -- Our own art in Media.
  local media = { "Logo", "LogoSmall", "KeyJourney", "KeyGuild", "HeaderRoster", "HeaderCouncil", "HeaderArena",
    "HeaderCalendar", "HordeRoster", "HordeCouncil", "HordeArena", "HordeBoard", "HordeHall", "DialogFrame", "WindowFrame", "MomentFrame",
    "IconSetHorde", "PageJoin", "PageQuest", "PageAttune", "PageTourney", "PageSince", "PageGatherings", "PageCompanions",
    "MedallionRing", "Emblems", "IconSet", "CrestAlliansens", "EmptyQuests", "EmptyHistory", "EmptyGatherings", "EmptySince", "EmptyVotes", "EmptyJoin" }
  for i = 1, 14 do media[#media + 1] = ("Chapter%02d"):format(i) end
  media[#media + 1] = "ChapterPrologue"
  for _, tile in pairs(ns.DUNGEON_TILE) do media[#media + 1] = tile end
  for _, name in ipairs(media) do
    if t:SetTexture(ns.MEDIA .. name) == false then missing[#missing + 1] = "Media\\" .. name end
  end
  table.sort(missing); table.sort(defaults)
  report().missingTextures = missing
  report().defaultDungeonArt = defaults
  t:Hide()
  c:That(#missing == 0, #missing == 0 and "every texture loads" or ("missing: " .. table.concat(missing, ", ")))
  if inGame() then
    c:That(true, #defaults == 0 and "every dungeon has a picture of its own" or ("default picture: " .. table.concat(defaults, ", ")))
  end
end)

-- Boss data (Data/Encounters.lua) for this game version: every dungeon and raid has its bosses, made from this
-- client's build. Forever is the game the addon is for: a gap there fails (run tools/update-game-data.ps1 on the new
-- build); on retail, where we test until Forever is out, it is a note.
step("boss data", function(c)
  local set, built = ns.EncounterSet()
  local forever = set == "wowf"
  local none = ns.Clears:NoBossData()
  report().noBossData = none
  local note = forever and "" or " (retail: a note only)"
  c:That(not forever or #none == 0,
    (#none == 0 and "every dungeon and raid has its bosses" or ("no boss data: " .. table.concat(none, ", "))) .. note)
  local version, build = GetBuildInfo()
  local client = tostring(version) .. "." .. tostring(build)
  c:That(not forever or built == client, ("boss data from build %s, this client %s%s"):format(tostring(built), client, note))
end)

-- The Classic preset plans only with this game's places: in WoW Forever what Blizzard has announced
-- (ns.FOREVER_SCHEDULE), never a place that is only in the game's files (the owner, 4 Nov 2026).
step("the Classic preset: only places this game offers", function(c)
  local j = ns.BuildJourney("classic")
  local stray, n = {}, 0
  for key in pairs(j.place) do
    n = n + 1
    if not ns.InGame(key) then stray[#stray + 1] = key end
  end
  table.sort(stray)
  c:That(#stray == 0, #stray == 0 and (n .. " places, all in this game") or ("not in this game: " .. table.concat(stray, ", ")))
  local out = {}
  for _, r in ipairs(ns.RAIDS) do if not ns.InGame(r[1]) then out[#out + 1] = r[1] end end
  c:That(#out == 0, #out == 0 and (#ns.RAIDS .. " raids in the Endgame, all in this game") or ("raid not in this game: " .. table.concat(out, ", ")))
end)

step("crests: the medallion and the heraldic emblems", function(c)
  local E = ns.Emblems
  E.list = nil; E:Scan()
  local pics = {}
  for _, p in ipairs(E.PICTURES) do if E:Has(p.key) then pics[#pics + 1] = p.key end end
  c:That(true, #pics .. " picture crest(s): " .. table.concat(pics, ", "))
  if not inGame() then c:That(true, "art not checked outside the game") return end
  c:That(E:Has("Her_Lion"), "the heraldic emblems are offered")
  local first = UnitFactionGroup("player") == "Horde" and "Her_Axes" or "Her_Lion"
  c:Eq(E:First(), first, "a new fellowship starts with the " .. (first == "Her_Axes" and "axes" or "lion"))
  c:That(ns.Window.frame.header.crest.medal, "the header crest is a medallion")
  local sections = E:Sections()
  c:Eq(#sections[3][2], 0, "the picker: Crests and Heraldry only, no game icons")
  -- The book's frame: the gold and leather of the dialogs, not the diamond corners.
  c:That(ns.Window.frame.frameArt and ns.Window.frame.frameArt:IsShown(), "the gold and leather frame")
end)

step("controls: which of the game's button templates and art this client has", function(c)
  local has = ns.Gallery:Probe()
  local yes, no = {}, {}
  for name, ok in pairs(has) do if ok then yes[#yes + 1] = name else no[#no + 1] = name end end
  table.sort(yes); table.sort(no)
  report().controls = has
  c:That(true, "has: " .. table.concat(yes, ", "))
  c:That(true, "missing: " .. (#no > 0 and table.concat(no, ", ") or "none"))
  c:That(has.UIPanelButtonTemplate == true or not inGame(), "the red panel button exists")
  -- The WoW-style controls use the game's art (UI/Widgets.lua): without it they fall back to the flat look.
  if inGame() then
    local art = ns.UI.ArtReady()
    c:That(art.panel, "secondary buttons: the game's dark panel button")
    c:That(art.list, "choices: the game's collection-list buttons")
    c:That(art.roles, "roles: the Dungeon Finder role icons")
  end
end)

-- Create a Fellowship (28 Oct 2026): every step on both pages, and Your own journey shaped in the journey editor.
-- Walked through on the page without creating anything; the Selftest fellowship is founded after it.
local function bothPages(c, pf, key)
  c:That(pf.body[key]:IsShown() and pf.side[key]:IsShown(), key .. ": on both pages")
end

step("create: each step on both pages, Your own journey adds Chapters", function(c)
  local W, C = ns.Window, ns.CreateState
  C:Reset()
  W.startView = "create"
  if W:IsOpen() then W:Refresh() else W:Open() end
  local pf = W.pageFrames.create
  c:Eq(W.current, "create", "Create a Fellowship is open")
  c:Eq(#C:Steps(), 5, "five steps")
  bothPages(c, pf, "fellowship")
  c:That(pf.crest:IsShown() and pf.emblemGrid:IsShown(), "step 1: your banner and every emblem on the right page")
  c:That(pf.next:IsShown() and not pf.prev:IsShown() and not pf.create:IsShown(), "step 1: Next, no Back")
  if inGame() then c:That(pf.next:GetLeft() > pf.left:GetRight(), "Next is on the right page") end
  -- A size suggests a play style and a journey.
  C:SetSize("duo"); W:Refresh()
  local suggest = ns.Rules.SIZE_SUGGEST.duo
  c:Eq(ns.Rules.StyleOf(C.rules), suggest[1], "a duo: the suggested play style")
  c:Eq(C.preset, suggest[2], "and the suggested journey")
  click(pf.next)
  c:Eq(C:StepKey(), "style", "step 2: the play style")
  bothPages(c, pf, "style")
  c:That(pf.levelCells[1] and pf.levelCells[1]:IsShown(), "what the style allows at each level, on the right")
  click(pf.next)
  c:Eq(C:StepKey(), "journey", "step 3: the journey")
  bothPages(c, pf, "journey")
  C:ChooseOwn(); W:Refresh()
  c:Eq(#C:Steps(), 6, "Your own journey: six steps")
  c:Eq(C.journey and #C.journey.chapters, #ns.BuildJourney(suggest[2]).chapters, "a copy of the suggested journey")
  click(pf.next)
  c:Eq(C:StepKey(), "chapters", "step 4: Chapters")
  bothPages(c, pf, "chapters")
end)

-- The drag itself needs a real mouse (/jtf tests has a step for it): here the editor's own drop, and its ghost.
step("create: the journey editor (Split, Merge, the marks, a dungeon in and out)", function(c)
  local W, C, JE = ns.Window, ns.CreateState, ns.JourneyEdit
  local ed = W.pageFrames.create.editor
  local n = #C.journey.chapters
  local rows, marks = 0, 0
  for _, r in ipairs(ed.rows.items) do if r:IsShown() then rows = rows + 1 end end
  for _, h in ipairs(ed.handles) do if h:IsShown() then marks = marks + 1 end end
  c:Eq(rows, n, "a row for every chapter")
  c:Eq(marks, n - 1, "a gold mark between each two chapters")
  click(ed.rows.items[2])
  c:Eq(C.sel, 2, "a click on a row chooses chapter II")
  click(ed.split)
  local j = C.journey
  c:Eq(#j.chapters, n + 1, "Split: one more chapter")
  c:Eq(j.chapters[2].cap, j.chapters[3].floor, "the two halves join up")
  C.sel = 2; W:Refresh()
  click(ed.merge)
  c:Eq(#C.journey.chapters, n, "Merge: one again")
  -- The mark between II and III moves the level both chapters share.
  j = C.journey
  local was = j.chapters[2].cap
  local to = was + 1 <= j.chapters[3].cap and was + 1 or was - 1
  ed.src.edit(function(jj) JE.SetBoundary(jj, 2, to) end)
  c:That(j.chapters[2].cap == to and j.chapters[3].floor == to, ("the mark: II ends and III begins at %d"):format(to))
  ed:HandleTip(ed.handles[2])
  c:That(GameTooltip:IsShown(), "the mark's tooltip shows both chapters' levels")
  GameTooltip:Hide()
  -- A dungeon picked up follows the cursor; let go over nothing, it goes back. (In the game the drag ends at once when
  -- no mouse button is down, so the cursor update is held for the check; it failed there, 28 Oct 2026.)
  ed.Target, ed.DragUpdate = function() return nil end, function() end
  ed:BeginDrag({ base = "dm" }, "The Deadmines")
  c:That(ed.ghost:IsShown() and ed.ghost.text:GetText() == "The Deadmines", "a dragged dungeon follows the cursor, with its name")
  ed:EndDrag()
  ed.Target, ed.DragUpdate = nil, nil
  c:That(not ed.ghost:IsShown(), "and goes when it is let go")
  local last = #j.chapters
  ed:Drop({ base = "dm" }, { kind = "chapter", i = last })
  local key = JE.PlacedIn(C.journey, "dm", last)
  c:That(key ~= nil, "dropped on the last chapter's row: there")
  ed:Drop({ key = key }, { kind = "shelf" })
  c:Eq(key and C.journey.place[key], nil, "dropped on the shelf: out again")
  c:That(ed.shelfBy and ed.shelfBy.dm ~= nil, "the shelf has every dungeon")
end)

-- X1 (SPEC §9): the challenges, after the journey. None by default; they combine; Shared lives starts at what the size
-- suggests (a duo: 4) and the Leader may change it; the review shows them. Three banners side by side, every challenge
-- in sight at once (the owner, 1 Nov 2026).
local function chalRow(pf, key) return pf.chalRows[key] end
-- Every row of a banner stays on its cloth, above the pointed tail.
local function onCloth(b)
  local last = b.rows[#b.rows]
  return last:GetBottom() and b:GetBottom() and last:GetBottom() >= b:GetBottom() + b.tail
end
step("challenges: Create's step, three banners, they combine, the size suggests the shared lives", function(c)
  local W, C, Ch = ns.Window, ns.CreateState, ns.Challenges
  local pf = W.pageFrames.create
  local row = function(key) return chalRow(pf, key) end
  click(pf.next)
  c:Eq(C:StepKey(), "challenges", "step 5: the challenges")
  bothPages(c, pf, "challenges")
  c:Eq(C:Challenges(), nil, "none by default")
  c:Eq(#pf.banners, 3, "three banners: Survival, Story and Travel, Gear, Gold & More")
  local n, all = 0, true
  for _, k in ipairs(Ch.LIST) do
    if row(k) then n = n + 1; all = all and row(k):IsVisible() end
  end
  c:Eq(n, #Ch.LIST, "a row for each challenge (" .. #Ch.LIST .. ")")
  c:That(all, "every challenge in sight at once")
  for i, g in ipairs(Ch.GROUPS) do
    c:Eq(#pf.banners[i].rows, #g.list, L["CHAL_GROUP_" .. g.key:upper()] .. ": its " .. #g.list .. " challenges")
  end
  c:That(not pf.lives:IsShown() and not pf.pvp:IsShown(), "nothing asked before a challenge is chosen")
  click(row("hardcore")); click(row("shared"))
  c:That(row("hardcore").chosen and row("shared").chosen, "Hardcore and Shared lives chosen together")
  c:That(row("hardcore").check:IsShown() and row("hardcore").tint:IsShown(), "a chosen row is ticked and lit")
  if inGame() then
    local b = pf.banners
    c:That(b[2]:GetLeft() > b[1]:GetRight() and b[3]:GetLeft() > b[2]:GetRight(), "the banners stand side by side")
    c:That(math.abs(b[1]:GetTop() - b[3]:GetTop()) < 1 and math.abs(b[1]:GetBottom() - b[3]:GetBottom()) < 1, "as long as each other")
    c:That(b[1].pic:GetTexture() ~= nil, "each banner hangs from its picture")
    c:That(b[1]:GetBottom() > pf.prev:GetTop(), "the banners end above Back")
  end
  -- Hovering a challenge: its rule on the right page in the book's type, in place of what you take on (a tooltip
  -- covered that page; the check of 1 Nov 2026, 14:32), and back when the pointer leaves.
  local ring = row("ring")
  ring:GetScript("OnEnter")(ring)
  c:That(pf.peek:IsShown() and pf.chalText:GetAlpha() == 0, "hovering a challenge: its rule on the right page")
  c:Eq(pf.peek.name:GetText(), L.CHAL_RING, "its name")
  c:Has(pf.peek.rule:GetText(), L.CHAL_RING_RULE, "and its whole rule")
  c:Eq(pf.peek.group:GetText(), L.CHAL_GROUP_STORY:upper(), "under its banner's name")
  c:That(not GameTooltip:IsShown(), "no tooltip over the page")
  if inGame() then c:That(pf.peek.rule:GetBottom() > pf.next:GetTop(), "the rule stays above Next") end
  ring:GetScript("OnLeave")(ring)
  c:That(not pf.peek:IsShown() and pf.chalText:GetAlpha() == 1, "and back to what you take on")
  -- A faint emblem low on each banner's cloth: a skull, the Ring, a coin.
  for i, bn in ipairs(pf.banners) do
    c:That(bn.emblem:IsShown(), L["CHAL_GROUP_" .. Ch.GROUPS[i].key:upper()] .. ": its emblem on the cloth")
    if inGame() then c:That(bn.emblem:GetAlpha() < 0.3 and bn.emblem:GetBottom() > bn:GetBottom(), "faint, above the tail") end
  end
  c:That(pf.lives:IsShown(), "Shared lives asks how many")
  c:Eq(C:Lives(), Ch.SHARED_SUGGEST.duo, "a duo: the suggested number of lives")
  c:Eq(pf.lives.note:GetText(), L.CHAL_LIVES_SUGGEST:format(ns.Rules.SizeWord("duo"), Ch.SHARED_SUGGEST.duo), "and says what is suggested for a duo")
  click(pf.lives.up)
  c:Eq(C:Challenges() and C:Challenges().shared, Ch.SHARED_SUGGEST.duo + 1, "one more, by the arrow")
  c:Has(row("shared").tipText, L.CHAL_SHARED_RULE:format(C:Lives()), "its rule, hovered, has the lives chosen")
  c:Has(pf.chalText:GetText(), L.CHAL_HARDCORE_RULE, "what Hardcore Fellowship means, on the right page")
  c:That(pf.pvp:IsShown(), "Hardcore Fellowship asks whether it's a PvP realm")
  click(pf.pvp)
  c:Eq(C:Challenges() and C:Challenges().hardcore, "pvp", "on a PvP realm")
  c:Eq(row("hardcore").name:GetText(), L.CHAL_HARDCORE_PVP, "the row is called Hardcore PvP Fellowship")
  c:Has(pf.chalName:GetText(), L.CHAL_HARDCORE_PVP, "and so is the line on the right")
  c:Has(pf.chalText:GetText(), L.CHAL_HARDCORE_PVP_RULE, "and any death counts, also one to another player")
  if inGame() then
    c:That(pf.pvp:GetBottom() >= row("hardcore"):GetBottom(), "the PvP realm tick under Hardcore, inside its row")
    c:That(row("shared"):GetTop() <= row("hardcore"):GetBottom(), "Shared lives comes under it")
  end
  c:That(pf.chalNote:IsShown(), "the Fallen and starting anew, on the right page")
  c:That(pf.chalLives:IsShown() and pf.chalLives:Lit() == C:Lives(), "the shared lives as a row of candles, all lit (" .. C:Lives() .. ")")
  if inGame() then
    c:That(onCloth(pf.banners[1]), "Survival holds its rows, the tick and the lives on its cloth")
    c:That(pf.chalLater:GetBottom() > pf.next:GetTop(), "the right page's text stays above Next")
  end
end)

-- X3-X5 (the owner, 1 Nov 2026): the other two banners. Ironman Fellowship takes Hardcore Fellowship and White gear
-- only with it; Pauper asks for the gold; One class only is the Leader's class; No healers is not for a Leader who
-- heals. Gear, Gold & More holds all seven with the most it can ask.
step("challenges: Story and Gear banners, Ironman takes two with it, Pauper's gold", function(c)
  local W, C, Ch = ns.Window, ns.CreateState, ns.Challenges
  local pf = W.pageFrames.create
  local row = function(key) return chalRow(pf, key) end
  click(row("ring")); click(row("walk"))
  c:That(row("ring").chosen and row("walk").chosen and row("hardcore").chosen, "they combine across the banners")
  c:Has(pf.chalText:GetText(), L.CHAL_RING_RULE, "the Ring's rule on the right page")
  c:That(not (pf.chalText:GetText() or ""):find(L.CHAL_RING_PASS_RULE, 1, true), "without how it passes on (the rulebook says that)")
  c:Has(pf.chalName:GetText(), L.CHAL_WALK, "Walk everywhere in the line")
  click(row("ironman"))
  c:That(row("white").chosen, "Ironman Fellowship takes White gear only with it")
  c:Eq(row("white").sub:GetText(), L.CHAL_WITH_IRONMAN, "and says so")
  c:Eq(row("white").tipNote, L.CHAL_INCLUDED, "and the right page too, when it is hovered")
  row("white"):GetScript("OnEnter")(row("white"))
  c:Eq(pf.peek.note:IsShown() and pf.peek.note:GetText(), L.CHAL_INCLUDED, "hovered: why it is greyed, on the right page")
  row("white"):GetScript("OnLeave")(row("white"))
  click(row("white"))
  c:That(row("white").chosen, "it can't be taken off while Ironman is chosen")
  local ch = C:Challenges()
  c:That(ch.hardcore == "pvp" and ch.white and ch.ironman, "Hardcore PvP Fellowship and White gear only come with it")
  c:That(pf.pvp:IsShown(), "the PvP realm tick stays with Hardcore")
  click(row("pauper"))
  c:That(pf.gold:IsShown(), "Pauper asks for the gold")
  c:Eq(C:Gold(), Ch.PAUPER_SUGGEST, "10 gold suggested")
  c:Eq(pf.gold.note:GetText(), L.CHAL_GOLD_SUGGEST:format(Ch.PAUPER_SUGGEST), "and says so")
  click(pf.gold.up)
  c:Eq(C:Challenges().pauper, 15, "a step up: 15")
  c:Eq(pf.gold.stepper.value:GetText(), L.CHAL_GOLD_N:format(15), "15 gold between the arrows")
  c:Has(pf.chalName:GetText(), L.CHAL_PAUPER_N:format(15), "Pauper (15 gold) in the line")
  click(row("oneclass"))
  c:Eq(C:Challenges().oneclass, ns.Fellowship:MyInfo().class, "One class only: the Leader's class")
  c:Has(row("oneclass").sub:GetText(), Ch.ClassName(ns.Fellowship:MyInfo().class), "the row names it")
  local role = C.role
  C.role = "Healer"; W:Refresh()
  click(row("nohealers"))
  c:That(not row("nohealers").chosen, "No healers can't be chosen by a Leader who heals")
  c:Eq(row("nohealers").sub:GetText(), L.CHAL_HEALER_YOU, "the row says why")
  c:Eq(row("nohealers").tipNote, L.CHAL_HEALER_LEADER, "and the right page, hovered, what to do")
  -- (The most Gear, Gold & More can ask at once: Ironman's White gear, Pauper's gold, your class, the healer.)
  if inGame() then c:That(onCloth(pf.banners[3]), "Gear, Gold & More holds all seven on its cloth, with all they ask") end
  C.role = role; W:Refresh()
  click(row("nohealers"))
  c:That(row("nohealers").chosen, "another role: it can")
  c:Has(pf.chalNote:GetText(), L.CHAL_NOTE_HELD, "the right page: those two are held at the door")
  if inGame() then
    for i = 1, 3 do c:That(onCloth(pf.banners[i]), L["CHAL_GROUP_" .. Ch.GROUPS[i].key:upper()] .. ": every row on the cloth") end
    c:That(pf.chalLater:GetBottom() > pf.next:GetTop(), "the right page holds them all, above Next")
  end
  -- (Back to what the next steps expect: Survival's two, and nothing else.)
  for _, k in ipairs({ "ring", "walk", "ironman", "pauper", "oneclass", "nohealers" }) do C.challenges[k] = nil end
  C.gold = nil
  W:Refresh()
end)

step("create: review, Change goes back; nothing is created", function(c)
  local W, C = ns.Window, ns.CreateState
  local pf = W.pageFrames.create
  click(pf.next)
  c:Eq(C:StepKey(), "review", "step 6: review")
  c:Has(pf.reviewChal:GetText(), L.CHAL_HARDCORE_PVP, "the review lists the challenges")
  if inGame() then c:That(pf.reviewChal:GetBottom() > pf.prev:GetTop(), "the challenges' line stays above Back") end
  click(pf.changeChal)
  c:Eq(C:StepKey(), "challenges", "Change opens the challenges")
  C:Goto("review"); W:Refresh()
  bothPages(c, pf, "review")
  c:That(pf.create:IsShown() and not pf.next:IsShown(), "Create the fellowship, on the right page")
  c:Has(pf.reviewRoad.head.text:GetText(), L.PRESET_OWN, "the review shows Your own journey")
  click(pf.reviewRoad.change)
  c:Eq(C:StepKey(), "chapters", "Change opens Chapters")
  C:Reset()
  W.startView = "welcome"; W:Refresh()
  c:Eq(cur(), nil, "nothing created")
end)

step("found the Selftest fellowship", function(c)
  -- The Welcome page's two ways in are picture tiles (like the Adventure Guide).
  local wp = ns.Window.pageFrames.welcome
  c:That(wp and wp.found and wp.found.pic and wp.join and wp.join.pic, "Welcome: Found and Join as picture tiles")
  local f = ns.Fellowship:Create({ name = "Selftest", role = "Tank", preset = "classic" })
  c:Eq(ns.Rules.StyleOf(f.rules), "together", "a new fellowship plays Together")
  c:Eq(cur() and cur().name, "Selftest", "founded")
  if inGame() then c:Eq(f.emblem, ns.Emblems:First(), "with the faction's emblem") end
  -- The setup guide comes first for a character that has not seen it; its choices are the settings' own.
  c:Eq(ns.Window.page, "setup", "the setup guide opens after founding")
  local S = ns.Settings
  local mode = S:ToastMode()
  c:That(mode == "all" or mode == "big" or mode == "off" or mode == "custom", "banners: " .. tostring(mode))
  c:That(S:TrackerMode() ~= nil, "tracker: " .. tostring(S:TrackerMode()))
  ns.char.setupDone = true
  ns.Window:Open("overview")
  c:That(f ~= nil, "created")
end)

step("setup guide: three steps, the page fits, Skip goes back", function(c)
  local W, G = ns.Window, ns.SetupGuide
  W:ShowPage("chapter")
  G:Open("chapter")
  local pf = W.pageFrames.setup
  c:Eq(W.current, "setup", "Run it again opens the guide")
  c:That(pf.body[1]:IsShown() and not pf.prev:IsShown() and pf.next:IsShown(), "step 1: Look, with Next")
  local chosen
  for _, t in ipairs(pf.themes) do if t.chosen then chosen = t.key end end
  c:Eq(chosen, ns.Settings:Get("theme"), "the current theme is chosen")
  -- Beside the sidebar the page is narrower: the tiles stay on the left page (they ran over the spine; seen in game).
  if inGame() then
    local right, edge = pf.themes[1]:GetRight(), pf.left:GetRight()
    c:That(right and edge and right <= edge + 1, ("the theme tiles stay on the left page (%s <= %s)"):format(tostring(right), tostring(edge)))
  end
  G.step = 2; W:Refresh()
  c:That(pf.body[2]:IsShown() and pf.prev:IsShown(), "step 2: While you play, with Back")
  c:Eq(ns.Settings:TrackerMode() ~= nil, true, "tracker mode " .. tostring(ns.Settings:TrackerMode()))
  G.step = 3; W:Refresh()
  c:That(pf.body[3]:IsShown() and pf.done:IsShown() and not pf.next:IsShown(), "step 3: Reminders, with Start the journey")
  pf.skip:GetScript("OnClick")(pf.skip)
  c:Eq(W.current, "chapter", "Skip goes back to the page it came from")
  c:That(ns.char.setupDone == true, "seen")
end)

step("getting started (the leader of a new fellowship)", function(c)
  local f = cur()
  local list = ns.Together:Started(f)
  c:That(list ~= nil and #list == 4, "four steps")
  for _, p in ipairs({ "rules", "chapter", "admin" }) do ns.Window:ShowPage(p) end
  list = ns.Together:Started(f)
  local open = 0
  for _, s in ipairs(list or {}) do if not s.done then open = open + 1 end end
  c:Eq(open, 1, "only Invite Heroes is left")
  ns.Window:ShowPage("overview")
end)

shot("overview, getting started")

step("invite pretend Heroes", function(c)
  for _, n in ipairs(PRETEND) do
    ns.Dev:Fake(n)
    c:Eq(ns.Fellowship:Invite(n), "sent", "invite " .. n)
  end
end, 1.5)

step("the invites were received (pretend receipts)", function(c)
  for _, n in ipairs(PRETEND) do c:Eq(ns.Sync:InviteStatus(full(n)), "received", n) end
end)

step("pretend Heroes accept", function(c)
  for _, n in ipairs(PRETEND) do dev("hero " .. n .. " accept") end
  local f = cur()
  c:Eq(ns.Fellowship:Count(f), 4, "four Heroes")
  -- A stop: everything after this needs the pretend Heroes.
  if ns.Fellowship:Count(f) < 4 then c.stop = true; c:That(false, "stopped: the steps after this need the pretend Heroes") end
  -- The size never limited invites; four companions fit the Party rules, and Duo rules would now get a suggestion.
  local R = ns.Rules
  c:Eq(R.SizeFor(ns.Fellowship:Count(f)), "party", "four companions: a party")
  c:Eq(R.SizeSuggestion(R.WithSize(f.rules, "duo"), ns.Fellowship:Count(f)), "party", "Duo rules would get the Party suggestion")
  c:Eq(ns.Together:SizeHint(f), nil, "no suggestion for rules that fit")
end)

step("levels and the You card (catch-up)", function(c)
  -- Everyone past the Prologue (levels 1-15), then you fall back below the floor of Chapter II (15-21).
  for _, n in ipairs(PRETEND) do dev("hero " .. n .. " level 15") end
  dev("level 16")
  c:That(ns.Journey:CurrentIndex(cur()) >= 2, "the Prologue is done")
  dev("pace 1200")
  dev("level 13")
  local y = ns.Together:You(cur())
  c:Has(y.head, "13", "You card head")
  c:Eq(y.lines[1] and y.lines[1].text, L.YOU_LAST, "you are the last one")
  -- One more below the floor: "1 other Adventurer" ("1 other Adventurers" in the check of 1 Nov 2026, 11:30).
  local corwin = ns.Hero:Get(cur(), full("Corwin"))
  if corwin then
    local was = corwin.level
    corwin.level = 13
    local y2 = ns.Together:You(cur())
    corwin.level = was
    c:Eq(y2.lines[1] and y2.lines[1].text, L.YOU_BELOW_TOO_1, "you and one other below the floor")
  end
  c:Has(y.lines[2] and y.lines[2].text, "at your pace", "an estimate")
  -- Where to catch up (M25): the journey's dungeons good for your level, third so the Overview shows it.
  if #ns.Together:GoodFor(cur(), 13) > 0 then
    c:Has(y.lines[3] and y.lines[3].text, (L.YOU_GOOD_FOR:format(13, ""):gsub("[:%.%s]+$", "")), "where to catch up")
  end
end)

shot("overview, catch-up", function() ns.Window:ShowPage("overview") end)

step("level track: where you stand and where the Adventurers stand", function(c)
  local pf = ns.Window.pageFrames.overview
  local you = pf.you
  c:That(you.segs[1]:IsShown() and you.lvl:GetText() ~= nil, "the card: steps and your level")
  local total = 0
  for _, k in ipairs(you.counts) do total = total + (tonumber(k.v:GetText()) or 0) end
  c:Eq(total, 4, "the counts add up to four Adventurers")
  local n = 0
  for _, r in ipairs(pf.stand.rows.items) do if r:IsShown() then n = n + 1 end end
  c:Eq(n, 4, "four Adventurers in the standings")
  if inGame() then
    -- 332 with three next steps and Invite to group, and it fit well in the tour (27 Oct 2026); 379 with Play now's
    -- box since M25, which still fit (check of 29 Oct 2026).
    c:That(you:GetHeight() < 400, ("the card stays compact (%d)"):format(you:GetHeight()))
  end
end)

-- U5: the level track on the Chapter and Adventurers pages. Adventurers at one level share one marker with their
-- number and a line of names; no marker or level number is left over from an earlier draw (the check of 31 Oct 2026
-- caught level numbers that stayed behind).
local function trackSeen(c, where, t, levels)
  local markers, numbers = 0, 0
  for _, d in ipairs(t.markers.items) do
    if d:IsShown() then
      markers = markers + 1
      if d.lv:IsVisible() then numbers = numbers + 1 end
    end
  end
  c:Eq(markers, #levels, where .. ": one marker per level")
  -- U12: each name after its class icon, in dark ink (in the game, where the class icons are).
  if inGame() and t.lines.items[1] then
    c:Has(t.lines.items[1]:GetText() or "", "|T", where .. ": class icons before the names")
  end
  c:That(numbers <= markers, where .. ": no level number without its marker")
  local lines = 0
  for _, fs in ipairs(t.lines.items) do if fs:IsShown() then lines = lines + 1 end end
  c:That(lines >= 1, where .. ": a line of names under the track")
end

step("level track: the Chapter and Adventurers pages, one marker per level", function(c)
  local f = cur()
  local n = ns.Journey:CurrentIndex(f)
  local tr = ns.Journey:TrackLevels(f, n)
  c:That(tr ~= nil and #tr.levels >= 1, "the track has its Adventurers")
  local shared
  for _, e in ipairs(tr and tr.levels or {}) do if #e.names > 1 then shared = e end end
  ns.Window:ShowPage("chapter")
  local cp = ns.Window.pageFrames.chapter
  c:That(cp.levelTrack:IsShown(), "on the Chapter page")
  trackSeen(c, "Chapter page", cp.levelTrack, tr.levels)
  if shared then
    local found
    for _, d in ipairs(cp.levelTrack.markers.items) do
      if d:IsShown() and d.n:GetText() == tostring(#shared.names) then found = true end
    end
    c:That(found, ("%d Adventurers at level %d share one marker with their number"):format(#shared.names, shared.level))
  end
  -- A chapter far ahead stretches the track; its floor and cap then share one label instead of overlapping.
  local far = #f.journey.chapters
  cp.sel = far
  ns.Window:Refresh()
  trackSeen(c, "a chapter far ahead", cp.levelTrack, ns.Journey:TrackLevels(f, far).levels)
  local m = cp.levelTrack.marks
  if inGame() and m[2].label:IsShown() then
    c:That(m[1].label:GetRight() < m[2].label:GetLeft(), "a chapter far ahead: floor and cap do not overlap")
  end
  cp.sel = nil
  ns.Window:ShowPage("heroes")
  local hp = ns.Window.pageFrames.heroes
  if hp.levelTrack:IsShown() then
    trackSeen(c, "Adventurers page", hp.levelTrack, tr.levels)
  else
    c:That(true, "Adventurers page: no room left for the track")
  end
end)

step("the ones ahead see who is behind", function(c)
  dev("level 18")
  dev("hero Corwin level 13")
  local y = ns.Together:You(cur())
  local all = {}
  for _, l in ipairs(y.lines) do all[#all + 1] = l.text end
  c:Has(table.concat(all, " | "), "Corwin", "Corwin is behind")
  dev("hero Corwin level 15")
end)

-- M25: you pull ahead (the level up to 18 above did it), and Play now with the pretend Adventurers online.
step("keep in step: you pull ahead; Play now", function(c)
  local f = cur()
  local who, gap = ns.Progress:Ahead(f)
  c:That(who ~= nil and (gap or 0) >= ns.Progress.AHEAD, ("ahead of %s by %s levels"):format(tostring(who), tostring(gap)))
  c:That(toastSeen("ahead", nil), "a toast when you pulled ahead")
  local all = {}
  for _, l in ipairs(ns.Together:You(f).lines) do all[#all + 1] = l.text end
  if who then c:Has(table.concat(all, " | "), L.YOU_AHEAD:format(gap, ns.Short(who)), "the You card says it") end
  local p = ns.Together:PlayNow(f)
  c:That(p ~= nil and p.text ~= nil, "Play now: " .. tostring(p and p.text))
  ns.Window:ShowPage("overview")
  c:That(ns.Window.pageFrames.overview.you.play:IsShown(), "the Play now block on the Overview")
end)

shot("overview, play now")

-- What's New (the check of 1 Nov 2026, 14:32): once after each update, over the book; never while the self-test runs.
step("what's new: once after an update, our own art", function(c)
  local N, W = ns.News, ns.Window
  local keep = ns.db.newsSeen
  ns.db.newsSeen = nil
  c:That(N:Due(), "not seen on this account, in a fellowship: due")
  c:That(not N:Pending(), "but not while the self-test runs")
  c:That(N:Show(), "it shows over the book")
  local o = W.overlays and W.overlays.news
  c:That(o ~= nil and o:IsShown(), "What's New is open")
  if o then
    c:Eq(o.head:GetText(), L.NEWS_TITLE, "its gold title")
    c:Eq(o.bigTitle:GetText(), L.NEWS_BIG_TITLE, "the big news")
    c:That(o.pic:GetTexture() ~= nil, "in a round picture")
    c:That(o.ring == nil or o.ring:IsShown(), "inside the gold ring")
    c:Eq(#o.cards, 2, "two picture cards")
    c:Eq(o.cards[1].title:GetText(), L.NEWS_A_TITLE, "the first card")
    c:Eq(o.cards[2].title:GetText(), L.NEWS_B_TITLE, "the second card")
    c:That(o.cards[1].pic:GetTexture() ~= nil, "with a dungeon's loading screen")
    if inGame() then
      c:That(o.bigText:GetBottom() > o.ok:GetTop(), "the big news' words stay above Continue")
      c:That(o.cards[2]:GetBottom() > o.ok:GetTop() - 1 and o.cards[2]:GetBottom() >= o.box:GetBottom(), "the cards inside the frame")
      c:That(o.bigText:GetRight() < o.cards[1]:GetLeft(), "the big news beside the cards")
    end
  end
  c:Eq(ns.db.newsSeen, N.ID, "seen: not again until the next update")
  c:That(not N:Due(), "no longer due")
  if o then
    click(o.ok)
    c:That(not o:IsShown(), "Continue closes it")
  end
  ns.db.newsSeen = keep
end)

-- /jtf news typed in combat (the 0.12.0 review): the book opens, What's New waits until combat ends.
step("what's new: /jtf news in combat shows it after combat", function(c)
  local N, W, Co = ns.News, ns.Window, ns.Combat
  local keep, wasSimulated = ns.db.newsSeen, Co.simulated
  Co:SetSimulated(true)
  N:Open()
  local o = W.overlays and W.overlays.news
  c:That(not (o and o:IsShown()), "not during combat")
  Co:SetSimulated(wasSimulated)
  o = W.overlays and W.overlays.news
  c:That(Co:InCombat() or (o ~= nil and o:IsShown()), "it shows once combat ends")
  if o and o:IsShown() then click(o.ok) end
  ns.db.newsSeen = keep
end)

step("since you were last here", function(c)
  ns.Since:Mark()
  dev("hero Elyra level 17")
  local d = ns.Since:Digest(cur())
  c:That(d ~= nil and #d.levels == 1, "Elyra levelled")
  ns.Since.current = d
  ns.Window:ShowPage("since")
end)

shot("since you were last here")

step("chapter page and Find group", function(c)
  ns.Window:ShowPage("chapter")
  local pf = ns.Window.pageFrames.chapter
  c:That(pf.rows.items[1] and pf.rows.items[1]:IsShown(), "dungeon rows")
  local picked = ns.Together:FindGroup(cur(), "dm")
  c:That(#picked > 0, "Find group picks pretend Heroes (" .. #picked .. ")")
  -- Every row names its role in the role's colour; the next chapter's bridges come last.
  local J, last = ns.Journey, nil
  for _, card in ipairs(pf.rows.items) do if card:IsShown() then last = card end end
  local role = pf.rows.items[1].roleText or ""
  c:That(role:find("Mandatory", 1, true) or role:find("Optional", 1, true), "the first row names its role: " .. role)
  local bridges = J:EarlyBridges(cur(), J:CurrentIndex(cur()))
  if #bridges > 0 then
    c:Has(last and last.roleText or "", "Bridge", "the next chapter's bridge is listed: " .. bridges[1].d[2])
    c:Eq(last and last.borderRole, J.ROLE_COLOR.b[1], "in the bridge colour")
  end
  -- The Dungeon Journal is a book icon on the row; the stage track shows the chapter's stages.
  c:That(pf.rows.items[1].dj and pf.rows.items[1].dj.icon ~= nil, "Dungeon Journal: an icon button")
  c:That(pf.track:IsShown() and pf.nodes.items[1] and pf.nodes.items[1]:IsShown(), "the stage track")
  -- One Blackrock Depths over chapters XIII and XIV (the Prologue is chapter I), each with its part of the bosses.
  local f, Cl = cur(), ns.Clears
  c:Eq(table.concat(Cl:Placements(f, "brd"), ","), "brd,brd#2", "Blackrock Depths: two placements")
  local n1, n2 = #Cl:Needed(f, "brd"), #Cl:Needed(f, "brd#2")
  c:That(n1 > 0 and n2 > 0, ("bosses that count: %d in XIII, %d in XIV"):format(n1, n2))
  local named = 0
  for _, d in ipairs(ns.DUNGEONS) do if d[2]:find("Blackrock Depths", 1, true) then named = named + 1 end end
  c:Eq(named, 1, "one Blackrock Depths in the lists")
  -- A later chapter opens after the chapter before it.
  local cur3 = J:CurrentIndex(f) + 3
  c:Has(J:Banner(f, cur3).text, "Chapter " .. J.Roman(cur3 - 1), "a later chapter names the one before it")
end)

shot("chapter")

-- The Chapter page (28 Oct 2026): while someone is below the floor, the track stands at the floor and a box in the
-- middle says who, at what level and how far.
step("chapter page: waiting for the floor, the box in the middle", function(c)
  local f, J = cur(), ns.Journey
  local n = J:CurrentIndex(f)
  local floor = J:FloorLevel(f, f.journey.chapters[n])
  local was = ns.Hero:Level(f, full("Corwin"))
  dev("hero Corwin level " .. (floor - 2))
  ns.Window:ShowPage("chapter")
  local pf = ns.Window.pageFrames.chapter
  local nodes, b = J:Stages(f, n)
  c:Eq(b.stage, "floor", "the chapter waits for the floor")
  c:Eq(nodes[1] and nodes[1].state, "current", "the track stands at its first stage")
  c:That(pf.wait:IsShown(), "the waiting box")
  c:That(not pf.nextLine:IsShown(), "no What's next line while waiting (the box says it)")
  local named = false
  for _, r in ipairs(pf.wait.rows.items) do if r:IsShown() and r.name:GetText() == "Corwin" then named = true end end
  c:That(named, "it names Corwin, with level and how far")
  dev("hero Corwin level " .. math.max(was, floor))
  ns.Window:Refresh()
  c:That(not pf.wait:IsShown(), "gone when everyone is at the floor")
end)

step("clears: partial, then cleared", function(c)
  local f = cur()
  dev("group Brannic"); dev("group Elyra"); dev("group Corwin")
  dev("kill dm 2")
  local e = f.history[1]
  c:That(e and e.type == "run", "a run in History")
  dev("kill dm")
  c:That(ns.Journey:ClearedBy(f, "dm")[ns.Me()] ~= nil, "The Deadmines cleared for you")
  dev("group off")
  -- The picture moment after the final boss.
  c:That(ns.Picture.frame and ns.Picture.frame:IsShown(), "the picture moment is offered")
end)

shot("picture moment")

step("picture moment: take a picture, Done", function(c)
  local P = ns.Picture
  c:That(P:Take(false), "a picture taken")
  c:Eq(P.taken, 1, "counted")
  P:Hide()
  c:That(not P.frame:IsShown(), "Done closes it")
  ns.Settings:Set("picture", false)
  c:That(not P:Offer("dm"), "off in Settings")
  ns.Settings:Set("picture", true)
end, 1.5)

step("mark cleared: the next chapter unlocks (big moment)", function(c)
  local f = cur()
  local n = ns.Journey:CurrentIndex(f)
  for _, x in ipairs(ns.Journey:Required(f, n)) do
    if not ns.Journey:Cleared(f, x.key) then ns.Clears:Mark(x.key) end
  end
  c:Eq(ns.Journey:CurrentIndex(f), n + 1, "chapter " .. (n + 1))
  local t = ns.Toasts.frame
  c:That(t and t:IsShown() and t:GetWidth() >= 600, "large banner")
  if inGame() then c:That(t and t.frame and t.frame[1]:IsShown(), "in the gold and leather frame") end
end, 1.5)

shot("next chapter unlocked (big moment)")

shot("chronicle", function() ns.Window:ShowPage("chronicle") end)

-- Moments (29 Oct 2026): the moments so far, the picture taken after The Deadmines' final boss, and that picture
-- in the outbox for Discord.
step("moments: the journey's big moments and pictures", function(c)
  local f, Mo = cur(), ns.Moments
  local chapter
  for _, m in ipairs(Mo:List(f)) do if m.k == "chapter" then chapter = m end end
  c:That(chapter ~= nil, "a chapter that began")
  c:That(Mo:Find(f, "clear:dm") ~= nil, "The Deadmines, cleared the first time")
  c:That(#Mo:Pictures(f) >= 1, "the picture taken after the boss is kept")
  local posted
  for _, n in ipairs(ns.Board:News(f)) do if n.kind == "picture" and n.screenshot then posted = n end end
  c:That(posted ~= nil, "in the outbox for Discord, with when it was taken")
  ns.Window:ShowPage("moments")
  local pf = ns.Window.pageFrames.moments
  c:That(pf.tiles.items[1] and pf.tiles.items[1]:IsShown(), "a tile for each moment")
  c:That(pf.big:IsShown() and pf.big.title:GetText() ~= "", "the chosen one large")
end)

shot("moments")

step("group photo: everyone together on the whole screen", function(c)
  local PH = ns.Photo
  c:That(PH:Open({ standIns = true }), "opens out of combat")
  c:That(not UIParent:IsShown(), "the interface hidden")
  c:That(#PH.cast == #ns.Fellowship:Members(cur()), ("%d in the photo (stand-ins for the others)"):format(#PH.cast))
  local named = 0
  for _, x in ipairs(PH.cast) do if x.label:IsShown() then named = named + 1 end end
  c:That(true, ("%d names placed under the feet"):format(named))
  -- U16: the names at 20 with the class icon in front.
  local mine = PH.NameText(cur(), ns.Me())
  if inGame() then c:Has(mine, "|T", "your name in the photo: your class icon in front") end
  c:Has(mine, ns.Short(ns.Me()), "and your name")
  c:Eq(PH.NAME_SIZE, 20, "names at 20")
  PH:StepPose(1)
  c:That(PH.frame.pose.value:GetText():find(L.PHOTO_EVERYONE, 1, true) ~= nil, "a pose for everyone")
  -- Over the world: the game's camera in first person, and Look around gives the mouse to the game.
  local zoom = GetCameraZoom and GetCameraZoom()
  PH:SetBackdrop("world")
  c:That(not zoom or ns.char.photoZoom ~= nil, ("the world: first person (the camera was %.1f yards back)"):format(zoom or -1))
  PH:Look(true)
  c:That(not PH.frame:IsMouseEnabled() and not PH.frame.scene:IsMouseEnabled() and PH.frame.looking:IsShown(),
    "look around: the mouse goes to the game, Back to the photo shows")
  PH:Look(false)
  c:That(PH.frame:IsMouseEnabled() and PH.frame.chrome:IsShown(), "back to the photo")
  PH:Close()
  c:That(UIParent:IsShown() and not PH:IsOpen(), "closed: the interface is back")
  c:That(ns.char.photoZoom == nil, "the camera goes back as far as it was")
end)

-- A pose that plays once: the chosen one stood under Salute in two checks of 30 Oct 2026, and the game takes no
-- handler for an animation's end. The photo starts it again every PH.AGAIN seconds: over five seconds, at least once.
local PH_WAIT = 5
-- Which poses your model has: a hidden model of you, asked in part 2, once it has loaded. A pose the model lacks is
-- drawn as standing.
local poseProbe
step("group photo: Salute starts again (part 1)", function(c)
  local PH = ns.Photo
  c:That(PH:Open({ standIns = true }), "opens")
  PH:SetBackdrop("studio")
  PH:Choose(1)
  while PH.cast[1] and PH.POSES[PH.cast[1].pose][1] ~= "PHOTO_POSE_SALUTE" do PH:StepPose(1) end
  PH.restarts = 0
  c:That(PH.cast[1] ~= nil and PH.cast[1].actor.once == true, "the first one salutes, a pose that plays once")
  if not poseProbe then
    poseProbe = CreateFrame("PlayerModel", nil, PH.frame)
    poseProbe:SetSize(64, 64)
    poseProbe:SetPoint("BOTTOMLEFT")
    poseProbe:SetAlpha(0)
  end
  poseProbe:SetUnit("player")
end, PH_WAIT)
step("group photo: Salute starts again (part 2)", function(c)
  local PH = ns.Photo
  c:That((PH.restarts or 0) >= 1, ("the salute started again %d times in %d seconds"):format(PH.restarts or 0, PH_WAIT))
  if poseProbe.HasAnimation then
    local has, lacks = {}, {}
    for _, p in ipairs(PH.POSES) do
      local list = poseProbe:HasAnimation(p[2]) and has or lacks
      list[#list + 1] = L[p[1]]
    end
    c:That(true, ("your model has: %s; lacks: %s"):format(table.concat(has, ", "), #lacks > 0 and table.concat(lacks, ", ") or "none"))
  else
    c:That(true, "this client cannot say which poses a model has")
  end
  PH:Close()
  c:That(not PH:IsOpen(), "closed")
end)

-- Members near you in 3D (31 Oct 2026, UI/Models.lua): a Companion's real model also loads when they are not grouped,
-- from a friendly nameplate, your target, focus or the one under the mouse. What this client offers for it; needs no
-- fellowship ("/jtf check models" runs only this). Four probes the same day showed that nothing else can draw another
-- player (docs/ARCHITECTURE.md §5).
step("models: what the game offers for Adventurers near you", function(c)
  c:That(UnitExists ~= nil and UnitIsPlayer ~= nil and UnitName ~= nil, "UnitExists, UnitIsPlayer and UnitName exist")
  -- Friendly players' nameplates: Midnight's name first, the older one after (the check of 31 Oct 2026 found no
  -- nameplateShowFriends on retail 12.1.5). The game's own list says which nameplate settings this client has.
  local cv = C_CVar and C_CVar.GetCVar
  local plates, which
  for _, k in ipairs(ns.Models.PLATE_CVARS) do
    local v = cv and cv(k)
    if v ~= nil then plates, which = v, k break end
  end
  c:That(true, ("friendly player nameplates (%s): %s (on, members near you show in 3D without being targeted)"):format(
    tostring(which), plates == "1" and "on" or (plates and "off" or "unknown")))
  local all = ConsoleGetAllCommands or (C_Console and C_Console.GetAllCommands)
  local ok, list = pcall(all or error)
  if ok and type(list) == "table" then
    local names = {}
    for _, e in ipairs(list) do
      local n = type(e) == "table" and e.command
      if type(n) == "string" and n:lower():find("^nameplateshow") then names[#names + 1] = n end
    end
    table.sort(names)
    c:That(true, "this client's nameplate settings: " .. (#names > 0 and table.concat(names, ", ") or "none"))
  end
  local unit = UnitExists("target") and UnitIsPlayer("target") and "target" or nil
  if unit then
    local n = UnitName(unit)
    c:That(true, ("your target's name can be read: %s"):format((issecretvalue and issecretvalue(n)) and "no (secret here)" or "yes"))
  else
    c:That(true, "target a player to see whether their name can be read here")
  end
  local mine = ns.Models:DrawableUnit(ns.Self())
  c:Eq(mine, "player", "you are always drawn")
end)

step("quests: tabs and attunements", function(c)
  dev("hero Brannic quests")
  ns.Window:ShowPage("quests")
  local pf = ns.Window.pageFrames.quests
  -- At this character's own level first (low levels see none yet), then as a level 60 sees them.
  ns.QuestLists.viewLevel = nil
  pf.tabs.buttons[3]:Click()
  c:That(pf.alscroll:IsShown(), "Attunements tab")
  local open = #ns.QuestLists:Attunements(cur(), ns.Me())
  c:That(open > 0 and pf.aRows.items[1]:IsShown() or pf.aNone:IsShown(), ("%d open at level %d"):format(open, UnitLevel("player") or 0))
  ns.QuestLists.viewLevel = 60
  ns.Window:Refresh()
  -- Our attunements are WoW Forever's; retail has none of them (30 Oct 2026: each game shows only its own).
  if #ns.ATTUNEMENTS == 0 then
    c:That(pf.aNone:IsShown(), "none in this game: the tab says so")
  else
    c:That(pf.aRows.items[1] and pf.aRows.items[1]:IsShown(), "attunement rows (as level 60)")
  end
  ns.QuestLists.viewLevel = nil
  local done = {}
  for _, a in ipairs(ns.QuestLists:Attunements(cur())) do
    if ns.QuestLists:Progress(cur(), a, ns.Me()).done then done[#done + 1] = a.name end
  end
  report().myAttunements = done
  c:That(true, "you have: " .. (#done > 0 and table.concat(done, ", ") or "none"))
end)

shot("quests, attunements")

step("quests tab", function(c)
  local pf = ns.Window.pageFrames.quests
  pf.tabs.buttons[2]:Click()
  local n = 0
  for _, r in ipairs(pf.rows.items) do if r:IsShown() then n = n + 1 end end
  c:That(true, n .. " quests shown (needs quests in your log)")
end)

shot("quests")

step("heroes and inspect", function(c)
  ns.Window:ShowPage("heroes")
  local pf = ns.Window.pageFrames.heroes
  -- 3D: your own head on your card; pretend Companions cannot be drawn, so they show their class crest.
  local mine, theirs
  for _, card in ipairs(pf.cards.items) do
    if card:IsShown() and card.who == ns.Me() then mine = card elseif card:IsShown() then theirs = theirs or card end
  end
  c:That(mine and mine.portrait.model and mine.portrait.model:IsShown(), "your card: your head in 3D")
  -- The invite box sits above the cards (28 Oct 2026); the page's sketch (the road ahead) fills what room is left
  -- under them, so with four cards and the box it may not fit (it failed here once the box came; 27 Oct 2026).
  c:That(pf.invite:IsShown() and pf.send:IsShown(), "Invite Adventurers above the cards")
  if inGame() and pf.cards.items[1] then
    c:That(pf.invite:GetTop() > pf.cards.items[1]:GetTop(), "the invite box is above the first card")
  end
  -- Each card's presence mark: green online, yellow AFK, red offline, grey away, a green ring online with a quiet addon.
  c:That(mine and mine.presence:IsShown() and mine.presence.kind ~= "offline" and mine.presence.kind ~= "quiet",
    "your card: online (green), AFK or away, never offline")
  if inGame() then c:That(true, pf.art:IsShown() and "the page sketch under them" or "no room left for the page sketch") end
  c:That(theirs and theirs.crest:IsShown(), "a pretend Adventurer's card: the class crest")
  pf.sel = full("Brannic")
  ns.Window:Refresh()
  c:That(pf.whisper:IsShown(), "Whisper button")
  -- The item-level box: a dash (not "1") until gear is shared, and a tooltip either way (check of 1 Nov 2026).
  c:That(pf.ilvlBox.tip ~= nil and pf.ilvlBox.tip ~= "", "the item level box says what it is: " .. tostring(pf.ilvlBox.tip))
  if pf.ilvlBox.tip == L.ILVL_NONE_TIP:format(ns.Short(full("Brannic"))) then c:Eq(pf.iIlvl:GetText(), "–", "no gear shared: a dash") end
  c:That(pf.inviteBtn:IsShown(), "Invite button")
  c:That(pf.stageCrest:IsShown(), "Inspect a pretend Adventurer: the crest and why")
  pf.sel = ns.Me()
  ns.Window:Refresh()
  c:That(pf.modelBox.model and pf.modelBox.model:IsShown(), "Inspect yourself: your whole character in 3D")
  -- The paper doll as in the game's character window: your race's dressing-room picture, the slots inside the stage.
  if inGame() then
    -- A picture behind the model: the race's dressing room when the game has that atlas, else the chapter's landscape.
    c:That(pf.stage.race:IsShown() and pf.stage.race:GetTexture() ~= nil, "a picture behind the model: "
      .. (pf.stage.raceAtlas or "the chapter's landscape"))
    local g, st = pf.gear[#pf.gear], pf.stage
    c:That(g:GetBottom() and st:GetBottom() and g:GetBottom() >= st:GetBottom() - 1, "the weapon slots are inside the stage")
  end
  pf.sel = full("Brannic")
  ns.Window:Refresh()
end)

-- Shift on another Companion's item shows the game's comparison with what you wear (your own items show as on the
-- character sheet, without one). Hovering cannot hold Shift here, so this calls what the slot calls with Shift held.
step("heroes and inspect: Shift-compare", function(c)
  if not inGame() then c:That(true, "not checked outside the game") return end
  c:That(GameTooltip_ShowCompareItem ~= nil, "the game's compare function exists")
  if not GameTooltip_ShowCompareItem or not GetInventoryItemID then return end
  local id
  for slot = 1, 17 do id = id or GetInventoryItemID("player", slot) end
  if not id then c:That(true, "nothing equipped to compare with") return end
  GameTooltip:SetOwner(UIParent, "ANCHOR_CURSOR")
  GameTooltip:SetItemByID(id)
  GameTooltip:Show()
  local ok, err = pcall(GameTooltip_ShowCompareItem, GameTooltip)
  c:That(ok, "the comparison runs" .. (ok and "" or (": " .. tostring(err))))
  c:That(ShoppingTooltip1 and ShoppingTooltip1:IsShown(), "the comparison shows next to the item (item " .. id .. ")")
  GameTooltip:Hide()
end)

shot("inspect")

step("gatherings", function(c)
  local G = ns.Gatherings
  c:That(G:Schedule("wc", "selftest", time() + 2 * 3600), "scheduled")
  dev("hero Brannic gather")
  local list = G:Upcoming(cur())
  c:Eq(#list, 2, "two Gatherings")
  local items = ns.Inbox:Items()
  local found = false
  for _, it in ipairs(items) do if it.actions and #it.actions == 3 then found = true end end
  c:That(found, "inbox asks for an answer")
  -- The Overview keeps one line; the Gatherings page has the list and the chosen one.
  ns.Window:ShowPage("overview")
  c:Has(ns.Window.pageFrames.overview.gather.text:GetText(), "Next Gathering", "one line on the Overview")
  ns.Window:ShowPage("gatherings")
  local pf = ns.Window.pageFrames.gatherings
  c:That(pf.rows.items[2] and pf.rows.items[2]:IsShown(), "both on the Gatherings page")
  c:That(pf.band:IsShown() and pf.who[1]:IsShown(), "the chosen one with who is coming")
  -- The week ahead (M25): seven days; today has the one set up two hours from now (unless that is tomorrow).
  c:Eq(#pf.week, 7, "the week ahead")
  local planned = 0
  for _, row in ipairs(pf.week) do if row.what:IsShown() then planned = planned + 1 end end
  c:That(planned >= 1, planned .. " days with a Gathering")
end)

shot("gatherings")

step("gathering form", function(c)
  local o = ns.GatherForm:Open()
  c:That(o and o:IsShown(), "form open")
end)

shot("gathering form")

step("rule votes", function(c)
  local o = ns.Window.overlays and ns.Window.overlays.gather
  if o then o:Hide() end
  local f = cur()
  local before = f.rules.minHeroes
  dev("hero Brannic propose")
  local v = ns.Votes:List(f)[1]
  c:That(v ~= nil, "a vote is open")
  dev("hero Elyra vote yes")
  dev("hero Corwin vote yes")
  c:That(f.rules.minHeroes ~= before, "the rule changed by vote")
  -- The Rules page is the rulebook (28 Oct 2026): the articles on the left, the votes on the right; the Leader votes
  -- there and changes the rules in Manage.
  ns.Window:ShowPage("rules")
  local pf = ns.Window.pageFrames.rules
  c:Eq(#pf.articles, 6, "six articles")
  c:Has(pf.articles[2].text:GetText(), L.BOOK_ADV_N:format(f.rules.minHeroes), "Dungeon runs has the new number")
  c:That(pf.dHead:IsShown() and pf.vRows.items[1]:IsShown(), "the vote under Decided this week")
  c:That(pf.leaderBox:IsShown() and not pf.propose:IsShown(), "the Leader: the way to the Rules tab, not Propose")
end)

shot("rules and votes")

step("needs attention", function(c)
  dev("hero Corwin level 13")
  ns.Window:ShowPage("manage")
  local items = ns.Attention:Items(cur())
  c:That(#items > 0, #items .. " items")
  c:Eq(ns.Window.navItems.manage.badge:IsShown(), true, "count on the bookmark")
end)

shot("manage")

step("inbox", function(c)
  dev("hero Elyra ask")
  ns.Window:OpenPanel("inbox")
  c:That(ns.Window.panels.inbox:IsShown(), "inbox open")
end)

shot("inbox")

step("tournament", function(c)
  ns.Window:HidePanels()
  dev("tourney start")
  ns.Tourney:SignUp(true)
  for _, n in ipairs(PRETEND) do dev("hero " .. n .. " signup") end
  dev("tourney next")
  local t = cur().tourney
  c:That(t and t.phase == "running", "running")
  ns.Window:ShowPage("tourney")
end)

shot("tournament")

---------------------------------------------------------------------------
-- More: invites, ranks, the fellowship, Journey Admin, clears, the cap, asks, the inbox, the whole tournament
---------------------------------------------------------------------------
local OFFLINE_NAME = "Jtfnobodyhere" -- nobody plays this name: a real whisper to it comes back offline

-- Pretend Hero sends an op (as /jtf debug does).
local function opFrom(name, op)
  local f = cur()
  ns.Comm:Inject(full(name), "OP", { fid = f.id, v = f.v + 1, op = op, t = time() })
end

step("invite: already a Hero, already invited", function(c)
  ns.Window:HidePanels()
  c:Eq(ns.Fellowship:Invite("Brannic"), "member", "Brannic is already a Hero")
  ns.Dev:Fake("Darrow")
  c:Eq(ns.Fellowship:Invite("Darrow"), "sent", "invite Darrow")
  c:Eq(ns.Fellowship:Invite("Darrow"), "invited", "invite Darrow again")
end, 1.2)

step("invite: cancel", function(c)
  ns.Fellowship:CancelInvite(full("Darrow"))
  c:That(cur().invites[full("Darrow")] == nil, "the invite is gone")
end)

step("invite: a pretend Hero declines", function(c)
  ns.Dev:Fake("Fenna")
  ns.Fellowship:Invite("Fenna")
  dev("hero Fenna decline")
  c:That(cur().invites[full("Fenna")] == nil, "the invite is gone")
  c:That(not cur().members[full("Fenna")], "not a Hero")
end)

-- The first check in WoW Forever (5 Nov 2026): an invite to "Arielas Fireson" went to "Arielas fireson-Realm", which
-- the game did not find, and said "offline" though both were in one party. Forever names are "First Surname".
step("invite: names as the game has them (WoW Forever: First Surname)", function(c)
  c:Eq(ns.CleanName("arielas fireson"), "Arielas Fireson", "each part of a name gets its capital")
  c:That(cur().members[ns.Me()] ~= nil, "you are in your fellowship under your own name (" .. tostring(ns.Me()) .. ")")
  local _, second = UnitName("player")
  if ns.IsForever() then
    c:Eq(ns.FullName(ns.CleanName("arielas-fireson")), "Arielas Fireson-" .. ns.Realm(), "a hyphen is the space")
    c:Eq(ns.WhisperTarget(full("Arielas Fireson")), "Arielas Fireson", "whispers go to the name alone")
    if type(second) == "string" and second ~= "" then
      c:That(ns.Self():find(" " .. second, 1, true) ~= nil, "your key has your surname: " .. ns.Self())
    end
    -- In a group: a first name alone finds the one in it who has it.
    local other = ns.UnitFull("party1")
    if other and ns.Short(other):find(" ", 1, true) then
      c:Eq(ns.Friends:Resolve(full(ns.Short(other):match("^(%S+)"))), other, "a first name finds " .. ns.Short(other))
    end
  else
    c:Eq(ns.WhisperTarget("Bob-OtherRealm"), "Bob-OtherRealm", "retail whispers keep the realm")
  end
end)

-- The owner, 5 Nov 2026: invite a Battle.net friend by BattleTag (the character they play now).
step("invite: a BattleTag nobody on your list has is not sent", function(c)
  c:Eq(ns.Fellowship:Invite("Jtfnobody#0000"), nil, "not sent")
  c:That(cur().invites[full("Jtfnobody#0000")] == nil, "no invite made")
  c:That(toastSeen(nil, "Jtfnobody#0000"), "a toast says no friend with it is playing")
end)

step("invite: a real name that is offline", function(c)
  c:Eq(ns.Fellowship:Invite(OFFLINE_NAME), "sent", "sent")
end, 3)

-- Invites wait up to a day (3 Nov 2026): an invite to someone offline stays open, and the courier sends it again.
step("invite: offline is reported and the invite waits", function(c)
  local name = full(OFFLINE_NAME)
  c:That(cur().invites[name] ~= nil, "the invite stays open")
  c:Eq(ns.Sync:InviteStatus(name), "offline", "the list says it waits until they are online")
  -- The check of 3 Nov 2026, 21:57: and how long it still waits.
  local left = ns.Sync:InviteLeft(cur(), name)
  c:That(left ~= nil and left > ns.Sync.EXPIRE - 600 and left <= ns.Sync.EXPIRE, "it waits about a day")
  c:Has(ns.Sync:OfflineText(cur(), name), L.INV_LEFT:format(ns.TimeLeft(left or 0)), "the list says how long")
  -- The check of 4 Nov 2026, 20:33: "· 23 hours left" ran under Cancel. It wraps before it now.
  ns.Window:ShowPage("manage")
  local row
  for _, r in ipairs(ns.Window.pageFrames.manage.invites.items) do if r:IsShown() and r.who == name then row = r end end
  c:Has(row and row.wait:GetText(), L.INV_LEFT:format(ns.TimeLeft(left or 0)), "Manage shows how long")
  local wr, cl = row and row.wait:GetRight(), row and row.cancel:GetLeft()
  if wr and cl and inGame() then c:That(wr <= cl + 1, "the words end before Cancel") end
  c:That(toastSeen(nil, OFFLINE_NAME), "a toast says " .. OFFLINE_NAME .. " is offline")
end)

step("invite: the courier sends an open invite again, naming who may take the answer", function(c)
  local f, name = cur(), full(OFFLINE_NAME)
  c:Eq(ns.Sync:Courier(f), ns.Me(), "the Leader's addon delivers")
  local sent, send = {}, ns.Comm.Send
  ns.Comm.Send = function(_, to, tag, data) if tag == "INV" then sent[to] = data end end
  ns.Sync.sent[name] = nil
  local n = ns.Sync:Deliver()
  ns.Comm.Send = send
  c:Eq(n, 1, "one invite sent again")
  local inv = sent[name]
  c:Eq(inv and inv.who and inv.who[1], ns.Me(), "the Leader takes the answer first")
  c:Eq(inv and inv.t, cur().invites[name], "it keeps the day it was made")
  ns.Fellowship:CancelInvite(name)
  c:That(cur().invites[name] == nil, "cancelled again")
end)

step("remove a Hero, a Hero leaves", function(c)
  local f = cur()
  local chapter = ns.Journey:CurrentIndex(f)
  for _, n in ipairs({ "Darrow", "Fenna" }) do ns.Dev:Fake(n); dev("hero " .. n .. " accept") end
  c:That(f.members[full("Darrow")] ~= nil and f.members[full("Fenna")] ~= nil, "Darrow and Fenna joined")
  c:Eq(ns.Journey:CurrentIndex(f), chapter, "newcomers do not reopen completed chapters")
  ns.Fellowship:Remove(full("Darrow"))
  c:That(f.members[full("Darrow")] == nil, "Darrow removed")
  dev("hero Fenna leave")
  c:That(f.members[full("Fenna")] == nil, "Fenna left")
  c:Has(f.chronicle[1] and f.chronicle[1].text, "Fenna", "chronicle")
end)

-- Two ranks (27 Oct 2026): the Leader and Adventurers. Adventurers invite; the rest is the Leader's.
step("ranks: the Leader and Adventurers", function(c)
  local f, P = cur(), ns.Permissions
  local b = full("Brannic")
  c:Eq(P.Rank(f, b), "member", "Brannic is an Adventurer")
  c:That(P.Can(f, b, "invite"), "an Adventurer invites")
  c:That(not P.Can(f, b, "remove", full("Elyra")) and not P.Can(f, b, "rules") and not P.Can(f, b, "clears"), "and nothing more")
  -- Manage (28 Oct 2026): one sidebar entry, three tabs.
  local W = ns.Window
  W:ShowPage("manage")
  c:That(ns.Pages:InNav("rulesadmin", ns.Pages:Context()), "Admin: the rules for the Leader")
  local tabs = W.pageFrames.manage.tabs
  c:Eq(#tabs.buttons, 3, "three tabs")
  click(tabs.buttons[2])
  c:Eq(W.current, "managefellowship", "The fellowship tab")
  c:That(W.navItems.manage.ribbon:IsShown(), "Manage stays marked")
  click(W.pageFrames.managefellowship.tabs.buttons[3])
  c:Eq(W.current, "rulesadmin", "the Rules tab")
  W:ShowPage("manage")
end)

step("away: the leader marks a Hero, and I'm away / I'm back", function(c)
  local f = cur()
  ns.Fellowship:SetAway(full("Elyra"), true)
  c:Eq(ns.Journey:Away(f, full("Elyra")), "forced", "Elyra away (set by the Leader)")
  ns.Fellowship:SetAway(full("Elyra"), false)
  c:Eq(ns.Journey:Away(f, full("Elyra")), nil, "Elyra back")
  ns.Fellowship:SetAway(ns.Me(), true)
  c:Has(ns.Together:You(f).head, L.YOU_AWAY, "You card says away")
  ns.Fellowship:SetAway(ns.Me(), false)
  c:Eq(ns.Journey:Away(f, ns.Me()), nil, "back")
end)

-- A Friend of the fellowship (SPEC §1.1, the owner, 1 Nov 2026): invited as one, in the fellowship and the runs, never
-- counted for the floor, the votes, the firsts, the tournament or the challenges; in the tallies. Tamsin, a pretend
-- one, joins as a Friend for this step and is removed at its end.
step("friend of the fellowship: invited as one, never counted, tallies only", function(c)
  local f, F, J, W = cur(), ns.Fellowship, ns.Journey, ns.Window
  local t, me = full("Tamsin"), ns.Me()
  local counted = #J:Counted(f)
  -- The invite box offers it; the open invite says so.
  W:ShowPage("heroes")
  local pf = W.pageFrames.heroes
  pf.sel = nil; W:Refresh()
  c:That(pf.asFriend:IsShown(), "the invite box offers: As a Friend of the fellowship")
  F:Do({ k = "invite", name = t, friend = true })
  c:That(f.inviteFriend[t] == true, "invited as a Friend")
  W:Refresh()
  local row
  for _, r in ipairs(pf.invRows.items) do if r:IsShown() and r.who == t then row = r end end
  c:That(row ~= nil, "the open invite is listed")
  if row then c:Has(row.name:GetText(), L.INV_AS_FRIEND, "as a Friend") end
  dev("hero Tamsin accept")
  c:That(F:IsFriend(f, t), "Tamsin joined as a Friend of the fellowship")
  c:That(f.inviteFriend[t] == nil, "the invite is gone")
  local joined = false
  for _, e in ipairs(f.chronicle) do if e.text == L.CHR_JOINED_FRIEND:format(ns.Short(t)) then joined = true end end
  c:That(joined, "the Chronicle: " .. L.CHR_JOINED_FRIEND:format(ns.Short(t)))
  -- Never counted, never away, never behind.
  c:Eq(#J:Counted(f), counted, "not counted for the floor")
  c:Eq(J:Away(f, t), nil, "not away either")
  c:Eq(ns.Hero:Status(f, t), L.STATUS_FRIEND, "the card says: " .. L.STATUS_FRIEND)
  W:Refresh()
  local card
  for _, x in ipairs(pf.cards.items) do if x:IsShown() and x.who == t then card = x end end
  c:That(card ~= nil and card.standing:GetText() == L.STATUS_FRIEND, "Tamsin's card, in the fellowship's colours of calm")
  -- Counted apart (check of 1 Nov 2026, 11:30): not in the Adventurers tile or the roles; "1 Friend" beside them.
  local nFr = F:Friends(f)
  c:Eq(pf.stats[1].v:GetText(), tostring(F:Adventurers(f)), "the Adventurers tile leaves the Friends out")
  c:That(pf.compFriend:IsShown() and pf.compFriend.n:GetText() == tostring(nFr), "the Friends counted apart beside the roles: " .. nFr)
  local _, sub = ns.Pages:Titles("heroes", F:Context())
  c:Has(sub, nFr == 1 and L.SUB_AND_FRIEND:format("") or L.SUB_AND_FRIENDS:format("", nFr), "the page says so: " .. sub)
  c:That(F:Successor(f) ~= t, "never the next Leader before an Adventurer")
  -- Votes, the tournament, the challenges: not a Friend's.
  c:Eq(F:Apply(f, { k = "vote", a = "ballot", id = "none", yes = true }, t, time()), false, "no vote")
  c:Eq(F:Apply(f, { k = "tourney", a = "sign", on = true }, t, time()), false, "no tournament sign-up")
  local keep = { f.challenges, f.challengesOff, f.falls }
  f.challenges, f.challengesOff = { hardcore = true }, nil
  c:Eq(ns.Challenges:ApplyFall(f, t, { n = 1, lvl = 10 }, time()), false, "a death costs a Friend nothing")
  c:Eq(ns.Challenges:Fallen(f, t), nil, "never Fallen")
  f.challenges, f.challengesOff, f.falls = keep[1], keep[2], keep[3]
  -- Firsts: not a Friend's; tallies: yes.
  local open = ns.Firsts:Open(f)
  f.heroes[t] = f.heroes[t] or {}
  local hk = { f.heroes[t].deeds, f.heroes[t].tally }
  if open[1] then
    f.heroes[t].deeds = { [open[1]] = time() }
    local got = false
    for _, x in ipairs(ns.Firsts:List(f)) do if x.name == t then got = true end end
    c:That(not got, "no first for a Friend (" .. open[1] .. " stays open)")
  end
  f.heroes[t].tally = { quests = 999 }
  local q
  for _, x in ipairs(ns.Firsts:Tallies(f)) do if x.kind == "quests" then q = x end end
  c:That(q and q.top[1] and q.top[1].name == t, "but the tallies count: Tamsin did the most quests")
  f.heroes[t].deeds, f.heroes[t].tally = hk[1], hk[2]
  -- Switching: yourself only. Back to Adventurer only at or below the chapter's cap; the Leader always counts.
  dev("hero Tamsin friend off")
  c:That(not F:IsFriend(f, t) and #J:Counted(f) == counted + 1, "Tamsin plays on as an Adventurer: counted again")
  dev("hero Tamsin friend")
  c:That(F:IsFriend(f, t), "and a Friend again")
  c:Eq(F:FriendBlock(f, true), "leader", "the Leader cannot become a Friend")
  local ch = J:Current(f)
  local lead, mine = f.leader, f.members[me]
  local hm = ns.Hero:Get(f, me)
  local lvl = hm and hm.level
  if ch and hm then
    f.leader, mine.friend = t, true
    hm.level = ch.cap + f.rules.capTol + 1
    c:Eq(F:FriendBlock(f, false), "cap", "back as an Adventurer: not over the chapter's cap")
    hm.level = ch.cap
    c:Eq(F:FriendBlock(f, false), nil, "at the cap: yes")
    f.leader, mine.friend, hm.level = lead, nil, lvl
  end
  -- Your own page: the Friend section (as the Leader: why not).
  pf.sel = me; W:Refresh()
  c:That(pf.friendHead:IsShown(), "your own page: Friend of the fellowship")
  c:Eq(pf.friendText:GetText(), L.FRIEND_NOT_LEADER, "the Leader always counts")
  pf.sel = nil; W:Refresh()
  -- Removed again (the steps after this one count three pretend Adventurers).
  F:Remove(t)
  c:That(f.members[t] == nil, "Tamsin removed again")
end)

step("rename and banner", function(c)
  local f = cur()
  ns.Fellowship:Rename("Selftest Renamed")
  c:Eq(f.name, "Selftest Renamed", "renamed")
  ns.Fellowship:Rename("Selftest")
  c:Eq(f.name, "Selftest", "name back")
  local color = ns.BANNERS[2] and ns.BANNERS[2][2]
  ns.Fellowship:SetBanner(color, f.emblem)
  c:Eq(f.color, color, "banner colour")
end)

step("Journey Admin: needed bosses, publish", function(c)
  local f = cur()
  local A = ns.AdminDraft
  local list = ns.Clears:Bosses("dm")
  c:That(#list >= 2, #list .. " Deadmines bosses in the data")
  A:Edit(f, function(jd) jd.place.dm.bosses = { list[1].tok, list[2].tok } end)
  c:That(A:Changes(f) >= 1, "a change in the draft")
  c:That(A:Publish(f), "published")
  c:Eq(#ns.Clears:Needed(f, "dm"), 2, "two needed bosses")
  ns.Window:ShowPage("admin")
end)

shot("journey admin")

step("Journey Admin: add and remove a chapter, discard", function(c)
  local f = cur()
  local A = ns.AdminDraft
  local n = #f.journey.chapters
  A.sel = 1
  A:AddChapter(f)
  c:Eq(#A:Journey(f).chapters, n + 1, "a chapter added in the draft")
  A:RemoveChapter(f)
  c:Eq(#A:Journey(f).chapters, n, "removed again")
  A:Discard()
  c:Eq(#f.journey.chapters, n, "the published journey is unchanged")
end)

step("export and import a journey", function(c)
  local f = cur()
  local s = ns.Journey.Export(f.journey)
  c:Has(s, ns.Journey.EXPORT_PREFIX, "export string")
  local j = ns.Journey.Import(s)
  c:Eq(j and #j.chapters, #f.journey.chapters, "imports the same chapters")
  c:Eq(ns.Journey.Import("nonsense"), nil, "rejects nonsense")
end)

-- Journey Admin has the journey editor too (28 Oct 2026): every change goes to the draft until Publish.
step("Journey Admin: the journey editor works on the draft", function(c)
  local f, A, W, JE = cur(), ns.AdminDraft, ns.Window, ns.JourneyEdit
  W:ShowPage("admin")
  local ed = W.pageFrames.admin.editor
  local n = #f.journey.chapters
  A.sel = 2; W:Refresh()
  click(ed.split)
  c:Eq(#A:Journey(f).chapters, n + 1, "Split changes the draft")
  c:Eq(#f.journey.chapters, n, "not the published journey")
  local pf = W.pageFrames.admin
  click(ed.tabs.buttons[2])
  c:That(ed.shelf:IsVisible() and pf.publish:IsVisible(), "the Every dungeon tab, and Publish in the bar under it")
  A.sel = n + 1; W:Refresh()
  click(ed.shelfBy.dm)
  c:That(JE.PlacedIn(A:Journey(f), "dm", n + 1) ~= nil, "a click on the shelf puts The Deadmines in the chosen chapter")
  c:That(A:Changes(f) >= 2, A:Changes(f) .. " changes in the draft")
  A:Discard(); click(ed.tabs.buttons[1])
  c:That(not pf.publish:IsVisible(), "nothing to publish after Discard")
  c:Eq(#f.journey.chapters, n, "Discard: the published journey as it was")
  c:Eq(JE.PlacedIn(f.journey, "dm", n), nil, "without The Deadmines in the last chapter")
end)

-- U11: the chosen chapter enlarged on the ruler where the parts are too narrow for its number.
step("Journey Admin: the chosen narrow chapter is enlarged on the ruler", function(c)
  local f, A, W = cur(), ns.AdminDraft, ns.Window
  W:ShowPage("admin")
  local ed = W.pageFrames.admin.editor
  local n = #f.journey.chapters
  A.sel = n; W:Refresh(); ed:Refresh()
  local seg = ed.segs[n]
  if (seg:GetWidth() or 99) < 34 then
    c:That(ed.lens:IsShown(), "the last chapter, narrow: enlarged")
    c:Eq(ed.lens.n:GetText(), ns.Journey.Roman(n), "with its number")
    c:Eq(seg.n:GetText() or "", "", "its own part under the lens has no second number")
  else
    c:That(not ed.lens:IsShown(), "the last chapter is wide enough here: no lens needed")
  end
  A.sel = 2; W:Refresh(); ed:Refresh()
  c:That(not ed.lens:IsShown() or (ed.segs[2]:GetWidth() or 99) < 34, "a wide chapter: its own number, no lens")
  A:Discard()
end)

step("clears: a cell in the table, and Undo clear", function(c)
  local f = cur()
  local J = ns.Journey
  local function has() return J:ClearedBy(f, "dm")[full("Brannic")] ~= nil end
  local before = has()
  ns.Clears:Toggle("dm", full("Brannic"))
  c:That(has() ~= before, "a click on Brannic's cell changes his clear")
  ns.Clears:Toggle("dm", full("Brannic"))
  c:That(has() == before, "a second click changes it back")
  local chapter = J:CurrentIndex(f)
  local back = J:ReopensChapter(f, "dm")
  ns.Clears:Undo("dm")
  c:That(next(J:ClearedBy(f, "dm")) == nil, "Undo clear removes every clear")
  c:Eq(J:CurrentIndex(f), back, "the leader's undo reopens chapter " .. tostring(back))
  ns.Clears:Mark("dm")
  c:That(J:Cleared(f, "dm"), "marked again")
  c:Eq(J:CurrentIndex(f), chapter, "back in chapter " .. chapter)
  c:That(#ns.Clears:Entries(f, "run") > 0, "runs in History")
end)

step("the cap: over it, History, the warning, the toast", function(c)
  local f = cur()
  local ch = ns.Journey:Current(f)
  dev("level " .. (ch.cap + 2))
  c:That(#ns.Clears:Entries(f, "cap") > 0, "over-the-cap entry in History")
  c:That(toastSeen("overCap"), "over-the-cap toast")
  local warned = false
  for _, it in ipairs(ns.Inbox:Items()) do if it.text == L.WARN_AT_CAP then warned = true end end
  c:That(warned, "cap warning in the inbox")
  dev("level " .. (ch.cap - 1))
end)

step("progress toasts: a Hero reaches the floor and the cap", function(c)
  local f = cur()
  local ch = ns.Journey:Current(f)
  dev("hero Corwin level " .. ch.floor)
  dev("hero Brannic level " .. ch.cap)
  c:That(toastSeen("heroFloor") or toastSeen("floor"), "a floor toast")
  c:That(toastSeen("heroCap"), "Brannic reached the cap")
  ns.Settings:SetToast("heroCap", false)
  c:Eq(ns.Toasts:Push("heroCap", "x", "y"), "off", "a toast type can be turned off")
  ns.Settings:SetToast("heroCap", true)
end)

step("ask to group up: Join and Not now", function(c)
  local Q = ns.Quests
  dev("hero Elyra ask")
  c:Eq(#Q:Asks(), 1, "an ask")
  Q:Answer(full("Elyra"), true)
  c:Eq(#Q:Asks(), 0, "answered Join")
  dev("hero Elyra ask")
  Q:Answer(full("Elyra"), false)
  c:Eq(#Q:Asks(), 0, "answered Not now")
  Q:AskGroup({ name = "Selftest", others = { full("Brannic") } })
  c:That(toastSeen(nil, "Brannic was asked"), "my ask is sent")
end)

step("inbox: answer a Gathering and a vote", function(c)
  local f = cur()
  dev("hero Corwin gather")
  local before = #ns.Gatherings:Unanswered(f)
  c:That(before > 0, "an unanswered Gathering")
  dev("hero Brannic propose")
  for _, it in ipairs(ns.Inbox:Items()) do
    if it.actions and #it.actions == 3 then it.actions[1][2]() break end
  end
  c:Eq(#ns.Gatherings:Unanswered(f), before - 1, "answered Yes from the inbox")
  local v = ns.Votes:Unvoted(f)[1]
  c:That(v ~= nil, "a vote to answer")
  for _, it in ipairs(ns.Inbox:Items()) do
    if it.actions and #it.actions == 2 and it.text:find(L.R_MINHEROES, 1, true) then it.actions[2][2]() break end
  end
  c:Eq(v and v.ballots[ns.Me()], false, "voted No from the inbox")
end)

step("quests: Show all brings in far-off quests", function(c)
  local f = cur()
  -- Show all only brings in grey quests: more than GREY_BELOW levels under your own level (M19: "near" is near
  -- you). A quest Brannic is on, that far below you: hidden until Show all. Too low a character has none.
  local lvl = UnitLevel("player") or 1
  local far = lvl - ns.Quests.GREY_BELOW - 1
  if far < 1 then
    c:That(true, ("Show all: not testable at level %d (nothing is grey yet)"):format(lvl))
  else
    ns.Comm:Inject(full("Brannic"), "QUESTS", { fid = f.id, q = { [99901] = { t = "A Far-off Errand", z = "Elwynn Forest", l = far, h = 0, g = 1 } },
      d = {}, ln = {}, t = time() })
    ns.Window:ShowPage("quests")
    local pf = ns.Window.pageFrames.quests
    pf.tabs.buttons[2]:Click()
    c:That(pf.showAll:IsShown(), "Show all is offered")
    local function count() local n = 0 for _, r in ipairs(pf.rows.items) do if r:IsShown() then n = n + 1 end end return n end
    local n = count()
    pf.showAll:Click()
    c:That(count() > n, "more quests after Show all")
    pf.all = nil
  end
  -- Your side's first dungeon with quests (The Deadmines quests are Alliance only; it failed on a Horde character).
  local horde = UnitFactionGroup("player") == "Horde"
  local key = horde and "rfc" or "dm"
  local d = ns.Dungeon(key)
  -- Our dungeon quest lists are WoW Forever's: retail shows none.
  if next(ns.DUNGEON_QUESTS) == nil then
    c:That(ns.QuestLists:DungeonLine(f, key) == nil, "no quest lists in this game: no quest line on the Chapter page")
  else
    c:That(ns.QuestLists:DungeonLine(f, key) ~= nil, (d and d[2] or key) .. " has a quest line on the Chapter page")
  end
end)

step("Chronicle filters and totals", function(c)
  local f = cur()
  local t = ns.Clears:Totals(f)
  c:That(t[1] > 0, t[1] .. " runs that counted")
  c:That(t[4] > 0, t[4] .. " over the cap")
  ns.Window:ShowPage("chronicle")
end)

-- F1 (SPEC §8): the fellowship's firsts from what the Adventurers share; only deeds after joining count.
step("Chronicle: the fellowship's firsts and tallies", function(c)
  local f, FS = cur(), ns.Firsts
  local t = GetServerTime and GetServerTime() or time()
  local b, e = f.heroes[full("Brannic")], f.heroes[full("Elyra")]
  c:That(b ~= nil and e ~= nil, "pretend Adventurers to share deeds")
  if not (b and e) then return end
  local keep = { b.deeds, b.tally, e.deeds, e.tally }
  b.deeds, b.tally = { lvl10 = t - 120, fall = t - 60 }, { falls = 2, quests = 4 }
  e.deeds, e.tally = { lvl10 = t - 240, mount = t - 30 }, { falls = 0, quests = 9 }
  -- A deed from long before Elyra joined does not count.
  e.deeds.rare = (f.members[full("Elyra")].joined or t) - 86400
  local byKey = {}
  for _, x in ipairs(FS:List(f)) do byKey[x.key] = x.name end
  c:Eq(byKey.lvl10, full("Elyra"), "first to level 10: Elyra, 2 minutes before Brannic")
  c:Eq(byKey.fall, full("Brannic"), "first to fall: Brannic")
  c:Eq(byKey.rare, nil, "a deed from before joining is no first")
  local talliesOf = {}
  for _, x in ipairs(FS:Tallies(f)) do talliesOf[x.kind] = x end
  c:That(talliesOf.falls and talliesOf.falls.name == full("Brannic") and talliesOf.falls.n == 2, "has fallen most: Brannic (2)")
  -- A toast for a recent first, once.
  ns.char.firstsSeen = nil
  local before = #report().toasts
  FS:Check(f)
  local firsts = 0
  for i = before + 1, #report().toasts do if report().toasts[i].kind == "first" then firsts = firsts + 1 end end
  c:That(firsts >= 3, firsts .. " toasts for the recent firsts")
  c:Eq(FS:Check(f), 0, "no second toast for the same first")
  ns.Window:ShowPage("chronicle")
  local pf = ns.Window.pageFrames.chronicle
  pf.filter = "first"; ns.Window:Refresh()
  -- The Firsts filter is a cabinet of medals (check of 1 Nov 2026): the earned ones, then the ones still open, greyed.
  local medals, open, named = 0, 0, 0
  for _, m in ipairs(pf.medals.items) do
    if m:IsShown() then
      medals = medals + 1
      if m.open then open = open + 1 end
      if m.title:GetText() ~= m.key then named = named + 1 end
    end
  end
  c:Eq(medals, #FS.KEYS, "a medal for every first, earned or not")
  c:Eq(medals - open, #FS:List(f), "earned: " .. #FS:List(f))
  c:Eq(open, #FS:Open(f), "still open, for someone to race for: " .. #FS:Open(f))
  c:Eq(named, medals, "every medal has its name")
  c:That(pf.earnedHead:IsShown() and pf.openHead:IsShown(), "Earned, then Still open")
  -- Who is closest to an open level first (check of 1 Nov 2026, 11:30): named under it instead of "Nobody yet"; under
  -- the next one only, the lowest someone is still below (check of 1 Nov 2026, 14:32).
  local near, named2 = nil, 0
  for _, m in ipairs(pf.medals.items) do
    if not near and m:IsShown() and m.open and m.key:find("^lvl") and FS:Closest(f, m.key) then near = m end
    if m:IsShown() and m.closest then named2 = named2 + 1 end
  end
  c:That(named2 <= 1, "only the next open level names who is closest (" .. named2 .. ")")
  if near then
    local who, lvl = FS:Closest(f, near.key)
    c:Eq(near.closest, who, near.key .. ": " .. (who and (ns.Short(who) .. " " .. L.FIRST_CLOSEST:format(lvl)) or "nobody below it"))
    if who then c:Eq(near.when:GetText(), L.FIRST_CLOSEST:format(lvl), "said under the medal") end
  end
  -- First to fall: gold without a challenge (violet and silver under one: the challenges' step).
  for _, m in ipairs(pf.medals.items) do
    if m:IsShown() and m.key == "fall" and not m.open then
      c:Eq(m.solemn, ns.Challenges:Ever(f) or nil, "First to fall: " .. (m.solemn and "violet and silver" or "gold"))
    end
  end
  local rows = 0
  for _, r in ipairs(pf.rows.items) do if r:IsShown() then rows = rows + 1 end end
  c:Eq(rows, 0, "no Chronicle lines under the medals")
  c:That(pf.tHead:IsShown(), "the tallies on the right page")
  -- The podium: the top three of each tally (Elyra did 9 quests, Brannic 4).
  local q = talliesOf.quests
  local qi = {}
  for i, x in ipairs(q and q.all or {}) do qi[x.name] = i end
  c:That(qi[full("Elyra")] and qi[full("Brannic")] and qi[full("Elyra")] < qi[full("Brannic")], "most quests: Elyra above Brannic")
  local podium
  for _, r in ipairs(pf.tRows.items) do if r:IsShown() and r.what:GetText() == L.TALLY_QUESTS then podium = r end end
  c:That(podium ~= nil and podium.places[1]:IsShown(), "the quests tally as a podium")
  if podium and q then c:Has(podium.places[1].name:GetText(), ns.Short(q.top[1].name), "first place: " .. ns.Short(q.top[1].name)) end
  ns.Moments:Check(f)
  c:That(ns.Moments:Find(f, "first:fall") ~= nil, "a Moments card for the first to fall")
  local news = 0
  for _, n in ipairs(ns.Board:News(f)) do if n.kind == "first" then news = news + 1 end end
  c:That(news >= 3, news .. " firsts in the Discord outbox")
  pf.filter = "all"
  b.deeds, b.tally, e.deeds, e.tally = keep[1], keep[2], keep[3], keep[4]
end)

-- X2 (SPEC §9): survival, on the Selftest fellowship with Hardcore and two shared lives for a while (put back by the
-- last of these steps). Brannic falls: Fallen, honoured (the Chronicle's memorial line, a toast, his card), no longer
-- counted, a shared life gone; Corwin's fall takes the last one, and the journey goes on.
local function withChallenges(f, ch)
  if not ST.chalKeep then ST.chalKeep = { f.challenges, f.challengesOff, f.falls, f.broken, f.ring, f.race } end
  f.challenges, f.challengesOff, f.falls, f.broken, f.ring, f.race = ch, nil, nil, nil, nil, nil
end
local function putChallengesBack(f)
  local k = ST.chalKeep
  if not k then return end
  f.challenges, f.challengesOff, f.falls, f.broken, f.ring, f.race = k[1], k[2], k[3], k[4], k[5], k[6]
  ST.chalKeep = nil
end
local function kindSeen(kind, since)
  for i = since + 1, #report().toasts do if report().toasts[i].kind == kind then return true end end
  return false
end

step("challenges: Hardcore and shared lives, the Fallen honoured", function(c)
  local f, Ch, J = cur(), ns.Challenges, ns.Journey
  withChallenges(f, { hardcore = true, shared = 2 })
  local b, co = full("Brannic"), full("Corwin")
  -- Candles that live (check of 1 Nov 2026, 11:30): the lit ones flicker, unless Reduce effects is on.
  ns.Window:ShowPage("overview")
  local still = ns.Settings:Get("reduce") and true or false
  local lit1 = ns.Window.pageFrames.overview.lives.candles.items[1]
  c:That(lit1 ~= nil and lit1.flickering == not still, still and "Reduce effects: the candles stay still" or "the lit candles flicker")
  local counted, before = #J:Counted(f), #report().toasts
  ns.lastSound = nil
  dev("hero Brannic fall")
  local e = Ch:Fallen(f, b)
  c:That(e ~= nil, "a death under Hardcore: Brannic has fallen")
  if not e then return end
  -- A heavier toast for a Fallen (check of 1 Nov 2026): darker, slower, and a bell.
  local fallToast
  for i = before + 1, #report().toasts do if report().toasts[i].kind == "challenge" then fallToast = fallToast or report().toasts[i] end end
  c:That(fallToast ~= nil and fallToast.solemn == true, "the toast is a solemn one")
  -- (Its kicker said the Settings line "A challenge: a fall, a broken rule, the Ring"; check of 1 Nov 2026, 15:23.)
  c:Eq(fallToast and fallToast.kicker, Ch:Name("hardcore", f.challenges.hardcore), "the challenge's name above the title")
  -- A fall for good that also spends the last shared life: Hardcore still (the 0.12.0 review).
  local _, _, _, last = Ch:FallToast(f, setmetatable({ out = true, life = true, pool = 0 }, { __index = e }))
  c:Eq(last and last.kicker, Ch:Name("hardcore", f.challenges.hardcore), "also when it spends the last shared life")
  local T = ns.Toasts
  if T.frame and T.frame:IsShown() and T.current and T.current.solemn then
    c:That(T.frame.solemn and T.frame.solemnBg:IsShown(), "its banner: night violet")
    if inGame() then c:That(T.frame.hold:GetDuration() >= 5, "and it stays longer: " .. T.frame.hold:GetDuration() .. " seconds") end
    if ns.Settings:Get("sounds") ~= false then c:Eq(ns.lastSound, "bell", "a bell tolls") end
  end
  c:Eq(e.foe, L.DEV_FOE, "who he was fighting is kept with it")
  c:Eq(e.lvl, ns.Hero:Level(f, b), "and his level")
  c:Eq(#J:Counted(f), counted - 1, "the Fallen no longer hold the fellowship back")
  c:Eq(Ch:SharedLeft(f), 1, "a shared life is gone: 1 of 2 left")
  c:That(kindSeen("challenge", before), "a toast for everyone")
  dev("hero Brannic fall")
  c:Eq(Ch:FallsOf(f, b), 1, "a Fallen's next death costs nothing more")
  dev("hero Corwin fall")
  c:That(Ch:LivesOut(f) ~= nil and Ch:LivesOut(f).who == co, "Corwin's fall took the last shared life")
  c:Eq(Ch:SharedLeft(f), 0, "none left; the journey goes on")
  -- The shared lives as candles on the Overview (check of 1 Nov 2026): two, both out; the tooltip names who.
  ns.Window:ShowPage("overview")
  local ov = ns.Window.pageFrames.overview
  c:That(ov.lives:IsShown() and ov.lives.candles.total == 2 and ov.lives.candles:Lit() == 0, "the Overview's candles: 2, none lit")
  c:Eq(ov.lives.text:GetText(), Ch:LivesView(f).title, "and what they mean")
  c:Eq(#(ov.lives.candles.tipLines or {}), 2, "the tooltip names each life lost")
  -- Each candle is the flame beside "Shared lives" (the game's candles read as white pearls; check of 1 Nov, 11:30).
  c:Eq(ns.UI.icons[ov.lives.candles.items[1].icon], ns.ICONS.chal_shared, "each candle: the shared lives' flame")
  -- Lives lost since the row was last seen: each candle goes out with a snuff and smoke (none with Reduce effects).
  ns.char.livesSeen = ns.char.livesSeen or {}
  ns.char.livesSeen[f.id] = 2
  ns.Window:Refresh()
  c:Eq(#(ov.lives.candles.snuffed or {}), still and 0 or 2, still and "Reduce effects: no snuff" or "both candles go out as you look")
  c:Eq(ns.char.livesSeen[f.id], 0, "and only once")
  -- Never counted (check of 1 Nov 2026, 11:30): not in the counts, never away, not online to group with, and never the
  -- next Leader while someone plays on.
  local inCounts, plays = 0, 0
  for _, x in ipairs(J:Counts(f, J:CurrentIndex(f))) do inCounts = inCounts + x[2] end
  for name, m in pairs(f.members) do if not m.friend and not Ch:Fallen(f, name) then plays = plays + 1 end end
  c:Eq(inCounts, plays, "the counts leave the Fallen out")
  local bm = f.members[b]
  local wasAway = bm.away
  bm.away = "forced"
  c:Eq(J:Away(f, b), nil, "a Fallen is never away")
  bm.away = wasAway
  local offered = false
  for _, n in ipairs(ns.Together:Online(f)) do if Ch:Fallen(f, n) then offered = true end end
  c:That(not offered, "no Fallen among those online to group with")
  local heir = ns.Fellowship:Successor(f)
  c:That(heir ~= nil and not Ch:Fallen(f, heir), "the next Leader plays on: " .. (heir and ns.Short(heir) or "nobody"))
  local first = ns.Progress:LongestServing(f)
  c:That(not (first and Ch:Fallen(f, first)), "no Fallen takes over")
  -- The Chronicle (All): the memorial line, with the level, the place and the day.
  ns.Window:ShowPage("chronicle")
  local pf = ns.Window.pageFrames.chronicle
  pf.filter = "all"; ns.Window:Refresh()
  local want, found = Ch:FallText(f, e), false
  for _, r in ipairs(pf.rows.items) do if r:IsShown() and r.text:GetText() == want then found = true end end
  c:That(found, "the Chronicle's memorial line: " .. want)
  c:Has(want, Ch.Day(e.t), "with the day")
  -- His card on the Adventurers page: Fallen, and when and where.
  ns.Window:ShowPage("heroes")
  local hp, card = ns.Window.pageFrames.heroes, nil
  hp.sel = nil; ns.Window:Refresh()
  local fallenSeen, livingAfter = false, false
  for _, x in ipairs(hp.cards.items) do
    if x:IsShown() then
      if x.who == b then card = x end
      local isF = Ch:Fallen(f, x.who) ~= nil
      if isF then fallenSeen = true elseif fallenSeen then livingAfter = true end
    end
  end
  c:That(card ~= nil, "Brannic still has his card")
  c:That(fallenSeen and not livingAfter, "the Fallen come after those who play on")
  -- Recent history on the left page: his fall, with the skull (the check of 1 Nov 2026, 14:32: it was missing there).
  local fallLine
  for i, fs in ipairs(hp.feed) do
    local text = fs:GetText() or ""
    if fs:IsShown() and hp.feedIcon[i].key == "hist_fallen" and text:find(ns.Short(b), 1, true) then fallLine = text end
  end
  c:That(fallLine ~= nil, "Recent history: his fall, with the skull")
  local iconsOk = true
  for i, fs in ipairs(hp.feed) do if fs:IsShown() and not hp.feedIcon[i]:IsShown() then iconsOk = false end end
  c:That(iconsOk, "every line of Recent history has its icon")
  -- Counted apart: "1 Fallen" beside the roles, and the roles only of those who play on (check of 1 Nov 2026).
  local fallenN, roles = 0, 0
  for name in pairs(f.members) do if Ch:Fallen(f, name) then fallenN = fallenN + 1 end end
  for _, x in ipairs(hp.comp) do roles = roles + (tonumber(x.n:GetText()) or 0) end
  c:That(hp.compFallen:IsShown() and hp.compFallen.n:GetText() == tostring(fallenN), "the Fallen counted apart: " .. fallenN)
  c:Eq(roles, ns.Fellowship:Adventurers(f) - fallenN, "the roles count only the Adventurers who play on")
  if card then
    -- A memorial: a skull on the greyed crest, no Online, no Old addon, the card in violet.
    c:That(card.fallenMark:IsShown(), "a skull on his crest's corner")
    -- Clear of the line beside it (it covered the L of "Level 22"; check of 1 Nov 2026, 11:30).
    if inGame() and card.fallenMark:GetRight() and card.xp:GetLeft() then
      c:That(card.fallenMark:GetRight() <= card.xp:GetLeft(), "the skull stays clear of the memorial line")
    end
    c:That(card.crest:IsShown() and card.crest.icon:IsDesaturated(), "his class crest greyed")
    c:That(not card.presence:IsShown() and not card.status:IsShown() and not card.old:IsShown(), "no Online, Offline or Old addon")
    c:Eq(card.standing:GetText(), L.STATUS_FALLEN, "Fallen on his card")
    c:Eq(card.xp:GetText(), Ch:FallenLine(e), "place, day and foe on his card")
    -- The line stops before "Fallen" (they ran into each other in the check of 1 Nov 2026, 01:20), and holds the foe
    -- whole (it was cut after the level was on it too; the check after 1133f90).
    if inGame() and card.xp:GetRight() and card.standing:GetLeft() then
      c:That(card.xp:GetRight() <= card.standing:GetLeft(), "the memorial line stops before Fallen")
      c:That(card.xp:GetStringWidth() <= card.xp:GetWidth() + 1, "the whole line fits, the foe included")
    end
  end
  -- His memorial page (check of 1 Nov 2026, 11:30): his crest and the fall in place of the gear, his journey on the
  -- right in place of the chapter.
  hp.sel = b; ns.Window:Refresh()
  c:That(hp.memorial:IsShown() and not hp.modelBox:IsShown() and not hp.ilvlBox:IsShown(), "inspecting him: a memorial, not his gear")
  c:Eq(hp.memorial.title:GetText(), L.MEMORIAL_TITLE:format(ns.Short(b)), "the memorial's title")
  c:Eq(hp.memorial.line:GetText(), Ch:Memorial(f, b).line, "where, when and fighting whom")
  c:That(hp.memHead:IsShown() and not hp.chHead:IsShown(), "his journey in place of this chapter")
  c:Eq(hp.facts[2].k:GetText(), L.FACT_DAYS, "the days he was in the fellowship")
  c:That(not hp.inviteBtn:IsShown() and not hp.iBar:IsShown(), "no Invite to group, no XP")
  hp.sel = nil
  -- First to fall, under a challenge: violet and silver, not gold.
  local hb = f.heroes[b]
  local keepDeeds = hb and hb.deeds
  if hb then hb.deeds = { fall = e.t } end
  ns.Window:ShowPage("chronicle")
  pf.filter = "first"; ns.Window:Refresh()
  local fm
  for _, m in ipairs(pf.medals.items) do if m:IsShown() and m.key == "fall" and not m.open then fm = m end end
  c:That(fm ~= nil and fm.solemn and fm.edge:IsShown(), "First to fall under a challenge: violet and silver, not gold")
  pf.filter = "all"
  if hb then hb.deeds = keepDeeds end
  -- The Discord board keeps the Fallen, last, as memorial rows.
  local rows = ns.Board:Build(f).heroes or {}
  local lastRow = rows[#rows]
  c:That(lastRow ~= nil and lastRow.group == "fallen", "the Discord board: the Fallen last, as memorial rows")
  local fe = lastRow and Ch:Fallen(f, lastRow.name)
  if fe then c:Has(lastRow.text or "", Ch.Day(fe.t), "with the day they fell") end
end)

step("challenges: the rulebook, Turn off in Manage, shared lives alone", function(c)
  local f, Ch, W = cur(), ns.Challenges, ns.Window
  -- The rulebook: an article after the rules.
  W:ShowPage("rules")
  local rp = W.pageFrames.rules
  c:That(rp.chal.head:IsShown(), "the rulebook has the Challenges article")
  c:Has(rp.chal:Text(), L.CHAL_HARDCORE, "it names Hardcore")
  c:Has(rp.chal:Text(), ns.Short(full("Brannic")), "and the Fallen")
  c:That(rp.chal.lives:IsShown() and rp.chal.lives.total == 2, "the rulebook's candles too")
  -- A block for each challenge with its icon, who broke it and what stands now on lines of their own, the candles
  -- under Shared lives (the check of 1 Nov 2026, 14:32: it was one long paragraph).
  local blocks = {}
  for _, bl in ipairs(rp.chal.blocks.items) do if bl:IsShown() then blocks[bl.key] = bl end end
  c:That(blocks.hardcore ~= nil and blocks.shared ~= nil, "a block for each challenge on")
  if blocks.shared then
    c:That(blocks.shared.icon:GetTexture() ~= nil and blocks.shared.ring:IsShown(), "with its icon in a gold ring")
    c:That(blocks.shared.notes:IsShown(), "the lives left on a line of their own")
    if inGame() then
      c:That(rp.chal.lives:GetTop() <= blocks.shared:GetBottom() + 1, "the candles under Shared lives")
      c:That(blocks.shared.notes:GetBottom() >= blocks.shared:GetBottom() - 1, "the block holds its lines")
    end
  end
  c:That(rp.chal.after:IsShown(), "the Fallen and starting anew after the blocks")
  -- The right page: where the challenges stand, as number tiles.
  local tiles = {}
  for _, t in ipairs(rp.tiles) do if t:IsShown() then tiles[t.key] = t end end
  c:That(rp.tilesHead:IsShown() and tiles.shared ~= nil and tiles.broken ~= nil, "the right page: the challenges as tiles")
  if tiles.shared then
    c:Eq(tiles.shared.v:GetText(), L.TILE_OF:format(Ch:SharedLeft(f), Ch:SharedLives(f)), "the lives left, in a tile")
  end
  if tiles.shared and tiles.broken and inGame() then
    c:That(math.abs(tiles.shared:GetTop() - tiles.broken:GetTop()) < 1, "two to a row")
  end
  -- Manage → Rules: Turn off asks first, then it is gone for good and the Chronicle says so.
  W:ShowPage("rulesadmin")
  local ap = W.pageFrames.rulesadmin
  local row
  for _, r in ipairs(ap.chalRows.items) do if r:IsShown() and r.key == "hardcore" then row = r end end
  c:That(row ~= nil and row.off:IsShown(), "Hardcore with Turn off")
  if row then
    click(row.off)
    c:That(W.confirm and W.confirm:IsShown(), "it asks first")
    local ok = W.confirm and W.confirm.ok:GetScript("OnClick")
    if ok then ok(W.confirm.ok) end
  end
  c:That(not Ch:Has(f, "hardcore") and f.challengesOff and f.challengesOff.hardcore ~= nil, "Hardcore is off")
  c:That(Ch:Fallen(f, full("Brannic")) ~= nil, "the Fallen stay Fallen")
  local off = false
  for _, e in ipairs(Ch:Entries(f)) do if e.icon == "challenge" then off = true end end
  c:That(off, "the Chronicle says it was turned off")
  -- Shared lives alone: a fall costs one of the fellowship's lives, and nobody falls for good.
  withChallenges(f, { shared = 3 })
  dev("hero Elyra fall")
  c:Eq(Ch:SharedLeft(f), 2, "Shared lives alone: Elyra's fall leaves 2 of 3")
  c:Eq(Ch:Fallen(f, full("Elyra")), nil, "and she plays on")
  c:Eq(ns.Hero:Status(f, full("Elyra")) == L.STATUS_FALLEN, false, "her card does not say Fallen")
end)

-- My own death: the same path as the game's (Firsts notices it; the fall waits a moment for the Death Recap).
step("challenges: your own fall, recorded after a moment", function(c)
  local f, Ch = cur(), ns.Challenges
  withChallenges(f, { hardcore = "pvp" })
  ST.myFalls = Ch:FallsOf(f, ns.Me())
  ST.myFoe = Ch:Foe() -- (a best guess: the enemy you have targeted, when the game shares the name)
  Ch:Fell()
  c:That(true, "your fall, as the game's PLAYER_DEAD would bring it (foe now: " .. tostring(ST.myFoe) .. ")")
end, 1.6) -- (longer than the moment the fall waits for the Death Recap, Challenges.RECAP_WAIT)

step("challenges: your own fall (checked)", function(c)
  local f, Ch = cur(), ns.Challenges
  c:Eq(Ch:FallsOf(f, ns.Me()), (ST.myFalls or 0) + 1, "your fall is recorded in the fellowship")
  local e = Ch:Fallen(f, ns.Me())
  c:That(e ~= nil, "Hardcore PvP Fellowship: any death ends the journey")
  c:That(e and e.zone ~= nil, "where: " .. tostring(e and e.zone))
  local recap = Ch.Recap()
  c:That(true, "the game's Death Recap gives an addon: " .. tostring(recap) .. " (nil: nothing, or hidden)")
  putChallengesBack(f)
  c:Eq(Ch:Fallen(f, ns.Me()), nil, "the Selftest fellowship's challenges put back")
end)

-- X3-X5 (the owner, 1 Nov 2026): a broken rule is marked, not stopped: the Chronicle's line, a toast, "Broke ..." on
-- the card, "Broken by" in the rulebook. Only the first break of each challenge is kept.
local function chronicleHas(text)
  ns.Window:ShowPage("chronicle")
  local pf = ns.Window.pageFrames.chronicle
  pf.filter = "all"; ns.Window:Refresh()
  for _, r in ipairs(pf.rows.items) do if r:IsShown() and r.text:GetText() == text then return true end end
  return false
end
local function cardOf(name)
  ns.Window:ShowPage("heroes")
  local hp = ns.Window.pageFrames.heroes
  hp.sel = nil; ns.Window:Refresh()
  for _, x in ipairs(hp.cards.items) do if x:IsShown() and x.who == name then return x end end
  return nil
end
local function cardLine(name)
  local x = cardOf(name)
  return x and x.line:GetText()
end
step("challenges: a broken rule, marked in the Chronicle, the card and the rulebook", function(c)
  local f, Ch = cur(), ns.Challenges
  withChallenges(f, { walk = true, white = true, fellowfound = true })
  local b, before = full("Brannic"), #report().toasts
  dev("hero Brannic break taxi")
  local e = Ch:Broke(f, b, "walk")
  c:That(e ~= nil, "Brannic took a flight path: Walk everywhere broken")
  if not e then return end
  c:That(kindSeen("challenge", before), "a toast for everyone")
  -- Its own icon and the challenge's name above the title, not the skull of a death (the check of 1 Nov, 14:32).
  local bt
  for i = before + 1, #report().toasts do if report().toasts[i].kind == "challenge" then bt = report().toasts[i] end end
  c:Eq(bt and bt.icon, ns.ICONS.chal_walk, "the toast: Walk everywhere's icon")
  c:Eq(bt and bt.kicker, L.CHAL_WALK, "and its name above the title")
  local T = ns.Toasts
  if T.frame and T.frame:IsShown() and T.current and T.current.kicker == L.CHAL_WALK and inGame() then
    c:Eq(ns.UI.icons[T.frame.icon], ns.ICONS.chal_walk, "on the banner too")
  end
  dev("hero Brannic break hearth")
  c:Eq(#Ch:BrokenBy(f, "walk"), 1, "the hearthstone after it adds nothing: only the first break is kept")
  c:That(chronicleHas(Ch:BreakText(e)), "the Chronicle: " .. Ch:BreakText(e))
  c:Has(cardLine(b) or "", L.CARD_BROKE:format(L.CHAL_WALK), "his card: Broke Walk everywhere")
  dev("hero Brannic break trade")
  c:Has(cardLine(b) or "", L.CARD_BROKE_N:format(2), "two broken: Broke 2 challenges")
  c:Has(Ch:BreakText(Ch:Broke(f, b, "fellowfound")), L.DEV_BREAK_X, "the trade names who it was with")
  ns.Window:ShowPage("rules")
  c:Has(ns.Window.pageFrames.rules.chal:Text(), L.CHAL_BOOK_BROKEN:format(ns.Short(b)), "the rulebook: Broken by Brannic")
  -- Your own, as Fellowship/ChallengeWatch.lua records it.
  dev("break gear")
  local mine = Ch:Broke(f, ns.Me(), "white")
  c:That(mine ~= nil and mine.x == L.DEV_BREAK_GEAR, "your own: " .. (mine and Ch:BreakText(mine) or "nothing"))
  -- A Friend of the fellowship is never in the challenges.
  local el = full("Elyra")
  local m = f.members[el]
  local was = m and m.friend
  if m then
    m.friend = true
    dev("hero Elyra break taxi")
    c:Eq(Ch:Broke(f, el, "walk"), nil, "a Friend breaks nothing")
    m.friend = was
  end
end)

-- Lord of the Rings: the first ring found is the Ring; only its bearer ends the quest.
step("challenges: Lord of the Rings, found, carried, lost", function(c)
  local f, Ch = cur(), ns.Challenges
  withChallenges(f, { ring = true, race = true })
  ns.Window:ShowPage("rules")
  c:Has(ns.Window.pageFrames.rules.chal:Text(), L.CHAL_BOOK_RING_NONE, "the rulebook: nobody has found it yet")
  local ringTile
  for _, t in ipairs(ns.Window.pageFrames.rules.tiles) do if t:IsShown() and t.key == "ring" then ringTile = t end end
  c:Eq(ringTile and ringTile.v:GetText(), L.TILE_RING_NONE, "its tile: Not found")
  local b, before = full("Brannic"), #report().toasts
  dev("hero Brannic ring")
  c:That(f.ring ~= nil and f.ring.who == b, "Brannic found the Ring")
  if not f.ring then return end
  c:That(kindSeen("challenge", before), "a toast for everyone")
  -- The check of 3 Nov 2026, 21:57: the Ring on his portrait's corner, not a word on the card's line.
  local card = cardOf(b)
  c:That(card ~= nil and card.ringMark:IsShown(), "his card: the Ring on his portrait")
  c:That(not (cardLine(b) or ""):find(L.CARD_RING_BEARER, 1, true), "no Ring-bearer on the line")
  local tipped = false
  for _, l in ipairs(card and card.tip or {}) do if l[1] == L.CARD_RING_TIP:format(f.ring.item or L.RING_A_RING) then tipped = true end end
  c:That(tipped, "the card's tooltip says he carries it")
  c:That(not (cardOf(ns.Me()) and cardOf(ns.Me()).ringMark:IsShown()), "no Ring on your card")
  dev("hero Corwin ring")
  c:Eq(f.ring.who, b, "a later find is no Ring")
  dev("hero Corwin ring lost")
  c:Eq(f.ring.state, nil, "only the bearer ends it")
  dev("hero Brannic ring lost")
  c:Eq(f.ring.state, "lost", "it left his bags outside Blackrock Mountain: the quest fails")
  c:That(chronicleHas(Ch:RingText(f)), "the Chronicle: " .. Ch:RingText(f))
  -- Carried into Blackrock Mountain and destroyed there: the quest is done.
  f.ring = nil
  dev("hero Corwin ring")
  dev("hero Corwin ring done")
  c:Eq(f.ring and f.ring.state, "done", "Corwin destroyed it inside Blackrock Mountain: done")
  c:That(f.ring ~= nil and chronicleHas(Ch:RingText(f)), "the Chronicle: " .. (f.ring and Ch:RingText(f) or "nothing"))
  -- Its bearer falls under Hardcore: the Ring is lost with them.
  f.ring, f.challenges.hardcore = nil, true
  dev("hero Elyra ring")
  dev("hero Elyra fall")
  c:That(f.ring ~= nil and f.ring.state == "lost" and f.ring.why == "fell", "Elyra fell carrying it: lost")
  c:That(f.ring ~= nil and chronicleHas(Ch:RingText(f)), "the Chronicle: " .. (f.ring and Ch:RingText(f) or "nothing"))
  local rings = 0
  for _ in pairs(ns.ChallengeWatch.Rings()) do rings = rings + 1 end
  c:That(true, ("your bags and fingers hold %d ring(s); inside Blackrock Mountain now: %s"):format(rings,
    tostring(ns.ChallengeWatch.InBlackrock())))
end)

-- Lord of the Rings: a bearer who goes (here: becomes a Friend of the fellowship) passes the Ring to the next in line,
-- and a ring of theirs becomes it (the owner, 3 Nov 2026).
step("challenges: Lord of the Rings, passed on when its bearer goes", function(c)
  local f, Ch = cur(), ns.Challenges
  withChallenges(f, { ring = true, race = true })
  local b = full("Brannic")
  local m = f.members[b]
  c:That(m ~= nil, "Brannic is in the fellowship")
  if not m then return end
  local was, wasCatching = m.friend, m.catching
  m.friend = nil
  dev("hero Brannic ring")
  local nxt = Ch:NextBearer(f, b)
  local before = #report().toasts
  ns.lastSound = nil
  dev("hero Brannic friend")
  c:That(f.ring ~= nil and f.ring.state == nil, "Brannic became a Friend: the Ring is not lost")
  -- The check of 3 Nov 2026, 21:57: its toast in the big moments' gold frame, with a soft chime.
  local passed
  for i = before + 1, #report().toasts do if report().toasts[i].title == L.T_RING_PASSED then passed = report().toasts[i] end end
  c:That(passed ~= nil and passed.framed == true, "the toast: in the gold frame")
  c:Eq(passed and passed.sound, "ring", "and its own sound")
  if ns.Settings:Get("sounds") ~= false and ns.Toasts.current and ns.Toasts.current.title == L.T_RING_PASSED then
    c:Eq(ns.lastSound, "ring", "the chime plays")
  end
  c:Eq(f.ring and f.ring.who, nxt, "it passes to the next in line")
  c:That(nxt ~= nil and chronicleHas(L.CH_RING_PASSED:format("Brannic", ns.Short(nxt))), "the Chronicle says so")
  ns.Window:ShowPage("rules")
  c:Has(ns.Window.pageFrames.rules.chal:Text(), L.CHAL_BOOK_RING_WAIT:match(": (.*)$"), "the rulebook: a ring of theirs becomes it")
  c:Has(ns.Window.pageFrames.rules.chal:Text(), L.CHAL_BOOK_RING_ROAD:match("^(.-)%%s"), "the Ring's road")
  c:Eq(Ch:RingRoad(f), "Brannic" .. L.RING_ROAD_THEN .. ns.Short(nxt or "?"), "Brannic, then " .. ns.Short(nxt or "?"))
  c:Has(ns.Window.pageFrames.rules.chal:Text(), L.CHAL_RING_PASS_RULE, "the rule says how it passes on")
  if nxt and nxt ~= ns.Me() then
    dev("hero " .. ns.Short(nxt) .. " ring claim")
    c:Eq(f.ring and f.ring.guid, "dev-ring-2", "a ring of theirs is the Ring now")
  else
    c:That(true, "it passed to you: a ring you wear or carry becomes it")
  end
  f.ring = nil
  m.friend, m.catching = was, wasCatching
end)

-- Race to 60: the clock in the rulebook; done, the Chronicle keeps the time and the account the best (put back after).
step("challenges: Race to 60, the clock and the account's best", function(c)
  local f, Ch = cur(), ns.Challenges
  ns.Window:ShowPage("rules")
  c:Has(ns.Window.pageFrames.rules.chal:Text(), L.CHAL_BOOK_RACE:match("^(.-)%%s"), "the rulebook's clock")
  local raceTile
  for _, t in ipairs(ns.Window.pageFrames.rules.tiles) do if t:IsShown() and t.key == "race" then raceTile = t end end
  c:Eq(raceTile and raceTile.k:GetText(), L.TILE_RACE, "and its tile, the race clock")
  local keep = ns.db.raceRecord
  ns.Fellowship:Do({ k = "raced" })
  c:That(f.race ~= nil, "everyone at 60: the race is done")
  if f.race then
    c:Eq(f.race.secs, f.race.t - Ch:RaceStart(f), "the time since the founding")
    c:That(chronicleHas(L.CH_RACE:format(Ch.Span(f.race.secs))), "the Chronicle keeps it: " .. Ch.Span(f.race.secs))
    c:That(ns.db.raceRecord ~= nil, "the account's best")
  end
  ns.db.raceRecord = keep
end)

-- Ironman Fellowship holds Hardcore Fellowship and White gear only: Manage → Rules has no Turn off for them.
step("challenges: Ironman Fellowship holds the two it takes with it", function(c)
  local f, Ch, W = cur(), ns.Challenges, ns.Window
  withChallenges(f, { ironman = true, hardcore = true, white = true })
  W:ShowPage("rulesadmin")
  local rows = {}
  for _, r in ipairs(W.pageFrames.rulesadmin.chalRows.items) do if r:IsShown() then rows[r.key] = r end end
  local hc, iron = rows.hardcore, rows.ironman
  c:That(hc ~= nil and hc.held:IsShown() and not hc.off:IsShown(), "Hardcore: Held by Ironman Fellowship, no Turn off")
  c:That(rows.white ~= nil and rows.white.held:IsShown(), "White gear only: held too")
  c:That(iron ~= nil and iron.off:IsShown() and not iron.held:IsShown(), "Ironman Fellowship itself can be turned off")
  ns.Fellowship:Do({ k = "chaloff", key = "hardcore" })
  c:That(Ch:Has(f, "hardcore"), "and a Turn off for Hardcore is refused")
end)

-- The watch (Fellowship/ChallengeWatch.lua) on this client: the game functions it listens to are here, and a pass
-- over your own character runs. What it finds is written down, then put back with the challenges.
step("challenges: the watch reads this client", function(c)
  local f, Ch, CW = cur(), ns.Challenges, ns.ChallengeWatch
  if inGame() then
    local missing = {}
    for _, name in ipairs({ "TakeInboxItem", "TakeInboxMoney", "SendMail", "UseAction", "GetInventoryItemQuality",
      "GetMoney", "UnitOnTaxi", "GetProfessions" }) do
      if type(_G[name]) ~= "function" then missing[#missing + 1] = name end
    end
    local AH = C_AuctionHouse
    if not (AH and AH.PostItem) and type(_G.PostAuction) ~= "function" then missing[#missing + 1] = "the auction house" end
    if not (C_Container and C_Container.UseContainerItem) then missing[#missing + 1] = "C_Container.UseContainerItem" end
    c:Eq(table.concat(missing, ", "), "", "every game function the watch listens to is here")
  end
  withChallenges(f, { ironman = true, hardcore = true, white = true, walk = true, pauper = Ch.PAUPER_MAX })
  CW:CheckAll()
  local me, seen = ns.Me(), {}
  for _, key in ipairs({ "white", "pauper", "walk", "ironman" }) do
    local e = Ch:Broke(f, me, key)
    if e then seen[#seen + 1] = Ch:BreakText(e) end
  end
  c:That(true, "a pass over you: " .. (#seen > 0 and table.concat(seen, " ") or "nothing broken"))
  c:That(type(CW.TalentsSpent()) == "boolean", "talents read (points spent: " .. tostring(CW.TalentsSpent()) .. ")")
end)

-- One class only and No healers are held at the door, not marked.
step("challenges: One class only and No healers, held at the door", function(c)
  local f, Ch = cur(), ns.Challenges
  local mine = ns.Fellowship:MyInfo().class
  withChallenges(f, { oneclass = mine, nohealers = true })
  local other = mine == "MAGE" and "WARRIOR" or "MAGE"
  local ok, why = Ch:Allows(f, other, "DPS")
  c:That(not ok, "a " .. Ch.ClassName(other) .. " can't join")
  c:Eq(why, L.CHAL_ONECLASS_NO:format(Ch.ClassName(mine)), "and is told why")
  local b = full("Brannic")
  local role = f.members[b] and f.members[b].role
  dev("hero Brannic role Healer")
  c:That(f.members[b] and f.members[b].role ~= "Healer", "Brannic can't take the Healer role (still " .. tostring(f.members[b] and f.members[b].role) .. ")")
  c:Eq(f.members[b] and f.members[b].role, role, "his role is unchanged")
  -- A Friend of another class plays along, but can't play on as an Adventurer or be the next Leader.
  local fr
  for n, m in pairs(f.members) do if n ~= ns.Me() and m.class and m.class ~= mine then fr = n end end
  local m = fr and f.members[fr]
  if m then
    local was = m.friend
    m.friend = true
    c:That(not ns.Fellowship:CanLead(f, fr), "a " .. Ch.ClassName(m.class) .. " Friend can't be the next Leader")
    dev("hero " .. ns.Short(fr) .. " friend off")
    c:That(m.friend == true, "nor play on as an Adventurer")
    m.friend = was
  end
  putChallengesBack(f)
  c:Eq(ST.chalKeep, nil, "the Selftest fellowship's challenges put back")
end)

-- U15: chapters unlocked in a row (three or more) read as one line that opens to show them.
step("Chronicle: chapters unlocked in a row are one line", function(c)
  local now = time()
  local list = { { type = "run", time = now }, { type = "chapter", ch = 5, time = now }, { type = "chapter", ch = 4, time = now },
    { type = "chapter", ch = 3, time = now }, { type = "run", time = now } }
  local g = ns.ChronicleGroups(list, {})
  c:Eq(#g, 3, "a run, one line for chapters III to V, a run")
  c:That(g[2].group and g[2].lo == 3 and g[2].hi == 5, "the group: III to V")
  c:Eq(#ns.ChronicleGroups(list, { [g[2].key] = true }), 6, "opened: the group line and its three chapters")
  ns.Window:ShowPage("chronicle")
  local pf = ns.Window.pageFrames.chronicle
  local grouped
  for _, e in ipairs(pf.rows.items) do if e:IsShown() and e.groupKey then grouped = e end end
  c:That(true, grouped and "this fellowship's Chronicle groups its chapter lines" or "no three chapters in a row here")
end)

-- M25: a session with Brannic in the group (a pretend one: it started 15 minutes ago and he left 3 minutes ago).
step("session recap: the toast, and the Chronicle at Sessions", function(c)
  local S, f = ns.Session, cur()
  ns.Dev.group = { full("Brannic") }
  S:Tick()
  c:That(S.cur ~= nil, "a session starts with Brannic in the group")
  dev("group off")
  if S.cur then S.cur.start, S.cur.last = time() - 15 * 60, time() - 3 * 60 end
  S:Tick()
  c:That(S.cur == nil, "it ends two minutes after he left")
  c:That(toastSeen("session", nil), "the Session recap toast")
  local rec = S:List()[1]
  c:Eq(rec and rec.fid, f.id, "kept for this character")
  c:Has(rec and S:Text(rec), "Brannic", "with Brannic")
  ns.Window:Open("chronicle#session")
  local pf = ns.Window.pageFrames.chronicle
  c:Eq(pf.filter, "session", "a click opens the Chronicle at Sessions")
  c:That(pf.rows.items[1] and pf.rows.items[1]:IsShown(), "the session listed")
end)

shot("chronicle, sessions")

-- M25: an invite that reaches the player but not their addon (Kim, pretend: the no-answer path as after the wait).
step("friends without the addon: the share window", function(c)
  ns.Window:ShowPage("heroes")
  c:That(ns.Window.pageFrames.heroes.share:IsShown(), "Share the addon under Invite Adventurers")
  ns.Dev:Fake("Kim")
  ns.Fellowship:Invite("Kim")
  ns.Sync:DropInvite(cur(), full("Kim"), L.INVITE_NOANSWER, true)
  c:That(cur().invites[full("Kim")] == nil, "the invite is gone")
  local o = ns.Window.overlays and ns.Window.overlays.share
  c:That(o and o:IsShown(), "the window opens in the open book")
  c:Has(o and o.title:GetText(), "Kim", "it names Kim")
  c:Eq(o and o.url:GetText(), ns.Share.URL, "the addon's page to copy")
  c:Has(ns.Share:WhisperText("Kim"), ns.Share.URL, "Whisper the link puts the page in the whisper")
end)

shot("share the addon")

step("friends without the addon: closed", function(c)
  local o = ns.Window.overlays and ns.Window.overlays.share
  if o then o:Hide() end
  c:That(not (o and o:IsShown()), "closed")
end)

-- What WoW Addon Webhooks for Discord posts (Fellowship/Board.lua, docs/SAVED-DATA.md): written at logout; here only
-- built, so the Selftest fellowship never reaches the saved data.
step("board: what WoW Addon Webhooks for Discord gets (built, not saved)", function(c)
  local f = cur()
  local g = ns.Board:Group(f)
  local b = g.kept.board.data
  c:Eq(b.format, ns.Board.FORMAT, "format " .. tostring(b.format))
  c:Eq(b.fellowship and b.fellowship.name, f.name, "the fellowship")
  c:Eq(b.chapter and b.chapter.n, ns.Journey:Current(f).n, "the current chapter")
  c:That(b.stages and #b.stages >= 3, "the stages: " .. (b.stages and #b.stages or 0))
  c:Eq(#b.heroes, ns.Fellowship:Count(f), "every Adventurer once")
  local mine
  for _, h in ipairs(b.heroes) do if h.name == ns.Me() then mine = h end end
  c:Eq(mine and mine.short, ns.Short(ns.Me()), "you by name (the channel has no \"you\")")
  c:Has(b.summary, f.name, "the summary line")
  c:Eq(g.kept.board.text, b.summary, "the line with the picture")
  c:That(#g.news > 0, #g.news .. " news to post (clears and chapters)")
end)

step("other addons: DungeonJournal, Attune, Questie, Lore Forever and Spoken", function(c)
  local dj = ns.Window:JournalCommand() ~= nil
  local at = ns.QuestLists:AttuneCommand() ~= nil
  local qs = ns.Quests:QuestieState()
  local lore, spoken = ns.OtherAddons:HasLore(), ns.OtherAddons:HasSpoken()
  report().addons = { dungeonJournal = dj, attune = at, questie = qs, loreForever = lore, spoken = spoken }
  local function has(v) return v and "installed" or "not installed" end
  c:That(true, "DungeonJournal " .. has(dj) .. ", Attune " .. has(at) .. ", Questie " .. qs .. ", Lore Forever " .. has(lore)
    .. ", Spoken " .. has(spoken))
  -- The Quests page names Questie: a credit when it runs, else the recommendation (unless hidden).
  ns.Window:ShowPage("quests")
  local pf = ns.Window.pageFrames.quests
  c:That(qs == "on" and pf.questie:IsShown() or qs ~= "on", "Questie credited on the Quests page when running")
  -- Lore on every dungeon row, Lore Forever or not; without it a click says to install it (30 Oct 2026).
  ns.Window:ShowPage("chapter")
  local row
  for _, r in ipairs(ns.Window.pageFrames.chapter.rows.items) do if not row and r:IsShown() and r.key then row = r end end
  if not row then return c:That(true, "no dungeon rows in this chapter: Lore not checked") end
  c:That(row.lore:IsShown(), "Lore on the Chapter page's dungeon rows")
  if not lore then
    row.lore:GetScript("OnClick")(row.lore)
    c:That(toastSeen(nil, "Install the Lore Forever addon"), "without Lore Forever, a click says to install it")
  end
end)

---------------------------------------------------------------------------
-- M14 to M18 and the rest: toasts, attunements, quests together, milestones, one-level chapters, the Endgame,
-- leaving as the leader, away by the rule, takeover, roles, versions, help runs, the minimap and toast position
---------------------------------------------------------------------------
step("toasts: a long text wraps and the banner grows", function(c)
  ns.Toasts:Push("clear", "A long toast", ("The whole text must be readable, however long it is. "):rep(3))
  local t = ns.Toasts.frame
  if inGame() then c:That(t:GetHeight() > 86, ("taller than one line (%d)"):format(t:GetHeight())) end
end, 1)

-- U7: in the game the clear message finds the place's own picture (the same file as the Chapter page's rows).
step("toasts: a clear shows the place's picture and who was there", function(c)
  local key = ns.Dungeon("dm") and "dm" or ns.DUNGEONS[1][1]
  c:Eq(ns.Clears:ClearedToast(cur(), key, { ns.Me(), full("Brannic") }), "shown", "the clear message")
  local t = ns.Toasts.frame
  if inGame() then c:That(t.place:IsShown(), ("%s: its picture shows"):format(key)) end
  c:That(t.who:IsShown() and (t.who:GetText() or ""):find("Brannic", 1, true) ~= nil, "who was there")
end, 1)

-- U8: a Gathering's reminder and a newly open attunement show their place's picture, as a clear does.
step("toasts: a Gathering and an attunement show their place's picture", function(c)
  local QL = ns.QuestLists
  local mc, dmKey
  for _, a in ipairs(ns.ATTUNEMENTS) do
    if a.key == "mc" and a.kind == "raid" and not a.raid then mc = a end
    if a.item == 18249 then dmKey = a end
  end
  if mc then c:Eq(QL.PlaceOf(mc), "mc", "Molten Core's attunement: the raid's picture") end
  if dmKey then c:Eq(QL.PlaceOf(dmKey), "dme", "the Dire Maul key: Dire Maul's picture, not the Deadmines'") end
  local key = ns.Dungeon("dm") and "dm" or ns.DUNGEONS[1][1]
  ns.Toasts:Push("gathering", ns.L.G_SOON, ns.L.G_SOON_TEXT:format("The Deadmines", "20:00"), "gatherings", { dungeon = key })
  if inGame() then c:That(ns.Toasts.frame.place:IsShown(), ("a Gathering at %s: its picture"):format(key)) end
  ns.Toasts:Push("gathering", ns.L.G_SOON, ns.L.G_SOON_TEXT:format(ns.L.G_SOMETHING_ELSE, "20:00"), "gatherings", {})
  c:That(not ns.Toasts.frame.place:IsShown(), "a Gathering without a dungeon: the icon as before")
end, 1)

step("attunements: start levels and the toast when one opens", function(c)
  local QL = ns.QuestLists
  local side = UnitFactionGroup("player") == "Horde" and "H" or "A"
  -- Retail has none of our attunements (they are WoW Forever's): none opens there.
  if #ns.ATTUNEMENTS == 0 then
    c:Eq(#QL:NewlyAvailable(side, 1, ns.LevelCap()), 0, "none in this game")
    return
  end
  local open = QL:NewlyAvailable(side, 54, 55)
  local names = {}
  for _, a in ipairs(open) do names[#names + 1] = a.name end
  -- Upper Blackrock Spire's key, in both games' lists (Molten Core waits for Blizzard's word in WoW Forever).
  c:Has(table.concat(names, ", "), "Upper Blackrock Spire", "opening at 55")
  QL:OnLevelUp(55)
  c:That(toastSeen("attune", nil), "a toast for each one")
  QL.viewLevel = 30
  -- Only the ones not started: a high character has started or done some, and those stay open whatever the level
  -- (QL:CanStart; failed on a level 70, 29 Oct 2026).
  local fresh = 0
  for _, a in ipairs(QL:Attunements(cur(), ns.Me())) do
    local p = QL:Progress(cur(), a, ns.Me())
    if not (p.done or p.n > 0 or p.at ~= nil) then fresh = fresh + 1 end
  end
  c:Eq(fresh, 0, "none at level 30 (besides the ones you started)")
  QL.viewLevel = nil
end)

step("quests: Together and You could join", function(c)
  dev("hero Elyra quests")
  local together, join, pretend = 0, 0, false
  for _, x in ipairs(ns.Quests:Items(cur())) do
    if x.together then together = together + 1 end
    if x.join then join = join + 1 end
    if x.join and x.name == L.DEV_JOIN_QUEST then pretend = true end
  end
  c:That(pretend, "Elyra's quest is one you could join")
  c:That(true, ("%d together, %d to join"):format(together, join))
  ns.Window:ShowPage("quests")
  ns.Window.pageFrames.quests.tabs.buttons[2]:Click()
end)

shot("quests, together and could join")

step("milestones: Required holds the chapter, a tick reaches it", function(c)
  local f = cur()
  local J, M = ns.Journey, ns.Milestones
  local n = J:CurrentIndex(f)
  local j = J.Clean(f.journey)
  j.chapters[n].milestones = { { id = "st1", kind = "tick", name = "Selftest milestone", req = true },
    { id = "st2", kind = "level", value = j.chapters[n].cap, name = M.DefaultName("level", j.chapters[n].cap), req = false } }
  c:That(ns.Fellowship:PublishJourney(j), "published with two milestones")
  c:Eq(#M:OpenRequired(f, n), 1, "one Required milestone open")
  c:That(ns.Fellowship:Tick("st1", true), "ticked off")
  c:Eq(#M:OpenRequired(f, n), 0, "none open")
  c:Has(M:ProgressText(f, M:List(f, n)[1]), ns.Short(ns.Me()), "ticked off by you")
  ns.Window:ShowPage("chapter")
  ns.Window.pageFrames.chapter.sel = nil
end)

shot("chapter, milestones")

step("milestones: the form in Journey Admin", function(c)
  ns.AdminDraft:MilestoneForm(cur())
  local o = ns.Window.overlays.milestone
  c:That(o and o:IsShown(), "the Add a milestone form")
  -- A quest picked from the quests you and the others have (M25; Elyra shared hers above), or its ID.
  c:That(o.pick:IsShown(), "the quest list for a quest milestone")
  local list = ns.Quests:Pickable(cur())
  c:That(#list > 0, #list .. " quests to pick from")
  if #list > 0 then
    click(o.pick.items[1])
    c:Eq(o.value:GetText(), tostring(list[1].id), "a pick fills in the ID")
    c:Eq(o.name:GetText(), list[1].name, "and the name")
  end
end)

shot("journey admin, add a milestone")

step("milestones removed; a one-level chapter (60-60) can be published", function(c)
  local o = ns.Window.overlays.milestone
  if o then o:Hide() end
  local f = cur()
  local j = ns.Journey.Clean(f.journey)
  for _, ch in ipairs(j.chapters) do ch.milestones = nil end
  c:That(ns.Fellowship:PublishJourney(j), "milestones removed")
  local raids = ns.Journey.Clean({ chapters = { { name = "Raids", floor = 60, cap = 60 } } })
  c:That(raids ~= nil, "a 60-60 chapter is a valid journey")
  c:Eq(raids and #ns.Journey.Issues(raids, 1), 0, "no problems shown")
end)

step("leaving as the leader hands the fellowship over", function(c)
  local f = cur()
  local heir = ns.Fellowship:Successor(f)
  c:That(heir ~= nil and heir ~= ns.Me(), "a successor: " .. tostring(heir and ns.Short(heir)))
  c:Has(ns.Fellowship:LeaveQuestion(f), ns.Short(heir or "?"), "the question names them")
  ns.Window:ShowPage("managefellowship")
  c:Has(ns.Window.pageFrames.managefellowship.leaveText:GetText(), ns.Short(heir or "?"), "The fellowship tab says who leads after you")
end)

step("away by the rule, and the takeover rule", function(c)
  local f = cur()
  local h = ns.Hero:Get(f, full("Corwin"))
  local heard = h and h.heard
  if h then h.heard = time() - (f.rules.awayDays + 1) * 86400 end
  c:Eq(ns.Journey:Away(f, full("Corwin")), "auto", "Corwin away after the rule's days")
  if h then h.heard = heard end
  c:Eq(ns.Journey:Away(f, full("Corwin")), nil, "back when seen")
  -- Takeover, on a copy with Elyra as a leader gone for too long: the Adventurer who joined first (you, the founder).
  local copy = { leader = full("Elyra"), officers = {}, members = f.members, rules = f.rules,
    heroes = { [full("Elyra")] = { heard = time() - (f.rules.takeover + 1) * 86400 } } }
  c:Eq(ns.Progress:LongestServing(copy), ns.Me(), "you are in the fellowship the longest")
  c:That(ns.Progress:CanTakeOver(copy, ns.Me()), "you may take over")
end)

step("roles, addon versions, help runs", function(c)
  local f = cur()
  local m = f.members[ns.Me()]
  local role, second = m.role, m.second
  ns.Fellowship:SetRoles(ns.Me(), "Healer", "Tank")
  c:Eq(m.role .. "/" .. tostring(m.second), "Healer/Tank", "role and secondary role")
  ns.Fellowship:SetRoles(ns.Me(), role, second)
  c:That(ns.NewerVersion("1.2.0", "1.1.9") and not ns.NewerVersion("1.0.0", "1.0.0"), "versions compare")
  local ch = ns.Journey:Current(f)
  dev("hero Corwin level " .. (ch.floor - 3))
  dev("group Corwin")
  c:That(ns.Progress:HelpRun(f), "grouped with a Hero below the floor: a help run")
  dev("group off")
  dev("hero Corwin level " .. ch.floor)
end)

-- The Adventurers page (28 Oct 2026): a presence mark on every card like the game's friends list, and "Old addon"
-- for an addon older than the newest in the fellowship.
step("roles, addon versions: presence marks and the Old addon tag", function(c)
  local f, Hr = cur(), ns.Hero
  local B, E, Co = full("Brannic"), full("Elyra"), full("Corwin")
  local vers = {}
  for _, name in ipairs({ B, E }) do local h = Hr:Get(f, name); vers[name] = h and h.ver or false end
  dev("hero Brannic quiet"); dev("hero Elyra afk"); dev("hero Corwin offline")
  c:Eq((Hr:Presence(f, B)), "quiet", "Brannic: online in the game, the addon not heard (a green ring)")
  c:Eq((Hr:Presence(f, E)), "afk", "Elyra: AFK (yellow)")
  c:Eq((Hr:Presence(f, Co)), "offline", "Corwin: offline (red)")
  ns.Window:ShowPage("heroes")
  local pf = ns.Window.pageFrames.heroes
  local kind, old = {}, {}
  for _, card in ipairs(pf.cards.items) do
    if card:IsShown() and card.who then kind[card.who] = card.presence and card.presence.kind; old[card.who] = card.old:IsShown() end
  end
  c:Eq(kind[Co], "offline", "Corwin's card has the red mark")
  dev("hero Elyra version 0.9.2"); dev("hero Brannic version 0.9.0")
  c:Eq((Hr:OldVersion(f, B)), "0.9.0", "Brannic's addon is older than the newest")
  ns.Window:Refresh()
  for _, card in ipairs(pf.cards.items) do if card:IsShown() and card.who == B then old[B] = card.old:IsShown() end end
  c:That(old[B], "Brannic's card says Old addon")
  for _, n in ipairs(PRETEND) do dev("hero " .. n .. " online") end
  for name, v in pairs(vers) do local h = Hr:Get(f, name); if h then h.ver = v or nil end end
  c:Eq((Hr:Presence(f, Co)), "online", "Corwin back online (green)")
end)

step("the tracker on the screen", function(c)
  local TK = ns.Tracker
  -- Your own tracker settings are put back afterwards (with the tracker off, this step failed; 27 Oct 2026).
  local S0 = ns.Settings
  -- Its own panel: docked under the game's tracker (on by default since 2 Nov 2026) has its own step below.
  local was = { tracker = S0:Get("tracker"), trackerHover = S0:Get("trackerHover"), trackerDock = S0:Get("trackerDock") }
  S0:Set("tracker", true); S0:Set("trackerHover", false); S0:Set("trackerDock", false)
  c:Eq(ns.Settings:Get("tracker"), true, "Settings: tracker on")
  c:That(TK.frame ~= nil, "built")
  c:That(cur() ~= nil, "in a fellowship")
  TK:Refresh()
  c:That(TK.frame and TK.frame:IsShown(), "shown")
  local content = TK:Content(cur())
  c:Has(content.title, cur().journey.chapters[ns.Journey:CurrentIndex(cur())].name, "the chapter")
  -- U13: an icon on each line, and the little bar under "you".
  local icons, shownLines = 0, 0
  for _, b in ipairs(TK.frame.lines) do
    if b:IsShown() then shownLines = shownLines + 1; if b.icon:IsShown() then icons = icons + 1 end end
  end
  if inGame() then c:Eq(icons, shownLines, "every line has its icon") end
  c:That(content.bar ~= nil and content.bar.value >= 0 and content.bar.value <= 1, "the bar under you: a share of the way")
  if ns.Settings:TrackerLineOn("you") and not ns.char.trackerFolded then
    c:That(TK.frame.floorBar:IsShown(), "the bar shows under you")
  end
  c:That(content.next ~= nil, "a next step: " .. tostring(content.next))
  TK:SetFolded(true)
  -- The game scales sizes to screen pixels: 30 comes back as 29.999996.
  local h = TK.frame:GetHeight()
  c:That(math.abs(h - 30) < 0.5, ("folds to its title (height %.1f)"):format(h))
  TK:SetFolded(false)
  -- Settings: a line off, and details on mouse-over only.
  local S = ns.Settings
  local function lineShown(key) for _, b in ipairs(TK.frame.lines) do if b.key == key then return b:IsShown() end end end
  S:SetTrackerLine("online", false)
  c:That(not lineShown("online"), "a line switched off in Settings")
  S:SetTrackerLine("online", true)
  S:Set("trackerHover", true)
  c:That(TK.frame:GetAlpha() == 0 and not TK.frame.bar:IsMouseEnabled(), "hidden: completely invisible, clicks go through")
  S:Set("trackerHover", false)
  c:That(lineShown("status"), "and back")
  ns.Settings:Set("tracker", false)
  c:That(not TK.frame:IsShown(), "off in Settings")
  for k, v in pairs(was) do S0:Set(k, v) end
end)

-- Under the game's quest tracker (Settings; the owner, 2 Nov 2026). Only looked at, never changed: folding the game's
-- tracker from here would taint it (its quest item buttons would fail until a /reload).
step("the tracker under the game's quest tracker", function(c)
  local TK, S = ns.Tracker, ns.Settings
  local was = { tracker = S:Get("tracker"), trackerHover = S:Get("trackerHover"), trackerDock = S:Get("trackerDock") }
  local wasFolded = ns.char.trackerFolded
  S:Set("tracker", true); S:Set("trackerHover", false); TK:SetFolded(false)
  S:Set("trackerDock", true)
  local fr, ot = TK.frame, TK:GameTracker()
  if not ot or not fr.dock then
    c:That(not TK:Docked() and fr:IsShown() and fr.bar:IsShown(), "no game tracker to sit under here: the panel stays")
  else
    c:That(TK:Docked(), "docked under the game's quest tracker")
    local _, to = fr:GetPoint()
    c:That(to == ot or to == ot.NineSlice or to == ot.Header, "anchored to the game's tracker")
    if ot:IsCollapsed() then
      c:That(not fr:IsShown(), "the game's tracker is folded: ours folds away with it")
    else
      c:That(fr:IsShown() and fr.dock:IsShown() and not fr.bar:IsShown(), "the game's section header, not our title bar")
      c:Has(fr.dock.Text:GetText(), cur().journey.chapters[ns.Journey:CurrentIndex(cur())].name, "the chapter in the header")
      fr.dock.MinimizeButton:Click()
      c:That(ns.char.trackerFolded == true, "folds with the game's fold button")
      local tex = fr.dock.MinimizeButton:GetNormalTexture()
      if tex and tex.GetAtlas then
        -- Atlas names are not case-sensitive; the game gives this one back in capitals.
        c:Eq((tex:GetAtlas() or ""):lower(), "ui-questtrackerbutton-secondary-expand", "the game's fold button shows it folded")
      end
      fr.dock.MinimizeButton:Click()
      c:That(not ns.char.trackerFolded, "and opens again")
      -- The book repaints its colours when its page changes; the docked look must come back (a dark box with a gold
      -- edge was seen after a click on a line, 2 Nov 2026).
      ns.Theme:Apply()
      local _, _, _, bg = fr:GetBackdropColor()
      c:That(math.abs((bg or 0) - TK.DOCK_SHADE * (ot.NineSlice:GetAlpha() or 0)) < 0.01,
        ("after a repaint: no dark box (background %.2f)"):format(bg or -1))
    end
  end
  S:Set("trackerDock", false)
  c:That(not TK:Docked() and fr.bar:IsShown(), "off: its own panel again")
  for k, v in pairs(was) do S:Set(k, v) end
  TK:SetFolded(wasFolded)
end)

step("minimap button and toast position", function(c)
  local S = ns.Settings
  S:Set("minimap", false)
  c:That(not ns.MinimapButton.button:IsShown(), "minimap button hidden")
  S:Set("minimap", true)
  c:That(ns.MinimapButton.button:IsShown(), "and back")
  ns.Toasts:StartMove()
  c:That(ns.Toasts.moving and ns.Toasts.frame:IsShown(), "move mode shows a sample banner")
  ns.Toasts:StopMove()
  ns.Toasts:ResetPosition()
  c:That(not ns.Toasts.moving, "done; position reset")
end)

step("the Endgame: raids open after the journey", function(c)
  local f = cur()
  local E = ns.Endgame
  ST.reached = f.reached
  f.reached = #f.journey.chapters + 1
  c:That(E:Open(f), "the Endgame is open")
  c:That(ns.Pages:InNav("raids", ns.Pages:Context()), "Raids in the sidebar")
  for _, n in ipairs(PRETEND) do dev("group " .. n) end
  local before = f.rules.minHeroes
  -- The raid of this game with the most bosses in its data (WoW Forever: Onyxia's Lair; retail: one of its own),
  -- opened for the test when its day has not come (WoW Forever's raids open on 9 December 2026).
  local raid, most = nil, -1
  for _, r in ipairs(ns.RAIDS) do
    local list = ns.Clears:DataBosses(r[1]) or {}
    if #list > most then raid, most = r, #list end
  end
  c:That(raid ~= nil, "a raid in this game")
  if not raid then return end
  local key = raid[1]
  ST.raid, ST.raidOpened = key, ns.db.opened and ns.db.opened[key]
  if not ns.IsOpen(key) then
    c:That(ns.OpensText(key) ~= nil, raid[2] .. " opens on " .. tostring(ns.OpensText(key)))
    ns.db.opened = ns.db.opened or {}
    ns.db.opened[key] = time()
  end
  -- Find group first: it picks who has not cleared the raid, and Onyxia's Lair is cleared with its one boss.
  local picked = E:FindGroup(f, key)
  c:That(#picked > 0, "Find group for a raid picks " .. #picked)
  local want = math.min(2, most)
  dev("kill " .. key .. " " .. want)
  local n = ns.Clears:Progress(f, key, ns.Me())
  c:Eq(n, want, raid[2] .. ": bosses counted")
  c:That(#E:BossProgress(f, key) >= most, raid[2] .. ": bosses listed")
  local st = E:AttuneStatus(f, raid)
  c:That(true, #st.attuned .. " attuned to " .. raid[2])
  dev("group off")
  f.rules.minHeroes = before
  ns.Window:ShowPage("raids")
  ns.Window.pageFrames.raids.raid = key
  ns.Window:Refresh()
end, 1)

shot("raids")

step("the Endgame closes again (the journey is not done)", function(c)
  local f = cur()
  f.reached = ST.reached
  ns.Clears.recent = {}
  if ST.raid and ns.db.opened then ns.db.opened[ST.raid] = ST.raidOpened end
  c:That(not ns.Endgame:Open(f) or ns.Journey:CurrentIndex(f) > #f.journey.chapters, "closed")
  ns.Window:ShowPage("overview")
end)

-- The tournament: play every round (the higher seed wins), until there is a champion.
local function playRounds(c, label)
  local f = cur()
  local Tn, T = ns.Tourney, ns.Tournament
  local me = ns.Me()
  for _ = 1, 20 do
    local t = f.tourney
    if not t or t.phase ~= "running" then break end
    local live = T.Live(Tn:Build(t), t.slot)
    if #live == 0 then Tn:Advance(f) else
      for _, m in ipairs(live) do
        if m.a == me then Tn:OnDuel(m.a, m.b) else opFrom(ns.Short(m.a), { k = "tourney", a = "duel", key = m.key, w = m.a }) end
      end
    end
  end
  local t = f.tourney
  c:Eq(t and t.phase, "done", label .. ": the tournament is over")
  c:That(t and t.champion ~= nil, label .. ": champion " .. tostring(t and t.champion and ns.Short(t.champion)))
end

local function newTourney(format)
  local f = cur()
  if format then
    local r = {}
    for k, v in pairs(f.rules) do r[k] = v end
    r.tFormat = format
    ns.Fellowship:SetRules(r)
  end
  dev("tourney start")
  ns.Tourney:SignUp(true)
  for _, n in ipairs(PRETEND) do dev("hero " .. n .. " signup") end
  dev("tourney next")
end

step("tournament: bracket to a champion", function(c) playRounds(c, "bracket") ns.Window:ShowPage("tourney") end)

-- U17: the bracket's cards are larger, with each Adventurer's class icon and level.
step("tournament: the bracket's cards carry class icons and levels", function(c)
  ns.Window:ShowPage("tourney")
  local pf = ns.Window.pageFrames.tourney
  local card
  for _, x in ipairs(pf.cards.items) do if x:IsShown() then card = card or x end end
  c:That(card ~= nil, "a card on the page")
  if card then
    c:That(math.abs(card:GetHeight() - 60) < 0.5, ("cards 60 high (%.1f)"):format(card:GetHeight()))
    c:That((card.l1.level:GetText() or "") ~= "", "a level on the first line")
    if inGame() then c:Has(card.l1.name:GetText() or "", "|T", "a class icon before the name") end
    -- Every name whole, also yours with its You tag (check of 1 Nov 2026: "Edstr..." was cut).
    if inGame() then
      local cut
      for _, x in ipairs(pf.cards.items) do
        if x:IsShown() then
          for _, l in ipairs({ x.l1, x.l2 }) do
            local fs = l.name
            local whole = fs.GetUnboundedStringWidth and fs:GetUnboundedStringWidth() or fs:GetStringWidth()
            if whole > fs:GetWidth() + 1 then cut = fs:GetText() end
          end
        end
      end
      c:That(cut == nil, cut and ("a name is cut: " .. cut) or "every name on the cards is whole")
    end
  end
end)

shot("tournament, champion")

step("tournament: walkovers when nobody duels", function(c)
  newTourney()
  local t = cur().tourney
  c:Eq(t.phase, "running", "running")
  dev("tourney next")
  local wo = false
  for _ in pairs(t.wo or {}) do wo = true end
  c:That(wo, "matches decided by walkover")
end)

step("tournament: double elimination", function(c) newTourney("double") playRounds(c, "double") end)
step("tournament: groups, then knockout", function(c) newTourney("groups") playRounds(c, "groups") end)
step("tournament: round robin", function(c) newTourney("rr") playRounds(c, "round robin") ns.Window:ShowPage("tourney") end)

shot("tournament, round robin")

-- The fellowship's History (29 Oct 2026): its own story, apart from the journey's.
step("history: the fellowship's own story", function(c)
  local f = cur()
  c:That(#ns.Fellowship:ChronicleView(f, 1000, "members") > 0, "Adventurers who joined")
  c:That(#ns.Fellowship:ChronicleView(f, 1000, "events") > 0, "Gatherings and the tournament")
  ns.Window:ShowPage("history")
  local pf = ns.Window.pageFrames.history
  c:That(pf.rows.items[1] and pf.rows.items[1]:IsShown(), "its lines")
  c:Has(pf.founded:GetText(), "Founded", "when it was founded")
  c:That(pf.leads.items[1] and pf.leads.items[1]:IsShown(), "its Leaders")
end)

-- U9: the chapters so far, each with the day it began; the current one says "now".
step("history: the chapters so far", function(c)
  local f = cur()
  ns.Window:ShowPage("history")
  local pf = ns.Window.pageFrames.history
  local chs = ns.HistoryChapters(f, nil)
  c:Eq(#chs, math.min(ns.Journey:CurrentIndex(f), #f.journey.chapters), "one line per chapter reached")
  local shown = 0
  for _, d in ipairs(pf.chRows.items) do if d:IsShown() then shown = shown + 1 end end
  c:Eq(shown, #chs, "the timeline on the page")
  local last = pf.chRows.items[#chs]
  c:Has(last and last.day:GetText() or "", "now", "the current chapter: now")
end)

-- U6: the number tiles (a gold number over its label and icon) on every page that has them.
step("number tiles: the Adventurers page, Inspect, History and the Chronicle", function(c)
  local function tiles(where, list)
    local ok, icons = 0, 0
    for _, t in ipairs(list or {}) do
      if t:IsShown() and (t.v:GetText() or "") ~= "" and (t.k:GetText() or "") ~= "" then ok = ok + 1 end
      if t.icon:IsShown() then icons = icons + 1 end
    end
    c:Eq(ok, #(list or {}), where .. ": every tile has its number and label")
    if inGame() then c:That(true, ("%s: %d of %d with their icon"):format(where, icons, #(list or {}))) end
  end
  ns.Window:ShowPage("heroes")
  local hp = ns.Window.pageFrames.heroes
  hp.sel = nil
  ns.Window:Refresh()
  tiles("Adventurers page", hp.stats)
  hp.sel = full("Brannic")
  ns.Window:Refresh()
  tiles("Inspect", hp.facts)
  hp.sel = nil
  ns.Window:ShowPage("history")
  tiles("History", ns.Window.pageFrames.history.stats)
  ns.Window:ShowPage("chronicle")
  tiles("Chronicle", ns.Window.pageFrames.chronicle.stats)
end)

shot("fellowship history")

step("make a pretend Hero leader, and get it back", function(c)
  local f = cur()
  ns.Fellowship:MakeLeader(full("Brannic"))
  c:Eq(f.leader, full("Brannic"), "Brannic leads")
  c:That(not ns.Pages:InNav("admin", ns.Pages:Context()), "Journey Admin is gone from your sidebar")
  opFrom("Brannic", { k = "lead", name = ns.Me() })
  c:Eq(f.leader, ns.Me(), "you lead again")
end)

-- An Adventurer who joined lately gets "Welcome to the fellowship" in place of the Leader's Getting started: the
-- Chapter, the rulebook and the quests, each ticked when its page is opened (the lab and the check had no step for
-- it; asked for on 29 Oct 2026).
step("getting started as an Adventurer: the welcome card", function(c)
  local f, T, W = cur(), ns.Together, ns.Window
  local saved = ns.char.started and ns.char.started[f.id]
  ns.char.started[f.id] = {}
  ns.Fellowship:MakeLeader(full("Brannic"))
  local list, label = T:Started(f)
  c:Eq(label, L.WELCOME_LABEL, "the welcome card")
  c:Eq(list and #list, 3, "three steps: the Chapter, the rules, the quests")
  W:ShowPage("overview")
  c:That(W.pageFrames.overview.start and W.pageFrames.overview.start:IsShown(), "on the Overview")
  for _, p in ipairs({ "chapter", "rules" }) do W:ShowPage(p) end
  list = T:Started(f)
  local open = 0
  for _, s in ipairs(list or {}) do if not s.done then open = open + 1 end end
  c:Eq(open, 1, "only the quests are left")
  W:ShowPage("quests")
  c:Eq(T:Started(f), nil, "all done: the card goes")
  opFrom("Brannic", { k = "lead", name = ns.Me() })
  c:Eq(f.leader, ns.Me(), "you lead again")
  ns.char.started[f.id] = saved
  W:ShowPage("overview")
end)

-- New rules and a new journey from the Leader reach the Adventurers as toasts; a click on a toast opens its page
-- (28 Oct 2026: the toasts could not be clicked, and a new journey gave none).
step("toasts: the Leader's new rules and journey, and a click opens the page", function(c)
  local f, W = cur(), ns.Window
  ns.Fellowship:MakeLeader(full("Brannic"))
  local rules = {}
  for k, v in pairs(f.rules) do rules[k] = v end
  opFrom("Brannic", { k = "rules", rules = rules })
  c:That(toastSeen(nil, L.RULES_PUBLISHED:format("Brannic")), "new rules: a toast")
  opFrom("Brannic", { k = "journey", journey = ns.JourneyEdit.Copy(f.journey) })
  c:That(toastSeen(nil, L.JOURNEY_NEW:format("Brannic")), "a new journey: a toast")
  local T = ns.Toasts
  if T.current and T.current.page and T.frame:IsShown() then
    W:ShowPage("history")
    T:Click()
    c:Eq(W.current, T.current.page, "a click on the toast opens " .. T.current.page)
    c:That(not T.frame:IsShown(), "and the toast goes")
  else
    c:That(ns.Settings:Get("reduce"), "no toast on the screen (Reduce effects is on)")
  end
  opFrom("Brannic", { k = "lead", name = ns.Me() })
  c:Eq(f.leader, ns.Me(), "you lead again")
end)

-- A protected (secure) frame anywhere in the book makes the whole book protected: it then cannot open during combat
-- ("Interface action failed because of an AddOn"; the Tournament's hand-over button did it, 28 Oct 2026).
step("the book in combat: nothing in it is protected", function(c)
  if not inGame() then c:That(true, "only in the game") return end
  local bad, seen = {}, 0
  local function walk(fr, depth)
    seen = seen + 1
    if fr.IsProtected and fr:IsProtected() and #bad < 5 then
      bad[#bad + 1] = (fr.GetDebugName and fr:GetDebugName()) or fr:GetName() or fr:GetObjectType()
    end
    if depth < 40 then for _, child in ipairs({ fr:GetChildren() }) do walk(child, depth + 1) end end
  end
  walk(ns.Window.frame, 0)
  c:That(#bad == 0, ("%d frames, protected: %s"):format(seen, #bad > 0 and table.concat(bad, ", ") or "none"))
end)

-- Switching is done from the other character (Your characters: Take its place). In a fellowship of its own, a
-- character is told to leave it first; the whole switch is in tests/test_watch.lua (it needs a second client).
step("play another character: taken from the other character", function(c)
  local D = ns.Dev
  dev("watch")
  local s = ns.Characters:Summary(full(D.WATCH_ALT))
  c:That(s and not s.canTake, "not offered while this character is in a fellowship")
  c:Has(s and s.takeNote, cur().name, "it says to leave " .. cur().name .. " first")
  ns.Watch:Close()
  D:WatchForget()
  ns.Window:ShowPage("heroes")
  local pf = ns.Window.pageFrames.heroes
  pf.sel = ns.Me(); ns.Window:Refresh()
  c:That(pf.altHelp:IsShown(), "your own card says how to switch")
  pf.sel = nil
end)

-- Following another character's fellowship (Fellowship/Watch.lua): a pretend alt "Altara" of this account leads one
-- with Brannic and Elyra, whose answers go through the real messages (/jtf debug watch).
step("watch: follow another character's fellowship", function(c)
  local W, D = ns.Watch, ns.Dev
  local key = full(D.WATCH_ALT)
  c:That(ns.Characters:Summary(key) == nil, "no pretend alt before")
  dev("watch")
  c:That(W.active and W.as == key, "the book follows Altara's fellowship")
  c:That(ns.Characters:Summary(key) and ns.Characters:Summary(key).canWatch, "Your characters offers Follow")
  c:Eq(ns.Window.page, "overview", "it opens on the Overview")
  c:That(ns.Window.watchBar and ns.Window.watchBar:IsShown(), "the bar says whose fellowship it is, with Back")
  -- A clearer sign (check of 1 Nov 2026): the header under a cool tint, a spyglass on the bar.
  local h = ns.Window.frame.header
  c:That(h.watchVeil and h.watchVeil:IsShown(), "the header tinted while following")
  c:That(ns.Window.watchBar and ns.Window.watchBar.icon:IsShown(), "a spyglass on the bar")
end, 2)

step("watch: live and read-only", function(c)
  local W, D, Win = ns.Watch, ns.Dev, ns.Window
  c:That(W.last[D.WATCH_ID] ~= nil, "a pretend Adventurer answered")
  local f = ns.Fellowship:Get(D.WATCH_ID)
  c:Eq(f and ns.Hero:Level(f, full("Brannic")), 17, "Brannic's level arrived")
  c:Has(W:Freshness(f), "Live", "the bar says live")
  W.rendering = true
  local ctx = ns.Pages:Context()
  W.rendering = false
  c:That(ctx.watching and not ctx.canManage and not ns.Pages:InNav("quests", ctx), "read-only: no Quests or Manage")
  c:That(ns.Pages:InNav("rules", ctx), "the Rules page, to read")
  Win:ShowPage("rules")
  local rp = Win.pageFrames.rules
  c:Has(rp.who:GetText(), "Read only", "the rulebook says read only, as of when")
  c:That(not rp.leaderBox:IsShown() and not rp.propose:IsShown(), "no Propose, no way to the Rules tab")
  Win:ShowPage("heroes")
  c:That(not Win.pageFrames.heroes.leave:IsShown(), "no Leave")
  Win:ShowPage("chapter")
  local card = Win.pageFrames.chapter.rows.items[1]
  c:That(card and not card.group:IsShown() and not card.menu:IsShown(), "no Find group or Mark cleared")
  dev("watch level")
end, 2)

step("watch: news arrives, Back returns to your own", function(c)
  local W, D = ns.Watch, ns.Dev
  local f = ns.Fellowship:Get(D.WATCH_ID)
  -- The pretend answer waits in the send queue behind the check's other messages: wait for it, up to 6 seconds (2
  -- were not enough once the challenge steps came before it; check of 1 Nov 2026, 01:20).
  local t0, n = GetTime(), 0
  while f and ns.Hero:Level(f, full("Brannic")) ~= 18 and GetTime() - t0 < 6 and n < 600 do c:Yield(); n = n + 1 end
  c:Eq(f and ns.Hero:Level(f, full("Brannic")), 18, "Brannic levelled")
  W:Close()
  c:That(not W.active, "Back to your own")
  local h = ns.Window.frame.header
  c:That(not (h.watchVeil and h.watchVeil:IsShown()), "the tint goes with the bar")
  c:Eq(cur() and cur().name, "Selftest", "your own fellowship again")
  dev("watch off")
  c:That(ns.db.fellowships[D.WATCH_ID] == nil and ns.db.characters[full(D.WATCH_ALT)] == nil, "the pretend alt is gone")
end)

-- Show me around (UI/Walkthrough.lua): every step of the three tours on the sample fellowship; the game's glow art.
step("walkthrough: the glow art this client has", function(c)
  local UI = ns.UI
  local t = UIParent:CreateTexture()
  local has, no = {}, {}
  for key, path in pairs(UI.GLOW_PROBE) do
    if t:SetTexture(path) == false then no[#no + 1] = key else has[#has + 1] = key end
  end
  for _, atlas in ipairs(UI.GLOW_ATLAS_PROBE) do
    local ok = C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas) ~= nil
    if ok then has[#has + 1] = atlas else no[#no + 1] = atlas end
  end
  t:Hide()
  table.sort(has); table.sort(no)
  report().glow = { has = has, missing = no, sparks = UI.GlowArt() }
  c:That(true, "has: " .. table.concat(has, ", "))
  c:That(true, "missing: " .. (#no > 0 and table.concat(no, ", ") or "none"))
  c:That(true, "sparks: " .. (UI.GLOW_SPARKS[UI.GlowArt()] and UI.GLOW_SPARKS[UI.GlowArt()][1] or "our own dots"))
end)

step("walkthrough: every step of both tours", function(c)
  local WK, Win = ns.Walkthrough, ns.Window
  for _, rank in ipairs({ "leader", "member" }) do
    c:That(WK:Start(rank), rank .. ": started")
    c:Yield()
    local framed, count = 0, #WK.steps
    for i = 1, count do
      WK:Go(i)
      local s = WK.steps[i]
      if s.page and Win.current ~= s.page then c:That(false, rank .. " " .. s.id .. ": page " .. tostring(Win.current)) end
      -- The game refused to anchor the frame there (an error in the checks of 30 Oct 2026, 16:56 and 22:00): which
      -- part, also for the tracker, which is framed at a fixed place from the start.
      if WK.glow.refused == "all" then c:That(true, rank .. " " .. s.id .. ": the game refused both places, nothing framed")
      elseif WK.glow.refused then c:That(true, rank .. " " .. s.id .. ": anchoring refused, framed at a fixed place") end
      if s.target and s.id ~= "TRACKER" and WK.glow.refused ~= "all" then
        if WK.glow:IsShown() then framed = framed + 1 else c:That(false, rank .. " " .. s.id .. ": nothing framed") end
      end
      if s.id ~= "DONE" and (WK.card.title:GetText() or ""):sub(1, 5) == "WALK_" then c:That(false, rank .. " " .. s.id .. ": no text") end
      c:Yield()
    end
    c:That(framed > 0, ("%s: %d steps, %d framed"):format(rank, count, framed))
    WK:Stop(true)
  end
  c:Eq(ns.Watch.demo, nil, "the sample is gone")
  c:Eq(cur() and cur().name, "Selftest", "your own fellowship again")
end)

step("settings and themes", function(c)
  local S = ns.Settings
  local was = S:Get("theme")
  for _, th in ipairs({ "night", "faction", "journal" }) do S:Set("theme", th); c:Yield() end
  S:Set("theme", was)
  ns.Window:OpenSettings()
  c:That(ns.Window.current == "settings" and ns.Window:IsFlat(), "settings open, on the flat sheet")
  -- U10: folding sections; the toasts and the tracker take turns, and a folded heading says what is set.
  local pf = ns.Window.pageFrames.settings
  pf:Fold("tracker", true)
  c:That(pf.sections.tracker.body:IsShown() and not pf.sections.toasts.body:IsShown(), "the tracker opens, the toasts fold")
  c:That((pf.sections.toasts.head.sum:GetText() or "") ~= "", "the folded toasts say how many are on")
  pf:Fold("toasts", true)
  c:That(pf.sections.toasts.body:IsShown() and not pf.sections.tracker.body:IsShown(), "and back")
  pf:Fold("book", false)
  c:That(not pf.sections.book.body:IsShown() and (pf.sections.book.head.sum:GetText() or "") ~= "", "The book folds, its theme on the heading")
  pf:Fold("book", true)
  if inGame() then
    for _, side in ipairs({ "left", "right" }) do
      local last = side == "left" and pf.sections.help or pf.sections.toasts
      local bottom = last.body:GetBottom()
      c:That(bottom and pf[side]:GetBottom() and bottom >= pf[side]:GetBottom() - 1, side .. " page: everything fits")
    end
  end
end)

shot("settings")

-- This screen, whatever its resolution and UI scale (1080p, 1440p, 4K): the book with its logo and frame lies on it,
-- at its size and in full screen; full screen fills it, edge to edge (29 Oct 2026).
step("screen: the book lies on this screen, in a window and in full screen", function(c)
  local W, S = ns.Window, ns.Settings
  local was = S:Get("fullscreen")
  local w, h = UIParent:GetWidth(), UIParent:GetHeight()
  c:That(true, ("screen %.0f x %.0f UI units, UI scale %.2f"):format(w, h, UIParent:GetEffectiveScale() or 1))
  -- (Positions only count in the game: the unit-test harness places every frame at 100, 100.)
  if not inGame() then return end
  for _, fs in ipairs({ false, true }) do
    S:Set("fullscreen", fs)
    c:Yield()
    local l, b, r, t = W:Extents()
    local mode = fs and "full screen" or "window"
    c:That(l ~= nil, mode .. ": measured")
    if l then
      c:That(l >= -1 and b >= -1 and r <= w + 1 and t <= h + 1,
        ("%s: on the screen (%.0f, %.0f to %.0f, %.0f)"):format(mode, l, b, r, t))
      if fs then
        c:That(math.min((t - b) / h, (r - l) / w) > 0.99, ("full screen fills the screen (%.3f high, %.3f wide)")
          :format((t - b) / h, (r - l) / w))
        c:That(W.frame.backdrop:IsShown() and not W.frame.grip:IsShown(), "full screen: dimmed behind, no corner grip")
      end
    end
  end
  S:Set("fullscreen", was)
end)

---------------------------------------------------------------------------
-- The journey from level 1, newcomers, realms, trial accounts, pruning (27 Oct 2026)
---------------------------------------------------------------------------
local function count(t) local n = 0 for _ in pairs(t or {}) do n = n + 1 end return n end
local function has(list, x) for _, v in ipairs(list) do if v == x then return true end end return false end

step("prologue: the journey starts at level 1 with the Prologue and its picture", function(c)
  local f = cur()
  local ch = f.journey.chapters[1]
  c:Eq(ch and ch.art, "prologue", "chapter I is the Prologue")
  c:That(ch and ch.floor == 1 and ch.cap == 15, "levels 1-15")
  c:Eq(#ns.Journey:InChapter(f, 1), 0, "no dungeons")
  c:Eq(ns.Pages:ArtOf(f, 1), "prologue", "its own picture")
end)

step("catching up: a newcomer far below the floor does not hold the fellowship", function(c)
  local f, J = cur(), ns.Journey
  -- Past the first real chapter (newcomers there hold it, as friends joining at the start do).
  local saved = f.reached
  if J:CurrentIndex(f) <= 2 then f.reached = 3 end
  local ch = J:Current(f)
  local fen = full("Fenna")
  ns.Dev:Fake("Fenna")
  ns.Fellowship:Do({ k = "invite", name = fen })
  ns.Comm:Inject(fen, "ACC", { fid = f.id, role = "DPS", class = "DRUID", level = 2 })
  c:That(f.members[fen] ~= nil, "Fenna joined at level 2, in chapter " .. ch.n)
  c:That(J:CatchingUp(f, fen), "she is catching up")
  c:That(not has(J:Below(f, ch.n), fen), "she does not hold the dungeons")
  c:That(not has(J:Pacing(f), fen) and has(J:Counted(f), fen), "nor clears and milestones; she still votes")
  local note
  for _, r in ipairs(J:Groups(f, ch.n)[1].rows) do if r.name == fen then note = r.note end end
  c:Has(note, "catching up", "the Chapter page says so")
  dev("hero Fenna level " .. J:FloorLevel(f, f.journey.chapters[ch.n]))
  c:That(not J:CatchingUp(f, fen), "at the floor she counts like everyone")
  ns.Fellowship:Remove(fen)
  f.reached = saved
end)

step("realms: an invite to a realm that is not connected is refused", function(c)
  local list = GetAutoCompleteRealms and GetAutoCompleteRealms()
  report().realms = list
  local name = "Jtfnobody-Jtfnorealm"
  local r = ns.Fellowship:Invite(name)
  if type(list) == "table" then
    c:Eq(r, "realm", ("refused (%d connected realms)"):format(#list))
    c:That(toastSeen(nil, "Only your realm"), "with the reason")
  else
    c:Eq(r, "sent", "no list from the game: allowed")
    ns.Fellowship:CancelInvite(full(name))
  end
end)

step("trial account: the warning bar across the book", function(c)
  ns.Dev.pretendTrial = true
  ns.Window:ShowPage("overview")
  local bar = ns.Window.trialBar
  c:That(bar and bar:IsShown(), "the bar")
  c:Has(bar and bar.line:GetText(), "addon messages", "it says why")
  -- (This account's own answer is in the report: game APIs. A full account is pretended here.)
  ns.Dev.pretendTrial = false
  ns.Window:Refresh()
  c:That(not (bar and bar:IsShown()), "gone for a full account")
  ns.Dev.pretendTrial = nil
  ns.Window:Refresh()
end)

step("pruning: old votes and Gatherings go when the next one comes", function(c)
  local f = cur()
  local before, gBefore = count(f.votes), count(f.gatherings)
  c:That(before > 0, before .. " votes and " .. gBefore .. " Gatherings before")
  -- The next ones are made "11 days later" (the time of the change decides, not this client's clock).
  local later, co = time() + 11 * 86400, full("Corwin")
  ns.Comm:Inject(co, "OP", { fid = f.id, v = f.v + 1, t = later, op = { k = "vote", a = "propose", id = co .. "-prune",
    key = "awayDays", value = f.rules.awayDays == 7 and 14 or 7 } })
  c:Eq(count(f.votes), 1, "only the new vote")
  ns.Comm:Inject(co, "OP", { fid = f.id, v = f.v + 1, t = later, op = { k = "gather", a = "new", id = co .. "-prune",
    text = "Selftest", at = later + 3600 } })
  c:Eq(count(f.gatherings), 1, "only the new Gathering")
end)

---------------------------------------------------------------------------
-- Sync with pretend Adventurers who keep a copy of their own (Dev/Peers.lua): what otherwise needs two accounts.
-- Each action step is followed by its check, after the answers came. Last, as they replace the fellowship's copy
-- (a restore puts the original back).
---------------------------------------------------------------------------
local function PE() return ns.Peers end

-- The fingerprint is larger than the game's %d allows (/jtf debug sync stopped with "integer overflow"; 28 Oct 2026).
step("sync: the sync line prints (a large fingerprint)", function(c)
  local d = ns.Sync:Digest(cur())
  c:That(type(d) == "number", "the fingerprint " .. ("%.0f"):format(d))
  ns.Dev:SyncInfo()
  c:That(true, "/jtf debug sync printed")
end)

step("sync: offline at a change, caught up at the next login", function(c)
  PE():Take("Brannic", cur())
  PE():SetOnline("Brannic", false)
  ns.Fellowship:Rename("Selftest Synced")
  c:Eq(PE():Get("Brannic").copy.name, "Selftest", "Brannic, offline, did not get it")
  PE():SetOnline("Brannic", true)
  PE():Hello("Brannic")
end, 1)

step("sync: offline at a change, caught up at the next login (checked)", function(c)
  local f, p = cur(), PE():Get("Brannic")
  c:Eq(p.copy.name, "Selftest Synced", "Brannic's copy has it")
  c:Eq(ns.Sync:Digest(p.copy), ns.Sync:Digest(f), "the same fellowship on both")
  ns.Fellowship:Rename("Selftest")
end)

step("sync: changes made apart (you lead): both kept", function(c)
  PE():SetOnline("Brannic", false)
  ns.Fellowship:SetRoles(ns.Me(), "Healer")
  PE():Change("Brannic", { k = "role", name = full("Brannic"), role = "Tank", second = "" })
  c:Eq(PE():Get("Brannic").copy.v, cur().v, "the same version, different changes")
  PE():SetOnline("Brannic", true)
  PE():Hello("Brannic")
end, 1)

step("sync: changes made apart (you lead): both kept (checked)", function(c)
  local f, p = cur(), PE():Get("Brannic")
  c:Eq(f.members[ns.Me()].role, "Healer", "your change")
  c:Eq(f.members[full("Brannic")].role, "Tank", "Brannic's, made again on top of your copy")
  c:Eq(p.copy.members[ns.Me()].role, "Healer", "Brannic has yours")
  c:Eq(ns.Sync:Digest(p.copy), ns.Sync:Digest(f), "the same fellowship on both")
end)

step("sync: changes made apart (Brannic leads): both kept", function(c)
  ns.Fellowship:MakeLeader(full("Brannic"))
  c:Eq(PE():Get("Brannic").copy.leader, full("Brannic"), "his copy knows")
  PE():SetOnline("Brannic", false)
  ns.Fellowship:SetRoles(ns.Me(), "Tank")
  PE():Change("Brannic", { k = "role", name = full("Brannic"), role = "DPS", second = "" })
  PE():SetOnline("Brannic", true)
  PE():Hello("Brannic")
end, 1)

step("sync: changes made apart (Brannic leads): both kept (checked)", function(c)
  local f, p = cur(), PE():Get("Brannic")
  c:Eq(f.members[full("Brannic")].role, "DPS", "his copy won")
  c:Eq(f.members[ns.Me()].role, "Tank", "yours, made again on top")
  c:Eq(p.copy.members[ns.Me()].role, "Tank", "and passed on to him")
  c:Eq(ns.Sync:Digest(p.copy), ns.Sync:Digest(f), "the same fellowship on both")
  PE():Change("Brannic", { k = "lead", name = ns.Me() })
end, 0.8)

step("sync: a change lost while online arrives with the next state", function(c)
  local f = cur()
  c:Eq(f.leader, ns.Me(), "you lead again")
  ns.Sync.compared:Reset(full("Brannic"))
  PE():Change("Brannic", { k = "away", name = full("Brannic"), on = true }, true)
  c:Eq(ns.Journey:Away(f, full("Brannic")), nil, "lost: not here")
  PE():State("Brannic")
end, 1)

step("sync: a change lost while online arrives with the next state (checked)", function(c)
  c:Eq(ns.Journey:Away(cur(), full("Brannic")), "self", "the copy was asked for: Brannic is away")
  PE():Change("Brannic", { k = "away", name = full("Brannic"), on = false })
end, 0.8)

-- One truth (2 Nov 2026): both online, a change each lost on the way, at the same version: the next state finds it.
step("sync: a change each lost while both online: the next state makes them one", function(c)
  local b = full("Brannic")
  PE():SetOnline("Brannic", false)
  ns.Fellowship:SetRoles(ns.Me(), "Healer")
  PE():SetOnline("Brannic", true)
  PE():Change("Brannic", { k = "role", name = b, role = "Tank", second = "" }, true)
  c:Eq(PE():Get("Brannic").copy.v, cur().v, "the same version, different changes")
  ns.Sync.compared:Reset(b)
  PE():State("Brannic")
end, ns.Sync.GRACE + 1.5)

step("sync: a change each lost while both online: the next state makes them one (checked)", function(c)
  local f, p = cur(), PE():Get("Brannic")
  c:Eq(f.members[ns.Me()].role, "Healer", "your change")
  c:Eq(f.members[full("Brannic")].role, "Tank", "and Brannic's")
  c:Eq(ns.Sync:Digest(p.copy), ns.Sync:Digest(f), "the same fellowship on both")
end, 0.8)

-- Brannic took over in his own copy while you led elsewhere (you renamed): his copy wins on both sides, and your
-- rename, made while you still led, is kept (rights at the time).
step("sync: a takeover while you led elsewhere: one leader, your change kept", function(c)
  local b, p = full("Brannic"), PE():Get("Brannic")
  PE():SetOnline("Brannic", false)
  ns.Fellowship:Rename("Selftest Led")
  -- As Brannic's addon saw it: you not seen for 30 days, the Adventurers who joined before him away.
  local aw = {}
  for name in pairs(p.copy.members) do if name ~= b and name ~= ns.Me() then aw[name] = true end end
  p.copy.rules.takeoverNever = false
  c:That(PE():Change("Brannic", { k = "takeover", seen = time() - 30 * 86400, aw = aw }), "Brannic takes over in his copy")
  c:Eq(p.copy.leader, b, "his copy: he leads")
  PE():SetOnline("Brannic", true)
  PE():Hello("Brannic")
end, 1)

step("sync: a takeover while you led elsewhere: one leader, your change kept (checked)", function(c)
  local f, p = cur(), PE():Get("Brannic")
  c:Eq(f.leader, full("Brannic"), "Brannic leads in your copy too")
  c:Eq(f.name, "Selftest Led", "your rename, made while you led, is kept")
  c:Eq(p.copy.name, "Selftest Led", "and Brannic has it")
  c:Eq(ns.Sync:Digest(p.copy), ns.Sync:Digest(f), "the same fellowship on both")
  PE():Change("Brannic", { k = "lead", name = ns.Me() })
end, 0.8)

step("sync: the leadership back; the name again", function(c)
  c:Eq(cur().leader, ns.Me(), "you lead again")
  ns.Fellowship:Rename("Selftest")
end, 0.8)

-- Passed on (RELAY, RELAYQ): another Adventurer's firsts, tallies and quests reach those who never meet them.
step("sync: firsts, tallies, quests and tournament minutes are passed on", function(c)
  local f, e = cur(), full("Elyra")
  local h = f.heroes[e] or {}
  f.heroes[e] = h
  local keep = { h.deeds, h.tally, h.quests, h.questsTime, h.seq, h.ton }
  h.deeds, h.tally, h.seq = { mount = time() - 60 }, { falls = 2, quests = 30, runs = 7 }, (h.seq or 0) + 1
  h.ton = { id = 5, slot = 1, min = 12 }
  h.quests, h.questsTime = { [783] = { t = "A Threat Within", z = "Elwynn Forest", l = 1, h = 1, g = 1 } }, time()
  local sent, send = {}, ns.Comm.Send
  ns.Comm.Send = function(_, _, tag, data) sent[tag] = data end
  ns.Hero:Relay(f, full("Brannic"), {}, {}, {})
  ns.Comm.Send = send
  local st, q = sent.RELAY and sent.RELAY.h[e], sent.RELAYQ and sent.RELAYQ.q[e]
  c:That(st and st.deeds and st.deeds.mount, "Elyra's first mount goes with her state")
  c:Eq(st and st.tally and st.tally.falls, 2, "and her tallies")
  c:Eq(st and st.tally and st.tally.runs, 7, "her own count of dungeon runs")
  c:Eq(st and st.ton and st.ton.min, 12, "her tournament minutes")
  c:That(q and q.q and q.q[783], "her quests go too")
  -- Her runs count is her own, whatever this copy's History holds.
  local runs
  for _, x in ipairs(ns.Firsts:Tallies(f)) do
    if x.kind == "runs" then for _, y in ipairs(x.all) do if y.name == e then runs = y.n end end end
  end
  c:Eq(runs, 7, "the runs tally shows her count")
  h.deeds, h.tally, h.quests, h.questsTime, h.seq, h.ton = keep[1], keep[2], keep[3], keep[4], keep[5], keep[6]
end)

step("sync: one run seen apart is one History line with everyone in it", function(c)
  local mine = { type = "run", key = "x", time = 1000, last = 1100, names = { full("Elyra") }, cleared = {}, killed = { a = true } }
  ns.Clears:JoinRun(mine, { type = "run", key = "x", time = 900, last = 1500, names = { full("Brannic") }, cleared = {},
    killed = { b = true }, ok = true })
  c:Eq(#mine.names, 2, "both names")
  c:That(mine.killed.a and mine.killed.b, "both kills")
  c:Eq(mine.time, 900, "from the first kill"); c:Eq(mine.last, 1500, "to the last")
  c:That(mine.ok, "counted when either copy counted it")
end)

-- Conflicts (3 Nov 2026): a copy with the same changes but another Ring-bearer opens the report window, once a day.
step("sync: a copy that disagrees about the One Ring opens the report window", function(c)
  local f, Cf, b = cur(), ns.Conflicts, full("Brannic")
  c:Eq(#Cf:Issues(f), 0, "nothing impossible in this copy")
  local copy = ns.Serialize.Decode(ns.Serialize.Encode(f))
  copy.ring = { who = b, t = time(), item = "The One Ring" }
  if f.ring and f.ring.who == b then copy.ring.who = ns.Me() end
  -- (The step can run again: this conflict's once-a-day mark is cleared first.)
  ns.db.conflictSeen = ns.db.conflictSeen or {}
  ns.db.conflictSeen["disagree:" .. f.id .. ":" .. b .. ":ring"] = nil
  local x = Cf:Taking(f, copy, b)
  c:Eq(x and x.parts[1], "ring", "the Ring is named")
  local o = ns.Window.overlays and ns.Window.overlays.conflict
  c:That(o and o:IsShown(), "the report window is open")
  c:Eq(o and o.text:GetText(), Cf:Lead(x), "it says what was found")
  -- The check of 3 Nov 2026, 21:57: a line for each part, with its icon.
  local row = o and o.items[1]
  c:That(row ~= nil and row:IsShown() and (row.text:GetText() or ""):lower() == L.CONFLICT_PART_RING:lower(), "the One Ring on its own line")
  c:Eq(row and ns.UI.icons[row.icon], ns.ICONS.chal_ring, "with the Ring's icon")
  c:Has(o and o.report:GetText(), "- ring (here:", "the report says what each copy holds")
  c:Eq(Cf:Taking(f, copy, b), nil, "not again the same day")
  if x and ns.db.conflicts[1] == x then table.remove(ns.db.conflicts, 1) end
  if o then o:Hide() end
end)

-- The code review of 1.0.0 (4 Nov 2026): a Ring left with a bearer who went before it could pass on, an issue that
-- names several Adventurers, a decline taken in turn.
step("sync: the 1.0 review's fixes (a left Ring, every name, a decline in turn)", function(c)
  local f, Cf = cur(), ns.Conflicts
  local copy = ns.Serialize.Decode(ns.Serialize.Encode(f))
  copy.ring = { who = "Ghost-Nowhere", t = time() }
  c:Eq(Cf:LeftRing(copy), "Ghost-Nowhere", "a Ring that never passed, its bearer gone: the Leader passes it")
  local found = false
  for _, x in ipairs(Cf:Issues(copy)) do if x.part == "ring" then found = true end end
  c:That(not found, "and it is not reported")
  copy.ring.passes = { { from = ns.Me(), to = "Ghost-Nowhere", t = time() } }
  c:Eq(Cf:LeftRing(copy), nil, "one that passed before is a fault")
  c:Eq(Cf.Who({ who = "Ghost-Nowhere", all = { "Ghost-Nowhere", "Wisp-Nowhere" } }), "Ghost, Wisp", "an issue names everyone")
  c:That((tonumber(ns.Sync.DEC_WAIT) or 0) > 0, "a decline: the next in turn waits before taking it")
end)

-- The code review of 0.13.0 (2 Nov 2026): what it left open.
step("sync: a change carries the game's server time", function(c)
  local l, st = ns.db.oplog and ns.db.oplog[cur().id] or {}, nil
  for i = #l, 1, -1 do if l[i].a == ns.Self() then st = l[i].op and l[i].op.st; break end end
  c:That(tonumber(st) ~= nil, "your newest change says when, by the game's clock")
  c:That(st and math.abs(st - GetServerTime()) < 3600, "within the hour")
end)

step("sync: a copy from an addon before 0.13 is never refused by both sides", function(c)
  local S = ns.Sync
  local old = { v = 5, leader = full("Brannic"), holder = full("Elyra") }
  local new = { v = 5, lv = 2, leader = full("Brannic"), holder = ns.Me() }
  c:That(S:Beats(old, new) and not S:Beats(new, old), "its copy wins: its addon takes only its leader's")
  new.holder = full("Brannic")
  c:That(S:Beats(new, old) and not S:Beats(old, new), "unless ours is held by its leader")
end)

step("sync: a vote's pass keeps the tally its maker had", function(c)
  local E = ns.Serialize
  local f = ns.Fellowship:Sanitize(E.Decode(E.Encode(ns.Sync:Copy(cur()))))
  local yes, late = {}, nil
  for name in pairs(f.members) do
    f.members[name].friend, f.members[name].away = nil, nil
    yes[name] = true
    if name ~= ns.Me() then late = name end
  end
  local value = f.rules.minHeroes == 3 and 2 or 3
  f.votes = { st = { id = "st", by = ns.Me(), key = "minHeroes", value = value, t = time(), ends = time() + 600,
    ballots = { [ns.Me()] = true, [late or ns.Me()] = false } } }
  local toast = ns.Toast
  ns.Toast = function() end
  local ok = ns.Votes:Apply(f, { k = "vote", a = "pass", id = "st", bl = yes, aw = {} }, ns.Me(), time())
  ns.Toast = toast
  c:That(ok, "it passes on the tally it carries")
  c:Eq(E.Encode(f.votes.st.ballots), E.Encode(yes), "the copy keeps that tally, not the ballot that came later")
end)

step("sync: a quest log without a time is not given this PC's", function(c)
  local f, name = { members = { [full("Elyra")] = {} }, heroes = {} }, full("Elyra")
  ns.Quests:Store(f, name, { q = { [783] = { t = "A Threat Within", z = "Elwynn Forest", l = 1, h = 0, g = 1 } } })
  c:Eq(f.heroes[name].questsTime, nil, "no time")
  c:That(f.heroes[name].quests[783], "the log is kept")
end)

step("sync: a run line taken from another copy counts once in your runs tally", function(c)
  local f, keep = cur(), ns.char.tally
  ns.char.tally = { fid = f.id, runs = 5 }
  ns.Firsts:RunsSeen(f) -- (the runs this History holds already are counted)
  local e = { type = "run", key = "selftest", time = time() - 60, last = time() - 30, names = { ns.Me() }, cleared = {}, killed = {} }
  table.insert(f.history, 1, e)
  ns.Firsts:CountRuns(f)
  local first = ns.char.tally.runs
  ns.Firsts:CountRuns(f)
  local again = ns.char.tally.runs
  for i, h in ipairs(f.history) do if h == e then table.remove(f.history, i); break end end
  ns.char.tally = keep
  c:Eq(first, 6, "counted")
  c:Eq(again, 6, "once")
end)

step("sync: one limit for both comparisons while online", function(c)
  local lim = ns.Sync.Limiter()
  c:Eq(getmetatable(ns.Clears.compared), getmetatable(ns.Sync.compared), "kills and copies use the same one")
  c:That(lim:Ready("x") and lim:Take("x", "a"), "the first comparison")
  c:That(not lim:Ready("x"), "not again within the minute")
  lim.at.x = GetTime() - 61
  c:That(lim:Ready("x") and not lim:Take("x", "a"), "the same difference waits half an hour")
  lim:Reset("x")
  c:That(lim:Take("x", "a"), "until it is reset")
end)

step("sync: kills compared at login", function(c)
  local f, J = cur(), ns.Journey
  -- A dungeon of the last chapters (nothing in this run touched it), with a boss Brannic killed and we did not hear.
  local key
  for n = #f.journey.chapters, 1, -1 do
    for _, x in ipairs(J:Required(f, n)) do if not key and #ns.Clears:Needed(f, x.key) > 0 then key = x.key end end
  end
  local tok = key and ns.Clears:Needed(f, key)[1]
  c:That(key ~= nil, "a dungeon: " .. tostring(key))
  if not key then return end
  ST.kill = { key = key, tok = tok }
  local p = PE():Get("Brannic")
  p.copy.kills[key] = p.copy.kills[key] or {}
  p.copy.kills[key][full("Brannic")] = { [tok] = time() }
  PE():Hello("Brannic")
end, 1)

step("sync: kills compared at login (checked)", function(c)
  local k, f = ST.kill, cur()
  local mine = k and f.kills[k.key] and f.kills[k.key][full("Brannic")]
  c:That(mine and mine[k.tok], "Brannic's kill reached this copy")
  c:Eq(ns.Clears:Digest(PE():Get("Brannic").copy), ns.Clears:Digest(f), "the same kills on both")
end)

step("sync: a state passed on by another Adventurer is taken only when newer", function(c)
  local f, e = cur(), full("Elyra")
  local was = ns.Hero:Level(f, e)
  local seq = tonumber((ns.Hero:Get(f, e) or {}).seq) or 0
  ns.Comm:Inject(full("Brannic"), "RELAY", { fid = f.id, h = { [e] = { level = was + 1, seq = seq + 5, heard = time(), t = time() } } })
  c:Eq(ns.Hero:Level(f, e), was + 1, "Elyra's newer state, passed on by Brannic")
  ns.Comm:Inject(full("Brannic"), "RELAY", { fid = f.id, h = { [e] = { level = 1, seq = seq + 1, heard = time(), t = time() } } })
  c:Eq(ns.Hero:Level(f, e), was + 1, "an older one is not taken")
  dev("hero Elyra level " .. was)
end)

step("sync: a copy that knew fewer levels keeps the chapter reached", function()
  local f = cur()
  ST.reached = ns.Journey:Reached(f)
  local p = PE():Take("Elyra", f)
  p.copy.reached = 1
  PE():Change("Elyra", { k = "role", name = full("Elyra"), role = "Healer", second = "" }, true)
  PE():Hello("Elyra")
end, 1)

step("sync: a copy that knew fewer levels keeps the chapter reached (checked)", function(c)
  local f = cur()
  c:Eq(f.members[full("Elyra")].role, "Healer", "Elyra's newer copy was taken")
  c:Eq(ns.Journey:Reached(f), ST.reached, "chapter reached kept")
end)

step("sync: removed while away, told at the next login", function(c)
  ns.Dev:Fake("Darrow")
  dev("hero Darrow accept")
  local f = cur()
  c:That(f.members[full("Darrow")] ~= nil, "Darrow joined")
  PE():Take("Darrow", f)
  PE():SetOnline("Darrow", false)
  ns.Fellowship:Remove(full("Darrow"))
  PE():SetOnline("Darrow", true)
  PE():Hello("Darrow")
end, 1)

step("sync: removed while away, told at the next login (checked)", function(c)
  local p = PE():Get("Darrow")
  c:That(p and p.gone, "Darrow's addon got the copy without Darrow")
  PE():Forget("Darrow")
end)

step("sync: a copy nobody asked for is ignored", function(c)
  local f, s = cur(), full("Jtfstranger")
  ns.Dev:Fake("Jtfstranger")
  ns.Comm:Inject(s, "SNAP", { f = { id = "jtf-selftest-stranger", v = 5, name = "Not yours", leader = s,
    members = { [s] = {}, [ns.Me()] = {} }, rules = {}, journey = ns.BuildJourney("classic") } })
  c:Eq(cur() and cur().id, f.id, "still yours")
  c:That(ns.Fellowship:Get("jtf-selftest-stranger") == nil and ns.Sync.restore == nil, "nothing taken, nothing offered")
end)

step("sync: lost saved data, restored at once from an Adventurer", function(c)
  local f = cur()
  PE():Take("Elyra", f)
  ST.lost = f
  ns.db.fellowships[f.id] = nil
  c:Eq(cur(), nil, "the copy is gone (this character still knows its fellowship)")
  PE():State("Elyra")
end, 1.2)

step("sync: lost saved data, restored at once from an Adventurer (checked)", function(c)
  local f, lost = cur(), ST.lost
  c:That(f and f.id == lost.id and f.name == lost.name, "back, from Elyra's copy")
  c:That(toastSeen(nil, lost.name .. " is back"), "the toast")
  -- The steps after this see the fellowship as it was (a copy carries no Adventurers' levels).
  ns.db.fellowships[lost.id] = lost
  ns.char.fellowshipId = lost.id
end)

step("sync: lost all saved data, the book asks first", function()
  local f = cur()
  PE():Take("Elyra", f)
  ST.lost = f
  ns.db.fellowships[f.id] = nil
  ns.char.fellowshipId = nil
  ns.Window:Open()
  PE():State("Elyra")
end, 1.2)

step("sync: lost all saved data, the book asks first (checked)", function(c)
  local W, lost = ns.Window, ST.lost
  c:Eq(cur(), nil, "not taken without asking")
  c:That(toastSeen(nil, "still lists you"), "the toast: your fellowship was found")
  c:That(W.confirm and W.confirm:IsShown(), "the question in the book")
  c:Has(W.confirm and W.confirm.text:GetText(), lost.name, "it names the fellowship")
  local ok = W.confirm and W.confirm.ok:GetScript("OnClick")
  if ok then ok(W.confirm.ok) end
  c:That(cur() and cur().id == lost.id, "Restore brings it back")
  ns.db.fellowships[lost.id] = lost
  ns.char.fellowshipId = lost.id
  W:ShowPage("overview")
end)

---------------------------------------------------------------------------
-- Running
---------------------------------------------------------------------------
function ST:Finish(keep)
  local r = report()
  if self.push then ns.Toasts.Push, self.push = self.push, nil end
  ns.Window:HidePanels()
  dev("pace off"); dev("level off"); dev("group off"); dev("tourney off")
  ns.Dev:WatchForget()
  if ns.Peers then ns.Peers:Forget() end
  ns.Dev.pretendTrial = nil
  if self.lost and not cur() then ns.db.fellowships[self.lost.id] = self.lost; ns.char.fellowshipId = self.lost.id end
  self.lost = nil
  if ns.Walkthrough then ns.Walkthrough:Stop() end
  -- The pretend Heroes go, then you leave: alone, leaving ends the fellowship.
  local f = cur()
  if not keep and f and f.name == "Selftest" then
    -- The session recaps and pictures of the run go with it.
    ns.Moments:Forget(f.id)
    local sessions = ns.Session:List()
    for i = #sessions, 1, -1 do if sessions[i].fid == f.id then table.remove(sessions, i) end end
    ns.Session.cur = nil
    if f.leader ~= ns.Me() then ns.Comm:Inject(full("Brannic"), "OP", { fid = f.id, v = f.v + 1, op = { k = "lead", name = ns.Me() }, t = time() }) end
    for name in pairs(f.members) do if name ~= ns.Me() then ns.Fellowship:Remove(name) end end
    ns.Fellowship:Leave()
  end
  ns.char.setupDone = self.savedSetup
  r.finished = time()
  self.running = false
  ns:Print(L.SELFTEST_DONE:format(r.passed, r.failed), true)
  local done = self.onDone
  self.onDone = nil
  if done then C_Timer.After(1, done) end
end

-- opts.onDone: runs after the self-test has cleaned up (/jtf check goes on with the tour). opts.only (a set of area
-- keys that stand alone, Dev/Areas.lua): only their steps.
function ST:Run(arg, opts)
  if self.running then return end
  if ns.Combat:InCombat() then ns:Print(L.SELFTEST_COMBAT, true) return end
  if cur() then ns:Print(L.SELFTEST_IN_FELLOWSHIP, true) return end
  local keep = arg == "keep"
  self.running = true
  self.onDone = opts and opts.onDone
  local only = opts and opts.only
  -- Not seen, so founding shows the setup guide (checked in "found"); as it was afterwards.
  self.savedSetup = ns.char.setupDone
  ns.char.setupDone = nil
  ns.db.selftest = { started = time(), passed = 0, failed = 0, steps = {}, shots = {}, toasts = {}, env = ST.Env() }
  -- Every toast during the run is noted (kind, title, text, the page a click opens), so the report shows which ones
  -- fired. (The page is passed on: without it, a click on a toast opened nothing during the self-test; so is a clear's
  -- picture and who was there.)
  self.push = ns.Toasts.Push
  ns.Toasts.Push = function(t, kind, title, text, page, more)
    local list = report().toasts
    -- (A page that is a function, such as the share window's, is noted by name: saved data holds no functions.)
    list[#list + 1] = { kind = kind, title = title, text = text, page = type(page) == "function" and "(opens a window)" or page, t = time(),
      solemn = more and more.solemn or nil, icon = more and more.icon or nil, kicker = more and more.kicker or nil,
      framed = more and more.framed or nil, sound = more and more.sound or nil }
    return ST.push(t, kind, title, text, page, more)
  end
  ns:Print(L.SELFTEST_START:format(#steps), true)
  local i = 0
  local nextStep
  -- A step runs as a coroutine, so c:Yield() can spread it over several frames; its longest part is timed (ms in the
  -- report: the check report lists slow steps). (No xpcall inside: the game's Lua cannot yield across it. An error
  -- ends the coroutine, and its stack is read from the coroutine.)
  local function run(s)
    local c = setmetatable({ lines = {} }, Check)
    local slowest = 0
    c.co = coroutine.create(function() s.fn(c) end)
    local function part()
      ns.doing = "self-test: " .. s.name
      local t = debugprofilestop and debugprofilestop()
      local ok, e = coroutine.resume(c.co)
      if t then slowest = math.max(slowest, debugprofilestop() - t) end
      ns.doing = nil
      if not ok then
        local err = tostring(e) .. "\n" .. (debugstack and debugstack(c.co, 1, 10, 0) or "")
        c.bad = true; c.lines[#c.lines + 1] = "ERROR: " .. err; ns:LogError("selftest", s.name, err)
      end
      if coroutine.status(c.co) ~= "dead" then return C_Timer.After(0, part) end
      add(s.name, not c.bad, table.concat(c.lines, "\n"), slowest > 0 and math.floor(slowest + 0.5) or nil)
      if c.stop then return ST:Finish(keep) end
      C_Timer.After(s.wait or ST.WAIT, nextStep)
    end
    part()
  end
  nextStep = function()
    i = i + 1
    local s = steps[i]
    if not s then return ST:Finish(keep) end
    if only and not only[ns.CheckAreas:ForStep(s.name)[1] or ""] then return nextStep() end
    run(s)
  end
  ns.Window:WhenBuilt(nextStep)
end
