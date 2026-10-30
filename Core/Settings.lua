-- Personal settings (per character). Defaults and limits follow the mockup.
local _, ns = ...
local S = {}
ns.Settings = S

S.TOAST_EVENTS = { "chapter", "floor", "clear", "heroFloor", "heroCap", "overCap", "ahead", "session", "gathering", "attune", "version" }

S.DEFAULTS = {
  theme = "journal", size = 1, fullscreen = false, chat = "all", warnCap = true, warnPct = 75, reduce = false, minimap = true, lang = "en",
  picture = true, -- the picture moment after a dungeon's final boss (UI/Picture.lua)
  sounds = true, -- the book's sounds (UI/Sound.lua)
  tracker = true, -- the on-screen tracker (UI/Tracker.lua)
  trackerHover = false, -- hidden mode: the tracker is invisible until the mouse is over it
  trackerPeek = true, -- hidden mode: it shows for a few seconds when something in it changes
  trackerHideCombat = false, -- not shown in combat
  trackerHideInstance = false, -- not shown in dungeons, raids, battlegrounds and arenas
  trackerLines = { status = true, you = true, bar = true, next = true, clears = true, run = true, quests = false,
    online = true, gather = true, duel = true, inbox = true },
  toasts = { chapter = true, floor = true, clear = true, heroFloor = true, heroCap = true, overCap = true, gathering = true,
    attune = true, version = true, -- version: your addon is older than another Adventurer's (once per session)
    ahead = true, session = true, -- M25: you pull ahead of an Adventurer; the recap of a session played together
    journey = true }, -- journey: the journey is complete and the Endgame opens (not a row in Settings)
}

S.SIZE_MIN, S.SIZE_MAX = 0.8, 1.2
S.WARN_MIN, S.WARN_MAX, S.WARN_STEP = 50, 95, 5

local function fill(target, defaults)
  for k, v in pairs(defaults) do
    if type(v) == "table" then
      if type(target[k]) ~= "table" then target[k] = {} end
      fill(target[k], v)
    elseif target[k] == nil then
      target[k] = v
    end
  end
end

-- Fills in missing settings, so saved data from older versions keeps working.
function S:Init(char)
  if type(char.settings) ~= "table" then char.settings = {} end
  fill(char.settings, self.DEFAULTS)
  self.data = char.settings
  -- The chosen language's texts, when a translation exists (before any page is built).
  if self.data.lang ~= "en" then ns.UseLocale(self.data.lang) end
end

function S:Get(key) return self.data[key] end

function S:Set(key, value)
  self.data[key] = value
  ns:Fire("SETTING", key, value)
end

function S:ToastOn(kind) return self.data.toasts[kind] ~= false end

-- The tracker's lines, each on or off (Settings → Tracker).
S.TRACKER_LINES = { "status", "you", "bar", "next", "clears", "run", "quests", "online", "gather", "duel", "inbox" }
function S:TrackerLineOn(key) return self.data.trackerLines[key] ~= false end
function S:SetTrackerLine(key, on)
  self.data.trackerLines[key] = on and true or false
  ns:Fire("SETTING", "tracker", self.data.tracker)
end

function S:SetToast(kind, on)
  self.data.toasts[kind] = on and true or false
  ns:Fire("SETTING", "toasts", self.data.toasts)
end

-- The setup guide's simple choices, made of the settings above (no settings of their own).
-- Tracker: "always" (on), "hover" (details on mouse-over only) or "off".
function S:TrackerMode()
  if not self.data.tracker then return "off" end
  return self.data.trackerHover and "hover" or "always"
end
function S:SetTrackerMode(mode)
  self.data.trackerHover = mode == "hover"
  self:Set("tracker", mode ~= "off")
end

-- Banners (toasts): "all", "big" (only the big moments: a chapter unlocks, the journey is complete), "off", or
-- "custom" when the toasts were set one by one in Settings.
function S:ToastMode()
  local on, total = 0, #self.TOAST_EVENTS
  for _, kind in ipairs(self.TOAST_EVENTS) do if self:ToastOn(kind) then on = on + 1 end end
  local journey = self:ToastOn("journey")
  if on == total and journey then return "all" end
  if on == 0 and not journey then return "off" end
  if on == 1 and self:ToastOn("chapter") and journey then return "big" end
  return "custom"
end
function S:SetToastMode(mode)
  for _, kind in ipairs(self.TOAST_EVENTS) do
    self.data.toasts[kind] = mode == "all" or (mode == "big" and kind == "chapter")
  end
  self.data.toasts.journey = mode ~= "off"
  ns:Fire("SETTING", "toasts", self.data.toasts)
end

-- Window size: 80% to 120%, set by dragging the book's corner (whole percents); never larger than the screen allows
-- (ns.Window:Scale). Full screen ignores it.
function S:SetSize(v)
  v = math.floor(v * 100 + 0.5) / 100
  self:Set("size", ns.Clamp(v, self.SIZE_MIN, self.SIZE_MAX))
end

-- Warn at: 50% to 95% in steps of 5%.
function S:SetWarn(v)
  v = math.floor(v / self.WARN_STEP + 0.5) * self.WARN_STEP
  self:Set("warnPct", ns.Clamp(v, self.WARN_MIN, self.WARN_MAX))
end

function S:StepWarn(dir)
  self:Set("warnPct", ns.Clamp(self.data.warnPct + dir * self.WARN_STEP, self.WARN_MIN, self.WARN_MAX))
end
