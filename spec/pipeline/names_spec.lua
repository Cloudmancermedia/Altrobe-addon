local names = require("tools.names")

local ROOT = "spec/pipeline/fixtures/att"
local BUILD = "1.60.1.70338"

describe("names", function()
  describe("parseLine", function()
    it("reads an encounter or NPC name from the comment after its constructor", function()
      assert.are.same({ "encounter", 97, "Baron Silverlaine" },
        { names.parseLine("\t\te(97, {\t-- Baron Silverlaine") })
      assert.are.same({ "npc", 3914, "Rethilgore" },
        { names.parseLine("\tn(3914, {\t-- Rethilgore <The Cell Keeper>") })
      assert.are.same({ "npc", 14506, "Lord Hel'nurath" },
        { names.parseLine("\tn_conditional(14506, {\t-- Lord Hel'nurath") })
    end)

    it("reads NPC names from creature references", function()
      assert.are.same({ "npc", 16042, "Lord Valthalak" }, { names.parseLine("\t\tcr = 16042,\t-- Lord Valthalak") })
      assert.are.same({ "npc", 14516, "Death Knight Darkreaver" },
        { names.parseLine('\t["cr"] = 14516,\t-- Death Knight Darkreaver') })
      assert.are.same({ "npc", 16118, "Kormok" }, { names.parseLine('\tprovider = { "n", 16118 },\t-- Kormok') })
      assert.are.same({ "npc", 3887, "Baron Silverlaine" },
        { names.parseLine("\t\tcreatureID = 3887,\t-- Baron Silverlaine") })
    end)

    it("ignores lines that name nothing it can key", function()
      assert.is_nil(names.parseLine("\ti(1484),\t-- Witching Stave"))
      assert.is_nil(names.parseLine("\tn(QUESTS, {"))
      assert.is_nil(names.parseLine("\tn(3864, {"))
      assert.is_nil(names.parseLine("\t\t3863,\t-- Lupine Horror"))
    end)
  end)

  describe("load", function()
    local loaded

    setup(function() loaded = names.load(ROOT, BUILD) end)

    it("prefers the Forever source files over the Classic ones", function()
      assert.are.equal("Ghamoo-ra", loaded.npc[4887])
    end)

    it("falls back to the Classic source files", function()
      assert.are.equal("Standard Only Boss", loaded.encounter[3313])
      assert.are.equal("Wing Boss", loaded.npc[5003])
    end)

    it("leaves a name nil when one source disagrees with itself and records it", function()
      assert.is_nil(loaded.encounter[3312])
      assert.are.same({ "encounter 3312" }, loaded.conflicts)
    end)

    it("keeps alternatives in a comment for pick to settle", function()
      assert.are.equal("Onyxia [Classic] / Onyxia the Broodmother [CATA+]", loaded.encounter[1084])
    end)

    it("fails when a source directory is missing", function()
      assert.has_error(function() names.load("spec/pipeline/fixtures/missing", BUILD) end)
    end)
  end)

  describe("pick", function()
    local loaded

    setup(function() loaded = names.load(ROOT, BUILD) end)

    it("returns a single name as it is", function()
      assert.are.equal("Wing Boss", names.pick(loaded, "Wing Boss", 5003))
      assert.is_nil(names.pick(loaded, nil, 5003))
    end)

    it("picks the alternative the client's kill criteria name for that NPC", function()
      -- Criteria 900 kills NPC 10184 under tree row "Onyxia"; row 52 is not a kill criteria.
      assert.are.equal("Onyxia", names.pick(loaded, loaded.encounter[1084], 10184))
    end)

    it("leaves alternatives nil when the client does not settle them", function()
      assert.is_nil(names.pick(loaded, "Razorgore the Untamed / Grethok the Controller", 12435))
      assert.is_nil(names.pick(loaded, loaded.encounter[1084], nil))
    end)
  end)
end)
