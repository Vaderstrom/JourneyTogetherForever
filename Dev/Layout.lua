-- The layout check (M25, 29 Oct 2026): /jtf check measures every screen it photographs, so the small things that
-- kept turning up in screenshot reviews are found by the game itself. For every visible text in the book:
--   cut       the game shortened it ("…") because it does not fit
--   overlap   its letters run over another text's letters
--   outside   it sticks out of the box it belongs to (the nearest frame with a background), or out of the book
-- Text inside a scrolling list that is only partly in view is fine (the list fades at its edge). Text under something
-- drawn over it (a window in the book, a side panel, the walkthrough card) is not seen, so it is left out: in the first
-- check most of the "overlaps" were page text under a window.
-- Dev/Tour.lua scans before each screenshot; tools/check-report.lua prints what was found per screenshot.
-- /jtf lab (Checks) scans the page that is open. Developer text, so it lives here and not in Locales.
local _, ns = ...
local LO = { MAX = 12, OVERLAP = 0.3, SLACK = 2 }
ns.Layout = LO

local function shown(r) return r.IsVisible and r:IsVisible() and (r.GetEffectiveAlpha == nil or (r:GetEffectiveAlpha() or 1) > 0.05) end

-- left, bottom, right, top of a region, or nil when the game does not place it.
local function box(r)
  local l, b, w, h = r:GetRect()
  if not l or not w or w <= 0 or not h or h <= 0 then return nil end
  return l, b, l + w, b + h
end

-- Where a text's letters are (its box can be wider than the text): by its justification.
local function letters(fs)
  local l, b, r, t = box(fs)
  if not l then return nil end
  local sw, sh = fs:GetStringWidth() or 0, fs:GetStringHeight() or 0
  if sw <= 0 or sh <= 0 then return nil end
  sw, sh = math.min(sw, r - l), math.min(sh, t - b)
  local jh = fs.GetJustifyH and fs:GetJustifyH() or "CENTER"
  local x = jh == "LEFT" and l or (jh == "RIGHT" and r - sw or (l + r - sw) / 2)
  local jv = fs.GetJustifyV and fs:GetJustifyV() or "MIDDLE"
  local y = jv == "TOP" and t - sh or (jv == "BOTTOM" and b or (b + t - sh) / 2)
  return x, y, x + sw, y + sh
end

-- The nearest ancestor of a kind: a scroll frame (what is outside it is hidden) or a box with a background.
local function ancestor(r, test)
  local p = r:GetParent()
  while p do
    if test(p) then return p end
    p = p:GetParent()
  end
end
local function isScroll(p) return p.GetObjectType and p:GetObjectType() == "ScrollFrame" end
local function hasBox(p) return p.GetBackdrop and p:GetBackdrop() ~= nil end

-- Frames that hide what is under them: marked layoutCover (side panels, the walkthrough card), in the book's dialog
-- frame (its parchment middle: windows in the book, dialogs; their own background is clear), or a solid background.
local function isCover(f)
  if f.layoutCover then return true end
  local p = f.framePieces
  if p and p[22] and p[22]:IsShown() then return true end
  if f.GetBackdrop and f:GetBackdrop() ~= nil and f.GetBackdropColor then
    local _, _, _, a = f:GetBackdropColor()
    return (a or 0) >= 0.9
  end
  return false
end

-- Drawing order: the frame strata, then the frame level.
local STRATA = { BACKGROUND = 1, LOW = 2, MEDIUM = 3, HIGH = 4, DIALOG = 5, FULLSCREEN = 6, FULLSCREEN_DIALOG = 7, TOOLTIP = 8 }
local function order(f)
  return (STRATA[f.GetFrameStrata and f:GetFrameStrata() or "MEDIUM"] or 3) * 100000 + (f.GetFrameLevel and f:GetFrameLevel() or 0)
end

local function isAncestor(a, r)
  local p = r:GetParent()
  while p do
    if p == a then return true end
    p = p:GetParent()
  end
  return false
end

