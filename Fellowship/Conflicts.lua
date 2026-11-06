-- Conflicts (the owner, 3 Nov 2026): data two Adventurers' addons should agree on but do not, or something that
-- cannot be in one copy, is a bug in the addon. The addon that finds it opens a window with a report to copy and the
-- addresses to post it (UI/Conflict.lua), at most once a day for the same conflict, never in a fight; the last KEEP
-- are kept in the saved data (JourneyTogetherForeverDB.conflicts).
-- Two kinds:
--   disagree    two copies that applied exactly the same changes (the same version and the same changes seen, f.seen)
--               hold different shared parts (the One Ring, the Leader, rules, votes ...); or, with the same kills,
--               different dungeon progress; or, with the same states of everyone, different firsts. Every state
--               carries small fingerprints of these (Conflicts:Prints); a difference is looked at again Sync.GRACE
--               seconds later, then the copy that loses (Sync:Beats) takes the other, and the parts that differed
--               are named as it does (Conflicts:Taking). The fellowship goes on from one copy, as always.
--   impossible  one copy holds something that cannot be: a Leader who is not in the fellowship, someone invited and
--               in it at once, an Adventurer without a role, a Ring-bearer who is not in the fellowship
--               (Conflicts:Check, after every change).
local _, ns = ...
local L = ns.L
local F = ns.Fellowship
local Cf = { KEEP = 20, AGAIN = 86400 }
ns.Conflicts = Cf

-- The parts compared, in the order they are named.
Cf.PARTS = { "ring", "leader", "members", "rules", "journey", "banner", "invites", "challenges", "votes", "gatherings",
  "tourney", "milestones", "dungeons", "firsts" }
Cf.ISSUES = { "leader", "invited", "role", "ring" }

local function hash(v)
  local s, h = ns.Serialize.Encode({ v == nil and false or v }), 5381
  for i = 1, #s do h = (h * 33 + s:byte(i)) % 4294967296 end
  return h
end

-- Nothing, or an empty list: the same (a copy that went through Fellowship:Sanitize has empty lists where another
-- has none).
local function n(v)
  if v == nil or (type(v) == "table" and next(v) == nil) then return false end
  return v
end

---------------------------------------------------------------------------
-- Fingerprints
---------------------------------------------------------------------------
-- Each shared part's fingerprint: only what the changes themselves make (not the levels, classes and catching-up
-- marks each addon fills in from the states it hears).
function Cf:Parts(f)
  local members = {}
  for name, m in pairs(f.members) do members[name] = { m.role, m.second or "", m.away or "", m.friend and 1 or 0, m.joined or 0 } end
  return {
    ring = hash(n(f.ring)), leader = hash({ f.leader, f.lv or 0 }), members = hash(members), rules = hash(n(f.rules)),
    journey = hash(n(f.journey)), banner = hash({ f.name, f.color, f.emblem }),
    invites = hash({ n(f.invites), n(f.inviteFrom), n(f.inviteFriend) }),
    challenges = hash({ n(f.challenges), n(f.challengesOff), n(f.falls), n(f.broken), n(f.race) }),
    votes = hash(n(f.votes)), gatherings = hash(n(f.gatherings)), tourney = hash(n(f.tourney)), milestones = hash(n(f.ticks)),
  }
end

-- Who has cleared which dungeon (made from the kills and the changes), for the Adventurers in the fellowship.
function Cf:DungeonHash(f)
  local out = {}
  for key, who in pairs(f.runs or {}) do
    for name in pairs(who) do
      if f.members[name] then out[key] = out[key] or {}; out[key][name] = true end
    end
  end
  return hash(out)
end

