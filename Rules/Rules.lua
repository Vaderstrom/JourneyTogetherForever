-- The fellowship's rules (SPEC §3): defaults, limits, and the texts that describe them (from the mockup).
local _, ns = ...
local L = ns.L
local R = {}
ns.Rules = R

R.DEFAULTS = {
  floorTol = 0, capTol = 0, runXp = true, runXpMax = 1, minHeroes = 4, clearMode = "all", clearN = 3,
  offInvite = true, offRemove = true, offClears = false, offAdmin = false, takeover = 14, takeoverNever = false,
  awayDays = 14, awayNever = false, showFuture = false,
  gmT = false, tStart = "manual", tFormat = "single", tBo = 1, tSeed = "level", tMin = 4, tSignup = 48, tRound = 72, tTotal = 14,
}

-- Founding in a few choices (27 Oct 2026): the fellowship's size and a play style each set part of the rules, so
-- they never fight (a duo cannot need five Companions for a run); the full form stays for fine-tuning. Officers,
-- takeover and the tournament keep their own values. Party + Together are the defaults.
-- Size: the numbers. Companions per run (dungeons take five, so a duo or trio fills up with others), who must clear a
-- dungeon (a large fellowship fields several parties), and when a quiet Companion counts as away. Each size suggests
-- a style and a journey (docs: SPEC §4.2). Size never limits who can be invited.
R.SIZE_ORDER = { "duo", "trio", "party", "large" }
R.SIZES = {
  duo = { minHeroes = 2, clearMode = "all", awayDays = 7, awayNever = false },
  trio = { minHeroes = 3, clearMode = "all", awayDays = 10, awayNever = false },
  party = { minHeroes = 4, clearMode = "all", awayDays = 14, awayNever = false },
  large = { minHeroes = 5, clearMode = "n", clearN = 5, awayDays = 7, awayNever = false },
}
R.SIZE_RANGE = { duo = { 1, 2 }, trio = { 3, 3 }, party = { 4, 5 }, large = { 6, math.huge } }
R.SIZE_SUGGEST = { duo = { "strict", "short" }, trio = { "together", "short" }, party = { "together", "classic" },
  large = { "relaxed", "long" } }
-- Play style: the slack. How far under the floor or over the cap a Companion may be, and XP from runs over the cap.
R.STYLE_ORDER = { "relaxed", "together", "strict" }
R.STYLES = {
  relaxed = { floorTol = 2, capTol = 2, runXp = true, runXpMax = 2 },
  together = { floorTol = 0, capTol = 0, runXp = true, runXpMax = 1 },
  strict = { floorTol = 0, capTol = 0, runXp = false, runXpMax = 1 },
}

local function matches(rules, set)
  for k, v in pairs(set) do if rules[k] ~= v then return false end end
  return true
end

-- The style these rules match, or "custom".
function R.StyleOf(rules)
  for _, key in ipairs(R.STYLE_ORDER) do if matches(rules, R.STYLES[key]) then return key end end
  return "custom"
end

-- The size these rules were made for, or "custom".
function R.SizeOf(rules)
  for _, key in ipairs(R.SIZE_ORDER) do if matches(rules, R.SIZES[key]) then return key end end
  return "custom"
end

-- The size that fits a number of Companions.
function R.SizeFor(n)
  for _, key in ipairs(R.SIZE_ORDER) do
    local r = R.SIZE_RANGE[key]
    if n >= r[1] and n <= r[2] then return key end
  end
  return "large"
end

local function with(rules, set)
  local out = {}
  for k, v in pairs(rules) do out[k] = v end
  for k, v in pairs(set or {}) do out[k] = v end
  return R.Clean(out)
end

-- Copies of the rules with a style's or a size's values.
function R.WithStyle(rules, key) return with(rules, R.STYLES[key]) end
function R.WithSize(rules, key) return with(rules, R.SIZES[key]) end

-- Names: "Party (4-5)", "Together", and the plain word for sentences ("a large fellowship").
function R.SizeName(key) return key == "custom" and L.SIZE_CUSTOM or L["SIZE_" .. key:upper()] end
function R.StyleName(key) return key == "custom" and L.STYLE_CUSTOM or L["STYLE_" .. key:upper()] end
function R.SizeWord(key) return L["SIZE_WORD_" .. key:upper()] end

