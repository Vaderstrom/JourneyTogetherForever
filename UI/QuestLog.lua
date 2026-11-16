-- Journey marks in the game's quest log (U216, the owner, 15 Nov 2026: "tagg quests in the wow questlog that are
-- important to the journey"; picked "Quest log + tracker", "Dungeon quests" and "Milestone quests"): a small mark
-- before the title of each such quest in the game's quest log (on the map), and a line in its tooltip naming the
-- dungeon and chapter, or the goal. Hooks only: nothing of the game's quest log is replaced, no field is written on
-- its buttons (the marks live in our own tables), and nothing happens in combat. The game's quest tracker gets none:
-- a section of ours there tainted its quest item buttons in combat (2 Nov 2026).
local _, ns = ...
local L = ns.L
local UI = ns.UI
local QM = { marks = setmetatable({}, { __mode = "k" }), CACHE = 2 }
ns.QuestLogMarks = QM

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

-- shortcut: made again at most every CACHE seconds (the quest log redraws often while it is open); a quest done or
-- picked up shows at the next redraw after that.
function QM:Current()
  local f = ns.Fellowship:Current()
  if not f then return nil end
  local now = GetTime()
  if not self.map or self.mapFid ~= f.id or now - self.at > self.CACHE then
    self.map, self.mapFid, self.at = self:Map(f), f.id, now
  end
  return self.map
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

-- A button's quest ID, or nil (none, or a secret value).
local function questOf(b)
  local id = b.questID
  if issecretvalue and issecretvalue(id) then return nil end
  return type(id) == "number" and id or nil
end

-- The game's own tooltip for the quest, with our line under it.
local function onEnter(b)
  local id, map = questOf(b), QM.map
  local text = id and map and map[id]
  if text and GameTooltip:IsOwned(b) then
    GameTooltip:AddLine(text, 1, 0.82, 0, true)
    GameTooltip:Show()
  end
end

function QM:Update(sf)
  if InCombatLockdown() then return end -- (the marks come at the next redraw out of combat)
  local map = self:Current()
  for _, b in ipairs(self.Titles(sf or QuestScrollFrame)) do
    local id = questOf(b)
    local text = map and id and map[id]
    local mark = self.marks[b]
    if text and not mark then
      mark = b:CreateTexture(nil, "OVERLAY")
      mark:SetSize(14, 14)
      if b.Text then mark:SetPoint("RIGHT", b.Text, "LEFT", -2, 0) else mark:SetPoint("LEFT", b, "LEFT", 2, 0) end
      UI.SetIcon(mark, ns.ICONS.toast_dquest)
      self.marks[b] = mark
      b:HookScript("OnEnter", onEnter) -- (once per button: with its mark)
    end
    if mark then mark:SetShown(text and true or false) end
  end
end

-- What this game's quest log has (WoW Forever's may differ from retail's): for the check.
function QM:Probe()
  local sf = QuestScrollFrame
  return { update = type(QuestLogQuests_Update) == "function", list = sf ~= nil,
    pool = sf ~= nil and sf.titleFramePool ~= nil, hooked = self.installed == true }
end

-- The quest log may load after us: hooked once it is there.
local function hook()
  if QM.installed or type(QuestLogQuests_Update) ~= "function" then return end
  QM.installed = true
  hooksecurefunc("QuestLogQuests_Update", function() QM:Update() end)
end
ns:On("LOGIN", hook)
ns:RegisterEvent("ADDON_LOADED", hook)
