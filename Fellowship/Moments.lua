-- Moments (SPEC §4.7, 29 Oct 2026; the Chronicle's second tab): the journey's big moments, kept as they happened, and
-- the pictures you took.
--   f.moments = { list = { moment, ... } newest first (at most MAX), seen = { [id] = true }, lv = { [name] = level } }
--   moment = { id, k, time, ch, key, mid, name, level, names, levels }
--     k = "chapter"    chapter ch began, so ch - 1 is complete      id "chapter:<ch>"
--         "end"        every chapter is complete                     id "end"
--         "clear"      the fellowship cleared dungeon key, the first time   id "clear:<key>"
--         "milestone"  milestone mid (name) of chapter ch is done     id "ms:<mid>"
--         "level"      names[1] reached level, the journey's last cap  id "level:<name>"
--         "champion"   names[1] won the Guild Master tournament        id "champion:<time>"
--     names: who was there (a chapter: the Adventurers then). levels[name]: their level then, only when the addon saw
--     it happen (moments found later, from the Chronicle or a copy from another Adventurer, have none).
--   ns.db.pictures = { { time, f, key, ch, names, by }, ... } newest first: the pictures taken with Take a picture
--     (UI/Picture.lua) on this account. The game saves them in its Screenshots folder, which an addon cannot open, so
--     the Moments tab counts them with the moment they belong to, and Discord gets them through the outbox (Board.lua).
-- Moments come from what the fellowship keeps anyway (Chronicle, clears, milestones, levels, the chronicle), so every
-- Adventurer's addon finds the same ones, also after being away. Nothing is sent. No frames here.
local _, ns = ...
local L = ns.L
local F, J = ns.Fellowship, ns.Journey
-- RECENT: a moment seen this soon after it happened keeps the levels of that time. A picture belongs to a moment
-- taken from BEFORE seconds before it to AFTER seconds after it.
local M = { MAX = 100, PICTURES = 200, RECENT = 3600, BEFORE = 600, AFTER = 1800 }
ns.Moments = M

-- The moments kept for f. New (the first time this version sees the fellowship): what is done already and has no
-- time of its own (milestones, levels) is noted as seen, not shown as happening now.
function M:Data(f)
  local a = f.moments
  if type(a) == "table" and type(a.list) == "table" and type(a.seen) == "table" then return a, false end
  a = { list = {}, seen = {}, lv = {} }
  f.moments = a
  return a, true
end

-- Keeps moment m (unless its id is already kept). Returns it when new.
function M:Add(f, m)
  local a = self:Data(f)
  if a.seen[m.id] then return nil end
  a.seen[m.id] = true
  m.ch = m.ch or math.min(J:CurrentIndex(f), #f.journey.chapters)
  if m.names and not m.levels and math.abs(time() - m.time) <= self.RECENT then
    m.levels = {}
    for _, n in ipairs(m.names) do m.levels[n] = ns.Hero:Level(f, n) end
  end
  local pos = #a.list + 1
  for i, x in ipairs(a.list) do if x.time <= m.time then pos = i break end end
  table.insert(a.list, pos, m)
  while #a.list > self.MAX do table.remove(a.list) end
  return m
end

local function recent(t) return time() - t <= M.RECENT end

-- Finds the moments f has reached that are not kept yet. Returns how many were added.
function M:Check(f)
  if not f or not f.journey then return 0 end
  local a, new = self:Data(f)
  local chapters, n0 = f.journey.chapters, #a.list
  -- Chapters: the History's "chapter" entries (chapter ch unlocked), the first time each.
  for i = #f.history, 1, -1 do
    local e = f.history[i]
    if e.type == "chapter" and tonumber(e.ch) and e.ch > 1 and chapters[e.ch] then
      self:Add(f, { id = "chapter:" .. e.ch, k = "chapter", time = e.time, ch = e.ch, names = recent(e.time) and F:Members(f) or nil })
    end
  end
  if #chapters > 0 and J:CurrentIndex(f) > #chapters and not a.seen["end"] then
    local t = new and f.history[1] and f.history[1].time or time()
    self:Add(f, { id = "end", k = "end", time = t, ch = #chapters, names = recent(t) and F:Members(f) or nil })
  end
  -- First clears: the newest run in the History where someone cleared it (else when the clears were marked).
  for key, who in pairs(f.runs) do
    if not a.seen["clear:" .. key] and J:Cleared(f, key) then
      local run
      for _, e in ipairs(f.history) do
        if e.type == "run" and e.key == key and type(e.cleared) == "table" and #e.cleared > 0 then run = e break end
      end
      local t, names = 0, {}
      if run then t, names = run.last or run.time, run.names
      else
        for name, at in pairs(who) do t = math.max(t, at); names[#names + 1] = name end
        table.sort(names)
      end
      local p = f.journey.place[key]
      self:Add(f, { id = "clear:" .. key, k = "clear", time = t, key = key, names = names, ch = p and p.ch or nil })
    end
  end
  -- Milestones: a ticked one at its tick; the others when this addon sees them done.
  for n = 1, #chapters do
    for _, ms in ipairs(ns.Milestones:List(f, n)) do
      local id = "ms:" .. ms.id
      if not a.seen[id] and ns.Milestones:Progress(f, ms).done then
        local tick = f.ticks and f.ticks[ms.id]
        if new and not tick then a.seen[id] = true
        else
          self:Add(f, { id = id, k = "milestone", time = tick and tick.t or time(), ch = n, mid = ms.id, name = ms.name,
            names = tick and { tick.by } or J:Pacing(f) })
        end
      end
    end
  end
  -- The journey's last cap (level 60 in Forever): for an Adventurer seen below it before. Above it the first time
  -- (a newcomer at a higher level, a retail character) is no moment.
  local last = chapters[#chapters]
  local top = last and last.cap
  a.lv = type(a.lv) == "table" and a.lv or {}
  for name in pairs(f.members) do
    -- (Only a level the addon has heard: an unknown one is not "below".)
    local h = f.heroes and f.heroes[name]
    local lvl = (h and h.level) or f.members[name].level
    local before = a.lv[name]
    if top and lvl and before and before < top and lvl >= top then
      self:Add(f, { id = "level:" .. name, k = "level", time = time(), names = { name }, level = top })
    end
    a.lv[name] = lvl
  end
  for name in pairs(a.lv) do if not f.members[name] then a.lv[name] = nil end end
  -- The Guild Master tournament's champion (the chronicle's line).
  for _, e in ipairs(f.chronicle) do
    if e.k == "champion" and e.who then self:Add(f, { id = "champion:" .. e.time, k = "champion", time = e.time, names = { e.who } }) end
  end
  return #a.list - n0
end

-- The moments of f, newest first.
function M:List(f)
  self:Check(f)
  return f.moments.list
end

function M:Find(f, id)
  for _, m in ipairs(self:List(f)) do if m.id == id then return m end end
  return nil
end

---------------------------------------------------------------------------
-- Pictures
---------------------------------------------------------------------------
-- One picture taken with Take a picture, in dungeon key (when one), with the Adventurers in the group; or a group
-- photo (UI/Photo.lua, photo = true) with those in it.
function M:Picture(f, key, names, photo)
  local db = ns.db
  db.pictures = type(db.pictures) == "table" and db.pictures or {}
  local p = { time = time(), key = key, by = ns.Me(), photo = photo or nil }
  if f then p.f, p.names, p.ch = f.id, names or ns.Clears:GroupHeroes(f), math.min(J:CurrentIndex(f), #f.journey.chapters) end
  table.insert(db.pictures, 1, p)
  while #db.pictures > self.PICTURES do table.remove(db.pictures) end
  return p
end

-- The pictures of f, newest first.
function M:Pictures(f)
  local out = {}
  for _, p in ipairs(type(ns.db.pictures) == "table" and ns.db.pictures or {}) do
    if f and p.f == f.id then out[#out + 1] = p end
  end
  return out
end

-- Forgets the pictures of fellowship fid (the self-test's and the tour's, at their end).
function M:Forget(fid)
  local list = type(ns.db.pictures) == "table" and ns.db.pictures or {}
  for i = #list, 1, -1 do if list[i].f == fid then table.remove(list, i) end end
end

-- The pictures taken around moment m, oldest first (a clear: in that dungeon).
function M:PicturesOf(f, m)
  local out = {}
  for _, p in ipairs(self:Pictures(f)) do
    if p.time >= m.time - self.BEFORE and p.time <= m.time + self.AFTER and (m.k ~= "clear" or not p.key or p.key == m.key) then
      table.insert(out, 1, p)
    end
  end
  return out
end

---------------------------------------------------------------------------
-- Texts
---------------------------------------------------------------------------
local function dname(key) local d = ns.Dungeon(key); return d and d[2] or tostring(key) end

-- The moment's title ("Chapter III begins").
function M:Title(m)
  local who = m.names and m.names[1] and ns.Short(m.names[1]) or ""
  if m.k == "chapter" then return L.MO_CHAPTER:format(J.Roman(m.ch))
  elseif m.k == "end" then return L.MO_END
  elseif m.k == "clear" then return L.MO_CLEAR:format(dname(m.key))
  elseif m.k == "milestone" then return L.MO_MILESTONE:format(m.name or "")
  elseif m.k == "level" then return L.MO_LEVEL:format(who, m.level or 60)
  elseif m.k == "champion" then return L.MO_CHAMPION:format(who) end
  return ""
end

-- What happened, in a sentence or two.
function M:Text(f, m)
  local ch = f.journey.chapters[m.ch]
  if m.k == "chapter" then
    local done = f.journey.chapters[m.ch - 1]
    local text = ch and L.MO_CHAPTER_TEXT:format(J.Roman(m.ch), ch.name, ch.floor, ch.cap) or ""
    if done then text = L.MO_CHAPTER_DONE:format(J.Roman(m.ch - 1), done.name) .. " " .. text end
    return text
  elseif m.k == "end" then return L.MO_END_TEXT
  elseif m.k == "clear" then return ch and L.MO_CLEAR_TEXT:format(dname(m.key), J.Roman(m.ch), ch.name) or L.MO_CLEAR_TEXT_0:format(dname(m.key))
  elseif m.k == "milestone" then return L.MO_MILESTONE_TEXT:format(J.Roman(m.ch), ch and ch.name or "", m.name or "")
  elseif m.k == "level" then return L.MO_LEVEL_TEXT:format(ns.Short(m.names[1]), m.level or 60)
  elseif m.k == "champion" then return L.MO_CHAMPION_TEXT:format(ns.Short(m.names[1])) end
  return ""
end

-- "Victor (21), Noa (20) and Pata (19)", each in their class colour (light: on the page's parchment).
function M:Who(f, m, light)
  local out = {}
  for i, n in ipairs(m.names or {}) do
    local member = f.members[n]
    local h = f.heroes and f.heroes[n]
    local hex = ns.ClassHex(member and member.class or (h and h.class), light)
    local text = ns.Short(n)
    if hex then text = "|cff" .. hex .. text .. "|r" end
    local lvl = m.levels and m.levels[n]
    out[i] = lvl and L.MO_WHO_LEVEL:format(text, lvl) or text
  end
  if #out <= 1 then return out[1] or "" end
  return table.concat(out, ", ", 1, #out - 1) .. L.AND .. out[#out]
end

-- "29 Oct 2026" and "Thursday 29 October 2026, 14:15".
function M.Day(t) return date(L.MO_DAY, t) end
function M.When(t) return date(L.MO_WHEN, t) end
function M.Clock(t) return date("%H:%M", t) end

-- After Clears' own check (it writes the History's chapter entries first: registered earlier, Fellowship/Clears.lua).
local function check() local f = F:Current(); if f then M:Check(f) end end
ns:On("FELLOWSHIP", check)
ns:On("HEROES", check)
ns:On("JOINED", check)
