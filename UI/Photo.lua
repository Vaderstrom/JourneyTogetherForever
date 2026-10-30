-- Group photo (asked for 29 Oct 2026, after Narcissus's photo mode). The whole screen: the interface hides and the
-- fellowship stands together in one 3D scene, over the world or a backdrop. It is a ModelScene, as Blizzard's own
-- party pose: one camera and one light for everyone, so a gnome stands as tall as a gnome next to a tauren. Click
-- someone to choose them, drag to turn them, give them a pose (or everyone, with nobody chosen); the wheel zooms and
-- right-drag moves the camera. Take the photo hides the controls for the game's own screenshot (the Screenshots
-- folder); it is kept with your pictures (Moments, and Discord when Pictures from runs is on).
-- WoW draws a player only as a unit: yourself, and another member while in your group and near enough. An actor
-- keeps the model it loaded, so members drawn earlier this session stay, as on the Adventurers page (UI/Models.lua);
-- the others are left out and named in a line (decided 29 Oct 2026). Opens only out of combat (hiding the
-- interface is not allowed in a fight) and closes when a fight starts.
-- A big fellowship stands in even rows, each row between the heads of the one in front, the camera looking down
-- more for every row (asked for 10 and more, 30 Oct 2026). Over the world the game's camera goes to first person, so
-- the world is the backdrop; Look around gives the mouse back to the game to walk and turn and find the place, the
-- group staying in front (30 Oct 2026). The camera's distance comes back when the photo closes.
local _, ns = ...
local L = ns.L
local UI, Theme, Combat = ns.UI, ns.Theme, ns.Combat
local F = ns.Fellowship

local PH = {
  actors = {},      -- [name] = actor, kept for the session once its model loaded
  cast = {},        -- who stands in the photo now: { name, actor, x, y, pose, label }
  ROW = 6,          -- members in a row at most; more stand in rows behind, the rows as even as can be
  GAP = 1.1,        -- yards between members in a row, at least (PH:Measure: wider models stand further apart)
  BACK = 1.5,       -- how far behind each row stands
  HEIGHT = 2.1,     -- about a tall member, until PH:Measure knows: the camera's aim and the click areas
  ROOM = 0.2,       -- yards between the widest two neighbours
  HEADROOM = 1.15,  -- the framed height, times the tallest member
  PITCH = 0.06,     -- the camera looks down a little; ROW_PITCH more for each row behind, up to PITCH_MAX
  ROW_PITCH = 0.12,
  PITCH_MAX = 0.4,
  ZOOM = { 0.35, 2.5 }, -- times the framed distance
  GLIDE = 3,        -- seconds the game's camera may take to glide back out (PH:GameCamera)
  TICK = 10,
  taken = 0,
}
ns.Photo = PH

-- Poses: { text, animation, plays once } with the game's animation IDs (0 Stand, 26 Ready1H, 68 EmoteCheer, ...).
-- The game's Emotes table marks Cheer, Salute, Wave and the like ONESHOT: the model plays them once and stands, so
-- they start again every AGAIN seconds (PH:Again). Stand, Ready, Dance, Kneel and Sit go on by themselves. Sit is 97
-- (SitGround, what /sit holds): the check of 30 Oct 2026 found that a player model has no 72 (EmoteSitGround), and
-- stood.
PH.POSES = {
  { "PHOTO_POSE_STAND", 0 }, { "PHOTO_POSE_READY", 26 }, { "PHOTO_POSE_CHEER", 68, true },
  { "PHOTO_POSE_SALUTE", 113, true }, { "PHOTO_POSE_FLEX", 82, true }, { "PHOTO_POSE_ROAR", 74, true },
  { "PHOTO_POSE_WAVE", 67, true }, { "PHOTO_POSE_BOW", 66, true }, { "PHOTO_POSE_LAUGH", 70, true },
  { "PHOTO_POSE_POINT", 84, true }, { "PHOTO_POSE_DANCE", 69 }, { "PHOTO_POSE_KNEEL", 75 }, { "PHOTO_POSE_SIT", 97 },
}
PH.AGAIN = 4 -- seconds from one start of a pose that plays once to the next
-- Backdrops: the world itself (the interface hidden), a dark studio, the chapter's picture, the dungeon's.
PH.BACKDROPS = { "world", "studio", "chapter", "dungeon" }

---------------------------------------------------------------------------
-- Where everyone stands
---------------------------------------------------------------------------
-- How many rows n stand in: rows of `row` at most.
function PH.Rows(n, row) return math.max(1, math.ceil(n / row)) end

