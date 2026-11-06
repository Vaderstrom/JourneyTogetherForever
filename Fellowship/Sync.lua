-- Messages between Heroes about the fellowship (docs/ARCHITECTURE.md §2).
--   INV / INVX   invite / invite cancelled          ACC / DEC   answer to an invite
--   INVA         receipt: the invited player's addon has the invite
--   ACCOK / ACCX the inviter's addon took the Accept / the invite is no longer open
--   OP           one change, with the new version    SNAPQ / SNAP  ask for / send the whole fellowship
--   SNAPM        the rest of a new Adventurer's copy (Chronicle, History; U60)
-- Invites wait up to a day (the owner, 3 Nov 2026): an invite to someone offline stays open, and one online
-- Adventurer's addon (the courier: the Leader when online, else the first by name) sends it again every few minutes
-- until their addon has it (Sync:Deliver). The invite lists who may take the answer (who), so Accept reaches whoever of
-- them is online, not only the inviter. An invite that reaches a player whose addon does not answer (no addon, busy in
-- a fight) is removed and the inviter is told.
-- A change is applied when its version is exactly one more than ours. On a gap we ask the sender for the whole
-- fellowship; on a clash (two changes at once) the leader puts it on top and sends everyone its copy, and two
-- Adventurers swap copies. At login (HELLO) and with every state after it (STATE, Fellowship/Hero.lua), versions and
-- a fingerprint (Sync:Digest) are compared; when two copies differ, both pick the same one to go on from (Sync:Beats).
-- Nothing is lost when players are not online at the same time (27 Oct 2026): every change carries who made it (a,
-- the character whose addon made it) and that character's own count (n); a copy knows the highest count it has of
-- everyone (f.seen). Each addon keeps the changes it applied lately (ns.db.oplog, not sent). When it takes another
-- copy, the changes that copy has not seen are made again on top and passed on (Sync:Replay), checked against the
-- rights whoever made them had then (r: "leader" when they led; Fellowship:Apply). Versions decide the order.
local _, ns = ...
local L = ns.L
local F, P, Comm = ns.Fellowship, ns.Permissions, ns.Comm
local S = {}
ns.Sync = S

S.RECEIPT_WAIT = 6  -- seconds to wait for the invited player's receipt
S.ACCEPT_WAIT = 10  -- seconds to wait for each Adventurer's addon after Accept
S.EXPIRE = 86400    -- an invite not answered within a day is removed
S.DEC_WAIT = 15     -- a decline: how long each Adventurer after the first in turn waits before removing the invite
S.DELIVER_EVERY = 300 -- seconds between the courier's tries to deliver an open invite
S.WHO_MAX = 8       -- Adventurers an invite names to take the answer

-- The invites this client sent in this session: sent[name] = { at (GetTime), received (time), offline, again }.
S.sent = {}

S.LOG_MAX = 150 -- changes each addon keeps per fellowship, to make again on top of another copy
-- After a change goes out, this addon's state (its version and fingerprint) follows within STATE_AFTER seconds, so a
-- copy that lost the change on the way notices it at once and asks for the copy (the soak test of 6 Nov 2026: a lost
-- change was otherwise found only at the next heartbeat, five minutes later).
S.STATE_AFTER = 10

-- a: the character whose addon made the change (left out when it is this one); n: its count; by: whose rights it
-- uses when that is not a (another character taking a place, Fellowship:TakePlace); r: "leader" when by led then.
function S:SendOp(f, recipients, op, t, a, n, by, r)
  local msg = { fid = f.id, v = f.v, op = op, t = t, n = n, a = a ~= ns.Self() and a or nil, by = by ~= a and by or nil, r = r }
  for _, name in ipairs(recipients) do Comm:Send(name, "OP", msg) end
  if #recipients > 0 and ns.Hero then ns.Hero:Soon("state", self.STATE_AFTER, function() ns.Hero:SendState() end) end
end

local function oplog(fid)
  ns.db.oplog = ns.db.oplog or {}
  ns.db.oplog[fid] = ns.db.oplog[fid] or {}
  return ns.db.oplog[fid]
end

