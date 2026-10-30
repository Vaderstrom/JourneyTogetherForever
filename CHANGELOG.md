# Changelog

## 0.9.2 beta (30 October 2026)
- The Your characters panel on the Welcome page: the pale fade at the bottom of the page's list showed through it,
  across a character's name. Lists now fade under the panels, and a panel's list under a question in the book.
- Journey Admin is tidier: the right page has three tabs, This chapter (name, levels, dungeons, milestones), Every
  dungeon and Whole journey (Start over, Import, Export), and Publish sits in a bar at the bottom that never scrolls,
  gold while there are unpublished changes. It was at the end of a long scroll, under every dungeon. Create a
  Fellowship's Chapters step has the same tabs.
- The round icons (the sidebar and the header's buttons) follow the header's art: a Horde character sees them in
  crimson in every theme. In the Journal and Night themes they were blue under the Horde's art.
- `/jtf brand` (for the README): the README's pictures, taken on an Alliance character in the Journal theme, with
  the showcase fellowship "The Lantern Bearers" (a blue banner with the lion), roles that fit the classes, and the
  game's interface hidden (the tracker shows only in its own picture). Each picture's place on the screen is saved; `tools/brand-shots.lua` and `tools/crop-shots.ps1` cut them into
  `.github/screenshots`.

## 0.9.1 beta (30 October 2026)
A beta: everything below, and the milestones M1 to M9 in the next section. Version 1.0 comes when WoW Forever
launches and the addon has been tested there, with its dungeon and raid lists brought in line with Forever's.

- The README describes every feature, with pictures from the game.
- The release notes on GitHub (and later CurseForge) are this changelog.

- **Dungeon pictures in Discord**: the board's dungeons and the posts of their clears show the dungeon's loading
  screen, as the book does, read by WoW Addon Webhooks for Discord from your own game (its W6: an addon may not ship
  copies of the game's art). Before, only Forever's own dungeons had a picture there; the others had an empty frame.
  An app without W6 draws the board as before. The loading screens are also cut a little lower at the top, in the
  book too: a sliver of the game's logo showed.
- Fixes from the code review before this release:
  - Following your fellowship from another character no longer drops this account's Moments or lowers the furthest
    chapter reached.
  - After a long dungeon run your messages to the others go out at once: only your newest level, XP and gear wait
    while sending is held (an update every minute piled up and held back everything behind it).
  - A boss kill whose result the game hides (a secret value) is skipped instead of compared.
  - History entries in a copy from another Adventurer are checked (numbers as numbers, runs with their lists), so a
    bad one can no longer break the Discord board at logout.
  - Parts of a long message that stopped coming (the sender logged off) are forgotten.
- **Full screen is the whole screen**: the book now reaches every edge of the screen (it kept the window's width,
  with dimmed gaps at the sides). The logo sits inside the header, with the fellowship's crest and name beside it.
  Each page keeps the width it was laid out for, in the middle of its half of the book; on Settings and Journey Admin
  the two halves stay together in the middle of the sheet. The sidebar grows with the taller book.
- **Group photo for big fellowships**: up to six in a row, the rows as even as can be (ten stand in two rows of
  five, twenty in four), each row standing between the heads of the row in front, and the camera looking down a
  little more for every row, so the faces behind show. Names stay under the front row's feet and go over the heads
  of the rows behind.
- **Group photo over the world**: the game's camera goes to first person, so the world is the backdrop and not your
  own back. **Look around** hides the controls and gives the mouse back to the game: walk, turn and zoom as always to
  find the place, with everyone staying in front of you; **Back to the photo** brings the controls back. The camera
  goes back as far as it was when the photo closes (also after a reload with the photo open).
- Fixes from the check run of 30 Oct: your own 3D head on a member's Adventurers page was a grey box (it is set
  again whenever its card shows); in the group photo you crouched as on your mount (your pose is set again once your
  model has loaded), the pose bar kept the last photo's pose, names of hostile NPCs still stood over the world, and
  the camera's distance was saved wrong when the photo opened again while the camera still glided back; the
  controls gallery's fifth column ran off the book.
- Fixes from the check run of 29 Oct (late): your 3D head on the walkthrough's sample Adventurers page was an empty
  box (moved to another card while shown, it is now set again there); the controls gallery stays above the pages'
  scroll fades and wraps its columns at the book's own height.
- **Raids open only after the journey**: the Endgame (and its banner, and Raids in the sidebar) opens when the last
  chapter is complete, no longer when every Adventurer is level 60. A fellowship of level 70s on retail got the
  Endgame banner in its second chapter.
- **Full screen uses the room**: the book now fills the screen from top to bottom. The room is shared: the book is a
  little larger than in a window, and its pages are taller, so dungeons, quests, Adventurers and the chronicle show
  more before they scroll. On a 4K screen the pages grow from 730 to about 900.
- **A chosen card stands out**: the chosen size of fellowship (and the chosen emblem) is lighter than the page,
  with a gold rim and a soft gold glow at the top. It was a darker gold wash that read as faded into the page.
- **Adventure Guide art**: gold titles on pictures (the Found and Join tiles, presets, raid cards) use Morpheus, the
  Adventure Guide's title font; the divider under titles is the guide's ink flourish on light pages; empty pages
  frame their picture in the guide's gold ring. All of it is in Forever's files too, and each falls back to the
  drawn look where it is missing. `/jtf debug buttons` shows the art.
- **Full screen**: the red expand button beside Close (or Settings → The book → Full screen) makes the book as large
  as the screen allows, in the middle, with the world and the interface dimmed behind it; the condense button goes
  back. Kept per character. On a 4K screen with a lower UI scale the book stayed at its drawn size, about two thirds
  of the screen; full screen fills it. The size dragged at the corner no longer runs off the screen (120% did on a
  screen 768 UI units high, the game's usual).
- Fixes from the check run of 29 Oct (evening): the bottom of a scrolling page fades into the page's own parchment
  (it was a light band); the inserts' ribbon ends in a swallowtail (a white diamond showed under it); the
  walkthrough's card is solid; a big toast's text keeps clear of its frame; the 20-entrant tournament sample fills
  the whole page, with levels and classes in the entrants list; the walkthrough's sample Rules page shows Propose; ink
  sketches and page pictures are tinted on the Night theme; an empty Moments page says how pictures join it; the
  group photo spaces and frames everyone by the size of their model; a past entrant no longer breaks the tournament
  page.
- New files `Media/FadeMask.tga` and `Media/RibbonMask.tga` (made by `tools/make-masks.lua`): **a full game restart**
  is needed.
- **Book, flat sheet and bookmarks**: Journey Admin and Settings lie on one flat sheet across the whole book, with no
  fold (it read as a black string across Journey Admin's ruler) and their title across the top. Your characters and
  the Inbox are bookmarked inserts: a loose sheet over the right page with a drop shadow and a ribbon with its icon
  over the top edge; they slide in (not with Reduce effects).
- **Settings is a page**: two sides and no scrolling: the book, messages, help and the commands on the left; progress
  toasts and the tracker on the right, two boxes to a line, the tracker's options faded while it is off. Every
  explanation is behind a "?". The gear opens it and, pressed again or with Back, returns to where you were; it works
  outside a fellowship too.
- **Tournaments for big fellowships**: with more than 8 entrants in a stage the structure shows round by round
  (finished rounds as a line of winners and a line of byes, the round being played as cards two to a line, later
  rounds as one line each); up to 8 the drawn bracket stays. The winner of a match is on a gold band with a tick, the
  loser faded, your own line tagged You, and a Champion box follows the final. `/jtf debug tourney big` shows 20.
- Fixes from the check run of 29 Oct: closing the group photo no longer closes the book; the photo frames the whole
  group and hides nameplates and names in the world; the level track's floor and cap labels no longer overlap; "at
  the cap" only for those at it, not over it; levels to go with a decimal ("2.6 levels"); Since you were last here
  says when only levels moved; the picture prompt and the tracker keep clear of the action bars and the minimap; a
  one-level chapter shows in Journey Admin; open dungeons are easier to read.
- `UI/Panels/Settings.lua` moved to `UI/Pages/Settings.lua` (both TOCs): **a full game restart** is needed.
- **Discord through WoW Addon Webhooks for Discord**: the Journey Together Companion for Discord became WoW Addon Webhooks
  for Discord, one app for every addon that brings a plugin, in its own repository. Journey Together is its first
  plugin: the new `Webhooks` folder (shipped in the package) holds `webhooks.json` and the board picture, `card.html`,
  whose look and drawing (`board.css`, `board.js`) the sample boards in `docs/mockup/companion-board.html` now share.
  On logout the addon writes the outbox `JourneyTogetherForeverDB.webhooks` (docs/SAVED-DATA.md) in place of `board`:
  per fellowship the board (kept up to date), the news (Chapter complete, Dungeon cleared, each with its picture from
  `Media`) and each Adventurer's level for the weekly summary. The old `board` table is removed at the next logout.
  The test harness writes `tests/fixtures/webhooks.lua`. The Companion's code (`companion/`) and its release workflow
  are gone. Saved-data change only: `/reload` is enough.
- **Play now**: with other Adventurers online, the Overview shows the one best thing to do together (help the one
  below the floor, a dungeon two of you need, a quest you share, or level together) with one button, in place of
  Invite to group. The tracker's next step says the same.
- **Keep everyone in step**: below the floor, the You card names the journey's dungeons good for your level (the ones
  you have not cleared first) and who is online. Two or more levels ahead of an Adventurer (not one catching up), a
  toast says so once per level and the You card keeps the line.
- **Session recap**: a session starts when another Adventurer is in your group and ends two minutes after the last
  one leaves (or at logout; /reload keeps it going). After ten minutes or more, a big toast sums it up: how long, with
  whom, levels gained, dungeons and clears, bosses, quests turned in and chapters unlocked. A click opens History at
  the new Sessions tab. Recaps stay on your character (the last 50) and are never sent.
- **Friends without the addon**: an invite that gets no answer from the player's addon opens a short window with the
  addon's page to copy and Whisper the link (the chat box opens with the whisper; you press Enter). The same window
  opens from "Friend without the addon? Share it" under Invite Adventurers.
- **Milestones from your quests**: Journey Admin's milestone form picks a quest from your quest log, then from the
  quests the others share. Typing a quest ID still works.
- Gatherings: the right page shows the week ahead, each day with its Gatherings or Schedule (opens the form at that
  day).
- Lists that scroll fade at their lower edge while there is more below. Dropdowns end long choices in "...". History's
  five tabs fit. The Chapter page has no next-step line while the chapter waits for the floor.
- Both new toasts (ahead, session recap) can be turned off in Settings.
- Developer: the layout check (Dev/Layout.lua) measures every visible text before each tour screenshot (cut off,
  overlapping, outside its box; not text under a window, a side panel or the walkthrough card); check-report prints
  it. /jtf debug session and /jtf debug share, Lab entries, six new in-game test steps, new self-test steps and tour
  shots for the batch.
- Developer: **Getting started in the lab** (`/jtf lab`, Scenarios): Welcome, an invitation, as an Adventurer (you
  join the Lab fellowship and see the welcome card), as the Leader, and the setup guide; "Show me around" as an
  Adventurer under Events. A self-test step checks the Adventurer's welcome card (three steps, ticked as you visit
  Chapter and Rules) and an in-game test step looks at it (48 steps).
- Developer: the game once stopped `/jtf check` for running too long ("exceeded its execution time limit") and its
  error window covered most screenshots. Self-test steps now spread long work over frames and are timed
  (check-report lists the slow ones), the game's warnings about the addon go to the error log with the step that was
  running, and the tour closes the error window before each screenshot (the report says when it had to).
- Fixed (from the check run of 29 Oct): with Play now, the Overview's card no longer repeats the group-up step and
  the Online now line (the card grew too tall); a dungeon row on the Chapter page drops "Level" when its line would be
  cut next to Find group; Schedule a Gathering: the time, hint and problem line go under the days, which no longer
  run over the time.
- Fixed (from the second check run of 29 Oct): Play now's button sits on its label's row and the catch-up line names
  who is online once, not after each dungeon (the Overview's card was 400 high while catching up); History's All tab
  keeps entries of the same moment in their order (chapters unlocked together came out IV, IX, V ...); the rules
  form says "If the Leader is away" like the rulebook. Developer: the tour opens the Chapter page for its tooltip,
  next-chapter and later-chapter shots (they showed the Overview), shows History at All and the welcome card again;
  the layout check counts dialogs in the book's frame and the button gallery as covering the page, and no longer
  reports page text that lies partly under a dialog or the walkthrough card.
- Developer: **a Dev copy next to the addon**. `JourneyTogetherForever-Dev.toc` loads the same files from a folder
  named `JourneyTogetherForever-Dev`, with its own saved data (`JourneyTogetherForeverDevDB`,
  `JourneyTogetherForeverDevCharDB`), so the released addon and the Dev copy can each be turned off in the AddOns
  list. With both on, the second to load stays off and says so in chat. The report tools read either file.
- **Chronicle, Moments and History**: two stories, two pages. The journey's page is now the **Chronicle** (it was
  History: runs, sessions, leader changes, the cap), with a second tab, **Moments**: the journey's big moments as
  picture tiles (a chapter begins, the journey is complete, a dungeon's first clear, a milestone, an Adventurer at
  the journey's last level, the champion). The chosen moment shows large with what happened, who was there with
  their levels then, and the pictures you took then (Take a picture is kept with the fellowship, the dungeon and the
  group; the game keeps the files in its Screenshots folder, which an addon cannot show, so the tab shows the
  chapter's or dungeon's picture: the screenshots themselves go to Discord). Moments come from what the fellowship
  keeps anyway, so everyone's addon finds the same ones; fellowships from before find their chapters and first clears
  from the Chronicle. The Fellowship section gets a new **History**: who joined, left and leads, rules and votes, Gatherings
  and the tournament, with filters, when the fellowship was founded, its numbers and its Leaders. "From the
  chronicle" on the Overview and Adventurers pages is now "Recent history". With Raids, the tournament and Admin the
  sidebar has 12 entries, each a little lower so they fit. Developer: `/jtf check` areas chronicle, moments and
  history, with their self-test steps and tour shots; two in-game test steps; the self-test and the tour forget the
  pictures they take.
- **Pictures to Discord** (opt-in): pictures taken with Take a picture go into the outbox as news of a new kind,
  "Pictures from runs", not posted until the player draws a line from it, with when they were taken (`screenshot`)
  so WoW Addon Webhooks for Discord posts the game's file with "The Deadmines: a picture with Lea, Pata and Noa."
  (docs/SAVED-DATA.md; the app does so from its W4).
- **Only when in Discord**: the news in the outbox carry fields the app's Only when can test: a completed
  chapter's number, and the dungeon and who was there for clears and pictures ("Who includes Lea"). The plugin's
  manifest names them. Saved-data change only: `/reload` is enough.
- **Group photo**: the whole screen, like Narcissus's photo mode. The interface hides and the fellowship stands
  together in one 3D scene at their true size, the Leader in the middle; names under their feet and the crest, name,
  place and day top left. Choose someone to turn them and give them a pose (or everyone a pose), pick a backdrop (the
  world, a studio, the chapter, the dungeon), zoom and move the camera, then Take the photo: the game's screenshot
  without the controls, kept with your pictures and, with "Pictures from runs", posted to Discord as "A group photo
  with ...". From the Adventurers page, the banner after a final boss, or `/jtf photo`; out of combat only. Members
  the game cannot draw (not in your group and near) are left out and named. `/jtf debug photo` stands you in for
  them.
- **Lore Forever and Spoken**: with Lore Forever running, dungeon and raid cards get a Lore button that opens its
  story of the place. With Spoken running, attunement steps, chain parts and quests get Listen, which opens Spoken's
  Compendium at the quest to read and hear it (only quests Spoken would show, so nothing is spoiled). Both addons
  are for Forever; without them nothing changes.
- **New files** (Dev/Layout.lua, Fellowship/Session.lua, Fellowship/Moments.lua, UI/Share.lua, UI/Pages/Moments.lua,
  UI/Pages/History.lua, UI/OtherAddons.lua, UI/Photo.lua, JourneyTogetherForever-Dev.toc; UI/Pages/History.lua is
  now UI/Pages/Chronicle.lua): a full game restart is needed.
- **The Rules page is the fellowship's rulebook**: who sets the rules, the play style and size, and six numbered
  articles in plain sentences with today's values in colour (Leveling together, Dungeon runs, Away, If the Leader is
  away, The book, Guild Master tournament). On the right, **Change a rule**: the open votes with Yes / No, Propose a change
  (a rule and a new value), and the votes decided this week. The Leader votes too and changes the rules in Manage.
  The values stand out in a deep red-brown (a warm gold on the Night theme); a passed vote says what the rule was.
- **Manage** takes in Rules Admin: one sidebar entry with three tabs, Adventurers (needs attention, ranks, away,
  remove, invites), The fellowship (name, banner colour, every emblem, your banner as the others see it, Leave) and
  Rules (the draft and Publish).
- **Journey Admin's ruler runs across both pages**, with the levels under it (where the journey starts, then 10,
  20 ... 60, a mark every 5 levels) and each chapter's number in its part. It lies on one of the book's cards (the
  rounded frame of the Overview and the dungeon cards; the leather plate tried first looked out of place inside the
  book), shaded where it crosses the fold like the pages, so it no longer looks pasted over the middle of the book.
  The track looks like the book's bars (dark and inset, a thin gold edge, a highlight along each
  chapter's part; the chosen chapter has a bright edge). Create a Fellowship's journey editor and its journey views
  (step 3 and the review) have the same plate and track.
