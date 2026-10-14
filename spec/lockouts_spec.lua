local env = require("spec.helpers.wow_env")

describe("Lockouts", function()
  local ns, invalidated

  before_each(function()
    env.reset()
    ns = env.load({ "Core.lua", "Services/InstanceContext.lua", "Services/Lockouts.lua" })
    ns.Data = {
      instances = {
        [100] = { id = 100, name = "Fixture Keep", encounters = { 1001, 1002, -77 } },
        [200] = { id = 200, name = "The Other Place", encounters = { 2001 } },
      },
      encounters = {
        [1001] = { id = 1001, instanceID = 100, name = "First Boss" },
        [1002] = { id = 1002, instanceID = 100, name = "Second Boss" },
        [-77] = { id = -77, instanceID = 100 },
        [2001] = { id = 2001, instanceID = 200, name = "First Boss" },
      },
    }
    invalidated = 0
    ns.Plan = { Invalidate = function() invalidated = invalidated + 1 end }
  end)

  it("marks bosses killed by matching saved instances and bosses by name", function()
    env.saved = {
      { name = "fixture keep", locked = true, encounters = {
        { name = "First Boss", killed = true }, { name = "Second Boss", killed = false },
        { name = "Nobody We Know", killed = true },
      } },
      { name = "Other Place", locked = true, encounters = { { name = "First Boss", killed = false } } },
    }
    assert.are.same({ [100] = { killed = { [1001] = true } } }, ns.Lockouts.Get())
  end)

  it("ignores expired lockouts and instances it does not know", function()
    env.saved = {
      { name = "Fixture Keep", locked = false, encounters = { { name = "First Boss", killed = true } } },
      { name = "Elsewhere", locked = true, encounters = { { name = "First Boss", killed = true } } },
    }
    assert.are.same({}, ns.Lockouts.Get())
  end)

  it("never matches a boss whose name the data does not have", function()
    env.saved = { { name = "Fixture Keep", locked = true, encounters = { { name = "", killed = true } } } }
    assert.are.same({}, ns.Lockouts.Get())
  end)

  it("marks a boss killed for the session when an encounter ends in success", function()
    env.fire(ns, "ENCOUNTER_END", 1002, "Second Boss", 1, 5, 1)
    env.fire(ns, "ENCOUNTER_END", 1001, "First Boss", 1, 5, 0)
    assert.are.same({ [100] = { killed = { [1002] = true } } }, ns.Lockouts.Get())
    assert.are.equal(2, invalidated)
  end)

  it("matches an encounter it does not know by name in the current instance", function()
    env.mapID = nil
    env.instance = { name = "The Other Place", type = "party" }
    env.fire(ns, "ENCOUNTER_END", 9999, "first boss", 1, 5, 1)
    assert.are.same({ [200] = { killed = { [2001] = true } } }, ns.Lockouts.Get())
  end)

  it("merges session kills with saved lockouts", function()
    env.saved = { { name = "Fixture Keep", locked = true, encounters = { { name = "First Boss", killed = true } } } }
    env.fire(ns, "ENCOUNTER_END", 1002, "Second Boss", 1, 5, 1)
    assert.are.same({ [100] = { killed = { [1001] = true, [1002] = true } } }, ns.Lockouts.Get())
  end)

  it("asks the client for lockouts on entering the world and replans when they arrive", function()
    env.fire(ns, "PLAYER_ENTERING_WORLD")
    assert.are.equal(1, env.raidInfoRequests)
    env.fire(ns, "UPDATE_INSTANCE_INFO")
    assert.are.equal(1, invalidated)
  end)
end)
