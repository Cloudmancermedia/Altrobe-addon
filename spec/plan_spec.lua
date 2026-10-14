local env = require("spec.helpers.wow_env")
local dungeonFixture = require("spec.fixtures.dungeon")

local FILES = {
  "Core.lua", "Data/ClassProficiency.lua", "Domain/Evaluator.lua", "Services/Profile.lua",
  "Services/Collection.lua", "Services/InstanceContext.lua", "Services/Lockouts.lua", "Services/Plan.lua",
}

describe("Plan", function()
  local ns, evaluations

  local function encounter(plan, instanceID, encounterID)
    for _, inst in ipairs(plan.instances) do
      if inst.instanceID == instanceID then
        for _, enc in ipairs(inst.encounters) do
          if enc.encounterID == encounterID then return enc end
        end
      end
    end
  end

  before_each(function()
    env.reset()
    _G.AltrobeDB = nil
    ns = env.load(FILES)
    local fixture = dungeonFixture()
    ns.Data = fixture.data
    env.transmog.visualOf = fixture.visualOf
    env.fire(ns, "ADDON_LOADED", "Altrobe")
    evaluations = 0
    local evaluate = ns.Evaluator.Evaluate
    ns.Evaluator.Evaluate = function(input)
      evaluations = evaluations + 1
      return evaluate(input)
    end
  end)

  it("assembles every input from the services", function()
    env.mapID = 1000
    env.transmog.ownedVisuals = { [900] = true }
    env.saved = { { name = "Fixture Keep", locked = true, encounters = { { name = "Second Boss", killed = true } } } }
    ns.Data.sources[5004].collectionRule = "unknown"
    env.items[15004] = { name = "Dagger", quality = 3, bindType = 1, cached = true }

    local plan = ns.Plan.Get()
    assert.are.equal(100, plan.current)
    assert.are.same({}, encounter(plan, 100, 1001).missing)
    assert.is_true(encounter(plan, 100, 1002).killed)
    assert.are.equal("group", encounter(plan, 100, 1002).missing[1].collectionRule)
  end)

  it("asks for item facts of sources whose rule is unknown", function()
    ns.Data.sources[5004].collectionRule = "unknown"
    ns.Data.sources[5005].collectionRule = "unknown"
    ns.Plan.Get()
    table.sort(env.itemRequests)
    assert.are.same({ 15004, 15005 }, env.itemRequests)
  end)

  it("caches the plan until something changes", function()
    ns.Plan.Get()
    ns.Plan.Get()
    assert.are.equal(1, evaluations)
    env.fire(ns, "ZONE_CHANGED_NEW_AREA")
    ns.Plan.Get()
    assert.are.equal(2, evaluations)
  end)

  it("re-evaluates once for a burst of changes", function()
    ns.Plan.Get()
    env.fire(ns, "PLAYER_ENTERING_WORLD")
    env.fire(ns, "UPDATE_INSTANCE_INFO")
    env.fire(ns, "TRANSMOG_COLLECTION_UPDATED")
    env.fire(ns, "ENCOUNTER_END", 1001, "First Boss", 1, 5, 1)
    assert.are.equal(1, #env.timers)
    env.runTimers()
    assert.are.equal(2, evaluations)
    assert.is_true(encounter(ns.Plan.Get(), 100, 1001).killed)
    assert.are.equal(2, evaluations)
  end)

  it("waits for combat to end before re-evaluating", function()
    local before = ns.Plan.Get()
    env.inCombat = true
    env.fire(ns, "ZONE_CHANGED_NEW_AREA")
    env.runTimers()
    assert.are.equal(1, evaluations)
    assert.are.equal(before, ns.Plan.Get())
    assert.is_true(ns.Plan.IsStale())

    env.inCombat = false
    env.fire(ns, "PLAYER_REGEN_ENABLED")
    env.runTimers()
    assert.are.equal(2, evaluations)
    assert.is_false(ns.Plan.IsStale())
  end)

  it("does not evaluate for the first time in combat", function()
    env.inCombat = true
    assert.is_nil(ns.Plan.Get())
    assert.are.equal(0, evaluations)
  end)

  it("tells listeners when a new plan is ready", function()
    local got
    ns.Plan.OnUpdate(function(plan) got = plan end)
    ns.Plan.Invalidate()
    env.runTimers()
    assert.are.equal(ns.Plan.Get(), got)
  end)
end)
