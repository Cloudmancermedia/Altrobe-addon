local iteminfo = require("tools.iteminfo")

local ROOT = "spec/pipeline/fixtures/att"

describe("iteminfo", function()
  local info

  setup(function()
    info = iteminfo.load(ROOT, "1.60.1.70338")
  end)

  it("parses quoted CSV fields that contain commas", function()
    local got = iteminfo.parseCSVLine('1,"Robe, of Tests",,"say ""hi"""')
    assert.are.same({ "1", "Robe, of Tests", "", 'say "hi"' }, got)
  end)

  it("reads quality from the client search-name table first, then the harvested ItemDB", function()
    assert.are.equal(2, info:lookup(1001).quality)
    assert.are.equal(3, info:lookup(1002).quality)
    assert.is_nil(info:lookup(1006).quality)
  end)

  it("leaves quality nil when the two upstream tables disagree", function()
    local row = info:lookup(2002)
    assert.is_nil(row.quality)
    assert.is_true(row.qualityConflict)
  end)

  it("reads bind-on-pickup only when upstream says so", function()
    assert.is_true(info:lookup(1003).bop)
    assert.is_nil(info:lookup(1002).bop)
  end)

  it("turns a class bitmask into class IDs and drops masks that allow every class", function()
    assert.are.same({ 9 }, info:lookup(3001).classes)
    assert.is_nil(info:lookup(1007).classes)
  end)

  it("treats a required level of 1 as no requirement", function()
    assert.are.equal(15, info:lookup(1001).minLevel)
    assert.is_nil(info:lookup(1007).minLevel)
  end)

  it("names areas from the client area table", function()
    assert.are.equal("City of Dalaran", info.areaNames[16544])
  end)

  it("maps source IDs to items from the client appearance table", function()
    assert.are.equal(1001, info.appearanceItem[101])
  end)

  describe("describe", function()
    local function d(itemID) return iteminfo.describe(info:lookup(itemID)) end

    it("maps armor to slot and armor type", function()
      assert.are.same({ slot = "INVTYPE_CHEST", itemClass = "armor", itemSubType = "CLOTH" }, d(1001))
      assert.are.same({ slot = "INVTYPE_HEAD", itemClass = "armor", itemSubType = "PLATE" }, d(2001))
    end)

    it("calls cloaks and rings GENERIC and shields SHIELD", function()
      assert.are.equal("GENERIC", d(1006).itemSubType)
      assert.are.equal("INVTYPE_CLOAK", d(1006).slot)
      assert.are.equal("GENERIC", d(1007).itemSubType)
      assert.are.equal("SHIELD", d(1004).itemSubType)
    end)

    it("uses the WeaponWise weapon keys", function()
      assert.are.same({ slot = "INVTYPE_WEAPON", itemClass = "weapon", itemSubType = "DAGGER" }, d(1002))
      assert.are.equal("CROSSBOW", d(1003).itemSubType)
      assert.are.equal("INVTYPE_RANGEDRIGHT", d(1003).slot)
    end)

    it("leaves the subtype nil for weapon kinds WeaponWise does not track", function()
      local got = d(2002)
      assert.are.equal("weapon", got.itemClass)
      assert.is_nil(got.itemSubType)
    end)

    it("returns nothing for an item the client tables do not know", function()
      assert.are.same({}, iteminfo.describe(info:lookup(424242)))
    end)
  end)
end)
