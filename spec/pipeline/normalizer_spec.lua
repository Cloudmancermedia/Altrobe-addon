local loader = require("tools.loader")
local iteminfo = require("tools.iteminfo")
local normalizer = require("tools.normalizer")

local ROOT = "spec/pipeline/fixtures/att"

local AVAILABILITY = {
  [2959] = { availability = "live" },
  [760] = { availability = "announced", unlockDate = "2026-12-09" },
  [742] = { availability = "assumed" },
  [78789] = { availability = "announced", unlockDate = "2026-12-09", name = "Hyjal Summit" },
  [741] = { availability = "assumed", fallback = "vanilla" },
}

local function build(availability)
  return normalizer.normalize({
    camelot = loader.loadFile(ROOT .. "/db/Camelot/Categories/Instances.lua").Instances,
    vanilla = loader.loadFile(ROOT .. "/db/Vanilla/Categories/Instances.lua").Instances,
    items = iteminfo.load(ROOT, "1.60.1.70338"),
    availability = availability or AVAILABILITY,
    timeline = 16001,
  })
end

describe("normalizer", function()
  local data

  setup(function() data = build() end)

  describe("classification", function()
    it("calls a source under an encounter a boss drop", function()
      local src = data.sources[104]
      assert.are.equal("boss", src.kind)
      assert.are.equal(3311, src.encounterID)
      assert.are.equal(2959, src.instanceID)
    end)

    it("calls a source under the zone-drop header trash", function()
      assert.are.equal("trash", data.sources[102].kind)
      assert.is_nil(data.sources[102].encounterID)
    end)

    it("calls a quest reward a quest source", function()
      assert.are.equal("quest", data.sources[101].kind)
    end)

    it("calls a source under the vendors header a vendor source", function()
      assert.are.equal("vendor", data.sources[106].kind)
    end)

    it("leaves a drop from an NPC without an encounter unresolved and keeps the NPC", function()
      assert.are.equal("unresolved", data.sources[105].kind)
      assert.are.equal(4887, data.sources[105].npcID)
    end)

    it("ignores items that have no appearance source and sources outside any instance", function()
      assert.is_nil(data.sources[900])
      assert.are.equal(1, data.stats.outsideInstance)
    end)
  end)

  describe("timeline", function()
    it("drops removed, not-yet-added and retired sources and counts them", function()
      assert.is_nil(data.sources[107])
      assert.is_nil(data.sources[108])
      assert.is_nil(data.sources[109])
      assert.are.equal(3, data.stats.excludedByTimeline)
    end)

    it("keeps a source removed in a later patch and re-added after that", function()
      -- Upstream writes "removed in 2.0.1, back in 10.1.7" as awp=100107, rwp=20001.
      assert.are.equal("boss", data.sources[110].kind)
    end)
  end)

  describe("duplicates", function()
    it("keeps the first relationship as primary and records the others", function()
      local src = data.sources[103]
      assert.are.equal(3311, src.encounterID)
      assert.are.same({ { instanceID = 2959, encounterID = 3313, kind = "boss" } }, src.alsoFrom)
      assert.are.same({ 101, 103 }, data.stats.duplicateSources)
    end)

    it("clears the faction when the same source comes from both factions", function()
      assert.is_nil(data.sources[101].faction)
      assert.is_nil(data.sources[101].alsoFrom)
    end)
  end)

  describe("item fields", function()
    it("fills slot, class, subtype, quality, classes and level", function()
      local src = data.sources[104]
      assert.are.equal("INVTYPE_SHIELD", src.slot)
      assert.are.equal("armor", src.itemClass)
      assert.are.equal("SHIELD", src.itemSubType)
      assert.are.equal(4, src.quality)
      assert.are.same({ 8 }, src.classes)
      assert.are.equal(20, src.minLevel)
    end)

    it("leaves unknown quality nil and counts it", function()
      assert.is_nil(data.sources[105].quality)
      assert.is_true(data.stats.byInstance[2959].nilQuality >= 1)
    end)
  end)

  describe("collectionRule", function()
    it("is group for a dungeon bind-on-pickup drop of quality 2 or 3", function()
      assert.are.equal("group", data.sources[103].collectionRule)
    end)

    it("is recipient for quality 4", function()
      assert.are.equal("recipient", data.sources[104].collectionRule)
    end)

    it("is recipient for a raid drop of known quality", function()
      assert.are.equal("recipient", data.sources[301].collectionRule)
    end)

    it("is recipient for quest and vendor sources of known quality", function()
      assert.are.equal("recipient", data.sources[101].collectionRule)
      assert.are.equal("recipient", data.sources[106].collectionRule)
    end)

    it("is unknown when quality is unknown, even in a raid", function()
      assert.are.equal("unknown", data.sources[105].collectionRule)
      assert.are.equal("unknown", data.sources[201].collectionRule)
    end)

    it("is unknown for a dungeon drop whose binding upstream does not state", function()
      assert.are.equal("unknown", data.sources[102].collectionRule)
    end)
  end)

  describe("instances", function()
    it("names instances from the client area table and keeps upstream order of encounters", function()
      local inst = data.instances[2959]
      assert.are.equal("City of Dalaran", inst.name)
      assert.are.equal("dungeon", inst.kind)
      assert.are.equal(16544, inst.zoneTextAreaID)
      assert.are.same({ 3310, 3311, 3312, 3313 }, inst.encounters)
      assert.are.same({}, inst.uiMapIDs)
    end)

    it("merges maps and mapID into sorted uiMapIDs", function()
      assert.are.same({ 248, 249 }, data.instances[760].uiMapIDs)
    end)

    it("takes zoneTextAreaID from a single-entry zoneTextAreaIDs list", function()
      assert.are.equal(2677, data.instances[742].zoneTextAreaID)
      assert.are.equal("Blackwing Lair", data.instances[742].name)
    end)

    it("uses the availability name when the client tables have none", function()
      assert.are.equal("Hyjal Summit", data.instances[78789].name)
    end)

    it("records encounters with their instance and NPC", function()
      assert.are.same({ id = 3311, instanceID = 2959, npcID = 247126 }, data.encounters[3311])
    end)
  end)

  describe("availability", function()
    it("assigns availability and unlock date from the hand-maintained table", function()
      assert.are.equal("live", data.instances[2959].availability)
      assert.are.equal("announced", data.instances[760].availability)
      assert.are.equal("2026-12-09", data.instances[760].unlockDate)
      assert.are.equal("assumed", data.instances[742].availability)
    end)

    it("fails when an upstream instance has no availability entry", function()
      local partial = {}
      for k, v in pairs(AVAILABILITY) do partial[k] = v end
      partial[742] = nil
      assert.has_error(function() build(partial) end, "instance 742 has no entry in tools/availability.lua")
    end)
  end)

  describe("Vanilla fallback", function()
    it("takes an instance missing from Camelot from Vanilla and records the provenance", function()
      assert.are.equal("vanilla", data.instanceSources[741])
      assert.are.equal("camelot", data.instanceSources[760])
      assert.are.equal("Molten Core", data.instances[741].name)
      assert.are.equal("raid", data.instances[741].kind)
    end)

    it("prefers Camelot when both have the instance", function()
      assert.is_nil(data.sources[999])
    end)

    it("uses Vanilla quality for Vanilla instances and names items in assumed instances", function()
      local src = data.sources[301]
      assert.are.equal(4, src.quality)
      assert.are.same({ 9 }, src.classes)
      assert.are.equal("Felheart Gloves", src.name)
      assert.is_nil(data.sources[104].name)
    end)

    it("fails when a fallback instance is in neither database", function()
      local extra = {}
      for k, v in pairs(AVAILABILITY) do extra[k] = v end
      extra[12345] = { availability = "assumed", fallback = "vanilla" }
      assert.has_error(function() build(extra) end, "instance 12345 is in neither Camelot nor Vanilla")
    end)
  end)

  it("checks source IDs against the client appearance table", function()
    assert.are.same({ 202 }, data.stats.appearanceMismatch)
  end)
end)
