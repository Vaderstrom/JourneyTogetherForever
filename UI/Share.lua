-- Friends without the addon (SPEC §6, M25): a short window in the book with the addon's page to copy and Whisper the
-- link (the chat box opens with a whisper and the link; Enter sends it). It opens when an invite reached the player
-- but their addon did not answer (Fellowship/Sync.lua), and from Share the addon under Invite Adventurers.
local _, ns = ...
local L = ns.L
local UI = ns.UI
local Sh = {}
ns.Share = Sh

-- The addon's page. (The CurseForge project is made before the 0.9 beta: its address must be this one.)
Sh.URL = "https://www.curseforge.com/wow/addons/journey-together-forever"

-- What the chat box gets: "/w Kim Come level with us! ..."; nil without a name.
function Sh:WhisperText(name)
  name = ns.CleanName(name)
  if not name then return nil end
  return ("/w %s %s"):format(ns.Display(name), L.SHARE_MESSAGE:format(self.URL))
end

function Sh:Whisper(name)
  local text = self:WhisperText(name)
  local open = (ChatFrameUtil and ChatFrameUtil.OpenChat) or ChatFrame_OpenChat
  if text and open then open(text) end
  return text
end

local function build(o)
  local w = 488
  o.text = UI.WrapText(o.box, 14, "ink", w, "book")
  o.text:SetPoint("TOPLEFT", 16, -48)
  o.hint = UI.WrapText(o.box, 12, "ink2", w)
  o.urlLabel = UI.Text(o.box, 12, "ink2")
  o.urlLabel:SetText(L.SHARE_COPY)
  o.url = UI.EditBox(o.box, w, 200, "")
  -- The page's address stays as it is: typing in it puts it back, and a click selects it for Ctrl+C.
  o.url.edit:HookScript("OnTextChanged", function(eb, user)
    if user then eb:SetText(Sh.URL); eb:HighlightText() end
  end)
  o.url.edit:HookScript("OnEditFocusGained", function(eb) eb:HighlightText() end)
  local function whisper()
    if Sh:Whisper(o.name:GetText()) then o:Hide() else o.name.edit:SetFocus() end
  end
  o.nameLabel = UI.Text(o.box, 12, "ink2")
  o.nameLabel:SetText(L.SHARE_TO)
  o.name = UI.EditBox(o.box, 220, 48, L.CHARACTER_NAME, whisper)
  o.whisper = UI.TextButton(o.box, L.SHARE_WHISPER, whisper, "primary", 13)
  o.how = UI.WrapText(o.box, 11, "ink2", w)
  o.how:SetText(L.SHARE_WHISPER_HOW)
end

-- Opens the window (and the book when it is closed). name: who to whisper (may be empty); noAnswer: their addon did
-- not answer an invite. Returns the window, or nil in combat.
function Sh:Open(name, noAnswer)
  local W = ns.Window
  if ns.Combat:InCombat() then return nil end
  if not W:IsOpen() then W:Open("heroes") end
  if not W.frame then return nil end
  local o = W:Overlay("share", 520, 300)
  if not o.url then build(o) end
  name = name or ""
  local short = name ~= "" and ns.Short(name) or ""
  o.title:SetText(noAnswer and L.SHARE_NOANSWER_TITLE:format(short) or L.SHARE_TITLE)
  o.text:SetText(noAnswer and L.SHARE_NOANSWER:format(short) or L.SHARE_TEXT)
  o.hint:SetText(noAnswer and L.SHARE_NOANSWER_HINT or "")
  -- Top to bottom: the text, the hint, the page to copy, then who to whisper and the button.
  local y = 48 + o.text:GetStringHeight() + 6
  o.hint:ClearAllPoints(); o.hint:SetPoint("TOPLEFT", 16, -y)
  if noAnswer then y = y + o.hint:GetStringHeight() + 6 end
  y = y + 8
  o.urlLabel:ClearAllPoints(); o.urlLabel:SetPoint("TOPLEFT", 16, -y)
  y = y + 18
  o.url:ClearAllPoints(); o.url:SetPoint("TOPLEFT", 16, -y)
  o.url:SetText(self.URL)
  y = y + 26 + 14
  o.nameLabel:ClearAllPoints(); o.nameLabel:SetPoint("TOPLEFT", 16, -y)
  y = y + 18
  o.name:ClearAllPoints(); o.name:SetPoint("TOPLEFT", 16, -y)
  o.name:SetText(name ~= "" and ns.Display(name) or "")
  o.whisper:ClearAllPoints(); o.whisper:SetPoint("LEFT", o.name, "RIGHT", 12, 0)
  y = y + 26 + 8
  o.how:ClearAllPoints(); o.how:SetPoint("TOPLEFT", 16, -y)
  y = y + o.how:GetStringHeight() + 16
  o.box:SetHeight(y)
  o:Show()
  o.url.edit:SetFocus()
  return o
end
