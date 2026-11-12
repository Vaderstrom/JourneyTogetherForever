-- Playing together (SPEC §6): your To do and Focus now (U139, U140), Play now's pick, your standing for the tracker,
-- and the actions that bring Adventurers together: invite to group and whisper. No frames here.
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

-- Other Heroes online now, highest level first. Not the Fallen: their journey ended, and their card shows no presence
-- (the Overview offered a Fallen to group with; seen in the check of 1 Nov 2026, 11:30).
function T:Online(f)
  local me, list = ns.Me(), {}
  for name in pairs(f.members) do
    if name ~= me and Hr:Online(f, name) and not (f.falls and ns.Challenges:Fallen(f, name)) then list[#list + 1] = name end
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
  local function result(kind, text, action, names, key)
    local grouped = true
    for _, n in ipairs(names) do if not here[n] then grouped = false end end
    return { kind = kind, text = text, action = action, names = names, key = key, grouped = grouped }
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
        local r = result("help", L.PLAY_HELP:format(ns.Short(name)), "invite", online)
        r.who = name
        return r
      end
    end
    if mineBelow then return result("helpme", L.PLAY_HELP_ME:format(ns.Quests.NameList(online)), "invite", online) end
    -- An open dungeon at least two of you still need (the first by level).
    for _, x in ipairs(J:Required(f, ch.n)) do
      if J:Open(f, x.key) and not J:Cleared(f, x.key) then
        local who, need, meToo = J:ClearedBy(f, x.key), {}, false
        if not who[me] then meToo = true end
        for _, name in ipairs(online) do if not who[name] then need[#need + 1] = name end end
        if #need + (meToo and 1 or 0) >= 2 then
          local list = meToo and withYou(need) or ns.Quests.NameList(need)
          return result("run", L.PLAY_RUN:format(x.d[2], list), "find", need, x.key)
        end
      end
    end
  end
  -- A quest you share with someone online.
  local isOn = {}
  for _, n in ipairs(online) do isOn[n] = true end
  for _, x in ipairs(ns.Quests:Items(f)) do
    if x.mine and not x.chain and not x.dungeon then
      local with = {}
      for _, n in ipairs(x.others or {}) do if isOn[n] then with[#with + 1] = n end end
      if #with > 0 then return result("quest", L.PLAY_QUEST:format(withYou(with), x.name), "invite", with) end
    end
  end
  return result("level", (#online == 1 and L.PLAY_LEVEL_1 or L.PLAY_LEVEL_N):format(ns.Quests.NameList(online)), "invite", online)
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
local VISITS = { rules = true, chapter = true, admin = true }
function T:Visited(page)
  local f = F:Current()
  if f and VISITS[page] then started(f)[page] = true end
end

-- The Leader of a new fellowship: { { done, text, page } }, the first items of the To do (SPEC §6, U140), or nil
-- when everything is done (or hidden on the old card). (A new Adventurer's welcome went with the rebuild: the To do
-- and the first tour show them the way, U146.)
function T:Started(f)
  local s = started(f)
  if s.hidden or f.leader ~= ns.Me() then return nil end
  local steps = {
    { done = F:Count(f) >= 2, text = L.START_INVITE, page = "heroes" },
    { done = s.rules == true, text = L.START_RULES, page = "rules" },
    { done = s.chapter == true, text = L.START_CHAPTER, page = "chapter" },
    { done = s.admin == true, text = L.START_BOSSES, page = "admin" },
  }
  for _, st in ipairs(steps) do if not st.done then return steps end end
  return nil
end

---------------------------------------------------------------------------
-- Your To do (U140, SPEC §4.5) and Focus now (U139, SPEC §4.4)
---------------------------------------------------------------------------
local function plural(n, one, many) return n == 1 and L[one] or L[many]:format(n) end

-- A dungeon row's state for you: its line, and the action at its right ("find": nothing to get first; "ready":
-- quests to get first), or wait (the chapter waits for the floor), and a short line for where the line does not fit
-- beside Find group (the check of 10 Nov 2026, 22:46: "Nothing to get first: its 4 quests start i...").
-- waiting: x's chapter is yours and waits for the floor. Its dungeons the game has opened then say what to get ready
-- meanwhile, dimmed and without a button; the waiting box above says what it waits for (the check of 11 Nov 2026,
-- 23:49).
local function dungeonLine(f, x, st, fl, waiting)
  if st == "cleared" then return L.STATE_CLEARED end
  if st == "locked" then
    if not waiting or x.early or not ns.IsOpen(x.key, f) then return L.TODO_WAIT:format(fl), nil, true end
    local line, _, _, short = dungeonLine(f, x, "open", fl)
    return line, nil, true, short
  end
  if x.early then return L.TODO_EARLY:format(J.Roman(x.early)) end
  -- Cleared by you while the clear rule waits for others (the owner, 11 Nov 2026): who still needs it, and Find group
  -- to help them, not Get ready.
  local who = J:ClearedBy(f, x.key)
  if who[ns.Me()] then
    local need, pacers = {}, J:Pacing(f)
    for _, name in ipairs(pacers) do if not who[name] then need[#need + 1] = name end end
    local mode = f.rules.clearMode
    -- Where the names do not fit beside the button: how many (the check of 11 Nov 2026, 23:49; the tooltip names them).
    if mode == "all" then return L.TODO_YOU_CLEARED:format(J.Names(f, need)), "find", nil, L.TODO_YOU_CLEARED_N:format(#need) end
    local more = math.max(1, (mode == "n" and math.min(f.rules.clearN, #pacers) or 1) - (#pacers - #need))
    return L.TODO_YOU_CLEARED_N:format(more), "find", nil, L.TODO_YOU_CLEARED_SHORT
  end
  local QL = ns.QuestLists
  local r = QL:Ready(f, x.key, ns.Me())
  if r and not r.ready then
    local parts = {}
    if r.early < r.earlyOf then parts[1] = plural(r.earlyOf - r.early, "TODO_CHAIN_1", "TODO_CHAIN_N") end
    if r.pick < r.pickOf then parts[#parts + 1] = plural(r.pickOf - r.pick, "TODO_PICK_1", "TODO_PICK_N") end
    return L.TODO_GET_READY:format(table.concat(parts, ", ")), "ready"
  end
  -- (Ready with a quest someone shares at the entrance, U177: not "in your log".)
  local shares = ns.Ready.Shares(r)
  if shares then return L.TODO_READY_SHARED:format(shares), "find", nil, L.TODO_READY_SHARED_SHORT end
  if r then return plural(r.quests, "TODO_READY_1", "TODO_READY_N"), "find" end
  local _, _, _, _, open = QL:Counts(f, x.key)
  if open and open > 0 then return plural(open, "TODO_INSIDE_1", "TODO_INSIDE_N"), "find", nil, L.TODO_NOTHING end
  return L.TODO_NOTHING, "find"
end

-- Your To do for chapter n, in order: the new Leader's first steps (the current chapter only), reach the floor, the
-- chapter's dungeons (the suggested order) and its Required milestones, steps for later dungeons still open (U136),
-- and under If you like the next chapter's dungeons that may be run now and the Optional milestones. Each item
-- { kind = "start" | "floor" | "dungeon" | "milestone" | "later" | "early", text or line, done }; a dungeon or early
-- one also has x, state, action ("find" | "ready") and wait; a milestone m and req; a later one e (QL:Later's entry).
-- noLater: without the steps for later dungeons (they cost the most; Focus now asks for them last).
function T:ToDo(f, n, noLater)
  local items, early = {}, {}
  local ch = f.journey.chapters[n]
  if not ch then return items end
  local me, now = ns.Me(), n == J:CurrentIndex(f)
  if now then
    for _, st in ipairs(self:Started(f) or {}) do items[#items + 1] = { kind = "start", text = st.text, done = st.done, page = st.page } end
  end
  local fl, lvl = J:FloorLevel(f, ch), Hr:Level(f, me)
  -- (A Friend of the fellowship never counts for the floor, SPEC §1.1.)
  if not F:IsFriend(f, me) then items[#items + 1] = { kind = "floor", text = L.TODO_FLOOR:format(fl), done = lvl >= fl } end
  for _, x in ipairs(J:ChapterList(f, n)) do
    local st = J:DungeonState(f, n, x)
    local line, action, wait, short = dungeonLine(f, x, st, fl, now and not J:Unlocked(f))
    local it = { kind = x.early and "early" or "dungeon", x = x, state = st, line = line, action = action, wait = wait,
      short = short, done = st == "cleared", you = J:ClearedBy(f, x.key)[me] ~= nil }
    if x.early then early[#early + 1] = it else items[#items + 1] = it end
  end
  -- The milestones (SPEC §2; the owner, 9 Nov 2026): Required ones hold the chapter, Optional ones are goals.
  for _, m in ipairs(ns.Milestones:List(f, n)) do
    local it = { kind = "milestone", m = m, req = m.req, done = ns.Milestones:Progress(f, m).done }
    if m.req then items[#items + 1] = it else early[#early + 1] = it end
  end
  if not noLater then
    for _, e in ipairs(ns.QuestLists:Later(f, n)) do
      items[#items + 1] = { kind = "later", e = e, x = e.x, line = ns.QuestLists.LaterLine(e) }
    end
  end
  for _, it in ipairs(early) do items[#items + 1] = it end
  return items
end

-- "All 4 of you still need it." for Focus now (SPEC §4.4), or nil when only you count.
local function needLine(f, key)
  local counted, who, n = J:Counted(f), J:ClearedBy(f, key), 0
  for _, name in ipairs(counted) do if not who[name] then n = n + 1 end end
  if #counted < 2 or n == 0 then return nil end
  if n == #counted then return n == 2 and L.FOCUS_NEED_BOTH or L.FOCUS_NEED_ALL:format(n) end
  return n == 1 and L.FOCUS_NEED_1 or L.FOCUS_NEED_N:format(n)
end

-- Focus now: the one thing to do now, the first open item of your chapter's To do, picked in Play now's order when
-- others are online (SPEC §4.4, §6). { head, why, button = { kind = "page" | "find" | "invite" | "ready", page, key,
-- names }, link = { page or key (a Dungeon page), text } }; the tracker shows head.
function T:Focus(f)
  local ch = J:Current(f)
  if not ch then return { head = L.FOCUS_RAIDS, why = L.FOCUS_RAIDS_WHY, button = { kind = "page", page = "raids" } } end
  local me = ns.Me()
  local items = self:ToDo(f, ch.n, true)
  local p = self:PlayNow(f)
  local invite = p and { kind = "invite", names = p.names } or nil
  local chapter = { page = "chapter", text = L.FOCUS_LINK_CHAPTER }
  local function page(x) return { key = x.key, text = L.FOCUS_LINK_DUNGEON } end
  for _, it in ipairs(items) do
    if it.kind == "start" and not it.done then
      -- Watching an alt's fellowship (Fellowship/Watch.lua): it is that character who leads it, not you.
      local why = (ns.Watch.rendering and not ns.Watch.demo) and L.FOCUS_START_WHY_WATCH:format(ns.Short(me)) or L.FOCUS_START_WHY
      return { head = it.text, why = why, button = { kind = "page", page = it.page } }
    end
  end
  local below = J:Below(f, ch.n)
  if not F:IsFriend(f, me) and Hr:Level(f, me) < J:FloorLevel(f, ch) then
    local others = {}
    for _, name in ipairs(below) do if name ~= me then others[#others + 1] = name end end
    local why = self.HowFar(f, me, J:FloorLevel(f, ch), true)
    if #others > 0 then why = why .. " " .. L.FOCUS_SAME_SPOT:format(ns.Quests.NameList(others)) end
    return { head = L.FOCUS_FLOOR:format(J:FloorLevel(f, ch)), why = why, button = invite, link = chapter }
  end
  if p and p.kind == "help" then
    return { head = L.FOCUS_HELP:format(ns.Short(p.who)), why = L.FOCUS_HELP_WHY, button = invite, link = chapter }
  end
  -- Play now's dungeon, else the first you still need (as Recommended next), else the first one you cleared.
  local pick
  for _, it in ipairs(items) do
    if it.kind == "dungeon" and not it.done and not it.wait then
      if p and p.key == it.x.key then pick = it break end
      if not pick or (pick.you and not it.you) then pick = it end
    end
  end
  if pick then
    -- (One you cleared: its line already names who still needs it.)
    local name, need = pick.x.d[2], not pick.you and needLine(f, pick.x.key)
    local why = need and (pick.line .. " " .. need) or pick.line
    if pick.action == "ready" then
      return { head = L.FOCUS_READY:format(name), why = why, button = { kind = "ready", key = pick.x.key }, link = page(pick.x) }
    end
    return { head = L.FOCUS_RUN:format(name), why = why, button = { kind = "find", key = pick.x.key }, link = page(pick.x) }
  end
  -- A Required milestone holds the chapter once its dungeons are done (SPEC §1: the To do lists it), before the steps
  -- for later dungeons, which never do.
  local ms = #below == 0 and ns.Milestones:OpenRequired(f, ch.n)[1]
  if ms then return { head = L.FOCUS_MILESTONE:format(ms.name), why = ns.Milestones:ProgressText(f, ms), link = chapter } end
  local e = ns.QuestLists:Later(f, ch.n)[1] -- (each has a step at least)
  if e then
    return { head = L.FOCUS_PREPARE:format(e.x.d[2]), why = ns.QuestLists.LaterLine(e),
      button = { kind = "ready", key = e.x.key }, link = page(e.x) }
  end
  if #below > 0 then
    return { head = L.FOCUS_WAITING, why = L.NEXT_WAITING:format(J.Names(f, below, true), J:FloorLevel(f, ch)), button = invite, link = chapter }
  end
  if p then return { head = L.FOCUS_TOGETHER, why = p.text, button = invite } end
  if Hr:Level(f, me) < ch.cap then return { head = L.FOCUS_LEVEL:format(ch.cap), why = L.FOCUS_LEVEL_WHY, link = chapter } end
  return { head = L.FOCUS_DONE, why = L.FOCUS_DONE_WHY, link = chapter }
end

-- The tracker's Prequest line (U124): the next step of a chain for your chapter's dungeons (not cleared) or a later
-- dungeon's, once your level reaches it and it is not in your log yet. { text, key } or nil.
function T:StartEarly(f)
  local QL = ns.QuestLists
  local cur, me = J:CurrentIndex(f), ns.Me()
  local lvl = Hr:Level(f, me)
  local keys = {}
  for _, x in ipairs(J:ChapterList(f, cur)) do
    if not x.early and not J:Cleared(f, x.key) then keys[#keys + 1] = x.key end
  end
  for _, e in ipairs(QL:Later(f, cur)) do keys[#keys + 1] = e.x.key end
  for _, key in ipairs(keys) do
    local g = QL:Groups(f, key, me)
    for _, q in ipairs(g and g.earlier or {}) do
      -- (The dungeon quest already in your log or done: nothing to start, as Who is ready counts it.)
      for _, s in ipairs(q.status == "no" and q.steps or {}) do
        if s.status ~= "done" then
          -- The chain's next step: open now and not picked up yet, or nothing to say for this chain.
          if s.status == "no" and s.lvl and s.lvl <= lvl then
            local st = s.start or {}
            local where = st.by and st.zone and L.TRACK_BY_IN:format(st.by, st.zone) or st.by or st.zone
            return { text = L.TRACK_EARLY:format(s.name .. (where and (", " .. where) or "")), key = key }
          end
          break
        end
      end
    end
  end
  return nil
end

-- Does what Focus now's button says.
function T:DoFocus(f, b)
  if not b then return end
  if b.kind == "invite" then self:Invite(b.names)
  elseif b.kind == "find" then self:FindGroup(f, b.key)
  elseif b.kind == "ready" then ns.DungeonPage:Open(b.key)
  elseif b.page then ns.Window:ShowPage(b.page) end
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

---------------------------------------------------------------------------
-- Your standing, for the tracker (the You card went with the rebuild, U139)
---------------------------------------------------------------------------
-- { head ("Level 19 · 2.6 to the cap"), state (the head without the level) }.
function T:You(f)
  local me = ns.Me()
  local lvl = Hr:Level(f, me)
  local ch = J:Current(f)
  local state
  if not ch then state = L.YOU_DONE
  elseif F:IsFriend(f, me) then state = L.YOU_FRIEND -- (nothing to reach, SPEC §1.1)
  elseif J:Away(f, me) then state = L.YOU_AWAY
  else
    -- Levels to go count the XP you have, as on the Chapter page; the number alone, so the line fits the tracker
    -- ("Ready, 2.6 levels to the cap" took two lines; the owner's pick of 9 Nov 2026).
    local h = Hr:Get(f, me) or {}
    local function togo(target)
      local n = ns.Pace.LevelsTo(lvl, h.xp, h.xpMax, target)
      return n == math.floor(n) and ('%d'):format(n) or L.LEVELS_NUM:format(n)
    end
    local fl = J:FloorLevel(f, ch)
    if lvl < fl then state = L.YOU_BELOW:format(togo(fl))
    elseif lvl > J:CapLevel(f, ch) then state = L.YOU_OVER:format(lvl - ch.cap)
    elseif lvl >= ch.cap then state = L.YOU_AT_CAP
    else state = L.YOU_READY:format(togo(ch.cap)) end
  end
  return { head = L.YOU_HEAD:format(lvl, state), state = state }
end
