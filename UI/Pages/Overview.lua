-- Overview (SPEC §4.4, U139, the rebuild of 9 Nov 2026): the glance, one flat sheet across both pages that fits the
-- book without scrolling. At the top the chapter's banner across the sheet: its picture (drifting slowly), its name and
-- levels, the shared lives, and along its lower edge Where we stand (the level track, one line, the room for the
-- dungeon quests as the answer). Below three cards side by side, each on its own picture with a link at its foot:
-- Focus now (Together:Focus) on its dungeon's, Since last time (Since:Digest) on the Chronicle's notice board and Coming
-- up (the first step for a later dungeon, the next two Gatherings, the next chapter) on the road ahead. Opening it, the
-- cards fade in one after another (U148-U155, the owner's picks of 9 Nov 2026). The detail lives on the Chapter page.
local _, ns = ...
local L = ns.L
local UI, Theme = ns.UI, ns.Theme
local J = ns.Journey

local TOP_H, STRIP_H, GAP, PAD = 204, 108, 22, 16
local DRIFT = 10 -- how far the banner's picture drifts each way
local FEED_N, GATHER_N = 4, 2
local FOOT = 40 -- a card's link at its foot, and the gap above it

-- The sheet's width: both halves of the book and the fold between them (W:PageInsets).
local function sheetWidth() return 2 * ns.Window.PAGE_W + 52 end

local function maxLines(fs, n) if fs.SetMaxLines then fs:SetMaxLines(n) end return fs end
local function shadow(...) for _, t in ipairs({ ... }) do t:SetShadowOffset(1, -1); t:SetShadowColor(0, 0, 0, 1) end end

-- A card: its own picture behind a dark fade, its heading (and a small note at the right), a gold rule, its words light
-- in every theme, and a link at its foot. All three look as Focus now did (the owner after the check of 9 Nov 2026,
-- 22:42: the torn parchment hid the headings; "I like the first windows style the best", each picture telling at once
-- what the card is about). paint(p) sets the picture once the card has its size, and again on each refresh.
local DUSK = { 0.055, 0.03, 0.01 }
local function panel(parent, title, linkFn, paint)
  local p = CreateFrame("Frame", nil, parent)
  p.art = p:CreateTexture(nil, "BACKGROUND")
  local shade = p:CreateTexture(nil, "BORDER")
  UI.FramePicture(p, p.art, shade)
  -- Darkest under the heading, lighter lower down so the picture shows; a dark foot again under the link.
  UI.SetGradient(shade, "VERTICAL", { DUSK[1], DUSK[2], DUSK[3], 0.5 }, { DUSK[1], DUSK[2], DUSK[3], 0.84 })
  local foot = p:CreateTexture(nil, "BORDER", nil, 1)
  foot:SetPoint("BOTTOMLEFT", UI.PIC_INSET, UI.PIC_INSET); foot:SetPoint("BOTTOMRIGHT", -UI.PIC_INSET, UI.PIC_INSET)
  foot:SetHeight(44)
  UI.SetGradient(foot, "VERTICAL", { DUSK[1], DUSK[2], DUSK[3], 0.7 }, { DUSK[1], DUSK[2], DUSK[3], 0 })
  p.head = UI.Text(p, 18, "chipText", "title")
  p.head:SetPoint("TOPLEFT", PAD, -PAD)
  p.head:SetText(title)
  p.note = UI.Text(p, 12, "muted", "body", "RIGHT")
  p.note:SetPoint("TOPRIGHT", -PAD, -PAD - 4)
  p.note:EnableMouse(true)
  local rule = UI.Solid(p, "BORDER", "gold", 0.5, 2)
  rule:SetHeight(1); rule:SetPoint("TOPLEFT", PAD, -PAD - 26); rule:SetPoint("TOPRIGHT", -PAD, -PAD - 26)
  p.link = UI.TextButton(p, "", linkFn, "link", 13)
  p.link:SetPoint("BOTTOMLEFT", PAD - 4, PAD - 6)
  Theme:TextColor(p.link.text, "chipText")
  shadow(p.head, p.note, p.link.text)
  p.top = PAD + 36 -- where the card's content starts
  p.paint = function() paint(p) end
  p:SetScript("OnSizeChanged", p.paint)
  return p
end

local function cardSize(p) return p:GetWidth() - 2 * UI.PIC_INSET, p:GetHeight() - 2 * UI.PIC_INSET end

-- Focus now's picture: its dungeon's, else the chapter's; cropped to the card's size (known once it is laid out).
local function focusArt(pf)
  local fo, a = pf.focus, pf.focusArtOf
  local w, h = cardSize(fo)
  if not a or not (w > 0 and h > 0) then return end
  local ok, generic = false, true
  if a.key then ok, generic = ns.SetDungeonArt(fo.art, a.key, w, h) end
  if not ok or generic then ns.Pages:SetChapterArt(fo.art, a.chapter, w, h, 0.4) end
end

-- A card on one of the book's own pictures (ns.Pages.ART, the Horde's where it has its own): Since last time on the
-- Chronicle's notice board, Coming up on the road ahead.
local function sceneArt(p, key)
  local w, h = cardSize(p)
  if not (w > 0 and h > 0) then return end
  local art = (Theme:Horde() and ns.Pages.ART_HORDE or ns.Pages.ART)[key]
  p.art:SetTexture(ns.MEDIA .. art[1])
  UI.Cover(p.art, art[2], w, h)
  p.artFile = art[1] -- (the self-test reads it: the game may give the texture back as a number)
