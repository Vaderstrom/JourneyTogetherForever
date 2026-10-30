-- Our own lists (SPEC §6): attunements and keys, and the quests of each dungeon, by quest ID. Written for this addon
-- (no data copied from other addons); every ID is checked against WoW Forever's quest table by
-- tools/check-quest-lists.ps1. Names are the game's English quest names, shown until the client knows the quest.
-- side: "A" Alliance, "H" Horde, nil both. A step lists one or more quest IDs; any of them done counts.
local _, ns = ...

-- Attunements and keys: { key, name, kind ("raid" / "key"), side, level (the level from which a Hero can start it;
-- below it the attunement is not shown to them), item (the key or amulet; having it also counts as done),
-- steps = { { ids, name } }, drop (true: the key drops, there is no quest), from (a dropped key: the dungeon it
-- drops in; its level is that dungeon's best level from, so it follows Data/Dungeons.lua) }
-- tools/update-game-data.ps1 checks every quest ID and item against the game, and each start level against the
-- first quest's own level.
ns.ATTUNEMENTS = {
  -- The Scarlet Key (Armory and Cathedral) drops in the Library (missing until 27 Oct 2026: the first key shown was
  -- Blackrock Depths at 48).
  { key = "smarm", name = "Scarlet Monastery (Armory and Cathedral)", kind = "key", item = 7146, drop = true,
    from = "smlib", steps = {} },
  { key = "mc", name = "Molten Core", kind = "raid", level = 55, steps = { { { 7848 }, "Attunement to the Core" } } },
  -- Not an attunement to enter, but Majordomo Executus can only be summoned with the Hydraxian Waterlords' help.
  { key = "hydraxis", name = "Hydraxian Waterlords (Majordomo)", kind = "raid", level = 55, steps = {
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
-- Dungeons that are new in WoW Forever have no list yet.
ns.DUNGEON_QUESTS = {
  rfc = { { 5723, "Testing an Enemy's Strength", "H" }, { 5725, "The Power to Destroy...", "H" },
    { 5728, "Hidden Enemies", "H" }, { 5761, "Slaying the Beast", "H" } },
  dm = { { 166, "The Defias Brotherhood", "A" }, { 2040, "Underground Assault", "A" }, { 214, "Red Silk Bandanas", "A" },
    { 168, "Collecting Memories", "A" }, { 167, "Oh Brother. . .", "A" }, { 373, "The Unsent Letter", "A" } },
  wc = { { 914, "Leaders of the Fang" }, { 1486, "Deviate Hides" }, { 959, "Trouble at the Docks" },
    { 1487, "Deviate Eradication" }, { 1491, "Smart Drinks" }, { 6981, "The Glowing Shard" } },
  sfk = { { 1013, "The Book of Ur", "H" }, { 1014, "Arugal Must Die", "H" }, { 1098, "Deathstalkers in Shadowfang", "H" } },
  bfd = { { 1198, "In Search of Thaelrid", "A" }, { 1199, "Twilight Falls", "A" }, { 1200, "Blackfathom Villainy", "A" },
    { 1275, "Researching the Corruption", "A" }, { 6563, "The Essence of Aku'Mai" },
    { 6565, "Allegiance to the Old Gods", "H" }, { 6921, "Amongst the Ruins", "H" }, { 6922, "Baron Aquanis", "H" } },
  stocks = { { 386, "What Comes Around...", "A" }, { 377, "Crime and Punishment", "A" }, { 387, "Quell The Uprising", "A" },
    { 388, "The Color of Blood", "A" }, { 378, "The Fury Runs Deep", "A" }, { 391, "The Stockade Riots", "A" } },
  rfk = { { 1221, "Blueleaf Tubers" }, { 1144, "Willix the Importer" }, { 1101, "The Crone of the Kraul", "A" },
    { 1142, "Mortality Wanes", "A" }, { 1109, "Going, Going, Guano!", "H" }, { 1102, "A Vengeful Fate", "H" } },
  gnomer = { { 2904, "A Fine Mess", "A" }, { 2922, "Save Techbot's Brain!", "A" }, { 2926, "Gnogaine", "A" },
    { 2927, "The Day After", "A" }, { 2929, "The Grand Betrayal", "A" }, { 2930, "Data Rescue", "A" },
    { 2928, "Gyrodrillmatic Excavationators", "H" }, { 2841, "Rig Wars" }, { 2945, "Grime-Encrusted Ring" } },
  smgy = { { 1048, "Into The Scarlet Monastery", "H" } },
  smlib = { { 1053, "In the Name of the Light", "A" }, { 1050, "Mythology of the Titans", "A" },
    { 1049, "Compendium of the Fallen", "H" }, { 1048, "Into The Scarlet Monastery", "H" } },
  smarm = { { 1053, "In the Name of the Light", "A" }, { 1048, "Into The Scarlet Monastery", "H" } },
  smcath = { { 1053, "In the Name of the Light", "A" }, { 1048, "Into The Scarlet Monastery", "H" } },
  rfd = { { 3636, "Bring the Light", "A" }, { 3341, "Bring the End", "H" }, { 3523, "Scourge of the Downs" },
    { 3525, "Extinguishing the Idol" } },
  ulda = { { 2278, "The Platinum Discs" }, { 2240, "The Hidden Chamber" }, { 2361, "Restoring the Necklace" },
    { 1139, "The Lost Tablets of Will", "A" }, { 2418, "Power Stones", "A" }, { 704, "Agmond's Fate", "A" },
    { 709, "Solution to Doom" }, { 2283, "Necklace Recovery" }, { 2398, "The Lost Dwarves", "A" } },
  zf = { { 2770, "Gahz'rilla" }, { 2846, "Tiara of the Deep" }, { 2936, "The Spider God", "H" },
    { 2768, "Divino-matic Rod" }, { 2865, "Scarab Shells" }, { 3042, "Troll Temper" },
    { 3527, "The Prophecy of Mosh'aru" }, { 2991, "Nekrum's Medallion" } },
  mara = { { 7044, "Legends of Maraudon" }, { 7046, "The Scepter of Celebras" }, { 7064, "Corruption of Earth and Seed" },
    { 7029, "Vyletongue Corruption", "H" }, { 7041, "Vyletongue Corruption", "A" }, { 7028, "Twisted Evils" },
    { 7067, "The Pariah's Instructions" } },
  st = { { 3373, "The Essence of Eranikus" }, { 3528, "The God Hakkar" }, { 3446, "Into the Depths" },
    { 3447, "Secret of the Circle" }, { 1475, "Into The Temple of Atal'Hakkar", "A" },
    { 1446, "Jammal'an the Prophet", "A" }, { 3380, "The Sunken Temple" } },
  brd = { { 4136, "Ribbly Screwspigot" }, { 4123, "The Heart of the Mountain" }, { 4134, "Lost Thunderbrew Recipe" },
    { 4081, "KILL ON SIGHT: Dark Iron Dwarves" }, { 4082, "KILL ON SIGHT: High Ranking Dark Iron Officials" },
    { 3981, "Commander Gor'shak", "H" }, { 4341, "Kharan Mighthammer", "A" }, { 3906, "Disharmony of Flame", "H" },
    { 3802, "Dark Iron Legacy" }, { 4083, "The Spectral Chalice" },
    { 4201, "The Love Potion" }, { 4126, "Hurley Blackbreath" }, { 4286, "The Good Stuff" },
    { 4362, "The Fate of the Kingdom", "A" }, { 3907, "Disharmony of Fire", "H" }, { 7201, "The Last Element" },
    { 4024, "A Taste of Flame" }, { 4061, "The Rise of the Machines" } },
  lbrs = { { 4701, "Put Her Down" }, { 4729, "Kibler's Exotic Pets" }, { 4742, "Seal of Ascension" },
    { 4788, "The Final Tablets" }, { 4862, "En-Ay-Es-Tee-Why" }, { 4866, "Mother's Milk" }, { 4867, "Urok Doomhowl" },
    { 5001, "Bijou's Belongings" }, { 4903, "Warlord's Command", "H" }, { 5089, "General Drakkisath's Command", "A" } },
  ubrs = { { 5102, "General Drakkisath's Demise", "A" }, { 4974, "For The Horde!", "H" }, { 5081, "Maxwell's Mission", "A" },
    { 4734, "Egg Freezing" }, { 7761, "Blackhand's Command" } },
  dme = { { 7488, "Lethtendris's Web", "A" }, { 7489, "Lethtendris's Web", "H" },
    { 7441, "Pusillin and the Elder Azj'Tordin" }, { 5526, "Shards of the Felvine" }, { 5527, "A Reliquary of Purity" } },
  strat = { { 5212, "The Flesh Does Not Lie", "A" }, { 5243, "Houses of the Holy" }, { 5213, "The Active Agent", "A" },
    { 5848, "Of Love and Family" }, { 5251, "The Archivist" }, { 5262, "The Truth Comes Crashing Down" },
    { 5125, "Aurius' Reckoning" }, { 6163, "Ramstein" } },
  scholo = { { 5382, "Doctor Theolen Krastinov, the Butcher" }, { 5384, "Kirtonos the Herald" },
    { 5466, "The Lich, Ras Frostwhisper" }, { 5529, "Plagued Hatchlings" },
    { 5515, "Krastinov's Bag of Horrors" }, { 5343, "Barov Family Fortune", "A" }, { 5341, "Barov Family Fortune", "H" },
    { 4771, "Dawn's Gambit" } },
}
