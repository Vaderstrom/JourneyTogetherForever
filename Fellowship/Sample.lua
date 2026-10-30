-- The sample fellowship of the walkthrough (UI/Walkthrough.lua, 27 Oct 2026): "The Lantern Bearers" in Chapter III,
-- with Adventurers at every standing (one below the floor, one over the cap, one away), a dungeon half cleared, a
-- Gathering, an open vote and a few Chronicle lines, so every page has something to show. You are in it with the rank
-- of the tour (Leader or Adventurer). It is made with the same changes a real fellowship gets (F:Apply),
-- lives only in memory, is never saved and never sent.
local _, ns = ...
local L = ns.L
local S = {}
ns.Sample = S

S.ID = "jtf-walkthrough-sample"
-- name, class, role, level, minutes since heard (nil: online now)
S.PEOPLE = {
  { "Brannic", "PALADIN", "Healer", 23 },
  { "Elyra", "PRIEST", "DPS", 22 },
  { "Corwin", "MAGE", "DPS", 19 },
  { "Darrow", "ROGUE", "DPS", 26, 180 },
  { "Fenna", "DRUID", "Tank", 21, 60 * 24 * 16 },
}

local function full(name) return ns.FullName(name) end

-- rank: "leader" or "member" (your rank in the sample).
function S:Build(rank)
  local F, J = ns.Fellowship, ns.Journey
  local me, now = ns.Self(), time()
  local _, myClass = UnitClass("player")
  local brannic = full("Brannic")
  local leader = rank == "leader" and me or brannic
  local f = {
    id = self.ID, v = 1, name = L.SAMPLE_NAME, faction = (UnitFactionGroup("player")), color = "2E6A8A",
    emblem = ns.Emblems:First(), leader = leader, officers = {}, members = {}, invites = {}, inviteFrom = {},
    rules = ns.Rules.Clean(nil), journey = ns.BuildJourney("classic"), chronicle = {}, heroes = {}, runs = {}, kills = {},
    undone = {}, history = {}, ticks = {}, updated = now, sample = true,
  }
  local function add(name, class, role, level, ago)
    f.members[name] = { role = role, joined = now - 86400 * 9, class = class, level = level }
    f.heroes[name] = { level = level, xp = 300 + (#name * 97) % 600, xpMax = 1000, class = class, t = now,
      heard = now - (ago or 0) * 60, offline = ago ~= nil or nil }
  end
  add(me, myClass, "Tank", 23)
  for _, p in ipairs(self.PEOPLE) do add(full(p[1]), p[2], p[3], p[4], p[5]) end
  -- Fenna has not been seen for 16 days: away by the rule.
  F:Log(f, L.CHR_FOUNDED:format(f.name, ns.Short(leader)), now - 86400 * 9, "founded", leader)
  -- The Prologue and Chapter II done (its required dungeons cleared by everyone). Chapter III: the first dungeon
  -- cleared by three.
  local everyone = {}
  for name in pairs(f.members) do everyone[#everyone + 1] = name end
  local t = now - 86400 * 3
  f.reached = 2
  for _, x in ipairs(J:Required(f, 2)) do
    F:Apply(f, { k = "clear", key = x.key, names = everyone }, leader, t)
    t = t + 3600
  end
  local ch3 = J:Required(f, 3)
  if ch3[1] then F:Apply(f, { k = "clear", key = ch3[1].key, names = { me, brannic, full("Elyra") } }, leader, now - 7200) end
  -- A Gathering tonight and an open vote (one Companion fewer for a run).
  F:Apply(f, { k = "gather", a = "new", id = "sample-gather", text = L.SAMPLE_GATHER, at = now + 3 * 3600 }, full("Elyra"), now - 1800)
  F:Apply(f, { k = "vote", a = "propose", id = "sample-vote", key = "minHeroes", value = 3 }, full("Corwin"), now - 900)
  f.v = 40
  return f
end
