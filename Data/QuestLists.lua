-- Our own lists (SPEC §6): attunements and keys, by quest ID. Written for this addon (no data copied from other
-- addons); every ID is checked against WoW Forever's quest table by tools/update-game-data.ps1. Names are the game's
-- English quest names, shown until the client knows the quest.
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

-- The dungeons' quests and where they start: Data/DungeonQuests.lua (the one source for dungeon quests, the owner,
-- 9 Nov 2026). Both lists are WoW Forever's:
-- ns.KeepThisGame (Data/Dungeons.lua) keeps them in Forever only.
ns.ALL_ATTUNEMENTS, ns.ALL_DUNGEON_QUESTS = ns.ATTUNEMENTS, ns.DUNGEON_QUESTS
