-- /jtf tests: the in-game tests, one step at a time (the steps: Dev/ManualSteps.lua). A card on the screen says what
-- to do and what you should see, with buttons that run the step's commands. Works / Problem mark the step; Problem
-- also takes a screenshot (the card hides for it) and opens a note. Progress is kept in JourneyTogetherForeverDB.manual,
-- so /reload, logging out or another character carry on at the same step. When every step is marked the report is
-- complete; after a /reload, tools/manual-report.lua prints it with the screenshot files.
--   /jtf tests            open the card (at the first step not marked)
--   /jtf tests <n>        go to step n
--   /jtf tests restart    clear every mark and start again
--   /jtf tests close      hide the card (the marks stay)
local _, ns = ...
local L = ns.L
local UI = ns.UI
local M = { on = false }
ns.Manual = M

local CARD_W, PAD = 400, 16

local function steps() return ns.ManualSteps end

-- The saved run: { started, build, version, trial, i, open, pos, finished, results = { [id] = { status, note, shots,
-- at, char } } }.
function M:Data()
  local d = ns.db.manual
  if type(d) ~= "table" or type(d.results) ~= "table" then
    d = { started = time(), results = {}, i = 1 }
    ns.db.manual = d
  end
  d.build = select(4, GetBuildInfo())
  d.version = ns.VERSION
  d.trial = ns.Trial()
  return d
end

local function result(id)
  local r = M:Data().results
  r[id] = r[id] or {}
  return r[id]
end

function M:Counts()
  local ok, bad, done = 0, 0, 0
  local res = self:Data().results
  for _, s in ipairs(steps()) do
    local st = res[s.id] and res[s.id].status
    if st == "pass" then ok = ok + 1 end
    if st == "fail" then bad = bad + 1 end
    if st then done = done + 1 end
  end
  return ok, bad, done
end

