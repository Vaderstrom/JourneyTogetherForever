-- Hero state (docs/ARCHITECTURE.md §1 HeroState, §2): what each Hero shares about themselves.
--   HELLO / HI   at login: my state and the fellowship version; HI is the answer (no further answer)
--   STATE        my level, XP, rested XP, zone, guild (on change, and as a heartbeat every 5 minutes)
--   GEAR         what I wear (on change, and with HELLO / HI)
--   RELAY / RELAYG  another Adventurer's state / gear, passed on (below)
-- A Hero counts as online while their messages keep coming (heartbeat), and as offline as soon as a whisper to them
-- fails ("No player named ..."). Everything stored for another Hero carries the time it was heard ("Seen ...").
-- Passed on (27 Oct 2026): each Adventurer counts their own states (seq) and gear (gseq). HELLO and HI carry the
-- counts this addon has of everyone; the other side sends back the states and gear it has newer, so Lea's level
-- reaches Noa through Pata even when Lea and Noa never play at the same time. Only the owner raises a count, so
-- the highest count is always the newest; no clock is compared.
local _, ns = ...
local L = ns.L
local F, Comm = ns.Fellowship, ns.Comm
local Hr = { HEARTBEAT = 300, ONLINE_FOR = 420, XP_EVERY = 60, timers = {} }
ns.Hero = Hr

-- Gear slots in the mockup's order: { label key, inventory slot }.
Hr.SLOTS = {
  { "SLOT_HEAD", 1 }, { "SLOT_NECK", 2 }, { "SLOT_SHOULDER", 3 }, { "SLOT_BACK", 15 }, { "SLOT_CHEST", 5 },
  { "SLOT_WRIST", 9 }, { "SLOT_HANDS", 10 }, { "SLOT_WAIST", 6 }, { "SLOT_LEGS", 7 }, { "SLOT_FEET", 8 },
  { "SLOT_FINGER", 11 }, { "SLOT_FINGER", 12 }, { "SLOT_TRINKET", 13 }, { "SLOT_TRINKET", 14 },
  { "SLOT_MAINHAND", 16 }, { "SLOT_OFFHAND", 17 }, { "SLOT_RANGED", 18 },
}

-- An item's icon by its ID (the game knows it without the item in the cache), or nil.
function Hr.ItemIcon(id)
  local fn = C_Item and C_Item.GetItemIconByID or GetItemIcon
  return id and fn and fn(id) or nil
end

-- The game's empty-slot picture for an inventory slot (the character sheet's), or a plain one.
local SLOT_NAME = { [1] = "HeadSlot", [2] = "NeckSlot", [3] = "ShoulderSlot", [15] = "BackSlot", [5] = "ChestSlot",
  [9] = "WristSlot", [10] = "HandsSlot", [6] = "WaistSlot", [7] = "LegsSlot", [8] = "FeetSlot", [11] = "Finger0Slot",
  [12] = "Finger1Slot", [13] = "Trinket0Slot", [14] = "Trinket1Slot", [16] = "MainHandSlot", [17] = "SecondaryHandSlot",
  [18] = "RangedSlot" }
function Hr.SlotPicture(slot)
  local name = SLOT_NAME[slot]
  if name and GetInventorySlotInfo then
    local ok, _, tex = pcall(GetInventorySlotInfo, name)
    if ok and tex then return tex end
  end
  return "Interface\\PaperDoll\\UI-Backpack-EmptySlot"
end

-- Item quality from the colour code of an item link (no item cache needed).
local QUALITY = { ["9d9d9d"] = 0, ffffff = 1, ["1eff00"] = 2, ["0070dd"] = 3, a335ee = 4, ff8000 = 5, e6cc80 = 6, ["00ccff"] = 7 }

