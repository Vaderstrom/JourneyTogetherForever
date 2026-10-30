-- Dungeons of WoW Forever (from the mockup's DUNGEONS).
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
  { "dme", "Dire Maul: East", 57, 60, 14, "m" }, { "strat", "Stratholme", 58, 60, 14, "m" }, { "scholo", "Scholomance", 58, 60, 14, "m" },
  { "ubrs", "Upper Blackrock Spire", 60, 60, 14, "o" }, { "rfc", "Ragefire Chasm", 13, 18, 0, "m" },
}

-- The raids of the Endgame (M18, SPEC §2): { key, name, level, size, attunement key (Data/QuestLists.lua) or nil }.
-- Not part of the journey's chapters: they open for the fellowship when the journey is complete.
ns.RAIDS = {
  { "zg", "Zul'Gurub", 58, 20 }, { "ony", "Onyxia's Lair", 60, 40, "ony" }, { "mc", "Molten Core", 60, 40, "mc" },
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

-- A dungeon, or a raid (as { key, name, level, 60 } so names and levels read the same way). Takes placement keys.
function ns.Dungeon(key)
  key = ns.BaseKey(key)
  for _, d in ipairs(ns.DUNGEONS) do if d[1] == key then return d end end
  local r = ns.Raid(key)
  if r then return { r[1], r[2], r[3], 60 } end
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
  ubrs = "UpperBlackrockSpire", dme = "DireMaul", strat = "Stratholme", scholo = "Scholomance", rfc = "RagefireChasm",
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
  lbrs = { 131825, "classic" }, ubrs = { 131825, "classic" }, dme = { 131835, "classic" }, strat = { 131871, "classic" },
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
-- tile (the default tile when the game has none for it). Returns false when there is no picture at all; the
-- second result is true when only the default tile was found (a large card shows something better then).
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
  local key = ns.IsForever() and "wowf" or "wow"
  local data = ns.ENCOUNTERS and ns.ENCOUNTERS[key]
  return key, data and data.build
end

-- The game version's dungeon data.
function ns.EncounterData()
  local data = ns.ENCOUNTERS and ns.ENCOUNTERS[(ns.EncounterSet())]
  return data and data.maps or {}
end
