-- Since you were last here (SPEC §6). Shown once per session, the first time the book opens, when something changed.
-- Left: when you were last here, a new chapter, and what happened (chronicle and runs). Right: who levelled, and
-- Continue to the Overview.
local _, ns = ...
local L = ns.L
local UI, Theme = ns.UI, ns.Theme
local Hr = ns.Hero

local function build(pf)
  local W = ns.Window
  local width = W.PAGE_W - 8
  pf.lscroll = UI.Scroll(pf.left)
  pf.lscroll:SetAllPoints()
  pf.art = UI.PageArt(pf.lscroll, "Since")
  local Lc = pf.lscroll.child
  pf.ago = UI.WrapText(Lc, 13, "ink2", width, "book")
  pf.chapter = UI.Card(Lc, "3E7A3A")
  pf.chapter:SetWidth(width)
  pf.chapter.icon = UI.Round(pf.chapter, "ARTWORK", 22)
  pf.chapter.icon:SetPoint("LEFT", 10, 0)
  UI.SetIcon(pf.chapter.icon, ns.ICONS.toast_chapter or ns.ICONS.bn_done)
  pf.chapter.text = UI.WrapText(pf.chapter, 14, "ink", width - 50, "title")
  pf.chapter.text:SetPoint("LEFT", 40, 0)
  pf.eventsHead = UI.SectionHeader(Lc, width)
  pf.eventsHead:SetText(L.SINCE_EVENTS)
  pf.events = UI.Pool(function()
    local e = CreateFrame("Frame", nil, Lc)
    e:SetWidth(width)
    e.text = UI.WrapText(e, 13, "ink", width, "book")
    e.text:SetPoint("TOPLEFT")
    e.when = UI.Text(e, 11, "ink2")
    e.when:SetPoint("TOPLEFT", e.text, "BOTTOMLEFT", 0, -2)
    return e
  end)
  pf.more = UI.Text(Lc, 12, "ink2")
  pf.none = UI.SketchLine(Lc, width, "EmptySince")
  pf.none:SetText(L.SINCE_NOTHING)

  pf.rscroll = UI.Scroll(pf.right)
  pf.rscroll:SetAllPoints()
  local R = pf.rscroll.child
  pf.levelsHead = UI.Heading(R, width, L.SINCE_LEVELS, nil, 18)
  pf.levels = UI.Pool(function()
    local r = CreateFrame("Frame", nil, R)
    r:SetSize(width, 22)
    r.name = UI.Text(r, 13, "ink")
    r.name:SetPoint("LEFT")
    r.change = UI.Text(r, 13, "ink", "title", "RIGHT")
    r.change:SetPoint("RIGHT")
    return r
  end)
  pf.noLevels = UI.WrapText(R, 13, "ink2", width, "book")
  pf.noLevels:SetText(L.SINCE_NO_LEVELS)
  -- Where the fellowship stands now (M21; the page was half empty): the chapter's picture and its status.
  pf.nowHead = UI.SectionHeader(R, width)
  pf.nowHead:SetText(L.SINCE_NOW)
  pf.nowPic = CreateFrame("Frame", nil, R)
  pf.nowPic:SetSize(width, 96)
  pf.nowPic.art = pf.nowPic:CreateTexture(nil, "BACKGROUND")
  local fade = pf.nowPic:CreateTexture(nil, "BORDER")
  UI.FramePicture(pf.nowPic, pf.nowPic.art, fade)
  UI.SetGradient(fade, "VERTICAL", { 0.055, 0.03, 0.01, 0.88 }, { 0.055, 0.03, 0.01, 0.05 })
  pf.nowPic.title = UI.Text(pf.nowPic, 19, "goldText", "fancy")
  pf.nowPic.title:SetPoint("BOTTOMLEFT", 12, 10)
  pf.nowPic.title:SetShadowOffset(0, -1); pf.nowPic.title:SetShadowColor(0, 0, 0, 1)
  pf.nowBanner = UI.StatusBanner(R, width)
  pf.continue = UI.TextButton(R, L.CONTINUE, function()
    ns.Since:Continue()
    W:ShowPage("overview")
  end, "primary")
end

