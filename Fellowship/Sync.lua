-- Messages between Heroes about the fellowship (docs/ARCHITECTURE.md §2).
--   INV / INVX   invite / invite cancelled          ACC / DEC   answer to an invite
--   INVA         receipt: the invited player's addon has the invite
--   ACCOK / ACCX the inviter's addon took the Accept / the invite is no longer open
--   OP           one change, with the new version    SNAPQ / SNAP  ask for / send the whole fellowship
-- Invites work while both players are online: an invite that is not received at once (offline, no addon, busy in a
-- fight) is removed and the inviter is told; an Accept the inviter's addon does not take is reported to the player.
-- A change is applied when its version is exactly one more than ours. On a gap we ask the sender for the whole
-- fellowship; on a clash (two changes at once) we ask the leader, whose copy wins. At login, HELLO (Fellowship/Hero.lua)
-- compares versions with every Hero.
-- Nothing is lost when players are not online at the same time (27 Oct 2026): every change carries who made it (a,
-- the character whose addon made it) and that character's own count (n); a copy knows the highest count it has of
-- everyone (f.seen). Each addon keeps the changes it applied lately (ns.db.oplog, not sent). When it takes another
-- copy, the changes that copy has not seen are made again on top and passed on (Sync:Replay), checked against the
-- rights of whoever made them. Versions decide the order; no clock is compared.
local _, ns = ...
local L = ns.L
local F, P, Comm = ns.Fellowship, ns.Permissions, ns.Comm
local S = {}
ns.Sync = S

S.RECEIPT_WAIT = 6  -- seconds to wait for the invited player's receipt
S.ACCEPT_WAIT = 10  -- seconds to wait for the inviter's addon after Accept
S.EXPIRE = 86400    -- an invite not answered within a day is removed

-- The invites this client sent in this session: sent[name] = { at (GetTime), received (time) }.
S.sent = {}

S.LOG_MAX = 150 -- changes each addon keeps per fellowship, to make again on top of another copy

-- a: the character whose addon made the change (left out when it is this one); n: its count; by: whose rights it
-- uses when that is not a (another character taking a place, Fellowship:TakePlace).
function S:SendOp(f, recipients, op, t, a, n, by)
  local msg = { fid = f.id, v = f.v, op = op, t = t, n = n, a = a ~= ns.Self() and a or nil, by = by ~= a and by or nil }
  for _, name in ipairs(recipients) do Comm:Send(name, "OP", msg) end
end

local function oplog(fid)
  ns.db.oplog = ns.db.oplog or {}
  ns.db.oplog[fid] = ns.db.oplog[fid] or {}
  return ns.db.oplog[fid]
end

