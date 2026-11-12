-- Shortcuts to other addons that tell more (asked for 29 Oct 2026): Lore Forever and Spoken tell a dungeon's or a
-- raid's story (Settings: Stories from, 6 Nov 2026), Spoken reads quests aloud. Neither is needed, and both are made for Forever (and Classic), not retail. Their
-- buttons always show: without the addon a click says, in a toast,
-- what installing it would give (30 Oct 2026; they showed only while the addon ran, so nobody learnt of them).
-- Lore Forever has no API for other addons: its chat command is asked about the place by name ("/lore The
-- Deadmines"), as a player would. Spoken's Quests part opens its Compendium at a quest, the same call as the Open
-- in Compendium button Spoken puts on the game's quest windows. That call is not part of Spoken's public API
-- (addons/Spoken/API.lua in rusty-key/spoken-wow), so every use is guarded: if a Spoken update changes it, the
-- Listen buttons only disappear.
local _, ns = ...
local L = ns.L
local OA = {}
ns.OtherAddons = OA

---------------------------------------------------------------------------
-- Lore Forever
---------------------------------------------------------------------------
function OA:LoreCommand() return ns.SlashCommand("/lore") end

function OA:HasLore() return self:LoreCommand() ~= nil end

-- The name Lore Forever knows a place by: ours shortens Scarlet Monastery's wings ("SM: Library").
function OA.LoreName(name) return (name:gsub("^SM: ", "Scarlet Monastery ")) end

-- Lore Forever's pages with a recording (its zone: entries), by our key. The story button plays it too (the owner,
-- 10 Nov 2026: "Play it for you"), the way Lore Forever's own Listen link in chat does: an addon:LoreForever: link
-- passed to the game's SetItemRef callbacks. Nothing plays for a place not listed; again while it plays stops it.
OA.LORE_VOICED = { hot = "hallofthanes", rol = "ruinsoflordaeron", dm = "deadmines", wc = "wailing",
  sfk = "shadowfang", bfd = "blackfathom", stocks = "stockade", rfk = "razorfenkraul", gnomer = "gnomeregan",
  rfc = "ragefire", smlib = "scarlet", smgy = "scarlet", smarm = "scarlet", smcath = "scarlet" }

function OA.LoreListen(key)
  local page = OA.LORE_VOICED[key]
  if not (page and type(EventRegistry) == "table" and EventRegistry.TriggerEvent) then return false end
  return (pcall(EventRegistry.TriggerEvent, EventRegistry, "SetItemRef", "addon:LoreForever:listen::zone:" .. page))
end

---------------------------------------------------------------------------
-- Spoken's stories of places (the owner, 6 Nov 2026: Spoken instead of Lore Forever, the two talk over each other)
---------------------------------------------------------------------------
-- Spoken's Places part tells a dungeon's story: SpokenDungeons.dungeons[instance ID].story = { map, area }, opened
-- with SpokenPlaces:ShowLoreFor, which Spoken lists for other addons (docs/places/ADDON.md in Spoken). Its caller
-- checks that the part is on and the place not locked (not found yet). Our instance IDs are Data/Dungeons.lua's.
-- Returns SpokenPlaces, the map and the area, or nil.
local function spokenStory(key)
  local places, list = SpokenPlaces, SpokenDungeons
  if type(places) ~= "table" or type(places.ShowLoreFor) ~= "function" then return nil end
  if type(Spoken) == "table" and type(Spoken.IsPartOn) == "function" then
    local ok, on = pcall(Spoken.IsPartOn, Spoken, "places")
    if ok and on == false then return nil end
  end
  local where = ns.DUNGEON_MAPS[ns.BaseKey(key)]
  local d = where and type(list) == "table" and type(list.dungeons) == "table" and list.dungeons[where[1]]
  local story = type(d) == "table" and type(d.story) == "table" and d.story
  if not (story and story[1] and story[2]) then return nil end
  return places, story[1], story[2]
end

function OA:HasSpokenStory(key) return spokenStory(key) ~= nil end

