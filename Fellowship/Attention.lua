-- Needs attention (SPEC §6): what the leader should look at, on the Manage page with a count in the sidebar.
-- Adventurers not seen for a while, falling behind, over the cap, open invites, older addon versions. Nothing here
-- changes the fellowship; it only points.
local _, ns = ...
local L = ns.L
local F, J, Hr = ns.Fellowship, ns.Journey, ns.Hero
local A = { QUIET_DAYS = 3 }
ns.Attention = A

local DAY = 86400

-- { { icon, text } }, most urgent first. Empty for Adventurers (they do not see Manage).
function A:Items(f)
  local me = ns.Me()
  local rank = ns.Permissions.Rank(f, me)
  if rank ~= "leader" then return {} end
  local items = {}
  local function add(icon, text) items[#items + 1] = { icon = icon, text = text } end
  local ch = J:Current(f)

  -- Falling behind: below the floor of the current chapter.
  if ch then
    -- (Not yourself: your own catch-up is on the You card.)
    for _, name in ipairs(J:Below(f, ch.n)) do
      if name ~= me then add("waiting", L.NA_BEHIND:format(ns.Short(name), Hr:Level(f, name), J:FloorLevel(f, ch))) end
    end
    for _, name in ipairs(J:OverCap(f)) do
      add("cap", L.NA_OVER:format(ns.Short(name), Hr:Level(f, name), ch.cap))
    end
  end
  -- Not seen for a while (not yet away), and away by the rule.
  local names = F:Members(f)
  for _, name in ipairs(names) do
    if name ~= me then
      local days = math.floor((time() - Hr:LastSeen(f, name)) / DAY)
      local away = J:Away(f, name)
      if away == "auto" then add("away", L.NA_AWAY_AUTO:format(ns.Short(name), days))
      elseif not away and days >= self.QUIET_DAYS then add("away", L.NA_QUIET:format(ns.Short(name), days)) end
    end
  end
  -- Open invites.
  local invites = {}
  for name in pairs(f.invites) do invites[#invites + 1] = name end
  table.sort(invites)
  for _, name in ipairs(invites) do add("group", L.NA_INVITE:format(ns.Short(name))) end
  -- Older addon versions than the newest one seen in the fellowship (as on the Adventurers page).
  for _, name in ipairs(names) do
    local ver, newest = Hr:OldVersion(f, name)
    if ver then add("done", L.NA_VERSION:format(ns.Short(name), ver, newest)) end
  end
  return items
end

function A:Count(f) return f and #self:Items(f) or 0 end
