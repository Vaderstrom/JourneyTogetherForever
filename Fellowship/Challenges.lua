-- Challenge modes (SPEC §9, decided with the owner 31 Oct and 1 Nov 2026): extra rules the Leader takes on when
-- founding the fellowship. They combine, cannot be added later (a run is honest from level 1), and turning one off
-- (Manage → Rules) is written in the Chronicle. The addon cannot stop anyone: it notices and marks. Three groups, as
-- Create's three tabs show them:
-- Survival (X1, X2; Three lives each dropped, PvP realm without dying merged into Hardcore, the owner, 1 Nov 2026)
--   hardcore     Hardcore Fellowship: one life each, a death ends that Adventurer's journey. On a PvP realm it is
--                called Hardcore PvP Fellowship (value "pvp"). The Leader says so at founding: the game does not tell
--                an addon the kind of realm. A death to another player counts like any other (the game does not tell
--                an addon who killed you either).
--   shared       the fellowship has lives together (set at founding; the size suggests how many), every death costs
--                one; none left loses the challenge, and the journey goes on, marked (the owner, 31 Oct 2026)
-- Story and Travel (X4)
--   ring         Lord of the Rings: the first ring that comes into anyone's bags (not from a quest or the auction
--                house) is the Ring; its finder carries it and must destroy it inside Blackrock Mountain. It leaving
--                their bags anywhere else, or its bearer falling, loses it (the owner, 1 Nov 2026).
--   walk         Walk everywhere: no flight paths, no hearthstone
--   questless    no quests turned in (attunements and dungeon keys are allowed)
--   race         Race to 60: the time from founding to everyone at level 60 (also where the game's cap is higher);
--                the account keeps the best
-- Gear, Gold & More (X3, X5)
--   fellowfound  Fellowship-found: no trade or mail with anyone outside the fellowship, no auction house
--   white        White gear only (shirt and tabard aside)
--   pauper       never more gold than the Leader set (value: the gold, 10 suggested)
--   ironman      Ironman Fellowship: Hardcore Fellowship and White gear only, and no talents, no professions, no
--                potions or food buffs
--   oneclass     everyone plays the Leader's class (value: the class); another can't join (enforced, not marked)
--   nohealers    nobody takes the Healer role (enforced, not marked)
--   dungeons     Dungeons only: experience earned outside a dungeon, once the journey's first dungeon is open
--                (a dungeon's own quests aside)
-- The Fallen (their last life spent) stay in the fellowship, honoured: a memorial line in the Chronicle with level,
-- place, day and a best guess at the foe, a toast, "Fallen" on their card. They no longer hold the fellowship back
-- (J:Counted) and may bring a new character, who joins at level 1 and catches up.
-- A broken rule (SPEC §9): written in the Chronicle ("Brannic took a flight path, breaking Walk everywhere."), and
-- that Adventurer's challenge shows as broken; they play on. Only the first break of each challenge is kept.
-- Every Adventurer's own addon notices their own deaths (Fellowship/Firsts.lua, op "fell") and broken rules
-- (Fellowship/ChallengeWatch.lua, op "broke") and records them in the fellowship, so every copy, a newcomer's too,
-- knows. A Friend of the fellowship is never in the challenges.
local _, ns = ...
local L = ns.L
local F = ns.Fellowship
local C = { RECENT = 3600, RECAP_WAIT = 1, SHARED_MIN = 1, SHARED_MAX = 30, FALLS_MAX = 200, BROKEN_MAX = 300,
  PAUPER_MIN = 1, PAUPER_MAX = 1000, PAUPER_SUGGEST = 10, RACE_LEVEL = 60 }
ns.Challenges = C

-- Create's tabs, in the order shown (the owner, 1 Nov 2026).
C.GROUPS = {
  { key = "survival", list = { "hardcore", "shared" } },
  { key = "story", list = { "ring", "walk", "questless", "race" } },
  { key = "more", list = { "fellowfound", "white", "pauper", "ironman", "oneclass", "nohealers", "dungeons" } },
}
C.LIST, C.GROUP_OF = {}, {}
for _, g in ipairs(C.GROUPS) do
  for _, k in ipairs(g.list) do C.LIST[#C.LIST + 1] = k; C.GROUP_OF[k] = g.key end
end
local KNOWN = {}
for _, k in ipairs(C.LIST) do KNOWN[k] = true end
-- Shared lives: what the fellowship's size suggests (the owner, 31 Oct 2026); the Leader may change it, 1 to 30.
C.SHARED_SUGGEST = { duo = 4, trio = 6, party = 10, large = 15 }
-- Ironman Fellowship takes these on with it: chosen with it, and not turned off while it is on.
C.INCLUDES = { ironman = { "hardcore", "white" } }
-- What an Adventurer did, and the challenge it breaks (op "broke"; Fellowship/ChallengeWatch.lua notices them).
C.WHAT = { trade = "fellowfound", mail = "fellowfound", mailto = "fellowfound", ah = "fellowfound", gear = "white",
  gold = "pauper", taxi = "walk", hearth = "walk", quest = "questless", xp = "dungeons", talent = "ironman",
  prof = "ironman", potion = "ironman", food = "ironman" }

local function str(v) return type(v) == "string" and v ~= "" and #v <= 64 and v or nil end
-- A value the game may hide from addons (12.0's secret values): never compared, joined or kept.
local function plain(v) return v ~= nil and not (issecretvalue and issecretvalue(v)) end
local function nameOk(v) return plain(v) and type(v) == "string" and v ~= "" and #v <= 64 end
C.plain, C.nameOk = plain, nameOk

---------------------------------------------------------------------------
-- What the fellowship keeps (f.challenges, f.challengesOff, f.falls, f.broken, f.ring, f.race; they go with copies
-- like the rules)
---------------------------------------------------------------------------
-- The challenges chosen: { hardcore = true | "pvp", shared = <lives>, pauper = <gold>, oneclass = <class>,
-- <other> = true }; nil when none.
function C.Clean(ch)
  if type(ch) ~= "table" then return nil end
  local out, any = {}, false
  for _, k in ipairs(C.LIST) do
    local v = ch[k]
    if k == "shared" or k == "pauper" then
      local lo, hi = k == "shared" and C.SHARED_MIN or C.PAUPER_MIN, k == "shared" and C.SHARED_MAX or C.PAUPER_MAX
      v = tonumber(v)
      v = v and ns.Clamp(math.floor(v), lo, hi) or nil
    elseif k == "hardcore" then
      v = (v == "pvp" and "pvp") or v == true or nil
    elseif k == "oneclass" then
      v = type(v) == "string" and v:match("^%u+$") and #v <= 16 and v or nil
    else
      v = v == true or nil
    end
    if v then out[k], any = v, true end
  end
  for k, list in pairs(C.INCLUDES) do
    if out[k] then for _, inc in ipairs(list) do out[inc] = out[inc] or true end end
  end
  return any and out or nil
end

-- Fills in what an older copy or another addon's copy lacks (Fellowship:Sanitize). Empty: nil.
function C:Sanitize(f)
  f.challenges = C.Clean(f.challenges)
  local off = {}
  if type(f.challengesOff) == "table" then
    for _, k in ipairs(C.LIST) do
      local o = f.challengesOff[k]
      if type(o) == "table" and tonumber(o.t) then
        off[k] = { t = tonumber(o.t), by = str(o.by), v = tonumber(o.v) or str(o.v) }
      end
    end
  end
  f.challengesOff = next(off) and off or nil
  local falls = {}
  for _, e in ipairs(type(f.falls) == "table" and f.falls or {}) do
    if type(e) == "table" and type(e.who) == "string" and tonumber(e.t) then
      falls[#falls + 1] = { who = e.who, t = tonumber(e.t), n = tonumber(e.n), lvl = tonumber(e.lvl), zone = str(e.zone),
        foe = str(e.foe), foeP = e.foeP == true or nil, fatal = e.fatal == true or nil, life = e.life == true or nil,
        out = e.out == true or nil, pool = tonumber(e.pool) }
    end
  end
  f.falls = #falls > 0 and falls or nil
  local broken = {}
  for _, e in ipairs(type(f.broken) == "table" and f.broken or {}) do
    if type(e) == "table" and type(e.who) == "string" and tonumber(e.t) and C.WHAT[e.what] then
      broken[#broken + 1] = { who = e.who, t = tonumber(e.t), what = e.what, key = C.WHAT[e.what], x = str(e.x) }
    end
  end
  f.broken = #broken > 0 and broken or nil
  local r = f.ring
  if type(r) == "table" and type(r.who) == "string" and tonumber(r.t) then
    f.ring = { who = r.who, t = tonumber(r.t), item = str(r.item), id = tonumber(r.id), guid = str(r.guid),
      state = (r.state == "done" or r.state == "lost") and r.state or nil, tEnd = tonumber(r.tEnd),
      why = (r.why == "fell" or r.why == "gone") and r.why or nil }
  else
    f.ring = nil
  end
  f.race = type(f.race) == "table" and tonumber(f.race.t) and { t = tonumber(f.race.t), secs = tonumber(f.race.secs) } or nil
end

function C:Has(f, key) return f.challenges ~= nil and f.challenges[key] ~= nil end
-- Chosen now, or turned off since (the rulebook and Manage show them).
function C:Ever(f) return f.challenges ~= nil or f.challengesOff ~= nil end
-- The challenge that takes key on with it, while it is on (Ironman Fellowship for Hardcore Fellowship), or nil.
function C:IncludedBy(f, key)
  for k, list in pairs(self.INCLUDES) do
    if self:Has(f, k) then for _, inc in ipairs(list) do if inc == key then return k end end end
  end
  return nil
end

-- Each Adventurer has one life of their own (Hardcore Fellowship): a death ends their journey.
function C:OneLife(f) return self:Has(f, "hardcore") end

-- A survival challenge is on: a death costs something.
function C:Survival(f) return self:OneLife(f) or self:Has(f, "shared") end

-- How many of name's falls were recorded; the fall that ended name's journey (nil while they still have lives).
function C:FallsOf(f, name)
  local n = 0
  for _, e in ipairs(f.falls or {}) do if e.who == name then n = n + 1 end end
  return n
end
function C:Fallen(f, name)
  for _, e in ipairs(f.falls or {}) do if e.who == name and e.fatal then return e end end
  return nil
end

-- Shared lives: how many the fellowship had, how many are left (nil without the challenge), and the fall that took
-- the last one.
function C:SharedLives(f) return f.challenges and f.challenges.shared end
function C:SharedLeft(f)
  local total = self:SharedLives(f)
  if not total then return nil end
  local spent = 0
  for _, e in ipairs(f.falls or {}) do if e.life then spent = spent + 1 end end
  return math.max(0, total - spent)
end
function C:LivesOut(f)
  for _, e in ipairs(f.falls or {}) do if e.out then return e end end
  return nil
end

-- Broken rules: name's break of key (nil if none), the challenges name broke (in Create's order), and who broke key.
function C:Broke(f, name, key)
  for _, e in ipairs(f.broken or {}) do if e.who == name and e.key == key then return e end end
  return nil
end
function C:BrokenOf(f, name)
  local out = {}
  for _, k in ipairs(self.LIST) do if self:Broke(f, name, k) then out[#out + 1] = k end end
  return out
end
function C:BrokenBy(f, key)
  local out = {}
  for _, e in ipairs(f.broken or {}) do if e.key == key then out[#out + 1] = e.who end end
  return out
end

-- key binds name now: chosen, and name is an Adventurer who has neither fallen nor broken it yet.
function C:Holds(f, name, key)
  return self:Has(f, key) and f.members[name] ~= nil and not F:IsFriend(f, name) and not self:Fallen(f, name)
    and not self:Broke(f, name, key)
end

-- The class's name ("Warrior").
function C.ClassName(class) return (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[class]) or class end

-- One class only and No healers are held, not marked: whether someone of this class and roles may be an Adventurer
-- of f. true, or false, why and the challenge. A Friend of the fellowship is never in the challenges.
function C:Allows(f, class, role, second, friend)
  local ch = f and f.challenges
  if friend or not ch then return true end
  if ch.oneclass and class and class ~= ch.oneclass then return false, L.CHAL_ONECLASS_NO:format(C.ClassName(ch.oneclass)), "oneclass" end
  if ch.nohealers and (role == "Healer" or second == "Healer") then return false, L.CHAL_NOHEALERS_NO, "nohealers" end
  return true
end

-- Race to 60: when it began (the founding) and the account's best time ({ secs, name, t }, or nil).
function C:RaceStart(f) return f.founded or tonumber((f.id or ""):match("%-(%d+)$")) end
function C:Record() return ns.db and ns.db.raceRecord end

---------------------------------------------------------------------------
-- Changes (Fellowship:Apply)
---------------------------------------------------------------------------
-- Everyone hears of a change within the hour (a copy brought by joining or updating brings no flood).
local function fresh(f, t) return not f.sample and time() - t <= C.RECENT end

-- A fall of by's (op "fell"), recorded with what it cost under the challenges on now: the end of their journey
-- (fatal: their one life), a shared life (pool: how many are left; out: it was the last). False when it costs
-- nothing (no survival challenge, already Fallen, the shared lives spent and no life of their own at stake) or this
-- fall (the tally's count, n) is recorded already.
function C:ApplyFall(f, by, op, t)
  -- (A Friend of the fellowship is never in the challenges: a death costs nothing, SPEC §1.1.)
  if not self:Survival(f) or self:Fallen(f, by) or F:IsFriend(f, by) then return false end
  local n = tonumber(op.n)
  if n then
    for _, e in ipairs(f.falls or {}) do if e.who == by and e.n == n then return false end end
  end
  local one, left = self:OneLife(f), self:SharedLeft(f)
  local e = { who = by, t = t, n = n, lvl = tonumber(op.lvl), zone = str(op.zone), foe = str(op.foe), foeP = op.foeP == true or nil }
  if left and left > 0 then e.life, e.pool, e.out = true, left - 1, left == 1 or nil end
  e.fatal = one or nil
  if not e.life and not one then return false end
  f.falls = f.falls or {}
  table.insert(f.falls, e)
  while #f.falls > self.FALLS_MAX do table.remove(f.falls, 1) end
  if fresh(f, t) then ns:Toast("challenge", self:FallToast(f, e)) end
  -- The Ring-bearer fell: the Ring is lost with them.
  local r = f.ring
  if e.fatal and r and not r.state and r.who == by then
    r.state, r.tEnd, r.why = "lost", t, "fell"
    if fresh(f, t) then ns:Toast("challenge", L.T_RING_LOST, self:RingText(f), "chronicle", self:ToastOf("ring", { solemn = true })) end
  end
  ns:Fire("CHALLENGES")
  return true
end

-- A broken rule of by's (op "broke": what they did, x: who or what it was), the first of its challenge only.
function C:ApplyBreak(f, by, op, t)
  local key = self.WHAT[op.what]
  if not key or not self:Holds(f, by, key) then return false end
  local e = { who = by, t = t, what = op.what, key = key, x = str(op.x) }
  f.broken = f.broken or {}
  table.insert(f.broken, e)
  while #f.broken > self.BROKEN_MAX do table.remove(f.broken, 1) end
  if fresh(f, t) then
    ns:Toast("challenge", by == ns.Me() and L.T_BROKE_YOU or L.T_BROKE, self:BreakText(e), "chronicle", self:ToastOf(key))
  end
  ns:Fire("CHALLENGES")
  return true
end

-- Lord of the Rings: by found the Ring (op "ring": its name, item id and the game's id of that very item). The
-- earliest find wins while the quest is open, so two finds at once end the same on every copy.
function C:ApplyRing(f, by, op, t)
  if not self:Holds(f, by, "ring") then return false end
  local r = f.ring
  if r and (r.state or r.t <= t) then return false end
  f.ring = { who = by, t = t, item = str(op.item), id = tonumber(op.id), guid = type(op.guid) == "string" and #op.guid <= 64 and op.guid or nil }
  if fresh(f, t) then ns:Toast("challenge", L.T_RING, self:RingText(f), "chronicle", self:ToastOf("ring")) end
  ns:Fire("CHALLENGES")
  return true
end

-- The Ring-bearer destroyed the Ring inside Blackrock Mountain ("done"), or it left their bags ("lost").
function C:ApplyRingEnd(f, by, op, t)
  local r = f.ring
  if not r or r.state or r.who ~= by or (op.state ~= "done" and op.state ~= "lost") then return false end
  r.state, r.tEnd, r.why = op.state, t, op.state == "lost" and "gone" or nil
  if fresh(f, t) then
    ns:Toast("challenge", r.state == "done" and L.T_RING_DONE or L.T_RING_LOST, self:RingText(f), "chronicle",
      self:ToastOf("ring", { solemn = r.state == "lost" or nil }))
  end
  ns:Fire("CHALLENGES")
  return true
end

-- Race to 60: everyone reached level 60 (op "raced"). The earliest wins; the account keeps its best time.
function C:ApplyRace(f, _, _, t)
  local start = self:RaceStart(f)
  if not self:Has(f, "race") or not start or (f.race and f.race.t <= t) then return false end
  f.race = { t = t, secs = math.max(0, t - start) }
  if not f.sample and ns.db then
    local best = ns.db.raceRecord
    if not best or f.race.secs < best.secs then ns.db.raceRecord = { secs = f.race.secs, name = f.name, t = t } end
  end
  if fresh(f, t) then ns:Toast("challenge", L.T_RACE, L.CH_RACE:format(C.Span(f.race.secs)), "chronicle", self:ToastOf("race")) end
  ns:Fire("CHALLENGES")
  return true
end

-- The Leader turns a challenge off (op "chaloff"): for good, written in the Chronicle. v: what it was (the shared
-- lives, "pvp", the gold, the class), so its name can still be told. Not one Ironman Fellowship holds while it is on.
function C:ApplyOff(f, by, op, t)
  local key = op.key
  if not KNOWN[key] or not self:Has(f, key) or self:IncludedBy(f, key) then return false end
  local v = f.challenges[key] ~= true and f.challenges[key] or nil
  f.challengesOff = f.challengesOff or {}
  f.challengesOff[key] = { t = t, by = by, v = v }
  f.challenges[key] = nil
  if not next(f.challenges) then f.challenges = nil end
  if by ~= ns.Me() and fresh(f, t) then
    ns:Toast("challenge", L.T_CHAL_OFF, L.T_CHAL_OFF_TEXT:format(ns.Short(by), self:Name(key, v)), "rules", self:ToastOf(key))
  end
  ns:Fire("CHALLENGES")
  return true
end

function C:TurnOff(key) return F:Do({ k = "chaloff", key = key }) end

---------------------------------------------------------------------------
-- My own death
---------------------------------------------------------------------------
-- The game's Death Recap: the source of the last hit (nil when the game has none, or keeps it from addons). The list
-- is newest first, as the game's own Death Recap shows it; with no recap id it is the latest death's.
function C.Recap()
  local DR = C_DeathRecap
  if not (DR and DR.GetRecapEvents) then return nil end
  local ok, events = pcall(DR.GetRecapEvents)
  if not ok or not plain(events) or type(events) ~= "table" then return nil end
  local e = events[1]
  if not plain(e) or type(e) ~= "table" or not nameOk(e.sourceName) then return nil end
  local guid = e.sourceGUID
  return e.sourceName, (plain(guid) and type(guid) == "string" and guid:sub(1, 7) == "Player-") or nil
end

-- Who you were fighting: the enemy you had targeted (a best guess: the game no longer tells an addon who killed you).
-- Returns the name and whether it is a player; nil when there is none or the game hides the name.
function C:Foe()
  if not (UnitExists and UnitExists("target")) then return nil end
  local hostile = UnitCanAttack and UnitCanAttack("player", "target")
  if not plain(hostile) or not hostile then return nil end
  local name = UnitName("target")
  if not nameOk(name) then return nil end
  local player = UnitIsPlayer("target")
  return name, (plain(player) and player) and true or nil
end

-- My fall (Firsts.lua counted it): recorded when a survival challenge is on. The target is read at once (it may go),
-- the Death Recap a moment later (the game makes it after the death), and the Recap wins when it has a name.
function C:Fell()
  local f = F:Current()
  if not f or not self:Survival(f) or self:Fallen(f, ns.Me()) or F:IsFriend(f, ns.Me()) then return end
  local tally = ns.char.tally
  local n = type(tally) == "table" and tally.fid == f.id and tonumber(tally.falls) or nil
  local lvl = (ns.Dev and ns.Dev.myLevel) or UnitLevel("player")
  local zone = (GetRealZoneText and GetRealZoneText()) or (GetZoneText and GetZoneText())
  zone = nameOk(zone) and zone or nil
  local foe, player = self:Foe()
  C_Timer.After(self.RECAP_WAIT, function()
    local rf, rp = C.Recap()
    if rf then foe, player = rf, rp end
    if F:Current() ~= f then return end
    F:Do({ k = "fell", n = n, lvl = lvl, zone = zone, foe = foe, foeP = player or nil })
  end)
end
ns:On("FELL", function() C:Fell() end)

---------------------------------------------------------------------------
-- In words
---------------------------------------------------------------------------
-- "Hardcore Fellowship", "Hardcore PvP Fellowship", "Shared lives (10)", "Pauper (10 gold)", "One class only
-- (Warrior)". v: the challenge's value.
function C:Name(key, v)
  if key == "shared" and tonumber(v) then return L.CHAL_SHARED_N:format(v) end
  if key == "pauper" and tonumber(v) then return L.CHAL_PAUPER_N:format(v) end
  if key == "oneclass" and type(v) == "string" then return L.CHAL_ONECLASS_N:format(C.ClassName(v)) end
  if key == "hardcore" and v == "pvp" then return L.CHAL_HARDCORE_PVP end
  return L["CHAL_" .. key:upper()] or key
end

-- The challenges of f (or of a choice { key = value }) as one line: "Hardcore Fellowship · Shared lives (10)"; nil
-- when none.
function C:Line(ch)
  if not ch then return nil end
  local parts = {}
  for _, k in ipairs(self.LIST) do if ch[k] then parts[#parts + 1] = self:Name(k, ch[k]) end end
  return #parts > 0 and table.concat(parts, "  ·  ") or nil
end

-- A challenge's rule in a sentence (Create's right page, the rulebook).
function C:Rule(key, v)
  if key == "shared" then return L.CHAL_SHARED_RULE:format(tonumber(v) or 0) end
  if key == "pauper" then return L.CHAL_PAUPER_RULE:format(tonumber(v) or self.PAUPER_SUGGEST) end
  if key == "oneclass" then return L.CHAL_ONECLASS_RULE:format(C.ClassName(v or "")) end
  if key == "hardcore" and v == "pvp" then return L.CHAL_HARDCORE_PVP_RULE end
  return L["CHAL_" .. key:upper() .. "_RULE"]
end

-- "2 Nov 2026"
local function day(t) return (date(L.MO_DAY, t):gsub("^0", "")) end
C.Day = day
-- "18 days 3 hours", "5 hours 12 minutes", "40 minutes"
local function unit(n, one, many) return n == 1 and L[one] or L[many]:format(n) end
function C.Span(secs)
  secs = math.max(0, secs or 0)
  local d, h, m = math.floor(secs / 86400), math.floor(secs % 86400 / 3600), math.floor(secs % 3600 / 60)
  if d > 0 then return unit(d, "SPAN_DAY", "SPAN_DAYS") .. " " .. unit(h, "SPAN_HOUR", "SPAN_HOURS") end
  if h > 0 then return unit(h, "SPAN_HOUR", "SPAN_HOURS") .. " " .. unit(m, "SPAN_MIN", "SPAN_MINS") end
  return unit(math.max(1, m), "SPAN_MIN", "SPAN_MINS")
end
-- "at level 23 in Duskwood"
local function where(e)
  if e.zone then return L.FALL_WHERE:format(e.lvl or 0, e.zone) end
  return L.FALL_LEVEL:format(e.lvl or 0)
end
-- ", fighting Hogger" (a best guess), or "".
local function foe(e)
  if not e.foe then return "" end
  return (e.foeP and L.FALL_FOE_PLAYER or L.FALL_FOE):format(e.foe)
end

-- The Chronicle's line for a fall: a memorial for the Fallen, else the life it cost.
function C:FallText(f, e)
  local who = ns.Short(e.who)
  local text
  if e.fatal then text = L.CH_MEMORIAL:format(who, where(e), day(e.t), foe(e))
  else text = L.CH_FELL:format(who, where(e), foe(e)) end
  if e.out then text = text .. " " .. L.CH_SHARED_OUT:format(self:SharedLives(f) or 0)
  elseif e.life then text = text .. " " .. L.CH_SHARED_LEFT:format(e.pool or 0, self:SharedLives(f) or 0) end
  return text
end

-- The toast for a fall: the Fallen first, then the lives it cost. Returns what ns:Toast takes after the kind: the
-- title, the text, the page a click opens and { solemn } (a Fallen or the last shared life: the darker banner with
-- the bell, UI/Toast.lua).
function C:FallToast(f, e)
  local me = e.who == ns.Me()
  local who = ns.Short(e.who)
  local title
  if e.out then title = L.T_SHARED_OUT
  elseif e.fatal then title = me and L.T_FALLEN_YOU or L.T_FALLEN:format(who)
  elseif e.life then title = L.T_SHARED_LIFE
  else title = me and L.T_FELL_YOU or L.T_FELL:format(who) end
  -- (The title names them when they fell for good, or it was you; otherwise the text does.)
  local text = ((e.fatal or me) and not e.out) and L.T_FALL_DETAIL:format(where(e), foe(e)) or L.T_FALL_WHO:format(who, where(e), foe(e))
  if e.fatal then text = text .. " " .. L.T_FALLEN_HONOURED end
  if e.out then text = text .. " " .. L.T_SHARED_OUT_TEXT
  elseif e.life then text = text .. " " .. L.CH_SHARED_LEFT:format(e.pool or 0, self:SharedLives(f) or 0) end
  -- Above the title, the challenge the fall is about (it said the Settings line "A challenge: a fall, a broken rule,
  -- the Ring"; check of 1 Nov 2026, 15:23); the skull stays.
  -- A fall for good names Hardcore, even when it spent the last shared life: Hardcore ended that journey.
  local kicker = e.fatal and self:Name("hardcore", f.challenges and f.challenges.hardcore) or self:Name("shared")
  return title, text, "chronicle", { solemn = (e.fatal or e.out) and true or nil, kicker = kicker }
end

-- A challenge's toast (a broken rule, the Ring, the race, turned off): the challenge's own icon and its name as the
-- small line above the title (the check of 1 Nov 2026, 14:32: they had the skull of a death, which stays for falls).
function C:Icon(key) return ns.ICONS["chal_" .. key] or ns.ICONS.hist_challenge end
function C:ToastOf(key, more)
  more = more or {}
  more.icon, more.kicker = self:Icon(key), self:Name(key)
  return more
end

-- What a broken rule's x stands for when the addon did not get it (a name the game hid).
local NONE = { trade = "BREAK_SOMEONE", mail = "BREAK_SOMEONE", mailto = "BREAK_SOMEONE", gear = "BREAK_A_GREEN",
  potion = "BREAK_A_POTION", quest = "BREAK_A_QUEST", xp = "BREAK_OUTSIDE", prof = "BREAK_A_PROFESSION", gold = "BREAK_MORE" }
-- "Brannic took a flight path, breaking Walk everywhere."
function C:BreakText(e)
  local did = L["BREAK_" .. e.what:upper()]:format(e.x or (NONE[e.what] and L[NONE[e.what]]) or "")
  return L.CH_BROKE:format(ns.Short(e.who), did, self:Name(e.key))
end

-- Lord of the Rings in a sentence: found, destroyed, or lost (and how).
function C:RingText(f)
  local r = f.ring
  if not r then return nil end
  local who, item = ns.Short(r.who), r.item or L.RING_A_RING
  if r.state == "done" then return L.CH_RING_DONE:format(who, item) end
  if r.state == "lost" then return (r.why == "fell" and L.CH_RING_FELL or L.CH_RING_GONE):format(who, item) end
  return L.CH_RING:format(who, item)
end

-- Shared lives for the candles (UI.Lives): how many, how many left, and the tooltip: the title and one line for each
-- life lost ("Brannic, level 22, 1 Nov 2026"). nil without the challenge.
function C:LivesView(f)
  local total = self:SharedLives(f)
  if not total then return nil end
  local left, out = self:SharedLeft(f), self:LivesOut(f)
  local lines = {}
  for _, e in ipairs(f.falls or {}) do
    if e.life then lines[#lines + 1] = L.LIVES_TIP_LOST:format(ns.Short(e.who), e.lvl or 0, day(e.t)) end
  end
  if #lines == 0 then lines[1] = L.LIVES_TIP_NONE end
  local title = out and L.LIVES_OUT:format(day(out.t)) or L.LIVES_LEFT:format(left, total)
  return { total = total, left = left, title = title, lines = lines }
end

-- The Fallen's card (the Adventurers page): "Duskwood · 2 Nov 2026 · fighting Hogger". (The level is the card's big
-- number: on the line too, it pushed the foe past the card's edge; check of 1 Nov 2026 after 1133f90.)
function C:FallenLine(e)
  local parts = {}
  if e.zone then parts[#parts + 1] = e.zone end
  parts[#parts + 1] = day(e.t)
  if e.foe then parts[#parts + 1] = (e.foeP and L.FALLEN_FOE_PLAYER or L.FALLEN_FOE):format(e.foe) end
  return table.concat(parts, "  ·  ")
end

-- A Fallen Adventurer's memorial (the Adventurers page, inspected): the fall and its sentence ("Fell at level 23 in
-- Duskwood on 2 Nov 2026, fighting Hogger."), when they joined, their days in the fellowship (the day they joined
-- counts as one), the journey's dungeons they cleared and the firsts they earned (in the medals' order). nil when name
-- has not fallen.
function C:Memorial(f, name)
  local e, m = self:Fallen(f, name), f.members[name]
  if not e or not m then return nil end
  local joined = tonumber(m.joined)
  local cleared = 0
  for key in pairs(f.journey.place) do if ns.Journey:ClearedBy(f, key)[name] then cleared = cleared + 1 end end
  local mine, firsts = {}, {}
  for _, x in ipairs(ns.Firsts:List(f)) do if x.name == name then mine[x.key] = true end end
  for _, key in ipairs(ns.Firsts.KEYS) do if mine[key] then firsts[#firsts + 1] = key end end
  return { e = e, joined = joined, days = joined and math.floor(math.max(0, e.t - joined) / 86400) + 1 or nil,
    cleared = cleared, firsts = firsts, line = L.MEMORIAL_FELL:format(where(e), day(e.t), foe(e)) }
end

-- What an Adventurer's card adds after their roles: "Ring-bearer", "Broke Walk everywhere" (or "Broke 3 challenges");
-- nil when nothing.
function C:CardNote(f, name)
  local parts = {}
  local r = f.ring
  if r and not r.state and r.who == name then parts[#parts + 1] = L.CARD_RING_BEARER end
  local broke = self:BrokenOf(f, name)
  if #broke == 1 then parts[#parts + 1] = L.CARD_BROKE:format(self:Name(broke[1]))
  elseif #broke > 1 then parts[#parts + 1] = L.CARD_BROKE_N:format(#broke) end
  return #parts > 0 and table.concat(parts, "  ·  ") or nil
end

-- The Chronicle's entries (UI/Pages/Chronicle.lua, under All): the falls, the broken rules, the Ring, the race and
-- the challenges turned off, newest first.
function C:Entries(f)
  local out = {}
  local function add(e) e.type, e.seq = "challenge", #out; out[#out + 1] = e end
  for _, e in ipairs(f.falls or {}) do
    local chip, color = L.ST_LIFE, "B8742A"
    if e.fatal then chip, color = L.ST_FALLEN, "5E4B6E" elseif e.out then chip, color = L.ST_LIVES_OUT, "B0321E" end
    add({ icon = e.fatal and "fallen" or "life", time = e.t, text = self:FallText(f, e), chip = chip, chipColor = color, who = e.who })
  end
  for _, e in ipairs(f.broken or {}) do
    add({ icon = "broke", time = e.t, text = self:BreakText(e), chip = L.ST_BROKE, chipColor = "9A5B2E", who = e.who })
  end
  local r = f.ring
  if r then
    add({ icon = "ring", time = r.t, text = L.CH_RING:format(ns.Short(r.who), r.item or L.RING_A_RING), chip = L.ST_RING,
      chipColor = "A8862E", who = r.who })
    if r.state then
      add({ icon = "ring", time = r.tEnd or r.t, text = self:RingText(f), who = r.who,
        chip = r.state == "done" and L.ST_RING_DONE or L.ST_RING_LOST, chipColor = r.state == "done" and "3E7A3A" or "B0321E" })
    end
  end
  if f.race then
    add({ icon = "race", time = f.race.t, text = L.CH_RACE:format(C.Span(f.race.secs)), chip = L.ST_RACE,
      chipColor = "3E7A3A" })
  end
  for _, k in ipairs(self.LIST) do
    local o = f.challengesOff and f.challengesOff[k]
    if o then
      add({ icon = "challenge", time = o.t, chip = L.ST_CHAL_OFF, chipColor = "7A6A55",
        text = L.CH_OFF:format(ns.Short(o.by or f.leader), self:Name(k, o.v)) })
    end
  end
  -- (In the same second, the one recorded last comes first.)
  table.sort(out, function(a, b) if a.time ~= b.time then return a.time > b.time end return a.seq > b.seq end)
  return out
end

-- The rulebook's article (the Rules page), or nil when the fellowship never had a challenge: { title, intro, items,
-- after, text }. items: a block for each challenge on, { key, title, name, rule, broken, notes } (name: the title
-- marked as a value): who broke it ("Broken by Pata.") and what stands now (the lives left, the Ring, the race
-- clock), each a line of its own (the check of 1 Nov
-- 2026, 14:32: eleven rules ran together as one paragraph). after: the lines of no challenge on (the Fallen, starting
-- anew, a challenge turned off). text: all of it as one paragraph. hl(s) marks a value.
function C:Book(f, hl)
  if not self:Ever(f) then return nil end
  hl = hl or function(s) return s end
  local items, after, byKey = {}, {}, {}
  for _, k in ipairs(self.LIST) do
    if self:Has(f, k) then
      local name = self:Name(k, f.challenges[k])
      local it = { key = k, title = name, name = hl(name), rule = self:Rule(k, f.challenges[k]), notes = {} }
      local by = self:BrokenBy(f, k)
      for i, who in ipairs(by) do by[i] = ns.Short(who) end
      if #by > 0 then it.broken = L.CHAL_BOOK_BROKEN:format(table.concat(by, ", ")) end
      items[#items + 1], byKey[k] = it, it
    end
  end
  -- A line under its challenge's block, or after the blocks when that challenge is off now.
  local function note(key, line)
    local list = byKey[key] and byKey[key].notes or after
    list[#list + 1] = line
  end
  if self:Has(f, "shared") then
    local out = self:LivesOut(f)
    if out then note("shared", L.CHAL_BOOK_OUT:format(day(out.t), ns.Short(out.who), out.lvl or 0))
    else note("shared", L.CHAL_BOOK_LEFT:format(hl(tostring(self:SharedLeft(f))), self:SharedLives(f))) end
  end
  local r = f.ring
  if r then
    if r.state then note("ring", self:RingText(f) .. " " .. L.CHAL_BOOK_ON:format(day(r.tEnd or r.t)))
    else note("ring", L.CHAL_BOOK_RING:format(hl(ns.Short(r.who)), r.item or L.RING_A_RING)) end
  elseif self:Has(f, "ring") then
    note("ring", L.CHAL_BOOK_RING_NONE)
  end
  if f.race then
    note("race", L.CH_RACE:format(hl(C.Span(f.race.secs))))
  elseif self:Has(f, "race") and self:RaceStart(f) then
    note("race", L.CHAL_BOOK_RACE:format(hl(C.Span(time() - self:RaceStart(f)))))
    local best = self:Record()
    if best then note("race", L.CHAL_BOOK_RECORD:format(hl(C.Span(best.secs)), best.name or "?")) end
  end
  local fallen = {}
  for _, e in ipairs(f.falls or {}) do if e.fatal then fallen[#fallen + 1] = ns.Short(e.who) end end
  if #fallen > 0 then after[#after + 1] = L.CHAL_BOOK_FALLEN:format(table.concat(fallen, ", ")) end
  if self:Survival(f) then after[#after + 1] = L.CHAL_BOOK_ANEW end
  for _, k in ipairs(self.LIST) do
    local o = f.challengesOff and f.challengesOff[k]
    if o then after[#after + 1] = L.CHAL_BOOK_OFF:format(self:Name(k, o.v), day(o.t), ns.Short(o.by or f.leader)) end
  end
  local parts = { L.CHAL_BOOK_INTRO }
  for _, it in ipairs(items) do
    parts[#parts + 1] = L.CHAL_BOOK_ONE:format(it.name, it.rule)
    if it.broken then parts[#parts + 1] = it.broken end
    for _, line in ipairs(it.notes) do parts[#parts + 1] = line end
  end
  for _, line in ipairs(after) do parts[#parts + 1] = line end
  return { title = L.CHAL_BOOK, intro = L.CHAL_BOOK_INTRO, items = items, after = after, text = table.concat(parts, " ") }
end

-- The rulebook's tiles (the Rules page's right page, UI.NumberTile): what stands now, at a glance. { { key, value,
-- label, icon } }: the shared lives left, the race clock, the Ring and the rules broken (always, with any challenge
-- on). nil when none is on.
function C:Tiles(f)
  local broken, on = 0, false
  for _, k in ipairs(self.LIST) do
    if self:Has(f, k) then on, broken = true, broken + #self:BrokenBy(f, k) end
  end
  if not on then return nil end
  local out = {}
  local total = self:SharedLives(f)
  if total then
    out[#out + 1] = { key = "shared", value = L.TILE_OF:format(self:SharedLeft(f), total), label = L.TILE_LIVES, icon = self:Icon("shared") }
  end
  local start = self:Has(f, "race") and self:RaceStart(f)
  if f.race or start then
    out[#out + 1] = { key = "race", value = C.Span(f.race and f.race.secs or time() - start),
      label = f.race and L.TILE_RACE_DONE or L.TILE_RACE, icon = self:Icon("race") }
  end
  if self:Has(f, "ring") then
    local r = f.ring
    local held = r and not r.state
    local v = held and ns.Short(r.who) or (not r and L.TILE_RING_NONE) or (r.state == "done" and L.TILE_RING_DONE) or L.TILE_RING_LOST
    out[#out + 1] = { key = "ring", value = v, label = held and L.CARD_RING_BEARER or L.TILE_RING, icon = self:Icon("ring") }
  end
  out[#out + 1] = { key = "broken", value = broken, label = L.TILE_BROKEN, icon = ns.ICONS.hist_broke }
  return out
end
