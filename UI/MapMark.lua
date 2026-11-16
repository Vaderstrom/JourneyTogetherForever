-- Show on map (the owner, 14 Nov 2026): the world map opens with our own marks: where a quest starts and where each of
-- its chain's steps starts, numbered as the book numbers them (steps done faded, the next one glowing), or a dungeon's
-- entrance. A click on a mark sets the game's waypoint there and follows it ("Click the cross"); the marks stay until
-- the map closes, the one followed ringed; a right-click takes them away. Each mark is our medallion's ring centred
-- on the spot, the map seen through its middle (the owner, 16 Nov 2026: "Use a better marking symbol where the middle
-- is visible. Just centering you to the location."; it was the fellowship's crest, 14 Nov: "make it unique to our
-- addon", not another addon's cross; the gold dot in the middle went too, U238).
-- The book steps aside while the map is open (it draws above the map) and comes back when the map closes.
-- The marks are our own frames on the map's canvas, placed by the spot's share of the canvas and kept the same size
-- when the map zooms; each shows only while the map shows its zone. The map's own code is only read (its map and
-- canvas) and watched (hooksecurefunc, HookScript), never changed.
local _, ns = ...
local L = ns.L
local UI = ns.UI
local MM = { marks = {} }
ns.MapMark = MM

local SIZE = 36
local RING = ns.MEDIA .. "MedallionRing"

-- Our medallion's ring (Media, shipped with the addon; open in the middle) at size, tinted.
local function medallion(m, layer, size, r, g, b, a)
  local t = m:CreateTexture(nil, layer)
  t:SetSize(size, size); t:SetPoint("CENTER")
  t:SetTexture(RING)
  t:SetVertexColor(r, g, b, a)
  return t
end