end

-- The banner's picture at pf.driftAt (0 to 1): the 2:1 picture's whole width less 2 * DRIFT of the banner's, from its
-- left part to its right part, so the banner is always full.
local function pan(pf)
  local w = pf.pic.artW
  local show = w / (w + 2 * DRIFT)
  local u = (1 - show) * (pf.driftAt or 0)
  UI.Cover(pf.pic.art, 2 * show, w, pf.pic.artH, 0.45, { u, u + show, 0, 1 })
end

-- The gentle open: the panels fade in one after another and the banner's picture drifts. Not with Reduce effects.
-- pf.openedAt: when it last played (the self-test reads it).
local function playOpen(pf)
  if ns.Settings:Get("reduce") then pf.drift:Stop(); return end
  for _, ag in ipairs(pf.opens) do ag:Stop(); ag:Play() end
  if not pf.drift:IsPlaying() then pf.drift:Play() end
  pf.openedAt = GetTime()
end

local function build(pf)
  local W = ns.Window
  local width = sheetWidth()
  local sheet = CreateFrame("Frame", nil, pf.left)
  sheet:SetPoint("TOPLEFT", pf.left, "TOPLEFT")
  sheet:SetPoint("BOTTOMRIGHT", pf.right, "BOTTOMRIGHT")
  pf.sheet = sheet

  -- The chapter's banner across the top (it was a small picture with empty paper beside it; the owner's pick of
  -- 9 Nov 2026). Its picture drifts by the part of the image it shows, never by moving: moved, the picture left the
  -- dark ground showing at its left (the owner, check of 10 Nov 2026).
  local inset = UI.PIC_INSET
  local banner = CreateFrame("Frame", nil, sheet)
  banner:SetSize(width, TOP_H)
  banner:SetPoint("TOPLEFT")
  pf.banner = banner
  local lvl = banner:GetFrameLevel()
  local ground = banner:CreateTexture(nil, "BACKGROUND")
  ground:SetAllPoints(); ground:SetColorTexture(0.1, 0.07, 0.04, 1)
  local art = CreateFrame("Frame", nil, banner)
  art:SetFrameLevel(lvl + 1)
  art:SetPoint("TOPLEFT", inset, -inset); art:SetPoint("BOTTOMRIGHT", -inset, inset)
  pf.drift = art:CreateAnimationGroup() -- only a clock: there and back in a minute, gently at each end
  pf.driftTick = pf.drift:CreateAnimation("Animation")
  pf.driftTick:SetDuration(60)
  pf.driftTick:SetScript("OnUpdate", function(self)
    pf.driftAt = 0.5 - 0.5 * math.cos(2 * math.pi * (self:GetProgress() or 0)); pan(pf)
  end)
  pf.drift:SetLooping("REPEAT")
  -- Above the picture: its name and levels (a click opens the Chapter page), then the strip of paper.
  pf.pic = CreateFrame("Button", nil, banner)
  pf.pic:SetFrameLevel(lvl + 3)
  pf.pic:SetPoint("TOPLEFT", inset, -inset); pf.pic:SetPoint("BOTTOMRIGHT", banner, "BOTTOMRIGHT", -inset, STRIP_H)
  pf.pic.art = art:CreateTexture(nil, "BACKGROUND")
  pf.pic.art:SetAllPoints()
  pf.pic.artW, pf.pic.artH = width - 2 * inset, TOP_H - 2 * inset
  local fade = pf.pic:CreateTexture(nil, "BORDER")
  fade:SetAllPoints()
  UI.SetGradient(fade, "VERTICAL", { 0.055, 0.03, 0.01, 0.88 }, { 0.055, 0.03, 0.01, 0 })
  local hl = pf.pic:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints(); hl:SetColorTexture(1, 0.9, 0.6, 0.12)
  pf.pic.levels = UI.Text(pf.pic, 13, "chipText", "body")
  pf.pic.levels:SetPoint("BOTTOMLEFT", 16, 10)
  pf.pic.title = UI.Text(pf.pic, 26, "goldText", "fancy")
  pf.pic.title:SetPoint("BOTTOMLEFT", pf.pic.levels, "TOPLEFT", 0, 2)
  pf.pic.title:SetWidth(width - 2 * inset - 200); pf.pic.title:SetWordWrap(true); maxLines(pf.pic.title, 2)
  -- The name of the strip below, at the picture's lower right.
  pf.pic.stand = UI.Text(pf.pic, 11, "chipText", "title", "RIGHT")
  pf.pic.stand:SetPoint("BOTTOMRIGHT", -16, 8)
  pf.pic.stand:SetText(L.WHERE_WE_STAND:upper())
  shadow(pf.pic.title, pf.pic.levels, pf.pic.stand)
  pf.pic:SetScript("OnClick", function() W:ShowPage("chapter") end)
  pf.pic.edge = UI.Box(banner, inset, nil, nil, "gold", 0.85)
  pf.pic.edge:SetAllPoints(); pf.pic.edge:SetFrameLevel(lvl + 5)

  -- Where we stand along the banner's lower edge, on the picture's own dark foot (U158: it was a strip of paper, the
  -- one part not in the cards' style): one level track, one line, the room as the answer; light in every theme.
  local sw = width - 2 * inset
  local st = CreateFrame("Frame", nil, banner)
  st:SetFrameLevel(lvl + 3)
  st:SetPoint("BOTTOMLEFT", inset, inset); st:SetPoint("BOTTOMRIGHT", -inset, inset)
  st:SetHeight(STRIP_H - inset)
  st.w = sw
  pf.stand = st
  local foot = st:CreateTexture(nil, "BACKGROUND")
  foot:SetAllPoints(); foot:SetColorTexture(DUSK[1], DUSK[2], DUSK[3], 0.88) -- (as dark as the fade above ends)
  st.track = UI.LevelTrack(st, sw - 24, true)
  st.line = UI.Text(st, 13, "chipText", "book")
  st.line:SetWordWrap(false)
  st.who = UI.TextButton(st, L.WHO_STANDS_WHERE, function() W:ShowPage("chapter") end, "link", 13)
  Theme:TextColor(st.who.text, "goldText")
  st.room = CreateFrame("Frame", nil, st)
  st.room:SetSize(sw - 32, 18)
  st.room.text = UI.Text(st.room, 14, "chipText", "title")
  st.room.text:SetPoint("LEFT")
  st.room.text:SetWordWrap(false)
  shadow(st.line, st.who.text, st.room.text)
  UI.Tooltip(st.room, function() return st.room.tip end)
  -- Shared lives (SPEC §9): how many are left, and a candle for each, on the picture's top left; a click opens the
  -- rulebook's Challenges.
  st.lives = CreateFrame("Button", nil, pf.pic)
  st.lives:SetSize(1, 24)
  st.lives:SetPoint("TOPLEFT", 16, -12)
  st.lives.text = UI.Text(st.lives, 13, "chipText", "book")
  st.lives.text:SetPoint("LEFT")
  shadow(st.lives.text)
  -- shortcut: one row of candles up to 25 lives (Large suggests 15); 26 to 30 take a second row over the chapter's
  -- name. Smaller candles on the banner if fellowships pick that many.
  st.lives.candles = UI.Lives(st.lives, sw - 240)
  st.lives.candles.onClick = function() W:ShowPage("rules") end
  st.lives:SetScript("OnClick", function() W:ShowPage("rules") end)

  -- The three panels, side by side.
  local pw = math.floor((width - 2 * GAP) / 3)
  local function place(p, i)
    p:SetPoint("TOPLEFT", sheet, "TOPLEFT", (i - 1) * (pw + GAP), -(TOP_H + GAP))
    p:SetPoint("BOTTOM", sheet, "BOTTOM")
    p:SetWidth(pw)
  end
  local inner = pw - 2 * PAD
  pf.innerW = inner

  -- Focus now: one thing to do, its reason, one button and the page it lives on; on its dungeon's picture, as the
  -- Adventure Guide's Suggested Content has (it was a plain cream card; the owner's pick of 9 Nov 2026).
  local fo = panel(sheet, L.FOCUS_NOW, function()
    local l = pf.focusLink
    if l and l.key then ns.DungeonPage:Open(l.key) elseif l then W:ShowPage(l.page) end
  end, function() focusArt(pf) end)
  place(fo, 1)
  pf.focus = fo
  fo.what = maxLines(UI.WrapText(fo, 24, "goldText", inner, "fancy"), 2)
  fo.what:SetPoint("TOPLEFT", PAD, -fo.top)
  fo.why = maxLines(UI.WrapText(fo, 13, "chipText", inner, "book"), 4)
  shadow(fo.what, fo.why)
  fo.btn = UI.TextButton(fo, "", function()
    local f = ns.Fellowship:Current()
    if f then ns.Together:DoFocus(f, pf.focusButton) end
  end, "primary", 15)

  -- Since last time: the newest lines, each with its kind's icon, and how many more the Chronicle has.
  local si = panel(sheet, L.SINCE_LAST_TIME, function() W:ShowPage("chronicle") end, function(p) sceneArt(p, "board") end)
  place(si, 2)
  pf.since = si
  UI.Tooltip(si.note, function() return si.noteTip end)
  si.rows = {}
  for i = 1, FEED_N do
    local r = CreateFrame("Frame", nil, si)
    r:SetWidth(inner)
    r.icon = UI.Round(r, "ARTWORK", 20)
    r.icon:SetPoint("TOPLEFT", 0, 1)
    r.text = maxLines(UI.WrapText(r, 13, "chipText", inner - 28, "book"), 4)
    r.text:SetPoint("TOPLEFT", 28, 0)
    shadow(r.text)
    si.rows[i] = r
  end
  si.none = UI.WrapText(si, 13, "muted", inner, "book")
  si.none:SetPoint("TOPLEFT", PAD, -si.top)
  si.none:SetText(L.SINCE_NOTHING_NEW)
  shadow(si.none)

  -- Coming up: the first step for a later dungeon (its picture; a click opens its page), the next two Gatherings and
  -- the next chapter.
  local co = panel(sheet, L.COMING_UP, function() W:ShowPage("gatherings") end, function(p) sceneArt(p, "land") end)
  place(co, 3)
  pf.coming = co
  co.link:SetLabel(L.ALL_GATHERINGS)
  co.prep = CreateFrame("Button", nil, co)
  co.prep:SetSize(inner, 46)
  co.prep.frame = CreateFrame("Frame", nil, co.prep)
  co.prep.frame:SetSize(64, 40); co.prep.frame:SetPoint("TOPLEFT")
  -- The picture belongs to its frame: on the row it filled the row behind the words, dark, and the frame's own ground
  -- covered it (the owner's check, 9 Nov 2026).
  co.prep.pic = co.prep.frame:CreateTexture(nil, "ARTWORK")
  UI.FramePicture(co.prep.frame, co.prep.pic)
  co.prep.title = UI.Text(co.prep, 14, "goldText", "title")
  co.prep.title:SetPoint("TOPLEFT", 74, -1)
  co.prep.title:SetWidth(inner - 74); co.prep.title:SetWordWrap(false)
  co.prep.line = maxLines(UI.WrapText(co.prep, 12, "muted", inner - 74, "book"), 2)
  co.prep.line:SetPoint("TOPLEFT", co.prep.title, "BOTTOMLEFT", 0, -2)
  shadow(co.prep.title, co.prep.line)
  co.prep:SetScript("OnClick", function() if co.prep.key then ns.DungeonPage:Open(co.prep.key) end end)
  co.gathers = {}
  for i = 1, GATHER_N do
    local g = CreateFrame("Button", nil, co)
    g:SetSize(inner, 38)
    g.cal = UI.Solid(g, "BACKGROUND", "dark", 0.6)
    g.cal:SetSize(36, 36); g.cal:SetPoint("TOPLEFT")
    g.day = UI.Text(g, 10, "muted", "title", "CENTER")
    g.day:SetPoint("TOP", g.cal, "TOP", 0, -3)
    g.num = UI.Text(g, 16, "goldText", "title", "CENTER")
    g.num:SetPoint("BOTTOM", g.cal, "BOTTOM", 0, 3)
    g.title = UI.Text(g, 14, "chipText", "title")
    g.title:SetPoint("TOPLEFT", 46, -2)
    g.title:SetWidth(inner - 46); g.title:SetWordWrap(false)
    g.sub = UI.Text(g, 12, "muted", "book")
    g.sub:SetPoint("TOPLEFT", g.title, "BOTTOMLEFT", 0, -3)
    shadow(g.title, g.sub)
    g:SetScript("OnClick", function() W:ShowPage("gatherings") end)
    co.gathers[i] = g
  end
  co.noGather = UI.Text(co, 13, "muted", "book")
  co.noGather:SetText(L.G_NEXT_NONE)
  co.nextCh = maxLines(UI.WrapText(co, 13, "chipText", inner, "book"), 2)
  shadow(co.noGather, co.nextCh)

  -- The gentle open (the owner's pick of 9 Nov 2026): each time the Overview opens, the panels fade in one after
  -- another (all within the tour's settling time) and the banner's picture drifts while it is shown.
  pf.opens = {}
  for i, p in ipairs({ fo, si, co }) do
    local ag = p:CreateAnimationGroup()
    -- Each starts a tenth of a second after the one before, held unseen until then (a delay alone shows it first).
    if i > 1 then
      local hold = ag:CreateAnimation("Alpha")
      hold:SetFromAlpha(0); hold:SetToAlpha(0); hold:SetDuration(0.1 * (i - 1)); hold:SetOrder(1)
    end
    local a = ag:CreateAnimation("Alpha")
    a:SetFromAlpha(0); a:SetToAlpha(1); a:SetDuration(0.3); a:SetOrder(2)
    if a.SetSmoothing then a:SetSmoothing("OUT") end
    pf.opens[i] = ag
  end
  sheet:SetScript("OnShow", function() playOpen(pf) end)
  sheet:SetScript("OnHide", function() pf.drift:Stop(); pf.driftAt = 0 end)
  -- Reduce effects turned on with the Overview open (Settings is a side panel): the picture stops at once.
  ns:On("SETTING", function(key, on) if key == "reduce" and on then pf.drift:Stop() end end)
end

-- Where we stand's line: who is below the floor (or that everyone is at the floor or the cap), and the clears.
local function standLine(f, cur)
  local c = J:Counts(f, cur)
  local below = J:Below(f, cur)
  local first
  if #below == 1 then first = below[1] == ns.Me() and L.WS_BELOW_YOU or L.WS_BELOW_1:format(ns.Short(below[1]))
  elseif #below > 1 then first = L.WS_BELOW_N:format(#below)
  elseif c[2] and c[2][2] == 0 and (c[3][2] + c[4][2]) > 0 then first = L.WS_AT_CAP
  else first = L.WS_AT_FLOOR end
  local req, done = J:Required(f, cur), 0
  for _, x in ipairs(req) do if J:Cleared(f, x.key) then done = done + 1 end end
  if #req == 0 then return first end
  return first .. " " .. L.WS_CLEARED:format(done, #req)
end

local function refreshStand(pf, f, cur, ch, watching)
  local st = pf.stand
  local y = 6
  -- A Friend of the fellowship never holds anyone back (SPEC §1.1): that, with how to count again, in the room's place.
  local friend = not watching and ns.Fellowship:IsFriend(f, ns.Me())
  local room = not watching and not friend and ns.Room:Chapter(f, ns.Me()) or nil
  -- The stop point on the track whenever the line names it, with room to spare too (U179, the owner, 10 Nov 2026: "mark
  -- in the overview where you should stop questing"); the Chapter page's track keeps it for the last half level.
  local th = st.track:Set(f, cur, 0, room and (room.stopAt or room.stop))
  st.track:ClearAllPoints(); st.track:SetPoint("TOPLEFT", 12, -y)
  y = y + th + 2
  st.line:SetText(standLine(f, cur))
  st.line:ClearAllPoints(); st.line:SetPoint("TOPLEFT", 16, -y)
  st.who:ClearAllPoints(); st.who:SetPoint("LEFT", st.line, "RIGHT", 10, 0)
  st.line:SetWidth(math.min(st.line:GetStringWidth() + 2, st.w - st.who:GetWidth() - 46))
  y = y + 22
  st.room:SetShown(room ~= nil or friend)
  if room or friend then
    if friend then
      st.room.text:SetText(L.WS_FRIEND); st.room.tip = L.WS_FRIEND_TIP
    else
      local text, color, tip = ns.Room.Answer(room)
      -- (The colours lifted for the dark foot, as the Night theme's pages lift them.)
      st.room.text:SetText(("|cff%s%s|r"):format(Theme.DARK_LIFT[color] or color, text))
      st.room.tip = tip
    end
    st.room:ClearAllPoints(); st.room:SetPoint("TOPLEFT", 16, -y)
  end
  local v = ch and ns.Challenges:LivesView(f)
  st.lives:SetShown(v ~= nil)
  if v then
    st.lives.text:SetText(v.title)
    st.lives.candles:SetTip(v.title, v.lines)
    local h = st.lives.candles:Set(v.total, v.left)
    st.lives.candles:ClearAllPoints(); st.lives.candles:SetPoint("LEFT", st.lives.text, "RIGHT", 12, 0)
    -- A life lost since you last looked: its candle goes out now, once (per fellowship, by this character). Not for
    -- the walkthrough's sample.
    if not f.sample then
      ns.char.livesSeen = type(ns.char.livesSeen) == "table" and ns.char.livesSeen or {}
      local seen = tonumber(ns.char.livesSeen[f.id])
      if seen and v.left < seen then st.lives.candles:Snuff(seen, v.left) end
      ns.char.livesSeen[f.id] = v.left
    end
    -- Only as wide as its words and candles: the rest of the picture still opens the Chapter page.
    st.lives:SetSize(st.lives.text:GetStringWidth() + 12 + st.lives.candles.used, math.max(24, h))
  end
end

local function refreshFocus(pf, f, cur, watching)
  local fo = pf.focus
  local x = ns.Together:Focus(f)
  fo.what:SetText(x.head)
  fo.why:SetText(x.why or "")
  local y = fo.top
  fo.what:ClearAllPoints(); fo.what:SetPoint("TOPLEFT", PAD, -y)
  y = y + fo.what:GetStringHeight() + 8
  fo.why:ClearAllPoints(); fo.why:SetPoint("TOPLEFT", PAD, -y)
  y = y + fo.why:GetStringHeight() + 14
  local b = not watching and x.button or nil
  pf.focusButton = b
  fo.btn:SetShown(b ~= nil)
  if b then
    fo.btn:SetLabel(b.kind == "find" and L.FIND_GROUP or (b.kind == "ready" and L.TODO_GET_READY_BUTTON
      or (b.kind == "invite" and L.INVITE_TO_GROUP or L.FOCUS_OPEN)))
    -- Larger than the book's other buttons: the one thing to press on this page.
    fo.btn:SetSize(math.max(150, fo.btn.text:GetStringWidth() + 56), 34)
    fo.btn:ClearAllPoints(); fo.btn:SetPoint("TOPLEFT", PAD, -y)
  end
  pf.focusLink = x.link or { page = "chapter", text = L.FOCUS_LINK_CHAPTER }
  fo.link:SetLabel(pf.focusLink.text)
  pf.focusArtOf = { key = pf.focusLink.key, chapter = ns.Pages:ArtOf(f, cur) }
  focusArt(pf)
end

-- Since last time: the chapter unlocked, who levelled, then the Chronicle's lines, newest first; FEED_N of them.
local function refreshSince(pf, f)
  local si = pf.since
  local d = ns.Since:Digest(f)
  ns.Since:Shown(f)
  local lines = {}
  if d then
    if d.chapter then lines[#lines + 1] = { "hist_chapter", d.chapter } end
    -- Everyone who levelled on one line (U169), so a fall or a clear is not pushed behind "more in the Chronicle".
    local lv = d.levels
    if #lv == 1 then
      lines[#lines + 1] = { "since_level", L.SINCE_REACHED:format(ns.Short(lv[1].name), lv[1].to) }
    elseif #lv > 1 then
      local parts = {}
      for i, x in ipairs(lv) do parts[i] = L.SINCE_LEVEL_ONE:format(ns.Short(x.name), x.to) end
      lines[#lines + 1] = { "since_level", L.SINCE_LEVELS:format(table.concat(parts, "  ·  ")) }
    end
    for _, e in ipairs(d.events) do lines[#lines + 1] = { e.icon or "chronicle", e.text, e.time } end
  end
  local snap = ns.char.since
  si.note:SetText(d and d.ago or "")
  si.noteTip = d and type(snap) == "table" and snap.t and L.SINCE_NOTE_TIP:format(date(L.G_DATE_FORMAT, snap.t)) or nil
  -- Each line whole, as many as fit above the link; the rest wait in the Chronicle, counted in its link (cut at two
  -- lines, a fall and a Gathering lost their end: the check of 10 Nov 2026, 22:46). Before the card is laid out its
  -- height is not known (nor in the unit-test harness): no limit then.
  local room = si:GetHeight() - FOOT
  if room < si.top + 40 then room = math.huge end
  local y, shown = si.top, 0
  for i, r in ipairs(si.rows) do
    local line = lines[i]
    if line then
      UI.SetIcon(r.icon, ns.ICONS[line[1]] or ns.ICONS.chronicle)
      r.text:SetText(line[2])
      local h = math.max(20, r.text:GetStringHeight())
      if shown > 0 and (shown < i - 1 or y + h > room) then line = nil end -- (in order: none after one left out)
      if line then
        r:SetHeight(h)
        r:ClearAllPoints(); r:SetPoint("TOPLEFT", PAD, -y)
        y, shown = y + h + 10, shown + 1
      end
    end
    r:SetShown(line ~= nil)
  end
  si.none:SetShown(#lines == 0)
  local more = math.max(0, #lines - shown) + (d and d.more or 0)
  si.link:SetLabel(more > 0 and L.SINCE_MORE_LINK:format(more) or L.THE_CHRONICLE_LINK)
end

local function refreshComing(pf, f, cur, maxView)
  local co = pf.coming
  local y = co.top
  local inner = pf.innerW
  -- The first step for a later dungeon (U140), nearest chapter first: a prequest chain once your level reaches it.
  local first = ns.QuestLists:Later(f, cur)[1]
  co.prep:SetShown(first ~= nil)
  if first then
    co.prep.key = first.x.key
    ns.SetDungeonArt(co.prep.pic, first.x.key, 64 - 2 * UI.PIC_INSET, 40 - 2 * UI.PIC_INSET)
    co.prep.title:SetText(L.FOCUS_PREPARE:format(first.x.d[2]))
    co.prep.line:SetText(ns.QuestLists.LaterLine(first))
    local h = math.max(42, co.prep.title:GetStringHeight() + co.prep.line:GetStringHeight() + 4)
    co.prep:SetHeight(h)
    co.prep:ClearAllPoints(); co.prep:SetPoint("TOPLEFT", 16, -y)
    y = y + h + 12
  end
  -- The next two Gatherings.
  local G = ns.Gatherings
  local list = G:Upcoming(f)
  for i, g in ipairs(co.gathers) do
    local x = list[i]
    g:SetShown(x ~= nil)
    if x then
      g.day:SetText(date(L.G_WEEKDAY_FORMAT, x.at))
      g.num:SetText(tonumber(date("%d", x.at)))
      g.title:SetText(G.What(x))
      g.sub:SetText(L.COMING_GATHER_LINE:format(date(L.G_TIME_FORMAT, x.at), G.Counts(x).yes))
      g:ClearAllPoints(); g:SetPoint("TOPLEFT", 16, -y)
      y = y + 46
    end
  end
  co.noGather:SetShown(#list == 0)
  if #list == 0 then
    co.noGather:ClearAllPoints(); co.noGather:SetPoint("TOPLEFT", 16, -y)
    y = y + 26
  end
  -- Then the next chapter (or the raids).
  local count = #f.journey.chapters
  local text
  if cur >= count then text = L.COMING_RAIDS
  elseif cur + 1 > maxView then text = L.COMING_NEXT_HIDDEN:format(J.Roman(cur + 1))
  else text = L.COMING_NEXT:format(J.Roman(cur + 1), f.journey.chapters[cur + 1].name) end
  co.nextCh:SetWidth(inner)
  co.nextCh:SetText(text)
  co.nextCh:ClearAllPoints(); co.nextCh:SetPoint("TOPLEFT", 16, -(y + 2))
end

local function refresh(pf, ctx)
  local f = ctx.f
  if not f then return end
  local count = #f.journey.chapters
  local cur = math.min(J:CurrentIndex(f), count)
  local ch = J:Current(f)
  ns.Pages:SetChapterArt(pf.pic.art, ns.Pages:ArtOf(f, cur), pf.pic.artW, pf.pic.artH, 0.45)
  pan(pf)
  local shownCh = f.journey.chapters[cur]
  pf.pic.title:SetText(ch and L.CHAPTER_N_NAME:format(J.Roman(cur), shownCh.name) or L.BN_JOURNEY_DONE)
  pf.pic.levels:SetText(L.OV_PIC_LEVELS:format(J:FloorLevel(f, shownCh), shownCh.cap))
  refreshStand(pf, f, cur, ch, ctx.watching)
  refreshFocus(pf, f, cur, ctx.watching)
  refreshSince(pf, f)
  refreshComing(pf, f, cur, J:MaxView(f, ctx.me))
  -- (Again here: the board is the Horde's own for a Horde character, and the tour's Horde shots switch it.)
  pf.since.paint(); pf.coming.paint()
end

ns.Pages:Register({ id = "overview", label = ns.L.NAV_OVERVIEW, header = "both", flat = true, build = build,
  -- (No subtitle, U162: "Where the fellowship stands" said what the banner's Where we stand says just below it.)
  refresh = refresh, title = function() return L.TITLE_OVERVIEW, "" end })
