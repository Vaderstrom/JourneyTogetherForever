-- Join a fellowship (SPEC §4.3). Left: invitations and the role you join as. Right: how to join (a leader or
-- officer invites you by name; there are no public listings).
local _, ns = ...
local L = ns.L
local UI = ns.UI

local function build(pf)
  local W = ns.Window
  local width = W.PAGE_W_WIDE
  local left = pf.left
  pf.back = UI.TextButton(left, L.BACK_WELCOME, function() W.startView = "welcome"; W:Refresh() end, "link", 13)
  pf.back:SetPoint("TOPLEFT", 0, 4)
  pf.head = UI.Heading(left, width, L.INVITATIONS, nil, 20)
  pf.head:SetPoint("TOPLEFT", 0, -22)
  pf.area = CreateFrame("Frame", nil, left)
  pf.area:SetPoint("TOPLEFT", 0, -(pf.head:GetHeight() + 26)); pf.area:SetPoint("BOTTOMRIGHT")
  pf.cards = UI.Pool(function()
    local c = UI.Card(pf.area)
    c:SetWidth(width)
    c.text = UI.WrapText(c, 14, "ink", width - 24, "book")
    c.text:SetPoint("TOPLEFT", 12, -12)
    c.accept = UI.TextButton(c, L.ACCEPT, nil, "primary", 13)
    c.decline = UI.TextButton(c, L.DECLINE, nil, "plain", 13)
    return c
  end)
  pf.none = UI.SketchLine(pf.area, width, "EmptyJoin")
  pf.none:SetText(L.NO_INVITES)
  pf.roleRow = CreateFrame("Frame", nil, pf.area)
  pf.roleRow:SetSize(width, 28)
  local rl = UI.Text(pf.roleRow, 14, "ink")
  rl:SetPoint("LEFT"); rl:SetText(L.JOIN_AS)
  pf.role = UI.RoleChoice(pf.roleRow, ns.ROLE_CHOICES, function() return ns.CreateState.role end, function(v) ns.CreateState.role = v end)
  pf.role:SetPoint("LEFT", 110, 0)
  pf.roleRow:SetHeight(math.max(28, pf.role:GetHeight()))

  local head = UI.Heading(pf.right, width, L.JOIN_HOW, L.JOIN_HOW_TEXT)
  head:SetPoint("TOPLEFT")
  pf.howHead = head
  pf.art = UI.PageArt(pf.right, "Join")
end

local function refresh(pf)
  local stack = UI.Stack(pf.area)
  local invites = ns.Fellowship:MyInvites()
  local shown = 0
  for i, item in ipairs(invites) do
    local c = pf.cards:Get(i)
    if not c then break end
    shown = i
    local inv = item.inv
    c.text:SetText(L.INVITE_TEXT:format(ns.Short(inv.leader or inv.from), inv.name, inv.heroes or 1))
    local th = c.text:GetStringHeight()
    c.accept:ClearAllPoints(); c.accept:SetPoint("TOPLEFT", 12, -(th + 22))
    c.decline:ClearAllPoints(); c.decline:SetPoint("LEFT", c.accept, "RIGHT", 8, 0)
    c.accept:SetScript("OnClick", function() ns.Fellowship:AcceptInvite(item.fid, ns.CreateState.role) end)
    c.decline:SetScript("OnClick", function() ns.Fellowship:DeclineInvite(item.fid) end)
    c:SetHeight(th + 70)
    stack:Place(c, th + 70, 8)
  end
  pf.cards:HideFrom(shown + 1)
  pf.none:SetShown(#invites == 0)
  if #invites == 0 then stack:Place(pf.none, pf.none.h, 12) end
  stack:Skip(6)
  stack:Place(pf.roleRow, pf.roleRow:GetHeight(), 0)
  pf.role:Refresh()
  pf.art:Fit(pf.howHead:GetHeight())
end

ns.Pages:Register({ id = "join", label = L.TITLE_JOIN, header = "none", build = build, refresh = refresh,
  title = function() return L.TITLE_JOIN, L.ADDON_NAME end })
