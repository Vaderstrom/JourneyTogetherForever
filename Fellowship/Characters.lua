-- "Your characters" (SPEC §4.1): every character on this account and its fellowship, as last seen.
-- Another character's data is only as fresh as its last login, and the rows say so ("as of 2 days ago").
local _, ns = ...
local L = ns.L
local C = {}
ns.Characters = C

function C:Update()
  if not ns.db then return end
  local me = ns.Me()
  local className, class = UnitClass("player")
  local f = ns.Fellowship:Current()
  local faction, factionName = UnitFactionGroup("player")
  ns.db.characters[me] = { name = UnitName("player"), realm = ns.Realm(), class = class, className = className,
    level = UnitLevel("player"), fellowshipId = f and f.id or nil, lastSeen = time(), faction = faction, factionName = factionName }
end

-- This character first, then the others by name.
function C:List()
  local me, list = ns.Me(), {}
  for key in pairs(ns.db.characters) do list[#list + 1] = key end
  table.sort(list, function(a, b)
    if (a == me) ~= (b == me) then return a == me end
    return a < b
  end)
  return list
end

local function fellowshipOf(c)
  local f = c and ns.Fellowship:Get(c.fellowshipId)
  if f and not f.disbanded then return f end
  return nil
end

-- One row of the list (see the mockup's myChars).
function C:Row(key)
  local c = ns.db.characters[key]
  local isMe = key == ns.Me()
  local f = fellowshipOf(c)
  local row = { key = key, name = c.name, class = c.class, isMe = isMe, fellowship = f }
  row.line = L.CHAR_LINE:format(c.level or 0, c.className or "") .. (isMe and L.PLAYING_NOW or "")
  if f then
    local ch = ns.Fellowship:CurrentChapter(f)
    row.fname, row.color, row.emblem = f.name, f.color, f.emblem
    row.sub = ch and L.CHAPTER_LINE:format(ns.Journey.Roman(ch.n), ch.name) or L.JOURNEY_COMPLETE
    -- Without the chapter's name, for a row too narrow for all of it: "as of" must show ("Chapter III: The Wailing
    -- and the Wolf · as of 12..", check of 30 Oct 2026).
    row.subShort = ch and L.CHAPTER_ROMAN:format(ns.Journey.Roman(ch.n)) or L.JOURNEY_COMPLETE
    -- Followed live this session (Fellowship/Watch.lua): not "as of" when it was last played.
    local live = ns.Watch and ns.Watch.last[f.id]
    if not isMe then
      local when = live and L.ROW_LIVE or L.AS_OF:format(ns.TimeAgo(c.lastSeen))
      row.sub, row.subShort = row.sub .. when, row.subShort .. when
    end
  else
    row.fname = L.NO_FELLOWSHIP
    -- (It said "No fellowship" and "Not in a fellowship" under each other.) The other side's characters say so.
    local other = c.faction and c.faction ~= UnitFactionGroup("player")
    row.sub = isMe and L.FOUND_OR_JOIN or (other and L.CHAR_FACTION:format(c.factionName or c.faction) or "")
  end
  row.canView = f ~= nil and not isMe
  return row
end

-- The read-only summary of another character's fellowship.
function C:Summary(key)
  local c = ns.db.characters[key]
  local f = fellowshipOf(c)
  if not f or key == ns.Me() then return nil end
  local ch = ns.Fellowship:CurrentChapter(f)
  local short = c.name
  -- Followed live (Fellowship/Watch.lua) when a Companion of it answered this session.
  local W = ns.Watch
  local live = W and W.last[f.id]
  local canTake, takeNote = ns.Fellowship:CanTake(key)
  return {
    name = f.name, color = f.color, emblem = f.emblem, owner = L.ALT_OWNER:format(short),
    chapter = ch and L.ALT_CHAPTER:format(ch.n, ch.of, ch.name) or L.JOURNEY_COMPLETE,
    levels = ch and L.ALT_LEVELS:format(ch.floor, ch.cap, ns.Fellowship:Count(f)) or "",
    seen = live and L.ALT_LIVE:format(ns.TimeAgo(live)) or L.ALT_SEEN:format(ns.TimeAgo(c.lastSeen), short, short),
    canWatch = f.members[key] ~= nil and not f.members[ns.Me()],
    -- Play this character there instead (from the alt; Fellowship:TakePlace), or why not.
    canTake = canTake == true, takeNote = takeNote, short = short, fname = f.name,
  }
end

ns:On("LOGIN", function() C:Update() end)
ns:RegisterEvent("PLAYER_LEVEL_UP", function() C_Timer.After(1, function() C:Update() end) end)
ns:RegisterEvent("PLAYER_LOGOUT", function() C:Update() end)
