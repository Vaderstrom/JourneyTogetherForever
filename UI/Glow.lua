-- The walkthrough's highlight (UI/Walkthrough.lua, 27 Oct 2026): a pulsing gold frame around a part of the book,
-- with sparks that travel along its edge, like the game's own autocast and proc glows. The sparks use the game's art
-- when the client has it (the artifact sparks, then the cooldown star); our own dots otherwise. No library: the
-- motion is a few textures moved along the frame's edge in OnUpdate.
local _, ns = ...
local UI, Theme = ns.UI, ns.Theme

-- The game's spark art, best first: { file, texcoords or nil }. Each is tried; a missing file is skipped.
UI.GLOW_SPARKS = {
  { "Interface\\Artifacts\\Artifacts", { 0.8115234375, 0.9169921875, 0.8798828125, 0.9853515625 } },
  { "Interface\\Cooldown\\star4" },
}
-- Other game art a glow could use, for the self-test's report (Dev/SelfTest.lua): which this client has.
UI.GLOW_PROBE = {
  sparks = "Interface\\Artifacts\\Artifacts", star = "Interface\\Cooldown\\star4",
  iconAlert = "Interface\\SpellActivationOverlay\\IconAlert", ants = "Interface\\SpellActivationOverlay\\IconAlertAnts",
}
UI.GLOW_ATLAS_PROBE = { "UI-HUD-ActionBar-Proc-Loop-Flipbook", "NPE_ArrowDown", "editmode-actionbar-highlight-nineslice-center" }

local SPARKS, SPEED, PAD = 10, 90, 6 -- sparks on the edge, pixels a second, space around the target

-- Which spark art this client has: the index into GLOW_SPARKS, or 0 for our own dots.
function UI.GlowArt()
  if UI.glowArt then return UI.glowArt end
  local t = UIParent:CreateTexture()
  UI.glowArt = 0
  for i, a in ipairs(UI.GLOW_SPARKS) do
    if t:SetTexture(a[1]) ~= false then UI.glowArt = i break end
  end
  t:Hide()
  return UI.glowArt
end

function UI.Highlight(parent)
  local h = CreateFrame("Frame", nil, parent or UIParent)
  h:SetFrameStrata("FULLSCREEN_DIALOG")
  h:Hide()
  -- The frame: a gold line and a soft glow outside it that breathes.
  h.edges, h.glows = {}, {}
  for i = 1, 4 do
    h.edges[i] = UI.Solid(h, "OVERLAY", "F2C25B", 1)
    local g = h:CreateTexture(nil, "ARTWORK")
    g:SetColorTexture(1, 0.78, 0.3, 0.35)
    g:SetBlendMode("ADD")
    h.glows[i] = g
  end
  local function edge(i, a1, a2, horizontal, size, out)
    local e, g = h.edges[i], h.glows[i]
    e:ClearAllPoints(); e:SetPoint(a1); e:SetPoint(a2)
    g:ClearAllPoints()
    if horizontal then
      e:SetHeight(2)
      g:SetPoint(a1, h, a1, 0, out); g:SetPoint(a2, h, a2, 0, out); g:SetHeight(size)
    else
      e:SetWidth(2)
      g:SetPoint(a1, h, a1, out, 0); g:SetPoint(a2, h, a2, out, 0); g:SetWidth(size)
    end
  end
  edge(1, "TOPLEFT", "TOPRIGHT", true, 6, 2)
  edge(2, "BOTTOMLEFT", "BOTTOMRIGHT", true, 6, -2)
  edge(3, "TOPLEFT", "BOTTOMLEFT", false, 6, -2)
  edge(4, "TOPRIGHT", "BOTTOMRIGHT", false, 6, 2)
  local pulse = h:CreateAnimationGroup()
  pulse:SetLooping("BOUNCE")
  local a = pulse:CreateAnimation("Alpha")
  a:SetFromAlpha(1); a:SetToAlpha(0.55); a:SetDuration(0.9)
  if a.SetSmoothing then a:SetSmoothing("IN_OUT") end
  h.pulse = pulse
  -- The sparks.
  h.sparks = {}
  local art = UI.GLOW_SPARKS[UI.GlowArt()]
  for i = 1, SPARKS do
    local s
    if art then
      s = h:CreateTexture(nil, "OVERLAY", nil, 7)
      s:SetTexture(art[1])
      if art[2] then s:SetTexCoord(unpack(art[2])) end
      s:SetBlendMode("ADD")
      s:SetVertexColor(1, 0.85, 0.45)
    else
      s = UI.Round(h, "OVERLAY", 6, 7)
      Theme:Fill(s, "FFE6A0", 1)
    end
    local size = (i % 3 == 0) and 18 or 13
    s:SetSize(size, size)
    h.sparks[i] = s
  end
  h.t = 0
  h:SetScript("OnUpdate", function(self, elapsed)
    self.t = self.t + elapsed
    local w, ht = self:GetWidth(), self:GetHeight()
    if not w or w <= 0 or not ht or ht <= 0 then return end
    local per = 2 * (w + ht)
    for i, s in ipairs(self.sparks) do
      -- Evenly spread along the edge, going round; each flickers a little.
      local d = (self.t * SPEED + (i - 1) * per / #self.sparks) % per
      local x, y
      if d < w then x, y = d, 0
      elseif d < w + ht then x, y = w, -(d - w)
      elseif d < 2 * w + ht then x, y = w - (d - w - ht), -ht
      else x, y = 0, -(ht - (d - 2 * w - ht)) end
      s:ClearAllPoints(); s:SetPoint("CENTER", self, "TOPLEFT", x, y)
      s:SetAlpha(0.55 + 0.45 * math.abs(math.sin(self.t * 3 + i)))
    end
  end)

  -- Around one frame, or around several (from the first one's top left to the last one's bottom right). Frames in
  -- the book are anchored to (they move with the page); others, such as the tracker, get a fixed place on the screen:
  -- anchoring to them failed in game ("SetPoint would result in anchor family connection").
  function h:Around(first, last, fixed)
    last = last or first
    self:ClearAllPoints()
    if fixed then
      local s = UIParent:GetEffectiveScale()
      local function px(f, v) return (v or 0) * f:GetEffectiveScale() / s end
      self:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", px(first, first:GetLeft()) - PAD, px(first, first:GetTop()) + PAD)
      self:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMLEFT", px(last, last:GetRight()) + PAD, px(last, last:GetBottom()) - PAD)
    else
      self:SetPoint("TOPLEFT", first, "TOPLEFT", -PAD, PAD)
      self:SetPoint("BOTTOMRIGHT", last, "BOTTOMRIGHT", PAD, -PAD)
    end
    self:Show()
    if not ns.Settings or not ns.Settings:Get("reduce") then self.pulse:Play() end
  end
  function h:Off() self.pulse:Stop(); self:Hide() end
  return h
end