- Show me around (the Leader): Manage and its Rules tab one after the other, Journey Admin last.
- **One progress bar for the whole book** (the visual pass, round 1): a dark inset track with a thin edge (gold for
  the large ones), the fill with a highlight along its top and a bright spark at its end, and it glides to a new value
  (not with Reduce effects). Adventurer cards and Inspect: rested XP is a pale band ahead of the gold (at 0% it was a
  solid blue bar that looked full). The Overview's level track: a notch per level, floor and cap marked. Quests: a pip
  per item or kill for small goals ("3 of 7"), the count level with the bar. The Chapter page's waiting box too.
- The Chapter page's stage track: a soft halo around the stage the chapter is at, and the line thicker once a stage is
  done. The Overview's three steps have a thin edge in their colour.
- A chapter is named with its Roman numeral everywhere ("Chapter III unlocked", "Chapter II: Heroes Awaken" in
  History, Since you were last here, Your characters and the questions); counts stay in figures ("Chapter 3 of 15").
- Journey Admin's ruler: dark chapter numbers on the pale chapters (white on yellow could not be read).
- Fixed (from the check run): a Journey Admin draft left from another fellowship was edited instead of this one's;
  your 3D head could vanish from your card on the Adventurers page; following another character's fellowship, that
  character showed as online with "Addon not heard".