-- n places in rows of `row` at most, as even as can be (10 in two rows of five, the front row the fuller one): the
-- first in the middle of the front row, the next beside them in turn (right, left, right, ...), each row behind the
-- last. Each row stands between the heads of the row in front (straight behind it, the faces were hidden): half a
-- place to the side when the counts alone do not do it, to the right and the left in turn. { x (forward), y (right) }
-- in yards, the front row at x = 0.
function PH.Places(n, row, gap, back)
  local out = {}
  local rows = PH.Rows(n, row)
  local i, phase, sign = 0, nil, 1
  for r = 0, rows - 1 do
    local count = math.ceil((n - i) / (rows - r))
    -- Where the row stands across, in places: an even count is half a place off the middle.
    local base = count % 2 == 0 and 0.5 or 0
    local off = 0
    if phase then
      off = (phase + 0.5 - base) % 1
      if off > 0 then off, sign = off * sign, -sign end
    end
    phase = (base + off) % 1
    for k = 1, count do
      local side = k % 2 == 0 and k / 2 or -(k - 1) / 2
      out[#out + 1] = { x = -r * back, y = (side - base + off) * gap }
    end
    i = i + count
  end
  return out
end

-- How far the camera looks down for a group of n: more for every row, so the rows behind show over the heads.
function PH.Pitch(n, row)
  return math.min(PH.PITCH_MAX, PH.PITCH + PH.ROW_PITCH * (PH.Rows(n, row) - 1))
end

-- How far the camera stands to fit a row of n (and the rows behind): the first guess, before PH:Fit measures.
function PH.Distance(n, row, gap)
  local front = math.min(n, row)
  local rows = math.ceil(math.max(n, 1) / row)
  return math.max(3.6, (front - 1) * gap * 0.85 + 2.6) + (rows - 1) * 0.8
end

-- The camera's distance and height that frame a group: `span` is how tall and wide it shows now (in pixels), `mid`
-- where its middle shows (pixels from the bottom). The group should take FILL of the screen's height (or WIDE of
-- its width) with its middle at AIM. A thing's size on the screen goes with 1 / distance, so one step comes close
-- and a second one lands.
PH.FILL, PH.WIDE, PH.AIM = 0.62, 0.8, 0.5
function PH.Framing(dist, tz, spanH, spanW, mid, screenW, screenH, height)
  local k = math.max(spanH / (screenH * PH.FILL), spanW / (screenW * PH.WIDE))
  if k <= 0 then return dist, tz end
  -- pixels per yard after the move; the middle moves towards the screen's centre as the camera backs off.
  local perYard = spanH / height / k
  local centre = screenH / 2
  local midAfter = centre + (mid - centre) / k
  return dist * k, tz + (midAfter - screenH * PH.AIM) / perYard
end

---------------------------------------------------------------------------
-- Models
---------------------------------------------------------------------------
-- The pose an actor holds. A model loads after SetModelByUnit returns and then takes the unit's own stance: you
-- crouched as on your mount in the twelve-person photo (seen in the check, 30 Oct 2026). It is set again once loaded.
local function hold(a, pose)
  a.anim, a.once, a.since = pose[2], pose[3], GetTime()
  a:SetAnimation(pose[2])
end
local function onLoaded(a) if a.anim then a:SetAnimation(a.anim) end end
local function newActor(scene)
  local a = scene:CreateActor()
  if a.SetScript then pcall(a.SetScript, a, "OnModelLoaded", onLoaded) end
  return a
end

-- A pose that plays once starts again every AGAIN seconds (a ticker while the photo is open). The game says nothing
-- when it ends: an actor made in Lua takes no OnAnimFinished handler (check of 30 Oct 2026; only Blizzard's XML
-- templates have one). A frame of standing first, as setting the same animation again may not start it over. PH.restarts
-- counts them, for the self-test.
function PH:Again(now)
  for _, c in ipairs(self.cast or {}) do
    local a = c.actor
    if a.once and now - a.since >= self.AGAIN then
      a.since = now
      self.restarts = (self.restarts or 0) + 1
      a:SetAnimation(0)
      C_Timer.After(0, function() if a.once then a:SetAnimation(a.anim) end end)
    end
  end
end

-- Loads a member's model when the game can draw them now (also with the photo closed, while grouped). Returns the
-- actor once it has a model (now or earlier this session). No actors are made in combat.
function PH:Load(name)
  local a = self.actors[name]
  local unit = ns.Models:DrawableUnit(name)
  if not unit or not self.frame then return a and a.loaded and a or nil end
  if not a then
    if Combat:InCombat() then return nil end
    a = newActor(self.frame.scene)
    self.actors[name] = a
  end
  -- sheathed weapons look calmer in a photo; the game says false when the unit cannot be drawn.
  if a:SetModelByUnit(unit, true) ~= false then a.loaded = true end
  return a.loaded and a or nil
end

-- A stand-in (developer tools and the tour, one character): your own model under another member's name.
function PH:StandIn(name)
  local key = "standin:" .. name
  local a = self.actors[key]
  if not a then
    if Combat:InCombat() then return nil end
    a = newActor(self.frame.scene)
    self.actors[key] = a
  end
  if a:SetModelByUnit("player", true) ~= false then a.loaded = true end
  return a.loaded and a or nil
end

-- In the background: the members in your group whom the game can draw now.
function PH:Tick()
  local f = F:Current()
  if not f or not self.frame or not (IsInGroup and IsInGroup()) then return end
  for name in pairs(f.members) do
    if name ~= ns.Me() then self:Load(name) end
  end
end

