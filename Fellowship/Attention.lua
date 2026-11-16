-- Needs attention (SPEC §6, §4.13): what the Leader should look at, in the Inbox since U144 (9 Nov 2026; on the Manage
-- page until then). Adventurers not seen for a while, over the cap, open invites, older addon versions. (Not who is
-- below the floor: Focus now, the tracker and the Chapter page say it, U239-U240.)
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

-- { { icon, text, act = { label, fn } } }, most urgent first; notices in the Inbox, never on its count (U212, the owner,
-- 15 Nov 2026: each new level brought one back on the badge). Empty for Adventurers.
function A:Gather(f)
  local me = ns.Me()
  local rank = ns.Permissions.Rank(f, me)
  if rank ~= "leader" then return {} end
  local items = {}
  local function add(icon, text, name, act)
    items[#items + 1] = { icon = icon, text = text, act = act or { L.NA_CARD, card(name) } }
  end
  local ch = J:Current(f)

  if ch then
    for _, name in ipairs(J:OverCap(f)) do
      add("cap", L.NA_OVER:format(ns.Short(name), Hr:Level(f, name), ch.cap), name)
    end
  end
  -- Not seen for a while (not yet away), and away by the rule.
  local names = F:Members(f)
  for _, name in ipairs(names) do
    -- (Not a Friend of the fellowship: they drop in now and then, SPEC §1.1. Nor the Fallen: their journey ended.)
    if name ~= me and not J:Uncounted(f, name) then
      local days = math.floor((time() - Hr:LastSeen(f, name)) / DAY)
      local away = J:Away(f, name)
      if away == "auto" then add("away", L.NA_AWAY_AUTO:format(ns.Short(name), days), name)
      elseif not away and days >= self.QUIET_DAYS then add("away", L.NA_QUIET:format(ns.Short(name), days), name) end
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
      name, { L.NA_CANCEL_INVITE, function() F:CancelInvite(name) end })
  end
  -- Older addon versions than the newest one seen in the fellowship (as on the Adventurers page).
  for _, name in ipairs(names) do
    local ver, newest = Hr:OldVersion(f, name)
    if ver then add("done", L.NA_VERSION:format(ns.Short(name), ver, newest), name) end
  end
  return items
end

