local env = require("spec.helpers.wow_env")
local dungeonFixture = require("spec.fixtures.dungeon")
local raidFixture = require("spec.fixtures.raid")

local FILES = {
  "Core.lua", "Data/ClassProficiency.lua", "Domain/Evaluator.lua", "Services/Profile.lua",
  "Services/Collection.lua", "Services/InstanceContext.lua", "Services/Lockouts.lua", "Services/Plan.lua",
  "UI/WindowModel.lua", "UI/ChatPlan.lua", "UI/InstanceWindow.lua",
}

describe("instance window", function()
  local ns

  local function window() return _G.AltrobeInstanceWindow end

  local function shown()
    return window() ~= nil and window():IsShown()
  end

  local function text()
    return table.concat(env.texts(window()), "\n")
  end

  local function slash(rest)
    env.printed = {}
    _G.SlashCmdList.ALTROBE("window" .. (rest and (" " .. rest) or ""))
    return env.output()
  end

  local function enter(mapID)
    env.mapID = mapID
    env.fire(ns, mapID and "PLAYER_ENTERING_WORLD" or "ZONE_CHANGED_NEW_AREA")
    env.runTimers()
  end

  local function iconFor(itemID)
    local found
    local function walk(w)
      if rawget(w, "itemID") == itemID and w.shown then found = w end
      for _, child in ipairs(w.children) do walk(child) end
    end
    walk(window())
    return found
  end

  local function boot(db)
    env.reset()
    _G.AltrobeDB = db
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
  end

  before_each(function() boot(nil) end)

  it("opens on entering a known instance with relevant bosses", function()
    enter(1000)
    assert.is_true(shown())
    local out = text()
    assert.matches("Fixture Keep", out)
    assert.matches("PRIEST 0/5", out)
    assert.matches("1%. Opening Boss", out)
    assert.matches("2%. First Boss", out)
    assert.matches("3%. Second Boss", out)
    assert.matches("Trash: 1", out)
  end)

  it("stays closed outside instances", function()
    enter(nil)
    assert.is_false(shown())
  end)

  it("does not open on its own when no boss is relevant", function()
    env.transmog.ownedVisuals = { [900] = true, [902] = true, [901] = true, [904] = true, [903] = true,
      [905] = true }
    enter(1000)
    assert.is_false(shown())
  end)

  it("closes when the player leaves the instance", function()
    enter(1000)
    enter(nil)
    assert.is_false(shown())
  end)

  it("stays closed after the player closes it, until the next instance", function()
    enter(1000)
    window():Hide()
    env.fire(ns, "TRANSMOG_COLLECTION_UPDATED")
    env.runTimers()
    assert.is_false(shown())
    enter(nil)
    enter(1000)
    assert.is_true(shown())
  end)

  it("closes with Escape", function()
    enter(1000)
    assert.are.same({ "AltrobeInstanceWindow" }, _G.UISpecialFrames)
  end)

  it("greys a killed boss and keeps it in place", function()
    enter(1000)
    env.fire(ns, "ENCOUNTER_END", 1001, "First Boss", 1, 5, 1)
    env.runTimers()
    local out = text()
    assert.matches("2%. First Boss %- killed", out)
    assert.is_true(iconFor(15001).icon.desaturated)
  end)

  it("shows each missing item as an icon with the item tooltip", function()
    env.items[15001] = { icon = 134400 }
    enter(1000)
    local icon = iconFor(15001)
    assert.are.equal(134400, icon.icon.texture)
    icon.scripts.OnEnter(icon)
    assert.are.equal(15001, env.tooltip.itemID)
    assert.are.equal(icon, env.tooltip.owner)
  end)

  it("opens after combat when the player enters in combat", function()
    env.inCombat = true
    enter(1000)
    assert.is_false(shown())
    env.inCombat = false
    env.fire(ns, "PLAYER_REGEN_ENABLED")
    env.runTimers()
    assert.is_true(shown())
  end)

  it("keeps the last plan on screen during combat", function()
    enter(1000)
    env.inCombat = true
    env.fire(ns, "ENCOUNTER_END", 1001, "First Boss", 1, 5, 1)
    env.runTimers()
    assert.is_true(shown())
    assert.is_nil(text():find("killed", 1, true))
  end)

  describe("/altrobe window", function()
    it("toggles the window for the current instance", function()
      enter(1000)
      slash()
      assert.is_false(shown())
      slash()
      assert.is_true(shown())
    end)

    it("opens a named instance from anywhere and keeps it open outside instances", function()
      enter(nil)
      slash("fixture spire")
      assert.is_true(shown())
      assert.matches("Fixture Spire", text())
      env.fire(ns, "TRANSMOG_COLLECTION_UPDATED")
      env.runTimers()
      assert.is_true(shown())
    end)

    it("explains when the player is not in a known instance", function()
      enter(nil)
      assert.matches("/altrobe window <instance name>", slash(), 1, true)
    end)

    it("names the instance it could not find", function()
      assert.matches("No instance matches", slash("nowhere"))
    end)

    it("says so when nothing here is missing", function()
      env.transmog.ownedVisuals = { [900] = true, [902] = true, [901] = true, [904] = true, [903] = true,
        [905] = true }
      enter(1000)
      slash()
      assert.matches("No boss here drops", text())
    end)

    it("turns opening on entry off and on, and saves it", function()
      assert.matches("off", slash("auto off"))
      assert.is_false(_G.AltrobeDB.window.autoOpen)
      enter(1000)
      assert.is_false(shown())
      assert.matches("on", slash("auto on"))
      enter(nil)
      enter(1000)
      assert.is_true(shown())
    end)
  end)

  it("saves its position when dragged and restores it next session", function()
    enter(1000)
    window():ClearAllPoints()
    window():SetPoint("TOPLEFT", _G.UIParent, "TOPLEFT", 40, -60)
    window().scripts.OnDragStop(window())
    assert.are.same({ point = "TOPLEFT", relativePoint = "TOPLEFT", x = 40, y = -60 },
      _G.AltrobeDB.window.position)

    boot(_G.AltrobeDB)
    enter(1000)
    local point, _, relativePoint, x, y = window():GetPoint(1)
    assert.are.same({ "TOPLEFT", "TOPLEFT", 40, -60 }, { point, relativePoint, x, y })
  end)
end)
