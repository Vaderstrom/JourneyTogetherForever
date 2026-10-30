-- Pages of the book and the sidebar. No frames here: Window.lua draws what this file decides.
-- Rules from the mockup (navDef, accentFor, TITLES, PAGE_ART).
local _, ns = ...
local L = ns.L
local P = { pages = {} }
ns.Pages = P

-- Art from Media/ for the mockup's picture names. aspect = width / height of the file.
P.ART = {
  land = { "KeyJourney", 2 }, hall = { "KeyGuild", 2 }, heroes = { "HeaderRoster", 4 },
  council = { "HeaderCouncil", 4 }, arena = { "HeaderArena", 4 }, board = { "HeaderCalendar", 4 },
}
-- The Horde's own versions (our art, A8); the journey landscape and the chapters' pictures are for both factions.
P.ART_HORDE = {
  land = P.ART.land, hall = { "HordeHall", 2 }, heroes = { "HordeRoster", 4 },
  council = { "HordeCouncil", 4 }, arena = { "HordeArena", 4 }, board = { "HordeBoard", 4 },
}
P.PAGE_ART = { chronicle = "board", moments = "board", history = "hall", gatherings = "board", overview = "land", chapter = "land", quests = "board", heroes = "heroes", manage = "council",
  managefellowship = "council", tourney = "arena", raids = "land", setup = "hall", since = "land", admin = "board", rules = "council",
  rulesadmin = "council", create = "hall", welcome = "land", join = "heroes", settings = "hall" }

