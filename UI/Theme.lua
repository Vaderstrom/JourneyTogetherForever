-- Themes: colours from the mockup (docs/mockup/mockup-logic.js, THEMES and ACCENT).
-- UI code never stores a colour. It paints with a role ("ink", "page1", "accent" ...) through Theme,
-- and Theme:Apply() repaints everything when the theme or the accent changes.
local _, ns = ...
local T = {}
ns.Theme = T

-- card is { hex, alpha } (rgba in the mockup).
T.THEMES = {
  journal = { frame = "2A1C10", side = "24170C", sideInk = "EAD7A8", sideMuted = "A8865A", page1 = "F6EAD0", page2 = "E4CF9F",
    ink = "3B2410", ink2 = "4E3A20", line = "C2A271", card = { "FFFAEB", 0.55 }, light = true },
  night = { frame = "10141C", side = "0C1018", sideInk = "D5DBE8", sideMuted = "7D879C", page1 = "262D3B", page2 = "1B212D",
    ink = "EEE8DA", ink2 = "A9B1C4", line = "3E4A63", card = { "FFFFFF", 0.04 }, light = false },
  alliance = { frame = "10204A", side = "0B1736", sideInk = "E2E8F6", sideMuted = "8A98C0", page1 = "F3E9D2", page2 = "E2D3AE",
    ink = "1F2A44", ink2 = "46506A", line = "B8A57C", card = { "FFFCF0", 0.55 }, light = true },
  horde = { frame = "2E0F0B", side = "220A08", sideInk = "F2DCCB", sideMuted = "B08672", page1 = "F3E3CC", page2 = "E2C9A6",
    ink = "3A1612", ink2 = "5C3A2E", line = "C29A7A", card = { "FFFAEE", 0.55 }, light = true },
}
T.ACCENT = { journey = "C08A2E", leader = "9A2A3A" }

-- Fixed colours of the frame, header and toasts (the same in every theme).
T.FIXED = {
  gold = "D8B060", goldText = "FFE6A8", chipText = "F3E3BE", dark = "120A04", shade = "0E0802", white = "FFFFFF",
  ribbon1 = "6E140C", ribbon2 = "A82A1C", badge = "B02A1C", studEdge = "2A1A08", muted = "C9B48A",
  bookEdge = "6A4A20", band1 = "6B3A1C", band2 = "3A1E0E", toastTop = "2A1C10", toastText = "E9DCC0", iconLight = "F6DE9A", iconDark = "6A4410",
}

-- Fonts: Friz Quadrata (WoW's own) everywhere. "book" is the font for prose on the pages; it can differ later.
T.FONT_TITLE = "Fonts\\FRIZQT__.TTF"
T.FONT_BODY = "Fonts\\FRIZQT__.TTF"
T.FONT_BOOK = "Fonts\\FRIZQT__.TTF"
-- "fancy": Morpheus, the Adventure Guide's font for titles on its dungeon pictures (29 Oct 2026). Forever has the
-- file too; UI.Text falls back to the title font on a client without it.
T.FONT_FANCY = "Fonts\\MORPHEUS.TTF"

-- How the game's parchment is tinted per theme (r, g, b multiplied with the picture), and how strongly the page
-- colour is laid over it (calms the picture so text stays easy to read).
T.PAPER_TINT = { journal = { 1, 1, 1 }, night = { 0.32, 0.36, 0.46 }, alliance = { 0.94, 0.96, 1 }, horde = { 1, 0.93, 0.88 } }
T.PAPER_WASH = 0.5

T.accent = T.ACCENT.journey
T.painters = {}

function T:Horde()
  if self.forceKey then return self.forceKey == "horde" end -- /jtf tour's Horde shots, on any character
  return UnitFactionGroup("player") == "Horde"
end

-- The setting "faction" becomes the alliance or horde theme.
function T:Key()
  if self.forceKey then return self.forceKey end -- /jtf tour shows the Horde theme on any character
  local key = ns.Settings:Get("theme")
  if key == "faction" then return self:Horde() and "horde" or "alliance" end
  return self.THEMES[key] and key or "journal"
end

function T:Current() return self.THEMES[self:Key()] end

-- A role, a fixed colour name or a hex string -> r, g, b, a
-- The status colours (done, behind, warning) are dark for parchment; on the Night theme's dark pages the same hex
-- was hard to read (the Overview counts; seen in the tour), so they are lifted there.
-- The dungeon roles' colours (Rules/Journey.lua ROLE_COLOR) too: Bridge in dark blue was hard to read (28 Oct 2026).
T.DARK_LIFT = { ["3E7A3A"] = "7FD08A", ["2E7A3E"] = "7FD08A", ["B0321E"] = "F07A64", ["B8742A"] = "E8A85A",
  ["2E6FA8"] = "7FB4E8", ["A8761E"] = "F0C860", ["2F6FAE"] = "8CC0F0", ["4F7F3F"] = "A8D090", ["963A0E"] = "F4C477" }

-- The colour a hex string is drawn in on this theme (for |cff colour codes in text).
function T:HexFor(hex)
  if self:Current().light then return hex end
  return self.DARK_LIFT[hex:upper()] or hex
end

function T:RGBA(role, alpha)
  local v
  if role == "accentText" and not self:Current().light then
    -- Text in the accent colour on the Night theme's dark pages: lifted halfway to white ("Leader" in dark green or
    -- red could hardly be read; 28 Oct 2026).
    local r, g, b = ns.Hex(self.accent)
    return r + (1 - r) * 0.5, g + (1 - g) * 0.5, b + (1 - b) * 0.5, alpha or 1
  end
  if role == "accent" or role == "accentText" then v = self.accent
  else
    v = self:Current()[role] or self.FIXED[role] or role
    if type(v) == "string" and not self:Current().light then v = self.DARK_LIFT[v:upper()] or v end
  end
  if type(v) == "table" then
    local r, g, b = ns.Hex(v[1])
    return r, g, b, alpha or v[2]
  end
  local r, g, b = ns.Hex(v)
  return r, g, b, alpha or 1
end

-- Painters run now and on every Apply().
function T:Register(fn)
  table.insert(self.painters, fn)
  fn(self)
end

function T:Apply()
  for _, fn in ipairs(self.painters) do fn(self) end
end

function T:SetAccent(hex)
  if hex == self.accent then return end
  self.accent = hex
  self:Apply()
end

function T:TextColor(fs, role, alpha)
  self:Register(function() fs:SetTextColor(self:RGBA(role, alpha)) end)
end

function T:Fill(tex, role, alpha)
  self:Register(function() tex:SetColorTexture(self:RGBA(role, alpha)) end)
end

function T:Backdrop(frame, bgRole, bgAlpha, borderRole, borderAlpha)
  self:Register(function()
    if bgRole then frame:SetBackdropColor(self:RGBA(bgRole, bgAlpha)) end
    if borderRole then frame:SetBackdropBorderColor(self:RGBA(borderRole, borderAlpha)) end
  end)
end

-- A texture that fades from one colour to another. c1 and c2 are { role, alpha }.
function T:Gradient(tex, orientation, c1, c2)
  self:Register(function() ns.UI.SetGradient(tex, orientation, { self:RGBA(c1[1], c1[2]) }, { self:RGBA(c2[1], c2[2]) }) end)
end

ns:On("SETTING", function(key) if key == "theme" then T:Apply() end end)
