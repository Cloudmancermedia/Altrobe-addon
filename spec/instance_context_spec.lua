local env = require("spec.helpers.wow_env")

describe("InstanceContext", function()
  local ns

  before_each(function()
    env.reset()
    ns = env.load({ "Core.lua", "Services/InstanceContext.lua" })
    ns.Data = { instances = {
      [100] = { id = 100, name = "Fixture Keep", kind = "dungeon", uiMapIDs = { 1000, 1001 } },
      [200] = { id = 200, name = "Fixture Keep Depths", kind = "raid", uiMapIDs = { 2000 } },
      [300] = { id = 300, name = "The Hall of Thanes", kind = "dungeon", uiMapIDs = {} },
      [400] = { id = 400, name = "City of Dalaran", kind = "dungeon" },
    } }
  end)

  describe("Current", function()
    it("matches the player's map to an instance", function()
      env.mapID = 1001
      assert.are.same({ instanceID = 100 }, ns.InstanceContext.Current())
    end)

    it("falls back to the instance name inside an instance", function()
      env.mapID = 5555
      env.instance = { name = "fixture keep depths", type = "raid" }
      assert.are.same({ instanceID = 200 }, ns.InstanceContext.Current())
    end)

    it("finds instances that have no map IDs by name", function()
      env.instance = { name = "The Hall of Thanes", type = "party" }
      assert.are.same({ instanceID = 300 }, ns.InstanceContext.Current())
      env.instance = { name = "City of Dalaran", type = "scenario" }
      assert.are.same({ instanceID = 400 }, ns.InstanceContext.Current())
    end)

    it("is nil in the open world", function()
      env.mapID = 1453
      env.instance = { name = "City of Dalaran", type = "none" }
      assert.is_nil(ns.InstanceContext.Current())
    end)
  end)

  describe("Find", function()
    it("prefers an exact name", function()
      assert.are.same({ 100 }, ns.InstanceContext.Find("fixture keep"))
    end)

    it("matches part of a name, ignoring case and a leading 'the'", function()
      assert.are.same({ 300 }, ns.InstanceContext.Find("hall of thanes"))
      assert.are.same({ 400 }, ns.InstanceContext.Find("dalaran"))
    end)

    it("returns every candidate when the name is ambiguous, by ID", function()
      assert.are.same({ 100, 200 }, ns.InstanceContext.Find("fixture"))
      assert.are.same({}, ns.InstanceContext.Find("nowhere"))
    end)
  end)
end)
