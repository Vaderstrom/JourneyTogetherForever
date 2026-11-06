-- Fellowship Rules (SPEC §3, §6). One file, two pages:
--   rules       the rulebook (28 Oct 2026; it looked like a settings form, so how the rules are set was unclear):
--               left page the rules as numbered articles in plain sentences, the values in colour; right page
--               "Change a rule": the open votes with Yes / No, Propose a change (a rule and a new value; everyone
--               votes) and the votes decided this week. The Leader votes too, and changes the rules in Fellowship
--               Management. Following another character's fellowship: read only.
--   rulesadmin  the Leader's, the Rules tab of Manage (UI/Pages/Manage.lua): the form on a draft, then
--               Publish (everyone gets a toast and a History line) or Discard. Like Journey Admin.
local _, ns = ...
local L = ns.L
local UI, Theme = ns.UI, ns.Theme
local F, R, V = ns.Fellowship, ns.Rules, ns.Votes

-- The values in the rulebook: a deep red-brown that stands out from the ink (the gold was hard to read on parchment;
-- 28 Oct 2026), lifted to a warm gold on the Night theme (Theme.DARK_LIFT).
local VALUE = "963A0E"

local function copy(t)
  local out = {}
  for k, v in pairs(t) do out[k] = v end
  return out
end

---------------------------------------------------------------------------
-- The votes (both pages of the rulebook use the same rows)
---------------------------------------------------------------------------
local function voteText(f, v)
  -- Decided votes compare with the value the rule had when it was proposed.
  -- (A passed vote said "3 (now 4)" after the rule had become 3; seen in the check, 28 Oct 2026.)
  local st = V:Status(f, v)
  local text = st == "passed" and L.V_PROPOSED_PASSED or ((st == "open" or st == "passing") and L.V_PROPOSES or L.V_PROPOSED)
  local was = (v.result == "passed" and v.old ~= nil) and v.old or f.rules[v.key]
  return text:format(ns.Short(v.by), R.Name(v.key), R.ValueText(v.key, v.value), R.ValueText(v.key, was))
end

local function statusText(f, v)
  local st = V:Status(f, v)
  local yes, no, need = V:Counts(f, v)
  if st == "passed" or st == "passing" then return L.V_ST_PASSED, "3E7A3A" end
  if st == "done" then return L.V_ST_DONE, "ink2" end
  if st == "failed" then return L.V_ST_FAILED:format(yes, no), "B0321E" end
  return L.V_ST_OPEN:format(yes, no, need, ns.TimeLeft(v.ends - time())), "ink2"
end

local function voteRows(parent, width)
  return UI.Pool(function()
    local r = CreateFrame("Frame", nil, parent)
    r:SetWidth(width)
    r.text = UI.WrapText(r, 13, "ink", width - 8, "book")
    r.text:SetPoint("TOPLEFT", 4, 0)
    r.status = UI.WrapText(r, 11, "ink2", width - 8)
    r.ballot = UI.Choice(r, { { L.G_YES, true }, { L.G_NO, false } }, function() return r.v and r.v.ballots[ns.Me()] end,
      function(v) if r.v then V:Vote(r.v.id, v) end end)
    return r
  end)
end

-- One vote on the stack: who proposes what, how it stands, and Yes / No while it is open (not when following).
local function placeVote(r, f, v, s, canVote)
  r.v = v
  r.text:SetText(voteText(f, v))
  local top = r.text:GetStringHeight() + 2
  local text, color = statusText(f, v)
  r.status:SetText(text)
  r.status:SetTextColor(Theme:RGBA(color))
  r.status:ClearAllPoints(); r.status:SetPoint("TOPLEFT", 4, -top)
  top = top + r.status:GetStringHeight() + 4
  local open = V:Status(f, v) == "open" and canVote
  r.ballot:SetShown(open)
  if open then
    r.ballot:Refresh()
    r.ballot:ClearAllPoints(); r.ballot:SetPoint("TOPLEFT", 4, -top)
    top = top + 28
  end
  r:SetHeight(top)
  r:Show()
  s:Place(r, top, 8)
end

