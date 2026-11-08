-- Hero state (docs/ARCHITECTURE.md §1 HeroState, §2): what each Hero shares about themselves.
--   HELLO / HI   at login: my state and the fellowship version; HI is the answer (no further answer)
--   STATE        my level, XP, rested XP, zone, guild (on change, and as a heartbeat every 5 minutes)
--   GEAR         what I wear (on change, and with HELLO / HI)
--   RELAY / RELAYG / RELAYQ  another Adventurer's state / gear / quests, passed on (below)
-- A Hero counts as online while their messages keep coming (heartbeat), and as offline as soon as a whisper to them
-- fails ("No player named ..."). Everything stored for another Hero carries the time it was heard ("Seen ...").
-- Passed on (27 Oct 2026): each Adventurer counts their own states (seq) and gear (gseq). HELLO and HI carry the
-- counts this addon has of everyone; the other side sends back the states and gear it has newer, so Lea's level
-- reaches Noa through Pata even when Lea and Noa never play at the same time. Only the owner raises a count, so
-- the highest count is always the newest; no clock is compared. Quests go the same way by the time their owner sent
-- them (only the owner's clock: 2 Nov 2026), and a state passed on carries the firsts and tallies too.
-- Every state also carries the fellowship's fingerprints, so copies that differ are found while both are online
-- (Sync:CompareSoon, Clears:CompareSoon), not only at the next login.
local _, ns = ...
local L = ns.L
local F, Comm = ns.Fellowship, ns.Comm
local Hr = { HEARTBEAT = 300, ONLINE_FOR = 420, XP_EVERY = 30, timers = {} }
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
  -- A pretend level has no XP bar of its own: pretend 40% of it, its size from the game's table (the real one was
  -- level 1's in the check of 7 Nov 2026).
  if ns.Dev and ns.Dev.myLevel and ns.Dev.myLevel ~= UnitLevel("player") then
    xpMax = ns.Pace.LEVEL_XP[lvl] or 1000
    xp = math.floor(xpMax * 0.4)
  end
  return { level = lvl, xp = xp, xpMax = xpMax, rested = GetXPExhaustion() or 0,
    zone = GetZoneText and GetZoneText() or nil, class = class, className = className, race = race, guild = guild,
    gm = guild ~= nil and rankIndex == 0 or nil, run = f and ns.Progress:InRun(f) or nil,
    pace = ns.Pace and ns.Pace:PerHour() or nil, ver = ns.VERSION, t = time(), alts = self:MyAlts(),
    mark = ns.Watch and ns.Watch:Mark() or nil, -- this account's mark: any character of it may follow (U68)
    -- My deeds and tallies, for the fellowship's firsts (Fellowship/Firsts.lua).
    deeds = ns.Firsts and (ns.Firsts:State()) or nil, tally = ns.Firsts and select(2, ns.Firsts:State()) or nil,
    -- My online minutes in this tournament round, for the referee's walkovers (Fellowship/Tourney.lua).
    ton = f and f.heroes and f.heroes[ns.Me()] and f.heroes[ns.Me()].ton or nil,
    -- Reminders turned off (Settings, U100): whoever would remind me is told.
    noRemind = not ns.Settings:ToastOn("dremind") or nil }
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
  h.noRemind = s.noRemind == true or nil
  h.race = str(s.race) or h.race
  h.pace = num(s.pace) -- XP per hour of play (Fellowship/Pace.lua)
  h.ver = str(s.ver) or h.ver -- the Hero's addon version
  -- A Hero with a newer version: say once per session that an update is out, in chat and as a toast that opens the
  -- Adventurers page (it says so at the top until you update; 28 Oct 2026).
  if name ~= ns.Me() then Hr:TellNewer(name, h.ver, "heroes") end
  -- The other characters on this Companion's account: they may watch the fellowship (Fellowship/Watch.lua).
  if type(s.alts) == "table" then
    local alts = {}
    for _, a in ipairs(s.alts) do if type(a) == "string" and #a <= 64 and #alts < 20 then alts[#alts + 1] = a end end
    h.alts = alts
  end
  if type(s.mark) == "string" and #s.mark <= 32 then h.mark = s.mark end
  -- Deeds for the firsts: only the known ones, as times; the tallies as counts (Fellowship/Firsts.lua).
  if type(s.deeds) == "table" and ns.Firsts then
    local d = {}
    for k in pairs(ns.Firsts.KNOWN) do d[k] = num(s.deeds[k]) end
    h.deeds = d
  end
  if type(s.tally) == "table" then h.tally = { falls = num(s.tally.falls), quests = num(s.tally.quests), runs = num(s.tally.runs) } end
  if ns.Tourney then ns.Tourney:StoreMinutes(f, name, s.ton) end
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

-- The others, without those the game just said are offline (a whisper to them failed and nothing came since): quests
-- and gear wait for them, and come with the answer to their HELLO when they log in (U76, 7 Nov 2026).
function Hr:Reachable(f)
  local me, list = ns.Me(), {}
  for name in pairs(f.members) do
    local h = f.heroes and f.heroes[name]
    if name ~= me and not (h and h.offline) then list[#list + 1] = name end
  end
  return list
end

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
  if f.falls and ns.Challenges:Fallen(f, name) then return L.STATUS_FALLEN, Hr.FALLEN end
  if F:IsFriend(f, name) then return L.STATUS_FRIEND, Hr.FRIEND end
  local away = ns.Journey:Away(f, name)
  if away then return away == "forced" and L.STATUS_AWAY_FORCED or L.STATUS_AWAY, "ink2" end
  local text, color = self:Standing(f, name)
  if text then return text, color end
  if self:Online(f, name) then return L.STATUS_ONLINE, "3E9A52" end
  return L.STATUS_SEEN:format(ns.TimeAgo(self:LastSeen(f, name))), "ink2"
end

-- Where a Hero stands in the chapter: below the floor, over or at the cap, or the journey done; nil in between. The
-- Fallen of a survival challenge (SPEC §9): Fallen, in a muted violet (honoured, not an error). A Friend of the
-- fellowship (SPEC §1.1): in a calm teal, never a warning (they stand outside the floor and the cap).
Hr.FALLEN = "6E5A82"
Hr.FRIEND = "3A7A78"
function Hr:Standing(f, name)
  if f.falls and ns.Challenges:Fallen(f, name) then return L.STATUS_FALLEN, Hr.FALLEN end
  if F:IsFriend(f, name) then return L.STATUS_FRIEND, Hr.FRIEND end
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
local others = ns.Others

-- Keeps my own entry up to date and sends my state to every other Hero.
-- My next count: above anything of mine another addon has passed on (after a reinstall it started again at 1).
local function nextCount(key, have)
  ns.char[key] = math.max(ns.char[key] or 0, have or 0) + 1
  return ns.char[key]
end

-- The counts this addon has of everyone's state and gear, and the time of their quests (sent with HELLO and HI).
function Hr:Counts(f)
  local sq, gq, qq = {}, {}, {}
  for name, h in pairs(f.heroes or {}) do
    if f.members[name] then sq[name], gq[name], qq[name] = h.seq, h.gseq, h.questsTime end
  end
  return sq, gq, qq
end

function Hr:SendState(tag, to)
  local f = F:Current()
  if not f then return end
  local s = self:MyState()
  local mine = self:Get(f, ns.Me())
  s.seq = nextCount("seq", mine and mine.seq)
  self:Store(f, ns.Me(), s)
  -- What every copy must agree on and the kills (Fellowship/Clears.lua), with every state; the leadership as this
  -- copy has it (Sync:Beats). At login also the counts of everyone's state, gear and quests.
  local data = { fid = f.id, v = f.v, s = s, h = ns.Sync:Digest(f), k = ns.Clears:Digest(f), lv = f.lv or 0, ld = f.leader }
  -- The fingerprints of the rest, to find copies that should agree and do not (Fellowship/Conflicts.lua).
  for k, v in pairs(ns.Conflicts:Prints(f)) do data[k] = v end
  if tag == "HELLO" or tag == "HI" then data.sq, data.gq, data.qq = self:Counts(f) end
  -- Only the newest one waits: held in a dungeon, a state every minute piled up and held back everything behind it
  -- (code review, 30 Oct 2026).
  Comm:SendAll(to and { to } or others(f), tag or "STATE", data, false, true)
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
  Comm:SendAll(to and { to } or Hr:Reachable(f), "GEAR", { fid = f.id, g = g, t = gt, n = n }, false, true)
end

-- Sends `to` the states, gear and quests of others that this addon has newer than they do (their counts sq, gq, qq).
function Hr:Relay(f, to, sq, gq, qq)
  if type(sq) ~= "table" then return end -- an older addon: nothing to compare
  gq = type(gq) == "table" and gq or {}
  local me = ns.Me()
  -- Never count below what another addon has of me.
  ns.char.seq = math.max(ns.char.seq or 0, tonumber(sq[me]) or 0)
  ns.char.gseq = math.max(ns.char.gseq or 0, tonumber(gq[me]) or 0)
  local states, gears, quests = {}, {}, {}
  for name, h in pairs(f.heroes or {}) do
    if f.members[name] and name ~= to and name ~= me then
      if (h.seq or 0) > (tonumber(sq[name]) or 0) then
        states[name] = { level = h.level, xp = h.xp, xpMax = h.xpMax, rested = h.rested, zone = h.zone, class = h.class,
          className = h.className, race = h.race, guild = h.guild, gm = h.gm, pace = h.pace, ver = h.ver, t = h.t,
          alts = h.alts, mark = h.mark, seq = h.seq, heard = h.heard, deeds = h.deeds, tally = h.tally, ton = h.ton }
      end
      if h.gear and (h.gseq or 0) > (tonumber(gq[name]) or 0) then gears[name] = { g = h.gear, t = h.gearTime, n = h.gseq } end
      -- (An older addon sends no quest times: nothing is passed on to it.)
      if type(qq) == "table" and h.quests and (h.questsTime or 0) > (tonumber(qq[name]) or 0) then
        quests[name] = ns.Quests:Stored(h)
      end
    end
  end
  if next(states) then Comm:Send(to, "RELAY", { fid = f.id, h = states }) end
  if next(gears) then Comm:Send(to, "RELAYG", { fid = f.id, g = gears }) end
  if next(quests) then Comm:Send(to, "RELAYQ", { fid = f.id, q = quests }) end
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
  -- Others' state, gear and quests we have newer, and kills that differ (players who are not online at the same time).
  Hr:Relay(f, sender, d.sq, d.gq, d.qq)
  ns.Clears:Compare(f, sender, d.k)
  -- The fellowship itself: the one behind gets the other copy; at the same version with other content (changes made
  -- apart), both sides pick the same copy (Sync:Beats), and the other side makes its own changes again on top of it.
  ns.Sync:Compare(sender, f, d)
  ns.Conflicts:Compare(sender, f, d)
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
  -- A copy that differs (a change lost on the way, two at once), and kills that differ: found while both are online.
  ns.Sync:CompareSoon(sender, f, d)
  ns.Clears:CompareSoon(f, sender, d.k)
  ns.Conflicts:Compare(sender, f, d)
  ns:Fire("HEROES")
end)
Comm:On("GEAR", function(sender, d)
  local f = fellowshipFor(sender, d)
  if f then Hr:StoreGear(f, sender, d.g, d.t, tonumber(d.n)); ns:Fire("HEROES", nil, "gear") end
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
-- Quests passed on: taken only when their owner sent them later than the ones we have.
Comm:On("RELAYQ", function(sender, d)
  local f = fellowshipFor(sender, d)
  if not f or type(d.q) ~= "table" then return end
  local me, any, done = ns.Me(), false, false
  for name, x in pairs(d.q) do
    local h = f.heroes and f.heroes[name]
    local t = type(x) == "table" and tonumber(x.t)
    if type(name) == "string" and name ~= me and name ~= sender and t and t > ((h and h.questsTime) or 0) then
      done = ns.Quests:Store(f, name, x, t) or done
      any = true
    end
  end
  if any then ns:Fire("HEROES", nil, not done and "quests" or nil) end
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
  if any then ns:Fire("HEROES", nil, "gear") end
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
---------------------------------------------------------------------------
-- Is a newer version out? (the owner, 6 Nov 2026: "report themselves if there is a newer version out", as other
-- addons do). Fellowship members tell it in their state; anyone else with the addon in your guild or group tells it
-- with a short announcement ("V:1.0.5" on JTF, GUILD, PARTY or RAID), sent at login and when the group changes, and
-- in answer to an older one (so its player hears about the update too). Each channel at most once in ANNOUNCE_EVERY.
-- Never inside an instance (Midnight rules) and never from a development copy (its version is not a number).
---------------------------------------------------------------------------
Hr.ANNOUNCE_EVERY = 120
Hr.announced = {}

-- Says once a session that version ver is out (in chat, and a toast that opens page, if any).
function Hr:TellNewer(from, ver, page)
  if self.toldNewer or not ns.NewerVersion(ver, ns.VERSION) then return end
  -- (A version far ahead is not believed: more than one major version, from someone playing a joke.)
  local v, mine = ns.ParseVersion(ver), ns.ParseVersion(ns.VERSION)
  if v[1] > mine[1] + 1 then return end
  self.toldNewer = true
  ns:Print(L.NEWER_VERSION:format(ver), true)
  ns:Toast("version", L.TOAST_VERSION_TITLE, L.TOAST_VERSION_TEXT:format(ns.Short(from), ver, ns.VERSION), page)
end

function Hr:Announce(channel)
  if not ns.ParseVersion(ns.VERSION) or not (C_ChatInfo and C_ChatInfo.SendAddonMessage) then return end
  if IsInInstance() then return end
  if channel == "GUILD" and not IsInGuild() then return end
  if (channel == "PARTY" or channel == "RAID") and not IsInGroup() then return end
  local now = GetTime()
  if self.announced[channel] and now - self.announced[channel] < self.ANNOUNCE_EVERY then return end
  self.announced[channel] = now
  C_ChatInfo.SendAddonMessage(Comm.PREFIX, "V:" .. ns.VERSION, channel)
end

local function groupChannel() return IsInRaid() and "RAID" or "PARTY" end

ns:RegisterEvent("CHAT_MSG_ADDON", function(_, prefix, msg, channel, sender)
  if issecretvalue and (issecretvalue(prefix) or issecretvalue(msg) or issecretvalue(sender) or issecretvalue(channel)) then return end
  if prefix ~= Comm.PREFIX or type(msg) ~= "string" or not sender then return end
  if channel ~= "GUILD" and channel ~= "PARTY" and channel ~= "RAID" then return end
  local ver = msg:match("^V:(v?%d+%.%d+[%w%.%-]*)$")
  if not ver or ns.FullName(sender) == ns.Me() then return end
  Hr:TellNewer(sender, ver)
  if ns.NewerVersion(ns.VERSION, ver) then Hr:Announce(channel) end
end)
ns:On("LOGIN", function() C_Timer.After(20, function() Hr:Announce("GUILD"); Hr:Announce(groupChannel()) end) end)
ns:RegisterEvent("GROUP_ROSTER_UPDATE", function() Hr:Soon("announce", 10, function() Hr:Announce(groupChannel()) end) end)

-- After joining (or founding), say hello at once.
ns:On("JOINED", function() Hr:Hello() end)
ns:RegisterEvent("PLAYER_LEVEL_UP", function() C_Timer.After(ns.LEVEL_UP.state, function() Hr:SendState() end) end)
ns:RegisterEvent("PLAYER_XP_UPDATE", function() Hr:Soon("xp", Hr.XP_EVERY, function() Hr:SendState() end) end)
ns:RegisterEvent("UPDATE_EXHAUSTION", function() Hr:Soon("xp", Hr.XP_EVERY, function() Hr:SendState() end) end)
ns:RegisterEvent("ZONE_CHANGED_NEW_AREA", function() Hr:Soon("zone", 10, function() Hr:SendState() end) end)
ns:RegisterEvent("PLAYER_GUILD_UPDATE", function() Hr:Soon("guild", 10, function() Hr:SendState() end) end)
ns:RegisterEvent("PLAYER_EQUIPMENT_CHANGED", function() Hr:Soon("gear", 5, function() Hr:SendGear() end) end)
