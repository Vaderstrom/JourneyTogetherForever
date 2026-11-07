-- My XP pace (SPEC §6): XP per hour of play over about the last 10 hours played, shared with the other Heroes in
-- STATE (Fellowship/Hero.lua), so the catch-up card can say "about 2 hours at your pace". Time spent AFK is left out.
local _, ns = ...
local Pa = { WINDOW = 10 * 3600, MIN_SEC = 15 * 60, TICK = 60 }
ns.Pace = Pa

local function db()
  if type(ns.char.pace) ~= "table" then ns.char.pace = { xp = 0, sec = 0 } end
  return ns.char.pace
end

-- Adds XP gained and seconds played. Past the window, both shrink in step, so old play counts less.
function Pa:Add(xp, sec)
  local d = db()
  d.xp, d.sec = d.xp + xp, d.sec + sec
  if d.sec > self.WINDOW then
    local k = self.WINDOW / d.sec
    d.xp, d.sec = d.xp * k, self.WINDOW
  end
end

-- XP per hour of play, or nil until there is enough play time to tell. /jtf debug pace <n> pretends one.
function Pa:PerHour()
  if ns.Dev and ns.Dev.pace then return ns.Dev.pace end
  local d = db()
  if d.sec < self.MIN_SEC or d.xp <= 0 then return nil end
  return math.floor(d.xp / d.sec * 3600 + 0.5)
end

-- XP from one level to the next: the Classic curve WoW Forever keeps (4,084,700 to 60). /jtf check compares the
-- game's size at your level with it.
Pa.LEVEL_XP = { 400, 900, 1400, 2100, 2800, 3600, 4500, 5400, 6500, 7600, 8800, 10100, 11400, 12900, 14400, 16000,
  17700, 19400, 21300, 23200, 25200, 27300, 29400, 31700, 34000, 36400, 38900, 41400, 44300, 47400, 50800, 54500,
  58600, 62800, 67100, 71600, 76100, 80800, 85700, 90700, 95800, 101000, 106300, 111800, 117500, 123200, 129100,
  135100, 141200, 147500, 153900, 160400, 167100, 173900, 180800, 187900, 195000, 202300, 209800 }

-- A level's size: the game's own for the level the numbers come from, else the table; nil at the level cap.
local function size(l, level, max)
  if l == level and max and max > 0 then return max end
  return Pa.LEVEL_XP[l]
end

-- Where gain more XP takes someone at level with xp of max, walked level by level: a level with its fraction (15.4).
-- It stops at the level cap.
function Pa.Reach(level, xp, max, gain)
  local l, into = level, (xp or 0) + gain
  local s = size(l, level, max)
  while s and into >= s do into, l = into - s, l + 1; s = size(l, level, max) end
  return s and l + into / s or l
end

-- The point (a level with its fraction) from which gain XP ends exactly at to, walked back level by level; level and
-- max are where the numbers come from (the game's size there).
function Pa.Back(to, gain, level, max)
  local l = math.floor(to)
  local s = size(l, level, max)
  local below = s and (to - l) * s or 0
  if s and gain <= below then return l + (below - gain) / s end
  gain = gain - below
  while l > 1 do
    l = l - 1
    s = size(l, level, max)
    if s then
      if gain <= s then return l + (s - gain) / s end
      gain = gain - s
    end
  end
  return 1
end

-- XP from (level, xp) to the start of level target, level by level, and the seconds of play that takes at pace (nil
-- without a pace).
function Pa.ToLevel(level, xp, xpMax, target, pace)
  if not level or level >= target then return 0, 0 end
  if not xpMax or xpMax <= 0 then return nil, nil end
  local need = xpMax - (xp or 0)
  for l = level + 1, target - 1 do need = need + (size(l, level, xpMax) or 0) end
  return need, (pace and pace > 0) and need / pace * 3600 or nil
end

-- Levels still to go as a number with one decimal: level 15 at 40% to 17 is 1.6.
function Pa.LevelsTo(level, xp, xpMax, target)
  local frac = (xpMax and xpMax > 0) and ns.Clamp((xp or 0) / xpMax, 0, 1) or 0
  return math.max(0, math.floor(((target - level) - frac) * 10 + 0.5) / 10)
end

---------------------------------------------------------------------------
-- Measuring: XP gained between updates (also across a level up), and play time while not AFK
---------------------------------------------------------------------------
local function now() return { level = UnitLevel("player"), xp = UnitXP("player"), max = UnitXPMax("player") } end

function Pa:OnXP()
  local cur = now()
  local last = self.last
  if last and last.max and last.max > 0 then
    local gain = 0
    if cur.level == last.level then gain = cur.xp - last.xp
    elseif cur.level == last.level + 1 then gain = (last.max - last.xp) + cur.xp end
    if gain > 0 then self:Add(gain, 0) end
  end
  self.last = cur
end

function Pa:Tick()
  if UnitIsAFK and UnitIsAFK("player") then return end
  self:Add(0, self.TICK)
end

ns:RegisterEvent("PLAYER_XP_UPDATE", function() Pa:OnXP() end)
ns:On("LOGIN", function()
  Pa.last = now()
  C_Timer.NewTicker(Pa.TICK, function() Pa:Tick() end)
end)
