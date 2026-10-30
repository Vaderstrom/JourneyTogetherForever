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

-- XP from (level, xp) to the start of level target, and the seconds of play that takes at pace (nil without a
-- pace). Later levels are counted at this level's size, so it is an estimate.
function Pa.ToLevel(level, xp, xpMax, target, pace)
  if not level or level >= target then return 0, 0 end
  if not xpMax or xpMax <= 0 then return nil, nil end
  local need = (xpMax - (xp or 0)) + (target - level - 1) * xpMax
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
