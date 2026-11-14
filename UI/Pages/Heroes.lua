-- Heroes (SPEC §4.8). List view: left the fellowship's banner, its roles, every Adventurer's card (status, level, XP)
-- and Leave (U196, the owner, 14 Nov 2026); right Invite Adventurers, the Friends of the fellowship and the Fallen.
-- Click a Hero to inspect: left their gear, right XP, facts, this chapter's dungeons, roles,
-- I'm away / I'm back and Play another character (yourself).
local _, ns = ...
local L = ns.L
local UI, Theme = ns.UI, ns.Theme
local F, P, Hr, J = ns.Fellowship, ns.Permissions, ns.Hero, ns.Journey


local PORTRAIT = 56 -- the 3D head (or class crest) on a Companion card
local CARD_X = 8 + PORTRAIT + 8 -- where the card's text starts
local COMP_Y = 74 -- the roles under the banner (U190: where the number tiles were)
local CARDS_Y = COMP_Y + 52 -- the cards under the roles and their line (U196)
local FEW = 3 -- the Friends of the fellowship or the Fallen open at first up to this many (U199)
local OLD = "C8762E" -- an old addon: the orange of "2 to the floor"
local FALLEN_BG = { Hr.FALLEN, 0.16 } -- a Fallen's card: muted violet over the page, in every theme

-- Fallen under a survival challenge (SPEC §9).
local function isFallen(f, name) return f.falls ~= nil and ns.Challenges:Fallen(f, name) ~= nil end

local function inkFor(f, name)
  local _, token = Hr:ClassName(f, name)
  return ns.ClassHex(token, Theme:Current().light)
end

local function setNameColor(fs, f, name)
  local hex = inkFor(f, name)
  if hex then fs:SetTextColor(ns.Hex(hex)) else fs:SetTextColor(Theme:RGBA("ink")) end
end

-- XP bar (UI.Bar): the level so far in gold, rested XP as a pale blue band ahead of it (at 0% with rested XP the
-- whole bar was solid blue and read as full; seen in the check, 28 Oct 2026).
local function xpBar(parent, height, gold)
  local bar = UI.Bar(parent, height, gold)
  bar:SetColor("E2B23C")
  return bar
end