-- The first step without a mark, from i on (then from the start); nil when every step is marked.
function M:NextOpen(i)
  local res, list = self:Data().results, steps()
  for k = i, #list do if not (res[list[k].id] and res[list[k].id].status) then return k end end
  for k = 1, math.min(i - 1, #list) do if not (res[list[k].id] and res[list[k].id].status) then return k end end
end

-- A command button's action: the addon's own commands directly, a few game commands by their function.
function M:RunCommand(cmd)
  if type(cmd) == "table" then return cmd[2]() end
  local rest = cmd:match("^/jtf%s*(.*)$")
  if rest then return SlashCmdList.JOURNEYTOGETHERFOREVER(rest) end
  if cmd == "/reload" then return ReloadUI and ReloadUI() end
  local cvar, value = cmd:match("^/console%s+(%S+)%s+(%S+)$")
  if cvar then
    if C_CVar and C_CVar.SetCVar then C_CVar.SetCVar(cvar, value) end
    ns:Debug(L.MT_SET:format(cvar, value))
  end
end

---------------------------------------------------------------------------
-- The card
---------------------------------------------------------------------------
local function build()
  if M.card then return true end
  if ns.Combat:InCombat() then return false end
  local c = UI.Box(UIParent, 2, nil, nil, "gold", 1)
  c:SetSize(CARD_W, 300)
  c:SetFrameStrata("DIALOG")
  c:SetClampedToScreen(true)
  c:EnableMouse(true)
  c:SetMovable(true)
  c:RegisterForDrag("LeftButton")
  c:SetScript("OnDragStart", function(self) self:StartMoving() end)
  c:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local p, _, rp, x, y = self:GetPoint()
    M:Data().pos = { p, rp, x, y }
  end)
  local bg = UI.GradientTex(c, "BACKGROUND", "VERTICAL", { "dark", 0.97 }, { "toastTop", 0.97 })
  bg:SetPoint("TOPLEFT", 2, -2); bg:SetPoint("BOTTOMRIGHT", -2, 2)
  c.kicker = UI.Text(c, 12, "gold", "body")
  c.kicker:SetPoint("TOPLEFT", PAD, -12)
  c.count = UI.Text(c, 12, "gold", "body", "RIGHT")
  c.count:SetPoint("TOPRIGHT", -PAD - 52, -12)
  c.close = UI.TextButton(c, L.MT_CLOSE, function() M:Close() end, "link", 12)
  c.close:SetPoint("TOPRIGHT", -10, -7)
  c.track = UI.Solid(c, "ARTWORK", "gold", 0.25)
  c.track:SetPoint("TOPLEFT", PAD, -30); c.track:SetPoint("TOPRIGHT", -PAD, -30); c.track:SetHeight(3)
  c.fill = UI.Solid(c, "OVERLAY", "F2C25B", 1)
  c.fill:SetPoint("TOPLEFT", c.track, "TOPLEFT"); c.fill:SetHeight(3)
  c.title = UI.WrapText(c, 16, "goldText", CARD_W - 2 * PAD, "title")
  c.title:SetPoint("TOPLEFT", PAD, -42)
  c.seeHead = UI.Text(c, 11, "gold", "body")
  c.seeHead:SetText(L.MT_SEE)
  c.see = UI.WrapText(c, 13, "toastText", CARD_W - 2 * PAD, "body")
  c.auto = UI.WrapText(c, 12, "toastText", CARD_W - 2 * PAD, "body")
  c.cmdHead = UI.Text(c, 11, "gold", "body")
  c.cmdHead:SetText(L.MT_RUN)
  c.cmds = {}
  for i = 1, 6 do
    c.cmds[i] = UI.TextButton(c, "", function(b) M:RunCommand(b.cmd) end, "plain", 11)
  end
  c.status = UI.WrapText(c, 13, "toastText", CARD_W - 2 * PAD, "body")
  -- The note is saved as you type (one line each time, so the card says it is kept; it was unclear; seen in game).
  c.note = UI.EditBox(c, CARD_W - 2 * PAD - 6, 250, L.MT_NOTE)
  c.note.edit:HookScript("OnTextChanged", function(eb, user)
    if user and M.step then
      local r = result(M.step.id)
      local had = r.note ~= nil
      r.note = eb:GetText() ~= "" and eb:GetText() or nil
      if had ~= (r.note ~= nil) then M:Status() end
    end
  end)
  c.works = UI.TextButton(c, L.MT_WORKS, function() M:Mark("pass") end, "primary", 13)
  c.problem = UI.TextButton(c, L.MT_PROBLEM, function() M:Mark("fail") end, "danger", 13)
  c.shot = UI.TextButton(c, L.MT_SHOT, function() M:Shot() end, "plain", 12)
  c.back = UI.TextButton(c, L.MT_BACK, function() M:Go(M.i - 1) end, "link", 12)
  c.skip = UI.TextButton(c, L.MT_SKIP, function() M:Go(M.i + 1) end, "link", 12)
  -- After a mark: the way on (a Problem stays on its step for the note).
  c.next = UI.TextButton(c, L.MT_NEXT, function() M:Go(M:NextOpen(M.i + 1) or (#steps() + 1)) end, "primary", 13)
  c:Hide()
  M.card = c
  local pos = M:Data().pos
  if type(pos) == "table" and pos[1] then c:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
  else c:SetPoint("RIGHT", UIParent, "RIGHT", -60, 40) end
  return true
end

-- Lays the card out for the step (or the end, when every step is marked).
local function fill()
  local c, list = M.card, steps()
  local step = M.step
  local ok, bad, done = M:Counts()
  c.fill:SetWidth(math.max(3, (CARD_W - 2 * PAD) * done / #list))
  c.count:SetText(step and L.MT_COUNT:format(M.i, #list) or "")
  local y = 42
  local function place(w, gap)
    w:ClearAllPoints(); w:SetPoint("TOPLEFT", c, "TOPLEFT", PAD, -y)
    y = y + (w.GetStringHeight and w:GetStringHeight() or w:GetHeight()) + (gap or 6)
  end
  for _, b in ipairs(c.cmds) do b:Hide() end
  if not step then
    c.kicker:SetText(L.MT_KICKER)
    c.title:SetText(L.MT_ALL_DONE_T:format(#list))
    c.see:SetText(L.MT_ALL_DONE:format(ok, bad))
    place(c.title, 8); place(c.see, 12)
    for _, w in ipairs({ c.seeHead, c.auto, c.cmdHead, c.status, c.note, c.works, c.problem, c.shot, c.skip, c.next }) do w:Hide() end
    c.back:ClearAllPoints(); c.back:SetPoint("TOPLEFT", c, "TOPLEFT", PAD, -y); c.back:Show()
    c:SetHeight(y + 40)
    return
  end
  c.kicker:SetText((L.MT_KICKER .. "  ·  " .. step.section):upper())
  c.title:SetText(step.todo)
  place(c.title, 10)
  c.seeHead:Show(); place(c.seeHead, 2)
  c.see:SetText(step.see or ""); place(c.see, 8)
  -- What the addon sees (a hint; you decide).
  local seen, text
  if step.auto then
    local okRun, a, b = pcall(step.auto)
    if okRun then seen, text = a, b else seen, text = false, tostring(a) end
  end
  if text then
    c.auto:SetText(L.MT_SEES:format(text))
    if seen then c.auto:SetTextColor(0.55, 0.85, 0.55) else c.auto:SetTextColor(0.95, 0.55, 0.45) end
    c.auto:Show(); place(c.auto, 8)
  else
    c.auto:Hide()
  end
  -- The step's commands, as buttons that wrap to more lines.
  if step.cmds and #step.cmds > 0 then
    c.cmdHead:Show(); place(c.cmdHead, 4)
    local x, rowH = 0, 0
    for i, cmd in ipairs(step.cmds) do
      local b = c.cmds[i]
      if b then
        b.cmd = cmd
        b:SetLabel(type(cmd) == "table" and cmd[1] or cmd)
        local w = b:GetWidth()
        if x > 0 and x + w > CARD_W - 2 * PAD then x, y = 0, y + rowH + 4 end
        b:ClearAllPoints(); b:SetPoint("TOPLEFT", c, "TOPLEFT", PAD + x, -y)
        x, rowH = x + w + 6, b:GetHeight()
        b:Show()
      end
    end
    y = y + rowH + 10
  else
    c.cmdHead:Hide()
  end
  -- Works / Problem (the chosen one lit), then what is saved for this step, the note, and the way on.
  local r = M:Data().results[step.id] or {}
  c.works:ClearAllPoints(); c.works:SetPoint("TOPRIGHT", c, "TOPRIGHT", -PAD, -y); c.works:Show()
  c.problem:ClearAllPoints(); c.problem:SetPoint("RIGHT", c.works, "LEFT", -8, 0); c.problem:Show()
  c.works:SetAlpha(r.status == "fail" and 0.5 or 1); c.problem:SetAlpha(r.status == "pass" and 0.5 or 1)
  c.shot:ClearAllPoints(); c.shot:SetPoint("TOPLEFT", c, "TOPLEFT", PAD, -y); c.shot:Show()
  y = y + 38
  c.status:ClearAllPoints(); c.status:SetPoint("TOPLEFT", c, "TOPLEFT", PAD, -y)
  M:Status()
  y = y + c.status:GetStringHeight() + 8
  c.note:SetText(r.note or "")
  c.note:Show(); place(c.note, 12)
  c.back:ClearAllPoints(); c.back:SetPoint("TOPLEFT", c, "TOPLEFT", PAD, -(y + 4)); c.back:SetShown(M.i > 1)
  c.next:ClearAllPoints(); c.next:SetPoint("TOPRIGHT", c, "TOPRIGHT", -PAD, -y); c.next:SetShown(r.status ~= nil)
  c.skip:ClearAllPoints(); c.skip:SetPoint("TOPRIGHT", c, "TOPRIGHT", -PAD, -(y + 4)); c.skip:SetShown(r.status == nil)
  c:SetHeight(y + 40)
end

-- The line that says what is saved for this step: its mark, screenshots and note.
function M:Status()
  local c, step = self.card, self.step
  if not c or not step then return end
  local r = self:Data().results[step.id] or {}
  local shots = r.shots and #r.shots or 0
  local parts = {}
  if r.status == "pass" then parts[1] = L.MT_SAVED_WORKS
  elseif r.status == "fail" then parts[1] = L.MT_SAVED_PROBLEM
  else parts[1] = L.MT_NOT_MARKED end
  if shots > 0 then parts[#parts + 1] = (shots == 1 and L.MT_SHOTS_1 or L.MT_SHOTS_N):format(shots) end
  if r.note then parts[#parts + 1] = L.MT_NOTE_SAVED end
  c.status:SetText(table.concat(parts, "  ·  "))
  if r.status == "pass" then c.status:SetTextColor(0.55, 0.85, 0.55)
  elseif r.status == "fail" then c.status:SetTextColor(0.95, 0.55, 0.45)
  else c.status:SetTextColor(0.75, 0.68, 0.55) end
  c.status:Show()
end

---------------------------------------------------------------------------
-- Running the steps
---------------------------------------------------------------------------
-- Step i (past the last: the end of the list, or the first step not marked).
function M:Go(i)
  if not self.card then return end
  local list = steps()
  if i < 1 then i = 1 end
  if i > #list then i = self:NextOpen(1) or (#list + 1) end
  self.i = i
  self.step = list[i]
  self:Data().i = i
  fill()
  self.card:Show()
end

function M:Open(n)
  if not build() then
    ns:Print(L.MT_COMBAT, true)
    return false
  end
  local d = self:Data()
  self.on, d.open = true, true
  local i = tonumber(n) or d.i or 1
  if not tonumber(n) and not (steps()[i]) then i = self:NextOpen(1) or (#steps() + 1) end
  self:Go(i)
  return true
end

function M:Close()
  self.on = false
  if self.card then self.card:Hide() end
  if ns.db.manual then ns.db.manual.open = nil end
end

-- Marks this step. Works goes on to the next step without a mark. Problem takes a screenshot and stays, with the
-- note ready and Next step to go on (it stayed without saying so, and Works was pressed to move on; seen in game).
function M:Mark(status)
  local step = self.step
  if not step then return end
  local r = result(step.id)
  r.status, r.at, r.char = status, time(), ns.Me()
  local note = self.card.note:GetText()
  r.note = note ~= "" and note or nil
  local ok, bad, done = self:Counts()
  if done == #steps() and not self:Data().finished then self:Finish(ok, bad) end
  if status == "fail" then
    fill()
    -- The note gets the cursor once the card is back from the screenshot.
    self.focusNote = true
    if not self:Shot() then self:ShotDone(true) end
    return
  end
  self:Go(self:NextOpen(self.i + 1) or (#steps() + 1))
end

-- Every step has a mark: the run is finished (the report is saved at the next /reload).
function M:Finish(ok, bad)
  self:Data().finished = time()
  ns:Print(L.MT_DONE:format(#steps(), ok, bad), true)
end

-- A screenshot for this step: the card hides for it, and comes back when the game has saved it.
function M:Shot()
  if not Screenshot or not self.step or self.shooting then return false end
  local r = result(self.step.id)
  r.shots = r.shots or {}
  r.shots[#r.shots + 1] = time()
  self.shooting = true
  self.card:Hide()
  C_Timer.After(0.1, function() Screenshot() end)
  C_Timer.After(2, function() M:ShotDone() end)
  return true
end

-- The card again after a screenshot (force: no screenshot was taken).
function M:ShotDone(force)
  if not self.shooting and not force then return end
  self.shooting = false
  if self.on and self.card then fill(); self.card:Show() end
  if self.focusNote and self.card then self.focusNote = nil; self.card.note.edit:SetFocus() end
end
ns:RegisterEvent("SCREENSHOT_SUCCEEDED", function() M:ShotDone() end)
ns:RegisterEvent("SCREENSHOT_FAILED", function() M:ShotDone() end)

function M:Command(text)
  local w = (text or ""):lower():match("^%s*(%S*)")
  if w == "restart" then
    local pos = ns.db.manual and ns.db.manual.pos
    ns.db.manual = nil
    self:Data().pos = pos
    ns:Print(L.MT_RESTART:format(#steps()), true)
    return self:Open(1)
  elseif w == "close" then
    return self:Close()
  end
  local fresh = not (ns.db.manual and ns.db.manual.results and next(ns.db.manual.results))
  if self:Open(tonumber(w)) and fresh then ns:Print(L.MT_START:format(#steps()), true) end
end

-- After a /reload or a login (on any character of the account): the card comes back at the same step.
ns:On("LOGIN", function()
  local d = ns.db and ns.db.manual
  if type(d) ~= "table" or not d.open then return end
  C_Timer.After(2, function() ns.Combat:AfterCombat(function() M:Open() end) end)
end)
