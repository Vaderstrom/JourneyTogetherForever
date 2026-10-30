-- The Guild Master tournament (SPEC §4.10): its state in the fellowship (f.tourney) and the ops that change it.
--   start    the leader (rule "Start: by the leader"), or any Hero's addon when the rule is "Automatically" and the
--            last tournament ended at least AUTO_EVERY ago; opens sign-up for the rule's time
--   sign     sign up / withdraw (yourself, while sign-up is open)
--   duel     one duel won: reported by the winner's addon when the game says "X has defeated Y in a duel";
--            best of 3 / 5 counts duel wins
--   advance  sign-up or a round is over (sent by the referee's addon when due, see Referee): seeds, or walkovers
--            by online time
-- Ops are checked by every client like any other change (Fellowship.lua), so they agree on the tournament.
-- Walkovers: a match not played when its round ends goes to the player who was online longer in that round (each
-- Hero's addon counts its own minutes and shares them with TON); equal, or both unknown: the higher seed.
local _, ns = ...
local L = ns.L
local F, P, T, Comm = ns.Fellowship, ns.Permissions, ns.Tournament, ns.Comm
local Tn = { TICK = 30, DUEL_GAP = 20, AUTO_EVERY = 7 * 86400 }
ns.Tourney = Tn

local function on(f)
  return F:TournamentState(f) == "on" or (ns.Dev and ns.Dev.tourney) == true
end

local function active(t) return t and (t.phase == "signup" or t.phase == "running") end

function Tn:Need(t) return math.ceil((t.bo or 1) / 2) end

-- The tournament's structure now (nil before the seeds are set).
function Tn:Build(t)
  if not t or not t.seeds then return nil end
  return T.Build(t.format, t.seeds, t.results)
end

-- Signed-up Heroes, in the order they signed up.
function Tn:Signed(f, t)
  local list = {}
  for name, at in pairs(t.signed or {}) do if f.members[name] then list[#list + 1] = { name = name, at = at } end end
  table.sort(list, function(a, b) if a.at ~= b.at then return a.at < b.at end return a.name < b.name end)
  local out = {}
  for i, x in ipairs(list) do out[i] = x.name end
  return out
end

-- Is it time to move on (sign-up over, or the round over or fully played)?
function Tn:Due(_, t, now)
  if not active(t) then return false end
  if t.phase == "signup" then return now >= t.signupEnd end
  local B = self:Build(t)
  return now >= (t.roundEnd or 0) or #T.Live(B, t.slot) == 0
end

-- My match in the round being played: the match and the other player, or nil.
function Tn:MyMatch(f, me)
  local t = f.tourney
  if not t or t.phase ~= "running" then return nil end
  for _, m in ipairs(T.Live(self:Build(t), t.slot)) do
    if m.a == me then return m, m.b end
    if m.b == me then return m, m.a end
  end
  return nil
end

---------------------------------------------------------------------------
-- Ops (Fellowship:Apply calls this for k = "tourney")
---------------------------------------------------------------------------
local function startNew(f, t)
  local r = f.rules
  return { id = t, phase = "signup", format = r.tFormat, bo = r.tBo, seedMode = r.tSeed, min = r.tMin,
    roundLen = r.tRound, total = r.tTotal, signupEnd = t + r.tSignup * 3600, signed = {}, results = {}, duels = {},
    duelT = {}, wo = {} }
end

local function finish(f, t, now, phase)
  t.phase, t.ended = phase, now
  f.tourneyLast = now
end

-- Closes the round: walkovers for unplayed matches, then the next round or the end.
local function closeRound(f, t, now, online)
  local B = Tn:Build(t)
  local seedOf = {}
  for i, n in ipairs(t.seeds) do seedOf[n] = i end
  for _, m in ipairs(T.Live(B, t.slot)) do
    local ma, mb = tonumber(online[m.a]) or 0, tonumber(online[m.b]) or 0
    local w
    if ma ~= mb then w = ma > mb and m.a or m.b else w = seedOf[m.a] < seedOf[m.b] and m.a or m.b end
    t.results[m.key], t.wo[m.key] = w, true
  end
  B = Tn:Build(t)
  if B.champion then
    t.champion = B.champion
    finish(f, t, now, "done")
    F:Log(f, L.CHR_T_CHAMPION:format(ns.Short(B.champion)), now, "champion", B.champion)
  else
    t.slot = T.CurrentSlot(B)
    t.roundEnd = now + t.roundLen * 3600
  end
end

function Tn:Apply(f, op, by, now)
  local a = op.a
  local t = f.tourney
  if a == "start" then
    if not on(f) or active(t) then return false end
    if f.rules.tStart == "auto" then
      if f.tourneyLast and now < f.tourneyLast + self.AUTO_EVERY then return false end
    elseif by ~= f.leader then
      return false
    end
    f.tourney = startNew(f, now)
    F:Log(f, L.CHR_T_START, now, "tstart")
    return true
  end
  if not active(t) then return false end
  if a == "sign" then
    if t.phase ~= "signup" or now >= t.signupEnd or ns.Journey:Away(f, by) then return false end
    t.signed[by] = op.on and now or nil
    return true
  elseif a == "duel" then
    if t.phase ~= "running" or type(op.key) ~= "string" then return false end
    local m
    for _, x in ipairs(T.Live(self:Build(t), t.slot)) do if x.key == op.key then m = x end end
    if not m or (by ~= m.a and by ~= m.b) or (op.w ~= m.a and op.w ~= m.b) then return false end
    -- Both players' addons report the same duel: one report is enough.
    if t.duelT[m.key] and math.abs(now - t.duelT[m.key]) < self.DUEL_GAP then return false end
    t.duelT[m.key] = now
    local wins = t.duels[m.key] or {}
    wins[op.w] = (wins[op.w] or 0) + 1
    t.duels[m.key] = wins
    if wins[op.w] >= self:Need(t) then t.results[m.key] = op.w end
    if #T.Live(self:Build(t), t.slot) == 0 then closeRound(f, t, now, {}) end
    return true
  elseif a == "advance" then
    if not on(f) or not self:Due(f, t, now) then return false end
    if t.phase == "signup" then
      local signed = self:Signed(f, t)
      if #signed < t.min or #signed < 2 then
        finish(f, t, now, "cancelled")
        F:Log(f, L.CHR_T_CANCELLED, now, "tcancel")
        return true
      end
      -- The seeds come with the op (by level as the sender knows them, or random by the tournament's id).
      local seeds, set = {}, {}
      for _, n in ipairs(signed) do set[n] = true end
      for _, n in ipairs(type(op.seeds) == "table" and op.seeds or {}) do if set[n] then seeds[#seeds + 1] = n; set[n] = nil end end
      if next(set) then return false end
      t.seeds, t.phase = seeds, "running"
      local B = self:Build(t)
      if B.champion then t.champion = B.champion; finish(f, t, now, "done"); return true end
      t.slot = T.CurrentSlot(B)
      t.roundEnd = now + t.roundLen * 3600
      return true
    end
    closeRound(f, t, now, type(op.online) == "table" and op.online or {})
    return true
  end
  return false
end

---------------------------------------------------------------------------
-- Actions
---------------------------------------------------------------------------
function Tn:Start() return F:Do({ k = "tourney", a = "start" }) end
function Tn:SignUp(yes) return F:Do({ k = "tourney", a = "sign", on = yes and true or false }) end

-- Online minutes this round, as known here (mine counted here, the others' from TON).
function Tn:OnlineMinutes(f)
  local t, out = f.tourney, {}
  for name in pairs(f.members) do
    local h = f.heroes and f.heroes[name]
    local x = h and h.ton
    if x and x.id == t.id and x.slot == t.slot then out[name] = x.min end
  end
  return out
end

function Tn:Advance(f)
  local t = f.tourney
  local op = { k = "tourney", a = "advance" }
  if t.phase == "signup" then
    op.seeds = T.Seed(self:Signed(f, t), t.seedMode, function(n) return ns.Hero:Level(f, n) end, tostring(t.id))
  else
    op.online = self:OnlineMinutes(f)
  end
  return F:Do(op)
end

-- The one addon that starts automatic tournaments and closes rounds, so two never do it at once: the leader when
-- online, else the online Hero first by name (every addon works it out from who it hears).
function Tn:Referee(f)
  if ns.Hero:Online(f, f.leader) then return f.leader end
  local best
  for name in pairs(f.members) do
    if ns.Hero:Online(f, name) and (not best or name < best) then best = name end
  end
  return best
end

-- Every TICK seconds: start (automatic rule) and move on when due (the referee), count my online minutes.
function Tn:Tick()
  local f = F:Current()
  if not f or not on(f) then return end
  local now = time()
  local t = f.tourney
  local referee = self:Referee(f) == ns.Me()
  if referee and not active(t) and f.rules.tStart == "auto" and (not f.tourneyLast or now >= f.tourneyLast + self.AUTO_EVERY) then
    self:Start()
    return
  end
  if referee and self:Due(f, t, now) then self:Advance(f) return end
  if t and t.phase == "running" and self:MyMatch(f, ns.Me()) then
    local me = ns.Me()
    f.heroes = f.heroes or {}
    f.heroes[me] = f.heroes[me] or {}
    local x = f.heroes[me].ton
    if not x or x.id ~= t.id or x.slot ~= t.slot then x = { id = t.id, slot = t.slot, min = 0 } end
    x.min = x.min + self.TICK / 60
    f.heroes[me].ton = x
    self.tonCount = (self.tonCount or 0) + 1
    if self.tonCount % 10 == 0 then
      for name in pairs(f.members) do if name ~= me then Comm:Send(name, "TON", { fid = f.id, id = t.id, slot = t.slot, min = x.min }) end end
    end
  end
end

Comm:On("TON", function(sender, d)
  local f = type(d) == "table" and F:Get(d.fid)
  if not f or not f.members[sender] then return end
  f.heroes = f.heroes or {}
  f.heroes[sender] = f.heroes[sender] or {}
  f.heroes[sender].ton = { id = tonumber(d.id), slot = tonumber(d.slot), min = tonumber(d.min) or 0 }
end)

---------------------------------------------------------------------------
-- Duels: the game's message "X has defeated Y in a duel" (or "Y has fled from X in a duel")
---------------------------------------------------------------------------
-- A game format string ("%1$s has defeated %2$s in a duel") as a Lua pattern, and which capture is which argument.
function Tn.FormatPattern(fmt)
  local order = {}
  -- Escape everything special except "%" (still part of the %1$s specifiers; "$" becomes "%$").
  local p = fmt:gsub("([%(%)%.%+%-%*%?%[%]%^%$])", "%%%1")
  p = p:gsub("%%(%d)%%%$s", function(i) order[#order + 1] = tonumber(i); return "(.-)" end)
  p = p:gsub("%%s", function() order[#order + 1] = #order + 1; return "(.-)" end)
  return "^" .. p .. "$", order
end

-- Winner and loser (full names) from a system message, or nil.
function Tn.ParseDuel(msg)
  for _, fmt in ipairs({ DUEL_WINNER_KNOCKOUT, DUEL_WINNER_RETREAT }) do
    if type(fmt) == "string" then
      local pattern, order = Tn.FormatPattern(fmt)
      local caps = { msg:match(pattern) }
      if #caps >= 2 then
        local args = {}
        for i, argN in ipairs(order) do args[argN] = caps[i] end
        if args[1] and args[2] then return ns.FullName(args[1]), ns.FullName(args[2]) end
      end
    end
  end
  return nil
end

-- The winner's addon reports the duel (one report, so two addons never send it at once).
function Tn:OnDuel(winner, loser)
  local f = F:Current()
  local me = ns.Me()
  local m = f and self:MyMatch(f, me)
  if not m or winner ~= me then return end
  if (winner == m.a and loser == m.b) or (winner == m.b and loser == m.a) then
    F:Do({ k = "tourney", a = "duel", key = m.key, w = winner })
  end
end

ns:RegisterEvent("CHAT_MSG_SYSTEM", function(_, msg)
  if type(msg) ~= "string" or (issecretvalue and issecretvalue(msg)) then return end
  local w, l = Tn.ParseDuel(msg)
  if w then Tn:OnDuel(w, l) end
end)

ns:On("LOGIN", function() C_Timer.NewTicker(Tn.TICK, function() Tn:Tick() end) end)

-- Start tournament (the page's button): the leader, when the rule is "by the leader".
function Tn:CanStart(f, me)
  return on(f) and not active(f.tourney) and f.rules.tStart ~= "auto" and P.Rank(f, me) == "leader"
end
