-- Since last time (the Overview, SPEC §4.4): what changed in the fellowship since you last opened the book.
-- A snapshot (time, chapter, every Adventurer's level, the lines of the last week) is kept per character in
-- ns.char.since. It is taken when the book closes (or the game logs out) after the Overview showed Since last time; so a
-- session without looking keeps the older snapshot and nothing is missed.
-- A line is new when the snapshot did not have it, not when its time is later (the release review of 10 Nov 2026):
-- a run or a fall held in an instance arrives after you looked, with the time it happened, and a time from another
-- player's PC is not comparable with this PC's. Lines older than LATE are left out.
local _, ns = ...
local L = ns.L
local F, J, Hr = ns.Fellowship, ns.Journey, ns.Hero
local S = { MAX_EVENTS = 8, LATE = 7 * 86400 }
-- The challenges' lines it shows, as Recent history did: the falls and the shared lives (SPEC §4.8).
local FALLS = { fallen = true, life = true, candle = true }
ns.Since = S

-- The Chronicle's lines: the fellowship's log, counted runs, firsts, falls and shared lives, and the pictures taken on
-- this account, each { key, time, text, icon, run }. A run is known by its dungeon and when it was: its text grows as
-- names come in, its time moves earlier when a report from earlier in the run arrives late, and a copy from another
-- Adventurer (SNAP) brings its own id; so it is the same run within Clears.SAME_RUN, as Clears merges them. A first
-- by its holder (an earlier time arriving late is the same first).
local function lines(f)
  local list = {}
  local function add(key, t, text, icon, run)
    t = tonumber(t)
    if t then list[#list + 1] = { key = key, time = t, text = text, icon = icon, run = run } end
  end
  local function k(...) return table.concat({ ... }, ":") end
  -- Each line with its kind's icon, as on the History page (the same icon on every line said nothing; 9 Nov 2026).
  for _, e in ipairs(f.chronicle or {}) do add(k("c", tostring(e.time), tostring(e.text)), e.time, e.text, F.LOG_ICON[e.k]) end
  for _, e in ipairs(f.history or {}) do
    if e.type == "run" and e.ok then add(k("r", tostring(e.key)), e.time, ns.Clears:Text(e), "hist_run", true) end
  end
  for _, e in ipairs(ns.Firsts:Entries(f)) do
    add(k("f", tostring(e.key), tostring(e.who)), e.time, e.text, "hist_first")
  end
  for _, e in ipairs(ns.Challenges:Entries(f)) do
    if FALLS[e.icon] then add(k("x", e.icon, tostring(e.who), tostring(e.time)), e.time, e.text, ns.Clears.ICON[e.icon]) end
  end
  for _, p in ipairs(ns.Moments:Pictures(f)) do
    add(k("p", tostring(p.by), tostring(p.time)), p.time, ns.Moments.PictureText(p), "bn_group")
  end
  return list
end

function S:Snapshot(f)
  local levels, seen, now = {}, {}, time()
  for name in pairs(f.members) do levels[name] = Hr:Level(f, name) end
  -- (A week by this PC's clock: a line from a PC some hours off still falls inside it.)
  for _, x in ipairs(lines(f)) do
    if x.time > now - self.LATE then
      if x.run then seen[x.key] = seen[x.key] or {}; table.insert(seen[x.key], x.time) else seen[x.key] = true end
    end
  end
  return { fid = f.id, t = now, cur = J:CurrentIndex(f), levels = levels, seen = seen }
end

function S:Mark(f)
  f = f or F:Current()
  if f then ns.char.since = self:Snapshot(f) end
end

-- What changed: { ago, chapter (text or nil), events = { { text, time } }, levels = { { name, from, to } } }, or nil
-- when nothing did (or there is no snapshot of this fellowship yet).
function S:Digest(f)
  local snap = ns.char.since
  if not f or type(snap) ~= "table" or snap.fid ~= f.id or not snap.t then return nil end
  local d = { ago = ns.TimeAgo(snap.t), events = {}, levels = {} }
  local cur = J:CurrentIndex(f)
  if cur > (snap.cur or cur) then
    local ch = f.journey.chapters[cur]
    d.chapter = ch and L.SINCE_CHAPTER:format(ns.Journey.Roman(cur), ch.name) or L.BN_JOURNEY_DONE
  end
  -- The lines the snapshot did not have, newest first (an older snapshot has no list: by time, as before).
  local function had(x)
    local s = snap.seen[x.key]
    if not x.run then return s ~= nil end
    for _, t in ipairs(type(s) == "table" and s or {}) do
      if math.abs(t - x.time) < ns.Clears.SAME_RUN then return true end
    end
    return false
  end
  local list = {}
  for _, x in ipairs(lines(f)) do
    local new
    if type(snap.seen) == "table" then new = not had(x) and x.time > snap.t - self.LATE else new = x.time > snap.t end
    if new then list[#list + 1] = x end
  end
  table.sort(list, function(a, b) return a.time > b.time end)
  for i = 1, math.min(#list, self.MAX_EVENTS) do d.events[i] = list[i] end
  d.more = math.max(0, #list - self.MAX_EVENTS)
  -- Levels gained, most first.
  for name in pairs(f.members) do
    local was, now = (snap.levels or {})[name], Hr:Level(f, name)
    if was and now > was then d.levels[#d.levels + 1] = { name = name, from = was, to = now } end
  end
  table.sort(d.levels, function(a, b)
    if a.to - a.from ~= b.to - b.from then return a.to - a.from > b.to - b.from end
    return a.name < b.name
  end)
  if not d.chapter and #d.events == 0 and #d.levels == 0 then return nil end
  return d
end

ns:On("LOGIN", function()
  local f = F:Current()
  -- First time in this fellowship on this character: start counting from now.
  if f and (type(ns.char.since) ~= "table" or ns.char.since.fid ~= f.id) then S:Mark(f) end
end)
ns:On("JOINED", function() S:Mark() end)
-- The Overview showed Since last time for your own fellowship (not another character's, not the first tour's sample,
-- not during /jtf check): closing the book starts it over, so the next time says what came after ("since you last
-- opened the book").
function S:Shown(f) if f == F:Current() and not ns.News.Dev() then self.shown = true end end
function S:Closed()
  if self.shown and not ns.News.Dev() then self.shown = nil; self:Mark() end
end
ns:RegisterEvent("PLAYER_LOGOUT", function() S:Closed() end)