---------------------------------------------------------------------------
-- List view
---------------------------------------------------------------------------
local function buildList(pf, width)
  local left = CreateFrame("Frame", nil, pf.left)
  left:SetAllPoints()
  pf.listL = left
  pf.crest = UI.Crest(left, 52, 64)
  pf.crest:SetPoint("TOPLEFT", 0, 0)
  pf.fname = UI.Text(left, 20, "ink", "title")
  pf.fname:SetPoint("TOPLEFT", pf.crest, "TOPRIGHT", 12, -8)
  pf.fname:SetWidth(width - 64)
  pf.fline = UI.Text(left, 12, "ink2")
  pf.fline:SetPoint("TOPLEFT", pf.fname, "BOTTOMLEFT", 0, -4)
  pf.fline:SetWidth(width - 64); pf.fline:SetWordWrap(false) -- (a long Leader's name ends in "...", not past the page)
  -- (No number tiles since U190, the owner, 14 Nov 2026: the count is in the line under the name (U201), the chapter in
  -- the header's chip, the clears on the Dungeons page.)
  pf.comp = {}
  for i, role in ipairs({ "Tank", "Healer", "DPS" }) do
    local f = CreateFrame("Frame", nil, left)
    f:SetSize((width - 16) / 3, 30)
    f:SetPoint("TOPLEFT", (i - 1) * ((width - 16) / 3 + 8), -COMP_Y)
    local icon = UI.RoleIcon(f, 22)
    icon:SetPoint("LEFT")
    UI.SetRole(icon, role)
    f.n = UI.Text(f, 16, "ink", "title")
    f.n:SetPoint("LEFT", icon, "RIGHT", 6, 0)
    f.label = UI.Text(f, 12, "ink2")
    f.label:SetPoint("LEFT", f.n, "RIGHT", 6, 0)
    f.one, f.many = ({ L.COMP_TANK, L.COMP_HEALER, L.COMP_DAMAGE })[i], ({ L.COMP_TANKS, L.COMP_HEALERS, L.COMP_DAMAGE })[i]
    f.role = role
    -- A missing tank or healer: the count in red, and what to do in the tooltip (0 Healers said nothing more).
    f.missingText = ({ L.COMP_NO_TANK, L.COMP_NO_HEALER })[i]
    -- (Drawn short, without the word: "2 Healers" in the tooltip.)
    f:SetScript("OnEnter", function()
      local text = f.missing and f.missingText or (f.short and (f.n:GetText() .. " " .. f.label:GetText()))
      if not text then return end
      GameTooltip:SetOwner(f, "ANCHOR_TOP")
      GameTooltip:SetText(text, 1, 1, 1, 1, true)
      GameTooltip:Show()
    end)
    f:SetScript("OnLeave", function() GameTooltip:Hide() end)
    pf.comp[i] = f
  end
  -- The Fallen apart from the roles (SPEC §9): they no longer play one. A skull and how many, after Damage, when
  -- someone has fallen (the four columns are placed by refreshList).
  local fl = CreateFrame("Frame", nil, left)
  fl:SetSize((width - 24) / 4, 30)
  fl.icon = UI.Round(fl, "ARTWORK", 22)
  fl.icon:SetPoint("LEFT")
  UI.SetIcon(fl.icon, ns.ICONS.hist_fallen)
  fl.n = UI.Text(fl, 16, Hr.FALLEN, "title")
  fl.n:SetPoint("LEFT", fl.icon, "RIGHT", 6, 0)
  fl.label = UI.Text(fl, 12, "ink2")
  fl.label:SetPoint("LEFT", fl.n, "RIGHT", 6, 0)
  fl.label:SetText(L.COMP_FALLEN)
  fl:EnableMouse(true)
  UI.Tooltip(fl, L.COMP_FALLEN_TIP)
  pf.compFallen = fl
  -- Friends of the fellowship apart too (SPEC §1.1): they play no counted role. Their mark and how many, in teal,
  -- before the Fallen.
  local fr = CreateFrame("Frame", nil, left)
  fr:SetSize((width - 24) / 4, 30)
  fr.icon = UI.Round(fr, "ARTWORK", 22)
  fr.icon:SetPoint("LEFT")
  UI.SetIcon(fr.icon, ns.ICONS.bn_friend)
  fr.n = UI.Text(fr, 16, Hr.FRIEND, "title")
  fr.n:SetPoint("LEFT", fr.icon, "RIGHT", 6, 0)
  fr.label = UI.Text(fr, 12, "ink2")
  fr.label:SetPoint("LEFT", fr.n, "RIGHT", 6, 0)
  fr:EnableMouse(true)
  UI.Tooltip(fr, L.COMP_FRIEND_TIP)
  pf.compFriend = fr
  local div = UI.Divider(left)
  div:SetPoint("TOPLEFT", 0, -(COMP_Y + 40)); div:SetPoint("TOPRIGHT", 0, -(COMP_Y + 40))
  pf.tourney = UI.WrapText(left, 12, "ink2", width)
  -- (The level track left this page on 10 Nov 2026, U168: its home is the Chapter page, and each card has its level.)
  pf.leave = UI.TextButton(left, L.LEAVE, function()
    local f = F:Current()
    if f then ns.Window:Confirm(F:LeaveQuestion(f), L.LEAVE_SHORT, function() F:Leave() end) end
  end, "plain", 13)
  pf.leave:SetPoint("BOTTOMLEFT", 0, 0)
  -- The group photo on the whole screen (UI/Photo.lua).
  pf.photo = UI.TextButton(left, L.GROUP_PHOTO, function() ns.Photo:Open() end, "primary", 13)
  pf.photo:SetPoint("BOTTOMRIGHT", 0, 0)
  UI.Tooltip(pf.photo, L.GROUP_PHOTO_TIP)
  -- Every Adventurer's card under the roles, above Leave and Group photo (U196); placed by refreshList.
  pf.lscroll = UI.Scroll(left)

  -- Right page: Invite Adventurers, then the Friends of the fellowship and the Fallen.
  pf.scroll = UI.Scroll(pf.right)
  pf.scroll:SetAllPoints()
  pf.art = UI.PageArt(pf.scroll, "Companions")
  pf.listR = pf.scroll
  -- One pool for both pages: each card goes to the page it is placed on (refreshList).
  pf.cards = UI.Pool(function()
    local c = UI.Card(pf.lscroll.child, "line", "Button")
    c:SetSize(width - 8, 72)
    -- Their face in 3D (UI/Models.lua) once the game has drawn them this session; else their class crest.
    c.portrait = CreateFrame("Frame", nil, c)
    c.portrait:SetSize(PORTRAIT, PORTRAIT); c.portrait:SetPoint("TOPLEFT", 8, -8)
    c.portrait.bg = UI.Box(c.portrait, 1, "000000", 0.35, "gold", 0.7)
    c.portrait.bg:SetAllPoints()
    c.crest = UI.ClassCrest(c, PORTRAIT)
    c.crest:SetPoint("CENTER", c.portrait)
    c.role = UI.RoleIcon(c, 18)
    c.role:SetPoint("TOPLEFT", CARD_X, -8)
    c.name = UI.Text(c, 14, nil, "body")
    c.name:SetPoint("LEFT", c.role, "RIGHT", 6, 0)
    c.rank = UI.Text(c, 11, "accentText", "body")
    c.rank:SetPoint("LEFT", c.name, "RIGHT", 8, 0)
    c.level = UI.Text(c, 18, "ink", "title", "RIGHT")
    c.level:SetPoint("TOPRIGHT", -10, -7)
    -- Presence (28 Oct 2026): the mark and its word at the top, when last seen (or why away) under them, as in the
    -- game's friends list. Where they stand in the chapter sits after the XP.
    c.status = UI.Text(c, 12, nil, "body", "RIGHT")
    c.status:SetPoint("RIGHT", c.level, "LEFT", -10, 0)
    c.presence = UI.Presence(c, 10)
    c.presence:SetPoint("RIGHT", c.status, "LEFT", -5, 0)
    c.detail = UI.Text(c, 11, "ink2", "body", "RIGHT")
    c.detail:SetPoint("TOPRIGHT", -10, -30)
    c.line = UI.Text(c, 12, "ink2")
    c.line:SetPoint("TOPLEFT", CARD_X + 24, -28)
    -- An older addon than the newest in the fellowship (the versions are in the tooltip).
    c.old = UI.Text(c, 11, OLD, "body")
    c.old:SetPoint("LEFT", c.line, "RIGHT", 8, 0)
    c.old:SetText(L.OLD_ADDON)
    c.bar = xpBar(c, 8)
    c.bar:SetPoint("TOPLEFT", CARD_X, -45)
    c.xp = UI.Text(c, 11, "ink2")
    c.xp:SetPoint("TOPLEFT", CARD_X, -56)
    c.standing = UI.Text(c, 11, nil, "body", "RIGHT")
    c.standing:SetPoint("TOPRIGHT", -10, -56)
    -- The Fallen's mark: a skull in a violet ring on the crest's rim (a frame of its own, above the crest). It sits
    -- inside the portrait's corner, clear of the line beside it (it covered the L of "Level 22"; check of 1 Nov 2026,
    -- 11:30).
    c.fallenMark = CreateFrame("Frame", nil, c)
    c.fallenMark:SetSize(24, 24)
    c.fallenMark:SetPoint("CENTER", c.portrait, "BOTTOMRIGHT", -8, 8)
    c.fallenMark:SetFrameLevel(c:GetFrameLevel() + 8)
    local ring = UI.Round(c.fallenMark, "ARTWORK", 24)
    ring:SetPoint("CENTER"); Theme:Fill(ring, Hr.FALLEN, 1)
    c.fallenMark.icon = UI.Round(c.fallenMark, "OVERLAY", 20)
    c.fallenMark.icon:SetPoint("CENTER")
    UI.SetIcon(c.fallenMark.icon, ns.ICONS.hist_fallen)
    c.fallenMark:Hide()
    -- The Ring-bearer's mark: the Ring in a gold ring on the same corner (a bearer is never Fallen: the Ring is lost
    -- with them). The check of 3 Nov 2026, 21:57: in place of "Ring-bearer" on the card's line.
    c.ringMark = CreateFrame("Frame", nil, c)
    c.ringMark:SetSize(24, 24)
    c.ringMark:SetPoint("CENTER", c.portrait, "BOTTOMRIGHT", -8, 8)
    c.ringMark:SetFrameLevel(c:GetFrameLevel() + 8)
    local gold = UI.Round(c.ringMark, "ARTWORK", 24)
    gold:SetPoint("CENTER"); Theme:Fill(gold, "gold", 1)
    c.ringMark.icon = UI.Round(c.ringMark, "OVERLAY", 20)
    c.ringMark.icon:SetPoint("CENTER")
    UI.SetIcon(c.ringMark.icon, ns.Challenges:Icon("ring"))
    c.ringMark:Hide()
    local hl = c:CreateTexture(nil, "HIGHLIGHT")
    hl:SetPoint("TOPLEFT", 4, -4); hl:SetPoint("BOTTOMRIGHT", -4, 4); hl:SetColorTexture(1, 0.9, 0.6, 0.12)
    c:SetScript("OnClick", function() pf.sel = c.who; ns.Window:Refresh() end)
    -- The tooltip says what the mark means (and an old addon, when theirs is).
    c:SetScript("OnEnter", function()
      if not c.tip then return end
      GameTooltip:SetOwner(c, "ANCHOR_RIGHT")
      GameTooltip:SetText(ns.Short(c.who), 1, 1, 1)
      for _, line in ipairs(c.tip) do GameTooltip:AddLine(line[1], line[2], line[3], line[4], true) end
      GameTooltip:Show()
    end)
    c:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return c
  end)
  -- Invite an Adventurer, for everyone (27 Oct 2026: Adventurers invite; only here since U197, the owner, 14 Nov 2026).
  -- On top of the right page: the name box with friends and guild members as you type, Send invite, the open invites.
  local R = pf.scroll.child
  -- Your addon is older than another Adventurer's: a line at the very top until you update (28 Oct 2026).
  pf.oldNote = UI.Card(R, OLD)
  pf.oldNote:SetWidth(width - 8)
  pf.oldNote.text = UI.WrapText(pf.oldNote, 12, "ink", width - 32)
  pf.oldNote.text:SetPoint("TOPLEFT", 12, -9)
  -- Open at first (U196, the owner, 14 Nov 2026; U108 had it folded): a click on the heading folds the name box, and
  -- that is kept for the character; open invites show either way.
  pf.invHead = UI.FoldHeader(R, width - 8, function()
    ns.char.heroesOpen = ns.char.heroesOpen or {}
    ns.char.heroesOpen.inviteShut = pf.invite:IsShown() or nil
    ns.Window:Refresh()
  end)
  pf.invHead:SetText(L.INVITE_HEROES)
  UI.InviteBox(pf, R, width - 118, width - 8)
  pf.invRows = UI.Pool(function()
    local r = CreateFrame("Frame", nil, R)
    r:SetSize(width - 8, 28)
    r.name = UI.Text(r, 13, "ink")
    r.name:SetPoint("LEFT")
    r.cancel = UI.TextButton(r, L.CANCEL, function() F:CancelInvite(r.who) end, "plain", 12)
    r.cancel:SetPoint("RIGHT")
    -- Wraps before Cancel (the time left of an offline invite ran under it; the check of 4 Nov 2026, 20:33).
    r.wait = UI.Text(r, 12, "ink2")
    -- (Its width set in refresh, as on Manage: two lines were read as one; the check of 8 Nov 2026.)
    r.wait:SetPoint("LEFT", r.name, "RIGHT", 6, 0)
    r.wait:SetWordWrap(true); r.wait:SetJustifyH("LEFT")
    -- The time an offline invite still waits, as a thin bar that empties over its day (U57; from Manage, U197).
    r.left = UI.Bar(r, 4)
    r.left:SetPoint("BOTTOMLEFT", 0, 2)
    -- "Offline · 23 hours left" on the row; that it reaches them at login in its tooltip (U204, the owner, 14 Nov 2026).
    r:EnableMouse(true)
    UI.Tooltip(r, function() return r.offline and L.INVITE_OFFLINE:format(ns.Short(r.who)) end)
    return r
  end)
  -- The Friends of the fellowship and the Fallen under headings of their own: open at first while there are a few, closed
  -- above that (U199, the owner, 14 Nov 2026: closed at first, U108, hid a single Fallen's memorial; U108 came from a
  -- fellowship with many Friends scrolling a long way). A click opens or folds it, kept for the character.
  pf.folds = {}
  for g, x in ipairs({ { "friends", L.FOLD_FRIENDS }, { "fallen", L.FOLD_FALLEN } }) do
    local id = x[1]
    pf.folds[g] = UI.FoldHeader(R, width - 8, function()
      ns.char.heroesOpen = ns.char.heroesOpen or {}
      ns.char.heroesOpen[id] = not pf.folds[g].open
      ns.Window:Refresh()
    end)
    pf.folds[g].id, pf.folds[g].label = id, x[2]
  end
end

local function tourneyLine(f)
  local state, guild = F:TournamentState(f)
  if state == "off" then return nil end -- (U190: nothing while it is off)
  if state == "on" then return L.TOURNEY_ON:format(guild or "") end
  return state == "paused-gm" and L.TOURNEY_PAUSED_GM or L.TOURNEY_PAUSED_GUILD
