-- The fellowship: state, creation and changes (docs/ARCHITECTURE.md §1–2).
-- Every change is an "op". The Hero who makes it applies it, raises the version (f.v) and sends it to the
-- other Heroes (Fellowship/Sync.lua). Everyone checks the sender's rank (Rules/Permissions.lua) before applying.
local _, ns = ...
local L = ns.L
local P, R = ns.Permissions, ns.Rules
local F = { pendingJoin = {} }
ns.Fellowship = F

F.CHRONICLE_MAX = 50
F.ROLES = { Tank = true, Healer = true, DPS = true }

function F:Get(id) return id and ns.db.fellowships[id] or nil end

-- This character's fellowship (nil when none, or when it was disbanded or this character is no longer in it).
function F:Current()
  -- While the book draws another character's fellowship (Fellowship/Watch.lua): that one.
  local W = ns.Watch
  if W and W.rendering then return W:Fellowship() end
  local f = self:Get(ns.char.fellowshipId)
  if f and not f.disbanded and f.members[ns.Me()] then return f end
  return nil
end

function F:Count(f)
  local n = 0
  for _ in pairs(f.members) do n = n + 1 end
  return n
end

-- Sorted member names: the leader, then the Adventurers, each by name.
function F:Members(f)
  local list = {}
  for name in pairs(f.members) do list[#list + 1] = name end
  local function order(n) return n == f.leader and 0 or 1 end
  table.sort(list, function(a, b)
    if order(a) ~= order(b) then return order(a) < order(b) end
    return a < b
  end)
  return list
end

-- About this character, shared when founding or joining (until M3 shares it live).
function F:MyInfo()
  local _, class = UnitClass("player")
  local guild, _, rankIndex = GetGuildInfo("player")
  return { class = class, level = UnitLevel("player"), guild = guild, gm = guild ~= nil and rankIndex == 0 or nil }
end

-- The fellowship's own story (the History page, UI/Pages/History.lua): f.chronicle = { { text, time, k, who } },
-- newest first. k says what happened (lines written before 29 Oct 2026 have none); who is the Adventurer it is about.
-- The History page's filter of each k; "journey" lines (changes to clears and milestones) show under All only, as
-- the Chronicle has them too.
F.LOG_GROUP = {
  founded = "members", invited = "members", joined = "members", left = "members", removed = "members", swap = "members",
  leads = "members", swapleader = "members", takeover = "members",
  rules = "rules", journey = "rules", renamed = "rules", vote = "rules", votepassed = "rules",
  gather = "events", gathercancel = "events", tstart = "events", champion = "events", tcancel = "events",
  marked = "journey", undid = "journey", reopened = "journey", ticked = "journey", unticked = "journey",
}
function F:Log(f, text, t, k, who)
  table.insert(f.chronicle, 1, { text = text, time = t or time(), k = k, who = who })
  while #f.chronicle > self.CHRONICLE_MAX do table.remove(f.chronicle) end
end

-- The chronicle as the pages show it: the same line in a row once, with a count ("× 4"). (Seen in the UI tour.)
-- { { text, time, n, k } }, newest first, at most max; group: only the lines of that History filter.
function F:ChronicleView(f, max, group)
  local out = {}
  for _, e in ipairs(f.chronicle) do
    if not group or self.LOG_GROUP[e.k] == group then
      local last = out[#out]
      if last and last.text == e.text then last.n = last.n + 1
      else
        if #out >= max then break end
        out[#out + 1] = { text = e.text, time = e.time, n = 1, k = e.k }
      end
    end
  end
  for _, e in ipairs(out) do if e.n > 1 then e.text = L.CHR_TIMES:format(e.text, e.n) end end
  return out
end

local function validBanner(color)
  for _, b in ipairs(ns.BANNERS) do if b[2] == color then return true end end
  return false
end

-- An emblem: a game icon name (see ns.Emblems).
local function validEmblem(e) return ns.Emblems:Valid(e) end

local function cleanName(text)
  text = type(text) == "string" and strtrim(text) or ""
  if text == "" or #text > 48 then return nil end
  return text
end

-- History entries as the pages and the Discord board read them: each with a type and a time, numbers as numbers, a
-- run with its dungeon and lists. One that is not is left out (a chapter number as text broke the board at logout;
-- code review, 30 Oct 2026).
local function cleanHistory(list)
  local out = {}
  for _, e in ipairs(type(list) == "table" and list or {}) do
    if type(e) == "table" and type(e.type) == "string" and tonumber(e.time) and (e.type ~= "run" or type(e.key) == "string") then
      for _, k in ipairs({ "time", "last", "ch", "of", "need", "bossesKilled", "bossesOf" }) do e[k] = tonumber(e[k]) end
      if type(e.text) ~= "string" then e.text = nil end
      if e.type == "run" then
        for _, k in ipairs({ "names", "cleared", "killed" }) do if type(e[k]) ~= "table" then e[k] = {} end end
      end
      out[#out + 1] = e
    end
  end
  return out
end

-- Fills in anything missing, so a copy from another Hero (or an older version) is safe to use.
function F:Sanitize(f)
  if type(f) ~= "table" or type(f.id) ~= "string" or type(f.leader) ~= "string" or type(f.members) ~= "table" then return nil end
  f.v = tonumber(f.v) or 0
  f.name = cleanName(f.name) or L.ADDON_NAME
  f.color = validBanner(f.color) and f.color or ns.BANNERS[1][2]
  f.emblem = validEmblem(f.emblem) and f.emblem or ns.Emblems:First()
  -- Stewards are gone (two ranks, 27 Oct 2026): an old copy's officers are Adventurers.
  f.officers = {}
  f.invites = type(f.invites) == "table" and f.invites or {}
  f.inviteFrom = type(f.inviteFrom) == "table" and f.inviteFrom or {}
  f.rules = R.Clean(f.rules)
  f.chronicle = type(f.chronicle) == "table" and f.chronicle or {}
  f.heroes = type(f.heroes) == "table" and f.heroes or {}
  f.runs = type(f.runs) == "table" and f.runs or {}
  f.kills = type(f.kills) == "table" and f.kills or {}
  if type(f.tourney) ~= "table" then f.tourney = nil end
  f.gatherings = type(f.gatherings) == "table" and f.gatherings or {}
  f.votes = type(f.votes) == "table" and f.votes or {}
  f.reached = tonumber(f.reached) and math.floor(f.reached) or nil
  f.reopenV = tonumber(f.reopenV)
  f.undone = type(f.undone) == "table" and f.undone or {}
  f.history = cleanHistory(f.history)
  f.ticks = type(f.ticks) == "table" and f.ticks or {}
  -- Which changes this copy has: the highest count of each character's changes (Fellowship/Sync.lua).
  local seen = {}
  if type(f.seen) == "table" then
    for a, n in pairs(f.seen) do if type(a) == "string" and tonumber(n) then seen[a] = tonumber(n) end end
  end
  f.seen = seen
  f.journey = ns.Journey.Clean(f.journey) or ns.BuildJourney("classic")
  ns.Journey.MigrateKeys(f)
  for name, m in pairs(f.members) do if type(m) ~= "table" then f.members[name] = { role = "DPS" } end end
  return f
end

---------------------------------------------------------------------------
-- Founding
---------------------------------------------------------------------------
-- o: name, color, emblem, role, preset, rules
function F:Create(o)
  if ns.Trial() then ns:Toast(nil, L.TRIAL_T, L.TRIAL) end
  local me, now = ns.Me(), time()
  local info = self:MyInfo()
  local f = {
    id = (UnitGUID("player") or me) .. "-" .. now, v = 1,
    name = cleanName(o.name) or L.DEFAULT_FELLOWSHIP_NAME:format(ns.Short(me)),
    faction = (UnitFactionGroup("player")), color = validBanner(o.color) and o.color or ns.BANNERS[1][2],
    emblem = validEmblem(o.emblem) and o.emblem or ns.Emblems:First(), leader = me, officers = {},
    members = { [me] = { role = F.ROLES[o.role] and o.role or "DPS", joined = now, class = info.class, level = info.level, guild = info.guild, gm = info.gm } },
    -- (o.journey: one shaped while creating it, "Your own journey"; otherwise the preset's.)
    invites = {}, inviteFrom = {}, rules = R.Clean(o.rules), journey = (o.journey and ns.Journey.Clean(o.journey)) or ns.BuildJourney(o.preset),
    chronicle = {}, heroes = {}, runs = {}, kills = {}, undone = {}, history = {}, ticks = {}, seen = {}, updated = now,
  }
  self:Log(f, L.CHR_FOUNDED:format(f.name, ns.Short(me)), now, "founded", me)
  ns.db.fellowships[f.id] = f
  ns.char.fellowshipId = f.id
  wipe(ns.char.invites)
  self:Changed()
  ns:Fire("JOINED")
  return f
end

---------------------------------------------------------------------------
-- Changes (ops). Apply checks that "by" may make the change, then makes it.
---------------------------------------------------------------------------
function F:Apply(f, op, by, t)
  if type(op) ~= "table" then return false end
  t = tonumber(t) or time()
  local k, n = op.k, op.name
  if k == "invite" then
    if not P.Can(f, by, "invite") or type(n) ~= "string" or f.members[n] then return false end
    f.invites[n] = t
    f.inviteFrom[n] = by
    self:Log(f, L.CHR_INVITED:format(ns.Short(n)), t, "invited", n)
  elseif k == "uninvite" then
    if not P.Can(f, by, "uninvite", n) or not f.invites[n] then return false end
    f.invites[n], f.inviteFrom[n] = nil, nil
  elseif k == "join" then
    -- Made by the Hero who received the accept: that Hero must be allowed to invite, and the invite must exist.
    if not P.Can(f, by, "answer") or not f.invites[n] or f.members[n] or not F.ROLES[op.role] then return false end
    f.invites[n], f.inviteFrom[n] = nil, nil
    f.members[n] = { role = op.role, joined = t, class = op.class, level = tonumber(op.level), guild = op.guild, gm = op.gm }
    ns.Journey:MarkNewcomer(f, n, op.level)
    -- "X was invited" is folded into "X joined the fellowship".
    local invited = L.CHR_INVITED:format(ns.Short(n))
    for i = #f.chronicle, 1, -1 do if f.chronicle[i].text == invited then table.remove(f.chronicle, i) end end
    self:Log(f, L.CHR_JOINED:format(ns.Short(n)), t, "joined", n)
  elseif k == "leave" then
    if not P.Can(f, by, "leave") then return false end
    f.members[by] = nil
    self:Log(f, L.CHR_LEFT:format(ns.Short(by)), t, "left", by)
  elseif k == "remove" then
    if not P.Can(f, by, "remove", n) then return false end
    f.members[n] = nil
    self:Log(f, L.CHR_REMOVED:format(ns.Short(n)), t, "removed", n)
  elseif k == "lead" then
    if not P.Can(f, by, "lead", n) then return false end
    f.leader = n
    self:Log(f, L.CHR_LEADS:format(ns.Short(n)), t, "leads", n)
  elseif k == "rename" then
    local name = cleanName(op.name)
    if not P.Can(f, by, "rename") or not name then return false end
    f.name = name
    self:Log(f, L.CHR_RENAMED:format(name), t, "renamed", by)
  elseif k == "banner" then
    if not P.Can(f, by, "banner") or not validBanner(op.color) or not validEmblem(op.emblem) then return false end
    f.color, f.emblem = op.color, op.emblem
  elseif k == "rules" then
    -- Rules Admin publishes the rules (the leader); a passed vote changes one rule (Fellowship/Votes.lua).
    if not P.Can(f, by, "rules") or type(op.rules) ~= "table" then return false end
    f.rules = R.Clean(op.rules)
    self:Log(f, L.CHR_RULES:format(ns.Short(by)), t, "rules", by)
    if by ~= ns.Me() and not f.sample then ns:Toast(nil, L.RULES_PUBLISHED_T, L.RULES_PUBLISHED:format(ns.Short(by)), "rules") end
  elseif k == "disband" then
    if not P.Can(f, by, "disband") then return false end
    f.disbanded = t
  elseif k == "journey" then
    -- Journey Admin publishes a new journey (the leader).
    local journey = ns.Journey.Clean(op.journey)
    if not P.Can(f, by, "journey") or not journey then return false end
    f.journey = journey
    -- Fewer chapters than the fellowship had reached: the journey is complete, not beyond it.
    if f.reached and f.reached > #journey.chapters + 1 then f.reached = #journey.chapters + 1 end
    ns.Clears:Reevaluate(f) -- the needed bosses may have changed
    self:Log(f, L.CHR_JOURNEY, t, "journey", by)
    -- The Adventurers hear of it (they did not; seen in game).
    if by ~= ns.Me() and not f.sample then ns:Toast(nil, L.JOURNEY_NEW_T, L.JOURNEY_NEW:format(ns.Short(by)), "overview") end
  elseif k == "role" then
    -- Role and secondary role ("" for none); the secondary role cannot be the same as the role.
    local second = op.second or ""
    if not P.Can(f, by, "roles", n) or not F.ROLES[op.role] or (second ~= "" and (not F.ROLES[second] or second == op.role)) then return false end
    f.members[n].role, f.members[n].second = op.role, second ~= "" and second or nil
  elseif k == "away" then
    -- Away by yourself ("self") or marked by the leader ("forced"); on = false clears it.
    if not P.Can(f, by, "away", n) then return false end
    f.members[n].away = op.on and (by == n and "self" or "forced") or nil
  elseif k == "swap" then
    -- Play another character on the same account: it takes this Hero's place, rank and roles.
    if not P.Can(f, by, "swap") or type(n) ~= "string" or f.members[n] or f.invites[n] then return false end
    local m = f.members[by]
    f.members[n] = { role = m.role, second = m.second, joined = m.joined, class = op.class, level = tonumber(op.level) }
    ns.Journey:MarkNewcomer(f, n, op.level)
    f.members[by] = nil
    if f.leader == by then f.leader = n end
    if f.heroes then f.heroes[by] = nil end
    self:Log(f, L.CHR_SWAP:format(ns.Short(by), ns.Short(n)), t, f.leader == n and "swapleader" or "swap", n)
  elseif k == "tourney" then
    -- The Guild Master tournament: start, sign up, a duel won, sign-up or a round over (Fellowship/Tourney.lua).
    if not P.Rank(f, by) or not ns.Tourney:Apply(f, op, by, t) then return false end
  elseif k == "gather" then
    -- Gatherings (Fellowship/Gatherings.lua): any Hero schedules, answers for themselves; organizer, leader and
    -- the leader cancel.
    if not P.Rank(f, by) or not ns.Gatherings:Apply(f, op, by, t) then return false end
  elseif k == "vote" then
    -- Rule votes (Fellowship/Votes.lua): any Hero proposes and votes; a majority changes the rule.
    if not P.Rank(f, by) or not ns.Votes:Apply(f, op, by, t) then return false end
  elseif k == "takeover" then
    -- The longest-serving Adventurer takes over when the leader has not been seen for the rule's days (Progress.lua).
    if not ns.Progress:CanTakeOver(f, by) then return false end
    local old = f.leader
    f.leader = by
    self:Log(f, L.CHR_TAKEOVER:format(ns.Short(by), ns.Short(old), f.rules.takeover), t, "takeover", by)
  elseif k == "tick" then
    -- A milestone ticked off by hand (Rules/Milestones.lua): the leader.
    local m = type(op.id) == "string" and ns.Milestones:Find(f, op.id)
    if not P.Can(f, by, "clears") or not m or m.kind ~= "tick" then return false end
    f.ticks[op.id] = op.on and { by = by, t = t } or nil
    self:Log(f, (op.on and L.CHR_TICKED or L.CHR_UNTICKED):format(ns.Short(by), m.name), t, op.on and "ticked" or "unticked", by)
  elseif k == "clear" or k == "unclear" or k == "cell" then
    -- Mark cleared, Undo clear, one Hero's clear (Fellowship/Clears.lua): the leader.
    if not P.Can(f, by, "clears") or type(op.key) ~= "string" or not ns.Endgame:Tracked(f, op.key) then return false end
    if not ns.Clears:ApplyOp(f, op, by, t) then return false end
  else
    return false
  end
  f.updated = t
  return true
end

-- After a change: leave the fellowship locally if it was disbanded or this character is no longer in it. Taken out
-- by someone else (removed, or disbanded, also while away and learned from a copy later) says so; leaving yourself
-- (F.leaving) does not.
function F:AfterChange(f)
  if ns.char.fellowshipId == f.id and (f.disbanded or not f.members[ns.Me()]) then
    ns.char.fellowshipId = nil
    -- The getting-started card goes with the membership: joining again starts it afresh (the lab's Test fellowship
    -- keeps one id, so its welcome card stayed ticked or hidden from one run to the next; 30 Oct 2026).
    if ns.char.started then ns.char.started[f.id] = nil end
    if not self.leaving then ns:Toast(nil, L.GONE_T, (f.disbanded and L.GONE_DISBANDED or L.GONE_REMOVED):format(f.name)) end
  end
  self:Changed()
end

-- Makes a change as this character and sends it to the other Heroes. Returns true when it was allowed.
function F:Do(op)
  -- Nothing is changed from a watched fellowship's pages (they draw as another character).
  if ns.Watch and ns.Watch.rendering then return false end
  local f = self:Current()
  if not f then return false end
  local me, t = ns.Me(), time()
  local others = {}
  for name in pairs(f.members) do if name ~= me then others[#others + 1] = name end end
  if not self:Apply(f, op, me, t) then return false end
  f.v = f.v + 1
  local n = ns.Sync:Note(f, me, nil, me, op, t)
  ns.Sync:SendOp(f, others, op, t, me, n, me)
  self:AfterChange(f)
  return true
end

---------------------------------------------------------------------------
-- Actions used by the pages
---------------------------------------------------------------------------
-- Returns "sent", "member", "invited", "realm" (a realm messages cannot reach), "busy" (messages are not allowed now:
-- a fight, a dungeon) or nil (not allowed / no name). Whether it arrived comes a few seconds later (Fellowship/Sync.lua).
function F:Invite(text)
  local f = self:Current()
  local name = ns.FullName(ns.CleanName(text))
  if not f or not name or not P.Can(f, ns.Me(), "invite") then return nil end
  if not ns.Reachable(name) then
    ns:Toast(nil, L.INVITE_NOT_SENT, L.INVITE_REALM:format(ns.Short(name), ns.RealmOf(name)))
    return "realm"
  end
  if ns.Comm:Held() then
    ns:Toast(nil, L.INVITE_NOT_SENT, L.INVITE_BUSY)
    return "busy"
  end
  if f.members[name] then
    ns:Toast(nil, L.ALREADY_HERO, L.ALREADY_HERO_TEXT:format(ns.Short(name)))
    return "member"
  end
  if f.invites[name] then
    ns:Toast(nil, L.ALREADY_INVITED, L.ALREADY_INVITED_TEXT:format(ns.Short(name)))
    return "invited"
  end
  if not self:Do({ k = "invite", name = name }) then return nil end
  ns.Sync:SendInvite(f, name)
  return "sent"
end

function F:CancelInvite(name)
  local f = self:Current()
  if f and self:Do({ k = "uninvite", name = name }) then ns.Comm:Send(name, "INVX", { fid = f.id }) end
end

-- Invitations to this character (only while not in a fellowship), newest first. Older than a day: gone.
function F:MyInvites()
  local list = {}
  if self:Current() then return list end
  for fid, inv in pairs(ns.char.invites) do
    if time() - (inv.time or 0) > ns.Sync.EXPIRE then ns.char.invites[fid] = nil
    else list[#list + 1] = { fid = fid, inv = inv } end
  end
  table.sort(list, function(a, b) return (a.inv.time or 0) > (b.inv.time or 0) end)
  return list
end

-- Accept: the inviter's addon must take it now (ACCOK, then the fellowship comes as SNAP). If the inviter is offline,
-- does not answer, or the invite is no longer open, the player is told and asks for a new invite.
function F:AcceptInvite(fid, role)
  local inv = ns.char.invites[fid]
  if not inv or self:Current() then return end
  if ns.Trial() then ns:Toast(nil, L.TRIAL_T, L.TRIAL) end
  if ns.Comm:Held() then
    ns:Toast(nil, L.ACCEPT_FAILED, L.ACCEPT_BUSY)
    return
  end
  local p = { from = inv.from }
  self.pendingJoin[fid] = p
  local info = self:MyInfo()
  ns.Comm:Send(inv.from, "ACC", { fid = fid, role = F.ROLES[role] and role or "DPS", class = info.class, level = info.level, guild = info.guild, gm = info.gm }, true)
  ns.char.invites[fid] = nil
  C_Timer.After(ns.Sync.ACCEPT_WAIT, function()
    if F.pendingJoin[fid] == p and not p.ok then
      F.pendingJoin[fid] = nil
      ns:Toast(nil, L.ACCEPT_FAILED, L.ACCEPT_NOANSWER:format(ns.Short(inv.from)))
    end
  end)
  self:Changed()
end

function F:DeclineInvite(fid)
  local inv = ns.char.invites[fid]
  if not inv then return end
  ns.Comm:Send(inv.from, "DEC", { fid = fid })
  ns.char.invites[fid] = nil
  self:Changed()
end

-- Who leads when the leader leaves: the Adventurer who joined first (those who are away last; ties by name). nil
-- when the leader is the only one.
function F:Successor(f)
  local best, bestKey
  for name, m in pairs(f.members) do
    if name ~= f.leader then
      local key = { m.away and 1 or 0, m.joined or 0, name }
      if not best or key[1] < bestKey[1] or (key[1] == bestKey[1] and (key[2] < bestKey[2] or (key[2] == bestKey[2] and key[3] < bestKey[3]))) then
        best, bestKey = name, key
      end
    end
  end
  return best
end

-- Leaving. A leader hands the fellowship to F:Successor first, so it goes on for everyone else; a leader who is the
-- only Hero ends it. (Two changes the other Heroes' addons already know: lead, then leave.)
-- (F.leaving: no "You are no longer in ..." toast for your own leaving.)
local function yourself(fn)
  F.leaving = true
  local ok = fn()
  F.leaving = nil
  return ok
end

function F:Leave()
  local f = self:Current()
  if not f then return false end
  if f.leader ~= ns.Me() then return yourself(function() return self:Do({ k = "leave" }) end) end
  local heir = self:Successor(f)
  if not heir then return yourself(function() return self:Do({ k = "disband" }) end) end
  return self:Do({ k = "lead", name = heir }) and yourself(function() return self:Do({ k = "leave" }) end)
end

-- The question before leaving: who leads after you, or that the fellowship ends.
function F:LeaveQuestion(f)
  if f.leader ~= ns.Me() then return L.LEAVE_CONFIRM:format(f.name) end
  local heir = self:Successor(f)
  if not heir then return L.LEAVE_CONFIRM_ALONE:format(f.name) end
  return L.LEAVE_CONFIRM_LEAD:format(f.name, ns.Short(heir))
end
function F:Remove(name) return self:Do({ k = "remove", name = name }) end
function F:MakeLeader(name) return self:Do({ k = "lead", name = name }) end
function F:Rename(text) return self:Do({ k = "rename", name = text }) end
function F:SetBanner(color, emblem) return self:Do({ k = "banner", color = color, emblem = emblem }) end
function F:SetRules(rules) return self:Do({ k = "rules", rules = rules }) end
function F:Disband() return yourself(function() return self:Do({ k = "disband" }) end) end
function F:SetRoles(name, role, second) return self:Do({ k = "role", name = name, role = role, second = second or "" }) end
function F:SetAway(name, on) return self:Do({ k = "away", name = name, on = on and true or false }) end
function F:Tick(id, on) return self:Do({ k = "tick", id = id, on = on and true or false }) end

-- Play another character (27 Oct 2026): from the alt, not the main. While you play an alt, Your characters offers
-- "Take <main>'s place" for a fellowship of another character on this account. Same faction only, and not while
-- this character is in a fellowship of its own. First the newest copy is fetched from a Companion who is online
-- (Fellowship/Watch.lua); that Companion takes the change and passes it on. Nobody online: nothing changes.
F.TAKE_WAIT = 10

-- Can this character take main's place? true, or false and why (nil: not offered at all).
function F:CanTake(main)
  local c = ns.db.characters[main]
  local f = c and self:Get(c.fellowshipId)
  local me = ns.Me()
  if not f or f.disbanded or not f.members[main] or main == me or f.members[me] then return false end
  local own = self:Current()
  if own then return false, L.TAKE_LEAVE_FIRST:format(own.name) end
  if f.faction and f.faction ~= UnitFactionGroup("player") then return false, L.TAKE_FACTION:format(f.faction) end
  return true
end

function F:TakePlace(main)
  if not self:CanTake(main) then return false end
  local W, fid = ns.Watch, ns.db.characters[main].fellowshipId
  local name = self:Get(fid).name
  local function done(fresh) F:FinishTake(main, fresh.id) end
  W.onNews[fid] = done
  W:Poll(fid)
  C_Timer.After(self.TAKE_WAIT, function()
    if W.onNews[fid] ~= done then return end
    W.onNews[fid] = nil
    ns:Toast(nil, L.TAKE_FAILED, L.TAKE_NO_ANSWER:format(name, ns.Short(main)))
  end)
  return true
end

-- The newest copy is here: the change is made as main (Sync.lua accepts it from an alt main's addon listed).
function F:FinishTake(main, fid)
  local f, me, t = self:Get(fid), ns.Me(), time()
  if not f or f.disbanded or not f.members[main] or f.members[me] then return false end
  local _, class = UnitClass("player")
  local op = { k = "swap", name = me, from = main, class = class, level = UnitLevel("player") }
  local others = {}
  for name in pairs(f.members) do if name ~= main then others[#others + 1] = name end end
  if not self:Apply(f, op, main, t) then return false end
  f.v = f.v + 1
  local n = ns.Sync:Note(f, me, nil, main, op, t)
  ns.Sync:SendOp(f, others, op, t, me, n, main)
  ns.char.fellowshipId = f.id
  local c = ns.db.characters[main]
  if c then c.fellowshipId = nil end
  local W = ns.Watch
  if W.fid == f.id then W.active, W.fid, W.as = false, nil, nil end
  ns.Characters:Update()
  self:AfterChange(f)
  ns.Hero:Hello()
  ns:Toast(nil, L.TAKE_DONE, L.TAKE_DONE_TEXT:format(ns.Short(main), f.name))
  if ns.Window then ns.Window.page = "overview"; ns.Window:RefreshSoon() end
  return true
end
---------------------------------------------------------------------------
-- For the pages
---------------------------------------------------------------------------
-- "off", "on", "paused-guild" (not every Hero in one guild) or "paused-gm" (its Guild Master is not a Hero).
function F:TournamentState(f)
  if not f.rules.gmT then return "off" end
  local guild, gm = nil, false
  for _, m in pairs(f.members) do
    if not m.guild or (guild and m.guild ~= guild) then return "paused-guild" end
    guild = m.guild
    if m.gm then gm = true end
  end
  return gm and "on" or "paused-gm", guild
end

-- The current chapter { n, of, floor, cap, name }, or nil when the journey is complete (Rules/Journey.lua).
function F:CurrentChapter(f) return ns.Journey:Current(f) end

function F:PublishJourney(journey) return self:Do({ k = "journey", journey = journey }) end

function F:Context()
  local f = self:Current()
  if not f then return { inFellow = false } end
  local me = ns.Me()
  local rank = P.Rank(f, me)
  return {
    inFellow = true, f = f, me = me, isLeader = rank == "leader",
    tActive = self:TournamentState(f) == "on", name = f.name, color = f.color, emblem = f.emblem, heroes = self:Count(f),
    chapter = self:CurrentChapter(f),
  }
end

function F:Changed()
  if ns.Characters then ns.Characters:Update() end
  ns:Fire("FELLOWSHIP")
end

ns:On("DB_READY", function()
  ns.db.fellowships = ns.db.fellowships or {}
  ns.db.characters = ns.db.characters or {}
  ns.char.invites = type(ns.char.invites) == "table" and ns.char.invites or {}
  for id, f in pairs(ns.db.fellowships) do if not F:Sanitize(f) then ns.db.fellowships[id] = nil end end
end)
