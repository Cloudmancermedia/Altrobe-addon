local env = require("spec.helpers.wow_env")
local validator = require("tools.validator")

-- Guards the committed Data/Generated files: they load in TOC order, match the
-- manifest, and still pass the build's validation.
describe("committed generated data", function()
  local data

  setup(function()
    local files = {}
    for line in io.lines("Altrobe.toc") do
      if line:match("^Data\\Generated\\") then files[#files + 1] = (line:gsub("\\", "/")) end
    end
    data = env.load(files).Data
  end)

  local function count(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
  end

  it("matches the manifest counts", function()
    assert.are.same({
      instances = count(data.instances), encounters = count(data.encounters), sources = count(data.sources),
    }, data.manifest.counts)
  end)

  it("passes validation", function()
    assert.are.same({}, validator.validate({
      instances = data.instances, encounters = data.encounters, sources = data.sources,
      instanceSources = data.manifest.instanceSources,
    }))
  end)

  it("comes from the pinned upstream commit", function()
    assert.are.equal(require("tools.build_data").PINNED_COMMIT, data.manifest.commit)
    assert.are.same({}, data.tokens)
  end)
end)
