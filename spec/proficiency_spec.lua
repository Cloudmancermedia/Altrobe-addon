local env = require("spec.helpers.wow_env")

describe("Proficiency", function()
  local P

  before_each(function()
    env.reset()
    P = env.load({ "Data/ClassProficiency.lua" }).Proficiency
  end)

  local function src(itemClass, itemSubType)
    return { itemClass = itemClass, itemSubType = itemSubType }
  end

  it("allows only the class's primary armor type", function()
    assert.is_true(P.CanCollect("PRIEST", src("armor", "CLOTH")))
    assert.is_false(P.CanCollect("PRIEST", src("armor", "LEATHER")))
    assert.is_true(P.CanCollect("ROGUE", src("armor", "LEATHER")))
    assert.is_false(P.CanCollect("ROGUE", src("armor", "CLOTH")))
    assert.is_true(P.CanCollect("HUNTER", src("armor", "MAIL")))
    assert.is_true(P.CanCollect("PALADIN", src("armor", "PLATE")))
    assert.is_false(P.CanCollect("SHAMAN", src("armor", "PLATE")))
  end)

  it("lets every class collect generic armor", function()
    for class in pairs(P.ArmorType) do
      assert.is_true(P.CanCollect(class, src("armor", "GENERIC")), class)
    end
  end)

  it("merges Forever weapon additions into the Classic baseline", function()
    assert.is_true(P.CanCollect("PRIEST", src("weapon", "DAGGER")))
    assert.is_false(P.CanCollect("PRIEST", src("weapon", "SWORD_1H")))
    assert.is_true(P.CanCollect("SHAMAN", src("weapon", "MACE_2H")))
    assert.is_true(P.CanCollect("ROGUE", src("weapon", "AXE_1H")))
    assert.is_true(P.CanCollect("DRUID", src("weapon", "POLEARM")))
    assert.is_false(P.CanCollect("MAGE", src("weapon", "POLEARM")))
  end)

  it("returns nil when the rule cannot decide", function()
    assert.is_nil(P.CanCollect("PRIEST", src("armor", nil)))
    assert.is_nil(P.CanCollect("PRIEST", src("armor", "SHIELD")))
    assert.is_nil(P.CanCollect("DEATHKNIGHT", src("armor", "PLATE")))
  end)

  it("maps every class file to its class ID", function()
    assert.are.same({
      WARRIOR = 1, PALADIN = 2, HUNTER = 3, ROGUE = 4, PRIEST = 5,
      SHAMAN = 7, MAGE = 8, WARLOCK = 9, DRUID = 11,
    }, P.ClassIDs)
  end)
end)
