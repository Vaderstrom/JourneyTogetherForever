-- Since you were last here (SPEC §6): what changed in the fellowship since you last opened the book.
-- A snapshot (time, chapter, every Hero's level) is kept per character in ns.char.since. It is taken when you press
-- Continue on the page, and at logout when the book was opened in that session; so a session without opening the
-- book keeps the older snapshot and nothing is missed.
local _, ns = ...
local L = ns.L
local F, J, Hr = ns.Fellowship, ns.Journey, ns.Hero
local S = { MAX_EVENTS = 8 }
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
  -- Chronicle and counted runs, newest first.
  local list = {}
  for _, e in ipairs(f.chronicle or {}) do
    if (e.time or 0) > snap.t then list[#list + 1] = { text = e.text, time = e.time } end
  end
  for _, e in ipairs(f.history or {}) do
    if (e.time or 0) > snap.t and e.type == "run" and e.ok then list[#list + 1] = { text = ns.Clears:Text(e), time = e.time } end
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

-- The book shows the page once per session, the first time it opens (Window:Open).
function S:Pending()
  if self.shown then return false end
  self.shown = true
  local f = F:Current()
  self.current = f and self:Digest(f)
  return self.current ~= nil
end

function S:Continue()
  self:Mark()
  self.current = nil
end

ns:On("LOGIN", function()
  local f = F:Current()
  -- First time in this fellowship on this character: start counting from now.
  if f and (type(ns.char.since) ~= "table" or ns.char.since.fid ~= f.id) then S:Mark(f) end
end)
ns:On("JOINED", function() S:Mark() end)
ns:RegisterEvent("PLAYER_LOGOUT", function()
  if ns.Window and ns.Window.openedThisSession then S:Mark() end
end)
