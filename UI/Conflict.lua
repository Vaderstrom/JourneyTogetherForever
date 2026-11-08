-- The conflict window (the owner, 3 Nov 2026): Fellowship/Conflicts.lua found data the Adventurers' addons should agree
-- on but do not. In the book (it opens when closed), never in a fight: what was found, the report to copy, and where
-- to post it (GitHub issues, the CurseForge page's comments). Its addresses and report cannot be typed over.
local _, ns = ...
local L = ns.L
local UI = ns.UI
local Cw = {}
ns.ConflictWindow = Cw

Cw.GITHUB = "https://github.com/Vaderstrom/JourneyTogetherForever/issues"
Cw.CURSEFORGE = "https://www.curseforge.com/wow/addons/journey-together-forever/comments"

local W = 528

-- A box whose text stays as it is: typing puts it back, a click selects it for Ctrl+C.
local function locked(eb, get)
  eb:HookScript("OnTextChanged", function(e, user) if user then e:SetText(get()); e:HighlightText() end end)
  eb:HookScript("OnEditFocusGained", function(e) e:HighlightText() end)
end

local function build(o)
  o.text = UI.WrapText(o.box, 14, "ink", W, "book")
  o.items = {}
  o.hint = UI.WrapText(o.box, 12, "ink2", W)
  o.hint:SetText(L.CONFLICT_HINT)
  o.ghLabel = UI.Text(o.box, 12, "ink2")
  o.ghLabel:SetText(L.CONFLICT_GITHUB)
  o.gh = UI.EditBox(o.box, W, 200, "")
  locked(o.gh.edit, function() return Cw.GITHUB end)
  o.cfLabel = UI.Text(o.box, 12, "ink2")
  o.cfLabel:SetText(L.CONFLICT_CURSEFORGE)
  o.cf = UI.EditBox(o.box, W, 200, "")
  locked(o.cf.edit, function() return Cw.CURSEFORGE end)
  o.reportLabel = UI.Text(o.box, 12, "ink2")
  o.reportLabel:SetText(L.CONFLICT_REPORT)
  -- U59 (the check of 4 Nov 2026): one click selects the whole report and says what to press.
  o.select = UI.TextButton(o.box, L.CONFLICT_SELECT, function() Cw:SelectReport() end)
  o.selected = UI.Text(o.box, 12, "accent")
  o.holder = UI.Card(o.box)
  o.holder:SetSize(W, 104)
  o.scroll = CreateFrame("ScrollFrame", nil, o.holder)
  o.scroll:SetPoint("TOPLEFT", 8, -8); o.scroll:SetPoint("BOTTOMRIGHT", -8, 8)
  o.report = CreateFrame("EditBox", nil, o.scroll)
  o.report:SetMultiLine(true)
  o.report:SetAutoFocus(false)
  o.report:SetFont(ns.Theme.FONT_BODY, 12, "")
  o.report:SetWidth(W - 20)
  ns.Theme:TextColor(o.report, "ink")
  o.report:SetScript("OnEscapePressed", function() o:Hide() end)
  locked(o.report, function() return o.reportText or "" end)
  o.scroll:SetScrollChild(o.report)
end

-- One line of the list: the part's icon in a gold ring, its words beside it.
local function item(o, i)
  local r = o.items[i]
  if r then return r end
  r = CreateFrame("Frame", nil, o.box)
  r:SetSize(W - 12, 22)
  local ring = UI.Round(r, "ARTWORK", 20)
  ring:SetPoint("TOPLEFT", 0, 0); ns.Theme:Fill(ring, "gold", 0.9)
  r.icon = UI.Round(r, "OVERLAY", 16)
  r.icon:SetPoint("CENTER", ring, "CENTER")
  r.text = UI.WrapText(r, 13, "ink", W - 40)
  r.text:SetPoint("TOPLEFT", 28, -3)
  o.items[i] = r
  return r
end

-- Opens the window for conflict c (Conflicts:Found). Returns it, or nil in a fight.
function Cw:Open(c)
  local Win = ns.Window
  if not c or ns.Combat:InCombat() then return nil end
  if not Win:IsOpen() then Win:Open() end
  if not Win.frame then return nil end
  local o = Win:Overlay("conflict", W + 32, 420)
  if not o.report then build(o) end
  self.shown = c
  o.title:SetText(L.CONFLICT_T)
  o.text:SetText(ns.Conflicts:Lead(c))
  o.reportText = ns.Conflicts:Report(c)
  -- Top to bottom: what was found (a line for each part), what to do, the two addresses, the report.
  local y = 48
  o.text:ClearAllPoints(); o.text:SetPoint("TOPLEFT", 16, -y)
  y = y + o.text:GetStringHeight() + 8
  local list = ns.Conflicts:Items(c)
  for i, x in ipairs(list) do
    local r = item(o, i)
    UI.SetIcon(r.icon, x.icon)
    r.text:SetText(x.text)
    r:SetHeight(math.max(22, r.text:GetStringHeight() + 6))
    r:ClearAllPoints(); r:SetPoint("TOPLEFT", 28, -y)
    r:Show()
    y = y + r:GetHeight() + 4
  end
  for i = #list + 1, #o.items do o.items[i]:Hide() end
  y = y + 6
  o.hint:ClearAllPoints(); o.hint:SetPoint("TOPLEFT", 16, -y)
  y = y + o.hint:GetStringHeight() + 12
  for _, row in ipairs({ { o.ghLabel, o.gh, self.GITHUB }, { o.cfLabel, o.cf, self.CURSEFORGE } }) do
    row[1]:ClearAllPoints(); row[1]:SetPoint("TOPLEFT", 16, -y)
    y = y + 18
    row[2]:ClearAllPoints(); row[2]:SetPoint("TOPLEFT", 16, -y)
    row[2]:SetText(row[3])
    y = y + 26 + 8
  end
  o.reportLabel:ClearAllPoints(); o.reportLabel:SetPoint("TOPLEFT", 16, -y)
  o.select:ClearAllPoints(); o.select:SetPoint("TOPRIGHT", o.box, "TOPLEFT", 16 + W, -(y - 8))
  o.selected:ClearAllPoints(); o.selected:SetPoint("RIGHT", o.select, "LEFT", -8, 0)
  o.selected:SetText("")
  y = y + 26
  o.holder:ClearAllPoints(); o.holder:SetPoint("TOPLEFT", 16, -y)
  o.report:SetText(o.reportText)
  y = y + o.holder:GetHeight() + 16
  o.box:SetHeight(y)
  o:Show()
  o.report:SetFocus()
  o.report:HighlightText()
  return o
end

-- Selects the whole report for Ctrl+C and says so (U59).
function Cw:SelectReport()
  local o = ns.Window.overlays and ns.Window.overlays.conflict
  if not (o and o.report) then return end
  o.report:SetFocus()
  o.report:HighlightText()
  o.selected:SetText(L.CONFLICT_SELECTED)
end
