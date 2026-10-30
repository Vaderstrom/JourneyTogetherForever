-- Schedule a Gathering (SPEC §6): a form in the book. What: a dungeon of the journey or "Something else", and a
-- few words (either or both). When: a day (today up to 6 days ahead) and a time in steps of 15 minutes, in the
-- player's own time.
local _, ns = ...
local L = ns.L
local UI = ns.UI
local GF = { day = 0, hour = 20, minute = 0, choice = 1 }
ns.GatherForm = GF

local DAYS_SHOWN = 7 -- today and the six days after it

-- The choices for What: "Something else" first, then the journey's dungeons from the current chapter on, then
-- every other dungeon of the game by level (also ones the journey left out or the fellowship has done), then the
-- raids. (Only the next journey dungeons were offered; a player missed the rest, 27 Oct 2026.)
function GF:Choices(f)
  local list = { { key = nil, text = L.G_SOMETHING_ELSE } }
  local cur = ns.Journey:CurrentIndex(f)
  local ahead, rest = {}, {}
  for _, d in ipairs(ns.DUNGEONS) do
    local p = f.journey.place[d[1]]
    if p and p.ch >= cur then ahead[#ahead + 1] = { key = d[1], ch = p.ch, lvl = d[3] }
    else rest[#rest + 1] = { key = d[1], lvl = d[3] } end
  end
  table.sort(ahead, function(a, b)
    if a.ch ~= b.ch then return a.ch < b.ch end
    if a.lvl ~= b.lvl then return a.lvl < b.lvl end
    return a.key < b.key
  end)
  table.sort(rest, function(a, b) if a.lvl ~= b.lvl then return a.lvl < b.lvl end return a.key < b.key end)
  for _, k in ipairs(ahead) do list[#list + 1] = { key = k.key, text = ns.Dungeon(k.key)[2] } end
  for _, k in ipairs(rest) do list[#list + 1] = { key = k.key, text = ns.Dungeon(k.key)[2] } end
  for _, r in ipairs(ns.RAIDS) do list[#list + 1] = { key = r[1], text = L.G_RAID_CHOICE:format(r[2]) } end
  return list
end

-- The chosen time as a timestamp.
function GF:At()
  local now = time()
  local t = date("*t", now)
  local midnight = now - (t.hour * 3600 + t.min * 60 + t.sec)
  return midnight + self.day * 86400 + self.hour * 3600 + self.minute * 60
end

local function dayText(n)
  if n == 0 then return L.G_TODAY end
  if n == 1 then return L.G_TOMORROW end
  return date(L.G_DAY_FORMAT, time() + n * 86400)
end
GF.DayText = dayText
GF.DAYS_SHOWN = DAYS_SHOWN

-- Which of the days shown a time is on (0 today), or nil outside them.
function GF.DayOf(at)
  local now = time()
  local t = date("*t", now)
  local d = math.floor((at - (now - (t.hour * 3600 + t.min * 60 + t.sec))) / 86400)
  if d >= 0 and d < DAYS_SHOWN then return d end
  return nil
end

local function stepper(parent, valueWidth, down, up, text)
  local s = UI.Stepper(parent, down, up, text)
  s.value:SetWidth(valueWidth)
  s:SetWidth(26 + 4 + valueWidth + 4 + 26)
  return s
end

function GF:Build()
  local W = ns.Window
  local o = W:Overlay("gather", 480, 360)
  if o.what then return o end
  o.title:SetText(L.G_SCHEDULE_TITLE)
  local function label(text, y)
    local t = UI.Text(o.box, 13, "ink2")
    t:SetPoint("TOPLEFT", 18, y)
    t:SetText(text)
    return t
  end
  -- What: a dropdown (paging through thirty dungeons with arrows was slow; seen in the UI tour). Day: a row of days.
  label(L.G_FIELD_WHAT, -56)
  o.what = UI.Dropdown(o.box, 300, {}, function() return GF.choice end, function(v) GF.choice = v end)
  o.what:SetPoint("TOPLEFT", 120, -50)
  label(L.G_FIELD_NOTE, -94)
  o.note = UI.EditBox(o.box, 300, ns.Gatherings.TEXT_MAX, L.G_NOTE_HINT)
  o.note:SetPoint("TOPLEFT", 120, -88)
  label(L.G_FIELD_DAY, -134)
  local days = {}
  for i = 0, DAYS_SHOWN - 1 do days[#days + 1] = { dayText(i), i } end
  o.day = UI.Choice(o.box, days, function() return GF.day end, function(v) GF.day = v end, 340)
  o.day:SetPoint("TOPLEFT", 120, -128)
  -- Time and the rest go under the days, which take two or three lines (they ran over the time; check of 29 Oct 2026).
  o.timeLabel = UI.Text(o.box, 13, "ink2")
  o.timeLabel:SetPoint("TOPLEFT", o.day, "BOTTOMLEFT", -102, -16)
  o.timeLabel:SetText(L.G_FIELD_TIME)
  o.time = stepper(o.box, 80, function()
    local m = (GF.hour * 60 + GF.minute - 15) % 1440
    GF.hour, GF.minute = math.floor(m / 60), m % 60
  end, function()
    local m = (GF.hour * 60 + GF.minute + 15) % 1440
    GF.hour, GF.minute = math.floor(m / 60), m % 60
  end, function() return ("%02d:%02d"):format(GF.hour, GF.minute) end)
  o.time:SetPoint("TOPLEFT", o.day, "BOTTOMLEFT", 0, -10)
  o.hint = UI.WrapText(o.box, 12, "ink2", 444)
  o.hint:SetPoint("TOPLEFT", o.time, "BOTTOMLEFT", -102, -14)
  o.hint:SetText(L.G_FORM_HINT)
  o.problem = UI.WrapText(o.box, 12, "B0321E", 444)
  o.problem:SetPoint("TOPLEFT", o.hint, "BOTTOMLEFT", 0, -10)
  o.ok = UI.TextButton(o.box, L.G_SCHEDULE, function() GF:Submit() end, "primary")
  o.ok:SetPoint("BOTTOMRIGHT", -16, 14)
  return o
end

-- day (optional): the day to start on (0 today; the Gatherings page's week ahead).
function GF:Open(day)
  local W = ns.Window
  local f = ns.Fellowship:Current()
  if not W.frame or not f or ns.Combat:InCombat() then return end
  if day then self.day = day end
  self.choices = self:Choices(f)
  self.choice = math.min(self.choice, #self.choices)
  local o = self:Build()
  o.note:SetText("")
  o.problem:SetText("")
  local opts = {}
  for i, c in ipairs(self.choices) do opts[i] = { c.text, i } end
  o.what:SetOptions(opts)
  self.day = math.min(self.day, DAYS_SHOWN - 1)
  for i, b in ipairs(o.day.buttons) do b.text:SetText(dayText(i - 1)) end
  o.day:Layout()
  for _, s in ipairs({ o.day, o.time }) do s:Refresh() end
  -- The window fits the days, the hint and room for a problem line above Schedule.
  o.box:SetHeight(128 + o.day:GetHeight() + 10 + o.time:GetHeight() + 14 + o.hint:GetStringHeight() + 10 + 18 + 52)
  o:Show()
  return o
end

function GF:Submit()
  local o = ns.Window.overlays and ns.Window.overlays.gather
  if not o then return end
  local c = self.choices[self.choice]
  local text = strtrim(o.note:GetText() or "")
  if not c.key and text == "" then o.problem:SetText(L.G_NEED_WHAT) return end
  local at = self:At()
  if at < time() - 60 then o.problem:SetText(L.G_IN_PAST) return end
  if ns.Gatherings:Schedule(c.key, text ~= "" and text or nil, at) then o:Hide() end
end
