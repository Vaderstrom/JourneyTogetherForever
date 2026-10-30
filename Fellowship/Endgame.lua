-- The Endgame (SPEC §2, M18): after the journey, the classic raids (Data/Dungeons.lua, ns.RAIDS). It opens when the
-- last chapter is complete, and only then (29 Oct 2026: everyone at level 60 no longer opens it; a fellowship of
-- level 70s on retail got the banner in its second chapter). Then the Raids page shows each raid with who is
-- attuned, boss progress and clears; raid kills count like dungeon kills (Fellowship/Clears.lua) once it is open,
-- with the same "Heroes needed for a run" (the rest of the raid can be anyone).
local _, ns = ...
local L = ns.L
local F, J = ns.Fellowship, ns.Journey
local E = {}
ns.Endgame = E

function E:Open(f)
  return f ~= nil and J:CurrentIndex(f) > #f.journey.chapters
end

-- Do kills in key count for this fellowship? A dungeon of its journey, or a raid once the Endgame is open.
function E:Tracked(f, key)
  if f.journey.place[key] then return true end
  return ns.Raid(key) ~= nil and self:Open(f)
end

-- Does this Hero have what the raid needs? (true when it needs no attunement.)
function E:Attuned(f, raid, name)
  local key = raid[5]
  if not key then return true end
  for _, a in ipairs(ns.QuestLists:Attunements(f)) do
    if a.key == key then return ns.QuestLists:Progress(f, a, name).done end
  end
  return true
end

-- { attuned = { names }, missing = { names } } among the counted Heroes (this character first).
function E:AttuneStatus(f, raid)
  local out = { attuned = {}, missing = {} }
  for _, name in ipairs(J:Counted(f)) do
    table.insert(self:Attuned(f, raid, name) and out.attuned or out.missing, name)
  end
  return out
end

-- Per boss: { name, have (Heroes who killed it), of (counted) }.
function E:BossProgress(f, key)
  local counted, out = J:Counted(f), {}
  for _, b in ipairs(ns.Clears:Bosses(key)) do
    local have = 0
    for _, name in ipairs(counted) do
      local k = f.kills[key] and f.kills[key][name]
      if k and k[b.tok] then have = have + 1 end
    end
    out[#out + 1] = { name = b.name, have = have, of = #counted }
  end
  return out
end

-- Find group for a raid: every online Hero who has not cleared it. A raid needs a raid group: in a party it is made
-- a raid first; alone, the first four are invited and a click again (once someone has joined) invites the rest.
function E:FindGroup(f, key)
  local who, list = J:ClearedBy(f, key), {}
  for _, name in ipairs(ns.Together:Online(f)) do
    if not who[name] and not J:Away(f, name) then list[#list + 1] = name end
  end
  local r = ns.Raid(key)
  if #list == 0 then
    ns:Toast(nil, L.FIND_GROUP, L.FIND_NOBODY:format(r and r[2] or key))
    return list
  end
  local inRaid = IsInRaid and IsInRaid()
  local inParty = not inRaid and IsInGroup and IsInGroup()
  if inParty then
    local convert = (C_PartyInfo and C_PartyInfo.ConvertToRaid) or ConvertToRaid
    if convert then convert(); inRaid = true end
  end
  if not inRaid and #list > 4 then
    local first = {}
    for i = 1, 4 do first[i] = list[i] end
    ns.Together:Invite(first)
    ns:Toast(nil, L.FIND_GROUP, L.RAID_INVITE_MORE:format(#list - 4))
    return first
  end
  ns.Together:Invite(list)
  return list
end

-- The first time the Endgame is open for this character's fellowship: a big moment.
function E:Check()
  local f = F:Current()
  if not f or not self:Open(f) then return end
  ns.char.endgameSeen = type(ns.char.endgameSeen) == "table" and ns.char.endgameSeen or {}
  if ns.char.endgameSeen[f.id] then return end
  ns.char.endgameSeen[f.id] = time()
  -- After the "journey complete" banner (a big one stays about seven seconds), not over it.
  C_Timer.After(self.TOAST_AFTER, function() ns:Toast("journey", L.TOAST_ENDGAME, L.TOAST_ENDGAME_TEXT) end)
end
E.TOAST_AFTER = 8

ns:On("FELLOWSHIP", function() E:Check() end)
ns:On("HEROES", function() E:Check() end)