-- Opens Spoken's story of the place: "open", "locked" (Spoken tells it once this character has found the place) or
-- nil (Spoken has none).
function OA:SpokenLore(key)
  local places, map, area = spokenStory(key)
  if not places then return nil end
  if type(places.IsLocked) == "function" then
    local ok, locked = pcall(places.IsLocked, places, map, area)
    if ok and locked then return "locked" end
  end
  return pcall(places.ShowLoreFor, places, map, area) and "open" or nil
end

-- Which addon the story button opens for key now: "spoken", "lore" or nil (neither has it). The setting says which
-- comes first; the other stands in when the first has no story for the place.
function OA:StoryFrom(key)
  local spoken, lore = self:HasSpokenStory(key), self:HasLore()
  if ns.Settings:Get("storyFrom") == "lore" then
    return lore and "lore" or (spoken and "spoken") or nil
  end
  return spoken and "spoken" or (lore and "lore") or nil
end

-- The story button's tooltip: who tells it.
function OA:StoryTip(key)
  local from = self:StoryFrom(key)
  return from == "spoken" and L.LORE_TIP_SPOKEN or (from == "lore" and L.LORE_TIP) or L.LORE_TIP_NONE
end

-- Opens a dungeon's or a raid's story, in Spoken or Lore Forever (Settings: Stories from); with neither, a toast
-- says to install one. Returns true when one was asked.
function OA:Lore(key)
  local d = key and ns.Dungeon(key)
  if not d then return false end
  local function forever()
    local ask = self:LoreCommand()
    if not ask then return false end
    ask(self.LoreName(d[2]))
    OA.LoreListen(key)
    return true
  end
  local first = self:StoryFrom(key)
  if first == "lore" then return forever() end
  if first == "spoken" then
    local got = self:SpokenLore(key)
    if got == "open" then return true end
    -- Not found yet: Spoken keeps it to itself (no spoilers); Lore Forever tells it when it is there.
    if got == "locked" then
      if forever() then return true end
      ns:Toast(nil, L.SPOKEN, L.SPOKEN_STORY_LOCKED)
      return false
    end
    if forever() then return true end
  end
  -- (With Spoken running, installing it is not the answer: it has no story here, or its Places part is off.)
  ns:Toast(nil, L.STORIES, self:HasSpoken() and L.SPOKEN_NO_STORY or L.LORE_MISSING)
  return false
end

---------------------------------------------------------------------------
-- Spoken
---------------------------------------------------------------------------
-- The Compendium's Quests tab of Spoken (API version 1) and its Quests part, or nil.
local function questsTab()
  if type(Spoken) ~= "table" or type(Spoken.IsCompatible) ~= "function" then return nil end
  local ok, compatible = pcall(Spoken.IsCompatible, Spoken, 1)
  if not (ok and compatible) then return nil end
  local tab = type(VoiceOver) == "table" and VoiceOver.QuestsTab
  if type(tab) ~= "table" or type(tab.Open) ~= "function" or type(tab.Has) ~= "function" then return nil end
  return tab
end

function OA:HasSpoken() return questsTab() ~= nil end

-- Of a quest ID or a list of them (a step done by any of several quests), the first whose words Spoken would show:
-- one this character may take, and started (or all quests unlocked in Spoken's settings), as Spoken's own button
-- does, so nothing is spoiled. nil when there is none, or no Spoken.
function OA:SpokenQuest(ids)
  local tab = questsTab()
  if not tab or not ids then return nil end
  for _, id in ipairs(type(ids) == "table" and ids or { ids }) do
    local ok, has = pcall(tab.Has, tab, id)
    if ok and has then return id end
  end
  return nil
end

-- Opens Spoken's Compendium at the quest (a quest ID or a step's list of them), where it is read and heard. Without
-- Spoken a toast says to install it; when Spoken keeps the quest hidden, the toast says when it shows. Returns true
-- when it opened.
function OA:Listen(ids)
  if not ids then return false end
  local tab = questsTab()
  if not tab then
    ns:Toast(nil, L.SPOKEN, L.LISTEN_MISSING)
    return false
  end
  local id = self:SpokenQuest(ids)
  if not id then
    ns:Toast(nil, L.SPOKEN, L.LISTEN_HIDDEN)
    return false
  end
  return (pcall(tab.Open, tab, id))
end
