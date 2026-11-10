-- Needs attention (SPEC §6, §4.13): what the Leader should look at, in the Inbox since U144 (9 Nov 2026; on the Manage
-- page until then). Adventurers not seen for a while, falling behind, over the cap, open invites, older addon versions.
-- Nothing here changes the fellowship; it only points.
local _, ns = ...
local L = ns.L
local F, J, Hr = ns.Fellowship, ns.Journey, ns.Hero
local A = { QUIET_DAYS = 3 }
ns.Attention = A

local DAY = 86400

-- Their card on the Adventurers page.
local function card(name)
  return function()
    local W = ns.Window
    W:ShowPage("heroes")
    W.pageFrames.heroes.sel = name
    W:Refresh()
  end
end

-- { { icon, text, key, act = { label, fn } } }, most urgent first; the Inbox adds Seen (U106: it takes a line off the
-- count until its key changes: a new level, a login, a new version). Empty for Adventurers.
function A:Gather(f)
  local me = ns.Me()
  local rank = ns.Permissions.Rank(f, me)
  if rank ~= "leader" then return {} end
  local items = {}
  local function add(icon, text, key, name, act)
    items[#items + 1] = { icon = icon, text = text, key = key, act = act or { L.NA_CARD, card(name) } }
  end
  local ch = J:Current(f)

  -- Falling behind: below the floor of the current chapter.
  if ch then
    -- (Not yourself: Focus now tells you how far you are.)
    for _, name in ipairs(J:Below(f, ch.n)) do
      if name ~= me then
        add("waiting", L.NA_BEHIND:format(ns.Short(name), Hr:Level(f, name), J:FloorLevel(f, ch)),
          ("behind:%s:%d:%d"):format(name, Hr:Level(f, name), J:FloorLevel(f, ch)), name)
      end
    end
    for _, name in ipairs(J:OverCap(f)) do
      add("cap", L.NA_OVER:format(ns.Short(name), Hr:Level(f, name), ch.cap), ("over:%s:%d:%d"):format(name, Hr:Level(f, name), ch.cap), name)
    end
  end
  -- Not seen for a while (not yet away), and away by the rule.
  local names = F:Members(f)
  for _, name in ipairs(names) do
    -- (Not a Friend of the fellowship: they drop in now and then, SPEC §1.1. Nor the Fallen: their journey ended.)
    if name ~= me and not J:Uncounted(f, name) then
      local last = Hr:LastSeen(f, name)
      local days = math.floor((time() - last) / DAY)
      local away = J:Away(f, name)
      -- (Keyed by when they were last seen, not the days: seen stays seen until they log in again.)
      if away == "auto" then add("away", L.NA_AWAY_AUTO:format(ns.Short(name), days), ("away:%s:%d"):format(name, last), name)
      elseif not away and days >= self.QUIET_DAYS then add("away", L.NA_QUIET:format(ns.Short(name), days), ("quiet:%s:%d"):format(name, last), name) end
    end
  end
  -- Open invites.
  local invites = {}
  for name in pairs(f.invites) do invites[#invites + 1] = name end
  table.sort(invites)
  -- With the time it still waits (U57): "Jtfnobodyhere: 23 hours left".
  for _, name in ipairs(invites) do
    local left = ns.Sync and ns.Sync:InviteLeft(f, name)
    add("group", left and L.NA_INVITE_LEFT:format(ns.Short(name), ns.TimeLeft(left)) or L.NA_INVITE:format(ns.Short(name)),
      "invite:" .. name .. ":" .. tostring(f.invites[name]), name, { L.NA_CANCEL_INVITE, function() F:CancelInvite(name) end })
  end
  -- Older addon versions than the newest one seen in the fellowship (as on the Adventurers page).
  for _, name in ipairs(names) do
    local ver, newest = Hr:OldVersion(f, name)
    if ver then add("done", L.NA_VERSION:format(ns.Short(name), ver, newest), ("ver:%s:%s:%s"):format(name, ver, newest), name) end
  end
  return items
end

