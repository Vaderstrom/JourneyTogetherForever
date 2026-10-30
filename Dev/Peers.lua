-- Pretend Companions with a copy of their own (27 Oct 2026). A plain pretend Hero (Dev/Debug.lua) only sends what a
-- debug command tells it; a peer keeps its own copy of the fellowship and answers the sync messages the way a second
-- addon would (Fellowship/Sync.lua, Hero.lua, Clears.lua): HELLO / HI, SNAPQ / SNAP, OP and KILLD / KILLS. So
-- /jtf selftest (area "sync") runs the paths that normally need two accounts with one: catching up after being
-- offline, changes made apart (both kept), a change missed while online, kills compared at login, a lost copy
-- restored, removed while away. A peer that is offline gets nothing. Answers come a moment later, as over the wire,
-- and everything goes through the serializer. Nothing is saved.
local _, ns = ...
local Pe = { list = {}, DELAY = 0 } -- answers on the next frame, as over the wire (never inside the sender's call)
ns.Peers = Pe

local F = ns.Fellowship

-- Through the serializer, as a real message would be.
local function wire(t) return (ns.Serialize.Decode(ns.Serialize.Encode(t))) end

-- A peer's own changes to its copy: no toasts on this client.
local function quietly(fn)
  local toast = ns.Toast
  ns.Toast = function() end
  local ok, res = pcall(fn)
  ns.Toast = toast
  if not ok then error(res, 0) end
  return res
end

local function send(p, tag, data)
  C_Timer.After(Pe.DELAY, function() ns.Comm:Inject(p.name, tag, data) end)
end

function Pe:Get(name) return name and self.list[ns.FullName(name)] or nil end

-- name gets a copy of fellowship f as it is now (as after a sync), online.
function Pe:Take(name, f)
  local full = ns.Dev:Fake(name)
  local p = { name = full, copy = F:Sanitize(wire(f)), online = true, ops = {} }
  self.list[full] = p
  return p
end

function Pe:Forget(name)
  if name then self.list[ns.FullName(name)] = nil else wipe(self.list) end
end

function Pe:SetOnline(name, on)
  local p = self:Get(name)
  if p then p.online = on and true or false end
end

-- What the peer sends about itself (a real addon counts its own states up).
local function state(p)
  local h = p.copy.heroes and p.copy.heroes[p.name] or {}
  p.seq = math.max(p.seq or 0, tonumber(h.seq) or 0) + 1
  return { level = p.level or h.level or UnitLevel("player"), xp = 100, xpMax = 1000, class = ns.Dev:PretendClass(p.name),
    t = time(), seq = p.seq }
end

-- The peer logs in: HELLO with its version, the fingerprints of its copy and its kills, and its counts.
function Pe:Hello(name, tag)
  local p = self:Get(name)
  if not p or not p.online then return end
  local c = p.copy
  local sq, gq = ns.Hero:Counts(c)
  send(p, tag or "HELLO", { fid = c.id, v = c.v, s = state(p), h = ns.Sync:Digest(c), k = ns.Clears:Digest(c), sq = sq, gq = gq })
end

-- The peer's level or XP changed: STATE (with its version, Sync:AskSoon).
function Pe:State(name, level)
  local p = self:Get(name)
  if not p or not p.online then return end
  p.level = level or p.level
  send(p, "STATE", { fid = p.copy.id, v = p.copy.v, s = state(p) })
end

-- The peer makes a change in its own copy and sends it (online). lost: it never arrives (a message lost in a fight).
function Pe:Change(name, op, lost)
  local p = self:Get(name)
  if not p then return false end
  local c, t = p.copy, time()
  if not quietly(function() return F:Apply(c, op, p.name, t) end) then return false end
  c.v = c.v + 1
  local n = (c.seen[p.name] or 0) + 1
  c.seen[p.name] = n
  p.ops[#p.ops + 1] = { n = n, op = op, t = t }
  if p.online and not lost then send(p, "OP", { fid = c.id, v = c.v, op = op, t = t, n = n }) end
  return true
end

-- A copy from this client: taken when it is not older (this client decided it wins), the peer's own changes it has
-- not seen made again on top and sent (as Sync:Replay). A copy without the peer: it was removed.
function Pe:TakeCopy(p, f)
  local snap = F:Sanitize(wire(f))
  local c = p.copy
  if not snap or snap.id ~= c.id or snap.v < c.v then return end
  snap.heroes = c.heroes
  quietly(function() ns.Clears:Merge(snap, c) end)
  p.copy = snap
  p.took = (p.took or 0) + 1
  if snap.disbanded or not snap.members[p.name] then p.gone = true return end
  for _, e in ipairs(p.ops) do
    if (snap.seen[p.name] or 0) < e.n and quietly(function() return F:Apply(snap, e.op, p.name, e.t) end) then
      snap.v = snap.v + 1
      snap.seen[p.name] = e.n
      send(p, "OP", { fid = snap.id, v = snap.v, op = e.op, t = e.t, n = e.n })
    end
  end
end

-- A change from this client: applied when it is the next version, else the peer asks for the copy (a gap).
function Pe:Op(p, d)
  local c, v = p.copy, tonumber(d.v) or 0
  local a, n = d.a or ns.Me(), tonumber(d.n)
  if n and (c.seen[a] or 0) >= n then return end
  if v == c.v + 1 then
    if quietly(function() return F:Apply(c, d.op, d.by or a, tonumber(d.t)) end) then
      c.v = v
      if n then c.seen[a] = math.max(c.seen[a] or 0, n) end
      if c.disbanded or not c.members[p.name] then p.gone = true end
    end
  elseif v > c.v + 1 then
    send(p, "SNAPQ", { fid = c.id, v = c.v })
  end
end

-- HELLO / HI from this client: answer a HELLO, compare versions and fingerprints like Hero.lua's hello().
function Pe:Hello2(p, d, answer)
  local c = p.copy
  if answer then self:Hello(p.name, "HI") end
  if d.k and d.k ~= ns.Clears:Digest(c) then send(p, "KILLD", { fid = c.id, d = ns.Clears:KeyDigests(c) }) end
  local v = tonumber(d.v) or 0
  if v > c.v then send(p, "SNAPQ", { fid = c.id, v = c.v })
  elseif v < c.v then send(p, "SNAP", { f = ns.Sync:Copy(c) })
  elseif d.h and d.h ~= ns.Sync:Digest(c) then
    local me = ns.Me()
    local winner = (p.name == c.leader or me == c.leader) and c.leader or (p.name < me and p.name or me)
    if winner == p.name then send(p, "SNAP", { f = ns.Sync:Copy(c) }) else send(p, "SNAPQ", { fid = c.id, v = c.v }) end
  end
end

-- Kills: the dungeons whose fingerprints differ, with their newest runs (as Clears.lua's KILLD handler).
function Pe:Kills(p, digests)
  local c, kills, keys = p.copy, {}, {}
  for key, digest in pairs(ns.Clears:KeyDigests(c)) do
    if digests[key] ~= digest then kills[key] = c.kills[key]; keys[key] = true end
  end
  if not next(kills) then return end
  local history = {}
  for _, e in ipairs(c.history) do if e.type == "run" and keys[e.key] then history[#history + 1] = e end end
  send(p, "KILLS", { fid = c.id, kills = kills, history = history })
end

-- Messages from this client to a peer (Dev:Intercept). Returns true when the name is a peer (handled or dropped).
function Pe:Handle(target, tag, data)
  local p = self.list[target]
  if not p then return false end
  p.got = p.got or {}
  if not p.online then return true end
  p.got[tag] = (p.got[tag] or 0) + 1
  if type(data) ~= "table" then return true end
  if tag == "SNAP" then self:TakeCopy(p, data.f) return true end
  if data.fid ~= p.copy.id then return true end
  if tag == "SNAPQ" then send(p, "SNAP", { f = ns.Sync:Copy(p.copy) })
  elseif tag == "OP" then self:Op(p, data)
  elseif tag == "HELLO" or tag == "HI" then self:Hello2(p, data, tag == "HELLO")
  elseif tag == "KILLD" and type(data.d) == "table" then self:Kills(p, data.d)
  elseif tag == "KILLS" and type(data.kills) == "table" then
    quietly(function() ns.Clears:Merge(p.copy, { kills = data.kills, history = data.history or {} }) end)
  end
  return true
end
