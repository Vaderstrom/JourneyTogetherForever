-- Our own lists (SPEC §6): attunements and keys, and the quests of each dungeon, by quest ID. Written for this addon
-- (no data copied from other addons); every ID is checked against WoW Forever's quest table by
-- tools/check-quest-lists.ps1. Names are the game's English quest names, shown until the client knows the quest.
-- side: "A" Alliance, "H" Horde, nil both. A step lists one or more quest IDs; any of them done counts.
local _, ns = ...

-- Attunements and keys: { key, name, kind ("raid" / "key"), side, level (the level from which a Hero can start it;
-- below it the attunement is not shown to them), item (the key or amulet; having it also counts as done),
-- steps = { { ids, name } }, drop (true: the key drops, there is no quest), from (a dropped key: the dungeon it
-- drops in; its level is that dungeon's best level from, so it follows Data/Dungeons.lua), raid (the raid it is
-- for, when that is not its key: shown only while the game has that raid) }
-- tools/update-game-data.ps1 checks every quest ID and item against the game, and each start level against the
-- first quest's own level.
ns.ATTUNEMENTS = {
  -- The Scarlet Key (Armory and Cathedral) drops in the Library (missing until 27 Oct 2026: the first key shown was
  -- Blackrock Depths at 48).
  { key = "smarm", name = "Scarlet Monastery (Armory and Cathedral)", kind = "key", item = 7146, drop = true,
    from = "smlib", steps = {} },
  { key = "mc", name = "Molten Core", kind = "raid", level = 55, steps = { { { 7848 }, "Attunement to the Core" } } },
  -- Not an attunement to enter, but Majordomo Executus can only be summoned with the Hydraxian Waterlords' help.
  { key = "hydraxis", name = "Hydraxian Waterlords (Majordomo)", kind = "raid", raid = "mc", level = 55, steps = {
    { { 6804 }, "Poisoned Water" }, { { 6805 }, "Stormers and Rumblers" }, { { 6821 }, "Eye of the Emberseer" },
    { { 6822 }, "The Molten Core" }, { { 6823 }, "Agent of Hydraxis" }, { { 6824 }, "Hands of the Enemy" } } },
  { key = "ony", name = "Onyxia's Lair", kind = "raid", side = "A", level = 50, item = 16309, steps = {
    { { 4182 }, "Dragonkin Menace" }, { { 4183 }, "The True Masters" }, { { 4184 }, "The True Masters" },
    { { 4185 }, "The True Masters" }, { { 4186 }, "The True Masters" }, { { 4223 }, "The True Masters" },
    { { 4224 }, "The True Masters" }, { { 4241 }, "Marshal Windsor" }, { { 4242 }, "Abandoned Hope" },
    { { 4264 }, "A Crumpled Up Note" }, { { 4282 }, "A Shred of Hope" }, { { 4322 }, "Jail Break!" },
    { { 6402 }, "Stormwind Rendezvous" }, { { 6403 }, "The Great Masquerade" }, { { 6501 }, "The Dragon's Eye" },
    { { 6502 }, "Drakefire Amulet" } } },
  { key = "ony", name = "Onyxia's Lair", kind = "raid", side = "H", level = 55, item = 16309, steps = {
    { { 4903 }, "Warlord's Command" }, { { 4941 }, "Eitrigg's Wisdom" }, { { 4974 }, "For The Horde!" },
    { { 6566 }, "What the Wind Carries" }, { { 6567 }, "The Champion of the Horde" },
    { { 6568 }, "The Testament of Rexxar" }, { { 6569 }, "Oculus Illusions" }, { { 6570 }, "Emberstrife" },
    { { 6582 }, "The Test of Skulls, Scryer" }, { { 6583 }, "The Test of Skulls, Somnus" },
    { { 6584 }, "The Test of Skulls, Chronalis" }, { { 6585 }, "The Test of Skulls, Axtroz" },
    { { 6601 }, "Ascension..." }, { { 6602 }, "Blood of the Black Dragon Champion" } } },
  { key = "bwl", name = "Blackwing Lair", kind = "raid", level = 58, steps = { { { 7761 }, "Blackhand's Command" } } },
  -- Naxxramas: the Argent Dawn's quest, at Honored, Revered or Exalted (any of the three counts).
  { key = "naxx", name = "Naxxramas", kind = "raid", level = 60, steps = {
    { { 9121, 9122, 9123 }, "The Dread Citadel - Naxxramas" } } },
  { key = "ubrs", name = "Upper Blackrock Spire", kind = "key", level = 55, item = 12344, steps = {
    { { 4742 }, "Seal of Ascension" }, { { 4743 }, "Seal of Ascension" } } },
  { key = "scholo", name = "Scholomance", kind = "key", side = "A", level = 55, item = 13704, steps = {
    { { 5092 }, "Clear the Way" }, { { 5097 }, "All Along the Watchtowers" }, { { 5533 }, "Scholomance" },
    { { 5537 }, "Skeletal Fragments" }, { { 5538 }, "Mold Rhymes With..." }, { { 5801, 5802 }, "Fire Plume Forged" },
    { { 5803 }, "Araj's Scarab" }, { { 5505, 5511 }, "The Key to Scholomance" } } },
  { key = "scholo", name = "Scholomance", kind = "key", side = "H", level = 55, item = 13704, steps = {
    { { 5096 }, "Scarlet Diversions" }, { { 5098 }, "All Along the Watchtowers" }, { { 838 }, "Scholomance" },
    { { 964 }, "Skeletal Fragments" }, { { 5514 }, "Mold Rhymes With..." }, { { 5801, 5802 }, "Fire Plume Forged" },
    { { 5804 }, "Araj's Scarab" }, { { 5505, 5511 }, "The Key to Scholomance" } } },
  { key = "brd", name = "Blackrock Depths", kind = "key", level = 48, item = 11000, steps = {
    { { 3801 }, "Dark Iron Legacy" }, { { 3802 }, "Dark Iron Legacy" } } },
  { key = "strat", name = "Stratholme", kind = "key", item = 12382, drop = true, from = "strat", steps = {} },
  { key = "dm", name = "Dire Maul", kind = "key", item = 18249, drop = true, from = "dme", steps = {} },
}

-- Dropped keys start where their dungeon does.
for _, a in ipairs(ns.ATTUNEMENTS) do
  local d = a.from and ns.Dungeon(a.from)
  if d and not a.level then a.level = d[3] end
end
-- Lowest first, so lists and "the first one opens at" read in order.
table.sort(ns.ATTUNEMENTS, function(a, b)
  if (a.level or 0) ~= (b.level or 0) then return (a.level or 0) < (b.level or 0) end
  return a.name < b.name
end)

