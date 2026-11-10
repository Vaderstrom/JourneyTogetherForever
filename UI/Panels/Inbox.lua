-- Inbox panel (SPEC §4.13): invitations, asks to group up (Join / Not now), cap warnings, the tournament and, for the
-- Leader, what needs attention (U144; Fellowship/Attention.lua).
local _, ns = ...
local L = ns.L
local UI, Theme = ns.UI, ns.Theme
local Inbox = {}
ns.Inbox = Inbox

-- A button that closes the Inbox and opens a page.
local function go(page) return function() ns.Window:HidePanels(); ns.Window:ShowPage(page) end end

-- { text, important, actions = { { label, fn, style } }, key, seen } items, most important first. An item with a key
-- is a notice (U105): it has a button to where it is handled and Seen, which takes it off the count until its key
-- changes; seen ones come last, dimmed. Items with answers (invitations, votes) count until answered.
function Inbox:Items()
  local items = ns.SeenLast("inboxSeen", self:Gather())
  for _, item in ipairs(items) do
    if item.key and not item.seen then
      local key = item.key
      item.actions = item.actions or {}
      item.actions[#item.actions + 1] = { L.NOTICE_SEEN, function() Inbox:See(key) end, "plain" }
    end
  end
  return items
end

function Inbox:See(key)
  ns.MarkSeen("inboxSeen", key, self:Gather())
  ns.Window:Refresh()
end

function Inbox:Gather()
  local items = {}
  for _, item in ipairs(ns.Fellowship:MyInvites()) do
    -- Accept / Decline here too (the item was text only; seen in the tour). The role is the Join page's choice.
    local fid = item.fid
    items[#items + 1] = { text = (item.inv.friend and L.INBOX_INVITE_FRIEND or L.INBOX_INVITE):format(ns.Short(item.inv.leader or item.inv.from), item.inv.name), important = true,
      actions = { { L.ACCEPT, function() ns.Fellowship:AcceptInvite(fid, ns.CreateState.role) end, "primary" },
        { L.DECLINE, function() ns.Fellowship:DeclineInvite(fid) end, "plain" } } }
  end
  -- Gatherings I have not answered.
  local cur = ns.Fellowship:Current()
  for _, g in ipairs(cur and ns.Gatherings:Unanswered(cur) or {}) do
    local G = ns.Gatherings
    items[#items + 1] = { text = L.INBOX_GATHER:format(ns.Short(g.by), G.What(g), G.When(g.at)), important = true, actions = {
      { L.G_YES, function() G:Answer(g.id, "yes") end }, { L.G_MAYBE, function() G:Answer(g.id, "maybe") end },
      { L.G_NO, function() G:Answer(g.id, "no") end } } }
  end
  -- Rule votes I have not voted on.
  for _, v in ipairs(cur and ns.Votes:Unvoted(cur) or {}) do
    local R = ns.Rules
    items[#items + 1] = { text = L.INBOX_VOTE:format(ns.Short(v.by), R.Name(v.key), R.ValueText(v.key, v.value),
      R.ValueText(v.key, cur.rules[v.key])), important = true, actions = {
      { L.G_YES, function() ns.Votes:Vote(v.id, true) end }, { L.G_NO, function() ns.Votes:Vote(v.id, false) end } } }
  end
  for _, a in ipairs(ns.Quests:Asks()) do
    items[#items + 1] = { text = L.GROUP_ASKED_TEXT:format(ns.Short(a.from), a.q), important = true, actions = {
      { L.JOIN_GROUP, function() ns.Quests:Answer(a.from, true) end, "primary" },
      { L.NOT_NOW, function() ns.Quests:Answer(a.from, false) end, "plain" } } }
  end
  -- The Captain: rules for the fellowship's new size?
  local sizeKey = cur and ns.Together:SizeHint(cur)
  if sizeKey then
    items[#items + 1] = { text = L.INBOX_SIZE:format(ns.Fellowship:Count(cur), ns.Rules.SizeWord(sizeKey)), important = true, actions = {
      { L.SIZE_USE, function() ns.Together:UseSize(sizeKey) end, "primary" },
      { L.SIZE_KEEP, function() ns.Together:KeepSize(sizeKey) end, "plain" } } }
  end
  -- The cap warning (Settings: Warn before the cap).
  local f = ns.Fellowship:Current()
  local ch = f and ns.Journey:Current(f)
  local cap = f and ns.Progress:CapState(f, ch)
  if cap then
    items[#items + 1] = { key = ("cap:%s:%s:%d"):format(cap, f.id, ch.n), important = cap == "at",
      text = cap == "at" and L.WARN_AT_CAP or L.WARN_CLOSE:format(ch.cap), actions = { { L.OPEN_CHAPTER, go("chapter"), "primary" } } }
  end
  -- For the Leader, what needs attention (U144; on Manage until the rebuild): each with its button and Seen.
  for _, a in ipairs(f and ns.Attention:Gather(f) or {}) do
    local act = a.act[2]
    items[#items + 1] = { key = a.key, text = a.text, important = false,
      actions = { { a.act[1], function() ns.Window:HidePanels(); act() end, "primary" } } }
  end
  -- The tournament: sign-up open, my next duel, and for the Guild Master the hand-over.
  local t = f and f.tourney
  if t then
    local me = ns.Me()
    -- (A table each: Items adds Seen to it.)
    local function open() return { { L.INBOX_OPEN_TOURNEY, go("tourney"), "primary" } } end
    if t.phase == "signup" and not t.signed[me] then
      items[#items + 1] = { key = "tsign:" .. tostring(t.id), text = L.INBOX_T_SIGNUP, important = false, actions = open() }
    end
    local m, other = ns.Tourney:MyMatch(f, me)
    if m then
      items[#items + 1] = { key = ("tduel:%s:%s:%s"):format(tostring(t.id), tostring(t.slot), other),
        text = L.INBOX_T_DUEL:format(ns.Short(other)), important = true, actions = open() }
    end
    local _, _, rankIndex = GetGuildInfo("player")
    if t.phase == "done" and t.champion and t.champion ~= me and rankIndex == 0 then
      items[#items + 1] = { key = "thand:" .. tostring(t.id), text = L.INBOX_T_HANDOVER:format(ns.Short(t.champion)),
        important = true, actions = open() }
    end
  end
  return items
end

function Inbox:Count()
  local n = 0
  for _, item in ipairs(self:Items()) do if not item.seen then n = n + 1 end end
  return n
end

local function build(p)
  p.rows = UI.Pool(function()
    local r = UI.Card(p.body)
    r:SetWidth(p.width)
    r.bar = UI.Solid(r, "ARTWORK", "line")
    r.bar:SetPoint("TOPLEFT", 4, -4); r.bar:SetPoint("BOTTOMLEFT", 4, 4); r.bar:SetWidth(4)
    r.text = UI.WrapText(r, 14, "ink", p.width - 24)
    r.text:SetPoint("TOPLEFT", 14, -12)
    r.buttons = {}
    for i = 1, 3 do
      r.buttons[i] = UI.TextButton(r, "", function(b) if b.fn then b.fn() end end, i == 1 and "primary" or "plain", 12)
    end
    return r
  end)
  p.empty = UI.WrapText(p.body, 12, "ink2", p.width)
  p.empty:SetText(L.INBOX_EMPTY)
end

local function refresh(p)
  local items = Inbox:Items()
  local stack = UI.Stack(p.body)
  stack:Skip(10)
  local shown = 0
  for i, item in ipairs(items) do
    local r = p.rows:Get(i)
    if not r then break end
    shown = i
    r.text:SetText(item.text)
    r.text:SetTextColor(Theme:RGBA(item.seen and "ink2" or "ink"))
    r.bar:SetColorTexture(Theme:RGBA(item.important and not item.seen and "C0392B" or "line"))
    local h = r.text:GetStringHeight() + 24
    local x = 14
    for j, b in ipairs(r.buttons) do
      local a = item.actions and item.actions[j]
      b:SetShown(a ~= nil)
      if a then
        b.fn = a[2]
        b:SetLabel(a[1])
        b:ClearAllPoints(); b:SetPoint("TOPLEFT", r, "TOPLEFT", x, -(h - 6))
        x = x + b:GetWidth() + 8
      end
    end
    if item.actions then h = h + 30 end
    r:SetHeight(h)
    stack:Place(r, r:GetHeight(), 10)
  end
  p.rows:HideFrom(shown + 1)
  p.empty:SetShown(#items == 0)
  if #items == 0 then stack:Place(p.empty, 16, 0) end
  p.scroll:SetContentHeight(stack.y + 10)
end

ns.Window:RegisterPanel("inbox", { title = L.INBOX, build = build, refresh = refresh })

-- 1.4's Seen marks on Manage's Needs attention carry over to the Inbox, once (U144); the pages' first visits went
-- with U146 (walkPages).
ns:On("DB_READY", function()
  local c = ns.char
  if type(c.attSeen) == "table" then
    c.inboxSeen = type(c.inboxSeen) == "table" and c.inboxSeen or {}
    for k, v in pairs(c.attSeen) do if v == true then c.inboxSeen[k] = true end end
  end
  c.attSeen, c.walkPages = nil, nil
end)