-- Pages register themselves: { id, label, icon, title = function(ctx) return title, sub end, build, refresh }.
-- build(page) gets the page frame with .left and .right; refresh(page, ctx) runs when it is shown.
-- parent: a tab of another page (Manage's tabs): in the sidebar as that page, which stays marked.
function P:Register(def)
  def.icon = def.icon or def.id
  self.pages[def.id] = def
end

function P:Get(id) return self.pages[id] end

-- What the current character is in the fellowship. "/jtf debug tourney on" shows the tournament page.
function P:Context()
  local ctx = ns.Fellowship:Context()
  ctx.playerName = UnitName("player")
  -- Manage is the Leader's, in Admin; Adventurers invite on the Adventurers page (27 Oct 2026).
  ctx.canManage = ctx.isLeader or false
  ctx.canAdmin = ctx.isLeader or false
  if ns.Dev and ns.Dev.tourney and ctx.inFellow then ctx.tActive = true end
  -- Watching another character's fellowship (Fellowship/Watch.lua): read-only, no rank.
  -- (The walkthrough's sample keeps your rank there, so its pages show as they will for you.)
  if ns.Watch and ns.Watch.rendering and ns.Watch.demo and ctx.inFellow then
    ctx.demo, ctx.tActive = true, false
  elseif ns.Watch and ns.Watch.rendering and ctx.inFellow then
    ctx.watching, ctx.watchAs = true, ns.Watch.as
    ctx.isLeader, ctx.canManage, ctx.canAdmin, ctx.tActive = false, false, false, false
  end
  return ctx
end

-- Sidebar groups for ctx (empty outside a fellowship).
function P:Nav(ctx)
  if not ctx.inFellow then return {} end
  -- Watching: the pages to follow the fellowship by, nothing to act on. The rules read only (28 Oct 2026).
  if ctx.watching then
    local journey = { "overview", "chapter", "chronicle" }
    if ctx.f and ns.Endgame and ns.Endgame:Open(ctx.f) then table.insert(journey, 3, "raids") end
    return { { label = L.NAV_JOURNEY, items = journey }, { label = L.NAV_FELLOWSHIP, items = { "heroes", "rules", "history" } } }
  end
  local fellowship = { "heroes", "gatherings" }
  if ctx.tActive then fellowship[#fellowship + 1] = "tourney" end
  -- The rules are the whole fellowship's: in the same place for everyone (they were under CAPTAIN for the Captain,
  -- which made them look like a Captain's page; 27 Oct 2026). What each rank may do there, the page says.
  fellowship[#fellowship + 1] = "rules"
  -- The fellowship's own story (the journey's is the Chronicle; 29 Oct 2026).
  fellowship[#fellowship + 1] = "history"
  -- Raids once the Endgame is open (after the journey, Fellowship/Endgame.lua).
  local journey = { "overview", "chapter", "quests", "chronicle" }
  if ctx.f and ns.Endgame and ns.Endgame:Open(ctx.f) then table.insert(journey, 3, "raids") end
  local nav = {
    { label = L.NAV_JOURNEY, items = journey },
    { label = L.NAV_FELLOWSHIP, items = fellowship },
  }
  -- The Leader's Admin: Manage (Adventurers, the fellowship and the rules as tabs; 28 Oct 2026) and
  -- Journey Admin. The journey and the rules are each edited as a draft and published.
  if ctx.isLeader then nav[#nav + 1] = { label = L.NAV_ADMIN_GROUP, items = { "manage", "admin" } } end
  return nav
end

-- The sidebar entry a page is under: its own, or its parent's for a tab.
function P:NavItem(id)
  local def = self.pages[id]
  return def and def.parent or id
end

function P:InNav(id, ctx)
  local item = self:NavItem(id)
  for _, g in ipairs(self:Nav(ctx)) do
    for _, it in ipairs(g.items) do if it == item then return true end end
  end
  return false
end

-- Which page shows: in a fellowship the chosen page (if it is in the sidebar, or a free page such as Since you were
-- last here), otherwise the start page.
function P:Resolve(page, startView, ctx)
  local def = self.pages[page]
  -- Settings shows in and outside a fellowship (def.anywhere).
  if def and def.anywhere then return page end
  if ctx.inFellow then
    return ((def and def.free) or self:InNav(page, ctx)) and page or "overview"
  end
  return startView or "welcome"
end

-- Accent colour of a page: leader red for Journey Admin and Manage, the fellowship's colour for Adventurers, Rules
-- and History.
function P:Accent(page, ctx)
  local A = ns.Theme.ACCENT
  if page == "admin" or self:NavItem(page) == "manage" then return A.leader end
  if page == "heroes" or page == "rules" or page == "history" then return ctx.color or A.journey end
  return A.journey
end

-- Title and subtitle of a page.
function P:Titles(page, ctx)
  local def = self.pages[page]
  if def and def.title then return def.title(ctx) end
  return def and def.label or page, ""
end

-- A chapter picture (Media\Chapter01 ... Chapter14, or ChapterPrologue; 2:1) on tex, cropped to w x h; the journey
-- landscape when there is none (or the journey has more chapters than pictures). picture: a number, or "prologue".
function P:SetChapterArt(tex, picture, w, h, focusY)
  local file = picture == "prologue" and "ChapterPrologue" or (tonumber(picture) and ("Chapter%02d"):format(picture))
  local ok = file and tex:SetTexture(ns.MEDIA .. file)
  if not ok then tex:SetTexture(ns.MEDIA .. self.ART.land[1]) end
  ns.UI.Cover(tex, 2, w, h, focusY)
end

-- The picture of chapter n of a fellowship's journey: its own (art), else by its place (older journeys).
function P:ArtOf(f, n)
  local ch = f and n and f.journey.chapters[n]
  if not ch then return nil end
  return ch.art or n
end

-- Header picture and background picture of a page, in the Horde's own art for Horde characters (the mockup had none
-- for the Horde until we had art for it).
function P:Art(page, horde)
  local set = horde and self.ART_HORDE or self.ART
  local head = set[self.PAGE_ART[page] or "land"]
  local bg = (page == "overview" or page == "chapter" or page == "quests") and set.land or set.hall
  return head, bg
end

-- Name and chip in the header.
function P:Header(ctx)
  if not ctx.inFellow then
    local _, faction = UnitFactionGroup("player")
    return L.ADDON_NAME, faction or ""
  end
  local ch = ctx.chapter
  if ch then return ctx.name, L.CHIP_CHAPTER:format(ch.n, ch.of, ch.floor, ch.cap) end
  return ctx.name, L.JOURNEY_COMPLETE
end