-- Records a change this copy now has. n nil: a new change made here by a (its next count). Returns n.
function S:Note(f, a, n, by, op, t)
  f.seen = f.seen or {}
  if not n then
    ns.db.opn = ns.db.opn or {}
    n = math.max(ns.db.opn[a] or 0, f.seen[a] or 0) + 1
    ns.db.opn[a] = n
  end
  f.seen[a] = math.max(f.seen[a] or 0, n)
  local l = oplog(f.id)
  l[#l + 1] = { a = a, n = n, by = by, op = op, t = t }
  while #l > self.LOG_MAX do table.remove(l, 1) end
  return n
end

-- The changes this addon has that the copy has not seen, oldest first.
function S:Missing(copy)
  local out, seen = {}, copy.seen or {}
  for _, e in ipairs(oplog(copy.id)) do
    if e.n and e.n > (seen[e.a] or 0) then out[#out + 1] = e end
  end
  return out
end

-- Makes them again on top of the copy just taken, each with the rights of whoever made it, and passes them on.
function S:Replay(f, list)
  local me, lost = ns.Self(), false
  for _, e in ipairs(list) do
    if (f.seen[e.a] or 0) < e.n then
      if F:Apply(f, e.op, e.by or e.a, e.t) then
        f.v = f.v + 1
        f.seen[e.a] = e.n
        local others = {}
        for name in pairs(f.members) do if name ~= me then others[#others + 1] = name end end
        self:SendOp(f, others, e.op, e.t, e.a, e.n, e.by or e.a)
      elseif e.a == me then
        lost = true
      end
    end
  end
  if lost then ns:Print(L.SYNC_LOST, true) end
  F:AfterChange(f)
end

-- The invited player's addon answers INVA (a receipt). Without one in RECEIPT_WAIT seconds the invite is removed.
function S:SendInvite(f, name)
  local s = { at = GetTime() }
  self.sent[name] = s
  Comm:Send(name, "INV", { fid = f.id, name = f.name, leader = f.leader, color = f.color, emblem = f.emblem,
    heroes = F:Count(f), faction = f.faction }, true)
  -- Only this invite: a newer one to the same player has its own wait.
  C_Timer.After(self.RECEIPT_WAIT, function()
    local cur = F:Current()
    if S.sent[name] == s and not s.received and cur and cur.invites[name] then S:DropInvite(cur, name, L.INVITE_NOANSWER, true) end
  end)
end

-- Removes an invite this client sent, and tells the inviter why. noAddon: the invite reached them but their addon did
-- not answer (M25): they may not have it yet, so the share window opens (in the open book; else the toast opens it).
function S:DropInvite(f, name, text, noAddon)
  self.sent[name] = nil
  if f.invites[name] and P.Can(f, ns.Me(), "uninvite", name) then F:Do({ k = "uninvite", name = name }) end
  ns:Print(text:format(ns.Short(name)), true)
  if noAddon and ns.Share then
    if ns.Window:IsOpen() and ns.Share:Open(name, true) then return end
    ns:Toast(nil, L.INVITE_NOT_RECEIVED, L.SHARE_NOANSWER:format(ns.Short(name)), function() ns.Share:Open(name, true) end)
    return
  end
  ns:Toast(nil, L.INVITE_NOT_RECEIVED, text:format(ns.Short(name)))
end

-- "received" (their addon has it) or "sending" (waiting for the receipt). Nil when someone else sent it.
function S:InviteStatus(name)
  local s = self.sent[name]
  if not s then return nil end
  return s.received and "received" or "sending"
end

-- Open invites that cannot work any more: the ones this character sent in an earlier session (the receiver could not
-- reach a logged-out inviter), and any older than a day. The receiver is told (INVX).
function S:Tidy()
  local f = F:Current()
  if not f then return end
  local me, now = ns.Me(), time()
  for name, t in pairs(f.invites) do
    -- (Each one this character may cancel: the leader any, an Adventurer their own.)
    if not P.Can(f, me, "uninvite", name) then t = nil end
    local mine = f.inviteFrom and f.inviteFrom[name] == me and not self.sent[name]
    if t and (mine or now - (tonumber(t) or 0) > self.EXPIRE) then
      if F:Do({ k = "uninvite", name = name }) then Comm:Send(name, "INVX", { fid = f.id }) end
    end
  end
end

-- The whole fellowship, without Hero states (those come from each Hero: HELLO, STATE, GEAR) or the moments kept
-- (Fellowship/Moments.lua), with only the newest SNAP_HISTORY History entries (the receiver keeps its own older
-- ones). Keeps it small: at one part a second a full History made a copy of about two minutes late in the journey
-- (measured 27 Oct 2026).
S.SNAP_HISTORY = 30
function S:Copy(f)
  local copy = {}
  for k, v in pairs(f) do if k ~= "heroes" and k ~= "history" and k ~= "moments" then copy[k] = v end end
  copy.history = {}
  for i = 1, math.min(#(f.history or {}), self.SNAP_HISTORY) do copy.history[i] = f.history[i] end
  return copy
end
function S:SendSnap(name, f)
  Comm:Send(name, "SNAP", { f = self:Copy(f) }, false, true)
end
function S:AskSnap(name, f) Comm:Send(name, "SNAPQ", { fid = f.id, v = f.v }, false, true) end

-- A short fingerprint of what every copy must agree on (not Hero states, runs or History, which each client adds
-- itself). HELLO carries it: two copies with the same version but different content (two changes at once while the
-- leader was offline) are noticed and the leader's copy wins.
function S:Digest(f)
  -- (seen: which changes the copy has, so two copies with different changes at the same version are noticed too.)
  local core = { f.name, f.color, f.emblem, f.leader, f.officers, f.rules, f.journey, f.disbanded or false, f.seen or {} }
  local members = {}
  for name, m in pairs(f.members) do members[name] = { m.role, m.second or "", m.away or "" } end
  core[#core + 1] = members
  local s, h = ns.Serialize.Encode(core), 5381
  for i = 1, #s do h = (h * 33 + s:byte(i)) % 4294967296 end
  return h
end

---------------------------------------------------------------------------
-- Receiving
---------------------------------------------------------------------------
Comm:On("INV", function(sender, d)
  if type(d) ~= "table" or type(d.fid) ~= "string" or type(d.name) ~= "string" then return end
  if d.faction ~= (UnitFactionGroup("player")) then return end
  -- The receipt: this addon has the invite (or is already in that fellowship).
  Comm:Send(sender, "INVA", { fid = d.fid }, true)
  local cur = F:Current()
  if cur and cur.id == d.fid then return end
  ns.char.invites[d.fid] = { from = sender, name = d.name, leader = d.leader, color = d.color, emblem = d.emblem,
    heroes = tonumber(d.heroes) or 1, time = time() }
  F:Changed()
end)

Comm:On("INVA", function(sender, d)
  local f = F:Current()
  if type(d) ~= "table" or not f or f.id ~= d.fid or not f.invites[sender] then return end
  local s = S.sent[sender] or {}
  s.received = time()
  S.sent[sender] = s
  ns:Fire("HEROES")
end)

-- A whisper to someone failed: they are offline (Core/Comm.lua). An invite to them is removed at once; an Accept
-- sent to an inviter who is offline is reported to the player.
ns:On("OFFLINE", function(name)
  local s, f = S.sent[name], F:Current()
  if s and not s.received and f and f.invites[name] then S:DropInvite(f, name, L.INVITE_OFFLINE) end
  for fid, p in pairs(F.pendingJoin) do
    if p.from == name and not p.ok then
      F.pendingJoin[fid] = nil
      ns:Toast(nil, L.ACCEPT_FAILED, L.ACCEPT_OFFLINE:format(ns.Short(name)))
    end
  end
end)

Comm:On("INVX", function(sender, d)
  local inv = type(d) == "table" and ns.char.invites[d.fid]
  if inv and (inv.from == sender or inv.leader == sender) then
    ns.char.invites[d.fid] = nil
    F:Changed()
  end
end)

Comm:On("ACC", function(sender, d)
  if type(d) ~= "table" then return end
  local f = F:Current()
  -- The invite is gone (cancelled, expired) or this Hero may no longer answer: tell the player.
  if not f or f.id ~= d.fid or not f.invites[sender] or not P.Can(f, ns.Me(), "answer") then
    Comm:Send(sender, "ACCX", { fid = d.fid }, true)
    return
  end
  if F:Do({ k = "join", name = sender, role = d.role, class = d.class, level = d.level, guild = d.guild, gm = d.gm }) then
    Comm:Send(sender, "ACCOK", { fid = f.id }, true)
    S:SendSnap(sender, f)
  end
end)

-- The inviter's addon took my Accept: the fellowship is on its way (SNAP).
Comm:On("ACCOK", function(sender, d)
  local p = type(d) == "table" and F.pendingJoin[d.fid]
  if p and p.from == sender then p.ok = true end
end)

Comm:On("ACCX", function(sender, d)
  local p = type(d) == "table" and F.pendingJoin[d.fid]
  if p and p.from == sender then
    F.pendingJoin[d.fid] = nil
    ns:Toast(nil, L.ACCEPT_FAILED, L.ACCEPT_CLOSED:format(ns.Short(sender)))
  end
end)

Comm:On("DEC", function(sender, d)
  local f = F:Current()
  if type(d) ~= "table" or not f or f.id ~= d.fid or not f.invites[sender] then return end
  if P.Can(f, ns.Me(), "uninvite", sender) then F:Do({ k = "uninvite", name = sender }) end
end)

Comm:On("OP", function(sender, d)
  if type(d) ~= "table" or type(d.op) ~= "table" then return end
  local f = F:Get(d.fid)
  if not f then S:Unknown(sender, d.fid) return end
  local op = d.op
  -- a made it (the sender, or a Companion whose change is passed on); by: whose rights it uses.
  local a = type(d.a) == "string" and d.a or sender
  local by = type(d.by) == "string" and d.by or a
  local n = tonumber(d.n)
  -- Another character on a Companion's account takes that Companion's place (Fellowship:TakePlace): made as that
  -- Companion, by a character their addon listed as theirs.
  if op.k == "swap" and op.from ~= nil then
    if by ~= op.from or not f.members[op.from] or (sender ~= op.from and not ns.Watch.IsAlt(f, op.from, op.name)) then return end
  end
  if not f.members[sender] and not (op.k == "swap" and op.name == sender and by == op.from) then return end
  -- Already here (passed on by someone else too): nothing to do.
  if n and f.seen and (f.seen[a] or 0) >= n then return end
  local v = tonumber(d.v) or 0
  if v == f.v + 1 then
    if F:Apply(f, op, by, d.t) then
      f.v = v
      if n then S:Note(f, a, n, by, op, d.t) end
      F:AfterChange(f)
    end
  elseif v > f.v + 1 then
    S:AskSnap(sender, f)
  elseif ns.Me() == f.leader then
    -- A clash: two changes at once. The leader applies it if allowed and sends everyone its copy.
    if F:Apply(f, op, by, d.t) then
      f.v = f.v + 1
      if n then S:Note(f, a, n, by, op, d.t) end
      for name in pairs(f.members) do if name ~= f.leader then S:SendSnap(name, f) end end
      F:AfterChange(f)
    end
  elseif f.leader ~= sender then
    S:AskSnap(f.leader, f)
  end
end)
Comm:On("SNAPQ", function(sender, d)
  if type(d) ~= "table" then return end
  local f = F:Get(d.fid)
  if f and f.members[ns.Me()] and f.v >= (tonumber(d.v) or 0) then S:SendSnap(sender, f) end
end)

Comm:On("SNAP", function(sender, d)
  local snap = type(d) == "table" and F:Sanitize(d.f)
  if not snap or not snap.members[sender] and snap.leader ~= sender then return end
  local me, mine = ns.Me(), F:Get(snap.id)
  -- The copy of a fellowship this addon lost (Sync:Unknown): restored at once when this character knew it was in it,
  -- else after a question.
  if not mine and S.asked[snap.id] and snap.members[me] and snap.members[sender] and not F:Current() and not snap.disbanded then
    S.asked[snap.id] = nil
    if ns.char.fellowshipId == snap.id then return S:Restore(snap) end
    S.restore = { f = snap, from = sender }
    ns:Toast(nil, L.RESTORE_FOUND_T, L.RESTORE_FOUND:format(snap.name))
    ns:Print(L.RESTORE_FOUND:format(snap.name), true)
    if ns.Window and ns.Window:IsOpen() then S:OfferRestore() end
    return
  end
  local joining = F.pendingJoin[snap.id] ~= nil and snap.members[me] ~= nil
  -- At the same version with other content (Digest) the leader's copy wins, else the one whose name sorts first.
  local newer = mine and (mine.members[sender] or mine.leader == sender)
    and (snap.v > mine.v or (snap.v == mine.v and (sender == mine.leader or (me ~= mine.leader and sender < me))))
  if not joining and not newer then return end
  S:KeepLocal(snap, mine)
  -- Our changes the copy has not seen are made again on top of it (nothing made while apart is lost). Not when the
  -- copy no longer lists us (we were removed while away), and not when joining: changes kept from an earlier time in
  -- this fellowship (our own "leave" among them) belong to that time, and are forgotten.
  local missing = mine and snap.members[me] and not joining and S:Missing(snap) or {}
  if joining and ns.db.oplog then ns.db.oplog[snap.id] = nil end
  ns.db.fellowships[snap.id] = snap
  if joining then
    F.pendingJoin[snap.id] = nil
    ns.char.fellowshipId = snap.id
    wipe(ns.char.invites)
    ns:Toast(nil, L.WELCOME_TOAST, L.WELCOME_TOAST_TEXT:format(snap.name), "overview")
  end
  F:AfterChange(snap)
  if joining then ns:Fire("JOINED") end
  if #missing > 0 then S:Replay(snap, missing) end
end)

-- What a copy taken from another addon does not carry, kept from ours (mine: our copy, or nil). Also for a copy
-- watched from another character (Fellowship/Watch.lua): it dropped this account's Moments (code review, 30 Oct 2026).
function S:KeepLocal(snap, mine)
  -- Hero states are not in a copy: keep what we heard ourselves, for the Heroes still in the fellowship.
  snap.heroes = {}
  if mine and mine.heroes then
    for name, h in pairs(mine.heroes) do if snap.members[name] then snap.heroes[name] = h end end
  end
  -- The moments kept are each addon's own (Fellowship/Moments.lua): kept, never sent.
  snap.moments = mine and mine.moments or nil
  if not mine then return end
  -- Run reports are not versioned: keep the ones we heard of (Fellowship/Clears.lua).
  ns.Clears:Merge(snap, mine)
  -- The furthest chapter reached is not lowered by a copy that knew fewer levels, only by a newer reopen (J:Reopen).
  if (snap.reopenV or 0) <= (mine.reopenV or 0) then
    snap.reached = math.max(snap.reached or 1, mine.reached or 1)
    snap.reopenV = mine.reopenV
  end
end

---------------------------------------------------------------------------
-- Changes missed while online (a message lost during a boss fight): a STATE with a newer version asks for the copy,
-- at most once a minute per fellowship.
---------------------------------------------------------------------------
S.askedAt = {}
function S:AskSoon(sender, f)
  local last = self.askedAt[f.id]
  if last and GetTime() - last < 60 then return end
  self.askedAt[f.id] = GetTime()
  self:AskSnap(sender, f)
end

-- Removed (or the fellowship disbanded) while away: the HELLO of someone no longer in our copy, from an older copy,
-- gets ours once, so their addon sees it and says so (Fellowship:AfterChange).
S.told = {}
function S:NotMember(sender, d)
  local f = type(d) == "table" and F:Get(d.fid)
  if not f or f.members[sender] or not f.members[ns.Me()] or (tonumber(d.v) or 0) >= f.v then return end
  local key = sender .. "|" .. f.id
  if self.told[key] then return end
  self.told[key] = true
  self:SendSnap(sender, f)
end

---------------------------------------------------------------------------
-- Lost saved data (a new PC, a reinstall, a wiped WTF folder): the others still have this character as a member and
-- keep sending to it. A message about a fellowship this addon does not know, while this character is in none, asks
-- the sender for the copy; the copy is taken when it lists this character (27 Oct 2026).
---------------------------------------------------------------------------
S.asked = {}

function S:Unknown(sender, fid)
  if type(fid) ~= "string" or F:Get(fid) or F:Current() or self.asked[fid] or self.restore then return end
  self.asked[fid] = true
  Comm:Send(sender, "SNAPQ", { fid = fid, v = 0 }, false, true)
end

function S:Restore(snap)
  self.restore = nil
  snap.heroes = snap.heroes or {}
  ns.db.fellowships[snap.id] = snap
  ns.char.fellowshipId = snap.id
  F:AfterChange(snap)
  ns:Toast(nil, L.RESTORE_DONE_T, L.RESTORE_DONE:format(snap.name))
  ns:Fire("JOINED")
  ns.Hero:Hello()
  if ns.Window and ns.Window:IsOpen() then ns.Window:ShowPage("overview") end
  return true
end

-- The question, in the book: "Lea says you are in Band. Restore it?"
function S:OfferRestore()
  local r = self.restore
  if not r or F:Current() then return end
  ns.Window:Confirm(L.RESTORE_Q:format(ns.Short(r.from), r.f.name), L.RESTORE_OK, function() S:Restore(r.f) end)
end

ns:On("LOGIN", function()
  C_Timer.After(6, function() S:Tidy() end)
  C_Timer.NewTicker(3600, function() S:Tidy() end)
end)
