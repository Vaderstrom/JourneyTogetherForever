-- Journey Together Forever: start-up, saved data, events and chat output.
local ADDON, ns = ...
local L = ns.L
ns.ADDON = ADDON
ns.MEDIA = "Interface\\AddOns\\" .. ADDON .. "\\Media\\"
-- When the game read these files (login or /reload). The check report compares it with the files on disk, so a check
-- run without a /reload after a change says it saw the old code (it happened twice on 30 Oct 2026).
ns.loadedAt = time()

-- The developer's copy (29 Oct 2026): the folder JourneyTogetherForever-Dev with its own TOC sits next to the
-- released addon, so either can be turned off in the AddOns list. It keeps its own saved data (the two files would
-- otherwise share one table and write over each other). With both turned on, the second one to load stays off: it
-- never sends, draws or answers /jtf, and says so once.
local DEV = ADDON:find("%-Dev$") ~= nil
local DB_NAME = DEV and "JourneyTogetherForeverDevDB" or "JourneyTogetherForeverDB"
local CHAR_NAME = DEV and "JourneyTogetherForeverDevCharDB" or "JourneyTogetherForeverCharDB"
local OTHER = DEV and "JourneyTogetherForever" or "JourneyTogetherForever-Dev"
local isLoaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
if isLoaded and isLoaded(OTHER) then ns.off = OTHER end

-- Game events. Modules call ns:RegisterEvent(event, fn); fn gets (event, ...).
local frame = CreateFrame("Frame")
local handlers = {}
function ns:RegisterEvent(event, fn)
  if not handlers[event] then handlers[event] = {}; frame:RegisterEvent(event) end
  table.insert(handlers[event], fn)
end
-- Errors in our handlers are written to the error log (JourneyTogetherForeverDB.errors, read after a /reload), then
-- shown as usual.
ns.ERRORS_MAX = 40
function ns:LogError(kind, msg, stack)
  if not ns.db then return end
  ns.db.errors = type(ns.db.errors) == "table" and ns.db.errors or {}
  table.insert(ns.db.errors, 1, { t = time(), kind = kind, msg = tostring(msg), stack = stack, ver = ns.VERSION })
  while #ns.db.errors > ns.ERRORS_MAX do table.remove(ns.db.errors) end
end

local function trace(err)
  return { msg = err, stack = debugstack and debugstack(2, 12, 0) or (debug and debug.traceback and debug.traceback()) }
end

-- One handler, its errors logged. (The game's xpcall passes arguments on: no table or function is made per event.
-- The ponytail audit of 6 Nov 2026: every addon message of every addon in a raid made both, twice.)
local XARGS = select(2, xpcall(function(a) return a end, function() end, true)) == true
local function run(fn, event, ...)
  local ok, e
  if XARGS then ok, e = xpcall(fn, trace, event, ...)
  else
    local n, args = select("#", ...), { ... }
    ok, e = xpcall(function() fn(event, unpack(args, 1, n)) end, trace)
  end
  if not ok then
    ns:LogError(event, e.msg, e.stack)
    if geterrorhandler then geterrorhandler()(e.msg) else error(e.msg, 0) end
  end
end

frame:SetScript("OnEvent", function(_, event, ...)
  if ns.off then
    if event == "PLAYER_LOGIN" then DEFAULT_CHAT_FRAME:AddMessage("|cffe2b857" .. L.ADDON_NAME .. "|r: " .. L.TWO_COPIES:format(ADDON, ns.off)) end
    return
  end
  for _, fn in ipairs(handlers[event]) do run(fn, event, ...) end
end)

-- An event of one unit only ("player"): the game hands over no other. UNIT_AURA and UNIT_SPELLCAST_SUCCEEDED come for
-- every unit in a raid and on every nameplate, many times a second, and the addon only reads its own (ponytail audit).
-- (ns.unitEvents: their frames by event, for the self-test.)
ns.unitEvents = {}
function ns:RegisterUnitEvent(event, unit, fn)
  local f = CreateFrame("Frame")
  f:RegisterUnitEvent(event, unit)
  f:SetScript("OnEvent", function(_, ev, ...) if not ns.off then run(fn, ev, ...) end end)
  ns.unitEvents[event] = f
end

-- A protected action blocked or forbidden for this addon (for example a group invite without a click).
local function blocked(event, addon, fn)
  if addon == ADDON then ns:LogError(event, tostring(fn), debugstack and debugstack(2, 8, 0) or nil) end
