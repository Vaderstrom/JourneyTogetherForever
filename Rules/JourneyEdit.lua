-- Editing a journey (the journey editor, UI/JourneyEditor.lua; 28 Oct 2026). Plain functions on a journey table
-- ({ chapters, place }), so Create a Fellowship and Journey Admin edit the same way and the rules run in tests.
-- Chapters join up: one chapter's cap is the next one's floor, so moving the level between two chapters moves both
-- and a journey never gets a gap.
local _, ns = ...
local L = ns.L
local JE = {}
ns.JourneyEdit = JE

function JE.Copy(t)
  if type(t) ~= "table" then return t end
  local out = {}
  for k, v in pairs(t) do out[k] = JE.Copy(v) end
  return out
end

-- The level where chapter i ends and i + 1 begins. It moves between i's floor and i + 1's cap (a one-level chapter,
-- floor = cap, is allowed). True when something changed.
function JE.SetBoundary(j, i, level)
  local a, b = j.chapters[i], j.chapters[i + 1]
  if not a or not b then return false end
  level = ns.Clamp(math.floor(level + 0.5), a.floor, b.cap)
  if a.cap == level and b.floor == level then return false end
  a.cap, b.floor = level, level
  return true
end

-- A chapter's floor or cap: inside the journey that is the level it shares with its neighbour.
function JE.SetFloor(j, i, v)
  if i > 1 then return JE.SetBoundary(j, i - 1, v) end
  local c = j.chapters[1]
  if not c then return false end
  v = ns.Clamp(v, 1, c.cap)
  if c.floor == v then return false end
  c.floor = v
  return true
end

function JE.SetCap(j, i, v)
  if i < #j.chapters then return JE.SetBoundary(j, i, v) end
  local c = j.chapters[i]
  if not c then return false end
  v = ns.Clamp(v, c.floor, ns.LevelCap())
  if c.cap == v then return false end
  c.cap = v
  return true
end

function JE.Rename(j, i, name)
  name = strtrim(name or "")
  local c = j.chapters[i]
  if not c or name == "" or #name > 48 or c.name == name then return false end
  c.name = name
  return true
end

-- Splits chapter i in two at its middle level; the new chapter (after it) takes the dungeons whose best level is in
-- its half. A chapter of one level step (59-60) gets a one-level chapter after it (60-60, as for raids). Returns the
-- new chapter's number, or nil.
function JE.Split(j, i)
  local c = j.chapters[i]
  if not c or c.floor >= c.cap or #j.chapters >= ns.Journey.MAX_CHAPTERS then return nil end
  local mid = c.cap - c.floor >= 2 and math.floor((c.floor + c.cap) / 2) or c.cap
  local new = { name = L.NEW_CHAPTER, floor = mid, cap = c.cap, color = ns.PALETTE[i % #ns.PALETTE + 1] }
  c.cap = mid
  table.insert(j.chapters, i + 1, new)
  for key, p in pairs(j.place) do
    if p.ch > i then
      p.ch = p.ch + 1
    elseif p.ch == i and mid < new.cap then
      local d = ns.Dungeon(key)
      if d and (d[3] + d[4]) / 2 >= mid then p.ch = i + 1 end
    end
  end
  return i + 1
end

-- Merges chapter i with the next one: one chapter from i's floor to the next one's cap, with the dungeons and
-- milestones of both. A dungeon in both (Blackrock Depths' two halves) becomes one, needing the bosses of both.
function JE.Merge(j, i)
  local a, b = j.chapters[i], j.chapters[i + 1]
  if not a or not b then return false end
  a.cap = b.cap
  for _, m in ipairs(b.milestones or {}) do
    a.milestones = a.milestones or {}
    if #a.milestones < ns.Milestones.MAX then a.milestones[#a.milestones + 1] = m end
  end
  table.remove(j.chapters, i + 1)
  local here = {}
  for key, p in pairs(j.place) do if p.ch == i then here[ns.BaseKey(key)] = key end end
  for key, p in pairs(j.place) do
    if p.ch == i + 1 then
      local keep = here[ns.BaseKey(key)]
      if keep then
        local kp = j.place[keep]
        if kp.bosses and p.bosses then
          local has = {}
          for _, tok in ipairs(kp.bosses) do has[tok] = true end
          for _, tok in ipairs(p.bosses) do if not has[tok] then kp.bosses[#kp.bosses + 1] = tok end end
        else
          kp.bosses = nil
        end
        j.place[key] = nil
      else
        p.ch = i
      end
    elseif p.ch > i + 1 then
      p.ch = p.ch - 1
    end
  end
  return true
end

-- Removes chapter i and its dungeons; its levels go to the chapter before it (the first chapter's to nobody: the
-- journey then starts at the next one's floor). Never the last chapter left.
function JE.RemoveChapter(j, i)
  local c = j.chapters[i]
  if not c or #j.chapters <= 1 then return false end
  if i > 1 then j.chapters[i - 1].cap = c.cap end
  table.remove(j.chapters, i)
  for key, p in pairs(j.place) do
    if p.ch == i then j.place[key] = nil elseif p.ch > i then p.ch = p.ch - 1 end
  end
  return true
end

-- The placement key of dungeon `base` in chapter ch, if it is there.
function JE.PlacedIn(j, base, ch)
  for key, p in pairs(j.place) do if p.ch == ch and ns.BaseKey(key) == base then return key end end
end

-- The chapters a dungeon is in, in order.
function JE.ChaptersOf(j, base)
  local out = {}
  for key, p in pairs(j.place) do if ns.BaseKey(key) == base then out[#out + 1] = p.ch end end
  table.sort(out)
  return out
end

-- Puts a dungeon in chapter ch (Mandatory, every boss). One already elsewhere gets another placement (one dungeon
-- over several chapters, each with its own bosses); never twice in one chapter. Returns the placement key, or nil.
function JE.Add(j, base, ch)
  base = ns.BaseKey(base)
  if not ns.Dungeon(base) or not j.chapters[ch] or JE.PlacedIn(j, base, ch) then return nil end
  local n, key = 1, base
  while j.place[key] do n = n + 1; key = ns.PartKey(base, n) end
  j.place[key] = { ch = ch, role = "m" }
  return key
end

-- Moves a placement (with its role and bosses) to chapter ch; not onto a chapter that already has that dungeon.
function JE.Move(j, key, ch)
  local p = j.place[key]
  if not p or not j.chapters[ch] or p.ch == ch or JE.PlacedIn(j, ns.BaseKey(key), ch) then return false end
  p.ch = ch
  return true
end

function JE.Unplace(j, key)
  if not j.place[key] then return false end
  j.place[key] = nil
  return true
end

function JE.SetRole(j, key, role)
  local p = j.place[key]
  if not p or (role ~= "m" and role ~= "b" and role ~= "o") or p.role == role then return false end
  p.role = role
  return true
end

-- The placements of chapter ch, by the dungeons' levels: { { key, d } }.
function JE.InChapter(j, ch)
  local list = {}
  for key, p in pairs(j.place) do
    local d = ns.Dungeon(key)
    if d and p.ch == ch then list[#list + 1] = { key = key, d = d } end
  end
  table.sort(list, function(a, b) if a.d[3] ~= b.d[3] then return a.d[3] < b.d[3] end return a.key < b.key end)
  return list
end
