-- Builds Data/Generated/*.lua from a local All The Things checkout.
-- Usage (from the repo root): luajit tools/build_data.lua /path/to/AllTheThings
--
-- Reads db/Camelot (Forever), db/Vanilla (Classic Era, for instances Camelot
-- lacks), the Forever client tables under .contrib/ and, for boss names, the
-- comments in upstream's source files (tools/names.lua). Upstream files are
-- data: they load in the sandbox in tools/loader.lua and nothing upstream is
-- executed otherwise. Writes nothing unless the data validates.
local scriptDir = (arg and arg[0] or ""):match("^(.*)/tools/[^/]*$")
if scriptDir then package.path = scriptDir .. "/?.lua;" .. package.path end

local loader = require("tools.loader")
local iteminfo = require("tools.iteminfo")
local names = require("tools.names")
local normalizer = require("tools.normalizer")
local validator = require("tools.validator")
local emitter = require("tools.emitter")

local M = {}

M.VERSION = "1.0.0"
M.UPSTREAM = "ATTWoWAddon/AllTheThings"
M.PINNED_COMMIT = "cb48940f5c6681970053a2baf28bbbae4d0bd225"
M.GAME_BUILD = "1.60.1.70338"
M.TIMELINE = 16001 -- 1.60.1 as major*10000 + minor*100 + patch
M.OUT_DIR = "Data/Generated"
-- Load order; Altrobe.toc lists the same files.
M.FILES = { "Manifest.lua", "Instances.lua", "Encounters.lua", "Sources.lua", "Tokens.lua" }

local function shellQuote(s)
  return "'" .. s:gsub("'", "'\\''") .. "'"
end

local function readCommit(root)
  local p = io.popen("git -C " .. shellQuote(root) .. " rev-parse HEAD 2>/dev/null")
  local out = p and p:read("*l")
  if p then p:close() end
  return out
end

local function writeFiles(dir, files)
  for _, f in ipairs(files) do
    local tmp = dir .. "/" .. f.name .. ".tmp"
    local h = assert(io.open(tmp, "wb"))
    h:write(f.text)
    h:close()
  end
  for _, f in ipairs(files) do
    assert(os.rename(dir .. "/" .. f.name .. ".tmp", dir .. "/" .. f.name))
  end
end

-- opts: attRoot, outDir, commit, generatedAt, availability, requirePinned.
-- Returns the normalized data (with .stats). Raises on any failure before
-- touching outDir.
function M.run(opts)
  local root = opts.attRoot
  local commit = opts.commit or readCommit(root)
  if opts.requirePinned and commit ~= M.PINNED_COMMIT then
    error(string.format("checkout is at %s, not the pinned commit %s", tostring(commit), M.PINNED_COMMIT), 0)
  end

  local camelot = loader.loadFile(root .. "/db/Camelot/Categories/Instances.lua")
  local vanilla = loader.loadFile(root .. "/db/Vanilla/Categories/Instances.lua")
  local data = normalizer.normalize({
    camelot = camelot.Instances,
    vanilla = vanilla.Instances,
    items = iteminfo.load(root, M.GAME_BUILD),
    names = names.load(root, M.GAME_BUILD),
    availability = opts.availability or require("tools.availability"),
    timeline = M.TIMELINE,
  })

  local errors = validator.validate(data)
  if #errors > 0 then
    error("validation failed; nothing written:\n  " .. table.concat(errors, "\n  "), 0)
  end

  local function count(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
  end
  local manifest = {
    upstream = M.UPSTREAM,
    commit = commit,
    generatedAt = opts.generatedAt or os.date("!%Y-%m-%dT%H:%M:%SZ"),
    gameBuild = M.GAME_BUILD,
    extractorVersion = M.VERSION,
    counts = { instances = count(data.instances), encounters = count(data.encounters), sources = count(data.sources) },
    instanceSources = data.instanceSources,
  }

  writeFiles(opts.outDir or M.OUT_DIR, {
    { name = "Manifest.lua", text = emitter.assignment("manifest", manifest) },
    { name = "Instances.lua", text = emitter.file("instances", data.instances) },
    { name = "Encounters.lua", text = emitter.file("encounters", data.encounters) },
    { name = "Sources.lua", text = emitter.file("sources", data.sources) },
    { name = "Tokens.lua", text = emitter.file("tokens", {}) },
  })
  return data, manifest
end

local function main(args)
  local root = args[1]
  if not root then
    io.stderr:write("usage: luajit tools/build_data.lua /path/to/AllTheThings\n")
    os.exit(2)
  end
  local ok, data, manifest = pcall(M.run, { attRoot = root, requirePinned = true })
  if not ok then
    io.stderr:write("build_data: ", tostring(data), "\n")
    os.exit(1)
  end
  local s = data.stats
  print(string.format("instances %d, encounters %d, sources %d", manifest.counts.instances,
    manifest.counts.encounters, manifest.counts.sources))
  print(string.format("excluded by timeline %d, outside any instance %d, duplicated sources %d, "
    .. "quality conflicts %d, source/item mismatches vs client %d", s.excludedByTimeline, s.outsideInstance,
    #s.duplicateSources, s.qualityConflict, #s.appearanceMismatch))
  print(string.format("encounters without a name %d", s.unnamedEncounters))
  local ids = {}
  for id in pairs(s.byInstance) do ids[#ids + 1] = id end
  table.sort(ids)
  print("id\tsource\tkind\tavailability\tsources\tnilQuality\tnilSlot\tnilSubType\tname")
  for _, id in ipairs(ids) do
    local i, b = data.instances[id], s.byInstance[id]
    print(table.concat({ id, data.instanceSources[id], i.kind, i.availability, b.sources, b.nilQuality, b.nilSlot,
      b.nilSubType, i.name }, "\t"))
  end
end

if arg and arg[0] and arg[0]:match("build_data%.lua$") then main(arg) end

return M
