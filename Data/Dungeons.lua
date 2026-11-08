-- Dungeons of WoW Forever (from the mockup's DUNGEONS; Dire Maul West and North added 30 Oct 2026, when Forever's
-- Dungeon Finder listed them: optional in the last Classic chapter, at Dire Maul East's levels, as the game tunes the
-- three wings alike; Ragefire Chasm, which the mockup left out, optional in the first chapter: "Make it so that the
-- clients available dungeons are present", the owner, 30 Oct 2026; Shaper's Terrace, the ninth new dungeon Blizzard
-- announced, mandatory in the last chapter, the owner's choice of 30 Oct 2026). The whole catalog: the game keeps what
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
  { "ubrs", "Upper Blackrock Spire", 60, 60, 14, "o" }, { "rfc", "Ragefire Chasm", 13, 18, 1, "m" },
  { "shaper", "Shaper's Terrace", 58, 60, 14, "m" },
}

-- The raids of the Endgame (M18, SPEC §2): { key, name, level, size, attunement key (Data/QuestLists.lua) or nil }.
-- Not part of the journey's chapters: they open for the fellowship when the journey is complete. WoW Forever's own
-- raids (Barrow Deeps, Hyjal Summit) came in on 30 Oct 2026 from Blizzard's raid overview; the Classic ones stay in
-- the catalog for the day WoW Forever announces them (ns.FOREVER_SCHEDULE).
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

-- Is key a dungeon or raid of the catalog? Journeys keep the placements of dungeons this game lacks; the pages skip
-- them while it lacks them (30 Oct 2026, the owner: Classic chapters that lose their dungeon finish on level, and it
-- slots back in when the game adds it).
function ns.KnownKey(key)
  key = ns.BaseKey(key)
  if type(key) ~= "string" then return false end
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

-- WoW Forever's own dungeons, its nine new ones: in the Forever preset, not in the Classic one (the owner, 6 Nov 2026).
ns.FOREVER_OWN = {
  hot = true, rol = true, exc = true, dal = true, drown = true, krol = true, alcaz = true, bmh = true, shaper = true,
}

