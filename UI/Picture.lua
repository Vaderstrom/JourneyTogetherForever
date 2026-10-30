-- The picture moment (SPEC §5): when a dungeon's final boss dies, a small banner asks whether to take a picture of
-- the group before everyone leaves. Take a picture saves a screenshot (the game's own, into the Screenshots folder);
-- Without the interface hides the whole interface for that picture (only out of combat: hiding it in a fight is not
-- allowed); Done or a few minutes close it. The game has no photo mode an addon can open, so this is the screenshot.
-- The banner is made at login, never in combat (the boss dies in combat).
local _, ns = ...
local L = ns.L
local UI, Combat, Settings = ns.UI, ns.Combat, ns.Settings
-- 60 seconds, low on the screen above the action bars, away from the book (over the header it covered the
-- fellowship's name; seen in the tour). Leaving the instance closes it too.
local P = { STAY = 60, taken = 0 }
ns.Picture = P

function P:Build()
  if self.frame then return self.frame end
  local f = UI.Card(UIParent, "gold")
  f.bgRole = "page1"
  f:Paint()
  UI.DialogFrame(f)
  f:SetSize(530, 128)
  f:SetFrameStrata("DIALOG")
  -- Above three rows of action bars (at 190 it covered the top row; seen in the check, 29 Oct 2026).
  f:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 300)
  f:SetClampedToScreen(true)
  f.title = UI.Text(f, 17, "ink", "title")
  f.title:SetPoint("TOPLEFT", 16, -12)
  f.title:SetText(L.PIC_TITLE)
  f.text = UI.WrapText(f, 13, "ink2", 498, "book")
  f.text:SetPoint("TOPLEFT", 16, -36)
  f.take = UI.TextButton(f, L.PIC_TAKE, function() P:Take(false) end, "primary", 13)
  f.take:SetPoint("BOTTOMLEFT", 16, 14)
  f.clean = UI.TextButton(f, L.PIC_CLEAN, function() P:Take(true) end, "plain", 13)
  f.clean:SetPoint("LEFT", f.take, "RIGHT", 8, 0)
  -- The group photo on the whole screen (UI/Photo.lua), here in the dungeon.
  f.photo = UI.TextButton(f, L.PIC_PHOTO, function() if ns.Photo:Open() then P:Hide() end end, "plain", 13)
  f.photo:SetPoint("LEFT", f.clean, "RIGHT", 8, 0)
  f.done = UI.TextButton(f, L.PIC_DONE, function() P:Hide() end, "plain", 13)
  f.done:SetPoint("BOTTOMRIGHT", -16, 14)
  f:Hide()
  self.frame = f
  return f
end

-- Shown for the dungeon whose final boss just died (key), unless turned off in Settings.
function P:Offer(key)
  if not Settings:Get("picture") then return false end
  local f = self.frame
  if not f then return false end
  local d = ns.Dungeon(key)
  self.key, self.taken, self.token = key, 0, (self.token or 0) + 1
  f.text:SetText(L.PIC_TEXT:format(d and d[2] or key))
  self:Refresh()
  f:Show()
  local token = self.token
  C_Timer.After(self.STAY, function() if P.token == token then P:Hide() end end)
  return true
end

function P:Refresh()
  local f = self.frame
  if not f then return end
  f.clean:SetEnabled(not Combat:InCombat())
  f.photo:SetEnabled(not Combat:InCombat())
  if self.taken > 0 then f.text:SetText(L.PIC_TAKEN:format(self.taken)) end
end

function P:Hide()
  self.token = (self.token or 0) + 1
  if self.frame then self.frame:Hide() end
end

-- One picture. clean: without the interface (out of combat only); it comes back right after.
function P:Take(clean)
  if clean and Combat:InCombat() then return false end
  local f = self.frame
  if clean then
    UIParent:Hide()
    C_Timer.After(0.1, function()
      if Screenshot then Screenshot() end
      C_Timer.After(0.4, function() UIParent:Show() end)
    end)
  else
    -- The banner itself stays out of the picture.
    f:SetAlpha(0)
    C_Timer.After(0.05, function()
      if Screenshot then Screenshot() end
      C_Timer.After(0.3, function() f:SetAlpha(1) end)
    end)
  end
  self.taken = self.taken + 1
  -- Kept for Moments and Discord (Fellowship/Moments.lua): when, where and with whom.
  ns.Moments:Picture(ns.Fellowship:Current(), self.key)
  self:Refresh()
  return true
end

ns:On("LOGIN", function() Combat:AfterCombat(function() P:Build() end) end)
ns:RegisterEvent("PLAYER_REGEN_ENABLED", function() if P.frame and P.frame:IsShown() then P:Refresh() end end)
-- Out of the dungeon: the moment has passed.
ns:RegisterEvent("PLAYER_ENTERING_WORLD", function()
  local _, kind = IsInInstance()
  if P.frame and P.frame:IsShown() and kind ~= "party" and kind ~= "raid" then P:Hide() end
end)
