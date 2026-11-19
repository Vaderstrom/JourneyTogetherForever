-- Journey marks in the game's quest log (U216, the owner, 15 Nov 2026: "tagg quests in the wow questlog that are
-- important to the journey"; picked "Quest log + tracker", "Dungeon quests" and "Milestone quests"): a small mark
-- before the title of each such quest in the game's quest log (on the map), and a line in its tooltip naming the
-- dungeon and chapter, or the goal. Hooks only: nothing of the game's quest log is replaced, no field is written on
-- its buttons (the marks live in our own tables), and nothing happens in combat. The game's quest tracker gets none:
-- a section of ours there tainted its quest item buttons in combat (2 Nov 2026).
-- Together in the game's quest log (U268; U270, the owner after the check of 19 Nov 2026: "make it clearer in the
-- ingame questlog ... the group up etc is blocking the view"): a quest you share gets a Journey Together section in its
-- text, under the description (who has it, each one's step and whether online, the answer, Ask to group up); the
-- game's world map shows the Adventurers on that quest on their live spots (ns.Spots). In the quest list, a small crest
-- after the title of each such quest (U271, the owner after the check of 19 Nov 2026, 19:33).
-- The crest on the map's top right corner, beside Overlord's round button and drawn like it (U271): a click opens the
-- game's own menu with Chapter and Quests; a click on one opens the book there, above the map, which stays open
-- (closing it from our code calls the game's HideUIPanel, a taint risk; the owner, 20 Nov 2026).
-- The setting In the game's quest log and map (questLog, on) turns all of it off, the journey marks too.
local _, ns = ...
local L = ns.L
local UI = ns.UI
local weak = { __mode = "k" }
local QM = { marks = setmetatable({}, weak), crests = setmetatable({}, weak), hooked = setmetatable({}, weak), pins = {},
  CACHE = 2 }
ns.QuestLogMarks = QM

local function on() return ns.Settings:Get("questLog") ~= false end

-- questID -> its tooltip line: your dungeon quests of the journey and their chain steps (the dungeon quest log's,
-- U213), and the journey's quest milestones you have not done.
function QM:Map(f)
  local QL, J, M, me = ns.QuestLists, ns.Journey, ns.Milestones, ns.Me()
  local out = {}
  local log = QL:Log(f, me)
  for _, list in ipairs({ log.under, log.open }) do
    for _, r in ipairs(list) do
      local d = ns.Dungeon(r.key)
      local text = L.QLOG_DUNGEON:format(d and d[2] or r.key, L.CHAPTER_ROMAN:format(J.Roman(r.n)))
      out[r.q.id] = out[r.q.id] or text
      for _, s in ipairs(r.q.steps or {}) do if s.id then out[s.id] = out[s.id] or text end end
    end
  end
  for n, ch in ipairs(f.journey.chapters) do
    for _, m in ipairs(ch.milestones or {}) do
      if m.kind == "quest" and not M:HeroDone(f, m, me) then
        out[m.value] = L.QLOG_GOAL:format(m.name, L.CHAPTER_ROMAN:format(J.Roman(n)))
      end
    end
  end
  return out
end

-- questID -> the Together item for it (U268): a quest in my log, or the step of a chain I am on, that another
-- Adventurer has or could join.
function QM:Together(f)
  local me, out = ns.Me(), {}
  for _, x in ipairs(ns.Quests:Items(f)) do
    if x.mine and (#x.others > 0 or #(x.joiners or {}) > 0) then
      local id = x.chain and x.ids[math.min((x.at[me] or 0) + 1, #x.ids)] or ns.Quests.QuestID(x)
      if id then out[id] = x end
    end
  end
  return out
end

-- The lines of a quest's Journey Together section: who has it, with their step or count and whether online
-- ("Brannic · step 1 of 2 · online, Teldrassil"), then who could join you. { { name, text, faded } }
function QM.Rows(f, x)
  local Hr, out = ns.Hero, {}
  for _, name in ipairs(x.others) do
    local done
    if x.chain then
      local v, n = x.at[name] or 0, #x.steps
      done = v >= n and L.QLOG_FINISHED or L.QLOG_STEP:format(v + 1, n)
    else
      done = L.QLOG_HAVE:format(x.have[name] or 0, x.goal or 0)
    end
    local seen
    if Hr:Online(f, name) then
      local h = f.heroes and f.heroes[name]
      local at = h and type(h.zone) == "string" and h.zone ~= "" and not (issecretvalue and issecretvalue(h.zone)) and h.zone
      seen = at and L.QLOG_ONLINE_AT:format(at) or L.QLOG_ONLINE
    else
      seen = L.QLOG_SEEN:format(ns.TimeAgo(Hr:LastSeen(f, name)))
    end
    out[#out + 1] = { name = name, text = L.QLOG_ROW:format(ns.Short(name), done, seen) }
  end
  for _, name in ipairs(x.joiners or {}) do
    out[#out + 1] = { name = name, text = L.QLOG_COULD:format(ns.Short(name)), faded = true }
  end
  return out
end

-- shortcut: made again at most every CACHE seconds (the quest log redraws often while it is open); a quest done or
-- picked up shows at the next redraw after that.
function QM:Current()
  local f = ns.Fellowship:Current()
  if not f or not on() then return nil end
  local now = GetTime()
  if not self.map or self.mapFid ~= f.id or now - self.at > self.CACHE then
    self.map, self.together, self.mapFid, self.at = self:Map(f), self:Together(f), f.id, now
  end
  return self.map, self.together
end

-- The quest log's title buttons: the game's pool of them when it has one, else the list's children.
function QM.Titles(sf)
  local pool = sf and sf.titleFramePool
  local list = {}
  if pool and pool.EnumerateActive then
    for b in pool:EnumerateActive() do list[#list + 1] = b end
  elseif sf and sf.Contents and sf.Contents.GetChildren then
    list = { sf.Contents:GetChildren() }
  end
  return list
end

-- A quest ID, or nil (none, or a secret value).
local function plainID(id)
  if issecretvalue and issecretvalue(id) then return nil end
  return type(id) == "number" and id or nil
end
local function questOf(b) return plainID(b.questID) end

-- The game's own tooltip for the quest, with our line under it.
local function onEnter(b)
  local id = questOf(b)
  if not id or not on() or not GameTooltip:IsOwned(b) then return end
  local text = QM.map and QM.map[id]
  if text then GameTooltip:AddLine(text, 1, 0.82, 0, true); GameTooltip:Show() end
end

-- The small crest after a shared quest's title (U271): at the end of its first line, after the game's check mark
-- when the quest is tracked.
function QM:TitleCrest(b, f)
  local c = self.crests[b]
  if not c then
    c = UI.Crest(b, 16, 16)
    c:EnableMouse(false)
    self.crests[b] = c
  end
  c:Set(f.color, f.emblem)
  c:ClearAllPoints()
  local t, check = b.Text, b.Check
  if type(check) == "table" and check:IsShown() then
    c:SetPoint("LEFT", check, "RIGHT", 2, 0)
  elseif t then
    local w = math.min(t:GetStringWidth() or 0, t:GetWidth() or 0)
    c:SetPoint("LEFT", t, "TOPLEFT", w + 4, -7)
  else
    c:SetPoint("RIGHT", b, "RIGHT", -24, 0)
  end
  c:Show()
end

function QM:Update(sf)
  if InCombatLockdown() then return end -- (the marks come at the next redraw out of combat)
  local map, together = self:Current()
  local f = together and ns.Fellowship:Current()
  for _, b in ipairs(self.Titles(sf or QuestScrollFrame)) do
    local id = questOf(b)
    if f and id and together[id] then self:TitleCrest(b, f) elseif self.crests[b] then self.crests[b]:Hide() end
    local text = map and id and map[id]
    if text and not self.hooked[b] then
      self.hooked[b] = true
      b:HookScript("OnEnter", onEnter) -- (once per button)
    end
    local mark = self.marks[b]
    if text and not mark then
      mark = b:CreateTexture(nil, "OVERLAY")
      mark:SetSize(14, 14)
      if b.Text then mark:SetPoint("RIGHT", b.Text, "LEFT", -2, 0) else mark:SetPoint("LEFT", b, "LEFT", 2, 0) end
      UI.SetIcon(mark, ns.ICONS.toast_dquest)
      self.marks[b] = mark
    end
    if mark then mark:SetShown(text and true or false) end
  end
end

---------------------------------------------------------------------------
-- The card beside a quest's details, and the Adventurers on the world map (U268)
---------------------------------------------------------------------------
-- Opens the book at a page, and at its tab and a row there, above the world map, which stays open (the owner, 20 Nov
-- 2026: closing it from our code calls the game's panel manager, HideUIPanel, a taint risk). The book is the player's
-- again, not aside for the map (MapMark.lua): closing the map later does not bring it back.
function QM:OpenBook(page, tab, sel)
  ns.MapMark.book = nil
  local W = ns.Window
  W:WhenBuilt(function()
    W:Open(page)
    local pf = W.pageFrames[page]
    if pf and tab then pf.tab, pf.sel = tab, sel; W:Refresh() end
  end)
end

-- The game's quest text in the map's details: the frame its description is in, and the lowest of its texts (the seal
-- when it shows, else the description). Not the game's spacer under them: in WoW Forever it keeps the room behind the
-- rewards box at the details' foot, and the section sat hidden there (the check of 19 Nov 2026, 19:33). nil when the
-- description is elsewhere (the game moves the same texts to a quest giver's window).
function QM.QuestText()
  local desc = QuestInfoDescriptionText
  local details = QuestMapFrame and QuestMapFrame.DetailsFrame
  local p = desc and details and desc:GetParent()
  local up, n = p, 0
  while up and up ~= details and n < 6 do up, n = up:GetParent(), n + 1 end
  if not p or up ~= details then return nil end
  local seal = QuestInfoSealFrame
  if seal and seal:IsShown() and seal:GetParent() == p then return p, seal end
  return p, desc
end

-- In the game's style: the font and colour of one of its quest texts.
local function gameFont(fs, from, fallback)
  fs:SetFontObject(from and from:GetFontObject() or fallback)
  if from then fs:SetTextColor(from:GetTextColor()) end
end

-- Our section, made once out of combat, in the quest text's frame (a frame of ours in it; nothing of the game's moves).
-- shortcut: the game sizes its quest text's scroll by its own texts; under a long description the section can sit past
-- the end of the scroll (the self-test records it as questLogSection). Upgrade if that shows in play. (The rewards have
-- their own box at the foot of the details in WoW Forever, the check of 19 Nov 2026: the section never meets them.)
function QM:Section(p)
  local s = self.section
  if not s then
    if ns.Combat:InCombat() then return nil end -- (drawn when the fight ends, below)
    s = CreateFrame("Frame", nil, p)
    s.head = s:CreateFontString(nil, "ARTWORK")
    s.head:SetPoint("TOPLEFT")
    s.rows = UI.Pool(function()
      local r = CreateFrame("Frame", nil, s)
      r.icon = UI.Round(r, "ARTWORK", 14)
      r.icon:SetPoint("TOPLEFT", 0, -1)
      r.text = r:CreateFontString(nil, "ARTWORK")
      r.text:SetPoint("TOPLEFT", 18, 0)
      r.text:SetJustifyH("LEFT")
      return r
    end)
    s.tips = UI.Pool(function() local t = s:CreateFontString(nil, "ARTWORK"); t:SetJustifyH("LEFT"); return t end)
    s.ask = UI.TextButton(s, L.ASK_GROUP, function() if QM.shownQuest then ns.Quests:AskGroup(QM.shownQuest) end end, "primary", 12)
    self.section = s
  end
  if s:GetParent() ~= p then s:SetParent(p) end
  return s
end

-- Under the description: Journey Together, a line for each Adventurer on the quest, then the answer (§4.6).
function QM:ShowSection(x)
  local p, last = self.QuestText()
  local s = x and p and self:Section(p)
  if not s then if self.section then self.section:Hide() end return end
  local f, desc = ns.Fellowship:Current(), QuestInfoDescriptionText
  local w = math.max(desc:GetWidth() or 0, 200)
  gameFont(s.head, QuestInfoDescriptionHeader, "QuestTitleFont")
  s.head:SetText(L.QLOG_CARD)
  local y, n = s.head:GetStringHeight() + 6, 0
  for i, row in ipairs(self.Rows(f, x)) do
    local r = s.rows:Get(i)
    if not r then break end
    n = i
    gameFont(r.text, desc, "QuestFont")
    r.text:SetWidth(w - 18)
    r.text:SetText(row.text)
    local e = ns.Quests:Face(f, row.name, x.zone, row.faded)
    if not ns.SetClassIcon(r.icon, e.class) then UI.SetIcon(r.icon, ns.ICONS.heroes) end
    r.icon:SetDesaturated(e.faded or not e.online)
    r:SetAlpha(e.faded and 0.6 or 1)
    local h = math.max(r.text:GetStringHeight(), 14)
    r:SetSize(w, h)
    r:ClearAllPoints(); r:SetPoint("TOPLEFT", 0, -y)
    r:Show()
    y = y + h + 3
  end
  s.rows:HideFrom(n + 1)
  n, y = 0, y + 3
  for i, text in ipairs(ns.Quests:Detail(x).tips) do
    local t = s.tips:Get(i)
    if not t then break end
    n = i
    gameFont(t, desc, "QuestFont")
    t:SetWidth(w)
    t:SetText(text)
    t:ClearAllPoints(); t:SetPoint("TOPLEFT", 0, -y)
    t:Show()
    y = y + t:GetStringHeight() + 3
  end
  s.tips:HideFrom(n + 1)
  -- Ask to group up under them while someone can be asked (U271: out of the crest's menu).
  local ask = #ns.Quests.AskList(x) > 0
  s.ask:SetShown(ask)
  if ask then
    s.ask:ClearAllPoints(); s.ask:SetPoint("TOPLEFT", 0, -(y + 3))
    y = y + 3 + s.ask:GetHeight()
  end
  s:SetSize(w, y)
  s:ClearAllPoints(); s:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, -15)
  s:Show()
end

-- A quest's details show (the game's QuestMapFrame_ShowQuestDetails): its section when you share it, and the
-- Adventurers on the map.
function QM:ShowQuest(questID)
  local _, together = self:Current()
  local x = together and together[plainID(questID) or 0]
  if not x then return self:HideQuest() end
  self.shownQuest = x
  self:ShowSection(x)
  self:PlaceFaces()
end

function QM:HideQuest()
  if self.section then self.section:Hide() end
  self.shownQuest = nil
  self:PlaceFaces()
end

-- The crest on the map's top right corner (U271, the owner: "so it sits next to overlord"): a round button drawn like the
-- game's minimap buttons (and Overlord's), the fellowship's crest in it.
function QM:Crest()
  if self.crest or InCombatLockdown() or not WorldMapFrame then return self.crest end
  local b = CreateFrame("Button", nil, WorldMapFrame)
  b:SetSize(32, 32)
  b:SetScale(1.3) -- (Overlord's size on the map)
  -- Over the map's pins, our marks (9000, MapMark.lua) and faces (9001). No higher: the game's menu sits 501 above its
  -- owner and its words 20 above that, and frame levels stop at 10000; at 9500 the words were drawn under the menu's own
  -- background (the check of 19 Nov 2026 22:39).
  b:SetFrameLevel(9100)
  b:RegisterForClicks("LeftButtonUp")
  local bg = b:CreateTexture(nil, "BACKGROUND")
  bg:SetSize(20, 20); bg:SetPoint("TOPLEFT", 7, -5)
  bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
  b.crest = UI.Crest(b, 20, 20)
  b.crest:SetPoint("CENTER", bg, "CENTER")
  b.crest:EnableMouse(false)
  local ring = CreateFrame("Frame", nil, b) -- (above the crest's own layers)
  ring:SetAllPoints()
  ring:SetFrameLevel(b.crest:GetFrameLevel() + 5)
  local border = ring:CreateTexture(nil, "OVERLAY")
  border:SetSize(53, 53); border:SetPoint("TOPLEFT")
  border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
  b:SetScript("OnClick", function() QM:OpenMenu(b) end)
  UI.Tooltip(b, L.QLOG_CREST_TIP)
  self.crest = b
  return b
end

-- The menu's shortcuts, { label, open }: the pages in your sidebar. Quests opens at the quest whose details show
-- when you share it.
function QM:MenuItems()
  local ctx, out = ns.Pages:Context(), {}
  if not ctx.inFellow then return out end
  if ns.Pages:InNav("chapter", ctx) then out[#out + 1] = { L.NAV_CHAPTER, function() QM:OpenBook("chapter") end } end
  if ns.Pages:InNav("quests", ctx) then
    out[#out + 1] = { L.NAV_QUESTS, function()
      local x = QM.shownQuest
      QM:OpenBook("quests", "quests", x and x.id)
    end }
  end
  return out
end

-- The game's own menu (the map's Filter menu draws the same); without it the first shortcut opens.
function QM:OpenMenu(b)
  local items = self:MenuItems()
  if not (MenuUtil and MenuUtil.CreateContextMenu) then
    if items[1] then items[1][2]() end
    return
  end
  MenuUtil.CreateContextMenu(b, function(_, root)
    root:CreateTitle(L.QLOG_CARD)
    for _, it in ipairs(items) do root:CreateButton(it[1], it[2]) end
  end)
end

-- Shown with the map while you are in a fellowship (on your own too): left of Overlord's round button while it sits on
-- the corner, else on the corner itself.
function QM:ShowCrest()
  local b = self:Crest()
  if not b then return end
  local f = on() and ns.Fellowship:Current()
  b:SetShown(f and true or false)
  if not f then return end
  b.crest:Set(f.color, f.emblem)
  local area = WorldMapFrame.ScrollContainer or WorldMapFrame
  -- shortcut: Overlord's own field for its button (Overlord 2.6.0); another version without it puts ours on the corner.
  local ov = type(Overlord) == "table" and type(Overlord.MapMarkers) == "table" and Overlord.MapMarkers._mapModeButton
  b:ClearAllPoints()
  if type(ov) == "table" and ov.IsShown and ov:IsShown() and not ov._olMoved then
    b:SetPoint("TOPRIGHT", ov, "TOPLEFT", -2, 0)
  else
    b:SetPoint("TOPRIGHT", area, "TOPRIGHT", -5, -5)
  end
end

-- A face on the world map's canvas: the Adventurer's class circle, named on pointing.
function QM:Pin(c)
  local b = UI.SpotFace(c, 22)
  b:SetFrameLevel(9001)
  -- (The map zoomed or was resized: placed again, as our marks are.)
  b:SetScript("OnUpdate", function(pin)
    local cv = ns.MapMark.Canvas()
    if cv and (ns.MapMark.Zoom() ~= pin.z or cv:GetWidth() ~= pin.w) then QM:PlaceFaces() end
  end)
  return b
end

-- The Adventurers on the quest whose details show, on the shown map at their live spots (asked while it shows).
function QM:PlaceFaces()
  local x, MM = self.shownQuest, ns.MapMark
  local c = x and on() and WorldMapFrame and WorldMapFrame:IsShown() and MM.Canvas()
  local map = c and MM.ShownMap()
  local who = {}
  if map then for name in pairs(x.chain and x.at or x.have) do who[#who + 1] = name end end
  table.sort(who)
  -- shortcut: one watch at a time (ns.Spots); with the book open over the map, the book's map keeps it, and this one
  -- takes it back when the book closes (Unwatch fires SPOTS).
  if #who > 0 and not ns.Window:IsOpen() then ns.Spots:Watch(map, who, "worldmap")
  elseif #who == 0 then ns.Spots:Unwatch("worldmap") end
  local f, n, z = ns.Fellowship:Current(), 0, map and MM.Zoom() or 1
  for _, name in ipairs(f and who or {}) do
    local sx, sy = ns.Spots:Spot(name, map)
    local b = sx and (self.pins[n + 1] or (not InCombatLockdown() and self:Pin(c)))
    if b then
      n = n + 1
      self.pins[n] = b
      b:SetWho(f, name)
      b:SetScale(1 / z)
      b:ClearAllPoints(); b:SetPoint("CENTER", c, "TOPLEFT", c:GetWidth() * sx * z, -c:GetHeight() * sy * z)
      b.z, b.w = z, c:GetWidth()
      b:Show()
    end
  end
  for i = n + 1, #self.pins do self.pins[i]:Hide() end
end

-- What this game's quest log has (WoW Forever's may differ from retail's): for the check.
function QM:Probe()
  local sf = QuestScrollFrame
  return { update = type(QuestLogQuests_Update) == "function", list = sf ~= nil,
    pool = sf ~= nil and sf.titleFramePool ~= nil, hooked = self.installed == true,
    details = type(QuestMapFrame_ShowQuestDetails) == "function", text = QuestInfoDescriptionText ~= nil,
    display = type(QuestInfo_Display) == "function", menu = MenuUtil ~= nil and MenuUtil.CreateContextMenu ~= nil }
end

-- The quest log may load after us: hooked once it is there.
local function hook()
  if QM.installed or type(QuestLogQuests_Update) ~= "function" then return end
  QM.installed = true
  hooksecurefunc("QuestLogQuests_Update", function() QM:Update() end)
  if type(QuestMapFrame_ShowQuestDetails) == "function" then
    hooksecurefunc("QuestMapFrame_ShowQuestDetails", function(id) QM:ShowQuest(id) end)
  end
  -- The game moves the same quest texts to a quest giver's window: our section stays with the map's (the map's
  -- rewards, drawn by the same function, leave the description where it is).
  if type(QuestInfo_Display) == "function" then
    hooksecurefunc("QuestInfo_Display", function()
      if QM.section and not QM.QuestText() then QM.section:Hide() end
    end)
  end
  local details = QuestMapFrame and QuestMapFrame.DetailsFrame
  if details then details:HookScript("OnHide", function() QM:HideQuest() end) end
  if WorldMapFrame then
    WorldMapFrame:HookScript("OnHide", function() QM:HideQuest() end)
    pcall(hooksecurefunc, WorldMapFrame, "OnMapChanged", function() QM:PlaceFaces() end)
    -- (Overlord may show its button in its own OnShow, after ours: placed again once every OnShow has run.)
    WorldMapFrame:HookScript("OnShow", function() QM:ShowCrest(); C_Timer.After(0, function() QM:ShowCrest() end) end)
  end
  QM:ShowCrest()
end
ns:On("LOGIN", hook)
ns:RegisterEvent("ADDON_LOADED", hook)
ns:On("SPOTS", function() if QM.shownQuest then QM:PlaceFaces() end end)
-- The fight over: all of it drawn again, as nothing is made in combat (CLAUDE.md): the titles' crests, the map's crest,
-- the section's lines and the faces (the release review of 20 Nov 2026: a quest first opened in combat stayed bare).
ns:On("COMBAT", function(inCombat)
  if inCombat or not QM.installed then return end
  QM:Update(); QM:ShowCrest()
  if QM.shownQuest then QM:ShowSection(QM.shownQuest); QM:PlaceFaces() end
end)
-- The setting: off, the quest log and map are the game's own again at once.
ns:On("SETTING", function(key)
  if key ~= "questLog" then return end
  QM.map, QM.together = nil, nil
  QM:Update()
  if not on() then QM:HideQuest() end
  QM:ShowCrest()
end)
