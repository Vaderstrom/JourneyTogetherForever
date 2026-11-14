-- Manage (SPEC §4.9), the Leader's, in Admin, on one spread (U197, the owner, 14 Nov 2026: its two tabs went): left
-- every Adventurer with a menu (away, lead, remove); right a bar that says the rules are edited on the Rules page
-- (U143), then the fellowship's name, banner colour and emblem. Invites, the banner as the others see it and Leave live
-- on the Adventurers page only. What needs the Leader is in the Inbox (U144). Join only by invitation.
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

-- Where the rules are edited (U143, the owner's condition of 9 Nov 2026 that it is clear to the Leader): a bar at the
-- top of the right page with Open the Rules page.
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

local function build(pf)
  local W = ns.Window
  local width = W.PAGE_W - 8

  -- Left: the Adventurers.
  pf.lscroll = UI.Scroll(pf.left)
  pf.lscroll:SetAllPoints()
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
      -- The member the menu opened on: the pooled row may hold another by the time a choice is made (a redraw when
      -- someone joins; review of 1.7.0).
      local who = r.who
      local f, me, list = F:Current(), ns.Me(), {}
      if not f or not f.members[who] or who == f.leader then return list end
      if f.leader == me then
        list[#list + 1] = { f.members[who].away == "forced" and L.CLEAR_AWAY or L.MARK_AWAY,
          function() F:SetAway(who, f.members[who].away ~= "forced") end }
        -- A Friend of the fellowship and back (the owner, 10 Nov 2026); back only at or below the chapter's cap. Not for
        -- one of the Fallen (the rules refuse it).
        if P.Can(f, me, "friend", who) then
          local friend = F:IsFriend(f, who)
          list[#list + 1] = { friend and L.MAKE_ADVENTURER or L.MAKE_FRIEND, function()
            if friend then
              local ok, why = F:SetFriend(false, who)
              if not ok and why == "offline" then
                ns:Toast(nil, L.MAKE_ADVENTURER, L.MAKE_ADVENTURER_OFFLINE:format(ns.Short(who)))
              elseif not ok and why == "cap" then
                ns:Toast(nil, L.MAKE_ADVENTURER, L.MAKE_ADVENTURER_CAP:format(ns.Short(who),
                  ns.Journey:CapLevel(f, ns.Journey:Current(f)), ns.Hero:Level(f, who)))
              end
            else
              W:Confirm(L.MAKE_FRIEND_CONFIRM:format(ns.Short(who)), L.MAKE_FRIEND, function() F:SetFriend(true, who) end)
            end
          end }
        end
        list[#list + 1] = { L.MAKE_LEADER, function()
          W:Confirm(L.MAKE_LEADER_CONFIRM:format(ns.Short(who)), L.MAKE_LEADER, function() F:MakeLeader(who) end)
        end }
      end
      if P.Can(f, me, "remove", who) then
        list[#list + 1] = { L.REMOVE, function()
          W:Confirm(L.REMOVE_CONFIRM:format(ns.Short(who)), L.REMOVE, function() F:Remove(who) end)
        end, true }
      end
      return list
    end)
    r.menu:SetPoint("TOPRIGHT", 0, -14)
    r.sep = UI.Solid(r, "BACKGROUND", "line", 0.6)
    r.sep:SetHeight(1); r.sep:SetPoint("BOTTOMLEFT"); r.sep:SetPoint("BOTTOMRIGHT")
    return r
  end)

  -- Right: the bar to the Rules page, then the fellowship's name, banner colour and every emblem (as in Create a
  -- Fellowship).
  local Rp = pf.right
  pf.rulesBar = rulesBar(Rp, width)
  pf.rulesBar:SetPoint("TOPLEFT")
  local y = RULES_BAR_H + 10
  pf.fHead = UI.SectionHeader(Rp, width)
  pf.fHead:SetText(L.MG_FELLOWSHIP)
  pf.fHead:SetPoint("TOPLEFT", 0, -y)
  y = y + 35
  local function label(text, at)
    local t = UI.Text(Rp, 13, "ink2")
    t:SetPoint("TOPLEFT", 0, -at)
    t:SetText(text)
    return t
  end
  pf.renameLabel = label(L.NAME, y)
  pf.rename = UI.EditBox(Rp, width - 80, 48, "", function(t) F:Rename(t) end)
  pf.rename:SetPoint("TOPLEFT", 0, -(y + 18))
  pf.save = UI.TextButton(Rp, L.SAVE, function() F:Rename(pf.rename:GetText()) end, "plain", 13)
  pf.save:SetPoint("TOPRIGHT", 0, -(y + 17))
  pf.bannerLabel = label(L.BANNER, y + 58)
  pf.swatches = UI.Swatches(Rp, function() local f = F:Current(); return f and f.color end,
    function(v) local f = F:Current(); if f then F:SetBanner(v, f.emblem) end end)
  pf.swatches:SetPoint("TOPLEFT", 0, -(y + 76))
  pf.emblemLabel = label(L.EMBLEM, y + 118)
  pf.emblemGrid = UI.EmblemGrid(Rp, width - 10, function(n)
    local f = F:Current()
    if f then ns.Sound("choose"); F:SetBanner(f.color, n) end
  end)
  pf.emblemGrid:SetPoint("TOPLEFT", 0, -(y + 138)); pf.emblemGrid:SetPoint("BOTTOMRIGHT", -8, 0)
end

local function refresh(pf, ctx)
  local f = ctx.f
  if not f then return end
  local width = ns.Window.PAGE_W - 8
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

  -- Right page: the fellowship's name and banner.
  if not pf.rename.edit:HasFocus() then pf.rename:SetText(f.name) end
  pf.swatches:Refresh()
  pf.emblemGrid:Refresh(f.color, f.emblem)
end

ns.Pages:Register({ id = "manage", label = L.NAV_MANAGE, build = build, refresh = refresh,
  title = function() return L.TITLE_MANAGE, L.SUB_MANAGE end })
