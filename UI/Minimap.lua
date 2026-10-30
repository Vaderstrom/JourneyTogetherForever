-- Minimap button: opens and closes the book. Drag it around the minimap.
-- Adapted from GuildHall_Core/UI/Frame.lua (CreateMinimapButton).
local _, ns = ...
local L = ns.L
local M = {}
ns.MinimapButton = M

local DEFAULT_ANGLE = 225

function M:Place()
  local b = self.button
  local a = math.rad(ns.char.minimapAngle or DEFAULT_ANGLE)
  local r = (Minimap:GetWidth() or 140) / 2 + 10
  b:ClearAllPoints()
  b:SetPoint("CENTER", Minimap, "CENTER", math.cos(a) * r, math.sin(a) * r)
end

function M:Build()
  if self.button or not Minimap then return end
  local b = CreateFrame("Button", nil, Minimap)
  b:SetSize(32, 32)
  b:SetFrameStrata("MEDIUM")
  b:SetFrameLevel(8)
  b:RegisterForClicks("LeftButtonUp")
  b:RegisterForDrag("LeftButton")
  local icon = b:CreateTexture(nil, "BACKGROUND")
  icon:SetSize(22, 22); icon:SetPoint("CENTER")
  icon:SetTexture(ns.MEDIA .. "LogoSmall")
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
    GameTooltip:SetText(L.ADDON_NAME)
    -- What the button does, like other minimap buttons (the tooltip was only the name; seen in the tour).
    GameTooltip:AddLine(L.MINIMAP_TIP_CLICK, 1, 1, 1)
    GameTooltip:AddLine(L.MINIMAP_TIP_DRAG, 0.7, 0.7, 0.7)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  self.button = b
  self:Place()
  self:Update()
end

function M:Update()
  if self.button then self.button:SetShown(ns.Settings:Get("minimap")) end
end

ns:On("LOGIN", function() ns.Combat:AfterCombat(function() M:Build() end) end)
ns:On("SETTING", function(key) if key == "minimap" then M:Update() end end)
