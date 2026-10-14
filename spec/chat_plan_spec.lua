local env = require("spec.helpers.wow_env")
local dungeonFixture = require("spec.fixtures.dungeon")
local raidFixture = require("spec.fixtures.raid")

local FILES = {
  "Core.lua", "Data/ClassProficiency.lua", "Domain/Evaluator.lua", "Services/Profile.lua",
  "Services/Collection.lua", "Services/InstanceContext.lua", "Services/Lockouts.lua", "Services/Plan.lua",
  "UI/ChatPlan.lua",
}

describe("/altrobe plan", function()
  local ns

  local function plan(rest)
    env.printed = {}
    _G.SlashCmdList.ALTROBE("plan" .. (rest and (" " .. rest) or ""))
    return env.output()
  end

  before_each(function()
    env.reset()
    _G.AltrobeDB = nil
    ns = env.load(FILES)
    ns.Data = { instances = {}, encounters = {}, sources = {} }
    for _, build in ipairs({ dungeonFixture, raidFixture }) do
      local f = build()
      for _, key in ipairs({ "instances", "encounters", "sources" }) do
        for id, row in pairs(f.data[key]) do ns.Data[key][id] = row end
      end
      for id, visual in pairs(f.visualOf) do env.transmog.visualOf[id] = visual end
    end
    env.fire(ns, "ADDON_LOADED", "Altrobe")
    env.mapID = 1000
  end)

  it("lists the current instance's relevant bosses in order with opportunity and item count", function()
    local out = plan()
    assert.matches("Fixture Keep", out)
    assert.matches("PRIEST 0/5", out)
    local first = out:find("First Boss", 1, true)
    local second = out:find("Second Boss", 1, true)
    assert.is_truthy(first and second and first < second)
    assert.matches("2%. First Boss %- |cff1eff00sure|r %- 1 missing", out)
    assert.matches("3%. Second Boss %- |cff1eff00sure|r %- 2 missing", out)
    assert.matches("Trash: 1 missing", out)
    assert.matches("Other: 1 missing", out)
  end)

  it("leaves out bosses with nothing missing", function()
    assert.matches("1%. Opening Boss", plan())
    env.transmog.ownedVisuals = { [904] = true }
    env.fire(ns, "TRANSMOG_COLLECTION_UPDATED")
    local out = plan()
    assert.is_nil(out:find("Opening Boss", 1, true))
  end)

  it("shows item IDs until items load, then links", function()
    local out = plan()
    assert.matches("item:15001", out)
    assert.matches("loading", out)
    assert.is_truthy(#env.itemRequests > 0)

    env.items[15001] = { name = "Fixture Robe", quality = 3, bindType = 1, cached = true }
    env.fire(ns, "GET_ITEM_INFO_RECEIVED", 15001, true)
    out = plan()
    assert.matches("[Fixture Robe]", out, 1, true)
  end)

  it("marks killed bosses and colours a raid roll", function()
    env.mapID = nil
    env.fire(ns, "ENCOUNTER_END", 2001, "Raid Boss One", 1, 5, 1)
    local out = plan("fixture spire")
    assert.matches("|cffffd100roll|r", out, 1, true)
    assert.matches("killed", out)
  end)

  it("plans a named instance from anywhere", function()
    env.mapID = nil
    local out = plan("fixture keep")
    assert.matches("Fixture Keep", out)
  end)

  it("explains when the player is not in a known instance", function()
    env.mapID = nil
    local out = plan()
    assert.matches("/altrobe plan <instance name>", out, 1, true)
  end)

  it("lists the candidates when the name is ambiguous or unknown", function()
    env.mapID = nil
    assert.matches("Which one", plan("fixture"))
    assert.matches("No instance matches", plan("nowhere"))
  end)

  it("says so when no boss has anything missing", function()
    env.transmog.ownedVisuals = { [900] = true, [902] = true, [901] = true, [904] = true }
    local out = plan()
    assert.matches("No boss here drops", out)
  end)

  it("waits for combat to end and then prints", function()
    env.inCombat = true
    local out = plan()
    assert.matches("after combat", out)
    assert.is_nil(out:find("First Boss", 1, true))
    env.inCombat = false
    env.printed = {}
    env.fire(ns, "PLAYER_REGEN_ENABLED")
    assert.matches("First Boss", env.output())
  end)

  it("keeps chat lines short", function()
    for line in plan():gmatch("[^\n]+") do
      local visible = line:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h", ""):gsub("|h", "")
      assert.is_true(#visible <= 80, visible)
    end
  end)
end)
