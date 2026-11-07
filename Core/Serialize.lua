-- Compact serializer for addon messages. Values: nil, booleans, numbers, strings and tables (any depth).
--   n = nil, t/f = true/false, d<number>; = number, s<text>; = string, { key value ... } = table
-- Strings escape "\" ";" "|" and control bytes, so a message never contains "|" (chat escapes) or "\0".
-- Lighter packing (U75, 7 Nov 2026): the same text as before, with far less throwaway data: pieces go straight into
-- one reused buffer, texts that need no escaping are not copied, and each depth keeps its key list.
local _, ns = ...
local S = {}
ns.Serialize = S

local find, gsub, format, char, concat, sort = string.find, string.gsub, string.format, string.char, table.concat, table.sort

local NEED = "[%z\1-\31\\;|]"
local ESC = { ["\\"] = "\\\\", [";"] = "\\s", ["|"] = "\\p" }
for b = 0, 31 do ESC[char(b)] = "\\c" .. char(b + 64) end
local function escape(s)
  if not find(s, NEED) then return s end
  return (gsub(s, NEED, ESC))
end

local PLAIN = { ["\\"] = "\\", s = ";", p = "|" }
local function unescape(s)
  if not find(s, "\\", 1, true) then return s end
  local out, i = {}, 1
  while i <= #s do
    local ch = s:sub(i, i)
    if ch ~= "\\" then out[#out + 1] = ch; i = i + 1
    else
      local a = s:sub(i + 1, i + 1)
      if a == "c" then out[#out + 1] = char(s:byte(i + 2) - 64); i = i + 3
      else out[#out + 1] = PLAIN[a] or a; i = i + 2 end
    end
  end
  return concat(out)
end

local function keyOrder(a, b)
  local ta, tb = type(a), type(b)
  if ta ~= tb then return ta < tb end
  if ta == "number" or ta == "string" then return a < b end
  return tostring(a) < tostring(b)
end

local buf, pool = {}, {}

-- Numbers as text, remembered: writing them was most of the throwaway data (keys, levels and times repeat from one
-- message to the next). Emptied when full. Not 0 (0 and -0 share a key but not a text) or NaN (not a key).
local NUM, numCount, NUM_MAX = {}, 0, 4096
local function num(v)
  local s = NUM[v]
  if s then return s end
  s = format("%.14g", v)
  if v ~= 0 and v == v then
    if numCount >= NUM_MAX then NUM, numCount = {}, 0 end
    NUM[v], numCount = s, numCount + 1
  end
  return s
end

-- Writes v into buf after position n; returns the new last position.
local function encode(v, n, depth)
  local t = type(v)
  if v == nil then n = n + 1; buf[n] = "n"
  elseif t == "boolean" then n = n + 1; buf[n] = v and "t" or "f"
  elseif t == "number" then buf[n + 1], buf[n + 2], buf[n + 3] = "d", num(v), ";"; n = n + 3
  elseif t == "string" then buf[n + 1], buf[n + 2], buf[n + 3] = "s", escape(v), ";"; n = n + 3
  elseif t == "table" then
    n = n + 1; buf[n] = "{"
    local keys = pool[depth]
    if not keys then keys = {}; pool[depth] = keys end
    local c = 0
    for k in pairs(v) do c = c + 1; keys[c] = k end
    local i = c + 1
    while keys[i] ~= nil do keys[i] = nil; i = i + 1 end
    sort(keys, keyOrder)
    for j = 1, c do
      local k = keys[j]
      n = encode(k, n, depth + 1)
      n = encode(v[k], n, depth + 1)
    end
    n = n + 1; buf[n] = "}"
  else
    error("cannot serialize a " .. t)
  end
  return n
end

function S.Encode(v)
  local n = encode(v, 0, 1)
  return concat(buf, "", 1, n)
end

-- Reads one value at position i. Returns value, next position (or nil on bad input).
local function decode(s, i)
  local c = s:sub(i, i)
  if c == "n" then return nil, i + 1
  elseif c == "t" then return true, i + 1
  elseif c == "f" then return false, i + 1
  elseif c == "d" then
    local j = find(s, ";", i, true)
    if not j then return nil, nil end
    local n = tonumber(s:sub(i + 1, j - 1))
    if not n then return nil, nil end
    return n, j + 1
  elseif c == "s" then
    -- The first ";" not escaped, found a jump at a time: escapes are "\" and one byte, a control byte's "\c" and two
    -- (byte 28's last one is itself a "\").
    local j = i + 1
    while true do
      j = find(s, "[\\;]", j)
      if not j then return nil, nil end
      if s:byte(j) == 59 then break end
      j = j + (s:byte(j + 1) == 99 and 3 or 2)
    end
    return unescape(s:sub(i + 1, j - 1)), j + 1
  elseif c == "{" then
    local t = {}
    i = i + 1
    while true do
      if s:sub(i, i) == "}" then return t, i + 1 end
      if i > #s then return nil, nil end
      local k
      k, i = decode(s, i)
      if not i or k == nil then return nil, nil end
      local v
      v, i = decode(s, i)
      if not i then return nil, nil end
      t[k] = v
    end
  end
  return nil, nil
end

-- Returns the value, or nil and false when the text is not valid.
function S.Decode(s)
  if type(s) ~= "string" or s == "" then return nil, false end
  local ok, v, i = pcall(decode, s, 1)
  if not ok or not i or i ~= #s + 1 then return nil, false end
  return v, true
end
