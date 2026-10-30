-- Raids (SPEC §2, M18): the Endgame after the journey. Left: each classic raid as a card with its picture, who is
-- attuned, your boss progress and Find group. Right: the chosen raid's bosses with how many Heroes have killed each,
-- and its attunement per Hero. In the sidebar once the Endgame is open (Fellowship/Endgame.lua).
local _, ns = ...
local L = ns.L
local UI = ns.UI
local E = ns.Endgame
local OA = ns.OtherAddons

local PIC_H = 96

local function names(list, me)
  local out = {}
  for _, n in ipairs(list) do
    if n == me then table.insert(out, 1, L.YOU_LABEL) else out[#out + 1] = ns.Short(n) end -- you first
  end
  return table.concat(out, ", ")
end

local function build(pf)
  local W = ns.Window
  local width = W.PAGE_W - 8
  pf.lscroll = UI.Scroll(pf.left)
  pf.lscroll:SetAllPoints()
  local Lc = pf.lscroll.child
  pf.help = UI.WrapText(Lc, 12, "ink2", width)
  pf.cards = UI.Pool(function()
    local c = UI.Card(Lc)
    c:SetWidth(width)
    c.pic = CreateFrame("Button", nil, c)
    c.pic:SetHeight(PIC_H); c.pic:SetPoint("TOPLEFT", 4, -4); c.pic:SetPoint("TOPRIGHT", -4, -4)
    c.pic.bg = c.pic:CreateTexture(nil, "BACKGROUND")
    c.pic.bg:SetAllPoints(); c.pic.bg:SetColorTexture(0.1, 0.07, 0.04, 1)
    c.pic.tex = c.pic:CreateTexture(nil, "ARTWORK")
    c.pic.tex:SetAllPoints()
    local fade = c.pic:CreateTexture(nil, "ARTWORK", nil, 2)
    fade:SetPoint("BOTTOMLEFT"); fade:SetPoint("BOTTOMRIGHT"); fade:SetHeight(PIC_H * 0.6)
    UI.SetGradient(fade, "VERTICAL", { 0.05, 0.03, 0.01, 0.9 }, { 0.05, 0.03, 0.01, 0 })
    local top = c.pic:CreateTexture(nil, "ARTWORK", nil, 2)
    top:SetPoint("TOPLEFT"); top:SetPoint("TOPRIGHT"); top:SetHeight(26)
    UI.SetGradient(top, "VERTICAL", { 0.05, 0.03, 0.01, 0 }, { 0.05, 0.03, 0.01, 0.6 })
    local hl = c.pic:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints(); hl:SetColorTexture(1, 0.9, 0.6, 0.1)
    c.pic:SetScript("OnClick", function() pf.raid = c.key; W:Refresh() end)
    c.mark = UI.Mark(c.pic, 14)
    c.mark:SetPoint("BOTTOMLEFT", 10, 11)
    c.name = UI.Text(c.pic, 18, "goldText", "fancy")
    c.name:SetPoint("BOTTOMLEFT", 30, 9)
    c.name:SetShadowOffset(1, -1); c.name:SetShadowColor(0, 0, 0, 1)
    c.size = UI.Text(c.pic, 11, "E8C878")
    c.size:SetPoint("LEFT", c.name, "RIGHT", 8, 0)
    c.size:SetShadowOffset(1, -1); c.size:SetShadowColor(0, 0, 0, 1)
    c.state = UI.Text(c.pic, 12, "goldText", "body", "RIGHT")
    c.state:SetPoint("TOPRIGHT", -8, -6)
    c.state:SetShadowOffset(1, -1); c.state:SetShadowColor(0, 0, 0, 1)
    c.sel = UI.Solid(c, "BORDER", "accent", 1)
    c.sel:SetPoint("TOPLEFT", c.pic, "BOTTOMLEFT", 0, 0); c.sel:SetPoint("TOPRIGHT", c.pic, "BOTTOMRIGHT", 0, 0); c.sel:SetHeight(2)
    c.info = UI.WrapText(c, 12, "ink2", width - 24)
    c.info:SetPoint("TOPLEFT", 12, -(PIC_H + 10))
    c.group = UI.TextButton(c, L.FIND_GROUP, function()
      local f = ns.Fellowship:Current()
      if f and c.key then E:FindGroup(f, c.key) end
    end, "primary", 12)
    c.dj = UI.RoundButton(c, 28, "journal", function() W:DungeonJournal(c.key) end)
    UI.Tooltip(c.dj, L.DUNGEON_JOURNAL)
    -- The raid's story in Lore Forever, while it runs (UI/OtherAddons.lua).
    c.lore = UI.RoundButton(c, 28, "lore", function() OA:Lore(c.key) end)
    UI.Tooltip(c.lore, L.LORE_TIP)
    c.lore:SetPoint("LEFT", c.dj, "RIGHT", 6, 0)
    return c
  end)

  pf.rscroll = UI.Scroll(pf.right)
  pf.rscroll:SetAllPoints()
  local R = pf.rscroll.child
  pf.head = UI.Heading(R, width, "", nil, 20)
  pf.attHead = UI.SectionHeader(R, width)
  pf.attHead:SetText(L.RAID_ATTUNE_HEAD)
  pf.attText = UI.WrapText(R, 13, "ink", width, "book")
  pf.bossHead = UI.SectionHeader(R, width)
  pf.bossHead:SetText(L.RAID_BOSSES_HEAD)
  pf.bosses = UI.Pool(function()
    local b = CreateFrame("Frame", nil, R)
    b:SetSize(width, 22)
    b.mark = UI.Mark(b, 12)
    b.mark:SetPoint("LEFT", 2, 0)
    b.name = UI.Text(b, 13, "ink")
    b.name:SetPoint("LEFT", 22, 0)
    b.n = UI.Text(b, 12, "ink2", "body", "RIGHT")
    b.n:SetPoint("RIGHT")
    return b
  end)
end

local function refresh(pf, ctx)
  local f = ctx.f
  if not f then return end
  local width = ns.Window.PAGE_W - 8
  local me, J = ctx.me, ns.Journey
  local counted = J:Counted(f)
  local s = UI.Stack(pf.lscroll.child)
  pf.help:SetText(L.RAIDS_HELP:format(f.rules.minHeroes))
  s:Place(pf.help, pf.help:GetStringHeight(), 10)
  -- The chosen raid, kept while the book is used (pf.sel is cleared each time a page opens).
  pf.raid = pf.raid or ns.RAIDS[1][1]
  local chosen
  for i, r in ipairs(ns.RAIDS) do
    local c = pf.cards:Get(i)
    if not c then break end
    local key = r[1]
    c.key = key
    if key == pf.raid then chosen = r end
    c.name:SetText(r[2])
    c.size:SetText(L.RAID_SIZE:format(r[4]))
    local ok, default = ns.SetDungeonArt(c.pic.tex, key, width - 8, PIC_H)
    if default then ns.Pages:SetChapterArt(c.pic.tex, nil, width - 8, PIC_H, 0.5); ok = true end
    c.pic.tex:SetShown(ok)
    local cleared = 0
    for name in pairs(J:ClearedBy(f, key)) do if f.members[name] then cleared = cleared + 1 end end
    local done = J:Cleared(f, key)
    c.mark:SetMark(done and "cleared" or "open")
    c.state:SetText(L.RAID_CLEARED_BY:format(cleared, #counted))
    c.sel:SetShown(key == pf.raid)
    local st = E:AttuneStatus(f, r)
    local att = not r[5] and L.RAID_NO_ATTUNE
      or (#st.attuned > 0 and L.RAID_ATTUNED:format(names(st.attuned, me)) or L.RAID_NOBODY_ATTUNED)
    local n, of = ns.Clears:Progress(f, key, me)
    c.info:SetText(att .. "\n" .. (of == 1 and L.RAID_YOU_BOSS or L.RAID_YOU_BOSSES):format(n, of))
    local h = PIC_H + 10 + c.info:GetStringHeight() + 8
    c.group:ClearAllPoints(); c.group:SetPoint("TOPLEFT", 12, -h)
    -- Watching an alt's fellowship (Fellowship/Watch.lua): no Find group, it would form your own.
    c.group:SetShown(not ctx.watching)
    c.dj:ClearAllPoints()
    if ctx.watching then c.dj:SetPoint("TOPLEFT", 12, -h) else c.dj:SetPoint("LEFT", c.group, "RIGHT", 6, 0) end
    c.lore:SetShown(OA:HasLore())
    h = h + 34
    c:SetHeight(h)
    s:Place(c, h, 8)
  end
  pf.cards:HideFrom(#ns.RAIDS + 1)
  pf.lscroll:SetContentHeight(s.y + 8)

  -- Right: the chosen raid.
  local r = UI.Stack(pf.rscroll.child)
  chosen = chosen or ns.RAIDS[1]
  pf.head:Set(chosen[2], L.RAID_SIZE:format(chosen[4]))
  r:Place(pf.head, pf.head:GetHeight(), 6)
  r:Place(pf.attHead, 29, 4)
  local st = E:AttuneStatus(f, chosen)
  if not chosen[5] then pf.attText:SetText(L.RAID_NO_ATTUNE)
  else
    pf.attText:SetText((#st.attuned > 0 and L.RAID_ATTUNED:format(names(st.attuned, me)) or L.RAID_NOBODY_ATTUNED)
      .. (#st.missing > 0 and ("\n" .. L.RAID_NOT_ATTUNED:format(names(st.missing, me))) or ""))
  end
  r:Place(pf.attText, pf.attText:GetStringHeight(), 10)
  r:Place(pf.bossHead, 29, 4)
  local list = E:BossProgress(f, chosen[1])
  for i, b in ipairs(list) do
    local row = pf.bosses:Get(i)
    if not row then break end
    row.name:SetText(b.name)
    row.n:SetText((b.of == 1 and L.HIST_CLEARED_BY_1 or L.RAID_BOSS_HEROES):format(b.have, b.of))
    row.mark:SetMark(b.of > 0 and b.have >= b.of and "cleared" or "open")
    r:Place(row, 22, 2)
  end
  pf.bosses:HideFrom(#list + 1)
  pf.rscroll:SetContentHeight(r.y + 8)
end

ns.Pages:Register({ id = "raids", label = L.NAV_RAIDS, build = build, refresh = refresh,
  title = function() return L.TITLE_RAIDS, L.SUB_RAIDS end })
