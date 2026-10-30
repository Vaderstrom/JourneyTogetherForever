-- The feature map for /jtf check (Dev/Check.lua): every feature area of the addon with its self-test checks
-- (Dev/SelfTest.lua, steps whose name starts with one of `checks`) and its screenshots (Dev/Tour.lua, shot ids in
-- `shots`). tests/test_check.lua holds the map to the code: every shot and every step belongs to exactly one area,
-- and every id listed here exists. A new feature gets its area here, a step and a shot; then
-- "/jtf check <area>" checks it and takes only its pictures, and tools/check-report.lua shows them together.
-- noShots / noChecks: areas that have nothing to show or nothing to test on their own (with the reason).
local _, ns = ...
local A = {}
ns.CheckAreas = A

A.LIST = {
  { key = "basics", title = "Game, art, boss data, crests; the book in combat",
    checks = { "game APIs", "textures", "boss data", "crests:", "the book in combat" },
    noShots = "checks only: game functions and our files" },
  { key = "controls", title = "Buttons and choices (the game's art)", checks = { "controls:" }, shots = { "controls-gallery" } },
  { key = "welcome", title = "Welcome and Your characters", shots = { "welcome", "characters-panel" },
    checks = { "play another character" } },
  { key = "found", title = "Create a Fellowship (size, style, journey, your own)",
    checks = { "create:", "found the Selftest fellowship", "rename and banner" },
    shots = { "create-1", "create-1-filled", "emblem-picker", "create-2", "create-2-fine", "create-3", "create-3-own", "create-chapters",
      "create-chapters-shelf", "create-chapters-journey", "create-4" } },
  { key = "setup", title = "Setup guide", checks = { "setup guide" }, shots = { "setup-1", "setup-2", "setup-3" } },
  { key = "join", title = "Invitations and joining",
    checks = { "invite pretend Heroes", "the invites were received", "pretend Heroes accept", "invite:" },
    shots = { "join-empty", "join-invite", "inbox-invite", "manage-invite-open" } },
  { key = "member", title = "As a member", checks = { "make a pretend Hero leader", "getting started as an Adventurer" },
    shots = { "member-overview", "member-chapter", "member-heroes", "member-rules", "member-rules-propose" } },
  { key = "overview", title = "Overview: where you stand, where the Companions stand",
    checks = { "getting started (the leader", "levels and the You card", "level track", "the ones ahead" },
    shots = { "leader-overview-new", "overview-ready", "overview-catchup", "overview-behind", "overview-future", "overview-left-bottom" } },
  { key = "together", title = "Playing together: Play now, keep in step, session recap, friends without the addon",
    checks = { "keep in step", "session recap", "friends without the addon" },
    shots = { "overview-playnow", "toast-ahead", "toast-session", "chronicle-sessions", "share-window" } },
  { key = "watch", title = "Following another character's fellowship", checks = { "watch:" },
    shots = { "watch-overview", "watch-chapter", "watch-heroes", "watch-rules", "watch-inspect", "watch-characters" } },
  { key = "walkthrough", title = "Show me around (the walkthrough)", checks = { "walkthrough:" },
    shots = { "walk-offer", "walk-intro", "walk-stand", "walk-chapter", "walk-manage", "walk-header", "walk-tracker", "walk-rulesadmin", "walk-member-invite",
      "walk-member-rules", "walk-done" } },
  { key = "since", title = "Since you were last here", checks = { "since you were last here" }, shots = { "since" } },
  { key = "chapter", title = "Chapter, dungeons and clears",
    checks = { "chapter page and Find group", "chapter page:", "clears:", "mark cleared", "prologue:", "catching up:" },
    shots = { "leader-chapter-new", "chapter-waiting", "chapter", "chapter-tooltip", "chapter-next",
      "chapter-later", "find-group", "chapter-partial", "undo-reopen-confirm", "chapter-catching" } },
  { key = "milestones", title = "Milestones", checks = { "milestones" },
    shots = { "chapter-milestones", "admin-milestone-form", "admin-one-level" } },
  { key = "chronicle", title = "Chronicle and the cap", checks = { "Chronicle filters", "the cap:" },
    shots = { "leader-chronicle-empty", "chronicle", "chronicle-runs" } },
  { key = "moments", title = "Moments: the journey's big moments and your pictures", checks = { "moments:" },
    shots = { "leader-moments-empty", "moments" } },
  { key = "history", title = "History: the fellowship's own story", checks = { "history:" },
    shots = { "leader-history-alone", "history" } },
  { key = "photo", title = "Group photo: everyone together on the whole screen", checks = { "group photo:" },
    shots = { "group-photo", "group-photo-studio", "group-photo-twelve", "group-photo-look" } },
  { key = "quests", title = "Shared quests and chains",
    checks = { "quests tab", "quests: Show all", "quests: Together", "other addons" },
    shots = { "leader-quests-empty", "quests", "quests-join", "quests-showall", "quests-chains" } },
  { key = "attune", title = "Attunements", checks = { "quests: tabs and attunements", "attunements:" },
    shots = { "quests-attune-none", "quests-attune", "quests-attune-ony", "toast-attune" } },
  { key = "companions", title = "Companions and inspect", checks = { "heroes and inspect", "roles, addon versions" },
    shots = { "leader-heroes-alone", "heroes", "heroes-presence", "heroes-old-yours", "inspect", "inspect-me", "inspect-me-bottom" } },
  { key = "manage", title = "Manage: ranks, away, takeover, the fellowship, the rules",
    checks = { "needs attention", "remove a Hero", "ranks:", "away:", "leaving as the leader", "away by the rule" },
    shots = { "leader-manage-alone", "manage", "manage-fellowship", "manage-rules", "leave-confirm" } },
  { key = "rules", title = "Rules and votes", checks = { "rule votes", "pruning:" }, shots = { "leader-rules", "rules-vote", "rules-vote-passed" } },
  { key = "gatherings", title = "Gatherings", checks = { "gatherings", "gathering form" },
    shots = { "gatherings-empty", "gather-form", "gatherings", "overview-gatherings", "toast-gathering" } },
  { key = "inbox", title = "Inbox", checks = { "inbox", "ask to group up" }, shots = { "inbox-full", "inbox-size" } },
  { key = "admin", title = "Journey Admin", checks = { "Journey Admin", "export and import" },
    shots = { "leader-admin", "admin-chapter-2", "admin-bosses", "admin-shelf", "admin-add-again", "admin-journey", "admin-export" } },
  { key = "raids", title = "The Endgame and raids", checks = { "the Endgame" }, shots = { "raids", "raids-mc", "toast-endgame" } },
  { key = "tourney", title = "Guild Master tournament", checks = { "tournament" },
    shots = { "tourney-signup", "tourney-bracket", "tourney-champion", "tourney-double", "tourney-groups", "tourney-rr", "tourney-20" } },
  { key = "toasts", title = "Toasts, big moments, picture moment", checks = { "picture moment", "progress toasts", "toasts:" },
    shots = { "chapter-unlocked", "picture-moment", "toast-move", "toast-clear", "toast-hero-floor", "toast-chapter", "toast-journey",
      "toast-long" } },
  { key = "tracker", title = "Tracker and minimap button", checks = { "the tracker", "minimap button" },
    shots = { "tracker", "tracker-all", "tracker-hidden", "minimap-tooltip" } },
  { key = "sync", title = "Sync with Adventurers who play at other times (pretend copies)", checks = { "sync:" },
    shots = { "sync-restore" } },
  { key = "board", title = "The board for the Discord companion", checks = { "board:" },
    noShots = "saved data for the companion app; nothing on the screen" },
  { key = "access", title = "Realms and trial accounts", checks = { "realms:", "trial account:" }, shots = { "trial-bar" } },
  { key = "settings", title = "Settings", checks = { "settings and themes" }, shots = { "settings", "settings-tracker-off" } },
  { key = "themes", title = "Themes, book sizes and full screen", checks = { "screen:" },
    shots = { "night-overview", "night-chapter", "night-quests", "night-heroes", "night-manage", "alliance-overview", "alliance-chapter",
      "alliance-heroes", "horde-overview", "horde-chapter", "horde-heroes", "horde-manage", "horde-chronicle", "horde-quests", "size-80",
      "size-120", "fullscreen", "fullscreen-settings", "fullscreen-heroes",
      "fullscreen-admin" } },
}

local byKey, byShot = {}, {}
for _, a in ipairs(A.LIST) do
  byKey[a.key] = a
  for _, id in ipairs(a.shots or {}) do byShot[id] = a.key end
end

function A:Get(key) return byKey[key] end

-- The area of a tour shot, or nil.
function A:ForShot(id) return byShot[id] end

-- Self-test steps that only open a page (named "show: ...") belong to no area.
function A.IsShowStep(name) return name:sub(1, 6) == "show: " end

-- The areas of a self-test step (normally exactly one): every area with a check prefix the name starts with.
function A:ForStep(name)
  local out = {}
  for _, a in ipairs(self.LIST) do
    for _, p in ipairs(a.checks or {}) do
      if name:sub(1, #p) == p then out[#out + 1] = a.key break end
    end
  end
  return out
end

-- "setup,join" or "setup join" -> { setup = true, join = true }, and the unknown words.
function A:Parse(text)
  local set, unknown, any = {}, {}, false
  for word in (text or ""):gmatch("[%w_]+") do
    if byKey[word] then set[word] = true; any = true else unknown[#unknown + 1] = word end
  end
  return any and set or nil, unknown
end
