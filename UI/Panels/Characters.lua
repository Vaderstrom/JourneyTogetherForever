-- "Your characters" panel (SPEC §4.1, the header button): the same list as on the Welcome page.
local _, ns = ...
local L = ns.L
local UI = ns.UI

local function build(p)
  p.intro = UI.WrapText(p.body, 12, "ink2", p.width)
  p.intro:SetPoint("TOPLEFT", 0, -4)
  p.intro:SetText(L.CHARACTERS_INTRO)
  p.listFrame = CreateFrame("Frame", nil, p.body)
  p.listFrame:SetPoint("TOPLEFT", 0, -(p.intro:GetStringHeight() + 14))
  p.listFrame:SetSize(p.width, 10)
  p.list = UI.CharacterList(p.listFrame, p.width)
end

local function refresh(p)
  local h = p.list:Refresh()
  p.scroll:SetContentHeight(p.intro:GetStringHeight() + 24 + h)
end

ns.Window:RegisterPanel("characters", { title = L.YOUR_CHARACTERS, build = build, refresh = refresh })