end
ns:RegisterEvent("ADDON_ACTION_BLOCKED", blocked)
ns:RegisterEvent("ADDON_ACTION_FORBIDDEN", blocked)

-- A game warning about this addon, such as "exceeded its execution time limit" (seen in the check of 29 Oct 2026,
-- where it was never logged). ns.doing names what the addon was busy with (the self-test sets it to its step).
ns:RegisterEvent("LUA_WARNING", function(_, _, text)
  if type(text) == "string" and text:find(ADDON, 1, true) then ns:LogError("LUA_WARNING", text, ns.doing) end
end)

-- Chat output. The setting "Chat messages" decides what is shown: all, important only, or nothing.
function ns:Print(msg, important)
  local mode = ns.Settings and ns.char and ns.Settings:Get("chat") or "all"
  if mode == "off" or (mode == "important" and not important) then return end
  DEFAULT_CHAT_FRAME:AddMessage("|cffe2b857" .. L.ADDON_NAME .. "|r: " .. tostring(msg))
end

-- Developer output (/jtf debug): always printed, never queued.
function ns:Debug(msg)
  if ns.quiet then return end -- /jtf tour keeps the chat clean for its screenshots
  DEFAULT_CHAT_FRAME:AddMessage("|cff8a98c0JTF debug|r: " .. tostring(msg))
end

-- WoW Forever: up to 1.0.1 a character was known by its first name alone ("Erathor-<realm>"); in 1.0.2 and 1.0.3 every
-- name ended with this addon's own numbered realm ("Arielas Fireson-CAMWOWEU4Realm9RPPvP"); since 1.0.4 with the
-- ruleset ("Arielas Fireson-PvP", Core/Util.lua). Once per character, the saved data is moved to the new keys: this
-- character's first-name key becomes its whole name, and every name on its realm gets the ruleset.
local function remap(t, fix, seen)
  seen[t] = true
  local moves = {}
  for k, v in pairs(t) do
    if type(v) == "table" then
      if not seen[v] then remap(v, fix, seen) end
    elseif type(v) == "string" then
      local n = fix(v)
      if n then t[k] = n end
    end
    if type(k) == "string" then
      local n = fix(k)
      if n and n ~= k then moves[k] = n end
    end
  end
  for k, n in pairs(moves) do
    if t[n] == nil then t[n] = t[k] end
    t[k] = nil
  end
end

function ns.KeepWholeName()
  if not (ns.db and ns.char) then return end
  local me, new, old = ns.Self(), ns.Realm(), ns.GameRealm()
  local first = (me or ""):match("^(%S+) [^%-]+%-")
  if not first or ns.char.wholeName == me then return end
  local mine, tail = first .. "-" .. old, "-" .. old
  local function fix(s)
    if s == mine then return me end
    if new ~= old and #s > #tail and s:sub(-#tail) == tail and not s:sub(1, -#tail - 1):find("-", 1, true) then
      return s:sub(1, -#tail - 1) .. "-" .. new
    end
  end
  remap(ns.char, fix, {})
  remap(ns.db, fix, {})
  ns.char.wholeName = me
end

ns:RegisterEvent("ADDON_LOADED", function(_, name)
  if name ~= ADDON then return end
  -- The dungeons, raids and quests WoW Forever offers, before anything reads them.
  ns.KeepThisGame()
  -- Account-wide: every character's last known fellowship (for "Your characters").
  _G[DB_NAME] = _G[DB_NAME] or { schema = 1, characters = {}, fellowships = {} }
  -- Per character: this character's membership, personal settings and window position.
  _G[CHAR_NAME] = _G[CHAR_NAME] or { schema = 1 }
  ns.db, ns.char = _G[DB_NAME], _G[CHAR_NAME]
  -- Where dungeon quests start and their XP, as learned in play until 1.5: Data/DungeonQuests.lua's now.
  ns.db.questStarts, ns.db.questXP = nil, nil
  -- The dungeons' mob XP measured in runs until 1.5: the room no longer counts the mobs (10 Nov 2026).
  ns.db.mobXP = nil
  ns.KeepWholeName()
  -- This copy's version (from the TOC; the packager fills it in), shared with the other Heroes.
  local meta = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
  ns.VERSION = meta and meta(ADDON, "Version") or nil
  ns.Settings:Init(ns.char)
  ns:Fire("DB_READY")
end)

ns:RegisterEvent("PLAYER_LOGIN", function()
  ns.KeepWholeName() -- (in case the game gave no surname yet when the addon loaded)
  ns:Fire("LOGIN")
  ns:Print(L.LOADED)
end)
