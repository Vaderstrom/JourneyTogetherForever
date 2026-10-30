-- Developer tools: /jtf debug ... (docs/ARCHITECTURE.md §6). Nothing here is saved.
-- Pretend Heroes make it possible to test inviting and joining with one account: their messages go through
-- the same receive path as real ones (ns.Comm:Inject), and messages to them are handled here, not whispered.
local _, ns = ...
local L = ns.L
-- game: what the game's lists pretend about a pretend Hero ({ online, afk }; /jtf debug hero <Name> quiet|afk).
local D = { tourney = false, fakes = {}, game = {} }
ns.Dev = D

D.TEST_LEADER = "Testleader"
D.TEST_ID = "dev-test-fellowship"
D.TEST_HEROES = { { "Brannic", "Healer", "PALADIN" }, { "Elyra", "DPS", "MAGE" } }

-- Each pretend Companion's class (all were paladins, so every class crest looked the same; seen in game). Other
-- names get one of the classes by their letters.
D.PRETEND_CLASS = { Brannic = "WARRIOR", Elyra = "PRIEST", Corwin = "MAGE", Darrow = "ROGUE", Fenna = "DRUID", Fakehero = "HUNTER" }
D.CLASSES = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }
function D:PretendClass(name)
  local short = ns.Short(name)
  if self.PRETEND_CLASS[short] then return self.PRETEND_CLASS[short] end
  local sum = 0
  for i = 1, #short do sum = sum + short:byte(i) end
  return self.CLASSES[sum % #self.CLASSES + 1]
end

local function fake(name)
  local full = ns.FullName(ns.CleanName(name))
  if full then D.fakes[full] = true end
  return full
end

-- Marks a name as a pretend Hero before inviting it, so the invite goes to /jtf debug and never out as a whisper
-- (a real whisper to a name nobody plays comes back "offline" and removes the invite).
function D:Fake(name) return fake(name) end

-- Pretend members to make a fellowship of n for the group photo (UI/Photo.lua): names only, never added to it.
D.CROWD = { "Ash", "Bryn", "Cato", "Dara", "Edda", "Finn", "Gale", "Hollis", "Ivo", "Juna", "Kell", "Lio", "Mara",
  "Nils", "Odo", "Pell", "Quin", "Rhea", "Sten", "Tova" }
function D:Crowd(f, n)
  local out, have = {}, f and #ns.Fellowship:Members(f) or 0
  for i = 1, math.min(#self.CROWD, (n or 0) - have) do out[i] = ns.FullName(self.CROWD[i]) end
  return out
end

-- The pretend fellowship that "Testleader" sends when you accept the invite.
function D:TestFellowship(myRole)
  local leader, me, now = ns.FullName(self.TEST_LEADER), ns.Me(), time()
  local _, myClass = UnitClass("player")
  local level = UnitLevel("player")
  local f = {
    id = self.TEST_ID, v = 3, name = L.DEV_FELLOWSHIP, faction = (UnitFactionGroup("player")), color = "6A3A9A", emblem = "Her_Wolf",
    leader = leader, officers = {}, invites = {}, rules = ns.Rules.New(), journey = ns.BuildJourney("classic"), chronicle = {},
    members = { [leader] = { role = "Tank", class = "WARRIOR", level = level, joined = now },
      [me] = { role = myRole, class = myClass, level = level, joined = now } },
    updated = now,
  }
  for _, h in ipairs(self.TEST_HEROES) do
    local n = fake(h[1])
    f.members[n] = { role = h[2], class = h[3], level = level, joined = now }
  end
  table.insert(f.chronicle, { text = L.CHR_FOUNDED:format(f.name, self.TEST_LEADER), time = now, k = "founded" })
  return f
end

-- Messages to pretend Heroes. Returns true when handled (nothing is whispered).
function D:Intercept(target, tag, data)
  if not self.fakes[target] then return false end
  -- A pretend Hero with a copy of its own answers like a second addon (Dev/Peers.lua).
  if ns.Peers and ns.Peers:Handle(target, tag, data) then return true end
  -- Pretend Heroes have the addon: an invite gets its receipt.
  if tag == "INV" then C_Timer.After(0.3, function() ns.Comm:Inject(target, "INVA", { fid = data.fid }) end) end
  if tag == "GRPA" then ns:Debug(L.DEV_ANSWERED:format(ns.Short(target), data.yes and L.JOIN_GROUP or L.NOT_NOW)) end
  -- The pretend alt's fellowship (/jtf debug watch): its Companions answer as real ones would (Fellowship/Watch.lua).
  if data.fid == self.WATCH_ID and (tag == "WATCHQ" or tag == "WATCHG") then
    C_Timer.After(0.3, function() self:WatchAnswer(target, tag) end)
  end
  if target == ns.FullName(self.TEST_LEADER) and tag == "ACC" and data.fid == self.TEST_ID then
    local f = self:TestFellowship(data.role)
    C_Timer.After(0.5, function() ns.Comm:Inject(target, "SNAP", { f = f }) end)
  end
  return true
end

local function onOff(word) return word == "on" or word == "1" or word == "true" end

-- /jtf debug hero <Name> accept|decline|leave|level <n>|offline
function D:Hero(name, what, arg)
  local f = ns.Fellowship:Current()
  local full = fake(name)
  if not f or not full then ns:Debug(L.DEV_NO_FELLOWSHIP) return end
  -- Everything but answering an invite needs them in the fellowship (after /jtf check there is none; seen in game).
  if what ~= "accept" and what ~= "decline" and not f.members[full] then
    ns:Debug(L.DEV_NOT_COMPANION:format(ns.Short(full), ns.Short(full)))
    return
  end
  if (what == "accept" or what == "decline") and f.members[full] then
    -- Pressed again (seen in game: it said "no open invite", which read as a failure).
    ns:Debug(L.DEV_ALREADY_IN:format(ns.Short(full)))
  elseif what == "accept" or what == "decline" then
    -- No open invite (never sent, or removed because the whisper to a pretend name came back "offline"): the leader
    -- invites again, now as a pretend Hero.
    if not f.invites[full] and ns.Permissions.Can(f, ns.Me(), "invite") and not f.members[full] then
      ns.Fellowship:Do({ k = "invite", name = full })
    end
    if not f.invites[full] then ns:Debug(L.DEV_NOT_INVITED:format(ns.Short(full))) return end
    ns.Comm:Inject(full, what == "accept" and "ACC" or "DEC", { fid = f.id, role = "DPS", class = self:PretendClass(full), level = UnitLevel("player") })
  elseif what == "leave" then
    ns.Comm:Inject(full, "OP", { fid = f.id, v = f.v + 1, op = { k = "leave" }, t = time() })
  elseif what == "level" and tonumber(arg) then
    -- The pretend Hero shares a new level (and some XP and a pace of 2,500 XP an hour), as a real one does.
    ns.Comm:Inject(full, "STATE", { fid = f.id, v = f.v, s = { level = tonumber(arg), xp = 400, xpMax = 1000, rested = 200, pace = 2500, t = time() } })
  elseif what == "gather" then
    -- The pretend Hero sets up a Gathering in 16 minutes (so the reminder comes after about a minute).
    ns.Comm:Inject(full, "OP", { fid = f.id, v = f.v + 1, op = { k = "gather", a = "new", id = full .. "-" .. time(),
      text = arg and arg ~= "" and arg or L.DEV_GATHER_TEXT, at = time() + 16 * 60 }, t = time() })
  elseif what == "propose" then
    -- The pretend Hero proposes one Hero fewer for a run (or 4 if it is at the lowest).
    local value = f.rules.minHeroes > 2 and f.rules.minHeroes - 1 or 4
    ns.Comm:Inject(full, "OP", { fid = f.id, v = f.v + 1, op = { k = "vote", a = "propose", id = full .. "-minHeroes-" .. time(),
      key = "minHeroes", value = value }, t = time() })
  elseif what == "vote" then
    -- The pretend Hero votes on the first open vote: /jtf debug hero <Name> vote yes|no
    local v = ns.Votes:List(f)[1]
    if v then
      ns.Comm:Inject(full, "OP", { fid = f.id, v = f.v + 1, op = { k = "vote", a = "ballot", id = v.id, yes = (arg or ""):lower() ~= "no" }, t = time() })
      ns.Votes:Settle(v.id)
    end
  elseif what == "ask" then
    -- The pretend Hero asks you to group up for the first quest in your log.
    local q
    for _, x in pairs(ns.Quests:MyLog()) do q = q or x.t end
    ns.Comm:Inject(full, "GRPQ", { fid = f.id, q = q or "A quest" })
  elseif what == "quests" then
    -- The pretend Hero shares your quest log, with less progress on every other quest.
    local log, n = {}, 0
    for id, q in pairs(ns.Quests:MyLog()) do
      n = n + 1
      local copy = {}
      for k, v in pairs(q) do copy[k] = v end
      if n % 2 == 0 then copy.h = math.max(0, q.h - 1) end
      log[id] = copy
    end
    -- And one of their own that you could join (a made-up quest at your level).
    local lvl = UnitLevel("player") or 1
    log[99900 + lvl] = { t = L.DEV_JOIN_QUEST, z = GetZoneText and GetZoneText() or "", l = lvl, h = 1, g = 8, k = true, o = L.DEV_JOIN_OBJ }
    ns.Comm:Inject(full, "QUESTS", { fid = f.id, q = log, d = ns.Quests:MyDone(), ln = {}, t = time() })
  elseif what == "signup" then
    -- The pretend Hero signs up for the tournament (a real op from them).
    ns.Comm:Inject(full, "OP", { fid = f.id, v = f.v + 1, op = { k = "tourney", a = "sign", on = true }, t = time() })
  elseif what == "offline" or what == "quiet" or what == "afk" then
    -- As if last heard 3 hours ago and a whisper to them failed. quiet: the game's friends list still shows them
    -- online (their addon is not heard); afk: online and AFK in the game (Friends:Status).
    local h = ns.Hero:Get(f, full)
    if h then h.heard = time() - 3 * 3600
    else ns.Hero:Store(f, full, { level = ns.Hero:Level(f, full) }, time() - 3 * 3600) end -- never heard from yet
    self.game[full] = what ~= "offline" and { online = true, afk = what == "afk" or nil } or nil
    ns:Fire("OFFLINE", full)
    ns:Fire("HEROES", true)
  elseif what == "online" then
    -- Their addon is heard again (a state with the level and XP they have), and the game no longer pretends.
    self.game[full] = nil
    ns.Comm:Inject(full, "STATE", { fid = f.id, v = f.v, s = self:StateOf(f, full) })
  elseif self:HeroMore(f, full, what, arg) == false then
    D:Help()
  end
end

-- A pretend Companion's state as they would send it now: the level, XP and version they have (so a hello does not
-- change them), with `ver` replaced when given.
function D:StateOf(f, full, ver)
  local h = ns.Hero:Get(f, full) or {}
  return { level = ns.Hero:Level(f, full), xp = h.xp, xpMax = h.xpMax, rested = h.rested, pace = h.pace,
    class = h.class, className = h.className, ver = ver or h.ver, t = time() }
end

-- More of another Companion's client, for what needs two accounts (docs/E2E-CHECKS.md): their answers, their
-- reports and their changes, sent as the real messages. Returns false for an unknown action.
-- An op from them: as the next version, or with "gap" / "clash" the version their client would have then.
local function op(f, full, o, mode)
  local v = mode == "clash" and f.v or (mode == "gap" and f.v + 2 or f.v + 1)
  ns.Comm:Inject(full, "OP", { fid = f.id, v = v, op = o, t = time() })
end
D.op = op

function D:HeroMore(f, full, what, arg)
  local me = ns.Me()
  local target = arg ~= "" and arg and ns.FullName(ns.CleanName(arg)) or me
  if what == "answer" then
    -- Their answer to the next Gathering: /jtf debug hero <Name> answer yes|maybe|no
    local g = ns.Gatherings:Upcoming(f)[1]
    if not g then ns:Debug(L.DEV_NO_GATHERING) return true end
    op(f, full, { k = "gather", a = "answer", id = g.id, answer = (arg == "maybe" or arg == "no") and arg or "yes" })
  elseif what == "kill" then
    -- Their client reports a boss kill in your group's dungeon: /jtf debug hero <Name> kill <key>
    local key = (arg or ""):lower()
    if not ns.Endgame:Tracked(f, key) then ns:Debug(L.DEV_NO_DUNGEON:format(key, "")) return true end
    -- The first needed boss; a dungeon without boss data learns one by name, as from a real kill.
    local b = ns.Clears:Needed(f, key)[1] or ("n" .. L.DEV_BOSS)
    local names = { full }
    for _, n in ipairs(self.group or {}) do names[#names + 1] = n end
    names[#names + 1] = me
    ns.Comm:Inject(full, "RUN", { fid = f.id, key = key, b = b, names = names, t = time() })
  elseif what == "gear" then
    -- They share their gear (your own items, as a stand-in).
    ns.Comm:Inject(full, "GEAR", { fid = f.id, g = ns.Hero:MyGear(), t = time() })
  elseif what == "version" then
    -- Their addon says hello with another version: /jtf debug hero <Name> version 0.9.0 (the version notice)
    ns.Comm:Inject(full, "HELLO", { fid = f.id, v = f.v, s = self:StateOf(f, full, arg ~= "" and arg or "0.9.0") })
  elseif what == "away" then
    op(f, full, { k = "away", name = full, on = arg ~= "off" })
  elseif what == "role" then
    op(f, full, { k = "role", name = full, role = (arg == "Tank" or arg == "Healer") and arg or "DPS", second = "" })
  elseif what == "remove" then
    op(f, full, { k = "remove", name = target })
  elseif what == "lead" then
    op(f, full, { k = "lead", name = target })
  elseif what == "rename" then
    op(f, full, { k = "rename", name = arg ~= "" and arg or L.DEV_RENAMED })
  elseif what == "disband" then
    op(f, full, { k = "disband" })
  elseif what == "rules" then
    -- They change a rule (as the captain): one Companion fewer for a run.
    local r = {}
    for k, v in pairs(f.rules) do r[k] = v end
    r.minHeroes = r.minHeroes > 2 and r.minHeroes - 1 or 4
    op(f, full, { k = "rules", rules = r })
  elseif what == "journey" then
    -- They publish the journey again (as the captain), with the last chapter removed.
    local j = ns.Journey.Clean(f.journey)
    if j and #j.chapters > 1 then table.remove(j.chapters) end
    op(f, full, { k = "journey", journey = j })
  elseif what == "invite" then
    -- As a Steward, they invite someone: /jtf debug hero <Name> invite <Other>
    op(f, full, { k = "invite", name = target })
  elseif what == "clear" then
    -- As a Steward or the captain, they mark a dungeon cleared: /jtf debug hero <Name> clear <key>
    op(f, full, { k = "clear", key = (arg or ""):lower(), names = ns.Journey:Counted(f) })
  elseif what == "swap" then
    -- They play another character on their account: /jtf debug hero <Name> swap <Alt>
    op(f, full, { k = "swap", name = target ~= me and target or ns.FullName(ns.Short(full) .. "alt"), class = self:PretendClass(full), level = UnitLevel("player") })
  elseif what == "clash" or what == "gap" then
    -- Sync edge cases: a change made at the same time as one of yours (same version), or one after a change you
    -- missed (version two ahead: your client asks for the whole fellowship).
    op(f, full, { k = "away", name = full, on = true }, what)
  elseif what == "snap" then
    -- They send their whole copy, one version ahead (as after a change you missed).
    local copy = {}
    for k, v in pairs(f) do if k ~= "heroes" then copy[k] = v end end
    copy.v = f.v + 1
    copy.name = f.name .. "*"
    ns.Comm:Inject(full, "SNAP", { f = copy })
  else
    return false
  end
  return true
end

-- /jtf debug sync: this client's view of the sync (version, fingerprint, messages waiting, held or not).
function D:SyncInfo()
  local f = ns.Fellowship:Current()
  local n, by = ns.Comm:Pending()
  local who = {}
  for name, k in pairs(by) do who[#who + 1] = ns.Short(name) .. " " .. k end
  -- The fingerprint as text: it can be above 2^31, and the game's %d stops there ("integer overflow"; seen in game).
  ns:Debug(L.DEV_SYNC:format(f and f.v or 0, f and ("%.0f"):format(ns.Sync:Digest(f)) or "0", n,
    #who > 0 and table.concat(who, ", ") or "-", ns.Comm:Held() and L.ON or L.OFF))
end

-- The command list, one line each. "|" is the start of a colour code in the game's chat, so it is doubled to show as
-- itself (the list came out garbled; seen in game).
function D:Help()
  for line in (L.DEV_HELP .. ", "):gmatch("(.-), ") do ns:Debug((line:gsub("|", "||"))) end
end

-- /jtf debug watch [level|off]: "Altara", another character of this account (pretend), leads a fellowship with
-- Brannic and Elyra; the book follows it as if you played an alt (Fellowship/Watch.lua). "level": they level up.
-- "off": stop and forget them. Never saved: a leftover is removed at the next login.
D.WATCH_ID, D.WATCH_ALT = "dev-watch-fellowship", "Altara"
D.WATCH_HEROES = { { "Brannic", "Healer", "PALADIN" }, { "Elyra", "DPS", "MAGE" } }

function D:WatchForget()
  local alt = ns.FullName(self.WATCH_ALT)
  if ns.Watch.fid == self.WATCH_ID then ns.Watch:Close() end
  -- You took Altara's place to try it: you leave her fellowship with it.
  if ns.char.fellowshipId == self.WATCH_ID then ns.char.fellowshipId = nil end
  ns.db.fellowships[self.WATCH_ID] = nil
  if alt and ns.db.characters[alt] and ns.db.characters[alt].fellowshipId == self.WATCH_ID then ns.db.characters[alt] = nil end
  self.watchLevel = nil
end

function D:Watch(what)
  if what == "off" then self:WatchForget(); ns:Debug(L.DEV_WATCH_OFF) return end
  local alt, now = ns.FullName(self.WATCH_ALT), time()
  if what == "level" and ns.db.fellowships[self.WATCH_ID] then
    self.watchLevel = (self.watchLevel or 17) + 1
    ns.Watch:Poll(self.WATCH_ID)
    ns:Debug(L.DEV_WATCH:format(self.WATCH_ALT, self.watchLevel))
    return
  end
  self.watchLevel = self.watchLevel or 17
  local f = {
    id = self.WATCH_ID, v = 2, name = L.DEV_WATCH_FELLOWSHIP, faction = (UnitFactionGroup("player")), color = "2E6A8A", emblem = "Her_Eagle",
    leader = alt, officers = {}, invites = {}, rules = ns.Rules.New(), journey = ns.BuildJourney("classic"), chronicle = {},
    members = { [alt] = { role = "Tank", class = "WARRIOR", level = 16, joined = now - 86400 } }, updated = now - 7200,
  }
  for _, h in ipairs(self.WATCH_HEROES) do f.members[fake(h[1])] = { role = h[2], class = h[3], level = 16, joined = now - 86400 } end
  table.insert(f.chronicle, { text = L.CHR_FOUNDED:format(f.name, self.WATCH_ALT), time = now - 86400, k = "founded" })
  ns.db.fellowships[f.id] = ns.Fellowship:Sanitize(f) or f
  ns.db.characters[alt] = { name = self.WATCH_ALT, realm = ns.Realm(), class = "WARRIOR", className = LOCALIZED_CLASS_NAMES_MALE
    and LOCALIZED_CLASS_NAMES_MALE.WARRIOR or "Warrior", level = 16, fellowshipId = f.id, lastSeen = now - 7200 }
  ns.Watch:Open(alt)
  ns:Debug(L.DEV_WATCH:format(self.WATCH_ALT, self.watchLevel))
end

-- A pretend Companion of the watched fellowship answers: "I can" (WATCHA), then the levels (WATCHS).
function D:WatchAnswer(from, tag)
  local f = ns.db.fellowships[self.WATCH_ID]
  if not f then return end
  if tag == "WATCHQ" then ns.Comm:Inject(from, "WATCHA", { fid = f.id, v = f.v }) return end
  local h, lvl = {}, self.watchLevel or 17
  for i, x in ipairs(self.WATCH_HEROES) do
    -- (Each with their own count, as a real addon sends: passed-on states are taken only when newer.)
    h[ns.FullName(x[1])] = { level = lvl - (i - 1), xp = 300 + 200 * i, xpMax = 1000, class = x[3], t = time(), heard = time(), seq = lvl }
  end
  h[ns.FullName(self.WATCH_ALT)] = { level = 16, class = "WARRIOR", heard = 0, seq = 1 }
  ns.Comm:Inject(from, "WATCHS", { fid = f.id, h = h })
end

-- /jtf debug invite: "Testleader" invites you.
function D:Invite()
  local leader = fake(self.TEST_LEADER)
  ns.Comm:Inject(leader, "INV", { fid = self.TEST_ID, name = L.DEV_FELLOWSHIP, leader = leader, color = "6A3A9A", emblem = "Her_Wolf",
    heroes = 3, faction = (UnitFactionGroup("player")) })
end

-- /jtf debug group <Name>|off: pretend that a Hero (a pretend Hero you invited) is in your group, for runs.
function D:Group(name)
  self.group = self.group or {}
  if name == "" or name:lower() == "off" then wipe(self.group)
  else
    local full = ns.FullName(ns.CleanName(name))
    if full then self.group[#self.group + 1] = full end
  end
  local names = {}
  for i, n in ipairs(self.group) do names[i] = ns.Short(n) end
  ns:Debug(L.DEV_GROUP:format(#names > 0 and table.concat(names, ", ") or L.OFF))
end

-- /jtf debug kill <dungeon or raid key> [n]: as if the needed bosses of that dungeon (all, or the first n not yet
-- killed by you) died with your group. Raids once the Endgame is open.
function D:Kill(key, count)
  local f = ns.Fellowship:Current()
  if not f then ns:Debug(L.DEV_NO_FELLOWSHIP) return end
  if not ns.Endgame:Tracked(f, key) then
    local keys = {}
    for k in pairs(f.journey.place) do keys[#keys + 1] = k end
    if ns.Endgame:Open(f) then for _, r in ipairs(ns.RAIDS) do keys[#keys + 1] = r[1] end end
    table.sort(keys)
    ns:Debug(L.DEV_NO_DUNGEON:format(key, table.concat(keys, ", ")))
    return
  end
  local Cl = ns.Clears
  local names = {}
  for _, b in ipairs(Cl:Bosses(key)) do names[b.tok] = b.name end
  local mine = f.kills[key] and f.kills[key][ns.Me()] or {}
  local left = tonumber(count) or math.huge
  for _, tok in ipairs(Cl:Needed(f, key)) do
    if left > 0 and not mine[tok] then
      left = left - 1
      Cl.recent[key .. ":" .. tok] = nil
      Cl:Kill(f, key, { tok = tok, name = names[tok] or tok:sub(2) })
    end
  end
end

-- /jtf debug tourney start|next: open sign-up now (the tournament page shows even without the guild conditions), or
-- end sign-up / the round now.
function D:TourneyStep(what)
  local f = ns.Fellowship:Current()
  if not f then ns:Debug(L.DEV_NO_FELLOWSHIP) return end
  self.tourney = true
  if what == "start" then
    f.tourneyLast = nil
    local t = f.tourney
    if t and (t.phase == "signup" or t.phase == "running") then t.phase = "cancelled" end
    if f.leader == ns.Me() or f.rules.tStart == "auto" then ns.Tourney:Start()
    else ns.Comm:Inject(f.leader, "OP", { fid = f.id, v = f.v + 1, op = { k = "tourney", a = "start" }, t = time() }) end
  elseif what == "next" and f.tourney then
    local t = f.tourney
    if t.phase == "signup" then t.signupEnd = time() else t.roundEnd = time() end
    ns.Tourney:Advance(f)
  end
end

-- /jtf debug tourney big [off]: the tournament page's right side draws a sample of 20 entrants (you among them):
-- round 1 played (one upset), round 2 begun, so the round-by-round view can be seen with one character.
D.SAMPLE_NAMES = { "Aldric", "Brannic", "Corwin", "Dain", "Elyra", "Fenna", "Garrick", "Halla", "Ivor", "Jessa", "Kael",
  "Lirien", "Maren", "Nyx", "Orin", "Perrin", "Rowan", "Sable", "Tamsin" }
function D:TourneySample(on, n)
  if not on then
    self.tourneySample = nil
    ns:Debug(L.DEV_TOURNEY_BIG_OFF)
  else
    n = n or 20
    local T, realm = ns.Tournament, GetRealmName and GetRealmName() or "Realm"
    local seeds = {}
    for i = 1, n - 1 do seeds[#seeds + 1] = self.SAMPLE_NAMES[(i - 1) % #self.SAMPLE_NAMES + 1] .. "-" .. realm end
    table.insert(seeds, math.min(5, #seeds + 1), ns.Me())
    local results, upset = {}, true
    local seedOf = {}
    for i, name in ipairs(seeds) do seedOf[name] = i end
    -- Round 1: the higher seed wins, but for one upset; round 2: its first two duels.
    for _, slot in ipairs({ 1, 2 }) do
      local live = T.Live(T.Build("single", seeds, results), slot)
      for i, m in ipairs(live) do
        if slot == 1 or i <= 2 then
          local high, low = seedOf[m.a] < seedOf[m.b] and m.a or m.b, seedOf[m.a] < seedOf[m.b] and m.b or m.a
          results[m.key] = (upset and slot == 1 and low ~= ns.Me() and high ~= ns.Me()) and low or high
          if slot == 1 and results[m.key] == low then upset = false end
        end
      end
    end
    -- Levels and classes for the entrants list (pretend Heroes have no data of their own). Yours as the fellowship
    -- knows it, so a pretend level shows (it was your real level 2 among levels 18-26; check of 30 Oct 2026).
    local CLASSES = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }
    local f = ns.Fellowship:Current()
    local levels, classes = {}, {}
    for i, name in ipairs(seeds) do
      levels[name] = name == ns.Me() and (f and ns.Hero:Level(f, name) or UnitLevel("player")) or 18 + (i * 7) % 9
      classes[name] = name ~= ns.Me() and CLASSES[(i - 1) % #CLASSES + 1] or nil
    end
    self.tourneySample = { format = "single", seeds = seeds, results = results, levels = levels, classes = classes }
    self.tourney = true
    ns:Debug(L.DEV_TOURNEY_BIG:format(n))
  end
  if ns.Window:IsOpen() then ns.Window:Refresh() end
end

-- /jtf debug duel <Winner> <Loser>: as if the game said "Winner has defeated Loser in a duel". The winner's addon
-- reports it: yours, or a pretend Hero's.
function D:Duel(winner, loser)
  local f = ns.Fellowship:Current()
  local w, l = ns.FullName(ns.CleanName(winner)), ns.FullName(ns.CleanName(loser))
  if not f or not w or not l or not f.tourney then D:Help() return end
  if w == ns.Me() then
    ns.Tourney:OnDuel(w, l)
    return
  end
  for _, m in ipairs(ns.Tournament.Live(ns.Tourney:Build(f.tourney), f.tourney.slot)) do
    if (m.a == w and m.b == l) or (m.a == l and m.b == w) then
      self.fakes[w] = true
      ns.Comm:Inject(w, "OP", { fid = f.id, v = f.v + 1, op = { k = "tourney", a = "duel", key = m.key, w = w }, t = time() })
    end
  end
end

-- /jtf debug session: a session recap now, as if you had played 15 minutes with your pretend group (or with the
-- first other Adventurer): the big toast, and the Chronicle → Sessions.
function D:Session()
  local f = ns.Fellowship:Current()
  local S = ns.Session
  if not f then D:Help() return end
  if not S.cur then
    local saved = self.group
    if not saved or #saved == 0 then
      for name in pairs(f.members) do if name ~= ns.Me() then self.group = { name } break end end
    end
    S:Tick()
    self.group = saved
  end
  if not S.cur then D:Help() return end
  S.cur.start = math.min(S.cur.start, time() - 15 * 60)
  S:End()
end

-- /jtf debug emblems: how many of the emblem icons the game has (for bug reports).
function D:Emblems()
  ns:Debug(L.DEV_EMBLEMS:format(#ns.Emblems:Scan(), #ns.Emblems.ICONS))
end

function D:Command(msg)
  local cmd, a, b, c = (msg or ""):match("^(%S*)%s*(%S*)%s*(%S*)%s*(%S*)")
  cmd, b = cmd:lower(), b:lower()
  if cmd == "hero" then
    self:Hero(a, b, c)
  elseif cmd == "invite" then
    self:Invite()
  elseif cmd == "level" then
    -- Pretend my own level (or "off" for the real one); sent to the other Heroes like a real level up.
    self.myLevel = tonumber(a)
    ns:Debug(L.DEV_LEVEL:format(self.myLevel and tostring(self.myLevel) or L.OFF))
    ns.Hero:SendState()
  elseif cmd == "pace" then
    -- Pretend my XP per hour (or "off" for the measured one).
    self.pace = tonumber(a)
    ns:Debug(L.DEV_PACE:format(self.pace and tostring(self.pace) or L.OFF))
    ns.Hero:SendState()
  elseif cmd == "since" then
    -- "since mark": count from now; "since": show the page now.
    if a:lower() == "mark" then ns.Since:Mark(); ns:Debug(L.DEV_SINCE_MARK)
    else ns.Since.current = ns.Since:Digest(ns.Fellowship:Current()); ns.Window:Open("since") end
    return
  elseif cmd == "group" then
    self:Group(a)
  elseif cmd == "kill" then
    self:Kill(a:lower(), b)
  elseif cmd == "emblems" then
    self:Emblems()
  elseif cmd == "photo" then
    -- The group photo with you standing in for everyone the game cannot draw (UI/Photo.lua), to see it with one
    -- character. "photo 12": twelve in it (pretend members added).
    ns.Photo:Open({ standIns = true, extra = self:Crowd(ns.Fellowship:Current(), tonumber(a)) })
  elseif cmd == "buttons" then
    ns.Window:Open(); ns.Window:WhenBuilt(function() ns.Gallery:Show() end)
  elseif cmd == "tourney" and (a:lower() == "start" or a:lower() == "next") then
    self:TourneyStep(a:lower())
  elseif cmd == "tourney" and a:lower() == "big" then
    self:TourneySample((b or ""):lower() ~= "off")
  elseif cmd == "tourney" then
    self.tourney = onOff(a:lower())
    ns:Debug(L.DEV_TOURNEY:format(self.tourney and L.ON or L.OFF))
  elseif cmd == "duel" then
    self:Duel(a, b)
  elseif cmd == "sync" then
    self:SyncInfo()
    return
  elseif cmd == "hold" then
    -- As inside a dungeon or a boss fight: addon messages wait (on), and go out again (off).
    ns.Comm.encounter = onOff(a:lower())
    ns:Debug(L.DEV_HOLD:format(ns.Comm.encounter and L.ON or L.OFF))
  elseif cmd == "combat" then
    ns.Combat:SetSimulated(not ns.Combat.simulated)
    ns:Debug(L.DEV_COMBAT:format(ns.Combat.simulated and L.ON or L.OFF))
  elseif cmd == "toast" then
    ns.Toasts:Example()
  elseif cmd == "session" then
    self:Session()
  elseif cmd == "share" then
    -- The window an invite opens when the player's addon does not answer (nobody is contacted).
    ns.Share:Open(a ~= "" and a or "Kim", true)
    return
  elseif cmd == "watch" then
    self:Watch(a:lower())
    return
  else
    D:Help()
    return
  end
  ns.Window:Refresh()
end

-- A pretend alt left behind (/jtf debug watch, then a reload) is never kept.
ns:On("LOGIN", function() if ns.db and ns.db.fellowships[D.WATCH_ID] then D:WatchForget() end end)
