-- Who may do what in a fellowship (SPEC §1 and §3, the mockup's canInvite / canRemoveAny / canClears / canAdmin).
-- Every client checks this for its own actions and for every change another Hero sends.
local _, ns = ...
local P = {}
ns.Permissions = P

-- Two ranks (27 Oct 2026): the Leader and the Adventurers ("leader" and "member" in code). Stewards ("officer") are
-- gone: an old copy's officers count as Adventurers.
function P.Rank(f, name)
  if not f or not name or not f.members[name] then return nil end
  if f.leader == name then return "leader" end
  return "member"
end

-- action: invite, uninvite, answer, remove, lead, rename, banner, rules, disband, leave, journey, clears,
-- roles (yourself, or the leader for anyone), away (yourself, or the leader for anyone), swap (yourself).
-- The Leader may do everything. An Adventurer invites (and takes the answer to their own invite), cancels their own
-- invites, and changes only what concerns themselves (votes and Gatherings: their own files).
function P.Can(f, who, action, target)
  local rank = P.Rank(f, who)
  if not rank then return false end
  local leader = rank == "leader"
  if action == "roles" or action == "away" then return P.Rank(f, target) ~= nil and (target == who or leader) end
  if action == "swap" then return true end
  if action == "leave" then return not leader end
  if action == "remove" then return leader and P.Rank(f, target) == "member" end
  if action == "lead" then return leader and target ~= who and P.Rank(f, target) ~= nil end
  if action == "invite" or action == "answer" then return true end
  if action == "uninvite" then return leader or (target ~= nil and f.inviteFrom and f.inviteFrom[target] == who) end
  if action == "rename" or action == "banner"
    or action == "rules" or action == "disband" or action == "journey" or action == "clears" then return leader end
  return false
end