---------------------------------------------------------------------------
-- The rulebook (rules)
---------------------------------------------------------------------------
-- The rules to propose a change to, in the rulebook's order: "II  ·  Adventurers needed for a run".
local function ruleOptions()
  local opts = {}
  for i, a in ipairs(R.BOOK) do
    for _, key in ipairs(a.rules) do opts[#opts + 1] = { ns.Journey.Roman(i) .. "  ·  " .. R.Name(key), key } end
  end
  return opts
end

-- A challenge in the rulebook (the check of 1 Nov 2026, 14:32: eleven rules ran together as one paragraph): its icon in
-- a gold ring, its name and rule, then who broke it (in red) and what stands now, each on a line of its own.
-- :Set(item of ns.Challenges:Book) returns the height.
local BLOCK_ICON, BLOCK_IN = 26, 38
local ROAD_STEP, ROAD_ICON, ROAD_ROW = 74, 26, 50
local BROKEN = "B0321E"
local function chalBlock(parent, width)
  local b = CreateFrame("Frame", nil, parent)
  b:SetWidth(width)
  b.ring = UI.Round(b, "BORDER", BLOCK_ICON + 4)
  b.ring:SetPoint("TOPLEFT", 0, 0)
  Theme:Fill(b.ring, "gold", 0.9)
  b.icon = UI.Round(b, "ARTWORK", BLOCK_ICON)
  b.icon:SetPoint("CENTER", b.ring)
  b.name = UI.WrapText(b, 14, "ink", width - BLOCK_IN, "title")
  b.name:SetPoint("TOPLEFT", BLOCK_IN, -2)
  b.rule = UI.WrapText(b, 13, "ink", width - BLOCK_IN, "book")
  b.rule:SetPoint("TOPLEFT", b.name, "BOTTOMLEFT", 0, -3)
  b.broken = UI.WrapText(b, 12, BROKEN, width - BLOCK_IN, "book")
  b.notes = UI.WrapText(b, 12, "ink2", width - BLOCK_IN, "book")
  -- The Ring's road (U58): each bearer a step with their class icon, joined by a gold line, the Ring on who carries
  -- it now.
  b.roadHead = UI.Text(b, 12, "ink2", "title")
  b.roadHead:SetText(L.RING_ROAD_HEAD)
  b.steps = UI.Pool(function()
    local st = CreateFrame("Frame", nil, b)
    st:SetSize(ROAD_STEP, ROAD_ROW)
    st.line = UI.Solid(st, "BACKGROUND", "gold", 0.8)
    st.line:SetHeight(2)
    st.line:SetPoint("RIGHT", st, "TOP", -ROAD_ICON / 2 - 2, -ROAD_ICON / 2 - 2)
    st.line:SetWidth(ROAD_STEP - ROAD_ICON - 4)
    st.crest = UI.ClassCrest(st, ROAD_ICON + 4)
    st.crest:SetPoint("TOP", 0, 0)
    st.ring = UI.Round(st, "OVERLAY", 16)
    st.ring:SetPoint("CENTER", st.crest, "TOPRIGHT", -3, -3)
    UI.SetIcon(st.ring, ns.ICONS.chal_ring)
    st.name = UI.Text(st, 11, "ink", "body", "CENTER")
    st.name:SetPoint("TOP", st.crest, "BOTTOM", 0, -2)
    st.name:SetWidth(ROAD_STEP - 4)
    return st
  end)
  function b:Road(steps, y, f)
    self.roadHead:SetShown(steps ~= nil)
    if not steps then self.steps:HideFrom(1); return y end
    self.roadHead:ClearAllPoints(); self.roadHead:SetPoint("TOPLEFT", BLOCK_IN, -(y + 6))
    y = y + 6 + 16
    local per = math.max(1, math.floor((width - BLOCK_IN) / ROAD_STEP))
    local n = 0
    for i, one in ipairs(steps) do
      local st = self.steps:Get(i)
      if not st then break end
      n = i
      local col, row = (i - 1) % per, math.floor((i - 1) / per)
      st:ClearAllPoints(); st:SetPoint("TOPLEFT", BLOCK_IN + col * ROAD_STEP, -(y + row * ROAD_ROW))
      local _, token = ns.Hero:ClassName(f, one.name)
      st.crest:Set(token)
      st.name:SetText(ns.Short(one.name))
      st.ring:SetShown(one.bearer == true)
      st.line:SetShown(col > 0)
      st.bearer = one.bearer
      st:Show()
    end
    self.steps:HideFrom(n + 1)
    return y + math.ceil(n / per) * ROAD_ROW
  end
  function b:Set(it, f)
    self.key = it.key
    if not UI.SetIcon(self.icon, ns.Challenges:Icon(it.key)) then UI.SetIcon(self.icon, ns.ICONS.hist_challenge) end
    self.name:SetText(it.title)
    self.rule:SetText(it.rule)
    local h = 2 + self.name:GetStringHeight() + 3 + self.rule:GetStringHeight()
    self.broken:SetShown(it.broken ~= nil)
    if it.broken then
      self.broken:SetText(it.broken)
      self.broken:ClearAllPoints(); self.broken:SetPoint("TOPLEFT", BLOCK_IN, -(h + 5))
      h = h + 5 + self.broken:GetStringHeight()
    end
    self.notes:SetShown(#it.notes > 0)
    if #it.notes > 0 then
      self.notes:SetText(table.concat(it.notes, "\n"))
      self.notes:ClearAllPoints(); self.notes:SetPoint("TOPLEFT", BLOCK_IN, -(h + 5))
      h = h + 5 + self.notes:GetStringHeight()
    end
    h = self:Road(it.road, h, f)
    h = math.ceil(math.max(h, BLOCK_ICON + 4))
    self:SetHeight(h)
    return h
  end
  return b
end

-- The challenges' tiles on the right page (UI.NumberTile), two to a row.
local TILE_H, TILE_GAP = 58, 8

local function buildBook(pf)
  local W = ns.Window
  local width = W.PAGE_W - 10
  pf.lscroll = UI.Scroll(pf.left)
  pf.lscroll:SetAllPoints()
  pf.rscroll = UI.Scroll(pf.right)
  pf.rscroll:SetAllPoints()
  local Lc, Rc = pf.lscroll.child, pf.rscroll.child

  -- Left: who sets the rules, the play style and size, then the articles.
  pf.who = UI.WrapText(Lc, 12, "ink2", width, "book")
  pf.intro = UI.WrapText(Lc, 13, "ink", width, "book")
  pf.articles = {}
  for i = 1, #R.BOOK do
    local a = { head = UI.SectionHeader(Lc, width), text = UI.WrapText(Lc, 13, "ink", width, "book") }
    pf.articles[i] = a
  end
  -- The challenges chosen at founding (SPEC §9), an article after the rules when the fellowship has or had one: a
  -- line on them, a block for each challenge on (the shared lives' candles under its own), then the lines of none.
  pf.chal = { head = UI.SectionHeader(Lc, width), intro = UI.WrapText(Lc, 13, "ink", width, "book"),
    after = UI.WrapText(Lc, 13, "ink", width, "book") }
  pf.chal.blocks = UI.Pool(function() return chalBlock(Lc, width) end)
  pf.chal.lives = UI.Lives(Lc, width - BLOCK_IN)
  -- The words of the whole article, as one paragraph (the self-test looks in it).
  function pf.chal:Text() return self.book and self.book.text or "" end

  -- Right: change a rule.
  pf.cHead = UI.Heading(Rc, width, L.CHANGE_RULE, "")
  pf.openHead = UI.SectionHeader(Rc, width)
  pf.openHead:SetText(L.OPEN_VOTES)
  pf.vRows = voteRows(Rc, width)
  pf.vNone = UI.SketchLine(Rc, width, "EmptyVotes")
  pf.vNone:SetText(L.OPEN_VOTES_NONE)
  pf.pHead = UI.SectionHeader(Rc, width)
  pf.pHead:SetText(L.PROPOSE_HEAD)
  pf.ruleLabel = UI.Text(Rc, 13, "ink2")
  pf.ruleLabel:SetText(L.PROPOSE_RULE)
  local opts = ruleOptions()
  pf.pkey = opts[1][2]
  pf.rule = UI.Dropdown(Rc, width, opts, function() return pf.pkey end, function(key) pf.pkey, pf.pval = key, nil; W:Refresh() end)
  pf.valueLabel = UI.Text(Rc, 13, "ink2")
  pf.valueLabel:SetText(L.PROPOSE_VALUE)
  pf.value = UI.Dropdown(Rc, width - 110, {}, function() return pf.pval end, function(v) pf.pval = v; W:Refresh() end)
  -- (The longest list's rows made now, not during combat: away after 1-30 days.)
  pf.value:SetOptions(R.Choices("awayDays"))
  pf.propose = UI.TextButton(Rc, L.PROPOSE, function()
    local f = F:Current()
    if not pf.canPropose or not f or pf.pval == nil or V:OpenFor(f, pf.pkey) then return end
    V:Propose(pf.pkey, pf.pval)
    pf.pval = nil
    W:Refresh()
  end, "primary", 13)
  pf.now = UI.Text(Rc, 12, "ink2")
  pf.pNote = UI.WrapText(Rc, 12, "B0321E", width)
  pf.pNote:SetText(L.PROPOSE_OPEN)
  -- The Leader sets the rules in Manage; following another character: read only.
  pf.leaderBox = UI.Card(Rc, "gold")
  pf.leaderBox:SetWidth(width)
  pf.leaderText = UI.WrapText(pf.leaderBox, 13, "ink", width - 24, "book")
  pf.leaderText:SetPoint("TOPLEFT", 12, -10)
  pf.leaderText:SetText(L.PROPOSE_LEADER)
  pf.toAdmin = UI.TextButton(pf.leaderBox, L.OPEN_RULES_TAB, function() W:ShowPage("rulesadmin") end, "plain", 12)
  pf.watchText = UI.WrapText(Rc, 12, "ink2", width)
  pf.watchText:SetText(L.PROPOSE_WATCH)
  pf.dHead = UI.SectionHeader(Rc, width)
  pf.dHead:SetText(L.DECIDED_VOTES)
  -- Under Propose a change, while a challenge is on: where the challenges stand, as number tiles.
  pf.tilesHead = UI.SectionHeader(Rc, width)
  pf.tilesHead:SetText(L.CHAL_TILES)
  pf.tiles = {}
  local tw = math.floor((width - TILE_GAP) / 2)
  for i = 1, 4 do pf.tiles[i] = UI.NumberTile(Rc, tw, TILE_H) end
end

local function refreshBook(pf, ctx)
  local f = ctx.f
  if not f then return end
  local hex = Theme:HexFor(VALUE)
  local function hl(text) return "|cff" .. hex .. text .. "|r" end

  -- Following another character (the walkthrough's sample is drawn the same way, but shows the page as its rank
  -- sees it: it said "From another character..." where the tour says "propose a change"; seen in the seventh check).
  local follow = ctx.watching == true and not ctx.demo

  -- Left page.
  local s = UI.Stack(pf.lscroll.child)
  pf.who:SetText(follow and L.BOOK_WHO_WATCH:format(ns.TimeAgo(ns.Watch:AsOf(f))) or L.BOOK_WHO:format(ns.Short(f.leader)))
  s:Place(pf.who, pf.who:GetStringHeight(), 8)
  local count, made = F:Count(f), R.SizeOf(f.rules)
  local size = made == "custom" and L.BOOK_SIZE_CUSTOM:format(count) or L.BOOK_SIZE:format(hl(R.SizeWord(made)), count)
  pf.intro:SetText(L.BOOK_STYLE:format(hl(R.StyleName(R.StyleOf(f.rules)))) .. " " .. size)
  s:Place(pf.intro, pf.intro:GetStringHeight(), 12)
  for i, a in ipairs(R.Book(f.rules, hl)) do
    local art = pf.articles[i]
    art.head:SetText(ns.Journey.Roman(i) .. ".  " .. a.title)
    s:Place(art.head, 29, 4)
    local text = a.text
    -- The tournament pauses by itself while the fellowship is not one guild with its Guild Master.
    if R.BOOK[i].title == "BOOK_TOURNEY" and f.rules.gmT and F:TournamentState(f) ~= "on" then text = text .. " " .. L.COND_NOT end
    art.text:SetText(text)
    s:Place(art.text, art.text:GetStringHeight(), 12)
  end
  local chal = ns.Challenges:Book(f, hl)
  local c = pf.chal
  c.book = chal
  c.head:SetShown(chal ~= nil); c.intro:SetShown(chal ~= nil)
  local lives = chal and ns.Challenges:LivesView(f)
  c.lives:Hide()
  local nb = 0
  if chal then
    c.head:SetText(ns.Journey.Roman(#R.BOOK + 1) .. ".  " .. chal.title)
    s:Place(c.head, 29, 4)
    c.intro:SetText(chal.intro)
    s:Place(c.intro, c.intro:GetStringHeight(), 12)
    for _, it in ipairs(chal.items) do
      local b = c.blocks:Get(nb + 1)
      if not b then break end
      nb = nb + 1
      s:Place(b, b:Set(it, f), 12)
      if it.key == "shared" and lives then
        c.lives:SetTip(lives.title, lives.lines)
        s:Skip(-4)
        s:Place(c.lives, c.lives:Set(lives.total, lives.left), 14, BLOCK_IN)
      end
    end
  end
  c.blocks:HideFrom(nb + 1)
  local after = chal ~= nil and #chal.after > 0
  c.after:SetShown(after)
  if after then
    c.after:SetText(table.concat(chal.after, "\n"))
    s:Place(c.after, c.after:GetStringHeight(), 12)
  end
  pf.lscroll:SetContentHeight(s.y + 8)

  -- Right page: how a change is made, the open votes, Propose (or the Leader's way), the votes decided this week.
  local t = UI.Stack(pf.rscroll.child)
  local need = math.floor(#ns.Journey:Counted(f) / 2) + 1
  pf.cHead:Set(L.CHANGE_RULE, need == 1 and L.CHANGE_HOW_1 or L.CHANGE_HOW:format(need))
  t:Place(pf.cHead, pf.cHead:GetHeight(), 4)
  t:Place(pf.openHead, 29, 6)
  local open, done = {}, {}
  for _, v in ipairs(V:List(f)) do
    local st = V:Status(f, v)
    if st == "open" or st == "passing" then open[#open + 1] = v else done[#done + 1] = v end
  end
  local n = 0
  for _, v in ipairs(open) do
    local r = pf.vRows:Get(n + 1)
    if not r then break end
    n = n + 1
    placeVote(r, f, v, t, not ctx.watching and not ctx.isFriend)
  end
  pf.vNone:SetShown(#open == 0)
  if #open == 0 then t:Place(pf.vNone, pf.vNone.h, 6) end
  t:Skip(10)

  t:Place(pf.pHead, 29, 6)
  -- Adventurers propose; the Leader changes the rules in Manage; nothing for a follower. The walkthrough's sample
  -- shows the form, but Propose does nothing there (its proposal would go to your own fellowship).
  -- A Friend of the fellowship reads the votes (SPEC §1.1): the rules are the counted Adventurers'.
  local friend = ctx.isFriend and not follow
  local showForm = not follow and not ctx.isLeader and not friend
  pf.canPropose = showForm and not ctx.demo
  local form = { pf.ruleLabel, pf.rule, pf.valueLabel, pf.value, pf.propose, pf.now }
  for _, w in ipairs(form) do w:SetShown(showForm) end
  pf.pNote:Hide()
  pf.leaderBox:SetShown(ctx.isLeader and not follow)
  pf.watchText:SetShown(follow or friend)
  pf.watchText:SetText(friend and L.PROPOSE_FRIEND or L.PROPOSE_WATCH)
  if showForm then
    local key, now = pf.pkey, f.rules[pf.pkey]
    local opts, keep = {}, false
    for _, o in ipairs(R.Choices(key)) do
      if o[2] ~= now then
        opts[#opts + 1] = o
        if o[2] == pf.pval then keep = true end
      end
    end
    if not keep then pf.pval = opts[1] and opts[1][2] end
    pf.rule:Refresh()
    pf.value:SetOptions(opts)
    t:Place(pf.ruleLabel, 16, 2)
    t:Place(pf.rule, 26, 8)
    t:Place(pf.valueLabel, 16, 2)
    local y = t.y
    t:Place(pf.value, 26, 4)
    pf.propose:ClearAllPoints(); pf.propose:SetPoint("TOPRIGHT", pf.rscroll.child, "TOPRIGHT", 0, -y + 1)
    pf.now:SetText(L.PROPOSE_NOW:format(R.ValueText(key, now)))
    t:Place(pf.now, 16, 4)
    local busy = V:OpenFor(f, key) ~= nil
    pf.propose:SetEnabled(not busy and pf.pval ~= nil)
    if busy then
      pf.pNote:Show()
      t:Place(pf.pNote, pf.pNote:GetStringHeight(), 4)
    end
  elseif ctx.isLeader and not follow then
    pf.toAdmin:SetShown(not ctx.demo)
    local h = pf.leaderText:GetStringHeight() + 20
    if pf.toAdmin:IsShown() then
      pf.toAdmin:ClearAllPoints(); pf.toAdmin:SetPoint("TOPLEFT", 12, -h)
      h = h + 34
    end
    pf.leaderBox:SetHeight(h)
    t:Place(pf.leaderBox, h, 4)
  else
    t:Place(pf.watchText, pf.watchText:GetStringHeight(), 4)
  end

  -- Where the challenges stand: the lives left, the race clock, the Ring, the rules broken.
  local tiles = ns.Challenges:Tiles(f) or {}
  pf.tilesHead:SetShown(#tiles > 0)
  if #tiles > 0 then
    t:Skip(10)
    t:Place(pf.tilesHead, 29, 8)
    for i, tile in ipairs(pf.tiles) do
      local x = tiles[i]
      tile:SetShown(x ~= nil)
      if x then
        tile.key = x.key
        tile:Set(x.value); tile:SetLabel(x.label); tile:SetIcon(x.icon)
        tile:ClearAllPoints()
        tile:SetPoint("TOPLEFT", pf.rscroll.child, "TOPLEFT", ((i - 1) % 2) * (tile:GetWidth() + TILE_GAP),
          -(t.y + math.floor((i - 1) / 2) * (TILE_H + TILE_GAP)))
      end
    end
    t:Skip(math.ceil(#tiles / 2) * (TILE_H + TILE_GAP))
  else
    for _, tile in ipairs(pf.tiles) do tile:Hide() end
  end

  pf.dHead:SetShown(#done > 0)
  if #done > 0 then
    t:Skip(10)
    t:Place(pf.dHead, 29, 6)
    for _, v in ipairs(done) do
      local r = pf.vRows:Get(n + 1)
      if not r then break end
      n = n + 1
      placeVote(r, f, v, t, false)
    end
  end
  pf.vRows:HideFrom(n + 1)
  pf.rscroll:SetContentHeight(t.y + 8)
end

---------------------------------------------------------------------------
-- The Rules tab of Manage (rulesadmin)
---------------------------------------------------------------------------
-- The rules in the draft that differ from the fellowship's: { key, ... } in a fixed order.
local function changed(f, draft)
  local keys = {}
  if not draft then return keys end
  for k, v in pairs(draft) do if f.rules[k] ~= v then keys[#keys + 1] = k end end
  table.sort(keys)
  return keys
end

local function buildAdmin(pf)
  local W = ns.Window
  local width = W.PAGE_W - 10
  local top = ns.ManageTabs(pf)
  pf.lscroll = UI.Scroll(pf.left)
  pf.lscroll:SetPoint("TOPLEFT", 0, -top); pf.lscroll:SetPoint("BOTTOMRIGHT")
  pf.rscroll = UI.Scroll(pf.right)
  pf.rscroll:SetAllPoints()
  local Lc = pf.lscroll.child

  pf.yourPart = UI.Card(Lc, "gold")
  pf.yourPart:SetWidth(width)
  pf.yourPart.text = UI.WrapText(pf.yourPart, 13, "ink", width - 24, "book")
  pf.yourPart.text:SetPoint("TOPLEFT", 12, -9)
  pf.yourPart.text:SetText(L.RULES_YOU_ADMIN)
  -- The draft: what changed, Publish and Discard.
  pf.draftBox = UI.Card(Lc, "gold")
  pf.draftBox:SetWidth(width)
  pf.draftText = UI.WrapText(pf.draftBox, 13, "ink", width - 24, "book")
  pf.draftText:SetPoint("TOPLEFT", 12, -10)
  pf.propose = UI.TextButton(pf.draftBox, L.PUBLISH, function()
    if not F:Current() or not pf.draft then return end
    W:Confirm(L.RULES_PUBLISH_CONFIRM, L.PUBLISH, function()
      if F:SetRules(pf.draft) then pf.draft = nil; ns:Toast(nil, L.RULES_PUBLISHED_T, L.RULES_PUBLISHED_YOU) end
      W:Refresh()
    end)
  end, "primary", 12)
  pf.undo = UI.TextButton(pf.draftBox, L.DISCARD, function() pf.draft = nil; W:Refresh() end, "plain", 12)
  -- The challenges chosen at founding (SPEC §9): none can be added; each can be turned off, for good (asks first).
  pf.chalHead = UI.SectionHeader(Lc, width)
  pf.chalHead:SetText(L.MG_CHAL_HEAD)
  pf.chalText = UI.WrapText(Lc, 12, "ink2", width, "book")
  pf.chalText:SetText(L.MG_CHAL_TEXT)
  pf.chalRows = UI.Pool(function()
    local r = CreateFrame("Frame", nil, Lc)
    r:SetSize(width, 28)
    r.name = UI.Text(r, 13, "ink")
    r.name:SetPoint("LEFT", 4, 0)
    r.off = UI.TextButton(r, L.MG_CHAL_TURN_OFF, function()
      local key = r.key
      if not key then return end
      W:Confirm(L.MG_CHAL_CONFIRM:format(ns.Challenges:Name(key, r.v)), L.MG_CHAL_TURN_OFF, function()
        ns.Challenges:TurnOff(key)
        W:Refresh()
      end)
    end, "plain", 12)
    r.off:SetPoint("RIGHT")
    -- (One Ironman Fellowship holds: not turned off while it is on.)
    r.held = UI.Text(r, 12, "ink2", nil, "RIGHT")
    r.held:SetPoint("RIGHT", -4, 0); r.held:SetText(L.MG_CHAL_INCLUDED)
    return r
  end)
  -- Fellowship size and play style (27 Oct 2026), each one choice above the full form: the size sets the numbers
  -- (Adventurers per run, who must clear, away time), the style the slack. Both go into the draft.
  local function apply(fn)
    local f = F:Current()
    if not f then return end
    pf.draft = fn(pf.draft or f.rules); W:Refresh()
  end
  pf.sizeHead = UI.SectionHeader(Lc, width)
  pf.sizeHead:SetText(L.SIZE_HEAD)
  local sizes = {}
  for i, key in ipairs(R.SIZE_ORDER) do sizes[i] = { R.SizeName(key), key } end
  pf.size = UI.Choice(Lc, sizes, function()
    local f = F:Current()
    return R.SizeOf(pf.draft or (f and f.rules) or R.New())
  end, function(key) apply(function(r) return R.WithSize(r, key) end) end)
  pf.sizeText = UI.WrapText(Lc, 12, "ink2", width, "book")
  pf.styleHead = UI.SectionHeader(Lc, width)
  pf.styleHead:SetText(L.STEP_STYLE)
  local styles = {}
  for i, key in ipairs(R.STYLE_ORDER) do styles[i] = { L["STYLE_" .. key:upper()], key } end
  pf.style = UI.Choice(Lc, styles, function()
    local f = F:Current()
    return R.StyleOf(pf.draft or (f and f.rules) or R.New())
  end, function(key) apply(function(r) return R.WithStyle(r, key) end) end)
  pf.styleText = UI.WrapText(Lc, 12, "ink2", width, "book")
  pf.formTop = 0

  pf.form = UI.RulesForm(Lc, pf.rscroll.child, width, {
    get = function() local f = F:Current(); return pf.draft or (f and f.rules) or ns.Rules.New() end,
    set = function(k, v)
      local f = F:Current()
      if not f then return end
      pf.draft = pf.draft or copy(f.rules)
      pf.draft[k] = v
      W:Refresh()
    end,
    cond = function()
      local f = F:Current()
      if not f then return false end
      local state, guild = F:TournamentState({ rules = { gmT = true }, members = f.members })
      return state == "on", guild
    end,
    heroes = function() local f = F:Current(); return f and F:Count(f) or 1 end,
    top = function() return pf.formTop end,
    onLayout = function(lh, rh) pf.lscroll:SetContentHeight(lh + 10); pf.rscroll:SetContentHeight(rh + 10) end,
  })
end

local function refreshAdmin(pf, ctx)
  local f = ctx.f
  if not f then return end
  pf.tabs:Refresh()
  local s = UI.Stack(pf.lscroll.child)
  local yh = pf.yourPart.text:GetStringHeight() + 18
  pf.yourPart:SetHeight(yh)
  s:Place(pf.yourPart, yh, 10)
  local keys = changed(f, pf.draft)
  pf.draftBox:SetShown(#keys > 0)
  if #keys > 0 then
    local parts = {}
    for i, k in ipairs(keys) do parts[i] = L.V_CHANGE:format(R.Name(k), R.ValueText(k, pf.draft[k])) end
    pf.draftText:SetText(L.RULES_DRAFT:format(table.concat(parts, "; ")))
    local h = pf.draftText:GetStringHeight() + 20
    pf.propose:ClearAllPoints(); pf.propose:SetPoint("TOPLEFT", 12, -h)
    pf.undo:ClearAllPoints(); pf.undo:SetPoint("LEFT", pf.propose, "RIGHT", 8, 0)
    pf.draftBox:SetHeight(h + 36)
    s:Place(pf.draftBox, h + 36, 8)
  end
  s:Skip(8)
  -- The challenges: each one on with Turn off, the ones turned off with their day.
  local Ch = ns.Challenges
  local ever = Ch:Ever(f)
  pf.chalHead:SetShown(ever); pf.chalText:SetShown(ever)
  local n = 0
  if ever then
    s:Place(pf.chalHead, 29, 6)
    s:Place(pf.chalText, pf.chalText:GetStringHeight(), 6)
    for _, k in ipairs(Ch.LIST) do
      local on, was = Ch:Has(f, k), f.challengesOff and f.challengesOff[k]
      if on or was then
        local r = pf.chalRows:Get(n + 1)
        if not r then break end
        n = n + 1
        r.key, r.v = on and k or nil, on and f.challenges[k] or nil
        r.name:SetText(on and Ch:Name(k, f.challenges[k]) or L.MG_CHAL_WAS_OFF:format(Ch:Name(k, was.v), Ch.Day(was.t)))
        r.name:SetTextColor(Theme:RGBA(on and "ink" or "ink2"))
        local held = on and Ch:IncludedBy(f, k) ~= nil
        r.off:SetShown(on and not held and not ctx.watching)
        r.held:SetShown(held)
        r:Show()
        s:Place(r, 28, 2)
      end
    end
    s:Skip(10)
  end
  pf.chalRows:HideFrom(n + 1)
  -- The size (how many you are, and which size the rules were made for), the play style, then the full form.
  local rules = pf.draft or f.rules
  s:Place(pf.sizeHead, 29, 6)
  pf.size:Refresh()
  s:Place(pf.size, 28, 6)
  local count, made = F:Count(f), R.SizeOf(rules)
  pf.sizeText:SetText(made == "custom" and L.SIZE_NOW_CUSTOM:format(count)
    or (R.SizeFor(count) == made and L.SIZE_NOW_FITS:format(count) or L.SIZE_NOW:format(count, R.SizeWord(made))))
  s:Place(pf.sizeText, pf.sizeText:GetStringHeight(), 12)
  s:Place(pf.styleHead, 29, 6)
  pf.style:Refresh()
  s:Place(pf.style, 28, 6)
  local style = R.StyleOf(rules)
  pf.styleText:SetText(style == "custom" and L.STYLE_CUSTOM_TEXT or L["STYLE_" .. style:upper() .. "_TEXT"])
  s:Place(pf.styleText, pf.styleText:GetStringHeight(), 12)
  pf.formTop = s.y
  pf.form:Refresh()
end

ns.Pages:Register({ id = "rules", label = L.NAV_RULES, build = buildBook, refresh = refreshBook,
  title = function() return L.TITLE_RULES, L.SUB_RULES end })
ns.Pages:Register({ id = "rulesadmin", label = L.MG_TAB_RULES, icon = "rules", parent = "manage", build = buildAdmin,
  refresh = refreshAdmin, title = function() return L.TITLE_MANAGE, L.SUB_RULES_ADMIN end })
