-- What WoW Addon Webhooks for Discord posts (SPEC §7, docs/SAVED-DATA.md): on logout (and /reload) the fellowship of the
-- character logging out is written to the outbox, JourneyTogetherForeverDB.webhooks.groups[fellowshipId]: the board
-- (a kept post, drawn by Webhooks/card.html) and the news (chapter complete, dungeon cleared), with every value and
-- sentence the app shows. The app only delivers it: the rules and the wording stay here and in Locales/enUS.lua.
-- No frames here.
local _, ns = ...
local L = ns.L
local J = ns.Journey
local B = { FORMAT = 1, OUTBOX = 1, NEWS = 20, LATEST = 3 }
ns.Board = B

-- History entries the Latest list shows: runs, chapters, leader changes (SPEC §7.3).
local LATEST = { run = true, chapter = true, leader = true }
-- Standing of each Journey:Groups group, in its order.
local STANDING = { "below", "ready", "cap", "over", "away" }
local ROLE = { m = L.ROLE_MANDATORY, b = L.ROLE_BRIDGE, o = L.ROLE_OPTIONAL }

-- The Media file of a chapter's picture (Pages:SetChapterArt).
local function chapterPicture(f, n)
  local ch = f.journey.chapters[n]
  local art = ch and (ch.art or n)
  if art == "prologue" then return "ChapterPrologue" end
  return tonumber(art) and ("Chapter%02d"):format(art) or nil
end

-- "Torvi (24), Brannic (23)": like Journey's names with levels, but never "you" (the board is for the channel).
local function withLevels(f, list)
  local out = {}
  for i, name in ipairs(list) do out[i] = ("%s (%d)"):format(ns.Short(name), ns.Hero:Level(f, name)) end
  return table.concat(out, ", ")
end

