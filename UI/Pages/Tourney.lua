-- Guild Master tournament (SPEC §4.10). Left: the phase and what it means for you (sign up, your next duel, the
-- winner and the Guild Master's hand-over button), the entrants and seeds, the schedule and the time check.
-- Right: the structure of the format (brackets, group tables, the round robin schedule), as far as it is known.
local _, ns = ...
local L = ns.L
local UI, Theme = ns.UI, ns.Theme
local T, Tn, Hr, R = ns.Tournament, ns.Tourney, ns.Hero, ns.Rules

local COL_W = 196
local CARD_W, CARD_H, GAP = COL_W - 18, 44, 4 -- 18 px between columns for the bracket lines

local function who(x)
  if x == false then return L.T_BYE end
  if x == nil then return L.T_TBD end
  return ns.Short(x)
end

local function build(pf)
  local W = ns.Window
  local width = W.PAGE_W - 8

  pf.lscroll = UI.Scroll(pf.left)
  pf.lscroll:SetAllPoints()
  local Lc = pf.lscroll.child
  pf.card = UI.Card(Lc)
  pf.card:SetWidth(width)
  pf.phase = UI.Text(pf.card, 16, "ink", "title")
  pf.phase:SetPoint("TOPLEFT", 12, -10)
  pf.lines = UI.Pool(function() return UI.WrapText(pf.card, 13, "ink", width - 24, "book") end)
  pf.signUp = UI.TextButton(pf.card, L.T_SIGN_UP, function() Tn:SignUp(true) end, "primary")
  pf.withdraw = UI.TextButton(pf.card, L.T_WITHDRAW, function() Tn:SignUp(false) end, "plain")
  pf.start = UI.TextButton(pf.card, L.T_START, function() Tn:Start() end, "primary")
  -- The Guild Master hands over by typing /gleader: the button puts it in the chat box, Enter sends it. (It was a
  -- secure button; one secure button in the book made the whole book protected, so it could not open in combat;
  -- seen in game.)
  pf.handover = UI.TextButton(pf.card, "", function(b)
    local open = (ChatFrameUtil and ChatFrameUtil.OpenChat) or ChatFrame_OpenChat
    if open and b.cmd then open(b.cmd) end
  end, "primary")
  pf.handover:Hide()
  pf.handoverHow = UI.WrapText(pf.card, 12, "ink2", width - 24, "body")
  pf.handoverHow:Hide()

  pf.entrantsHead = UI.SectionHeader(Lc, width)
  pf.entrantsHead:SetText(L.T_ENTRANTS)
  pf.entrants = UI.Pool(function()
    local r = CreateFrame("Frame", nil, Lc)
    r:SetSize(width, 20)
    r.seed = UI.Text(r, 12, "ink2", "body", "RIGHT")
    r.seed:SetPoint("LEFT", 0, 0); r.seed:SetWidth(22)
    r.name = UI.Text(r, 13, "ink", "title")
    r.name:SetPoint("LEFT", 30, 0)
    r.level = UI.Text(r, 12, "ink2", "body", "RIGHT")
    r.level:SetPoint("RIGHT", -2, 0)
    return r
  end)
  pf.sched = {}
  for i = 1, 4 do
    local r = CreateFrame("Frame", nil, Lc)
    r:SetSize(width, 18)
    r.k = UI.Text(r, 12, "ink2")
    r.k:SetPoint("LEFT")
    r.v = UI.Text(r, 12, "ink", "body", "RIGHT")
    r.v:SetPoint("RIGHT")
    pf.sched[i] = r
  end
  pf.fit = UI.WrapText(Lc, 12, "2E7A3E", width)
  pf.note = UI.WrapText(Lc, 12, "ink2", width, "book")
  pf.note:SetText(L.T_NOTE)

  pf.rscroll = UI.Scroll(pf.right)
  pf.rscroll:SetAllPoints()
  pf.art = UI.PageArt(pf.rscroll, "Tourney")
  local Rc = pf.rscroll.child
  pf.stageHeads = UI.Pool(function() return UI.SectionHeader(Rc, width) end)
  -- Round names in ink (the light accent was hard to read on parchment; seen in the UI tour).
  pf.labels = UI.Pool(function() return UI.Text(Rc, 12, "ink2", "title") end)
  pf.cards = UI.Pool(function()
    local c = UI.Card(Rc)
    c:SetSize(CARD_W, CARD_H)
    local function line(y)
      local l = {}
      -- The winner's line has a light gold band behind it (29 Oct 2026: who won was hard to see).
      l.band = UI.Solid(c, "ARTWORK", "gold", 0.18)
      l.band:SetPoint("TOPLEFT", 3, y + 3); l.band:SetPoint("TOPRIGHT", -3, y + 3); l.band:SetHeight(17)
      l.name = UI.Text(c, 12, "ink", "title")
      l.name:SetPoint("TOPLEFT", 8, y); l.name:SetWidth(CARD_W - 52)
      -- "You" on your own line, as a small tag after the name.
      l.you = UI.Box(c, 1, "dark", 0.85, "gold", 0.8)
      l.you.text = UI.Text(l.you, 10, "goldText", "title", "CENTER")
      l.you.text:SetPoint("CENTER", 0, 0)
      l.you.text:SetText(L.T_YOU)
      l.you:SetSize(l.you.text:GetStringWidth() + 10, 14)
      l.score = UI.Text(c, 12, "ink2", "body", "RIGHT")
      l.score:SetPoint("TOPRIGHT", -26, y)
      l.mark = UI.Check(c, 14)
      l.mark:SetTexture(ns.MARKS.done)
      l.mark:SetPoint("TOPRIGHT", -8, y + 1)
      return l
    end
    c.l1, c.l2 = line(-7), line(-24)
    return c
  end)
  -- After the final (or the standings): who won, in a gold-edged box.
  pf.champ = UI.Card(Rc, "gold")
  pf.champ:SetSize(width, 62)
  pf.champ.bgRole = "page1"
  pf.champ:Paint()
  pf.champ.head = UI.Text(pf.champ, 11, "ink2", "title", "CENTER")
  pf.champ.head:SetPoint("TOP", 0, -10)
  pf.champ.head:SetText(L.T_CHAMPION_HEAD:upper())
  pf.champ.name = UI.Text(pf.champ, 19, "ink", "title", "CENTER")
  pf.champ.name:SetPoint("TOP", pf.champ.head, "BOTTOM", 0, -5)
  pf.champ:Hide()
  pf.rows = UI.Pool(function()
    local r = CreateFrame("Frame", nil, Rc)
    r:SetSize(width, 18)
    r.name = UI.Text(r, 12, "ink", "title")
    r.name:SetPoint("LEFT", 8, 0)
    r.wl = UI.Text(r, 12, "ink")
    r.wl:SetPoint("LEFT", 170, 0)
    r.adv = UI.Text(r, 11, "2E7A3E", "body", "RIGHT")
    r.adv:SetPoint("RIGHT", -4, 0)
    return r
  end)
  pf.texts = UI.Pool(function() return UI.WrapText(Rc, 12, "ink", width, "book") end)
  -- Bracket lines between a round and the next (M21): gold when the winner's path, line colour otherwise.
  pf.links = UI.Pool(function() return Rc:CreateTexture(nil, "BORDER") end)
end

-- The stages to draw: { title, columns = { { label, matches } } | tables = { { name, rows } } | rounds = { text } }.
local function stages(B, format, seeds, done)
  local out = {}
  local function columns(stage)
    local cols = {}
    for _, m in ipairs(B.matches) do
      if m.stage == stage then
        cols[m.col] = cols[m.col] or { label = m.label, matches = {} }
        table.insert(cols[m.col].matches, m)
      end
    end
    return cols
  end
  -- (champion: the stage after which the Champion box goes.)
  if format == "single" then
    out[1] = { title = L.T_STAGE_BRACKET, columns = columns("wb"), champion = true }
  elseif format == "double" then
    out[1] = { title = L.T_STAGE_WINNERS, columns = columns("wb") }
    local lb = columns("lb")
    if next(lb) then out[#out + 1] = { title = L.T_STAGE_LOSERS, columns = lb } end
    out[#out + 1] = { title = L.T_GRAND_FINAL, columns = columns("gf"), champion = true }
  elseif format == "groups" then
    local tables = {}
    for g = 1, #B.groups do
      local order, wins, losses, gDone = B.GroupTable(g)
      local rows = {}
      for i, n in ipairs(order) do
        rows[i] = { name = n, w = wins[n], l = losses[n], adv = i <= 2 and (gDone and L.T_ADVANCES or L.T_TOP2) or "" }
      end
      tables[g] = { name = L.T_GROUP:format(string.char(64 + g)), rows = rows }
    end
    out[1] = { title = L.T_STAGE_GROUPS, tables = tables }
    out[2] = { title = L.T_STAGE_KNOCKOUT, columns = columns("ko"), champion = true }
  else
    local order, wins, losses = {}, {}, {}
    for _, n in ipairs(seeds) do wins[n], losses[n] = 0, 0 end
    for _, m in ipairs(B.matches) do
      if m.w then
        wins[m.w] = wins[m.w] + 1
        local l = m.w == m.a and m.b or m.a
        losses[l] = losses[l] + 1
      end
    end
    for i, n in ipairs(seeds) do order[i] = n end
    local seedOf = {}
    for i, n in ipairs(seeds) do seedOf[n] = i end
    table.sort(order, function(a, b) if wins[a] ~= wins[b] then return wins[a] > wins[b] end return seedOf[a] < seedOf[b] end)
    local rows = {}
    for i, n in ipairs(order) do rows[i] = { name = n, w = wins[n], l = losses[n], adv = (i == 1 and done) and L.T_WINNER or "" } end
    out[1] = { title = L.T_STAGE_STANDINGS, tables = { { name = L.T_EVERYONE, rows = rows } }, champion = true }
    local rounds = {}
    for r, ps in ipairs(B.rrRounds or {}) do
      local parts = {}
      for _, p in ipairs(ps) do
        local a, b = seeds[p[1]], seeds[p[2]]
        parts[#parts + 1] = (a and b) and L.T_VS:format(ns.Short(a), ns.Short(b)) or L.T_RESTS:format(ns.Short(a or b))
      end
      rounds[r] = L.T_ROUND_N:format(r) .. ":  " .. table.concat(parts, ",  ")
    end
    out[2] = { title = L.T_STAGE_SCHEDULE, rounds = rounds }
  end
  return out
end

local function refresh(pf, ctx)
  local f = ctx.f
  if not f then return end
  local me, now = ctx.me, time()
  local t = f.tourney
  local r = f.rules
  local light = Theme:Current().light
  -- /jtf debug tourney big: a pretend running tournament drives the whole page (Dev/Debug.lua). (It drew only the
  -- right side, next to the real one on the left; seen in the seventh check.)
  local sample = ns.Dev and ns.Dev.tourneySample
  if sample then
    t = { phase = "running", format = sample.format, seeds = sample.seeds, results = sample.results, bo = 1, duels = {},
      roundLen = r.tRound, total = r.tTotal, min = r.tMin, signed = {} }
    for _, n in ipairs(sample.seeds) do t.signed[n] = true end
  end
  local function level(n) return sample and sample.levels and sample.levels[n] or Hr:Level(f, n) end
  local phase = t and t.phase or "none"
  local signed = sample and sample.seeds or (t and Tn:Signed(f, t) or {})
  local seeds = t and t.seeds or T.Seed(signed, r.tSeed, level, t and tostring(t.id) or "")
  local B = (#seeds >= 2) and T.Build(t and t.format or r.tFormat, seeds, t and t.results or {}) or nil

  -- The status card.
  local s = UI.Stack(pf.lscroll.child)
  pf.phase:SetText(({ none = L.T_PHASE_NONE, signup = L.T_PHASE_SIGNUP, running = L.T_PHASE_RUNNING, done = L.T_PHASE_DONE,
    cancelled = L.T_PHASE_CANCELLED })[phase])
  local lines = {}
  if t then
    local count = #signed == 1 and L.T_COUNT_1 or L.T_COUNT_N:format(#signed)
    if phase == "signup" then count = count .. L.T_CLOSES:format(ns.TimeLeft(t.signupEnd - now)) end
    lines[#lines + 1] = { count, "ink" }
  end
  if phase == "running" then
    local m, other
    if not sample then m, other = Tn:MyMatch(f, me) end
    if m then
      lines[#lines + 1] = { L.T_MY_MATCH:format(ns.Short(other), t.bo == 1 and L.T_ONE_DUEL or L.T_BEST_OF:format(t.bo),
        ns.TimeLeft((t.roundEnd or now) - now)), "accent" }
    end
  end
  if phase == "done" and t.champion then lines[#lines + 1] = { L.T_CHAMPION:format(ns.Short(t.champion)), "B8742A" } end
  if (phase == "signup" or phase == "cancelled") and #signed < (t and t.min or r.tMin) then
    lines[#lines + 1] = { L.T_FEW:format(t and t.min or r.tMin), "B0321E" }
  end
  if r.tStart == "auto" and phase ~= "signup" and phase ~= "running" then
    local nextAt = (f.tourneyLast or now) + Tn.AUTO_EVERY
    lines[#lines + 1] = { L.T_AUTO_NEXT:format(nextAt <= now and L.TIME_JUST_NOW or L.TIME_IN:format(ns.TimeLeft(nextAt - now))), "ink2" }
  end
  local y = 36
  for i, ln in ipairs(lines) do
    local fs = pf.lines:Get(i)
    if not fs then break end
    fs:SetText(ln[1]); fs:SetTextColor(Theme:RGBA(ln[2]))
    fs:ClearAllPoints(); fs:SetPoint("TOPLEFT", 12, -y); fs:Show()
    y = y + fs:GetStringHeight() + 6
  end
  pf.lines:HideFrom(#lines + 1)
  local isSigned = t ~= nil and t.signed and t.signed[me] ~= nil
  local canSign = phase == "signup"
  pf.signUp:SetShown(canSign and not isSigned); pf.withdraw:SetShown(canSign and isSigned)
  pf.start:SetShown(not sample and Tn:CanStart(f, me))
  local bx = 12
  for _, b in ipairs({ pf.signUp, pf.withdraw, pf.start }) do
    if b:IsShown() then b:ClearAllPoints(); b:SetPoint("TOPLEFT", bx, -(y + 2)); bx = bx + b:GetWidth() + 6 end
  end
  if bx > 12 then y = y + 34 end
  -- Hand-over: only for the Guild Master, when someone else won.
  local _, _, rankIndex = GetGuildInfo("player")
  local handover = phase == "done" and t.champion ~= nil and t.champion ~= me and rankIndex == 0
  pf.handover:SetShown(handover); pf.handoverHow:SetShown(handover)
  if handover then
    pf.handover.cmd = "/gleader " .. Ambiguate(t.champion, "none")
    pf.handover:SetLabel(L.T_HANDOVER:format(ns.Short(t.champion)))
    pf.handover:ClearAllPoints(); pf.handover:SetPoint("TOPLEFT", 12, -(y + 2))
    pf.handoverHow:SetText(L.T_HANDOVER_HOW:format(pf.handover.cmd))
    pf.handoverHow:ClearAllPoints(); pf.handoverHow:SetPoint("TOPLEFT", 12, -(y + 34))
    y = y + 38 + pf.handoverHow:GetStringHeight()
  end
  pf.card:SetHeight(y + 6)
  s:Place(pf.card, y + 6, 10)

  -- Entrants and seeds.
  s:Place(pf.entrantsHead, 29, 4)
  local list = t and t.seeds or seeds
  for i, n in ipairs(list) do
    local row = pf.entrants:Get(i)
    if not row then break end
    row.seed:SetText(i .. ".")
    row.name:SetText(ns.Short(n))
    local _, token = Hr:ClassName(f, n)
    if sample and sample.classes then token = sample.classes[n] or token end
    local ink = ns.ClassHex(token, light)
    if ink then row.name:SetTextColor(ns.Hex(ink)) else row.name:SetTextColor(Theme:RGBA("ink")) end
    row.level:SetText(level(n))
    s:Place(row, 20, 0)
  end
  pf.entrants:HideFrom(#list + 1)
  s:Skip(10)
  local format = t and t.format or r.tFormat
  local bo = t and t.bo or r.tBo
  local fmt = ({ single = L.F_BRACKET, double = L.F_DOUBLE, groups = L.F_GROUPS, rr = L.F_RR })[format]
  local sched = {
    { L.T_SCHED_SIGNUP, L.T_SCHED_SIGNUP_V:format(R.DurLabel(r.tSignup)) },
    { L.T_SCHED_ROUND, R.DurLabel(t and t.roundLen or r.tRound) },
    { L.T_SCHED_TOTAL, L.T_SCHED_TOTAL_V:format(R.Days(t and t.total or r.tTotal)) },
    { L.T_SCHED_FORMAT, fmt .. ", " .. (bo == 1 and L.T_ONE_DUEL or L.T_BEST_OF:format(bo)) },
  }
  for i, row in ipairs(pf.sched) do
    row.k:SetText(sched[i][1]); row.v:SetText(sched[i][2])
    s:Place(row, 18, 2)
  end
  local fitText = R.TournamentFit(r, math.max(2, #list))
  pf.fit:SetText(fitText)
  pf.fit:SetTextColor(Theme:RGBA(fitText:find(L.TFIT_OK, 1, true) and "2E7A3E" or "B0321E"))
  s:Skip(6)
  s:Place(pf.fit, pf.fit:GetStringHeight(), 8)
  s:Place(pf.note, pf.note:GetStringHeight(), 4)
  pf.lscroll:SetContentHeight(s.y + 8)

  -- Right: the structure.
  local view = { B = B, format = format, seeds = list, duels = t and t.duels or {}, bo = bo, done = phase == "done" }
  local rs = UI.Stack(pf.rscroll.child)
  local nHead, nLab, nCard, nRow, nText, nLink = 0, 0, 0, 0, 0, 0
  local Rc = pf.rscroll.child
  -- A line from (x1, y1) to (x2, y2), straight across or down (y grows downward).
  local function link(x1, y1, x2, y2, gold)
    nLink = nLink + 1
    local ln = pf.links:Get(nLink)
    if not ln then return end
    ln:SetColorTexture(Theme:RGBA(gold and "gold" or "line", gold and 1 or 0.9))
    ln:ClearAllPoints()
    ln:SetPoint("TOPLEFT", Rc, "TOPLEFT", math.min(x1, x2), -math.min(y1, y2))
    ln:SetSize(math.max(2, math.abs(x2 - x1)), math.max(2, math.abs(y2 - y1)))
    ln:Show()
  end
  local function head(text)
    nHead = nHead + 1
    local h = pf.stageHeads:Get(nHead)
    if h then h:SetText(text); rs:Place(h, 29, 6) end
  end
  local function label(text, x, top)
    nLab = nLab + 1
    local lab = pf.labels:Get(nLab)
    if not lab then return end
    lab:SetText(text)
    lab:ClearAllPoints()
    if x then lab:SetPoint("TOPLEFT", Rc, "TOPLEFT", x, -top); lab:Show() else rs:Place(lab, 18, 2) end
  end
  local function line(text, role)
    nText = nText + 1
    local fs = pf.texts:Get(nText)
    if not fs then return end
    fs:SetText(text)
    fs:SetTextColor(Theme:RGBA(role or "ink"))
    rs:Place(fs, fs:GetStringHeight(), 4)
  end
  -- A match card at (x, y), w wide: the winner on a gold band, larger, green and ticked; the loser faded; byes and
  -- players not known yet in grey; your own line tagged "You", your card in gold.
  local function card(m, x, top, w)
    nCard = nCard + 1
    local c = pf.cards:Get(nCard)
    if not c then return end
    c:SetWidth(w)
    local wins = view.duels[m.key] or {}
    local decided = type(m.w) == "string"
    for _, side in ipairs({ { c.l1, m.a }, { c.l2, m.b } }) do
      local l, n = side[1], side[2]
      local known = type(n) == "string"
      local won, lost = decided and m.w == n, decided and known and m.w ~= n
      l.name:SetFont(Theme.FONT_TITLE, won and 13 or 12, "")
      l.name:SetText(who(n))
      l.name:SetTextColor(Theme:RGBA(not known and "ink2" or (won and "3E7A3A" or "ink")))
      l.name:SetAlpha(lost and 0.45 or 1)
      l.score:SetAlpha(lost and 0.45 or 1)
      l.band:SetShown(won)
      l.mark:SetShown(won)
      l.score:SetText(view.bo > 1 and known and (wins[n] or 0) or "")
      local mine = known and n == me
      local nameW = w - 52 - (mine and (l.you:GetWidth() + 6) or 0)
      l.name:SetWidth(nameW)
      l.you:SetShown(mine)
      if mine then
        l.you:ClearAllPoints()
        l.you:SetPoint("LEFT", l.name, "LEFT", math.min(l.name:GetStringWidth(), nameW) + 6, 0)
      end
    end
    c:SetSelected(m.a == me or m.b == me)
    c:ClearAllPoints(); c:SetPoint("TOPLEFT", Rc, "TOPLEFT", x, -top); c:Show()
  end

  -- Up to 8 entrants in a stage: the drawn bracket, columns two by two joined by bracket lines.
  local function bracket(st, cols)
    for i = 1, #cols, 2 do
      local top, tallest = rs.y, 0
      local prev -- the left column's card centres, to draw the bracket lines to the right column
      for k = 0, 1 do
        local col = st.columns[cols[i + k]]
        if col then
          local x, yy = k * COL_W, top
          label(col.label, x, yy)
          yy = yy + 18
          local centres = {}
          -- The right column feeds from two matches each: its card sits between them, as in a drawn bracket.
          local feeds = k == 1 and prev and #prev >= 2 * #col.matches - 1
          for j, m in ipairs(col.matches) do
            if feeds then
              local a, b = prev[2 * j - 1], prev[2 * j] or prev[2 * j - 1]
              yy = (a.y + b.y) / 2 - CARD_H / 2
              local mid = x - (COL_W - CARD_W) / 2
              for _, src in ipairs({ a, b }) do
                link(src.x + CARD_W, src.y, mid, src.y, src.w ~= nil)
              end
              link(mid, a.y, mid + 2, b.y, a.w ~= nil or b.w ~= nil)
              link(mid, yy + CARD_H / 2, x, yy + CARD_H / 2, m.w ~= nil)
            end
            centres[j] = { x = x, y = yy + CARD_H / 2, w = m.w }
            card(m, x, yy, CARD_W)
            yy = yy + CARD_H + GAP
          end
          prev = centres
          tallest = math.max(tallest, yy - top)
        end
      end
      rs:Skip(tallest + 6)
    end
  end

  -- More than 8 (29 Oct 2026; 20 Adventurers made a bracket too tall to follow): round by round. Finished rounds as
  -- a line of winners, the round being played as cards two to a line, later rounds as a line each; byes in a line.
  local function roundByRound(st, cols)
    local open = false
    for ci, c in ipairs(cols) do
      local col = st.columns[c]
      local duels, byes, winners, finished = {}, {}, {}, true
      for _, m in ipairs(col.matches) do
        if m.a == false or m.b == false then
          local through = m.a == false and m.b or m.a
          if type(through) == "string" then byes[#byes + 1] = ns.Short(through) end
        else
          duels[#duels + 1] = m
          if type(m.w) == "string" then winners[#winners + 1] = ns.Short(m.w) else finished = false end
        end
      end
      local last = ci == #cols
      if open then
        -- A later round: how many duels, still to be decided.
        line(L.T_LATER:format(col.label, #duels == 1 and L.T_DUELS_1 or L.T_DUELS_N:format(#duels)), "ink2")
      elseif finished and not last then
        label(col.label)
        if #winners > 0 then line(L.T_WINNERS_LINE:format(table.concat(winners, ", "))) end
        if #byes > 0 then line(L.T_BYES_LINE:format(table.concat(byes, ", ")), "ink2") end
        rs:Skip(4)
      else
        -- The round being played (or the final, also once it is over).
        open = not finished
        label(col.label)
        local cw = math.floor((ns.Window.PAGE_W - 8 - 10) / 2)
        for j, m in ipairs(duels) do
          card(m, ((j - 1) % 2) * (cw + 10), rs.y + math.floor((j - 1) / 2) * (CARD_H + GAP), cw)
        end
        rs:Skip(math.ceil(#duels / 2) * (CARD_H + GAP) + 2)
        if #byes > 0 then line(L.T_BYES_LINE:format(table.concat(byes, ", ")), "ink2") end
        rs:Skip(4)
      end
    end
  end

  local champShown = false
  for _, st in ipairs(B and stages(B, view.format, view.seeds, view.done) or {}) do
    head(st.title)
    if st.columns then
      local cols = {}
      for c in pairs(st.columns) do cols[#cols + 1] = c end
      table.sort(cols)
      local first = st.columns[cols[1]]
      if first and #first.matches > 4 then roundByRound(st, cols) else bracket(st, cols) end
    elseif st.tables then
      for _, tb in ipairs(st.tables) do
        label(tb.name)
        for _, row in ipairs(tb.rows) do
          nRow = nRow + 1
          local rr = pf.rows:Get(nRow)
          if rr then
            rr.name:SetText(ns.Short(row.name))
            rr.wl:SetText(row.w .. "-" .. row.l)
            rr.adv:SetText(row.adv)
            rs:Place(rr, 18, 0)
          end
        end
        rs:Skip(8)
      end
    else
      for _, text in ipairs(st.rounds) do line(text) end
    end
    if st.champion and type(B.champion) == "string" then
      champShown = true
      pf.champ.name:SetText(ns.Short(B.champion))
      rs:Skip(4)
      rs:Place(pf.champ, 62, 6)
    end
    rs:Skip(6)
  end
  pf.champ:SetShown(champShown)
  pf.stageHeads:HideFrom(nHead + 1); pf.labels:HideFrom(nLab + 1); pf.cards:HideFrom(nCard + 1)
  pf.rows:HideFrom(nRow + 1); pf.texts:HideFrom(nText + 1); pf.links:HideFrom(nLink + 1)
  pf.rscroll:SetContentHeight(rs.y + 8)
  pf.art:Fit(rs.y)
end

ns.Pages:Register({ id = "tourney", label = L.NAV_TOURNEY, build = build, refresh = refresh,
  title = function() return L.TITLE_TOURNEY, L.SUB_TOURNEY end })
