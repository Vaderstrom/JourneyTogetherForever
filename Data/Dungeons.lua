-- Dungeons of WoW Forever (from the mockup's DUNGEONS; Dire Maul West and North added 30 Oct 2026, when Forever's
-- Dungeon Finder listed them: optional in the last Classic chapter, at Dire Maul East's levels, as the game tunes the
-- three wings alike; Ragefire Chasm, which the mockup left out, optional in the first chapter: "Make it so that the
-- clients available dungeons are present", the owner, 30 Oct 2026; Shaper's Terrace, the ninth new dungeon Blizzard
-- announced, mandatory in the last chapter, the owner's choice of 30 Oct 2026). The whole catalog: each game keeps what
-- it offers (ns.KeepThisGame below).
-- { key, name, best level from, best level to, chapter in the Classic preset (0 = none), role }
-- role: "m" mandatory, "b" bridge (may be run in the chapter before), "o" optional.
local _, ns = ...

ns.DUNGEONS = {
  { "hot", "Hall of Thanes", 14, 17, 1, "m" }, { "rol", "Ruins of Lordaeron", 17, 20, 1, "m" }, { "dm", "The Deadmines", 18, 21, 1, "m" },
  { "wc", "Wailing Caverns", 19, 22, 2, "b" }, { "sfk", "Shadowfang Keep", 22, 25, 2, "m" }, { "bfd", "Blackfathom Deeps", 24, 27, 3, "b" },
  { "stocks", "The Stockade", 25, 28, 3, "m" }, { "exc", "Excavation Site", 27, 31, 4, "b" }, { "dal", "City of Dalaran", 29, 32, 4, "m" },
  { "rfk", "Razorfen Kraul", 29, 32, 4, "o" }, { "gnomer", "Gnomeregan", 31, 34, 5, "b" }, { "smlib", "SM: Library", 33, 36, 5, "m" },
  { "smgy", "SM: Graveyard", 31, 34, 5, "o" }, { "drown", "The Drowned City", 36, 39, 6, "b" }, { "smarm", "SM: Armory", 37, 40, 6, "m" },
  { "smcath", "SM: Cathedral", 37, 40, 6, "m" }, { "rfd", "Razorfen Downs", 38, 41, 6, "o" }, { "krol", "Krol'dok Stronghold", 40, 44, 7, "m" },
  { "ulda", "Uldaman", 44, 46, 8, "b" }, { "zf", "Zul'Farrak", 45, 48, 8, "m" }, { "mara", "Maraudon", 47, 50, 9, "m" },
  { "alcaz", "Alcaz Prison", 49, 52, 10, "m" }, { "st", "Sunken Temple", 51, 54, 11, "m" }, { "brd", "Blackrock Depths", 53, 58, 12, "m" },
  { "bmh", "Blackmaw Hold", 55, 58, 13, "b" }, { "lbrs", "Lower Blackrock Spire", 57, 60, 14, "m" },
  { "dme", "Dire Maul: East", 57, 60, 14, "m" }, { "dmw", "Dire Maul: West", 57, 60, 14, "o" },
  { "dmn", "Dire Maul: North", 57, 60, 14, "o" }, { "strat", "Stratholme", 58, 60, 14, "m" }, { "scholo", "Scholomance", 58, 60, 14, "m" },
  { "ubrs", "Upper Blackrock Spire", 60, 60, 14, "o" }, { "rfc", "Ragefire Chasm", 13, 18, 1, "o" },
  { "shaper", "Shaper's Terrace", 58, 60, 14, "m" },
}

-- The raids of the Endgame (M18, SPEC §2): { key, name, level, size, attunement key (Data/QuestLists.lua) or nil }.
-- Not part of the journey's chapters: they open for the fellowship when the journey is complete. WoW Forever's own
-- raids (Barrow Deeps, Hyjal Summit) came in on 30 Oct 2026 from Blizzard's raid overview; the Classic ones stay in
-- the catalog for retail and for the day WoW Forever announces them (ns.FOREVER_SCHEDULE).
ns.RAIDS = {
  { "zg", "Zul'Gurub", 58, 20 }, { "barrow", "Barrow Deeps", 60, 10 }, { "hyjal", "Hyjal Summit", 60, 20 },
  { "ony", "Onyxia's Lair", 60, 40, "ony" }, { "mc", "Molten Core", 60, 40, "mc" },
  { "bwl", "Blackwing Lair", 60, 40, "bwl" }, { "aq20", "Ruins of Ahn'Qiraj", 60, 20 },
  { "aq40", "Temple of Ahn'Qiraj", 60, 40 }, { "naxx", "Naxxramas", 60, 40, "naxx" },
}

function ns.Raid(key)
  for _, r in ipairs(ns.RAIDS) do if r[1] == key then return r end end
end

-- A dungeon can be placed in more than one chapter of a journey, each placement with its own needed bosses (Blackrock
-- Depths in Classic: the first half of its bosses in chapter XII, the rest in XIII; decided 27 Oct 2026, when the
-- two "parts" became one dungeon). A placement's key is the dungeon's key, or the key and "#2", "#3"... for the next
-- ones. Kills, clears and history are kept per placement; names, pictures, quests and the game's bosses per dungeon.
-- Old keys of saved journeys: the two parts of Blackrock Depths.
ns.KEY_ALIAS = { brd1 = "brd", brd2 = "brd#2" }

-- The dungeon of a placement key ("brd#2" -> "brd"; old keys too).
function ns.BaseKey(key)
  if type(key) ~= "string" then return key end
  key = ns.KEY_ALIAS[key] or key
  return (key:gsub("#%d+$", ""))
end

-- A dungeon, or a raid (as { key, name, level, the game's cap } so names and levels read the same way). Takes
-- placement keys. Only this game's (nil for a dungeon it lacks).
function ns.Dungeon(key)
  key = ns.BaseKey(key)
  for _, d in ipairs(ns.DUNGEONS) do if d[1] == key then return d end end
  local r = ns.Raid(key)
  if r then return { r[1], r[2], r[3], math.max(r[3], ns.LevelCap and ns.LevelCap() or 60) } end
end

-- Is key a dungeon or raid of any game: one of the catalog, or a retail Adventure Guide entry ("j" and its journal
-- ID)? Journeys keep the placements of dungeons this game lacks; the pages skip them while it lacks them (30 Oct
-- 2026, the owner: Classic chapters that lose their dungeon finish on level, and it slots back in when the game adds
-- it).
function ns.KnownKey(key)
  key = ns.BaseKey(key)
  if type(key) ~= "string" then return false end
  if key:match("^j%d+$") then return #key <= 8 end
  for _, list in ipairs({ ns.ALL_DUNGEONS or ns.DUNGEONS, ns.ALL_RAIDS or ns.RAIDS }) do
    for _, d in ipairs(list) do if d[1] == key then return true end end
  end
  return false
end

-- The Classic journey's splits of one dungeon over chapters: { dungeon = { { ch, boss names... }, ... } }. The first
-- part takes the dungeon's key, the next ones "#2", "#3".
ns.DUNGEON_SPLITS = {
  brd = {
    { ch = 12, "High Interrogator Gerstahn", "Lord Roccor", "Houndmaster Grebmar", "Ring of Law", "Pyromancer Loregrain",
      "Lord Incendius", "Warder Stilgiss", "Fineous Darkvire", "Bael'Gar", "General Angerforge" },
    { ch = 13, "Golem Lord Argelmach", "Hurley Blackbreath", "Phalanx", "Ribbly Screwspigot", "Plugger Spazzring",
      "The Vault", "Ambassador Flamelash", "The Seven", "Magmus", "Princess Moira Bronzebeard", "Emperor Dagran Thaurissan" },
  },
}

-- The placement key of part i of a split ("brd", "brd#2").
function ns.PartKey(key, i) return i == 1 and key or (key .. "#" .. i) end

-- Where each dungeon is: its instance ID (GetInstanceInfo) in Data/Encounters.lua. When several dungeons share one
-- instance (the Scarlet Monastery wings, Lower and Upper Blackrock Spire, Dire Maul), the names after the ID are
-- that dungeon's bosses; when no name matches (retail's versions), all are used.
-- Dungeons not in the game's data yet have no entry: their bosses are learned on the kill (Fellowship/Clears.lua).
ns.DUNGEON_MAPS = {
  hot = { 3065 }, rol = { 2999 }, dm = { 36 }, wc = { 43 }, sfk = { 33 }, bfd = { 48 }, stocks = { 34 }, exc = { 2998 },
  dal = { 2959 }, rfk = { 47 }, gnomer = { 90 }, rfd = { 129 }, ulda = { 70 }, zf = { 209 }, mara = { 349 }, st = { 109 },
  strat = { 329 }, scholo = { 289 }, rfc = { 389 },
  zg = { 309 }, ony = { 249 }, mc = { 409 }, bwl = { 469 }, aq20 = { 509 }, aq40 = { 531 }, naxx = { 533 },
  smgy = { 189, "Interrogator Vishas", "Bloodmage Thalnos" },
  smlib = { 189, "Houndmaster Loksey", "Arcanist Doan" },
  smarm = { 189, "Herod" },
  smcath = { 189, "High Inquisitor Fairbanks", "High Inquisitor Whitemane" },
  brd = { 230 },
  lbrs = { 229, "Highlord Omokk", "Shadow Hunter Vosh'gajin", "War Master Voone", "Mother Smolderweb", "Urok Doomhowl",
    "Quartermaster Zigris", "Halycon", "Gizrul the Slavener", "Overlord Wyrmthalak" },
  ubrs = { 229, "Pyroguard Emberseer", "Warchief Rend Blackhand", "The Beast", "General Drakkisath", "Lord Valthalak" },
  dme = { 429, "Zevrim Thornhoof", "Hydrospawn", "Lethtendris", "Pusillin", "Alzzin the Wildshaper" },
  dmw = { 429, "Tendris Warpwood", "Illyanna Ravenoak", "Magister Kalendris", "Immol'thar", "Prince Tortheldrin" },
  dmn = { 429, "Guard Mol'dar", "Stomper Kreeg", "Guard Fengus", "Guard Slip'kik", "Captain Kromcrush",
    "Cho'Rush the Observer", "King Gordok" },
}

-- Where each dungeon and raid is in WoW Forever's Dungeon Finder table (ns.ENCOUNTERS.wowf.finder, its LFGDungeons
-- IDs). It no longer decides what Forever shows (ns.FOREVER_SCHEDULE does, since 30 Oct 2026): the table is Classic's
-- with Forever's first four dungeons added. tools/update-game-data.ps1 reports new entries as a hint that something
-- is coming.
ns.FINDER_IDS = {
  wc = 1, scholo = 2, rfc = 3, dm = 5, sfk = 7, bfd = 9, stocks = 11, gnomer = 13, rfk = 15,
  smgy = 17, smlib = 17, smarm = 17, smcath = 17, rfd = 19, ulda = 21, zf = 23, mara = 25, st = 27, brd = 29,
  lbrs = 31, dme = 33, dmw = 35, dmn = 37, strat = 39, ubrs = 43,
  zg = 41, ony = 45, mc = 47, bwl = 49,
  dal = 3271, rol = 3272, hot = 3273, exc = 3274,
}

-- Retail's Adventure Guide entries (ns.ENCOUNTERS.wow.guide, by journal ID) that are dungeons and raids of the
-- catalog: retail's version of the same place (reworked since, with other bosses), so journeys and the presets
-- carry over. Every other guide entry is "j" and its journal ID. (The old Scarlet Monastery wings have no single
-- match in retail's Scarlet Halls and Scarlet Monastery; its Zul'Gurub is a dungeon, not the raid.)
ns.GUIDE_KEYS = {
  [63] = "dm", [64] = "sfk", [226] = "rfc", [227] = "bfd", [228] = "brd", [229] = "lbrs", [231] = "gnomer",
  [232] = "mara", [233] = "rfd", [234] = "rfk", [237] = "st", [238] = "stocks", [239] = "ulda", [240] = "wc",
  [241] = "zf", [246] = "scholo", [559] = "ubrs",
  [1276] = "dme", [230] = "dmw", [1277] = "dmn", -- Warpwood Quarter, Capital Gardens, Gordok Commons
  [236] = "strat", -- Stratholme - Main Gate (the Service Entrance is a guide entry of its own)
  [741] = "mc", [742] = "bwl", [743] = "aq20", [744] = "aq40", [754] = "naxx", [760] = "ony",
}

-- Retail's own Classic dungeons that the catalog has no key for, and their place in the presets, as the catalog's
-- { best level from, best level to, Classic chapter, role }: Scarlet Halls (Houndmaster and Armsmaster: the old
-- Library and Armory) where the Library was, Scarlet Monastery (Thalnos, Whitemane: the old Graveyard and Cathedral)
-- where the Cathedral was, and Stratholme's Service Entrance beside its Main Gate (30 Oct 2026, the owner: "Make it
-- so that the clients available dungeons are present").
ns.GUIDE_PLAN = {
  [311] = { 33, 36, 5, "m" }, [316] = { 37, 40, 6, "m" }, [1292] = { 58, 60, 14, "m" },
}

-- Rare spawns and bosses that need a summon or an item: listed, but not needed for a clear by default
-- (Journey Admin can tick them).
ns.OPTIONAL_BOSSES = {
  ["Miner Johnson"] = true, ["Tsu'zee"] = true, ["Lord Hel'nurath"] = true, ["Lord Valthalak"] = true, ["Kormok"] = true,
  ["Skul"] = true, ["Stonespine"] = true, ["Hearthsinger Forresten"] = true, ["Postmaster Malown"] = true,
  ["Black Guard Swordsmith"] = true, ["Crimson Hammersmith"] = true, ["Gahz'rilla"] = true,
  -- Raids: summoned and optional bosses.
  ["Edge of Madness"] = true, ["Gahz'ranka"] = true, ["Silithid Royalty"] = true, ["Viscidus"] = true, ["Ouro"] = true,
}

-- The game's picture of each dungeon (from the Adventure Guide's art, which Forever's files also have):
-- Interface\EncounterJournal\UI-EJ-DUNGEONBUTTON-<name>. Dungeons without one (Forever's own) use "Default".
ns.DUNGEON_ART = {
  dm = "Deadmines", wc = "WailingCaverns", sfk = "ShadowfangKeep", bfd = "BlackfathomDeeps", stocks = "TheStockade",
  rfk = "RazorfenKraul", gnomer = "Gnomeregan", smlib = "ScarletMonastery", smgy = "ScarletMonastery",
  smarm = "ScarletMonastery", smcath = "ScarletMonastery", rfd = "RazorfenDowns", ulda = "Uldaman", zf = "ZulFarrak",
  mara = "Maraudon", st = "SunkenTemple", brd = "BlackrockDepths", lbrs = "BlackrockSpire",
  ubrs = "UpperBlackrockSpire", dme = "DireMaul", dmw = "DireMaul", dmn = "DireMaul", strat = "Stratholme",
  scholo = "Scholomance", rfc = "RagefireChasm",
}

-- The dungeons' loading screens: large pictures the game has for every dungeon (LoadingScreens for the map's
-- LoadingScreenID, from wago.tools), as file IDs. Two kinds:
--   classic: the original loading screens (NarrowScreenFileDataID), 4:3 art stored square, the picture between
--            the logo at the top and the bar at the bottom. In Forever and retail.
--   forever: Forever's own dungeons (MainImageFileDataID), 2992 x 1684 with the picture in the middle band. Only in
--            Forever: retail knows these file IDs but draws them solid green.
-- The Forever dungeons not in the game's data yet (Drowned City, Krol'dok, Alcaz, Blackmaw) have none until they are.
ns.DUNGEON_SCREEN = {
  hot = { 7963781, "forever" }, rol = { 7963782, "forever" }, exc = { 7963777, "forever" }, dal = { 7963775, "forever" },
  dm = { 131833, "classic" }, wc = { 131882, "classic" }, sfk = { 131869, "classic" }, bfd = { 131823, "classic" },
  stocks = { 131870, "classic" }, rfk = { 131865, "classic" }, gnomer = { 131841, "classic" },
  smgy = { 131852, "classic" }, smlib = { 131852, "classic" }, smarm = { 131852, "classic" },
  smcath = { 131852, "classic" }, rfd = { 131864, "classic" }, ulda = { 131876, "classic" }, zf = { 131885, "classic" },
  mara = { 131850, "classic" }, st = { 131872, "classic" }, brd = { 131824, "classic" },
  lbrs = { 131825, "classic" }, ubrs = { 131825, "classic" }, dme = { 131835, "classic" }, dmw = { 131835, "classic" },
  dmn = { 131835, "classic" }, strat = { 131871, "classic" },
  scholo = { 131868, "classic" }, rfc = { 131862, "classic" },
  zg = { 131886, "classic" }, ony = { 131863, "classic" }, mc = { 131851, "classic" }, bwl = { 131827, "classic" },
  aq20 = { 131818, "classic" }, aq40 = { 131819, "classic" }, naxx = { 131854, "classic" },
}
-- Our own tiles (Media\DungeonHot ...: art/incoming, A7) for Forever's own dungeons: shown where the game has no
-- picture for them (retail, and the Forever dungeons not in the game's data yet). The game's loading screen comes first.
ns.DUNGEON_TILE = { hot = "DungeonHot", rol = "DungeonRol", exc = "DungeonExc", drown = "DungeonDrown",
  krol = "DungeonKrol", alcaz = "DungeonAlcaz", bmh = "DungeonBmh" }
-- Where the picture is in each kind of file (left, right, top, bottom) and its shape (width / height on screen).
-- classic starts below the tip of the frame under the logo, which reaches 0.255 (Shadowfang Keep's); it was 0.21
-- until 30 Oct 2026, and a sliver of the logo showed.
local BANDS = {
  own = { 0, 1, 0, 1, aspect = 2 },
  forever = { 0, 1, 0.165, 0.835, aspect = 2992 / (0.67 * 1684) },
  classic = { 0, 1, 0.26, 0.78, aspect = 4 / (0.52 * 3) },
  journal = { 0, 0.68359375, 0, 0.7421875, aspect = 175 / 95 }, -- the Adventure Guide's dungeon tile
}

-- The middle of a band in the shape w / h (the whole band when no shape is asked for).
local function crop(band, w, h)
  local l, r, t, b = band[1], band[2], band[3], band[4]
  local want = (w and h and h > 0) and w / h or band.aspect
  if want > band.aspect then
    local keep, mid = (b - t) * band.aspect / want, (t + b) / 2
    t, b = mid - keep / 2, mid + keep / 2
  else
    local keep, mid = (r - l) * want / band.aspect, (l + r) / 2
    l, r = mid - keep / 2, mid + keep / 2
  end
  return l, r, t, b
end

-- Puts a dungeon's picture on tex, cropped to the shape w x h: its loading screen, or else the Adventure Guide's
-- tile (retail's guide entries: their own, by file; the default tile when the game has none for it). Returns false
-- when there is no picture at all; the second result is true when only the default tile was found (a large card
-- shows something better then).
function ns.SetDungeonArt(tex, key, w, h)
  key = ns.BaseKey(key)
  local screen = ns.DUNGEON_SCREEN[key]
  if screen and screen[2] == "forever" and not ns.IsForever() then screen = nil end
  if screen and tex:SetTexture(screen[1]) then
    tex:SetTexCoord(crop(BANDS[screen[2]], w, h))
    return true, false
  end
  local tile = ns.DUNGEON_TILE[key]
  if tile and tex:SetTexture(ns.MEDIA .. tile) then
    tex:SetTexCoord(crop(BANDS.own, w, h))
    return true, false
  end
  local guide = ns.GUIDE_ART and ns.GUIDE_ART[key]
  if guide and guide > 0 and tex:SetTexture(guide) then
    tex:SetTexCoord(crop(BANDS.journal, w, h))
    return true, false
  end
  local base = "Interface\\EncounterJournal\\UI-EJ-DUNGEONBUTTON-"
  local own = ns.DUNGEON_ART[key] and tex:SetTexture(base .. ns.DUNGEON_ART[key])
  local ok = own or tex:SetTexture(base .. "Default")
  tex:SetTexCoord(crop(BANDS.journal, w, h))
  return ok ~= false, not own
end

-- The same loading screen for pictures outside the game: WoW Addon Webhooks for Discord reads it from the game's own
-- files (docs/SAVED-DATA.md). { game = file id, crop = { left, right, top, bottom } (the picture's part of the file),
-- aspect = the shape that part is shown at }, or nil where this client has none (Forever's own dungeons on retail).
function ns.DungeonScreen(key)
  local screen = ns.DUNGEON_SCREEN[ns.BaseKey(key)]
  if not screen or (screen[2] == "forever" and not ns.IsForever()) then return nil end
  local band = BANDS[screen[2]]
  return { game = screen[1], crop = { band[1], band[2], band[3], band[4] }, aspect = band.aspect }
end

-- Which boss data this client uses ("wowf": Forever, "wow": retail, where we test until Forever is out) and the game
-- build it was made from.
function ns.EncounterSet()
  local key = ns.Game()
  local data = ns.ENCOUNTERS and ns.ENCOUNTERS[key]
  return key, data and data.build
end

-- Each game shows what it offers (30 Oct 2026, the owner: "Only Dungeons, Raids, Quests and attunements that are
-- available should be visible in the addon depending on what client they are logged into"; then retail "All of
-- retail's", and for WoW Forever "Announcements + dates"):
--   WoW Forever: what Blizzard has announced (ns.FOREVER_SCHEDULE), with the bosses its data has; a raid announced for
--     a later date shows that date until it opens (ns.IsOpen).
--   retail: every dungeon and raid of its Adventure Guide (Data/Encounters.lua, guide), with the game's own names,
--     levels, pictures and bosses, and its expansion (ns.EXPANSION: the journey editor's shelf groups by it).
-- The lists above are the whole catalog, kept in ns.ALL_*; ns.KeepThisGame (when the addon loads) puts this game's in
-- ns.DUNGEONS, ns.RAIDS, ns.DUNGEON_MAPS and ns.DUNGEON_SCREEN, so the pages, the editor's shelf, Gatherings, clear
-- detection and the Endgame follow. The presets plan with the catalog (ns.PLAN_DUNGEONS: its levels and chapters), so
-- they stay the Classic ones in both games, with every Classic dungeon the game offers: on retail also its own Scarlet
-- Halls, Scarlet Monastery and Stratholme Service Entrance (ns.GUIDE_PLAN). A journey keeps the placement of a dungeon
-- this game lacks; ns.Dungeon knows it not, so the pages skip it until the game has it.
ns.ALL_DUNGEONS, ns.ALL_RAIDS = ns.DUNGEONS, ns.RAIDS
ns.ALL_DUNGEON_MAPS, ns.ALL_DUNGEON_SCREEN = ns.DUNGEON_MAPS, ns.DUNGEON_SCREEN
ns.PLAN_DUNGEONS, ns.EXPANSION, ns.GUIDE_ART = ns.DUNGEONS, {}, {}

local function catalogRow(key)
  for _, list in ipairs({ ns.ALL_DUNGEONS, ns.ALL_RAIDS }) do
    for _, d in ipairs(list) do if d[1] == key then return d end end
  end
end

-- A name as plain letters, to know a place by its name ("The Barrow Deeps", "Barrow Deeps").
function ns.PlainName(s) return (s:lower():gsub("^the ", ""):gsub("[^%w]", "")) end

-- Retail's guide entries by key (Data/Encounters.lua is generated, so this is worked out once per data table).
local byKey = setmetatable({}, { __mode = "k" })
local function guideEntries(data)
  if not byKey[data] then
    local out = {}
    for _, g in ipairs(data.guide) do out[ns.GUIDE_KEYS[g[1]] or ("j" .. g[1])] = g end
    byKey[data] = out
  end
  return byKey[data]
end

-- What WoW Forever offers, as Blizzard has announced it (30 Oct 2026, the owner: "Announcements + dates"). The game's
-- own files are no guide to it: unreleased content is encrypted there until it opens (five days before launch the
-- tables we can read had four of the nine new dungeons and neither new raid), and its Dungeon Finder table is
-- Classic's, with raids Blizzard has not announced (Zul'Gurub, Molten Core, Blackwing Lair).
-- true: open at launch (4 November 2026); a time: opens then, or earlier when the game shows it open (ns.IsOpen). Not
-- here: not shown in WoW Forever. Sources: Blizzard's "Explore the New Dungeons of World of Warcraft: Forever" (the nine
-- new dungeons), "World of Warcraft: Forever Raid Overview" ("Barrow Deeps, Hyjal Summit, and Onyxia's Lair unlock on
-- December 9"; no hour, so midnight Pacific); the Classic dungeons, which the game's data has with their bosses, as
-- the guides list them. The daily routine reads Blizzard's news for more (docs/GAME-UPDATES.md, tools/forever-news.txt).
local DEC_9 = 1796803200 -- 9 December 2026, 00:00 PST
ns.FOREVER_SCHEDULE = {
  rfc = true, dm = true, wc = true, sfk = true, bfd = true, stocks = true, rfk = true, gnomer = true, smgy = true,
  smlib = true, smarm = true, smcath = true, rfd = true, ulda = true, zf = true, mara = true, st = true, brd = true,
  lbrs = true, ubrs = true, dme = true, dmw = true, dmn = true, strat = true, scholo = true,
  hot = true, rol = true, exc = true, dal = true, drown = true, krol = true, alcaz = true, bmh = true, shaper = true,
  barrow = DEC_9, hyjal = DEC_9, ony = DEC_9,
}

-- Is the dungeon or raid in game ("wowf" or "wow"; default: this one)? Retail: its Adventure Guide lists it. Forever:
-- Blizzard has announced it.
function ns.InGame(key, game)
  game = game or ns.Game()
  key = ns.BaseKey(key)
  local data = ns.ENCOUNTERS and ns.ENCOUNTERS[game]
  if data and data.guide then return guideEntries(data)[key] ~= nil end
  if game == "wowf" then return ns.FOREVER_SCHEDULE[key] ~= nil end
  return false
end

-- When an announced place opens (a time), or nil when it is open from the start (and always on retail).
function ns.Opens(key)
  if ns.Game() ~= "wowf" then return nil end
  local at = ns.FOREVER_SCHEDULE[ns.BaseKey(key)]
  return type(at) == "number" and at or nil
end

-- Is it open? From its date, or earlier once the game shows it: a boss killed in it, here (ns.MarkOpen) or by a Hero
-- of fellowship f. A date is the earliest the posts allow, so nobody waits on a guessed hour.
function ns.IsOpen(key, f)
  local at = ns.Opens(key)
  if not at or time() >= at then return true end
  local opened = ns.db and ns.db.opened
  if opened and opened[ns.BaseKey(key)] then return true end
  local kills = f and f.kills and f.kills[key]
  return type(kills) == "table" and next(kills) ~= nil
end

-- A boss died in a place that has not opened by its date: it has (ns.db.opened[key] = when this was seen).
function ns.MarkOpen(key)
  key = ns.BaseKey(key)
  if ns.IsOpen(key) or not ns.db then return end
  ns.db.opened = ns.db.opened or {}
  ns.db.opened[key] = time()
end

-- "9 December": the day an announced place opens.
function ns.OpensText(key)
  local at = ns.Opens(key)
  return at and (date("%d %B", at):gsub("^0", "")) or nil
end

-- Lowest expansion, then level, then name.
local function byExpansion(a, b)
  local ea, eb = ns.EXPANSION[a[1]] or 0, ns.EXPANSION[b[1]] or 0
  if ea ~= eb then return ea < eb end
  if a[3] ~= b[3] then return a[3] < b[3] end
  return a[2] < b[2]
end

-- Retail: its Adventure Guide as this game's dungeons and raids. A catalog dungeon keeps its key (journeys and the
-- presets carry over) and its preset chapter, as retail's own Classic versions take theirs from ns.GUIDE_PLAN; the
-- name, levels, picture and bosses are the game's. A wing of a shared
-- instance (Dire Maul, Stratholme) has its bosses by name, as the catalog's wings do.
local function fromGuide(data)
  local dungeons, raids, maps, screens, plan = {}, {}, {}, {}, {}
  ns.EXPANSION, ns.GUIDE_ART = {}, {}
  for key, g in pairs(guideEntries(data)) do
    local own = catalogRow(key)
    local p = not own and ns.GUIDE_PLAN[g[1]]
    if p then own = { key, g[3], p[1], p[2], p[3], p[4] } end
    if g[5] == "r" then
      raids[#raids + 1] = { key, g[3], g[6], g[8] }
    else
      dungeons[#dungeons + 1] = { key, g[3], g[6], g[7], own and own[5] or 0, own and own[6] or "o" }
      if own then plan[#plan + 1] = own end
    end
    local m = { g[2] }
    for i = 10, #g do m[#m + 1] = g[i] end
    maps[key] = m
    ns.EXPANSION[key], ns.GUIDE_ART[key] = g[4], g[9]
    -- The catalog's loading screen where retail's instance is the same one (not its new Scholomance).
    local where = ns.ALL_DUNGEON_MAPS[key]
    if where and where[1] == g[2] then screens[key] = ns.ALL_DUNGEON_SCREEN[key] end
  end
  table.sort(dungeons, byExpansion)
  table.sort(raids, byExpansion)
  table.sort(plan, function(a, b) return a[1] < b[1] end)
  return dungeons, raids, maps, screens, plan
end

-- Keeps this game's dungeons, raids, attunements and dungeon quests (Core/Init.lua, when the addon loads). Our quest
-- lists are WoW Forever's (Data/QuestLists.lua, every ID checked against its quest table): retail has none of these
-- attunements and keys, and other quests for its versions of the dungeons. In Forever, an attunement or quest list
-- hides with its raid or dungeon.
function ns.KeepThisGame()
  local data = ns.ENCOUNTERS and ns.ENCOUNTERS[ns.Game()]
  if data and data.guide then
    ns.DUNGEONS, ns.RAIDS, ns.DUNGEON_MAPS, ns.DUNGEON_SCREEN, ns.PLAN_DUNGEONS = fromGuide(data)
  else
    local function keep(list)
      local out = {}
      for _, d in ipairs(list) do if ns.InGame(d[1]) then out[#out + 1] = d end end
      return out
    end
    ns.DUNGEONS, ns.RAIDS = keep(ns.ALL_DUNGEONS), keep(ns.ALL_RAIDS)
    ns.DUNGEON_MAPS, ns.DUNGEON_SCREEN, ns.PLAN_DUNGEONS = ns.ALL_DUNGEON_MAPS, ns.ALL_DUNGEON_SCREEN, ns.ALL_DUNGEONS
    ns.EXPANSION, ns.GUIDE_ART = {}, {}
  end
  local forever = ns.IsForever()
  ns.ATTUNEMENTS, ns.DUNGEON_QUESTS = {}, {}
  for _, a in ipairs(forever and ns.ALL_ATTUNEMENTS or {}) do
    local place = catalogRow(a.key)
    if (not a.from or ns.Dungeon(a.from)) and (not place or ns.Dungeon(a.key)) and (not a.raid or ns.Raid(a.raid)) then
      ns.ATTUNEMENTS[#ns.ATTUNEMENTS + 1] = a
    end
  end
  for key, list in pairs(forever and ns.ALL_DUNGEON_QUESTS or {}) do
    if ns.Dungeon(key) then ns.DUNGEON_QUESTS[key] = list end
  end
end

-- The game version's dungeon data.
function ns.EncounterData()
  local data = ns.ENCOUNTERS and ns.ENCOUNTERS[(ns.EncounterSet())]
  return data and data.maps or {}
end
