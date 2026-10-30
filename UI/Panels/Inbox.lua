-- Inbox panel (SPEC §4.13): invitations, asks to group up (Join / Not now), cap warnings and the tournament.
local _, ns = ...
local L = ns.L
local UI, Theme = ns.UI, ns.Theme
local Inbox = {}
ns.Inbox = Inbox

-- { text, important, actions = { { label, fn, style } } } items, most important first.
function Inbox:Items()
  local items = {}
  for _, item in ipairs(ns.Fellowship:MyInvites()) do
    -- Accept / Decline here too (the item was text only; seen in the tour). The role is the Join page's choice.
    local fid = item.fid
    items[#items + 1] = { text = L.INBOX_INVITE:format(ns.Short(item.inv.leader or item.inv.from), item.inv.name), important = true,
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
  if cap == "at" then items[#items + 1] = { text = L.WARN_AT_CAP, important = true }
  elseif cap == "close" then items[#items + 1] = { text = L.WARN_CLOSE:format(ch.cap), important = false } end
  -- The tournament: sign-up open, my next duel, and for the Guild Master the hand-over.
  local t = f and f.tourney
  if t then
    local me = ns.Me()
    if t.phase == "signup" and not t.signed[me] then items[#items + 1] = { text = L.INBOX_T_SIGNUP, important = false } end
    local m, other = ns.Tourney:MyMatch(f, me)
    if m then items[#items + 1] = { text = L.INBOX_T_DUEL:format(ns.Short(other)), important = true } end
    local _, _, rankIndex = GetGuildInfo("player")
    if t.phase == "done" and t.champion and t.champion ~= me and rankIndex == 0 then
      items[#items + 1] = { text = L.INBOX_T_HANDOVER:format(ns.Short(t.champion)), important = true }
    end
  end
  return items
end

function Inbox:Count() return #self:Items() end

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
    r.bar:SetColorTexture(Theme:RGBA(item.important and "C0392B" or "line"))
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