- **Everyone in a fellowship should update to this version together.** Older versions keep working with it, but the
  Prologue, catching up and restoring lost data only work once every Adventurer has it.
- **Create a Fellowship, redesigned**: every step uses both pages. Step 1: name, role and four size cards (each
  says what it suggests); your banner, its colour and every emblem on the right page. Step 2: each play style shows
  a strip of what it allows at each level of a chapter, explained on the right. Step 3: the chosen journey's
  chapters on the right. Review: the fellowship and the rules as rows, the journey's chapters, each with Change.
  Next and Create are on the right page.
- **Your own journey**, designed while you create the fellowship: the fourth journey tile (it replaces Start from
  scratch there) adds a Chapters step with the new **journey editor**. Drag the gold marks on the level ruler to move
  the level two chapters share (chapters always join up), Split / Merge / Remove chapters, and drag dungeons from a
  shelf of every dungeon onto a chapter (or from one chapter to another, or back onto the shelf). Clicks work too.
  It starts as a copy of the journey your size suggests; Start over and Import are there.
- **Journey Admin uses the same editor** (the ruler with marks, chapter rows with dungeon chips, the shelf), still on
  a draft until Publish, with each chapter's milestones and Export under it. The "Add dungeon" list is replaced by
  the shelf; "+ Add a chapter after" by Split in two (chapters always join up, so the floor-and-cap warnings are gone).
- "Found a fellowship" is now **Create a Fellowship** everywhere (Welcome, the steps, History lines). The command
  `/jtf adventurers` opens the Adventurers page (`/jtf companions` and `/jtf heroes` still work).
- Developer: **/jtf tests**, the in-game tests. A card on the screen walks through the 40 one-account checks
  (Dev/ManualSteps.lua) one at a time, with buttons for each step's commands and what the addon sees; Works goes on,
  Problem takes a screenshot and opens a note. Progress survives /reload and logging out; the report is saved and
  read with tools/manual-report.lua.
- **Chapter page redesigned**: a centred track of the chapter's stages (everyone at the floor → the dungeons →
  complete); while someone is below the floor a box in the middle says who, their level and how far; one line of
  What's next; every dungeon as one compact row (picture, kind, levels, Find group) so five fit without scrolling,
  with the details in a tooltip; a chapter without dungeons (the Prologue) shows its picture.
- Fixed: **the book could not open during combat** ("Interface action failed because of an AddOn"). The Tournament
  page's secure hand-over button made the whole book protected. The Guild Master's button now puts `/gleader <winner>`
  in the chat box; Enter hands over the guild.
