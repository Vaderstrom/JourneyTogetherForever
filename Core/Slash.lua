-- /jtf commands (SPEC §4.14).
local _, ns = ...
local L = ns.L
local W = ns.Window

ns.COMMANDS = {
  { "/jtf", L.CMD_TOGGLE }, { "/jtf chapter", L.CMD_CHAPTER }, { "/jtf adventurers", L.CMD_HEROES },
  { "/jtf quests", L.CMD_QUESTS }, { "/jtf photo", L.CMD_PHOTO }, { "/jtf settings", L.CMD_SETTINGS },
}
-- Command word -> page. Members are called Adventurers since 27 Oct 2026; "heroes" and "companions" still work.
local PAGES = { chapter = "chapter", heroes = "heroes", companions = "heroes", adventurers = "heroes", quests = "quests" }

-- The copy that stays off (Core/Init.lua) leaves /jtf to the one that runs.
if ns.off then return end
SLASH_JOURNEYTOGETHERFOREVER1 = "/jtf"
SlashCmdList.JOURNEYTOGETHERFOREVER = function(msg)
  local cmd, rest = (msg or ""):match("^%s*(%S*)%s*(.-)%s*$")
  cmd = cmd:lower()
  if cmd == "" then W:Toggle()
  elseif PAGES[cmd] then W:Open(PAGES[cmd]) -- shows the start page when that page is not yours
  elseif cmd == "settings" then W:OpenSettings()
  elseif cmd == "photo" then ns.Photo:Open()
  elseif cmd == "debug" then ns.Dev:Command(rest)
  elseif cmd == "check" then ns.Check:Run(rest)
  elseif cmd == "tests" then ns.Manual:Command(rest)
  elseif cmd == "selftest" then ns.SelfTest:Run(rest:lower())
  elseif cmd == "tour" then ns.Tour:Run(rest:lower())
  elseif cmd == "brand" then ns.Tour:Brand() -- the README's pictures (Dev/Tour.lua); not in the help
  elseif cmd == "lab" then ns.Lab:Toggle() -- the developer's test lab (Dev/Lab.lua); not in the help
  else
    for _, c in ipairs(ns.COMMANDS) do ns:Print(c[1] .. "  -  " .. c[2], true) end
  end
end