---------------------------------------------------------------------------
-- The screen
---------------------------------------------------------------------------
local function shadow(fs) fs:SetShadowOffset(1, -1); fs:SetShadowColor(0, 0, 0, 1) end

-- A band of black fading out from one edge (top or bottom), so the words over a bright world stay readable.
local function fade(parent, edge, h, alpha)
  local t = parent:CreateTexture(nil, "BORDER")
  t:SetPoint(edge .. "LEFT"); t:SetPoint(edge .. "RIGHT"); t:SetHeight(h)
  t:SetColorTexture(1, 1, 1, 1)
  local dark, clear = CreateColor(0, 0, 0, alpha), CreateColor(0, 0, 0, 0)
  if edge == "TOP" then t:SetGradient("VERTICAL", clear, dark) else t:SetGradient("VERTICAL", dark, clear) end
  return t
end

-- A stepper for the bar: the game's page arrows round a light label.
local function stepper(parent, width, onDown, onUp, getText)
  local s = UI.Stepper(parent, onDown, onUp, getText)
  s.value:SetWidth(width)
  -- As a role, so the theme does not paint it back to the book's ink (dark on the dark bar; seen in the tour).
  Theme:TextColor(s.value, "goldText")
  shadow(s.value)
  s:SetWidth(26 + 4 + width + 4 + 26)
  s:Refresh()
  return s
end

