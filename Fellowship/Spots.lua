-- Live spots (U267, SPEC §4.6 The map): while a map of ours shows (the book's, or the game's world map with a quest's
-- Adventurers, U268), every ASK_EVERY seconds the online Adventurers on that quest are asked where they are (POSQ) and
-- answer with their spot on that map (POS: x and y in thousandths) or only that they are elsewhere (no x and y).
-- Nothing is sent otherwise, and nothing inside instances: the game hides spots there, and a held message would arrive
-- stale. An answer to an ask more than KEEP seconds old, or for another map, is dropped (late, twice or out of order:
-- the newest within KEEP stands). Always answered within your fellowship, with no switch to stop it (the owner, 20 Nov
-- 2026: "Should just be on if you are in the same fellowship"); In the game's quest log and map off still answers.
--   POSQ { fid, m }        where are you on map m?
--   POS  { fid, m, x, y }  here (x, y from 0 to 1000), or elsewhere (no x, y)
local _, ns = ...
local Comm, F = ns.Comm, ns.Fellowship
local S = { ASK_EVERY = 10, KEEP = 30, at = {} }
ns.Spots = S

local function inside() return (IsInInstance()) and true or false end

-- My spot on map, from 0 to 1, or nil (not on that map, inside, or a value the game keeps secret).
function S.Mine(map)
  if not (C_Map and C_Map.GetPlayerMapPosition) or inside() then return nil end
  local ok, v = pcall(C_Map.GetPlayerMapPosition, map, "player")
  if not ok or v == nil or ns.Secret(v) then return nil end
  local x, y = v:GetXY()
  if ns.Secret(x) or ns.Secret(y) or type(x) ~= "number" or type(y) ~= "number" then return nil end
  if x <= 0 or y <= 0 or x >= 1 or y >= 1 then return nil end
  return x, y
end

-- Where name is on map: x, y from 0 to 1, or nil (elsewhere, offline or not heard within KEEP).
function S:Spot(name, map)
  if name == ns.Me() then return S.Mine(map) end
  local s = self.at[name]
  if not s or s.m ~= map or not s.x or GetTime() - s.t > self.KEEP then return nil end
  return s.x, s.y
end

-- owner watches map for names (the Adventurers on the quest); one watch at a time, the newest owner wins. Asks at once
-- when the map or owner is new, else on the ticker.
function S:Watch(map, names, owner)
  local fresh = map ~= self.map or owner ~= self.owner
  self.map, self.names, self.owner = map, names, owner
  if not self.ticker then self.ticker = C_Timer.NewTicker(self.ASK_EVERY, function() S:Ask() end) end
  if fresh then self:Ask() end
end

function S:Unwatch(owner)
  if owner ~= self.owner then return end
  self.map, self.names, self.owner, self.asked = nil, nil, nil, nil
  if self.ticker then self.ticker:Cancel(); self.ticker = nil end
  ns:Fire("SPOTS") -- (another map still showing watches again)
end

function S:Ask()
  local f = F:Current()
  if not (f and self.map) then return end
  if not inside() and not Comm:Held() then
    local to = {}
    for _, name in ipairs(self.names or {}) do
      if name ~= ns.Me() and f.members[name] and ns.Hero:Online(f, name) then to[#to + 1] = name end
    end
    self.asked = GetTime()
    if #to > 0 then Comm:SendAll(to, "POSQ", { fid = f.id, m = self.map }, false, true) end -- (a newer ask replaces one waiting)
  end
  ns:Fire("SPOTS") -- (my own spot moves too)
end

Comm:On("POSQ", function(sender, d)
  local f = type(d) == "table" and F:Get(d.fid)
  if not f or f ~= F:Current() or not f.members[sender] or type(d.m) ~= "number" then return end
  if inside() or Comm:Held() then return end
  local x, y = S.Mine(d.m)
  Comm:Send(sender, "POS", { fid = f.id, m = d.m, x = x and math.floor(x * 1000 + 0.5), y = y and math.floor(y * 1000 + 0.5) },
    nil, true)
end)

Comm:On("POS", function(sender, d)
  local f = type(d) == "table" and F:Get(d.fid)
  if not f or f ~= F:Current() or not f.members[sender] then return end
  if d.m ~= S.map or not S.asked or GetTime() - S.asked > S.KEEP then return end
  local x, y = tonumber(d.x), tonumber(d.y)
  local ok = x and y and x > 0 and y > 0 and x < 1000 and y < 1000
  S.at[sender] = { m = d.m, x = ok and x / 1000 or nil, y = ok and y / 1000 or nil, t = GetTime() }
  ns:Fire("SPOTS")
end)
