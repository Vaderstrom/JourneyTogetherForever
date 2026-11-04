-- Sounds (M20): the game's own book and button sounds, so the book feels like the spellbook. Settings → Sounds turns
-- them off. ns.Sound("open" | "close" | "page" | "choose" | "ring" | "bell").
local _, ns = ...

-- SOUNDKIT names, with their numbers for clients without the table.
local KIT = {
  open = { "IG_SPELLBOOK_OPEN", 829 },
  close = { "IG_SPELLBOOK_CLOSE", 830 },
  page = { "IG_ABILITY_PAGE_TURN", 836 },
  choose = { "IG_MAINMENU_OPTION_CHECKBOX_ON", 856 },
  ring = { "UI_EPICLOOT_TOAST", 31578 }, -- the Ring passes on (a soft shimmer, the game's epic loot toast)
}

-- The bell for the Fallen (SPEC §9): the toll of the fellowship's side, the game's own BellTollAlliance and
-- BellTollHorde (file numbers: the game has no SOUNDKIT name for them).
local BELL = { Alliance = 566564, Horde = 565853 }
ns.BELL = BELL

-- Plays a sound; true when the game says it plays. ns.lastSound: the last one asked for (the self-test reads it).
function ns.Sound(name)
  if not ns.Settings.data or ns.Settings:Get("sounds") == false then return false end
  ns.lastSound = name
  if name == "bell" then
    if not PlaySoundFile then return false end
    local f = ns.Fellowship and ns.Fellowship:Current()
    local side = (f and f.faction) or (UnitFactionGroup and UnitFactionGroup("player"))
    return PlaySoundFile(BELL[side] or BELL.Alliance, "SFX") and true or false
  end
  local s = KIT[name]
  if not s or not PlaySound then return false end
  local id = SOUNDKIT and SOUNDKIT[s[1]] or s[2]
  PlaySound(id, "SFX")
  return true
end
