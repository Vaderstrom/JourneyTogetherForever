-- /jtf check: the one command for testing and reviewing the addon in the game. It runs the self-test (every
-- feature's checks, Dev/SelfTest.lua) and then the tour (a screenshot of every screen, Dev/Tour.lua), on a character
-- without a fellowship, and writes JourneyTogetherForeverDB.check. After a /reload, tools/check-report.lua prints both
-- by feature area (Dev/Areas.lua) with the screenshot files, and writes review/index.html to look through them.
--   /jtf check                  everything: all checks, all screenshots, then on an Alliance character the README's
--                               pictures (/jtf brand) in the same run (about 12 minutes)
--   /jtf check setup join       those areas' checks with the ones they build on (Dev/Areas.lua, U253), then the tour
--                               up to their last screenshot, only theirs photographed (to look again after a fix; U209)
--   /jtf check models           an area that stands alone (Dev/Areas.lua): only its checks and screenshots
--   /jtf check quick            checks only, no screenshots (about 3 minutes)
--   /jtf check shots [areas]    screenshots only (all, or those areas; all of them also takes the README's pictures)
--   /jtf check areas            the areas, with how many checks and screenshots each has
-- Each run turns Lua errors on and reloads first, then goes on by itself; at the end it puts the setting back and shows
-- a button that reloads, which saves the results (the owner, 17 Nov 2026: a check ran with Lua errors off).
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

C.RESUME = 5 -- seconds after the reload's login before the check starts

-- Lua errors back as they were before the check (as the tour does with HDR).
function C:ErrorsBack()
  if not ns.db.errorsWas then return end
  pcall(C_CVar.SetCVar, "scriptErrors", ns.db.errorsWas)
  ns.db.errorsWas = nil
end

-- An error in a frame's script or a timer reaches only the game's error window, which keeps every one, even with Lua
-- errors off (ScriptErrorsFrame.errorData). Ours go into the error log, so the report has them after the reload;
-- those our event handlers logged themselves (Core/Init.lua) are there already. Ours are found by "TogetherForever":
-- the game keeps only the last 52 characters of a file's path, so "...neyTogetherForever-Dev/Fellowship/
-- ChallengeWatch.lua" has lost the start of the folder's name (tests/test_check.lua checks every file keeps this part).
function C:GameErrors()
  local list = ScriptErrorsFrame and ScriptErrorsFrame.errorData
  if type(list) ~= "table" then return end
  local function plain(v) return type(v) == "string" and not (issecretvalue and issecretvalue(v)) end
  local logged = {}
  for _, e in ipairs(ns.db.errors or {}) do if (tonumber(e.t) or 0) >= ns.loadedAt then logged[e.msg] = true end end
  for _, d in ipairs(list) do
    local m, s = d.message, plain(d.stack) and d.stack or ""
    local n = tonumber(d.count) or 1
    if plain(m) and not logged[m] and (m:find("TogetherForever", 1, true) or s:find("TogetherForever", 1, true)) then
      ns:LogError("Lua error", n > 1 and ("%s (%d times)"):format(m, n) or m, s)
    end
  end
end

-- (Lua errors since the reload that loaded the code checked: an error at the login counts too.)
local function counts(r)
  local st = r.selftest and ns.db.selftest or nil
  local errors = 0
  for _, e in ipairs(ns.db.errors or {}) do if (tonumber(e.t) or 0) >= (r.loaded or r.started) then errors = errors + 1 end end
  return st and st.passed or 0, st and st.failed or 0, r.shots and #ns.db.tour.shots or 0, errors
end

function C:Finish()
  local r = ns.db.check
  C:GameErrors()
  r.finished = time()
  self.running = false
  C:SoloBack()
  C:ErrorsBack()
  ns:Print(L.CHECK_DONE:format(counts(r)), true)
  r.tell = true
  C:SaveButton()
end

-- The game lets an addon reload only on a key or a click: the reload from a timer at the end was blocked
-- (ADDON_ACTION_BLOCKED, the check of 17 Nov 2026 20:56). So the end shows one button that reloads (after combat).
function C:SaveButton()
  ns.Combat:AfterCombat(function()
    if not self.save then
      self.save = ns.UI.TextButton(UIParent, L.CHECK_SAVE, function() ReloadUI() end, "primary")
      self.save:SetFrameStrata("DIALOG")
      self.save:SetPoint("CENTER", 0, 160)
    end
    self.save:Show()
  end)
end

-- (A check that keeps its fellowship: the journey waits until that one is left.)
function C:SoloBack()
  if ns.char.soloKept and not ns.Fellowship:Real() then ns.char.solo, ns.char.soloKept = ns.char.soloKept, nil end
end
ns:On("LOGIN", function()
  C:SoloBack()
  local r, nxt = ns.db.check, ns.db.checkNext
  if r and r.tell then r.tell = nil; ns:Print(L.CHECK_SAVED:format(counts(r)), true) end
  ns.db.checkNext = nil
  -- (Asked minutes ago: a reload that never came starts no check at a later login.)
  if type(nxt) ~= "table" or time() - (tonumber(nxt.t) or 0) > 600 then return C:ErrorsBack() end
  C_Timer.After(C.RESUME, function()
    C:Run(nxt.text, true)
    if not C.running then C:ErrorsBack() end -- (refused after the reload: a window over the book, say)
  end)
end)

function C:Run(text, resumed)
  if self.running or ns.SelfTest.running or ns.Tour.running then return end
  local w = words(text)
  if w[1] == "areas" or w[1] == "list" then return self:ListAreas() end
  local selftest, shots = true, true
  if w[1] == "quick" then shots = false; table.remove(w, 1)
  elseif w[1] == "shots" then selftest = false; table.remove(w, 1) end
  local areas, unknown = ns.CheckAreas:Parse(table.concat(w, " "))
  if #unknown > 0 then ns:Print(L.CHECK_UNKNOWN:format(table.concat(unknown, ", ")), true) return end
  if ns.Combat:InCombat() then ns:Print(L.SELFTEST_COMBAT, true) return end
  if ns.Fellowship:Real() then ns:Print(L.SELFTEST_IN_FELLOWSHIP, true) return end
  -- A window over the screen would be in every picture (the check of 10 Nov 2026, 14:31): closed first.
  local ok, cover = true, nil
  if shots then ok, cover = pcall(ns.Tour.Covering, ns.Tour) end
  if ok and cover then ns:Print(L.CHECK_COVERED:format(cover), true) return end
  -- The reload also loads what changed in the files, and empties the game's error window (C:GameErrors).
  if not resumed then
    ns.db.errorsWas = ns.db.errorsWas or C_CVar.GetCVar("scriptErrors")
    pcall(C_CVar.SetCVar, "scriptErrors", "1")
    ns.db.checkNext = { text = text or "", t = time() }
    ns:Print(L.CHECK_RELOADING, true)
    return ReloadUI()
  end
  local list = {}
  for key in pairs(areas or {}) do list[#list + 1] = key end
  table.sort(list)
  local only = ns.CheckAreas:Alone(areas) and areas or nil
  ns.db.check = { started = time(), loaded = ns.loadedAt, selftest = selftest, shots = shots, areas = #list > 0 and list or nil,
    only = only and true or nil }
  -- The journey on your own waits aside (U241): the check plays from no fellowship. Back at the end, or at the next
  -- login when the check stopped there.
  if ns.char.solo then ns.char.soloKept, ns.char.solo = ns.char.solo, nil end
  self.running = true
  local count = shots and ns.Tour:Count(areas) or 0
  -- A whole check also takes the README's pictures, so a release needs one run, not two (the owner, 10 Nov 2026).
  -- They are taken on an Alliance character only (TR:Brand).
  local brand = shots and not areas and UnitFactionGroup("player") == "Alliance"
  ns.db.check.brand = brand or nil
  local which = only and L.CHECK_WITH_SELFTEST_ONLY or areas and L.CHECK_WITH_SELFTEST_TO or L.CHECK_WITH_SELFTEST
  ns:Print(L.CHECK_START:format(selftest and which or "", count,
    #list > 0 and table.concat(list, ", ") or L.CHECK_ALL_AREAS, brand and L.CHECK_WITH_BRAND:format(#ns.Tour.BRAND) or ""), true)
  local function tour()
    if not shots then return C:Finish() end
    ns.Tour:Run("", { areas = areas, only = only, onDone = function(stopped)
      if stopped or not brand then return C:Finish() end
      -- (A moment after the tour, as when /jtf brand was typed after it: its pretend fellowship is gone first.)
      C_Timer.After(2, function() ns.Tour:Brand(function() C:Finish() end) end)
    end })
  end
  if selftest then ns.SelfTest:Run("", { only = only, areas = areas, onDone = tour }) else tour() end
end
