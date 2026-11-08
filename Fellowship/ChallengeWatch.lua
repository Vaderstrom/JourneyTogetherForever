-- Noticing my own broken rules (SPEC §9, decided with the owner 1 Nov 2026; Fellowship-crafted 8 Nov 2026). Each Adventurer's addon watches only its
-- own character and records what it saw in the fellowship (op "broke", Fellowship/Challenges.lua), so every copy
-- knows. The addon cannot stop anything: it notices, best it can, and marks. Only the first break of each challenge
-- is kept, so each watch stops once its challenge is broken (C:Holds).
-- Lord of the Rings and Race to 60 are watched here too: the first ring that comes into my bags, the Ring leaving
-- them, everyone at the level cap.
-- What the game does not tell an addon (12.0): who another trade window belongs to in an instance, aura values in
-- combat. Those are read outside combat and instances only, and every value is checked with C.plain first.
local _, ns = ...
local F = ns.Fellowship
local C = ns.Challenges
local CW = { RING_WAIT = 2, QUEST_SLACK = 3, TAXI_WAIT = 1, XP_WAIT = 0.5, CRAFT_WAIT = 2 }
ns.ChallengeWatch = CW

local plain = C.plain
local HEARTH = { [8690] = true, [556] = true } -- Hearthstone, Astral Recall
-- Blackrock Mountain: the instances inside it (Blackrock Depths, Blackrock Spire, Molten Core, Blackwing Lair) and the
-- mountain's own maps (the game's map IDs; checked in retail, Forever unknown: docs/ARCHITECTURE.md).
CW.BRM_INSTANCES = { [230] = true, [229] = true, [409] = true, [469] = true }
CW.BRM_MAPS = { [33] = true, [34] = true, [35] = true }
local POTION = { [1] = true, [2] = true, [3] = true } -- consumables: potion, elixir, flask
local WELL_FED_ICON = 136000

local function me() return ns.Self() end
-- The fellowship I am in, when key binds me now (chosen, I am an Adventurer, not Fallen, not broken yet).
local function binding(key)
  local f = F:Current()
  if f and C:Holds(f, me(), key) then return f end
  return nil
end
-- A broken rule: recorded in the fellowship (once per challenge).
local function broke(what, x)
  if not binding(C.WHAT[what]) then return false end
  return F:Do({ k = "broke", what = what, x = type(x) == "string" and x ~= "" and x or nil })
end
CW.Broke = broke

-- In the fellowship (a Friend of the fellowship too): a trade or mail with them is fine.
local function inFellowship(f, name)
  if not C.nameOk(name) then return true end -- (hidden from addons: given the benefit of the doubt)
  local full = ns.FullName(name)
  return full ~= nil and f.members[full] ~= nil
end
CW.InFellowship = inFellowship

---------------------------------------------------------------------------
-- Fellowship-found: no trade or mail with anyone outside the fellowship, no auction house
---------------------------------------------------------------------------
function CW:TradeShow()
  local name, realm = UnitName("NPC")
  if C.nameOk(name) then self.partner = (C.nameOk(realm) and name .. "-" .. realm) or name else self.partner = nil end
end
function CW:TradeDone()
  local f, who = binding("fellowfound"), self.partner
  self.partner = nil
  if f and who and not inFellowship(f, who) then broke("trade", ns.Short(who)) end
end

-- Taking an item or money from mail: the auction house's mail, or a player's (one you can answer) from outside.
function CW:TookMail(index)
  if GetInboxInvoiceInfo then
    local kind = GetInboxInvoiceInfo(index)
    if plain(kind) and kind then
      self.ahMailAt = GetTime() -- (a ring bought there is no Ring, with or without Fellowship-found)
      return broke("ah")
    end
  end
  local f = binding("fellowfound")
  if not f or not GetInboxHeaderInfo then return end
  local _, _, sender, _, _, _, _, _, _, _, _, canReply = GetInboxHeaderInfo(index)
  if canReply and C.nameOk(sender) and not inFellowship(f, sender) then broke("mail", ns.Short(sender)) end
