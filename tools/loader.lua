-- Loads an All The Things category file (generated Lua) into a plain node tree.
--
-- The file is untrusted data. It runs in an empty environment: no io, os,
-- require, load*, debug or string library. The only thing it can reach is the
-- app table `_`, whose constructors build nodes and whose other fields are an
-- inert placeholder. Precompiled bytecode is refused, and an instruction limit
-- stops a file that never finishes.
--
-- Node shape: { type = "inst"|"e"|"h"|"s"|"i"|"q"|..., id = n, itemID = n (s only),
--               fields = { non-array keys except g }, children = { nodes } }
local M = {}

local INSTRUCTION_LIMIT = 200000000

-- Upstream constructor name -> node type. Unlisted Create* names become their
-- suffix, e.g. CreateMount -> "Mount".
local TYPES = {
  CreateInstance = "inst",
  CreateEncounter = "e",
  CreateCustomHeader = "h",
  CreateHeader = "ah",
  CreateItemSource = "s",
  CreateItem = "i",
  CreateQuest = "q",
  CreateNPC = "n",
  CreateObject = "o",
  CreateCharacterClass = "cl",
  CreateExpansion = "x",
  CreateFilter = "flt",
  CreateAchievement = "ach",
  CreateAchievementCriteria = "crit",
  CreateQuestObjective = "qo",
  CreateFaction = "faction",
  CreateProfession = "prof",
  CreateRecipe = "r",
}

-- An inert value for every app field that is not a constructor: any index or
-- call returns itself.
local placeholder = setmetatable({}, {})
getmetatable(placeholder).__index = function() return placeholder end
getmetatable(placeholder).__call = function() return placeholder end

local function splitTable(t)
  local fields, children = {}, {}
  if type(t) ~= "table" then return fields, children end
  for k, v in pairs(t) do
    if type(k) ~= "number" and k ~= "g" then fields[k] = v end
  end
  if type(t.g) == "table" then
    for _, child in ipairs(t.g) do children[#children + 1] = child end
  else
    for _, child in ipairs(t) do children[#children + 1] = child end
  end
  return fields, children
end

local function constructor(nodeType)
  if nodeType == "s" then
    return function(sourceID, itemID, t)
      local fields, children = splitTable(t)
      return { type = "s", id = sourceID, itemID = itemID, fields = fields, children = children }
    end
  end
  return function(id, t)
    if type(id) == "table" and t == nil then id, t = nil, id end
    local fields, children = splitTable(t)
    return { type = nodeType, id = id, fields = fields, children = children }
  end
end

local function newApp(handlers)
  local app = {}
  app.AddEventHandler = function(event, fn)
    handlers[#handlers + 1] = { event = event, fn = fn }
  end
  return setmetatable(app, {
    __index = function(_, key)
      if type(key) == "string" and key:match("^Create") then
        return constructor(TYPES[key] or key:sub(7))
      end
      return placeholder
    end,
  })
end

local function withLimit(fn, ...)
  local jitOn = jit and jit.status and jit.status()
  if jit then jit.off() end
  debug.sethook(function() error("instruction limit exceeded", 2) end, "", INSTRUCTION_LIMIT)
  local results = { pcall(fn, ...) }
  debug.sethook()
  if jit and jitOn then jit.on() end
  if not results[1] then error(results[2], 0) end
  return unpack(results, 2)
end

-- Loads source text and returns the categories table the file fills.
function M.loadString(text, chunkName)
  if text:byte(1) == 27 then error(chunkName .. ": refusing precompiled bytecode", 0) end
  local chunk, err = loadstring(text, "=" .. chunkName)
  if not chunk then error(err, 0) end
  setfenv(chunk, {})

  local handlers = {}
  local categories = {}
  withLimit(function()
    chunk("AllTheThings", newApp(handlers))
    for _, h in ipairs(handlers) do
      if h.event == "OnBuildDataCache" then h.fn(categories) end
    end
  end)
  return categories
end

function M.loadFile(path)
  local f = assert(io.open(path, "rb"))
  local text = f:read("*a")
  f:close()
  -- Strip a UTF-8 byte order mark.
  if text:sub(1, 3) == "\239\187\191" then text = text:sub(4) end
  return M.loadString(text, path)
end

return M
