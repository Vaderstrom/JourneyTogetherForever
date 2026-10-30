-- 3D models of Companions (asked for 27 Oct 2026): a head on each Companion card, the whole character on Inspect.
-- WoW draws a player only as a unit: yourself always, another Companion when they are in your group and near enough
-- for the game to have them. It cannot build another player's body from data (12.0 has no custom-race models and
-- a character's looks cannot be read), so each Companion keeps the model frame it last loaded: once you have been
-- grouped and near, their model stays for the rest of the session (until /reload or logout). Until then the pages
-- show a crest with their class. Models load in the background while you are grouped, also with the book closed.
local _, ns = ...
local MD = { frames = { portrait = {}, body = {} }, TICK = 10 }
ns.Models = MD

local function secret(v) return issecretvalue and issecretvalue(v) end

local function unitName(unit)
  local n, r = UnitName(unit)
  if not n or secret(n) or secret(r) then return nil end
  return (r and r ~= "") and (n .. "-" .. r) or ns.FullName(n)
end

-- The unit token for a Companion: "player" for you, a group member by name, or nil (not in your group).
function MD:UnitFor(name)
  if name == ns.Self() then return "player" end
  if not (IsInGroup and IsInGroup()) then return nil end
  local raid = IsInRaid and IsInRaid()
  for i = 1, raid and 40 or 4 do
    local unit = (raid and "raid" or "party") .. i
    if unitName(unit) == name then return unit end
  end
end

-- Can the game draw this unit now: online and in sight?
local function drawable(unit)
  if unit == "player" then return true end
  local seen = UnitIsVisible and UnitIsVisible(unit)
  local online = UnitIsConnected and UnitIsConnected(unit)
  if secret(seen) or secret(online) then return false end
  return (seen and online) and true or false
end

-- The unit to draw a Companion from now, or nil (not in your group, or out of sight). The group photo uses it too
-- (UI/Photo.lua).
function MD:DrawableUnit(name)
  local unit = self:UnitFor(name)
  return unit and drawable(unit) and unit or nil
end

-- A model frame. The body turns when dragged, like the game's character sheet.
local function make(kind)
  local m = CreateFrame("PlayerModel")
  m:Hide()
  m.kind = kind
  if kind == "body" then
    m:EnableMouse(true)
    m:SetScript("OnMouseDown", function(self) self.turnX = GetCursorPosition() end)
    m:SetScript("OnMouseUp", function(self) self.turnX = nil end)
    m:SetScript("OnUpdate", function(self)
      if not self.turnX then return end
      local x = GetCursorPosition()
      self.facing = (self.facing or 0) + (x - self.turnX) / 90
      self:SetFacing(self.facing)
      self.turnX = x
    end)
  end
  return m
end

-- Sets the unit on a model frame when the game can draw that Companion now; false when it cannot.
local function apply(m, name)
  local unit = MD:UnitFor(name)
  if not (unit and drawable(unit)) then return false end
  m:SetUnit(unit)
  if m.kind == "portrait" then m:SetPortraitZoom(1) else m:SetPortraitZoom(0); m:SetFacing(m.facing or 0) end
  return true
end

-- Loads a Companion's model when the game can draw them now. Returns whether one is loaded (now or earlier this
-- session) and the frame. No frames are made during combat.
function MD:Load(name, kind)
  local list = self.frames[kind]
  local m = list[name]
  if not m then
    if ns.Combat:InCombat() then return false end
    m = make(kind)
    list[name] = m
    -- Shown again (its card, the page or the book): the unit is set again a frame later. Set while its card was
    -- hidden, your head stayed an empty box on a member's Adventurers page (seen in the check, 30 Oct 2026).
    m:SetScript("OnShow", function(shown)
      C_Timer.After(0, function() if shown:IsVisible() then apply(shown, name) end end)
    end)
  end
  local first = not m.loaded
  if apply(m, name) then
    m.loaded, m.at = true, time()
    if first and name ~= ns.Self() then ns:Fire("HEROES") end -- the pages can show it now
  end
  return m.loaded == true, m
end

-- Puts a Companion's model into a holder frame; false (and the holder empty) when there is none yet.
function MD:Place(name, kind, holder)
  local ok, m = self:Load(name, kind)
  -- Another Companion's model left in this holder (a card used again for someone else) goes, unless it has moved on
  -- to another holder already: then it is not this one's to hide (your head vanished from your own card that way;
  -- seen in the check, 28 Oct 2026).
  if holder.model and holder.model ~= m then
    if holder.model.holder == holder then holder.model:Hide(); holder.model.holder = nil end
    holder.model = nil
  end
  if not ok then return false end
  if m.holder and m.holder ~= holder and m.holder.model == m then m.holder.model = nil end
  local moved = m.holder ~= holder
  m.holder = holder
  m:SetParent(holder)
  m:ClearAllPoints(); m:SetAllPoints(holder)
  m:SetFrameLevel(holder:GetFrameLevel() + 1)
  m:Show()
  holder.model = m
  -- Moved to another card: the unit is set again once it sits there. Your head moved from one card to another while
  -- shown stayed an empty box (the walkthrough's sample, where you are third; seen in the check, 29 Oct 2026).
  if moved then apply(m, name) end
  return true
end

-- In the background: load the models of the Companions in your group whom the game can draw now.
function MD:Tick()
  local f = ns.Fellowship:Current()
  if not f or not (IsInGroup and IsInGroup()) then return end
  for name in pairs(f.members) do
    if name ~= ns.Self() then
      local unit = self:UnitFor(name)
      if unit and drawable(unit) then self:Load(name, "portrait"); self:Load(name, "body") end
    end
  end
end

ns:On("LOGIN", function() C_Timer.NewTicker(MD.TICK, function() MD:Tick() end) end)
ns:RegisterEvent("GROUP_ROSTER_UPDATE", function() MD:Tick() end)
-- New gear or looks: load again (yourself at once; others when they can be drawn).
ns:RegisterEvent("PLAYER_EQUIPMENT_CHANGED", function()
  for _, kind in ipairs({ "portrait", "body" }) do if MD.frames[kind][ns.Self()] then MD:Load(ns.Self(), kind) end end
end)
ns:RegisterEvent("UNIT_MODEL_CHANGED", function() MD:Tick() end)
