-- Where each dungeon's and raid's entrance is (U97, the owner, 8 Nov 2026), for the Dungeon page's Waypoint. Two
-- sources: a shipped table of the Classic entrances from public guides (zone and map position as the game shows
-- them; checked in the game for the Deadmines), and what the fellowship learns: where an Adventurer stood a moment
-- before walking into an instance is kept in the fellowship (op "entrance") and wins over the table. WoW Forever's own
-- dungeons are learned only. Not learned from the Dungeon Finder's teleport (IsInLFGDungeon) or a summon (a warlock's
-- or a meeting stone's: CONFIRM_SUMMON in the last SUMMONED seconds; the review of 8 Nov 2026: it taught Orgrimmar).
local _, ns = ...
local F = ns.Fellowship
local E = { SAMPLE = 2, FRESH = 15, SUMMONED = 180 }
ns.Entrances = E

local BRM = { zone = "Searing Gorge", x = 34.8, y = 85.3 } -- Blackrock Mountain's door from Searing Gorge
local SM = { zone = "Tirisfal Glades", x = 84.9, y = 31.1 } -- the Scarlet Monastery's courtyard
local DM = { zone = "Feralas", x = 59.1, y = 45.0 } -- Dire Maul
E.SHIPPED = {
  rfc = { zone = "Orgrimmar", x = 52.0, y = 49.6 }, wc = { zone = "The Barrens", x = 46.0, y = 36.4 },
  dm = { zone = "Westfall", x = 42.5, y = 71.7 }, sfk = { zone = "Silverpine Forest", x = 44.9, y = 67.9 },
  bfd = { zone = "Ashenvale", x = 14.2, y = 14.0 }, gnomer = { zone = "Dun Morogh", x = 24.4, y = 39.8 },
  rfk = { zone = "The Barrens", x = 42.3, y = 89.9 }, rfd = { zone = "The Barrens", x = 50.8, y = 92.9 },
  smgy = SM, smlib = SM, smarm = SM, smcath = SM,
  ulda = { zone = "Badlands", x = 44.6, y = 12.1 }, zf = { zone = "Tanaris", x = 38.7, y = 20.0 },
  mara = { zone = "Desolace", x = 29.1, y = 62.5 }, st = { zone = "Swamp of Sorrows", x = 69.9, y = 53.5 },
  brd = BRM, lbrs = BRM, ubrs = BRM, mc = BRM, bwl = BRM,
  dme = DM, dmw = DM, dmn = DM,
  strat = { zone = "Eastern Plaguelands", x = 31.3, y = 15.7 }, scholo = { zone = "Western Plaguelands", x = 69.7, y = 73.2 },
  ony = { zone = "Dustwallow Marsh", x = 52.6, y = 76.8 }, zg = { zone = "Stranglethorn Vale", x = 53.9, y = 17.6 },
  aq20 = { zone = "Silithus", x = 36.5, y = 93.9 }, aq40 = { zone = "Silithus", x = 28.6, y = 92.4 },
}

local plain = function(v) return v ~= nil and not (issecretvalue and issecretvalue(v)) end
local function pos(v) v = tonumber(v); return v and v > 0 and v <= 100 and math.floor(v * 10 + 0.5) / 10 or nil end

-- A dungeon's entrance: { zone, x, y, map, learned }, the fellowship's learned one first; nil when none is known.
function E:Get(f, key)
  local base = ns.BaseKey(key)
  local e = f and f.entrances and f.entrances[base]
  if e then return { zone = e.zone, x = e.x, y = e.y, map = e.map, learned = true } end
  local s = self.SHIPPED[base]
  return s and { zone = s.zone, x = s.x, y = s.y } or nil
end

-- A waypoint at the entrance (or its place in chat where the game allows none: QuestLists:Waypoint).
function E:Waypoint(f, key)
  local e = self:Get(f, key)
  if not e then return nil end
  local d = ns.Dungeon(key)
  return ns.QuestLists:Waypoint({ by = d and d[2] or key, zone = e.zone, x = e.x, y = e.y }, e.map or ns.QuestLists:MapOf(e))