-- The size whose rules fit better now that the fellowship has n Companions, or nil: when it has grown past the size
-- its rules were made for (not while it is still filling up after founding, and not when the rules were fine-tuned
-- to a mix of their own).
function R.SizeSuggestion(rules, n)
  local made = R.SizeOf(rules)
  if made == "custom" then return nil end
  local fits = R.SizeFor(n)
  local function index(key) for i, k in ipairs(R.SIZE_ORDER) do if k == key then return i end end end
  if index(fits) > index(made) then return fits end
  return nil
end

-- Allowed values (a list) or a range { min, max } for every rule.
R.ALLOWED = {
  floorTol = { 0, 1, 2, 3 }, capTol = { 0, 1, 2, 3 }, runXp = { true, false }, runXpMax = { 1, 2, 3, 4, 5 },
  minHeroes = { 2, 3, 4, 5 }, clearMode = { "one", "n", "all" }, clearN = { 2, 3, 4, 5 },
  offInvite = { true, false }, offRemove = { true, false }, offClears = { true, false }, offAdmin = { true, false },
  takeover = { range = { 7, 30 } }, takeoverNever = { true, false }, awayDays = { range = { 1, 30 } }, awayNever = { true, false },
  showFuture = { true, false }, gmT = { true, false }, tStart = { "manual", "auto" }, tFormat = { "single", "double", "groups", "rr" }, tBo = { 1, 3, 5 },
  tSeed = { "level", "random" }, tMin = { 2, 4, 6, 8 }, tSignup = { dur = true }, tRound = { dur = true }, tTotal = { range = { 1, 21 } },
}

-- Durations in hours, from 30 minutes to 7 days.
R.DUR = { 0.5, 1, 2, 6, 12, 24, 48, 72, 120, 168 }
local DUR_LABEL = { [0.5] = "DUR_30M", [1] = "DUR_1H", [2] = "DUR_2H", [6] = "DUR_6H", [12] = "DUR_12H", [24] = "DUR_1D",
  [48] = "DUR_2D", [72] = "DUR_3D", [120] = "DUR_5D", [168] = "DUR_7D" }

function R.DurLabel(h) return DUR_LABEL[h] and L[DUR_LABEL[h]] or L.HOURS_N:format(h) end