-- The firsts (worked out from everyone's deeds), and the state counts they were worked out from.
function Cf:FirstsHash(f)
  local out = {}
  for _, x in ipairs(ns.Firsts:List(f)) do out[x.key] = { x.name, x.time } end
  return hash(out)
end
function Cf:SeqHash(f)
  local out = {}
  for name in pairs(f.members) do
    local h = f.heroes and f.heroes[name]
    out[name] = h and h.seq or 0
  end
  return hash(out)
end

-- What every state carries (Fellowship/Hero.lua).
-- (Made afresh for every state, once a minute: a kept one would hide a copy whose parts changed without a change,
-- the very fault this looks for; code review of 1.0.0.)
function Cf:Prints(f)
  return { ph = hash(self:Parts(f)), dp = self:DungeonHash(f), fs = self:FirstsHash(f), sh = self:SeqHash(f) }
end

-- The parts two copies differ in, in the order of PARTS.
function Cf:Diff(a, b)
  local pa, pb, out = self:Parts(a), self:Parts(b), {}
  for _, part in ipairs(self.PARTS) do
    if pa[part] ~= pb[part] then out[#out + 1] = part end
  end
  return out
end

-- What each copy says, for the parts that can be said in a word (the report names it: "here: Lea, theirs: Pata").
local function said(f, part)
  if part == "ring" then
    local r = f.ring
    if not r then return L.CONFLICT_NOBODY end
    return ns.Short(r.who) .. (r.state and (" (" .. r.state .. ")") or "")
  elseif part == "leader" then
    return ns.Short(f.leader)
  end
end

---------------------------------------------------------------------------
-- Finding them
---------------------------------------------------------------------------
-- With another Adventurer's state (STATE, HELLO, HI; after their state is stored): only when both copies have made
-- the same changes and the same core (Sync:Digest), else syncing is still under way. At most once a minute for each
-- Adventurer, and the same difference once in half an hour.
Cf.compared = ns.Sync.Limiter()
function Cf:Compare(sender, f, d)
  -- (The limit first: the fingerprint is the costly part, and every state of every Adventurer comes here.)
  if type(d) ~= "table" or not d.ph or tonumber(d.v) ~= f.v or not self.compared:Ready(sender) then return end
  if d.h ~= ns.Sync:Digest(f) then return end
  local mine = self:Prints(f)
  local kills = d.k == ns.Clears:Digest(f)
  local parts = d.ph ~= mine.ph
  local dungeons = not parts and kills and d.dp ~= nil and d.dp ~= mine.dp
  local firsts = not parts and d.sh == mine.sh and d.fs ~= nil and d.fs ~= mine.fs
  if not (parts or dungeons or firsts) then return end
  local key = table.concat({ f.v, tostring(d.ph), tostring(d.dp), tostring(d.fs), mine.ph, mine.dp, mine.fs }, ":")
  if not self.compared:Take(sender, key) then return end
  -- (Two changes crossing settle themselves: looked at again a few seconds later, with the same version.)
  C_Timer.After(ns.Sync.GRACE, function()
    local g = F:Get(f.id)
    if not g or not g.members[sender] or g.v ~= tonumber(d.v) or ns.Sync:Digest(g) ~= d.h then return end
    local now = self:Prints(g)
    if parts and now.ph ~= d.ph then
      -- The copy that loses takes the other; the parts are named then (Conflicts:Taking).
      if ns.Sync:Beats(ns.Sync:TheirKey(g, sender, d), ns.Sync:Key(g, ns.Me())) then ns.Sync:AskSnap(sender, g) end
    elseif dungeons and now.dp ~= d.dp and d.k == ns.Clears:Digest(g) then
      self:Found(g, "disagree", sender, { "dungeons" })
    elseif firsts and now.fs ~= d.fs and now.sh == d.sh then
      self:Found(g, "disagree", sender, { "firsts" })
    end
  end)
end

-- A copy about to replace ours (Sync's SNAP): the same version and the same changes seen, yet other content.
function Cf:Taking(mine, snap, sender)
  if mine.v ~= snap.v or ns.Serialize.Encode({ mine.seen or {} }) ~= ns.Serialize.Encode({ snap.seen or {} }) then return nil end
  local parts = self:Diff(mine, snap)
  if #parts == 0 then return nil end
  local details = {}
  for _, part in ipairs(parts) do
    local here, theirs = said(mine, part), said(snap, part)
    if here then details[part] = { here = here, theirs = theirs } end
  end
  return self:Found(mine, "disagree", sender, parts, details)
end

-- What cannot be in one copy (after every change: Fellowship:AfterChange). Returns the issues found.
function Cf:Issues(f)
  local out = {}
  if not f.members[f.leader] then out[#out + 1] = { part = "leader", who = f.leader } end
  for name in pairs(f.invites or {}) do
    if f.members[name] then out[#out + 1] = { part = "invited", who = name } end
  end
  for name, m in pairs(f.members) do
    if not F.ROLES[m.role] then out[#out + 1] = { part = "role", who = name } end
  end
  -- (The Ring passes on when its bearer goes: Challenges:PassRing. One that never passed went with a bearer who left
  -- before that existed: the Leader's addon passes it, Cf:Check.)
  local r = f.ring
  if r and not r.state and not f.members[r.who] and r.passes then out[#out + 1] = { part = "ring", who = r.who } end
  table.sort(out, function(a, b) if a.part ~= b.part then return a.part < b.part end return a.who < b.who end)
  return out
end

-- A Ring left with a bearer who went before it could pass on (an addon before 1.0): whose it is, or nil.
function Cf:LeftRing(f)
  local r = f and f.ring
  if r and not r.state and not r.passes and type(r.who) == "string" and not f.members[r.who] then return r.who end
end

function Cf:Check(f)
  if not f or f.disbanded or not f.members[ns.Me()] then return nil end
  -- The Leader's addon passes such a Ring on (op "ringpass"), once this change is done.
  if self:LeftRing(f) and f.leader == ns.Me() and not self.passing then
    self.passing = true
    C_Timer.After(1, function()
      Cf.passing = nil
      local g = F:Current()
      local who = Cf:LeftRing(g)
      if who and g.leader == ns.Me() then F:Do({ k = "ringpass", name = who }) end
    end)
  end
  local issues = self:Issues(f)
  if #issues == 0 then return nil end
  local parts, details = {}, {}
  for _, x in ipairs(issues) do
    local d = details[x.part]
    if not d then
      parts[#parts + 1] = x.part
      details[x.part] = { who = x.who, all = { x.who } }
    else
      d.all[#d.all + 1] = x.who
    end
  end
  return self:Found(f, "impossible", nil, parts, details)
end

---------------------------------------------------------------------------
-- Telling the player
---------------------------------------------------------------------------
-- Kept and shown, unless the same conflict was shown within AGAIN seconds. Returns the conflict when shown.
function Cf:Found(f, kind, with, parts, details)
  ns.db.conflictSeen = type(ns.db.conflictSeen) == "table" and ns.db.conflictSeen or {}
  local key = table.concat({ kind, f.id, with or "", table.concat(parts, ",") }, ":")
  local now = time()
  local last = tonumber(ns.db.conflictSeen[key])
  if last and now - last < self.AGAIN then return nil end
  for k, t in pairs(ns.db.conflictSeen) do if now - (tonumber(t) or 0) >= self.AGAIN then ns.db.conflictSeen[k] = nil end end
  ns.db.conflictSeen[key] = now
  local c = { t = now, kind = kind, with = with, parts = parts, details = details or {}, fid = f.id, name = f.name,
    v = f.v, ver = ns.VERSION, game = ns.Game() }
  ns.db.conflicts = type(ns.db.conflicts) == "table" and ns.db.conflicts or {}
  table.insert(ns.db.conflicts, 1, c)
  while #ns.db.conflicts > self.KEEP do table.remove(ns.db.conflicts) end
  ns:Print(L.CONFLICT_CHAT, true)
  ns.Combat:AfterCombat(function() if ns.ConflictWindow then ns.ConflictWindow:Open(c) end end)
  return c
end

-- Who an issue names: "Ghost", or "Ghost, Bob" when it names several.
function Cf.Who(d)
  if type(d) ~= "table" then return "?" end
  if type(d.all) == "table" and #d.all > 1 then
    local names = {}
    for i, who in ipairs(d.all) do names[i] = ns.Short(who) end
    return table.concat(names, ", ")
  end
  return ns.Short(d.who or "?")
end

-- A part's name in a sentence ("the One Ring").
function Cf.PartName(part) return L["CONFLICT_PART_" .. part:upper()] or part end

-- Each part's icon in the window's list (the check of 3 Nov 2026, 21:57: one line each, with an icon).
Cf.PART_ICON = { ring = "chal_ring", leader = "heroes", members = "heroes", role = "heroes", rules = "rules",
  votes = "rules", journey = "chapter", milestones = "chapter", banner = "manage", invites = "inbox", invited = "inbox",
  challenges = "hist_challenge", gatherings = "gatherings", tourney = "tourney", dungeons = "hist_run",
  firsts = "hist_first" }

-- What was found, a part at a time: { part, text } ("the One Ring", "the Ring-bearer Ghost is not in the fellowship").
function Cf:Names(c)
  local out = {}
  for _, part in ipairs(c.parts) do
    local d = c.details[part]
    local text = c.kind == "impossible" and (L["CONFLICT_ISSUE_" .. part:upper()] or part):format(self.Who(d))
      or self.PartName(part)
    out[#out + 1] = { part = part, text = text }
  end
  return out
end

-- The window's first line, before the list ("Your addon and Lea's still disagree after syncing, about:").
function Cf:Lead(c)
  if c.kind == "impossible" then return L.CONFLICT_IMPOSSIBLE_LEAD end
  return L.CONFLICT_DISAGREE_LEAD:format(ns.Short(c.with or "?"))
end

-- The window's list: { icon = a path of ns.ICONS, text = "The One Ring" }, one for each part.
function Cf:Items(c)
  local out = {}
  for _, x in ipairs(self:Names(c)) do
    out[#out + 1] = { icon = ns.ICONS[self.PART_ICON[x.part] or "manage"], text = x.text:sub(1, 1):upper() .. x.text:sub(2) }
  end
  return out
end

-- The whole sentence that says what was found (the chat and the tests).
function Cf:Says(c)
  local names = {}
  for _, x in ipairs(self:Names(c)) do names[#names + 1] = x.text end
  local list = table.concat(names, ", ")
  if c.kind == "impossible" then return L.CONFLICT_IMPOSSIBLE:format(list) end
  return L.CONFLICT_DISAGREE:format(ns.Short(c.with or "?"), list)
end

-- The report to copy: plain lines, the same in every language the addon may get.
function Cf:Report(c)
  local lines = {
    ("Journey Together Forever %s (%s)"):format(tostring(c.ver or "?"), tostring(c.game or "?")),
    ("Found: %s"):format(date("%Y-%m-%d %H:%M", c.t)),
    ("Kind: %s%s"):format(c.kind, c.with and (", with " .. ns.Short(c.with)) or ""),
    ("Fellowship: %s, version %s"):format(tostring(c.name or "?"), tostring(c.v or "?")),
  }
  for _, part in ipairs(c.parts) do
    local d, line = c.details[part], "- " .. part
    if d and d.here then line = line .. (" (here: %s, theirs: %s)"):format(d.here, tostring(d.theirs))
    elseif d and d.who then line = line .. (" (%s)"):format(self.Who(d)) end
    lines[#lines + 1] = line
  end
  return table.concat(lines, "\n")
end
