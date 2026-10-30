-- Small helpers shared by every module.
local _, ns = ...
local L = ns.L

-- "#C08A2E" or "C08A2E" -> 0.75, 0.54, 0.18
function ns.Hex(hex)
  hex = hex:gsub("^#", "")
  return tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255
end

function ns.Clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

-- Messages between modules: ns:On("SETTING", fn), ns:Fire("SETTING", key, value).
local listeners = {}
function ns:On(event, fn)
  listeners[event] = listeners[event] or {}
  table.insert(listeners[event], fn)
end

function ns:Fire(event, ...)
  for _, fn in ipairs(listeners[event] or {}) do fn(...) end
end

---------------------------------------------------------------------------
-- Names. Heroes are stored as "Name-Realm" and shown as "Name".
---------------------------------------------------------------------------
function ns.Realm()
  local r = GetNormalizedRealmName and GetNormalizedRealmName()
  if not r or r == "" then r = (GetRealmName() or ""):gsub("[%s%-]", "") end
  return r
end

function ns.FullName(name)
  if not name or name == "" then return nil end
  name = strtrim(name)
  if name:find("-", 1, true) then return name end
  return name .. "-" .. ns.Realm()
end

-- WoW Forever, or retail (where we test until Forever is out)? The game's project ID says it (Forever:
-- WOW_PROJECT_CAMELOT); without it, Forever's interface numbers are the ones below 100000.
function ns.IsForever()
  if WOW_PROJECT_ID and WOW_PROJECT_CAMELOT then return WOW_PROJECT_ID == WOW_PROJECT_CAMELOT end
  return (select(4, GetBuildInfo()) or 0) < 100000
end

-- Trial accounts and accounts without game time cannot send addon messages (Forever, and retail from 12.1.7), so a
-- fellowship never hears them. Allowed, with a clear warning: a line on Welcome, a toast when founding or joining,
-- and a bar across the book (27 Oct 2026).
function ns.Trial()
  -- (/jtf selftest pretends one, to show the warnings.)
  if ns.Dev and ns.Dev.pretendTrial ~= nil then return ns.Dev.pretendTrial end
  return (IsTrialAccount and IsTrialAccount()) or (IsVeteranTrialAccount and IsVeteranTrialAccount()) or false
end

-- The realm of "Name-Realm" (nil for a bare name).
function ns.RealmOf(name) return type(name) == "string" and name:match("%-(.+)$") or nil end

-- Can fellowship messages reach this character? Addon whispers reach your own realm and the realms connected to it.
-- The game lists those (GetAutoCompleteRealms; empty when the realm has no partners). Without that list: yes.
local function realmKey(r) return (r or ""):gsub("[%s%-]", ""):lower() end
function ns.Reachable(name)
  local realm = ns.RealmOf(name)
  if not realm or realmKey(realm) == realmKey(ns.Realm()) then return true end
  local list = GetAutoCompleteRealms and GetAutoCompleteRealms()
  if type(list) ~= "table" then return true end
  for _, r in ipairs(list) do
    if realmKey(r) == realmKey(realm) then return true end
  end
  return false
end

function ns.Short(name) return name and (Ambiguate(name, "short")) or "" end

-- "Name" for this realm, "Name-Realm" for another.
function ns.Display(name) return name and (Ambiguate(name, "none")) or "" end

function ns.Me()
  -- While the book draws another character's fellowship (Fellowship/Watch.lua), "me" is that character.
  local W = ns.Watch
  if W and W.rendering and W.as then return W.as end
  return ns.Self()
end

-- The character being played, also while the book draws another one's fellowship (the "player" unit, models).
function ns.Self() return ns.FullName(UnitName("player")) end

-- Character names: letters only, first one capital (as the game shows them).
function ns.CleanName(text)
  text = strtrim(text or "")
  local name, realm = text:match("^([^%-]+)%-?(.*)$")
  if not name or name == "" then return nil end
  name = name:sub(1, 1):upper() .. name:sub(2):lower()
  return realm ~= "" and (name .. "-" .. realm) or name
end

