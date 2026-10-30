-- Shortcuts to other addons that tell more (asked for 29 Oct 2026): Lore Forever tells a dungeon's or a raid's story,
-- Spoken reads quests aloud. Neither is needed, and both are made for Forever (and Classic), not retail: their
-- buttons show only while the addon runs. The DungeonJournal and Attune shortcuts work the same way
-- (UI/Window.lua, Fellowship/QuestLists.lua).
-- Lore Forever has no API for other addons: its chat command is asked about the place by name ("/lore The
-- Deadmines"), as a player would. Spoken's Quests part opens its Compendium at a quest, the same call as the Open
-- in Compendium button Spoken puts on the game's quest windows. That call is not part of Spoken's public API
-- (addons/Spoken/API.lua in rusty-key/spoken-wow), so every use is guarded: if a Spoken update changes it, the
-- Listen buttons only disappear.
local _, ns = ...
local OA = {}
ns.OtherAddons = OA

---------------------------------------------------------------------------
-- Lore Forever
---------------------------------------------------------------------------
function OA:LoreCommand() return ns.SlashCommand("/lore") end

function OA:HasLore() return self:LoreCommand() ~= nil end

-- The name Lore Forever knows a place by: ours shortens Scarlet Monastery's wings ("SM: Library").
function OA.LoreName(name) return (name:gsub("^SM: ", "Scarlet Monastery ")) end

-- Opens Lore Forever on a dungeon's or a raid's story. Returns true when it was asked.
function OA:Lore(key)
  local d = key and ns.Dungeon(key)
  local ask = self:LoreCommand()
  if not (d and ask) then return false end
  ask(self.LoreName(d[2]))
  return true
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

-- Opens Spoken's Compendium at the quest, where it is read and heard. Returns true when it opened.
function OA:Listen(id)
  local tab = questsTab()
  if not (tab and id) then return false end
  return (pcall(tab.Open, tab, id))
end
