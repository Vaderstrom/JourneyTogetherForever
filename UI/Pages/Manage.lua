-- Manage (SPEC §4.9), the Leader's, in Admin. One sidebar entry with two tabs, each a page of its own (parent =
-- "manage"); on the right of both a bar says the rules are edited on the Rules page (U143):
--   manage            Adventurers: every Adventurer with a menu (away, lead, remove); invites.
--   managefellowship  The fellowship: its name, banner colour and emblem; your banner as the others see it; Leave.
-- What needs the Leader is in the Inbox (U144). (Everyone invites on the Adventurers page too.) Join only by invitation.
local _, ns = ...
local L = ns.L
local UI, Theme = ns.UI, ns.Theme
local F, P = ns.Fellowship, ns.Permissions

-- Who takes over if the leader stops playing: the longest-serving Adventurer (two ranks, 27 Oct 2026).
local function takeoverText(f)
  local leader = ns.Short(f.leader)
  if f.rules.takeoverNever then return L.TAKEOVER_NEVER:format(leader) end
  local first = ns.Progress:LongestServing(f)
  if first then return L.TAKEOVER_FIRST:format(leader, f.rules.takeover, ns.Short(first)) end
  return L.TAKEOVER_NOBODY:format(leader, f.rules.takeover)
end
ns.ManageTexts = { takeoverText = takeoverText }

-- The tab strip at the top of each tab's left page. Returns the height it takes.
local TABS = { { "MG_TAB_ADVENTURERS", "manage", "heroes" }, { "MG_TAB_FELLOWSHIP", "managefellowship", "manage" } }
function ns.ManageTabs(pf)
  local W = ns.Window
  local opts = {}
  for i, t in ipairs(TABS) do opts[i] = { L[t[1]], t[2], t[3] } end
  pf.tabs = UI.Tabs(pf.left, opts, function() return W.current end, function(id) W:ShowPage(id) end, W.PAGE_W - 8)
  pf.tabs:SetPoint("TOPLEFT", 0, 0)
  return 40
end

