-- The rules form (the mockup's ruleCtl): the same controls on the Rules page and in step 3 of founding.
-- Left page: summary, Leveling together, Dungeon runs. Right page: If the Leader is away, Away,
-- The book, Guild Master tournament. Rows that depend on another rule show only when they apply.
local _, ns = ...
local L = ns.L
local UI, R = ns.UI, ns.Rules

-- left, right: frames to fill (scroll children). width: content width of one page.
-- o.get() returns the rules table; o.set(key, value) changes one; o.cond() returns met, guild for the tournament;
-- o.heroes() returns the number of Heroes; o.onLayout(leftHeight, rightHeight) after every layout.
function UI.RulesForm(left, right, width, o)
  local form = { items = {}, controls = {} }
  local function get(k) return o.get()[k] end
  local function set(k) return function(v) o.set(k, v); form:Refresh() end end
  local function choice(parent, opts, key)
    local c = UI.Choice(parent, opts, function() return get(key) end, set(key), width)
    form.controls[#form.controls + 1] = c
    return c
  end
    local function onOff(parent, key) return choice(parent, { { L.ON, true }, { L.OFF, false } }, key) end
  local function nums(list) local t = {} for i, v in ipairs(list) do t[i] = { tostring(v), v } end return t end
  local function stepper(parent, down, up, text)
    local s = UI.Stepper(parent, down, up, text)
    form.controls[#form.controls + 1] = s
    return s
  end
  local function add(side, item) item.side = side; form.items[#form.items + 1] = item; return item end

  -- A heading.
  local function head(side, text)
    local parent = side == "left" and left or right
    local fs = UI.Text(parent, 17, "ink", "title")
    fs:SetText(text)
    return add(side, { frames = { fs }, layout = function(stack) stack:Skip(8); stack:Place(fs, 22, 6) end })
  end
  -- Label and hint on the left, control on the right.
  local function row(side, label, hint, control, visible)
    local parent = side == "left" and left or right
    local textW = width - control:GetWidth() - 12
    local l = UI.WrapText(parent, 14, "ink", textW)
    l:SetText(label)
    local h = UI.WrapText(parent, 12, "ink2", textW)
    h:SetText(hint or "")
    return add(side, { frames = { l, h, control }, visible = visible, layout = function(stack)
      local y = stack.y
      stack:Place(l, l:GetStringHeight(), 2)
      if hint then stack:Place(h, h:GetStringHeight(), 0) else h:Hide() end
      control:ClearAllPoints(); control:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, -y); control:Show()
      stack.y = math.max(stack.y, y + 28) + 12
    end })
  end
  -- Label and hint, the control below them.
  local function block(side, label, hint, control, visible, extra)
    local parent = side == "left" and left or right
    local l = UI.WrapText(parent, 14, "ink", width)
    l:SetText(label)
    local h = UI.WrapText(parent, 12, "ink2", width)
    h:SetText(hint or "")
    return add(side, { frames = { l, h, control }, visible = visible, layout = function(stack)
      stack:Place(l, l:GetStringHeight(), 2)
      if hint then stack:Place(h, h:GetStringHeight(), 6) else h:Hide(); stack:Skip(4) end
      stack:Place(control, control:GetHeight(), 8)
      if extra then extra(stack) end
      stack:Skip(6)
    end })
  end
  -- "after [ 14 days ] without logging in (7–30)"
  local function after(side, key, lo, hi, range, visible)
    local parent = side == "left" and left or right
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(width, 28)
    local a = UI.Text(f, 13, "ink2")
    a:SetText(L.R_AFTER); a:SetPoint("LEFT")
    local s = stepper(f, function() o.set(key, math.max(lo, get(key) - 1)); form:Refresh() end,
      function() o.set(key, math.min(hi, get(key) + 1)); form:Refresh() end, function() return R.Days(get(key)) end)
    s:SetPoint("LEFT", a, "RIGHT", 8, 0)
    local t = UI.Text(f, 13, "ink2")
    t:SetText(range); t:SetPoint("LEFT", s, "RIGHT", 8, 0)
    return add(side, { frames = { f }, visible = visible, layout = function(stack) stack:Place(f, 28, 10) end })
  end
  -- A line of text that changes with the rules.
  local function line(side, textFn, visible, boxed)
    local parent = side == "left" and left or right
    local box = boxed and UI.Card(parent) or nil
    local fs = UI.WrapText(box or parent, boxed and 13 or 12, boxed and "ink" or "ink2", boxed and (width - 24) or width, boxed and "book" or nil)
    if box then fs:SetPoint("TOPLEFT", 12, -9) end
    return add(side, { frames = { box or fs }, visible = visible, layout = function(stack)
      fs:SetText(textFn())
      if box then
        box:SetSize(width, fs:GetStringHeight() + 18)
        stack:Place(box, fs:GetStringHeight() + 18, 8)
      else
        stack:Place(fs, fs:GetStringHeight(), 10)
      end
    end })
  end

  -- Left page
  line("left", function() return R.Summary(o.get()) end, nil, true)
  head("left", L.H_LEVELING)
  row("left", L.R_FLOOR, L.R_FLOOR_HINT, choice(left, nums({ 0, 1, 2, 3 }), "floorTol"))
  row("left", L.R_CAP, L.R_CAP_HINT, choice(left, nums({ 0, 1, 2, 3 }), "capTol"))
  row("left", L.R_RUNXP, L.R_RUNXP_HINT, onOff(left, "runXp"))
  row("left", L.R_RUNXPMAX, L.R_RUNXPMAX_HINT, choice(left, nums({ 1, 2, 3, 4, 5 }), "runXpMax"), function() return get("runXp") end)
  head("left", L.H_RUNS)
  row("left", L.R_MINHEROES, L.R_MINHEROES_HINT, choice(left, nums({ 2, 3, 4, 5 }), "minHeroes"))
  block("left", L.R_CLEAR, L.R_CLEAR_HINT, choice(left, { { L.R_CLEAR_ONE, "one" }, { L.R_CLEAR_N, "n" }, { L.R_CLEAR_ALL, "all" } }, "clearMode"))
  row("left", L.R_CLEARN, L.R_CLEARN_HINT, choice(left, nums({ 2, 3, 4, 5 }), "clearN"), function() return get("clearMode") == "n" end)

  -- Right page
  -- (What Stewards may do was here; there are no Stewards since the two ranks of 27 Oct 2026.)
  head("right", L.H_TAKEOVER)
  block("right", L.R_TAKEOVER, L.R_TAKEOVER_HINT, choice(right, { { L.R_AFTER_DAYS, false }, { L.R_NEVER, true } }, "takeoverNever"))
  after("right", "takeover", 7, 30, L.R_TAKEOVER_RANGE, function() return not get("takeoverNever") end)
  head("right", L.H_AWAY)
  block("right", L.R_AWAY, L.R_AWAY_HINT, choice(right, { { L.R_AFTER_DAYS, false }, { L.R_NEVER, true } }, "awayNever"))
  after("right", "awayDays", 1, 30, L.R_AWAY_RANGE, function() return not get("awayNever") end)
  head("right", L.H_BOOK)
  block("right", L.R_SHOWFUTURE, L.R_SHOWFUTURE_HINT, choice(right, { { L.R_ALL_CHAPTERS, true }, { L.R_CURRENT_EARLIER, false } }, "showFuture"))
  head("right", L.H_GMT)
  row("right", L.R_GMT, L.R_GMT_HINT, onOff(right, "gmT"))
  line("right", function()
    local met, guild = o.cond()
    return met and L.COND_MET:format(guild or "") or L.COND_NOT
  end)
  local gm = function() return get("gmT") end
  block("right", L.R_TSTART, L.R_TSTART_HINT, choice(right, { { L.TSTART_MANUAL, "manual" }, { L.TSTART_AUTO, "auto" } }, "tStart"), gm)
  block("right", L.R_FORMAT, nil, choice(right, { { L.F_BRACKET, "single" }, { L.F_DOUBLE, "double" }, { L.F_GROUPS, "groups" }, { L.F_RR, "rr" } }, "tFormat"), gm)
  block("right", L.R_BO, nil, choice(right, { { L.BO_1, 1 }, { L.BO_3, 3 }, { L.BO_5, 5 } }, "tBo"), gm)
  block("right", L.R_SEED, L.R_SEED_HINT, choice(right, { { L.SEED_LEVEL, "level" }, { L.SEED_RANDOM, "random" } }, "tSeed"), gm)
  row("right", L.R_TMIN, L.R_TMIN_HINT, choice(right, nums({ 2, 4, 6, 8 }), "tMin"), gm)
  local function durStep(key) return stepper(right, function() o.set(key, R.StepDur(get(key), -1)); form:Refresh() end,
    function() o.set(key, R.StepDur(get(key), 1)); form:Refresh() end, function() return R.DurLabel(get(key)) end) end
  row("right", L.R_SIGNUP, L.R_SIGNUP_HINT, durStep("tSignup"), gm)
  row("right", L.R_ROUND, L.R_ROUND_HINT, durStep("tRound"), gm)
  row("right", L.R_TOTAL, L.R_TOTAL_HINT, stepper(right, function() o.set("tTotal", math.max(1, get("tTotal") - 1)); form:Refresh() end,
    function() o.set("tTotal", math.min(21, get("tTotal") + 1)); form:Refresh() end, function() return R.Days(get("tTotal")) end), gm)
  line("right", function() return R.TournamentFit(o.get(), o.heroes()) end, gm)

  function form:Refresh()
    for _, c in ipairs(self.controls) do c:Refresh() end
    local stacks = { left = UI.Stack(left), right = UI.Stack(right) }
    -- o.top(): room kept free above the form on the left page (the Rules page puts votes there).
    if o.top then stacks.left:Skip(o.top()) end
    for _, item in ipairs(self.items) do
      if item.visible == nil or item.visible() then
        item.layout(stacks[item.side])
      else
        for _, f in ipairs(item.frames) do f:Hide() end
      end
    end
    if o.onLayout then o.onLayout(stacks.left.y, stacks.right.y) end
  end

  -- Read only (the Leader on the Rules page: the rules are changed in Rules Admin): controls cannot be clicked.
  function form:SetEnabled(on)
    for _, c in ipairs(self.controls) do
      if c.SetEnabled then c:SetEnabled(on) end
      if c.up then c.up:SetEnabled(on); c.down:SetEnabled(on) end
    end
  end

  form:Refresh()
  return form
end
