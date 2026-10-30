-- The list of characters on the account (the mockup's myChars), used on the Welcome page and in the
-- "Your characters" panel. Clicking a character in another fellowship shows its summary below the list.
local _, ns = ...
local L = ns.L
local UI, Theme = ns.UI, ns.Theme

-- parent: frame to fill; width: content width. Returns an object with :Refresh() -> height.
function UI.CharacterList(parent, width)
  local list = { selected = nil }
  list.rows = UI.Pool(function()
    local b = UI.Card(parent, "line", "Button")
    b:SetSize(width, 58)
    b.crest = UI.Crest(b, 24, 30)
    b.crest:SetPoint("LEFT", 8, 0)
    -- Without a fellowship: the class crest, so no row has an empty gap (seen in the tour).
    b.classCrest = UI.ClassCrest(b, 30)
    b.classCrest:SetPoint("LEFT", 5, 0)
    b.name = UI.Text(b, 14, nil, "body")
    b.name:SetPoint("TOPLEFT", 42, -7)
    b.line = UI.Text(b, 12, "ink2", "body")
    b.line:SetPoint("LEFT", b.name, "RIGHT", 6, 0)
    b.fname = UI.Text(b, 12, "ink", "body")
    b.fname:SetPoint("TOPLEFT", b.name, "BOTTOMLEFT", 0, -3)
    b.sub = UI.Text(b, 11, "ink2", "body")
    b.sub:SetPoint("TOPLEFT", b.fname, "BOTTOMLEFT", 0, -2)
    b.sub:SetWidth(width - 50)
    return b
  end)
  -- Summary of another character's fellowship.
  local box = UI.Card(parent)
  box:SetWidth(width)
  box.edge = UI.Solid(box, "ARTWORK", "accent")
  box.edge:SetPoint("TOPLEFT"); box.edge:SetPoint("BOTTOMLEFT"); box.edge:SetWidth(4)
  box.lines = {}
  for i, spec in ipairs({ { 15, "ink", "title" }, { 12, "ink2" }, { 13, "ink" }, { 12, "ink2" }, { 12, "ink2", "book" } }) do
    local fs = UI.WrapText(box, spec[1], spec[2], width - 24, spec[3])
    box.lines[i] = fs
  end
  -- Follow it: the book shows that fellowship, live and read-only (Fellowship/Watch.lua).
  box.watch = UI.TextButton(box, L.WATCH_OPEN, function()
    if list.selected then ns.Window:HidePanels(); ns.Watch:Open(list.selected) end
  end, "primary", 13)
  -- Take its place: play this character in that fellowship instead (Fellowship:TakePlace), after a question.
  box.take = UI.TextButton(box, "", function()
    local key, s = list.selected, list.selected and ns.Characters:Summary(list.selected)
    if not s or not s.canTake then return end
    local me = ns.Short(ns.Me())
    ns.Window:Confirm(L.TAKE_CONFIRM:format(me, s.fname, s.short, s.short, me), L.TAKE_OK, function()
      ns.Window:HidePanels()
      ns.Fellowship:TakePlace(key)
    end)
  end, "plain", 13)
  box.note = UI.WrapText(box, 12, "ink2", width - 24)
  local hint = UI.WrapText(parent, 12, "ink2", width)
  hint:SetText(L.ALT_HINT)

  function list:Refresh()
    local stack = UI.Stack(parent)
    local keys = ns.Characters:List()
    local light = Theme:Current().light
    local shown = 0
    for i, key in ipairs(keys) do
      local b = self.rows:Get(i)
      if not b then break end
      local row = ns.Characters:Row(key)
      shown = i
      b.name:SetText(row.name)
      local hex = ns.ClassHex(row.class, light)
      if hex then b.name:SetTextColor(ns.Hex(hex)) else b.name:SetTextColor(Theme:RGBA("ink")) end
      b.line:SetText(row.line)
      b.fname:SetText(row.fname)
      b.sub:SetText(row.sub)
      b.crest:SetShown(row.fellowship ~= nil)
      if row.fellowship then b.crest:Set(row.color, row.emblem) end
      b.classCrest:SetShown(row.fellowship == nil)
      b.classCrest:Set(row.class)
      b:SetSelected(self.selected == key)
      b:SetEnabled(row.canView)
      b:SetScript("OnClick", function() list.selected = key; list:Refresh() end)
      stack:Place(b, 58, 4)
    end
    self.rows:HideFrom(shown + 1)
    local s = self.selected and ns.Characters:Summary(self.selected)
    box:SetShown(s ~= nil)
    hint:SetShown(s == nil)
    stack:Skip(6)
    if s then
      local texts = { s.name, s.owner, s.chapter, s.levels, s.seen }
      local h = 10
      for i, fs in ipairs(box.lines) do
        fs:SetText(texts[i])
        fs:ClearAllPoints(); fs:SetPoint("TOPLEFT", 14, -h)
        h = h + fs:GetStringHeight() + 3
      end
      box.watch:SetShown(s.canWatch == true)
      box.take:SetShown(s.canTake)
      if s.canWatch then
        box.watch:ClearAllPoints(); box.watch:SetPoint("TOPLEFT", 14, -(h + 6))
        if s.canTake then
          box.take:SetLabel(L.TAKE_OPEN:format(s.short))
          box.take:ClearAllPoints(); box.take:SetPoint("LEFT", box.watch, "RIGHT", 8, 0)
          -- Two buttons side by side when they fit, else under each other.
          if box.watch:GetWidth() + box.take:GetWidth() + 36 > width then
            box.take:ClearAllPoints(); box.take:SetPoint("TOPLEFT", box.watch, "BOTTOMLEFT", 0, -6)
            h = h + 34
          end
        end
        h = h + 40
      end
      box.note:SetShown(s.takeNote ~= nil)
      if s.takeNote then
        box.note:SetText(s.takeNote)
        box.note:ClearAllPoints(); box.note:SetPoint("TOPLEFT", 14, -h)
        h = h + box.note:GetStringHeight() + 6
      end
      box:SetHeight(h + 8)
      stack:Place(box, h + 8, 0)
    else
      stack:Place(hint, hint:GetStringHeight(), 0)
    end
    return stack.y
  end
  return list
end
