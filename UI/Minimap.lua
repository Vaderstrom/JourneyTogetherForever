-- Minimap button: opens and closes the book. Drag it around the minimap.
-- Adapted from GuildHall_Core/UI/Frame.lua (CreateMinimapButton).
-- Button collectors (the owner, 6 Nov 2026): addons that gather minimap buttons into a bar or a bag (Minimap Button
-- Bag, HidingBar, SexyMap, ElvUI and others) must be able to take it. When another addon has loaded LibDataBroker and
-- LibDBIcon (most players have them through some addon), the button is made by LibDBIcon, which every collector
-- knows; this addon ships neither library. Otherwise it is our own button with a name (collectors look for named
-- buttons on the minimap; the name is a global, one of the exceptions in CLAUDE.md). The game's addon compartment
-- (the button under the minimap's calendar) lists the addon too, so the book opens with the button hidden.
local ADDON, ns = ...
local L = ns.L
local M = {}
ns.MinimapButton = M

local DEFAULT_ANGLE = 225
M.NAME = ADDON:gsub("[^%w]", "") .. "MinimapButton"

function M:Place()
  local b = self.button
  if not b or self.dbicon then return end
  local a = math.rad(ns.char.minimapAngle or DEFAULT_ANGLE)
  local r = (Minimap:GetWidth() or 140) / 2 + 10
  b:ClearAllPoints()
  b:SetPoint("CENTER", Minimap, "CENTER", math.cos(a) * r, math.sin(a) * r)
end

local function tooltip(tt)
  tt:AddLine(L.ADDON_NAME)
  -- What the button does, like other minimap buttons (the tooltip was only the name; seen in the tour).
  tt:AddLine(L.MINIMAP_TIP_CLICK, 1, 1, 1)
  tt:AddLine(L.MINIMAP_TIP_DRAG, 0.7, 0.7, 0.7)
end

-- LibDBIcon from another addon, or nil.
local function libs()
  local stub = LibStub
  if type(stub) ~= "table" or type(stub.GetLibrary) ~= "function" then return nil end
  local ldb = stub:GetLibrary("LibDataBroker-1.1", true)
  local icon = stub:GetLibrary("LibDBIcon-1.0", true)
  if ldb and icon and ldb.NewDataObject and icon.Register then return ldb, icon end
end

function M:BuildDBIcon(ldb, icon)
  local obj = ldb:NewDataObject(ADDON, {
    type = "launcher", text = L.ADDON_NAME, label = L.ADDON_NAME, icon = ns.MEDIA .. "LogoSmall",
    OnClick = function() ns.Window:Toggle() end,
    OnTooltipShow = function(tt) if tt and tt.AddLine then tooltip(tt) end end,
  })
  if not obj then return false end
  -- LibDBIcon keeps its place and shown state in this table (minimapPos in degrees, hide).
  local db = type(ns.char.dbicon) == "table" and ns.char.dbicon or {}
  db.minimapPos = db.minimapPos or ns.char.minimapAngle or DEFAULT_ANGLE
  db.hide = not ns.Settings:Get("minimap")
  ns.char.dbicon = db
  icon:Register(ADDON, obj, db)
  self.dbicon = icon
  self.button = icon.GetMinimapButton and icon:GetMinimapButton(ADDON) or nil
  return true
end

function M:BuildOwn()
  local b = CreateFrame("Button", self.NAME, Minimap)
  b:SetSize(32, 32)
  b:SetFrameStrata("MEDIUM")
  b:SetFrameLevel(8)
  b:RegisterForClicks("LeftButtonUp")
  b:RegisterForDrag("LeftButton")
  local icon = b:CreateTexture(nil, "BACKGROUND")
  icon:SetSize(22, 22); icon:SetPoint("CENTER")
  icon:SetTexture(ns.MEDIA .. "LogoSmall")
  b.icon = icon
  local border = b:CreateTexture(nil, "OVERLAY")
  border:SetSize(54, 54); border:SetPoint("TOPLEFT")
  border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
  b:SetScript("OnDragStart", function()
    b:SetScript("OnUpdate", function()
      local mx, my = Minimap:GetCenter()
      local cx, cy = GetCursorPosition()
      local scale = Minimap:GetEffectiveScale()
      ns.char.minimapAngle = math.deg(math.atan2(cy / scale - my, cx / scale - mx))
      M:Place()
    end)
  end)
  b:SetScript("OnDragStop", function() b:SetScript("OnUpdate", nil) end)
  b:SetScript("OnClick", function() ns.Window:Toggle() end)
  b:SetScript("OnEnter", function()
    GameTooltip:SetOwner(b, "ANCHOR_LEFT")
    tooltip(GameTooltip)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  self.button = b
  self:Place()
end

-- The game's addon compartment (retail 10.1 and later, and WoW Forever): the addon in its list.
function M:Compartment()
  local cf = AddonCompartmentFrame
  if self.compartment or type(cf) ~= "table" or type(cf.RegisterAddon) ~= "function" then return end
  self.compartment = true
  cf:RegisterAddon({
    text = L.ADDON_NAME, icon = ns.MEDIA .. "LogoSmall", notCheckable = true,
    func = function() ns.Window:Toggle() end,
    funcOnEnter = function(button)
      GameTooltip:SetOwner(button, "ANCHOR_LEFT")
      GameTooltip:AddLine(L.ADDON_NAME)
      GameTooltip:AddLine(L.MINIMAP_TIP_CLICK, 1, 1, 1)
      GameTooltip:Show()
    end,
    funcOnLeave = function() GameTooltip:Hide() end,
  })
end

function M:Build()
  if self.button or self.dbicon or not Minimap then return end
  local ldb, icon = libs()
  if not (ldb and self:BuildDBIcon(ldb, icon)) then self:BuildOwn() end
  self:Compartment()
  self:Update()
end

function M:Update()
  local show = ns.Settings:Get("minimap")
  if self.dbicon then
    if type(ns.char.dbicon) == "table" then ns.char.dbicon.hide = not show end
    if show then self.dbicon:Show(ADDON) else self.dbicon:Hide(ADDON) end
  elseif self.button then
    self.button:SetShown(show)
  end
end

ns:On("LOGIN", function() ns.Combat:AfterCombat(function() M:Build() end) end)
ns:On("SETTING", function(key) if key == "minimap" then ns.Combat:AfterCombat(function() M:Update() end) end end)
