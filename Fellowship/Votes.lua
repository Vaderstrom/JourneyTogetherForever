-- Rule votes (SPEC §6): any Hero proposes a change to one rule (one open proposal per rule). Every Hero votes Yes or
-- No. It passes, and the rule changes by itself, as soon as more than half of the counted Heroes (away Heroes left
-- out) say Yes; it fails when that can no longer happen, or after 3 days. The leader can still change rules directly.
-- Ops: k = "vote", a = propose / ballot / pass. The Hero whose ballot makes the majority sends the pass; if that is
-- lost, the leader (or, with the leader offline, the proposer) sends it on the next check.
local _, ns = ...
local L = ns.L
local F, J, R = ns.Fellowship, ns.Journey, ns.Rules
local V = { OPEN_FOR = 3 * 86400, KEEP = 7 * 86400, TICK = 60 }
ns.Votes = V

local function all(f)
  if type(f.votes) ~= "table" then f.votes = {} end
  return f.votes
end

-- Yes and No among current members, the Yes votes needed (more than half of the counted Heroes), and who may still
-- vote (counted Heroes who have not). A Friend of the fellowship's ballot (cast before they became one) is left out.
-- aw: who is away by the rule as the pass's maker saw it (Fellowship.Claim).
function V:Counts(f, v, aw)
  local yes, no = 0, 0
  for name, b in pairs(v.ballots) do
    local m = f.members[name]
    if m and not m.friend then if b then yes = yes + 1 else no = no + 1 end end
  end
  local counted = J:Counted(f, aw)
  local left = 0
  for _, name in ipairs(counted) do if v.ballots[name] == nil then left = left + 1 end end
  return yes, no, math.floor(#counted / 2) + 1, left
end

-- "open", "passing" (the majority is there, the pass is on its way), "passed", "failed", or "done" (the rule
-- already has this value: the leader changed it).
function V:Status(f, v)
  if v.result == "passed" then return "passed" end
  if f.rules[v.key] == v.value then return "done" end
  local yes, _, need, left = self:Counts(f, v)
  if yes >= need then return "passing" end
  if time() > v.ends or yes + left < need then return "failed" end
  return "open"
end

-- Who was away by the rule for a change's maker (Fellowship.Claim), as a set.
local function awayFor(f, op)
  local aw = F.Claim(op, "aw", function() return J:AutoAway(f) end)
  return type(aw) == "table" and aw or {}
end

-- Open at time t (a change's own time), and still able to pass with who was away for the change's maker (aw):
-- the same on every copy (Votes:Apply).
local function openAt(f, key, t, aw)
  for _, v in pairs(all(f)) do
    if v.key == key and not v.result and t <= v.ends and f.rules[key] ~= v.value then
      local yes, _, need, left = V:Counts(f, v, aw)
      if yes >= need or yes + left >= need then return v end
    end
  end
  return nil
end

local function openFor(f, key)
  for _, v in pairs(all(f)) do
    if v.key == key then
      local st = V:Status(f, v)
      if st == "open" or st == "passing" then return v end
    end
  end
  return nil
end

-- Votes that ended more than KEEP before t are dropped when a new one is proposed (the op's time, so every copy drops
-- the same ones). The History keeps the lines.
function V:Prune(f, t)
  for id, v in pairs(all(f)) do
    if type(v) ~= "table" or (tonumber(v.closed or v.ends) or 0) + self.KEEP < t then f.votes[id] = nil end
  end
end

function V:Apply(f, op, by, t)
  local votes = all(f)
  if op.a == "propose" then
    self:Prune(f, t)
    local key, value, id = op.key, op.value, op.id
    if type(id) ~= "string" or votes[id] or R.DEFAULTS[key] == nil or not R.Valid(key, value) or f.rules[key] == value
      or openAt(f, key, t, awayFor(f, op)) then return false end
    votes[id] = { id = id, by = by, key = key, value = value, old = f.rules[key], t = t, ends = t + self.OPEN_FOR, ballots = { [by] = true } }
    F:Log(f, L.CHR_VOTE:format(ns.Short(by), R.Name(key), R.ValueText(key, value)), t, "vote", by)
  elseif op.a == "ballot" then
    -- (Until the vote ends, by the ballot's own time: every copy takes or refuses it the same.)
    local v = votes[op.id]
    if not v or v.result or t > v.ends then return false end
    v.ballots[by] = op.yes and true or false
  elseif op.a == "pass" then
    -- The majority as the pass's maker counted it (who was away for them, and the ballots they had), so every copy
    -- passes it the same and keeps the same tally: a ballot that reached one copy before the pass and another after
    -- it is in neither (code review of 0.13.0).
    local v = votes[op.id]
    if not v or v.result or f.rules[v.key] == v.value then return false end
    local bl = F.Claim(op, "bl", function()
      local copy = {}
      for name, b in pairs(v.ballots) do copy[name] = b end
      return copy
    end)
    local ballots = {}
    for name, b in pairs(type(bl) == "table" and bl or v.ballots) do
      if type(name) == "string" and type(b) == "boolean" then ballots[name] = b end
    end
    local yes, _, need = self:Counts(f, { ballots = ballots }, awayFor(f, op))
    if yes < need then return false end
    v.ballots = ballots
    local r = {}
    for k, val in pairs(f.rules) do r[k] = val end
    r[v.key] = v.value
    f.rules = R.Clean(r)
    v.result, v.closed = "passed", t
    F:Log(f, L.CHR_VOTE_PASSED:format(R.Name(v.key), R.ValueText(v.key, v.value)), t, "votepassed")
    ns:Toast(nil, L.V_PASSED, L.V_PASSED_TEXT:format(R.Name(v.key), R.ValueText(v.key, v.value)), "rules")
  else
    return false
  end
  return true
end

-- Sends the pass if the majority is there.
function V:Settle(id)
  local f = F:Current()
  local v = f and all(f)[id]
  if v and self:Status(f, v) == "passing" then F:Do({ k = "vote", a = "pass", id = id }) end
end

function V:Propose(key, value)
  local id = ns.Me() .. "-" .. key .. "-" .. time()
  if not F:Do({ k = "vote", a = "propose", id = id, key = key, value = value }) then return false end
  self:Settle(id) -- a fellowship of one (or two with the proposer as majority)
  return true
end

function V:Vote(id, yes)
  if not F:Do({ k = "vote", a = "ballot", id = id, yes = yes and true or false }) then return false end
  self:Settle(id)
  return true
end

-- Is a vote open for this rule? (One at a time.)
function V:OpenFor(f, key) return openFor(f, key) end

-- Votes to show: open ones first (soonest end first), then those decided in the last 7 days.
function V:List(f)
  local open, done = {}, {}
  for _, v in pairs(all(f)) do
    local st = self:Status(f, v)
    if st == "open" or st == "passing" then open[#open + 1] = v
    elseif time() - (v.closed or v.ends) < self.KEEP then done[#done + 1] = v end
  end
  table.sort(open, function(a, b) return a.ends < b.ends end)
  table.sort(done, function(a, b) return (a.closed or a.ends) > (b.closed or b.ends) end)
  for _, v in ipairs(done) do open[#open + 1] = v end
  return open
end

-- Open votes I have not voted on (for the inbox).
function V:Unvoted(f)
  local out, me = {}, ns.Me()
  for _, v in ipairs(self:List(f)) do
    if self:Status(f, v) == "open" and v.ballots[me] == nil then out[#out + 1] = v end
  end
  return out
end

-- A pass that got lost: the leader sends it, or the proposer when the leader is offline.
function V:Check()
  local f = F:Current()
  if not f then return end
  local me = ns.Me()
  for id, v in pairs(all(f)) do
    if self:Status(f, v) == "passing" then
      local leaderOn = ns.Hero:Online(f, f.leader)
      if me == f.leader or (not leaderOn and me == v.by) then self:Settle(id) end
    end
  end
end

ns:On("LOGIN", function() C_Timer.NewTicker(V.TICK, function() V:Check() end) end)