-- Dungeons in one faction's lands: in a preset only for that faction's fellowships (the owner, 6 Nov 2026: "ragefire
-- is only added for Horde, and Hall of Thanes only for Alliance fellowships"; their entrances are in the other
-- faction's capital). No other dungeon depends on the faction. Ragefire Chasm is mandatory for the Horde. The journey
-- editor still has them.
ns.DUNGEON_FACTION = { rfc = "Horde", hot = "Alliance" }

-- The placement key of part i of a split ("brd", "brd#2").
function ns.PartKey(key, i) return i == 1 and key or (key .. "#" .. i) end

-- Where each dungeon is: its instance ID (GetInstanceInfo) in Data/Encounters.lua. When several dungeons share one
-- instance (the Scarlet Monastery wings, Lower and Upper Blackrock Spire, Dire Maul), the names after the ID are
-- that dungeon's bosses; when no name matches, all are used.
-- Dungeons not in the game's data yet have no entry: their bosses are learned on the kill (Fellowship/Clears.lua).
ns.DUNGEON_MAPS = {
  hot = { 3065 }, rol = { 2999 }, dm = { 36 }, wc = { 43 }, sfk = { 33 }, bfd = { 48 }, stocks = { 34 }, exc = { 2998 },
  dal = { 2959 }, rfk = { 47 }, gnomer = { 90 }, rfd = { 129 }, ulda = { 70 }, zf = { 209 }, mara = { 349 }, st = { 109 },
  strat = { 329 }, scholo = { 289 }, rfc = { 389 },
  drown = { 2970 }, krol = { 3039 }, alcaz = { 2994 }, bmh = { 2974 }, shaper = { 3001 },
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
-- with Forever's own dungeons added. tools/update-game-data.ps1 reports new entries as a hint that something
-- is coming.
ns.FINDER_IDS = {
  wc = 1, scholo = 2, rfc = 3, dm = 5, sfk = 7, bfd = 9, stocks = 11, gnomer = 13, rfk = 15,
  smgy = 17, smlib = 17, smarm = 17, smcath = 17, rfd = 19, ulda = 21, zf = 23, mara = 25, st = 27, brd = 29,
  lbrs = 31, dme = 33, dmw = 35, dmn = 37, strat = 39, ubrs = 43,
  zg = 41, ony = 45, mc = 47, bwl = 49,
  dal = 3271, rol = 3272, hot = 3273, exc = 3274, shaper = 3267, bmh = 3268, alcaz = 3269, drown = 3270, krol = 3275,
}

-- Rare spawns and bosses that need a summon or an item: listed, but not needed for a clear by default
-- (Journey Admin can tick them). Reviewed against Forever's boss data on 6 Nov 2026 (the owner asked): rares (Ezra
-- Grimm, Ragglesnout), bosses that need a quest item or an event (Urok Doomhowl, Kirtonos, the Avatar of Hakkar,
-- Grubbis, the Vault, Hurley Blackbreath), and ones players spare on purpose: Princess Moira (her quest rewards
-- sparing her), the Grim Guzzler's Ribbly and Plugger (the bar turns on you), and Dire Maul North's guards and
-- Cho'Rush (a tribute run leaves them alive). Forever's own dungeons, from the guides of 6 Nov 2026 (the owner: "Rare
-- bosses should not be counted for a run"): Lyn the Ignored (City of Dalaran, a rare summoned with the Tome of
-- Dalaran), Mana Wraith (in the game's list, met by no guide), Lordaeron Captain (Ruins of Lordaeron, a rare), Viktor the
-- Vile and The Abandoned (Ruins of Lordaeron, each called by an event: the chimney's kindling, the knight statue),
-- Highland Horror (Excavation Site, for the Alliance quest Horrors in the Highland only). The Hall of Thanes has none.
ns.OPTIONAL_BOSSES = {
  ["Miner Johnson"] = true, ["Tsu'zee"] = true, ["Lord Hel'nurath"] = true, ["Lord Valthalak"] = true, ["Kormok"] = true,
  ["Skul"] = true, ["Stonespine"] = true, ["Hearthsinger Forresten"] = true, ["Postmaster Malown"] = true,
  ["Black Guard Swordsmith"] = true, ["Crimson Hammersmith"] = true, ["Gahz'rilla"] = true,
  ["Ezra Grimm"] = true, ["Ragglesnout"] = true, ["Urok Doomhowl"] = true, ["Kirtonos"] = true, ["Avatar of Hakkar"] = true,
  ["Grubbis"] = true, ["The Vault"] = true, ["Hurley Blackbreath"] = true, ["Princess Moira Bronzebeard"] = true,
  ["Ribbly Screwspigot"] = true, ["Plugger Spazzring"] = true,
  ["Guard Mol'dar"] = true, ["Stomper Kreeg"] = true, ["Guard Fengus"] = true, ["Guard Slip'kik"] = true,
  ["Captain Kromcrush"] = true, ["Cho'Rush the Observer"] = true,
  ["Lyn the Ignored"] = true, ["Mana Wraith"] = true, ["Lordaeron Captain"] = true, ["Viktor the Vile"] = true,
  ["The Abandoned"] = true, ["Highland Horror"] = true,
  -- Raids: summoned and optional bosses.
  ["Edge of Madness"] = true, ["Gahz'ranka"] = true, ["Silithid Royalty"] = true, ["Viscidus"] = true, ["Ouro"] = true,
  -- (Forever's Molten Core lists an encounter by the raid's own name, not in Classic: not needed until it is known.)
  ["The Molten Core"] = true,
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
--            the logo at the top and the bar at the bottom.
--   forever: Forever's own dungeons (MainImageFileDataID), 2992 x 1684 with the picture in the middle band.
-- Every Forever dungeon has one since build 1.60.1.70862 (8 Nov 2026); Barrow Deeps and Hyjal Summit not yet.
ns.DUNGEON_SCREEN = {
  hot = { 7963781, "forever" }, rol = { 7963782, "forever" }, exc = { 7963777, "forever" }, dal = { 7963775, "forever" },
  drown = { 7963741, "forever" }, krol = { 7963780, "forever" }, alcaz = { 7963734, "forever" },
  bmh = { 7963784, "forever" }, shaper = { 7963783, "forever" },
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
-- picture for them (a client without the loading screen). The game's loading screen comes first.
-- Shaper's Terrace and Barrow Deeps (6 Nov 2026) had no game art: Gemini's, made from what Blizzard showed.
ns.DUNGEON_TILE = { hot = "DungeonHot", rol = "DungeonRol", exc = "DungeonExc", drown = "DungeonDrown",
  krol = "DungeonKrol", alcaz = "DungeonAlcaz", bmh = "DungeonBmh", shaper = "DungeonShaper", barrow = "DungeonBarrow" }
-- The game's own picture for a place whose loading screen another place shares, or that has none (the owner, 6 Nov
-- 2026: a picture of its own for each, the game's art first): the Adventure Guide's tiles as file IDs. Scarlet Halls
-- (the Library and the Armory) and Scarlet Monastery (the Cathedral), Upper Blackrock Spire,
-- and Hyjal Summit from the Battle for Mount Hyjal. The Graveyard and Lower Blackrock Spire keep the loading screen;
-- Dire Maul's wings share one picture in the game too. Shown before the loading screen.
ns.DUNGEON_GUIDE = { smlib = 643262, smarm = 643262, smcath = 608214, ubrs = 1042000, hyjal = 608198 }
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
-- tile (the default tile when the game has none for it). Returns false
-- when there is no picture at all; the second result is true when only the default tile was found (a large card
-- shows something better then).
function ns.SetDungeonArt(tex, key, w, h)
  key = ns.BaseKey(key)
  local mine = ns.DUNGEON_GUIDE[key]
  if mine and tex:SetTexture(mine) then
    tex:SetTexCoord(crop(BANDS.journal, w, h))
    return true, false
  end
  local screen = ns.DUNGEON_SCREEN[key]
  if screen and tex:SetTexture(screen[1]) then
    tex:SetTexCoord(crop(BANDS[screen[2]], w, h))
    return true, false
  end
  local tile = ns.DUNGEON_TILE[key]
  if tile and tex:SetTexture(ns.MEDIA .. tile) then
    tex:SetTexCoord(crop(BANDS.own, w, h))
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
-- aspect = the shape that part is shown at }, or nil where the game has none.
function ns.DungeonScreen(key)
  local screen = ns.DUNGEON_SCREEN[ns.BaseKey(key)]
  if not screen then return nil end
  local band = BANDS[screen[2]]
  return { game = screen[1], crop = { band[1], band[2], band[3], band[4] }, aspect = band.aspect }
end

-- Which boss data this client uses ("wowf": WoW Forever) and the game build it was made from.
function ns.EncounterSet()
  local key = ns.Game()
  local data = ns.ENCOUNTERS and ns.ENCOUNTERS[key]
  return key, data and data.build
end

-- The addon shows what the game offers (30 Oct 2026, the owner: "Only Dungeons, Raids, Quests and attunements that
-- are available should be visible in the addon depending on what client they are logged into"; for WoW Forever
-- "Announcements + dates"): what Blizzard has announced (ns.FOREVER_SCHEDULE), with the bosses its data has; a raid
-- announced for a later date shows that date until it opens (ns.IsOpen).
-- The lists above are the whole catalog, kept in ns.ALL_*; ns.KeepThisGame (when the addon loads) puts what the game
-- offers in ns.DUNGEONS and ns.RAIDS, so the pages, the editor's shelf, Gatherings, clear detection, the Endgame and
-- the presets (the Classic levels and chapters, with only what Blizzard has announced: the owner, 4 Nov 2026) follow.
-- A journey keeps the placement of a dungeon the game lacks; ns.Dungeon knows it not, so the pages skip it until the
-- game has it.
ns.ALL_DUNGEONS, ns.ALL_RAIDS = ns.DUNGEONS, ns.RAIDS

local function catalogRow(key)
  for _, list in ipairs({ ns.ALL_DUNGEONS, ns.ALL_RAIDS }) do
    for _, d in ipairs(list) do if d[1] == key then return d end end
  end
end

-- A name as plain letters, to know a place by its name ("The Barrow Deeps", "Barrow Deeps").
function ns.PlainName(s) return (s:lower():gsub("^the ", ""):gsub("[^%w]", "")) end

-- What WoW Forever offers, as Blizzard has announced it (30 Oct 2026, the owner: "Announcements + dates"). The game's
-- own files are no guide to it: unreleased content is encrypted there until it opens (five days before launch the
-- tables we can read had four of the nine new dungeons and neither new raid), and its Dungeon Finder table is
-- Classic's, with raids Blizzard has not announced (Zul'Gurub, Molten Core, Blackwing Lair).
-- true: open at launch (4 November 2026); a time: opens then, or earlier when the game shows it open (ns.IsOpen). Not
-- here: not shown in WoW Forever. Sources: Blizzard's "Explore the New Dungeons of World of Warcraft: Forever" (the nine
-- new dungeons), "World of Warcraft: Forever Raid Overview" ("Barrow Deeps, Hyjal Summit, and Onyxia's Lair unlock on
-- December 9"; no hour, so midnight Pacific); the Classic dungeons, which the game's data has with their bosses, as
-- the guides list them. The daily routine reads Blizzard's news for more (docs/GAME-UPDATES.md, tools/forever-news.txt).
-- The same list, for people: docs/FOREVER-CONTENT.md (change both together; tests/test_games.lua compares them).
local DEC_9 = 1796803200 -- 9 December 2026, 00:00 PST
ns.FOREVER_SCHEDULE = {
  rfc = true, dm = true, wc = true, sfk = true, bfd = true, stocks = true, rfk = true, gnomer = true, smgy = true,
  smlib = true, smarm = true, smcath = true, rfd = true, ulda = true, zf = true, mara = true, st = true, brd = true,
  lbrs = true, ubrs = true, dme = true, dmw = true, dmn = true, strat = true, scholo = true,
  hot = true, rol = true, exc = true, dal = true, drown = true, krol = true, alcaz = true, bmh = true, shaper = true,
  barrow = DEC_9, hyjal = DEC_9, ony = DEC_9,
}

-- Is the dungeon or raid in the game? Blizzard has announced it for WoW Forever.
function ns.InGame(key)
  return ns.FOREVER_SCHEDULE[ns.BaseKey(key)] ~= nil
end

-- When an announced place opens (a time), or nil when it is open from the start.
function ns.Opens(key)
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

-- Keeps the dungeons, raids, attunements and dungeon quests the game offers (Core/Init.lua, when the addon loads).
-- Our quest lists are WoW Forever's (Data/QuestLists.lua, every ID checked against its quest table); an attunement
-- or quest list hides with its raid or dungeon.
function ns.KeepThisGame()
  local function keep(list)
    local out = {}
    for _, d in ipairs(list) do if ns.InGame(d[1]) then out[#out + 1] = d end end
    return out
  end
  ns.DUNGEONS, ns.RAIDS = keep(ns.ALL_DUNGEONS), keep(ns.ALL_RAIDS)
  ns.ATTUNEMENTS, ns.DUNGEON_QUESTS = {}, {}
  for _, a in ipairs(ns.ALL_ATTUNEMENTS or {}) do
    local place = catalogRow(a.key)
    if (not a.from or ns.Dungeon(a.from)) and (not place or ns.Dungeon(a.key)) and (not a.raid or ns.Raid(a.raid)) then
      ns.ATTUNEMENTS[#ns.ATTUNEMENTS + 1] = a
    end
  end
  for key, list in pairs(ns.ALL_DUNGEON_QUESTS or {}) do
    if ns.Dungeon(key) then ns.DUNGEON_QUESTS[key] = list end
  end
end

-- The game version's dungeon data.
function ns.EncounterData()
  local data = ns.ENCOUNTERS and ns.ENCOUNTERS[(ns.EncounterSet())]
  return data and data.maps or {}
end