- A click on a toast opens what it is about (new rules → Rules, a clear → Chapter, a Gathering → Gatherings, …).
  The Leader publishing a new journey now toasts the Adventurers too.
- **Adventurers page**: Invite Adventurers is at the top. Each card has a presence mark like the game's friends list:
  green Online, yellow AFK, red Offline (seen when), grey Away, and a green ring when the game shows someone online
  but their addon does not answer. Where they stand in the chapter moves after the XP, so you see both. Inspect and
  the standings on Overview and Chapter use the same marks.
- **Old addon versions**: an orange "Old addon" on the card of anyone whose addon is older than the newest in the
  fellowship. If yours is the old one, a toast tells you once per session (it opens the Adventurers page, where a line
  stays at the top until you update; Settings can turn the toast off).
- Developer: `/jtf debug hero <Name> online|quiet|afk` (quiet: online in the game, addon not heard).
- Developer: `/jtf debug sync` gave a Lua error when the fingerprint was above 2^31; `/jtf debug` help came out
  garbled in chat (one line per command now); `hero <Name> accept` says when they are already in. The test harness
  now fails a `%d` above 2^31 as the game does.
- Developer: the scripts looked over. tools/check-report.lua lists the Lua errors and blocked actions logged during
  the check (they had to be read from the saved data by hand) and runs on plain Lua 5.1 too (no goto); the tour no
  longer has two Chapter screenshots that could never be taken (the page fits now), and "a dungeon partly done" is
  taken again; harvest-quest-chains.lua prints its usage instead of a stack trace. Every Lua tool runs, the
  PowerShell scripts parse and the art tools compile.
- Developer: **/jtf lab**, the test lab (not in the help): a card with the checks (all, or one area), scenarios that
  put the book in a state with pretend Adventurers to look at by hand (a Lab fellowship, ended again with one
  button), pretend events (one Adventurer levels, goes offline, votes, leads ...) and the in-game tests card.
- Developer: the self-test (`/jtf selftest`, `/jtf check`) checks the new features: Create a Fellowship step by step
  with Your own journey and the journey editor (Split, Merge, a mark, a dungeon dropped in and out), the editor in
  Journey Admin on a draft, the Chapter page's waiting box, presence marks and Old addon, the Leader's new rules and
  journey as toasts and a click opening the page, nothing protected in the book (it opens in combat), the Discord
  board (built, not saved) and the sync line. New area "board"; 134 steps. Fixed: during the self-test a click on a
  toast opened nothing (the page was not passed on).
- Fixed (from the check run's screenshots): the Chapter page's stage "Run the dungeons" wrapped into the line under
  the track (each stage is one line now); the waiting box's "Also below the floor" named you by your character
  (now "you"); Journey Admin's milestone form had "Ticked by hand" outside the box; on the Night theme "Leader" and
  the dungeon roles (Bridge in dark blue) were hard to read.
- In-game tests card: after Problem the card says what is saved ("Saved: Problem · 1 screenshot · note saved") and
  shows Next step; the note says it is saved as you type. Clearer steps for the run, version, clash, hold and realms.
- Fixed: alone in a fellowship, What's next and the tracker said "0 of 1 Adventurers are there"; now "0 of 1
  Adventurer is there".
- Developer: planned a **companion app** that keeps the fellowship's progress posted in Discord (docs/SPEC.md §7,
  docs/SAVED-DATA.md, roadmap C1–C5, `companion/`). `companion/` is left out of the package and of luacheck.
- Developer (C1): on logout and `/reload` the addon saves a **board** of the current fellowship for the Companion
  (`JourneyTogetherForeverDB.board`, Fellowship/Board.lua): chapter, stages, every Adventurer's standing, dungeons,
  and chapter-complete and dungeon-cleared events. New "Chapter N unlocked" History entries keep their chapter number.
  `tests/fixtures/board.lua` is the sample the Companion's tests read. The board's events also carry the dungeon's
  name and the completed chapter's number and name (for the Companion's weekly summary).
- Fixed: joining a fellowship you had left before (the same one, invited again) threw you out at once: your old
  "leave" was made again on top of the new copy.
- Fixed: the journey picker said Classic has 14 chapters (15 with the Prologue); Journey Admin's ruler started at
  level 15, so the Prologue had no segment; the Prologue's Chapter page said "Dungeons open" (now "Level together").
- **Prologue**: every journey (except Start from scratch) begins with a Prologue, levels 1-15 without dungeons, so a
  fellowship can start together at level 1, with its own picture. Chapter numbers count it (Classic: Prologue and
  Chapters II-XV).
- **Catching up**: someone who joins far below the current floor no longer holds the fellowship back. They are
  "catching up" (on their card and the Chapter page) until their level reaches the floor, then count like everyone.
- **Lost saved data** (a new PC, a reinstall): the next message from your fellowship brings it back, at once or after
  a question in the book.
- **Realms**: invites to a realm that is not connected to yours are refused with the reason (addon messages do not
  reach it), and name suggestions leave those friends out.
- Catching up, finished: a newcomer catching up no longer holds the clears (when everyone must clear), a chapter's
  level goal, milestones or the Endgame either.
- Removed, or the fellowship disbanded, while you were away: your addon learns it at your next login and says so
  ("You are no longer in Band." / "Band was disbanded."), also when it happens while you are online.
- A change missed while online (lost during a boss fight) now arrives with the next level or XP update of anyone in
  the fellowship, instead of at the next login.
- A copy of the fellowship from someone who knew fewer levels no longer moves the fellowship back a chapter.
- Trial accounts and accounts without game time (the game blocks their addon messages): a warning on Welcome, when
  founding or joining, and a red bar across the book.
- Messages the game throttles are sent a moment later instead of being dropped.
- Forever is recognised by the game's project ID (the interface number as a fallback).
- Old votes (a week after they ended) and past Gatherings (a day after they started) are dropped, so saved data does
  not grow over a long journey. History keeps their lines.
- Self-test with two accounts' worth from one: pretend Adventurers now keep a copy of their own and answer like a
  second addon (Dev/Peers.lua), so `/jtf check sync` tries catching up at login, changes made apart, a change lost
  while online, kills compared at login, passed-on states, removed while away and restoring a lost copy. New checks
  for the Prologue, catching up, realms, the trial warning and pruning; three new screenshots.
- Self-test: a "boss data" check. On Forever it fails while a dungeon has no boss data or the data is from another
  build (run tools/update-game-data.ps1); on retail it is a note.
- Journey Admin opens on the current chapter.
- Sync for players who are not online at the same time: levels, XP and gear are passed on by whoever is online, kills
  are compared and merged at login, and changes made while apart are kept and made again on top of the newer copy,
  so nothing is lost. Still ordered by version numbers, not clocks.
- Two ranks: the **Leader** and the **Adventurers** (Captain, Steward and Companion are gone; Stewards become
  Adventurers). Adventurers invite, propose rule changes and vote, plan Gatherings. If the Leader stops playing, the
  Adventurer who joined first takes over.
- Admin for the Leader: **Journey Admin** and the new **Rules Admin**, where rule changes are a draft until
  published (everyone gets a toast and a History line). Fellowship > Rules shows the published rules and the votes.
