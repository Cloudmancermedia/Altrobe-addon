local env = require("spec.helpers.wow_env")
local dungeonFixture = require("spec.fixtures.dungeon")
local raidFixture = require("spec.fixtures.raid")

describe("Evaluator", function()
  local ns, data, visualOf

  -- Merges fresh copies of both fixtures into one ns.Data-shaped table.
  local function loadFixtures()
    data = { instances = {}, encounters = {}, sources = {} }
    visualOf = {}
    for _, build in ipairs({ dungeonFixture, raidFixture }) do
      local f = build()
      for _, key in ipairs({ "instances", "encounters", "sources" }) do
        for id, row in pairs(f.data[key]) do data[key][id] = row end
      end
      for id, visual in pairs(f.visualOf) do visualOf[id] = visual end
    end
  end

  before_each(function()
    env.reset()
    ns = env.load({ "Data/ClassProficiency.lua", "Domain/Evaluator.lua" })
    loadFixtures()
  end)

  local function evaluate(opts)
    opts = opts or {}
    local profile = {
      classes = opts.classes or { "PRIEST" },
      instanceKinds = opts.instanceKinds or { dungeon = true, raid = true },
      instances = opts.instances,
      slots = opts.slots,
      ownership = opts.ownership or "appearance",
    }
    return ns.Evaluator.Evaluate({
      data = data,
      proficiency = ns.Proficiency,
      profile = profile,
      collection = {
        visualOf = visualOf,
        ownedVisuals = opts.ownedVisuals or {},
        ownedSources = opts.ownedSources or {},
      },
      character = opts.character or { classFile = "PRIEST", level = 60, faction = "Horde" },
      itemFacts = opts.itemFacts,
      absentItems = opts.absentItems,
      instanceContext = opts.instanceContext,
      lockouts = opts.lockouts or {},
    })
  end

  local function instance(out, id)
    for _, inst in ipairs(out.instances) do
      if inst.instanceID == id then return inst end
    end
  end

  local function encounter(out, instanceID, encounterID)
    for _, enc in ipairs(instance(out, instanceID).encounters) do
      if enc.encounterID == encounterID then return enc end
    end
  end

  local function ids(missing)
    local list = {}
    for _, entry in ipairs(missing) do list[#list + 1] = entry.sourceID end
    return list
  end

  local function entry(missing, sourceID)
    for _, e in ipairs(missing) do
      if e.sourceID == sourceID then return e end
    end
  end

  describe("ownership", function()
    it("lets an owned visual suppress a redundant uncollected source", function()
      local out = evaluate({ ownedVisuals = { [900] = true }, ownedSources = { [5002] = true } })
      assert.are.same({}, ids(encounter(out, 100, 1001).missing))
      assert.are.same({ 5004 }, ids(encounter(out, 100, 1002).missing))
    end)

    it("tracks the exact source in exact mode without changing the appearance answer", function()
      local opts = { ownedVisuals = { [900] = true }, ownedSources = { [5002] = true } }
      local appearance = evaluate(opts)
      opts.ownership = "exact"
      local exact = evaluate(opts)

      assert.are.same({ 5001 }, ids(encounter(exact, 100, 1001).missing))
      assert.are.same({}, ids(encounter(appearance, 100, 1001).missing))
      assert.are.same({ owned = 1, total = 6 }, instance(exact, 100).progress.PRIEST)
      assert.are.same({ owned = 1, total = 5 }, instance(appearance, 100).progress.PRIEST)
    end)
  end)

  describe("multiple classes", function()
    it("lists each missing source once with the classes it is eligible for", function()
      local out = evaluate({ classes = { "PRIEST", "ROGUE" } })
      assert.are.same({
        sourceID = 5004, itemID = 15004, classes = { "PRIEST", "ROGUE" },
        collectionRule = "group", unresolved = false, levelLocked = false,
      }, entry(encounter(out, 100, 1002).missing, 5004))
      assert.are.same({ "ROGUE" }, entry(encounter(out, 100, 1001).missing, 5003).classes)
      assert.are.same({ "PRIEST" }, entry(encounter(out, 100, 1001).missing, 5001).classes)
    end)

    it("keeps each class's progress independent of the other selected classes", function()
      local owned = { [900] = true, [902] = true }
      local priestOnly = evaluate({ classes = { "PRIEST" }, ownedVisuals = owned })
      local both = evaluate({ classes = { "PRIEST", "ROGUE" }, ownedVisuals = owned })
      assert.are.same(instance(priestOnly, 100).progress.PRIEST, instance(both, 100).progress.PRIEST)
      assert.are.same({ owned = 2, total = 5 }, instance(both, 100).progress.PRIEST)
      assert.are.same({ owned = 1, total = 3 }, instance(both, 100).progress.ROGUE)
      assert.is_nil(instance(priestOnly, 100).progress.ROGUE)
    end)
  end)

  describe("eligibility", function()
    it("follows the class's armor type", function()
      local out = evaluate({ classes = { "PRIEST", "ROGUE" } })
      assert.is_nil(entry(encounter(out, 100, 1003).missing, 5005))
      out = evaluate({ classes = { "WARRIOR" } })
      assert.are.same({ "WARRIOR" }, entry(encounter(out, 100, 1003).missing, 5005).classes)
    end)

    it("honours the item's own class restriction", function()
      local out = evaluate({ classes = { "PRIEST", "ROGUE" } })
      assert.are.same({ "PRIEST" }, entry(encounter(out, 100, 1003).missing, 5006).classes)
    end)

    it("drops items for the other faction", function()
      local horde = evaluate({ classes = { "ROGUE" } })
      assert.is_nil(entry(encounter(horde, 100, 1003).missing, 5007))
      local alliance = evaluate({
        classes = { "ROGUE" }, character = { classFile = "ROGUE", level = 60, faction = "Alliance" },
      })
      assert.is_not_nil(entry(encounter(alliance, 100, 1003).missing, 5007))
    end)
  end)

  describe("encounters", function()
    it("calls a dungeon group drop sure and a raid drop a roll", function()
      local out = evaluate()
      assert.are.equal("sure", encounter(out, 100, 1001).opportunity)
      assert.are.equal("roll", encounter(out, 200, 2001).opportunity)
    end)

    it("calls a boss unknown when only unknown-rule sources are missing", function()
      data.sources[5001].collectionRule = "unknown"
      local out = evaluate()
      assert.are.equal("unknown", encounter(out, 100, 1001).opportunity)
    end)

    it("gives no opportunity and no relevance when nothing is missing", function()
      local out = evaluate({ ownedVisuals = { [950] = true } })
      local enc = encounter(out, 200, 2001)
      assert.is_false(enc.relevant)
      assert.is_nil(enc.opportunity)
    end)

    it("keeps a killed boss relevant while it still has missing drops", function()
      local out = evaluate({ classes = { "ROGUE" }, lockouts = { [100] = { killed = { [1001] = true } } } })
      local killed = encounter(out, 100, 1001)
      assert.is_true(killed.killed)
      assert.is_true(killed.relevant)
      local other = encounter(out, 100, 1003)
      assert.is_false(other.killed)
      assert.is_false(other.relevant)
    end)

    it("lists encounters in the instance's order and missing entries by source ID", function()
      local out = evaluate({ classes = { "PRIEST", "ROGUE" } })
      local order = {}
      for _, enc in ipairs(instance(out, 100).encounters) do order[#order + 1] = enc.encounterID end
      assert.are.same({ 1003, 1001, 1002 }, order)
      assert.are.same({ 5001, 5003 }, ids(encounter(out, 100, 1001).missing))
      local instanceOrder = {}
      for _, inst in ipairs(out.instances) do instanceOrder[#instanceOrder + 1] = inst.instanceID end
      assert.are.same({ 100, 200, 300 }, instanceOrder)
    end)
  end)

  describe("unresolved data", function()
    it("keeps a boss relevant when a source has no item subtype", function()
      data.sources[5005].itemSubType = nil
      local out = evaluate({ classes = { "ROGUE" } })
      local enc = encounter(out, 100, 1003)
      assert.is_true(enc.relevant)
      local e = entry(enc.missing, 5005)
      assert.is_true(e.unresolved)
      assert.are.same({ "ROGUE" }, e.classes)
    end)

    it("never counts a source with no visual as owned", function()
      visualOf[5001] = nil
      local out = evaluate({ ownedVisuals = { [900] = true }, ownedSources = { [5001] = true } })
      local e = entry(encounter(out, 100, 1001).missing, 5001)
      assert.is_true(e.unresolved)
      assert.are.same({ owned = 1, total = 6 }, instance(out, 100).progress.PRIEST)
    end)

    it("counts an exactly owned source as owned even without a visual", function()
      visualOf[5001] = nil
      local out = evaluate({ ownership = "exact", ownedSources = { [5001] = true } })
      assert.is_nil(entry(encounter(out, 100, 1001).missing, 5001))
    end)

    it("counts an owned visual as owned even when the subtype is missing", function()
      data.sources[5001].itemSubType = nil
      local out = evaluate({ ownedVisuals = { [900] = true } })
      assert.is_nil(entry(encounter(out, 100, 1001).missing, 5001))
    end)
  end)

  describe("items not in the client", function()
    it("leaves an absent item out of a live instance and counts it", function()
      local out = evaluate({ absentItems = { [15001] = true } })
      assert.is_nil(entry(encounter(out, 100, 1001).missing, 5001))
      assert.are.equal(1, instance(out, 100).notInClient)
      assert.are.same({ owned = 0, total = 5 }, instance(out, 100).progress.PRIEST)
    end)

    it("keeps absent items in an assumed instance", function()
      local out = evaluate()
      local before = instance(out, 300).progress.PRIEST.total
      local absent = {}
      for _, s in pairs(data.sources) do
        if s.instanceID == 300 then absent[s.itemID] = true end
      end
      out = evaluate({ absentItems = absent })
      assert.are.equal(before, instance(out, 300).progress.PRIEST.total)
      assert.are.equal(0, instance(out, 300).notInClient)
    end)
  end)

  it("lists a level-locked drop and flags it", function()
    local out = evaluate({ classes = { "ROGUE" }, character = { classFile = "ROGUE", level = 60, faction = "Horde" } })
    assert.is_true(entry(encounter(out, 200, 2002).missing, 6003).levelLocked)
    out = evaluate({ classes = { "ROGUE" }, character = { classFile = "ROGUE", level = 62, faction = "Horde" } })
    assert.is_false(entry(encounter(out, 200, 2002).missing, 6003).levelLocked)
  end)

  describe("availability and context", function()
    it("shows an assumed instance as inactive", function()
      local out = evaluate()
      local assumed = instance(out, 300)
      assert.is_false(assumed.active)
      assert.are.equal("assumed", assumed.availability)
      assert.is_true(entry(encounter(out, 300, 3001).missing, 7001).unresolved)
      assert.is_true(instance(out, 200).active)
    end)

    it("reports the current instance only when it is known and not assumed", function()
      assert.are.equal(200, evaluate({ instanceContext = { instanceID = 200 } }).current)
      assert.is_nil(evaluate({ instanceContext = { instanceID = 300 } }).current)
      assert.is_nil(evaluate({ instanceContext = { instanceID = 999 } }).current)
      assert.is_nil(evaluate().current)
    end)
  end)

  describe("filters", function()
    it("deactivates instance kinds that are not selected", function()
      local out = evaluate({ instanceKinds = { dungeon = true } })
      assert.is_true(instance(out, 100).active)
      assert.is_false(instance(out, 200).active)
    end)

    it("lists only the selected instances", function()
      local out = evaluate({ instances = { [100] = true } })
      assert.are.equal(1, #out.instances)
      assert.are.equal(100, out.instances[1].instanceID)
    end)

    it("lists only the selected slots without changing progress", function()
      local all = evaluate()
      local out = evaluate({ slots = { INVTYPE_CHEST = true } })
      assert.are.same({ 5001 }, ids(encounter(out, 100, 1001).missing))
      assert.are.same({ 5002 }, ids(encounter(out, 100, 1002).missing))
      assert.is_false(encounter(out, 100, 1003).relevant)
      assert.are.same({}, ids(instance(out, 100).trash.missing))
      assert.are.same(instance(all, 100).progress, instance(out, 100).progress)
    end)
  end)

  describe("runtime rule from item facts", function()
    local function rule(out, instanceID, encounterID, sourceID)
      return entry(encounter(out, instanceID, encounterID).missing, sourceID).collectionRule
    end

    it("makes a bind-on-pickup dungeon drop of quality 2 or 3 a group drop", function()
      data.sources[5001].collectionRule = "unknown"
      data.sources[5004].collectionRule = "unknown"
      local out = evaluate({ classes = { "PRIEST", "ROGUE" }, itemFacts = {
        [15001] = { quality = 3, bindType = 1 }, [15004] = { quality = 2, bindType = 1 },
      } })
      assert.are.equal("group", rule(out, 100, 1001, 5001))
      assert.are.equal("group", rule(out, 100, 1002, 5004))
      assert.are.equal("sure", encounter(out, 100, 1001).opportunity)
    end)

    it("makes an epic dungeon drop a recipient drop", function()
      data.sources[5001].collectionRule = "unknown"
      local out = evaluate({ itemFacts = { [15001] = { quality = 4, bindType = 1 } } })
      assert.are.equal("recipient", rule(out, 100, 1001, 5001))
    end)

    it("makes any raid drop with a known quality a recipient drop", function()
      data.sources[6001].collectionRule = "unknown"
      local out = evaluate({ itemFacts = { [data.sources[6001].itemID] = { quality = 2, bindType = 2 } } })
      assert.are.equal("recipient", rule(out, 200, 2001, 6001))
    end)

    it("leaves the rule unknown without a quality or for a dungeon drop that is not bind on pickup", function()
      data.sources[5001].collectionRule = "unknown"
      data.sources[5004].collectionRule = "unknown"
      local out = evaluate({ classes = { "PRIEST" }, itemFacts = {
        [15001] = { bindType = 1 }, [15004] = { quality = 3, bindType = 2 },
      } })
      assert.are.equal("unknown", rule(out, 100, 1001, 5001))
      assert.are.equal("unknown", rule(out, 100, 1002, 5004))
    end)

    it("never overrides a rule from the data", function()
      local out = evaluate({ itemFacts = { [15001] = { quality = 4, bindType = 1 } } })
      assert.are.equal("group", rule(out, 100, 1001, 5001))
    end)
  end)

  describe("source kinds", function()
    it("keeps trash and unplaced sources apart from boss drops and ignores quests and vendors", function()
      local out = evaluate()
      local inst = instance(out, 100)
      assert.are.same({ 5008 }, ids(inst.trash.missing))
      assert.are.same({ 5009 }, ids(inst.other.missing))
      for _, enc in ipairs(inst.encounters) do
        for _, e in ipairs(enc.missing) do
          assert.is_true(e.sourceID ~= 5008 and e.sourceID ~= 5009 and e.sourceID ~= 5010 and e.sourceID ~= 5011)
        end
      end
    end)
  end)

  it("evaluates 20 instances of 15 encounters with 10 sources each within 50 ms", function()
    data = { instances = {}, encounters = {}, sources = {} }
    visualOf = {}
    local subTypes = { "CLOTH", "LEATHER", "MAIL", "PLATE", "GENERIC", "DAGGER", "STAFF", "SWORD_1H" }
    local sourceID = 1
    for i = 1, 20 do
      local encounters = {}
      for e = 1, 15 do
        local encounterID = i * 100 + e
        encounters[e] = encounterID
        data.encounters[encounterID] = { id = encounterID, instanceID = i }
        for _ = 1, 10 do
          data.sources[sourceID] = {
            id = sourceID, itemID = sourceID, instanceID = i, encounterID = encounterID, kind = "boss",
            slot = "INVTYPE_CHEST", itemClass = "armor", itemSubType = subTypes[sourceID % #subTypes + 1],
            collectionRule = i % 2 == 0 and "recipient" or "group",
          }
          visualOf[sourceID] = math.floor(sourceID / 2)
          sourceID = sourceID + 1
        end
      end
      data.instances[i] = { id = i, kind = i % 2 == 0 and "raid" or "dungeon", availability = "live",
        encounters = encounters }
    end
    local owned = {}
    for v = 1, 1500, 3 do owned[v] = true end

    local best = math.huge
    for _ = 1, 3 do
      local start = os.clock()
      evaluate({ classes = { "PRIEST", "ROGUE", "WARRIOR" }, ownedVisuals = owned })
      best = math.min(best, os.clock() - start)
    end
    assert.is_true(best < 0.05, ("took %.1f ms"):format(best * 1000))
  end)
end)