end

local function roleLine(f, name)
  local m = f.members[name]
  local roleName = L["ROLE_" .. (m.role or "DPS"):upper()]
  if m.second then roleName = roleName .. " / " .. L["ROLE_" .. m.second:upper()] end
  -- The challenges (SPEC §9): "Ring-bearer", "Broke Walk everywhere".
  local note = f.challenges ~= nil and ns.Challenges:CardNote(f, name, true)
  return Hr:ClassName(f, name) .. "  ·  " .. roleName .. (note and ("  ·  " .. note) or "")
end

-- "4 Adventurers and 1 Friend": the Friends of the fellowship counted apart (SPEC §1.1).
local function countLine(ctx)
  local n, fr = ctx.heroes or 0, ctx.friends or 0
  local s = n == 1 and L.HEROES_1 or L.HEROES_N:format(n)
  if fr == 1 then return L.AND_FRIEND:format(s) end
  return fr > 1 and L.AND_FRIENDS:format(s, fr) or s
end

local function refreshList(pf, ctx, width)
  local f = ctx.f
  pf.crest:Set(f.color, f.emblem)
  pf.fname:SetText(f.name)
  -- The count beside the banner and the roles it adds up (U201, the owner, 14 Nov 2026: it was the right page's title,
  -- over the invite and away from the cards).
  pf.fline:SetText(L.FELLOWSHIP_LINE:format(countLine(ctx), f.faction or "", ns.Short(f.leader)))
  -- The roles of the Adventurers who play on; the Friends of the fellowship (SPEC §1.1) and the Fallen (SPEC §9)
  -- counted apart, each in a column after Damage when there are any.
  local counts, fallenN, friendN, living = { Tank = 0, Healer = 0, DPS = 0 }, 0, 0, 0
  for name, m in pairs(f.members) do
    if isFallen(f, name) then fallenN = fallenN + 1
    elseif m.friend then friendN = friendN + 1
    else counts[m.role] = (counts[m.role] or 0) + 1; living = living + 1 end
  end
  -- With both after Damage (five columns), the roles drop their words (kept in their tooltips) to make room.
  local extra = (friendN > 0 and 1 or 0) + (fallenN > 0 and 1 or 0)
  local short = extra == 2
  local roleW = short and 52 or (width - 8 * (2 + extra)) / (3 + extra)
  local extraW = extra > 0 and (width - 3 * (roleW + 8) - 8 * (extra - 1)) / extra or 0
  pf.compShort = short
  for i, c in ipairs(pf.comp) do
    c:ClearAllPoints(); c:SetPoint("TOPLEFT", (i - 1) * (roleW + 8), -COMP_Y); c:SetWidth(roleW)
    c.n:SetText(counts[c.role])
    c.label:SetText(counts[c.role] == 1 and c.one or c.many) -- "1 Tank", not "1 Tanks" (seen in the UI tour)
    c.label:SetShown(not short)
    c.short = short
    c.missing = c.missingText ~= nil and counts[c.role] == 0 and living >= 3
    c.n:SetTextColor(Theme:RGBA(c.missing and "B0321E" or "ink"))
    c:EnableMouse(c.missing or short)
  end
  local x = 3 * (roleW + 8)
  for _, it in ipairs({ { pf.compFriend, friendN }, { pf.compFallen, fallenN } }) do
    local fr, n = it[1], it[2]
    fr:SetShown(n > 0)
    if n > 0 then
      fr:ClearAllPoints(); fr:SetPoint("TOPLEFT", x, -COMP_Y); fr:SetWidth(extraW)
      fr.n:SetText(n)
      x = x + extraW + 8
    end
  end
  pf.compFriend.label:SetText(friendN == 1 and L.COMP_FRIEND or L.COMP_FRIENDS)
  -- (Recent history left this page in the rebuild: Since last time and the Chronicle hold it, SPEC §4.8.)
  local line = tourneyLine(f)
  pf.tourney:SetShown(line ~= nil)
  pf.tourney:SetText(line or "")
  pf.tourney:ClearAllPoints(); pf.tourney:SetPoint("TOPLEFT", 0, -CARDS_Y)
  local top = line and CARDS_Y + pf.tourney:GetStringHeight() + 10 or CARDS_Y
  pf.lscroll:ClearAllPoints(); pf.lscroll:SetPoint("TOPLEFT", 0, -top); pf.lscroll:SetPoint("BOTTOMRIGHT", 0, 38)
  -- The leader too: leaving hands the fellowship over. Not while watching an alt's fellowship (Fellowship/Watch.lua).
  pf.leave:SetShown(not ctx.watching)
  pf.photo:SetShown(not ctx.watching)

  -- Cards, highest level first (as in the mockup); Friends of the fellowship after those who count, the Fallen last.
  local names = F:Members(f)
  local function group(name) return isFallen(f, name) and 2 or (F:IsFriend(f, name) and 1 or 0) end
  table.sort(names, function(a, b)
    local ga, gb = group(a), group(b)
    if ga ~= gb then return ga < gb end
    local la, lb = Hr:Level(f, a), Hr:Level(f, b)
    if la ~= lb then return la > lb end
    return a < b
  end)
  local stack = UI.Stack(pf.scroll.child)
  -- Your own addon out of date (not while following another character: that one's version is not news).
  local mine, newest, by = Hr:OldVersion(f, ctx.me)
  pf.oldNote:SetShown(mine ~= nil and not ctx.watching)
  if pf.oldNote:IsShown() then
    pf.oldNote.text:SetText(L.OLD_YOURS:format(mine, ns.Short(by), newest))
    pf.oldNote:SetHeight(pf.oldNote.text:GetStringHeight() + 18)
    stack:Place(pf.oldNote, pf.oldNote:GetHeight(), 10)
  end
  -- Invite an Adventurer, on top (28 Oct 2026; it was under the cards). Not while following another character's
  -- fellowship; the walkthrough's veil keeps the sample's box from being used.
  local canInvite = not ctx.watching and P.Can(f, ctx.me, "invite")
  local opened = ns.char and ns.char.heroesOpen or {}
  local boxOpen = canInvite and not opened.inviteShut
  pf.invHead:SetShown(canInvite)
  for _, w in ipairs({ pf.invite, pf.send, pf.asFriend, pf.share }) do w:SetShown(boxOpen) end
  if not boxOpen then pf.suggest:Hide() end
  local nInv = 0
  if canInvite then
    pf.invHead:SetOpen(boxOpen)
    stack:Place(pf.invHead, 29, 6)
    if boxOpen then
      local iy = stack.y
      stack:Place(pf.invite, 28, 4)
      pf.send:ClearAllPoints(); pf.send:SetPoint("TOPRIGHT", pf.scroll.child, "TOPRIGHT", -8, -iy + 3)
      pf.asFriend:Refresh()
      stack:Place(pf.asFriend, 24, 2)
      stack:Place(pf.share, pf.share:GetHeight(), 6)
    end
    local open = {}
    for name in pairs(f.invites) do open[#open + 1] = name end
    table.sort(open)
    for i, name in ipairs(open) do
      local r = pf.invRows:Get(i)
      if not r then break end
      nInv = i
      r.who = name
      r.name:SetText(ns.Short(name) .. (f.inviteFriend and f.inviteFriend[name] and L.INV_AS_FRIEND or ""))
      local st = ns.Sync:InviteStatus(name)
      r.offline = st == "offline"
      r.wait:SetText(st == "received" and L.INV_RECEIVED or (st == "offline" and ns.Sync:OfflineText(f, name))
        or (st == "sending" and L.INV_SENDING or L.WAITING_ANSWER))
      r.wait:SetTextColor(Theme:RGBA(st == "received" and "3E7A3A" or "ink2"))
      r.cancel:SetShown(P.Can(f, ctx.me, "uninvite", name))
      r:SetWidth(width - 8)
      r.wait:SetWidth(math.max(60, width - 8 - r.name:GetStringWidth() - 6 - (r.cancel:IsShown() and r.cancel:GetWidth() + 8 or 0)))
      local left = st == "offline" and ns.Sync:InviteLeft(f, name)
      r.left:SetShown(left ~= nil and left ~= false)
      if left then
        r.left:SetColor(left < 3 * 3600 and "B0321E" or "B8742A")
        r.left:Set(width - 8 - (r.cancel:IsShown() and (r.cancel:GetWidth() + 8) or 0), left / ns.Sync.EXPIRE)
      end
      local h = math.max(28, math.ceil(r.wait:GetStringHeight() or 0) + 10) + (left and 6 or 0)
      r:SetHeight(h)
      stack:Place(r, h, 2)
    end
    stack:Skip(10)
  end
  pf.invRows:HideFrom(nInv + 1)
  -- The cards: the Adventurers on the left page, the Friends of the fellowship and the Fallen on the right, each under
  -- its folding heading.
  local shown = 0
  local function place(name, into)
    local c = pf.cards:Get(shown + 1)
    if not c then return end
    shown = shown + 1
    if c:GetParent() ~= into.parent then
      c:SetParent(into.parent)
      c.fallenMark:SetFrameLevel(c:GetFrameLevel() + 8); c.ringMark:SetFrameLevel(c:GetFrameLevel() + 8)
    end
    local m = f.members[name]
    c.who = name
    UI.SetRole(c.role, m.role)
    c.name:SetText(ns.Short(name))
    setNameColor(c.name, f, name)
    c.rank:SetText(name == f.leader and L.RANK_LEADER or "")
    c.level:SetText(Hr:Level(f, name))
    -- The Fallen (SPEC §9): a memorial, not a status. No presence or addon version; their class crest greyed with a
    -- skull on its corner (not their face), the card in muted violet, "Fallen" where the standing goes, and in place of
    -- the XP when and where they fell (the foe a best guess: the game does not tell an addon who killed you).
    local fallen = f.falls and ns.Challenges:Fallen(f, name) or nil
    local kind = Hr:Presence(f, name)
    local word, detail, tip = Hr:PresenceText(f, name)
    c.presence:Set(kind)
    c.status:SetText(word)
    c.status:SetTextColor(Theme:RGBA(UI.PRESENCE_TEXT[kind]))
    c.detail:SetText(detail or "")
    c.presence:SetShown(not fallen); c.status:SetShown(not fallen); c.detail:SetShown(not fallen)
    c.tip = { { tip, 1, 0.82, 0 } }
    local ver, newestVer = Hr:OldVersion(f, name)
    c.old:SetShown(ver ~= nil and not fallen)
    if ver then c.tip[2] = { L.OLD_ADDON_TIP:format(ver, newestVer), 1, 0.6, 0.2 } end
    local bearer = ns.Challenges:Bearer(f, name)
    if bearer then c.tip[#c.tip + 1] = { L.CARD_RING_TIP:format(f.ring.item or L.RING_A_RING), 1, 0.82, 0 } end
    local st, color = Hr:Standing(f, name)
    c.standing:SetText(st or "")
    if st then c.standing:SetTextColor(Theme:RGBA(color)) end
    c.line:SetText(roleLine(f, name))
    local drawn = false
    if fallen then ns.Models:Clear(c.portrait) else drawn = ns.Models:Place(name, "portrait", c.portrait) end
    c.crest:SetShown(not drawn)
    if not drawn then c.crest:Set(select(2, Hr:ClassName(f, name))) end
    c.crest.icon:SetDesaturated(fallen ~= nil); c.crest.ring:SetDesaturated(fallen ~= nil)
    c.fallenMark:SetShown(fallen ~= nil)
    c.ringMark:SetShown(bearer and not fallen)
    c.role:SetAlpha(fallen and 0.5 or 1)
    c.level:SetTextColor(Theme:RGBA(fallen and "ink2" or "ink"))
    c.bgRole, c.borderRole = fallen and FALLEN_BG or nil, fallen and Hr.FALLEN or "line"
    c:Paint()
    local pct, rested, text = Hr:XP(f, name)
    if fallen then pct, text = nil, ns.Challenges:FallenLine(fallen) end
    c.bar:Set(width - 16 - CARD_X, pct, rested)
    c.bar:SetShown(pct ~= nil)
    c.xp:SetText(text or "")
    c.xp:SetTextColor(Theme:RGBA(fallen and Hr.FALLEN or "ink2"))
    -- The line ends before the standing on its right ("fighting Defias Pillager" ran into "Fallen"; check of 1 Nov
    -- 2026, 01:20): its width is what is left, and the rest goes to the tooltip.
    c.xp:SetWidth(math.max(40, width - 8 - CARD_X - 10 - (c.standing:GetStringWidth() or 0) - 12))
    c.xp:SetWordWrap(false)
    if fallen then c.tip = { { text, 0.75, 0.65, 0.9 }, { L.FALLEN_CARD_TIP, 1, 1, 1 } } end
    c:SetAlpha(fallen and 1 or (kind == "away" and 0.6 or (kind == "offline" and 0.8 or 1)))
    c:SetWidth(width - 8)
    into:Place(c, 72, 6)
  end
  local groups = { [0] = {}, {}, {} }
  for _, name in ipairs(names) do local g = groups[group(name)]; g[#g + 1] = name end
  local ls = UI.Stack(pf.lscroll.child)
  for _, name in ipairs(groups[0]) do place(name, ls) end
  pf.lscroll:SetContentHeight(ls.y + 4)
  for g = 1, 2 do
    local h, list = pf.folds[g], groups[g]
    h:SetShown(#list > 0)
    if #list > 0 then
      h:SetText(h.label:format(#list))
      local open = opened[h.id]
      if open == nil then open = #list <= FEW end
      h:SetOpen(open)
      stack:Skip(4)
      stack:Place(h, 29, 6)
      if open then for _, name in ipairs(list) do place(name, stack) end end
    end
  end
  pf.cards:HideFrom(shown + 1)
  pf.scroll:SetContentHeight(stack.y + 4)
  pf.art:Fit(stack.y) -- the road ahead under what the right page holds
end

---------------------------------------------------------------------------
-- Inspect
---------------------------------------------------------------------------
local function buildInspect(pf, width)
  -- Left page: gear.
  local left = CreateFrame("Frame", nil, pf.left)
  left:SetAllPoints()
  pf.insL = left
  pf.iRole = UI.RoleIcon(left, 22)
  pf.iRole:SetPoint("TOPLEFT", 0, -4)
  pf.iName = UI.Text(left, 20, nil, "title")
  pf.iName:SetPoint("TOPLEFT", 30, 0)
  pf.iPresence = UI.Presence(left, 10)
  pf.iPresence:SetPoint("LEFT", pf.iName, "RIGHT", 8, 0)
  pf.iLine = UI.Text(left, 12, "ink2")
  pf.iLine:SetPoint("TOPLEFT", 30, -26)
  pf.iLine:SetWidth(width - 30 - 96) -- stops before the item level box (it ran under it; seen in the UI tour)
  local ilvlBox = UI.Card(left)
  ilvlBox:SetSize(84, 48)
  ilvlBox:SetPoint("TOPRIGHT", 0, 2)
  -- What the number is: the average of the items shared, or why there is none (it said "1" with nothing to explain).
  ilvlBox:EnableMouse(true)
  UI.Tooltip(ilvlBox, function() return ilvlBox.tip or "" end)
  pf.ilvlBox = ilvlBox
  pf.iIlvl = UI.Text(ilvlBox, 20, "ink", "title", "CENTER")
  pf.iIlvl:SetPoint("TOP", 0, -7)
  local ilvlKey = UI.Text(ilvlBox, 9, "ink2", "body", "CENTER")
  ilvlKey:SetPoint("TOP", pf.iIlvl, "BOTTOM", 0, -2)
  ilvlKey:SetText(L.ITEM_LEVEL)
  -- The paper doll, like the game's character window (redone 27 Oct 2026: a flat beige box with loose slots did not
  -- look like the game): one dark stage in the book's gold and leather frame, the race's dressing-room picture
  -- behind the Companion in 3D (UI/Models.lua; drag to turn), armour slots down both sides inside it and the weapons
  -- in a row under the model. Each slot is the game's item button: the icon in a border of the item's quality (the
  -- game's own icon border), the empty ones with the slot's picture. Item levels are in the tooltip and the average
  -- above, not on every icon (a "1" on each read like a stack count).
  local STAGE_TOP = 62
  pf.stage = CreateFrame("Frame", nil, left)
  pf.stage:SetPoint("TOPLEFT", 6, -STAGE_TOP); pf.stage:SetPoint("BOTTOMRIGHT", left, "BOTTOMRIGHT", -6, 26)
  pf.stage.back = pf.stage:CreateTexture(nil, "BACKGROUND", nil, -2)
  pf.stage.back:SetAllPoints(); pf.stage.back:SetColorTexture(0.06, 0.045, 0.03, 1)
  pf.stage.race = pf.stage:CreateTexture(nil, "BACKGROUND", nil, -1)
  pf.stage.race:SetAllPoints()
  -- A soft dark edge, so the slots and the frame stand out from the picture.
  for _, side in ipairs({ { "LEFT", "HORIZONTAL", 0.85, 0 }, { "RIGHT", "HORIZONTAL", 0, 0.85 } }) do
    local v = pf.stage:CreateTexture(nil, "BACKGROUND", nil, 1)
    v:SetPoint("TOP"); v:SetPoint("BOTTOM"); v:SetPoint(side[1]); v:SetWidth(90)
    UI.SetGradient(v, side[2], { 0, 0, 0, side[3] }, { 0, 0, 0, side[4] })
  end
  local floor = pf.stage:CreateTexture(nil, "BACKGROUND", nil, 1)
  floor:SetPoint("BOTTOMLEFT"); floor:SetPoint("BOTTOMRIGHT"); floor:SetHeight(90)
  UI.SetGradient(floor, "VERTICAL", { 0, 0, 0, 0.9 }, { 0, 0, 0, 0 })
  -- The window's frame art (its parchment cleared): DialogFrame's own file left a cream band inside the gold.
  UI.DialogFrame(pf.stage, { border = true, file = "WindowFrame" })
  pf.gear = {}
  local SLOT, GAP, PAD = 38, 44, 12
  local LEFT_N, RIGHT_N = 6, 8 -- head to wrist on the left, hands to trinkets on the right, then the weapons
  for n = 1, #Hr.SLOTS do
    local g = CreateFrame("Button", nil, pf.stage)
    g:SetSize(SLOT, SLOT)
    local col
    if n <= LEFT_N then
      col = 0; g:SetPoint("TOPLEFT", pf.stage, "TOPLEFT", PAD, -PAD - (n - 1) * GAP)
    elseif n <= LEFT_N + RIGHT_N then
      col = 1; g:SetPoint("TOPRIGHT", pf.stage, "TOPRIGHT", -PAD, -PAD - (n - LEFT_N - 1) * GAP)
    else
      col = 2
      local k, of = n - LEFT_N - RIGHT_N, #Hr.SLOTS - LEFT_N - RIGHT_N
      g:SetPoint("BOTTOM", pf.stage, "BOTTOM", (k - (of + 1) / 2) * GAP, PAD)
    end
    g.icon = g:CreateTexture(nil, "ARTWORK")
    g.icon:SetAllPoints()
    -- The game's item border (Interface\Common\WhiteIconFrame), tinted by quality; a dark one when empty.
    g.frame = g:CreateTexture(nil, "OVERLAY")
    g.frame:SetAllPoints()
    g.frame:SetTexture("Interface\\Common\\WhiteIconFrame")
    g.hl = g:CreateTexture(nil, "HIGHLIGHT")
    g.hl:SetAllPoints(); g.hl:SetTexture("Interface\\Buttons\\ButtonHilight-Square"); g.hl:SetBlendMode("ADD")
    g.ilvl = UI.Text(g, 11, "white", "title", "RIGHT"); g.ilvl:Hide() -- kept for tests; not drawn
    -- The slot and the item's name: kept for the tooltip of an empty slot and for tests; not drawn on the page.
    g.slot = UI.Text(g, 11, "ink2"); g.slot:Hide()
    g.name = UI.Text(g, 13, nil); g.name:Hide()
    -- The item's tooltip like the game's own: your own items as on the character sheet (no comparison with
    -- themselves), another Hero's compared with what you wear only while Shift is held (it showed the "Equipped"
    -- copy at once).
    local function tip()
      GameTooltip:SetOwner(g, col == 1 and "ANCHOR_LEFT" or "ANCHOR_RIGHT")
      if not g.id then GameTooltip:SetText(g.slot:GetText() or ""); GameTooltip:Show() return end
      if g.mine and GameTooltip.SetInventoryItem then GameTooltip:SetInventoryItem("player", Hr.SLOTS[n][2])
      elseif GameTooltip.SetItemByID then GameTooltip:SetItemByID(g.id)
      else GameTooltip:SetText(g.name:GetText()) end
      GameTooltip:Show()
      -- After Show: the game may add its comparison while showing an item.
      local compare = not g.mine and IsModifiedClick and IsModifiedClick("COMPAREITEMS")
      if compare and GameTooltip_ShowCompareItem then GameTooltip_ShowCompareItem(GameTooltip)
      elseif not compare and GameTooltip_HideShoppingTooltips then GameTooltip_HideShoppingTooltips(GameTooltip) end
    end
    g:SetScript("OnEnter", function() tip(); g:RegisterEvent("MODIFIER_STATE_CHANGED") end)
    g:SetScript("OnLeave", function() g:UnregisterEvent("MODIFIER_STATE_CHANGED"); GameTooltip:Hide() end)
    g:SetScript("OnEvent", function() if GameTooltip:IsOwned(g) then tip() end end)
    pf.gear[n] = g
  end
  -- The model between the slot columns and above the weapons.
  pf.modelBox = CreateFrame("Frame", nil, pf.stage)
  pf.modelBox:SetPoint("TOPLEFT", PAD + SLOT + 6, -PAD)
  pf.modelBox:SetPoint("BOTTOMRIGHT", -(PAD + SLOT + 6), PAD + SLOT + 4)
  pf.modelBox:SetFrameLevel(pf.stage:GetFrameLevel() + 1)
  -- U3 (the checks of 29 Oct and 1 Nov 2026): someone not near cannot be drawn (the shared looks probe, 31 Oct 2026),
  -- so in place of an empty model box and slots, a card: their class crest, class and role, item level, their gear
  -- as a list in quality colours, and when they were last near.
  local card = CreateFrame("Frame", nil, pf.stage)
  card:SetPoint("TOPLEFT", 22, -20); card:SetPoint("BOTTOMRIGHT", -22, 18)
  card:SetFrameLevel(pf.stage:GetFrameLevel() + 3)
  local cw = width - 12 - 44
  card.crest = UI.ClassCrest(card, 76)
  card.crest:SetPoint("TOPLEFT", -6, 4)
  card.role = UI.RoleIcon(card, 20)
  card.role:SetPoint("TOPLEFT", 82, -10)
  card.who = UI.Text(card, 16, "goldText", "title")
  card.who:SetPoint("LEFT", card.role, "RIGHT", 6, 0)
  card.ilvl = UI.Text(card, 13, "chipText")
  card.ilvl:SetPoint("TOPLEFT", 82, -40)
  card.note = UI.WrapText(card, 11, "chipText", cw)
  card.note:SetPoint("BOTTOMLEFT", 0, 0)
  card.rows = {}
  for n = 1, #Hr.SLOTS do
    local r = CreateFrame("Button", nil, card)
    r:SetSize(cw, 18)
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(16, 16); r.icon:SetPoint("LEFT")
    r.name = UI.Text(r, 12, nil, "body")
    r.name:SetPoint("LEFT", 22, 0); r.name:SetWidth(cw - 22 - 96)
    r.slot = UI.Text(r, 11, "chipText", "body", "RIGHT")
    r.slot:SetPoint("RIGHT")
    r:SetScript("OnEnter", function()
      if not (r.id and GameTooltip.SetItemByID) then return end
      GameTooltip:SetOwner(r, "ANCHOR_RIGHT"); GameTooltip:SetItemByID(r.id); GameTooltip:Show()
    end)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    card.rows[n] = r
  end
  card.none = UI.Text(card, 12, "chipText")
  card.none:SetPoint("TOPLEFT", 0, -92)
  card.none:SetText(L.GEAR_NONE)
  card:Hide()
  pf.card = card
  -- A Fallen Adventurer (SPEC §9): a memorial in place of the gear and the model, over the picture greyed and dimmed.
  -- Their class crest greyed with the skull on its rim, "In memory of", where and when they fell, and the Chronicle.
  local mem = CreateFrame("Frame", nil, pf.stage)
  mem:SetAllPoints()
  mem:SetFrameLevel(pf.stage:GetFrameLevel() + 2)
  -- (Smaller and higher since U41, to leave room for the stone and its candles at the foot.)
  mem.crest = UI.ClassCrest(mem, 100)
  mem.crest:SetPoint("TOP", 0, -30)
  mem.mark = CreateFrame("Frame", nil, mem)
  mem.mark:SetSize(36, 36)
  mem.mark:SetPoint("CENTER", mem.crest, "BOTTOMRIGHT", -16, 16)
  mem.mark:SetFrameLevel(mem:GetFrameLevel() + 4)
  local ring = UI.Round(mem.mark, "ARTWORK", 36)
  ring:SetPoint("CENTER"); Theme:Fill(ring, Hr.FALLEN, 1)
  mem.skull = UI.Round(mem.mark, "OVERLAY", 30)
  mem.skull:SetPoint("CENTER")
  UI.SetIcon(mem.skull, ns.ICONS.hist_fallen)
  local inner = width - 2 * (PAD + 24)
  mem.title = UI.Text(mem, 22, "goldText", "title", "CENTER")
  mem.title:SetPoint("TOP", mem.crest, "BOTTOM", 0, -20)
  mem.title:SetWidth(inner)
  mem.line = UI.WrapText(mem, 13, "chipText", inner)
  mem.line:SetJustifyH("CENTER")
  mem.line:SetPoint("TOP", mem.title, "BOTTOM", 0, -12)
  mem.honour = UI.Text(mem, 12, "B9A6CF", "body", "CENTER") -- the Fallen's violet, light enough for the dark stage
  mem.honour:SetPoint("TOP", mem.line, "BOTTOM", 0, -12)
  mem.honour:SetText(L.T_FALLEN_HONOURED)
  -- U41 (the check of 1 Nov 2026): Guild Together's memorial stone with its candle (U48), who lit a candle for them,
  -- and Light a candle (each Adventurer once).
  mem.light = UI.TextButton(mem, L.CANDLE_LIGHT, function() if pf.sel then ns.Challenges:LightCandle(pf.sel) end end, "primary", 12)
  mem.light:SetPoint("BOTTOM", 0, 16)
  mem.lit = UI.WrapText(mem, 12, "chipText", inner)
  mem.lit:SetJustifyH("CENTER")
  mem.stone = mem:CreateTexture(nil, "ARTWORK")
  mem.stone:SetSize(88, 88)
  mem.stone:SetPoint("BOTTOM", mem.lit, "TOP", 0, 4)
  mem.stone:SetShown(ns.SetProp(mem.stone, "stone"))
  mem:Hide()
  pf.memorial = mem
  -- The slots above the model (it turns when dragged between them).
  for _, g in ipairs(pf.gear) do g:SetFrameLevel(pf.stage:GetFrameLevel() + 10) end
  pf.gearAsOf = UI.WrapText(left, 12, "ink2", width)
  pf.gearAsOf:SetPoint("BOTTOMLEFT", 0, 0)

  -- Right page: XP, facts, dungeons, roles, away, play another character.
  pf.iscroll = UI.Scroll(pf.right)
  pf.iscroll:SetAllPoints()
  pf.insR = pf.iscroll
  local R = pf.iscroll.child
  pf.back = UI.TextButton(R, L.ALL_HEROES, function() pf.sel = nil; ns.Window:Refresh() end, "link", 13)
  pf.iRank = UI.Text(R, 12, "accentText", "body", "RIGHT")
  pf.iBar = xpBar(R, 12, true)
  pf.iXp = UI.Text(R, 12, "ink2")
  -- Another Hero: Whisper and Invite to group (SPEC §6).
  pf.whisper = UI.TextButton(R, L.WHISPER, function() if pf.sel then ns.Together:Whisper(pf.sel) end end, "plain", 12)
  pf.inviteBtn = UI.TextButton(R, L.INVITE_TO_GROUP, function() if pf.sel then ns.Together:Invite({ pf.sel }) end end, "plain", 12)
  -- Number tiles (U6): the level, the chapter's levels and the status (a word, drawn smaller when long).
  pf.facts = {}
  for i, s in ipairs({ { L.FACT_LEVEL, "bn_level" }, { L.FACT_CHAPTER, "chapter" }, { L.FACT_STATUS, "heroes" } }) do
    pf.facts[i] = UI.NumberTile(R, (width - 24) / 3, 54, s[1], ns.ICONS[s[2]])
  end
  pf.chHead = UI.Text(R, 17, "ink", "title")
  pf.chHead:SetText(L.THIS_CHAPTER)
  pf.dungeons = UI.Pool(function()
    local d = CreateFrame("Frame", nil, R)
    d:SetSize(width - 8, 22)
    d.done = UI.Check(d, 16)
    d.done:SetPoint("LEFT")
    d.wait = d:CreateTexture(nil, "ARTWORK")
    -- Not cleared yet: the yellow dot used for open dungeons and bosses (the ready-check "?" read like a quest).
    d.wait:SetSize(12, 12); d.wait:SetPoint("LEFT", 2, 0)
    d.wait:SetTexture(ns.MARKS.open)
    d.name = UI.Text(d, 13, "ink")
    d.name:SetPoint("LEFT", 22, 0)
    d.note = UI.Text(d, 12, "ink2", "body", "RIGHT")
    d.note:SetPoint("RIGHT")
    return d
  end)
  -- A Fallen Adventurer's journey (SPEC §9), in place of this chapter: when they joined and fell, the dungeons they
  -- cleared and the firsts they earned (named under the row).
  pf.memHead = UI.Text(R, 17, "ink", "title")
  pf.memHead:SetText(L.MEMORIAL_HEAD)
  pf.memRows = {}
  for i, key in ipairs({ "MEMORIAL_JOINED", "MEMORIAL_FELL_ON", "MEMORIAL_CLEARED", "MEMORIAL_FIRSTS" }) do
    local r = CreateFrame("Frame", nil, R)
    r:SetSize(width - 8, 22)
    r.label = UI.Text(r, 13, "ink2")
    r.label:SetPoint("LEFT")
    r.label:SetText(L[key])
    r.value = UI.Text(r, 13, "ink", "body", "RIGHT")
    r.value:SetPoint("RIGHT")
    pf.memRows[i] = r
  end
  pf.memFirsts = UI.WrapText(R, 12, "ink", width - 8)
  pf.memNote = UI.WrapText(R, 12, "ink2", width - 8)
  pf.memNote:SetText(L.CHAL_BOOK_ANEW)
  pf.rolesDiv = UI.Divider(R)
  pf.roleLabel = UI.Text(R, 13, "ink")
  pf.roleLabel:SetText(L.ROLE)
  pf.roleChoice = UI.RoleChoice(R, ns.ROLE_CHOICES, function() local f = F:Current(); return f and pf.sel and f.members[pf.sel] and f.members[pf.sel].role end,
    function(v)
      local f = F:Current()
      local m = f and f.members[pf.sel]
      if m then F:SetRoles(pf.sel, v, m.second ~= v and m.second or "") end
    end)
  pf.secondLabel = UI.Text(R, 13, "ink")
  pf.secondLabel:SetText(L.SECOND_ROLE)
  -- One row of secondary roles per primary role (the primary one is left out, as in the mockup).
  pf.seconds = {}
  for _, primary in ipairs({ "Tank", "Healer", "DPS" }) do
    local opts = { { L.NONE, "" } }
    for _, r in ipairs(ns.ROLE_CHOICES) do if r[2] ~= primary then opts[#opts + 1] = r end end
    pf.seconds[primary] = UI.Choice(R, opts, function() local f = F:Current(); local m = f and f.members[pf.sel]; return m and (m.second or "") end,
      function(v) local f = F:Current(); local m = f and f.members[pf.sel]; if m then F:SetRoles(pf.sel, m.role, v) end end)
  end
  pf.awayDiv = UI.Divider(R)
  pf.awayText = UI.WrapText(R, 13, "ink", width - 120)
  pf.awayButton = UI.TextButton(R, L.IM_AWAY, function()
    local f = F:Current()
    if f and f.members[pf.sel] then F:SetAway(pf.sel, not f.members[pf.sel].away) end
  end, "plain", 13)
  -- Friend of the fellowship (SPEC §1.1): become one, or play on as an Adventurer (at or below the chapter's cap).
  pf.friendDiv = UI.Divider(R)
  pf.friendHead = UI.Text(R, 17, "ink", "title")
  pf.friendHead:SetText(L.FRIEND_HEAD)
  pf.friendText = UI.WrapText(R, 13, "ink", width - 8)
  pf.friendButton = UI.TextButton(R, L.FRIEND_BECOME, function()
    local f = F:Current()
    if not f then return end
    if F:IsFriend(f, ns.Me()) then F:SetFriend(false)
    else ns.Window:Confirm(L.FRIEND_ASK, L.FRIEND_BECOME, function() F:SetFriend(true) end) end
  end, "plain", 13)
  pf.altHead = UI.Text(R, 17, "ink", "title")
  pf.altHead:SetText(L.PLAY_ANOTHER)
  pf.altHelp = UI.WrapText(R, 12, "ink2", width - 8)
end

local function refreshInspect(pf, ctx, width)
  local f, name = ctx.f, pf.sel
  local m = f.members[name]
  -- Watching an alt's fellowship (Fellowship/Watch.lua): nobody there is "you" to act as, the page only reads.
  local mine = name == ctx.me and not ctx.watching
  local h = Hr:Get(f, name) or {}
  local light = Theme:Current().light
  -- A Fallen Adventurer (SPEC §9): their memorial, not their gear and chapter.
  local memorial = f.falls and ns.Challenges:Memorial(f, name) or nil
  local fallen = memorial ~= nil
  local level = memorial and memorial.e.lvl or Hr:Level(f, name)

  -- Left: who, and their gear.
  UI.SetRole(pf.iRole, m.role)
  pf.iRole:SetAlpha(fallen and 0.5 or 1)
  pf.iName:SetText(ns.Short(name))
  setNameColor(pf.iName, f, name)
  local online = Hr:Online(f, name)
  local kind, inGame = Hr:Presence(f, name) -- inGame: also online when only the game says so (Invite to group works)
  pf.iPresence:Set(kind)
  pf.iPresence:SetShown(not fallen)
  -- The addon version (not a development copy's "@project-version@"); an old one in orange.
  local old = Hr:OldVersion(f, name)
  local ver = old and ("|cff" .. OLD .. L.INSPECT_VERSION_OLD:format(old) .. "|r")
    or (ns.ParseVersion(h.ver) and L.INSPECT_VERSION:format(h.ver)) or ""
  if fallen then pf.iLine:SetText(L.INSPECT_LINE:format(level, Hr:ClassName(f, name), L.STATUS_FALLEN))
  else pf.iLine:SetText(L.INSPECT_LINE:format(level, Hr:ClassName(f, name), L[UI.PRESENCE_LC[kind]]) .. ver) end
  pf.gearAsOf:SetShown(not fallen)
  pf.memorial:SetShown(fallen)
  local gear = h.gear or {}
  local total, count = 0, 0
  for n, g in ipairs(pf.gear) do
    local item = gear[n]
    g.slot:SetText(L[Hr.SLOTS[n][1]] .. (item and item.ilvl > 0 and ("  ·  " .. item.ilvl) or ""))
    g.name:SetText(item and item.name or L.SLOT_EMPTY)
    local q = item and item.q or 0
    g.name:SetTextColor(ns.Hex(ns.QualityHex(q, light)))
    g.id = item and item.id
    g.mine = mine
    local icon = item and Hr.ItemIcon(item.id)
    g.icon:SetTexture(icon or Hr.SlotPicture(Hr.SLOTS[n][2]))
    g.icon:SetDesaturated(false)
    g.icon:SetAlpha(1)
    -- Quality border as the game shows it (common items keep a plain dark border, as in the character window).
    if item and q >= 2 then g.frame:SetVertexColor(ns.Hex(ns.QualityHex(q, false))); g.frame:SetAlpha(1)
    else g.frame:SetVertexColor(0.55, 0.45, 0.3); g.frame:SetAlpha(item and 0.9 or 0.6) end
    g.ilvl:SetText(item and item.ilvl > 0 and item.ilvl or "")
    if item and item.ilvl > 0 then total, count = total + item.ilvl, count + 1 end
  end
  pf.iIlvl:SetText(count > 0 and math.floor(total / count + 0.5) or "–")
  pf.ilvlBox.tip = count > 0 and L.ILVL_TIP:format(count, ns.Short(name)) or L.ILVL_NONE_TIP:format(ns.Short(name))
  pf.ilvlBox:SetAlpha(count > 0 and 1 or 0.6)
  -- The stage: the Companion in 3D, else their class crest and why.
  -- The race's dressing-room picture behind them (the game's art; the chapter's picture, darkened, without it).
  local race = mine and select(2, UnitRace("player")) or h.race
  local atlas = race and ("dressingroom-background-" .. tostring(race):lower())
  local hasAtlas = atlas and C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas) ~= nil
  if hasAtlas then pf.stage.race:SetAtlas(atlas); pf.stage.race:SetVertexColor(1, 1, 1); pf.stage.race:SetAlpha(1)
  else ns.Pages:SetChapterArt(pf.stage.race, ns.Pages:ArtOf(f, ns.Journey:CurrentIndex(f)), 400, 520, 0.5); pf.stage.race:SetVertexColor(0.45, 0.4, 0.35) end
  pf.stage.raceAtlas = hasAtlas and atlas or nil
  pf.stage.race:SetDesaturated(fallen)
  if fallen then
    pf.stage.race:SetVertexColor(0.4, 0.36, 0.46)
    ns.Models:Clear(pf.modelBox)
    local mem = pf.memorial
    mem.crest:Set(select(2, Hr:ClassName(f, name)))
    mem.crest.icon:SetDesaturated(true); mem.crest.ring:SetDesaturated(true)
    mem.title:SetText(L.MEMORIAL_TITLE:format(ns.Short(name)))
    mem.line:SetText(memorial.line)
    local who = {}
    for _, c in ipairs(ns.Challenges:Candles(f, name)) do who[#who + 1] = c.who == ns.Me() and L.YOU_LABEL or ns.Short(c.who) end
    mem.lit:SetText(#who > 0 and L.CANDLES_LIT:format(table.concat(who, ", ")) or L.CANDLES_NONE)
    local can = not ctx.watching and ns.Challenges:CanLight(f, name)
    mem.light:SetShown(can)
    mem.lit:ClearAllPoints(); mem.lit:SetPoint("BOTTOM", 0, can and 50 or 18)
  end
  local drawn = not fallen and ns.Models:Place(name, "body", pf.modelBox)
  -- Not near (U3): the card in place of the model, the slots and the item level box.
  local card = not fallen and not drawn
  pf.card:SetShown(card)
  pf.modelBox:SetShown(drawn)
  pf.ilvlBox:SetShown(drawn)
  for _, g in ipairs(pf.gear) do g:SetShown(drawn) end
  if card then
    local cd = pf.card
    local className, token = Hr:ClassName(f, name)
    cd.crest:Set(token)
    UI.SetRole(cd.role, m.role)
    cd.who:SetText(L.INSPECT_CARD_WHO:format(className or "", L["ROLE_" .. (m.role or "DPS"):upper()] or m.role or ""))
    cd.ilvl:SetText(L.INSPECT_CARD_ILVL:format(pf.iIlvl:GetText()))
    local last = ns.Models:LastNear(name)
    cd.note:SetText(L.MODEL_NOT_MET:format(ns.Short(name)) .. " "
      .. (last and L.MODEL_LAST_NEAR:format(ns.TimeAgo(last)) or L.MODEL_NEVER_NEAR))
    -- Only the worn items, as close as the card's height lets them sit (at most 18 apart).
    local worn = {}
    for n = 1, #Hr.SLOTS do if gear[n] then worn[#worn + 1] = n end end
    local room = cd:GetHeight() - 92 - cd.note:GetStringHeight() - 10
    local step = math.max(13, math.min(18, room / math.max(1, #worn)))
    for i, r in ipairs(cd.rows) do
      local n = worn[i]
      local item = n and gear[n]
      r:SetShown(item ~= nil)
      if item then
        r.id = item.id
        r.icon:SetTexture(Hr.ItemIcon(item.id) or Hr.SlotPicture(Hr.SLOTS[n][2]))
        r.name:SetText(item.name or "")
        r.name:SetTextColor(ns.Hex(ns.QualityHex(item.q or 1, false)))
        r.slot:SetText(L[Hr.SLOTS[n][1]] .. (item.ilvl and item.ilvl > 0 and ("  ·  " .. item.ilvl) or ""))
        r:ClearAllPoints(); r:SetPoint("TOPLEFT", cd, "TOPLEFT", 0, -92 - (i - 1) * step)
      end
    end
    cd.none:SetShown(#worn == 0)
  end
  if not h.gear then pf.gearAsOf:SetText(L.GEAR_NONE)
  elseif online then pf.gearAsOf:SetText(L.GEAR_NOW:format(ns.Short(name)))
  else pf.gearAsOf:SetText(L.GEAR_AS_OF:format(ns.TimeAgo(h.gearTime or Hr:LastSeen(f, name)), ns.Short(name))) end

  -- Right.
  local R = pf.iscroll.child
  local s = UI.Stack(R)
  s:Place(pf.back, 24, 6)
  pf.iRank:ClearAllPoints(); pf.iRank:SetPoint("TOPRIGHT", R, "TOPRIGHT", -4, -6)
  pf.iRank:SetText(name == f.leader and L.RANK_LEADER or (m.friend and L.RANK_FRIEND or ""))
  pf.iRank:SetTextColor(Theme:RGBA(m.friend and Hr.FRIEND or "accentText"))
  -- (No XP or group for the Fallen: the bar, its line and Invite to group go.)
  local pct, rested, _, way = Hr:XP(f, name)
  if fallen then pct = nil end
  pf.iBar:Set(width - 8, pct, rested)
  pf.iBar:SetShown(pct ~= nil)
  if pct then s:Place(pf.iBar, 12, 4) end
  pf.iXp:SetText(way or "")
  pf.iXp:SetShown(not fallen)
  if not fallen then s:Place(pf.iXp, 14, 12) end
  local reach = not mine and not ctx.watching
  pf.whisper:SetShown(reach); pf.inviteBtn:SetShown(reach and not fallen)
  if reach then
    pf.inviteBtn:SetEnabled(inGame)
    s:Place(pf.whisper, 24, 12)
    pf.inviteBtn:ClearAllPoints(); pf.inviteBtn:SetPoint("LEFT", pf.whisper, "RIGHT", 8, 0)
  end
  local ch = ctx.chapter
  local st = Hr:Status(f, name)
  -- (The Fallen: their days in the fellowship where the chapter's levels go.)
  local days = memorial and (memorial.days or "-")
  local values = { level, fallen and days or (ch and (ch.floor .. "-" .. ch.cap) or "-"), st }
  pf.facts[2]:SetLabel(fallen and L.FACT_DAYS or L.FACT_CHAPTER)
  local y = s.y
  for i, tile in ipairs(pf.facts) do
    tile:Set(values[i])
    tile:ClearAllPoints(); tile:SetPoint("TOPLEFT", R, "TOPLEFT", (i - 1) * ((width - 24) / 3 + 8), -y); tile:Show()
  end
  s:Skip(66)
  -- The Fallen: their journey, from joining to the fall.
  pf.chHead:SetShown(not fallen)
  pf.memHead:SetShown(fallen); pf.memFirsts:SetShown(fallen); pf.memNote:SetShown(fallen)
  for _, r in ipairs(pf.memRows) do r:SetShown(fallen) end
  if fallen then
    s:Place(pf.memHead, 20, 6)
    local firsts = {}
    for _, key in ipairs(memorial.firsts) do firsts[#firsts + 1] = L["FIRSTN_" .. key:upper()] end
    local vals = { memorial.joined and ns.Challenges.Day(memorial.joined) or "-", ns.Challenges.Day(memorial.e.t),
      memorial.cleared, #firsts > 0 and #firsts or L.MEMORIAL_NONE }
    for i, r in ipairs(pf.memRows) do
      r.value:SetText(vals[i])
      r:SetWidth(width - 8)
      s:Place(r, 22, 2)
    end
    if #firsts > 0 then
      pf.memFirsts:SetText(table.concat(firsts, "  ·  "))
      s:Place(pf.memFirsts, pf.memFirsts:GetStringHeight(), 2)
    else pf.memFirsts:Hide() end
    s:Skip(10)
    s:Place(pf.memNote, pf.memNote:GetStringHeight(), 6)
  else
    s:Place(pf.chHead, 20, 6)
  end
  -- This chapter's dungeons, with this Hero's own clears.
  local list = {}
  for key, place in pairs(f.journey.place) do
    if ch and place.ch == ch.n and not fallen then
      local d = ns.Dungeon(key)
      if d then
        local n, of = ns.Clears:Progress(f, key, name)
        list[#list + 1] = { name = d[2], min = d[3], role = place.role, done = J:ClearedBy(f, key)[name] ~= nil, n = n, of = of }
      end
    end
  end
  table.sort(list, function(a, b) return a.min < b.min end)
  local shown = 0
  for i, dg in ipairs(list) do
    local d = pf.dungeons:Get(i)
    if not d then break end
    shown = i
    d.name:SetText(dg.name)
    d.done:SetShown(dg.done); d.wait:SetShown(not dg.done)
    d.note:SetText(dg.done and L.D_CLEARED or (dg.n > 0 and L.D_PARTIAL:format(dg.n, dg.of))
      or (dg.role == "o" and L.D_OPTIONAL or L.D_NOT_YET))
    s:Place(d, 22, 2)
  end
  pf.dungeons:HideFrom(shown + 1)

  -- Roles: yourself, or the leader for anyone.
  local canRoles = P.Can(f, ctx.me, "roles", name) and not ctx.watching and not fallen
  for _, w in ipairs({ pf.rolesDiv, pf.roleLabel, pf.roleChoice, pf.secondLabel }) do w:SetShown(canRoles) end
  for role, c in pairs(pf.seconds) do c:SetShown(canRoles and role == m.role) end
  if canRoles then
    s:Skip(8)
    pf.rolesDiv:ClearAllPoints(); pf.rolesDiv:SetPoint("TOPLEFT", R, "TOPLEFT", 0, -s.y); pf.rolesDiv:SetPoint("TOPRIGHT", R, "TOPRIGHT", 0, -s.y)
    s:Skip(20)
    s:Place(pf.roleLabel, 16, 4)
    pf.roleChoice:Refresh()
    s:Place(pf.roleChoice, pf.roleChoice:GetHeight(), 10)
    s:Place(pf.secondLabel, 16, 4)
    local sc = pf.seconds[m.role]
    if sc then sc:Refresh(); s:Place(sc, 24, 10) end
  end

  -- Yourself: away (not as a Friend of the fellowship: they never count, so are never away), being a Friend, and
  -- how to play another character here.
  -- (The Fallen are never away, nor become Friends of the fellowship.)
  local friend = m.friend == true
  for _, w in ipairs({ pf.awayDiv, pf.awayText, pf.awayButton }) do w:SetShown(mine and not friend and not fallen) end
  for _, w in ipairs({ pf.friendDiv, pf.friendHead, pf.friendText, pf.friendButton }) do w:SetShown(mine and not fallen) end
  for _, w in ipairs({ pf.altHead, pf.altHelp }) do w:SetShown(mine) end
  if mine then
    s:Skip(8)
    if not friend and not fallen then
      pf.awayDiv:ClearAllPoints(); pf.awayDiv:SetPoint("TOPLEFT", R, "TOPLEFT", 0, -s.y); pf.awayDiv:SetPoint("TOPRIGHT", R, "TOPRIGHT", 0, -s.y)
      s:Skip(20)
      pf.awayText:SetText(m.away == "forced" and L.AWAY_FORCED_TEXT or (m.away and L.AWAY_SELF_TEXT or L.AWAY_HINT))
      pf.awayButton:SetLabel(m.away and L.IM_BACK or L.IM_AWAY)
      local ay = s.y
      s:Place(pf.awayText, math.max(24, pf.awayText:GetStringHeight()), 14)
      pf.awayButton:ClearAllPoints(); pf.awayButton:SetPoint("TOPRIGHT", R, "TOPRIGHT", 0, -ay)
    end
    if not fallen then
      pf.friendDiv:ClearAllPoints(); pf.friendDiv:SetPoint("TOPLEFT", R, "TOPLEFT", 0, -s.y); pf.friendDiv:SetPoint("TOPRIGHT", R, "TOPRIGHT", 0, -s.y)
      s:Skip(20)
      local why = F:FriendBlock(f, not friend)
      local text = friend and L.FRIEND_ON_TEXT or L.FRIEND_HINT
      if why == "leader" then text = L.FRIEND_NOT_LEADER
      elseif why == "cap" then
        local cur = ns.Journey:Current(f)
        text = L.FRIEND_ON_TEXT .. " " .. L.FRIEND_OVER_CAP:format(ns.Journey:CapLevel(f, cur), Hr:Level(f, name))
      end
      pf.friendText:SetText(text)
      pf.friendButton:SetLabel(friend and L.FRIEND_BACK or L.FRIEND_BECOME)
      pf.friendButton:SetEnabled(why == nil)
      pf.friendButton:SetAlpha(why == nil and 1 or 0.5)
      -- U47: the Leader keeps the sentence, without a greyed button.
      pf.friendButton:SetShown(why ~= "leader")
      local fy = s.y
      s:Place(pf.friendHead, 20, 6)
      pf.friendButton:ClearAllPoints(); pf.friendButton:SetPoint("TOPRIGHT", R, "TOPRIGHT", 0, -(fy - 4))
      s:Place(pf.friendText, pf.friendText:GetStringHeight(), 14)
    end
    s:Place(pf.altHead, 20, 4)
    -- Switching is done from the other character now (Your characters: Take its place; 27 Oct 2026): this says how.
    pf.altHelp:SetText(L.ALT_HELP)
    s:Place(pf.altHelp, pf.altHelp:GetStringHeight(), 6)
  end
  pf.iscroll:SetContentHeight(s.y + 8)
end

---------------------------------------------------------------------------
local function build(pf)
  local width = ns.Window.PAGE_W
  buildList(pf, width)
  buildInspect(pf, width)
end

local function refresh(pf, ctx)
  local f = ctx.f
  if not f then return end
  if pf.sel and not f.members[pf.sel] then pf.sel = nil end
  local inspecting = pf.sel ~= nil
  pf.listL:SetShown(not inspecting); pf.listR:SetShown(not inspecting)
  pf.insL:SetShown(inspecting); pf.insR:SetShown(inspecting)
  local width = ns.Window.PAGE_W
  if inspecting then refreshInspect(pf, ctx, width) else refreshList(pf, ctx, width) end
end

-- No title (U201, the owner, 14 Nov 2026): Invite Adventurers heads the right page, the count is under the banner, and
-- inspect has its own headings.
ns.Pages:Register({ id = "heroes", label = L.NAV_HEROES, build = build, refresh = refresh, news = { quests = true, gear = true },
  header = "none" })
