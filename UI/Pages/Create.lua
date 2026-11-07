-- Create a Fellowship (SPEC §4.2): four steps, the fellowship, the play style, the journey, review. Simple first
-- (27 Oct 2026): the play style and the journey are a few picture tiles; every rule can still be fine-tuned (the
-- full form on both pages, behind a link). Each step uses both pages (28 Oct 2026; the right page was mostly empty):
-- what you choose on the left, what it means on the right (your banner and its emblems, the levels a play style
-- allows, the journey's chapters). Back stays on the left page; Next and Create are on the right, like turning a page.
local _, ns = ...
local L = ns.L
local UI, Theme = ns.UI, ns.Theme

-- The choices made so far (kept while the page is open; reset after founding).
local C = {}
ns.CreateState = C
function C:Reset()
  -- The banner starts in the side's colour: Alliance blue, Horde crimson (a Horde fellowship started blue; seen in game).
  local horde = ns.Theme:Horde()
  self.step, self.name, self.color, self.emblem, self.role, self.preset = 1, "", ns.BANNERS[horde and 2 or 1][2], ns.Emblems:First(), "DPS", ns.Rules.Suggest("party")[2]
  self.rules = ns.Rules.New()
  self.size = "party"
  self.fine = false -- step 2: the full rules form instead of the styles
  -- "Your own journey" (28 Oct 2026): shaped here, in a Chapters step after the journey (the journey editor).
  self.own, self.journey, self.sel = false, nil, 1
  -- Challenges (SPEC §9, 31 Oct 2026): none by default; they combine. lives: the shared lives chosen (nil: what the
  -- size suggests); gold: Pauper's limit (nil: 10).
  self.challenges, self.lives, self.pvp, self.gold = {}, nil, nil, nil
end

-- The steps, by key (C.step is a number into this list). Your own journey adds Chapters.
C.STEPS = { "fellowship", "style", "journey", "challenges", "review" }
C.STEPS_OWN = { "fellowship", "style", "journey", "chapters", "challenges", "review" }
C.STEP_LABELS = { fellowship = "STEP_FELLOWSHIP", style = "STEP_STYLE", journey = "STEP_JOURNEY", chapters = "STEP_CHAPTERS",
  challenges = "STEP_CHALLENGES", review = "STEP_REVIEW" }
function C:Steps() return self.own and self.STEPS_OWN or self.STEPS end
function C:StepKey() local s = self:Steps(); return s[ns.Clamp(self.step, 1, #s)] end
function C:Goto(key)
  for i, k in ipairs(self:Steps()) do if k == key then self.step = i end end
  self.fine = false
end

-- How many will you be? Sets the size's rules, and its suggested style and journey (both can still be changed).
function C:SetSize(key)
  local R = ns.Rules
  self.size = key
  local suggest = R.Suggest(key)
  self.rules = R.WithStyle(R.WithSize(self.rules, key), suggest[1])
  self.preset = suggest[2]
end

-- The journey the fellowship will start with: a preset's, or your own.
function C:Journey() return self.own and self.journey or ns.BuildJourney(self.preset) end
function C:JourneyTitle() return self.own and L.PRESET_OWN or ns.PRESETS[self.preset].title end

-- Your own journey starts as a copy of the journey your size suggests (kept when you look at a preset and come back).
function C:ChooseOwn()
  self.own = true
  if not self.journey then
    local suggest = ns.Rules.Suggest(self.size)
    self.journey, self.sel = ns.BuildJourney(suggest[2]), 1
  end
end

function C:ChoosePreset(key) self.own, self.preset = false, key end

-- Challenges: each on or off; Shared lives' number starts at what the size suggests, and the Leader may change it.
-- One Ironman Fellowship takes on (Hardcore Fellowship, White gear only) stays ticked with it; No healers is not for a
-- Leader who heals.
function C:Included(key) return self.challenges.ironman and ns.Challenges:IncludedBy({ challenges = { ironman = true } }, key) ~= nil end
function C:Blocked(key) return key == "nohealers" and self.role == "Healer" end
function C:ToggleChallenge(key)
  if self:Included(key) or self:Blocked(key) then return end
  self.challenges[key] = not self.challenges[key] or nil
end
function C:Chosen(key) return self.challenges[key] == true or self:Included(key) end
-- Pauper's gold: 10 suggested, in steps that grow with the gold.
C.GOLD_STEPS = { 1, 2, 3, 4, 5, 10, 15, 20, 25, 50, 75, 100, 150, 200, 250, 500, 750, 1000 }
function C:Gold() return self.gold or ns.Challenges.PAUPER_SUGGEST end
function C:StepGold(d)
  local cur, steps = self:Gold(), self.GOLD_STEPS
  if d > 0 then for _, g in ipairs(steps) do if g > cur then self.gold = g return end end
  else for i = #steps, 1, -1 do if steps[i] < cur then self.gold = steps[i] return end end end
end
function C:Lives() return self.lives or ns.Challenges.SHARED_SUGGEST[self.size] or ns.Challenges.SHARED_SUGGEST.party end
function C:StepLives(d)
  local Ch = ns.Challenges
  self.lives = ns.Clamp(self:Lives() + d, Ch.SHARED_MIN, Ch.SHARED_MAX)
end
-- What the fellowship is founded with: { hardcore = true | "pvp", shared = 10, pauper = 10, oneclass = "WARRIOR",
-- ... }, or nil for none. (pvp: on a PvP realm, which the Leader says: Hardcore PvP Fellowship. One class only: the
-- Leader's.)
function C:Challenges()
  local out = {}
  for k in pairs(self.challenges) do if not self:Blocked(k) then out[k] = true end end
  if out.ironman then out.hardcore, out.white = true, true end
  if out.hardcore and self.pvp then out.hardcore = "pvp" end
  if out.shared then out.shared = self:Lives() end
  if out.pauper then out.pauper = self:Gold() end
  if out.oneclass then out.oneclass = ns.Fellowship:MyInfo().class end
  return ns.Challenges.Clean(out)
end

-- The challenge banners (the owner, 1 Nov 2026: three vertical banners, every challenge in sight at once). Each hangs
-- from its group's picture: dark cloth with a gold edge and a pointed tail, drawn here. Its rows are placed by Refresh,
-- each as tall as its words and what it asks.
local BANNER_HEAD, BANNER_TAIL, BANNER_PAD, ROW_MIN = 36, 18, 6, 22
local CLOTH_TOP, CLOTH_BOTTOM = { 0.17, 0.11, 0.06, 0.97 }, { 0.09, 0.06, 0.035, 0.97 }
-- Each banner's picture (the dungeons' loading screens): Stratholme's dead for Survival, Blackrock Depths (where the
-- Ring ends) for Story and Travel, the Deadmines' gold for Gear, Gold & More.
C.GROUP_ART = { survival = "strat", story = "brd", more = "dm" }
-- And a faint emblem low on its cloth, under the rows (the check of 1 Nov 2026, 14:32): a skull, the Ring, a coin.
C.GROUP_EMBLEM = { survival = "chal_hardcore", story = "chal_ring", more = "chal_pauper" }

local function chalBanner(parent, w, group)
  local b = CreateFrame("Frame", nil, parent)
  b:SetWidth(w)
  b.group, b.tail, b.rows = group, BANNER_TAIL, {}
  b.head = CreateFrame("Frame", nil, b)
  b.head:SetPoint("TOPLEFT"); b.head:SetPoint("TOPRIGHT"); b.head:SetHeight(BANNER_HEAD)
  b.pic = b.head:CreateTexture(nil, "ARTWORK")
  local fade = b.head:CreateTexture(nil, "ARTWORK", nil, 2)
  UI.FramePicture(b.head, b.pic, fade)
  ns.SetDungeonArt(b.pic, C.GROUP_ART[group], w - 4, BANNER_HEAD - 4)
  UI.SetGradient(fade, "VERTICAL", { 0.05, 0.03, 0.01, 0.85 }, { 0.05, 0.03, 0.01, 0.3 })
  b.title = UI.Text(b.head, 16, "goldText", "fancy", "CENTER", "OVERLAY")
  b.title:SetPoint("CENTER", 0, -1); b.title:SetWidth(w - 12)
  b.title:SetShadowOffset(1, -1); b.title:SetShadowColor(0, 0, 0, 1)
  b.title:SetText(L["CHAL_GROUP_" .. group:upper()])
  local cloth = b:CreateTexture(nil, "BACKGROUND")
  cloth:SetPoint("TOPLEFT", 0, -BANNER_HEAD); cloth:SetPoint("BOTTOMRIGHT", 0, BANNER_TAIL)
  UI.SetGradient(cloth, "VERTICAL", CLOTH_BOTTOM, CLOTH_TOP)
  -- The tail: one-pixel strips, each a little narrower, down to the point.
  for i = 1, BANNER_TAIL do
    local s = b:CreateTexture(nil, "BACKGROUND")
    s:SetColorTexture(CLOTH_BOTTOM[1], CLOTH_BOTTOM[2], CLOTH_BOTTOM[3], CLOTH_BOTTOM[4])
    s:SetSize(math.max(1, w * (BANNER_TAIL - i + 0.5) / BANNER_TAIL), 1)
    s:SetPoint("TOP", b, "BOTTOM", 0, BANNER_TAIL - i + 1)
  end
  for _, side in ipairs({ "LEFT", "RIGHT" }) do
    local e = b:CreateTexture(nil, "BORDER")
    e:SetColorTexture(Theme:RGBA("gold", 0.85)); e:SetWidth(2)
    e:SetPoint("TOP" .. side, b.head, "BOTTOM" .. side)
    e:SetPoint("BOTTOM" .. side, b, "BOTTOM" .. side, 0, BANNER_TAIL)
  end
  for _, side in ipairs({ "BOTTOMLEFT", "BOTTOMRIGHT" }) do
    local l = b:CreateLine(nil, "BORDER")
    l:SetThickness(2); l:SetColorTexture(Theme:RGBA("gold", 0.85))
    l:SetStartPoint(side, b, side == "BOTTOMLEFT" and 1 or -1, BANNER_TAIL)
    l:SetEndPoint("BOTTOM", b, 0, 0)
  end
  b.emblem = UI.Round(b, "BORDER", 64, 1)
  b.emblem:SetPoint("BOTTOM", b, "BOTTOM", 0, BANNER_TAIL + 10)
  local found = UI.SetIcon(b.emblem, ns.ICONS[C.GROUP_EMBLEM[group]])
  b.emblem:SetDesaturated(true); b.emblem:SetVertexColor(1, 0.86, 0.58); b.emblem:SetAlpha(0.16)
  b.emblem:SetShown(found)
  return b
end

-- A box to tick (the game's check box) with words beside it; the whole row is the button. Hovering it calls
-- onHover(row), leaving it onHover(nil): the right page shows its .tipTitle, .tipText and .tipNote (set by Refresh).
local function chalTickBox(r, size)
  r.box = r:CreateTexture(nil, "ARTWORK")
  r.box:SetSize(size, size)
  r.box:SetTexture("Interface\\Buttons\\UI-CheckBox-Up")
  r.check = UI.Check(r, size)
  r.check:SetPoint("CENTER", r.box)
  local hi = r:CreateTexture(nil, "HIGHLIGHT")
  hi:SetAllPoints(); hi:SetColorTexture(1, 0.9, 0.6, 0.08)
end
local function chalRow(parent, w, key, onClick, onHover)
  local r = CreateFrame("Button", nil, parent)
  r:SetSize(w, ROW_MIN)
  r.key = key
  r.tint = r:CreateTexture(nil, "BACKGROUND")
  r.tint:SetAllPoints(); r.tint:SetColorTexture(1, 0.85, 0.45, 0.13); r.tint:Hide()
  chalTickBox(r, 20)
  r.box:SetPoint("TOPLEFT", 0, -1)
  r.name = UI.WrapText(r, 13, "chipText", w - 26, "body")
  r.name:SetPoint("TOPLEFT", 24, -4)
  r.sub = UI.WrapText(r, 11, nil, w - 26, "book")
  r.sub:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -2)
  Theme:TextColor(r.sub, "chipText", 0.8)
  r:SetScript("OnClick", function() ns.Sound("choose"); onClick() end)
  r:SetScript("OnEnter", function(self) onHover(self) end)
  r:SetScript("OnLeave", function() onHover(nil) end)
  return r
end
-- Under a chosen row, what it asks: a smaller tick (Hardcore's PvP realm), or a number with what is suggested.
local function chalTick(parent, w, label, getValue, setValue)
  local t = CreateFrame("Button", nil, parent)
  t:SetWidth(w)
  chalTickBox(t, 18)
  t.box:SetPoint("TOPLEFT", 0, -1)
  t.label = UI.WrapText(t, 12, "chipText", w - 22, "body")
  t.label:SetPoint("TOPLEFT", 22, -4); t.label:SetText(label)
  t:SetScript("OnClick", function() ns.Sound("choose"); setValue(not getValue()) end)
  function t:Refresh()
    self.check:SetShown(getValue() and true or false)
    self:SetHeight(math.max(20, self.label:GetStringHeight() + 8))
  end
  return t
end
local function chalNumber(parent, w, onDown, onUp, getText, getNote)
  local f = CreateFrame("Frame", nil, parent)
  f:SetSize(w, 36)
  f:EnableMouse(true) -- a click between the arrows is not a click on the row
  local s = UI.Stepper(f, onDown, onUp, getText)
  s.down:SetSize(22, 22); s.up:SetSize(22, 22); s.value:SetWidth(60)
  s:SetSize(22 + 4 + 60 + 4 + 22, 22)
  s:SetPoint("TOPLEFT")
  Theme:TextColor(s.value, "chipText")
  f.stepper, f.up, f.down = s, s.up, s.down
  f.note = UI.Text(f, 11, nil, "book")
  f.note:SetPoint("TOPLEFT", s, "BOTTOMLEFT", 0, -2); f.note:SetWidth(w)
  Theme:TextColor(f.note, "chipText", 0.8)
  function f:Refresh() s:Refresh(); self.note:SetText(getNote()) end
  return f
end

local STYLE_ART = { relaxed = 3, together = 1, strict = 13 }   -- chapter pictures on the style tiles
local PRESET_ART = { forever = 1, classic = 3, short = 5, long = 9, scratch = 12 }

local function styleName(key) return ns.Rules.StyleName(key) end
local function sizeName(key) return ns.Rules.SizeName(key) end
C:Reset()

local function myName() return ns.Short(ns.Me()) end
local function faction() return select(2, UnitFactionGroup("player")) or "" end
local function fellowshipName() return strtrim(C.name) ~= "" and strtrim(C.name) or L.DEFAULT_FELLOWSHIP_NAME:format(myName()) end

-- The levels around an example chapter (25-29), each with what the rules allow there: "below" the floor, "slack"
-- (the floor or cap allowance), "ready" (floor to cap), "runs" (only from fellowship runs) or "over" the cap.
-- Step 2 draws them as a strip of cells, so the three styles can be compared at a glance.
C.EXAMPLE = { 25, 29 }
function C.LevelKinds(r)
  local floor, cap = C.EXAMPLE[1], C.EXAMPLE[2]
  local out = {}
  for lvl = floor - 4, cap + 5 do
    local kind = "over"
    if lvl < floor - r.floorTol then kind = "below"
    elseif lvl < floor or (lvl > cap and lvl <= cap + r.capTol) then kind = "slack"
    elseif lvl <= cap then kind = "ready"
    elseif r.runXp and lvl <= cap + r.capTol + r.runXpMax then kind = "runs" end
    out[#out + 1] = { level = lvl, kind = kind }
  end
  return out
end
local KIND_COLOR = { below = "line", slack = "B8742A", ready = "3E7A3A", runs = "2E6FA8", over = "B0321E" }
local KIND_ORDER = { "below", "slack", "ready", "runs", "over" }
local CELLS = C.EXAMPLE[2] - C.EXAMPLE[1] + 10

-- What the review shows (28 Oct 2026: the fellowship, the rules as rows, the journey on the right page).
function C:Review()
  local R, r = ns.Rules, self.rules
  local clear = r.clearMode == "all" and L.REVIEW_CLEAR_ALL or (r.clearMode == "one" and L.REVIEW_CLEAR_ONE or L.REVIEW_CLEAR_N:format(r.clearN))
  local runs = not r.runXp and L.REVIEW_RUNXP_OFF or (r.runXpMax == 1 and L.REVIEW_RUNXP_1 or L.REVIEW_RUNXP_N:format(r.runXpMax))
  local rows = {
    { L.REVIEW_K_FLOOR, r.floorTol > 0 and L.REVIEW_SLACK_FLOOR:format(r.floorTol) or L.REVIEW_SLACK_NONE },
    { L.REVIEW_K_CAP, r.capTol > 0 and L.REVIEW_CAP:format(r.capTol) or L.REVIEW_CAP_NONE },
    { L.REVIEW_K_RUNXP, runs },
    { L.REVIEW_K_RUN, L.REVIEW_RUN_V:format(r.minHeroes) },
    { L.REVIEW_K_CLEAR, clear },
    { L.REVIEW_K_AWAY, r.awayNever and L.REVIEW_AWAY_NEVER or L.REVIEW_AWAY_V:format(r.awayDays) },
  }
  if r.gmT then rows[#rows + 1] = { L.REVIEW_K_GMT, L.REVIEW_GMT_ON } end
  return {
    name = fellowshipName(),
    line = L.REVIEW_LEAD:format(faction(), myName(), L["ROLE_" .. self.role:upper()]),
    style = L.REVIEW_SIZE_STYLE:format(sizeName(R.SizeOf(r)), styleName(R.StyleOf(r))),
    rules = rows,
    journey = self:JourneyTitle(),
    challenges = ns.Challenges:Line(self:Challenges()) or L.REVIEW_CHAL_NONE,
  }
end

function C:Create()
  local f = ns.Fellowship:Create({ name = self.name, color = self.color, emblem = self.emblem, role = self.role, preset = self.preset,
    journey = self.own and self.journey or nil, rules = self.rules, challenges = self:Challenges() })
  return f
end

local ROLES = { { L.ROLE_TANK, "Tank" }, { L.ROLE_HEALER, "Healer" }, { L.ROLE_DPS, "DPS" } }
ns.ROLE_CHOICES = ROLES

-- A journey's chapters and dungeons, counted.
local function counts(j)
  local per, seen, n = {}, {}, 0
  for key, p in pairs(j.place) do
    per[p.ch] = (per[p.ch] or 0) + 1
    local base = ns.BaseKey(key)
    if not seen[base] then seen[base] = true; n = n + 1 end
  end
  return per, n
end
C.Counts = counts

-- The chapters of a journey on the right page (step 3 and the review): a ruler of their levels, the numbers, and a
-- row per chapter with its levels and dungeons. :Set(journey, title).
local function roadView(parent, width)
  local v = CreateFrame("Frame", nil, parent)
  v:SetAllPoints()
  v.head = UI.SectionHeader(v, width)
  v.head:SetPoint("TOPLEFT", 0, -8)
  -- The ruler on its plate, as in the journey editor (29 Oct 2026).
  local JED = ns.JourneyEditor
  v.plate = JED.Plate(v, width, 12)
  v.plate:SetPoint("TOPLEFT", 0, -44)
  v.ruler = v.plate.ruler
  local rulerW = width - 2 * JED.PLATE_PAD
  v.segs = {}
  for i = 1, ns.Journey.MAX_CHAPTERS do
    local seg = v.ruler:CreateTexture(nil, "ARTWORK")
    seg:SetTexture(ns.WHITE)
    seg.shine, seg.shade = JED.Shine(v.ruler, seg, 12)
    v.segs[i] = seg
  end
  v.ticks = {}
  for i, lvl in ipairs({ 1, 15, 30, 45, 60 }) do
    local t = UI.Text(v.plate, 10, "ink2", "body", "CENTER")
    t:SetText(lvl)
    v.ticks[i] = { fs = t, v = lvl }
  end
  local below = 44 + v.plate:GetHeight()
  v.stats = UI.Text(v, 13, "ink", "book")
  v.stats:SetPoint("TOPLEFT", 0, -(below + 8))
  v.scroll = UI.Scroll(v)
  v.scroll:SetPoint("TOPLEFT", 0, -(below + 32)); v.scroll:SetPoint("BOTTOMRIGHT")
  v.rows = UI.Pool(function()
    local r = CreateFrame("Frame", nil, v.scroll.child)
    r:SetSize(width - 10, 22)
    r.sw = r:CreateTexture(nil, "ARTWORK")
    r.sw:SetSize(10, 10); r.sw:SetPoint("LEFT", 2, 0); r.sw:SetTexture(ns.WHITE)
    r.n = UI.Text(r, 12, "ink2")
    r.n:SetPoint("LEFT", 18, 0)
    r.name = UI.Text(r, 13, "ink")
    r.name:SetPoint("LEFT", 54, 0); r.name:SetWidth(width - 250)
    r.info = UI.Text(r, 12, "ink2", "body", "RIGHT")
    r.info:SetPoint("RIGHT", -4, 0)
    return r
  end)
  function v:Set(j, title)
    self.head:SetText(title)
    -- From the first floor to the last cap (60).
    local lo, hi = 60, 60
    for _, c in ipairs(j.chapters) do lo, hi = math.min(lo, c.floor), math.max(hi, c.cap) end
    local span = math.max(1, hi - lo)
    for i, seg in ipairs(self.segs) do
      local c = j.chapters[i]
      seg:SetShown(c ~= nil); seg.shine:SetShown(c ~= nil); seg.shade:SetShown(c ~= nil)
      if c then
        local x0 = (ns.Clamp(c.floor, lo, hi) - lo) / span * rulerW
        local x1 = (ns.Clamp(c.cap, lo, hi) - lo) / span * rulerW
        seg:ClearAllPoints(); seg:SetPoint("TOPLEFT", self.ruler, "TOPLEFT", x0, 0)
        seg:SetSize(math.max(1, x1 - x0 - 1), 12)
        seg:SetVertexColor(ns.Hex(c.color or "E2B857")); seg:SetAlpha(0.85)
      end
    end
    -- The end labels sit inside the ruler (as in Journey Admin).
    local first = true
    for i, t in ipairs(self.ticks) do
      -- (The last label is the ruler's end: 60, or the stretched journey's cap.)
      local lvl = i == #self.ticks and hi or t.v
      local shown = lvl >= lo
      t.fs:SetShown(shown)
      if shown then
        t.fs:SetText(lvl)
        local point = first and "TOPLEFT" or (i == #self.ticks and "TOPRIGHT" or "TOP")
        t.fs:ClearAllPoints(); t.fs:SetPoint(point, self.ruler, "BOTTOMLEFT", (lvl - lo) / span * rulerW, -5)
        first = false
      end
    end
    local per, n = counts(j)
    self.stats:SetText(L.ROAD_STATS:format(#j.chapters, n, lo))
    local s = UI.Stack(self.scroll.child)
    local shown = 0
    for i, c in ipairs(j.chapters) do
      local r = self.rows:Get(i)
      if not r then break end
      shown = i
      r.sw:SetVertexColor(ns.Hex(c.color or "E2B857"))
      r.n:SetText(ns.Journey.Roman(i))
      r.name:SetText(c.name)
      local d = per[i] or 0
      r.info:SetText(c.floor .. "-" .. c.cap .. "  ·  " .. (d == 0 and L.ROAD_NO_DUNGEONS or (d == 1 and L.ROAD_DUNGEON_1 or L.ROAD_DUNGEONS:format(d))))
      s:Place(r, 22, 0)
    end
    self.rows:HideFrom(shown + 1)
    self.scroll:SetContentHeight(s.y)
  end
  return v
end

local function build(pf)
  local W = ns.Window
  local width = W.PAGE_W_WIDE
  local left, right = pf.left, pf.right
  local function go(key) C:Goto(key); W:Refresh() end
  pf.back = UI.TextButton(left, L.BACK_WELCOME, function() W.startView = "welcome"; W:Refresh() end, "link", 13)
  pf.back:SetPoint("TOPLEFT", 0, 4)
  local head = UI.Heading(left, width, L.FOUND, L.CREATE_SUB, 20)
  head:SetPoint("TOPLEFT", 0, -22)
  pf.head = head
  -- Step strip: 1 Fellowship  2 Play style  3 Journey  (4 Chapters)  4 Review; placed on refresh.
  pf.steps = {}
  pf.stepY = head:GetHeight() + 26
  for i = 1, #C.STEPS_OWN do
    local s = CreateFrame("Frame", nil, left)
    s:SetHeight(24)
    s.disc = UI.Round(s, "ARTWORK", 22)
    s.disc:SetPoint("LEFT")
    s.n = UI.Text(s, 12, "white", "body", "CENTER", "OVERLAY")
    s.n:SetPoint("CENTER", s.disc)
    s.n:SetText(i)
    s.label = UI.Text(s, 13, nil, "body")
    s.label:SetPoint("LEFT", s.disc, "RIGHT", 6, 0)
    pf.steps[i] = s
  end
  local top = head:GetHeight() + 62

  -- One frame per step on each page: the left above Back, the right above Next.
  pf.body, pf.side = {}, {}
  for _, key in ipairs(C.STEPS_OWN) do
    local b = CreateFrame("Frame", nil, left)
    b:SetPoint("TOPLEFT", 0, -top); b:SetPoint("BOTTOMRIGHT", 0, 44)
    pf.body[key] = b
    local r = CreateFrame("Frame", nil, right)
    r:SetPoint("TOPLEFT"); r:SetPoint("BOTTOMRIGHT", 0, 44)
    pf.side[key] = r
  end

  -- Step 1, left: name, role, and how many you will be (four cards, each with what it suggests).
  local s1 = pf.body.fellowship
  local intro = UI.WrapText(s1, 14, "ink", width, "book")
  intro:SetPoint("TOPLEFT")
  intro:SetText(L.CREATE_INTRO)
  local y = intro:GetStringHeight() + 14
  local nameLabel = UI.Text(s1, 13, "ink2")
  nameLabel:SetPoint("TOPLEFT", 0, -y); nameLabel:SetText(L.NAME)
  pf.name = UI.EditBox(s1, width, 48, L.NAME_PLACEHOLDER)
  pf.name:SetPoint("TOPLEFT", 0, -(y + 18))
  pf.name.edit:HookScript("OnTextChanged", function() C.name = pf.name:GetText(); if pf.pname then pf.pname:SetText(fellowshipName()) end end)
  y = y + 58
  local rLabel = UI.Text(s1, 13, "ink")
  -- The role as the Dungeon Finder's role icons (UI.RoleChoice; 50 high, a row of words without the art).
  pf.role = UI.RoleChoice(s1, ROLES, function() return C.role end, function(v) C.role = v end)
  pf.role:SetPoint("TOPLEFT", 110, -y)
  rLabel:SetPoint("TOPLEFT", 0, -(y + math.floor(pf.role:GetHeight() / 2) - 7)); rLabel:SetText(L.YOUR_ROLE)
  -- How many will you be? It only sets rules; anyone can still be invited (and the Leader is told when the
  -- fellowship grows into another size).
  y = y + pf.role:GetHeight() + 12
  local sizeLabel = UI.Text(s1, 13, "ink")
  sizeLabel:SetPoint("TOPLEFT", 0, -y); sizeLabel:SetText(L.SIZE_PICK)
  y = y + 22
  local cw, ch = math.floor((width - 10) / 2), 48
  pf.sizes = {}
  for i, key in ipairs(ns.Rules.SIZE_ORDER) do
    local card = UI.Card(s1, "line", "Button")
    card:SetSize(cw, ch)
    card:SetPoint("TOPLEFT", ((i - 1) % 2) * (cw + 10), -(y + math.floor((i - 1) / 2) * (ch + 8)))
    card.title = UI.Text(card, 14, "ink", "title")
    card.title:SetPoint("TOPLEFT", 12, -8)
    card.title:SetText(L["SIZE_" .. key:upper()])
    card.sub = UI.Text(card, 12, "ink2")
    card.sub:SetPoint("TOPLEFT", card.title, "BOTTOMLEFT", 0, -4)
    local suggest = ns.Rules.Suggest(key)
    card.sub:SetText(L.SIZE_SUGGESTS:format(styleName(suggest[1]), ns.PRESETS[suggest[2]].title))
    card.check = UI.Check(card, 18)
    card.check:SetPoint("TOPRIGHT", -8, -8)
    local hl = card:CreateTexture(nil, "HIGHLIGHT")
    hl:SetPoint("TOPLEFT", 3, -3); hl:SetPoint("BOTTOMRIGHT", -3, 3); hl:SetColorTexture(1, 0.85, 0.45, 0.12)
    card.key = key
    card:SetScript("OnClick", function()
      if C.size ~= key then ns.Sound("choose") end
      C:SetSize(key); W:Refresh()
    end)
    pf.sizes[i] = card
  end
  y = y + 2 * ch + 8 + 10
  pf.sizeNote = UI.WrapText(s1, 12, "ink2", width)
  pf.sizeNote:SetPoint("TOPLEFT", 0, -y)
  pf.sizeNote:SetText(L.SIZE_NOTE)
  pf.faction = UI.WrapText(s1, 12, "ink2", width)
  pf.faction:SetPoint("TOPLEFT", pf.sizeNote, "BOTTOMLEFT", 0, -6)

  -- Step 1, right: your banner as others will see it, its colour, and every emblem to choose from.
  local r1 = pf.side.fellowship
  pf.preview = r1
  local bh = UI.SectionHeader(r1, width)
  bh:SetText(L.YOUR_BANNER); bh:SetPoint("TOPLEFT", 0, -8)
  pf.crest = UI.Crest(r1, 96, 96)
  pf.crest:SetPoint("TOPLEFT", 4, -46)
  pf.pname = UI.Text(r1, 20, "ink", "title")
  pf.pname:SetPoint("TOPLEFT", 124, -70)
  pf.pname:SetWidth(width - 124)
  local pnote = UI.WrapText(r1, 12, "ink2", width - 124, "book")
  pnote:SetPoint("TOPLEFT", pf.pname, "BOTTOMLEFT", 0, -6)
  pnote:SetText(L.BANNER_PREVIEW)
  local cLabel = UI.Text(r1, 13, "ink2")
  cLabel:SetPoint("TOPLEFT", 0, -158); cLabel:SetText(L.BANNER_COLOUR)
  pf.swatches = UI.Swatches(r1, function() return C.color end, function(v) C.color = v; W:Refresh() end)
  pf.swatches:SetPoint("TOPLEFT", 0, -178)
  local eLabel = UI.Text(r1, 13, "ink2")
  eLabel:SetPoint("TOPLEFT", 0, -222); eLabel:SetText(L.EMBLEM)
  pf.emblemGrid = UI.EmblemGrid(r1, width - 10, function(n) ns.Sound("choose"); C.emblem = n; W:Refresh() end)
  pf.emblemGrid:SetPoint("TOPLEFT", 0, -242); pf.emblemGrid:SetPoint("BOTTOMRIGHT", -8, 0)

  -- Step 2, left: the play style as three picture tiles, each with a strip of what it allows at every level; or
  -- (Fine-tune) the full rules form on both pages.
  local s2 = pf.body.style
  pf.stylePick = UI.Text(s2, 15, "ink", "title")
  pf.stylePick:SetPoint("TOPLEFT"); pf.stylePick:SetText(L.STYLE_PICK)
  pf.styles = {}
  for i, key in ipairs(ns.Rules.STYLE_ORDER) do
    local tile = UI.PictureTile(s2, width, 112, function(tex, w, h) ns.Pages:SetChapterArt(tex, STYLE_ART[key], w, h, 0.5) end,
      function() C.rules = ns.Rules.WithStyle(C.rules, key); W:Refresh() end)
    tile:Set(L["STYLE_" .. key:upper()], L["STYLE_" .. key:upper() .. "_TEXT"])
    tile:SetPoint("TOPLEFT", 0, -(26 + (i - 1) * 120))
    tile.key = key
    -- The strip along the top, like the journey tiles' chapters: the levels of the example chapter.
    tile.cells = {}
    local cellW = (width - 24) / CELLS
    for k, lv in ipairs(C.LevelKinds(ns.Rules.WithStyle(ns.Rules.New(), key))) do
      local cell = tile:CreateTexture(nil, "OVERLAY")
      cell:SetSize(math.max(1, cellW - 1), 6)
      cell:SetPoint("TOPLEFT", 12 + (k - 1) * cellW, -8)
      cell.kind = lv.kind
      tile.cells[k] = cell
    end
    pf.styles[i] = tile
  end
  pf.styleBack = UI.TextButton(s2, L.STYLE_BACK, function() C.fine = false; W:Refresh() end, "link", 13)
  pf.styleBack:SetPoint("TOPLEFT", 0, 2)

  -- Step 2, right: what the chosen style means: its strip with the level numbers, a key, and the rules in words.
  pf.styleInfo = pf.side.style
  local sh = UI.SectionHeader(pf.styleInfo, width)
  sh:SetText(L.STYLE_HEAD); sh:SetPoint("TOPLEFT", 0, -8)
  pf.styleName = UI.Text(pf.styleInfo, 20, "ink", "title")
  pf.styleName:SetPoint("TOPLEFT", 0, -48)
  pf.styleExample = UI.Text(pf.styleInfo, 13, "ink2", "book")
  pf.styleExample:SetPoint("TOPLEFT", 0, -80)
  pf.styleExample:SetText(L.STYLE_EXAMPLE:format(C.EXAMPLE[1], C.EXAMPLE[2]))
  pf.levelCells = {}
  local bigW = math.floor(width / CELLS)
  for k = 1, CELLS do
    local cell = CreateFrame("Frame", nil, pf.styleInfo)
    cell:SetSize(bigW - 2, 26)
    cell:SetPoint("TOPLEFT", (k - 1) * bigW, -102)
    cell.fill = cell:CreateTexture(nil, "ARTWORK")
    cell.fill:SetAllPoints()
    cell.n = UI.Text(cell, 12, "white", "body", "CENTER")
    cell.n:SetPoint("CENTER")
    cell.n:SetShadowOffset(1, -1); cell.n:SetShadowColor(0, 0, 0, 1)
    cell.n:SetText(C.EXAMPLE[1] - 4 + k - 1)
    pf.levelCells[k] = cell
  end
  pf.levelKey = {}
  for i, kind in ipairs(KIND_ORDER) do
    local item = CreateFrame("Frame", nil, pf.styleInfo)
    item:SetSize(width / 3, 18)
    item:SetPoint("TOPLEFT", ((i - 1) % 3) * width / 3, -(138 + math.floor((i - 1) / 3) * 20))
    item.sw = item:CreateTexture(nil, "ARTWORK")
    item.sw:SetSize(12, 12); item.sw:SetPoint("LEFT")
    item.text = UI.Text(item, 12, "ink2")
    item.text:SetPoint("LEFT", 18, 0)
    item.text:SetText(L["LV_" .. kind:upper()])
    item.kind = kind
    pf.levelKey[i] = item
  end
  pf.styleSummary = UI.WrapText(pf.styleInfo, 14, "ink", width, "book")
  pf.styleSummary:SetPoint("TOPLEFT", 0, -190)
  pf.styleLater = UI.WrapText(pf.styleInfo, 12, "ink2", width, "book")
  pf.styleLater:SetPoint("TOPLEFT", pf.styleSummary, "BOTTOMLEFT", 0, -16)
  pf.styleLater:SetText(L.STYLE_LATER)
  pf.styleFine = UI.TextButton(pf.styleInfo, L.STYLE_FINE, function() C.fine = true; W:Refresh() end, "link", 14)
  pf.styleFine:SetPoint("TOPLEFT", pf.styleLater, "BOTTOMLEFT", 0, -14)

  -- Step 2's fine-tuning: the full rules, on both pages (scrolling).
  pf.rulesLeft = UI.Scroll(pf.body.style)
  pf.rulesLeft:SetPoint("TOPLEFT", 0, -24); pf.rulesLeft:SetPoint("BOTTOMRIGHT")
  pf.rulesRight = UI.Scroll(right)
  pf.rulesRight:SetPoint("TOPLEFT"); pf.rulesRight:SetPoint("BOTTOMRIGHT", 0, 44)
  pf.form = UI.RulesForm(pf.rulesLeft.child, pf.rulesRight.child, width - 10, {
    get = function() return C.rules end,
    set = function(k, v) C.rules[k] = v end,
    cond = function()
      local info = ns.Fellowship:MyInfo()
      return info.gm == true, info.guild
    end,
    heroes = function() return 1 end,
    onLayout = function(lh, rh) pf.rulesLeft:SetContentHeight(lh + 10); pf.rulesRight:SetContentHeight(rh + 10) end,
  })

  -- Step 3, left: the journey presets as picture tiles, each with its chapters as a strip of colours, and Your own
  -- journey (shaped in the next step; it replaced Start from scratch here, which stays in Journey Admin).
  local s3 = pf.body.journey
  local jp = UI.Text(s3, 15, "ink", "title")
  jp:SetPoint("TOPLEFT"); jp:SetText(L.JOURNEY_PICK)
  pf.presets = {}
  -- Five tiles end where the three style tiles of step 2 end, above Back (Forever and Classic since 6 Nov 2026).
  local tileKeys = { "forever", "classic", "short", "long", "own" }
  local tileH = math.floor((352 - (#tileKeys - 1) * 6) / #tileKeys)
  for i, key in ipairs(tileKeys) do
    local own = key == "own"
    local P = ns.PRESETS[key] or { title = L.PRESET_OWN, text = L.PRESET_OWN_TEXT }
    local tile = UI.PictureTile(s3, width, tileH, function(tex, w, h) ns.Pages:SetChapterArt(tex, PRESET_ART[own and "scratch" or key], w, h, 0.5) end,
      function() if own then C:ChooseOwn() else C:ChoosePreset(key) end W:Refresh() end)
    -- (The count is the journey's own: with the Prologue, Classic has 15 chapters; the tile said 14.)
    local chapters = own and { { floor = 15, cap = 60 } } or ns.BuildJourney(key).chapters
    tile.count = #chapters
    tile:Set(P.title, P.text)
    -- Your own journey's picture is the brightest (fire and sunset): dimmed so its gold title and text read (check of
    -- 6 Nov 2026, the owner: "hard to read"; its text also took two lines and pushed the title off the tile).
    if own then tile.pic:SetVertexColor(0.55, 0.5, 0.47) end
    tile:SetPoint("TOPLEFT", 0, -(26 + (i - 1) * (tileH + 6)))
    -- Chapter strip along the top: each chapter's share of the levels (1-60 with the Prologue, else 15-60).
    local lo = chapters[1] and chapters[1].floor or 15
    local bx = 12
    for _, c in ipairs(chapters) do
      local seg = UI.Solid(tile, "OVERLAY", own and "goldText" or c.color)
      local w = (width - 24) * (c.cap - c.floor) / (60 - lo)
      seg:SetSize(math.max(1, w - 1), 5)
      seg:SetPoint("TOPLEFT", bx, -5)
      bx = bx + w
    end
    tile.key = key
    pf.presets[i] = tile
  end

  -- Your own journey's step: the journey editor on both pages (UI/JourneyEditor.lua), on the copy kept here.
  pf.editor = ns.JourneyEditor.New(pf.body.chapters, pf.side.chapters, width - 8, width - 8, {
    journey = function() return C.journey end,
    edit = function(fn, quiet)
      if C.journey then fn(C.journey) end
      if not quiet then W:Refresh() end
    end,
    replace = function(j) C.journey, C.sel = j, 1; W:Refresh() end,
    sel = function() return C.sel end,
    setSel = function(i) C.sel = i; W:Refresh() end,
  })

  -- Step 3, right: the chosen journey's chapters. The review's right page shows the same, with Change.
  pf.road = roadView(pf.side.journey, width)
  pf.reviewRoad = roadView(pf.side.review, width)
  pf.reviewRoad.change = UI.TextButton(pf.reviewRoad, L.CHANGE, function() go(C.own and "chapters" or "journey") end, "link", 12)
  pf.reviewRoad.change:SetPoint("BOTTOMRIGHT", pf.reviewRoad.head, "BOTTOMRIGHT", 0, 6)

  -- Challenges (SPEC §9), left: three banners side by side (Survival, Story and Travel, Gear, Gold & More; the owner,
  -- 1 Nov 2026), so every challenge is in sight at once. Each lists its challenges to tick (they combine; none is
  -- fine); hovering one tells its rule. Under a chosen row, what it asks: Hardcore Fellowship whether it's a PvP realm
  -- (the game doesn't tell an addon the kind of realm, so the Leader says it), Shared lives how many, Pauper how much
  -- gold. Right: what the fellowship takes on, in plain sentences.
  local s5 = pf.body.challenges
  local cp = UI.Text(s5, 15, "ink", "title")
  cp:SetPoint("TOPLEFT"); cp:SetText(L.CHAL_PICK)
  local cIntro = UI.WrapText(s5, 13, "ink2", width, "book")
  cIntro:SetPoint("TOPLEFT", 0, -24); cIntro:SetText(L.CHAL_INTRO)
  local cy = 24 + math.max(cIntro:GetStringHeight(), 32) + 10
  local Ch = ns.Challenges
  local gap = 12
  local bw = math.floor((width - 2 * gap) / 3)
  local rowW = bw - 2 * BANNER_PAD
  pf.banners, pf.chalRows = {}, {}
  for i, g in ipairs(Ch.GROUPS) do
    local b = chalBanner(s5, bw, g.key)
    b:SetPoint("TOPLEFT", (i - 1) * (bw + gap), -cy)
    b:SetPoint("BOTTOMLEFT", (i - 1) * (bw + gap), 0)
    for _, key in ipairs(g.list) do
      local r = chalRow(b, rowW, key, function() C:ToggleChallenge(key); W:Refresh() end,
        function(row) pf.peeking = row; pf:Peek() end)
      b.rows[#b.rows + 1] = r
      pf.chalRows[key] = r
    end
    pf.banners[i] = b
  end
  local extraW = rowW - 24
  pf.pvp = chalTick(pf.chalRows.hardcore, extraW, L.CHAL_PVP_REALM, function() return C.pvp end,
    function(on) C.pvp = on or nil; W:Refresh() end)
  pf.lives = chalNumber(pf.chalRows.shared, extraW, function() C:StepLives(-1); W:Refresh() end,
    function() C:StepLives(1); W:Refresh() end, function() return tostring(C:Lives()) end,
    function() return L.CHAL_LIVES_SUGGEST:format(ns.Rules.SizeWord(C.size), Ch.SHARED_SUGGEST[C.size] or Ch.SHARED_SUGGEST.party) end)
  pf.gold = chalNumber(pf.chalRows.pauper, extraW, function() C:StepGold(-1); W:Refresh() end,
    function() C:StepGold(1); W:Refresh() end, function() return L.CHAL_GOLD_N:format(C:Gold()) end,
    function() return L.CHAL_GOLD_SUGGEST:format(Ch.PAUPER_SUGGEST) end)
  pf.chalRows.hardcore.extra, pf.chalRows.shared.extra, pf.chalRows.pauper.extra = pf.pvp, pf.lives, pf.gold
  local r5 = pf.side.challenges
  local chh = UI.SectionHeader(r5, width)
  chh:SetText(L.CHAL_HEAD); chh:SetPoint("TOPLEFT", 0, -8)
  pf.chalName = UI.WrapText(r5, 18, "ink", width, "title")
  pf.chalName:SetPoint("TOPLEFT", 0, -48)
  pf.chalText = UI.WrapText(r5, 14, "ink", width, "book")
  pf.chalText:SetPoint("TOPLEFT", pf.chalName, "BOTTOMLEFT", 0, -12)
  -- Shared lives chosen: the lives as candles under the words, all lit (UI.Lives; placed by Refresh).
  pf.chalLives = UI.Lives(r5, width)
  pf.chalNote = UI.WrapText(r5, 12, "ink2", width, "book")
  pf.chalNote:SetPoint("TOPLEFT", pf.chalText, "BOTTOMLEFT", 0, -16)
  pf.chalNote:SetText(L.CHAL_NOTE)
  pf.chalLater = UI.WrapText(r5, 12, "ink2", width, "book")
  pf.chalLater:SetPoint("TOPLEFT", pf.chalNote, "BOTTOMLEFT", 0, -10)
  pf.chalLater:SetText(L.CHAL_LATER)
  -- Hovering a challenge: its rule here, in the book's type, in place of what the fellowship takes on (the check of
  -- 1 Nov 2026, 14:32; a tooltip covered this page). Its icon in a gold ring, its banner, its name, its rule and,
  -- in red, why it is greyed (Ironman takes it with it; you chose Healer).
  local pk = CreateFrame("Frame", nil, r5)
  pk:SetPoint("TOPLEFT", 0, -48); pk:SetSize(width, 200)
  pk.ring = UI.Round(pk, "BORDER", 52)
  pk.ring:SetPoint("TOPLEFT", 0, 0)
  Theme:Fill(pk.ring, "gold", 0.9)
  pk.icon = UI.Round(pk, "ARTWORK", 46)
  pk.icon:SetPoint("CENTER", pk.ring)
  pk.group = UI.Text(pk, 11, "ink2", "body")
  pk.group:SetPoint("TOPLEFT", 64, -6)
  pk.name = UI.WrapText(pk, 18, "ink", width - 64, "title")
  pk.name:SetPoint("TOPLEFT", 64, -22)
  pk.rule = UI.WrapText(pk, 15, "ink", width, "book")
  pk.note = UI.WrapText(pk, 13, "B0321E", width, "book")
  pk:Hide()
  pf.peek = pk
  function pf:Peek()
    local row = self.peeking
    local on = row ~= nil
    self.peek:SetShown(on)
    for _, w in ipairs({ self.chalName, self.chalText, self.chalLives, self.chalNote, self.chalLater }) do w:SetAlpha(on and 0 or 1) end
    if not on then return end
    local p = self.peek
    if not UI.SetIcon(p.icon, Ch:Icon(row.key)) then UI.SetIcon(p.icon, ns.ICONS.hist_challenge) end
    p.group:SetText(L["CHAL_GROUP_" .. Ch.GROUP_OF[row.key]:upper()]:upper())
    p.name:SetText(row.tipTitle or "")
    p.rule:SetText(row.tipText or "")
    local nameH = math.max(60, 22 + p.name:GetStringHeight() + 8)
    p.rule:ClearAllPoints(); p.rule:SetPoint("TOPLEFT", 0, -nameH)
    p.note:SetShown(row.tipNote ~= nil)
    p.note:SetText(row.tipNote or "")
    p.note:ClearAllPoints(); p.note:SetPoint("TOPLEFT", p.rule, "BOTTOMLEFT", 0, -12)
  end

  -- Step 4, left: the fellowship (banner, name, who leads it) and the rules as rows, each part with Change.
  local s4 = pf.body.review
  local function section(text, step, yy)
    local h = UI.SectionHeader(s4, width)
    h:SetText(text); h:SetPoint("TOPLEFT", 0, -yy)
    local b = UI.TextButton(s4, L.CHANGE, function() go(step) end, "link", 12)
    b:SetPoint("BOTTOMRIGHT", h, "BOTTOMRIGHT", 0, 6)
    return h, b
  end
  pf.changeFellowship = select(2, section(L.REVIEW_FELLOWSHIP, "fellowship", 0))
  pf.reviewCrest = UI.Crest(s4, 52, 52)
  pf.reviewCrest:SetPoint("TOPLEFT", 2, -38)
  pf.reviewName = UI.Text(s4, 18, "ink", "title")
  pf.reviewName:SetPoint("TOPLEFT", 68, -44); pf.reviewName:SetWidth(width - 68)
  pf.reviewLine = UI.Text(s4, 13, "ink2")
  pf.reviewLine:SetPoint("TOPLEFT", pf.reviewName, "BOTTOMLEFT", 0, -6)
  pf.changeRules = select(2, section(L.REVIEW_RULES, "style", 104))
  pf.reviewStyle = UI.Text(s4, 15, "ink", "book")
  pf.reviewStyle:SetPoint("TOPLEFT", 0, -142)
  pf.reviewRows = {}
  for i = 1, 7 do
    local k = UI.Text(s4, 12, "ink2")
    k:SetPoint("TOPLEFT", 0, -(170 + (i - 1) * 22))
    local v = UI.Text(s4, 13, "ink")
    v:SetPoint("TOPLEFT", 170, -(170 + (i - 1) * 22)); v:SetWidth(width - 170)
    pf.reviewRows[i] = { k = k, v = v }
  end
  -- The challenges (or None), under the rules' seven rows.
  pf.changeChal = select(2, section(L.REVIEW_CHALLENGES, "challenges", 330))
  pf.reviewChal = UI.WrapText(s4, 13, "ink", width, "book")
  pf.reviewChal:SetPoint("TOPLEFT", 0, -366)

  -- Footer: Back on the left page, Next / Create the fellowship on the right.
  pf.prev = UI.TextButton(left, L.BACK, function() C.step = math.max(1, C.step - 1); C.fine = false; W:Refresh() end, "plain", 14)
  pf.prev:SetPoint("BOTTOMLEFT", 0, 0)
  pf.next = UI.TextButton(right, L.NEXT, function() C.step = math.min(#C:Steps(), C.step + 1); C.fine = false; W:Refresh() end, "primary", 14)
  pf.next:SetPoint("BOTTOMRIGHT", 0, 0)
  pf.create = UI.TextButton(right, L.CREATE, function()
    W.page = "heroes"
    if not C:Create() then return end
    C:Reset()
    W.startView = "welcome"
    W:Refresh()
    -- A first fellowship: What's New, once (UI/News.lua).
    ns.News:ShowIfDue()
  end, "primary", 14)
  pf.create:SetPoint("BOTTOMRIGHT", 0, 0)
end

local function refresh(pf)
  local steps = C:Steps()
  C.step = ns.Clamp(C.step, 1, #steps)
  local step, key = C.step, C:StepKey()
  local width = ns.Window.PAGE_W_WIDE
  pf.head:Set(L.FOUND, #steps == 6 and L.CREATE_SUB_6 or L.CREATE_SUB)
  -- Six steps (Your own journey): each label as wide as it is, with the room left shared out (an even sixth cut
  -- "Challenges" into the next disc). Up to five: even slots.
  local even, widths, total = #steps <= 5, {}, 0
  if not even then
    for i, s in ipairs(pf.steps) do
      if steps[i] then
        s.label:SetText(L[C.STEP_LABELS[steps[i]]])
        widths[i] = 28 + s.label:GetStringWidth()
        total = total + widths[i]
      end
    end
  end
  local gap, x = even and 0 or math.max(0, (width - total) / #steps), 0
  for i, s in ipairs(pf.steps) do
    s:SetShown(steps[i] ~= nil)
    if steps[i] then
      local w = even and width / #steps or widths[i] + gap
      s:SetWidth(w)
      s:ClearAllPoints(); s:SetPoint("TOPLEFT", pf.left, "TOPLEFT", x, -pf.stepY)
      x = x + w
      s.label:SetText(L[C.STEP_LABELS[steps[i]]])
      s.disc:SetColorTexture(Theme:RGBA(i <= step and "accent" or "line"))
      s.label:SetTextColor(Theme:RGBA(i == step and "ink" or "ink2"))
    end
  end
  local fine = key == "style" and C.fine
  for k, b in pairs(pf.body) do b:SetShown(k == key) end
  for k, r in pairs(pf.side) do r:SetShown(k == key and not fine) end
  local suggest = ns.Rules.Suggest(C.size)
  local function recommended(on) return on and ("  ·  " .. L.STYLE_RECOMMENDED) or "" end

  -- Step 1.
  if pf.name:GetText() ~= C.name then pf.name:SetText(C.name) end
  pf.role:Refresh()
  for _, card in ipairs(pf.sizes) do
    local on = card.key == C.size
    card:SetSelected(on); card.check:SetShown(on)
  end
  local fac = faction()
  pf.faction:SetText(L.FACTION_LINE:format(fac, fac))
  pf.crest:Set(C.color, C.emblem)
  pf.pname:SetText(fellowshipName())
  pf.swatches:Refresh()
  pf.emblemGrid:Refresh(C.color, C.emblem)

  -- Step 2: the style tiles and what the chosen one means, or the full form (fine-tune). "Recommended" follows the
  -- size (a duo: Strict; a large fellowship: Relaxed).
  pf.stylePick:SetShown(not fine)
  local style = ns.Rules.StyleOf(C.rules)
  for _, tile in ipairs(pf.styles) do
    tile:SetShown(not fine); tile:SetChosen(tile.key == style)
    tile.title:SetText(L["STYLE_" .. tile.key:upper()] .. recommended(tile.key == suggest[1]))
    for _, cell in ipairs(tile.cells) do cell:SetColorTexture(Theme:RGBA(KIND_COLOR[cell.kind], 0.95)) end
  end
  pf.styleBack:SetShown(fine)
  pf.rulesLeft:SetShown(fine); pf.rulesRight:SetShown(fine)
  if key == "style" and not fine then
    pf.styleName:SetText(styleName(style))
    for k, lv in ipairs(C.LevelKinds(C.rules)) do
      local cell = pf.levelCells[k]
      if cell then cell.fill:SetColorTexture(Theme:RGBA(KIND_COLOR[lv.kind], 0.95)) end
    end
    for _, item in ipairs(pf.levelKey) do item.sw:SetColorTexture(Theme:RGBA(KIND_COLOR[item.kind], 0.95)) end
    pf.styleSummary:SetText(ns.Rules.Summary(C.rules))
  end
  if fine then pf.form:Refresh() end

  -- Step 3, and Your own journey's chapters.
  for _, tile in ipairs(pf.presets) do
    local own = tile.key == "own"
    tile:SetChosen(own and C.own or (not C.own and C.preset == tile.key))
    tile.title:SetText(own and (L.PRESET_OWN .. "  ·  " .. L.PRESET_YOU_BUILD)
      or (ns.PRESETS[tile.key].title .. "  ·  " .. L.PRESET_CHAPTERS:format(tile.count) .. recommended(tile.key == suggest[2])))
  end
  if key == "journey" then pf.road:Set(C:Journey(), L.ROAD_HEAD:format(C:JourneyTitle())) end
  if key == "chapters" then pf.editor:Refresh() end

  -- Challenges: every banner's rows ticked or not, under a chosen row what it asks (the PvP realm, Shared lives'
  -- number: what the size suggests until changed, Pauper's gold), and on the right what the fellowship takes on.
  if key ~= "challenges" and pf.peeking then pf.peeking = nil; pf:Peek() end
  if key == "challenges" then
    local Ch = ns.Challenges
    local chosen = C:Challenges()
    for _, b in ipairs(pf.banners) do
      local y = BANNER_HEAD + BANNER_PAD
      for _, r in ipairs(b.rows) do
        local k = r.key
        local included, blocked = C:Included(k), C:Blocked(k)
        local on = C:Chosen(k) and not blocked
        r.chosen = on
        r.check:SetShown(on)
        r.check:SetDesaturated(included); r.check:SetAlpha(included and 0.6 or 1)
        r.tint:SetShown(on)
        r:SetAlpha(blocked and 0.55 or 1)
        local name = k == "hardcore" and Ch:Name("hardcore", C.pvp and "pvp") or L["CHAL_" .. k:upper()]
        r.name:SetText(name)
        r.name:SetTextColor(Theme:RGBA(on and "goldText" or "chipText"))
        local sub = (included and L.CHAL_WITH_IRONMAN) or (blocked and L.CHAL_HEALER_YOU)
          or (k == "oneclass" and on and chosen and L.CHAL_CLASS_YOURS:format(Ch.ClassName(chosen.oneclass))) or nil
        r.sub:SetText(sub or ""); r.sub:SetShown(sub ~= nil)
        -- The tooltip: the rule as it would be now (the lives, the gold, your class).
        local v = (k == "hardcore" and C.pvp and "pvp") or (k == "shared" and C:Lives()) or (k == "pauper" and C:Gold())
          or (k == "oneclass" and ns.Fellowship:MyInfo().class) or true
        r.tipTitle, r.tipText = Ch:Name(k, v), Ch:Rule(k, v)
        r.tipNote = (included and L.CHAL_INCLUDED) or (blocked and L.CHAL_HEALER_LEADER) or nil
        local h = math.max(ROW_MIN, 4 + r.name:GetStringHeight() + (sub and 2 + r.sub:GetStringHeight() or 0) + 4)
        if r.extra then
          r.extra:SetShown(on)
          if on then
            r.extra:ClearAllPoints(); r.extra:SetPoint("TOPLEFT", 24, -h)
            r.extra:Refresh()
            h = h + r.extra:GetHeight() + 4
          end
        end
        r:SetHeight(h)
        r:ClearAllPoints(); r:SetPoint("TOPLEFT", b, "TOPLEFT", BANNER_PAD, -y)
        y = y + h + 2
      end
    end
    local shared = C:Chosen("shared")
    pf.chalName:SetText(Ch:Line(chosen) or L.CHAL_NONE)
    local lines = {}
    for _, k in ipairs(Ch.LIST) do if chosen and chosen[k] then lines[#lines + 1] = Ch:Rule(k, chosen[k]) end end
    -- (Many chosen: one line between them, so the page holds them all.)
    pf.chalText:SetText(#lines > 0 and table.concat(lines, #lines > 3 and "\n" or "\n\n") or L.CHAL_NONE_TEXT)
    local held = chosen and (chosen.oneclass or chosen.nohealers)
    pf.chalNote:SetText(held and (L.CHAL_NOTE .. " " .. L.CHAL_NOTE_HELD) or L.CHAL_NOTE)
    pf.chalNote:SetShown(chosen ~= nil)
    pf.chalLives:SetShown(shared)
    pf.chalNote:ClearAllPoints()
    if shared then
      pf.chalLives:ClearAllPoints(); pf.chalLives:SetPoint("TOPLEFT", pf.chalText, "BOTTOMLEFT", 0, -14)
      pf.chalLives:Set(C:Lives(), C:Lives())
      pf.chalLives:SetTip(L.LIVES_LEFT:format(C:Lives(), C:Lives()))
      pf.chalNote:SetPoint("TOPLEFT", pf.chalLives, "BOTTOMLEFT", 0, -16)
    else
      pf.chalNote:SetPoint("TOPLEFT", pf.chalText, "BOTTOMLEFT", 0, -16)
    end
    -- (Still pointing at a row: its rule as it is now, the lives or the gold just changed.)
    pf:Peek()
  end

  -- Review.
  if key == "review" then
    local rv = C:Review()
    pf.reviewCrest:Set(C.color, C.emblem)
    pf.reviewName:SetText(rv.name)
    pf.reviewLine:SetText(rv.line)
    pf.reviewStyle:SetText(rv.style)
    for i, row in ipairs(pf.reviewRows) do
      local item = rv.rules[i]
      row.k:SetShown(item ~= nil); row.v:SetShown(item ~= nil)
      if item then row.k:SetText(item[1]); row.v:SetText(item[2]) end
    end
    pf.reviewChal:SetText(rv.challenges)
    pf.reviewRoad:Set(C:Journey(), L.REVIEW_JOURNEY_V:format(rv.journey))
  end

  pf.prev:SetShown(step > 1)
  pf.next:SetShown(step < #steps)
  pf.create:SetShown(key == "review")
end

ns.Pages:Register({ id = "create", label = L.TITLE_CREATE, header = "none", build = build, refresh = refresh,
  title = function() return L.TITLE_CREATE, L.ADDON_NAME end })
