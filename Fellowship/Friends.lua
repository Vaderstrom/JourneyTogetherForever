-- People to invite: in-game friends, Battle.net friends playing WoW (this game and faction) and guild members.
-- Used by the invite boxes (Adventurers and Manage pages) to suggest names while typing. Characters on realms that
-- fellowship messages cannot reach (ns.Reachable) are left out.
-- The same lists (and your group) tell the presence marks what the game itself says: online, or AFK (Fr:Status).
local _, ns = ...
local Fr = { FRESH = 5, ASK_EVERY = 60 }
ns.Friends = Fr

-- Every candidate once: { name = "Name-Realm", online = true|false, afk = true|nil, source = "friend"|"bnet"|"guild",
-- tag = the BattleTag of a Battle.net friend ("Arielas#2345") }.
function Fr:All()
  local out, seen = {}, {}
  local me, faction = ns.Me(), (UnitFactionGroup("player"))
  local function add(name, online, source, afk, tag)
    if type(name) ~= "string" or name == "" then return end
    local full = ns.FullName(name)
    if full == me or not ns.Reachable(full) then return end
    afk = online == true and afk == true or nil
    local e = seen[full]
    if e then e.online, e.afk, e.tag = e.online or online == true, e.afk or afk, e.tag or tag; return end
    e = { name = full, online = online == true, afk = afk, source = source, tag = tag }
    seen[full] = e
    out[#out + 1] = e
  end
  if C_FriendList and C_FriendList.GetNumFriends then
    for i = 1, C_FriendList.GetNumFriends() or 0 do
      local info = C_FriendList.GetFriendInfoByIndex(i)
      if info then add(info.name, info.connected, "friend", info.afk) end
    end
  end
  if BNGetNumFriends and C_BattleNet and C_BattleNet.GetFriendNumGameAccounts then
    for i = 1, (BNGetNumFriends()) or 0 do
      local acc = C_BattleNet.GetFriendAccountInfo and C_BattleNet.GetFriendAccountInfo(i)
      local tag = acc and type(acc.battleTag) == "string" and acc.battleTag ~= "" and acc.battleTag or nil
      for j = 1, C_BattleNet.GetFriendNumGameAccounts(i) or 0 do
        local g = C_BattleNet.GetFriendGameAccountInfo(i, j)
        if g and g.clientProgram == (BNET_CLIENT_WOW or "WoW") and g.characterName and g.characterName ~= ""
          and (not g.wowProjectID or not WOW_PROJECT_ID or g.wowProjectID == WOW_PROJECT_ID)
          and (not g.factionName or g.factionName == faction) then
          -- (WoW Forever: the name alone; its names are unique in the region, and a realm would read as a surname.)
          -- (WoW Forever: a ruleset is several realms, so a friend's realm does not say whether they share yours; 1.0.3
          -- left out friends on another realm, wrongly. Their name is taken as on your ruleset.)
          local realm = not ns.IsForever() and g.realmName and (g.realmName:gsub("[%s%-]", "")) or ""
          add(realm ~= "" and (g.characterName .. "-" .. realm) or g.characterName, g.isOnline, "bnet", g.isGameAFK, tag)
        end
      end
    end
  end
  if IsInGuild and IsInGuild() and GetNumGuildMembers then
    for i = 1, GetNumGuildMembers() or 0 do
      -- status: 1 is AFK (2 is busy; "<AFK>" in older clients).
      local name, _, _, _, _, _, _, _, online, status = GetGuildRosterInfo(i)
      add(name, online, "guild", status == 1 or status == "<AFK>")
    end
  end
  return out
end

-- Names (or BattleTags) starting with text (all when empty), online first, at most max. skip(name) leaves a name out.
function Fr:Suggest(text, skip, max)
  local q = strtrim(text or ""):lower()
  local list = {}
  for _, e in ipairs(self:All()) do
    local short = ns.Short(e.name):lower()
    local tag = e.tag and e.tag:lower() or ""
    if (q == "" or short:sub(1, #q) == q or tag:sub(1, #q) == q) and not (skip and skip(e.name)) then list[#list + 1] = e end
  end
  table.sort(list, function(a, b)
    if a.online ~= b.online then return a.online end
    return a.name < b.name
  end)
  while #list > (max or 8) do table.remove(list) end
  return list
end

-- Where a suggestion comes from: "Friend", "Guild", "Battle.net: Arielas#2345".
function Fr:SourceText(e)
  if e.tag then return ns.L.SRC_BNET_TAG:format(e.tag) end
  return ns.L["SRC_" .. e.source:upper()]
end

-- A Battle.net friend's BattleTag ("Arielas#2345", any case) -> the character they play now, in this game and on your
-- faction ("Name-Realm"). Addon messages go to a character, never to an account. nil when none (or several).
function Fr:ByTag(text)
  local q = strtrim(text or ""):lower()
  if not q:find("#", 1, true) then return nil end
  local hit
  for _, e in ipairs(self:All()) do
    if e.tag and e.online and e.tag:lower() == q then
      if hit and hit ~= e.name then return nil end
      hit = e.name
    end
  end
  return hit
end

-- Ask the game for fresh friend and guild lists (they arrive a moment later; the next suggestion uses them).
function Fr:Request()
  if C_FriendList and C_FriendList.ShowFriends then C_FriendList.ShowFriends() end
  if IsInGuild and IsInGuild() and C_GuildInfo and C_GuildInfo.GuildRoster then C_GuildInfo.GuildRoster() end
end

---------------------------------------------------------------------------
-- What the game itself says about a character (the presence marks, SPEC §4.8)
---------------------------------------------------------------------------
local function plain(v) if issecretvalue and issecretvalue(v) then return nil end return v end

-- Your group: the game tells whether each member is connected, and AFK.
local function group(map)
  local n = GetNumGroupMembers and GetNumGroupMembers() or 0
  local raid = IsInRaid and IsInRaid()
  local me = ns.Me()
  for i = 1, raid and n or n - 1 do
    local unit = (raid and "raid" or "party") .. i
    local full = ns.UnitFull(unit)
    if full then
      local online = not UnitIsConnected or plain(UnitIsConnected(unit)) ~= false
      local afk = online and UnitIsAFK and plain(UnitIsAFK(unit)) == true or nil
      local e = map[full]
      if full ~= me then map[full] = { online = online or (e ~= nil and e.online), afk = afk or (e and e.afk) } end
    end
  end
end

-- A typed name as the game has it: a friend, Battle.net friend, guild member or someone in your group of that name, in
-- any case. In WoW Forever a first name alone finds the one of them who has it ("Arielas": Arielas Fireson, in your
-- party). nil when none (or, for a first name, more than one) matches.
function Fr:Resolve(full)
  if not full then return nil end
  local names = {}
  for _, e in ipairs(self:All()) do names[#names + 1] = e.name end
  local map = {}
  group(map)
  for name in pairs(map) do names[#names + 1] = name end
  local want = full:lower()
  for _, name in ipairs(names) do if name:lower() == want then return name end end
  local first = ns.Short(full):lower()
  if not ns.IsForever() or first:find(" ", 1, true) then return nil end
  local hit
  for _, name in ipairs(names) do
    if (ns.Short(name):lower():match("^(%S+) ")) == first then
      if hit and hit ~= name then return nil end
      hit = name
    end
  end
  return hit
end

-- { online = true|false, afk = true|nil } for a character the game lists (friends, Battle.net friends, guild, your
-- group), else nil. Built at most every few seconds (a guild roster can be long). /jtf debug hero <Name> quiet|afk
-- pretends it (Dev/Debug.lua).
function Fr:Status(name)
  local pretend = ns.Dev and ns.Dev.game and ns.Dev.game[name]
  if pretend then return pretend end
  local now = GetTime()
  if not self.map or now - self.mapAt >= self.FRESH then
    local map = {}
    for _, e in ipairs(self:All()) do map[e.name] = { online = e.online, afk = e.afk } end
    group(map)
    self.map, self.mapAt = map, now
    -- Fresh lists now and then (they arrive a moment later; the game throttles the guild roster itself).
    if not self.askedAt or now - self.askedAt >= self.ASK_EVERY then self.askedAt = now; self:Request() end
  end
  return self.map[name]
end

-- The game's lists changed: built again when next asked, and the open book redrawn (once for a burst).
local function changed()
  Fr.map = nil
  if ns.Window then ns.Window:RefreshSoon() end
end
for _, event in ipairs({ "FRIENDLIST_UPDATE", "BN_FRIEND_INFO_CHANGED", "GUILD_ROSTER_UPDATE", "GROUP_ROSTER_UPDATE",
  "PLAYER_FLAGS_CHANGED", "UNIT_CONNECTION" }) do
  ns:RegisterEvent(event, changed)
end
