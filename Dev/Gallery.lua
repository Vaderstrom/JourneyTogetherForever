-- /jtf debug buttons: a gallery of the game's own button and choice art, drawn on the book's parchment, to choose
-- the WoW-style controls from (27 Oct 2026: the flat parchment buttons looked like a web page). Every candidate is a
-- game template or texture; ones this client does not have show "missing". /jtf check controls takes its picture,
-- and the self-test records which templates exist (Dev/SelfTest.lua, "controls: ...").
local _, ns = ...
local UI, Theme = ns.UI, ns.Theme
local GA = {}
ns.Gallery = GA

-- Templates: { name, kind } (kind: "button" with a label, "tab", "check", "radio", "dropdown").
GA.TEMPLATES = {
  { "UIPanelButtonTemplate", "button" }, { "UIMenuButtonStretchTemplate", "button" },
  { "SharedButtonSmallTemplate", "button" }, { "SharedButtonTemplate", "button" },
  { "SharedGoldRedButtonSmallTemplate", "button" }, { "SharedGoldRedButtonTemplate", "button" },
  { "MagicButtonTemplate", "button" }, { "UIPanelDynamicResizeButtonTemplate", "button" },
  { "PanelTabButtonTemplate", "tab" }, { "PanelTopTabButtonTemplate", "tab" }, { "TabSystemButtonTemplate", "tab" },
  { "MinimalTabTemplate", "tab" },
  { "UICheckButtonTemplate", "check" }, { "SettingsCheckboxTemplate", "check" }, { "MinimalCheckboxTemplate", "check" },
  { "UIRadioButtonTemplate", "radio" }, { "WowStyle1DropdownTemplate", "dropdown" },
}
-- Atlases and files: { name, isAtlas, w, h } shown as a 140 x 26 swatch, or w x h. The Adventure Guide's art (its
-- Suggested Content, Tutorials and Journeys tabs) is in Forever's files too (29 Oct 2026, wago.tools).
GA.ART = {
  { "128-RedButton-Center", true }, { "128-GoldRedButton-Center", true }, { "uiframe-tab-center", true },
  { "uiframe-activetab-center", true }, { "Options_Tab_Middle", true }, { "Options_Tab_Active_Middle", true },
  { "common-dropdown-a-button", true }, { "PetList-ButtonBackground", true }, { "PetList-ButtonSelect", true },
  { "UI-LFG-RoleIcon-Tank", true }, { "UI-LFG-RoleIcon-Healer", true }, { "UI-LFG-RoleIcon-DPS", true },
  { "checkbox-minimal", true }, { "checkmark-minimal", true },
  { "adventureguide-ring", true, 47, 48 }, { "adventureguide-rewardring", true, 32, 32 },
  { "adventureguide-pane-small", true, 140, 66 }, { "adventureguide-tutorial-divider", true, 240, 6 },
  { "ui-journeys-renown-button", true, 140, 42 }, { "ui-journeys-renown-divider", true, 240, 8 },
  { "Interface\\Buttons\\UI-Panel-Button-Up" }, { "Interface\\Buttons\\UI-Panel-Button-Disabled" },
  { "Interface\\Buttons\\UI-DialogBox-Button-Up" }, { "Interface\\PaperDollInfoFrame\\UI-Character-ActiveTab" },
  { "Interface\\PaperDollInfoFrame\\UI-Character-InActiveTab" }, { "Interface\\LFGFrame\\UI-LFG-ICON-ROLES" },
}

local function atlasExists(name)
  return (C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(name) ~= nil) == true
end

-- Which of the templates and art this client has: { [name] = true | false }.
function GA:Probe()
  local out = {}
  local holder = CreateFrame("Frame", nil, UIParent)
  holder:Hide()
  for _, t in ipairs(self.TEMPLATES) do
    local ok = pcall(CreateFrame, t[2] == "dropdown" and "DropdownButton" or (t[2] == "check" or t[2] == "radio") and "CheckButton" or "Button", nil, holder, t[1])
    out[t[1]] = ok
  end
  local tex = holder:CreateTexture()
  for _, a in ipairs(self.ART) do
    if a[2] then out[a[1]] = atlasExists(a[1]) else out[a[1]] = tex:SetTexture(a[1]) ~= false end
  end
  return out