-- Where the rules are edited (U143, the owner's condition of 9 Nov 2026 that it is clear to the Leader): a bar at the
-- top of the right page with Open the Rules page. Returns the bar; its height is RULES_BAR_H.
local RULES_BAR_H = 64
local function rulesBar(parent, width)
  local b = UI.Card(parent, "gold")
  b:SetSize(width, RULES_BAR_H)
  b.text = UI.WrapText(b, 13, "ink", width - 24, "book")
  b.text:SetPoint("TOPLEFT", 12, -9)
  b.text:SetText(L.MG_RULES_BAR)
  b.btn = UI.TextButton(b, L.MG_OPEN_RULES, function() ns.Window:ShowPage("rules") end, "plain", 12)
  b.btn:SetPoint("BOTTOMRIGHT", -10, 8)
  return b
end

---------------------------------------------------------------------------
-- Adventurers (manage)
---------------------------------------------------------------------------
local function build(pf)
  local W = ns.Window
  local width = W.PAGE_W - 8
  local top = ns.ManageTabs(pf)

  -- Left: the Adventurers.
  pf.lscroll = UI.Scroll(pf.left)
  pf.lscroll:SetPoint("TOPLEFT", 0, -top); pf.lscroll:SetPoint("BOTTOMRIGHT")
  local L1 = pf.lscroll.child
  -- What the Leader does here and who takes over, behind the "?".
  pf.memHead = UI.SectionHeader(L1, width)
  pf.memHead:SetText(L.NAV_HEROES)
  pf.memHead:SetHelp("") -- the "?" made now, not during combat
  pf.rows = UI.Pool(function()
    local r = CreateFrame("Frame", nil, L1)
    r:SetSize(width, 52)
    r.role = UI.RoleIcon(r, 18)
    r.role:SetPoint("TOPLEFT", 0, -4)
    r.name = UI.Text(r, 14, nil, "body")
    r.name:SetPoint("LEFT", r.role, "RIGHT", 6, 0)
    r.level = UI.Text(r, 12, "ink2")
    r.level:SetPoint("LEFT", r.name, "RIGHT", 8, 0)
    r.lead = UI.Text(r, 12, "accent")
    r.lead:SetPoint("TOPLEFT", 24, -28)
    -- Mark away, Make leader and Remove in a "⋯" menu (in a row they ran off the page; seen in the UI tour).
    r.menu = UI.MenuButton(r, function()
      local f, me, list = F:Current(), ns.Me(), {}
      if not f or not f.members[r.who] or r.who == f.leader then return list end
      if f.leader == me then
        list[#list + 1] = { f.members[r.who].away == "forced" and L.CLEAR_AWAY or L.MARK_AWAY,
          function() F:SetAway(r.who, f.members[r.who].away ~= "forced") end }
        list[#list + 1] = { L.MAKE_LEADER, function()
          W:Confirm(L.MAKE_LEADER_CONFIRM:format(ns.Short(r.who)), L.MAKE_LEADER, function() F:MakeLeader(r.who) end)
        end }
      end
      if P.Can(f, me, "remove", r.who) then
        list[#list + 1] = { L.REMOVE, function()
          W:Confirm(L.REMOVE_CONFIRM:format(ns.Short(r.who)), L.REMOVE, function() F:Remove(r.who) end)
        end, true }
      end
      return list
    end)
    r.menu:SetPoint("TOPRIGHT", 0, -14)
    r.sep = UI.Solid(r, "BACKGROUND", "line", 0.6)
    r.sep:SetHeight(1); r.sep:SetPoint("BOTTOMLEFT"); r.sep:SetPoint("BOTTOMRIGHT")
    return r
  end)

  -- Right: invites.
  pf.rscroll = UI.Scroll(pf.right)
  pf.rscroll:SetAllPoints()
  local R1 = pf.rscroll.child
  pf.rulesBar = rulesBar(R1, width)
  pf.ihead = UI.Heading(R1, width, L.INVITE_HEROES, "")
  pf.nameLabel = UI.Text(R1, 13, "ink2")
  pf.nameLabel:SetText(L.INVITE_NAME)
  UI.InviteBox(pf, R1, width - 110, width)
  pf.noPerm = UI.WrapText(R1, 12, "ink2", width)
  pf.noPerm:SetText(L.NO_INVITE_PERM)
  pf.invites = UI.Pool(function()
    local r = CreateFrame("Frame", nil, R1)
    r:SetSize(width, 32)
    r.name = UI.Text(r, 14, "ink")
    r.name:SetPoint("LEFT")
    r.cancel = UI.TextButton(r, L.CANCEL, function() F:CancelInvite(r.who) end, "plain", 12)
    r.cancel:SetPoint("RIGHT")
    -- Wraps before Cancel ("· 23 hours left" ran under it; the check of 4 Nov 2026, 20:33).
    r.wait = UI.Text(r, 12, "ink2")
    -- (Its width is set in refresh: anchored at both ends its height was read as one line before the layout, and two
    -- lines ran into the bar below; the check of 8 Nov 2026.)
    r.wait:SetPoint("LEFT", r.name, "RIGHT", 6, 0)
    r.wait:SetWordWrap(true); r.wait:SetJustifyH("LEFT")
    r.wait:SetText(L.WAITING_ANSWER)
    -- The time an offline invite still waits, as a thin bar that empties over its day (U57).
    r.left = UI.Bar(r, 4)
    r.left:SetPoint("BOTTOMLEFT", 0, 2)
    return r
  end)
  pf.noInvites = UI.Text(R1, 12, "ink2")
  pf.noInvites:SetText(L.NO_OPEN_INVITES)
end

local function refresh(pf, ctx)
  local f = ctx.f
  if not f then return end
  pf.tabs:Refresh()
  local me, width = ctx.me, ns.Window.PAGE_W - 8
  local light = Theme:Current().light

  -- Left page: the Adventurers.
  local s = UI.Stack(pf.lscroll.child)
  pf.memHead:SetHelp(L.MANAGE_HELP_LEADER .. "\n\n" .. takeoverText(f))
  s:Place(pf.memHead, 29, 6)
  local shown = 0
  for i, name in ipairs(F:Members(f)) do
    local r = pf.rows:Get(i)
    if not r then break end
    shown = i
    local m = f.members[name]
    r.who = name
    UI.SetRole(r.role, m.role)
    r.name:SetText(ns.Short(name))
    local hex = ns.ClassHex(m.class, light)
    if hex then r.name:SetTextColor(ns.Hex(hex)) else r.name:SetTextColor(Theme:RGBA("ink")) end
    r.level:SetText(m.level and L.LEVEL_N:format(m.level) or "")
    local isLead = name == f.leader
    r.lead:SetText(isLead and L.RANK_LEADER or (m.friend and L.RANK_FRIEND or L.RANK_MEMBER))
    r.lead:SetTextColor(Theme:RGBA(isLead and "accentText" or (m.friend and ns.Hero.FRIEND or "ink2")))
    r.lead:Show()
    r.menu:Update()
    r:SetWidth(width)
    s:Place(r, 54, 4)
  end
  pf.rows:HideFrom(shown + 1)
  pf.lscroll:SetContentHeight(s.y + 8)

  -- Right page: invite, and the open invites.
  local t = UI.Stack(pf.rscroll.child)
  t:Place(pf.rulesBar, RULES_BAR_H, 10)
  pf.ihead:Set(L.INVITE_HEROES, L.INVITE_HELP:format(f.faction or ""))
  t:Place(pf.ihead, pf.ihead:GetHeight(), 4)
  local canInvite = P.Can(f, me, "invite")
  pf.noPerm:SetShown(not canInvite)
  for _, w in ipairs({ pf.nameLabel, pf.invite, pf.send, pf.asFriend, pf.share }) do w:SetShown(canInvite) end
  if canInvite then
    t:Place(pf.nameLabel, 16, 2)
    local y = t.y
    t:Place(pf.invite, 28, 4)
    pf.send:ClearAllPoints(); pf.send:SetPoint("TOPRIGHT", pf.rscroll.child, "TOPRIGHT", 0, -y + 3)
    pf.asFriend:Refresh()
    t:Place(pf.asFriend, 24, 2)
    t:Place(pf.share, pf.share:GetHeight(), 10)
  else
    t:Place(pf.noPerm, pf.noPerm:GetStringHeight(), 10)
  end
  local names = {}
  for name in pairs(f.invites) do names[#names + 1] = name end
  table.sort(names)
  local n = 0
  for i, name in ipairs(names) do
    local r = pf.invites:Get(i)
    if not r then break end
    n = i
    r.who = name
    r.name:SetText(ns.Short(name) .. (f.inviteFriend and f.inviteFriend[name] and L.INV_AS_FRIEND or ""))
    -- What this client knows about the invite it sent: sending, offline (it waits), or received by their addon. (No
    -- answer from an addon that got it removes the invite and says so.)
    local st = ns.Sync:InviteStatus(name)
    local text, color = L.WAITING_ANSWER, "ink2"
    if st == "received" then text, color = L.INV_RECEIVED, "3E7A3A"
    elseif st == "offline" then text = ns.Sync:OfflineText(f, name)
    elseif st == "sending" then text = L.INV_SENDING end
    r.wait:SetText(text)
    r.wait:SetTextColor(Theme:RGBA(color))
    r.cancel:SetShown(P.Can(f, me, "uninvite", name))
    r.wait:SetWidth(math.max(60, width - r.name:GetStringWidth() - 6 - (r.cancel:IsShown() and r.cancel:GetWidth() + 8 or 0)))
    local left = st == "offline" and ns.Sync:InviteLeft(f, name)
    r.left:SetShown(left ~= nil and left ~= false)
    local h = math.max(32, math.ceil(r.wait:GetStringHeight() or 0) + 12) + (left and 6 or 0)
    if left then
      r.left:SetColor(left < 3 * 3600 and "B0321E" or "B8742A")
      r.left:Set(width - (r.cancel:IsShown() and (r.cancel:GetWidth() + 8) or 0), left / ns.Sync.EXPIRE)
    end
    r:SetHeight(h)
    t:Place(r, h, 2)
  end
  pf.invites:HideFrom(n + 1)
  pf.noInvites:SetShown(#names == 0)
  if #names == 0 then t:Place(pf.noInvites, 16, 4) end
  pf.rscroll:SetContentHeight(t.y + 8)
end

---------------------------------------------------------------------------
-- The fellowship (managefellowship)
---------------------------------------------------------------------------
local function buildFellowship(pf)
  local W = ns.Window
  local width = W.PAGE_W - 8
  local y = ns.ManageTabs(pf)
  local Lp = pf.left
  local function label(text, at)
    local t = UI.Text(Lp, 13, "ink2")
    t:SetPoint("TOPLEFT", 0, -at)
    t:SetText(text)
    return t
  end
  -- Left: the name, the banner colour and every emblem (as in Create a Fellowship).
  pf.renameLabel = label(L.NAME, y)
  pf.rename = UI.EditBox(Lp, width - 80, 48, "", function(t) F:Rename(t) end)
  pf.rename:SetPoint("TOPLEFT", 0, -(y + 18))
  pf.save = UI.TextButton(Lp, L.SAVE, function() F:Rename(pf.rename:GetText()) end, "plain", 13)
  pf.save:SetPoint("TOPRIGHT", 0, -(y + 17))
  pf.bannerLabel = label(L.BANNER, y + 58)
  pf.swatches = UI.Swatches(Lp, function() local f = F:Current(); return f and f.color end,
    function(v) local f = F:Current(); if f then F:SetBanner(v, f.emblem) end end)
  pf.swatches:SetPoint("TOPLEFT", 0, -(y + 76))
  pf.emblemLabel = label(L.EMBLEM, y + 118)
  pf.emblemGrid = UI.EmblemGrid(Lp, width - 10, function(n)
    local f = F:Current()
    if f then ns.Sound("choose"); F:SetBanner(f.color, n) end
  end)
  pf.emblemGrid:SetPoint("TOPLEFT", 0, -(y + 138)); pf.emblemGrid:SetPoint("BOTTOMRIGHT", -8, 0)

  -- Right: the banner as the others see it, then leaving.
  local Rp = pf.right
  pf.rulesBar = rulesBar(Rp, width)
  pf.rulesBar:SetPoint("TOPLEFT")
  local top = RULES_BAR_H + 10
  pf.bHead = UI.Heading(Rp, width, L.MG_BANNER_HEAD, L.MG_BANNER_SUB)
  pf.bHead:SetPoint("TOPLEFT", 0, -top)
  pf.crest = UI.Crest(Rp, 96, 96)
  pf.crest:SetPoint("TOP", 0, -(top + 64))
  pf.fname = UI.Text(Rp, 20, "ink", "title", "CENTER")
  pf.fname:SetPoint("TOP", pf.crest, "BOTTOM", 0, -10); pf.fname:SetWidth(width)
  pf.fline = UI.Text(Rp, 13, "ink2", "body", "CENTER")
  pf.fline:SetPoint("TOP", pf.fname, "BOTTOM", 0, -4); pf.fline:SetWidth(width)
  -- Leaving as the leader hands the fellowship over (it is never ended for everyone); the box says to whom.
  pf.leaveBox = UI.Card(Rp, "B0321E")
  pf.leaveBox:SetWidth(width)
  pf.leaveBox:SetPoint("BOTTOMLEFT", 0, 0)
  pf.leaveText = UI.WrapText(pf.leaveBox, 13, "ink", width - 24, "book")
  pf.leaveText:SetPoint("TOPLEFT", 12, -10)
  pf.leave = UI.TextButton(pf.leaveBox, L.LEAVE_SHORT, function()
    local f = F:Current()
    if f then W:Confirm(F:LeaveQuestion(f), L.LEAVE_SHORT, function() F:Leave() end) end
  end, "danger", 13)
  pf.leave:SetPoint("BOTTOMRIGHT", -10, 10)
end

local function refreshFellowship(pf, ctx)
  local f = ctx.f
  if not f then return end
  pf.tabs:Refresh()
  if not pf.rename.edit:HasFocus() then pf.rename:SetText(f.name) end
  pf.swatches:Refresh()
  pf.emblemGrid:Refresh(f.color, f.emblem)
  pf.crest:Set(f.color, f.emblem)
  pf.fname:SetText(f.name)
  pf.fline:SetText(L.FELLOWSHIP_LINE:format(f.faction or "", ns.Short(f.leader)))
  local heir = F:Successor(f)
  pf.leaveText:SetText(heir and L.LEAVE_LEAD_TEXT:format(ns.Short(heir)) or L.LEAVE_ALONE_TEXT)
  pf.leaveBox:SetHeight(pf.leaveText:GetStringHeight() + 56)
  -- (The walkthrough's sample: nothing to leave.)
  pf.leave:SetShown(not ctx.demo)
end

ns.Pages:Register({ id = "manage", label = L.NAV_MANAGE, build = build, refresh = refresh,
  title = function() return L.TITLE_MANAGE, L.SUB_MANAGE end })
ns.Pages:Register({ id = "managefellowship", label = L.MG_TAB_FELLOWSHIP, icon = "manage", parent = "manage",
  build = buildFellowship, refresh = refreshFellowship, title = function() return L.TITLE_MANAGE, L.SUB_MANAGE_FELLOWSHIP end })
