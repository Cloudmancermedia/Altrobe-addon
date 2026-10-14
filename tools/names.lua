-- Boss names from the comments in upstream's hand-written source files.
--
-- The pinned checkout has no creature or journal encounter table for the
-- Forever client (no JournalEncounter or Creature CSV under .contrib/.db/forever/
-- .config/.wago/), and db/*/LocalizationDB.lua holds no NPC names. Upstream's
-- source files do name every node they key, in a trailing comment:
--
--   e(97, {	-- Baron Silverlaine
--   n(3914, {	-- Rethilgore <The Cell Keeper>
--   cr = 16042,	-- Lord Valthalak
--
-- The files are read as text, line by line; nothing in them is run. Subtitles
-- in angle brackets are dropped. SOURCE_DIRS is in order of preference: the
-- first directory that names an ID once wins. A directory that gives one ID
-- two different names leaves it nil, and the ID is listed in `conflicts`.
--
-- Some comments offer alternatives ("Baron Rivendare [Classic] / Lord Aurius
-- Rivendare [CATA+]"). pick() keeps one only when the Forever client agrees:
-- exactly one alternative, without its [tag], must equal a CriteriaTree
-- description whose Criteria kills that NPC (Type 0, Asset = npcID).
-- Otherwise the name stays nil.
local iteminfo = require("tools.iteminfo")

local M = {}

local WAGO = "/.contrib/.db/forever/.config/.wago/"
local KILL_CREATURE = "0"

M.SOURCE_DIRS = {
  "/.contrib/.db/forever/dungeons & raids",
  "/.contrib/.db/standard/01 - Dungeons Raids/01 - Classic",
}

local function clean(name)
  name = name:gsub("%s*<[^>]*>", ""):gsub("^%s+", ""):gsub("%s+$", "")
  if name == "" then return nil end
  return name
end

-- Patterns tried in order; each captures an ID and the comment text.
local PATTERNS = {
  { "encounter", "^%s*e%((%d+),%s*{?%s*%-%-%s*(.-)%s*$" },
  { "npc", "^%s*n%((%d+),%s*{?%s*%-%-%s*(.-)%s*$" },
  { "npc", "^%s*n_[%a_]+%((%d+),%s*{?%s*%-%-%s*(.-)%s*$" },
  { "npc", '^%s*%[?"?cr"?%]?%s*=%s*(%d+),%s*%-%-%s*(.-)%s*$' },
  { "npc", '^%s*%[?"?creatureID"?%]?%s*=%s*(%d+),%s*%-%-%s*(.-)%s*$' },
  { "npc", '{%s*"n",%s*(%d+)%s*},%s*%-%-%s*(.-)%s*$' },
}

-- Returns kind ("encounter" | "npc"), id, name for a line that names one, else nil.
function M.parseLine(line)
  for _, p in ipairs(PATTERNS) do
    local id, name = line:match(p[2])
    if id then
      name = clean(name)
      if name then return p[1], tonumber(id), name end
    end
  end
  return nil
end

local function shellQuote(s)
  return "'" .. s:gsub("'", "'\\''") .. "'"
end

local function listLua(dir)
  local probe = io.open(dir .. "/.", "rb")
  if not probe then error("missing upstream directory " .. dir, 0) end
  probe:close()
  local p = assert(io.popen("ls -1 " .. shellQuote(dir)))
  local files = {}
  for f in p:lines() do
    if f:match("%.lua$") then files[#files + 1] = f end
  end
  p:close()
  table.sort(files)
  return files
end

local function readCSV(path)
  local f = io.open(path, "rb")
  if not f then error("missing upstream table " .. path, 0) end
  local rows, header = {}, nil
  for line in f:lines() do
    line = line:gsub("\r$", "")
    if not header then
      header = iteminfo.parseCSVLine((line:gsub("^\239\187\191", "")))
    elseif line ~= "" then
      local fields, row = iteminfo.parseCSVLine(line), {}
      for k, name in ipairs(header) do row[name] = fields[k] end
      rows[#rows + 1] = row
    end
  end
  f:close()
  return rows
end

-- { [npcID] = { [description] = true } } from the client's kill criteria.
local function loadKillNames(root, build)
  local kills = {}
  for _, row in ipairs(readCSV(root .. WAGO .. "Criteria." .. build .. ".csv")) do
    if row.Type == KILL_CREATURE then kills[row.ID] = tonumber(row.Asset) end
  end
  local out = {}
  for _, row in ipairs(readCSV(root .. WAGO .. "CriteriaTree." .. build .. ".csv")) do
    local npcID = kills[row.CriteriaID]
    if npcID and row.Description_lang and row.Description_lang ~= "" then
      out[npcID] = out[npcID] or {}
      out[npcID][row.Description_lang] = true
    end
  end
  return out
end

-- The name to emit for a raw comment name, or nil. See the header.
function M.pick(loaded, name, npcID)
  if name == nil or not name:find("/", 1, true) then return name end
  local known = npcID and loaded.killNames[npcID]
  if not known then return nil end
  local found
  for part in (name .. "/"):gmatch("([^/]*)/") do
    part = part:gsub("%s*%[[^%]]*%]", ""):gsub("^%s+", ""):gsub("%s+$", "")
    if known[part] then
      if found and found ~= part then return nil end
      found = part
    end
  end
  return found
end

-- Returns { encounter = { [id] = name }, npc = { [id] = name }, conflicts = { "kind id", ... },
-- killNames = { [npcID] = { [name] = true } } }. Names may still hold alternatives; see pick().
function M.load(root, build)
  local out = { encounter = {}, npc = {}, conflicts = {}, killNames = loadKillNames(root, build) }
  local decided = { encounter = {}, npc = {} }
  for _, rel in ipairs(M.SOURCE_DIRS) do
    local dir = root .. rel
    local seen = { encounter = {}, npc = {} }
    for _, f in ipairs(listLua(dir)) do
      for line in io.lines(dir .. "/" .. f) do
        local kind, id, name = M.parseLine(line)
        if kind and not decided[kind][id] then
          local names = seen[kind][id] or {}
          seen[kind][id] = names
          names[name] = true
        end
      end
    end
    for kind, ids in pairs(seen) do
      for id, names in pairs(ids) do
        decided[kind][id] = true
        local only, count = nil, 0
        for name in pairs(names) do only, count = name, count + 1 end
        if count == 1 then
          out[kind][id] = only
        else
          out.conflicts[#out.conflicts + 1] = kind .. " " .. id
        end
      end
    end
  end
  table.sort(out.conflicts)
  return out
end

return M