-- itemID, name, quality from an item link.
function Hr.ParseLink(link)
  if type(link) ~= "string" then return nil end
  local color = link:match("|c%x%x(%x%x%x%x%x%x)")
  local id = tonumber(link:match("|Hitem:(%d+)"))
  local name = link:match("|h%[(.-)%]|h")
  return id, name, color and QUALITY[color:lower()] or 1
end

---------------------------------------------------------------------------
-- My own state
---------------------------------------------------------------------------
function Hr:MyState()
  local className, class = UnitClass("player")
  local _, race = UnitRace("player") -- the race's background on Inspect, like the game's dressing room
  local guild, _, rankIndex = GetGuildInfo("player")
  -- /jtf debug level <n> pretends another level (retail characters are far above the journey's levels).
  local lvl = (ns.Dev and ns.Dev.myLevel) or UnitLevel("player")
  -- run: in a fellowship run right now (levels gained there may pass the cap, Fellowship/Progress.lua).
  local f = F:Current()
  local xp, xpMax = UnitXP("player"), UnitXPMax("player")
  -- A max-level character has no XP bar: with a pretend level, pretend 40% of a level too.
  if ns.Dev and ns.Dev.myLevel and (xpMax or 0) <= 0 then xp, xpMax = 400, 1000 end
  return { level = lvl, xp = xp, xpMax = xpMax, rested = GetXPExhaustion() or 0,
    zone = GetZoneText and GetZoneText() or nil, class = class, className = className, race = race, guild = guild,
    gm = guild ~= nil and rankIndex == 0 or nil, run = f and ns.Progress:InRun(f) or nil,
    pace = ns.Pace and ns.Pace:PerHour() or nil, ver = ns.VERSION, t = time(), alts = self:MyAlts() }
end

-- The other characters on this account the addon has seen: they may watch this fellowship while you play them.
function Hr:MyAlts()
  local me, out = ns.Me(), {}
  for key in pairs(ns.db and ns.db.characters or {}) do
    if key ~= me and #out < 20 then out[#out + 1] = key end
  end
  table.sort(out)
  return out
end

-- { [n] = { id, name, ilvl, q } } in the order of SLOTS (empty slots left out).
function Hr:MyGear()
  local gear = {}
  for n, s in ipairs(self.SLOTS) do
    local link = GetInventoryItemLink("player", s[2])
    local id, name, q = Hr.ParseLink(link)
    if id then
      local ilvl = C_Item and C_Item.GetDetailedItemLevelInfo and C_Item.GetDetailedItemLevelInfo(link) or nil
      gear[n] = { id = id, name = name or "", ilvl = tonumber(ilvl) or 0, q = q }
    end
  end
  return gear
end

---------------------------------------------------------------------------
-- What is known about each Hero (stored in the fellowship, so it survives a reload and goes with a copy)
---------------------------------------------------------------------------
local function heroOf(f, name)
  f.heroes = f.heroes or {}
  f.heroes[name] = f.heroes[name] or {}
  return f.heroes[name]
end

local function num(v) return type(v) == "number" and v or nil end
local function str(v) return type(v) == "string" and v or nil end

-- relayed: passed on by another addon; taken only when its count is newer than ours. Returns true when stored.
function Hr:Store(f, name, s, heardAt, relayed)
  if type(s) ~= "table" or not f.members[name] then return false end
  local h = heroOf(f, name)
  local seq = num(s.seq)
  if relayed and (not seq or seq <= (h.seq or 0)) then return false end
  h.seq = math.max(h.seq or 0, seq or 0)
  h.level, h.xp, h.xpMax, h.rested = num(s.level) or h.level, num(s.xp), num(s.xpMax), num(s.rested)
  h.zone, h.class, h.className, h.guild, h.gm = str(s.zone), str(s.class) or h.class, str(s.className) or h.className, str(s.guild), s.gm == true or nil
  h.run = s.run == true or nil
  h.race = str(s.race) or h.race
  h.pace = num(s.pace) -- XP per hour of play (Fellowship/Pace.lua)
  h.ver = str(s.ver) or h.ver -- the Hero's addon version
  -- A Hero with a newer version: say once per session that an update is out, in chat and as a toast that opens the
  -- Adventurers page (it says so at the top until you update; 28 Oct 2026).
  if name ~= ns.Me() and not Hr.toldNewer and ns.NewerVersion(h.ver, ns.VERSION) then
    Hr.toldNewer = true
    ns:Print(L.NEWER_VERSION:format(h.ver), true)
    ns:Toast("version", L.TOAST_VERSION_TITLE, L.TOAST_VERSION_TEXT:format(ns.Short(name), h.ver, ns.VERSION), "heroes")
  end
  -- The other characters on this Companion's account: they may watch the fellowship (Fellowship/Watch.lua).
  if type(s.alts) == "table" then
    local alts = {}
    for _, a in ipairs(s.alts) do if type(a) == "string" and #a <= 64 and #alts < 20 then alts[#alts + 1] = a end end
    h.alts = alts
  end
  h.t = num(s.t) or time()
  -- (Passed on: when they were last heard by whoever passed it on; a failed whisper to them still stands.)
  if relayed then h.heard = heardAt or h.heard else h.heard, h.offline = heardAt or time(), nil end
  -- The member list keeps class, level and guild too (used for the tournament conditions and lists).
  local m = f.members[name]
  m.level, m.class, m.guild, m.gm = h.level or m.level, h.class or m.class, h.guild, h.gm
  -- A newcomer who reached the floor now counts like everyone (Rules/Journey.lua).
  if m.catching then ns.Journey:CaughtUp(f, name) end
  return true
end

-- n: the owner's gear count; relayed: taken only when newer than ours.
function Hr:StoreGear(f, name, gear, t, n, relayed)
  if type(gear) ~= "table" or not f.members[name] then return false end
  local cur = heroOf(f, name)
  if relayed and (not n or n <= (cur.gseq or 0)) then return false end
  cur.gseq = math.max(cur.gseq or 0, n or 0)
  local clean = {}
  for i = 1, #self.SLOTS do
    local g = gear[i]
    if type(g) == "table" and num(g.id) then clean[i] = { id = g.id, name = str(g.name) or "", ilvl = num(g.ilvl) or 0, q = num(g.q) or 1 } end
  end
  cur.gear, cur.gearTime = clean, num(t) or time()
  return true
end

function Hr:Get(f, name) return f.heroes and f.heroes[name] end

-- Online: me always; others while their heartbeat keeps coming and no whisper to them has failed.
function Hr:Online(f, name)
  -- Watching from another character: the watched one is not the one playing.
  if ns.Watch and ns.Watch.rendering and not ns.Watch.demo and name == ns.Watch.as then return false end
  if name == ns.Me() then return true end
  local h = self:Get(f, name)
  return h ~= nil and not h.offline and h.heard ~= nil and time() - h.heard < self.ONLINE_FOR
end

-- When this Hero was last heard from (or joined, if never). Me: now (not the character a watched fellowship is drawn
-- as: it said "Seen just now" for a character last played hours ago; seen in the tour).
function Hr:LastSeen(f, name)
  if name == ns.Me() and not (ns.Watch and ns.Watch.rendering and not ns.Watch.demo) then return time() end
  local h = self:Get(f, name)
  return (h and h.heard) or (f.members[name] and f.members[name].joined) or time()
end

-- Level: from the shared state, else from the member list.
function Hr:Level(f, name)
  local h = self:Get(f, name)
  return (h and h.level) or (f.members[name] and f.members[name].level) or 1
end

-- Status text and colour (the mockup's status): away, below the floor, over the cap, at the cap, online, seen.
-- Uses the current chapter (the first chapter until chapter progress arrives with M4).
function Hr:Status(f, name)
  local away = ns.Journey:Away(f, name)
  if away then return away == "forced" and L.STATUS_AWAY_FORCED or L.STATUS_AWAY, "ink2" end
  local text, color = self:Standing(f, name)
  if text then return text, color end
  if self:Online(f, name) then return L.STATUS_ONLINE, "3E9A52" end
  return L.STATUS_SEEN:format(ns.TimeAgo(self:LastSeen(f, name))), "ink2"
end

-- Where a Hero stands in the chapter: below the floor, over or at the cap, or the journey done; nil in between.
function Hr:Standing(f, name)
  local ch = F:CurrentChapter(f)
  if not ch then return L.STATUS_DONE, "3E9A52" end
  local lvl, r = self:Level(f, name), f.rules
  if lvl < ch.floor - r.floorTol then return L.STATUS_TO_FLOOR:format(ch.floor - r.floorTol - lvl), "C8762E" end
  if lvl > ch.cap + r.capTol then return L.STATUS_OVER_CAP, "C0392B" end
  if lvl >= ch.cap then return L.STATUS_AT_CAP, "B8463E" end
  return nil
end

-- Presence (SPEC §4.8): the mark on a card, in the colours of the game's friends list (UI.Presence).
--   away     grey        away from the journey (I'm away, set by the Leader, or not seen for the rule's days)
--   afk      yellow      the game says AFK (it tells for friends, guild members and your group)
--   online   green       their addon is heard
--   quiet    green ring  the game says online, but their addon is not heard (turned off, or a trial account)
--   offline  red         neither
-- Also returns whether they are online at all (addon or game), and why they are away ("self", "forced", "auto").
function Hr:Presence(f, name)
  local game
  -- (Following another character's fellowship, "me" is that character, not the one being played: it showed online
  -- with "Addon not heard"; seen in the check, 28 Oct 2026.)
  local watching = ns.Watch and ns.Watch.rendering and not ns.Watch.demo
  if name == ns.Me() and not watching then game = { online = true, afk = UnitIsAFK and UnitIsAFK("player") or nil }
  else game = ns.Friends:Status(name) end
  local addon = self:Online(f, name)
  local online = addon or (game ~= nil and game.online == true)
  local away = ns.Journey:Away(f, name)
  if away then return "away", online, away end
  if online and game and game.afk then return "afk", true end
  if addon then return "online", true end
  return online and "quiet" or "offline", online
end

-- The presence in words: the word by the mark, a detail under it (when last seen, or why away; nil when there is
-- nothing to add) and a sentence for the tooltip.
function Hr:PresenceText(f, name)
  local kind, online, away = self:Presence(f, name)
  local seen = L.STATUS_SEEN:format(ns.TimeAgo(self:LastSeen(f, name)))
  if kind == "away" then
    local detail = away == "forced" and L.PRESENCE_BY_LEADER or (online and L.PRESENCE_ONLINE_NOW or seen)
    local days = math.floor((time() - self:LastSeen(f, name)) / 86400)
    local tip = away == "forced" and L.PRESENCE_TIP_FORCED or (away == "auto" and L.PRESENCE_TIP_AUTO:format(days) or L.PRESENCE_TIP_AWAY)
    return L.PRESENCE_AWAY, detail, tip
  elseif kind == "afk" then return L.PRESENCE_AFK, nil, L.PRESENCE_TIP_AFK
  elseif kind == "online" then return L.PRESENCE_ONLINE, nil, L.PRESENCE_TIP_ONLINE
  elseif kind == "quiet" then return L.PRESENCE_ONLINE, L.PRESENCE_QUIET, L.PRESENCE_TIP_QUIET end
  return L.PRESENCE_OFFLINE, seen, L.PRESENCE_TIP_OFFLINE:format(ns.TimeAgo(self:LastSeen(f, name)))
end

-- Addon versions (SPEC §4.8): the newest one in the fellowship (yours or another Hero's) and who has it. A
-- development copy ("@project-version@") never counts.
function Hr:NewestVersion(f)
  local me = ns.Me()
  local newest, by = ns.ParseVersion(ns.VERSION) and ns.VERSION or nil, me
  for _, name in ipairs(F:Members(f)) do
    local h = name ~= me and self:Get(f, name)
    local ver = h and h.ver
    if ns.ParseVersion(ver) and (not newest or ns.NewerVersion(ver, newest)) then newest, by = ver, name end
  end
  return newest, newest and by or nil
end

-- A Hero's version when it is older than the newest in the fellowship, with the newest and who has it; nil when up
-- to date or unknown. The characters of this account share this addon (a watched alt's last version is not theirs).
function Hr:OldVersion(f, name)
  local h = self:Get(f, name)
  local mine = name == ns.Me() or (ns.db and ns.db.characters and ns.db.characters[name] ~= nil)
  local ver = mine and ns.VERSION or (h and h.ver)
  local newest, by = self:NewestVersion(f)
  if ns.NewerVersion(newest, ver) then return ver, newest, by end
  return nil
end

-- XP towards the next level: fraction done, fraction rested (on top of it), and the text "82% to 29  ·  rested".
-- Nil when this Hero has not shared XP yet.
function Hr:XP(f, name)
  local h = self:Get(f, name)
  if not h or not h.xpMax or h.xpMax <= 0 then return nil end
  local pct = ns.Clamp((h.xp or 0) / h.xpMax, 0, 1)
  local rested = math.min(1 - pct, (h.rested or 0) / h.xpMax)
  local lvl = self:Level(f, name)
  return pct, rested, L.XP_TO:format(math.floor(pct * 100 + 0.5), lvl + 1) .. (rested > 0 and L.XP_RESTED or ""),
    L.XP_WAY:format(math.floor(pct * 100 + 0.5), lvl + 1)
end

-- Class name to show (shared by the Hero, or the game's name for the class).
function Hr:ClassName(f, name)
  local h, m = self:Get(f, name), f.members[name]
  local token = (h and h.class) or (m and m.class) -- (a name no longer in the fellowship: a past entrant)
  return (h and h.className) or (LOCALIZED_CLASS_NAMES_MALE and token and LOCALIZED_CLASS_NAMES_MALE[token]) or token or "", token
end

---------------------------------------------------------------------------
-- Sending
---------------------------------------------------------------------------
local function others(f)
  local me, list = ns.Me(), {}
  for name in pairs(f.members) do if name ~= me then list[#list + 1] = name end end
  return list
end

-- Keeps my own entry up to date and sends my state to every other Hero.
-- My next count: above anything of mine another addon has passed on (after a reinstall it started again at 1).
local function nextCount(key, have)
  ns.char[key] = math.max(ns.char[key] or 0, have or 0) + 1
  return ns.char[key]
end

-- The counts this addon has of everyone's state and gear (sent with HELLO and HI).
function Hr:Counts(f)
  local sq, gq = {}, {}
  for name, h in pairs(f.heroes or {}) do
    if f.members[name] then sq[name], gq[name] = h.seq, h.gseq end
  end
  return sq, gq
end

function Hr:SendState(tag, to)
  local f = F:Current()
  if not f then return end
  local s = self:MyState()
  local mine = self:Get(f, ns.Me())
  s.seq = nextCount("seq", mine and mine.seq)
  self:Store(f, ns.Me(), s)
  local data = { fid = f.id, v = f.v, s = s }
  if tag == "HELLO" or tag == "HI" then
    -- What every copy must agree on, the counts of everyone's state and gear, and the kills (Fellowship/Clears.lua).
    data.h, data.k = ns.Sync:Digest(f), ns.Clears:Digest(f)
    data.sq, data.gq = self:Counts(f)
  end
  -- Only the newest one waits: held in a dungeon, a state every minute piled up and held back everything behind it
  -- (code review, 30 Oct 2026).
  for _, name in ipairs(to and { to } or others(f)) do Comm:Send(name, tag or "STATE", data, false, true) end
  ns:Fire("HEROES")
end

function Hr:SendGear(to)
  local f = F:Current()
  if not f then return end
  local g, t = self:MyGear(), time()
  -- A new count only when the gear changed (it is passed on to whoever has an older count).
  local mine = self:Get(f, ns.Me())
  local S = ns.Serialize
  local same = mine and mine.gear and mine.gseq and S.Encode(mine.gear) == S.Encode(g)
  local n = same and mine.gseq or nextCount("gseq", mine and mine.gseq)
  if not same then self:StoreGear(f, ns.Me(), g, t, n) end
  local gt = same and mine.gearTime or t
  for _, name in ipairs(to and { to } or others(f)) do Comm:Send(name, "GEAR", { fid = f.id, g = g, t = gt, n = n }, false, true) end
end

-- Sends `to` the states and gear of others that this addon has newer than they do (their counts sq, gq).
function Hr:Relay(f, to, sq, gq)
  if type(sq) ~= "table" then return end -- an older addon: nothing to compare
  gq = type(gq) == "table" and gq or {}
  local me = ns.Me()
  -- Never count below what another addon has of me.
  ns.char.seq = math.max(ns.char.seq or 0, tonumber(sq[me]) or 0)
  ns.char.gseq = math.max(ns.char.gseq or 0, tonumber(gq[me]) or 0)
  local states, gears = {}, {}
  for name, h in pairs(f.heroes or {}) do
    if f.members[name] and name ~= to and name ~= me then
      if (h.seq or 0) > (tonumber(sq[name]) or 0) then
        states[name] = { level = h.level, xp = h.xp, xpMax = h.xpMax, rested = h.rested, zone = h.zone, class = h.class,
          className = h.className, race = h.race, guild = h.guild, gm = h.gm, pace = h.pace, ver = h.ver, t = h.t,
          alts = h.alts, seq = h.seq, heard = h.heard }
      end
      if h.gear and (h.gseq or 0) > (tonumber(gq[name]) or 0) then gears[name] = { g = h.gear, t = h.gearTime, n = h.gseq } end
    end
  end
  if next(states) then Comm:Send(to, "RELAY", { fid = f.id, h = states }) end
  if next(gears) then Comm:Send(to, "RELAYG", { fid = f.id, g = gears }) end
end

-- At login: say hello (with my state and version) and show what I wear.
function Hr:Hello()
  self:SendState("HELLO")
  self:SendGear()
end

-- Runs fn once after sec seconds, however often it is asked for in between.
function Hr:Soon(key, sec, fn)
  if self.timers[key] then return end
  self.timers[key] = C_Timer.NewTimer(sec, function() Hr.timers[key] = nil; fn() end)
end

---------------------------------------------------------------------------
-- Receiving
---------------------------------------------------------------------------
local function fellowshipFor(sender, d)
  if type(d) ~= "table" then return nil end
  local f = F:Get(d.fid)
  -- A fellowship this addon does not know (its saved data was lost): ask for it (Sync:Unknown).
  if not f then ns.Sync:Unknown(sender, d.fid) return nil end
  if not f.members[sender] or not f.members[ns.Me()] then return nil end
  return f
end

-- HELLO and HI also compare versions: whoever is behind gets (or asks for) the whole fellowship.
local function hello(sender, d, answer)
  local f = fellowshipFor(sender, d)
  if not f then ns.Sync:NotMember(sender, d) return end
  Hr:Store(f, sender, d.s)
  -- Others' state and gear we have newer, and kills that differ (players who are not online at the same time).
  Hr:Relay(f, sender, d.sq, d.gq)
  ns.Clears:Compare(f, sender, d.k)
  local v = tonumber(d.v) or 0
  if v > f.v then ns.Sync:AskSnap(sender, f) elseif v < f.v then ns.Sync:SendSnap(sender, f)
  elseif d.h and d.h ~= ns.Sync:Digest(f) then
    -- Same version, different content (changes made apart): the leader's copy wins, else the one whose name sorts
    -- first. The other side takes it and makes its own missing changes again on top (Sync:Replay).
    local me = ns.Me()
    local winner = (me == f.leader or sender == f.leader) and f.leader or (me < sender and me or sender)
    if winner == me then ns.Sync:SendSnap(sender, f) else ns.Sync:AskSnap(sender, f) end
  end
  if answer then
    Hr:SendState("HI", sender)
    Hr:SendGear(sender)
    ns.Quests:Send(sender)
  end
  ns:Fire("HEROES")
end

Comm:On("HELLO", function(sender, d) hello(sender, d, true) end)
Comm:On("HI", function(sender, d) hello(sender, d, false) end)
Comm:On("STATE", function(sender, d)
  local f = fellowshipFor(sender, d)
  if not f then return end
  Hr:Store(f, sender, d.s)
  -- Their copy is newer: we missed a change (Sync:AskSoon).
  if (tonumber(d.v) or 0) > f.v then ns.Sync:AskSoon(sender, f) end
  ns:Fire("HEROES")
end)
Comm:On("GEAR", function(sender, d)
  local f = fellowshipFor(sender, d)
  if f then Hr:StoreGear(f, sender, d.g, d.t, tonumber(d.n)); ns:Fire("HEROES") end
end)
-- Passed on by another Adventurer: taken only when newer than what we have.
Comm:On("RELAY", function(sender, d)
  local f = fellowshipFor(sender, d)
  if not f or type(d.h) ~= "table" then return end
  local me, any = ns.Me(), false
  for name, s in pairs(d.h) do
    if type(name) == "string" and name ~= me and name ~= sender and type(s) == "table" then
      local heard = tonumber(s.heard)
      if Hr:Store(f, name, s, heard and math.min(heard, time()) or nil, true) then any = true end
    end
  end
  if any then ns:Fire("HEROES") end
end)
Comm:On("RELAYG", function(sender, d)
  local f = fellowshipFor(sender, d)
  if not f or type(d.g) ~= "table" then return end
  local me, any = ns.Me(), false
  for name, x in pairs(d.g) do
    if type(name) == "string" and name ~= me and name ~= sender and type(x) == "table" then
      if Hr:StoreGear(f, name, x.g, x.t, tonumber(x.n), true) then any = true end
    end
  end
  if any then ns:Fire("HEROES") end
end)

-- A whisper to this Hero failed: they are offline.
ns:On("OFFLINE", function(name)
  local f = F:Current()
  local h = f and Hr:Get(f, name)
  if h and h.offline == nil then h.offline = true; ns:Fire("HEROES") end
end)

---------------------------------------------------------------------------
-- Game events
---------------------------------------------------------------------------
ns:On("LOGIN", function()
  C_Timer.After(5, function() Hr:Hello() end)
  C_Timer.NewTicker(Hr.HEARTBEAT, function() Hr:SendState() end)
end)
-- After joining (or founding), say hello at once.
ns:On("JOINED", function() Hr:Hello() end)
ns:RegisterEvent("PLAYER_LEVEL_UP", function() C_Timer.After(1, function() Hr:SendState() end) end)
ns:RegisterEvent("PLAYER_XP_UPDATE", function() Hr:Soon("xp", Hr.XP_EVERY, function() Hr:SendState() end) end)
ns:RegisterEvent("UPDATE_EXHAUSTION", function() Hr:Soon("xp", Hr.XP_EVERY, function() Hr:SendState() end) end)
ns:RegisterEvent("ZONE_CHANGED_NEW_AREA", function() Hr:Soon("zone", 10, function() Hr:SendState() end) end)
ns:RegisterEvent("PLAYER_GUILD_UPDATE", function() Hr:Soon("guild", 10, function() Hr:SendState() end) end)
ns:RegisterEvent("PLAYER_EQUIPMENT_CHANGED", function() Hr:Soon("gear", 5, function() Hr:SendGear() end) end)
