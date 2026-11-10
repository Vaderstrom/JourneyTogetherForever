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
  -- The game's own pictures for wings that share a loading screen, and Hyjal Summit (6 Nov 2026). Without one this
  -- client shows the loading screen instead: reported, not a failure.
  local noGuide = {}
  for key, id in pairs(ns.DUNGEON_GUIDE) do if t:SetTexture(id) == false then noGuide[#noGuide + 1] = key end end
  table.sort(noGuide)
  -- Forever's own loading screens (all its dungeons since build 1.60.1.70862): without one, our tile shows.
  local noScreen = {}
  for key, s in pairs(ns.DUNGEON_SCREEN) do
    if s[2] == "forever" and t:SetTexture(s[1]) == false then noScreen[#noScreen + 1] = key end
  end
  table.sort(noScreen)
  if inGame() then
    c:That(true, #noScreen == 0 and "Forever's loading screens load for all its dungeons"
      or ("no loading screen in this client (our tile instead): " .. table.concat(noScreen, ", ")))
    c:That(true, #noGuide == 0 and "the game's own pictures for the Scarlet wings, Upper Blackrock Spire and Hyjal load"
      or ("not in this client (the loading screen instead): " .. table.concat(noGuide, ", ")))
  end
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
-- client's build. A gap fails (run tools/update-game-data.ps1 on the new build).
step("boss data", function(c)
  local _, built = ns.EncounterSet()
  local none = ns.Clears:NoBossData()
  report().noBossData = none
  -- Places Blizzard announced but has not put in the game's files yet (no map ID: the new dungeons and raids, check
  -- of 6 Nov 2026) are a note: there are no bosses to read until they are.
  local gap, later = {}, {}
  for _, key in ipairs(none) do
    if ns.DUNGEON_MAPS[key] then gap[#gap + 1] = key else later[#later + 1] = key end
  end
  c:That(#gap == 0,
    #gap == 0 and "every dungeon and raid in the game has its bosses" or ("no boss data: " .. table.concat(gap, ", ")))
  if #later > 0 then c:That(true, "not in the game's files yet: " .. table.concat(later, ", ")) end
  local version, build = GetBuildInfo()
  local client = tostring(version) .. "." .. tostring(build)
  c:That(built == client, ("boss data from build %s, this client %s"):format(tostring(built), client))
end)

-- The presets plan only with this game's places: in WoW Forever what Blizzard has announced (ns.FOREVER_SCHEDULE),
-- never a place that is only in the game's files (the owner, 4 Nov 2026). Classic has only Classic's own dungeons,
-- Forever its new ones too; Ragefire Chasm is the Horde's, Hall of Thanes the Alliance's (the owner, 6 Nov 2026).
-- A newer version is out (6 Nov 2026): told once a session from the guild or the group, as well as the fellowship.
step("version notice: announced to the guild and group, a newer one told once", function(c)
  local Hr = ns.Hero
  local devCopy = not ns.ParseVersion(ns.VERSION)
  c:That(type(Hr.Announce) == "function" and type(Hr.TellNewer) == "function", "the announcement and the notice are there")
  if devCopy then
    c:That(true, "a development copy (" .. tostring(ns.VERSION) .. ") announces nothing")
  else
    -- (Chat and toasts held back for the check.)
    local told, print, toast = Hr.toldNewer, ns.Print, ns.Toast
    ns.Print, ns.Toast, Hr.toldNewer = function() end, function() end, false
    Hr:TellNewer("Selftest", "999.0.0")
    c:Eq(Hr.toldNewer, false, "a version far ahead is not believed")
    ns.Print, ns.Toast, Hr.toldNewer = print, toast, told
  end
  c:That(not ns.NewerVersion("1.0.4", "1.0.5") and ns.NewerVersion("1.1.0", "1.0.9"), "versions compare by number")
end)

step("the presets: only places this game offers; Classic's own in Classic; each faction's own", function(c)
  local stray, n = {}, 0
  for _, preset in ipairs(ns.PRESET_ORDER) do
    for key in pairs(ns.BuildJourney(preset).place) do
      n = n + 1
      if not ns.InGame(key) then stray[#stray + 1] = preset .. ": " .. key end
    end
  end
  table.sort(stray)
  c:That(#stray == 0, #stray == 0 and (n .. " places in " .. #ns.PRESET_ORDER .. " presets, all in this game")
    or ("not in this game: " .. table.concat(stray, ", ")))
  local classic, own, must = ns.BuildJourney("classic"), {}, {}
  for key, p in pairs(classic.place) do
    if ns.FOREVER_OWN[ns.BaseKey(key)] then own[#own + 1] = key end
    if p.role == "m" then must[p.ch] = true end
  end
  c:That(#own == 0, #own == 0 and "Classic: none of Forever's new dungeons" or ("Classic has " .. table.concat(own, ", ")))
  local empty = {}
  for i = 2, #classic.chapters do if not must[i] then empty[#empty + 1] = classic.chapters[i].name end end
  c:That(#empty == 0, #empty == 0 and ("Classic: " .. (#classic.chapters - 1) .. " chapters, each with a dungeon to clear")
    or ("Classic chapters with nothing to clear: " .. table.concat(empty, ", ")))
  c:Eq(#ns.BuildJourney("forever").chapters, 15, "Forever: the Prologue and 14 chapters")
  local faction = UnitFactionGroup("player")
  local mine, theirs = faction == "Horde" and "rfc" or "hot", faction == "Horde" and "hot" or "rfc"
  local fj = ns.BuildJourney("forever")
  c:That(not fj.place[theirs] and (fj.place[mine] or not ns.InGame(mine)),
    ("%s: %s, not %s"):format(tostring(faction), ns.Dungeon(mine) and ns.Dungeon(mine)[2] or mine, theirs))
  if fj.place[mine] then c:Eq(fj.place[mine].role, "m", "and mandatory") end
  local both = {}
  for k in pairs(ns.DUNGEON_FACTION) do both[#both + 1] = k end
  table.sort(both)
  c:Eq(table.concat(both, ","), "hot,rfc", "no other dungeon depends on the faction")
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
  -- (Settings shows outside a fellowship too: a book closed on it opened on Settings; check of 8 Nov 2026, after /jtf brand.)
  W.page, W.startView = "overview", "create"
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
  c:Eq(#pf.presets, 5, "five journeys: Forever, Classic, Short, Long and Your own")
  c:Eq(ns.Rules.Suggest("party")[2], "forever", "a party is offered the Forever journey")
  if inGame() then
    local last = pf.presets[#pf.presets]
    c:That(last:GetBottom() >= pf.prev:GetTop() - 1, "the five tiles end above Back")
    -- Each tile's title inside the tile, its text on one line (check of 6 Nov 2026: Your own journey's text took two
    -- lines and pushed its title off the tile, over a bright picture).
    for _, t in ipairs(pf.presets) do
      c:That(t.title:GetTop() <= t:GetTop() + 0.5, t.key .. ": the title inside the tile")
      c:That(t.text:GetStringHeight() < 2 * (select(2, t.text:GetFont()) or 13), t.key .. ": the text on one line")
    end
    local r = select(1, last.pic:GetVertexColor())
    c:That(r and r < 0.7, "Your own journey's bright picture dimmed")
  end
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
-- The right page's row for a chosen challenge (U114), and its hover text ("" when it has none).
local function chosenItem(pf, key)
  for _, it in ipairs(pf.chalItems.items) do if it:IsShown() and it.key == key then return it end end
end
local function chosenTip(pf, key) local it = chosenItem(pf, key) return it and it.tip or "" end
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
  c:That(pf.peek:IsShown() and pf.chalList:GetAlpha() == 0, "hovering a challenge: its rule on the right page")
  c:Eq(pf.peek.name:GetText(), L.CHAL_RING, "its name")
  c:Has(pf.peek.rule:GetText(), L.CHAL_RING_RULE, "and its whole rule")
  c:Eq(pf.peek.group:GetText(), L.CHAL_GROUP_STORY:upper(), "under its banner's name")
  -- U45: what you have chosen stays in view under it.
  c:That(pf.peek.chosen:IsShown(), "your choices stay in view")
  c:Eq(pf.peek.chosen:GetText(), L.CHAL_CHOSEN:format(ns.Challenges:Line(C:Challenges()) or ""), "Chosen: and what you chose")
  c:That(not GameTooltip:IsShown(), "no tooltip over the page")
  if inGame() then c:That(pf.peek.rule:GetBottom() > pf.next:GetTop(), "the rule stays above Next") end
  ring:GetScript("OnLeave")(ring)
  c:That(not pf.peek:IsShown() and pf.chalList:GetAlpha() == 1, "and back to what you take on")
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
  -- U114: each chosen challenge one row on the right page, its icon and name; the rule on hover, not a wall of text.
  local nItems, iconsOk = 0, true
  for _, it in ipairs(pf.chalItems.items) do
    if it:IsShown() then
      nItems = nItems + 1
      if not it.icon:GetTexture() then iconsOk = false end
    end
  end
  local nChosen = 0
  for _ in pairs(C:Challenges() or {}) do nChosen = nChosen + 1 end
  c:Eq(nItems, nChosen, "one row for each challenge chosen (U114)")
  c:That(iconsOk, "each with its icon")
  c:That(not pf.chalText:IsShown(), "no rules as running text")
  c:Has(chosenTip(pf, "hardcore"), L.CHAL_HARDCORE_RULE, "what Hardcore Fellowship means, on its row's hover")
  c:That(pf.pvp:IsShown(), "Hardcore Fellowship asks whether it's a PvP realm")
  click(pf.pvp)
  c:Eq(C:Challenges() and C:Challenges().hardcore, "pvp", "on a PvP realm")
  c:Eq(row("hardcore").name:GetText(), L.CHAL_HARDCORE_PVP, "the row is called Hardcore PvP Fellowship")
  c:Eq(chosenItem(pf, "hardcore") and chosenItem(pf, "hardcore").name:GetText(), L.CHAL_HARDCORE_PVP, "and so is its row on the right")
  c:Has(chosenTip(pf, "hardcore"), L.CHAL_HARDCORE_PVP_RULE, "and any death counts, also one to another player")
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
-- heals. Gear, Gold & More holds all eight with the most it can ask. Fellowship-crafted (X7) never goes with Ironman.
step("challenges: Story and Gear banners, Ironman takes two with it, Pauper's gold", function(c)
  local W, C, Ch = ns.Window, ns.CreateState, ns.Challenges
  local pf = W.pageFrames.create
  local row = function(key) return chalRow(pf, key) end
  click(row("ring")); click(row("walk"))
  c:That(row("ring").chosen and row("walk").chosen and row("hardcore").chosen, "they combine across the banners")
  c:Has(chosenTip(pf, "ring"), L.CHAL_RING_RULE, "the Ring's rule on its row's hover")
  c:That(not chosenTip(pf, "ring"):find(L.CHAL_RING_PASS_RULE, 1, true), "without how it passes on (the rulebook says that)")
  c:Has(chosenItem(pf, "walk") and chosenItem(pf, "walk").name:GetText(), L.CHAL_WALK, "Walk everywhere has its row")
  click(row("ironman"))
  c:That(row("white").chosen, "Ironman Fellowship takes White gear only with it")
  c:Eq(row("white").sub:GetText(), L.CHAL_WITH_IRONMAN, "and says so")
  c:Eq(row("white").tipNote, L.CHAL_INCLUDED, "and the right page too, when it is hovered")
  row("white"):GetScript("OnEnter")(row("white"))
  c:Eq(pf.peek.note:IsShown() and pf.peek.note:GetText(), L.CHAL_INCLUDED, "hovered: why it is greyed, on the right page")
  row("white"):GetScript("OnLeave")(row("white"))
  click(row("white"))
  c:That(row("white").chosen, "it can't be taken off while Ironman is chosen")
  click(row("crafted"))
  c:That(not row("crafted").chosen, "Fellowship-crafted can't go with Ironman Fellowship (no professions)")
  c:Eq(row("crafted").sub:GetText(), L.CHAL_NOT_WITH:format(L.CHAL_IRONMAN), "the row says why")
  c:Eq(row("crafted").tipNote, L.CHAL_APART, "and the right page, hovered")
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
  c:Has(chosenItem(pf, "pauper") and chosenItem(pf, "pauper").name:GetText(), L.CHAL_PAUPER_N:format(15), "Pauper (15 gold) on its row")
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
  if inGame() then c:That(onCloth(pf.banners[3]), "Gear, Gold & More holds all eight on its cloth, with all they ask") end
  C.role = role; W:Refresh()
  click(row("nohealers"))
  c:That(row("nohealers").chosen, "another role: it can")
  c:Has(pf.chalNote:GetText(), L.CHAL_NOTE_HELD, "the right page: those two are held at the door")
  click(row("ironman")); click(row("crafted"))
  c:That(row("crafted").chosen and not row("ironman").chosen, "Ironman off: Fellowship-crafted can be chosen")
  c:Has(chosenTip(pf, "crafted"), L.CHAL_CRAFTED_RULE, "its rule on its row's hover")
  click(row("ironman"))
  c:That(not row("ironman").chosen, "and then Ironman Fellowship can't")
  c:Eq(row("ironman").sub:GetText(), L.CHAL_NOT_WITH:format(L.CHAL_CRAFTED), "and says why")
  if inGame() then
    for i = 1, 3 do c:That(onCloth(pf.banners[i]), L["CHAL_GROUP_" .. Ch.GROUPS[i].key:upper()] .. ": every row on the cloth") end
    c:That(pf.chalLater:GetBottom() > pf.next:GetTop(), "the right page holds them all, above Next")
  end
  -- The most at once (all but Ironman Fellowship, 13): the rows close up and still end above Next (review of U114).
  for _, k in ipairs(Ch.LIST) do if k ~= "ironman" and not row(k).chosen then click(row(k)) end end
  local most = 0
  for _, it in ipairs(pf.chalItems.items) do if it:IsShown() then most = most + 1 end end
  c:Eq(most, #Ch.LIST - 1, "a row for each of the 13")
  c:Eq(math.floor(pf.chalItems.items[1]:GetHeight() + 0.5), 22, "closer together")
  if inGame() then c:That(pf.chalLater:GetBottom() > pf.next:GetTop(), "all 13 and the notes above Next") end
  for _, k in ipairs({ "hardcore", "shared" }) do if not row(k).chosen then click(row(k)) end end
  for _, k in ipairs({ "questless", "race", "fellowfound", "white", "dungeons" }) do C.challenges[k] = nil end
  -- (Back to what the next steps expect: Survival's two, and nothing else.)
  for _, k in ipairs({ "ring", "walk", "ironman", "crafted", "pauper", "oneclass", "nohealers" }) do C.challenges[k] = nil end
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

-- U67 (7 Nov 2026): Your characters only as tall as the list, How a journey works right under it, to the page's foot.
step("welcome: How a journey works right under Your characters", function(c)
  local W = ns.Window
  W.startView = "welcome"; W:Refresh()
  local wp = W.pageFrames.welcome
  local _, rel = wp.how:GetPoint()
  c:That(rel == wp.scroll, "How sits right under the list")
  if inGame() then c:That(math.abs(wp.how:GetBottom() - wp.right:GetBottom()) < 4, "and reaches the page's foot") end
end)

step("found the Selftest fellowship", function(c)
  -- The Welcome page's two ways in are picture tiles (like the Adventure Guide).
  local wp = ns.Window.pageFrames.welcome
  c:That(wp and wp.found and wp.found.pic and wp.join and wp.join.pic, "Welcome: Found and Join as picture tiles")
  local f = ns.Fellowship:Create({ name = "Selftest", role = "Tank", preset = "forever" })
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
  -- Where the tracker sits, under its mode (its own panel by default since 8 Nov 2026); the five rows fit.
  local docked = ns.Settings:Get("trackerDock") == true
  c:Eq(pf.dock.buttons[2].on, docked, "where the tracker sits: " .. (docked and "under the game's quest tracker" or "its own panel"))
  if inGame() then
    local low, floor = pf.sounds:GetBottom(), pf.body[2]:GetBottom()
    c:That(low and floor and low >= floor - 1, ("step 2 fits above the footer (%s >= %s)"):format(tostring(low), tostring(floor)))
  end
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
  -- They head the To do (U140); Focus now names the first open one (U139).
  local todo = ns.Together:ToDo(f, ns.Journey:CurrentIndex(f))
  c:Eq(todo[1] and todo[1].kind, "start", "the first steps head the To do")
  c:Eq(ns.Together:Focus(f).head, L.START_INVITE, "Focus now: the first open step")
  for _, p in ipairs({ "rules", "chapter", "admin" }) do ns.Window:ShowPage(p) end
  list = ns.Together:Started(f)
  local open = 0
  for _, s in ipairs(list or {}) do if not s.done then open = open + 1 end end
  c:Eq(open, 1, "only Invite Heroes is left")
  ns.Window:ShowPage("overview")
  c:Eq(ns.Window.pageFrames.overview.focus.what:GetText(), L.START_INVITE, "on the Overview")
  -- Each step fits Focus now's two-line headline (the check of 10 Nov 2026 cut the bosses' step).
  local what = ns.Window.pageFrames.overview.focus.what
  for _, s in ipairs(list or {}) do
    what:SetText(s.text)
    c:That(not (what.IsTruncated and what:IsTruncated()), "whole in Focus now: " .. s.text)
  end
  ns.Window:Refresh()
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

step("levels: below the floor, Focus now says how far (catch-up)", function(c)
  -- Everyone past the Prologue (levels 1-15), then you fall back below the floor of Chapter II (15-21).
  for _, n in ipairs(PRETEND) do dev("hero " .. n .. " level 15") end
  dev("level 16")
  c:That(ns.Journey:CurrentIndex(cur()) >= 2, "the Prologue is done")
  dev("pace 1200")
  dev("level 13")
  local f = cur()
  c:Has(ns.Together:You(f).head, "13", "your standing (the tracker)")
  local fl = ns.Journey:FloorLevel(f, ns.Journey:Current(f))
  local fo = ns.Together:Focus(f)
  c:Eq(fo.head, L.FOCUS_FLOOR:format(fl), "Focus now: reach the floor")
  c:Has(fo.why, "at your pace", "an estimate")
  -- One more below the floor: named as in the same spot.
  local corwin = ns.Hero:Get(f, full("Corwin"))
  if corwin then
    local was = corwin.level
    corwin.level = 13
    local why = ns.Together:Focus(f).why
    corwin.level = was
    c:Has(why, L.FOCUS_SAME_SPOT:format("Corwin"), "and who is in the same spot")
  end
  local floorItem
  for _, it in ipairs(ns.Together:ToDo(f, ns.Journey:CurrentIndex(f))) do if it.kind == "floor" then floorItem = it end end
  c:That(floorItem ~= nil and not floorItem.done, "the To do: reach the floor, not done")
end)

shot("overview, catch-up", function() ns.Window:ShowPage("overview") end)

-- U139: everything on the Overview in view, no scrolling: each panel's last line above its link, Where we stand's last
-- line above the panels. (In the game only: the unit-test harness places every frame at 100, 100.)
local function overviewFits(c, where)
  local pf = ns.Window.pageFrames.overview
  local function above(r, limit, what)
    local b = r:GetBottom()
    c:That(b and limit and b >= limit - 1, ("%s: %s ends above its foot (%s >= %s)"):format(where, what, tostring(b), tostring(limit)))
  end
  local fo, si, co, st = pf.focus, pf.since, pf.coming, pf.stand
  above(fo.btn:IsShown() and fo.btn or fo.why, fo.link:GetTop(), "Focus now")
  local last = si.none
  for _, r in ipairs(si.rows) do if r:IsShown() then last = r end end
  above(last, si.link:GetTop(), "Since last time")
  above(co.nextCh, co.link:GetTop(), "Coming up")
  -- A later dungeon's picture in its own frame, not behind the words (the owner's check of 9 Nov 2026).
  local p, pfr = co.prep.pic, co.prep.frame
  c:That(p:GetParent() == pfr, where .. ": Coming up's picture belongs to its frame")
  local pr, fr = p:GetRight(), pfr:GetRight()
  c:That(not (co.prep:IsShown() and pr and fr) or pr <= fr + 0.5, ("%s: Coming up's picture stays in its frame (%s <= %s)"):format(where, tostring(pr), tostring(fr)))
  local low = st.room:IsShown() and st.room or st.line
  above(low, st:GetBottom(), "Where we stand")
  -- U149: the shared lives on the banner's picture, above its strip of paper.
  if st.lives:IsShown() then
    above(st.lives, pf.pic:GetBottom(), "the shared lives on the picture")
    local lb, tt = st.lives:GetBottom(), pf.pic.title:GetTop()
    c:That(lb and tt and lb >= tt - 1, ("%s: the shared lives clear of the chapter's name (%s >= %s)"):format(where,
      tostring(lb), tostring(tt)))
  end
end

step("level track: where you stand and where the Adventurers stand", function(c)
  local pf = ns.Window.pageFrames.overview
  local s = pf.stand
  local markers = 0
  for _, d in ipairs(s.track.markers.items) do if d:IsShown() then markers = markers + 1 end end
  c:That(s.track:IsShown() and markers >= 1, "Where we stand: the level track with its markers")
  c:Has(s.line:GetText(), L.WS_BELOW_YOU, "one line: you are below the floor")
  c:That(s.who:IsShown(), "Who stands where, a link to the Chapter page")
  -- U139: one large headline and at most one button in Focus now.
  c:That(select(2, pf.focus.what:GetFont()) >= 20, "Focus now: the headline is large")
  c:That(pf.lscroll == nil and pf.rscroll == nil, "nothing to scroll")
  if inGame() then overviewFits(c, "the Overview") end
end)

-- U148-U155 (the owner's picks after the checks of 9 Nov 2026): the chapter's banner with Where we stand along its
-- foot, three cards each on its own picture, the class faces on the track, the gentle open.
step("overview look: the banner, three cards on their pictures, faces and the open", function(c)
  local W = ns.Window
  W:ShowPage("overview")
  local pf = W.pageFrames.overview
  c:That(pf.pic:GetParent() == pf.banner and pf.stand:GetParent() == pf.banner, "the chapter's banner, Where we stand along its foot")
  c:That(pf.focus.art:GetTexture() ~= nil, "Focus now: a picture behind it")
  c:That(select(2, pf.focus.what:GetFont()) >= 24, "its headline large")
  if pf.focus.btn:IsShown() then c:Eq(math.floor(pf.focus.btn:GetHeight() + 0.5), 34, "its button larger") end
  -- U155 (the check of 9 Nov 2026, 22:42: the torn parchment hid the headings): each card on its own picture, its
  -- heading in light words.
  local P = ns.Theme:Horde() and ns.Pages.ART_HORDE or ns.Pages.ART
  c:Eq(pf.since.artFile, P.board[1], "Since last time on the Chronicle's notice board")
  c:Eq(pf.coming.artFile, P.land[1], "Coming up on the road ahead")
  c:That(pf.since.art:GetTexture() ~= nil and pf.coming.art:GetTexture() ~= nil, "both pictures found")
  for _, p in ipairs({ pf.focus, pf.since, pf.coming }) do
    local r, g, b = p.head:GetTextColor()
    c:That(r + g + b > 2, p.head:GetText() .. ": its heading light on the picture")
  end
  -- U158: Where we stand on the banner's dark foot, its words light; U162: the title alone, no subtitle.
  local sr, sg, sb = pf.stand.line:GetTextColor()
  c:That(sr + sg + sb > 2, "Where we stand: its line light on the dark foot")
  local mr, mg, mb = pf.stand.track.more:GetTextColor()
  c:That(mr + mg + mb > 2, "the level track drawn for a dark ground")
  c:Eq(W.frame.book.sub:GetText() or "", "", "no subtitle under Overview")
  if inGame() then
    local faces = 0
    for _, d in ipairs(pf.stand.track.markers.items) do if d:IsShown() and d.face:IsShown() then faces = faces + 1 end end
    c:That(faces >= 1, "class faces on the level track")
    -- Opening the page plays the fade (not with Reduce effects); the picture drifts while it is shown.
    local still = ns.Settings:Get("reduce")
    W:ShowPage("chapter"); pf.openedAt = nil; W:ShowPage("overview")
    c:That((pf.openedAt ~= nil) == not still, still and "Reduce effects: no fade" or "the panels fade in as it opens")
    c:That(pf.drift:IsPlaying() == not still, still and "Reduce effects: the picture is still" or "the banner's picture drifts")
    -- It drifts by the part of the image it shows, so no edge is ever bare (check of 10 Nov 2026: black on its left).
    local l, _, _, _, r = pf.pic.art:GetTexCoord()
    c:That(l >= 0 and r <= 1 and r > l, ("the drifting picture inside its image (%.3f to %.3f)"):format(l, r))
    c:That(math.abs(pf.pic.art:GetLeft() - pf.banner:GetLeft() - ns.UI.PIC_INSET) < 1, "the picture itself stays in place")
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
  local f = cur()
  local p = ns.Together:PlayNow(f)
  if p and p.kind == "help" then
    c:Eq(ns.Together:Focus(f).head, L.FOCUS_HELP:format(ns.Short(p.who)), "Focus now: help them to the floor")
  else
    c:Has(ns.Together:Focus(f).why, "Corwin", "Focus now names Corwin, below the floor")
  end
  dev("hero Corwin level 15")
end)

-- M25: you pull ahead (the level up to 18 above did it), and Play now with the pretend Adventurers online.
step("keep in step: you pull ahead; Play now", function(c)
  local f = cur()
  local who, gap = ns.Progress:Ahead(f)
  c:That(who ~= nil and (gap or 0) >= ns.Progress.AHEAD, ("ahead of %s by %s levels"):format(tostring(who), tostring(gap)))
  c:That(toastSeen("ahead", nil), "a toast when you pulled ahead")
  local p = ns.Together:PlayNow(f)
  c:That(p ~= nil and p.text ~= nil, "Play now: " .. tostring(p and p.text))
  -- Play now's pick is Focus now's (U139): one button on the Overview.
  ns.Window:ShowPage("overview")
  local fo = ns.Window.pageFrames.overview.focus
  c:Eq(fo.what:GetText(), ns.Together:Focus(f).head, "Focus now on the Overview")
  c:That(fo.btn:IsShown(), "with its button")
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
    -- U44: an item's own picture where it has one (a file in Media), else its dungeon's.
    local probe = o.box:CreateTexture()
    c:That(N.Art(probe, { art = N.BIG.art }, 100, 100, 1) == false, "without its own picture: the dungeon's")
    c:That(N.Art(probe, { art = N.BIG.art, pic = "Logo" }, 100, 100, 1) == true, "with one: its own (here the logo file)")
    probe:Hide()
    for _, item in ipairs({ N.BIG, N.CARDS[1], N.CARDS[2] }) do
      if item.pic then c:That(probe:SetTexture(ns.MEDIA .. item.pic) ~= false, "this news' picture is in Media: " .. item.pic) end
    end
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

step("since last time on the Overview", function(c)
  ns.Since:Mark()
  dev("hero Elyra level 17")
  local d = ns.Since:Digest(cur())
  c:That(d ~= nil and #d.levels == 1, "Elyra levelled")
  ns.Window:ShowPage("overview")
  local si = ns.Window.pageFrames.overview.since
  local found
  for _, r in ipairs(si.rows) do
    if r:IsShown() and (r.text:GetText() or ""):find(L.SINCE_REACHED:format("Elyra", 17), 1, true) then found = true end
  end
  c:That(found, "Since last time: Elyra reached level 17")
  -- U151: each line with its kind's icon (the Chronicle's book on every line said nothing).
  for _, r in ipairs(si.rows) do
    if r:IsShown() and (r.text:GetText() or ""):find(L.SINCE_REACHED:format("Elyra", 17), 1, true) then
      c:Eq(ns.UI.icons[r.icon], ns.ICONS.since_level, "a level gained: its own icon")
    end
  end
  c:That(not si.none:IsShown(), "not the empty line")
  click(si.link)
  c:Eq(ns.Window.current, "chronicle", "its link opens the Chronicle")
  ns.Window:ShowPage("overview")
end)

shot("since last time")

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
    c:Has(last and last.roleText or "", L.ROLE_BRIDGE, "the next chapter's bridge is listed: " .. bridges[1].d[2])
    c:Eq(last and last.borderRole, J.ROLE_COLOR.b[1], "in the bridge colour")
  end
  -- A row opens the Dungeon page, which has the Dungeon Journal (U96); the stage track shows the chapter's stages.
  c:That(pf.rows.items[1]:GetScript("OnMouseUp") ~= nil and pf.rows.items[1].dj == nil, "a row opens the Dungeon page")
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

-- 7 Nov 2026 (the owner): the mandatory dungeons first, lowest levels first; the first not cleared is recommended next.
step("chapter page: the mandatory dungeons first, the next one recommended", function(c)
  local f, J = cur(), ns.Journey
  local n
  for i = 1, #f.journey.chapters do
    local m = 0
    for _, x in ipairs(J:InChapter(f, i)) do if x.role == "m" then m = m + 1 end end
    if m >= 2 and not n then n = i end
  end
  if not n then return c:That(true, "no chapter with two mandatory dungeons in this journey") end
  local list, others, ok = J:ChapterList(f, n), false, true
  for _, x in ipairs(list) do
    if x.role == "m" and not x.early then ok = ok and not others else others = true end
  end
  c:That(ok, ("chapter %d lists its mandatory dungeons first"):format(n))
  local key = J:NextDungeon(f, n, list)
  c:That(true, key and ("recommended next: %s"):format(ns.Dungeon(key)[2]) or "all its mandatory dungeons are cleared")
  local pf = ns.Window.pageFrames.chapter
  pf.sel = n; ns.Window:ShowPage("chapter")
  if key then
    local shown
    for _, r in ipairs(pf.rows.items) do if r:IsShown() and r.key == key then shown = r end end
    c:Has(shown and shown.sub:GetText() or "", L.CH_ROW_NEXT, "its row says Recommended next")
  end
  pf.sel = nil
end)

-- The check of 7 Nov 2026: "Bridge · Chapter III · …" was cut beside the quests' map button.
step("chapter page: each dungeon row's line fits beside its buttons, in every chapter", function(c)
  local f, W, cut = cur(), ns.Window, {}
  local pf = W.pageFrames.chapter
  W:ShowPage("chapter")
  for n = 1, #f.journey.chapters do
    pf.sel = n; W:Refresh()
    for _, r in ipairs(pf.rows.items) do
      if r:IsShown() and r.sub:GetStringWidth() > r.sub:GetWidth() + 1 then
        cut[#cut + 1] = ("%d %s"):format(n, r.name:GetText() or "?")
      end
    end
  end
  pf.sel = nil; W:Refresh()
  c:Eq(#cut, 0, #cut > 0 and ("cut: " .. table.concat(cut, ", ")) or "every line whole")
end)

-- U64 (7 Nov 2026): a small dungeon picture shows large on hover.
step("chapter page: a dungeon's picture shows large on hover", function(c)
  local W = ns.Window
  W:ShowPage("chapter")
  local row = W.pageFrames.chapter.rows.items[1]
  if not (row and row:IsShown()) then return c:That(true, "no dungeon in this chapter") end
  row.pic:GetScript("OnEnter")(row.pic)
  local tip = ns.UI.pictureTip
  local _, default = ns.SetDungeonArt(row.pic.tex, row.key, 8, 4)
  if default then c:That(not (tip and tip:IsShown()), "only the game's default tile: nothing larger")
  else c:That(tip and tip:IsShown() and tip.key == row.key, "the picture, large, over the row") end
  row.pic:GetScript("OnLeave")(row.pic)
  c:That(not (tip and tip:IsShown()), "gone when the mouse leaves")
end)

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
  local named = false
  for _, r in ipairs(pf.wait.rows.items) do if r:IsShown() and r.name:GetText() == "Corwin" then named = true end end
  c:That(named, "it names Corwin, with level and how far")
  dev("hero Corwin level " .. math.max(was, floor))
  ns.Window:Refresh()
  c:That(not pf.wait:IsShown(), "gone when everyone is at the floor")
end)

-- Your To do (U140, U136): a new Leader's first steps, reach the floor, the chapter's dungeons, the steps for later
-- dungeons that open by this chapter's cap (under For later dungeons, on a gold tint), If you like last; a later
-- dungeon's page says when it comes instead of the room and Who is ready (U137, U138).
step("chapter page: the To do in order; steps for later dungeons on a gold tint; a later dungeon's page says when it comes", function(c)
  local f, T, J, W = cur(), ns.Together, ns.Journey, ns.Window
  local items = T:ToDo(f, J:CurrentIndex(f))
  -- (Required milestones after the dungeons, Optional ones under If you like: the owner, 9 Nov 2026.)
  local ORDER, last, ok = { start = 1, floor = 2, dungeon = 3, milestone = 3.5, later = 4, early = 5 }, 0, true
  for _, it in ipairs(items) do
    local k = (it.kind == "milestone" and not it.req) and 5 or ORDER[it.kind]
    if k < last then ok = false end
    last = k
  end
  c:That(ok, "in order: first steps, the floor, the dungeons and Required milestones, later dungeons, If you like")
  local later
  for _, it in ipairs(items) do if it.kind == "later" and not later then later = it end end
  W:ShowPage("chapter")
  local pf = W.pageFrames.chapter
  pf.sel = nil; W:Refresh()
  if not later then return c:That(true, "no step for a later dungeon opens by this chapter's cap") end
  c:That(pf.subLater:IsShown(), "under For later dungeons")
  local row
  for _, r in ipairs(pf.rows.items) do if r:IsShown() and r.key == later.x.key and r.tint:IsShown() then row = r end end
  c:That(row ~= nil, later.x.d[2] .. ": on a gold tint")
  c:Eq(row and row.brief:GetText(), later.line, "with its first step")
  -- One step, whole (check of 10 Nov 2026: a second one ran out of the row).
  c:That(row ~= nil and not (row.brief.IsTruncated and row.brief:IsTruncated()), "its line whole: " .. (later.line or ""))
  c:That(row ~= nil and not row.group:IsShown(), "no Find group: it comes later")
  ns.DungeonPage:Open(later.x.key)
  local dp = W.pageFrames.dungeon
  c:Has(dp.later:IsShown() and dp.later:GetText(), L.DG_LATER:format(J.Roman(later.e.chapter)), "its page says when it comes")
  c:That(not dp.room:IsShown() and not dp.rings:IsShown(), "no room or Who is ready for it")
  ns.DungeonPage:Back()
end)

-- The boss review of 6 Nov 2026: rares, summons and bosses players spare are not needed for a clear.
step("clears: optional bosses are not needed (rares, summons, a tribute run)", function(c)
  local Cl = ns.Clears
  local function needs(key, boss)
    local byTok = {}
    for _, b in ipairs(Cl:Bosses(key)) do byTok[b.tok] = b.name end
    for _, tok in ipairs(Cl:DefaultNeeded(key)) do if byTok[tok] == boss then return true end end
    return false
  end
  for _, x in ipairs({ { "dmn", "Guard Fengus" }, { "dmn", "Cho'Rush the Observer" }, { "scholo", "Kirtonos" },
    { "st", "Avatar of Hakkar" }, { "brd", "Princess Moira Bronzebeard" }, { "lbrs", "Urok Doomhowl" },
    { "rfd", "Ragglesnout" }, { "strat", "Ezra Grimm" },
    -- Forever's own (6 Nov 2026): rares and bosses an event calls.
    { "dal", "Lyn the Ignored" }, { "dal", "Mana Wraith" }, { "rol", "Lordaeron Captain" }, { "rol", "Viktor the Vile" },
    { "rol", "The Abandoned" }, { "exc", "Highland Horror" } }) do
    if #Cl:Bosses(x[1]) > 0 then c:That(not needs(x[1], x[2]), x[2] .. " is optional") end
  end
  if #Cl:Bosses("dmn") > 0 then c:That(needs("dmn", "King Gordok"), "King Gordok is needed") end
  if #Cl:Bosses("rol") > 0 then c:That(needs("rol", "Rath'mael"), "Rath'mael is needed") end
  if #Cl:Bosses("exc") > 0 then c:That(needs("exc", "Relic Guardian"), "Relic Guardian is needed") end
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
  -- U91: Take a picture is the main button; Without the interface and Group photo are smaller beside it.
  local fr = P.frame
  c:That(fr.clean:GetHeight() < fr.take:GetHeight() and fr.photo:GetHeight() < fr.take:GetHeight(), "one main button, two smaller choices")
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

-- 7 Nov 2026 (the owner: two Moments tabs named different Adventurers for the same first): a deed heard later, one
-- held back in a dungeon, takes the kept Moment over. Checked on a Moment of its own, taken out again.
step("moments: a first heard later takes the Moment over", function(c)
  local f, Mo, id = cur(), ns.Moments, "first:selftest"
  local other
  for _, n in ipairs(ns.Fellowship:Members(f)) do if n ~= ns.Me() then other = n break end end
  Mo:Add(f, { id = id, k = "first", time = time() - 60, names = { ns.Me() }, first = "fall" })
  c:That(other and Mo:Follow(f, id, time() - 120, other) ~= nil, "an earlier fall heard after the run takes it over")
  c:Eq(Mo:Find(f, id).names[1], other, "the Moment names who fell first")
  c:Eq(Mo:Follow(f, id, time() - 120, other), nil, "and stays put the next time")
  local a = Mo:Data(f)
  for i, m in ipairs(a.list) do if m.id == id then table.remove(a.list, i) break end end
  a.seen[id] = nil
end)

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

-- Models were loaded again every 10 seconds and on every mouseover, with the photo closed: the game stuttered in a
-- group (7 Nov 2026). A loaded one stays until the photo or the page shows it.
step("models: a loaded model is not loaded again in the background", function(c)
  local PH, key, calls = ns.Photo, "Selftest Model-Nowhere", 0
  local old = PH.actors[key]
  PH.actors[key] = { loaded = true, SetModelByUnit = function() calls = calls + 1 end }
  PH:Preload(key)
  PH.actors[key] = old
  c:Eq(calls, 0, "the group photo's model is kept, not loaded again")
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
  -- Only the attunements of raids Blizzard has announced (30 Oct 2026: the addon shows what the game offers).
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

-- The Quests tab (6 Nov 2026): two bold sections with their counts; each by zone, the zone you are in first (You are
-- here), then your continent's (Nearby); quests as cards with an icon and your progress.
step("quests tab: sections, zones by how close, quest cards", function(c)
  local pf = ns.Window.pageFrames.quests
  pf.tabs.buttons[1]:Click()
  c:Eq(pf.tab, "quests", "the first tab is Quests (U144: the Dungeon quests tab went to the Dungeon page)")
  c:That(pf.secs[1].title:GetText():find(L.Q_SECTION_MINE, 1, true) == 1, "Together now")
  c:That(pf.secs[2].title:GetText():find(L.Q_SECTION_OTHERS, 1, true) == 1, "Pick up and join")
  local zone = GetRealZoneText and GetRealZoneText() or GetZoneText()
  c:Eq(ns.Quests:Nearness(zone), "here", "the zone you are in (" .. tostring(zone) .. ") is here")
  c:Eq(ns.Quests:Nearness("Nowhere At All"), nil, "a made-up zone is not near")
  local n, bad = 0, 0
  for _, r in ipairs(pf.rows.items) do
    if r:IsShown() then
      n = n + 1
      if not r.icon:GetTexture() then bad = bad + 1 end
    end
  end
  c:That(bad == 0, n .. " quests shown as cards with an icon (needs quests in your log)")
  -- A zone marked You are here is the first of its section.
  local RANK, ok, last = { here = 0, near = 1 }, true, {}
  for _, z in ipairs(pf.zoneOrder or {}) do
    local r = RANK[z.near] or 2
    if last[z.sec] and r < last[z.sec] then ok = false end
    last[z.sec] = r
  end
  c:That(ok, #(pf.zoneOrder or {}) .. " zone headings: the one you are in first, then nearby ones")
  c:That(not pf.questie:IsShown(), "the Questie note is on the Quest chains tab only")
end)

shot("quests")

-- A dungeon's preparation lives on its own page (U141, the rebuild of 9 Nov 2026): the Quests page has three tabs, the
-- Chapter page's To do says what each of your chapter's dungeons needs and a row opens its page.
-- The first dungeon with a quest list for this side (the Deadmines, or Ragefire Chasm for the Horde).
local function listedDungeon()
  for _, x in ipairs(ns.DungeonPage.List(cur())) do
    if ns.QuestLists:Groups(cur(), x.key) then return x.key end
  end
end

step("dungeon quests: three Quests tabs; the To do says what each dungeon needs, Get ready where quests wait", function(c)
  ns.Window:ShowPage("quests")
  c:Eq(#ns.Window.pageFrames.quests.tabs.buttons, 3, "three tabs: Quests, Quest chains, Attunements & keys")
  local f, QL = cur(), ns.QuestLists
  local n, bad = 0, {}
  for _, it in ipairs(ns.Together:ToDo(f, ns.Journey:CurrentIndex(f))) do
    if it.kind == "dungeon" and not it.done and not it.wait then
      n = n + 1
      local r = QL:Ready(f, it.x.key, ns.Me())
      local want = (r and not r.ready) and "ready" or "find"
      if (it.line or "") == "" or it.action ~= want then bad[#bad + 1] = it.x.d[2] end
    end
  end
  c:Eq(table.concat(bad, ", "), "", n .. " dungeons, each with what you need")
  ns.Window:ShowPage("chapter")
  local row
  for _, r in ipairs(ns.Window.pageFrames.chapter.rows.items) do if not row and r:IsShown() and r.key then row = r end end
  if row then
    c:That((row.brief:GetText() or "") ~= "", "the row's line: " .. tostring(row.brief:GetText()))
    ns.DungeonPage:Open(row.key)
    c:Eq(ns.Window.current, "dungeon", "a row opens the dungeon's page")
    ns.DungeonPage:Back()
    c:Eq(ns.Window.current, "chapter", "Back returns to the Chapter page")
  end
end)

step("dungeon quests: a dungeon's page has its quests under three headings in the order you act, Pin on map", function(c)
  local QL = ns.QuestLists
  local key = listedDungeon()
  if not key then return c:That(true, "no dungeon with a quest list in this journey") end
  ns.DungeonPage:Open(key)
  c:Eq(ns.Window.current, "dungeon", "the Dungeon page (U96)")
  local pf = ns.Window.pageFrames.dungeon
  local g = QL:Groups(cur(), key)
  c:Eq(pf.secs[1]:IsShown(), #g.earlier > 0, "1. Prequest chains, when it has quests")
  c:Eq(pf.secs[2]:IsShown(), #g.pick > 0, "Pick up before you go, when it has quests")
  c:Eq(pf.secs[3]:IsShown(), #g.inside > 0, "Starts inside, when it has quests")
  c:Has(pf.secs[1]:IsShown() and pf.secs[1].text:GetText() or pf.secs[2].text:GetText(), "1. ", "the first heading shown is number 1")
  local n, bad, codes = 0, 0, 0
  for _, p in ipairs(pf.quests.items) do
    if p:IsShown() then
      n = n + 1
      if (p.where:GetText() or "") == "" or (p.where:GetText() or ""):find("%d%.%d, %d") then bad = bad + 1 end
      if p.pin:IsShown() ~= QL:CanPin(QL:Start(p.id) or {}) then bad = bad + 1 end
      for code in (p.where:GetText() or ""):gmatch("|c(........)") do
        if not code:find("^%x+$") then codes = codes + 1 end
      end
    end
  end
  c:Eq(n, #g.pick + #g.earlier + #g.inside, "every quest of the dungeon for your side")
  c:Eq(bad, 0, "each says where it starts and your status on one line, no spot numbers (U160); a pin where the place is known")
  c:Eq(codes, 0, "every colour in a status is a real one, not a theme's name")
  c:Eq(QL.WhereText({ by = "Scout Riell", zone = "Westfall", x = 56.7, y = 47.4 }), "Scout Riell, Westfall", "where, in words; the spot only on the pin (U160)")
  -- In the game: is a zone's map found by its name, and does the game allow a waypoint there? (Unknown in Forever
  -- until this ran.)
  local map = QL:MapOf({ zone = UnitFactionGroup("player") == "Horde" and "Orgrimmar" or "Westfall" })
  local can = map and C_Map and C_Map.CanSetUserWaypointOnMap and C_Map.CanSetUserWaypointOnMap(map)
  report().dungeonPin = { map = map, waypoint = can and true or false }
  c:That(true, "the zone's map: " .. tostring(map) .. "; waypoints there: " .. tostring(can and true or false))
end)

-- The list's counts are counted without building the groups, and each dungeon's quest list is made once (code review
-- of 1.2.0: both were made again for every dungeon at each redraw).
step("dungeon quests: the counts agree with the groups; each list made once", function(c)
  local QL, f = ns.QuestLists, cur()
  local key = listedDungeon()
  if not key then return c:That(true, "no dungeon with a quest list in this journey") end
  local g = QL:Groups(f, key)
  local function open(list)
    local n = 0
    for _, x in ipairs(list) do if x.status == "no" then n = n + 1 end end
    return n
  end
  local p, e, i = QL:Counts(f, key)
  c:Eq(("%d %d %d"):format(p, e, i), ("%d %d %d"):format(open(g.pick), open(g.earlier), open(g.inside)), "the counts agree with the groups")
  c:That(QL:DungeonQuests(f, key) == QL:DungeonQuests(f, key), "the dungeon's list is made once")
end)

-- The dungeons new in WoW Forever have their lists, each side its own (the owner, 7 Nov 2026).
step("dungeon quests: the dungeons new in WoW Forever have their lists", function(c)
  local g = ns.QuestLists:Groups(cur(), "hot")
  local horde = UnitFactionGroup("player") == "Horde"
  c:That(g ~= nil and #g.inside > 0, "Hall of Thanes: An Ancient Grudge starts inside, for both sides")
  c:Eq(g and #g.pick, horde and 1 or 2, "Hall of Thanes: quests to pick up in Ironforge (one for the Horde)")
end)

-- The owner, 9 Nov 2026: one source for dungeon quests, our own database (Data/DungeonQuests.lua). Every dungeon WoW
-- Forever has has its list, every quest on it its level, and its XP ships for the Room card. (A few starts are not
-- known yet: they read "not known yet".)
step("dungeon quests: every dungeon has its list, every quest its level", function(c)
  local missing = {}
  for _, d in ipairs(ns.DUNGEONS) do
    local list = ns.DUNGEON_QUESTS[ns.BaseKey(d[1])]
    if not (list and #list > 0) then missing[#missing + 1] = d[1] end
    for _, q in ipairs(list or {}) do
      if not (ns.QUEST_STARTS[q[1]] and ns.QUEST_STARTS[q[1]].lvl) then missing[#missing + 1] = q[2] end
    end
  end
  c:Eq(table.concat(missing, ", "), "", "nothing missing")
  c:Eq(ns.QUEST_STARTS[1200].inside, true, "Blackfathom Villainy starts inside, from Argent Guard Thaelrid")
  c:That(ns.QUEST_STARTS[1221].xp ~= nil, "Blueleaf Tubers ships its XP")
  c:That(ns.Room.QuestXP(1221) ~= nil, "and the Room card has an XP for it")
  local horde = UnitFactionGroup("player") == "Horde"
  local fang = false
  for _, q in ipairs(ns.QuestLists:DungeonQuests(cur(), "wc")) do if q.id == 914 then fang = true end end
  c:Eq(fang, horde, "Leaders of the Fang only for the Horde")
end)

-- The game itself says whether it knows each quest by its ID and under which name: every quest on a dungeon's list and
-- every step of a chain before one (8 Nov 2026: The Last Element was found as 3911 in WoW Forever; our data
-- lists it as 7201, and this step tells which the game knows).
local function listedQuests()
  local out, seen = {}, {}
  local function put(id, name) if not seen[id] then seen[id] = true; out[#out + 1] = { id, name } end end
  for _, list in pairs(ns.DUNGEON_QUESTS) do for _, q in ipairs(list) do put(q[1], q[2]) end end
  for _, st in pairs(ns.QUEST_STARTS) do for _, x in ipairs(st.after or {}) do put(x[1], x[2]) end end
  return out
end
step("dungeon quests: asks the game for every quest on a dungeon's list and in the chains before them", function(c)
  if not inGame() then return c:That(true, "outside the game") end
  local n = 0
  for _, q in ipairs(listedQuests()) do
    if not C_QuestLog.GetTitleForQuestID(q[1]) then n = n + 1; C_QuestLog.RequestLoadQuestByID(q[1]) end
  end
  c:That(true, n .. " asked")
end, 35) -- in 20 seconds the server sent about 230 of ~330 (check of 8 Nov 2026)

step("dungeon quests: the game knows every quest on a dungeon's list and in the chains by its ID and name", function(c)
  if not inGame() then return c:That(true, "outside the game") end
  local unknown, other = {}, {}
  for _, q in ipairs(listedQuests()) do
    local t = C_QuestLog.GetTitleForQuestID(q[1])
    if ns.Secret(t) then return c:That(true, "the game keeps quest names secret here (an instance)") end
    if not t or t == "" then unknown[#unknown + 1] = q[1] .. " " .. q[2]
    elseif t:lower() ~= q[2]:lower() then other[#other + 1] = q[1] .. " " .. q[2] .. " is " .. t end
  end
  table.sort(unknown) table.sort(other)
  -- Not loaded within the wait is no failure: every listed ID is in the game's quest table (docs/QUEST-SOURCES.md),
  -- and the server answers ~200 requests at its own pace.
  c:That(true, #unknown == 0 and "the game sent every quest" or ("not sent in time: " .. table.concat(unknown, ", ")))
  c:Eq(table.concat(other, ", "), "", "IDs the game names otherwise")
end)

-- U123 (the owner, 8 Nov 2026: the book tells players what to do ahead of time): a prequest chain lists its
-- steps, each with where it starts (Destruction in Deadmines' ten, Leaders of the Fang's five).
step("dungeon quests: a prequest chain lists its steps, each with where it starts", function(c)
  local horde = UnitFactionGroup("player") == "Horde"
  local key, id = horde and "wc" or "dm", horde and 914 or 92819
  ns.DungeonPage:Open(key)
  local pf = ns.Window.pageFrames.dungeon
  local row
  for _, p in ipairs(pf.quests.items) do if p:IsShown() and p.id == id then row = p end end
  c:That(row ~= nil, "the quest is on the page")
  if not row then return end
  local text = row.steps:GetText() or ""
  c:That(row.steps:IsShown(), "its steps show")
  -- More than five steps fold to the next one until Show all steps (U127).
  local folded = not horde
  if folded then
    c:Has(text, (L.DG_STEP_OF:format(1, 10, ""):gsub("%s+$", "")), "ten steps: folded to the next one")
    click(row.more)
    text = row.steps:GetText() or ""
  end
  c:Has(text, horde and "1. The Forgotten Pools" or "1. Testing the Wells", "the first step first")
  c:Has(text, horde and "Tonga Runetotem, The Barrens" or "Alba Fairmoon, Westfall", "where each step starts")
  if folded then click(row.more) end
  local found
  for _, q in ipairs(ns.QuestLists:Groups(cur(), key).earlier) do if q.id == id then found = q end end
  c:Eq(found and #found.steps, horde and 5 or 10, "under Prequest chains, every step")
end)

-- U123: a chain can go through the dungeon. A quest that starts inside with a step to take before the run is one to start
-- early (The Truth Comes Crashing Down, after The Archivist, done in the run: it only has to be taken); one whose chain
-- is all inside starts inside.
step("dungeon quests: a prequest chain can go through the dungeon, up to the run", function(c)
  local horde = UnitFactionGroup("player") == "Horde"
  local function has(list, id) for _, q in ipairs(list) do if q.id == id then return q end end end
  local q = has(ns.QuestLists:Groups(cur(), "strat").earlier, 5262)
  c:That(q ~= nil, "The Truth Comes Crashing Down (it starts inside): under Prequest chains")
  c:Eq(q and q.steps[#q.steps].start.run, true, "The Archivist is done in the run: taken before, that is enough")
  c:That(has(ns.QuestLists:Groups(cur(), "ulda").inside, horde and 2280 or 2279) ~= nil, "The Platinum Discs, whose chain is all inside: under Starts inside")
end)

step("dungeon quests: the To do's Get ready opens the dungeon's page; Back returns", function(c)
  ns.Window:ShowPage("chapter")
  local row
  for _, r in ipairs(ns.Window.pageFrames.chapter.rows.items) do
    if not row and r:IsShown() and r.group:IsShown() and r.action == "ready" then row = r end
  end
  if not row then return c:That(true, "nothing to get ready in this chapter") end
  c:Eq(row.group.text:GetText(), L.TODO_GET_READY_BUTTON, "Get ready instead of Find group")
  c:That(row.dj == nil and row.lore == nil, "the book and story buttons went to the page (U96)")
  click(row.group)
  c:Eq(ns.Window.current, "dungeon", "the Dungeon page")
  c:Eq(ns.Window.dungeon, row.key, "at that dungeon")
  click(ns.Window.pageFrames.dungeon.back)
  c:Eq(ns.Window.current, "chapter", "Back to the Chapter page")
end)

step("dungeon quests: the reminder toast, once per dungeon, never in combat", function(c)
  local QL = ns.QuestLists
  -- (Kept aside and put back: the self-test must not use up the real reminders of this character.)
  local was = ns.char.dqToasted
  ns.char.dqToasted = {}
  ns.Combat:SetSimulated(true)
  local before = #report().toasts
  QL:Remind(ns.LevelCap())
  c:Eq(#report().toasts, before, "none in combat")
  ns.Combat:SetSimulated(false)
  local any = next(ns.char.dqToasted) ~= nil
  c:That(not any or toastSeen("dquest", nil), "after combat: a toast for each dungeon with quests to pick up")
  local after = #report().toasts
  QL:Remind(ns.LevelCap())
  c:Eq(#report().toasts, after, "never twice")
  ns.char.dqToasted = was
end)

-- 9 Nov 2026: a step that is only taken (Rig Wars, before the Horde's Gnomeregan quest from Scooty) counts for Who is
-- ready once it is in the log; the step after it still has to be done.
step("dungeon quests: a step that is only taken is ready once it is in the log", function(c)
  local name = full("Grok")
  local f, Q, QL = { faction = "Horde", members = { [name] = {} }, heroes = {} }, ns.Quests, ns.QuestLists
  local function early(log, done)
    local q = {}
    for _, id in ipairs(log) do q[id] = { t = "Quest " .. id, z = "", l = 1, h = 0, g = 1 } end
    Q:Store(f, name, { q = q, d = done })
    return QL:Ready(f, "gnomer", name).early
  end
  local none = early({}, { 2842 })
  c:Eq(ns.QUEST_STARTS[2843].after[1].accept, true, "Rig Wars only has to be taken")
  c:Eq(early({ 2841 }, { 2842 }), none + 1, "Rig Wars in the log and Chief Engineer Scooty done: ready")
  c:Eq(early({ 2841 }, {}), none, "Rig Wars in the log, Chief Engineer Scooty not done: not ready")
end)

-- The owner, 9 Nov 2026: nothing about dungeon quests is learned in play. What 1.4 learned is dropped at load, and a
-- 1.4 Adventurer's message about where a quest starts (QSTART) is dropped unread.
step("dungeon quests: never learned in play; 1.4's messages about them are dropped", function(c)
  c:That(ns.QuestLists:IsDungeonQuest(166) and not ns.QuestLists:IsDungeonQuest(1), "the dungeons' quests known by ID")
  c:Eq(ns.db.questStarts, nil, "no learned starts kept")
  c:Eq(ns.db.questXP, nil, "no learned XP kept")
  c:Eq(ns.Comm.handlers.QSTART, nil, "a 1.4 message about where a quest starts is dropped")
end)

-- The Dungeons page (U157): every dungeon of the journey, chapter by chapter, a hidden chapter's too (its name hidden).
step("dungeon page: the Dungeons page lists every dungeon by chapter; a tile opens its page, Back returns (U157)", function(c)
  local W = ns.Window
  c:That(ns.Pages:InNav("dungeons", ns.Pages:Context()), "Dungeons in the sidebar")
  W:ShowPage("dungeons")
  local pf = W.pageFrames.dungeons
  local S, J = ns.Settings, ns.Journey
  local was = S:Get("dungeonsShow")
  S:Set("dungeonsShow", "all"); W:Refresh()
  local list, tiles, first = ns.DungeonPage.List(cur()), 0, nil
  for _, t in ipairs(pf.tiles.items) do if t:IsShown() then tiles = tiles + 1; first = first or t end end
  c:Eq(tiles, #list, "a tile for each dungeon of the journey; the raids on their own page (U165)")
  c:Eq(pf.none:IsShown(), #list == 0, "the empty line only without dungeons")
  local gold
  for _, h in ipairs(pf.heads.items) do
    if h:IsShown() then
      local r, g, b = h.text:GetTextColor()
      local ar, ag, ab = ns.Theme:RGBA("accentText")
      -- (The game keeps colours as floats: near enough, not equal.)
      if math.abs(r - ar) + math.abs(g - ag) + math.abs(b - ab) < 0.03 then gold = h.text:GetText() end
    end
  end
  c:Has(gold or "", J.Roman(J:CurrentIndex(cur())), "your chapter's heading in gold")
  -- U164: Only open ones: the dungeons the fellowship may run now.
  S:Set("dungeonsShow", "open"); W:Refresh()
  local want, got = 0, 0
  for _, x in ipairs(list) do if J:Open(cur(), x.key) then want = want + 1 end end
  for _, t in ipairs(pf.tiles.items) do if t:IsShown() then got = got + 1 end end
  c:Eq(got, want, "Only open ones: what the fellowship may run now")
  c:Eq(W.frame.book.sub:GetText(), L.SUB_DUNGEONS_OPEN, "and the subtitle says so")
  S:Set("dungeonsShow", "all"); W:Refresh()
  c:Eq(W.frame.book.sub:GetText() or "", "", "Show all: no subtitle")
  local view, later, hidden = ns.Journey:MaxView(cur(), ns.Me()), {}, 0
  for _, x in ipairs(list) do if x.n > view then later[x.n] = true end end
  for _, h in ipairs(pf.heads.items) do
    if h:IsShown() and (h.text:GetText() or ""):find(L.HIDDEN_CHAPTER, 1, true) then hidden = hidden + 1 end
  end
  local n = 0
  for _ in pairs(later) do n = n + 1 end
  c:Eq(hidden, n, "a hidden chapter's name stays hidden, its dungeons show")
  if first then
    click(first)
    c:Eq(W.current, "dungeon", "a tile opens its dungeon's page")
    c:Eq(W.dungeon, first.key, "that dungeon")
    click(W.pageFrames.dungeon.back)
    c:Eq(W.current, "dungeons", "Back to Dungeons")
  end
  S:Set("dungeonsShow", was)
end)
shot("dungeons")
shot("dungeons-open")

-- The Dungeon page (U96), Entrances (U97), Who is ready (U98, U99), Remind (U100), the game's tabs (U102).
step("dungeon page: opens from the Chapter page, the Overview, Journey Admin and a raid card; Back returns to each", function(c)
  local W = ns.Window
  local function back(from)
    c:Eq(W.current, "dungeon", "opened from " .. from)
    c:That(W:IsFlat(), "on the flat sheet: one paper under the title across both halves")
    click(W.pageFrames.dungeon.back)
    c:Eq(W.current, from, "Back to " .. from)
    -- A frame after each: the slow-steps list then times one opening, not all of them (10.6 s in one go, check of
    -- 8 Nov 2026, 23:21; the game stops a script at about 20).
    c:Yield()
  end
  W:ShowPage("chapter")
  local row = W.pageFrames.chapter.rows.items[1]
  if row and row:IsShown() and row.key then click(row.pic); back("chapter") end
  W:ShowPage("raids")
  local rc = W.pageFrames.raids and W.pageFrames.raids.cards.items[1]
  if rc and rc:IsShown() and rc.page:IsShown() then click(rc.page); back("raids") end
  -- The Overview: Coming up's first step for a later dungeon (U140).
  W:ShowPage("overview")
  local prep = W.pageFrames.overview.coming.prep
  if prep:IsShown() then click(prep); back("overview") end
  if cur().leader == ns.Me() then
    W:ShowPage("admin")
    local card
    for _, x in ipairs(W.pageFrames.admin.editor.drows.items) do if not card and x:IsShown() and x.key then card = x end end
    if card then card.picHit:GetScript("OnMouseUp")(card.picHit); back("admin") end
  end
end)

step("dungeon page: the story, the bosses with the kills, who cleared it, the foot; a raid's page", function(c)
  local key = listedDungeon() or "dm"
  ns.DungeonPage:Open(key)
  local pf = ns.Window.pageFrames.dungeon
  local story = rawget(L, "STORY_" .. ns.BaseKey(key):upper())
  c:Eq(pf.story:IsShown(), story ~= nil, "our own story where we have one")
  c:That((pf.more.text:GetText() or "") ~= "", "Read more in Spoken or Lore Forever")
  c:Eq(pf.bossNone:IsShown(), #ns.Clears:Bosses(key) == 0, "the bosses, or none known")
  -- U161: before any boss fell, no "Not yet" beside each (Who cleared it says it once); after, beside those standing.
  local fell = false
  for _, b in ipairs(ns.Clears:Bosses(key)) do
    for _, name in ipairs(ns.Journey:Counted(cur())) do if ns.Clears:Killed(cur(), key, name)[b.tok] then fell = true end end
  end
  local notYet, blank = 0, 0
  for _, row in ipairs(pf.bosses.items) do
    if row:IsShown() then
      if row.n:GetText() == L.DQ_NOT_YET then notYet = notYet + 1 elseif (row.n:GetText() or "") == "" then blank = blank + 1 end
    end
  end
  if fell then c:Eq(blank, 0, "a boss fell: each row says who was there, or Not yet")
  else c:Eq(notYet, 0, "no boss fell yet: no Not yet beside each") end
  c:That((pf.cleared:GetText() or "") ~= "", "who cleared it")
  c:That(pf.way:IsShown() and pf.dj:IsShown(), "Waypoint and the Dungeon Journal at the foot")
  -- Every Classic place has its story (WoW Forever's own have none yet).
  local missing = {}
  for k in pairs(ns.Entrances.SHIPPED) do
    if ns.Dungeon(k) and not rawget(L, "STORY_" .. k:upper()) then missing[#missing + 1] = k end
  end
  c:Eq(#missing, 0, "a story for each Classic place " .. table.concat(missing, ", "))
  local raid = ns.RAIDS[1] and ns.RAIDS[1][1]
  if raid then
    ns.DungeonPage:Open(raid)
    c:Has(select(2, ns.DungeonPage.Titles(ns.Pages:Context())), L.DG_RAID_SUB:match("^[^%%]+"), "a raid's page says its size and level")
    c:That(pf.none:IsShown(), "a raid: no quest list here")
  end
end)

step("dungeon page: the entrance from the shipped table; where you stand is read outside instances (U97)", function(c)
  local E = ns.Entrances
  local e = E:Get(cur(), "dm")
  c:Eq(e and e.zone, "Westfall", "the Deadmines' entrance in Westfall")
  local here = E.Here()
  report().entranceHere = here and { map = here.map, x = here.x, y = here.y, zone = here.zone } or false
  if IsInInstance() then
    c:That(true, "inside an instance: nothing read")
  else
    c:That(here ~= nil or not inGame(), "your place on the zone's map: " .. (here and (tostring(here.zone) .. " " .. here.x .. ", " .. here.y) or "none"))
  end
  c:Eq(E:Apply({}, { key = "krol", x = 40, y = 50 }), true, "a learned entrance is kept")
  c:Eq(E:Apply({}, { key = "dm#2", x = 40, y = 50 }), false, "a placement is no place")
end)

step("dungeon page: who is ready, a ring each, Show who a row each; a click shows their quests; Remind only where it may go (U98, U100, U126)", function(c)
  local key = listedDungeon()
  if not key then return c:That(true, "no dungeon with a quest list in this journey") end
  ns.DungeonPage:Open(key)
  local pf = ns.Window.pageFrames.dungeon
  pf.whoOpen = nil; ns.Window:Refresh()
  local rows, any = ns.Ready:Rows(cur(), key), false
  for _, x in ipairs(rows) do if x.r then any = true end end
  c:Eq(pf.readyHead:IsShown(), any, "Who is ready, when there is something to get ready")
  if not any then return end
  local rings, open = 0, 0
  for _, g in ipairs(pf.rings.items) do if g:IsShown() then rings = rings + 1 end end
  for _, b in ipairs(pf.readyRows.items) do if b:IsShown() then open = open + 1 end end
  c:Eq(rings, #rows, "folded: a ring for each Adventurer")
  c:Eq(open, 0, "and no rows")
  c:Has(pf.rings.items[1].tip, ns.Short(ns.Me()), "you first, how far on hover")
  click(pf.showWho)
  c:Eq(pf.readyRows.items[1].name, ns.Me(), "Show who: a row each, you first")
  -- U163: each row says Ready, or what is still missing, not two counts to work out.
  local line = pf.readyRows.items[1].line:GetText() or ""
  c:That(line:find(L.RD_READY:match("^[^%%]+"), 1, true) or line:find(L.RD_NEEDS:match("^[^%%]+"), 1, true)
    or line:find(L.RD_NOTHING, 1, true), "your row: Ready, or what you need: " .. line)
  c:That(not pf.readyRows.items[1].remind:IsShown(), "never yourself")
  local other = pf.readyRows.items[2]
  if other and other:IsShown() then
    click(other)
    c:Eq(pf.who, other.name, "a click shows their quests")
    c:Has(pf.whoNote:GetText(), ns.Short(other.name), "Showing their quests")
    local why = ns.Ready:CanRemind(cur(), other.name, key)
    c:Eq(other.remind:IsShown(), why == nil or why == "off", "Remind only where it may go (" .. tostring(why) .. ")")
    click(pf.readyRows.items[1])
    c:Eq(pf.who, nil, "your own row: your quests")
  end
  click(pf.showWho)
end)
shot("dungeon-page")
shot("dungeon-page-who")

step("dungeon page: ready toasts once, never in combat; a reminder once a day (U98-U100)", function(c)
  local R, QL = ns.Ready, ns.QuestLists
  local was, ready = ns.char.readyToasts, QL.Ready
  ns.char.readyToasts = {}
  QL.Ready = function() return { early = 1, earlyOf = 1, pick = 2, pickOf = 2, ready = true } end
  local ok, err = pcall(function()
    local since = #report().toasts
    ns.Combat:SetSimulated(true)
    R:Check()
    c:Eq(#report().toasts, since, "none in combat")
    ns.Combat:SetSimulated(false)
    c:That(#R:Watched(cur()) == 0 or toastSeen("dready", nil), "after combat: Ready for ...")
    -- Everyone ready (two counted at least): its own toast, once (U99).
    c:That(#R:Watched(cur()) == 0 or #ns.Journey:Counted(cur()) < 2 or toastSeen("dallready", nil), "Everyone is ready for ...")
    local n = #report().toasts
    R:Check()
    c:Eq(#report().toasts, n, "never twice")
  end)
  QL.Ready = ready
  ns.char.readyToasts = was
  ns.Combat:SetSimulated(false)
  if not ok then error(err) end
  -- Reminders: once per Adventurer, dungeon and day (applied here, not sent).
  local f = cur()
  local kept, other = f.reminds, nil
  for name in pairs(f.members) do if name ~= ns.Me() then other = name end end
  if other then
    f.reminds = nil
    local st = GetServerTime()
    c:Eq(R:Apply(f, ns.Me(), { name = other, key = "dm", st = st }, time()), true, "a reminder is kept")
    c:Eq(R:Apply(f, ns.Me(), { name = other, key = "dm", st = st }, time()), true, "a second the same day counts, and changes nothing")
    c:Eq(R:Reminded(f, other, "dm").by, ns.Me(), "the first stays")
    c:Eq(R:CanRemind(f, other, "dm"), "today", "then: reminded today")
    -- One reminding you: its toast, with what is left (U100).
    local readyFn = QL.Ready
    QL.Ready = function() return { early = 0, earlyOf = 1, pick = 1, pickOf = 3, ready = false } end
    local okR, errR = pcall(function()
      R:Apply(f, other, { name = ns.Me(), key = "dm", st = st }, time())
      c:That(not ns.Settings:ToastOn("dremind") or toastSeen("dremind", nil), "a reminder reaches you as a toast")
    end)
    QL.Ready = readyFn
    f.reminds = kept
    if not okR then error(errR) end
  end
end)
shot("toast-dready")

step("tabs: folder tabs with an icon on the Quests, Manage and Chronicle pages, their words inside (U102)", function(c)
  local W = ns.Window
  local pages = { "quests", "chronicle" }
  if cur().leader == ns.Me() then pages[#pages + 1] = "manage" end
  for _, id in ipairs(pages) do
    W:ShowPage(id)
    local tabs = W.pageFrames[id].tabs
    local b = tabs.buttons[1]
    c:That(b.fill ~= nil and b.icon ~= nil, id .. ": the book's folder tab with its icon")
    if inGame() then
      -- (The check of 8 Nov 2026: "Attunements & keys" ran past its tab and the page.)
      local last = tabs.buttons[#tabs.buttons]
      c:That(last:GetRight() <= tabs:GetRight() + 1, id .. ": the last tab ends on the page")
      for _, t in ipairs(tabs.buttons) do
        if t.text:GetRight() > t:GetRight() or t.text:GetLeft() < t:GetLeft() then c:That(false, id .. ": " .. t.label .. " inside its tab") end
      end
    end
  end
  -- The Quests page's title fits every tab, with no line under it (U147: the tabs say it).
  W:ShowPage("quests")
  local qp = W.pageFrames.quests
  for _, b in ipairs(qp.tabs.buttons) do
    click(b)
    c:Eq(W.frame.book.sub:GetText() or "", "", "Quests, " .. b.label .. ": no line under the title")
  end
  click(qp.tabs.buttons[1])
end)

-- Room for the dungeon quests (U78). A made-up chapter stands in for this character's (whose dungeon quests' XP may
-- not be known yet), and is put back after the step, also after an error.
local function fakeRoom(c)
  local R, ch = ns.Room, ns.Journey:Current(cur())
  local cap = ch and ch.cap or 20
  local fake, real = { now = cap - 2, levels = 2.4, to = cap + 0.4, cap = cap, tol = 0, limit = cap, stop = cap - 2.4,
    unknown = 1, n = ch and ch.n or 0 }, R.Chapter
  R.Chapter = function() return fake end
  c.undo = function() R.Chapter = real end
  return fake
end

step("room: the dungeon quests' levels in words, where to stop, the cap level left for the mobs", function(c)
  local R = ns.Room
  local main, stop, notes = R.Lines({ levels = 1.44, to = 27.44, cap = 28, tol = 1, stop = 26.56, unknown = 2 })
  c:Eq(main, L.ROOM_LINE:format(1.4, 27.4, L.ROOM_CAP_TOL:format(28, 1)), "the level they take you to, with the cap's allowance")
  c:Eq(stop, L.ROOM_STOP:format(L.ROOM_AT:format(26, 56)), "where to stop questing, as level and percent (U85)")
  c:Eq(notes, L.ROOM_MOBS:format(29) .. "  " .. L.ROOM_UNKNOWN_N:format(2), "the cap level left for the mobs, and the quests whose XP is not known yet")
  local r = R:Chapter(cur(), ns.Me())
  c:That(true, r and ("this chapter: %.1f levels, %d quests' XP not known"):format(r.levels, r.unknown)
    or "nothing to count in this chapter")
end)

-- The owner, 10 Nov 2026 ("Leave mobs out"): only the dungeon quests count, up to the start of the cap level; the cap
-- level itself is left for the dungeons' mobs, and nothing measured in runs is kept any more.
step("room: only the dungeon quests count, up to the start of the cap level", function(c)
  local R, J, f = ns.Room, ns.Journey, cur()
  c:Eq(ns.db.mobXP, nil, "no mob XP kept from older versions")
  local r = f and R:Chapter(f, ns.Me())
  if not r then return c:That(true, "nothing to count in this chapter, or at the level cap") end
  local ch = J:Current(f)
  c:Eq(r.limit, ch.cap + f.rules.capTol, "the start of the cap level, with its allowance")
  c:Eq(r.mobs, nil, "no mobs in the count")
  c:Has(select(3, R.Lines(r)), L.ROOM_MOBS:format(r.limit), "the note says the cap level is left for them")
end)

-- The check of 7 Nov 2026: "about 0.0 levels, to 1.0 of the cap 25" with a pretend level of 22.
step("room: counted from the level the book shows for you, and no card with nothing known", function(c)
  local r = ns.Room:Chapter(cur(), ns.Me())
  if not r then return c:That(true, "no XP known to count in this chapter: no card") end
  c:That(r.levels > 0, ("something to count: %.1f levels"):format(r.levels))
  c:Eq(math.floor(r.now), (ns.Dev and ns.Dev.myLevel) or UnitLevel("player"), "from the level every page shows for you")
end)

-- The owner, 8 Nov 2026: a quest's XP from the game itself, for any quest once the game has loaded it (asked here,
-- checked by the next step, after the wait). Blueleaf Tubers pays 5,000 in WoW Forever at full XP.
step("room: asks the game for a dungeon quest's XP by its ID", function(c)
  if not inGame() then return c:That(true, "outside the game (tests/test_room.lua)") end
  ns.Room.QuestXP(1221)
  c:That(ns.Room.asked[1221] or ns.Room.QuestXP(1221) ~= nil, "asked for Blueleaf Tubers")
end, 3)

step("room: the game gave WoW Forever's XP for a quest not in your log", function(c)
  if not inGame() then return c:That(true, "outside the game (tests/test_room.lua)") end
  if not ns.Pace.LEVEL_XP[UnitLevel("player")] then return c:That(true, "at the level cap: the game gives no quest XP") end
  local ok, xp = pcall(GetQuestLogRewardXP, 1221)
  if ns.Secret(xp) then return c:That(true, "the game keeps it secret here (an instance)") end
  c:That(ok and tonumber(xp) and xp > 0, "Blueleaf Tubers: " .. tostring(ok and xp) .. " XP from the game (5,000 at full XP)")
  if ok and tonumber(xp) and xp > 0 then c:Eq(ns.Room.QuestXP(1221), xp, "the Room card counts the game's number") end
end)

-- The check of 8 Nov 2026: the card showed only in the tour's stand-in. One dungeon quest's XP known (as after a
-- hand-in) is enough for the real count to make it.
step("room: one dungeon quest's XP known is enough for the Overview's answer (no stand-in)", function(c)
  local R, J, W, f = ns.Room, ns.Journey, ns.Window, cur()
  local ch = f and J:Current(f)
  local q
  for _, x in ipairs(ch and J:ChapterList(f, ch.n) or {}) do
    if not (x.early or q) then q = ns.QuestLists:DungeonQuests(f, x.key)[1] end
  end
  if not q then return c:That(true, "no dungeon quest on this chapter's lists") end
  local st = ns.QUEST_STARTS[q.id]
  local was = st.xp
  c.undo = function() st.xp = was; W:Refresh() end
  st.xp = was or 1500
  local r = R:Chapter(f, ns.Me())
  if not r then return c:That(true, "at the level cap, or " .. q.name .. " is done: no card") end
  W:ShowPage("overview")
  local room = W.pageFrames.overview.stand.room
  c:That(room:IsShown(), "under Where we stand, from the real count (" .. q.name .. ")")
  c:Has(room.text:GetText(), (R.Answer(r)), "the answer")
end)

-- 8 Nov 2026: a quest on the lists of two dungeons in one chapter (Scarlet Monastery's wings) counts once in the
-- chapter's room (tests/test_room.lua); a dungeon's own page still counts it.
step("room: a quest two dungeons of a chapter share counts once", function(c)
  local R, f, me = ns.Room, cur(), ns.Me()
  if not f then return c:That(true, "no fellowship") end
  local h = ns.Hero:Get(f, me) or {}
  local function open(key)
    local out = {}
    for _, q in ipairs(ns.QuestLists:DungeonQuests(f, key)) do
      if not (h.questsDone and h.questsDone[q.id]) then out[q.id] = R.QuestXP(q.id) or 0 end
      for _, s in ipairs(ns.QUEST_STARTS[q.id].after or {}) do -- a step done in the run counts too
        if s.run and not (h.questsDone and h.questsDone[s[1]]) then out[s[1]] = R.QuestXP(s[1], s.xp) or 0 end
      end
    end
    return out
  end
  local arm, cath, want = open("smarm"), open("smcath"), 0
  for id, xp in pairs(cath) do if arm[id] == nil then want = want + xp end end
  local seen = {}
  R:Share(f, "smarm", me, seen)
  c:Eq(R:Share(f, "smcath", me, seen).quests, want, "the Cathedral counts only what the Armory did not")
  local all = 0
  for _, xp in pairs(cath) do all = all + xp end
  c:Eq(R:Share(f, "smcath", me).quests, all, "its own page counts them all")
end)

-- Code review of 1.2.0: picking up a dungeon quest left the Overview's room card as it was (a quest list redrew only
-- the quest pages). A dungeon quest picked up or dropped redraws every page; any other quest still does not.
step("room: a dungeon quest picked up redraws every page, another quest only the quest pages", function(c)
  local name = full("Elyra")
  local f, Q = { members = { [name] = {} }, heroes = {} }, ns.Quests
  local function log(ids)
    local q = {}
    for _, id in ipairs(ids) do q[id] = { t = "Quest " .. id, z = "", l = 1, h = 0, g = 1 } end
    return { q = q }
  end
  Q:Store(f, name, log({ 783 }))
  c:Eq(Q:Store(f, name, log({ 783, 1 })), false, "another quest: the quest pages only")
  c:Eq(Q:Store(f, name, log({ 783, 1, 166 })), true, "a dungeon quest picked up: every page")
  c:Eq(Q:Store(f, name, log({ 783, 1, 166 })), false, "the same log again: the quest pages only")
  c:Eq(Q:Store(f, name, log({ 783, 1 })), true, "a dungeon quest dropped: every page")
end)

-- U82, U85 (the checks of 7 Nov 2026): the stop point as a red tick on the level tracks, and in the game's terms (level
-- and percent) on the tracker too.
step("room: the stop point as a red tick on the level tracks and as level and percent (U82, U85)", function(c)
  local R, J, f, W = ns.Room, ns.Journey, cur(), ns.Window
  c:Eq(R.StopAt(26.6), L.ROOM_AT:format(26, 60), "26.6 is level 26, 60% into it")
  c:Eq(R.StopAt(26.998), L.ROOM_AT_0:format(27), "just short of 27 is level 27")
  c:Eq(R.StopAt(26.6, true), L.ROOM_TICK:format(26, 60), "the tick's short form")
  local ch = J:Current(f)
  if not ch then return c:That(true, "no chapter going on") end
  local fake = fakeRoom(c)
  local fl = J:FloorLevel(f, ch)
  fake.stop = (fl + ch.cap) / 2
  W:ShowPage("overview")
  local t = W.pageFrames.overview.stand.track
  c:That(t.stop:IsShown(), "a red tick on the Overview's track")
  c:Eq(t.stopLabel:GetText(), R.StopAt(fake.stop, true), "with its words")
  local cp = W.pageFrames.chapter
  W:ShowPage("chapter"); cp.sel = nil; W:Refresh()
  c:That(cp.levelTrack.stop:IsShown(), "a red tick on the level track")
  c:Eq(cp.levelTrack.stopLabel:GetText(), R.StopAt(fake.stop, true), "with the same words")
  local TK, now = ns.Tracker, fake.now
  fake.now = fake.stop - 0.5
  c:Has(TK:Content(f).stop, L.TRACK_STOP:format(R.StopAt(fake.stop)), "the tracker says where to stop")
  -- On its own line under your little bar, and "now" past it (the check of 9 Nov 2026: it ran into the bar docked).
  -- (In the game only: the unit-test harness places every frame at 100, 100.)
  TK:Refresh()
  local fr, stopLine = TK.frame, nil
  for _, b in ipairs(fr and fr.lines or {}) do if b.key == "stop" then stopLine = b end end
  if inGame() and stopLine and stopLine:IsShown() and fr.floorBar:IsShown() then
    local lt, bb = stopLine:GetTop(), fr.floorBar:GetBottom()
    c:That(not (lt and bb) or lt <= bb + 0.5, ("the stop line starts under the little bar (%s <= %s)"):format(tostring(lt), tostring(bb)))
  end
  fake.now = fake.stop + 0.2
  c:Has(TK:Content(f).stop, L.TRACK_STOP_NOW, "past the stop point the tracker says now")
  fake.now = now
  fake.stop = nil
  W:Refresh()
  c:That(not cp.levelTrack.stop:IsShown(), "with room to spare, no tick")
end)

step("room: two warnings, half a level before the stop point and at it, once each", function(c)
  local R = ns.Room
  if not ns.Settings:ToastOn("room") then return c:That(true, "the room toasts are off in Settings") end
  local was, fake = ns.char.roomToasted, fakeRoom(c)
  ns.char.roomToasted = {}
  local undo = c.undo
  c.undo = function() undo(); ns.char.roomToasted = was end
  local before = #report().toasts
  fake.now = fake.stop - 0.3
  R:Check()
  c:Eq(#report().toasts, before + 1, "half a level before: the first warning")
  c:That(toastSeen("room", L.TOAST_ROOM_SOON:format(R.StopAt(fake.stop))), "it says where to stop")
  R:Check()
  c:Eq(#report().toasts, before + 1, "only once")
  fake.now = fake.stop + 0.1
  R:Check()
  c:That(toastSeen("room", L.TOAST_ROOM_NOW), "at the stop point: Leave room for the dungeons")
  R:Check()
  c:Eq(#report().toasts, before + 2, "only once")
end)

step("room: the Overview's answer, the Chapter page's total, the Dungeon page's answer with Show everyone", function(c)
  local R, W, J = ns.Room, ns.Window, ns.Journey
  local fake = fakeRoom(c)
  local undo = c.undo
  c.undo = function() undo(); W:Refresh() end
  W:ShowPage("overview")
  local room = W.pageFrames.overview.stand.room
  c:That(room:IsShown(), "the answer under Where we stand (U145)")
  c:Has(room.text:GetText(), (R.Answer(fake)), "its words")
  c:That((room.tip or ""):find((R.Lines(fake)), 1, true) ~= nil, "the figures on hover")
  W:ShowPage("chapter")
  W.pageFrames.chapter.sel = nil; W:Refresh()
  c:That(W.pageFrames.chapter.room:IsShown(), "the Chapter page: the total under where the Adventurers stand")
  local f, key = cur(), nil
  for _, x in ipairs(J:ChapterList(f, J:CurrentIndex(f))) do if not (x.early or key) then key = x.key end end
  if not key then return c:That(true, "no dungeon in this chapter") end
  ns.DungeonPage:Open(key)
  local pf = W.pageFrames.dungeon
  pf.everyone = nil; W:Refresh()
  c:That(pf.room:IsShown(), "the Dungeon page: the answer for your chapter's dungeon")
  c:That(not pf.roomHeroes:IsShown(), "yours only, until Show everyone")
  pf.roomAll.box:Click()
  c:That(pf.everyone and pf.roomHeroes:IsShown(), "Show everyone: the other Adventurers' too")
  pf.roomAll.box:Click()
end)

-- Levels are walked one by one with the game's XP table (audit, 7 Nov 2026): each level is bigger than the last.
step("room: levels walked one by one with the game's XP table", function(c)
  local Pa = ns.Pace
  local sum = 0
  for _, v in ipairs(Pa.LEVEL_XP) do sum = sum + v end
  c:Eq(sum, 4084700, "the table: 4,084,700 XP to 60")
  c:Eq(Pa.Reach(19, 0, 21300, 21300 + 11600), 20.5, "a level and a half from 19: level 20 is 23,200, not 21,300")
  c:Eq(Pa.Back(20.5, 21300 + 11600, 19, 21300), 19, "and back from 20.5")
  c:Eq(Pa.Reach(59, 0, 209800, 500000), 60, "it stops at the level cap")
  c:Eq((Pa.ToLevel(15, 4400, 14400, 17)), 10000 + 16000, "XP to a level, level by level")
  -- In the game: the size the game gives at this level, against the table (WoW Forever keeps the Classic curve).
  local level, max = UnitLevel("player"), UnitXPMax("player")
  if inGame() and level < ns.LevelCap() and not ns.Secret(max) then
    c:Eq(max, Pa.LEVEL_XP[level], ("the game's level %d is the table's size"):format(level))
  end
end)

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
  -- Folded at first (U108): the heading opens it.
  c:That(pf.invHead:IsShown() and (pf.invOpen or not pf.invite:IsShown()), "Invite Adventurers: folded at first")
  click(pf.invHead.click)
  c:That(pf.invite:IsShown() and pf.send:IsShown(), "Invite Adventurers above the cards, opened")
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
  -- U3: someone not near is a card (class crest, class and role, item level, gear as a list), no empty model box.
  c:That(pf.card:IsShown() and not pf.modelBox:IsShown() and not pf.gear[1]:IsShown(), "Inspect a pretend Adventurer: the card, no empty model box")
  c:That(pf.card.who:GetText() ~= "" and pf.card.ilvl:GetText():find(pf.iIlvl:GetText(), 1, true), "the card: class, role and item level")
  if inGame() then
    local low
    for _, r in ipairs(pf.card.rows) do if r:IsShown() then low = r end end
    if low then c:That(low:GetBottom() >= pf.card.note:GetTop() - 1, "the gear list stays above the note") end
  end
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
-- U90 (the check of 7 Nov 2026, 20:46): the same line by the same Adventurer on the same day is one line with "× 2".
step("recent history: the same line on the same day is one line", function(c)
  local t = time()
  local f = { chronicle = {
    { text = "Brannic published new rules.", time = t, k = "rules" },
    { text = "Elyra reached level 17.", time = t, k = "level" },
    { text = "Brannic published new rules.", time = t, k = "rules" },
  } }
  local v = ns.Fellowship:ChronicleView(f, 10)
  c:Eq(#v, 2, "two lines, not three")
  c:Eq(v[1].text, L.CHR_TIMES:format("Brannic published new rules.", 2), "with × 2")
end)

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
  -- Coming up on the Overview shows the next two (U139); the Gatherings page has the list and the chosen one.
  ns.Window:ShowPage("overview")
  local co = ns.Window.pageFrames.overview.coming
  c:That(co.gathers[1]:IsShown() and co.gathers[2]:IsShown() and not co.noGather:IsShown(), "both under Coming up")
  ns.Window:ShowPage("gatherings")
  local pf = ns.Window.pageFrames.gatherings
  c:That(pf.rows.items[2] and pf.rows.items[2]:IsShown(), "both on the Gatherings page")
  c:That(pf.band:IsShown() and pf.who[1]:IsShown(), "the chosen one with who is coming")
  -- The week ahead (M25): seven days; today has the one set up two hours from now (unless that is tomorrow).
  c:Eq(#pf.week, 7, "the week ahead")
  local planned = 0
  for _, row in ipairs(pf.week) do if row.what:IsShown() then planned = planned + 1 end end
  c:That(planned >= 1, planned .. " days with a Gathering")
  -- U4: day cards like the game's calendar, four to a row; a day with a Gathering shows its picture and who is coming.
  local d
  for _, x in ipairs(pf.week) do if x.g then d = x break end end
  c:That(d and d.art:IsShown() and d.who:GetText() ~= "", "a day card with its picture and who is coming")
  if inGame() then
    local first, last = pf.week[1], pf.week[4]
    c:That(math.abs(first:GetTop() - last:GetTop()) < 1 and last:GetRight() <= pf.rscroll.child:GetLeft() + ns.Window.PAGE_W + 1,
      "four day cards in a row, inside the page")
  end
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
  -- there and edits the rules from there (U143).
  ns.Window:ShowPage("rules")
  local pf = ns.Window.pageFrames.rules
  c:Eq(#pf.articles, 6, "six articles")
  c:Has(pf.articles[2].text:GetText(), L.BOOK_ADV_N:format(f.rules.minHeroes), "Dungeon runs has the new number")
  c:That(pf.dHead:IsShown() and pf.vRows.items[1]:IsShown(), "the vote under Decided this week")
  c:That(pf.editBar:IsShown() and not pf.propose:IsShown(), "the Leader: Edit the rules, not Propose")
  c:That(not pf.pHead:IsShown(), "no Propose a change heading for the Leader (it was empty)")
end)

shot("rules and votes")

step("needs attention", function(c)
  dev("hero Corwin level 13")
  local items = ns.Attention:Gather(cur())
  c:That(#items > 0, #items .. " items")
  ns.Window:ShowPage("manage")
  c:Eq(ns.Window.frame.header.inbox.badge:IsShown(), true, "counted on the Inbox button (U144)")
end)

step("needs attention: each in the Inbox, with where it is handled and Seen (U106, U144)", function(c)
  local W, I = ns.Window, ns.Inbox
  local kept = ns.char.inboxSeen
  ns.char.inboxSeen = nil
  local prefix = "behind:" .. full("Corwin") .. ":"
  local function corwin()
    for _, it in ipairs(I:Items()) do if it.key and it.key:sub(1, #prefix) == prefix then return it end end
  end
  local it, n = corwin(), I:Count()
  c:That(it and it.actions[1][1] == L.NA_CARD and it.actions[2][1] == L.NOTICE_SEEN, "Corwin behind: Their card and Seen")
  W:OpenPanel("inbox")
  local row
  for _, r in ipairs(W.panels.inbox.rows.items) do if it and r:IsShown() and r.text:GetText() == it.text then row = r end end
  c:That(row and row.buttons[1]:IsShown() and row.buttons[2]:IsShown(), "in the Inbox, two buttons")
  if it then
    it.actions[1][2]()
    c:Eq(W.current, "heroes", "Their card opens the Adventurers page"); c:Eq(W.pageFrames.heroes.sel, full("Corwin"), "at Corwin's card")
    W.pageFrames.heroes.sel = nil
    I:See(it.key)
    c:Eq(I:Count(), n - 1, "Seen: one fewer on the Inbox button")
    dev("hero Corwin level 14")
    local again = corwin()
    c:That(again and not again.seen, "a new level: it counts again")
  end
  ns.char.inboxSeen = kept
  W:HidePanels()
  W:ShowPage("manage")
end)

shot("manage")

step("inbox", function(c)
  dev("hero Elyra ask")
  ns.Window:OpenPanel("inbox")
  c:That(ns.Window.panels.inbox:IsShown(), "inbox open")
end)

step("inbox: a notice has its button and Seen, and Seen takes it off the count (U105)", function(c)
  local I, kept = ns.Inbox, ns.char.inboxSeen
  ns.char.inboxSeen = nil
  -- A notice made for the check: the tournament's sign-up (no other answer is asked).
  local gather = I.Gather
  I.Gather = function(self)
    local items = gather(self)
    items[#items + 1] = { key = "tsign:selftest", text = L.INBOX_T_SIGNUP, actions = { { L.INBOX_OPEN_TOURNEY, function() end, "primary" } } }
    return items
  end
  local ok, err = pcall(function()
    local n = I:Count()
    local it
    for _, x in ipairs(I:Items()) do if x.key == "tsign:selftest" then it = x end end
    c:That(it and it.actions[1][1] == L.INBOX_OPEN_TOURNEY and it.actions[2][1] == L.NOTICE_SEEN, "Open the tournament and Seen")
    if it then it.actions[2][2]() end
    c:Eq(I:Count(), n - 1, "Seen: one fewer on the Inbox button")
    local last = I:Items()[#I:Items()]
    c:That(last.key == "tsign:selftest" and last.seen and #last.actions == 1, "listed last, dimmed, without Seen")
    ns.Window:OpenPanel("inbox")
  end)
  I.Gather = gather
  ns.char.inboxSeen = kept
  ns.Window:Refresh()
  if not ok then error(err) end
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

-- The owner, 6 Nov 2026: names filled in as in the game's mail box (the rest highlighted; Tab or Enter takes it,
-- Escape takes it back, the arrows move through the list), from friends, guild, your group and people met lately.
step("invite: names filled in as in the mail box", function(c)
  ns.Window:ShowPage("manage")
  local pf = ns.Window.pageFrames.manage
  local eb = pf.invite.edit
  c:That(eb:GetScript("OnArrowPressed") ~= nil and eb:GetScript("OnTabPressed") ~= nil, "the arrows and Tab work in the box")
  c:That(type(GetAutoCompleteResults) == "function" or not inGame(), "the game's own name list (the mail box's) is here")
  ns.Dev.pretendNames = { "Zandrel Brightwater", "Zandor Stonefist" }
  eb:SetFocus() -- as a player clicking into it: the list shows only while the box has focus
  local function typed(text) pf.invite:SetText(text); eb:GetScript("OnTextChanged")(eb, true) end
  typed("z"); typed("zan")
  c:Eq(pf.invite:GetText(), "Zandor Stonefist", "the first name filled in")
  -- The rest of it highlighted where it can be seen (a faint grey on the dark box; check of 6 Nov 2026, 17:50).
  if eb.GetHighlightColor then
    local _, _, _, a = eb:GetHighlightColor()
    c:That((a or 0) >= 0.3, ("the filled-in part shows (highlight alpha %.2f)"):format(a or -1))
  end
  c:That(pf.suggest.rows[1]:IsShown() and pf.suggest.rows[2]:IsShown(), "both names in the list")
  c:Eq(pf.suggest.rows[1].sub:GetText(), L.SRC_RECENT, "where a name comes from")
  eb:GetScript("OnArrowPressed")(eb, "DOWN")
  c:Eq(pf.invite:GetText(), "Zandrel Brightwater", "Down: the next one")
  eb:GetScript("OnEscapePressed")(eb)
  c:Eq(pf.invite:GetText(), "zan", "Escape takes it back")
  typed("zand")
  local before = cur().invites[full("Zandor Stonefist")]
  eb:GetScript("OnEnterPressed")(eb)
  c:Eq(pf.invite:GetText(), "Zandor Stonefist", "Enter takes the name")
  c:That(cur().invites[full("Zandor Stonefist")] == before, "without sending it")
  ns.Dev.pretendNames = nil
  pf.invite:SetText(""); eb:ClearFocus(); pf.suggest:Hide()
end)

-- U65 (7 Nov 2026): an online name in the list has its class icon before it (the class reads without the colour).
step("invite: a class icon before each online name in the list", function(c)
  ns.Window:ShowPage("manage")
  local pf = ns.Window.pageFrames.manage
  local eb, FR = pf.invite.edit, ns.Friends
  local real = FR.Suggest
  FR.Suggest = function() return { { name = full("Selftest Iconic"), online = true, class = "MAGE", source = "friend", level = 20 } } end
  eb:SetFocus()
  pf.invite:SetText("selftest i"); eb:GetScript("OnTextChanged")(eb, true)
  FR.Suggest = real
  local text = pf.suggest.rows[1]:IsShown() and pf.suggest.rows[1].name:GetText() or ""
  c:Has(text, "Iconic", "the online name in the list")
  if inGame() then c:Has(text, "|T", "with its class icon first") end
  pf.invite:SetText(""); eb:ClearFocus(); pf.suggest:Hide()
end)

-- The ponytail audit of 6 Nov 2026: one invite box (UI.InviteBox) for the Adventurers page and Manage.
step("invite: the same box on the Adventurers page", function(c)
  ns.Window:ShowPage("heroes")
  local pf = ns.Window.pageFrames.heroes
  pf.invOpen = true; ns.Window:Refresh()
  local eb = pf.invite.edit
  c:That(pf.suggest ~= nil and pf.send ~= nil and pf.asFriend ~= nil and pf.share ~= nil,
    "Send invite, Invite as a Friend, Share the addon")
  ns.Dev.pretendNames = { "Zandor Stonefist" }
  eb:SetFocus()
  pf.invite:SetText("zan"); eb:GetScript("OnTextChanged")(eb, true)
  c:Eq(pf.invite:GetText(), "Zandor Stonefist", "the name filled in here too")
  c:That(ns.Friends:All() == ns.Friends:All(), "your friends and guild are read once while you type")
  -- (The owner, 6 Nov 2026.) Online names in their class colour with their level; the game's soft click when a name
  -- is filled in, once per name.
  local Fr, S = ns.Friends, ns.Settings
  Fr.all, Fr.allAt, Fr.allMe = { { name = full("Zanara Moonbrook"), online = true, source = "guild", class = "PRIEST",
    level = 23 } }, GetTime(), ns.Me()
  local sounds = S:Get("sounds")
  S:Set("sounds", true)
  ns.lastSound = nil
  pf.invite:SetText(""); eb:GetScript("OnTextChanged")(eb, true)
  pf.invite:SetText("z"); eb:GetScript("OnTextChanged")(eb, true)
  c:Eq(pf.invite:GetText(), "Zanara Moonbrook", "an online guild member first")
  c:Eq(ns.lastSound, "fill", "a soft click when the name is filled in")
  ns.lastSound = nil
  pf.invite:SetText("za"); eb:GetScript("OnTextChanged")(eb, true)
  c:Eq(ns.lastSound, nil, "not again for the same name")
  c:Has(pf.suggest.rows[1].name:GetText(), "|cff" .. ns.ClassHex("PRIEST", ns.Theme:Current().light), "in her class colour")
  c:Eq(pf.suggest.rows[1].sub:GetText(), L.SRC_WITH_LEVEL:format(23, L.SRC_GUILD), "with her level")
  S:Set("sounds", sounds)
  ns.Dev.pretendNames, Fr.all = nil, nil
  pf.invite:SetText(""); eb:ClearFocus(); pf.suggest:Hide()
end)

step("invite: an invitation as a toast with Accept and Decline, staying until answered (U109)", function(c)
  local T, S, hit = ns.Toasts, ns.Settings, nil
  if S:Get("reduce") or not S:ToastOn("invite") then return c:That(true, "the toast is turned off here") end
  T:Push("invite", L.T_INVITE, L.INBOX_INVITE:format("Lea", "Band"), nil,
    { icon = ns.ICONS.toast_invite, actions = { { L.ACCEPT, function() hit = true end }, { L.DECLINE, function() end } } })
  local f = T.frame
  c:That(f:IsShown() and f.acts[1]:IsShown() and f.acts[2]:IsShown(), "Accept and Decline on the toast")
  c:That(f.hold:GetDuration() >= T.ANSWER_HOLD, "it stays until answered")
  click(f.acts[1])
  c:That(hit and not f:IsShown(), "Accept runs and the toast goes")
end)

step("quests: Together never suggests a dungeon's quest (U110)", function(c)
  c:That(ns.QuestLists:IsDungeonQuest(166), "The Defias Brotherhood is a dungeon's quest")
  local x = { id = "q:166", chain = false, mine = true, others = { full("Brannic") }, name = "The Defias Brotherhood" }
  ns.Quests:Classify(x)
  c:That(x.dungeon, "marked as one: Play now and the tracker leave it out")
end)

step("settings and themes: the key binding opens the chosen page and closes the book (U107)", function(c)
  local W, S = ns.Window, ns.Settings
  local was = S:Get("keyPage")
  c:Eq(BINDING_NAME_JOURNEYTOGETHERFOREVER_OPEN, L.BIND_OPEN, "its name in the game's Key Bindings")
  if inGame() and GetNumBindings and GetBinding then
    local found = false
    for i = 1, GetNumBindings() do if GetBinding(i) == "JOURNEYTOGETHERFOREVER_OPEN" then found = true end end
    c:That(found, "Bindings.xml is loaded: the binding is in Key Bindings (a full restart after the update)")
  end
  W:Close()
  S:Set("keyPage", "chapter")
  SlashCmdList.JOURNEYTOGETHERFOREVER("key")
  c:Yield()
  c:That(W:IsOpen() and W.current == "chapter", "the key opens the Chapter page")
  SlashCmdList.JOURNEYTOGETHERFOREVER("key")
  c:That(not W:IsOpen(), "pressed again: closed")
  S:Set("keyPage", was)
  W:Open("overview")
  c:Yield()
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
  c:Eq(ns.FullName(ns.CleanName("arielas-fireson")), "Arielas Fireson-" .. ns.Realm(), "a hyphen is the space")
  c:Eq(ns.WhisperTarget(full("Arielas Fireson")), "Arielas Fireson", "whispers go to the name alone")
  -- (5 Nov 2026: a ruleset is several numbered realms; keys end with the ruleset, the same for everyone on it.)
  if C_GameRules and C_GameRules.IsGameRuleActive then
    c:That(not ns.Realm():find("%d"), "keys end with your ruleset, not your numbered realm: " .. ns.Realm()
      .. " (the game's realm: " .. tostring(ns.GameRealm()) .. ")")
    c:Eq(ns.FullName("Arielas Fireson-" .. ns.GameRealm()), "Arielas Fireson-" .. ns.Realm(), "a sender's realm becomes the ruleset")
  end
  if type(second) == "string" and second ~= "" then
    c:That(ns.Self():find(" " .. second, 1, true) ~= nil, "your key has your surname: " .. ns.Self())
  end
  -- In a group: a first name alone finds the one in it who has it.
  local other = ns.UnitFull("party1")
  if other and ns.Short(other):find(" ", 1, true) then
    c:Eq(ns.Friends:Resolve(full(ns.Short(other):match("^(%S+)"))), other, "a first name finds " .. ns.Short(other))
  end
end)

-- The owner, 5 Nov 2026: invite a Battle.net friend by BattleTag (the character they play now).
step("invite: a BattleTag nobody on your list has is not sent", function(c)
  c:Eq(ns.Fellowship:Invite("Jtfnobody#0000"), nil, "not sent")
  c:That(cur().invites[full("Jtfnobody#0000")] == nil, "no invite made")
  c:That(toastSeen(nil, "Jtfnobody#0000"), "a toast says no friend with it is playing")
  -- Rulesets (5 Nov 2026): what the game gives for a Battle.net friend's realm, beside yours (to read in the report;
  -- friends on another realm or ruleset are left out of the suggestions).
  local mine = GetRealmID and GetRealmID()
  for i = 1, (BNGetNumFriends and (BNGetNumFriends()) or 0) do
    for j = 1, (C_BattleNet and C_BattleNet.GetFriendNumGameAccounts and C_BattleNet.GetFriendNumGameAccounts(i)) or 0 do
      local g = C_BattleNet.GetFriendGameAccountInfo(i, j)
      if g and g.isOnline and g.clientProgram == (BNET_CLIENT_WOW or "WoW") and g.characterName then
        c:That(true, ("Battle.net: %s on realm %s (%s); yours %s / %s (%s)"):format(tostring(g.characterName),
          tostring(g.realmName), tostring(g.realmID), tostring(GetRealmName and GetRealmName()), ns.Realm(), tostring(mine)))
      end
    end
  end
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
  -- U57 (6 Nov 2026): a thin bar under it empties over its day; the Inbox says how long it still waits (U144).
  c:That(row ~= nil and row.left:IsShown(), "a bar under the offline invite")
  -- (The check of 8 Nov 2026: the words on two lines ran into the bar.)
  if row and inGame() then c:That(row.wait:GetBottom() >= row.left:GetTop(), "the words stay above the bar") end
  c:That(row ~= nil and math.abs((row.left.value or 0) - (left or 0) / ns.Sync.EXPIRE) < 0.01, "full for a new invite, emptying over the day")
  local said = false
  for _, it in ipairs(ns.Inbox:Items()) do
    if (it.text or "") == L.NA_INVITE_LEFT:format(OFFLINE_NAME, ns.TimeLeft(left or 0)) then said = true end
  end
  c:That(said, "the Inbox: " .. L.NA_INVITE_LEFT:format(OFFLINE_NAME, ns.TimeLeft(left or 0)))
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
  -- Manage (U143): one sidebar entry, two tabs, and a bar that says where the rules are edited: the Rules page.
  local W = ns.Window
  W:ShowPage("manage")
  c:That(ns.Pages:InNav("rulesadmin", ns.Pages:Context()), "Admin: the rules for the Leader")
  local tabs = W.pageFrames.manage.tabs
  c:Eq(#tabs.buttons, 2, "two tabs")
  click(tabs.buttons[2])
  c:Eq(W.current, "managefellowship", "The fellowship tab")
  c:That(W.navItems.manage.ribbon:IsShown(), "Manage stays marked")
  c:That(W.pageFrames.managefellowship.rulesBar:IsShown(), "the bar to the Rules page")
  click(W.pageFrames.managefellowship.rulesBar.btn)
  c:Eq(W.current, "rules", "it opens the Rules page")
  click(W.pageFrames.rules.editBar.btn)
  c:Eq(W.current, "rulesadmin", "Edit the rules")
  c:That(W.navItems.rules.ribbon:IsShown(), "Rules stays marked")
  W:ShowPage("manage")
end)

-- Editing the rules: Publish (7 Nov 2026: the owner found none; it lay at the top of the scroll, out of sight) in a bar
-- at the foot of the left page, never scrolled; Publish and Discard return to the Rules page (U143). The draft is the Leader's picks over the rules as they are now
-- (8 Nov 2026, the release review): a vote shows in the form and stays, a size goes out whole, a change that came
-- meanwhile is no change, and a draft stays with its fellowship.
step("rules editing: Publish in sight, and only your changes go out", function(c)
  local f, W, R = cur(), ns.Window, ns.Rules
  local was, rules = {}, {}
  for k, v in pairs(f.rules) do was[k], rules[k] = v, v end
  c.undo = function() ns.Fellowship:SetRules(was) end
  local function vote(k, v)
    rules[k] = v
    ns.Fellowship:SetRules(rules)
    W:Refresh()
  end
  W:ShowPage("rulesadmin")
  local pf = W.pageFrames.rulesadmin
  -- A floor allowance button other than the rule's now.
  local function other()
    for _, b in ipairs(pf.form.controls[1].buttons) do if b.value ~= f.rules.floorTol then return b end end
  end
  pf.picks = nil
  W:Refresh()
  c:That(pf.bar:IsShown() and not pf.propose:IsShown(), "the bar, without Publish while nothing changed")
  c:Eq(pf.barText:GetText(), L.PUBLISHED, "everything is published")
  local pick = other()
  click(pick)
  c:Eq(pf.barText:GetText(), L.RULES_BAR_1, "one change waits")
  c:That(pf.propose:IsShown() and pf.undo:IsShown() and pf.draftBox:IsShown(), "Publish, Discard and what changed")
  c:That(pf.bar:GetParent() == pf.left, "the bar is outside the scroll")
  if inGame() then
    c:That(pf.propose:IsVisible() and pf.bar:GetBottom() >= pf.left:GetBottom() - 1, "Publish is on the page")
  end
  -- A vote passes meanwhile: the form shows it, it is not one of your changes, and Publish keeps it.
  vote("runXp", not was.runXp)
  c:Eq(pf.rules().runXp, rules.runXp, "the form shows the vote's rule")
  c:Eq(pf.barText:GetText(), L.RULES_BAR_1, "still one change: yours")
  click(pf.propose)
  c:That(W.confirm:IsShown(), "it asks first")
  click(W.confirm.ok)
  c:Eq(W.current, "rules", "Publish returns to the Rules page")
  c:Eq(f.rules.floorTol, pick.value, "your change is published")
  c:Eq(f.rules.runXp, rules.runXp, "the rule changed meanwhile stays")
  W:ShowPage("rulesadmin")
  c:Eq(pf.barText:GetText(), L.PUBLISHED, "everything is published again")
  -- A size picks all its numbers: after a vote on one of them it still goes out whole.
  local size = R.SizeOf(f.rules) == "large" and 1 or 4
  click(pf.size.buttons[size])
  vote("minHeroes", R.SIZES[R.SIZE_ORDER[size]].minHeroes == 5 and 4 or 5)
  click(pf.propose); click(W.confirm.ok)
  W:ShowPage("rulesadmin")
  c:Eq(R.SizeOf(f.rules), R.SIZE_ORDER[size], "the size is published whole")
  -- A change that reached the rules meanwhile (a late rules op) is no change.
  pick = other()
  click(pick)
  vote("floorTol", pick.value)
  c:Eq(pf.barText:GetText(), L.PUBLISHED, "a change that came is no change")
  c:That(pf.picks == nil and not pf.propose:IsShown(), "the draft starts afresh")
  -- A new size replaces the last one's keys: Large then Party leaves no Large-only rule behind.
  click(pf.size.buttons[4]); click(pf.size.buttons[3])
  c:That(pf.picks == nil or pf.picks.clearN == nil, "no stray rule from Large")
  c:Eq(R.SizeOf(pf.rules()), "party", "Party shows")
  -- A draft stays with its fellowship and its Leader (picks made for another, or before a handover, are dropped).
  click(other())
  pf.pickKey = "another fellowship"
  W:Refresh()
  c:That(pf.picks == nil and pf.barText:GetText() == L.PUBLISHED, "another fellowship's draft is not this one's")
  -- Discard throws a draft away.
  click(other())
  click(pf.undo)
  c:That(pf.picks == nil and W.current == "rules", "Discard, back on the Rules page")
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
step("heroes and inspect: the Friends of the fellowship fold under their own heading (U108)", function(c)
  local W, f = ns.Window, cur()
  local kept = ns.char.heroesOpen
  ns.char.heroesOpen = nil
  local was = ns.Fellowship:IsFriend(f, full("Elyra"))
  if not was then dev("hero Elyra friend") end
  W:ShowPage("heroes")
  local pf = W.pageFrames.heroes
  local function shownCard(name) for _, x in ipairs(pf.cards.items) do if x:IsShown() and x.who == name then return true end end return false end
  c:That(pf.folds[1]:IsShown() and not pf.folds[1].open, "Friends of the fellowship: a heading, closed at first")
  c:Eq(shownCard(full("Elyra")), false, "Elyra's card folded away")
  click(pf.folds[1].click)
  c:Eq(shownCard(full("Elyra")), true, "a click opens it")
  c:That(ns.char.heroesOpen and ns.char.heroesOpen.friends, "kept for the character")
  if not was then dev("hero Elyra friend off") end
  ns.char.heroesOpen = kept
  W:Refresh()
end)

step("friend of the fellowship: invited as one, never counted, tallies only", function(c)
  local f, F, J, W = cur(), ns.Fellowship, ns.Journey, ns.Window
  local t, me = full("Tamsin"), ns.Me()
  local counted = #J:Counted(f)
  -- The invite box offers it; the open invite says so.
  W:ShowPage("heroes")
  local pf = W.pageFrames.heroes
  pf.sel, pf.invOpen = nil, true; W:Refresh()
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
  local keptOpen, undoOpen = ns.char.heroesOpen, c.undo
  c.undo = function() if undoOpen then undoOpen() end ns.char.heroesOpen = keptOpen end
  ns.char.heroesOpen = { friends = true } -- (folded at first, U108)
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
  c:That(not pf.friendButton:IsShown(), "and no greyed Become a Friend (U47)")
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

-- U94 (the check of 7 Nov 2026, 20:46): in full screen Journey Admin's ruler and chapter list take the width.
step("Journey Admin: in full screen the ruler and the chapter list take the width", function(c)
  local W, S = ns.Window, ns.Settings
  local was = S:Get("fullscreen")
  c.undo = function() S:Set("fullscreen", was); W:Refresh() end
  local pf = W.pageFrames.admin
  S:Set("fullscreen", false); W:ShowPage("admin")
  local winRuler = pf.editor.rulerW
  S:Set("fullscreen", true); W:Refresh()
  local lo, li, ri, ro = W:PageInsets()
  c:That(lo == 26 and ro == 26 and li == 26 and ri == 26, "full screen: the pages take the whole width")
  if inGame() then
    c:That(pf.editor.rulerW > winRuler + 20, ("the ruler is wider (%.0f, was %.0f)"):format(pf.editor.rulerW, winRuler))
    local row = pf.editor.rows.items and pf.editor.rows.items[1]
    if row then c:That(row:GetWidth() > W.PAGE_W, ("a chapter row takes the width (%.0f)"):format(row:GetWidth())) end
  end
  S:Set("fullscreen", false); W:Refresh()
  c:Eq(pf.editor.rulerW, winRuler, "in a window as before")
  S:Set("fullscreen", was); W:Refresh()
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

-- A boss learned on the kill ("n<name>") counts by its data token once a build gives the dungeon its bosses: chosen
-- by the leader, killed before the update, or sent by a copy still on the old data (hotfix 1.1.1).
step("Journey Admin: bosses chosen or killed by name count by their data token", function(c)
  local f, Cl, me = cur(), ns.Clears, ns.Me()
  local b = Cl:Bosses("dm")[1]
  c:Eq(Cl:Token("dm", "n" .. b.name), b.tok, "the name becomes the data token")
  c:Eq(Cl:Token("dm", "nNobody at all"), "nNobody at all", "a name the data lacks stays")
  local was = f.kills.dm
  f.kills.dm = { [me] = { ["n" .. b.name] = time() } }
  local n = Cl:Progress(f, "dm", me)
  f.kills.dm = was
  c:Eq(n, 1, "a kill saved by name counts")
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

-- The dungeons of the chosen chapter each with their picture, small and square beside them (the owner, 6 Nov 2026).
step("Journey Admin: each dungeon of the chapter with its picture", function(c)
  local W, A = ns.Window, ns.AdminDraft
  W:ShowPage("admin")
  local ed = W.pageFrames.admin.editor
  A.sel = 2; W:Refresh()
  local rows, pics = 0, 0
  for _, r in ipairs(ed.drows.items) do
    if r:IsShown() then
      rows = rows + 1
      if r.pic:IsShown() and r.pic:GetTexture() ~= nil then pics = pics + 1 end
    end
  end
  c:That(rows > 0, rows .. " dungeons in chapter II")
  c:Eq(pics, rows, "each with its picture")
  local first = ed.drows.items[1]
  c:That(first and first.name:GetLeft() and first.pic:GetRight() and first.name:GetLeft() > first.pic:GetRight() or not inGame(),
    "the name beside the picture, not over it")
  -- Bosses on a line of its own: "From the next chapter" (U147) left it no room beside the roles (check of 10 Nov 2026).
  c:That(first and (not inGame() or first.bosses:GetRight() <= first:GetRight() + 0.5), "Bosses: … inside its card")
  -- A place without a boss list: a short label that stays inside its card, the reason on hover (check of 6 Nov 2026).
  -- (WoW Forever: Shaper's Terrace in the last chapter.)
  local j, unknown, ch = A:Journey(cur())
  for key in pairs(ns.DUNGEON_TILE) do
    local at = ns.Dungeon(key) and #ns.Clears:Bosses(key) == 0 and ns.JourneyEdit.ChaptersOf(j, key)[1]
    if at then unknown, ch = key, at end
  end
  if unknown then
    A.sel = ch; W:Refresh()
    local card
    for _, r in ipairs(ed.drows.items) do if r:IsShown() and ns.BaseKey(r.key) == unknown then card = r end end
    c:That(card and card.unknown, unknown .. ": the boss list is not known")
    c:Eq(card and card.bosses.text:GetText(), L.ADMIN_BOSSES_NONE, "the short label")
    c:That(card and (not inGame() or card.bosses:GetRight() <= card:GetRight() + 0.5), "inside its card")
    A.sel = 2; W:Refresh()
  end
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
    -- Its neighbours under the lens have none either ("XV" beside the lens's "XVI"; check of 6 Nov 2026).
    local l, r = ed.lens.x, ed.lens.x + ed.lens:GetWidth()
    for i, o in ipairs(ed.segs) do
      if i ~= n and o:IsShown() and o.x < r and o.x + o:GetWidth() > l then
        c:Eq(o.n:GetText() or "", "", "chapter " .. i .. " under the lens: no number")
      end
    end
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
    pf.tabs.buttons[1]:Click()
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
  -- (Only dungeons Blizzard has announced have their quest lists.)
  if next(ns.DUNGEON_QUESTS) == nil then
    c:That(ns.QuestLists:DungeonLine(f, key) == nil, "no quest lists in this game: no quest line on the Chapter page")
  else
    c:That(ns.QuestLists:DungeonLine(f, key) ~= nil, (d and d[2] or key) .. " has a quest line on the Chapter page")
  end
end)

-- One Chronicle with three tabs (U142): The journey, Moments and The fellowship (History until the rebuild); the lines
-- under the day they were written (U132).
step("Chronicle: three tabs; the lines under their days", function(c)
  local W = ns.Window
  W:ShowPage("chronicle")
  c:Eq(#W.pageFrames.chronicle.tabs.buttons, 3, "three tabs")
  local want = { "chronicle", "moments", "history" }
  for i, id in ipairs(want) do
    -- Each tab's page has the strip: click on the one in sight.
    local b = W.pageFrames[W.current].tabs.buttons[i]
    click(b)
    c:Eq(W.current, id, b.label .. " opens its tab")
    c:That(W.navItems.chronicle.ribbon:IsShown(), b.label .. ": Chronicle stays marked")
  end
  W:ShowPage("history")
  local d = W.pageFrames.history.days
  c:That(d.n >= 1 and d.pool.items[1]:IsShown(), "The fellowship: " .. d.n .. " day headings")
  c:Eq(d.pool.items[1]:GetText(), ns.UI.DayLabel(cur().chronicle[1].time):upper(), "the newest day first")
  W:ShowPage("chronicle")
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
  -- (Your own deeds aside: you founded Selftest past level 10, so its level firsts are yours from then; U62.)
  local mine = f.heroes[ns.Me()]
  local keep = { b.deeds, b.tally, e.deeds, e.tally, mine and mine.deeds }
  if mine then mine.deeds = {} end
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
    c:Eq(near.closest, who, near.key .. ": " .. (who and (ns.Short(who) .. " " .. L.FIRST_PROGRESS:format(lvl, tonumber(near.key:match("%d+")))) or "nobody below it"))
    if who then c:Eq(near.when:GetText(), L.FIRST_PROGRESS:format(lvl, tonumber(near.key:match("%d+"))), "said under the medal: 20 of 30 (U42)") end
    if who then c:That(near.dots[1]:IsShown() and near.dots[#near.dots]:IsShown(), "a progress ring of dots round it (U42)") end
  end
  -- U42: the newest earned medal glinted as the cabinet opened (still with Reduce effects).
  if #FS:List(f) > 0 then c:That(pf.glinted ~= nil, "the newest medal glinted: " .. tostring(pf.glinted)) end
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
  -- (Settled at once here: waiting for the others has its own step, "board: a first goes to Discord only once ...".)
  local settle = ns.Board.SETTLE
  ns.Board.SETTLE = 0
  local news = 0
  for _, n in ipairs(ns.Board:News(f)) do if n.kind == "first" then news = news + 1 end end
  ns.Board.SETTLE = settle
  c:That(news >= 3, news .. " firsts in the Discord outbox")
  pf.filter = "all"
  b.deeds, b.tally, e.deeds, e.tally = keep[1], keep[2], keep[3], keep[4]
  if mine then mine.deeds = keep[5] end
end)

-- U61 and U62 (6 Nov 2026): the mount first needs a riding mount of your own; a level you brought in when founding or
-- joining is your first from that moment, without a toast or a Moment.
step("firsts: a real mount; levels brought in when joining", function(c)
  local f, FS = cur(), ns.Firsts
  local me = f.members[ns.Me()]
  local lvl = UnitLevel("player") or 0
  local d = FS:Mine()
  if lvl >= 10 then
    c:Eq(d.lvl10, me.joined, "founded at level " .. lvl .. ": the level 10 first from the moment you came in")
    c:That(FS:BroughtIn(f, { key = "lvl10", name = ns.Me(), time = me.joined }), "brought in: no toast, no Moment")
  else
    c:That(true, "below level 10: nothing brought in")
  end
  c:That(not FS:BroughtIn(f, { key = "lvl10", name = ns.Me(), time = (me.joined or 0) + 60 }), "a real level-up later is news")
  local taxi = UnitOnTaxi and UnitOnTaxi("player")
  if taxi then FS:CheckMount(); c:That(true, "on a flight path now: checked, it gives no mount first") end
  c:That(true, "the mount first: " .. (d.mount and "noted" or "not yet (a flight path or a vehicle gives none)"))
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
  local lit1 = ns.Window.pageFrames.overview.stand.lives.candles.items[1]
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
  -- U43: a fall for good is the big banner, in violet, and a click opens the memorial.
  c:That(fallToast ~= nil and fallToast.big == true and fallToast.page == "(opens a window)", "the big banner; a click opens his memorial")
  -- (Its kicker said the Settings line "A challenge: a fall, a broken rule, the Ring"; check of 1 Nov 2026, 15:23.)
  c:Eq(fallToast and fallToast.kicker, Ch:Name("hardcore", f.challenges.hardcore), "the challenge's name above the title")
  -- A fall for good that also spends the last shared life: Hardcore still (the 0.12.0 review).
  local _, _, _, last = Ch:FallToast(f, setmetatable({ out = true, life = true, pool = 0 }, { __index = e }))
  c:Eq(last and last.kicker, Ch:Name("hardcore", f.challenges.hardcore), "also when it spends the last shared life")
  local T = ns.Toasts
  if T.frame and T.frame:IsShown() and T.current and T.current.solemn then
    c:That(T.frame.solemn and T.frame.solemnBg:IsShown(), "its banner: night violet")
    c:That(T.frame.big and T.frame.go:IsShown(), "large, with To the memorial (U43)")
    T:Click()
    local hp = ns.Window.pageFrames.heroes
    c:That(ns.Window.current == "heroes" and hp and hp.sel == b and hp.memorial:IsShown(), "the click opens his memorial")
    if hp then hp.sel = nil end
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
  c:That(ov.stand.lives:IsShown() and ov.stand.lives.candles.total == 2 and ov.stand.lives.candles:Lit() == 0, "the Overview's candles: 2, none lit")
  c:Eq(ov.stand.lives.text:GetText(), Ch:LivesView(f).title, "and what they mean")
  c:Eq(#(ov.stand.lives.candles.tipLines or {}), 2, "the tooltip names each life lost")
  -- Each candle is the flame beside "Shared lives" (the game's candles read as white pearls; check of 1 Nov, 11:30).
  c:Eq(ns.UI.icons[ov.stand.lives.candles.items[1].icon], ns.ICONS.chal_shared, "each candle: the shared lives' flame")
  -- Lives lost since the row was last seen: each candle goes out with a snuff and smoke (none with Reduce effects).
  ns.char.livesSeen = ns.char.livesSeen or {}
  ns.char.livesSeen[f.id] = 2
  ns.Window:Refresh()
  c:Eq(#(ov.stand.lives.candles.snuffed or {}), still and 0 or 2, still and "Reduce effects: no snuff" or "both candles go out as you look")
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
  -- His card on the Adventurers page: Fallen, and when and where (under The Fallen, opened: folded at first, U108).
  local keptOpen, undoOpen = ns.char.heroesOpen, c.undo
  c.undo = function() if undoOpen then undoOpen() end ns.char.heroesOpen = keptOpen end
  ns.char.heroesOpen = { fallen = true }
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
  -- The Overview's Since last time: his fall, with the skull (Recent history on this page until the review of 9 Nov
  -- 2026, SPEC §4.8; the check of 1 Nov 2026, 14:32: it was missing there).
  c:That(hp.feed == nil, "no Recent history on the Adventurers page")
  local kept, fell = ns.char.since, Ch:Fallen(f, b)
  ns.char.since = ns.Since:Snapshot(f)
  ns.char.since.t = (fell and fell.t or time()) - 1
  local fallLine
  for _, ev in ipairs((ns.Since:Digest(f) or { events = {} }).events) do
    if ev.icon == "hist_fallen" and ev.text:find(ns.Short(b), 1, true) then fallLine = ev.text end
  end
  ns.char.since = kept
  c:That(fallLine ~= nil, "Since last time: his fall, with the skull")
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
  -- U41: candles. Two pretend Adventurers light one each (a second from one of them counts once); the stone, who lit
  -- them, Light a candle for you; the Chronicle says so.
  local F = ns.Fellowship
  F:Apply(f, { k = "candle", name = b }, full("Elyra"), time() - 60)
  F:Apply(f, { k = "candle", name = b }, full("Corwin"), time() - 30)
  c:That(not F:Apply(f, { k = "candle", name = b }, full("Elyra"), time()), "one candle each")
  ns.Window:Refresh()
  local mem = hp.memorial
  c:Has(mem.lit:GetText(), ns.Short(full("Elyra")), "who lit a candle")
  c:Has(mem.lit:GetText(), ns.Short(full("Corwin")), "both of them")
  c:That(mem.light:IsShown() == Ch:CanLight(f, b), "Light a candle while you have not")
  if inGame() then
    c:That(mem.stone:IsShown(), "Guild Together's memorial stone (our Props file)")
    c:That(mem.stone:GetTop() <= mem.honour:GetBottom() + 1, "the stone sits under the memorial's words")
  end
  local said = false
  for _, x in ipairs(Ch:Entries(f)) do if x.icon == "candle" and x.text == L.CH_CANDLE:format(ns.Short(full("Elyra")), ns.Short(b)) then said = true end end
  c:That(said, "the Chronicle: Elyra lit a candle")
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
  -- The rulebook's tiles: the last one fills its row when it stands alone (U46).
  local rp, shownT = ns.Window.pageFrames.rules, {}
  for _, t in ipairs(rp.tiles) do if t:IsShown() then shownT[#shownT + 1] = t end end
  if #shownT > 0 then
    -- (Rounded: the game reads a width back as 473.99997.)
    c:Eq(math.floor(shownT[#shownT]:GetWidth() + 0.5), #shownT % 2 == 1 and rp.tileFull or rp.tileW,
      #shownT .. " tiles: the last one's width")
  end
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

-- Only your own auras and spells come to the watch: in a raid or a city the game sends them for everyone near, many
-- times a second (ponytail audit, 6 Nov 2026).
step("challenges: the food and spell watch hear only you", function(c)
  for _, ev in ipairs({ "UNIT_AURA", "UNIT_SPELLCAST_SUCCEEDED" }) do
    local fr, on, unit = ns.unitEvents[ev], false, nil
    if fr then on, unit = fr:IsEventRegistered(ev) end
    c:That(on and unit == "player", ev .. ": for you alone")
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
  -- U58 (6 Nov 2026): the road as a path, each bearer a step with their class icon, the Ring on who carries it now.
  local block
  for _, bl in ipairs(ns.Window.pageFrames.rules.chal.blocks.items) do if bl:IsShown() and bl.key == "ring" then block = bl end end
  local shown = {}
  for _, st in ipairs(block and block.steps.items or {}) do if st:IsShown() then shown[#shown + 1] = st end end
  c:That(block ~= nil and block.roadHead:IsShown(), "the rulebook: The Ring's road under its block")
  c:Eq(#shown, 2, "two steps: Brannic, then " .. ns.Short(nxt or "?"))
  c:Eq(shown[1] and shown[1].name:GetText(), "Brannic", "Brannic first")
  c:That(shown[1] ~= nil and not shown[1].ring:IsShown() and not shown[1].line:IsShown(), "no Ring and no line before him")
  c:That(shown[2] ~= nil and shown[2].ring:IsShown() and shown[2].line:IsShown(), "the next joined by a line, the Ring on them")
  if nxt and nxt ~= ns.Me() then
    dev("hero " .. ns.Short(nxt) .. " ring claim")
    c:Eq(f.ring and f.ring.guid, "dev-ring-2", "a ring of theirs is the Ring now")
  else
    c:That(true, "it passed to you: a ring you wear or carry becomes it")
  end
  f.ring = nil
  m.friend, m.catching = was, wasCatching
end)

-- U55/U56 (6 Nov 2026): the Ring after its bearer's name in the standings (on the Chapter page since U139) and the
-- tracker; its hand-over toast is the two names with their class icons.
step("challenges: the Ring-bearer marked in the standings and the tracker; the hand-over", function(c)
  local f, Ch, b = cur(), ns.Challenges, full("Brannic")
  withChallenges(f, { ring = true, race = true })
  f.ring = { who = b, t = time(), item = "Gold Ring" }
  ns.Window:ShowPage("chapter")
  local pf, mine, his = ns.Window.pageFrames.chapter, nil, nil
  for _, r in ipairs(pf.stand.rows.items) do
    if r:IsShown() and r.name:GetText() == "Brannic" then his = r end
    if r:IsShown() and r.name:GetText() == ns.Short(ns.Me()) then mine = r end
  end
  c:That(his ~= nil and his.ring:IsShown(), "the standings: the Ring after Brannic's name")
  c:That(mine == nil or not mine.ring:IsShown(), "none after yours")
  local online = (ns.Tracker:Content(f) or {}).online or ""
  if online:find("Brannic", 1, true) then
    c:Has(online, "Brannic " .. ns.RingMark(11), "the tracker: the Ring after his name")
  else
    c:That(true, "Brannic is not online: the tracker lists only who is")
  end
  local text = Ch:HandOver(f, b, ns.Me())
  c:Has(text, "Brannic", "the hand-over names the bearer")
  c:Has(text, ns.Short(ns.Me()), "and the next")
  c:Has(text, "»", "with the arrow between")
  f.ring = nil
  ns.Window:Refresh()
  c:That(his == nil or not his.ring:IsShown(), "no Ring, no mark")
  ns.Window:ShowPage("overview")
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

-- X7 (8 Nov 2026): Fellowship-crafted reads who made a piece from its tooltip's "Made by" line (C_TooltipInfo, outside
-- combat). In the game: whether the tooltips of what you wear and carry can be read, and the first maker found (to see
-- the line, wear or carry something a player crafted).
step("challenges: Fellowship-crafted reads who made a piece", function(c)
  local CW = ns.ChallengeWatch
  c:Eq(CW.MadeBy((ITEM_CREATED_BY or "<Made by %s>"):format("Brannic")), "Brannic", "the game's Made by line gives the maker")
  c:Eq(CW.Maker({ lines = { { leftText = "Linen Vest" } } }), nil, "no such line: nobody made it")
  c:Eq(CW.Maker(nil), false, "no tooltip: nothing is marked")
  c:That(CW.CRAFT_FREE[2] and CW.CRAFT_FREE[11] and CW.CRAFT_FREE[13] and not CW.CRAFT_FREE[5],
    "necks, rings and trinkets are free; a chest is not")
  if not inGame() or InCombatLockdown() then return end
  local TI = C_TooltipInfo
  c:That(TI and TI.GetInventoryItem and TI.GetBagItem and ITEM_CREATED_BY ~= nil, "the game gives addons an item's tooltip and the Made by line")
  if not (TI and TI.GetInventoryItem and TI.GetBagItem) then return end
  local worn, read, maker = 0, 0, nil
  for _, s in ipairs(ns.Hero.SLOTS) do
    if GetInventoryItemLink("player", s[2]) then
      worn = worn + 1
      local by = CW.Maker(TI.GetInventoryItem("player", s[2]))
      if by ~= false then read = read + 1 end
      maker = maker or by or nil
    end
  end
  c:Eq(read, worn, "the tooltip of everything you wear can be read")
  for bag = 0, NUM_BAG_SLOTS or 4 do
    for slot = 1, (C_Container and C_Container.GetContainerNumSlots(bag)) or 0 do
      maker = maker or CW.Maker(TI.GetBagItem(bag, slot)) or nil
    end
  end
  c:That(true, maker and ("a piece you wear or carry: made by " .. maker)
    or "nothing you wear or carry says who made it (carry a crafted piece to see the line)")
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
  ns.Sync:DropInvite(cur(), full("Kim"), ns.Sync:NoAnswerText(), true)
  c:That(cur().invites[full("Kim")] == nil, "the invite is gone")
  local o = ns.Window.overlays and ns.Window.overlays.share
  c:That(o and o:IsShown(), "the window opens in the open book")
  c:Has(o and o.title:GetText(), "Kim", "it names Kim")
  c:Eq(o and o.url:GetText(), ns.Share.URL, "the addon's page to copy")
  -- (6 Nov 2026) The usual causes, not only "no addon": the version, a trial account, the full name and the ruleset.
  c:Has(ns.Sync:NoAnswerText(), "latest version", "no answer: the chat line names the version")
  c:Has(o and o.hint:GetText(), "latest version", "and the window's hint")
  c:Has(o and o.hint:GetText(), "ruleset", "the ruleset and the full name")
  c:Has(ns.Share:WhisperText("Kim"), ns.Share.URL, "Whisper the link puts the page in the whisper")
end)

shot("share the addon")

step("friends without the addon: closed", function(c)
  local o = ns.Window.overlays and ns.Window.overlays.share
  if o then o:Hide() end
  c:That(not (o and o:IsShown()), "closed")
end)

-- Code review of 1.2.0: a first heard later took its Moment over, but Discord already had the first name. A first goes
-- out only once every other Adventurer has been heard from after it, or a day later. On a made-up fellowship.
step("board: a first goes to Discord only once nobody can take it over", function(c)
  -- (Deed times are the server's clock, heard this PC's own: right whatever this PC's clock says; code review of 1.2.1.)
  local B, me, other, now, S = ns.Board, ns.Me(), full("Elyra"), time(), ns.Firsts.Now()
  local f = { members = { [me] = {}, [other] = {} }, heroes = { [other] = { heard = now - 600 } } }
  c:Eq(B:Settled(f, { name = me, time = S - 300 }), false, "someone not heard from since may still bring an earlier one")
  f.heroes[other].heard = now - 10
  c:Eq(B:Settled(f, { name = me, time = S - 300 }), true, "heard from after it: it goes out")
  f.heroes[other].heard = nil
  c:Eq(B:Settled(f, { name = me, time = S - B.SETTLE }), true, "a day later it goes out anyway")
  -- A first that waited a day keeps its place past the twenty newest clears.
  f.id, f.history = "selftest-board", {}
  for i = 1, B.NEWS + 5 do f.history[i] = { id = "run" .. i, type = "run", key = "dm", time = S - i, cleared = { other } } end
  f.heroes[other] = { deeds = { fall = S - B.SETTLE - 60 } }
  local firsts = 0
  for _, n in ipairs(B:News(f)) do if n.kind == "first" then firsts = firsts + 1 end end
  c:Eq(firsts, 1, "a first that waited is not cut with the older news")
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
  -- /dj takes its own short words, not names (7 Nov 2026: the link only toggled its window).
  c:Eq(ns.Window:JournalWord("smlib"), "smlib", "the Dungeon Journal link sends /dj its word for the dungeon")
  c:Eq(ns.Window:JournalWord("exc"), "exca", "and its own word where ours differs")
  local at = ns.QuestLists:AttuneCommand() ~= nil
  local qs = ns.Quests:QuestieState()
  local lore, spoken = ns.OtherAddons:HasLore(), ns.OtherAddons:HasSpoken()
  report().addons = { dungeonJournal = dj, attune = at, questie = qs, loreForever = lore, spoken = spoken }
  local function has(v) return v and "installed" or "not installed" end
  c:That(true, "DungeonJournal " .. has(dj) .. ", Attune " .. has(at) .. ", Questie " .. qs .. ", Lore Forever " .. has(lore)
    .. ", Spoken " .. has(spoken))
  -- The Quests page names Questie: a credit when it runs, else the recommendation (unless hidden).
  -- (On the Quest chains tab, since 6 Nov 2026: the note is about chains.)
  ns.Window:ShowPage("quests")
  local pf = ns.Window.pageFrames.quests
  local tabWas = pf.tab
  pf.tab = "chains"; ns.Window:Refresh()
  c:That(qs == "on" and pf.questie:IsShown() or qs ~= "on", "Questie credited on the Quest chains tab when running")
  pf.tab = "quests"; ns.Window:Refresh()
  c:That(not pf.questie:IsShown(), "not on the Quests tab")
  pf.tab = tabWas; ns.Window:Refresh()
  -- The story link on every dungeon's page, Lore Forever or not; without it a click says to install it (30 Oct 2026;
  -- on the Dungeon page since U96).
  ns.Window:ShowPage("chapter")
  local row
  for _, r in ipairs(ns.Window.pageFrames.chapter.rows.items) do if not row and r:IsShown() and r.key then row = r end end
  if not row then return c:That(true, "no dungeon rows in this chapter: Lore not checked") end
  ns.DungeonPage:Open(row.key)
  local more = ns.Window.pageFrames.dungeon.more
  c:That(more:IsShown(), "the story link on the Dungeon page")
  local OA = ns.OtherAddons
  if not lore and not OA:HasSpokenStory(row.key) then
    more:GetScript("OnClick")(more)
    c:That(toastSeen(nil, "Install Spoken or Lore Forever"), "with neither Spoken nor Lore Forever, a click says to install one")
  end
  -- Stories from (6 Nov 2026): Spoken first, or Lore Forever; the other stands in when the first has no story.
  local was = ns.Settings:Get("storyFrom")
  for _, pick in ipairs({ "spoken", "lore" }) do
    ns.Settings:Set("storyFrom", pick)
    local from, spokenHas = OA:StoryFrom(row.key), OA:HasSpokenStory(row.key)
    local want = pick == "lore" and (lore and "lore" or (spokenHas and "spoken") or nil)
      or (spokenHas and "spoken" or (lore and "lore") or nil)
    c:Eq(from, want, "Stories from " .. pick .. ": " .. ns.Dungeon(row.key)[2] .. " opens in")
  end
  ns.Settings:Set("storyFrom", was)
  c:That(OA:StoryTip(row.key) ~= nil, "the button says who tells it: " .. tostring(OA:StoryTip(row.key)))
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
  -- (Only the attunements of raids Blizzard has announced.)
  if #ns.ATTUNEMENTS == 0 then
    c:Eq(#QL:NewlyAvailable(side, 1, ns.LevelCap()), 0, "none in this game")
    return
  end
  local open = QL:NewlyAvailable(side, 54, 55)
  local names = {}
  for _, a in ipairs(open) do names[#names + 1] = a.name end
  -- Upper Blackrock Spire's key, in both games' lists (Molten Core waits for Blizzard's word in WoW Forever).
  c:Has(table.concat(names, ", "), "Upper Blackrock Spire", "opening at 55")
  local dqWas = ns.char.dqToasted -- (a level-up also reminds of dungeon quests, U79: put back after)
  ns.char.dqToasted = {}
  QL:OnLevelUp(55)
  ns.char.dqToasted = dqWas
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
  ns.Window.pageFrames.quests.tabs.buttons[1]:Click()
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
  -- U13: an icon on each line, and the little bar under "you". (Where to stop questing has none: it stands under your
  -- line, in line with its words; the check of 9 Nov 2026, 22:42 counted it.)
  local icons, shownLines = 0, 0
  for _, b in ipairs(TK.frame.lines) do
    if b:IsShown() and b.key ~= "stop" then shownLines = shownLines + 1; if b.icon:IsShown() then icons = icons + 1 end end
  end
  if inGame() then c:Eq(icons, shownLines, "every line has its icon") end
  c:That(content.bar ~= nil and content.bar.value >= 0 and content.bar.value <= 1, "the bar under you: a share of the way")
  if ns.Settings:TrackerLineOn("you") and not ns.char.trackerFolded then
    c:That(TK.frame.floorBar:IsShown(), "the bar shows under you")
  end
  c:That(content.next ~= nil, "a next step: " .. tostring(content.next))
  -- U159: the clears share the status line (one line less).
  local function lineText(key) for _, b in ipairs(TK.frame.lines) do if b.key == key and b:IsShown() then return b.text:GetText() end end end
  if content.status and content.clears and ns.Settings:TrackerLineOn("status") and ns.Settings:TrackerLineOn("clears") then
    c:Has(lineText("status") or "", content.clears, "the clears on the status line")
    c:Eq(lineText("clears"), nil, "and no line of their own")
  end
  c:Eq(content.next, ns.Together:Focus(cur()).head, "the Overview's Focus now (U139)")
  local early = ns.Together:StartEarly(cur())
  c:Eq(content.early, early and early.text or nil, "Prequest (U124): " .. tostring(early and early.text or "nothing now"))
  -- And with a chain step open (made up: your log may have none; the review of 9 Nov 2026 found this compared nil
  -- with nil).
  local QL, groups = ns.QuestLists, ns.QuestLists.Groups
  QL.Groups = ns.Dev.FakeChain
  local made = ns.Together:StartEarly(cur())
  local shownEarly = TK:Content(cur()).early
  QL.Groups = groups
  c:That(made ~= nil and shownEarly == made.text, "Prequest on the tracker: " .. tostring(shownEarly))
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
    if ot:IsVisible() and ot:GetLeft() then
      c:That(to == ot or to == ot.NineSlice or to == ot.Header, "anchored to the game's tracker")
    else
      -- No quests: the game hides its tracker and it has no place (6 Nov 2026: ours went to the top left corner).
      c:That(to == UIParent, "the game's tracker hidden (no quests): where it last stood, not anchored to it")
    end
    -- Never in the screen's top left corner, whatever the game's tracker does.
    local l, t = fr:GetLeft(), fr:GetTop()
    c:That(l and t and not (l < 40 and t > UIParent:GetTop() - 40), ("not in the top left corner (%s, %s)"):format(
      tostring(l and math.floor(l)), tostring(t and math.floor(t))))
    -- The game's tracker shows or hides: ours fades in at its new place, not with Reduce effects (6 Nov 2026).
    local reduce = S:Get("reduce")
    S:Set("reduce", false); TK.fadedAt = nil; TK:Follow()
    c:That(TK.fadedAt ~= nil or not fr:IsShown(), "fades in at its new place")
    S:Set("reduce", true); TK.fadedAt = nil; TK:Follow()
    c:Eq(TK.fadedAt, nil, "Reduce effects: it moves without fading")
    S:Set("reduce", reduce)
    if ot:IsCollapsed() then
      c:That(not fr:IsShown(), "the game's tracker is folded: ours folds away with it")
    else
      c:That(fr:IsShown() and fr.dock:IsShown() and not fr.bar:IsShown(), "the game's section header, not our title bar")
      -- U153: your level line on one line in the game's narrower column ("Ready, 2.6 levels to the cap" took two).
      for _, b in ipairs(fr.lines) do
        if b.key == "you" and b:IsShown() and b.text.GetNumLines then
          c:Eq(b.text:GetNumLines(), 1, "your level line on one line: " .. tostring(b.text:GetText()))
        end
      end
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

-- Ctrl and drag (the owner, 7 Nov 2026, "like Questie"). Ctrl cannot be pressed from here: a drag without it moves
-- nothing, and a drop (as after a drag with Ctrl) is made by hand. Your settings and the tracker's place are put back.
-- U92 (the check of 7 Nov 2026, 20:46): pointing at the title says how to move it; docked, the Ctrl part only.
step("the tracker: pointing at its title says how to move it", function(c)
  local fr = ns.Tracker.frame
  -- (The game's tooltip keeps its first line in GameTooltipTextLeft1; the harness's in the tooltip itself.)
  local function said() local t = _G.GameTooltipTextLeft1 or GameTooltip; return t:GetText() end
  fr.bar:GetScript("OnEnter")(fr.bar)
  c:That(GameTooltip:IsShown(), "a tooltip on the title")
  c:Eq(said(), L.TRACKER_MOVE_TIP, "Drag to move, hold Ctrl to drag by any line")
  fr.bar:GetScript("OnLeave")(fr.bar)
  if fr.dock then
    fr.dock.click:GetScript("OnEnter")(fr.dock.click)
    c:Eq(said(), L.TRACKER_MOVE_TIP_DOCK, "docked: the Ctrl part only")
    fr.dock.click:GetScript("OnLeave")(fr.dock.click)
  end
end)

step("the tracker: Ctrl and drag moves it; dropped while docked, it is its own panel there", function(c)
  local TK, S = ns.Tracker, ns.Settings
  local fr = TK.frame
  local was = { tracker = S:Get("tracker"), trackerHover = S:Get("trackerHover"), trackerDock = S:Get("trackerDock") }
  local pos = ns.char.trackerPos
  local function putBack()
    ns.char.trackerPos = pos
    for k, v in pairs(was) do S:Set(k, v) end
    TK:Place()
  end
  S:Set("tracker", true); S:Set("trackerHover", false); S:Set("trackerDock", true)
  if not fr:IsShown() then putBack() return c:That(true, "the tracker is folded away with the game's: nothing to drag") end
  local line = fr.lines[2]
  if not IsControlKeyDown() then
    -- (Code review of 1.3.0: a click that moved a little starts a drag and the game sends no OnClick; let go over
    -- the line it is the click. The line's own click is swapped for a count here, so no page opens.)
    local onClick, clicked = line:GetScript("OnClick"), 0
    line:SetScript("OnClick", function() clicked = clicked + 1 end)
    line.IsMouseOver = function() return true end
    line:GetScript("OnDragStart")(line)
    c:That(not TK.moving, "a drag on a line without Ctrl moves nothing")
    line:GetScript("OnDragStop")(line)
    c:Eq(clicked, 1, "let go over the line, it is a click")
    line.IsMouseOver = nil
    line:SetScript("OnClick", onClick)
  end
  local docked = TK:Docked()
  TK.moving = true
  TK:StopMove()
  local p = ns.char.trackerPos
  c:That(p ~= nil and p.point == "TOPLEFT" and p.x ~= nil and p.y ~= nil, "dropped: its place is kept")
  if docked then c:That(not TK:Docked() and fr.bar:IsShown(), "dropped from under the game's tracker: its own panel, with its title bar") end
  putBack()
end)

step("minimap button and toast position", function(c)
  local S = ns.Settings
  local M = ns.MinimapButton
  S:Set("minimap", false)
  -- A button collector (a bar or bag addon) may hold the LibDBIcon button and show it itself: then LibDBIcon's own
  -- hidden state is ours to check. The check of 8 Nov 2026 failed here with LibDBIcon and gave no reason; the line
  -- now names where the button sits.
  local b = M.button
  local on = b:GetParent() and b:GetParent():GetName() or "?"
  if M.dbicon and on ~= "Minimap" and b:IsShown() then
    c:That(type(ns.char.dbicon) == "table" and ns.char.dbicon.hide == true,
      "minimap button off for LibDBIcon; " .. on .. " (another addon) holds it and shows it there")
  else
    c:That(not b:IsShown(), "minimap button hidden (on " .. on .. (M.dbicon and ", made by LibDBIcon)" or ")"))
  end
  S:Set("minimap", true)
  c:That(b:IsShown(), "and back")
  -- Button collectors find it (6 Nov 2026): made by LibDBIcon when another addon loaded it, else named.
  if M.dbicon then
    c:That(M.button ~= nil, "made by LibDBIcon (another addon loaded it), which button collectors know")
  else
    c:Eq(M.button:GetName(), M.NAME, "the button has a name, so button collectors find it")
  end
  if AddonCompartmentFrame and AddonCompartmentFrame.RegisterAddon then c:That(M.compartment, "listed in the game's addon compartment") end
  ns.Toasts:StartMove()
  c:That(ns.Toasts.moving and ns.Toasts.frame:IsShown(), "move mode shows a sample banner")
  ns.Toasts:StopMove()
  ns.Toasts:ResetPosition()
  c:That(not ns.Toasts.moving, "done; position reset")
end)

-- Ctrl and drag a toast (the owner, 7 Nov 2026). As for the tracker: no Ctrl from here, the drop made by hand, your
-- toast place put back.
step("toasts: Ctrl and drag moves one while it shows; it fades where it was dropped", function(c)
  local T = ns.Toasts
  local pos = ns.char.toastPos
  T:Example()
  local f = T.frame
  if not IsControlKeyDown() then
    f:GetScript("OnDragStart")(f)
    c:That(not T.dragging, "a drag without Ctrl moves nothing (a click opens what it is about)")
  end
  T.dragging = true
  f:GetScript("OnDragStop")(f)
  c:That(not T.dragging and ns.char.toastPos ~= nil and ns.char.toastPos.point ~= nil, "dropped: its place is kept")
  c:Eq(f.fadeIn:GetDuration(), 0, "it shows its time again without fading in once more")
  -- (Reduce effects, or that example's kind turned off: no next toast to look at.)
  if T:Example() == "shown" then c:That(f.fadeIn:GetDuration() > 0, "the next toast fades in as usual") end
  -- Code review of 1.3.0: a toast that came during a drag shows at the drop; hidden while dragged, the drag is let go;
  -- a drag the game never ended (the button is up now) does not stop the next toast.
  local ex = T.EXAMPLES[1]
  T.dragging, T.waiting = true, { kind = ex[1], title = ex[2], text = ex[3] }
  f:GetScript("OnDragStop")(f)
  c:That(not T.waiting and f.title:GetText() == ex[2], "a toast that came during the drag shows when it is dropped")
  f:Show(); T.dragging = true
  f:Hide()
  c:That(not T.dragging, "hidden while dragged: the drag is let go")
  T.dragging = true
  if IsMouseButtonDown and T:Example() == "shown" then c:That(not T.dragging and f:IsShown(), "a drag the game never ended does not stop the next toast") end
  T.dragging = nil
  ns.char.toastPos = pos
  T:Place()
  f.anim:Stop(); f:Hide()
end, 1)

-- U2: the big moments start mid-screen and slide to the toasts' place; any other toast shows there at once.
step("toasts: a big moment starts mid-screen, then slides to its place", function(c)
  local T = ns.Toasts
  if T:Push("chapter", "Chapter test", "Mid-screen first") ~= "shown" then return end
  local f = T.frame
  local p, _, _, _, y = f:GetPoint()
  c:Eq(p, "CENTER", "in the middle of the screen")
  c:Eq(y, T.MID_Y, "a little above the centre, as the game's Level Up banner")
  c:That(T.mid ~= nil, "waiting to slide")
  if T:Push("heroFloor", "Toast test", "At its place at once") == "shown" then
    c:That(T.mid == nil, "a normal toast ends the slide")
    if not ns.char.toastPos then c:Eq(f:GetPoint(), "TOP", "and shows at the toasts' place") end
  end
  T.mid = nil; T:Place()
  f.anim:Stop(); f:Hide()
end, 1)

step("the Endgame: raids open after the journey", function(c)
  local f = cur()
  local E = ns.Endgame
  ST.reached = f.reached
  f.reached = #f.journey.chapters + 1
  c:That(E:Open(f), "the Endgame is open")
  c:That(ns.Pages:InNav("raids", ns.Pages:Context()), "Raids in the sidebar")
  for _, n in ipairs(PRETEND) do dev("group " .. n) end
  local before = f.rules.minHeroes
  -- The raid of this game with the most bosses in its data (WoW Forever: Onyxia's Lair),
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
  local pf = ns.Window.pageFrames.raids
  -- A raid the game has no boss list for (WoW Forever's Barrow Deeps until its first kill): said under Bosses.
  for _, r in ipairs(ns.RAIDS) do
    if #E:BossProgress(f, r[1]) == 0 then
      pf.raid = r[1]; ns.Window:Refresh()
      c:That(pf.noBosses:IsShown(), r[2] .. ": no boss list yet, and the page says so")
      break
    end
  end
  pf.raid = key
  ns.Window:Refresh()
  c:That(not pf.noBosses:IsShown(), raid[2] .. ": its bosses, no note")
end, 1)

shot("raids")

-- U63 (7 Nov 2026): a raid not open yet shows its picture large and a countdown on the right page.
step("the Endgame: a raid not open yet shows its picture and the countdown", function(c)
  local key
  for _, r in ipairs(ns.RAIDS) do if ns.Opens(r[1]) and not ns.IsOpen(r[1], cur()) then key = r[1] break end end
  if not key then return c:That(true, "every raid of this game is open: nothing to count down") end
  ns.Window:ShowPage("raids")
  local pf = ns.Window.pageFrames.raids
  pf.raid = key; ns.Window:Refresh()
  c:That(pf.soon:IsShown(), ns.Raid(key)[2] .. ": its picture, large")
  c:Has(pf.soon.text:GetText() or "", ns.OpensText(key), "the countdown names the day")
  -- U89: the card's ribbon counts down; the card says no date.
  for _, k in ipairs(pf.cards.items) do
    if k:IsShown() and k.name:GetText() == ns.Raid(key)[2] then
      c:That(not (k.state:GetText() or ""):find(ns.OpensText(key), 1, true), "the ribbon counts down: " .. (k.state:GetText() or ""))
      c:That(not (k.info:GetText() or ""):find(ns.OpensText(key), 1, true), "and the card says no date")
    end
  end
  pf.raid = nil
end)

step("the Endgame closes again (the journey is not done)", function(c)
  local f = cur()
  f.reached = ST.reached
  ns.Clears.recent = {}
  if ST.raid and ns.db.opened then ns.db.opened[ST.raid] = ST.raidOpened end
  c:That(not ns.Endgame:Open(f) or ns.Journey:CurrentIndex(f) > #f.journey.chapters, "closed")
  ns.Window:ShowPage("overview")
end)

-- U165 (the owner, 9 Nov 2026: "Same options for Raids"): Settings → Raids page.
step("the Endgame: Settings, Raids page: Show all puts Raids in the sidebar before the journey is complete (U165)", function(c)
  local P, S, W = ns.Pages, ns.Settings, ns.Window
  local was = S:Get("raidsShow")
  S:Set("raidsShow", "open")
  c:Eq(P:InNav("raids", P:Context()), ns.Endgame:Open(cur()), "Only open ones: Raids once the journey is complete")
  S:Set("raidsShow", "all")
  c:That(P:InNav("raids", P:Context()), "Show all: Raids in the sidebar")
  W:ShowPage("raids")
  c:Eq(W.current, "raids", "the Raids page opens")
  if not ns.Endgame:Open(cur()) then
    c:Has(W.pageFrames.raids.help:GetText() or "", L.RAIDS_HELP_EARLY:match("^[^;]+"), "it says when the raids open")
    local card = W.pageFrames.raids.cards:Get(1)
    c:That(card and not card.group:IsShown(), "no Find group before the journey is complete")
  end
  S:Set("raidsShow", was)
  W:ShowPage("overview")
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

-- The duel banner (the owner, 6 Nov 2026): the winner's name in gold, and a duel decided since you last looked
-- gleams once.
step("tournament: the winner in gold, a new result gleams once", function(c)
  local pf = ns.Window.pageFrames.tourney
  ns.char.tourneySeen = nil
  local reduce = ns.Settings:Get("reduce")
  ns.Settings:Set("reduce", false)
  pf.gleamed = nil
  ns.Window:ShowPage("tourney")
  c:That(pf.gleamed ~= nil, "a result you had not seen gleams")
  pf.gleamed = nil
  ns.Window:Refresh()
  c:Eq(pf.gleamed, nil, "once")
  local won
  for _, x in ipairs(pf.cards.items) do
    for _, l in ipairs({ x.l1, x.l2 }) do if x:IsShown() and l.band:IsShown() then won = won or l end end
  end
  if won then
    local r, g, b = won.name:GetTextColor()
    local wr, wg, wb = ns.Theme:RGBA(ns.Theme:Current().light and "8A5A10" or "F2C25B")
    c:That(math.abs(r - wr) + math.abs(g - wg) + math.abs(b - wb) < 0.02, "the winner's name in gold")
  else
    c:That(false, "a winner on a card")
  end
  -- The champion's card: a gold cup at both ends (U48), where the Props art loads.
  c:Eq(#pf.champ.cups, 2, "two cups on the champion's card")
  for i, cup in ipairs(pf.champ.cups) do c:That(not cup:IsShown() or cup:GetTexture() ~= nil, "cup " .. i .. " has its art") end
  ns.Settings:Set("reduce", reduce)
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

-- An Adventurer who joined lately had a welcome card until the rebuild (U146, 9 Nov 2026): the To do and the first
-- tour show them the way now; only a new Leader's first steps head the To do.
step("getting started as an Adventurer: the To do starts at the floor, no welcome card", function(c)
  local f, T, W = cur(), ns.Together, ns.Window
  ns.Fellowship:MakeLeader(full("Brannic"))
  c:Eq(T:Started(f), nil, "no first steps for an Adventurer")
  local todo = T:ToDo(f, ns.Journey:CurrentIndex(f))
  c:Eq(todo[1] and todo[1].kind, "floor", "the To do starts at the floor")
  W:ShowPage("overview")
  c:That(W.pageFrames.overview.start == nil, "no welcome card on the Overview")
  opFrom("Brannic", { k = "lead", name = ns.Me() })
  c:Eq(f.leader, ns.Me(), "you lead again")
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

-- The game's HDR output dimmed the check of 7 Nov 2026: the tour turns it off for its screenshots (Dev/Tour.lua).
-- Here only read, not switched: the tour's own record says whether it was off for them.
step("screenshots: the game's HDR output, and nothing left to put back from a tour", function(c)
  local v = C_CVar and C_CVar.GetCVar and C_CVar.GetCVar("HDROutput")
  c:That(true, v and ("HDR output: %s (the tour turns it off for its screenshots)"):format(v) or "no HDR setting in this client")
  c:Eq(ns.db.hdrWas, nil, "no HDR value waiting to be put back")
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
  c:That(not rp.editBar:IsShown() and not rp.propose:IsShown(), "no Propose, no Edit the rules")
  Win:ShowPage("heroes")
  c:That(not Win.pageFrames.heroes.leave:IsShown(), "no Leave")
  Win:ShowPage("chapter")
  local card = Win.pageFrames.chapter.rows.items[1]
  c:That(card and not card.group:IsShown() and not card.menu:IsShown(), "no Find group or Mark cleared")
  dev("watch level")
end, 2)

-- U68 (7 Nov 2026): an alt made since the main last logged in shows the account's mark and is answered at once.
step("watch: an alt made since the main last played shows the account's mark", function(c)
  local W, f = ns.Watch, cur()
  local mark = W:Mark()
  c:That(type(mark) == "string" and #mark == 16, "this account has a mark")
  c:Eq(ns.Hero:MyState().mark, mark, "shared with the state")
  local mine = ns.Hero:Get(f, ns.Me())
  local was = mine and mine.mark
  if mine then mine.mark = mark end
  local stranger = full("Selftest Newalt")
  c:That(W.Allowed(f, stranger, mark) and not W.Allowed(f, stranger, "someoneelse00000"), "Your character with the mark may follow; others not")
  if mine then mine.mark = was end
end)

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

-- U88 (the check of 7 Nov 2026, 17:25): the offer sits beside the book, over nothing on the page.
step("walkthrough: the offer sits beside the book", function(c)
  local WK, Win = ns.Walkthrough, ns.Window
  -- (Later marks the offer as answered: put back after the step.)
  local walk = ns.char.walk and ns.Serialize.Decode(ns.Serialize.Encode(ns.char.walk))
  c.undo = function() ns.char.walk = walk end
  Win:ShowPage("overview")
  c:That(WK:Offer("leader"), "Show me around? offered")
  local card, you = WK.card, Win.pageFrames.overview.focus
  c:That(card:GetPoint(1) ~= "CENTER", "not in the middle of the book")
  if inGame() and not Win:IsFullscreen() then
    local cs, ys = card:GetEffectiveScale(), you:GetEffectiveScale()
    local apart = card:GetLeft() * cs >= you:GetRight() * ys or card:GetRight() * cs <= you:GetLeft() * ys
      or card:GetTop() * cs <= you:GetBottom() * ys
    c:That(apart, "Focus now stays in sight")
  end
  WK:Later()
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

-- The first tour (the owner, 8 Nov 2026: the whole book at once was too long; What's New covered it). No page shows you
-- around by itself since the rebuild (U146): its ? does.
step("walkthrough: the first tour is short; no page tours by itself; What's New waits", function(c)
  local WK, Win, N = ns.Walkthrough, ns.Window, ns.News
  local walk = ns.char.walk and ns.Serialize.Decode(ns.Serialize.Encode(ns.char.walk))
  c.undo = function() ns.char.walk = walk end
  c:That(WK:Start(WK:MyRank(), nil, true), "the first tour started")
  c:Yield()
  local list = {}
  for _, s in ipairs(WK.steps) do list[#list + 1] = s.id end
  c:Eq(table.concat(list, ","), "INTRO,NAV,FOCUS,SINCE,COMING,STAND,HEADER,TRACKER,DONE", "the Overview and what you see first")
  c:That(N:Busy(), "What's New waits while a tour runs")
  WK:Go(#WK.steps)
  c:Eq(WK.card.title:GetText(), L.WALK_FIRSTDONE_T, "its own end")
  WK:Next()
  c:That(not WK.on, "over")
  c:That(not N:Busy(), "then What's New may come")
  Win:ShowPage("chapter")
  c:That(not WK.on, "a page opened for the first time: no tour by itself")
  c:That(Win.frame.header.help:IsShown(), "its ? is one click away")
  Win:ShowPage("overview")
end)

-- About this page (the owner, 7 Nov 2026): the header's ? on every page this character can open now.
step("page help: the header's ? walks each page, its left page then its right page (the Overview part by part), and stays there", function(c)
  local WK, Win = ns.Walkthrough, ns.Window
  local walk, done, framed = ns.char.walk, 0, 0
  for id in pairs(WK.PAGES) do
    -- The Dungeon page opens with its dungeon (U96).
    if id == "dungeon" then ns.DungeonPage:Open(listedDungeon() or "dm") else Win:ShowPage(id) end
    if Win.current == id then
      c:That(Win.frame.header.help:IsShown(), id .. ": the ? in the header")
      c:That(WK:StartPage(), id .. ": started")
      if WK.glow:IsShown() then framed = framed + 1 end
      local parts = WK.PARTS[id] or { { "" }, { "_R" } }
      for k, p in ipairs(parts) do
        c:Eq(WK.card.title:GetText(), L["WALK_PG_" .. id:upper() .. p[1] .. "_T"], ("%s: %d of %d"):format(id, k, #parts))
        WK:Next()
      end
      c:That(not WK.on and Win.current == id, id .. ": closed, still on the page")
      done = done + 1
    end
    c:Yield()
  end
  c:That(done >= 10, done .. " pages walked")
  c:That(framed > 0, framed .. " with their left page framed")
  c:Eq(ns.char.walk, walk, "the tour is offered as before")
  Win:ShowPage("overview")
end)

-- U166 (the owner, 10 Nov 2026: "a bug report button like dungeon journal has it").
step("report a bug: the header's bug opens where to report, with the version, and closes again (U166)", function(c)
  local Win, Cw = ns.Window, ns.ConflictWindow
  local h = Win.frame.header
  Win:ShowPage("overview")
  c:That(h.bug:IsShown(), "the bug in the header")
  local _, rel = h.bug:GetPoint(1)
  c:That(rel == h.help, "left of the ?")
  c:That(h.bug.icon:GetTexture() ~= nil, "its icon shows")
  c:Eq(ns.UI.icons[h.bug.icon], ns.ICONS.bug, "Blizzard's bug, the one its issue reporter uses (not the spare)")
  click(h.bug)
  local o = Win.overlays and Win.overlays.bug
  c:That(o and o:IsShown(), "it opens")
  if o then
    c:Eq(o.title:GetText(), L.BUG_T, "its title")
    c:Has(o.ver:GetText() or "", ns.VERSION or "?", "your version")
    c:Eq(o.gh:GetText(), Cw.GITHUB, "GitHub's issues")
    c:Eq(o.cf:GetText(), Cw.CURSEFORGE, "the CurseForge page's comments")
    shot("bug-report")
    click(h.bug)
    c:That(not o:IsShown(), "a second click closes it")
  end
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
  -- U86: the toast lines under three headings, each line under one.
  c:Eq(#pf.toastHeads, 3, "the toasts under three headings")
  c:Eq(pf.toastHeads[1]:GetText(), L.TOAST_GROUP_JOURNEY:upper(), "Your journey first")
  local rows = 0
  for _ in pairs(pf.toastRows) do rows = rows + 1 end
  c:Eq(rows, #ns.Settings.TOAST_EVENTS, "every toast line once")
  -- U116: a tick on each heading turns its whole group; it follows the lines under it.
  local Set, grp = ns.Settings, ns.Settings.TOAST_GROUPS[3]
  local kept = {}
  for _, k in ipairs(Set.TOAST_EVENTS) do kept[k] = Set:ToastOn(k) end
  local head = pf.toastHeads[3]
  c:That(head.box ~= nil and head.box:IsShown(), "a tick on the Dungeons and raids heading (U116)")
  if head.box then
    head.box:SetChecked(false); click(head.box)
    local off = 0
    for _, k in ipairs(grp[2]) do if not Set:ToastOn(k) then off = off + 1 end end
    c:Eq(off, #grp[2], "unticked: the whole group is off")
    c:That(not pf.toastRows[grp[2][1]]:GetChecked(), "and its lines show it")
    c:That(Set:ToastOn(ns.Settings.TOAST_GROUPS[1][2][1]), "the other groups stay as they were")
    click(pf.toastRows[grp[2][1]])
    c:That(not head.box:GetChecked(), "one line on: the group's tick stays off until all are")
    head.box:SetChecked(true); click(head.box)
    c:That(head.box:GetChecked() and pf.toastRows[grp[2][2]]:GetChecked(), "ticked: all on again")
    if inGame() then c:That(head.box:GetLeft() >= pf.right:GetLeft() - 4, "the tick on the page, in line with the ticks under it") end
  end
  for k, v in pairs(kept) do Set:SetToast(k, v) end
  ns.Window:Refresh()
  -- (The check of 8 Nov 2026: "Time to leave room for the dungeon quests" ran past the sheet.)
  if inGame() then
    for kind, box in pairs(pf.toastRows) do
      local lab = box:GetParent().label
      if lab:GetRight() > pf.right:GetRight() + 1 then c:That(false, kind .. ": its line ends on the page") end
    end
  end
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

-- U139: the Overview fits without scrolling in full screen too (U87 moved its Recent history there until the rebuild).
step("screen: the Overview fits without scrolling, in a window and in full screen", function(c)
  local W, S = ns.Window, ns.Settings
  local was = S:Get("fullscreen")
  c.undo = function() S:Set("fullscreen", was); W:Refresh() end
  W:ShowPage("overview")
  for _, fs in ipairs({ false, true }) do
    S:Set("fullscreen", fs); W:Refresh()
    c:That(W.current == "overview", fs and "full screen" or "a window")
    if inGame() then overviewFits(c, fs and "full screen" or "a window") end
  end
  S:Set("fullscreen", was); W:Refresh()
end)

-- 1.2.1 left the dimmed screen over the game after a login in full screen, the book closed (hotfix 1.2.2): dark, and
-- every click caught. Only an open book in full screen dims the screen.
step("screen: the screen is dimmed only behind an open book in full screen", function(c)
  local W = ns.Window
  c:Eq(W.frame.backdrop:IsShown(), W:IsOpen() and W:IsFullscreen(), "dimmed now: only with the book open in full screen")
  -- (Closing the book here would end the walkthrough and a watch: sized again only when it is closed already.)
  if not W:IsOpen() then
    W:ApplyScale()
    c:Eq(W.frame.backdrop:IsShown(), false, "the book closed and sized again: nothing dimmed")
  end
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

-- WoW Forever: a whole name is one in the region and the game reads the hyphen as the space, so there is no other
-- realm to refuse (check of 6 Nov 2026: 0 connected realms there, and the invite was sent).
step("realms: no realm is refused, a hyphen is part of the name", function(c)
  report().realms = GetAutoCompleteRealms and GetAutoCompleteRealms()
  c:Eq(ns.Fellowship:Invite("Jtfnobody-Jtfnorealm"), "sent", "no realms to refuse, the name is the whole name")
  for key in pairs(cur().invites or {}) do if key:find("^Jtfnobody") then ns.Fellowship:CancelInvite(key) end end
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

-- Lighter in game (U71, U75, U76; 7 Nov 2026): a message for many is packed once; the lighter packer writes the same
-- text as before; quests and gear wait for those the game said are offline. Checked on a queue of its own.
step("sync: packed once for many, the same text, nothing to those offline", function(c)
  local C, S = ns.Comm, ns.Serialize
  c:Eq(S.Encode({ 1, "a;b|c", x = true, [2.5] = { n = -3 } }), "{d1;d1;d2;sa\\sb\\pc;d2.5;{sn;d-3;}sx;t}", "the packer's text is unchanged")
  local odd = S.Decode(S.Encode({ "a\28", "b" }))
  c:That(odd and odd[1] == "a\28" and odd[2] == "b", "a text ending in control byte 28 reads back whole")
  local encode, n, q = S.Encode, 0, C.queue
  S.Encode = function(...) n = n + 1; return encode(...) end
  C.queue = {}
  C:SendAll({ full("Selftest One"), full("Selftest Two"), full("Selftest Three") }, "SELFTEST", { n = 1 })
  S.Encode = encode
  c:Eq(n, 1, "three players, packed once")
  c:Eq(#C.queue, 3, "and queued for each")
  C.queue = q
  local f = cur()
  local name = f and next(f.members)
  if name and name ~= ns.Me() then
    f.heroes[name] = f.heroes[name] or {}
    local was = f.heroes[name].offline
    f.heroes[name].offline = true
    local listed = false
    for _, x in ipairs(ns.Hero:Reachable(f)) do if x == name then listed = true end end
    f.heroes[name].offline = was
    c:That(not listed, "an Adventurer the game said is offline gets no quests or gear")
  end
end)

-- U70 (7 Nov 2026): /jtf perf times JTF's busiest jobs and reads the game's profiler for it.
step("sync: the performance report times JTF's jobs", function(c)
  c:That((ns.Dev.perfWrapped or 0) >= 8, ("%d of %d jobs timed"):format(ns.Dev.perfWrapped or 0, #ns.Dev.PERF_JOBS))
  local before = ns.db.perf and ns.db.perf.jobs and ns.db.perf.jobs.page and ns.db.perf.jobs.page.n or 0
  ns.Window:Refresh()
  c:Eq(ns.db.perf.jobs.page.n, before + 1, "a page drawn is counted")
  local m = ns.Dev:PerfMetrics()
  c:That(true, m and ("the game's profiler: worst %.1f ms"):format(m.PeakTime or 0) or "this client has no addon profiler")
  ns.Dev:Perf()
end)

-- U73 (7 Nov 2026): a level-up's jobs each wait their own moment, the state first, all within two seconds.
step("sync: a level-up's jobs run one after another, not all at once", function(c)
  local t, seen, last = ns.LEVEL_UP, {}, 0
  for _, k in ipairs({ "state", "characters", "race", "attune" }) do
    c:That(t[k] and t[k] > last and not seen[t[k]], k .. " waits " .. tostring(t[k]) .. " s, after the one before")
    seen[t[k] or 0], last = true, t[k] or last
  end
  c:That(last <= 2, "all within two seconds")
end)

-- U74 (7 Nov 2026): news from others redraws at most once a second, and a quest list only a page that shows it.
step("sync: a quest list does not redraw the Overview; other news waits up to a second", function(c)
  local W = ns.Window
  c:Eq(W.SOON, 1, "news redraws once a second at most")
  if W.soon then return c:That(true, "a redraw was already on its way; nothing to check now") end
  W.page = "overview"; W:Open(); W:Refresh()
  W:RefreshSoon("quests")
  c:That(not W.soon, "a quest list arriving waits for no redraw on the Overview")
  c:That(ns.Pages:Get("quests").news.quests and ns.Pages:Get("chapter").news.quests, "the Quests and Chapter pages show quest lists")
  W:RefreshSoon()
  c:That(W.soon, "a level arriving redraws, once")
end)

-- U60 (6 Nov 2026): three lanes for long messages, short ones first. Checked on a queue of its own (nothing is sent).
step("sync: three lanes, and a change goes before a long copy to someone else", function(c)
  local C = ns.Comm
  local reg = C_ChatInfo and C_ChatInfo.IsAddonMessagePrefixRegistered
  if reg then c:That(reg("JTF2") and reg("JTF3"), "the lanes JTF2 and JTF3 are registered") end
  local a, b = full("Selftest Lanes"), full("Selftest Other")
  local q = C.queue
  C.queue, C.peers[a] = {}, C.LANES
  C:Send(a, "SELFTEST", { text = string.rep("x", 3000) })
  C:Send(b, "SELFTEST", { n = 1 })
  local first, part = C.queue[1], C.queue[2]
  c:Eq(first and first.target, b, "the short message goes first")
  c:That(part and part.seq ~= nil, "then the long one's parts")
  C:Send(a, "SELFTEST", { n = 2 })
  c:Eq(C.queue[#C.queue].target, a, "a short one to the same player keeps its place after the long one")
  c:That(part and C:PickLane(part) ~= nil, "a lane is free for a part")
  c:Eq(first and C:PickLane(first), (C.lane[1].tokens >= 1) and 1 or nil, "a short message keeps to JTF")
  C.queue, C.peers[a] = q, nil
  ns.Dev:SyncInfo()
end)

-- The ponytail audit of 6 Nov 2026: a quest list went to every Adventurer every 15 s while questing; in a dungeon,
-- where messages wait, they piled up in front of every change. Only the newest waits now, and the links between quests
-- (about half of a list) go only when they changed.
step("sync: only the newest quest list waits for each Adventurer; links only when changed", function(c)
  local C, Q = ns.Comm, ns.Quests
  local a, q = full("Selftest Lanes"), C.queue
  C.queue = {}
  for i = 1, 3 do C:Send(a, "SELFTESTQ", { n = i }, false, true) end
  c:Eq(#C.queue, 1, "three lists, one waits")
  c:Eq(C.queue[1] and C.queue[1].msg, "SELFTESTQ:" .. ns.Serialize.Encode({ n = 3 }), "the newest one")
  c:That(C:Waiting(a, "SELFTESTQ") and not C:Waiting(a, "QUESTS"), "what waits, by its tag")
  C.queue = q
  local sent, send = {}, C.SendAll
  C.SendAll = function(_, _, tag, data, _, replace) if tag == "QUESTS" then sent[#sent + 1] = { data = data, replace = replace } end end
  Q.lastKey, Q.lastLinks = nil, nil
  Q:Send()
  local first = sent[1]
  sent, Q.lastKey = {}, nil
  Q:Send()
  C.SendAll = send
  c:That(first ~= nil and first.replace == true, "a quest list takes the place of the one still waiting")
  c:That(first ~= nil and first.data.ln ~= nil, "the first one carries the links")
  c:That(sent[1] ~= nil and sent[1].data.ln == nil, "the next one, links unchanged, does not")
end)

-- Real-time sync (the owner, 6 Nov 2026): outside instances whispers wait only for the byte limit; long messages are
-- packed with the game's deflate. The packing is checked over the wire too: a packed message to yourself.
step("sync: whispers outside instances wait only for the byte limit; long messages packed", function(c)
  local C = ns.Comm
  c:Eq(C:Free(), not IsInInstance(), "no per-prefix wait outside instances")
  c:Eq(C.Z, 1, "this game can pack (C_EncodingUtil)")
  local all = {}
  for i = 0, 255 do all[#all + 1] = string.char(i) end
  local text = table.concat(all):rep(8)
  local packed = C:Pack(text)
  c:That(packed ~= nil and not packed:find("\0", 1, true), "packed, with no NUL (addon messages cannot carry it)")
  c:Eq(packed and C:Unpack(packed), text, "every byte back as it was")
  local copy = ns.Serialize.Encode(cur())
  local p = C:Pack(copy)
  c:That(p ~= nil and #p < #copy, ("the fellowship copy: %d bytes, packed %d"):format(#copy, p and #p or 0))
  -- Over the wire: to yourself, read back in the next step.
  ST.packedGot = nil
  C:On("SELFTESTZ", function(_, d) ST.packedGot = d end)
  C.packs[ns.Me()] = 1
  ST.packedText = ("Packed over the wire. "):rep(150)
  C:Send(ns.Me(), "SELFTESTZ", { text = ST.packedText })
end, 3)

step("sync: the packed message to yourself arrived whole", function(c)
  -- (The test harness delivers no whispers during the self-test: there it is checked by tests/test_sync_speed.lua.)
  if inGame() then c:Eq(ST.packedGot and ST.packedGot.text, ST.packedText, "arrived and unpacked")
  else c:That(true, "over the wire in the game only") end
  ns.Comm.packs[ns.Me()] = nil
  ns.Comm:On("SELFTESTZ", nil)
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
  -- U59: Select the report selects it and says what to press.
  c:That(o and o.select:IsShown(), "Select the report shows")
  if o then o.select:Click() end
  c:Eq(o and o.selected:GetText(), L.CONFLICT_SELECTED, "it says Selected: press Ctrl+C")
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
    members = { [s] = {}, [ns.Me()] = {} }, rules = {}, journey = ns.BuildJourney("forever") } })
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
  ns.Dev.pretendNames = nil -- a step that stopped halfway must not leave its pretend names in the invite box
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
      framed = more and more.framed or nil, sound = more and more.sound or nil, big = more and more.big or nil }
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
      -- What a step stood in for is put back, also after an error (c.undo).
      local okUndo, eUndo = pcall(c.undo or function() end)
      if not okUndo then c.bad = true; c.lines[#c.lines + 1] = "ERROR: " .. tostring(eUndo) end
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
