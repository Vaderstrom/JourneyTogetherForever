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

local function classicBands()
  local out = {}
  for i, c in ipairs(ns.CLASSIC) do out[i] = { c[2], c[3] } end
  return out
end

ns.PRESET_ORDER = { "classic", "short", "long", "scratch" }
ns.PRESETS = {
  classic = { title = L.PRESET_CLASSIC, text = L.PRESET_CLASSIC_TEXT, bands = classicBands() },
  short = { title = L.PRESET_SHORT, text = L.PRESET_SHORT_TEXT, bands = { { 15, 19 }, { 19, 22 }, { 22, 25 }, { 25, 28 }, { 28, 31 }, { 31, 34 }, { 34, 37 }, { 37, 40 }, { 40, 43 }, { 43, 46 }, { 46, 49 }, { 49, 52 }, { 52, 55 }, { 55, 58 }, { 58, 60 } } },
  long = { title = L.PRESET_LONG, text = L.PRESET_LONG_TEXT, bands = { { 15, 20 }, { 20, 25 }, { 25, 30 }, { 30, 35 }, { 35, 40 }, { 40, 45 }, { 45, 50 }, { 50, 54 }, { 54, 58 }, { 58, 60 } } },
  scratch = { title = L.PRESET_SCRATCH, text = L.PRESET_SCRATCH_TEXT, bands = { { 15, 60 } } },
}

-- Chapters and dungeon places for a preset. Dungeons go to the chapter that matches their best level;
-- outside the Classic preset bridges become mandatory. The presets plan with the catalog's levels and chapters
-- (ns.PLAN_DUNGEONS, Data/Dungeons.lua), so they are the same in every game: in Forever every catalog dungeon is
-- placed, also one the game does not list yet (its chapter finishes on level until it does); on retail the ones its
-- Adventure Guide has, and its own Classic versions (ns.GUIDE_PLAN).
-- Every preset but Start from scratch begins with the Prologue (27 Oct 2026): levels 1-15, no dungeons, done when
-- everyone reaches 15. Each chapter keeps its picture (art: the preset chapter's number, or "prologue"), so the
-- pictures do not move when chapters are added in front.
function ns.BuildJourney(key)
  local P = ns.PRESETS[key] and key or "classic"
  local preset = ns.PRESETS[P]
  local chapters = {}
  local off = P == "scratch" and 0 or 1
  -- (The Prologue in a quiet parchment brown; the chapters keep their colours.)
  if off == 1 then chapters[1] = { name = L.PROLOGUE_NAME, floor = 1, cap = 15, color = "9A8A6A", art = "prologue" } end
  for i, b in ipairs(preset.bands) do
    local name = P == "classic" and ns.CLASSIC[i][1] or (P == "scratch" and L.JOURNEY_NAME or L.CHAPTER_N:format(i + off))
    chapters[i + off] = { name = name, floor = b[1], cap = b[2], color = ns.PALETTE[(i - 1) % #ns.PALETTE + 1], art = i }
  end
  local place = {}
  for _, d in ipairs(ns.PLAN_DUNGEONS or ns.DUNGEONS) do
    local k, min, max, ch, role = d[1], d[3], d[4], d[5], d[6]
    if P ~= "scratch" and ch ~= 0 then
      if P == "classic" and ns.DUNGEON_SPLITS[k] then
        -- One dungeon over several chapters, each with its part of the bosses (Blackrock Depths: XII and XIII).
        for i, part in ipairs(ns.DUNGEON_SPLITS[k]) do
          place[ns.PartKey(k, i)] = { ch = part.ch + off, role = role, bosses = ns.Journey.SplitTokens(k, i) }
        end
      elseif P == "classic" then
        place[k] = { ch = ch + off, role = role }
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
  return { chapters = chapters, place = place }
end
