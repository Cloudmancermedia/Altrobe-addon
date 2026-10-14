local validator = require("tools.validator")

local function valid()
  return {
    instances = {
      [1] = { id = 1, name = "A", kind = "dungeon", availability = "live", uiMapIDs = {}, encounters = { 10 } },
    },
    encounters = { [10] = { id = 10, instanceID = 1, journal = true } },
    sources = {
      [100] = {
        id = 100, itemID = 5, instanceID = 1, encounterID = 10, kind = "boss", quality = 3,
        slot = "INVTYPE_CHEST", itemClass = "armor", itemSubType = "SHIELD", collectionRule = "group",
      },
    },
    instanceSources = { [1] = "camelot" },
  }
end

describe("validator", function()
  it("accepts consistent data", function()
    assert.are.same({}, validator.validate(valid()))
  end)

  local function expectError(mutate, pattern)
    local data = valid()
    mutate(data)
    local errors = validator.validate(data)
    assert.is_true(#errors > 0, "expected an error matching " .. pattern)
    assert.matches(pattern, table.concat(errors, "\n"))
  end

  it("rejects a source whose instance is missing", function()
    expectError(function(d) d.sources[100].instanceID = 2 end, "source 100: instance 2 does not exist")
  end)

  it("rejects a source whose encounter is missing", function()
    expectError(function(d) d.sources[100].encounterID = 11 end, "source 100: encounter 11 does not exist")
  end)

  it("rejects a source whose encounter belongs to another instance", function()
    expectError(function(d)
      d.instances[2] = { id = 2, name = "B", kind = "raid", availability = "live", uiMapIDs = {}, encounters = {} }
      d.instanceSources[2] = "camelot"
      d.sources[100].instanceID = 2
    end, "source 100: encounter 10 belongs to instance 1")
  end)

  it("rejects an encounter whose instance is missing", function()
    expectError(function(d) d.encounters[10].instanceID = 3 end, "encounter 10: instance 3 does not exist")
  end)

  it("rejects an instance listing an unknown encounter", function()
    expectError(function(d) d.instances[1].encounters = { 10, 12 } end, "instance 1: encounter 12 does not exist")
  end)

  it("rejects a row stored under the wrong key", function()
    expectError(function(d) d.sources[101] = d.sources[100] end, "source 101: id is 100")
  end)

  it("rejects invalid enum values", function()
    expectError(function(d) d.sources[100].kind = "drop" end, "source 100: kind \"drop\"")
    expectError(function(d) d.sources[100].itemSubType = "SHIELDS" end, "itemSubType \"SHIELDS\"")
    expectError(function(d) d.sources[100].collectionRule = "all" end, "collectionRule \"all\"")
    expectError(function(d) d.sources[100].slot = "CHEST" end, "slot \"CHEST\"")
    expectError(function(d) d.instances[1].availability = "soon" end, "availability \"soon\"")
    expectError(function(d) d.instances[1].kind = "scenario" end, "kind \"scenario\"")
    expectError(function(d) d.instances[1].unlockDate = "Dec 9" end, "unlockDate \"Dec 9\"")
    expectError(function(d) d.instanceSources[1] = "retail" end, "instanceSources%[1%] \"retail\"")
  end)

  it("rejects an encounter without a journal flag", function()
    expectError(function(d) d.encounters[10].journal = nil end, "encounter 10: journal is not a boolean")
  end)

  it("rejects an NPC boss whose key is not its negative NPC ID", function()
    expectError(function(d)
      d.encounters[-7] = { id = -7, instanceID = 1, npcID = 8, journal = false }
    end, "encounter %-7: not keyed by %-npcID")
    expectError(function(d)
      d.encounters[-7] = { id = -7, instanceID = 1, npcID = 7, journal = true }
    end, "encounter %-7: journal encounter with a negative ID")
  end)

  it("rejects a non-string encounter name", function()
    expectError(function(d) d.encounters[10].name = 5 end, "encounter 10: name is not a string")
  end)

  it("rejects a subtype that does not fit the item class", function()
    expectError(function(d) d.sources[100].itemSubType = "DAGGER" end, "itemSubType \"DAGGER\"")
  end)

  it("rejects an instance without provenance", function()
    expectError(function(d) d.instanceSources[1] = nil end, "instance 1: no instanceSources entry")
  end)
end)
