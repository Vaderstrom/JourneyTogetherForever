-- Since last time (the Overview, SPEC §4.4): what changed in the fellowship since you last opened the book.
-- A snapshot (time, chapter, every Adventurer's level) is kept per character in ns.char.since. It is taken when the book
-- closes (or the game logs out) after the Overview showed Since last time; so a session without looking keeps the older
-- snapshot and nothing is missed.
local _, ns = ...
local L = ns.L
local F, J, Hr = ns.Fellowship, ns.Journey, ns.Hero
local S = { MAX_EVENTS = 8 }
-- The challenges' lines it shows, as Recent history did: the falls and the shared lives (SPEC §4.8).
local FALLS = { fallen = true, life = true, candle = true }
ns.Since = S

function S:Snapshot(f)
  local levels = {}
  for name in pairs(f.members) do levels[name] = Hr:Level(f, name) end
  return { fid = f.id, t = time(), cur = J:CurrentIndex(f), levels = levels }
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
  -- The Chronicle's lines, newest first: the fellowship's log, counted runs, firsts, falls and shared lives, and the
  -- pictures taken on this account.
  local list = {}
  local function add(t, text, icon) if (tonumber(t) or 0) > snap.t then list[#list + 1] = { text = text, time = t, icon = icon } end end
  -- Each line with its kind's icon, as on the History page (the same icon on every line said nothing; 9 Nov 2026).
  for _, e in ipairs(f.chronicle or {}) do add(e.time, e.text, F.LOG_ICON[e.k]) end
  for _, e in ipairs(f.history or {}) do if e.type == "run" and e.ok then add(e.time, ns.Clears:Text(e), "hist_run") end end
  for _, e in ipairs(ns.Firsts:Entries(f)) do add(e.time, e.text, "hist_first") end
  for _, e in ipairs(ns.Challenges:Entries(f)) do if FALLS[e.icon] then add(e.time, e.text, ns.Clears.ICON[e.icon]) end end
  for _, p in ipairs(ns.Moments:Pictures(f)) do add(p.time, ns.Moments.PictureText(p), "bn_group") end
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
-- shortcut: lines are compared by when they happened, so one held in an instance until after you looked (a run, a fall)
-- is in the Chronicle and its toast only; keep an arrival time per line if players miss them.
function S:Shown(f) if f == F:Current() and not ns.News.Dev() then self.shown = true end end
function S:Closed()
  if self.shown and not ns.News.Dev() then self.shown = nil; self:Mark() end
end
ns:RegisterEvent("PLAYER_LOGOUT", function() S:Closed() end)