function PH:Build()
  if self.frame then return self.frame end
  if Combat:InCombat() then return nil end
  self.backdrop, self.showNames, self.showCaption = "world", true, true
  -- No parent: it stays when the interface (UIParent) hides; the interface's scale, so sizes match the book's.
  local f = CreateFrame("Frame", nil, nil)
  f:SetFrameStrata("FULLSCREEN_DIALOG")
  f:SetScale(UIParent:GetEffectiveScale())
  f:SetAllPoints(UIParent)
  f:EnableMouse(true)
  f:EnableKeyboard(true)
  -- Escape closes it; every other key goes on to the game (the screenshot key too).
  f:SetScript("OnKeyDown", function(frame, key)
    local esc = key == "ESCAPE"
    frame:SetPropagateKeyboardInput(not esc)
    if esc then PH:Close() end
  end)
  f:Hide()

  -- The backdrop (none over the world) and a darker veil over pictures.
  f.bg = f:CreateTexture(nil, "BACKGROUND", nil, -8)
  f.bg:SetAllPoints()
  f.veil = f:CreateTexture(nil, "BACKGROUND", nil, -7)
  f.veil:SetAllPoints()
  f.veil:SetColorTexture(0, 0, 0, 0.35)
  f.fadeTop = fade(f, "TOP", 150, 0.6)
  f.fadeBottom = fade(f, "BOTTOM", 190, 0.75)

  -- The scene: one camera, one light.
  local s = CreateFrame("ModelScene", nil, f)
  s:SetAllPoints()
  s:SetCameraNearClip(0.1)
  s:SetCameraFarClip(200)
  s:SetCameraFieldOfView(0.75)
  s:SetLightVisible(true)
  s:SetLightType((Enum and Enum.ModelLightType and Enum.ModelLightType.Directional) or 1)
  s:SetLightDirection(-0.7, 0.3, -0.65)
  s:SetLightAmbientColor(0.6, 0.57, 0.55)
  s:SetLightDiffuseColor(0.95, 0.9, 0.82)
  s:EnableMouse(true)
  s:EnableMouseWheel(true)
  s:SetScript("OnMouseDown", function(_, button)
    local x, y = GetCursorPosition()
    PH.drag = { button = button, x = x, y = y }
    if button == "LeftButton" then PH:Choose(PH:At(x, y)) end
  end)
  s:SetScript("OnMouseUp", function() PH.drag = nil end)
  s:SetScript("OnUpdate", function() PH:Dragging() end)
  s:SetScript("OnMouseWheel", function(_, delta) PH:Zoom(delta) end)
  f.scene = s

  -- Names under everyone's feet, above the scene.
  f.over = CreateFrame("Frame", nil, f)
  f.over:SetAllPoints()
  f.over:SetFrameLevel(s:GetFrameLevel() + 5)
  f.labels = {}

  -- The caption, top left: the crest, the fellowship's name, and where and when.
  f.caption = CreateFrame("Frame", nil, f.over)
  f.caption:SetPoint("TOPLEFT", 40, -36)
  f.caption:SetSize(700, 72)
  f.crest = UI.Crest(f.caption, 52, 64)
  f.crest:SetPoint("TOPLEFT")
  f.title = UI.Text(f.caption, 28, "goldText", "title")
  f.title:SetPoint("TOPLEFT", f.crest, "TOPRIGHT", 16, -6)
  shadow(f.title)
  f.sub = UI.Text(f.caption, 14, "chipText")
  f.sub:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -6)
  shadow(f.sub)

  -- The controls: a dark band at the bottom, the hint and who is missing above it. All hidden for the photo.
  f.chrome = CreateFrame("Frame", nil, f.over)
  f.chrome:SetAllPoints()
  local bar = CreateFrame("Frame", nil, f.chrome)
  bar:SetPoint("BOTTOMLEFT"); bar:SetPoint("BOTTOMRIGHT"); bar:SetHeight(60)
  bar.bg = bar:CreateTexture(nil, "BACKGROUND")
  bar.bg:SetAllPoints(); bar.bg:SetColorTexture(0.03, 0.02, 0.01, 0.82)
  bar.line = bar:CreateTexture(nil, "BORDER")
  bar.line:SetPoint("TOPLEFT"); bar.line:SetPoint("TOPRIGHT"); bar.line:SetHeight(1)
  bar.line:SetColorTexture(Theme:RGBA("gold"))
  f.bar = bar
  f.pose = stepper(bar, 220, function() PH:StepPose(-1) end, function() PH:StepPose(1) end, function() return PH:PoseText() end)
  f.pose:SetPoint("LEFT", 24, 0)
  f.backdrop = stepper(bar, 190, function() PH:StepBackdrop(-1) end, function() PH:StepBackdrop(1) end,
    function() return L.PHOTO_BACKDROP:format(L["PHOTO_BG_" .. PH.backdrop:upper()]) end)
  f.backdrop:SetPoint("LEFT", f.pose, "RIGHT", 24, 0)
  f.names = UI.Checkbox(bar, function() return PH.showNames end, function(v) PH.showNames = v; PH:Labels() end)
  f.names:SetPoint("LEFT", f.backdrop, "RIGHT", 24, 0)
  f.namesText = UI.Text(bar, 13, "goldText")
  f.namesText:SetPoint("LEFT", f.names, "RIGHT", 2, 0)
  f.namesText:SetText(L.PHOTO_NAMES)
  f.cap = UI.Checkbox(bar, function() return PH.showCaption end, function(v) PH.showCaption = v; f.caption:SetShown(v) end)
  f.cap:SetPoint("LEFT", f.namesText, "RIGHT", 16, 0)
  f.capText = UI.Text(bar, 13, "goldText")
  f.capText:SetPoint("LEFT", f.cap, "RIGHT", 2, 0)
  f.capText:SetText(L.PHOTO_CAPTION)
  f.close = UI.TextButton(bar, L.PHOTO_CLOSE, function() PH:Close() end, "plain", 13)
  f.close:SetPoint("RIGHT", -24, 0)
  f.take = UI.TextButton(bar, L.PHOTO_TAKE, function() PH:Take() end, "primary", 14)
  f.take:SetPoint("RIGHT", f.close, "LEFT", -10, 0)
  f.look = UI.TextButton(bar, L.PHOTO_LOOK, function() PH:Look(true) end, "plain", 13)
  f.look:SetPoint("RIGHT", f.take, "LEFT", -10, 0)
  f.hint = UI.Text(f.chrome, 12, "chipText", "body", "CENTER")
  f.hint:SetPoint("BOTTOM", bar, "TOP", 0, 10)
  f.hint:SetText(L.PHOTO_HINT)
  shadow(f.hint)
  f.missing = UI.Text(f.chrome, 13, "goldText", "body", "CENTER")
  f.missing:SetPoint("BOTTOM", f.hint, "TOP", 0, 8)
  shadow(f.missing)
  -- Looking around: what to do, and the way back to the photo.
  f.looking = CreateFrame("Frame", nil, f.over)
  f.looking:SetPoint("BOTTOMLEFT"); f.looking:SetPoint("BOTTOMRIGHT"); f.looking:SetHeight(90)
  f.looking.back = UI.TextButton(f.looking, L.PHOTO_LOOK_DONE, function() PH:Look(false) end, "primary", 14)
  f.looking.back:SetPoint("BOTTOM", 0, 18)
  f.looking.text = UI.Text(f.looking, 13, "goldText", "body", "CENTER")
  f.looking.text:SetPoint("BOTTOM", f.looking.back, "TOP", 0, 10)
  f.looking.text:SetText(L.PHOTO_LOOK_HINT)
  shadow(f.looking.text)
  f.looking:Hide()
  -- After a photo: where it went.
  f.saved = UI.Text(f.over, 14, "goldText", "body", "CENTER")
  f.saved:SetPoint("TOP", 0, -40)
  shadow(f.saved)
  f.saved:Hide()

  self.frame = f
  return f
end

---------------------------------------------------------------------------
-- Opening, arranging, closing
---------------------------------------------------------------------------
-- The dungeon of this photo: the one you are in, or the one whose picture banner is up (UI/Picture.lua).
function PH:DungeonHere()
  local _, kind, _, _, _, _, _, instID = GetInstanceInfo()
  if kind == "party" or kind == "raid" then
    local keys = ns.Clears:KeysHere(instID, (GetInstanceInfo()))
    if keys[1] then return keys[1] end
  end
  local pic = ns.Picture
  return pic and pic.frame and pic.frame:IsShown() and pic.key or nil
end