-- The quests of each dungeon of the journey (Data/Dungeons.lua keys): { id, name, side }.
-- No list yet for Krol'dok Stronghold, Alcaz Prison, Blackmaw Hold and Shaper's Terrace (new in Forever): the sources
-- showed none on 7 Nov 2026 (docs/QUEST-SOURCES.md).
ns.DUNGEON_QUESTS = {
  hot = { { 96395, "An Ancient Grudge" }, { 96403, "Important Heirlooms", "A" }, { 96394, "The Restless Dead", "A" },
    { 96393, "Old Ironforge Incursion", "A" }, { 98423, "The Treaty of Understanding", "A" } },
  rol = { { 95250, "Abominable Creatures", "A" }, { 95195, "Bloodied Insignia", "A" }, { 95189, "Crest of Lordaeron", "A" },
    { 92415, "Remember That I Love You", "A" }, { 92401, "A Frightened Request", "H" }, { 92421, "Light's Justice", "H" },
    { 95216, "The New Plague", "H" }, { 92422, "The Wrath of Rath'mael", "H" }, { 97288, "Unending Torment", "H" },
    { 95204, "Crest of Lordaeron", "H" } },
  rfc = { { 5723, "Testing an Enemy's Strength", "H" }, { 5725, "The Power to Destroy...", "H" },
    { 5728, "Hidden Enemies", "H" }, { 5761, "Slaying the Beast", "H" }, { 5722, "Searching for the Lost Satchel", "H" },
    { 5724, "Returning the Lost Satchel", "H" } },
  dm = { { 166, "The Defias Brotherhood", "A" }, { 2040, "Underground Assault", "A" }, { 214, "Red Silk Bandanas", "A" },
    { 168, "Collecting Memories", "A" }, { 167, "Oh Brother...", "A" }, { 373, "The Unsent Letter", "A" },
    { 92753, "Destruction in Deadmines", "A" } },
  wc = { { 914, "Leaders of the Fang", "H" }, { 1486, "Deviate Hides" }, { 959, "Trouble at the Docks" },
    { 1487, "Deviate Eradication" }, { 1491, "Smart Drinks" }, { 6981, "The Glowing Shard" }, { 962, "Serpentbloom", "H" } },
  sfk = { { 1013, "The Book of Ur", "H" }, { 1014, "Arugal Must Die", "H" }, { 1098, "Deathstalkers in Shadowfang", "H" } },
  bfd = { { 1198, "In Search of Thaelrid", "A" }, { 1199, "Twilight Falls", "A" }, { 1200, "Blackfathom Villainy", "A" },
    { 1275, "Researching the Corruption", "A" }, { 6563, "The Essence of Aku'Mai" },
    { 6565, "Allegiance to the Old Gods", "H" }, { 6921, "Amongst the Ruins", "H" }, { 6922, "Baron Aquanis", "H" },
    { 971, "Knowledge in the Deeps", "A" }, { 6564, "Allegiance to the Old Gods", "H" }, { 6561, "Blackfathom Villainy", "H" } },
  stocks = { { 386, "What Comes Around...", "A" }, { 377, "Crime and Punishment", "A" }, { 387, "Quell The Uprising", "A" },
    { 388, "The Color of Blood", "A" }, { 378, "The Fury Runs Deep", "A" }, { 391, "The Stockade Riots", "A" } },
  exc = { { 98815, "Highland Hides", "A" }, { 95646, "Horrors in the Highland", "A" },
    { 95647, "Lost in the Thicket Things", "A" }, { 95772, "Songblade Search", "A" }, { 95810, "Lost Relic Carry", "A" },
    { 95697, "Changing Tastes", "H" }, { 95682, "Open the Maw", "H" }, { 95664, "Elder Knowledge", "H" } },
  dal = { { 92456, "A Green Sample", "A" }, { 92489, "Power Overwhelming", "A" }, { 92458, "Heart of Disruption", "A" },
    { 92457, "Starving Arcane", "A" }, { 96984, "Heart of Disruption", "H" }, { 96987, "Opportunistic Education", "H" },
    { 96988, "Source of Power", "H" }, { 96986, "The Grave Knight", "H" } },
  rfk = { { 1221, "Blueleaf Tubers" }, { 1144, "Willix the Importer" }, { 1101, "The Crone of the Kraul", "A" },
    { 1142, "Mortality Wanes", "A" }, { 1109, "Going, Going, Guano!", "H" }, { 1102, "A Vengeful Fate", "H" },
    { 6522, "An Unholy Alliance", "H" } },
  gnomer = { { 2904, "A Fine Mess" }, { 2922, "Save Techbot's Brain!", "A" }, { 2926, "Gnogaine", "A" },
    { 2927, "The Day After", "A" }, { 2929, "The Grand Betrayal", "A" }, { 2930, "Data Rescue", "A" },
    { 2928, "Gyrodrillmatic Excavationators", "A" }, { 2841, "Rig Wars", "H" }, { 2945, "Grime-Encrusted Ring" }, { 2924, "Essential Artificials", "A" },
    { 2962, "The Only Cure is More Green Glow", "A" }, { 2951, "The Sparklematic 5200!" } },
  smgy = { { 1048, "Into The Scarlet Monastery", "H" }, { 1113, "Hearts of Zeal", "H" }, { 1051, "Vorrel's Revenge" } },
  drown = { { 95776, "The Only Good Brinescale...", "H" }, { 96774, "Ancient Gurubashi Idol", "H" },
    { 95775, "The Drowned City", "H" } },
  smlib = { { 1053, "In the Name of the Light", "A" }, { 1050, "Mythology of the Titans", "A" },
    { 1049, "Compendium of the Fallen", "H" }, { 1048, "Into The Scarlet Monastery", "H" }, { 96800, "Past Due", "A" },
    { 1113, "Hearts of Zeal", "H" }, { 1160, "Test of Lore", "H" } },
  smarm = { { 1053, "In the Name of the Light", "A" }, { 1048, "Into The Scarlet Monastery", "H" },
    { 1113, "Hearts of Zeal", "H" } },
  smcath = { { 1053, "In the Name of the Light", "A" }, { 1048, "Into The Scarlet Monastery", "H" }, { 1113, "Hearts of Zeal", "H" } },
  rfd = { { 6626, "A Host of Evil" }, { 3636, "Bring the Light", "A" }, { 3341, "Bring the End", "H" },
    { 3523, "Scourge of the Downs" }, { 3525, "Extinguishing the Idol" }, { 6521, "An Unholy Alliance", "H" } },
  ulda = { { 2278, "The Platinum Discs" }, { 2240, "The Hidden Chamber", "A" },
    { 2361, "Restoring the Necklace", "A" }, { 1139, "The Lost Tablets of Will", "A" }, { 2418, "Power Stones", "A" },
    { 704, "Agmond's Fate", "A" }, { 709, "Solution to Doom" }, { 2283, "Necklace Recovery", "H" },
    { 2398, "The Lost Dwarves", "A" }, { 17, "Uldaman Reagent Run", "A" }, { 2202, "Uldaman Reagent Run", "H" },
    { 721, "A Sign of Hope", "A" }, { 722, "Amulet of Secrets", "A" }, { 1360, "Reclaimed Treasures", "A" },
    { 2342, "Reclaimed Treasures", "H" }, { 2198, "The Shattered Necklace", "A" }, { 2199, "Lore for a Price", "A" },
    { 2200, "Back to Uldaman", "A" }, { 2201, "Find the Gems", "A" }, { 2204, "Restoring the Necklace", "A" },
    { 2279, "The Platinum Discs", "A" }, { 2280, "The Platinum Discs", "H" },
    { 2284, "Necklace Recovery, Take 2", "H" }, { 2318, "Translating the Journal", "H" },
    { 2338, "Translating the Journal", "H" }, { 2339, "Find the Gems and Power Source", "H" },
    { 2340, "Deliver the Gems", "H" }, { 2341, "Necklace Recovery, Take 3", "H" } },
  zf = { { 2770, "Gahz'rilla" }, { 2846, "Tiara of the Deep" }, { 2936, "The Spider God", "H" },
    { 2768, "Divino-matic Rod" }, { 2865, "Scarab Shells" }, { 3042, "Troll Temper" },
    { 3527, "The Prophecy of Mosh'aru" }, { 2991, "Nekrum's Medallion", "A" }, { 2861, "Tabetha's Task" },
    { 2864, "Tran'rek" } },
  mara = { { 7044, "Legends of Maraudon" }, { 7046, "The Scepter of Celebras" },
    { 7064, "Corruption of Earth and Seed", "H" }, { 7029, "Vyletongue Corruption", "H" },
    { 7041, "Vyletongue Corruption", "A" }, { 7028, "Twisted Evils" }, { 7067, "The Pariah's Instructions" },
    { 7065, "Corruption of Earth and Seed", "A" }, { 7066, "Seed of Life" }, { 7068, "Shadowshard Fragments", "H" },
    { 7070, "Shadowshard Fragments", "A" } },
  st = { { 3373, "The Essence of Eranikus" }, { 3528, "The God Hakkar" }, { 3446, "Into the Depths" },
    { 3447, "Secret of the Circle" }, { 1475, "Into The Temple of Atal'Hakkar", "A" },
    { 1446, "Jammal'an the Prophet", "A" }, { 3380, "The Sunken Temple" }, { 1445, "The Temple of Atal'Hakkar", "H" },
    { 4143, "Haze of Evil", "A" }, { 4146, "Zapper Fuel", "H" } },
  brd = { { 4136, "Ribbly Screwspigot" }, { 4123, "The Heart of the Mountain" },
    { 4134, "Lost Thunderbrew Recipe", "H" }, { 4081, "KILL ON SIGHT: Dark Iron Dwarves", "H" },
    { 4082, "KILL ON SIGHT: High Ranking Dark Iron Officials", "H" }, { 3981, "Commander Gor'shak", "H" },
    { 4341, "Kharan Mighthammer", "A" }, { 3906, "Disharmony of Flame", "H" }, { 3802, "Dark Iron Legacy" },
    { 4083, "The Spectral Chalice" }, { 4201, "The Love Potion" }, { 4126, "Hurley Blackbreath", "A" },
    { 4286, "The Good Stuff", "A" }, { 4362, "The Fate of the Kingdom", "A" }, { 3907, "Disharmony of Fire", "H" },
    { 3911, "The Last Element", "H" }, { 4024, "A Taste of Flame" }, { 4063, "The Rise of the Machines", "H" },
    { 3982, "What Is Going On?", "H" }, { 4003, "The Royal Rescue", "H" }, { 4128, "Ragnar Thunderbrew", "A" },
    { 4132, "Operation: Death to Angerforge", "H" }, { 4133, "Vivian Lagrave", "H" }, { 4263, "Incendius!", "A" },
    { 4322, "Jail Break!", "A" }, { 4324, "Yuka Screwspigot" }, { 7604, "A Binding Contract" },
    { 7848, "Attunement to the Core" } },
  lbrs = { { 4701, "Put Her Down", "A" }, { 4729, "Kibler's Exotic Pets" }, { 4742, "Seal of Ascension" },
    { 4788, "The Final Tablets" }, { 4862, "En-Ay-Es-Tee-Why" }, { 4866, "Mother's Milk" }, { 4867, "Urok Doomhowl" },
    { 5001, "Bijou's Belongings" }, { 4903, "Warlord's Command", "H" }, { 5089, "General Drakkisath's Command", "A" },
    { 4724, "The Pack Mistress", "H" }, { 4982, "Bijou's Belongings", "H" }, { 5081, "Maxwell's Mission", "A" } },
  ubrs = { { 5102, "General Drakkisath's Demise", "A" }, { 4974, "For The Horde!", "H" }, { 4734, "Egg Freezing" },
    { 7761, "Blackhand's Command" }, { 4735, "Egg Collection" }, { 4743, "Seal of Ascension" },
    { 4764, "Doomrigger's Clasp", "A" }, { 4766, "Mayara Brightwing", "A" }, { 4768, "The Darkstone Tablet", "H" },
    { 4769, "Vivian Lagrave and the Darkstone Tablet", "H" }, { 5047, "Pip Quickwit, At Your Service!" },
    { 5127, "The Demon Forge" }, { 5160, "The Matron Protectorate" }, { 6502, "Drakefire Amulet", "A" },
    { 6569, "Oculus Illusions", "H" }, { 6602, "Blood of the Black Dragon Champion", "H" } },
  dme = { { 7488, "Lethtendris's Web", "A" }, { 7489, "Lethtendris's Web", "H" },
    { 7441, "Pusillin and the Elder Azj'Tordin" }, { 5526, "Shards of the Felvine" },
    { 5527, "A Reliquary of Purity" }, { 7492, "Camp Mojache", "H" }, { 7494, "Feathermoon Stronghold", "A" } },
  -- Elven Legends and Unfinished Gordok Business lead into both wings (wowf.io lists them on both). No Librams:
  -- wowf.io's 7483-7485 are not in WoW Forever's quest table (docs/QUEST-SOURCES.md).
  dmw = { { 7482, "Elven Legends", "A" }, { 7481, "Elven Legends", "H" }, { 7461, "The Madness Within" },
    { 7703, "Unfinished Gordok Business" } },
  dmn = { { 7482, "Elven Legends", "A" }, { 7481, "Elven Legends", "H" }, { 5518, "The Gordok Ogre Suit" },
    { 5525, "Free Knot!" }, { 7703, "Unfinished Gordok Business" } },
  strat = { { 5212, "The Flesh Does Not Lie", "A" }, { 5243, "Houses of the Holy" },
    { 5213, "The Active Agent", "A" }, { 5848, "Of Love and Family" }, { 5251, "The Archivist" },
    { 5262, "The Truth Comes Crashing Down" }, { 5125, "Aurius' Reckoning" }, { 6163, "Ramstein", "H" },
    { 5214, "The Great Ezra Grimm" }, { 5263, "Above and Beyond" }, { 5282, "The Restless Souls" },
    { 5463, "Menethil's Gift" }, { 8945, "Dead Man's Plea" } },
  scholo = { { 5382, "Doctor Theolen Krastinov, the Butcher" }, { 5384, "Kirtonos the Herald" },
    { 5466, "The Lich, Ras Frostwhisper" }, { 5529, "Plagued Hatchlings" },
    { 5515, "Krastinov's Bag of Horrors" }, { 5343, "Barov Family Fortune", "A" }, { 5341, "Barov Family Fortune", "H" },
    { 4771, "Dawn's Gambit" } },
}

