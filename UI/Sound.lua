-- Sounds (M20): the game's own book and button sounds, so the book feels like the spellbook. Settings → Sounds turns
-- them off. ns.Sound("open" | "close" | "page" | "choose").
local _, ns = ...

-- SOUNDKIT names, with their numbers for clients without the table.
local KIT = {
  open = { "IG_SPELLBOOK_OPEN", 829 },
  close = { "IG_SPELLBOOK_CLOSE", 830 },
  page = { "IG_ABILITY_PAGE_TURN", 836 },
  choose = { "IG_MAINMENU_OPTION_CHECKBOX_ON", 856 },
}

function ns.Sound(name)
  local s = KIT[name]
  if not s or not PlaySound or not ns.Settings.data or ns.Settings:Get("sounds") == false then return false end
  local id = SOUNDKIT and SOUNDKIT[s[1]] or s[2]
  PlaySound(id, "SFX")
  return true
end