-- (The map's methods called through pcall without a new function each time: the marks ask every frame they show.)
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

-- A mark's tooltip: the quest, each step that starts there, who and where, and what a click does.
local function tip(m)
  local at = m.at
  if not at then return end
  GameTooltip:SetOwner(m, "ANCHOR_RIGHT")
  GameTooltip:SetText(MM.title or at.st.by or at.st.zone or "", 1, 0.82, 0)
  for _, it in ipairs(at.items) do
    if it.k then
      local icon = (ns.QuestLists.STATUS[it.status] or ns.QuestLists.STATUS.no)[1]
      GameTooltip:AddLine(("|T%s:12:12|t %s"):format(icon, L.DQ_STEP:format(it.k, it.name)), 1, 1, 1)
    end
  end
  GameTooltip:AddLine(ns.QuestLists.PlaceLine(at.st), 1, 1, 1)
  GameTooltip:AddLine(L.MAP_MARK_TIP, 0.85, 0.8, 0.7, true)
  GameTooltip:Show()
end

local function hooks()
  -- Another zone on the map, or the map opened again: each mark shown or hidden for its zone.
  pcall(hooksecurefunc, WorldMapFrame, "OnMapChanged", function() MM:Place() end)
  WorldMapFrame:HookScript("OnShow", function() MM:Place() end)
  -- The map closed: the marks go, and the book comes back if it stepped aside for the map.
  WorldMapFrame:HookScript("OnHide", function()
    MM:Clear()
    if MM.book then
      MM.book = nil
      if not ns.Window:IsOpen() then ns.Window.frame:Show() end
    end
  end)
end

local function build(c)
  local m = CreateFrame("Button", nil, c)
  m:SetSize(SIZE, SIZE)
  -- (Over every other pin: the game's stay far below this, and another addon's drew over ours at 3000; the check of
  -- 15 Nov 2026. Its own frames add up to 6 levels; frame levels end at 10000.)
  m:SetFrameLevel(9000)
  m:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  -- The next to do: a glowing ring outside the mark, its middle open too.
  m.halo = medallion(m, "BACKGROUND", SIZE + 16, 1, 0.82, 0.35, 1)
  m.halo:SetBlendMode("ADD")
  m.pulse = m:CreateAnimationGroup()
  m.pulse:SetLooping("BOUNCE")
  local a = m.pulse:CreateAnimation("Alpha")
  a:SetTarget(m.halo); a:SetFromAlpha(1); a:SetToAlpha(0.25); a:SetDuration(1.1)
  -- The one followed: a light ring around it.
  m.ring = medallion(m, "BORDER", SIZE + 8, 1, 0.97, 0.85, 0.95)
  -- (Nothing in its middle: the spot itself shows, U238.)
  m.mark = medallion(m, "ARTWORK", SIZE, 1, 1, 1, 1)
  -- The steps' numbers under the mark.
  m.num = UI.Text(m, 14, nil, "title")
  m.num:SetFont(m.num:GetFont(), 14, "OUTLINE") -- (readable on any map)
  m.num:SetTextColor(1, 1, 1)
  m.num:SetPoint("TOP", m, "BOTTOM", 0, 4)
  m:SetScript("OnClick", function(self, button)
    GameTooltip:Hide()
    if button ~= "LeftButton" then return MM:Clear() end
    -- (Ringed only when the game set the waypoint; where it cannot, the place went to chat.)
    if ns.QuestLists:Waypoint(self.at.st, self.at.map) == "waypoint" then MM.followed = self.at; MM:Place() end
  end)
  m:SetScript("OnEnter", tip)
  m:SetScript("OnLeave", function() GameTooltip:Hide() end)
  -- (The map zoomed or was resized: placed again. Only while it shows.)
  m:SetScript("OnUpdate", function(self)
    local cv = canvas()
    if cv and (zoom() ~= self.z or cv:GetWidth() ~= self.w) then MM:Place() end
  end)
  m:Hide()
  return m
end

-- Each mark on its spot while the map shows its zone, the same size at any zoom (its scale undoes the canvas's).
function MM:Place()
  local c, list = canvas(), self.list
  if not c then return end
  local map, z, reduce = shownMap(), zoom(), ns.Settings:Get("reduce")
  for i, m in ipairs(self.marks) do
    local at = list and list[i]
    local on = at ~= nil and map == at.map
    m:SetShown(on)
    if not on then
      m.pulse:Stop()
    else
      m:SetScale(1 / z)
      m:ClearAllPoints()
      m:SetPoint("CENTER", c, "TOPLEFT", c:GetWidth() * at.st.x / 100 * z, -c:GetHeight() * at.st.y / 100 * z)
      m.z, m.w = z, c:GetWidth()
      m:SetAlpha(at.done and 0.45 or 1)
      m.ring:SetShown(self.followed == at)
      m.halo:SetShown(at.next == true)
      if at.next and not reduce then
        if not m.pulse:IsPlaying() then m.pulse:Play() end
      else
        m.pulse:Stop()
      end
    end
  end
end

-- A mark's numbers: its steps' (the quest's own start has none), a run of three or more as "1-5" ("1,2,3,4,5" ran
-- across the mark, then the crest; the check of 15 Nov 2026).
function MM.Label(items)
  local ks, out, i = {}, {}, 1
  for _, it in ipairs(items) do ks[#ks + 1] = it.k end
  while ks[i] do
    local j = i
    while ks[j + 1] == ks[j] + 1 do j = j + 1 end
    local run = j - i >= 2
    out[#out + 1] = run and (ks[i] .. "-" .. ks[j]) or ks[i]
    i = run and j + 1 or i + 1
  end
  return table.concat(out, ",")
end

-- Opens the map with marks (QuestLists:Marks: { st (a spot, x and y from 0 to 100), map, items = { { k (its step's
-- number; none for the quest's own start), name, status } }, done, next }, focus = the mark whose zone opens); title
-- names them in their tooltips (a quest; an entrance names itself). False when the map cannot open: in combat, or no
-- world map.
function MM:Show(list, title)
  if InCombatLockdown() or not (WorldMapFrame and OpenWorldMap) or #list == 0 then return false end
  local c = canvas()
  if not c then return false end
  for i, at in ipairs(list) do
    local m = self.marks[i] or build(c)
    self.marks[i] = m
    m.at = at
    m.num:SetText(MM.Label(at.items))
  end
  -- (The marks after the map is open: a hide while it opens takes them away.)
  if not self:Open(list[list.focus or 1].map) then self:Clear() return false end
  self.list, self.title, self.followed = list, title, nil
  self:Place()
  return true
end

-- Opens the world map at map, with or without marks. The book steps aside: it draws above the map. (Its close is not
-- the player's: watching another fellowship and the tour go on.) False when the game did not open it (a game rule
-- can turn the map off): the book is back.
function MM:Open(map)
  if not self.hooked then self.hooked = true; hooks() end
  local W = ns.Window
  if W:IsOpen() then
    self.book = true
    W.aside = true
    W:Close()
    W.aside = nil
  end
  OpenWorldMap(map)
  if WorldMapFrame:IsShown() then return true end
  if self.book then self.book = nil; W.frame:Show() end
  return false
end

function MM:Clear()
  self.list, self.followed = nil, nil
  for _, m in ipairs(self.marks) do m.pulse:Stop(); m:Hide() end
end