function R.StepDur(h, dir)
  local i = 1
  for n, v in ipairs(R.DUR) do if v == h then i = n end end
  return R.DUR[ns.Clamp(i + dir, 1, #R.DUR)]
end

function R.Valid(key, value)
  local a = R.ALLOWED[key]
  if not a then return false end
  if a.range then return type(value) == "number" and value == math.floor(value) and value >= a.range[1] and value <= a.range[2] end
  if a.dur then
    for _, v in ipairs(R.DUR) do if v == value then return true end end
    return false
  end
  for _, v in ipairs(a) do if v == value then return true end end
  return false
end

-- A full, valid set of rules: known keys only, invalid values replaced by the defaults.
function R.Clean(rules)
  local out = {}
  if type(rules) ~= "table" then rules = {} end
  for k, def in pairs(R.DEFAULTS) do
    local v = rules[k]
    if v ~= nil and R.Valid(k, v) then out[k] = v else out[k] = def end
  end
  return out
end

function R.New(overrides) return R.Clean(overrides or {}) end

local function levels(n) return (n == 1 and L.LEVELS_1 or L.LEVELS_N):format(n) end
local function days(n) return (n == 1 and L.DAYS_1 or L.DAYS_N):format(n) end
R.Days = days

-- The plain-language summary at the top of the Rules page.
function R.Summary(r)
  local cap = r.capTol > 0 and L.SUM_CAP:format(levels(r.capTol)) or L.SUM_CAP_NONE
  if r.runXp then cap = cap .. L.SUM_RUNXP:format(levels(r.runXpMax)) end
  local clear = r.clearMode == "one" and L.SUM_CLEAR_ONE or (r.clearMode == "n" and L.SUM_CLEAR_N:format(r.clearN) or L.SUM_CLEAR_ALL)
  local away = r.awayNever and L.SUM_AWAY_NEVER or L.SUM_AWAY:format(days(r.awayDays))
  -- Plain words for no allowance ("at most 0 levels below the floor" read oddly; seen in the tour).
  local floor = r.floorTol > 0 and L.SUM_FLOOR:format(levels(r.floorTol)) or L.SUM_FLOOR_NONE
  return floor .. " " .. cap .. ". " .. L.SUM_RUN:format(r.minHeroes) .. " " .. clear .. " " .. away
end

-- A rule and its value in words, for votes (SPEC §6): "Heroes needed for a run", "3".
local NAMES = {
  floorTol = "RN_FLOORTOL", capTol = "RN_CAPTOL", runXp = "R_RUNXP", runXpMax = "RN_RUNXPMAX", minHeroes = "R_MINHEROES",
  clearMode = "R_CLEAR", clearN = "RN_CLEARN", offInvite = "RN_OFFINVITE", offRemove = "RN_OFFREMOVE",
  offClears = "RN_OFFCLEARS", offAdmin = "RN_OFFADMIN", takeover = "RN_TAKEOVER", takeoverNever = "RN_TAKEOVERNEVER",
  awayDays = "RN_AWAYDAYS", awayNever = "RN_AWAYNEVER", showFuture = "R_SHOWFUTURE", gmT = "R_GMT", tStart = "RN_TSTART",
  tFormat = "RN_TFORMAT", tBo = "R_BO", tSeed = "R_SEED", tMin = "R_TMIN", tSignup = "R_SIGNUP", tRound = "R_ROUND",
  tTotal = "R_TOTAL",
}
local ENUMS = {
  clearMode = { one = "R_CLEAR_ONE", n = "R_CLEAR_N", all = "R_CLEAR_ALL" },
  tStart = { manual = "TSTART_MANUAL", auto = "TSTART_AUTO" },
  tFormat = { single = "F_BRACKET", double = "F_DOUBLE", groups = "F_GROUPS", rr = "F_RR" },
  tBo = { [1] = "BO_1", [3] = "BO_3", [5] = "BO_5" }, tSeed = { level = "SEED_LEVEL", random = "SEED_RANDOM" },
}
local ONOFF = { runXp = true, gmT = true }
local NEVER = { takeoverNever = true, awayNever = true }

function R.Name(key) return NAMES[key] and L[NAMES[key]] or key end

function R.ValueText(key, v)
  if ENUMS[key] then return L[ENUMS[key][v] or ""] or tostring(v) end
  if key == "showFuture" then return v and L.R_ALL_CHAPTERS or L.R_CURRENT_EARLIER end
  if NEVER[key] then return v and L.R_NEVER or L.R_AFTER_DAYS end
  if type(v) == "boolean" then return ONOFF[key] and (v and L.ON or L.OFF) or (v and L.YES or L.NO) end
  if key == "tSignup" or key == "tRound" then return R.DurLabel(v) end
  if key == "takeover" or key == "awayDays" or key == "tTotal" then return days(v) end
  if key == "floorTol" or key == "capTol" or key == "runXpMax" then return levels(v) end
  return tostring(v)
end

-- The rulebook (the Rules page, 28 Oct 2026): the rules as numbered articles, each with the rules it is made of (in
-- that order they are offered to propose a change). The officer rules (off*) went with the officers. Away and the
-- Leader's takeover are two rules, so two articles (29 Oct 2026; they were one, "Away and the Leader").
R.BOOK = {
  { title = "BOOK_LEVELING", rules = { "floorTol", "capTol", "runXp", "runXpMax" } },
  { title = "BOOK_RUNS", rules = { "minHeroes", "clearMode", "clearN" } },
  { title = "BOOK_AWAY", rules = { "awayNever", "awayDays" } },
  { title = "BOOK_LEADER", rules = { "takeoverNever", "takeover" } },
  { title = "BOOK_BOOK", rules = { "showFuture" } },
  { title = "BOOK_TOURNEY", rules = { "gmT", "tStart", "tFormat", "tBo", "tSeed", "tMin", "tSignup", "tRound", "tTotal" } },
}

-- Every value a rule can have, in order: { { text, value } }.
function R.Choices(key)
  local a, out = R.ALLOWED[key], {}
  if not a then return out end
  local list = a
  if a.range then
    list = {}
    for v = a.range[1], a.range[2] do list[#list + 1] = v end
  elseif a.dur then
    list = R.DUR
  end
  for _, v in ipairs(list) do out[#out + 1] = { R.ValueText(key, v), v } end
  return out
end

-- The articles in plain sentences: { { title, text } }. hl(s) marks a value (the page colours it).
function R.Book(r, hl)
  hl = hl or function(s) return s end
  local function adv(n) return hl(L.BOOK_ADV_N:format(n)) end
  local lines = {}
  -- I. Leveling together.
  lines[1] = {
    L.BOOK_FLOOR:format(hl(r.floorTol > 0 and L.BOOK_FLOOR_N:format(levels(r.floorTol)) or L.BOOK_FLOOR_0)),
    L.BOOK_CAP:format(hl(r.capTol > 0 and L.BOOK_CAP_N:format(levels(r.capTol)) or L.BOOK_CAP_0)),
    r.runXp and L.BOOK_RUNXP:format(hl(levels(r.runXpMax))) or L.BOOK_RUNXP_OFF:format(hl(L.BOOK_NO_XP)),
  }
  -- II. Dungeon runs.
  lines[2] = {
    L.BOOK_RUN:format(adv(r.minHeroes)),
    r.clearMode == "one" and L.BOOK_CLEAR_ONE:format(hl(L.BOOK_ONE_RUN))
      or (r.clearMode == "n" and L.BOOK_CLEAR_N:format(adv(r.clearN)) or L.BOOK_CLEAR_ALL:format(hl(L.BOOK_EVERY))),
  }
  -- III. Away.
  lines[3] = {
    r.awayNever and L.BOOK_AWAY_NEVER:format(hl(L.BOOK_NEVER_AWAY)) or L.BOOK_AWAY_DAYS:format(hl(days(r.awayDays))),
    L.BOOK_AWAY_SELF,
  }
  -- IV. If the Leader is away.
  lines[4] = {
    r.takeoverNever and L.BOOK_TAKEOVER_NEVER:format(hl(L.BOOK_NEVER_PASSES)) or L.BOOK_TAKEOVER:format(hl(days(r.takeover))),
  }
  -- V. The book.
  lines[5] = { r.showFuture and L.BOOK_SHOW_ALL:format(hl(L.BOOK_ALL_CHAPTERS)) or L.BOOK_SHOW_CUR:format(hl(L.BOOK_CUR_CHAPTERS)) }
  -- VI. Guild Master tournament.
  if r.gmT then
    lines[6] = {
      L.BOOK_T_ON,
      L.BOOK_T_HOW:format(hl(R.ValueText("tFormat", r.tFormat)), hl(R.ValueText("tBo", r.tBo)),
        hl(R.ValueText("tSeed", r.tSeed)), hl(tostring(r.tMin))),
      L.BOOK_T_TIME:format(hl(R.DurLabel(r.tSignup)), hl(R.DurLabel(r.tRound)), hl(days(r.tTotal))),
      r.tStart == "auto" and L.BOOK_T_AUTO or L.BOOK_T_MANUAL,
    }
  else
    lines[6] = { L.BOOK_T_OFF:format(hl(L.BOOK_OFF)) }
  end
  local out = {}
  for i, a in ipairs(R.BOOK) do out[i] = { title = L[a.title], text = table.concat(lines[i], " ") } end
  return out
end

-- Rounds of a tournament with n entrants, as the tournament plays them (Rules/Tournament.lua).
function R.TournamentRounds(format, n) return ns.Tournament.Rounds(format, n) end

-- "With 7 Heroes: sign-up 2 days + 3 rounds × 3 days = 11 days. Fits."
function R.TournamentFit(r, heroes)
  local n = math.max(2, heroes)
  local rounds = R.TournamentRounds(r.tFormat, n)
  local need = r.tSignup + rounds * r.tRound
  return L.TFIT:format(n, R.DurLabel(r.tSignup), rounds, R.DurLabel(r.tRound), math.ceil(need / 24))
    .. " " .. (need <= r.tTotal * 24 and L.TFIT_OK or L.TFIT_LONG)
end
