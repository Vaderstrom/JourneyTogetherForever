-- Journey presets (from the mockup's PRESETS, CLASSIC and buildJourney).
local _, ns = ...
local L = ns.L

-- Classic chapters: name, floor, cap.
ns.CLASSIC = {
  { "Heroes Awaken", 15, 21 }, { "The Wailing and the Wolf", 21, 25 }, { "Chains and Tides", 25, 29 }, { "Of Titans and Wizards", 29, 33 },
  { "Gnomes To The Monastery", 33, 37 }, { "Tides & The Scarlet Crusade", 37, 41 }, { "Into the Riverglades", 41, 45 }, { "Sand and Titans", 45, 48 },
  { "The Crystal Caves", 48, 50 }, { "Isle of Chains", 50, 52 }, { "Echoes of Hakkar", 52, 54 }, { "Into the Mountain", 54, 56 },
  { "Heart of the Mountain", 56, 58 }, { "Trials of the Champions", 58, 60 },
}

ns.PALETTE = { "4D8ECB", "4DC4CB", "4DCB9C", "4DCB66", "69CB4D", "9FCB4D", "CBC14D", "CB8B4D", "CB564D", "CB4D79", "CB4DAF", "B14DCB", "4D54CB", "22C3E6", "E2B857" }

-- Banner colours: label key, hex.
ns.BANNERS = { { "BANNER_BLUE", "2A5BB8" }, { "BANNER_CRIMSON", "A52A1E" }, { "BANNER_FOREST", "2E7A3E" }, { "BANNER_VIOLET", "6A3A9A" },
  { "BANNER_GOLD", "B8860B" }, { "BANNER_IRON", "4A5560" } }

-- The Classic preset (the owner, 6 Nov 2026: "Classic should be the classic dungeons"): Classic's own dungeons in
-- the Forever preset's chapters. A chapter that held only Forever's new dungeons (Into the Riverglades, Isle of
-- Chains) joins the next one, which keeps its name and picture, so its dungeons are still played at their best level.
-- Each entry: the first and last Forever chapter it covers, and a name where the old one no longer fits.
ns.CLASSIC_ONLY = {
  { 1, 1 }, { 2, 2 }, { 3, 3 }, { 4, 4, name = "Thorns of the Razorfen" }, { 5, 5 },
  { 6, 6, name = "The Scarlet Crusade" }, { 7, 8 }, { 9, 9 }, { 10, 11 }, { 12, 12 }, { 13, 13 }, { 14, 14 },
}

local function foreverBands()
  local out = {}
  for i, c in ipairs(ns.CLASSIC) do out[i] = { c[2], c[3] } end
  return out
end

local function classicBands()
  local out = {}
  for i, s in ipairs(ns.CLASSIC_ONLY) do out[i] = { ns.CLASSIC[s[1]][2], ns.CLASSIC[s[2]][3] } end
  return out
end

-- The Forever preset is what Classic was until 6 Nov 2026: every dungeon, Classic's and Forever's new ones.
ns.PRESET_ORDER = { "forever", "classic", "short", "long", "scratch" }
ns.PRESETS = {
  forever = { title = L.PRESET_FOREVER, text = L.PRESET_FOREVER_TEXT, bands = foreverBands() },
  classic = { title = L.PRESET_CLASSIC, text = L.PRESET_CLASSIC_TEXT, bands = classicBands() },
  short = { title = L.PRESET_SHORT, text = L.PRESET_SHORT_TEXT, bands = { { 15, 19 }, { 19, 22 }, { 22, 25 }, { 25, 28 }, { 28, 31 }, { 31, 34 }, { 34, 37 }, { 37, 40 }, { 40, 43 }, { 43, 46 }, { 46, 49 }, { 49, 52 }, { 52, 55 }, { 55, 58 }, { 58, 60 } } },
  long = { title = L.PRESET_LONG, text = L.PRESET_LONG_TEXT, bands = { { 15, 20 }, { 20, 25 }, { 25, 30 }, { 30, 35 }, { 35, 40 }, { 40, 45 }, { 45, 50 }, { 50, 54 }, { 54, 58 }, { 58, 60 } } },
  scratch = { title = L.PRESET_SCRATCH, text = L.PRESET_SCRATCH_TEXT, bands = { { 15, 60 } } },
}

-- Is the dungeon in a preset for this faction's fellowships ("Alliance", "Horde"; anything else: both)? Ragefire
-- Chasm only for the Horde, Hall of Thanes only for the Alliance (ns.DUNGEON_FACTION; the owner, 6 Nov 2026).
function ns.ForFaction(key, faction)
  local only = ns.DUNGEON_FACTION[ns.BaseKey(key)]
  if not only or (faction ~= "Alliance" and faction ~= "Horde") then return true end
  return only == faction
end

-- Chapters and dungeon places for a preset, for a fellowship of a faction (default: this character's). Dungeons go
-- to the chapter that matches their best level; outside the Forever and Classic presets bridges become mandatory. The presets plan with the catalog's levels and chapters
-- (ns.PLAN_DUNGEONS, Data/Dungeons.lua), so they are the same in every game: in Forever the dungeons Blizzard has
-- announced (ns.FOREVER_SCHEDULE; "Build the classic preset only with the dungeons and raids blizzard has announced",
-- the owner, 4 Nov 2026), so a place only in the game's files stays out; on retail the ones its Adventure Guide has,
-- and its own Classic versions (ns.GUIDE_PLAN). A journey keeps a placement the game later drops (its chapter then
-- finishes on level until the place is back).
-- Every preset but Start from scratch begins with the Prologue (27 Oct 2026): levels 1-15, no dungeons, done when
-- everyone reaches 15. Each chapter keeps its picture (art: the preset chapter's number, or "prologue"), so the
-- pictures do not move when chapters are added in front.
function ns.BuildJourney(key, faction)
  local P = ns.PRESETS[key] and key or "forever"
  local preset = ns.PRESETS[P]
  faction = faction or (UnitFactionGroup and UnitFactionGroup("player"))
  local chapters = {}
  local off = P == "scratch" and 0 or 1
  -- Forever and Classic: the catalog's chapters (ns.CLASSIC), Classic's merged as ns.CLASSIC_ONLY says.
  local byChapter = P == "forever" and {} or nil
  if P == "classic" then
    byChapter = {}
    for i, s in ipairs(ns.CLASSIC_ONLY) do for c = s[1], s[2] do byChapter[c] = i end end
  elseif byChapter then
    for i = 1, #ns.CLASSIC do byChapter[i] = i end
  end
  -- (The Prologue in a quiet parchment brown; the chapters keep their colours.)
  if off == 1 then chapters[1] = { name = L.PROLOGUE_NAME, floor = 1, cap = 15, color = "9A8A6A", art = "prologue" } end
  for i, b in ipairs(preset.bands) do
    local name, art, color = P == "scratch" and L.JOURNEY_NAME or L.CHAPTER_N:format(i + off), i, (i - 1) % #ns.PALETTE + 1
    if P == "forever" then name = ns.CLASSIC[i][1] end
    if P == "classic" then
      -- A merged chapter keeps the picture and colour of the chapter whose dungeons it has (the last one).
      local s = ns.CLASSIC_ONLY[i]
      art, color = s[2], s[2]
      name = s.name or ns.CLASSIC[s[2]][1]
    end
    chapters[i + off] = { name = name, floor = b[1], cap = b[2], color = ns.PALETTE[color], art = art }
  end
  local place = {}
  for _, d in ipairs(ns.PLAN_DUNGEONS or ns.DUNGEONS) do
    local k, min, max, ch, role = d[1], d[3], d[4], d[5], d[6]
    local skip = ch == 0 or P == "scratch" or not ns.ForFaction(k, faction) or (P == "classic" and ns.FOREVER_OWN[k])
    if not skip then
      if byChapter and ns.DUNGEON_SPLITS[k] then
        -- One dungeon over several chapters, each with its part of the bosses (Blackrock Depths: XII and XIII).
        for i, part in ipairs(ns.DUNGEON_SPLITS[k]) do
          place[ns.PartKey(k, i)] = { ch = byChapter[part.ch] + off, role = role, bosses = ns.Journey.SplitTokens(k, i) }
        end
      elseif byChapter then
        place[k] = { ch = byChapter[ch] + off, role = role }
      else
        local mid = (min + max) / 2
        local idx = #chapters
        for i = 1 + off, #chapters do
          local c = chapters[i]
          if mid >= c.floor and mid < c.cap then idx = i; break end
        end
        place[k] = { ch = idx, role = role == "b" and "m" or role }
      end
    end
  end
  -- A chapter with dungeons but none mandatory makes them mandatory (Classic's Razorfen Kraul, alone in its chapter).
  if P == "classic" then
    local hasMust = {}
    for _, p in pairs(place) do if p.role == "m" then hasMust[p.ch] = true end end
    for _, p in pairs(place) do if not hasMust[p.ch] then p.role = "m" end end
  end
  return { chapters = chapters, place = place }
end
