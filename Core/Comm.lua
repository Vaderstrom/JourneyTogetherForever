-- Addon messages between Heroes (docs/ARCHITECTURE.md §2). Whispers only: Heroes can be in different guilds.
-- A message is "TAG:<serialized data>". Long ones are split into "~id:i:n:part" and put together again.
-- Sending goes through a queue and waits while the game does not allow addon messages (Midnight rules): in dungeons,
-- raids, battlegrounds and arenas, during a boss encounter, and whenever the game reports a lockdown. Nothing is
-- dropped for that: it is sent when it is allowed again.
-- Speed (U60, 6 Nov 2026): the game allows each prefix a burst of 10 messages, then 1 a second. With one prefix a
-- whole fellowship copy (16 parts when founded, 40 and more late in the journey) arrived half a minute or more after a
-- join, and every change waited behind it. Now:
--   * three prefixes (lanes: JTF, JTF2, JTF3), each with its own allowance, carry the parts of a long message to an
--     addon that listens on all three (it says so with ln in its first messages; an older addon gets all on JTF);
--   * a limit on all lanes together (bytes, as ChatThrottleLib: too much at once can disconnect the player);
--   * a short message (a change, an answer) goes before the parts of a long one to someone else, and an urgent long
--     message (the copy a new Adventurer waits for) goes first.
-- Closer to real time (the owner, 6 Nov 2026; research by the Guild Together session, its docs/research/
-- sync-at-scale.md):
--   * the 10-then-1-a-second limit is per prefix, but "doesn't apply to whispers outside instanced content" (Warcraft
--     wiki, C_ChatInfo.SendAddonMessage), and the addon only whispers. Outside instances only the byte limit holds a
--     message back; inside a scenario or delve (not held, see Held) the per-prefix limit still counts;
--   * a message is sent on the next frame, not at the next tick;
--   * a long message is packed (the game's deflate, C_EncodingUtil) for an addon that says it reads packed ones (z,
--     beside ln): "#" and the packed bytes, with NUL (which addon messages cannot carry) and the escape byte itself
--     escaped as \1\2 and \1\1 (as Guild Together does). A whole copy is about 4 times smaller: a join takes about a
--     second.
-- Adapted from GuildHall_Core/Sync.lua (queue, chunks, handlers).
local _, ns = ...
local LANES = { "JTF", "JTF2", "JTF3" }
local LANE_OF = {}
for i, p in ipairs(LANES) do LANE_OF[p] = i end
local C = { PREFIX = LANES[1], LANES = #LANES, handlers = {}, queue = {}, buffers = {}, recent = {}, fullName = {},
  seq = 0, peers = {}, packs = {}, lane = {}, waits = {} }
ns.Comm = C
ns.PREFIX = C.PREFIX

local BURST, RATE, MAX, CHUNK = 10, 1, 250, 230
C.BYTES_BURST, C.BYTES_RATE, C.OVERHEAD = 4000, 800, 40
local LOCK_WAIT = 5 -- after a lockdown result, try again this many seconds later
for i = 1, #LANES do C.lane[i] = { tokens = BURST } end
C.bytes = C.BYTES_BURST
-- The first messages to another addon say how many lanes this one listens on (ln).
local HINT = { INV = true, INVA = true, ACC = true, ACCOK = true, HELLO = true, HI = true, STATE = true, SNAPQ = true }

-- Results of SendAddonMessage (Enum.SendAddonMessageResult; 11 and 12 since 11.1 / 12.0).
local RESULT = Enum and Enum.SendAddonMessageResult or {}
local LOCKDOWN = RESULT.AddOnMessageLockdown or 11
local OFFLINE = RESULT.TargetOffline or 12
-- The game's throttle (too many messages): that lane waits a moment and sends it then. (It used up the three tries
-- within three frames and dropped the message, so one part of a long copy could make the whole copy fail.)
local THROTTLED = { [RESULT.AddonMessageThrottle or 3] = true, [RESULT.ChannelThrottle or 8] = true }
local THROTTLE_WAIT = 1.5

local secret = ns.Secret

