-- Playing together (SPEC §6): the You card on the Overview (my standing, my next step, catch-up for the Hero who is
-- behind, who is behind for the others) and the actions that bring Heroes together: invite to group and whisper.
-- No frames here: UI/Pages/Overview.lua draws what You() returns.
local _, ns = ...
local L = ns.L
local F, J, Hr = ns.Fellowship, ns.Journey, ns.Hero
local T = {}
ns.Together = T

---------------------------------------------------------------------------
-- Actions
---------------------------------------------------------------------------
local function inGroup(f)
  local set = {}
  for _, name in ipairs(ns.Clears:GroupHeroes(f)) do set[name] = true end
  return set
end

-- Invites these Heroes to my group (those not in it yet). Pretend Heroes (/jtf debug) are only printed.
function T:Invite(names)
  local f = F:Current()
  if not f then return 0 end
  local invite = (C_PartyInfo and C_PartyInfo.InviteUnit) or InviteUnit
  local here, list = inGroup(f), {}
  for _, name in ipairs(names) do
    if name ~= ns.Me() and not here[name] then
      list[#list + 1] = name
      if ns.Dev and ns.Dev.fakes[name] then ns:Debug(L.DEV_WOULD_INVITE:format(ns.Short(name)))
      elseif invite then invite(ns.Display(name)) end
    end
  end
  if #list > 0 then ns:Toast(nil, L.INVITED, L.INVITED_TEXT:format(ns.Quests.NameList(list))) end
  return #list
end

-- Opens a whisper to this Hero in the chat box.
function T:Whisper(name)
  local tell = (ChatFrameUtil and ChatFrameUtil.SendTell) or ChatFrame_SendTell
  if tell then tell(ns.Display(name)) end
end

-- Find group for a dungeon (Chapter page): invites the online Heroes who still need it, a tank and a healer first,
-- then the rest by level, up to a group of five with me. Returns the names invited.
function T:FindGroup(f, key)
  local me = ns.Me()
  local who = J:ClearedBy(f, key)
  local cands = {}
  for _, name in ipairs(self:Online(f)) do
    if not who[name] and not J:Away(f, name) then cands[#cands + 1] = name end
  end
  local need = { Tank = 1, Healer = 1, DPS = 3 }
  local mine = f.members[me] and f.members[me].role
  if need[mine] then need[mine] = need[mine] - 1 end
  local picked, taken = {}, {}
  local function pick(name) picked[#picked + 1] = name; taken[name] = true end
  -- First the roles the group needs (cands are already highest level first), then anyone.
  for _, role in ipairs({ "Tank", "Healer", "DPS" }) do
    for _, name in ipairs(cands) do
      if need[role] > 0 and #picked < 4 and not taken[name] and f.members[name].role == role then
        pick(name); need[role] = need[role] - 1
      end
    end
  end
  for _, name in ipairs(cands) do if #picked < 4 and not taken[name] then pick(name) end end
  local d = ns.Dungeon(key)
  if #picked == 0 then
    ns:Toast(nil, L.FIND_GROUP, L.FIND_NOBODY:format(d and d[2] or key))
    return picked
  end
  self:Invite(picked)
  return picked
end

-- Other Heroes online now, highest level first.
function T:Online(f)
  local me, list = ns.Me(), {}
  for name in pairs(f.members) do
    if name ~= me and Hr:Online(f, name) then list[#list + 1] = name end
  end
  table.sort(list, function(a, b)
    local la, lb = Hr:Level(f, a), Hr:Level(f, b)
    if la ~= lb then return la > lb end
    return a < b
  end)
  return list
end

---------------------------------------------------------------------------
-- Play now (M25, SPEC §6 batch 3): when others are online, the one best thing to do together right now
---------------------------------------------------------------------------
-- "you, Brannic and Elyra" (you first).
local function withYou(names)
  local list = { L.NAME_YOU }
  for _, n in ipairs(names) do list[#list + 1] = ns.Short(n) end
  if #list <= 2 then return table.concat(list, L.AND) end
  return table.concat(list, ", ", 1, #list - 1) .. L.AND .. list[#list]
end

-- { text, action = "invite" | "find", names (to invite), key (Find group), grouped (all of them in your group) }, or
-- nil with nobody else online (or you away). The first that applies: someone below the floor to help (or you below
-- it, to be helped), an open dungeon at least two of you still need, a quest you share, else level together.
function T:PlayNow(f)
  local me = ns.Me()
  if not f or J:Away(f, me) then return nil end
  local online = {}
  for _, name in ipairs(self:Online(f)) do if not J:Away(f, name) then online[#online + 1] = name end end
  if #online == 0 then return nil end
  local here = inGroup(f)
  local function result(text, action, names, key)
    local grouped = true
    for _, n in ipairs(names) do if not here[n] then grouped = false end end
    return { text = text, action = action, names = names, key = key, grouped = grouped }
  end
  local ch = J:Current(f)
  if ch then
    local below = J:Below(f, ch.n)
    local mineBelow = false
    for _, name in ipairs(below) do
      if name == me then mineBelow = true end
    end
    for _, name in ipairs(below) do
      if name ~= me and not mineBelow and Hr:Online(f, name) then
        return result(L.PLAY_HELP:format(ns.Short(name)), "invite", online)
      end
    end
    if mineBelow then return result(L.PLAY_HELP_ME:format(ns.Quests.NameList(online)), "invite", online) end
    -- An open dungeon at least two of you still need (the first by level).
    for _, x in ipairs(J:Required(f, ch.n)) do
      if J:Open(f, x.key) and not J:Cleared(f, x.key) then
        local who, need, meToo = J:ClearedBy(f, x.key), {}, false
        if not who[me] then meToo = true end
        for _, name in ipairs(online) do if not who[name] then need[#need + 1] = name end end
        if #need + (meToo and 1 or 0) >= 2 then
          local list = meToo and withYou(need) or ns.Quests.NameList(need)
          return result(L.PLAY_RUN:format(x.d[2], list), "find", need, x.key)
        end
      end
    end
  end
  -- A quest you share with someone online.
  local isOn = {}
  for _, n in ipairs(online) do isOn[n] = true end
  for _, x in ipairs(ns.Quests:Items(f)) do
    if x.mine and not x.chain then
      local with = {}
      for _, n in ipairs(x.others or {}) do if isOn[n] then with[#with + 1] = n end end
      if #with > 0 then return result(L.PLAY_QUEST:format(withYou(with), x.name), "invite", with) end
    end
  end
  return result((#online == 1 and L.PLAY_LEVEL_1 or L.PLAY_LEVEL_N):format(ns.Quests.NameList(online)), "invite", online)
end

-- Does what Play now says: Find group for the dungeon, else invite them.
function T:DoPlayNow(f)
  local p = self:PlayNow(f)
  if not p then return nil end
  if p.action == "find" then return self:FindGroup(f, p.key) end
  self:Invite(p.names)
  return p.names
end

---------------------------------------------------------------------------
-- Getting started (leader of a new fellowship): a short list that goes away when done or hidden
---------------------------------------------------------------------------
local function started(f)
  ns.char.started = type(ns.char.started) == "table" and ns.char.started or {}
  ns.char.started[f.id] = ns.char.started[f.id] or {}
  return ns.char.started[f.id]
end

-- The book remembers which pages this character has opened (Window:Refresh).
local VISITS = { rules = true, chapter = true, admin = true, quests = true }
function T:Visited(page)
  local f = F:Current()
  if f and VISITS[page] then started(f)[page] = true end
end

-- How long a new member's welcome stays (M21): until done, hidden, or this long after joining.
T.WELCOME_DAYS = 14

-- { { done, text } } and the card's label, or nil when it is not shown (hidden, or everything done).
-- The leader of a new fellowship: Getting started. A Hero who joined lately: the welcome (a new member got
-- nothing; seen in the tour review).
function T:Started(f)
  local s = started(f)
  if s.hidden then return nil end
  local steps, label
  if f.leader == ns.Me() then
    label = L.START_LABEL
    steps = {
      { done = F:Count(f) >= 2, text = L.START_INVITE }, { done = s.rules == true, text = L.START_RULES },
      { done = s.chapter == true, text = L.START_CHAPTER }, { done = s.admin == true, text = L.START_BOSSES },
    }
  else
    local m = f.members[ns.Me()]
    if not m or time() - (tonumber(m.joined) or 0) > self.WELCOME_DAYS * 86400 then return nil end
    label = L.WELCOME_LABEL
    steps = {
      { done = s.chapter == true, text = L.WELCOME_CHAPTER }, { done = s.rules == true, text = L.WELCOME_RULES },
      { done = s.quests == true, text = L.WELCOME_QUESTS },
    }
  end
  for _, st in ipairs(steps) do if not st.done then return steps, label end end
  return nil
end

function T:HideStarted()
  local f = F:Current()
  if f then started(f).hidden = true; ns:Fire("HEROES", true) end
end

---------------------------------------------------------------------------
-- A new size (27 Oct 2026): the fellowship's size never limits invites; when it grows (or shrinks) into another
-- size than its rules were made for, the Captain is told once (a toast) and keeps an inbox item with Use them /
-- Keep mine until they answer or the size changes again. Rules fine-tuned to a mix of their own are left alone.
---------------------------------------------------------------------------
local function kept() ns.char.sizeKept = type(ns.char.sizeKept) == "table" and ns.char.sizeKept or {}; return ns.char.sizeKept end

-- The size whose rules to suggest to me (the Captain) now, or nil.
function T:SizeHint(f)
  if not f or f.leader ~= ns.Me() then return nil end
  local key = ns.Rules.SizeSuggestion(f.rules, F:Count(f))
  if not key or kept()[f.id] == key then return nil end
  return key
end

function T:UseSize(key)
  local f = F:Current()
  if f and f.leader == ns.Me() then F:SetRules(ns.Rules.WithSize(f.rules, key)) end
end

function T:KeepSize(key)
  local f = F:Current()
  if not f then return end
  kept()[f.id] = key
  ns:Fire("HEROES", true)
end

-- Someone joined or left: the toast, once per suggested size.
ns:On("FELLOWSHIP", function()
  local f = F:Current()
  local key = T:SizeHint(f)
  if not key then return end
  ns.char.sizeToasted = type(ns.char.sizeToasted) == "table" and ns.char.sizeToasted or {}
  if ns.char.sizeToasted[f.id] == key then return end
  ns.char.sizeToasted[f.id] = key
  ns:Toast(nil, L.SIZE_HINT_TITLE, L.SIZE_HINT_TEXT:format(F:Count(f), ns.Rules.SizeWord(key)))
end)

---------------------------------------------------------------------------
-- How far a Hero is from a level, in words
---------------------------------------------------------------------------
local function levels(n)
  if n == math.floor(n) then return (n == 1 and L.LEVELS_1 or L.LEVELS_N):format(n) end
  return L.LEVELS_DEC:format(n)
end

-- "1.6 levels to the floor, about 2 hours at your pace." (or without the estimate when there is no pace)
local function howFar(f, name, target, mine)
  local h = Hr:Get(f, name) or {}
  local lvl = Hr:Level(f, name)
  local n = ns.Pace.LevelsTo(lvl, h.xp, h.xpMax, target)
  local _, sec = ns.Pace.ToLevel(lvl, h.xp, h.xpMax, target, h.pace)
  if sec then return (mine and L.YOU_FAR_ETA or L.HERO_FAR_ETA):format(levels(n), ns.TimeLeft(sec)) end
  return (mine and L.YOU_FAR or L.HERO_FAR):format(levels(n))
end

T.HowFar = howFar

-- Shared quests in my log that other Heroes are on: { names }, { quest names } (at most 3).
local function sharedQuests(f)
  local quests, heroes, seen = {}, {}, {}
  for _, x in ipairs(ns.Quests:Items(f)) do
    if x.mine and #x.others > 0 and #quests < 3 then
      quests[#quests + 1] = x.name
      for _, n in ipairs(x.others) do if not seen[n] then seen[n] = true; heroes[#heroes + 1] = n end end
    end
  end
  return heroes, quests
end

-- The journey's dungeons good for a level (their best levels include it): at most two, the ones you have not
-- cleared first, then by level. { dungeon rows (ns.DUNGEONS) }.
function T:GoodFor(f, lvl)
  local me, seen, list = ns.Me(), {}, {}
  for key in pairs(f.journey.place or {}) do
    local base = ns.BaseKey(key)
    local d = ns.Dungeon(base)
    if d and not seen[base] and lvl >= d[3] and lvl <= d[4] then
      seen[base] = true
      list[#list + 1] = { d = d, done = J:ClearedBy(f, key)[me] ~= nil }
    end
  end
  table.sort(list, function(a, b)
    if a.done ~= b.done then return not a.done end
    if a.d[3] ~= b.d[3] then return a.d[3] < b.d[3] end
    return a.d[2] < b.d[2]
  end)
  local out = {}
  for i = 1, math.min(2, #list) do out[i] = list[i].d end
  return out
end

---------------------------------------------------------------------------
-- The You card
---------------------------------------------------------------------------
-- { head, state (the head without the level, for the Overview card), lines = { { icon, text } }, online = { names } }
function T:You(f)
  local me = ns.Me()
  local lvl = Hr:Level(f, me)
  local ch = J:Current(f)
  local out = { lines = {}, online = self:Online(f) }
  local function add(icon, text) out.lines[#out.lines + 1] = { icon = icon, text = text } end
  if not ch then
    out.head, out.state = L.YOU_HEAD:format(lvl, L.YOU_DONE), L.YOU_DONE
    return out
  end
  local r = f.rules
  local fl = J:FloorLevel(f, ch)
  local below = J:Below(f, ch.n)
  if J:Away(f, me) then
    out.head, out.state = L.YOU_HEAD:format(lvl, L.YOU_AWAY), L.YOU_AWAY
    add("away", L.YOU_AWAY_TEXT)
    return out
  end
  local h = Hr:Get(f, me) or {}
  -- Levels to go count the XP you have, as on the Chapter page ("13 levels" here beside its "12.1"; seen in the
  -- check of 30 Oct 2026).
  local function togo(target) return levels(ns.Pace.LevelsTo(lvl, h.xp, h.xpMax, target)) end

  -- Below the floor: the catch-up card.
  if lvl < fl then
    out.state = L.YOU_BELOW:format(togo(fl))
    out.head = L.YOU_HEAD:format(lvl, out.state)
    -- Alone, there are no others waiting (the card said so to a new Captain; seen in the tour).
    local alone = F:Count(f) <= 1
    if alone then add("waiting", L.YOU_ALONE)
    -- New and catching up: the chapter goes on without waiting (Rules/Journey.lua, J:CatchingUp).
    elseif J:CatchingUp(f, me) then add("waiting", L.YOU_CATCHING)
    else add("waiting", #below == 1 and L.YOU_LAST or L.YOU_BELOW_TOO:format(#below - 1)) end
    add("level", howFar(f, me, fl, true))
    -- Where to catch up (M25): the journey's dungeons good for your level, the ones you have not cleared first.
    -- (Third, before rested XP: the Overview shows three lines.)
    -- Who is online is said once, after the dungeons (it was repeated for each one; seen in the check of 29 Oct).
    local good = self:GoodFor(f, lvl)
    if #good > 0 then
      local online = self:Online(f)
      local parts = {}
      for i, d in ipairs(good) do parts[i] = d[2] end
      local list = table.concat(parts, ", ")
      if #online > 0 then list = L.YOU_GOOD_ONLINE:format(list, ns.Quests.NameList(online)) end
      add("open", L.YOU_GOOD_FOR:format(lvl, list))
    end
    if h.rested and h.rested > 0 and h.xpMax and h.xpMax > 0 then
      add("rested", L.YOU_RESTED:format(math.min(150, math.floor(h.rested / h.xpMax * 100 + 0.5))))
    end
    local heroes, quests = sharedQuests(f)
    if #quests > 0 then add("quest", L.YOU_HELP_QUESTS:format(ns.Quests.NameList(heroes), table.concat(quests, ", "))) end
    if not alone then add("group", L.YOU_ASK_HELP) end
    return out
  end

  -- Ready, at or over the cap.
  local state
  if lvl > ch.cap + r.capTol then state = L.YOU_OVER:format(lvl - ch.cap)
  elseif lvl >= ch.cap then state = L.YOU_AT_CAP
  else state = L.YOU_READY:format(togo(ch.cap)) end
  out.head, out.state = L.YOU_HEAD:format(lvl, state), state
  -- Who is behind, and how to help them.
  for i, name in ipairs(below) do
    if i > 2 then break end
    add("waiting", L.BEHIND:format(ns.Short(name), Hr:Level(f, name), howFar(f, name, fl, false)))
  end
  if #below > 0 then add("group", L.HELP_RUN) end
  -- Ahead of someone who is not below the floor (M25): a run with them keeps you in step.
  local who, gap = ns.Progress:Ahead(f)
  local listed = false
  for _, name in ipairs(below) do if name == who then listed = true end end
  if who and not listed then add("waiting", L.YOU_AHEAD:format(gap, ns.Short(who))) end
  -- My next step.
  if #below == 0 then
    local nextKey
    for _, x in ipairs(J:Required(f, ch.n)) do
      if not nextKey and not J:Cleared(f, x.key) and J:Open(f, x.key) then nextKey = x end
    end
    if nextKey then
      local mineDone = J:ClearedBy(f, nextKey.key)[me] ~= nil
      add("open", (mineDone and L.YOU_NEXT_HELP or L.YOU_NEXT_RUN):format(nextKey.d[2]))
    elseif #J:Required(f, ch.n) == 0 and lvl < ch.cap then
      add("level", L.YOU_NEXT_LEVEL:format(ch.cap))
    end
  end
  if lvl >= ch.cap then add("cap", L.YOU_STOP_XP) end
  return out
end
