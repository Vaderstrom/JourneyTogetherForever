-- /jtf check: the one command for testing and reviewing the addon in the game. It runs the self-test (every
-- feature's checks, Dev/SelfTest.lua) and then the tour (a screenshot of every screen, Dev/Tour.lua), on a character
-- without a fellowship, and writes JourneyTogetherForeverDB.check. After a /reload, tools/check-report.lua prints both
-- by feature area (Dev/Areas.lua) with the screenshot files, and writes review/index.html to look through them.
--   /jtf check                  everything: all checks, all screenshots (about 4 minutes)
--   /jtf check setup join       all checks, then only those areas' screenshots (to look again after a fix)
--   /jtf check quick            checks only, no screenshots (about a minute)
--   /jtf check shots [areas]    screenshots only (all, or those areas)
--   /jtf check areas            the areas, with how many checks and screenshots each has
local _, ns = ...
local L = ns.L
local C = {}
ns.Check = C

local function words(text)
  local out = {}
  for w in (text or ""):lower():gmatch("[%w_]+") do out[#out + 1] = w end
  return out
end

function C:ListAreas()
  local A = ns.CheckAreas
  local steps = ns.SelfTest.steps
  for _, a in ipairs(A.LIST) do
    local n = 0
    for _, s in ipairs(steps) do
      for _, key in ipairs(A:ForStep(s.name)) do if key == a.key then n = n + 1 end end
    end
    ns:Print(L.CHECK_AREA_LINE:format(a.key, a.title, n, #(a.shots or {})), true)
  end
end

function C:Finish()
  local r = ns.db.check
  r.finished = time()
  self.running = false
  local st = r.selftest and ns.db.selftest or nil
  ns:Print(L.CHECK_DONE:format(st and st.passed or 0, st and st.failed or 0, r.shots and #ns.db.tour.shots or 0), true)
end

function C:Run(text)
  if self.running or ns.SelfTest.running or ns.Tour.running then return end
  local w = words(text)
  if w[1] == "areas" or w[1] == "list" then return self:ListAreas() end
  local selftest, shots = true, true
  if w[1] == "quick" then shots = false; table.remove(w, 1)
  elseif w[1] == "shots" then selftest = false; table.remove(w, 1) end
  local areas, unknown = ns.CheckAreas:Parse(table.concat(w, " "))
  if #unknown > 0 then ns:Print(L.CHECK_UNKNOWN:format(table.concat(unknown, ", ")), true) return end
  if ns.Combat:InCombat() then ns:Print(L.SELFTEST_COMBAT, true) return end
  if ns.Fellowship:Current() then ns:Print(L.SELFTEST_IN_FELLOWSHIP, true) return end
  local list = {}
  for key in pairs(areas or {}) do list[#list + 1] = key end
  table.sort(list)
  ns.db.check = { started = time(), selftest = selftest, shots = shots, areas = #list > 0 and list or nil }
  self.running = true
  local count = shots and ns.Tour:Count(areas) or 0
  ns:Print(L.CHECK_START:format(selftest and L.CHECK_WITH_SELFTEST or "", count,
    #list > 0 and table.concat(list, ", ") or L.CHECK_ALL_AREAS), true)
  local function tour()
    if not shots then return C:Finish() end
    ns.Tour:Run("", { areas = areas, onDone = function() C:Finish() end })
  end
  if selftest then ns.SelfTest:Run("", { onDone = tour }) else tour() end
end
