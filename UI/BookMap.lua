-- The map in the book (U267, SPEC §4.6, the owner, 19 Nov 2026: "A map inside the addon with button to go to ingame map
-- and set a tracker"): a zone drawn from the game's own map art, as wide as the page with a thin gold edge, our marks
-- on it (QuestLists:Marks' list, numbered as the book numbers steps) and each Adventurer on the quest as their class
-- circle on their live spot (ns.Spots), you too. Under it Open the game's map and Set waypoint, and one line for who is
-- elsewhere. Where the game gives no art for the zone there is no map (Fill returns 0).
local _, ns = ...
local L = ns.L
local UI, Theme = ns.UI, ns.Theme
local BM = {}
ns.BookMap = BM

local MARK, FACE, FOOT = 22, 18, 30

-- The art of map: its first layer ({ layerWidth, layerHeight, tileWidth, tileHeight }) and its tiles' files, or nil.
function BM.Art(map)
  if not (map and C_Map and C_Map.GetMapArtLayers and C_Map.GetMapArtLayerTextures) then return nil end
  local ok, layers = pcall(C_Map.GetMapArtLayers, map)
  local l = ok and type(layers) == "table" and layers[1]
  if not l or (l.layerWidth or 0) <= 0 or (l.tileWidth or 0) <= 0 or (l.tileHeight or 0) <= 0 then return nil end
  local ok2, files = pcall(C_Map.GetMapArtLayerTextures, map, 1)
  if not ok2 or type(files) ~= "table" or #files == 0 then return nil end
  return l, files
end

-- Who is not on the map: "Elsewhere: Brannic, Darkshore · Mira, offline" (you left out), or "". Someone online in the
-- map's zone without a spot (an addon too old to answer, or no answer yet) is left out: they are not elsewhere.
function BM.Elsewhere(f, names, map)
  local out, Hr = {}, ns.Hero
  local info = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(map)
  local here = info and type(info.name) == "string" and not ns.Secret(info.name) and info.name:lower()
  for _, name in ipairs(names) do
    local h = f.heroes and f.heroes[name]
    local zone = h and type(h.zone) == "string" and h.zone ~= "" and not ns.Secret(h.zone) and h.zone
    if name ~= ns.Me() and not ns.Spots:Spot(name, map) then
      if not Hr:Online(f, name) then out[#out + 1] = L.MAP_ELSE_OFF:format(ns.Short(name))
      elseif not zone then out[#out + 1] = ns.Short(name)
      elseif zone:lower() ~= here then out[#out + 1] = L.MAP_ELSE_AT:format(ns.Short(name), zone) end
    end
  end
  return #out > 0 and L.MAP_ELSEWHERE:format(table.concat(out, "  ·  ")) or ""
end

local function markTip(m)
  local at = m.at
  if not at then return end
  GameTooltip:SetOwner(m, "ANCHOR_RIGHT")
  GameTooltip:SetText(m.card.o.title or "", 1, 0.82, 0)
  for _, it in ipairs(at.items) do
    if it.k then GameTooltip:AddLine(L.DQ_STEP:format(it.k, it.name), 1, 1, 1) end
  end
  if at.st.by or at.st.zone then GameTooltip:AddLine(ns.QuestLists.PlaceLine(at.st), 1, 1, 1) end
  GameTooltip:AddLine(L.MAP_BOOK_MARK_TIP, 0.85, 0.8, 0.7, true)
  GameTooltip:Show()
end

-- card = BM.New(parent, width); card:Fill(o) shows it and returns its height, or 0 (hidden) without art for o.map.
-- o = { map, title (the quest), marks (QuestLists:Marks; may be empty), who (names on the quest, you too), open (Open
-- the game's map; default: the marks, else the zone), target ({ st, map }: Set waypoint; nil greys it) }.
function BM.New(parent, width)
  local card = CreateFrame("Frame", nil, parent)
  card:SetWidth(width)
  card.view = CreateFrame("Frame", nil, card)
  card.view:SetPoint("TOPLEFT", 1, -1)
  if card.view.SetClipsChildren then card.view:SetClipsChildren(true) end
  card.edge = UI.Box(card, 1, nil, nil, "gold", 0.9)
  card.edge:SetPoint("TOPLEFT"); card.edge:SetPoint("BOTTOMRIGHT", card.view, "BOTTOMRIGHT", 1, -1)
  card.edge:SetFrameLevel(card.view:GetFrameLevel() + 6)
  card.edge:EnableMouse(false)
  card.tiles = UI.Pool(function() return card.view:CreateTexture(nil, "BACKGROUND") end)
  card.marks = UI.Pool(function()
    local m = CreateFrame("Button", nil, card.view)
    m:SetSize(MARK, MARK)
    m:SetFrameLevel(card.view:GetFrameLevel() + 2)
    m.card = card
    m.ring = m:CreateTexture(nil, "ARTWORK")
    m.ring:SetAllPoints(); m.ring:SetTexture(ns.MEDIA .. "MedallionRing")
    m.num = UI.Text(m, 11, nil, "title")
    m.num:SetFont(m.num:GetFont(), 11, "OUTLINE")
    m.num:SetTextColor(1, 1, 1)
    m.num:SetPoint("TOP", m, "BOTTOM", 0, 3)
    m:SetScript("OnEnter", markTip)
    m:SetScript("OnLeave", function() GameTooltip:Hide() end)
    m:SetScript("OnClick", function(self) GameTooltip:Hide(); ns.QuestLists:Waypoint(self.at.st, self.at.map) end)
    return m
  end)
  card.faces = UI.Pool(function()
    local b = UI.SpotFace(card.view, FACE)
    b:SetFrameLevel(card.view:GetFrameLevel() + 4)
    return b
  end)
  card.openMap = UI.TextButton(card, L.MAP_OPEN_GAME, function() card:Open() end, "plain", 12)
  card.waypoint = UI.TextButton(card, L.MAP_WAYPOINT, function()
    local t = card.o and card.o.target
    if t then ns.QuestLists:Waypoint(t.st, t.map) end
  end, "plain", 12)
  UI.Tooltip(card.waypoint, function() return not (card.o and card.o.target) and L.MAP_WAYPOINT_NONE or nil end)
  card.elsewhere = UI.Text(card, 11, "ink2")
  card.elsewhere:SetWordWrap(false)
  card.elsewhere:SetWidth(width)
  card:SetScript("OnHide", function() ns.Spots:Unwatch(card) end)

  -- Open the game's map: the caller's, else our marks on it, else its zone.
  function card:Open()
    local o = self.o
    if not o then return end
    if o.open then return o.open() end
    if #(o.marks or {}) > 0 and ns.MapMark:Show(o.marks, o.title) then return end
    if not InCombatLockdown() then ns.MapMark:Open(o.map) end
  end

  -- The Adventurers on their spots and who is elsewhere (each time the spots change).
  function card:Draw()
    local o, f = self.o, ns.Fellowship:Current()
    if not (o and f) then return end
    local n = 0
    for _, name in ipairs(o.who or {}) do
      local x, y = ns.Spots:Spot(name, o.map)
      if x then
        local b = self.faces:Get(n + 1)
        if not b then break end
        n = n + 1
        b:SetWho(f, name)
        b:ClearAllPoints(); b:SetPoint("CENTER", self.view, "TOPLEFT", x * self.w, -y * self.h)
        b:Show()
      end
    end
    self.faces:HideFrom(n + 1)
    self.elsewhere:SetText(BM.Elsewhere(f, o.who or {}, o.map))
  end

  function card:Fill(o)
    local layer, files = BM.Art(o.map)
    if not layer or (self.tiles.items[1] == nil and ns.Combat:InCombat()) then self:Hide() return 0 end
    self.o = o
    local s = (width - 2) / layer.layerWidth
    self.w, self.h = width - 2, math.floor(layer.layerHeight * s + 0.5)
    self.view:SetSize(self.w, self.h)
    local cols = math.ceil(layer.layerWidth / layer.tileWidth)
    local tw, th = layer.tileWidth * s, layer.tileHeight * s
    local n = 0
    for i, file in ipairs(files) do
      local t = self.tiles:Get(i)
      if not t then break end
      if t:SetTexture(file) == false then
        if i == 1 then self:Hide() return 0 end -- (no art in this client)
      end
      n = i
      t:SetSize(tw, th)
      t:ClearAllPoints(); t:SetPoint("TOPLEFT", self.view, "TOPLEFT", ((i - 1) % cols) * tw, -math.floor((i - 1) / cols) * th)
      t:Show()
    end
    self.tiles:HideFrom(n + 1)
    -- Our marks: the next one gold, the done ones faded.
    local nm = 0
    for _, at in ipairs(o.marks or {}) do
      if at.map == o.map then
        local m = self.marks:Get(nm + 1)
        if not m then break end
        nm = nm + 1
        m.at = at
        m.num:SetText(ns.MapMark.Label(at.items))
        m.ring:SetVertexColor(Theme:RGBA(at.next and "gold" or "FFFFFF"))
        m:SetAlpha(at.done and 0.5 or 1)
        m:ClearAllPoints(); m:SetPoint("CENTER", self.view, "TOPLEFT", at.st.x / 100 * self.w, -at.st.y / 100 * self.h)
        m:Show()
      end
    end
    self.marks:HideFrom(nm + 1)
    self.waypoint:SetEnabled(o.target ~= nil)
    self.openMap:ClearAllPoints(); self.openMap:SetPoint("TOPLEFT", self.view, "BOTTOMLEFT", -1, -7)
    self.waypoint:ClearAllPoints(); self.waypoint:SetPoint("LEFT", self.openMap, "RIGHT", 8, 0)
    self.elsewhere:ClearAllPoints(); self.elsewhere:SetPoint("TOPLEFT", self.openMap, "BOTTOMLEFT", 0, -6)
    self:Show()
    ns.Spots:Watch(o.map, o.who or {}, self)
    self:Draw()
    local h = self.h + 2 + FOOT + 6 + 14
    self:SetHeight(h)
    return h
  end

  ns:On("SPOTS", function() if card:IsVisible() then card:Draw() end end)
  return card
end