-- Packing (see the top). C.Z is 1 when this client can pack and unpack.
local EU = C_EncodingUtil
C.Z = (EU and EU.CompressString and EU.DecompressString) and 1 or nil
local function escape(s) return (s:gsub("\1", "\1\1"):gsub("%z", "\1\2")) end
local function unescape(s) return (s:gsub("\1([\1\2])", function(x) return x == "\1" and "\1" or "\0" end)) end
C.Escape, C.Unescape = escape, unescape
function C:Pack(body)
  if not C.Z then return nil end
  local ok, z = pcall(EU.CompressString, body)
  if not ok or type(z) ~= "string" then return nil end
  return "#" .. escape(z)
end
function C:Unpack(msg)
  if not C.Z then return nil end
  local ok, body = pcall(EU.DecompressString, unescape(msg:sub(2)))
  if ok and type(body) == "string" then return body end
  return nil
end

-- Whispers outside instances: the game's per-prefix limit does not apply (only the byte limit does).
function C:Free()
  return not IsInInstance()
end

-- Sends on the next frame (the queue's ticker runs every 0.2 seconds).
function C:Kick()
  if self.kicked then return end
  self.kicked = true
  C_Timer.After(0, function() C.kicked = nil; C:Pump(0) end)
end

function C:On(tag, fn) self.handlers[tag] = fn end

-- Addon messages are not allowed now: wait.
function C:Held()
  if C_ChatInfo and C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown() then return true end
  if self.encounter or (self.lockedUntil and GetTime() < self.lockedUntil) then return true end
  local inside, kind = IsInInstance()
  return inside and (kind == "party" or kind == "raid" or kind == "pvp" or kind == "arena") or false
end

-- Where a short message to target goes: after everything already waiting for target (their order is kept), then
-- before the first part of a long message to someone else.
local function shortPlace(queue, target)
  local at = 1
  for i, item in ipairs(queue) do if item.target == target then at = i + 1 end end
  while queue[at] and not (queue[at].seq and queue[at].target ~= target) do at = at + 1 end
  return at
end

-- urgent: goes first in the queue (messages someone waits for: invites, their answers, a new Adventurer's copy).
-- replace: an older message with this tag to the same player that has not started going out is dropped (a newer
-- whole-fellowship copy makes the queued one useless).
function C:Send(target, tag, data, urgent, replace)
  if not target then return end
  if ns.Dev and ns.Dev:Intercept(target, tag, data) then return end
  if replace then self:DropTag(target, tag) end
  if HINT[tag] and type(data) == "table" then data.ln, data.z = #LANES, C.Z end
  local body = tag .. ":" .. ns.Serialize.Encode(data)
  local now = GetTime()
  -- A long message packed, for an addon that reads packed ones (when packing makes it shorter).
  if #body > MAX and self.packs[target] then
    local packed = self:Pack(body)
    if packed and #packed < #body then
      self.packed, self.saved = (self.packed or 0) + 1, (self.saved or 0) + #body - #packed
      body = packed
    end
  end
  self:Kick()
  if #body <= MAX then
    local item = { target = target, msg = body, tries = 0, tag = tag, at = now, last = true, urgent = urgent or nil }
    table.insert(self.queue, urgent and 1 or shortPlace(self.queue, target), item)
    return
  end
  self.seq = self.seq % 4095 + 1
  local n = math.ceil(#body / CHUNK)
  -- (An urgent long message goes after the urgent ones already waiting: the "yes, you are in" before the copy.)
  local at = 1
  while urgent and self.queue[at] and self.queue[at].urgent do at = at + 1 end
  for i = 1, n do
    local part = ("~%x:%d:%d:"):format(self.seq, i, n) .. body:sub((i - 1) * CHUNK + 1, i * CHUNK)
    local item = { target = target, msg = part, tries = 0, tag = tag, seq = self.seq, part = i, at = now, last = i == n, urgent = urgent or nil }
    if urgent then table.insert(self.queue, at + i - 1, item) else self.queue[#self.queue + 1] = item end
  end
end

-- Drops queued messages with this tag to target, unless their first part has already gone out (the receiver would
-- wait for the rest of a message that never comes).
function C:DropTag(target, tag)
  local started = {}
  for _, item in ipairs(self.queue) do
    if item.target == target and item.tag == tag and item.seq and item.part ~= 1 then started[item.seq] = true end
  end
  for _, item in ipairs(self.queue) do
    if item.target == target and item.tag == tag and item.seq and item.part == 1 then started[item.seq] = nil end
  end
  for i = #self.queue, 1, -1 do
    local item = self.queue[i]
    if item.target == target and item.tag == tag and not (item.seq and started[item.seq]) then table.remove(self.queue, i) end
  end
end

-- Is a message with this tag to target still waiting to go out?
function C:Waiting(target, tag)
  for _, item in ipairs(self.queue) do if item.target == target and item.tag == tag then return true end end
  return false
end

-- How many messages wait, and to whom (for /jtf debug sync).
function C:Pending()
  local by = {}
  for _, item in ipairs(self.queue) do by[item.target] = (by[item.target] or 0) + 1 end
  return #self.queue, by
end

-- The lane for item, or nil when none may send now. A short message keeps to JTF (changes stay in order); the parts
-- of a long one take the fullest lane the receiver listens on.
-- Outside instances (free) a lane needs no allowance; a lane the game throttled waits all the same.
function C:PickLane(item, free)
  local now, best = GetTime(), nil
  local max = item.seq and math.min(#LANES, self.peers[item.target] or 1) or 1
  for i = 1, max do
    local l = self.lane[i]
    if (free or l.tokens >= 1) and not (l.waitUntil and now < l.waitUntil) and (not best or l.tokens > self.lane[best].tokens) then best = i end
  end
  return best
end

function C:Pump(dt)
  for _, l in ipairs(self.lane) do l.tokens = math.min(BURST, l.tokens + dt * RATE) end
  self.bytes = math.min(self.BYTES_BURST, self.bytes + dt * self.BYTES_RATE)
  local free = self:Free()
  while #self.queue > 0 and not self:Held() do
    local item = self.queue[1]
    local cost = #item.msg + self.OVERHEAD
    local lane = self.bytes >= cost and self:PickLane(item, free)
    if not lane then break end
    table.remove(self.queue, 1)
    local now = GetTime()
    self.recent[item.target] = now
    self.recent[ns.Short(item.target)] = now
    self.fullName[ns.Short(item.target)] = item.target
    -- (WoW Forever: to "First Surname", without the realm; Core/Util.lua.)
    local to = ns.WhisperTarget(item.target)
    self.recent[to], self.fullName[to] = now, item.target
    local result = C_ChatInfo.SendAddonMessage(LANES[lane], item.msg, "WHISPER", to)
    local l = self.lane[lane]
    if result == LOCKDOWN then
      -- Not allowed right now: keep it (and everything after it) and try again a little later.
      table.insert(self.queue, 1, item)
      self.lockedUntil = GetTime() + LOCK_WAIT
      break
    elseif THROTTLED[result] then
      -- That lane waits; another may send it.
      table.insert(self.queue, 1, item)
      l.waitUntil, l.tokens = GetTime() + THROTTLE_WAIT, 0
      self.throttled = (self.throttled or 0) + 1
    elseif result == OFFLINE then
      -- The game says the player is offline: no use trying again, or sending the rest of what was for them.
      self:DropFor(item.target)
      ns:Fire("OFFLINE", item.target)
      l.tokens, self.bytes = math.max(0, l.tokens - 1), self.bytes - cost
    else
      local failed = result == false or (type(result) == "number" and result ~= 0)
      if failed and item.tries < 3 then
        item.tries = item.tries + 1
        table.insert(self.queue, 1, item)
        break
      end
      l.tokens, self.bytes = math.max(0, l.tokens - 1), self.bytes - cost
      -- How long the last of each kind waited in the queue (/jtf debug sync).
      if item.last then self.waits[item.tag] = now - item.at end
    end
  end
end

-- Forgets the queued messages to one player.
function C:DropFor(target)
  for i = #self.queue, 1, -1 do if self.queue[i].target == target then table.remove(self.queue, i) end end
end

function C:Receive(prefix, msg, channel, sender)
  -- During a lockdown the game hides incoming text and sender (secret values): such a message cannot be read.
  -- (Invites are sent again until their receipt arrives, see Fellowship/Sync.lua.)
  if secret(prefix) or secret(msg) or secret(sender) then return end
  if not LANE_OF[prefix] or channel ~= "WHISPER" or type(msg) ~= "string" or not sender then return end
  sender = ns.FullName(sender)
  -- A part on another lane: their addon listens on all of them.
  if LANE_OF[prefix] > 1 then self.peers[sender] = math.max(self.peers[sender] or 1, LANE_OF[prefix]) end
  if msg:sub(1, 1) == "~" then
    local id, i, n, part = msg:match("^~(%x+):(%d+):(%d+):(.*)$")
    i, n = tonumber(i), tonumber(n)
    if not id or not i or not n or i < 1 or i > n then return end
    local key = sender .. ":" .. id
    local buf = self.buffers[key]
    -- A message is given up when no part came for a minute. (It was a minute from the first part, but a long
    -- fellowship copy takes longer than that at one part per second, so it never arrived.)
    if not buf or GetTime() - buf.time > 60 or buf.n ~= n then
      -- Parts of messages that stopped coming (the sender logged off) go when a new message starts.
      for k, b in pairs(self.buffers) do if GetTime() - b.time > 60 then self.buffers[k] = nil end end
      buf = { parts = {}, got = 0, n = n }; self.buffers[key] = buf
    end
    buf.time = GetTime()
    if not buf.parts[i] then buf.parts[i] = part; buf.got = buf.got + 1 end
    if buf.got < n then return end
    self.buffers[key] = nil
    msg = table.concat(buf.parts)
  end
  -- Packed (see the top): from an addon that knows this one reads them.
  if msg:sub(1, 1) == "#" then
    msg = self:Unpack(msg)
    if not msg then return end
  end
  local tag, payload = msg:match("^(%u+):(.*)$")
  if not tag then return end
  local data, ok = ns.Serialize.Decode(payload)
  if not ok then return end
  if type(data) == "table" and tonumber(data.ln) then
    self.peers[sender] = math.max(1, math.min(#LANES, math.floor(tonumber(data.ln))))
    self.packs[sender] = tonumber(data.z) == 1 and C.Z == 1 or nil
  end
  local fn = self.handlers[tag]
  if fn then fn(sender, data) end
end

-- /jtf debug: a pretend Hero's message goes through the same path as a real one.
function C:Inject(sender, tag, data)
  self:Receive(self.PREFIX, tag .. ":" .. ns.Serialize.Encode(data), "WHISPER", sender)
end

-- Whispers to Heroes who are offline make the game say "No player named X is currently playing."
-- Hide that line for names the addon whispered in the last 10 seconds, and tell the addon that Hero is offline.
local function hideOffline(_, _, msg)
  local fmt = ERR_CHAT_PLAYER_NOT_FOUND_S
  if not fmt or secret(msg) or type(msg) ~= "string" then return false end
  local now = GetTime()
  for name, t in pairs(C.recent) do
    if now - t < 10 and msg == fmt:format(name) then
      ns:Fire("OFFLINE", C.fullName[name] or ns.FullName(name))
      return true
    end
  end
  return false
end

if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
  for _, p in ipairs(LANES) do C_ChatInfo.RegisterAddonMessagePrefix(p) end
end
local addFilter = ChatFrame_AddMessageEventFilter or (ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter)
if addFilter then addFilter("CHAT_MSG_SYSTEM", hideOffline) end

ns:RegisterEvent("CHAT_MSG_ADDON", function(_, prefix, msg, channel, sender) C:Receive(prefix, msg, channel, sender) end)
-- A boss encounter (also out in the world): addon messages wait until it ends.
ns:RegisterEvent("ENCOUNTER_START", function() C.encounter = true end)
ns:RegisterEvent("ENCOUNTER_END", function() C.encounter = false end)
ns:RegisterEvent("PLAYER_ENTERING_WORLD", function() C.encounter = false end)
ns:On("LOGIN", function() C_Timer.NewTicker(0.2, function() C:Pump(0.2) end) end)
