local build = require("tools.build_data")
local emitter = require("tools.emitter")

local ROOT = "spec/pipeline/fixtures/att"

local AVAILABILITY = {
  [2959] = { availability = "live" },
  [760] = { availability = "announced", unlockDate = "2026-12-09" },
  [742] = { availability = "assumed" },
  [78789] = { availability = "announced", unlockDate = "2026-12-09", name = "Hyjal Summit" },
  [741] = { availability = "assumed", fallback = "vanilla" },
}

local function tmpdir()
  local path = os.tmpname()
  os.remove(path)
  assert(os.execute("mkdir -p '" .. path .. "'"))
  return path
end

local function read(path)
  local f = io.open(path, "rb")
  if not f then return nil end
  local text = f:read("*a")
  f:close()
  return text
end

local function run(outDir, availability)
  return build.run({
    attRoot = ROOT,
    outDir = outDir,
    commit = "0000000000000000000000000000000000000000",
    generatedAt = "2026-10-13T00:00:00Z",
    availability = availability or AVAILABILITY,
  })
end

local function loadGenerated(dir)
  local ns = {}
  for _, name in ipairs(build.FILES) do
    assert(loadfile(dir .. "/" .. name))("Altrobe", ns)
  end
  return ns
end

describe("emitter", function()
  it("sorts keys, numbers before strings, and writes arrays in order", function()
    assert.are.equal('{b=1,c={3,1,2},["x-y"]="q"}', emitter.serialize({ c = { 3, 1, 2 }, b = 1, ["x-y"] = "q" }))
    assert.are.equal("{[2]=true,[10]=false,a=1}", emitter.serialize({ a = 1, [10] = false, [2] = true }))
  end)
end)

describe("build_data", function()
  it("writes the generated files the addon loads", function()
    local dir = tmpdir()
    run(dir)
    local data = loadGenerated(dir).Data
    assert.are.equal("ATTWoWAddon/AllTheThings", data.manifest.upstream)
    assert.are.equal("2026-10-13T00:00:00Z", data.manifest.generatedAt)
    assert.are.equal("1.60.1.70338", data.manifest.gameBuild)
    assert.are.equal("vanilla", data.manifest.instanceSources[741])
    assert.are.same({ instances = 5, encounters = 7, sources = 10 }, data.manifest.counts)
    assert.are.equal("boss", data.sources[104].kind)
    assert.are.same({}, data.tokens)
  end)

  it("writes identical bytes for the same input", function()
    local a, b = tmpdir(), tmpdir()
    run(a)
    run(b)
    for _, name in ipairs(build.FILES) do
      assert.are.equal(read(a .. "/" .. name), read(b .. "/" .. name), name)
    end
  end)

  it("fails on invalid data and leaves existing files alone", function()
    local dir = tmpdir()
    local f = assert(io.open(dir .. "/Sources.lua", "w"))
    f:write("-- previous build")
    f:close()

    local bad = {}
    for k, v in pairs(AVAILABILITY) do bad[k] = v end
    bad[2959] = { availability = "soon" }
    local ok, err = pcall(run, dir, bad)
    assert.is_false(ok)
    assert.matches("availability \"soon\"", err)
    assert.are.equal("-- previous build", read(dir .. "/Sources.lua"))
    assert.is_nil(read(dir .. "/Instances.lua"))
  end)

  it("refuses a checkout that is not the pinned commit", function()
    local ok, err = pcall(build.run, {
      attRoot = ROOT, outDir = tmpdir(), commit = "abc", generatedAt = "x", availability = AVAILABILITY,
      requirePinned = true,
    })
    assert.is_false(ok)
    assert.matches("pinned", err)
  end)
end)
