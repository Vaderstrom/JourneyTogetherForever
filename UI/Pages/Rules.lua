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
    placeVote(r, f, v, t, not ctx.watching)
  end
  pf.vNone:SetShown(#open == 0)
  if #open == 0 then t:Place(pf.vNone, pf.vNone.h, 6) end
  t:Skip(10)

  t:Place(pf.pHead, 29, 6)
  -- Adventurers propose; the Leader changes the rules in Manage; nothing for a follower. The walkthrough's sample
  -- shows the form, but Propose does nothing there (its proposal would go to your own fellowship).
  local showForm = not follow and not ctx.isLeader
  pf.canPropose = showForm and not ctx.demo
  local form = { pf.ruleLabel, pf.rule, pf.valueLabel, pf.value, pf.propose, pf.now }
  for _, w in ipairs(form) do w:SetShown(showForm) end
  pf.pNote:Hide()
  pf.leaderBox:SetShown(ctx.isLeader and not follow)
  pf.watchText:SetShown(follow)
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