end

-- Sending mail with an item or money to someone outside.
function CW:SentMail(to)
  local f = binding("fellowfound")
  if not f or not C.nameOk(to) or inFellowship(f, to) then return end
  local any = GetSendMailMoney and (tonumber(GetSendMailMoney()) or 0) > 0
  for i = 1, ATTACHMENTS_MAX_SEND or 12 do
    if any then break end
    any = GetSendMailItem and GetSendMailItem(i) ~= nil
  end
  if any then broke("mailto", ns.Short(to)) end
end

function CW:UsedAuctionHouse() broke("ah") end

---------------------------------------------------------------------------
-- White gear only, Pauper
---------------------------------------------------------------------------
-- Green or better in any slot (shirt and tabard aside: Hero.SLOTS has neither).
function CW:CheckGear()
  if not binding("white") or not GetInventoryItemQuality then return end
  for _, s in ipairs(ns.Hero.SLOTS) do
    local q = GetInventoryItemQuality("player", s[2])
    if plain(q) and (tonumber(q) or 0) >= 2 then
      local link = GetInventoryItemLink("player", s[2])
      local _, name = ns.Hero.ParseLink(link)
      return broke("gear", name)
    end
  end
end

---------------------------------------------------------------------------
-- Fellowship-crafted (X7): only gear someone in the fellowship made
---------------------------------------------------------------------------
-- Slots no profession makes: neck, rings, trinkets (shirt, tabard and bags are not in Hero.SLOTS).
CW.CRAFT_FREE = { [2] = true, [11] = true, [12] = true, [13] = true, [14] = true }
local function bare(s) return (s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
local madeBy
-- Who made it, from a tooltip line ("<Made by Brannic>", the game's ITEM_CREATED_BY), or nil.
function CW.MadeBy(text)
  if not plain(text) or type(text) ~= "string" then return nil end
  madeBy = madeBy or bare(ITEM_CREATED_BY or "<Made by %s>"):gsub("[%^%$%(%)%.%[%]%*%+%-%?]", "%%%0"):gsub("%%s", "(.+)")
  local name = bare(text):match(madeBy)
  return name and strtrim(name) ~= "" and strtrim(name) or nil
end
-- The maker in an item's tooltip (C_TooltipInfo's data): the name; nil when no line says; false when the tooltip
-- can't be read (not there, or a value the game hides): nothing is marked then.
function CW.Maker(data)
  if type(data) ~= "table" or type(data.lines) ~= "table" or #data.lines == 0 then return false end
  for _, line in ipairs(data.lines) do
    if not plain(line.leftText) then return false end
    local name = CW.MadeBy(line.leftText)
    if name then return name end
  end
  return nil
end
-- The gear you start with: white or grey, for level 1. nil when the game has not loaded the item yet (can't tell:
-- nothing is marked then; the review of 8 Nov 2026).
function CW.StartGear(link)
  local _, _, q = ns.Hero.ParseLink(link)
  if q > 1 or not (C_Item and C_Item.GetItemInfo) then return false end
  local need = select(5, C_Item.GetItemInfo(link))
  if not plain(need) or tonumber(need) == nil then return nil end
  return tonumber(need) <= 1
end
-- Made in the fellowship (a Friend of it too). In WoW Forever the tooltip may give the first name alone: then any
-- member with that first name.
function CW.CraftedIn(f, name)
  if inFellowship(f, name) then return true end
  if name:find("[%s%-]") then return false end
  for m in pairs(f.members) do
    if ns.Short(m):match("^(%S+)") == name then return true end
  end
  return false
end
-- Tooltips are read outside combat only (after it, when it ends). A piece without a maker is looked at again in a
-- moment before it is marked: the game may still be fetching the maker's name.
function CW:CheckCrafted(again)
  local f = binding("crafted")
  if not f or not (C_TooltipInfo and C_TooltipInfo.GetInventoryItem) then return end
  if InCombatLockdown() then self.craftLater = true return end
  for _, s in ipairs(ns.Hero.SLOTS) do
    local link = not self.CRAFT_FREE[s[2]] and GetInventoryItemLink("player", s[2])
    if link and self.StartGear(link) == false then
      local by = self.Maker(C_TooltipInfo.GetInventoryItem("player", s[2]))
      if by ~= false and not (by and self.CraftedIn(f, by)) then
        if not again then
          C_Timer.After(self.CRAFT_WAIT, function() CW:CheckCrafted(true) end)
          return
        end
        local _, name = ns.Hero.ParseLink(link)
        return broke("craft", name)
      end
    end
  end
end

function CW:CheckGold()
  local f = binding("pauper")
  if not f or not GetMoney then return end
  local money, limit = tonumber(GetMoney()) or 0, (f.challenges.pauper or C.PAUPER_SUGGEST) * 10000
  if money > limit then broke("gold", tostring(math.floor(money / 10000))) end
end

---------------------------------------------------------------------------
-- Walk everywhere: no flight paths, no hearthstone
---------------------------------------------------------------------------
function CW:CheckTaxi()
  if binding("walk") and UnitOnTaxi and UnitOnTaxi("player") then broke("taxi") end
end
function CW:Cast(unit, spell)
  if unit ~= "player" or not plain(spell) then return end
  if HEARTH[spell] then broke("hearth") end
  -- A potion, elixir or flask from my bags or bars just went off (Ironman Fellowship).
  -- (Its own spell only: a potion on cooldown does not go off, and the next spell cast is another one; code review of
  -- 1 Nov 2026.)
  local p = self.potion
  if p and GetTime() - p.at <= 1 and (not p.spell or p.spell == spell) then
    self.potion = nil
    broke("potion", p.name)
  end
end

---------------------------------------------------------------------------
-- Questless, Dungeons only
---------------------------------------------------------------------------
-- Attunements and keys are allowed (Data/QuestLists.lua), and so are a dungeon's own quests under Dungeons only.
local allowed, dungeonQuest
local function lists()
  if allowed then return end
  allowed, dungeonQuest = {}, {}
  for _, a in ipairs(ns.ALL_ATTUNEMENTS or {}) do
    for _, step in ipairs(a.steps or {}) do
      for _, id in ipairs(type(step[1]) == "table" and step[1] or {}) do allowed[id] = true end
    end
  end
  for _, list in pairs(ns.ALL_DUNGEON_QUESTS or {}) do
    for _, q in ipairs(list) do dungeonQuest[q[1]] = true end
  end
end
function CW.QuestAllowed(id) lists(); return allowed[id] == true end
function CW.DungeonQuest(id) lists(); return dungeonQuest[id] == true end

function CW:QuestDone(id, xp)
  id = tonumber(id)
  self.questAt = GetTime()
  if not id then return end
  if self.DungeonQuest(id) then self.allowXP = (self.allowXP or 0) + (tonumber(xp) or 0) end
  if binding("questless") and not self.QuestAllowed(id) then
    local name = C_QuestLog and C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(id)
    broke("quest", plain(name) and name or nil)
  end
end

-- Inside a dungeon (a raid too)?
local function inDungeon()
  local inside, kind = IsInInstance()
  return inside and (kind == "party" or kind == "raid")
end
-- Any dungeon of the journey open: Dungeons only begins (before it, the fellowship levels as it likes).
function CW.DungeonsBegun(f)
  for key in pairs(f.journey.place or {}) do
    if ns.Journey:Open(f, key) then return true end
  end
  return false
end

-- Experience since I last looked; a level-up in between counts the rest of the old level.
function CW:XPGained()
  local xp, max, lvl = tonumber(UnitXP("player")) or 0, tonumber(UnitXPMax("player")) or 0, UnitLevel("player")
  local was = self.xp
  self.xp = { xp = xp, max = max, lvl = lvl }
  if not was then return 0 end
  if lvl == was.lvl then return math.max(0, xp - was.xp) end
  return math.max(0, was.max - was.xp) + xp
end
function CW:CheckXP()
  local gained = self:XPGained()
  local allow = self.allowXP or 0
  self.allowXP = math.max(0, allow - gained)
  local f = binding("dungeons")
  if not f or gained <= allow or inDungeon() or not self.DungeonsBegun(f) then return end
  local zone = GetRealZoneText and GetRealZoneText()
  broke("xp", C.nameOk(zone) and zone or nil)
end

---------------------------------------------------------------------------
-- Ironman Fellowship: no talents, no professions, no potions or food buffs
---------------------------------------------------------------------------
-- Talent points spent (a specialization is fine). Retail's talent trees, or the old points.
function CW.TalentsSpent()
  local CT, T = C_ClassTalents, C_Traits
  if CT and CT.GetActiveConfigID and T and T.GetConfigInfo and T.GetTreeCurrencyInfo then
    local id = CT.GetActiveConfigID()
    local info = id and T.GetConfigInfo(id)
    for _, tree in ipairs(info and info.treeIDs or {}) do
      for _, cur in ipairs(T.GetTreeCurrencyInfo(id, tree, false) or {}) do
        if (tonumber(cur.spent) or 0) > 0 then return true end
      end
    end
    return false
  end
  if UnitCharacterPoints then
    local lvl, free = UnitLevel("player"), tonumber((UnitCharacterPoints("player"))) or 0
    return lvl >= 10 and free < lvl - 9
  end
  return false
end
function CW:CheckTalents()
  if binding("ironman") and self.TalentsSpent() then broke("talent") end
end

function CW:CheckProfessions()
  if not binding("ironman") or not (GetProfessions and GetProfessionInfo) then return end
  for _, i in pairs({ GetProfessions() }) do
    local name = GetProfessionInfo(i)
    if C.nameOk(name) then return broke("prof", name) end
  end
end

-- An item used from my bags or bars: a potion, elixir or flask waits for its cast (Cast above).
function CW:UsedItem(id)
  if not binding("ironman") or not id or not C_Item or not C_Item.GetItemInfoInstant then return end
  local itemID, _, _, _, _, class, sub = C_Item.GetItemInfoInstant(id)
  if itemID and class == 0 and POTION[sub] then
    local spell = C_Item.GetItemSpell and select(2, C_Item.GetItemSpell(itemID))
    self.potion = { at = GetTime(), name = C_Item.GetItemNameByID and C_Item.GetItemNameByID(itemID) or nil,
      spell = plain(spell) and tonumber(spell) or nil }
  end
end

-- Well Fed (the game's own name for it, or its icon): read outside combat only.
local wellFed
function CW:CheckFood()
  if not binding("ironman") or InCombatLockdown() or not (C_UnitAuras and C_UnitAuras.GetAuraDataByIndex) then return end
  wellFed = wellFed or (C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(19705)) or "Well Fed"
  for i = 1, 40 do
    local a = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
    if not a then break end
    if plain(a.name) and plain(a.icon) and (a.name == wellFed or a.icon == WELL_FED_ICON) then return broke("food") end
  end
end

---------------------------------------------------------------------------
-- Lord of the Rings
---------------------------------------------------------------------------
-- The rings I carry (bags and the two ring slots): { [id of that very item] = { id, name } }.
local function ringAt(loc, out)
  if not (ItemLocation and C_Item.DoesItemExist and C_Item.DoesItemExist(loc)) then return end
  local id = C_Item.GetItemID(loc)
  local _, _, _, equip = C_Item.GetItemInfoInstant(id)
  if equip ~= "INVTYPE_FINGER" then return end
  local guid = C_Item.GetItemGUID and C_Item.GetItemGUID(loc)
  out[plain(guid) and guid or ("item:" .. id)] = { id = id, name = C_Item.GetItemNameByID and C_Item.GetItemNameByID(id) }
end
function CW.Rings()
  local out = {}
  if not (ItemLocation and C_Item and C_Container) then return out end
  for bag = 0, (NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4) do
    for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do ringAt(ItemLocation:CreateFromBagAndSlot(bag, slot), out) end
  end
  for _, s in ipairs({ 11, 12 }) do ringAt(ItemLocation:CreateFromEquipmentSlot(s), out) end
  return out
end

-- Inside Blackrock Mountain: where the Ring is destroyed.
function CW.InBlackrock()
  local id = select(8, GetInstanceInfo())
  if plain(id) and CW.BRM_INSTANCES[id] then return true end
  local map = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
  return plain(map) and CW.BRM_MAPS[map] == true
end

-- A ring that came into my bags since I last looked, not from a quest, the auction house or the bank: the Ring, if
-- nobody found one before. As its bearer: the Ring gone from my bags is destroyed inside Blackrock Mountain, or lost.
-- Passed to me (Challenges:PassRing): a ring I wear or carry becomes the Ring, or the next one I get.
-- Only while I may find the Ring or carry it: reading every bag slot at each loot was wasted for everyone else
-- (ponytail audit, 6 Nov 2026).
function CW:CheckRings()
  local f = F:Current()
  local r = f and f.ring
  local finding = f and not r and C:Holds(f, me(), "ring")
  if not finding and not (r and not r.state and r.who == me()) then self.rings = nil return end
  local now, known = self.Rings(), self.rings
  self.rings = now
  if finding then
    if not known then return end -- (the first look only remembers what I carry)
    local t = GetTime()
    local from = (self.questAt and t - self.questAt <= self.QUEST_SLACK) or (self.ahMailAt and t - self.ahMailAt <= self.QUEST_SLACK)
      or self.atAuction or self.atBank
    if not from then
      for guid, x in pairs(now) do
        if not known[guid] then return F:Do({ k = "ring", item = x.name, id = x.id, guid = guid }) end
      end
    end
  elseif r and not r.state and r.who == me() and not r.guid and r.passes then
    local ids = {}
    for guid in pairs(now) do ids[#ids + 1] = guid end
    table.sort(ids)
    local guid = ids[1]
    if guid then return F:Do({ k = "ringclaim", item = now[guid].name, id = now[guid].id, guid = guid }) end
  elseif r and not r.state and r.who == me() and r.guid and not now[r.guid] then
    -- (Moved between bags, or from bag to finger: looked at again in a moment.)
    C_Timer.After(self.RING_WAIT, function()
      local cur = F:Current()
      local ring = cur and cur.ring
      if not ring or ring.state or ring.who ~= me() or CW.Rings()[ring.guid] then return end
      F:Do({ k = "ringend", state = CW.InBlackrock() and "done" or "lost" })
    end)
  end
end

---------------------------------------------------------------------------
-- Race to 60
---------------------------------------------------------------------------
-- Everyone at level 60: every Adventurer, away or not (the Fallen and Friends aside).
function CW:CheckRace()
  local f = F:Current()
  if not f or not C:Has(f, "race") or f.race or not f.members[me()] then return end
  local cap, any = C.RACE_LEVEL, false
  for name in pairs(f.members) do
    if not ns.Journey:Uncounted(f, name) then
      local lvl = name == me() and UnitLevel("player") or ns.Hero:Level(f, name)
      if lvl < cap then return end
      any = true
    end
  end
  if any then F:Do({ k = "raced" }) end
end

---------------------------------------------------------------------------
-- Everything at once (after logging in, joining, a copy)
---------------------------------------------------------------------------
function CW:CheckAll()
  self:CheckGear(); self:CheckCrafted(); self:CheckGold(); self:CheckTaxi(); self:CheckTalents(); self:CheckProfessions(); self:CheckFood()
  self:CheckRace()
end

-- Events (none of this runs in the stubbed tests until they fire it).
local function hook(t, name, fn)
  if type(t) == "string" then t, name, fn = _G, t, name end
  if t and type(t[name]) == "function" then hooksecurefunc(t, name, fn) end
end
ns:On("LOGIN", function()
  CW:XPGained()
  C_Timer.After(10, function() CW.rings = CW.Rings(); CW:CheckAll(); CW:CheckRings() end)
  hook("TakeInboxItem", function(i) CW:TookMail(i) end)
  hook("TakeInboxMoney", function(i) CW:TookMail(i) end)
  hook("AutoLootMailItem", function(i) CW:TookMail(i) end)
  hook("SendMail", function(to) CW:SentMail(to) end)
  local AH = C_AuctionHouse
  for _, name in ipairs({ "PostItem", "PostCommodity", "PlaceBid", "ConfirmCommoditiesPurchase" }) do
    hook(AH, name, function() CW:UsedAuctionHouse() end)
  end
  hook("PostAuction", function() CW:UsedAuctionHouse() end)
  hook("PlaceAuctionBid", function() CW:UsedAuctionHouse() end)
  hook(C_Container, "UseContainerItem", function(bag, slot) CW:UsedItem(C_Container.GetContainerItemID(bag, slot)) end)
  hook("UseAction", function(slot)
    local kind, id = GetActionInfo(slot)
    if kind == "item" then CW:UsedItem(id) end
  end)
  hook("UseItemByName", function(name) CW:UsedItem(name) end)
end)
ns:On("JOINED", function() C_Timer.After(3, function() CW:CheckAll() end) end)
ns:On("HEROES", function() CW:CheckRace() end)
-- The Ring passed to me: a ring I carry becomes it (CW:CheckRings).
ns:On("CHALLENGES", function()
  local f = F:Current()
  local r = f and f.ring
  if r and not r.state and r.passes and not r.guid and r.who == me() and not CW.claimSoon then
    CW.claimSoon = true
    C_Timer.After(1, function() CW.claimSoon = nil; CW:CheckRings() end)
  end
end)
ns:RegisterEvent("TRADE_SHOW", function() CW:TradeShow() end)
ns:RegisterEvent("UI_INFO_MESSAGE", function(_, _, text) if text == ERR_TRADE_COMPLETE then CW:TradeDone() end end)
ns:RegisterEvent("PLAYER_EQUIPMENT_CHANGED", function() CW:CheckGear(); CW:CheckCrafted() end)
ns:RegisterEvent("PLAYER_REGEN_ENABLED", function() if CW.craftLater then CW.craftLater = nil; CW:CheckCrafted() end end)
ns:RegisterEvent("PLAYER_MONEY", function() CW:CheckGold() end)
ns:RegisterEvent("PLAYER_CONTROL_LOST", function() C_Timer.After(CW.TAXI_WAIT, function() CW:CheckTaxi() end) end)
ns:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player", function(_, unit, _, spell) CW:Cast(unit, spell) end)
ns:RegisterEvent("QUEST_TURNED_IN", function(_, id, xp) CW:QuestDone(id, xp) end)
ns:RegisterEvent("PLAYER_XP_UPDATE", function() C_Timer.After(CW.XP_WAIT, function() CW:CheckXP() end) end)
ns:RegisterEvent("PLAYER_LEVEL_UP", function() C_Timer.After(ns.LEVEL_UP.race, function() CW:CheckRace() end) end)
ns:RegisterEvent("TRAIT_CONFIG_UPDATED", function() CW:CheckTalents() end)
ns:RegisterEvent("CHARACTER_POINTS_CHANGED", function() CW:CheckTalents() end)
ns:RegisterEvent("SKILL_LINES_CHANGED", function() CW:CheckProfessions() end)
ns:RegisterUnitEvent("UNIT_AURA", "player", function() CW:CheckFood() end)
ns:RegisterEvent("BAG_UPDATE_DELAYED", function() CW:CheckRings() end)
ns:RegisterEvent("AUCTION_HOUSE_SHOW", function() CW.atAuction = true end)
ns:RegisterEvent("AUCTION_HOUSE_CLOSED", function() CW.atAuction = nil; C_Timer.After(1, function() CW.rings = CW.Rings() end) end)
ns:RegisterEvent("BANKFRAME_OPENED", function() CW.atBank = true end)
ns:RegisterEvent("BANKFRAME_CLOSED", function() CW.atBank = nil; C_Timer.After(1, function() CW.rings = CW.Rings() end) end)