local function refresh(pf, ctx)
  local f = ctx.f
  if not f then return end
  local width = ns.Window.PAGE_W - 8
  local d = ns.Since.current or ns.Since:Digest(f) or { events = {}, levels = {}, more = 0 }
  local light = Theme:Current().light

  local s = UI.Stack(pf.lscroll.child)
  pf.ago:SetText(d.ago and L.SINCE_AGO:format(d.ago) or "")
  s:Place(pf.ago, pf.ago:GetStringHeight(), 10)
  pf.chapter:SetShown(d.chapter ~= nil)
  if d.chapter then
    pf.chapter.text:SetText(d.chapter)
    -- (The card had no height: an empty gap where "Chapter 2 is unlocked" should be; seen in the tour.)
    local h = math.max(40, pf.chapter.text:GetStringHeight() + 18)
    pf.chapter:SetHeight(h)
    s:Place(pf.chapter, h, 12)
  end
  pf.eventsHead:SetShown(#d.events > 0)
  if #d.events > 0 then s:Place(pf.eventsHead, 29, 6) end
  local n = 0
  for i, e in ipairs(d.events) do
    local row = pf.events:Get(i)
    if not row then break end
    n = i
    row.text:SetText(e.text)
    row.when:SetText(ns.TimeAgo(e.time))
    local h = row.text:GetStringHeight() + 18
    row:SetHeight(h)
    s:Place(row, h, 6)
  end
  pf.events:HideFrom(n + 1)
  pf.more:SetShown((d.more or 0) > 0)
  if (d.more or 0) > 0 then
    pf.more:SetText(L.SINCE_MORE:format(d.more))
    s:Place(pf.more, 16, 4)
  end
  pf.none:SetShown(not d.chapter and #d.events == 0)
  if not d.chapter and #d.events == 0 then
    -- "Nothing new" next to a list of who levelled read wrong (seen in the check, 29 Oct 2026).
    pf.none:SetText(#d.levels > 0 and L.SINCE_ONLY_LEVELS or L.SINCE_NOTHING)
    s:Place(pf.none, pf.none.h, 4)
  end
  pf.lscroll:SetContentHeight(s.y + 8)
  pf.art:Fit(s.y)

  local r = UI.Stack(pf.rscroll.child)
  r:Place(pf.levelsHead, pf.levelsHead:GetHeight(), 8)
  local m = 0
  for i, lv in ipairs(d.levels) do
    local row = pf.levels:Get(i)
    if not row then break end
    m = i
    local _, token = Hr:ClassName(f, lv.name)
    local hex = ns.ClassHex(token, light)
    row.name:SetText(ns.Short(lv.name))
    if hex then row.name:SetTextColor(ns.Hex(hex)) else row.name:SetTextColor(Theme:RGBA("ink")) end
    row.change:SetText(L.SINCE_LEVEL:format(lv.from, lv.to))
    r:Place(row, 22, 2)
  end
  pf.levels:HideFrom(m + 1)
  pf.noLevels:SetShown(#d.levels == 0)
  if #d.levels == 0 then r:Place(pf.noLevels, pf.noLevels:GetStringHeight(), 4) end
  r:Skip(10)
  local J = ns.Journey
  local cur = J:CurrentIndex(f)
  local ch = f.journey.chapters[cur]
  r:Place(pf.nowHead, 29, 6)
  ns.Pages:SetChapterArt(pf.nowPic.art, ch and ns.Pages:ArtOf(f, cur) or nil, width - 2 * UI.PIC_INSET, 96 - 2 * UI.PIC_INSET, 0.5)
  pf.nowPic.title:SetText(ch and L.CHAPTER_N_NAME:format(ns.Journey.Roman(cur), ch.name) or L.BN_JOURNEY_DONE)
  r:Place(pf.nowPic, 96, 8)
  r:Place(pf.nowBanner, pf.nowBanner:Set(J:Banner(f, cur)), 4)
  r:Skip(10)
  r:Place(pf.continue, 28, 4, width - pf.continue:GetWidth())
  pf.rscroll:SetContentHeight(r.y + 8)
end

-- Not in the sidebar: the book opens it by itself (free = shown in a fellowship without a sidebar entry).
ns.Pages:Register({ id = "since", label = L.TITLE_SINCE, free = true, build = build, refresh = refresh,
  title = function() return L.TITLE_SINCE, L.SUB_SINCE end })
