-- Journey Admin (SPEC §4.11): the Leader edits the chapters and dungeons, with the journey editor (UI/JourneyEditor.lua,
-- the same as in Create a Fellowship's "Your own journey"; 28 Oct 2026) and each chapter's milestones.
-- Every edit goes into a draft; Heroes keep seeing the published journey until Publish. Discard throws it away.
-- Export shows the journey as a string to copy; Import (in the editor) reads one into the draft.
local _, ns = ...
local L = ns.L
local UI = ns.UI
local F, JE = ns.Fellowship, ns.JourneyEdit

local A = { sel = 1 }
ns.AdminDraft = A

-- The draft belongs to one fellowship: in another one (a new fellowship, the walkthrough's sample, the lab) it is
-- dropped. (A draft left from an earlier fellowship was edited instead; seen in the check, 28 Oct 2026.)
function A:Own(f)
  if self.jd and (not f or self.fid ~= f.id) then self.jd, self.fid, self.sel = nil, nil, 1 end
end

function A:Journey(f) self:Own(f); return self.jd or f.journey end

-- Changes the draft (made from the published journey the first time). quiet: no redraw (typing a name).
function A:Edit(f, fn, quiet)
  self:Own(f)
  if not self.jd then self.jd, self.fid = JE.Copy(f.journey), f.id end
  fn(self.jd)
  if not quiet then ns.Window:Refresh() end
end

-- Number of changes against the published journey (as the mockup counts them).
function A:Changes(f)
  self:Own(f)
  if not self.jd then return 0 end
  local S = ns.Serialize
  local n = S.Encode(self.jd.chapters) ~= S.Encode(f.journey.chapters) and 1 or 0
  local keys = {}
  for k in pairs(self.jd.place) do keys[k] = true end
  for k in pairs(f.journey.place) do keys[k] = true end
  for k in pairs(keys) do if S.Encode(self.jd.place[k]) ~= S.Encode(f.journey.place[k]) then n = n + 1 end end
  return n
end

function A:Publish(f)
  self:Own(f)
  if not self.jd then return false end
  -- Never silently: a journey that cannot be published says so (a 60-60 chapter did nothing; seen in game).
  if not F:PublishJourney(self.jd) then
    ns:Toast(nil, L.JOURNEY_NOT_PUBLISHED, L.JOURNEY_NOT_PUBLISHED_TEXT)
    return false
  end
  self.jd = nil
  ns:Toast(nil, L.JOURNEY_PUBLISHED, L.JOURNEY_PUBLISHED_TEXT)
  ns.Window:Refresh()
  return f ~= nil
end

function A:Discard() self.jd = nil; ns.Window:Refresh() end

-- Needed bosses of a dungeon in the draft: the leader's choice, or every boss.
function A:Needed(f, key)
  local p = self:Journey(f).place[key]
  return p and p.bosses or ns.Clears:DefaultNeeded(key)
end

function A:PickBosses(f, key)
  local d = ns.Dungeon(key)
  if not f or not d then return end
  local list = ns.Clears:Bosses(key)
  if #list == 0 then return end
  local needed, items = self:Needed(f, key), {}
  for i, b in ipairs(list) do
    local on = false
    for _, tok in ipairs(needed) do if tok == b.tok then on = true end end
    items[i] = { text = b.name, on = on }
  end
  ns.Window:PickMany(L.ADMIN_BOSSES_TITLE:format(d[2]), items, function(ons)
    self:Edit(f, function(jd)
      local toks = {}
      for i, b in ipairs(list) do if ons[i] then toks[#toks + 1] = b.tok end end
      jd.place[key].bosses = toks
    end)
  end)
end

-- A chapter more: the chosen one split in two (chapters join up, so a new one takes part of a chapter's levels).
function A:AddChapter(f)
  self:Edit(f, function(d)
    local n = JE.Split(d, self.sel)
    if n then self.sel = n end
  end)
end

function A:RemoveChapter(f)
  if #self:Journey(f).chapters <= 1 then return end
  self:Edit(f, function(d)
    JE.RemoveChapter(d, self.sel)
    self.sel = math.max(1, self.sel - 1)
  end)
end

---------------------------------------------------------------------------
-- Milestones (Rules/Milestones.lua): add, Required / Optional, remove, all in the draft
---------------------------------------------------------------------------
local MS_KINDS = { { L.MS_KIND_QUEST, "quest" }, { L.MS_KIND_LEVEL, "level" }, { L.MS_KIND_ATTUNE, "attune" }, { L.MS_KIND_TICK, "tick" } }

function A:AddMilestone(f, m)
  local clean = ns.Milestones.Clean({ m })
  if not clean then return false end
  self:Edit(f, function(d)
    local ch = d.chapters[self.sel]
    ch.milestones = ch.milestones or {}
    table.insert(ch.milestones, clean[1])
  end)
  return true
end

function A:RemoveMilestone(f, id)
  self:Edit(f, function(d)
    local list = d.chapters[self.sel].milestones or {}
    for i = #list, 1, -1 do if list[i].id == id then table.remove(list, i) end end
  end)
end

function A:SetRequired(f, id, req)
  self:Edit(f, function(d)
    for _, m in ipairs(d.chapters[self.sel].milestones or {}) do if m.id == id then m.req = req end end
  end)
end

-- The form: kind, value (quest ID, level or attunement), name, Required or Optional; Add puts it in the draft.
function A:MilestoneForm(f)
  local W = ns.Window
  if not W.frame or ns.Combat:InCombat() then return end
  -- 540 wide: the four kinds in one row ("Ticked by hand" stood out of a 480 box; seen in game, 28 Oct 2026).
  local o = W:Overlay("milestone", 540, 360)
  if not o.kind then
    local box = o.box
    o.title:SetText(L.MS_FORM_TITLE)
    o.state = { kind = "quest", req = true, attune = "mc" }
    local y = -48
    local function label(text) local t = UI.Text(box, 13, "ink2"); t:SetPoint("TOPLEFT", 16, y - 4); t:SetText(text); return t end
    label(L.MS_KIND)
    o.kind = UI.Choice(box, MS_KINDS, function() return o.state.kind end, function(v) o.state.kind = v; A:FormRefresh(o) end)
    o.kind:SetPoint("TOPLEFT", 110, y)
    y = y - 40
    o.valueLabel = label("")
    o.value = UI.EditBox(box, 120, 6, "")
    o.value:SetPoint("TOPLEFT", 110, y)
    -- A quest: picked from your log and the others' shared ones (M25), or its ID typed in the box. Both work.
    o.pick = UI.Dropdown(box, 270, {}, function() return o.state.pick end, function(id)
      local auto = o.autoName
      o.state.pick = id
      o.value:SetText(tostring(id))
      for _, x in ipairs(o.quests or {}) do
        if x.id == id and (strtrim(o.name:GetText() or "") == "" or o.name:GetText() == auto) then
          o.name:SetText(x.name); o.autoName = x.name
        end
      end
    end)
    o.pick:SetPoint("TOPLEFT", 240, y)
    -- An ID typed by hand: the list no longer shows a pick.
    o.value.edit:HookScript("OnTextChanged", function(_, user)
      if user and o.state.pick then o.state.pick = nil; A:PickText(o) end
    end)
    o.attune = UI.Dropdown(box, 220, {}, function() return o.state.attune end, function(v) o.state.attune = v; A:FormRefresh(o) end)
    o.attune:SetPoint("TOPLEFT", 110, y)
    o.valueHint = UI.WrapText(box, 11, "ink2", 400)
    o.valueHint:SetPoint("TOPLEFT", 110, y - 30)
    y = y - 70
    label(L.MS_NAME)
    o.name = UI.EditBox(box, 340, 60, "")
    o.name:SetPoint("TOPLEFT", 110, y)
    y = y - 40
    o.req = UI.Choice(box, { { L.MS_REQUIRED, true }, { L.MS_OPTIONAL, false } }, function() return o.state.req end,
      function(v) o.state.req = v; o.req:Refresh() end)
    o.req:SetPoint("TOPLEFT", 110, y)
    o.problem = UI.WrapText(box, 12, "B0321E", 340)
    o.problem:SetPoint("TOPLEFT", 110, y - 34)
    o.add = UI.TextButton(box, L.MS_ADD_BUTTON, function()
      local s = o.state
      local value = s.kind == "attune" and s.attune or (s.kind ~= "tick" and tonumber(o.value:GetText())) or nil
      local name = strtrim(o.name:GetText() or "")
      if name == "" and value then name = ns.Milestones.DefaultName(s.kind, value) end
      local cur = F:Current()
      if cur and A:AddMilestone(cur, { id = ns.Milestones.NewID(), kind = s.kind, value = value, name = name, req = s.req }) then
        o:Hide()
      else
        o.problem:SetText(L.MS_BAD)
      end
    end, "primary")
    o.add:SetPoint("BOTTOMRIGHT", -16, 14)
  end
  local opts = {}
  for _, a in ipairs(ns.QuestLists:Attunements(f)) do opts[#opts + 1] = { a.name, a.key } end
  o.attune:SetOptions(opts)
  -- Your quests, then the ones the others share ("Wanted: Hogger (Pata)").
  o.quests = ns.Quests:Pickable(f)
  local qopts = {}
  for _, x in ipairs(o.quests) do
    qopts[#qopts + 1] = { x.mine and x.name or L.MS_PICK_OTHER:format(x.name, ns.Quests.NameList(x.others)), x.id }
  end
  o.state.pick, o.autoName = nil, nil
  o.pick:SetOptions(qopts)
  o.value:SetText(""); o.name:SetText(""); o.problem:SetText("")
  self:FormRefresh(o)
  o:Show()
end

-- The quest list's text when nothing is picked: what to do, or that there are no quests to pick.
function A:PickText(o)
  o.pick:Refresh()
  if not o.state.pick then o.pick.text:SetText(#(o.quests or {}) > 0 and L.MS_PICK or L.MS_PICK_NONE) end
  o.pick:SetEnabled(#(o.quests or {}) > 0)
end

function A:FormRefresh(o)
  local k = o.state.kind
  o.kind:Refresh(); o.req:Refresh(); o.attune:Refresh()
  o.value:SetShown(k == "quest" or k == "level")
  o.pick:SetShown(k == "quest")
  self:PickText(o)
  o.attune:SetShown(k == "attune")
  o.valueLabel:SetShown(k ~= "tick")
  o.valueLabel:SetText(k == "quest" and L.MS_VALUE_QUEST or (k == "level" and L.MS_VALUE_LEVEL or L.MS_VALUE_ATTUNE))
  o.valueHint:SetText(k == "quest" and L.MS_VALUE_QUEST_HINT or (k == "tick" and L.MS_NAME_TICK_HINT or ""))
end

-- "Quest #166  ·  Required"
local function kindLine(m)
  local what = m.kind == "quest" and L.MS_KIND_LINE_QUEST:format(m.value) or (m.kind == "level" and L.MS_KIND_LINE_LEVEL:format(m.value)
    or (m.kind == "attune" and L.MS_KIND_LINE_ATTUNE or L.MS_KIND_LINE_TICK))
  return what
end
A.KindLine = kindLine

-- The bar with Publish under both halves (30 Oct 2026: Publish lay at the end of a long scroll, under every dungeon).
local BAR_H = 46

local function build(pf)
  local W = ns.Window
  local width = W.PAGE_W - 8
  local function cur() return F:Current() end
  -- The editor, above the bar; it works on the draft (made from the published journey on the first change).
  local edL, edR = CreateFrame("Frame", nil, pf.left), CreateFrame("Frame", nil, pf.right)
  edL:SetPoint("TOPLEFT"); edL:SetPoint("BOTTOMRIGHT", 0, BAR_H + 12)
  edR:SetPoint("TOPLEFT"); edR:SetPoint("BOTTOMRIGHT", 0, BAR_H + 12)
  pf.editor = ns.JourneyEditor.New(edL, edR, width, width, {
    journey = function() local f = cur(); return f and A:Journey(f) end,
    edit = function(fn, quiet)
      local f = cur()
      if not f then return end
      A:Edit(f, fn, quiet)
      if quiet then pf.showDraft() end
    end,
    replace = function(j)
      local f = cur()
      A.jd, A.fid, A.sel = j, f and f.id, 1
      W:Refresh()
    end,
    sel = function() return A.sel end,
    setSel = function(i) A.sel = i; W:Refresh() end,
    importHint = L.IMPORT_HINT,
    spread = true, -- the ruler across both pages (28 Oct 2026)
    afterChapter = function(r) pf.placeMilestones(r) end,
    afterJourney = function(r) pf.placeExport(r) end,
  })
  local ed = pf.editor
  local R = ed.panes.chapter
  -- (Names the tests, the tour and the self-test use.)
  pf.name, pf.floor, pf.cap, pf.drows, pf.presets, pf.import = ed.name, ed.floor, ed.cap, ed.drows, ed.presets, ed.import

  -- Milestones of the chosen chapter, after its dungeons (in This chapter).
  pf.msHead = UI.SectionHeader(R, width)
  pf.msHead:SetText(L.MS_ADMIN_HEAD)
  pf.msNone = UI.WrapText(R, 12, "ink2", width, "book")
  pf.msNone:SetText(L.MS_ADMIN_NONE)
  pf.msRows = UI.Pool(function()
    local c = UI.Card(R)
    c:SetSize(width, 64)
    c.name = UI.Text(c, 13, "ink", "title")
    c.name:SetPoint("TOPLEFT", 10, -9); c.name:SetWidth(width - 50)
    c.kind = UI.Text(c, 11, "ink2")
    c.kind:SetPoint("TOPLEFT", c.name, "BOTTOMLEFT", 0, -2)
    c.x = CreateFrame("Button", nil, c, "UIPanelCloseButton")
    c.x:SetSize(24, 24); c.x:SetPoint("TOPRIGHT", -2, -2)
    c.x:SetScript("OnClick", function() local f = cur(); if f then A:RemoveMilestone(f, c.id) end end)
    c.req = UI.Choice(c, { { L.MS_REQUIRED, true }, { L.MS_OPTIONAL, false } }, function() return c.reqOn end,
      function(v) local f = cur(); if f then A:SetRequired(f, c.id, v) end end)
    c.req:SetPoint("TOPRIGHT", -30, -34)
    return c
  end)
  pf.msAdd = UI.TextButton(R, L.MS_ADD, function() local f = cur(); if f then A:MilestoneForm(f) end end, "plain")
  function pf.placeMilestones(r)
    local f = cur()
    local ch = f and A:Journey(f).chapters[A.sel]
    if not ch then return end
    r:Place(pf.msHead, 29, 4)
    local ms = ch.milestones or {}
    local shown = 0
    for i, m in ipairs(ms) do
      local c = pf.msRows:Get(i)
      if not c then break end
      shown = i
      c.id, c.reqOn = m.id, m.req
      c.name:SetText(m.name)
      c.kind:SetText(kindLine(m))
      c.req:Refresh()
      r:Place(c, 64, 6)
    end
    pf.msRows:HideFrom(shown + 1)
    pf.msNone:SetShown(#ms == 0)
    if #ms == 0 then r:Place(pf.msNone, pf.msNone:GetStringHeight(), 6) end
    r:Place(pf.msAdd, 28, 16)
  end

  -- Export, in Whole journey: the journey as a string to copy.
  local J = ed.panes.journey
  pf.exportLabel = UI.Text(J, 13, "ink2")
  pf.exportLabel:SetText(L.EXPORT_TITLE)
  pf.export = UI.TextButton(J, L.EXPORT, function()
    local f = cur()
    if f then W:TextDialog(L.EXPORT_TITLE, L.EXPORT_HINT, ns.Journey.Export(A:Journey(f))) end
  end, "plain", 12)
  function pf.placeExport(r)
    r:Place(pf.exportLabel, 16, 4)
    r:Place(pf.export, 28, 12)
  end

  -- The bar under both halves, never scrolled: what is not published yet, Discard and Publish. Gold while there is
  -- a draft.
  pf.bar = UI.Card(pf.left)
  pf.bar:SetPoint("BOTTOMLEFT", pf.left, "BOTTOMLEFT", 0, 0)
  pf.bar:SetPoint("BOTTOMRIGHT", pf.right, "BOTTOMRIGHT", 0, 0)
  pf.bar:SetHeight(BAR_H)
  pf.publish = UI.TextButton(pf.bar, L.PUBLISH, function() A:Publish(cur()) end, "primary")
  pf.publish:SetPoint("RIGHT", -9, 0)
  pf.discard = UI.TextButton(pf.bar, L.DISCARD, function() A:Discard() end, "plain")
  pf.discard:SetPoint("RIGHT", pf.publish, "LEFT", -6, 0)
  pf.draftText = UI.Text(pf.bar, 13, "ink", "book")
  pf.draftText:SetPoint("LEFT", 14, 0)
  function pf.showDraft()
    local f = cur()
    if not f then return end
    local n = A:Changes(f)
    pf.draftText:SetText(A.jd and (n == 1 and L.DRAFT_1 or L.DRAFT_N:format(n)) or L.PUBLISHED)
    pf.publish:SetShown(A.jd ~= nil); pf.discard:SetShown(A.jd ~= nil)
    pf.bar:SetSelected(A.jd ~= nil)
  end
end

local function refresh(pf, ctx)
  local f = ctx.f
  if not f then return end
  A:Own(f)
  -- Opened afresh without a draft: the chapter the fellowship is in (chapter I is the Prologue, without dungeons).
  if pf.sel == nil and not A.jd then A.sel = ns.Journey:CurrentIndex(f) end
  pf.sel = true
  A.sel = ns.Clamp(A.sel, 1, #A:Journey(f).chapters)
  pf.editor:Refresh()
  pf.showDraft()
end

-- A tool, not a page to read: the flat sheet, its title across the top (29 Oct 2026).
ns.Pages:Register({ id = "admin", label = L.NAV_ADMIN, build = build, refresh = refresh, flat = true, header = "both",
  title = function() return L.TITLE_ADMIN, L.SUB_ADMIN end })