-- Records a change this copy now has. n nil: a new change made here by a (its next count). Returns n.
function S:Note(f, a, n, by, op, t, r)
  f.seen = f.seen or {}
  if not n then
    ns.db.opn = ns.db.opn or {}
    n = math.max(ns.db.opn[a] or 0, f.seen[a] or 0) + 1
    ns.db.opn[a] = n
  end
  f.seen[a] = math.max(f.seen[a] or 0, n)
  local l = oplog(f.id)
  l[#l + 1] = { a = a, n = n, by = by, op = op, t = t, r = r }
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
      if F:Apply(f, e.op, e.by or e.a, e.t, e.r) then
        f.v = f.v + 1
        f.seen[e.a] = e.n
        self:SendOp(f, ns.Others(f), e.op, e.t, e.a, e.n, e.by or e.a, e.r)
      elseif e.a == me then
        lost = true
      end
    end
  end
  if lost then ns:Print(L.SYNC_LOST, true) end
  F:AfterChange(f)
end

-- Who may take the answer to an invite to name: the Leader, the inviter, this character, then the others heard from
-- most lately (an Accept tries them in turn until one is online).
function S:Answerers(f, name)
  local out, seen = {}, { [name] = true }
  local function add(n)
    if n and f.members[n] and not seen[n] and #out < self.WHO_MAX and P.Can(f, n, "answer") then seen[n] = true; out[#out + 1] = n end
  end
  add(f.leader); add(f.inviteFrom and f.inviteFrom[name]); add(ns.Me())
  local rest = {}
  for n in pairs(f.members) do if not seen[n] then rest[#rest + 1] = n end end
  table.sort(rest, function(a, b)
    local x, y = ns.Hero:LastSeen(f, a), ns.Hero:LastSeen(f, b)
    if x ~= y then return x > y end
    return a < b
  end)
  for _, n in ipairs(rest) do add(n) end
  return out
end

-- The invited player's addon answers INVA (a receipt). The first time: without one in RECEIPT_WAIT seconds (online
-- without the addon, or in a fight) the invite is removed; offline, it waits for the courier (Sync:Deliver). again:
-- the courier's try, which only the day's limit ends.
function S:SendInvite(f, name, again)
  local s = { at = GetTime(), again = again or nil }
  self.sent[name] = s
  Comm:Send(name, "INV", { fid = f.id, name = f.name, leader = f.leader, color = f.color, emblem = f.emblem,
    heroes = F:Count(f), faction = f.faction, friend = f.inviteFriend and f.inviteFriend[name] or nil,
    oneclass = f.challenges and f.challenges.oneclass, nohealers = f.challenges and f.challenges.nohealers,
    t = tonumber(f.invites[name]), who = self:Answerers(f, name) }, true)
  if again then return end
  -- Only this invite: a newer one to the same player has its own wait.
  C_Timer.After(self.RECEIPT_WAIT, function()
    local cur = F:Current()
    if S.sent[name] == s and not s.received and not s.offline and cur and cur.invites[name] then
      S:DropInvite(cur, name, S:NoAnswerText(), true)
    end
  end)
end

-- The one addon that delivers open invites, so they are not sent twice: the Leader when online, else the online
-- Adventurer first by name (every addon works it out from who it hears).
function S:Courier(f)
  if ns.Hero:Online(f, f.leader) then return f.leader end
  local best
  for name in pairs(f.members) do
    if ns.Hero:Online(f, name) and (not best or name < best) then best = name end
  end
  return best
end

-- The courier's round (every DELIVER_EVERY seconds): each open invite this addon has not seen received is sent again.
-- A whisper to someone still offline fails quietly (Core/Comm.lua hides the game's line).
function S:Deliver()
  local f = F:Current()
  if not f or self:Courier(f) ~= ns.Me() or Comm:Held() then return 0 end
  local n, now, clock = 0, time(), GetTime()
  for name, t in pairs(f.invites) do
    local s = self.sent[name]
    local fresh = now - (tonumber(t) or 0) <= self.EXPIRE
    if fresh and not (s and (s.received or clock - s.at < self.DELIVER_EVERY - 5)) then
      self:SendInvite(f, name, true)
      n = n + 1
    end
  end
  return n
end

-- Removes an invite this client sent, and tells the inviter why. noAddon: the invite reached them but their addon did
-- not answer (M25): they may not have it yet, so the share window opens (in the open book; else the toast opens it).
-- No answer to an invite: the usual causes (a player on CurseForge, 6 Nov 2026, read it as "no addon" only). In
-- WoW Forever also the full "First Surname" and the ruleset: addon messages do not cross rulesets.
function S:NoAnswerText()
  return ns.IsForever() and L.INVITE_NOANSWER_FOREVER or L.INVITE_NOANSWER
end

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

-- "received" (their addon has it), "offline" (it waits until they are online) or "sending" (waiting for the
-- receipt). Nil when this addon has not sent it.
function S:InviteStatus(name)
  local s = self.sent[name]
  if not s then return nil end
  return s.received and "received" or (s.offline and "offline") or "sending"
end

-- How long the open invite to name still waits before it is removed (S:Tidy), in seconds; nil when none.
function S:InviteLeft(f, name)
  local t = f and f.invites and tonumber(f.invites[name])
  return t and math.max(0, self.EXPIRE - (time() - t)) or nil
end

-- "offline: it reaches them when they log in  ·  23 hours left" (Manage, the Adventurers page).
function S:OfflineText(f, name)
  local left = self:InviteLeft(f, name)
  return left and (L.INV_OFFLINE .. "  ·  " .. L.INV_LEFT:format(ns.TimeLeft(left))) or L.INV_OFFLINE
end

-- Open invites older than a day are removed, and the receiver is told (INVX).
function S:Tidy()
  local f = F:Current()
  if not f then return end
  local me, now = ns.Me(), time()
  for name, t in pairs(f.invites) do
    -- (Each one this character may cancel: the leader any, an Adventurer their own.)
    if not P.Can(f, me, "uninvite", name) then t = nil end
    if t and now - (tonumber(t) or 0) > self.EXPIRE then
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
-- first: the copy a new Adventurer waits for (U60, 6 Nov 2026). It goes first, without the Chronicle and History
-- (most of a copy late in the journey; neither is compared between copies), which follow in SNAPM. An older addon
-- (no lanes, Core/Comm.lua) has no SNAPM: it gets the whole copy.
function S:SendSnap(name, f, first)
  local copy = self:Copy(f)
  if not (first and (Comm.peers[name] or 1) >= Comm.LANES) then
    Comm:Send(name, "SNAP", { f = copy }, first, true)
    return
  end
  local more = { fid = f.id, chronicle = copy.chronicle, history = copy.history }
  copy.chronicle, copy.history, copy.more = nil, nil, true
  Comm:Send(name, "SNAP", { f = copy }, true, true)
  Comm:Send(name, "SNAPM", more, false, true)
end
function S:AskSnap(name, f) Comm:Send(name, "SNAPQ", { fid = f.id, v = f.v }, false, true) end

-- Which of two copies the fellowship goes on from: the same answer on both sides, whoever asks (2 Nov 2026).
-- A key is { v, lv, leader, holder }: the newer version; then the newer leadership (a takeover or a handover the other
-- copy has not seen: its count, f.lv); then the leader whose name sorts first (two leadership changes at once); then
-- the copy the leader holds; then the holder whose name sorts first. Each side compares its own copy with the other's.
-- A copy from an addon before 0.13 has no lv (nil): that addon takes another copy at the same version only from its
-- leader, so the newer addon's copy wins only when its holder is that leader, and otherwise takes the older addon's
-- copy (and makes its own changes again on top). Never both sides refusing (code review of 0.13.0).
function S:Key(f, holder) return { v = f.v, lv = f.lv or 0, leader = f.leader, holder = holder } end
function S:Beats(a, b)
  if a.v ~= b.v then return a.v > b.v end
  if (a.lv == nil) ~= (b.lv == nil) then
    local old, new = a.lv == nil and a or b, a.lv == nil and b or a
    return (new.holder == old.leader) == (a == new)
  end
  if a.lv ~= b.lv then return a.lv > b.lv end
  if a.leader ~= b.leader then return a.leader < b.leader end
  local al, bl = a.holder == a.leader, b.holder == b.leader
  if al ~= bl then return al end
  return a.holder < b.holder
end
-- The other copy's key from what its addon sent (v, lv, ld); an older addon sends no lv (nil, above) or ld (our
-- leader stands in).
function S:TheirKey(f, sender, d)
  return { v = tonumber(d.v) or 0, lv = tonumber(d.lv), leader = type(d.ld) == "string" and d.ld or f.leader, holder = sender }
end

-- Compares our copy with another Adventurer's (HELLO, HI and STATE carry v, lv, ld and the fingerprint h): the
-- one behind gets the other copy; at the same version with other content, both sides pick the same copy (Beats),
-- and the other one takes it and makes its own missing changes again on top (Replay).
function S:Compare(sender, f, d)
  local v = tonumber(d.v) or 0
  if v > f.v then self:AskSnap(sender, f)
  elseif v < f.v then self:SendSnap(sender, f)
  elseif d.h and d.h ~= self:Digest(f) then
    if self:Beats(self:TheirKey(f, sender, d), self:Key(f, ns.Me())) then self:AskSnap(sender, f) else self:SendSnap(sender, f) end
  end
end

-- The same with every state while both are online (a change lost on the way, two at once): at most once a minute
-- for each Adventurer, and the same difference only once in half an hour (a copy that cannot be made the same must
-- not send itself every minute). Behind them: ask for their copy. Ahead: nothing (their addon asks when it hears our
-- state; pushing ours sent whole copies for a change still on its way). The same version with other content: GRACE
-- seconds later, if it still differs (two changes crossing settle themselves).
S.GRACE = 5
S.swappedAt, S.SWAP_EVERY = {}, 30

-- The limit both comparisons while online use (this one and Clears:CompareSoon): at most once EVERY seconds for each
-- Adventurer, and the same difference (key) only once in SAME seconds. Ready is checked before the fingerprints are
-- made (they cost the most), Take once the difference is known.
-- (SAME was 30 minutes while a copy was slow and costly; packed and without the per-prefix wait, a failed swap is
-- tried again after 2 minutes: the owner, 6 Nov 2026, "syncing always consolidates".)
local Limiter = { EVERY = 60, SAME = 120 }
Limiter.__index = Limiter
function S.Limiter() return setmetatable({ at = {}, last = {} }, Limiter) end
function Limiter:Ready(who) return not self.at[who] or GetTime() - self.at[who] >= self.EVERY end
function Limiter:Take(who, key)
  local now, last = GetTime(), self.last[who]
  if last and last.key == key and now - last.at < self.SAME then return false end
  self.at[who], self.last[who] = now, { key = key, at = now }
  return true
end
function Limiter:Reset(who) self.at[who], self.last[who] = nil, nil end

S.compared = S.Limiter()
function S:CompareSoon(sender, f, d)
  -- (Compared with them lately: not dropped but done when the limit allows, with the newest state heard.)
  if not self.compared:Ready(sender) then
    self.later = self.later or {}
    local first = self.later[sender] == nil
    self.later[sender] = { fid = f.id, d = d }
    if first then
      C_Timer.After(self.compared.EVERY - (GetTime() - (self.compared.at[sender] or GetTime())) + 1, function()
        local w = S.later and S.later[sender]
        if S.later then S.later[sender] = nil end
        local g = w and F:Get(w.fid)
        if g and g.members[sender] then S:CompareSoon(sender, g, w.d) end
      end)
    end
    return
  end
  local v, mine = tonumber(d.v) or 0, self:Digest(f)
  if v < f.v or (v == f.v and (not d.h or d.h == mine)) then return end
  if not self.compared:Take(sender, f.v .. ":" .. v .. ":" .. tostring(d.h) .. ":" .. mine) then return end
  if v > f.v then self:AskSnap(sender, f) return end
  C_Timer.After(self.GRACE, function()
    local g = F:Get(f.id)
    if g and g.members[sender] and g.v == v and d.h ~= self:Digest(g) then self:Compare(sender, g, d) end
  end)
end

-- A short fingerprint of what every copy must agree on (not Hero states, runs or History, which each client adds
-- itself). HELLO carries it: two copies with the same version but different content (two changes at once while the
-- leader was offline) are noticed and the leader's copy wins.
function S:Digest(f)
  -- (seen: which changes the copy has, so two copies with different changes at the same version are noticed too.)
  local core = { f.name, f.color, f.emblem, f.leader, f.officers, f.rules, f.journey, f.disbanded or false, f.seen or {} }
  local members = {}
  -- (A Friend of the fellowship adds a mark only then, so copies without any Friends agree with older versions.)
  for name, m in pairs(f.members) do members[name] = { m.role, m.second or "", m.away or "", m.friend and 1 or nil } end
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
  -- Declined already (the courier did not hear it yet): said again, and not shown again.
  local no = type(ns.char.declined) == "table" and tonumber(ns.char.declined[d.fid])
  -- (An older addon sends no t and never tries again: its invite is a new one.)
  if no and tonumber(d.t) and tonumber(d.t) <= no then Comm:Send(sender, "DEC", { fid = d.fid }) return end
  local cur = F:Current()
  if cur and cur.id == d.fid then return end
  -- Who may take the answer (an older addon sends none: only the sender).
  local who = {}
  for _, n in ipairs(type(d.who) == "table" and d.who or {}) do
    if type(n) == "string" and #n <= 64 and #who < S.WHO_MAX then who[#who + 1] = n end
  end
  -- The same invite again (the courier's try) keeps its day: from when it was made, never later than now. A new
  -- invite (made later, after the old one was cancelled) has its own day (code review of 1.0.0).
  local old, now = ns.char.invites[d.fid], time()
  local made = math.min(tonumber(d.t) or now, now)
  ns.char.invites[d.fid] = { from = sender, name = d.name, leader = d.leader, color = d.color, emblem = d.emblem,
    heroes = tonumber(d.heroes) or 1, time = (not tonumber(d.t) and old and old.time) or made, friend = d.friend == true or nil,
    oneclass = type(d.oneclass) == "string" and d.oneclass:match("^%u+$") and #d.oneclass <= 16 and d.oneclass or nil,
    nohealers = d.nohealers == true or nil, who = who }
  if not old then F:Changed() end
end)

Comm:On("INVA", function(sender, d)
  local f = F:Current()
  if type(d) ~= "table" or not f or f.id ~= d.fid or not f.invites[sender] then return end
  local s = S.sent[sender] or {}
  s.received = time()
  S.sent[sender] = s
  ns:Fire("HEROES")
end)

-- A whisper to someone failed: they are offline (Core/Comm.lua). An invite to them waits (the inviter is told once);
-- an Accept goes on to the next Adventurer who may take it.
ns:On("OFFLINE", function(name)
  local s, f = S.sent[name], F:Current()
  if s and not s.received and not s.offline and f and f.invites[name] then
    s.offline = true
    if not s.again then
      ns:Print(L.INVITE_OFFLINE:format(ns.Short(name)), true)
      ns:Toast(nil, L.INVITE_WAITING_T, L.INVITE_OFFLINE:format(ns.Short(name)))
    end
    ns:Fire("HEROES")
  end
  for fid, p in pairs(F.pendingJoin) do
    if p.from == name and not p.ok then F:AcceptNext(fid) end
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
  -- One class only, No healers (an older addon on their side did not check): they are told why.
  local ok, _, no = ns.Challenges:Allows(f, d.class, d.role, nil, f.inviteFriend and f.inviteFriend[sender])
  if not ok then
    Comm:Send(sender, "ACCX", { fid = d.fid, no = no, class = f.challenges.oneclass }, true)
    return
  end
  if F:Do({ k = "join", name = sender, role = d.role, class = d.class, level = d.level, guild = d.guild, gm = d.gm }) then
    Comm:Send(sender, "ACCOK", { fid = f.id }, true)
    S:SendSnap(sender, f, true)
  end
end)

-- The inviter's addon took my Accept: the fellowship is on its way (SNAP).
Comm:On("ACCOK", function(sender, d)
  local p = type(d) == "table" and F.pendingJoin[d.fid]
  if p and p.from == sender then p.ok = true; ns.char.invites[d.fid] = nil end
end)

Comm:On("ACCX", function(sender, d)
  local p = type(d) == "table" and F.pendingJoin[d.fid]
  if p and p.from == sender then
    -- Not open in their copy (cancelled, or they have not heard of it yet): the next Adventurer in turn, while there is
    -- one (F:AcceptNext tells the player when every one said so). A challenge's refusal is final.
    -- Only the inviter's word closes it: another Adventurer's copy may not have the invite yet, and when the rest are
    -- offline the invite stays open to try later (code review of 1.0.0).
    if not d.no then
      if sender == p.list[1] then p.closed = sender end
      F:AcceptNext(d.fid)
      return
    end
    F.pendingJoin[d.fid] = nil
    ns.char.invites[d.fid] = nil
    F:Changed()
    local text = L.ACCEPT_CLOSED:format(ns.Short(sender))
    if d.no == "nohealers" then text = L.CHAL_NOHEALERS_NO
    elseif d.no == "oneclass" and type(d.class) == "string" then text = L.CHAL_ONECLASS_NO:format(ns.Challenges.ClassName(d.class)) end
    ns:Toast(nil, L.ACCEPT_FAILED, text)
  end
end)

Comm:On("DEC", function(sender, d)
  local f = F:Current()
  if type(d) ~= "table" or not f or f.id ~= d.fid or not f.invites[sender] then return end
  -- (Any Adventurer who may take the answer removes it: the player said no. The first in turn at once, the next ones
  -- after DEC_WAIT seconds each, if nobody before them has; an older addon sends no turn: at once.)
  local function take()
    local g = F:Current()
    if g and g.id == d.fid and g.invites[sender] then F:Do({ k = "uninvite", name = sender, declined = true }) end
  end
  local i = math.floor(tonumber(d.i) or 1)
  if i <= 1 then take() else C_Timer.After(math.min(i - 1, 5) * S.DEC_WAIT, take) end
end)

Comm:On("OP", function(sender, d)
  if type(d) ~= "table" or type(d.op) ~= "table" then return end
  local f = F:Get(d.fid)
  if not f then S:Unknown(sender, d.fid) return end
  local op = d.op
  -- a made it (the sender, or a Companion whose change is passed on); by: whose rights it uses; r: their rank then.
  local a = type(d.a) == "string" and d.a or sender
  local by = type(d.by) == "string" and d.by or a
  local r = d.r == "leader" and "leader" or nil
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
    if F:Apply(f, op, by, d.t, r) then
      f.v = v
      if n then S:Note(f, a, n, by, op, d.t, r) end
      F:AfterChange(f)
    end
  elseif v > f.v + 1 then
    S:AskSnap(sender, f)
  elseif ns.Me() == f.leader then
    -- A clash: two changes at once. The leader applies it if allowed and sends everyone its copy.
    if F:Apply(f, op, by, d.t, r) then
      f.v = f.v + 1
      if n then S:Note(f, a, n, by, op, d.t, r) end
      for name in pairs(f.members) do if name ~= f.leader then S:SendSnap(name, f) end end
      F:AfterChange(f)
    end
  elseif f.leader ~= sender and ns.Hero:Online(f, f.leader) then
    -- A clash with the leader online: the leader's copy, with both changes, comes to everyone.
    S:AskSnap(f.leader, f)
  else
    -- A clash with the leader offline (or from the leader, on another copy): the two swap copies at once, and the
    -- one that Beats is taken by the other (2 Nov 2026: they waited for the leader, who might not come for days).
    -- Once in SWAP_EVERY seconds with each Adventurer: a burst of changes passed on would each send the whole copy
    -- (code review, 2 Nov 2026); a clash left over is found with the next state (CompareSoon).
    local now = GetTime()
    if S.swappedAt[sender] and now - S.swappedAt[sender] < S.SWAP_EVERY then return end
    S.swappedAt[sender] = now
    S:SendSnap(sender, f)
    S:AskSnap(sender, f)
  end
end)
Comm:On("SNAPQ", function(sender, d)
  if type(d) ~= "table" then return end
  local f = F:Get(d.fid)
  if f and f.members[ns.Me()] and f.v >= (tonumber(d.v) or 0) then S:SendSnap(sender, f) end
end)

Comm:On("SNAP", function(sender, d)
  -- (A copy from an addon before 0.13 has no leadership count: Sync:Beats.)
  local old = type(d) == "table" and type(d.f) == "table" and d.f.lv == nil
  if type(d) == "table" and type(d.f) == "table" then d.f.more = nil end
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
  -- Taken when it wins over ours (Beats: the same answer on both sides).
  local theirs = S:Key(snap, sender)
  if old then theirs.lv = nil end
  local newer = mine and (mine.members[sender] or mine.leader == sender) and S:Beats(theirs, S:Key(mine, me))
  if not joining and not newer then return end
  -- (It keeps our count of leadership changes: its addon does not count them.)
  if old and mine then snap.lv = mine.lv end
  -- (A run line with me in it, new here, counts for my runs tally: Firsts:CountRuns.)
  if mine then ns.Firsts:RunsSeen(mine) end
  -- The same changes and other content: a bug, reported (Fellowship/Conflicts.lua). This copy goes on from theirs.
  if mine and not joining then ns.Conflicts:Taking(mine, snap, sender) end
  S:KeepLocal(snap, mine)
  -- Our changes the copy has not seen are made again on top of it (nothing made while apart is lost). Not when the
  -- copy no longer lists us (we were removed while away), and not when joining: changes kept from an earlier time in
  -- this fellowship (our own "leave" among them) belong to that time, and are forgotten.
  local missing = mine and snap.members[me] and not joining and S:Missing(snap) or {}
  if joining and ns.db.oplog then ns.db.oplog[snap.id] = nil end
  ns.db.fellowships[snap.id] = snap
  ns.Firsts:CountRuns(snap)
  if joining then
    -- (How long it took from Accept: /jtf debug sync.)
    ns.Comm.waits.JOIN = GetTime() - (F.pendingJoin[snap.id].at or GetTime())
    F.pendingJoin[snap.id] = nil
    ns.char.fellowshipId = snap.id
    wipe(ns.char.invites)
    ns:Toast(nil, L.WELCOME_TOAST, L.WELCOME_TOAST_TEXT:format(snap.name), "overview")
  end
  F:AfterChange(snap)
  if joining then ns:Fire("JOINED") end
  if #missing > 0 then S:Replay(snap, missing) end
end)

-- The rest of a new Adventurer's copy (S:SendSnap): the Chronicle lines and History entries we do not have yet.
Comm:On("SNAPM", function(sender, d)
  local f = type(d) == "table" and F:Get(d.fid)
  if not f or not f.members[sender] or not f.members[ns.Me()] then return end
  local have, list = {}, {}
  for _, e in ipairs(f.chronicle) do have[tostring(e.time) .. "|" .. tostring(e.text)] = true; list[#list + 1] = e end
  for _, e in ipairs(type(d.chronicle) == "table" and d.chronicle or {}) do
    local key = type(e) == "table" and tonumber(e.time) and type(e.text) == "string" and (e.time .. "|" .. e.text)
    if key and not have[key] then
      have[key] = true
      list[#list + 1] = { text = e.text, time = tonumber(e.time), k = type(e.k) == "string" and e.k or nil, who = type(e.who) == "string" and e.who or nil }
    end
  end
  -- (Newest first; lines with the same time keep their order.)
  for i, e in ipairs(list) do e._i = i end
  table.sort(list, function(a, b) if a.time ~= b.time then return a.time > b.time end return a._i < b._i end)
  for _, e in ipairs(list) do e._i = nil end
  while #list > F.CHRONICLE_MAX do table.remove(list) end
  f.chronicle = list
  ns.Clears:Merge(f, { history = F.CleanHistory(d.history) })
  F:Changed()
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
  C_Timer.After(30, function() S:Deliver() end)
  C_Timer.NewTicker(S.DELIVER_EVERY, function() S:Deliver() end)
end)
