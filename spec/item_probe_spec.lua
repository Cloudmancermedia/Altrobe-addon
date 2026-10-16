local env = require("spec.helpers.wow_env")
local dungeonFixture = require("spec.fixtures.dungeon")

local FILES = {
  "Core.lua", "Data/ClassProficiency.lua", "Domain/Evaluator.lua", "Services/Profile.lua",
  "Services/Collection.lua", "Services/InstanceContext.lua", "Services/Lockouts.lua", "Services/Plan.lua",
  "UI/WindowModel.lua", "UI/ChatPlan.lua", "Dev/ItemProbe.lua",
}

describe("/altrobe items", function()
  local ns

  local function rowFor(itemID)
    for _, row in ipairs(_G.AltrobeDB.debug.items.rows) do
      if row.itemID == itemID then return row end
    end
  end

  before_each(function()
    env.reset()
    _G.AltrobeDB = nil
    ns = env.load(FILES)
    local f = dungeonFixture()
    ns.Data = f.data
    for id, visual in pairs(f.visualOf) do env.transmog.visualOf[id] = visual end
    env.fire(ns, "ADDON_LOADED", "Altrobe")
    -- Item 15002 does not exist in this client; 15001 exists but is not cached.
    _G.C_Item.DoesItemExistByID = function(itemID) return itemID ~= 15002 end
    _G.C_Item.IsItemDataCachedByID = function(itemID)
      return env.items[itemID] ~= nil and env.items[itemID].cached == true
    end
    _G.C_Item.GetItemInfoInstant = function(itemID) return itemID, "Armor", "Cloth", "INVTYPE_CHEST" end
  end)

  it("saves the client's view of every missing item in the instance", function()
    _G.SlashCmdList.ALTROBE("items fixture keep")
    local probe = _G.AltrobeDB.debug.items
    assert.are.equal(100, probe.instanceID)

    local present = rowFor(15001)
    assert.is_true(present.exists)
    assert.is_false(present.cached)
    assert.are.equal("Armor", present.instantType)
    assert.is_true(present.pending)
    assert.is_false(present.hasFacts)

    assert.is_false(rowFor(15002).exists)
    assert.matches("Saved", env.output())
  end)

  it("logs the client's load answers after a probe", function()
    _G.SlashCmdList.ALTROBE("items fixture keep")
    env.fire(ns, "GET_ITEM_INFO_RECEIVED", 15001, false)
    env.fire(ns, "ITEM_DATA_LOAD_RESULT", 15002, false)
    assert.are.same({
      { event = "GET_ITEM_INFO_RECEIVED", itemID = 15001, success = false },
      { event = "ITEM_DATA_LOAD_RESULT", itemID = 15002, success = false },
    }, _G.AltrobeDB.debug.events)
  end)

  it("names the instance it could not find", function()
    _G.SlashCmdList.ALTROBE("items nowhere")
    assert.matches("No instance matches", env.output())
    assert.is_nil((_G.AltrobeDB.debug or {}).items)
  end)
end)