local function heroes(f, n)
  local note, standing = {}, {}
  for i, g in ipairs(J:Groups(f, n)) do
    for _, r in ipairs(g.rows) do note[r.name], standing[r.name] = r.note, STANDING[i] end
  end
  local counted, catching, away = {}, {}, {}
  for _, name in ipairs(J:Counted(f)) do
    if J:CatchingUp(f, name) then catching[#catching + 1] = name else counted[#counted + 1] = name end
  end
  for name in pairs(f.members) do if J:Away(f, name) then away[#away + 1] = name end end
  table.sort(away, function(a, b)
    local la, lb = ns.Hero:Level(f, a), ns.Hero:Level(f, b)
    if la ~= lb then return la > lb end
    return a < b
  end)
  local list = {}
  local function add(names, group)
    for _, name in ipairs(names) do
      local h, m = f.heroes[name], f.members[name]
      local xp = h and tonumber(h.xp) and tonumber(h.xpMax) and h.xpMax > 0 and ns.Clamp(h.xp / h.xpMax, 0, 1) or 0
      list[#list + 1] = { name = name, short = ns.Short(name), class = (h and h.class) or m.class, level = ns.Hero:Level(f, name),
        xp = xp, group = group, standing = n and standing[name] or nil, text = n and note[name] or nil,
        seen = ns.Hero:LastSeen(f, name) }
    end
  end
  add(counted, "counted"); add(catching, "catching"); add(away, "away")
  return list
end

local function dungeons(f, n)
  local list, pacing = {}, #J:Pacing(f)
  for _, x in ipairs(J:ChapterList(f, n)) do
    local count = 0
    for _ in pairs(J:ClearedBy(f, x.key)) do count = count + 1 end
    local state = J:DungeonState(f, n, x)
    list[#list + 1] = { key = ns.BaseKey(x.key), name = x.d[2], role = ROLE[x.role] or ROLE.o, state = state,
      done = state == "cleared", text = state == "cleared" and L.BOARD_CLEARED or L.BOARD_CLEARED_BY:format(count, pacing),
      art = ns.DungeonScreen(x.key) }
  end
  return list
end

-- A picture in Media for a news post: the app converts the TGA, and posts without it when the file is missing.
local function media(name) return name and ("Media/%s.tga"):format(name) or nil end
-- A dungeon's: its loading screen from the game's files, as in the game, or else our own tile.
local function dungeonPicture(key) return ns.DungeonScreen(key) or media(ns.DUNGEON_TILE[ns.BaseKey(key)]) end

-- "Lea", "Pata": the names as the posts show them, for the app's Only when ("Who includes Lea").
local function shorts(list)
  local out = {}
  for i, name in ipairs(list) do out[i] = ns.Short(name) end
  return out
end

-- The news, newest first: chapter complete (a "chapter" History entry: Chapter N unlocked, so N - 1 is complete) and
-- dungeon cleared (a run entry with Heroes who cleared it), and pictures. Older chapter entries without their number
-- are left out.
-- id is the History entry's id; name is the short name the weekly summary lists; fields are what the app's Only when
-- may test (Webhooks/webhooks.json names them): the completed chapter's number, the dungeon, who was there.
function B:News(f)
  local list = {}
  for _, e in ipairs(f.history) do
    if #list >= self.NEWS then break end
    if e.type == "chapter" and tonumber(e.ch) and e.ch > 1 then
      local done, nxt = f.journey.chapters[e.ch - 1], f.journey.chapters[e.ch]
      if done and nxt then
        list[#list + 1] = { id = e.id, kind = "chapter", time = e.time, picture = media(chapterPicture(f, e.ch - 1)),
          name = done.name, text = L.BOARD_EV_CHAPTER:format(f.name, e.ch - 1, done.name, e.ch, nxt.floor, nxt.cap),
          fields = { n = e.ch - 1 } }
      end
    elseif e.type == "run" and type(e.cleared) == "table" and #e.cleared > 0 then
      local d = ns.Dungeon(e.key)
      list[#list + 1] = { id = e.id, kind = "clear", time = e.time, picture = dungeonPicture(e.key),
        name = d and d[2] or nil, text = L.BOARD_EV_CLEAR:format(d and d[2] or tostring(e.key), ns.Clears.AndList(e.cleared)),
        fields = { dungeon = d and d[2] or nil, who = shorts(e.cleared) } }
    end
  end
  -- The pictures taken on this account with Take a picture (Fellowship/Moments.lua): screenshot is when, for the app
  -- to find the game's file (WoWScrnShot_MMDDYY_HHMMSS.jpg, the computer's own clock) and post it. Posted only where
  -- the player draws "Pictures from runs" to, which is nowhere until they do (Webhooks/webhooks.json).
  for i, p in ipairs(ns.Moments:Pictures(f)) do
    if i > self.NEWS then break end
    local d = p.key and ns.Dungeon(p.key)
    local who = p.names or { p.by }
    local names = ns.Clears.AndList(who)
    list[#list + 1] = { id = ("picture:%s:%d"):format(p.by or "", p.time), kind = "picture", time = p.time, screenshot = p.time,
      name = d and d[2] or nil, text = d and (p.photo and L.BOARD_EV_PHOTO or L.BOARD_EV_PICTURE):format(d[2], names)
        or (p.photo and L.BOARD_EV_PHOTO_0 or L.BOARD_EV_PICTURE_0):format(names),
      fields = { dungeon = d and d[2] or nil, who = shorts(who) } }
  end
  table.sort(list, function(a, b) return a.time > b.time end)
  while #list > self.NEWS do table.remove(list) end
  return list
end

-- The board of fellowship f (docs/SAVED-DATA.md): the data Webhooks/card.html draws.
function B:Build(f)
  local cur = J:Current(f)
  local n = cur and cur.n
  local b = {
    format = self.FORMAT, saved = time(), by = ns.Me(), addon = ns.VERSION,
    fellowship = { id = f.id, name = f.name, faction = f.faction, color = f.color, emblem = f.emblem, leader = f.leader },
    journey = cur and "chapter" or "complete",
    heroes = heroes(f, n),
    latest = {},
  }
  for _, e in ipairs(f.history) do
    if #b.latest >= self.LATEST then break end
    if LATEST[e.type] then b.latest[#b.latest + 1] = ns.Clears:Text(e) end
  end
  if not cur then
    b.title = L.BN_JOURNEY_DONE
    b.summary = L.BOARD_SUMMARY_DONE:format(f.name, L.BN_JOURNEY_DONE)
    return b
  end
  local nodes, banner = J:Stages(f, n)
  b.title = L.CHIP_CHAPTER:format(cur.n, cur.of, cur.floor, cur.cap)
  b.chapter = { n = cur.n, of = cur.of, name = cur.name, floor = cur.floor, cap = cur.cap, picture = chapterPicture(f, n) }
  b.summary = L.BOARD_SUMMARY:format(f.name, b.title, banner.title)
  b.stageColor = banner.color -- the current stage's colour, as on the Chapter page's track
  b.stages = {}
  for i, x in ipairs(nodes) do b.stages[i] = { key = x.key, text = x.label, state = x.state } end
  b.dungeons = dungeons(f, n)
  if #b.dungeons == 0 then b.level = banner.stage == "level" and banner.text or nil end
  local below = J:Below(f, n)
  if #below > 0 then b.waiting = L.BN_WAITING_TEXT:format(J:FloorLevel(f, f.journey.chapters[n]), withLevels(f, below)) end
  return b
end

-- Fellowship f as an outbox group (WoW Addon Webhooks for Discord, its docs/PLUGINS.md §3). numbers: each Adventurer's
-- level, for the weekly summary.
function B:Group(f)
  local board = self:Build(f)
  local count, numbers = ns.Fellowship:Count(f), {}
  for _, h in ipairs(board.heroes) do numbers[h.short] = h.level end
  return { name = f.name, saved = board.saved, by = board.by, color = f.color,
    sub = (count == 1 and L.BOARD_SUB_ONE or L.BOARD_SUB):format(ns.Short(f.leader), count),
    kept = { board = { text = board.summary, data = board } }, news = self:News(f), numbers = numbers }
end

-- Write the current fellowship's group and drop the groups of fellowships no character on this account is in.
-- (Until 29 Oct 2026 the Journey Together Companion read db.board; the outbox replaces it.)
function B:Write()
  local db = ns.db
  if not db then return end
  db.board = nil
  local out = db.webhooks
  if type(out) ~= "table" or out.format ~= self.OUTBOX or type(out.groups) ~= "table" then
    out = { format = self.OUTBOX, groups = {} }
    db.webhooks = out
  end
  local f = ns.Fellowship:Current()
  if f and not f.disbanded then out.groups[f.id] = self:Group(f) end
  local keep = {}
  for _, c in pairs(db.characters or {}) do if c.fellowshipId then keep[c.fellowshipId] = true end end
  if f and not f.disbanded then keep[f.id] = true end
  for id in pairs(out.groups) do if not keep[id] then out.groups[id] = nil end end
end

ns:RegisterEvent("PLAYER_LOGOUT", function() B:Write() end)