-- Who stands in the photo, the leader first (in the middle): those with a model, the others missing. With
-- standIns (developer tools), the missing stand in as yourself; extra adds pretend members (a big fellowship).
function PH:Cast(f, standIns, extra)
  local names = F:Members(f)
  for _, n in ipairs(extra or {}) do names[#names + 1] = n end
  table.sort(names, function(a, b)
    if (a == f.leader) ~= (b == f.leader) then return a == f.leader end
    return a < b
  end)
  local cast, missing = {}, {}
  for _, name in ipairs(names) do
    local a = self:Load(name)
    if not a and standIns then a = self:StandIn(name) end
    if a then cast[#cast + 1] = { name = name, actor = a } else missing[#missing + 1] = name end
  end
  return cast, missing
end

function PH:Open(opts)
  opts = opts or {}
  if Combat:InCombat() then ns:Toast(nil, L.PHOTO_TITLE, L.PHOTO_COMBAT); return false end
  local f = F:Current()
  if not f or not self:Build() then return false end
  local fr = self.frame
  fr:SetScale(UIParent:GetEffectiveScale()) -- the interface's scale may have changed
  for _, a in pairs(self.actors) do a:Hide() end
  local cast, missing = self:Cast(f, opts.standIns, opts.extra)
  self.cast, self.missing, self.chosen, self.key = cast, missing, nil, self:DungeonHere()
  self.gap, self.height, self.measured = self.GAP, self.HEIGHT, false
  -- Everyone stands again, and the bar says so (it kept the last photo's "Everyone: Salute"; seen in the check).
  self.allPose = nil
  self.pitch = PH.Pitch(#cast, self.ROW)
  local places = PH.Places(#cast, self.ROW, self.gap, self.BACK)
  for i, c in ipairs(cast) do
    c.x, c.y, c.pose = places[i].x, places[i].y, 1
    c.actor:SetPosition(c.x, c.y, 0)
    c.actor:SetYaw(0)
    hold(c.actor, self.POSES[1])
    c.actor:Show()
    local label = fr.labels[i] or UI.Text(fr.over, 14, "white", "title", "CENTER")
    shadow(label)
    fr.labels[i] = label
    c.label = label
  end
  for i = #cast + 1, #fr.labels do fr.labels[i]:Hide() end
  -- The caption: the fellowship, then the dungeon (or the chapter) and the day.
  fr.crest:Set(f.color, f.emblem)
  fr.title:SetText(f.name)
  local d = self.key and ns.Dungeon(self.key)
  local ch = ns.Journey:Current(f)
  local where = d and d[2] or (ch and L.PHOTO_CHAPTER:format(ns.Journey.Roman(ch.n), ch.name) or L.BN_JOURNEY_DONE)
  fr.sub:SetText(L.PHOTO_SUB:format(where, date(L.MO_DAY)))
  fr.caption:SetShown(self.showCaption)
  fr.missing:SetText(#missing > 0 and L.PHOTO_MISSING:format(ns.Clears.AndList(self:Shorts(missing))) or "")
  -- The camera: a first guess, everyone in, the middle of the front row at chest height; PH:Fit measures and
  -- corrects it once the scene is on the screen.
  self.dist, self.tx, self.ty, self.tz = PH.Distance(#cast, self.ROW, self.GAP), 0, 0, 1.05
  if self.backdrop == "dungeon" and not self.key then self.backdrop = "world" end
  self:Camera()
  self.zoom = nil
  self:SetBackdrop(self.backdrop)
  self:Look(false)
  fr.pose:Refresh(); fr.names:Refresh(); fr.cap:Refresh()
  -- The interface goes; the photo stays (it has no parent). The book comes back with the interface.
  self.book = ns.Window:IsOpen()
  if UIParent:IsShown() then self.hidUI = true; UIParent:Hide() end
  self:WorldNames(false)
  fr:Show()
  -- The scene is drawn from the next frame on: measure and frame the group then, twice, then the names.
  C_Timer.After(0, function()
    PH:Fit()
    C_Timer.After(0, function() PH:Fit(); PH:Labels(); PH:Hold() end)
  end)
  -- A model that loads late is measured a moment later; the group is spaced and framed again then.
  C_Timer.After(0.4, function()
    if PH:IsOpen() and not PH.measured then PH:Fit(); PH:Fit(); PH:Labels() end
    if PH:IsOpen() then PH:Hold() end
  end)
  if self.again then self.again:Cancel() end
  self.again = C_Timer.NewTicker(0.25, function() PH:Again(GetTime()) end)
  return true
end

-- Everyone in their pose again, once the models have loaded (see hold).
function PH:Hold()
  for _, c in ipairs(self.cast or {}) do hold(c.actor, self.POSES[c.pose]) end
end

function PH:IsOpen() return self.frame ~= nil and self.frame:IsShown() end

function PH:Close()
  if not self.frame then return end
  self:Look(false)
  self.frame:Hide()
  self.drag = nil
  if self.again then self.again:Cancel(); self.again = nil end
  self:WorldNames(true)
  self:GameCamera(false)
  if self.hidUI then
    self.hidUI = nil
    -- UIParent's OnShow closes the game's windows (CloseAllWindows), and the book is one of them (UISpecialFrames):
    -- it closed under the photo (seen in the check, 29 Oct 2026). Out of that list while the interface comes back.
    local name = ns.Window.frame and ns.Window.frame:GetName()
    local at
    for i, n in ipairs(UISpecialFrames or {}) do if n == name then at = i end end
    if at then table.remove(UISpecialFrames, at) end
    UIParent:Show()
    if at then table.insert(UISpecialFrames, at, name) end
    if self.book and not ns.Window:IsOpen() then ns.Window.frame:Show() end
  end
  self.book = nil
end

-- Nameplates and the names over heads belong to the world, not the interface: they stay when it hides and stood
-- over the photo (seen in the check). Off while the photo is open; saved first, so a reload with the photo open
-- puts them back at the next login.
-- Hostile, interactive and special NPCs and pets have names of their own ("Gnoll Assailant" stood over the photo in
-- the check of 30 Oct 2026); a name this client does not have is left alone.
PH.WORLD_CVARS = { "nameplateShowAll", "nameplateShowEnemies", "nameplateShowFriends", "UnitNameNPC",
  "UnitNameOwn", "UnitNameFriendlyPlayerName", "UnitNameEnemyPlayerName", "UnitNameNonCombatCreatureName",
  "UnitNameHostleNPC", "UnitNameInteractiveNPC", "UnitNameFriendlySpecialNPCName", "UnitNameFriendlyPetName",
  "UnitNameFriendlyGuardianName", "UnitNameFriendlyTotemName", "UnitNameFriendlyMinionName", "UnitNameEnemyPetName",
  "UnitNameEnemyGuardianName", "UnitNameEnemyTotemName", "UnitNameEnemyMinionName" }
function PH:WorldNames(on)
  local cv = C_CVar
  if not cv or not ns.char then return end
  if on then
    for k, v in pairs(ns.char.photoCVars or {}) do pcall(cv.SetCVar, k, v) end
    ns.char.photoCVars = nil
  elseif not ns.char.photoCVars then
    local saved = {}
    for _, k in ipairs(self.WORLD_CVARS) do
      local v = cv.GetCVar(k)
      if v ~= nil and v ~= "0" then saved[k] = v; pcall(cv.SetCVar, k, "0") end
    end
    ns.char.photoCVars = saved
  end
end

-- Over the world, the game's camera in first person: your own character goes, and the world is the backdrop. Its
-- distance is saved first (also over a reload with the photo open) and comes back when the photo closes: all the
-- way in, then out by it (the camera glides; measured mid-glide, the difference came out wrong). CameraZoomIn and
-- CameraZoomOut are the mouse wheel's own functions, open to addons. Given back a moment ago, the camera may still be
-- gliding out: then the distance it is going to is saved, not where it is (the tour's photos one after the other).
function PH:GameCamera(first)
  if not (GetCameraZoom and CameraZoomIn and CameraZoomOut) or not ns.char then return end
  if first then
    if ns.char.photoZoom == nil then
      local last = self.lastZoom
      local gliding = last and GetTime() - last.t < self.GLIDE
      ns.char.photoZoom = gliding and last.v or GetCameraZoom()
    end
    CameraZoomIn(50)
  elseif ns.char.photoZoom ~= nil then
    local was = ns.char.photoZoom
    ns.char.photoZoom = nil
    if type(was) == "number" then
      CameraZoomIn(50); CameraZoomOut(was)
      self.lastZoom = { v = was, t = GetTime() }
    end
  end
end

-- Look around (the world backdrop): the controls go and the mouse and the wheel go to the game, so you walk, turn
-- and zoom as always to find the place; the group stays where it stands on the screen. Back to the photo with the
-- button (Esc closes the photo as always).
function PH:Look(on)
  local fr = self.frame
  if not fr then return end
  self.looking = on and true or false
  fr:EnableMouse(not on)
  fr.scene:EnableMouse(not on)
  fr.scene:EnableMouseWheel(not on)
  fr.looking:SetShown(on)
  if on then self.drag = nil; self:Choose(nil) end
  self:Chrome(not on)
end

-- How wide and tall the widest and the tallest member stand, from the models' own bounds (yards), or nil while the
-- game cannot say. A troll's shoulders and weapons took more than GAP and overlapped the neighbour, and the heads
-- came near the top of the screen (seen in the seventh check).
function PH:Measure()
  local wide, tall
  for _, c in ipairs(self.cast) do
    local a = c.actor
    if not a.GetActiveBoundingBox then return nil end
    local ok, x1, y1, z1, x2, y2, z2 = pcall(a.GetActiveBoundingBox, a)
    -- (Two vectors in some clients, six numbers in others.)
    if ok and type(x1) == "table" and type(y1) == "table" then
      x1, y1, z1, x2, y2, z2 = x1.x, x1.y, x1.z, y1.x, y1.y, y1.z
    end
    if not ok or type(z2) ~= "number" or type(z1) ~= "number" or z2 - z1 <= 0 then return nil end
    -- Across the row, whichever way the model is drawn: its width or its depth, the larger.
    wide = math.max(wide or 0, math.abs(y2 - y1), math.abs(x2 - x1))
    tall = math.max(tall or 0, z2 - z1)
  end
  return wide, tall
end

-- Spaces the cast by the widest member and frames by the tallest, once the models can be measured.
function PH:Spread()
  if self.measured then return end
  local wide, tall = self:Measure()
  if not wide then return end
  self.measured = true
  self.gap = ns.Clamp(wide + self.ROOM, self.GAP, 3)
  self.height = ns.Clamp(tall, 1, 4)
  local places = PH.Places(#self.cast, self.ROW, self.gap, self.BACK)
  for i, c in ipairs(self.cast) do
    c.x, c.y = places[i].x, places[i].y
    c.actor:SetPosition(c.x, c.y, 0)
  end
end

-- Frames the group from what the scene draws (Project3DPointTo2D): the guessed distance showed only legs, about
-- 2.5 times too close (seen in the check, 29 Oct 2026). Each member's feet and the tallest one's head with room
-- above it, and half a place to each side.
function PH:Fit()
  local fr = self.frame
  if not fr or not fr:IsShown() or #self.cast == 0 then return end
  self:Spread()
  local s = fr.scene
  local eff = s:GetEffectiveScale()
  local w, h = (s:GetWidth() or 0) * eff, (s:GetHeight() or 0) * eff
  if w <= 0 or h <= 0 then return end
  local lo, hi, left, right
  local half, top = (self.gap or self.GAP) / 2, (self.height or self.HEIGHT) * self.HEADROOM
  for _, c in ipairs(self.cast) do
    for _, p in ipairs({ { c.y - half, 0 }, { c.y + half, top } }) do
      local px, py = s:Project3DPointTo2D(c.x, p[1], p[2])
      if not px or not py then return end
      lo, hi = math.min(lo or py, py), math.max(hi or py, py)
      left, right = math.min(left or px, px), math.max(right or px, px)
    end
  end
  if hi - lo < 1 then return end
  self.dist, self.tz = PH.Framing(self.dist, self.tz, hi - lo, right - left, (lo + hi) / 2, w, h, top)
  self.fit = self.dist
  self:Camera()
end

function PH:Shorts(names)
  local out = {}
  for i, n in ipairs(names) do out[i] = ns.Short(n) end
  return out
end

-- The camera on its target, from the front (the actors face +x), a little above.
function PH:Camera()
  local s = self.frame.scene
  local p = self.pitch or self.PITCH
  s:SetCameraOrientationByYawPitchRoll(math.pi, p, 0)
  s:SetCameraPosition(self.tx + self.dist * math.cos(p), self.ty, self.tz + self.dist * math.sin(p))
end

-- The wheel: from close up to far, measured from the framing PH:Fit found.
function PH:Zoom(delta)
  local fit = self.fit or self.dist
  self.dist = ns.Clamp(self.dist * (delta > 0 and 0.9 or 1.1), fit * self.ZOOM[1], fit * self.ZOOM[2])
  self:Camera()
  self:Labels()
end

function PH:SetBackdrop(kind)
  local fr, f = self.frame, F:Current()
  self.backdrop = kind
  -- The interface's size: the same as the photo's (same scale and place), and known before the photo is first shown.
  local w, h = UIParent:GetWidth(), UIParent:GetHeight()
  if kind == "world" then self:GameCamera(true) end
  fr.look:SetShown(kind == "world")
  fr.bg:SetShown(kind ~= "world")
  fr.veil:SetShown(kind == "chapter" or kind == "dungeon")
  fr.bg:SetTexCoord(0, 1, 0, 1)
  if kind == "studio" then
    fr.bg:SetColorTexture(1, 1, 1, 1)
    fr.bg:SetGradient("VERTICAL", CreateColor(0.02, 0.015, 0.01, 1), CreateColor(0.16, 0.12, 0.08, 1))
  elseif kind == "chapter" and f then
    fr.bg:SetGradient("VERTICAL", CreateColor(1, 1, 1, 1), CreateColor(1, 1, 1, 1))
    ns.Pages:SetChapterArt(fr.bg, ns.Pages:ArtOf(f, ns.Journey:CurrentIndex(f)) or 1, w, h, 0.5)
  elseif kind == "dungeon" and self.key then
    fr.bg:SetGradient("VERTICAL", CreateColor(1, 1, 1, 1), CreateColor(1, 1, 1, 1))
    ns.SetDungeonArt(fr.bg, self.key, w, h)
  end
  fr.backdrop:Refresh()
end

function PH:StepBackdrop(dir)
  local list = {}
  for _, k in ipairs(self.BACKDROPS) do if k ~= "dungeon" or self.key then list[#list + 1] = k end end
  local at = 1
  for i, k in ipairs(list) do if k == self.backdrop then at = i end end
  self:SetBackdrop(list[(at - 1 + dir) % #list + 1])
end

-- The pose of the one chosen, or everyone's (nobody chosen).
function PH:PoseText()
  local c = self.chosen and self.cast[self.chosen]
  local pose = self.POSES[(c and c.pose) or self.allPose or 1]
  return L.PHOTO_POSE:format(c and ns.Short(c.name) or L.PHOTO_EVERYONE, L[pose[1]])
end

function PH:StepPose(dir)
  local n = #self.POSES
  local c = self.chosen and self.cast[self.chosen]
  if c then
    c.pose = (c.pose - 1 + dir) % n + 1
    hold(c.actor, self.POSES[c.pose])
  else
    self.allPose = ((self.allPose or 1) - 1 + dir) % n + 1
    for _, x in ipairs(self.cast) do x.pose = self.allPose end
    self:Hold()
  end
  self.frame.pose:Refresh()
end

-- Chooses the one at index i (nil: nobody); their name turns gold.
function PH:Choose(i)
  self.chosen = i
  for k, c in ipairs(self.cast) do c.label:SetTextColor(Theme:RGBA(k == i and "goldText" or "white")) end
  self.frame.pose:Refresh()
end

-- A point on the ground or above it, on the screen (physical pixels from the screen's corner), or nil.
function PH:Screen(x, y, z)
  local s = self.frame.scene
  local px, py = s:Project3DPointTo2D(x, y, z)
  if not px or not py then return nil end
  local eff = s:GetEffectiveScale()
  return (s:GetLeft() or 0) * eff + px, (s:GetBottom() or 0) * eff + py
end

-- Who is under the cursor (physical pixels): the one whose body the point is on, the nearest in front first.
function PH:At(cx, cy)
  local best, bestD
  for i, c in ipairs(self.cast) do
    local fx, fy = self:Screen(c.x, c.y, 0)
    local _, hy = self:Screen(c.x, c.y, self.height or self.HEIGHT)
    if fx and hy then
      local half = math.max(24, (hy - fy) * 0.22)
      local d = math.abs(cx - fx) - c.x * 10 -- the front row wins a tie
      if math.abs(cx - fx) <= half and cy >= fy - 12 and cy <= hy + 12 and (not bestD or d < bestD) then best, bestD = i, d end
    end
  end
  return best
end

-- Names under the feet of the front row and over the heads of the rows behind (their feet are hidden), while Names
-- is ticked.
function PH:Labels()
  local fr = self.frame
  if not fr then return end
  local s = fr.scene
  local eff = s:GetEffectiveScale()
  local top = (self.height or self.HEIGHT) * 1.02
  for _, c in ipairs(self.cast) do
    local front = c.x > -0.01
    local px, py = s:Project3DPointTo2D(c.x, c.y, front and 0 or top)
    local show = self.showNames and px ~= nil and py ~= nil
    c.label:SetShown(show == true)
    if show then
      c.label:SetText(ns.Short(c.name))
      c.label:ClearAllPoints()
      if front then c.label:SetPoint("TOP", s, "BOTTOMLEFT", px / eff, py / eff - 6)
      else c.label:SetPoint("BOTTOM", s, "BOTTOMLEFT", px / eff, py / eff + 4) end
    end
  end
end

-- Left-drag turns the one chosen; right-drag moves the camera.
function PH:Dragging()
  local d = self.drag
  if not d then return end
  local x, y = GetCursorPosition()
  local dx, dy = x - d.x, y - d.y
  if dx == 0 and dy == 0 then return end
  d.x, d.y = x, y
  local c = self.chosen and self.cast[self.chosen]
  if d.button == "LeftButton" and c then
    c.yaw = (c.yaw or 0) + dx / 90
    c.actor:SetYaw(c.yaw)
  elseif d.button == "RightButton" then
    local k = self.dist / 900
    self.ty, self.tz = self.ty - dx * k, self.tz - dy * k
    self:Camera()
    self:Labels()
  end
end

-- The controls and hints; off for the photo itself (the caption and the names stay, as chosen).
function PH:Chrome(on)
  local fr = self.frame
  fr.chrome:SetShown(on)
  if not on then for _, c in ipairs(self.cast) do c.label:SetTextColor(Theme:RGBA("white")) end
  elseif self.chosen then self:Choose(self.chosen) end
end

-- The photo: the controls go, the game's screenshot, the controls come back. Kept with your pictures.
function PH:Take()
  local fr = self.frame
  if not self:IsOpen() then return false end
  self:Chrome(false)
  fr.saved:Hide()
  C_Timer.After(0.1, function()
    if Screenshot then Screenshot() end
    C_Timer.After(0.4, function()
      if PH:IsOpen() then PH:Chrome(true); fr.saved:Show() end
    end)
  end)
  self.taken = self.taken + 1
  fr.saved:SetText(L.PHOTO_SAVED:format(self.taken))
  local names = {}
  for i, c in ipairs(self.cast) do names[i] = c.name end
  ns.Moments:Picture(F:Current(), self.key, names, true)
  return true
end

ns:On("LOGIN", function()
  PH:WorldNames(true) -- after a reload with the photo open
  PH:GameCamera(false)
  Combat:AfterCombat(function() PH:Build() end)
  C_Timer.NewTicker(PH.TICK, function() PH:Tick() end)
end)
ns:RegisterEvent("GROUP_ROSTER_UPDATE", function() PH:Tick() end)
-- A fight: back to the interface (this event comes before the lockdown).
ns:RegisterEvent("PLAYER_REGEN_DISABLED", function() if PH:IsOpen() then PH:Close() end end)
