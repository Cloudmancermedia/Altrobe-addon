local dungeonFixture = require("spec.fixtures.dungeon")

local function load()
  local ns = {}
  assert(loadfile("UI/WindowModel.lua"))("Altrobe", ns)
  return ns.WindowModel
end

local function entry(sourceID, extra)
  local e = { sourceID = sourceID, itemID = sourceID + 10000, classes = { "PRIEST" }, collectionRule = "group",
    unresolved = false, levelLocked = false }
  for k, v in pairs(extra or {}) do e[k] = v end
  return e
end

describe("WindowModel", function()
  local Model, data, plan

  before_each(function()
    Model = load()
    data = dungeonFixture().data
    plan = {
      instances = {
        {
          instanceID = 100, kind = "dungeon", availability = "live", active = true,
          progress = { PRIEST = { owned = 3, total = 8 }, ROGUE = { owned = 1, total = 6 } },
          encounters = {
            { encounterID = 1003, relevant = false, killed = false, missing = {} },
            { encounterID = 1001, relevant = true, killed = true, opportunity = "sure",
              missing = { entry(5001), entry(5003, { unresolved = true }) } },
            { encounterID = 1002, relevant = true, killed = false, opportunity = "roll",
              missing = { entry(5004, { levelLocked = true }) } },
          },
          trash = { missing = { entry(5008) } },
          other = { missing = {} },
          notInClient = 2,
        },
      },
      current = 100,
    }
  end)

  it("titles the window with the instance and per-class progress in profile order", function()
    local view = Model.Build(plan, data, { "ROGUE", "PRIEST" }, 100)
    assert.are.equal("Fixture Keep", view.title)
    assert.is_nil(view.note)
    assert.are.same({
      { classFile = "ROGUE", owned = 1, total = 6 },
      { classFile = "PRIEST", owned = 3, total = 8 },
    }, view.progress)
  end)

  it("lists relevant bosses by their position in the instance, killed ones in place", function()
    local view = Model.Build(plan, data, { "PRIEST" }, 100)
    assert.are.equal(2, #view.bosses)
    local first, second = view.bosses[1], view.bosses[2]
    assert.are.same({ 2, 1001, "First Boss", "sure", true },
      { first.number, first.encounterID, first.name, first.opportunity, first.killed })
    assert.are.same({ 3, 1002, "Second Boss", "roll", false },
      { second.number, second.encounterID, second.name, second.opportunity, second.killed })
  end)

  it("gives each boss its missing items with their flags", function()
    local items = Model.Build(plan, data, { "PRIEST" }, 100).bosses[1].items
    assert.are.same({
      { itemID = 15001, sourceID = 5001, unresolved = false, levelLocked = false, classes = { "PRIEST" } },
      { itemID = 15003, sourceID = 5003, unresolved = true, levelLocked = false, classes = { "PRIEST" } },
    }, items)
  end)

  it("summarises trash, other and items not in the client", function()
    local view = Model.Build(plan, data, { "PRIEST" }, 100)
    assert.are.same({ trash = 1, other = 0, notInClient = 2 },
      { trash = view.trash, other = view.other, notInClient = view.notInClient })
  end)

  it("says which flags appear so the legend shows only those", function()
    local view = Model.Build(plan, data, { "PRIEST" }, 100)
    assert.is_true(view.flags.unresolved)
    assert.is_true(view.flags.levelLocked)
    plan.instances[1].encounters[2].missing = { entry(5001) }
    plan.instances[1].encounters[3].missing = { entry(5004) }
    view = Model.Build(plan, data, { "PRIEST" }, 100)
    assert.is_false(view.flags.unresolved)
    assert.is_false(view.flags.levelLocked)
  end)

  it("notes instances that are announced or not in Forever yet", function()
    data.instances[100].availability = "assumed"
    assert.are.equal("not in Forever yet", Model.Build(plan, data, { "PRIEST" }, 100).note)
    data.instances[100].availability = "announced"
    assert.are.equal("announced", Model.Build(plan, data, { "PRIEST" }, 100).note)
  end)

  it("has an empty boss list when nothing is relevant", function()
    for _, enc in ipairs(plan.instances[1].encounters) do enc.relevant = false end
    assert.are.same({}, Model.Build(plan, data, { "PRIEST" }, 100).bosses)
  end)

  it("returns nil for an instance the plan does not have", function()
    assert.is_nil(Model.Build(plan, data, { "PRIEST" }, 999))
    assert.is_nil(Model.Build(nil, data, { "PRIEST" }, 100))
  end)

  describe("BossName", function()
    it("uses the encounter name, then the NPC ID, then the encounter ID", function()
      data.encounters[-7] = { id = -7, instanceID = 100, npcID = 7 }
      assert.are.equal("First Boss", Model.BossName(data, 1001))
      assert.are.equal("NPC 7", Model.BossName(data, -7))
      assert.are.equal("Boss 4242", Model.BossName(data, 4242))
    end)
  end)
end)