-- Where each dungeon quest starts (U79, 7 Nov 2026), from public sources (docs/QUEST-SOURCES.md): by (the quest
-- giver), zone (its map's name), x, y (the position on that map, 0 to 100), lvl (the quest's level), min (the level it
-- can be taken from), item (it starts from this item), inside (it starts in the dungeon), after = { { id, name, lvl,
-- by, item, zone, inside } } (the chain to do first, first step first: each step's quest and where it starts, from
-- wowf.io's required steps; same-named parts in a row are one step, its first part's giver and its last part's ID),
-- xp (the XP it pays in WoW Forever, for the Room card, U78; never a Classic value: Forever pays about twice as much).
-- Only what WoW Forever sources show: the rest is learned in game (QL:Learn), and chains also from Questie (QL:Before).
ns.QUEST_STARTS = {
  -- Ragefire Chasm
  [5723] = { by = "Rahauro", zone = "Thunder Bluff", x = 70.8, y = 31.6, lvl = 15 },
  [5725] = { by = "Varimathras", zone = "Undercity", x = 56.4, y = 92.6, lvl = 16 },
  [5728] = { by = "Thrall", zone = "Orgrimmar", x = 31.7, y = 38.0, lvl = 16,
    after = { { 5727, "Hidden Enemies", lvl = 12, by = "Thrall", zone = "Orgrimmar" } } },
  [5761] = { by = "Neeru Fireblade", zone = "Orgrimmar", x = 49.5, y = 50.4, lvl = 16 },
  [5722] = { by = "Rahauro", zone = "Thunder Bluff", x = 70.8, y = 31.6, lvl = 16 },
  [5724] = { item = "Grimtotem Satchel", inside = true, lvl = 16 },
  -- The Deadmines
  [214] = { by = "Scout Riell", zone = "Westfall", x = 56.7, y = 47.4, lvl = 17, min = 14,
    after = { { 155, "The Defias Brotherhood", lvl = 18, by = "Gryan Stoutmantle", zone = "Westfall" } } },
  [168] = { by = "Wilder Thistlenettle", zone = "Stormwind City", x = 70.2, y = 40.9, lvl = 18, min = 14, xp = 1350 },
  [92753] = { item = "Extra-Destructive Explosives", lvl = 18, min = 9, after = {
    { 92744, "Murloc Gills", by = "Alba Fairmoon", zone = "Westfall" },
    { 92745, "The State of the Mines", by = "Alba Fairmoon", zone = "Westfall" },
    { 92747, "Moonbrook Espionage", by = "Alba Fairmoon", zone = "Westfall" },
    { 92748, "Explosive Consultation", by = "Alba Fairmoon", zone = "Westfall" },
    { 92749, "A Dynamite Plan", by = "Sprite Jumpsprocket", zone = "Stormwind City" },
    { 92751, "Detonation at a Distance", by = "Sprite Jumpsprocket", zone = "Stormwind City" },
    { 92752, "Explosive Consultation", by = "Sprite Jumpsprocket", zone = "Stormwind City" }
  } },
  [167] = { by = "Wilder Thistlenettle", zone = "Stormwind City", x = 70.2, y = 40.9, lvl = 20, min = 15, xp = 1550 },
  [2040] = { by = "Shoni the Shilent", zone = "Stormwind City", x = 62.6, y = 34.2, lvl = 20, min = 15 },
  [166] = { by = "Gryan Stoutmantle", zone = "Westfall", x = 56.3, y = 47.6, lvl = 22, min = 14,
    after = { { 155, "The Defias Brotherhood", lvl = 18, by = "Gryan Stoutmantle", zone = "Westfall" } } },
  [373] = { item = "An Unsent Letter", inside = true, lvl = 22 },
  -- Wailing Caverns
  [1486] = { by = "Nalpak", zone = "The Barrens", lvl = 17, min = 13 },
  [1491] = { by = "Mebok Mizzyrix", zone = "The Barrens", x = 62.4, y = 37.6, lvl = 18, min = 13,
    after = { { 865, "Raptor Horns", lvl = 18, by = "Mebok Mizzyrix", zone = "The Barrens" } } },
  [959] = { by = "Crane Operator Bigglefuzz", zone = "The Barrens", lvl = 18, min = 14 },
  [962] = { by = "Apothecary Zamah", zone = "Thunder Bluff", lvl = 18, min = 14 },
  [1487] = { by = "Ebru", zone = "The Barrens", lvl = 21, min = 15 },
  [914] = { by = "Nara Wildmane", zone = "Thunder Bluff", lvl = 22, min = 10, after = {
    { 870, "The Forgotten Pools", lvl = 13, by = "Tonga Runetotem", zone = "The Barrens" },
    { 877, "The Stagnant Oasis", lvl = 16, by = "Tonga Runetotem", zone = "The Barrens" },
    { 880, "Altered Beings", lvl = 16, by = "Tonga Runetotem", zone = "The Barrens" },
    { 1489, "Hamuul Runetotem", lvl = 16, by = "Tonga Runetotem", zone = "The Barrens" },
    { 1490, "Nara Wildmane", lvl = 16, by = "Arch Druid Hamuul Runetotem", zone = "Thunder Bluff" }
  } },
  [6981] = { item = "Glowing Shard", inside = true, lvl = 26, min = 15 },
  -- Shadowfang Keep
  [1098] = { by = "High Executor Hadrec", zone = "Silverpine Forest", lvl = 25, min = 18 },
  [1013] = { by = "Keeper Bel'dugur", zone = "Undercity", lvl = 26, min = 16 },
  [1014] = { by = "Dalar Dawnweaver", zone = "Silverpine Forest", lvl = 27, min = 18 },
  -- Blackfathom Deeps
  [6563] = { by = "Je'neu Sancrea", zone = "Ashenvale", lvl = 22, min = 17, xp = 1750 },
  [6564] = { item = "Damp Note", zone = "Ashenvale", lvl = 22, min = 17, xp = 1300,
    after = { { 6562, "Trouble in the Deeps", lvl = 22, by = "Tsunaman", zone = "Stonetalon Mountains" } } },
  [971] = { by = "Gerrig Bonegrip", zone = "Ironforge", x = 50.5, y = 6.0, lvl = 23, min = 18 },
  [1198] = { by = "Dawnwatcher Shaedlass", zone = "Darnassus", lvl = 24, min = 18 },
  [1275] = { by = "Gershala Nightwhisper", zone = "Darkshore", x = 38.3, y = 43.0, lvl = 24, xp = 2400 },
  [1199] = { by = "Argent Guard Manados", zone = "Darnassus", lvl = 25, min = 20 },
  [6565] = { by = "Je'neu Sancrea", zone = "Ashenvale", lvl = 26, min = 17, after = {
    { 6562, "Trouble in the Deeps", lvl = 22, by = "Tsunaman", zone = "Stonetalon Mountains" },
    { 6564, "Allegiance to the Old Gods", lvl = 22, item = "Damp Note", zone = "Ashenvale" }
  } },
  [1200] = { by = "Argent Guard Thaelrid", inside = true, lvl = 27, min = 18 },
  [6921] = { by = "Je'neu Sancrea", zone = "Ashenvale", lvl = 27, min = 21 },
  [6561] = { by = "Argent Guard Thaelrid", inside = true, lvl = 27, min = 18 },
  [6922] = { item = "Strange Water Globe", inside = true, lvl = 30, min = 21 },
  -- The Stockade
  [386] = { by = "Guard Berton", zone = "Redridge Mountains", x = 21.3, y = 46.6, lvl = 25 },
  [377] = { by = "Councilman Millstipe", zone = "Duskwood", x = 72.0, y = 47.7, lvl = 26 },
  [387] = { by = "Warden Thelwater", zone = "Stormwind City", x = 51.5, y = 69.2, lvl = 26 },
  [388] = { by = "Nikova Raskol", zone = "Stormwind City", x = 76.3, y = 63.6, lvl = 26 },
  [378] = { by = "Motley Garmason", lvl = 27,
    after = { { 303, "The Dark Iron War", lvl = 30, by = "Motley Garmason", zone = "Wetlands" } } },
  [391] = { lvl = 29, min = 16, after = {
    { 373, "The Unsent Letter", lvl = 22, item = "An Unsent Letter", zone = "The Deadmines" },
    { 389, "Bazil Thredd", lvl = 22, by = "Baros Alexston", zone = "Stormwind City" }
  } },
  -- Razorfen Kraul
  [1221] = { by = "Mebok Mizzyrix", zone = "The Barrens", x = 62.4, y = 37.6, lvl = 26, min = 20, xp = 5000 },
  [1142] = { by = "Heralath Fallowbrook", inside = true, lvl = 30, min = 25 },
  [1144] = { by = "Willix the Importer", inside = true, lvl = 30, min = 22 },
  [1109] = { by = "Master Apothecary Faranell", zone = "Undercity", lvl = 33, min = 30 },
  [1102] = { by = "Auld Stonespire", zone = "Thunder Bluff", lvl = 34, min = 29 },
  [1101] = { by = "Falfindel Waywarder", zone = "Feralas", lvl = 34, min = 29,
    after = { { 1100, "Lonebrow's Journal", lvl = 34, item = "Henrig Lonebrow's Journal" } } },
  [6522] = { item = "Small Scroll", inside = true, lvl = 36, min = 28 },
  -- Gnomeregan
  [2922] = { by = "Tinkmaster Overspark", zone = "Ironforge", lvl = 26, min = 20 },
  [2926] = { item = "Empty Leaden Collection Phial", lvl = 27 },
  [2927] = { lvl = 27, min = 20 },
  [2904] = { by = "Kernobee", inside = true, lvl = 30, min = 20 },
  [2928] = { by = "Shoni the Shilent", zone = "Stormwind City", lvl = 30, min = 20 },
  [2962] = { by = "Ozzie Togglevolt", zone = "Dun Morogh", lvl = 30, min = 20, after = {
    { 2927, "The Day After", lvl = 27, by = "Gnoarn", zone = "Ironforge" },
    { 2926, "Gnogaine", lvl = 27, by = "Ozzie Togglevolt", zone = "Dun Morogh" }
  } },
  [2924] = { by = "Klockmort Spannerspan", zone = "Ironforge", lvl = 30, min = 24 },
  [2951] = { by = "The Sparklematic 5200", inside = true, lvl = 30, min = 25 },
  [2930] = { by = "Master Mechanic Castpipe", zone = "Ironforge", x = 69.9, y = 48.5, lvl = 30, min = 25 },
  [2945] = { item = "Grime-Encrusted Ring", inside = true, lvl = 34, min = 28 },
  [2929] = { by = "High Tinker Mekkatorque", zone = "Ironforge", x = 68.7, y = 49.1, lvl = 35, min = 25 },
  [2841] = { by = "Nogg", zone = "Orgrimmar", lvl = 35, min = 25 },
  -- Scarlet Monastery
  [1051] = { by = "Vorrel Sengutz", inside = true, lvl = 33, min = 25 },
  [1113] = { by = "Master Apothecary Faranell", zone = "Undercity", lvl = 33, min = 30,
    after = { { 1109, "Going, Going, Guano!", lvl = 33, by = "Master Apothecary Faranell", zone = "Undercity" } } },
  [1160] = { by = "Parqual Fintallas", zone = "Undercity", lvl = 36, min = 26, after = {
    { 1149, "Test of Faith", lvl = 26, by = "Dorn Plainstalker", zone = "Thousand Needles" },
    { 1150, "Test of Endurance", lvl = 30, by = "Dorn Plainstalker", zone = "Thousand Needles" },
    { 1151, "Test of Strength", lvl = 30, by = "Dorn Plainstalker", zone = "Thousand Needles" },
    { 1159, "Test of Lore", lvl = 30, by = "Dorn Plainstalker", zone = "Thousand Needles" }
  } },
  [1050] = { by = "Librarian Mae Paledust", zone = "Ironforge", x = 74.9, y = 12.2, lvl = 38, min = 28 },
  [1049] = { by = "Sage Truthseeker", zone = "Thunder Bluff", lvl = 38, min = 28 },
  [96800] = { by = "Magus Olvek", zone = "Alterac Mountains", lvl = 38, min = 30 },
  [1053] = { by = "Raleigh the Devout", zone = "Hillsbrad Foothills", lvl = 40, min = 34,
    after = { { 1052, "Down the Scarlet Path", lvl = 39, by = "Brother Anton", zone = "Desolace" } } },
  [1048] = { by = "Varimathras", zone = "Undercity", lvl = 42, min = 33 },
  -- Razorfen Downs
  [6626] = { by = "Myriam Moonsinger", zone = "The Barrens", lvl = 35, min = 28 },
  [6521] = { by = "Varimathras", zone = "Undercity", lvl = 36, min = 28,
    after = { { 6522, "An Unholy Alliance", lvl = 36, item = "Small Scroll", zone = "Razorfen Kraul" } } },
  [3523] = { by = "Belnistrasz", inside = true, lvl = 37, min = 32 },
  [3525] = { by = "Belnistrasz", inside = true, lvl = 37, min = 32,
    after = { { 3523, "Scourge of the Downs", lvl = 37, by = "Belnistrasz", inside = true } } },
  [3636] = { by = "Archbishop Benedictus", zone = "Stormwind City", lvl = 42, min = 39 },
  [3341] = { by = "Andrew Brownell", zone = "Undercity", lvl = 42, min = 37 },
  -- Uldaman
  [2279] = { by = "The Discs of Norgannon", inside = true, min = 40,
    after = { { 2278, "The Platinum Discs", lvl = 47, by = "The Discs of Norgannon", inside = true } } },
  [721] = { by = "Prospector Ryedol", zone = "Badlands", lvl = 35, min = 35,
    after = { { 720, "A Sign of Hope", by = "Crumpled Map", zone = "Badlands" } } },
  [2418] = { by = "Rigglefuzz", zone = "Badlands", lvl = 36, min = 30, xp = 3500 },
  [704] = { by = "Prospector Ironband", zone = "Loch Modan", lvl = 38, min = 30, after = {
    { 707, "Ironband Wants You!", by = "Prospector Stormpike", zone = "Ironforge" },
    { 738, "Find Agmond", by = "Prospector Ironband", zone = "Loch Modan" },
    { 739, "Murdaloc", by = "Battered Dwarven Skeleton", zone = "Badlands" }
  } },
  [709] = { by = "Theldurin the Lost", zone = "Badlands", lvl = 40, min = 30 },
  [2398] = { by = "Prospector Stormpike", zone = "Ironforge", lvl = 40, min = 35 },
  [2240] = { by = "Baelog", inside = true, lvl = 40, min = 35,
    after = { { 2398, "The Lost Dwarves", lvl = 40, by = "Prospector Stormpike", zone = "Ironforge" } } },
  [722] = { by = "Hammertoe Grez", zone = "Loch Modan", lvl = 40, min = 35,
    after = { { 721, "A Sign of Hope", by = "Crumpled Map", zone = "Badlands" } } },
  [2283] = { by = "Dran Droffers", zone = "Orgrimmar", lvl = 41, min = 37 },
  [2198] = { item = "Shattered Necklace", zone = "Badlands", lvl = 41, min = 37 },
  [2199] = { by = "Talvash del Kissel", zone = "Ironforge", lvl = 41, min = 37,
    after = { { 2198, "The Shattered Necklace", lvl = 41, item = "Shattered Necklace", zone = "Badlands" } } },
  [2284] = { by = "Dran Droffers", zone = "Orgrimmar", lvl = 41, min = 37,
    after = { { 2283, "Necklace Recovery", lvl = 41, by = "Dran Droffers", zone = "Orgrimmar" } } },
  [17] = { by = "Ghak Healtouch", zone = "Loch Modan", lvl = 42, min = 36,
    after = { { 2500, "Badlands Reagent Run", by = "Ghak Healtouch", zone = "Loch Modan" } } },
  [2202] = { by = "Jarkal Mossmeld", zone = "Badlands", lvl = 42, min = 36,
    after = { { 2258, "Badlands Reagent Run", by = "Jarkal Mossmeld", zone = "Badlands" } } },
  [2200] = { by = "Talvash del Kissel", zone = "Ironforge", lvl = 42, min = 37, after = {
    { 2198, "The Shattered Necklace", lvl = 41, item = "Shattered Necklace", zone = "Badlands" },
    { 2199, "Lore for a Price", lvl = 41, by = "Talvash del Kissel", zone = "Ironforge" }
  } },
  [2318] = { by = "Remains of a Paladin", inside = true, lvl = 42, min = 37, after = {
    { 2283, "Necklace Recovery", lvl = 41, by = "Dran Droffers", zone = "Orgrimmar" },
    { 2284, "Necklace Recovery, Take 2", lvl = 41, by = "Dran Droffers", zone = "Orgrimmar" }
  } },
  [2338] = { by = "Jarkal Mossmeld", zone = "Badlands", lvl = 42, min = 37, after = {
    { 2283, "Necklace Recovery", lvl = 41, by = "Dran Droffers", zone = "Orgrimmar" },
    { 2284, "Necklace Recovery, Take 2", lvl = 41, by = "Dran Droffers", zone = "Orgrimmar" },
    { 2318, "Translating the Journal", lvl = 42, by = "Remains of a Paladin", inside = true }
  } },
  [1360] = { by = "Krom Stoutarm", zone = "Ironforge", lvl = 43, min = 33 },
  [2342] = { by = "Patrick Garrett", zone = "Undercity", lvl = 43, min = 33 },
  [2201] = { by = "Remains of a Paladin", inside = true, lvl = 43, min = 40, after = {
    { 2198, "The Shattered Necklace", lvl = 41, item = "Shattered Necklace", zone = "Badlands" },
    { 2199, "Lore for a Price", lvl = 41, by = "Talvash del Kissel", zone = "Ironforge" },
    { 2200, "Back to Uldaman", lvl = 42, by = "Talvash del Kissel", zone = "Ironforge" }
  } },
  [2361] = { by = "Talvash del Kissel", zone = "Ironforge", lvl = 44, min = 37, after = {
    { 2198, "The Shattered Necklace", lvl = 41, item = "Shattered Necklace", zone = "Badlands" },
    { 2199, "Lore for a Price", lvl = 41, by = "Talvash del Kissel", zone = "Ironforge" },
    { 2200, "Back to Uldaman", lvl = 42, by = "Talvash del Kissel", zone = "Ironforge" },
    { 2201, "Find the Gems", lvl = 43, by = "Remains of a Paladin", inside = true },
    { 2204, "Restoring the Necklace", lvl = 44, by = "Talvash's Scrying Bowl", inside = true }
  } },
  [2204] = { by = "Talvash's Scrying Bowl", inside = true, lvl = 44, min = 37, after = {
    { 2198, "The Shattered Necklace", lvl = 41, item = "Shattered Necklace", zone = "Badlands" },
    { 2199, "Lore for a Price", lvl = 41, by = "Talvash del Kissel", zone = "Ironforge" },
    { 2200, "Back to Uldaman", lvl = 42, by = "Talvash del Kissel", zone = "Ironforge" },
    { 2201, "Find the Gems", lvl = 43, by = "Remains of a Paladin", inside = true }
  } },
  [2339] = { by = "Jarkal Mossmeld", zone = "Badlands", lvl = 44, min = 37, after = {
    { 2283, "Necklace Recovery", lvl = 41, by = "Dran Droffers", zone = "Orgrimmar" },
    { 2284, "Necklace Recovery, Take 2", lvl = 41, by = "Dran Droffers", zone = "Orgrimmar" },
    { 2338, "Translating the Journal", lvl = 42, by = "Remains of a Paladin", inside = true }
  } },
  [2340] = { by = "Jarkal Mossmeld", zone = "Badlands", lvl = 44, min = 37, after = {
    { 2283, "Necklace Recovery", lvl = 41, by = "Dran Droffers", zone = "Orgrimmar" },
    { 2284, "Necklace Recovery, Take 2", lvl = 41, by = "Dran Droffers", zone = "Orgrimmar" },
    { 2338, "Translating the Journal", lvl = 42, by = "Remains of a Paladin", inside = true },
    { 2339, "Find the Gems and Power Source", lvl = 44, by = "Jarkal Mossmeld", zone = "Badlands" }
  } },
  [2341] = { by = "Dran Droffers", zone = "Orgrimmar", lvl = 44, min = 40, after = {
    { 2283, "Necklace Recovery", lvl = 41, by = "Dran Droffers", zone = "Orgrimmar" },
    { 2284, "Necklace Recovery, Take 2", lvl = 41, by = "Dran Droffers", zone = "Orgrimmar" },
    { 2338, "Translating the Journal", lvl = 42, by = "Remains of a Paladin", inside = true },
    { 2339, "Find the Gems and Power Source", lvl = 44, by = "Jarkal Mossmeld", zone = "Badlands" },
    { 2340, "Deliver the Gems", lvl = 44, by = "Jarkal Mossmeld", zone = "Badlands" }
  } },
  [1139] = { by = "Advisor Belgrum", zone = "Ironforge", lvl = 45, min = 35, after = {
    { 721, "A Sign of Hope", by = "Crumpled Map", zone = "Badlands" },
    { 722, "Amulet of Secrets", lvl = 40, by = "Hammertoe Grez", zone = "Loch Modan" },
    { 724, "Prospect of Faith", by = "Hammertoe Grez", zone = "Loch Modan" },
    { 726, "Passing Word of a Threat", by = "Historian Karnik", zone = "Ironforge" },
    { 762, "An Ambassador of Evil", lvl = 44, by = "Historian Karnik", zone = "Ironforge" }
  } },
  [2278] = { by = "The Discs of Norgannon", inside = true, lvl = 47, min = 40 },
  [2280] = { by = "The Discs of Norgannon", inside = true, lvl = 47, min = 40,
    after = { { 2278, "The Platinum Discs", lvl = 47, by = "The Discs of Norgannon", inside = true } } },
  -- Zul'Farrak
  [2865] = { by = "Tran'rek", zone = "Tanaris", lvl = 45, min = 40 },
  [3042] = { by = "Trenton Lighthammer", zone = "Tanaris", lvl = 45, min = 40 },
  [2936] = { by = "Master Gadrin", zone = "Durotar", lvl = 45, min = 40 },
  [2864] = { by = "Krazek", zone = "Stranglethorn Vale", lvl = 45, min = 40 },
  [2846] = { by = "Tabetha", zone = "Dustwallow Marsh", lvl = 46, min = 40 },
  [2861] = { by = "Anastasia Hartwell", zone = "Undercity", lvl = 46, min = 40 },
  [2768] = { by = "Chief Engineer Bilgewhizzle", zone = "Tanaris", lvl = 47, min = 40 },
  [3527] = { by = "Yeh'kinya", zone = "Tanaris", lvl = 47, min = 40 },
  [2991] = { by = "Thadius Grimshade", zone = "Blasted Lands", lvl = 47, min = 40 },
  [2770] = { by = "Wizzle Brassbolts", zone = "Thousand Needles", lvl = 50, min = 40 },
  -- Maraudon
  [7068] = { by = "Uthel'nay", zone = "Orgrimmar", lvl = 42, min = 39 },
  [7070] = { by = "Archmage Tervosh", zone = "Dustwallow Marsh", lvl = 42, min = 39 },
  [7041] = { by = "Talendria", zone = "Desolace", lvl = 47, min = 41 },
  [7029] = { by = "Vark Battlescar", zone = "Desolace", lvl = 47, min = 41 },
  [7028] = { by = "Willow", zone = "Desolace", lvl = 47, min = 41 },
  [7067] = { by = "Centaur Pariah", zone = "Desolace", lvl = 48, min = 39 },
  [7044] = { by = "Cavindra", zone = "Desolace", lvl = 49, min = 41 },
  [7046] = { by = "Celebras the Redeemed", inside = true, lvl = 49, min = 41 },
  [7064] = { by = "Selendra", zone = "Desolace", lvl = 51, min = 45 },
  [7065] = { by = "Keeper Marandis", zone = "Desolace", lvl = 51, min = 45 },
  [7066] = { by = "Zaetar's Spirit", inside = true, lvl = 51, min = 45 },
  -- The Sunken Temple
  [1475] = { by = "Brohann Caskbelly", zone = "Stormwind City", lvl = 50, min = 41 },
  [1445] = { by = "Fel'zerul", zone = "Swamp of Sorrows", lvl = 50, min = 38 },
  [3446] = { by = "Marvon Rivetseeker", zone = "Tanaris", lvl = 51, min = 46 },
  [3447] = { by = "Marvon Rivetseeker", zone = "Tanaris", lvl = 51, min = 46 },
  [4143] = { by = "Gregan Brewspewer", zone = "Feralas", lvl = 52, min = 47 },
  [4146] = { by = "Liv Rizzlefix", zone = "The Barrens", lvl = 52, min = 47 },
  [3528] = { by = "Yeh'kinya", zone = "Tanaris", lvl = 53, min = 40 },
  [1446] = { by = "Atal'ai Exile", zone = "The Hinterlands", lvl = 53, min = 38 },
  [3373] = { item = "Essence of Eranikus", inside = true, lvl = 55, min = 48 },
  -- Blackrock Depths
  [3802] = { by = "Franclorn Forgewright", zone = "Burning Steppes", lvl = 52, min = 48 },
  [4081] = { zone = "Badlands", lvl = 52, min = 48 },
  [4136] = { by = "Yuka Screwspigot", zone = "Burning Steppes", lvl = 53, min = 48 },
  [4324] = { by = "Yorba Screwspigot", zone = "Tanaris", lvl = 53, min = 48 },
  [4082] = { zone = "Badlands", lvl = 54, min = 50 },
  [3911] = { by = "Shadowmage Vivian Lagrave", zone = "Badlands", lvl = 54, min = 48, xp = 5450 }, -- 3911 in WoW Forever (7201 in Classic)
  [4201] = { by = "Mistress Nagmara", inside = true, lvl = 54, min = 50 },
  [3982] = { by = "Commander Gor'shak", inside = true, lvl = 54, min = 48 },
  [4126] = { by = "Ragnar Thunderbrew", zone = "Dun Morogh", lvl = 55, min = 50 },
  [4123] = { by = "Maxwort Uberglint", zone = "Burning Steppes", lvl = 55, min = 50 },
  [4134] = { by = "Shadowmage Vivian Lagrave", zone = "Badlands", lvl = 55, min = 50 },
  [4083] = { inside = true, lvl = 55, min = 40 },
  [4128] = { by = "Enohar Thunderbrew", zone = "Blasted Lands", lvl = 55, min = 50 },
  [4133] = { by = "Apothecary Zinge", zone = "Undercity", lvl = 55, min = 50 },
  [4286] = { by = "Oralius", zone = "Burning Steppes", lvl = 56, min = 50 },
  [3907] = { by = "Thunderheart", zone = "Badlands", lvl = 56, min = 48 },
  [4263] = { by = "Jalinda Sprig", zone = "Burning Steppes", lvl = 56, min = 48 },
  [4024] = { by = "Cyrus Therepentous", zone = "Burning Steppes", lvl = 58, min = 52 },
  [4063] = { by = "Lotwil Veriatus", zone = "Badlands", lvl = 58, min = 52 },
  [4132] = { by = "Warlord Goretooth", zone = "Badlands", lvl = 58, min = 52 },
  [4322] = { by = "Marshal Windsor", inside = true, lvl = 58, min = 50 },
  [4362] = { by = "King Magni Bronzebeard", zone = "Ironforge", lvl = 59, min = 50 },
  [4003] = { by = "Thrall", zone = "Orgrimmar", lvl = 59, min = 48 },
  [7604] = { item = "Thorium Brotherhood Contract", inside = true, lvl = 60, min = 60 },
  [7848] = { by = "Lothos Riftwaker", zone = "Searing Gorge", lvl = 60, min = 55 },
  -- Lower and Upper Blackrock Spire
  [4788] = { by = "Prospector Ironboot", zone = "Tanaris", lvl = 58, min = 40 },
  [4701] = { by = "Helendis Riverhorn", zone = "Burning Steppes", lvl = 59, min = 55 },
  [4729] = { by = "Kibler", zone = "Burning Steppes", lvl = 59, min = 55 },
  [4862] = { by = "Kibler", zone = "Burning Steppes", lvl = 59, min = 55 },
  [5001] = { by = "Bijou", inside = true, lvl = 59, min = 55 },
  [4724] = { by = "Galamav the Marksman", zone = "Badlands", lvl = 59, min = 55 },
  [4982] = { by = "Bijou", inside = true, lvl = 59, min = 55 },
  [4866] = { by = "Ragged John", zone = "Burning Steppes", lvl = 60, min = 55 },
  [4903] = { by = "Warlord Goretooth", zone = "Badlands", lvl = 60, min = 55 },
  [4867] = { by = "Warosh", inside = true, lvl = 60, min = 55 },
  [5089] = { inside = true, lvl = 60, min = 55 },
  [4742] = { by = "Scarshield Infiltrator", inside = true, lvl = 60, min = 57 },
  [5102] = { by = "Marshal Maxwell", zone = "Burning Steppes", lvl = 60, min = 55 },
  [5081] = { by = "Marshal Maxwell", zone = "Burning Steppes", lvl = 60, min = 55 },
  [4974] = { by = "Thrall", zone = "Orgrimmar", lvl = 60, min = 55 },
  [7761] = { zone = "Burning Steppes", lvl = 60, min = 55 },
  [4735] = { by = "Tinkee Steamboil", zone = "Burning Steppes", lvl = 60, min = 57 },
  [4743] = { by = "Scarshield Infiltrator", inside = true, lvl = 60, min = 57 },
  [4764] = { by = "Mayara Brightwing", zone = "Burning Steppes", lvl = 60, min = 57 },
  [4766] = { by = "Count Remington Ridgewell", zone = "Stormwind City", lvl = 60, min = 57 },
  [4768] = { by = "Shadowmage Vivian Lagrave", zone = "Badlands", lvl = 60, min = 57 },
  [4769] = { by = "Apothecary Zinge", zone = "Undercity", lvl = 60, min = 57 },
  [5047] = { by = "Pip Quickwit", inside = true, lvl = 60, min = 55 },
  [5127] = { by = "Lorax", zone = "Winterspring", lvl = 60, min = 55 },
  [5160] = { by = "Awbee", inside = true, lvl = 60, min = 57 },
  [6502] = { by = "Haleh", zone = "Winterspring", lvl = 60, min = 50 },
  [6569] = { by = "Myranda the Hag", zone = "Western Plaguelands", lvl = 60, min = 55 },
  [6602] = { by = "Rexxar", zone = "Desolace", lvl = 60, min = 55 },
  -- Dire Maul: East
  [7488] = { by = "Latronicus Moonspear", zone = "Feralas", lvl = 57, min = 54 },
  [7489] = { by = "Talo Thornhoof", zone = "Feralas", lvl = 57, min = 54 },
  [7492] = { by = "Harbinger Balthazad", zone = "Undercity", lvl = 57, min = 54 },
  [7494] = { by = "Crier Goodman", zone = "Stormwind City", lvl = 57, min = 54 },
  [7441] = { by = "Azj'Tordin", zone = "Feralas", lvl = 58, min = 54 },
  [5526] = { by = "Rabine Saturna", zone = "Moonglade", lvl = 60, min = 56 },
  -- Dire Maul: West and North
  [7482] = { by = "Scholar Runethorn", zone = "Feralas", lvl = 60, min = 54 },
  [7481] = { by = "Sage Korolusk", zone = "Feralas", lvl = 60, min = 54 },
  [7461] = { by = "Shen'dralar Ancient", inside = true, lvl = 60, min = 56 },
  [7703] = { by = "Captain Kromcrush", inside = true, lvl = 60, min = 56 },
  [5518] = { by = "Knot Thimblejack", inside = true, lvl = 60, min = 56 },
  [5525] = { by = "Knot Thimblejack", inside = true, lvl = 60, min = 57 },
  -- Stratholme
  [5848] = { by = "Artist Renfray", zone = "Western Plaguelands", lvl = 60, min = 52 },
  [5243] = { by = "Leonid Barthalomew the Revered", zone = "Eastern Plaguelands", lvl = 60, min = 55 },
  [5251] = { by = "Duke Nicholas Zverenhoff", zone = "Eastern Plaguelands", lvl = 60, min = 55 },
  [5212] = { by = "Betina Bigglezink", zone = "Eastern Plaguelands", lvl = 60, min = 55 },
  [5213] = { by = "Betina Bigglezink", zone = "Eastern Plaguelands", lvl = 60, min = 55 },
  [5262] = { inside = true, lvl = 60, min = 55 },
  [5125] = { by = "Aurius", inside = true, lvl = 60, min = 55 },
  [6163] = { by = "Nathanos Blightcaller", zone = "Eastern Plaguelands", lvl = 60, min = 56 },
  [5214] = { by = "Smokey LaRue", zone = "Eastern Plaguelands", lvl = 60, min = 55 },
  [5263] = { by = "Duke Nicholas Zverenhoff", zone = "Eastern Plaguelands", lvl = 60, min = 55 },
  [5282] = { by = "Egan", zone = "Eastern Plaguelands", lvl = 60, min = 55 },
  [5463] = { by = "Leonid Barthalomew the Revered", zone = "Eastern Plaguelands", lvl = 60, min = 57 },
  [8945] = { by = "Anthion Harmon", zone = "Eastern Plaguelands", lvl = 60, min = 58 },
  -- Scholomance
  [5343] = { by = "Weldon Barov", zone = "Western Plaguelands", lvl = 60, min = 52 },
  [5341] = { by = "Alexi Barov", zone = "Tirisfal Glades", lvl = 60, min = 52 },
  [5529] = { by = "Betina Bigglezink", zone = "Eastern Plaguelands", lvl = 58, min = 55 },
  [5382] = { by = "Eva Sarkhoff", zone = "Western Plaguelands", lvl = 60, min = 55 },
  [5384] = { by = "Eva Sarkhoff", zone = "Western Plaguelands", lvl = 60, min = 55 },
  [5515] = { by = "Eva Sarkhoff", zone = "Western Plaguelands", lvl = 60, min = 55 },
  [5466] = { by = "Magistrate Marduke", zone = "Western Plaguelands", lvl = 60, min = 57 },
  [4771] = { by = "Betina Bigglezink", zone = "Eastern Plaguelands", lvl = 60, min = 57 },
  -- The dungeons new in WoW Forever (7 Nov 2026): wowforevertalents.com and wowf.io; the IDs of the steps before from
  -- warcraft.wiki.gg, whose pages of these Forever-only quests are Forever's (docs/QUEST-SOURCES.md).
  -- The Hall of Thanes
  [96395] = { by = "Ghostly Attendant", inside = true, lvl = 15, min = 10 },
  [96403] = { by = "Thom Filch", zone = "Ironforge", x = 32.0, y = 45.0, lvl = 15, min = 10 },
  [96394] = { by = "Afadra Dunwall", zone = "Ironforge", x = 33.9, y = 48.1, lvl = 15, min = 10 },
  [96393] = { by = "Earthseer Farsen", zone = "Dun Morogh", x = 64.8, y = 58.5, lvl = 16, min = 9,
    after = { { 96391, "Underground Map", lvl = 15, item = "Dark Iron Map", zone = "Dun Morogh" } } },
  [98423] = { item = "Treaty of Understanding", inside = true, lvl = 16, min = 9 },
  -- Ruins of Lordaeron
  [95250] = { by = "Captain Truman", inside = true, lvl = 21, min = 16 },
  [95195] = { item = "Bloodied Insignia", inside = true, lvl = 22, min = 16 },
  [95189] = { item = "Crest of Lordaeron", inside = true, lvl = 22, min = 16 },
  [92415] = { item = "Blood-Stained Letter", inside = true, lvl = 22, min = 15 },
  [92401] = { by = "Tabitha Heartweaver", zone = "Silverpine Forest", x = 44.5, y = 43.0, lvl = 22, min = 15 },
  [92421] = { by = "Morbin Lightbane", zone = "Undercity", lvl = 22, min = 15 },
  [95216] = { by = "Theodore Griffs", zone = "Undercity", lvl = 22, min = 16 },
  [92422] = { by = "Deathguard Kristof", zone = "Tirisfal Glades", lvl = 22, min = 15 },
  [97288] = { item = "Abominable Head", inside = true, lvl = 21, min = 15 }, -- 15 since Blizzard's hotfix of 6 Nov 2026
  [95204] = { item = "Crest of Lordaeron", inside = true, lvl = 22, min = 16 },
  -- Excavation Site
  [98815] = { by = "James Halloran", zone = "Wetlands", x = 8.6, y = 55.8, lvl = 28, min = 24, xp = 1150 },
  [95646] = { by = "Rethiel the Greenwarden", zone = "Wetlands", x = 56.3, y = 40.5, lvl = 31, min = 24 },
  [95647] = { by = "Caitlin Grassman", zone = "Wetlands", x = 11.9, y = 58.8, lvl = 31, min = 24 },
  [95772] = { by = "Dorin Songblade", zone = "Redridge Mountains", x = 25.7, y = 46.5, lvl = 31, min = 24 },
  [95810] = { item = "Titan Relic", inside = true, lvl = 31, min = 24 },
  [95697] = { by = "Borstan", zone = "Orgrimmar", lvl = 31, min = 24 },
  [95682] = { by = "Deathstalker Agent", zone = "Wetlands", lvl = 31, min = 24,
    after = { { 95663, "Dragonmaw Rumors", lvl = 31 } } },
  [95664] = { item = "Titan Relic", inside = true, lvl = 31, min = 24 },
  -- City of Dalaran
  [92456] = { by = "Shylamiir", zone = "Stormwind City", x = 31.3, y = 62.9, lvl = 33, min = 24 },
  [92489] = { by = "High Sorcerer Andromath", zone = "Stormwind City", x = 48.8, y = 87.6, lvl = 33, min = 24 },
  [92458] = { by = "Image of Archmage Modera", zone = "Silverpine Forest", x = 68.7, y = 45.2, lvl = 33, min = 24,
    after = { { 92432, "An Alarming Request", lvl = 33, by = "Emissary Jacques", zone = "Hillsbrad Foothills" } } },
  [92457] = { by = "Image of Archmage Modera", zone = "Silverpine Forest", x = 68.7, y = 45.2, lvl = 33, min = 24,
    xp = 9400 },
  [96984] = { by = "Image of Archmage Modera", zone = "Silverpine Forest", lvl = 33, min = 24, after = {
    { 92434, "Blood in the Streets", lvl = 34, by = "Magus Wordeen Voidglare", zone = "Hillsbrad Foothills" }
  } },
  [96987] = { by = "Rexxie Copperclutch", zone = "Alterac Mountains", lvl = 33, min = 24 },
  [96988] = { by = "Doctor Martin Felben", zone = "Undercity", lvl = 33, min = 24 },
  [96986] = { by = "Melisara", zone = "Hillsbrad Foothills", lvl = 33, min = 24 },
  -- The Drowned City (where they start: not known yet)
  [95776] = { lvl = 38, min = 30 },
  [96774] = { lvl = 40, min = 30 },
  [95775] = { lvl = 40, min = 30 },
}

-- Both lists are WoW Forever's: ns.KeepThisGame (Data/Dungeons.lua) keeps them in Forever only.
ns.ALL_ATTUNEMENTS, ns.ALL_DUNGEON_QUESTS = ns.ATTUNEMENTS, ns.DUNGEON_QUESTS