- Manage is in the Leader's Admin. Everyone invites from the Adventurers page (a box under the cards, with your own
  open invites to cancel); the Leader can invite from both.
- Check runs: a screenshot whose screen failed to set up, or would repeat the one before (a page too short to
  scroll), is no longer taken; the report lists it as not taken. The walkthrough's tracker step works again.
- Show me around: a walkthrough of the book for Captains, Stewards and Companions. A guide card beside the book with
  Back and Next, the part it explains framed in gold with sparks and the rest dimmed, on a sample fellowship so every
  page has something to show. Offered once after the setup guide, any time from Settings, and as a short tour of
  what is new after a promotion.
- The logo's medallion is solid behind every letter (the O, G and E of TOGETHER had see-through edges).
- Sharper art on 4K screens: the book's frame and the dialogs' frame at 1024 pixels (were 256), the crest
  medallion at 512, the big moments' banner at 2048, the empty-page sketches at 512 and the minimap logo at 128.
- Fixed: a square gold frame around the fellowship's crest (on the tracker and elsewhere) after the theme changed.
- Overview: a quick look at the top. **Where you stand** shows the chapter's state and its three steps, your level on
  a line from the floor to the cap, your next steps and the counts, now with **over the cap** on its own. The right
  page lists where the Companions stand (below the floor, ready, at the cap, over the cap, away) as on the Chapter
  page. What's next moved to the Chapter page as a list. Below the floor (or over the cap) your line shows the floor
  (or cap) as a tick, so the distance is visible.
- Follow your other characters' fellowships: while you level an alt, Your characters → **Follow this fellowship**
  shows your main's fellowship live and read-only (levels, chapter, clears, History, Companions), with a toast when it
  opens a chapter. The Companions there answer from their own addon; nothing can be changed from the alt.
  `/jtf debug watch` tries it on one character; `/jtf check watch` checks it.
- Following another character's fellowship now has a **Rules** page too: its rules as of the last news, read only,
  with its votes (no Yes or No) and no draft or Propose.
- Play another character, from the alt: while you play it, Your characters → your main → **Take its place**, after a
  question. Any level (below the floor it catches up), same faction only, not while it is in a fellowship of its own.
  A Companion who is online passes it on. Your own card now says how.
- Default emblem: the lion for Alliance characters, the axes for Horde (it was an icon).
- Self-test: a check that Shift-compare works with the game's comparison tooltip.
- Rules are under Fellowship in the sidebar for every Companion, the Captain too, with a line saying what you may do
  there (change at once as Captain, or propose and vote). A Horde character starts with a crimson banner and sees
  the Horde hall on Welcome; the Raids page has its header picture; the tour shows the Alliance theme on any side.
- Tracker: hidden mode is now completely invisible (clicks go through) until you point at it, and shows itself for a
  few seconds when something changes; it can hide in combat and in dungeons. New lines to choose: your XP bar,
  dungeons cleared this chapter, your bosses in the dungeon you are in, shared quests, your next duel, the inbox.
- Sync: a long copy of the fellowship (late in a journey, a minute or more at the game's one message per second) no
  longer gets lost; copies are smaller (newest History only, the rest kept); a newer copy replaces a queued one; two
  copies that drifted apart at the same version are noticed at login and the captain's copy wins.
- Debug: `/jtf debug hero <Name> ...` fakes every reply another Companion's client can send (answers, kills, gear,
  versions, ranks, rules, journey, invites, clears, swaps, and the sync cases clash, gap and snap);
  `/jtf debug sync` and `/jtf debug hold on|off`. docs/E2E-CHECKS.md lists what still needs the real game or a second
  account.
- The Welcome logo is larger and the inside of its R is no longer black; the Horde theme's icons have red discs.
- WoW-style controls from the game's own art (chosen from a gallery of it, seen in game): secondary buttons are the
  game's dark panel button with gold text (red stays the one main action); choices (size, Yes / No, numbers,
  ranks) are the Collections window's list buttons with the gold selection rim; your role is picked with the
  Dungeon Finder's role icons. Each falls back to the old look where the art is missing.
