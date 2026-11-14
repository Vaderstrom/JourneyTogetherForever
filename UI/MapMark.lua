-- Show on map (the owner, 14 Nov 2026): the world map opens at a quest giver's or a dungeon entrance's zone with our own
-- mark on the spot, and a click on the mark sets the game's waypoint and follows it ("Click the cross"); a right-click
-- takes it away. The mark is the fellowship's crest in its gold medallion with a slow gold halo ("make it unique to our
-- addon": not another addon's cross). One mark at a time; a new Show on map moves it.
-- It is our own frame on the map's canvas, placed by the spot's share of the canvas and kept the same size when the map
-- zooms. The map's own code is only read (its map and canvas) and watched (hooksecurefunc, HookScript), never changed.
local _, ns = ...
local L = ns.L
local UI = ns.UI
local MM = {}
ns.MapMark = MM

local SIZE = 34

-- (The map's methods called through pcall without a new function each time: the mark asks every frame it shows.)
local function canvas()
  local W = WorldMapFrame
  if not W then return nil end
  local ok, c = pcall(W.GetCanvas, W)
  if ok and c then return c end
  return W.ScrollContainer and W.ScrollContainer.Child
end

local function zoom()
  local ok, z = pcall(WorldMapFrame.GetCanvasScale, WorldMapFrame)
  return ok and tonumber(z) and z > 0 and z or 1
end

local function shownMap()
  local ok, id = pcall(WorldMapFrame.GetMapID, WorldMapFrame)
  return ok and id or nil
end

-- The mark's tooltip: what it is, where, and what a click does.
local function tip(m)
  local at = MM.at
  if not at then return end
  GameTooltip:SetOwner(m, "ANCHOR_RIGHT")
  GameTooltip:SetText(at.title or at.by or at.zone or "", 1, 0.82, 0)
  GameTooltip:AddLine(ns.QuestLists.PlaceLine(at), 1, 1, 1)
  GameTooltip:AddLine(L.MAP_MARK_TIP, 0.85, 0.8, 0.7, true)
  GameTooltip:Show()
end

local function build(c)
  local m = CreateFrame("Button", nil, c)
  m:SetSize(SIZE, SIZE)
  m:SetFrameLevel(3000) -- (over the map's own pins)
  m:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  m.halo = UI.Round(m, "BACKGROUND", SIZE + 14)
  m.halo:SetPoint("CENTER")
  m.halo:SetColorTexture(1, 0.82, 0.35, 0.45)
  m.pulse = m:CreateAnimationGroup()
  m.pulse:SetLooping("BOUNCE")
  local a = m.pulse:CreateAnimation("Alpha")
  a:SetTarget(m.halo); a:SetFromAlpha(1); a:SetToAlpha(0.25); a:SetDuration(1.1)
  m.crest = UI.Crest(m, SIZE, SIZE)
  m.crest:SetPoint("CENTER")
  m.crest:EnableMouse(false)
  m:SetScript("OnClick", function(_, button)
    local at = MM.at
    if button == "LeftButton" and at then ns.QuestLists:Waypoint(at, at.map) end
    GameTooltip:Hide()
    MM:Clear()
  end)
  m:SetScript("OnEnter", tip)
  m:SetScript("OnLeave", function() GameTooltip:Hide() end)
  -- (The map zoomed or was resized: placed again. Only while it shows.)
  m:SetScript("OnUpdate", function(self)
    local cv = canvas()
    if cv and (zoom() ~= self.z or cv:GetWidth() ~= self.w) then MM:Place() end
  end)
  m:Hide()
  -- Another zone on the map, or the map opened again: shown or hidden for its zone.
  pcall(hooksecurefunc, WorldMapFrame, "OnMapChanged", function() MM:Place() end)
  WorldMapFrame:HookScript("OnShow", function() MM:Place() end)
  return m
end

-- On its spot while the map shows its zone, the same size at any zoom (its scale undoes the canvas's).
function MM:Place()
  local m, c, at = self.mark, canvas(), self.at
  if not (m and c) then return end
  local on = at ~= nil and shownMap() == at.map
  m:SetShown(on)
  if not on then m.pulse:Stop() return end
  local z = zoom()
  m:SetScale(1 / z)
  m:ClearAllPoints()
  m:SetPoint("CENTER", c, "TOPLEFT", c:GetWidth() * at.x / 100 * z, -c:GetHeight() * at.y / 100 * z)
  m.z, m.w = z, c:GetWidth()
  if not m.pulse:IsPlaying() and not ns.Settings:Get("reduce") then m.pulse:Play() end
end

-- Opens the map at map with the mark on st's spot (x, y from 0 to 100); title names it in the tooltip (a quest; an
-- entrance names itself). False when the map cannot open: in combat, or no world map.
function MM:Show(st, map, title)
  if InCombatLockdown() or not (WorldMapFrame and OpenWorldMap) then return false end
  local c = canvas()
  if not c then return false end
  self.mark = self.mark or build(c)
  local f = ns.Fellowship:Current()
  self.mark.crest:Set(f and f.color, f and f.emblem)
  self.at = { map = map, x = st.x, y = st.y, by = st.by, zone = st.zone, title = title }
  OpenWorldMap(map)
  self:Place()
  return true
end

function MM:Clear()
  self.at = nil
  if self.mark then self.mark.pulse:Stop(); self.mark:Hide() end
end
