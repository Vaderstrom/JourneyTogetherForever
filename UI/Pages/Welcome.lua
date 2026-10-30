-- Welcome (SPEC §4.1): shown to a character without a fellowship.
local _, ns = ...
local L = ns.L
local UI = ns.UI

local function build(pf)
  local W = ns.Window
  local width = W.PAGE_W_WIDE
  local left = pf.left
  local logo = left:CreateTexture(nil, "ARTWORK")
  -- Bigger, and cut to the drawing (the file has empty space around it; the logo looked small, 27 Oct 2026).
  logo:SetSize(190, 157)
  logo:SetPoint("TOP", 0, 4)
  logo:SetTexture(ns.MEDIA .. "Logo")
  logo:SetTexCoord(55 / 1024, 972 / 1024, 129 / 1024, 885 / 1024)
  local tag = UI.Text(left, 18, "ink", "title", "CENTER")
  tag:SetPoint("TOP", logo, "BOTTOM", 0, -2)
  tag:SetText(L.TAGLINE)
  -- The two ways in as large picture tiles, like the Adventure Guide's dungeon buttons (they were two small buttons
  -- under the features; seen in game, 27 Oct 2026). Sized so the three feature lines still fit under them.
  local TILE_H, TILE_TOP = 112, -186
  pf.found = UI.PictureTile(left, width, TILE_H, function(tex, w, h) ns.Pages:SetChapterArt(tex, 1, w, h, 0.45) end,
    function() W.startView = "create"; W:Refresh() end)
  pf.found:Set(L.FOUND, L.FOUND_TILE)
  pf.found:SetPoint("TOP", 0, TILE_TOP)
  -- The Join tile shows your side's hall (a Horde character saw the Alliance throne room; seen in game).
  pf.join = UI.PictureTile(left, width, TILE_H, function(tex, w, h)
    local hall = (ns.Theme:Horde() and ns.Pages.ART_HORDE or ns.Pages.ART).hall
    tex:SetTexture(ns.MEDIA .. hall[1]); UI.Cover(tex, hall[2], w, h, 0.5)
  end, function() W.startView = "join"; W:Refresh() end)
  pf.join:Set(L.JOIN, L.JOIN_TILE)
  pf.join:SetPoint("TOP", pf.found, "BOTTOM", 0, -12)
  -- A link to the Join page (it was pale gold text that did nothing; seen in the tour).
  pf.invites = UI.TextButton(left, "", function() W.startView = "join"; W:Refresh() end, "link", 13)
  pf.invites:SetPoint("TOP", pf.join, "BOTTOM", 0, -6)
  -- A trial account (ns.Trial): what will not work, where the invites line would be.
  pf.trial = UI.WrapText(left, 12, "B0321E", width, "book")
  pf.trial:SetPoint("TOP", pf.join, "BOTTOM", 0, -6)
  pf.trial:SetText(L.TRIAL)
  -- What the addon does, below the two ways in.
  local y = TILE_TOP - 2 * TILE_H - 12 - 36
  for i, key in ipairs({ "overview", "tourney", "quests" }) do
    local icon = UI.Round(left, "ARTWORK", 22)
    icon:SetPoint("TOPLEFT", 0, y)
    UI.SetIcon(icon, ns.ICONS[key])
    local fs = UI.WrapText(left, 13, "ink", width - 34, "book")
    fs:SetPoint("TOPLEFT", 34, y + 1)
    fs:SetText(L["FEATURE_" .. i])
    y = y - math.max(26, fs:GetStringHeight() + 8)
  end

  local head = UI.Heading(pf.right, width, L.YOUR_CHARACTERS, L.CHARACTERS_SUB)
  head:SetPoint("TOPLEFT")
  -- How it works (M21): the lower half of the page was empty (seen in the tour). The first chapter's picture with
  -- the three steps of a journey on it.
  local how = CreateFrame("Frame", nil, pf.right)
  how:SetSize(width, 230)
  how:SetPoint("BOTTOMLEFT")
  pf.how = how
  local hh = UI.SectionHeader(how, width)
  hh:SetText(L.HOW_HEAD)
  hh:SetPoint("TOPLEFT")
  -- The picture in its frame (UI.FramePicture), the steps written on it.
  local box = CreateFrame("Frame", nil, how)
  how.box = box
  box:SetPoint("TOPLEFT", 0, -34); box:SetPoint("BOTTOMRIGHT")
  local pic = box:CreateTexture(nil, "ARTWORK")
  local shade = box:CreateTexture(nil, "ARTWORK", nil, 2)
  UI.FramePicture(box, pic, shade)
  ns.Pages:SetChapterArt(pic, 1, width - 2 * UI.PIC_INSET, 196 - 2 * UI.PIC_INSET, 0.5)
  UI.SetGradient(shade, "HORIZONTAL", { 0.05, 0.03, 0.01, 0.9 }, { 0.05, 0.03, 0.01, 0.2 })
  for i = 1, 3 do
    local n = UI.Text(box, 22, "goldText", "title")
    n:SetPoint("TOPLEFT", how, "TOPLEFT", 14, -34 - 14 - (i - 1) * 58)
    n:SetText(i)
    n:SetShadowOffset(1, -1); n:SetShadowColor(0, 0, 0, 1)
    local t = UI.WrapText(box, 13, "chipText", width * 0.62, "book")
    t:SetPoint("TOPLEFT", how, "TOPLEFT", 40, -34 - 16 - (i - 1) * 58)
    t:SetText(L["HOW_" .. i])
    t:SetShadowOffset(1, -1); t:SetShadowColor(0, 0, 0, 1)
  end
  pf.scroll = UI.Scroll(pf.right)
  pf.scroll:SetPoint("TOPLEFT", 0, -(head:GetHeight() + 6)); pf.scroll:SetPoint("BOTTOMRIGHT", how, "TOPRIGHT", 0, 10)
  pf.list = UI.CharacterList(pf.scroll.child, width - 8)
end

local function refresh(pf)
  local n = #ns.Fellowship:MyInvites()
  local trial = ns.Trial()
  pf.trial:SetShown(trial)
  -- (The invites line goes under the trial warning.)
  pf.invites:ClearAllPoints()
  pf.invites:SetPoint("TOP", trial and pf.trial or pf.join, "BOTTOM", 0, trial and -4 or -6)
  pf.invites:SetShown(n > 0)
  pf.invites:SetLabel(ns.InlineTexture(ns.ICONS.inbox, 14) .. " " .. (n == 1 and L.INVITES_WAITING_1 or L.INVITES_WAITING_N:format(n)))
  pf.scroll:SetContentHeight(pf.list:Refresh() + 8)
end

ns.Pages:Register({ id = "welcome", label = L.ADDON_NAME, header = "none", build = build, refresh = refresh,
  title = function(ctx) return L.TITLE_WELCOME:format(ctx.playerName or ""), L.ADDON_NAME end })