end

local function label(parent, text, x, y)
  local fs = UI.Text(parent, 11, "ink2", "body")
  fs:SetPoint("TOPLEFT", x, y)
  fs:SetWidth(GA.colW - 10)
  fs:SetWordWrap(false)
  fs:SetText(text)
  return fs
end

-- The gallery over the book's two pages.
function GA:Show()
  local W = ns.Window
  if not W.frame then return end
  local g = self.frame
  if not g then
    g = CreateFrame("Frame", nil, W.frame.book)
    g.layoutCover = true -- hides the pages under it (Dev/Layout.lua)
    g:SetAllPoints(W.frame.book)
    -- Above the pages' scroll fades too (they sit 40 over their list; one showed over the gallery in the check).
    g:SetFrameLevel(W.frame.book:GetFrameLevel() + 300)
    local bg = g:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    Theme:Register(function() bg:SetColorTexture(Theme:RGBA("page1", 1)) end)
    local has = self:Probe()
    local x, y, col = 24, -20, 0
    -- A cell h high goes in the next column when it would reach the Close button (the gallery ran out of the book at
    -- the bottom; the full screen's taller book has room for more). Five columns share the book's width: at 300 each
    -- the fifth ran off the right edge (seen in the check, 30 Oct 2026).
    local bh, bw = W.frame.book:GetHeight(), W.frame.book:GetWidth()
    local bottom = -((bh and bh > 200) and bh or 600) + 52
    GA.colW = math.min(300, math.floor((((bw and bw > 200) and bw or 1240) - 24) / 5))
    local colW = GA.colW
    local function room(h)
      if y - h < bottom and y < -20 then col = col + 1; x = 24 + col * colW; y = -20 end
    end
    local function nextCell(h) y = y - h end
    for _, t in ipairs(self.TEMPLATES) do
      room(48)
      label(g, t[1] .. (has[t[1]] and "" or "  (missing)"), x, y)
      if has[t[1]] then
        local kind = t[2]
        local ftype = kind == "dropdown" and "DropdownButton" or ((kind == "check" or kind == "radio") and "CheckButton" or "Button")
        local ok, b = pcall(CreateFrame, ftype, nil, g, t[1])
        if ok and b then
          b:SetPoint("TOPLEFT", x, y - 14)
          if kind == "button" or kind == "tab" then
            pcall(function() b:SetText(kind == "tab" and "Party (4-5)" or "Choose emblem") end)
            if kind == "button" then pcall(b.SetSize, b, 140, 24) end
            if kind == "tab" and PanelTemplates_TabResize then pcall(PanelTemplates_TabResize, b, 0) end
          elseif kind == "check" or kind == "radio" then
            pcall(b.SetChecked, b, true)
          elseif kind == "dropdown" then
            pcall(b.SetSize, b, 150, 24)
            pcall(function() b:SetDefaultText("Journal") end)
          end
          b:Show()
        end
      end
      nextCell(48)
    end
    for _, a in ipairs(self.ART) do
      room(math.max(48, (a[4] or 26) + 22))
      local short = a[1]:gsub("^Interface\\%a+\\", "")
      label(g, short .. (has[a[1]] and "" or "  (missing)"), x, y)
      if has[a[1]] then
        local t = g:CreateTexture(nil, "ARTWORK")
        t:SetPoint("TOPLEFT", x, y - 14)
        if a[2] then t:SetAtlas(a[1]) else t:SetTexture(a[1]) end
        local role = a[1]:find("RoleIcon") or a[1]:find("ICON%-ROLES") or a[1]:find("minimal")
        t:SetSize(math.min(a[3] or (role and 32 or 140), colW - 24), a[4] or (role and 32 or 26))
      end
      nextCell(math.max(48, (a[4] or 26) + 22))
    end
    local close = UI.TextButton(g, "Close", function() g:Hide() end, "primary")
    close:SetPoint("BOTTOMRIGHT", -20, 16)
    self.frame = g
  end
  g:Show()
end

function GA:Hide() if self.frame then self.frame:Hide() end end
