-- Icons. WoW's fonts cannot draw the mockup's symbols (✦ ⚔ ⚑ ...), so every icon is a texture.
-- These are the game's own icons; with our painted set ready (below) most names point at one of its cells instead.
local _, ns = ...
local I = "Interface\\Icons\\"

ns.ICONS = {
  -- Sidebar
  overview = I .. "INV_Misc_Book_09",
  chapter = I .. "INV_Misc_Note_01",
  quests = I .. "INV_Misc_Map_01",
  chronicle = I .. "INV_Misc_Book_09",
  history = I .. "INV_Misc_PocketWatch_01",
  raids = I .. "INV_Misc_Head_Dragon_01",
  heroes = I .. "INV_Misc_GroupNeedMore",
  gatherings = I .. "Spell_Fire_Fire",
  journal = I .. "INV_Misc_Book_09", -- the Dungeon Journal button
  lore = I .. "INV_Misc_Book_07", -- Lore Forever: a dungeon's story
  listen = I .. "INV_Misc_Horn_01", -- Spoken: a quest read aloud
  manage = I .. "INV_Misc_Gear_01",
  tourney = I .. "Ability_DualWield",
  admin = I .. "INV_Feather_05",
  rules = I .. "INV_Misc_Book_11",
  rulesadmin = I .. "INV_Misc_Book_11",
  -- Header buttons
  characters = I .. "INV_Misc_GroupLooking",
  inbox = I .. "INV_Letter_15",
  settings = I .. "Trade_Engineering",
  -- Toasts (one per event; "default" for other toasts)
  toast_chapter = I .. "INV_Misc_Book_09",
  toast_floor = I .. "Ability_Warrior_RallyingCry",
  toast_clear = I .. "Ability_DualWield",
  toast_heroFloor = I .. "Spell_ChargePositive",
  toast_heroCap = I .. "Ability_Warrior_DefensiveStance",
  toast_overCap = I .. "Spell_Shadow_DeathScream",
  toast_default = I .. "INV_Misc_Book_09",
  toast_gathering = I .. "INV_Misc_GroupNeedMore",
  toast_attune = I .. "INV_Misc_Key_03",
  toast_ahead = I .. "INV_Misc_GroupNeedMore",
  toast_session = I .. "INV_Misc_GroupNeedMore",
  -- Status banner and "What's next" (the mockup's 🔒 ⏳ ⚔ ⚑ ✓ ✋)
  bn_locked = I .. "INV_Misc_Key_03",
  bn_waiting = I .. "INV_Misc_PocketWatch_01",
  bn_open = I .. "Ability_DualWield",
  bn_level = I .. "Ability_Warrior_RallyingCry",
  bn_done = I .. "INV_Misc_Book_09",
  bn_cap = I .. "Ability_Warrior_DefensiveStance",
  bn_quest = I .. "INV_Sword_04",
  bn_chain = I .. "INV_Scroll_03",
  -- The You card (SPEC §6)
  bn_rested = I .. "Spell_Nature_Sleep",
  bn_group = I .. "INV_Misc_GroupNeedMore",
  bn_away = I .. "Spell_Nature_TimeStop",
  -- History (the mockup's ⚔ ✓ ↺ ✦ !) and the Dungeon Journal's bosses (☠)
  hist_run = I .. "Ability_DualWield",
  hist_mark = "Interface\\RaidFrame\\ReadyCheck-Ready",
  hist_undo = "Interface\\Buttons\\UI-RefreshButton",
  hist_chapter = I .. "INV_Misc_Book_09",
  hist_cap = I .. "Spell_Shadow_DeathScream",
  hist_session = I .. "INV_Misc_GroupNeedMore",
  boss = "Interface\\TargetingFrame\\UI-TargetingFrame-Skull",
}

-- Our own painted icon set (M20, art/incoming/icon-sheet: a 4 x 4 sheet in the medallion style, converted to
-- Media\IconSet). Each cell replaces the game icons below that name it. Turned on only together with the file
-- (ICON_SET_READY): the game says yes to a missing addon file, so it cannot be found out at run time.
ns.ICON_SET_READY = true
ns.ICON_SET = {
  -- The Chronicle is the journey's book; the hourglass is the fellowship's History (29 Oct 2026).
  overview = 1, chapter = 2, quests = 3, history = 4, chronicle = 14, raids = 5, heroes = 6, manage = 7, tourney = 8, admin = 9,
  rules = 10, rulesadmin = 10, characters = 11, inbox = 12, settings = 13,
  toast_chapter = 14, toast_default = 14, bn_done = 14, hist_chapter = 14, toast_floor = 14,
  toast_clear = 15, bn_open = 15, hist_run = 15,
  toast_gathering = 16, bn_rested = 16, gatherings = 16, journal = 1,
  -- Shared cells: the hourglass waits, the helmets are Heroes, the scale is the cap rule, the keys lock and attune.
  bn_waiting = 4, bn_level = 4, bn_chain = 2, bn_quest = 3,
  toast_heroFloor = 6, toast_heroCap = 6, bn_group = 6, toast_ahead = 6, toast_session = 6, hist_session = 6,
  bn_locked = 7, toast_attune = 7,
  toast_overCap = 10, bn_cap = 10, hist_cap = 10,
  bn_away = 11,
}

-- With the set ready, those names point at a cell of it ("IconSet#3"; several names share game icons, so the
-- name decides, not the picture).
if ns.ICON_SET_READY then
  for key, cell in pairs(ns.ICON_SET) do ns.ICONS[key] = ns.MEDIA .. "IconSet#" .. cell end
end

-- Of each 128-pixel cell only the blue disc inside the medallion's ring is shown (pixels 29 to 94): the book draws
-- its own round frames, and at 18 pixels the whole medallion would leave the symbol tiny.
ns.ICON_DISC = { 29 / 128, 94 / 128 }

-- The texture and coordinates of an icon: a cell of our set, or a game icon with its border trimmed.
function ns.IconArt(path)
  local cell = type(path) == "string" and tonumber(path:match("IconSet#(%d+)$"))
  if cell then
    local col, row = (cell - 1) % 4, math.floor((cell - 1) / 4)
    local a, z = ns.ICON_DISC[1], ns.ICON_DISC[2]
    -- The Horde theme: the same set with crimson discs instead of blue (Media\IconSetHorde, made by
    -- tools/convert-art.ps1; the blue looked out of place in red; 27 Oct 2026).
    local file = (ns.Theme and ns.Theme:Key() == "horde") and "IconSetHorde" or "IconSet"
    return ns.MEDIA .. file, (col + a) / 4, (col + z) / 4, (row + a) / 4, (row + z) / 4
  end
  return path, 0.08, 0.92, 0.08, 0.92
end

-- The Adventure Guide's sprite sheets (Forever has the files, though not the guide). Coordinates from Blizzard's
-- Blizzard_EncounterJournal.xml. { left, right, top, bottom, file = other sheet }.
ns.EJ_FILE = "Interface\\EncounterJournal\\UI-EncounterJournalTextures"
local EJ_TILE = "Interface\\EncounterJournal\\UI-EncounterJournalTextures_Tile"
ns.EJ_SPRITES = {
  leftHeader = { 0, 0.755859375, 0.9599609375, 1 },
  rightHeader = { 0.755859375, 0, 0.9599609375, 1 },
  paperLeft = { 0.84960938, 0.97460938, 0.49023438, 0.51855469 },
  paperRight = { 0.72656250, 0.85156250, 0.52441406, 0.55273438 },
  paperMid = { 0, 1, 0.34375000, 0.40039063, file = EJ_TILE },
  dungeonUp = { 0.00195313, 0.34179688, 0.42871094, 0.52246094 },
  dungeonHighlight = { 0.34570313, 0.68554688, 0.33300781, 0.42675781 },
}
-- The Adventure Guide's book (both pages), and the part of the file that is the book.
ns.EJ_BOOK = "Interface\\EncounterJournal\\UI-EJ-JournalBG"
ns.EJ_BOOK_BOX = { 0, 0.766601562, 0, 0.830078125 }

-- Small state marks in lists (the mockup's ✓ ◆ 🔒).
ns.MARKS = {
  cleared = "Interface\\RaidFrame\\ReadyCheck-Ready",
  done = "Interface\\RaidFrame\\ReadyCheck-Ready",
  open = "Interface\\COMMON\\Indicator-Yellow",
  current = "Interface\\COMMON\\Indicator-Yellow",
  locked = "Interface\\PetBattles\\PetBattle-LockIcon",
  waiting = "Interface\\RaidFrame\\ReadyCheck-Waiting",
}
---------------------------------------------------------------------------
-- Fellowship emblems: game icons that read like heraldry (crowns, banners, weapons, beasts, sun, moon, stars).
-- A fellowship stores the icon name. Which icons the game has is found out once at login, so a missing one
-- never shows as a blank. (Guild-tabard emblem files cannot be used: addons cannot load them.)
---------------------------------------------------------------------------
local E = { DEFAULT = "Her_Lion" }
ns.Emblems = E

E.ICONS = {
  "INV_Crown_01", "INV_Crown_02", "INV_BannerPVP_01", "INV_BannerPVP_02", "INV_BannerPVP_03", "INV_Shield_06",
  "INV_Shield_05", "INV_Sword_04", "INV_Sword_27", "INV_Sword_39", "INV_Axe_09", "INV_Hammer_04", "INV_Staff_13",
  "INV_Weapon_Bow_07", "Ability_DualWield", "Ability_Warrior_BattleShout", "Ability_Hunter_Pet_Wolf",
  "Ability_Hunter_Pet_Bear", "Ability_Hunter_Pet_Owl", "Ability_Hunter_Pet_Raptor", "Ability_Hunter_Pet_Cat",
  "Ability_Hunter_Pet_Spider", "Ability_Mount_WhiteTiger", "Ability_Druid_CatForm", "Ability_Racial_BearForm",
  "INV_Misc_Head_Dragon_01", "INV_Misc_Head_Dragon_Black", "Spell_Holy_HolyBolt", "Spell_Holy_SealOfMight",
  "Spell_Holy_SealOfWisdom", "Spell_Holy_Restoration", "Spell_Holy_PowerWordShield", "Spell_Nature_StarFall",
  "Spell_Nature_Lightning", "Spell_Nature_Tranquility", "Spell_Nature_ProtectionformNature", "Spell_Nature_Earthquake",
  "Spell_Fire_Fire", "Spell_Fire_FlameBolt", "Spell_Frost_FrostNova", "Spell_Frost_IceStorm", "Spell_Arcane_StarFire",
  "Spell_Arcane_Blast", "Spell_Shadow_ShadowBolt", "INV_Misc_Bone_HumanSkull_01", "INV_Misc_Book_09", "INV_Misc_Rune_01",
  "INV_Jewelry_Ring_03", "INV_Misc_Key_03", "INV_Misc_Map_01", "INV_Misc_Horn_01", "INV_Misc_Ribbon_01",
}

-- Picture crests (our art, Media\Crest<file>): a whole picture with a transparent background, such as a guild's
-- logo. Chosen like an emblem (the key starts with "Pic_"); shown as it is, without the coloured shield.
-- Add one only together with its file: the game does not say when an addon's file is missing (the self-test of
-- 26 Oct 2026 found a missing one "loading"), so a listed picture without its file would show as a blank crest.
E.PICTURES = {
  { key = "Pic_Alliansens", file = "CrestAlliansens" }, -- the Alliansens Hjältar Forever logo (27 Oct 2026)
}

-- Heraldic emblems (our art, Media\Emblems: a 4 x 4 atlas of pale gold silhouettes), shown in the crest medallion.
-- They come first in the picker and a new fellowship starts with the lion.
E.HERALDRY = { "Her_Lion", "Her_Eagle", "Her_Wolf", "Her_Dragon", "Her_Stag", "Her_Boar", "Her_Swords", "Her_Axes",
  "Her_Hammers", "Her_Star", "Her_Crown", "Her_Tower", "Her_Oak", "Her_Sun", "Her_Moon", "Her_Flame" }

function E:Picture(key)
  for _, p in ipairs(self.PICTURES) do if p.key == key then return p end end
end

-- The atlas cell (1-16) of a heraldic emblem, or nil.
function E:Heraldry(key)
  for i, k in ipairs(self.HERALDRY) do if k == key then return i end end
end

-- Texture coordinates of an emblem: its atlas cell, the whole picture, or a game icon without its border.
function E:Coords(key)
  local i = self:Heraldry(key)
  if i then
    local col, row = (i - 1) % 4, math.floor((i - 1) / 4)
    return col / 4, (col + 1) / 4, row / 4, (row + 1) / 4
  end
  if self:Picture(key) then return 0, 1, 0, 1 end
  return 0.08, 0.92, 0.08, 0.92
end

-- Our own art (heraldry, pictures): drawn without the icon's frame line.
function E:Own(key) return self:Heraldry(key) ~= nil or self:Picture(key) ~= nil end

function E:Texture(key)
  local p = self:Picture(key)
  if p then return ns.MEDIA .. p.file end
  if self:Heraldry(key) then return ns.MEDIA .. "Emblems" end
  return "Interface\\Icons\\" .. key
end

-- SetTexture returns false for a file the game does not have (nil from older clients: treated as found).
function E:Scan()
  if self.list then return self.list end
  local probe = UIParent:CreateTexture(nil, "BACKGROUND")
  probe:Hide()
  self.list, self.set = {}, {}
  -- Picture crests first, then the heraldry (only when their files are in Media), then the game's icons.
  local keys = {}
  for _, p in ipairs(self.PICTURES) do keys[#keys + 1] = p.key end
  for _, key in ipairs(self.HERALDRY) do keys[#keys + 1] = key end
  for _, key in ipairs(self.ICONS) do keys[#keys + 1] = key end
  for _, key in ipairs(keys) do
    -- (Our own art needs a clear yes: it is only there when its file is.)
    local found = probe:SetTexture(self:Texture(key))
    if (self:Own(key) and found == true) or (not self:Own(key) and found ~= false) then
      self.list[#self.list + 1] = key
      self.set[key] = true
    end
  end
  probe:SetTexture(nil)
  return self.list
end

function E:Has(key) return self.set ~= nil and self.set[key] == true end
-- The emblem a new fellowship starts with: your side's heraldry, the lion for the Alliance and the crossed axes
-- for the Horde. (It was the first emblem the game had, and before the scan a game icon; seen in game.)
function E:First()
  return UnitFactionGroup("player") == "Horde" and "Her_Axes" or "Her_Lion"
end
function E:Valid(key) return type(key) == "string" and #key <= 64 and key:match("^[%w_]+$") ~= nil end

-- The emblem picker's sections (M20): { { label, keys } }: picture crests and the heraldic emblems. The game's icons
-- only when our heraldry art is missing (they looked out of place next to it; removed 27 Oct 2026). A fellowship
-- that chose an icon earlier keeps it.
function E:Sections(list)
  local L = ns.L
  local sections = { { L.EMBLEMS_CRESTS, {} }, { L.EMBLEMS_HERALDRY, {} }, { L.EMBLEMS_ICONS, {} } }
  for _, n in ipairs(list or self:Scan()) do
    local s = self:Picture(n) and 1 or (self:Heraldry(n) and 2 or 3)
    table.insert(sections[s][2], n)
  end
  if #sections[2][2] > 0 then sections[3][2] = {} end
  return sections
end

ns:On("LOGIN", function() ns.Combat:AfterCombat(function() E:Scan(); ns.Window:Refresh() end) end)

---------------------------------------------------------------------------
-- Parchment for the pages: the game's quest and spellbook pages. The first one the game has is used;
-- otherwise the pages keep their plain theme colours.
---------------------------------------------------------------------------
ns.PAPER = {
  { atlas = "QuestBG-Parchment" },
  { file = "Interface\\QuestFrame\\QuestBG", coords = { 0, 0.586, 0, 0.65 } },
  { file = "Interface\\Spellbook\\Spellbook-Page-1", coords = { 0, 1, 0, 0.83 } },
}

-- Puts the first parchment the game has on tex. Returns true when one was found.
function ns.SetPaper(tex)
  for _, p in ipairs(ns.PAPER) do
    if p.atlas then
      if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(p.atlas) then
        tex:SetAtlas(p.atlas)
        return true
      end
    elseif tex:SetTexture(p.file) then
      local c = p.coords
      tex:SetTexCoord(c[1], c[2], c[3], c[4])
      return true
    end
  end
  return false
end

-- "|T...|t": an icon inside a line of text.
function ns.InlineTexture(path, size)
  return ("|T%s:%d:%d:0:0:64:64:5:59:5:59|t"):format(path, size or 12, size or 12)
end

ns.CIRCLE_MASK ="Interface\\CharacterFrame\\TempPortraitAlphaMask"
ns.WHITE = "Interface\\Buttons\\WHITE8X8"
