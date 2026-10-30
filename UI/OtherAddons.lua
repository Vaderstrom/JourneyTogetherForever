-- Shortcuts to other addons that tell more (asked for 29 Oct 2026): Lore Forever tells a dungeon's or a raid's story,
-- Spoken reads quests aloud. Neither is needed, and both are made for Forever (and Classic), not retail. Their
-- buttons always show, as the Dungeon Journal's does (UI/Window.lua): without the addon a click says, in a toast,
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

-- Opens Lore Forever on a dungeon's or a raid's story; without it, a toast says to install it. Returns true when it
-- was asked.
function OA:Lore(key)
  local d = key and ns.Dungeon(key)
  if not d then return false end
  local ask = self:LoreCommand()
  if not ask then
    ns:Toast(nil, L.LORE_FOREVER, L.LORE_MISSING)
    return false
  end
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