local function name(fs)
  local t = (fs:GetText() or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("\n", " ")
  if #t > 40 then t = t:sub(1, 38) .. ".." end
  return '"' .. t .. '"'
end

local function within(a1, b1, c1, d1, a2, b2, c2, d2, slack)
  return a1 >= a2 - slack and b1 >= b2 - slack and c1 <= c2 + slack and d1 <= d2 + slack
end

-- Every visible text under root: { fs, l, b, r, t } with its letters' place (the part in view of a scroll list).
local function collect(root)
  local out, covers = {}, {}
  local function visit(f)
    if not shown(f) then return end
    if f ~= root and isCover(f) then
      local l, b, r, t = box(f)
      if l then covers[#covers + 1] = { f = f, l = l, b = b, r = r, t = t, order = order(f) } end
    end
    for _, region in ipairs({ f:GetRegions() }) do
      if region.GetObjectType and region:GetObjectType() == "FontString" and shown(region) and (region:GetText() or "") ~= "" then
        local l, b, r, t = letters(region)
        if l then
          local clip = ancestor(region, isScroll)
          local cl, cb, cr, ct
          if clip then cl, cb, cr, ct = box(clip) end
          -- Out of the list's view: not drawn, so nothing to check.
          if not cl or (r > cl and l < cr and t > cb and b < ct) then
            out[#out + 1] = { fs = region, l = l, b = b, r = r, t = t, clip = clip, layer = ancestor(region, isCover) or root }
          end
        end
      end
    end
    for _, child in ipairs({ f:GetChildren() }) do visit(child) end
  end
  visit(root)
  -- Leave out the texts that something drawn later covers (at the middle of their letters).
  local seen = {}
  for _, a in ipairs(out) do
    local mine = order(a.fs:GetParent())
    local x, y = (a.l + a.r) / 2, (a.b + a.t) / 2
    for _, c in ipairs(covers) do
      if c.order > mine and x > c.l and x < c.r and y > c.b and y < c.t and not isAncestor(c.f, a.fs) then a.hidden = true; break end
    end
    if not a.hidden then seen[#seen + 1] = a end
  end
  return seen
end

-- The problems on the screen under root (the book by default): a list of short lines, at most MAX.
function LO:Scan(root)
  root = root or (ns.Window and ns.Window.frame)
  local out, seen = {}, {}
  if not root or not shown(root) or not box(root) then return out end
  local function add(line) if #out < self.MAX and not seen[line] then seen[line] = true; out[#out + 1] = line end end
  local rl, rb, rr, rt = box(root)
  local list = collect(root)
  for i, a in ipairs(list) do
    local fs = a.fs
    if fs.IsTruncated and fs:IsTruncated() then add("cut: " .. name(fs)) end
    if not within(a.l, a.b, a.r, a.t, rl, rb, rr, rt, self.SLACK) then
      add("outside the book: " .. name(fs))
    elseif not a.clip then
      local holder = ancestor(fs, hasBox)
      local hl, hb, hr, ht
      if holder then hl, hb, hr, ht = box(holder) end
      if hl and not within(a.l, a.b, a.r, a.t, hl, hb, hr, ht, self.SLACK) then add("outside its box: " .. name(fs)) end
    end
    -- Only texts on the same surface: where a window or card lies over the page, its text is drawn over the page's
    -- and hides it, even when the page text's middle is outside it (seen in the check of 29 Oct 2026).
    for j = i + 1, #list do
      local c = list[j]
      local w = a.layer == c.layer and (math.min(a.r, c.r) - math.max(a.l, c.l)) or 0
      local h = math.min(a.t, c.t) - math.max(a.b, c.b)
      if w > 1 and h > 1 then
        local small = math.min((a.r - a.l) * (a.t - a.b), (c.r - c.l) * (c.t - c.b))
        if small > 0 and w * h / small >= self.OVERLAP then add("overlap: " .. name(fs) .. " and " .. name(c.fs)) end
      end
    end
  end
  return out
end

-- /jtf lab: the open page, in chat.
function LO:Report()
  local list = self:Scan()
  if #list == 0 then ns:Print("Layout: nothing cut off, overlapping or outside on this page.", true) return list end
  ns:Print(("Layout: %d to look at on this page:"):format(#list), true)
  for _, line in ipairs(list) do ns:Print("  " .. line, true) end
  return list
end