---------------------------------------------------------------------------
-- Time: "just now", "10 min ago", "3 hours ago", "yesterday", "2 days ago".
---------------------------------------------------------------------------
function ns.TimeAgo(t)
  local d = math.max(0, time() - (t or 0))
  if d < 60 then return L.TIME_JUST_NOW end
  if d < 3600 then return L.TIME_MIN:format(math.floor(d / 60)) end
  if d < 86400 then
    local h = math.floor(d / 3600)
    return h == 1 and L.TIME_HOUR or L.TIME_HOURS:format(h)
  end
  if d < 2 * 86400 then return L.TIME_YESTERDAY end
  return L.TIME_DAYS:format(math.floor(d / 86400))
end

-- Time left: "45 min", "1 hour", "5 hours", "1 day", "3 days".
function ns.TimeLeft(sec)
  sec = math.max(0, sec or 0)
  if sec < 3600 then return L.MINUTES_N:format(math.max(1, math.ceil(sec / 60))) end
  if sec < 86400 then
    local h = math.floor(sec / 3600)
    return h == 1 and L.DUR_1H or L.HOURS_N:format(h)
  end
  local d = math.floor(sec / 86400)
  return (d == 1 and L.DAYS_1 or L.DAYS_N):format(d)
end

---------------------------------------------------------------------------
-- Addon versions: "v1.2.3" or "1.2.3-beta" -> { 1, 2, 3 }; nil for a development copy ("@project-version@").
---------------------------------------------------------------------------
function ns.ParseVersion(v)
  if type(v) ~= "string" then return nil end
  local a, b, c = v:match("^v?(%d+)%.(%d+)%.?(%d*)")
  if not a then return nil end
  return { tonumber(a), tonumber(b), tonumber(c) or 0 }
end

-- Is version a newer than b? False when either is unknown.
function ns.NewerVersion(a, b)
  local x, y = ns.ParseVersion(a), ns.ParseVersion(b)
  if not x or not y then return false end
  for i = 1, 3 do
    if x[i] ~= y[i] then return x[i] > y[i] end
  end
  return false
end

---------------------------------------------------------------------------
-- Class colours from the mockup: bright on dark themes, ink on light ones.
---------------------------------------------------------------------------
local CLS = { WARRIOR = "C69B6D", PALADIN = "F48CBA", HUNTER = "AAD372", ROGUE = "FFF468", PRIEST = "E8E8E8", SHAMAN = "2459FF",
  MAGE = "3FC7EB", WARLOCK = "8788EE", DRUID = "FF7C0A" }
local CLS_INK = { WARRIOR = "7A5230", PALADIN = "A8406E", HUNTER = "4E7A2A", ROGUE = "7A6A00", PRIEST = "55555A", SHAMAN = "0A4AB8",
  MAGE = "1A6E8E", WARLOCK = "4A3E9A", DRUID = "A8540A" }

-- Item quality colours (0 poor … 7 heirloom): bright on dark themes, ink on light ones.
local QCOL = { [0] = "9D9D9D", "FFFFFF", "1EFF00", "0070DD", "A335EE", "FF8000", "E6CC80", "00CCFF" }
local QCOL_INK = { [0] = "6B6B6B", "3B2410", "1E7A00", "0058B0", "7A1FB8", "B85A00", "8A7A40", "007A99" }
function ns.QualityHex(q, light) return (light and QCOL_INK or QCOL)[q or 1] or QCOL[1] end

-- Returns a hex colour for a class token ("WARRIOR"), or nil for unknown classes.
function ns.ClassHex(token, light)
  if not token then return nil end
  local hex = (light and CLS_INK or CLS)[token]
  if hex then return hex end
  local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[token]
  if not c then return nil end
  local k = light and 0.55 or 1
  return ("%02X%02X%02X"):format(c.r * 255 * k, c.g * 255 * k, c.b * 255 * k)
end

-- Another addon's chat command, by any of its names ("/dj"): its function in SlashCmdList, or nil when that addon
-- is not running. How the book opens the addons it works with (UI/OtherAddons.lua).
function ns.SlashCommand(...)
  local want = {}
  for i = 1, select("#", ...) do want[select(i, ...)] = true end
  for key, fn in pairs(SlashCmdList) do
    for i = 1, 9 do
      local cmd = _G["SLASH_" .. key .. i]
      if type(cmd) ~= "string" then break end
      if want[cmd:lower()] then return fn end
    end
  end
  return nil
end