end

function E:Apply(f, op)
  local key, x, y = op.key, pos(op.x), pos(op.y)
  if type(key) ~= "string" or not ns.Dungeon(key) or ns.BaseKey(key) ~= key or not (x and y) then return false end
  f.entrances = f.entrances or {}
  -- The first seen stays, by the server's clock (st), so two Adventurers walking in at once leave every copy with the
  -- same one, whichever change came first (the review of 8 Nov 2026). An older addon's change has no st: it stays
  -- only where nothing was known.
  local had, st = f.entrances[key], tonumber(op.st)
  if not had or (st and had.st and st < had.st) then
    f.entrances[key] = { x = x, y = y, map = tonumber(op.map), st = st,
      zone = type(op.zone) == "string" and #op.zone <= 64 and op.zone or nil }
  end
  return true
end

function E:Sanitize(f)
  if type(f.entrances) ~= "table" then f.entrances = nil return end
  local out = {}
  for key, e in pairs(f.entrances) do
    if type(key) == "string" and type(e) == "table" and pos(e.x) and pos(e.y) then
      out[key] = { x = pos(e.x), y = pos(e.y), map = tonumber(e.map), st = tonumber(e.st), zone = type(e.zone) == "string" and e.zone or nil }
    end
  end
  f.entrances = next(out) and out or nil
end

---------------------------------------------------------------------------
-- Learning: where I stood a moment before walking in
---------------------------------------------------------------------------
-- My place on the zone's map (a cave's own map goes up to its zone), or nil.
function E.Here()
  if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition) then return nil end
  local map = C_Map.GetBestMapForUnit("player")
  if not plain(map) or not map then return nil end
  local info = C_Map.GetMapInfo and C_Map.GetMapInfo(map)
  while info and Enum and Enum.UIMapType and info.mapType and info.mapType > Enum.UIMapType.Zone
    and info.parentMapID and info.parentMapID > 0 do
    map = info.parentMapID
    info = C_Map.GetMapInfo(map)
  end
  local p = C_Map.GetPlayerMapPosition(map, "player")
  if not p then return nil end
  local x, y = p:GetXY()
  if not (plain(x) and plain(y)) or not (pos(x * 100) and pos(y * 100)) then return nil end
  return { map = map, x = pos(x * 100), y = pos(y * 100), zone = info and plain(info.name) and info.name or nil }
end

function E:Sample()
  if IsInInstance() or not F:Current() then return end
  local here = self.Here()
  if here then here.at = GetTime(); self.last = here end
end

-- Just walked into an instance: the place a moment before is its entrance, for each of the catalog's dungeons there,
-- once per fellowship.
function E:Entered()
  local inside, kind = IsInInstance()
  local f, last = F:Current(), self.last
  self.last = nil
  if not inside or (kind ~= "party" and kind ~= "raid") or not f or not last or GetTime() - last.at > self.FRESH then return end
  if IsInLFGDungeon and IsInLFGDungeon() then return end
  if self.summoned and GetTime() - self.summoned <= self.SUMMONED then return end
  local name, _, _, _, _, _, _, instID = GetInstanceInfo()
  for _, key in ipairs(ns.Clears:KeysHere(plain(instID) and instID or nil, plain(name) and name or nil)) do
    local base = ns.BaseKey(key)
    if not (f.entrances and f.entrances[base]) then
      F:Do({ k = "entrance", key = base, map = last.map, x = last.x, y = last.y, zone = last.zone })
    end
  end
end

ns:On("LOGIN", function() C_Timer.NewTicker(E.SAMPLE, function() E:Sample() end) end)
ns:RegisterEvent("PLAYER_ENTERING_WORLD", function() E:Entered() end)
ns:RegisterEvent("CONFIRM_SUMMON", function() E.summoned = GetTime() end)
