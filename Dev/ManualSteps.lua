-- The in-game tests (/jtf tests, Dev/Manual.lua): what /jtf check cannot do by itself, one step at a time, with one
-- account. This list is the source; docs/E2E-CHECKS.md points here. Each step:
--   id       stable key for the report (keep it when the text changes)
--   section  heading on the card
--   todo     what to do;  see: what you should see
--   cmds     commands with a button on the card: "/jtf ...", "/reload", "/console scriptErrors 1", or
--            { label, fn } for anything else
--   auto     optional: function() -> ok (true/false), what the addon sees (shown on the card, never marks the step)
-- Developer text (like the check's), so it lives here and not in Locales.
local _, ns = ...

local function cur() return ns.Fellowship:Current() end
local function full(name) return ns.FullName(name) end
local function inTest()
  local f = cur()
  if not f then return false, "you are in no fellowship" end
  return f.id == ns.Dev.TEST_ID, "you are in " .. f.name
end
local function none()
  local f = cur()
  return f == nil, f and ("you are still in " .. f.name) or "you are in no fellowship"
end
local function member(name)
  local f = cur()
  return f ~= nil and f.members[full(name)] ~= nil
end

local function realms()
  local list = GetAutoCompleteRealms and GetAutoCompleteRealms() or {}
  ns:Print(#list > 0 and table.concat(list, ", ") or "(no connected realms: only your own)", true)
end

ns.ManualSteps = {
  -- Start
  { id = "lua-errors", section = "Start", todo = "Turn Lua errors on.",
    see = "Any Lua error at any later step is a Problem: take a screenshot of it.",
    cmds = { "/console scriptErrors 1" },
    auto = function()
      local v = C_CVar and C_CVar.GetCVar and C_CVar.GetCVar("scriptErrors")
      return v == "1", "Lua errors " .. (v == "1" and "on" or "off")
    end },

  -- Creating and joining
  { id = "welcome", section = "Creating and joining", todo = "Open the book (you have no fellowship after /jtf check).",
    see = "Welcome: the tiles Create a Fellowship and Join a fellowship; the red trial line; under Your characters, your row says \"Create one, or join with an invitation\".",
    cmds = { "/jtf" }, auto = none },
  { id = "create-journey", section = "Creating and joining",
    todo = "Click Create a Fellowship. Step 1: click a size card and an emblem on the right page. Step 2: click each play style. Go to step 3 (Journey).",
    see = "Step 1: the banner on the right follows your colour and emblem. Step 2: each style's strip of levels, and the right page explains the chosen one. Step 3: Classic says 15 chapters; its colour strip starts with the Prologue's brown, and the right page lists its chapters.",
    auto = function()
      local n = #ns.BuildJourney("classic").chapters
      return n == 15, "Classic has " .. n .. " chapters"
    end },
  { id = "create-own", section = "Creating and joining",
    todo = "Click Your own journey, then Next (Chapters). Drag a dungeon from the shelf (right page) onto a chapter on the left, and drag a gold mark on the ruler. Then Back, and pick Classic again.",
    see = "Five steps while Your own journey is chosen. The dungeon follows the cursor and lands as a chip in the chapter you drop it on; the mark moves the level two chapters share (the tooltip shows both). Back on Classic: four steps.",
    auto = function()
      local C = ns.CreateState
      local j = C and C.journey
      if not j then return false, "no journey of your own yet" end
      return true, ("your own journey: %d chapters, %d placed dungeons"):format(#j.chapters, select(2, C.Counts(j)))
    end },
  { id = "create-done", section = "Creating and joining", todo = "Pick Classic, go to step 4 and press Create.",
    see = "The Trial account toast; the header says Chapter 1 of 15 · 1-15.",
    auto = function()
      local f = cur()
      if not f then return false, "you are in no fellowship" end
      local n = #f.journey.chapters
      return n == 15 and ns.Journey:CurrentIndex(f) == 1 and f.leader == ns.Me(),
        ("%s: chapter %d of %d"):format(f.name, ns.Journey:CurrentIndex(f) or 0, n)
    end },
  { id = "prologue-page", section = "Creating and joining", todo = "Open the Chapter page.",
    see = "Level 1-15 · Level together. A track of stages (Everyone at 1 done, Level to 15, Complete) and the Prologue's picture (a valley with an inn) where dungeons would be.",
    cmds = { "/jtf chapter" },
    auto = function()
      local f = cur()
      if not f then return false, "you are in no fellowship" end
      local n = #ns.Journey:InChapter(f, 1)
      return n == 0, "the first chapter has " .. n .. " dungeons"
    end },
  { id = "admin-ruler", section = "Creating and joining", todo = "Open Journey Admin (under Admin in the sidebar).",
    see = "The journey editor: the level ruler runs across both pages on a card (the book's rounded frame, like the Overview's card, shaded where it crosses the fold), from 1 to 60 with 10, 20 ... under it, a segment per chapter (its number in it, the chosen one with a bright edge) and gold marks between; dungeons are chips in each chapter, and the shelf of every dungeon is on the right page under the ruler. Drag a gold mark: both chapters' levels follow." },
  { id = "leave-alone", section = "Creating and joining", todo = "Manage → The fellowship → Leave → confirm.",
    see = "You were alone, so the fellowship ends; you are back on Welcome.", auto = none },
  { id = "accept", section = "Creating and joining", todo = "Get the pretend invite, then Join a fellowship → Accept.",
    see = "A toast and the inbox badge; after Accept you are in Test Fellowship (Testleader leads).",
    cmds = { "/jtf debug invite" }, auto = inTest },
  { id = "leave-member", section = "Creating and joining", todo = "Adventurers → Leave the fellowship → confirm.",
    see = "Back on Welcome.", auto = none },
  { id = "rejoin", section = "Creating and joining", todo = "Get the invite again and accept. Wait 10 seconds.",
    see = "You stay in Test Fellowship (this used to throw you out at once).",
    cmds = { "/jtf debug invite" }, auto = inTest },
  { id = "commands", section = "Creating and joining", todo = "Open the Adventurers page by command, then the help.",
    see = "All three open the Adventurers page; the help lists /jtf adventurers.",
    cmds = { "/jtf adventurers", "/jtf companions", "/jtf heroes", "/jtf help" } },

  -- As an Adventurer
  { id = "welcome-card", section = "As an Adventurer (Testleader leads)", todo = "Open the Overview, then the Chapter, Rules and Quests pages one by one, and the Overview again.",
    see = "Welcome to the fellowship on the Overview: the Chapter, the rulebook and the quests, each ticked once you opened its page. When all three are ticked the card goes.",
    auto = function()
      local f = cur()
      if not f then return false, "you are in no fellowship" end
      local list, label = ns.Together:Started(f)
      if label == ns.L.WELCOME_LABEL then
        local done = 0
        for _, s in ipairs(list) do if s.done then done = done + 1 end end
        return false, ("the welcome card: %d of %d ticked"):format(done, #list)
      end
      return f.leader ~= ns.Me(), f.leader ~= ns.Me() and "all ticked: the card is gone" or "you lead this fellowship"
    end },
  { id = "rulebook", section = "As an Adventurer (Testleader leads)",
    todo = "Open Rules. Read the rulebook on the left; on the right choose a rule and a new value, and press Propose.",
    see = "Six numbered articles in plain sentences (Away and If the Leader is away are two), the values in colour. Your proposal shows under Open votes with Yes / No; the rule itself has not changed yet.",
    auto = function()
      local f = cur()
      if not f then return false, "you are in no fellowship" end
      for _, v in pairs(f.votes or {}) do
        if v.by == ns.Me() then return true, "your vote: " .. ns.Rules.Name(v.key) end
      end
      return false, "no vote proposed by you"
    end },
  { id = "leader-rules", section = "As an Adventurer (Testleader leads)", todo = "Testleader changes a rule.",
    see = "A toast: New rules. Click it: the Rules page opens. A line under Recent history (Adventurers page) and in History.",
    cmds = { "/jtf debug hero Testleader rules" },
    auto = function()
      local f = cur()
      if not f then return false, "you are in no fellowship" end
      return f.rules.minHeroes ~= 4, "a run counts with " .. f.rules.minHeroes .. " Adventurers"
    end },
  { id = "leader-journey", section = "As an Adventurer (Testleader leads)",
    todo = "Testleader publishes a shorter journey. Press the button once: each press removes one more chapter.",
    see = "A toast: A new journey. The header says Chapter 1 of 14; a line under Recent history.",
    cmds = { "/jtf debug hero Testleader journey" },
    auto = function()
      local f = cur()
      if not f then return false, "you are in no fellowship" end
      local n = #f.journey.chapters
      return n == 14, "the journey has " .. n .. " chapters"
    end },
  { id = "removed", section = "As an Adventurer (Testleader leads)", todo = "Testleader removes you.",
    see = "\"You are no longer in Test Fellowship.\" and Welcome.",
    cmds = { "/jtf debug hero Testleader remove" }, auto = none },
  { id = "disbanded", section = "As an Adventurer (Testleader leads)",
    todo = "Get the invite and accept it, then Testleader disbands.",
    see = "\"Test Fellowship was disbanded.\" and Welcome.",
    cmds = { "/jtf debug invite", "/jtf debug hero Testleader disband" }, auto = none },
  { id = "handed-lead", section = "As an Adventurer (Testleader leads)",
    todo = "Get the invite and accept it, then Testleader hands the fellowship to you.",
    see = "You are the Leader: Admin shows in the sidebar.",
    cmds = { "/jtf debug invite", "/jtf debug hero Testleader lead" },
    auto = function()
      local f = cur()
      if not f then return false, "you are in no fellowship" end
      return f.leader == ns.Me(), ns.Short(f.leader) .. " leads"
    end },

  -- As the Leader
  { id = "corwin-joins", section = "As the Leader", todo = "Corwin accepts an invite.",
    see = "Corwin joins: his card on Adventurers and a line under Recent history and in History (Fellowship). (The Chronicle is for runs, Leader changes and the cap.)",
    cmds = { "/jtf debug hero Corwin accept" },
    auto = function() return member("Corwin"), member("Corwin") and "Corwin is in" or "Corwin is not in" end },
  { id = "gathering", section = "As the Leader", todo = "Brannic sets up a Gathering; Elyra answers Maybe, Corwin No.",
    see = "Gatherings: who is coming, maybe, not coming.",
    cmds = { "/jtf debug hero Brannic gather", "/jtf debug hero Elyra answer maybe", "/jtf debug hero Corwin answer no" },
    auto = function()
      local f = cur()
      local n = f and #ns.Gatherings:Upcoming(f) or 0
      return n > 0, n .. " Gatherings coming up"
    end },
  { id = "role", section = "As the Leader", todo = "Elyra changes her role.", see = "Adventurers: the Healer icon for Elyra.",
    cmds = { "/jtf debug hero Elyra role Healer" },
    auto = function()
      local f = cur()
      local m = f and f.members[full("Elyra")]
      return m ~= nil and m.role == "Healer", m and ("Elyra: " .. tostring(m.role)) or "Elyra is not in"
    end },
  { id = "away", section = "As the Leader", todo = "Elyra goes away, then comes back.",
    see = "Adventurers: her card fades, with a grey mark and Away (Online now or Seen … under it); then the mark is green or red again.",
    cmds = { "/jtf debug hero Elyra away", "/jtf debug hero Elyra away off" },
    auto = function()
      local f = cur()
      if not f or not f.members[full("Elyra")] then return false, "Elyra is not in" end
      return true, "Elyra: " .. ns.Hero:Presence(f, full("Elyra"))
    end },
  { id = "presence", section = "As the Leader",
    todo = "Elyra: online with her addon quiet, then AFK, then online again. Hover her card each time.",
    see = "Adventurers: a green ring with Online and Addon not heard; then a yellow mark and AFK; then a green mark and Online. The tooltip says what each mark means.",
    cmds = { "/jtf debug hero Elyra quiet", "/jtf debug hero Elyra afk", "/jtf debug hero Elyra online" },
    auto = function()
      local f = cur()
      if not f or not f.members[full("Elyra")] then return false, "Elyra is not in" end
      local kind = ns.Hero:Presence(f, full("Elyra"))
      return kind == "online", "Elyra: " .. kind
    end },
  { id = "run", section = "As the Leader",
    todo = "Group with Elyra and Corwin; Brannic reports a boss kill in the Deadmines. Then ungroup.",
    see = "Chronicle → Runs: a Deadmines run with you in it, under Runs that did not count (the Deadmines is in chapter IV, not open yet). Counted runs are checked by /jtf check.",
    cmds = { "/jtf debug group Elyra", "/jtf debug group Corwin", "/jtf debug hero Brannic kill dm", "/jtf debug group off" } },
  { id = "gear", section = "As the Leader", todo = "Brannic shares his gear.", see = "Inspect Brannic: his items.",
    cmds = { "/jtf debug hero Brannic gear" } },
  { id = "version", section = "As the Leader", todo = "Brannic says hello with an older addon than Elyra's.",
    see = "Adventurers: Old addon in orange after Brannic's class and role (the tooltip has both versions), not on Elyra's. Inspect Brannic: the line under his name ends with addon 0.9.0 (old). A development copy (the junction) is never old: no line at the top of the page, no toast.",
    cmds = { "/jtf debug hero Elyra version 0.9.2", "/jtf debug hero Brannic version 0.9.0" },
    auto = function()
      local f = cur()
      if not f then return false, "you are in no fellowship" end
      local old = ns.Hero:OldVersion(f, full("Brannic"))
      return old == "0.9.0", "Brannic: " .. tostring(old and (old .. " (old)") or "not old")
    end },
  { id = "not-allowed", section = "As the Leader", todo = "Brannic tries to remove Elyra and to rename the fellowship.",
    see = "Nothing changes: an Adventurer may not.",
    cmds = { "/jtf debug hero Brannic remove Elyra", "/jtf debug hero Brannic rename Nope" },
    auto = function()
      local f = cur()
      if not f then return false, "you are in no fellowship" end
      return member("Elyra") and f.name ~= "Nope", ("%s; Elyra %s"):format(f.name, member("Elyra") and "is in" or "is gone")
    end },
  { id = "member-invites", section = "As the Leader", todo = "Brannic invites Darrow (every Adventurer may invite).",
    see = "Manage, Adventurers tab: an open invite to Darrow, sent by Brannic.", cmds = { "/jtf debug hero Brannic invite Darrow" },
    auto = function()
      local f = cur()
      local on = f ~= nil and f.invites[full("Darrow")] ~= nil
      return on, on and "Darrow is invited" or "no invite to Darrow"
    end },
  { id = "swap", section = "As the Leader", todo = "Corwin plays another character.",
    see = "Adventurers: Corwinalt in Corwin's place; a line in History.", cmds = { "/jtf debug hero Corwin swap Corwinalt" },
    auto = function()
      return member("Corwinalt") and not member("Corwin"), member("Corwinalt") and "Corwinalt is in" or "no Corwinalt"
    end },
  { id = "history", section = "As the Leader", todo = "Open History (Fellowship). Try its filters.",
    see = "Who joined, left and leads, Gatherings and the rest, newest first; Adventurers, Rules and votes, Events filter them. Right: Founded on … by …, the numbers, the Leaders, Open the Chronicle.",
    auto = function()
      local f = cur()
      local n = f and #ns.Fellowship:ChronicleView(f, 1000, "members") or 0
      return n > 0, n .. " lines about Adventurers"
    end },
  { id = "moments", section = "As the Leader", todo = "Mark a dungeon of this chapter cleared (Chapter page), then open the Chronicle and its Moments tab.",
    see = "A tile for the dungeon's first clear (its picture, the day). Click it: large on the right, what happened, who was there with levels, Your pictures.",
    auto = function()
      local f = cur()
      local n = f and #ns.Moments:List(f) or 0
      return n > 0, n .. " moments"
    end },
  { id = "photo", section = "As the Leader", todo = "Open the group photo with stand-ins (you in everyone's place). Click one, turn them, change poses and the backdrop, then Take the photo.",
    see = "The interface hides. Everyone stands side by side in one scene, at their true size, with names under their feet and the fellowship's crest and name top left. Take the photo leaves out the controls; Esc brings the interface back.",
    cmds = { "/jtf debug photo" },
    auto = function()
      local PH = ns.Photo
      return PH.cast ~= nil and #PH.cast > 0, #(PH.cast or {}) .. " in the photo"
    end },

  -- Playing together (M25)
  { id = "play-now", section = "Playing together", todo = "Elyra and Corwin come online. Open the Overview.",
    see = "A gold Play now block: the one best thing to do with who is online (help someone to the floor, a dungeon two of you need, a shared quest, or level together) with one button. The tracker's next line says the same.",
    cmds = { "/jtf debug hero Elyra online", "/jtf debug hero Corwin online", "/jtf" },
    auto = function()
      local f = cur()
      local p = f and ns.Together:PlayNow(f)
      return p ~= nil, p and p.text or "no Play now (nobody online?)"
    end },
  { id = "ahead", section = "Playing together", todo = "Corwin falls behind, then you level up (pretend) twice.",
    see = "A toast \"You are … levels ahead of Corwin\"; the You card on the Overview says it too. Then set your level back.",
    cmds = { "/jtf debug hero Corwin level 15", "/jtf debug level 18", "/jtf debug level 19", "/jtf debug level off" } },
  { id = "session", section = "Playing together", todo = "End a pretend session with your group (as if you played 15 minutes), then click the big toast.",
    see = "The Session recap toast (big, no fanfare); its click opens the Chronicle at Sessions with the recap and a Your session chip.",
    cmds = { "/jtf debug session" },
    auto = function()
      local f = cur()
      local n = f and #ns.Session:Entries(f) or 0
      return n > 0, n .. " sessions kept"
    end },
  { id = "share", section = "Playing together",
    todo = "Adventurers page: under the name box, click Friend without the addon? Share it. Then press Whisper the link with a friend's name, and press Escape in the chat box (nothing is sent).",
    see = "The window: the addon's page (Ctrl+C copies it) and Whisper the link; the chat box opens with /w and the link. /jtf debug share shows the window an unanswered invite opens.",
    cmds = { "/jtf debug share Kim" } },
  { id = "milestone-pick", section = "Playing together",
    todo = "Brannic shares his quests. Journey Admin → Add a milestone → Quest → Pick from your quests.",
    see = "Your quests first, then the others' with their names; a pick fills in the quest ID and the name. Typing an ID works too. Close without adding.",
    cmds = { "/jtf debug hero Brannic quests" } },
  { id = "week", section = "Playing together", todo = "Open Gatherings.",
    see = "The right page: The week ahead, seven days, each with its Gatherings or Schedule; Schedule opens the form at that day. Long lists fade at their lower edge while there is more below." },

  -- Sync edge cases
  { id = "sync-line", section = "Sync edge cases", todo = "Show the sync state.",
    see = "One line in chat: version, fingerprint, messages waiting, held off.", cmds = { "/jtf debug sync" } },
  { id = "clash", section = "Sync edge cases",
    todo = "Elyra sends a change made at the same time as one of yours. Press the four buttons in order.",
    see = "The second sync line has a version one higher than the first: you took her change (Elyra shows away until the last button).",
    cmds = { "/jtf debug sync", "/jtf debug hero Elyra clash", "/jtf debug sync", "/jtf debug hero Elyra away off" } },
  { id = "snap", section = "Sync edge cases", todo = "Brannic sends his whole copy, one version ahead.",
    see = "The fellowship's name gets a *.", cmds = { "/jtf debug hero Brannic snap" },
    auto = function()
      local f = cur()
      return f ~= nil and f.name:sub(-1) == "*", f and f.name or "you are in no fellowship"
    end },
  { id = "hold", section = "Sync edge cases",
    todo = "Hold on pretends you are in a dungeon (no combat needed; inside one the game holds addon messages). Then on the Adventurers page invite any name, on Manage's Rules tab change a rule and Publish, and Sync. Then Hold off, wait a few seconds, Sync again.",
    see = "The invite: \"You can't invite during a fight or inside a dungeon.\" First sync: messages waiting, held on. Second: 0 waiting, held off.",
    cmds = { "/jtf debug hold on", "/jtf debug sync", "/jtf debug hold off", "/jtf debug sync" },
    auto = function()
      local n = ns.Comm:Pending()
      return not ns.Comm:Held(), ("held %s, %d messages waiting"):format(ns.Comm:Held() and "on" or "off", n)
    end },
  { id = "offline", section = "Sync edge cases", todo = "Brannic goes offline.",
    see = "Adventurers: a red mark and Offline on his card, Seen 3 hours ago under it, the card a little faded; Invite to group greyed for him.",
    cmds = { "/jtf debug hero Brannic offline" } },

  -- The client
  { id = "combat", section = "The client", todo = "Get into combat (a training dummy or any mob); open the book with /jtf or the minimap button and turn pages.",
    see = "Everything works; no blocked-action error." },
  { id = "positions", section = "The client",
    todo = "Drag and resize the book, drag and fold the tracker, drag the minimap button; Settings → Toast position → Move. Then reload.",
    see = "Everything stays where you put it; this card comes back at this step.", cmds = { "/reload" } },
  { id = "sounds-effects", section = "The client", todo = "Settings: sounds off, then on. Reduce effects on, then off again.",
    see = "Sounds only when on; with Reduce effects no page-turn animation and no toasts.", cmds = { "/jtf settings" } },
  { id = "relog", section = "The client", todo = "Log out and in again.",
    see = "Everything is still there; Since you were last here; the setup guide does not come again." },
  { id = "other-character", section = "The client",
    todo = "Log in on another character, look at Your characters, press Follow this fellowship and open its Rules, then come back.",
    see = "Your characters lists this character's fellowship with \"as of …\" and Follow this fellowship. Its Rules page says \"Read only\" and \"as of …\"; nothing there can be changed." },
  { id = "realms", section = "The client",
    todo = "List the realms you can whisper. Then on the Adventurers page invite a made-up name on a realm not in that list, for example Bob-Illidan. Nobody is contacted.",
    see = "The list prints in chat; the invite is refused: only your realm and the realms connected to it can share a fellowship.",
    cmds = { { "List realms", realms } } },
  { id = "leave-test", section = "The client", todo = "Leave Test Fellowship (Manage → The fellowship → Leave).",
    see = "Brannic leads after you; you are back on Welcome.", auto = none },
}