- Full review of the first /jtf check: pages now really start at their top when turned to or opened from a toast
  (the reset never reached the pages' scroll areas); the review step says "everyone at the floor, no levels over
  the cap" instead of "floor -0, cap +0"; the emblem picker is sized to its emblems; a chain's heading has no stray
  dot; "Your next duel: you against Elyra"; "1 more planned" Gatherings; Your characters no longer says "below".
- Testing: `/jtf check` runs every feature's checks and screenshots in one go, or only the screenshots of the areas
  you name (`/jtf check setup`), or only the checks (`quick`). `Dev/Areas.lua` maps every check and screenshot to
  one of 26 feature areas (a unit test keeps it complete); `tools/check-report.lua` prints the report by area and
  writes `review/index.html` with the screenshots grouped by area. The self-test checks the setup guide.
- Setup guide: the first time you are in a fellowship, "Make the book yours" walks through three short steps
  (theme; tracker, banners, chat and sounds; reminders). Every choice changes the book at once, Skip and Use the
  defaults are always there, and Settings can run it again. Banners can now be set to "Only big moments".
- Founding asks how many you will be (Duo, Trio, Party, Large): it sets the run and clear rules that fit, and
  suggests a play style and a journey. It never limits invites: when the fellowship grows past its size, the Captain
  is offered the rules that fit (Use them / Keep mine). The Rules page shows the size too. Play styles now set only
  the slack at the floor and cap.
- Layout fixes from the tour at the wider window: the Welcome page's feature lines fit, the size note no longer
  covers the faction line, the journey tiles in setup end above Back / Next; "0 of 1 boss" on the Raids page.
- UX review fixes: rank buttons say Companion / Steward; "Waiting for you" instead of your own name; the Join page
  no longer mentions asking to join; attunement names are no longer cut off; a character without a fellowship shows
  its class crest; dungeons not cleared yet show a yellow dot instead of a "?"; a page you turn to starts at the
  top; the Dungeon clears table has a key with each dungeon's name.
- Quest chains show quest names instead of numbers (the game is asked for titles it has not loaded yet); a dungeon
  card says "2 of 5 bosses down so far" instead of "Nobody has run it yet" after kills; the Steward invite rule no
  longer mentions requests to join.
- Polish: long help texts (how clears are counted, votes, what Stewards may do) sit behind a "?" by their heading;
  Manage starts with its title; the tournament winner is readable; status colours are brighter in the Night theme;
  the minimap tooltip says what click and drag do; the tracker is wider with a short title ("II · The Wailing and
  the Wolf"); a missing tank or healer shows in red with advice on mouse-over.
- Page sketches: seven journal-style drawings fill the empty lower part of Join, a quest's details, Attunements,
  the tournament bracket, Since you were last here, Gatherings and Companions. They only show when there is room,
  and are softer in the Night theme.
- Full tour review: an invitation no longer sends the Join page back to Welcome; the Welcome invite line opens Join;
  the inbox invitation has Accept / Decline; a Captain alone is told to invite Companions; you are named first in
  waiting lines; "1 Companion" singular; open dungeons and the current chapter in amber; class dots readable on
  parchment; a page opened from outside starts at its top; class variants of a quest count as one chain step;
  attunement names fit the grid; the "chapter unlocked" card on Since you were last here shows; Gatherings and
  Since show their sketch also when empty; the big banners carry the fellowship's crest.
- Welcome: Found a fellowship and Join a fellowship are large picture tiles, like the Adventure Guide.
- Founding is simpler: choose a play style (Relaxed, Together, Strict) instead of every rule, then a journey from
  picture tiles; every rule can still be fine-tuned. The Rules page has the same styles on top.
- The book is wider (1280 instead of 1140) for longer lines and less scrolling; it fits narrow screens.
- Bigger icons in the sidebar.
- The book's frame is only leather and gold now, meeting the window's edge (the parchment strip between them is
  gone).
- The close button is the game's red cross, in the window's top-right corner.
- Pretend Companions (`/jtf debug`) have their own classes, so their class crests differ.
- Questie is the recommended companion addon for quests: the Quests page recommends installing it (you can hide the
  note), and credits it when it is running. Journey Together Forever loads after Questie when both are installed.
- Quest chains from more places: the chains we ship (`Data/QuestChains.lua`, filled by a new harvest command from
  what the addon learned while we played), the game's own quest lines when it has them, and Questie's database when
  the player has Questie installed (read only, for the session). Follow-ups offered right after a hand-in are linked
  too, and a second possible follow-up is kept as a branch instead of replacing the first.
- The emblem picker offers Crests and Heraldry only (the game's icons are gone from it).
- The game-data command also reports whether the game has quest lines for classic quests (docs/QUEST-CHAINS.md).
- Blackrock Depths is one dungeon again. Journey Admin can place a dungeon in more than one chapter, each with the
  bosses that count there; Classic keeps the first half in chapter XII and the rest in XIII. Saved journeys move over
  with their clears.
- The book's frame is the gold and leather of the dialogs and big moments, without the diamond corners.
- A chapter that has not started says it opens after the chapter before it (not "after Chapter I" for all of them).
- The Dungeon Journal is a book icon on the dungeon cards.
- Settings → Tracker: choose its lines, and show them only on mouse-over.
- Companions in 3D: your face on your Companion card and your whole character on your Inspect page, between your gear
  like the character sheet (drag to turn). Another Companion appears in 3D once you have been grouped and near them,
  and stays until you log out; until then their card shows their class crest.
- New names, so the fellowship never reads like a guild: the leader is the **Captain**, officers are **Stewards**,
  and every member is a **Companion** (the Heroes page is now "The Companions"; `/jtf companions` opens it).
  "1 Companion of …" instead of "1 Heroes of …".
- Item tooltips on the Heroes page work like the game's: your own items without a copy of themselves, another
  Hero's compared with what you wear only while Shift is held.
- Schedule a Gathering offers every dungeon of the game and the raids (the journey's next dungeons first), in a list
  that scrolls.
- Gatherings have their own page (under Fellowship): Schedule and the upcoming Gatherings on the left, the chosen one
  on the right with who is coming, maybe, not coming or has not answered. The Overview keeps one line about the next
  Gathering.
- Dungeons are coloured by role on the Chapter page and the Overview: mandatory gold, bridge blue, optional green.
  A chapter also lists the next chapter's bridge dungeons, since they may be run early.
- Attunements and keys: the Scarlet Key (Scarlet Monastery Armory and Cathedral) is in the list, from level 33.
  Keys that drop in a dungeon start at that dungeon's level. The list is sorted by start level, and "none open yet"
  names the first one you can reach, with "What opens when" on the right page: every attunement and key by level.
- `tools/update-game-data.ps1`: one command that rebuilds the boss data from the newest Forever build and reports
  what else changed in the game (new dungeons, pictures, quest and key IDs, attunement levels).
- Our own painted icons: the sidebar, header buttons, toasts, banners, the You card, History and the guides use one
  set of hand-painted icons on blue discs instead of the game's mixed icons. Attunement toasts show a key ring.
- Fixes from the in-game run of 27 Oct 2026:
  - The attunement toast showed an empty box where an arrow was: the game's font has no arrows. It now says
    "The steps are in Quests, under Attunements." Minus signs are plain hyphens for the same reason.
  - The tracker no longer says "The journey is complete" four times: after the journey it says the Endgame is open.
  - On the level track, the name of a Hero far below the floor is no longer cut off at the page's edge.
- The Alliansens Hjältar Forever logo is a crest you can choose (Manage → emblem → Crests). It shows on its own,
  without the coloured shield.
- Release readiness:
  - The book and the tracker redraw once for a burst of news from other Heroes (logins, heartbeats, quest logs)
    instead of once per message. Your own clicks still redraw at once.
  - Smaller download: two unused header pictures removed.
  - Three unused texts removed.
- Map pins for dungeon entrances are not planned: they would need the Adventure Guide's data, which WoW Forever
  does not have.
- The tracker: a small panel on the screen (like the quest tracker) with the chapter, its status, where you stand,
  the next step, who is online and a Gathering in the next day. Drag it by its title, click the title to fold it,
  click a line to open the book there. Settings → Tracker on the screen.
- Pages that guide:
  - The Overview shows What's next right under the chapter's status, above the counts and the level track.
  - A Hero who has just joined gets a welcome card on the Overview: see the chapter, read the rules, find quests to
    do together. It ticks as they open each page.
  - Inspect is a paper doll: each item's icon in a border of its quality, two columns like the character sheet,
    and the item's tooltip on hover.
  - Tournament brackets have lines: each match of a later round sits between the two that lead to it, and the
    winners' path is gold.
  - Full pages: Welcome explains how a journey works over the first chapter's picture; Since you were last here
    shows where the fellowship stands now; History lists the journey's dungeons so far with how many Heroes cleared
    each.
  - Share quest stays visible and says why it cannot be used yet (group up first, or the quest cannot be shared).
- A richer book (design system 2.0):
  - Chosen options are dark leather with gold text; red is kept for the one main action.
  - Sounds: the book opens and closes like the spellbook, pages turn, choices click (Settings → Sounds).
  - Pages fade in with a page turn (not with Reduce effects).
  - Small grey text is at least 12 points and a little darker on parchment.
  - The emblem picker has sections: Crests, Heraldry, Icons.
  - Menu buttons show three gold dots instead of "...".
  - Ready for our own painted icon set (sidebar, header, banners, toasts) once the art is in.
- Fixes from the fifth UI tour:
  - The picture banner sits low on the screen, closes after a minute or when you leave the dungeon, and no longer
    covers the book's header.
  - Quests near your own level show first ("You could join" was empty until Show all).
  - The Raids page keeps the raid you chose.
  - The Dungeon clears table shows each dungeon's picture as its column head instead of a cut-off name.
  - Journey Admin's level ruler shows 15 at its start, and the chapter editor's last line fits.
  - The rules summary says "when every Hero has reached the floor" instead of "at most 0 levels below".
- A clearer interface, from the review of the UI tour:
  - One main red button per card; other buttons are flat parchment, destructive ones red text and they ask first.
  - Choices fill the chosen option; Quests and History have real tabs with counts.
  - Member actions on Manage and clear actions on the Chapter page sit in a "..." menu (the Manage row ran off the
    page).
  - Empty Quests and History pages explain what will appear; dialogs fit their content; hint text is darker and
    wrapped lines have room between them; no page cuts its last line.
  - The level track no longer overlaps names; done chapters fold on the Overview; empty groups fold on the Chapter
    page, where the run rule is said once; the clears table shows open rings; the chronicle merges repeats and
    folds "invited" into "joined"; "1 Tank"; inspect keeps the addon version out of the item level box.
  - Schedule a Gathering: a dropdown for the dungeon and a row of days.
  - From the second tour: flat buttons use the page's darker parchment, and the Chapter page's level line wraps
    instead of being cut off.
- New art:
  - Chapters 1 to 10 have their own illustration, in the page header, on the Overview and behind the big
    "chapter unlocked" banner.
  - Section headers are book headings (dark ink with a thin gold rule) instead of bands, and page titles stand on
    the page with nothing behind them; the bands showed seams and covered text.
  - Dialogs have a leather frame with gold corners.
  - Chapters 11 to 14 have their illustrations too; Horde characters get Horde header art; Forever's own dungeons
    have painted tiles where the game has no picture for them; big moments have a gold and leather frame.
  - Empty pages and sections have small ink sketches.
  - Dungeon cards on the Chapter page open with a large picture: the dungeon's loading screen (Forever's own
    dungeons in Forever only), with its name on it.
  - Gatherings look like rows of the game's Achievements window, with the dungeon's picture in a gold frame.
  - The logo sits on the book's top-left corner like a seal.
  - `tools/convert-art.ps1` converts new art from `art/incoming/` into `Media/`.
- The Endgame: when the journey is complete (or everyone is 60), a Raids page opens with the classic raids: who is
  attuned, boss progress, clears, and Find group for a raid (a party becomes a raid). Raid kills are detected like
  dungeon kills; the boss data now includes the raids.
- Milestones in chapters (Journey Admin → Add a milestone): a quest everyone does, a level, an attunement, or one the
  leader ticks off by hand; Required ones keep the chapter open until done, Optional ones are goals. The Chapter page
  lists them with how far the fellowship is, and Tick off for the leader.
- Quests are about playing together: Together (you and other Heroes are on it) and You could join (others are on it,
  you have not done it and are level for it); your own quests are left to the game's quest log.
  `/jtf debug hero <Name> quests` also gives the pretend Hero a quest you could join.
- Attunements: Naxxramas and the Hydraxian Waterlords (Majordomo) are listed; each attunement shows from the level
  you can start it (or once started), and a toast says when one opens to you.
- Toasts show their whole text: a long one wraps and the banner grows.
- A picture moment after a dungeon's final boss: Take a picture, Without the interface (out of combat), Done. Turn it
  off in Settings → "Picture after a final boss".
- Journey Admin: a chapter can be one level (floor = cap, such as 60-60 at the end); being at that level counts as
  ready. A journey that cannot be published now says so instead of doing nothing.
- Crests are medallions: a bronze rune ring around the banner colour, with one of 16 heraldic emblems (lion, eagle,
  wolf, dragon, stag, boar, swords, axes, hammers, star, crown, tower, oak, sun, moon, flame). The game's icons stay
  available. New fellowships start with the lion.
- Picture crests: a whole picture (such as a guild's logo) can be chosen as the emblem; it shows on its own,
  without the coloured shield, next to the fellowship's name.
- Text typed into name boxes is light on the dark box (it could not be read).
- The Window size slider is gone from Settings; drag the book's corner instead.
- The leader can leave: the fellowship goes to the longest-serving officer, else the Hero who joined first, and goes
  on for everyone else. Disband is gone (a leader who is the only Hero ends it by leaving). Leaving asks first.
- The leader's Undo clear of a dungeon an earlier chapter needs reopens that chapter for everyone, until it is
  cleared again (an officer's undo does not).
- `/jtf tour` (on a character without a fellowship): about 90 screenshots of every screen, state, toast, theme and
  size, as a player would see them, with a list to match them (`tools/tour-manifest.lua`), for UI reviews.
- Completed chapters stay complete: a Hero joining or coming back from away no longer sends the fellowship back to an
  earlier chapter.
- Toasts about yourself say "You reached the floor" (the cap, over the cap). Journey Admin shows the Bosses box on its
  own row.
- `/jtf selftest` (on a character without a fellowship): founds a Selftest fellowship with pretend Heroes, runs
  through every page and feature, takes a screenshot of each page, writes a pass/fail report to the saved data and
  disbands the fellowship again (`/jtf selftest keep` keeps it). `tools/selftest-report.lua` prints the report.
  It covers invites (already a Hero, already invited, cancel, decline, a real offline name), remove and leave,
  ranks, away, rename and banner, Journey Admin (needed bosses, publish, chapters, discard, export and import),
  clears (table cells, undo, mark), the cap and progress toasts, Ask to group up, inbox answers, Show all, History,
  all four tournament formats to a champion and walkovers, and handing over the lead; it notes every toast.
- Errors in the addon's event handlers, and protected actions the game blocks for it, are written to an error log in
  the saved data (and still shown as usual).
- Nobody left behind (SPEC §6, from the review of the build):
  - The Overview starts with a **You** card: your level and standing, your next step, and the Heroes online now with
    Invite to group.
  - A Hero below the floor gets a catch-up plan: how far to the floor, an estimate at their own pace, rested XP, and
    quests others share with them. The Heroes ahead see who is behind and how to help.
  - Help runs: grouping with a Hero below the floor counts as a fellowship run, so helpers may gain XP.
  - Each Hero's addon measures their XP per hour of play and shares it, for the estimates.
  - The level track on the Overview shows every Hero between the floor and the cap.
  - Since you were last here: the first time the book opens in a session, a page with new chapters, what happened
    and who levelled, if anything changed.
  - Inspect has Whisper and Invite to group. Ask to group up can be answered with Join (the asker's addon invites
    you) or Not now, from the inbox. Quests have Invite to group and Share quest.
  - Developer tools: `/jtf debug pace <xp per hour>|off`, `/jtf debug since [mark]`, `/jtf debug hero <Name> ask`.
- Gatherings: any Hero schedules a time to play together (a dungeon, a few words, or both); Heroes answer Yes, Maybe
  or No on the Overview or in the inbox; a reminder 15 minutes before, and the organizer's addon invites those coming
  when it starts. `/jtf debug hero <Name> gather` for testing alone.
- Big moments: a chapter unlocking and the journey being complete get a larger banner with a fanfare.
- Every Hero can read the rules (Rules under Fellowship) and propose changes: each changed rule becomes a vote, and
  it passes as soon as more than half of the Heroes (away Heroes not counted) say Yes, within 3 days. Votes are on
  the Rules page and in the inbox. The leader can still change rules directly. `/jtf debug hero <Name> propose` and
  `vote yes|no` for testing alone.
- Find group invites the online Heroes who still need the dungeon, a tank and a healer first, up to a group of five.
- Needs attention for the leader and officers at the top of Manage, with a count on its bookmark: Heroes below the
  floor or over the cap, not seen for days, away by the rule, open invites, older addon versions, and the takeover
  clock.
- Heroes share their addon version: inspect shows it, and a newer one is mentioned once per session.
- Getting started for the leader of a new fellowship, on the Overview, until done or hidden.
- Quests page tabs: Chains, Quests (this chapter's levels first, Show all for the rest) and Attunements.
- Attunements and keys up to 60: a grid of who has done what (Molten Core, Onyxia, Blackwing Lair, UBRS, Scholomance,
  BRD, Stratholme, Dire Maul), each attunement's steps with who is on which, and Open Attune when the Attune addon is
  installed. Heroes share the listed quests they have done and the keys they carry.
- Dungeon quests: the Chapter page shows how many of each classic dungeon's quests every Hero has picked up.
  Our own list of quest IDs, checked against WoW Forever's quest table (`tools/check-quest-lists.ps1`).

## Milestones M1 to M9
Built first, also part of 0.9.1 beta.

- Repository set up: addon skeleton, docs, mockup and release workflow.
- The book window: leather frame with gold trim, header with logo, sidebar, two parchment pages and page art.
  Opens with `/jtf` or the minimap button, moves, remembers its place; drag the bottom-right corner to resize (80% to 120%).
- Themes: Journal, Night and Faction (Alliance blue or Horde red).
- Settings panel with every setting from the mockup.
- Toasts show at any time, also during combat; Settings → Toast position lets you drag them where you want.
- Commands: `/jtf`, `/jtf chapter`, `/jtf heroes`, `/jtf quests`, `/jtf settings`.
- Found a fellowship in four steps: name, banner colour, emblem and your role; a journey preset (Classic, Short
  chapters, Long chapters, Start from scratch); the rules; a review.
- Invite Heroes, accept or decline invitations, choose the role you join as. The invite box suggests friends, Battle.net friends and guild members while you type.
- Emblems: about 50 heraldic game icons (crowns, banners, weapons, beasts, sun and stars), chosen from a grid.
  Chosen options, colours and presets are marked clearly.
- The book uses the game's look: Friz Quadrata, red panel buttons, input boxes, parchment pages with a calm wash so
  text reads well. Settings use checkboxes, sliders and dropdowns like the game's settings menu.
- Leaving a fellowship brings you back to the Welcome page. New logo, also for the minimap icon.
- Heroes page: every Hero with status (online, "Seen 3 hours ago", to the floor, at or over the cap, away), level
  and XP with rested XP. Levels show at once, XP within a minute.
- Inspect a Hero: gear with item levels and quality colours ("Gear as of …"), XP, this chapter's dungeons, role and
  secondary role, I'm away / I'm back, and Play another character (an alt takes your place, rank and roles).
- Manage: the leader can mark a Hero as away.
- Heroes say hello at login and send a heartbeat; a Hero whose whisper fails shows as offline at once.
- Chapter progress: the current chapter, dungeons open when everyone reaches the floor, a chapter completes when its
  required dungeons are cleared (or, without dungeons, when everyone reaches the cap). The header shows it.
- Overview: the contents of the book (done, current, or yet to be revealed), the chronicle, and any chapter with its
  status banner, counts, dungeons and What's next.
- Chapter page: status banner with its step, over-the-cap warning, the dungeons with who is missing and Find group,
  and where the Heroes stand.
- Journey Admin: chapters (add, remove, rename, floor and cap with a level ruler), dungeons (add, role, remove),
  start over from a preset; changes are a draft until Publish; Export and Import a journey string.
- Manage: officers and members, hand over leadership, remove Heroes, rename, banner and emblem, disband (asks first).
- Leave the fellowship from the Heroes page. The Heroes page shows the banner, numbers, chronicle and every Hero.
- Rules page for the leader: every rule, with a plain-language summary; changes reach every Hero.
- Welcome page and Your characters: every character on the account with its fellowship, as of its last login.
- Inbox shows invitations; the header badge counts them.
- Heroes talk through addon whispers with a throttled queue; nothing is sent inside dungeons and raids; no
  "No player named…" spam when a Hero is offline.
- Developer tools: `/jtf debug invite`, `/jtf debug hero <Name> accept|decline|leave`, `/jtf debug emblems` (count),
  `/jtf debug tourney`, `/jtf debug combat`, `/jtf debug toast`.
- Clears: a Hero clears a dungeon once they were in the group for every needed boss, in one run or over several.
  A kill counts when the dungeon is open and enough Heroes are in the group. The toast shows the moment the last
  needed boss dies; Heroes outside the group hear it once the group leaves the instance.
- Bosses come from the game's own data for WoW Forever (and retail, for testing), built from wago.tools by
  `tools/build-dungeon-data.ps1`, so they are known before the run. Dungeons not in the data yet learn their bosses
  on the kill. Journey Admin chooses which bosses are needed per dungeon (for example one path of Blackrock
  Depths); by default every boss is, except rare spawns and summoned bosses.
- Chapter page: each dungeon with its picture, Dungeon Journal (a shortcut to the DungeonJournal addon, for loot,
  quests and where to pick them up), Mark cleared and Undo clear (leader, or officers if allowed), and the Dungeon
  clears table (click a cell to add or undo one Hero's clear).
- The Adventure Guide's look: the Journal theme uses the guide's book for its pages, page titles sit on the guide's
  header strips, and the Chapter, Quests and Tournament pages use its section headers.
- Quests: Heroes share their quest logs. The Quests page lists your quests and other Heroes' quests (chains first,
  then by zone); the details show your progress, a chain's parts with "You are here", how far the others are,
  what you can do together, and Ask to group up. Chains are learned as Heroes hand in quests. What's next on the
  Overview mentions shared quests and chains. `/jtf debug hero <Name> quests` for testing alone.
- Rules at work: Heroes not seen for the rule's days count as away; the longest-serving officer takes over when the
  leader has been gone for the rule's days; progress toasts (chapter unlocked, everyone at the floor, a Hero at the
  floor, at the cap, over the cap); going over the cap outside a fellowship run (or past what runs allow) is
  written to History; the cap warning shows in chat and the inbox.
- Join page: your invitations and how to join (a leader or officer invites you by name). Joining is by invitation
  only; there are no public listings.
- Languages: translations can be added as Locales files; missing texts stay English.
- Messages wait instead of failing in battlegrounds, arenas, boss encounters and the game's lockdowns, and are sent
  afterwards. A player the game reports offline is not retried.
- Invites work while both players are online: the inviter knows within seconds whether the invite reached the
  player's addon, or why not (offline, no addon, busy in a fight), and the player knows at once whether accepting
  worked. Invites end when the inviter logs out, and after a day at most.
- Guild Master tournament: started by the leader or automatically (new rule), sign-up, seeds by level or random,
  bracket, double elimination, groups then knockout, or round robin; duel winners from the game's duel message,
  best of 3 / 5; walkovers by online time; the Guild Master hands over to the winner with one click. Tournament
  page with the phase, your next duel, entrants and seeds, the schedule and the brackets or tables; inbox items.
- History page: runs ("3 of 6 bosses", cleared, Counted / Did not count), leader changes and chapters unlocked,
  with filters and totals.
- Heroes page: Dungeons cleared, and each Hero's own clears and boss progress in inspect.
- Developer tools: `/jtf debug group <Name>|off` and `/jtf debug kill <dungeon key> [number of bosses]`.
- Tests run outside the game (`lua tests/run_all.lua` or `luajit tests/run_all.lua`) and in the GitHub workflow.
- The addon loads on retail (Interface 120105) and is ready for WoW Forever (16001).
