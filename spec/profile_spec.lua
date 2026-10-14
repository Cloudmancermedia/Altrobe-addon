local env = require("spec.helpers.wow_env")

describe("Profile", function()
  local ns, invalidated

  before_each(function()
    env.reset()
    _G.AltrobeDB = nil
    ns = env.load({ "Core.lua", "Data/ClassProficiency.lua", "Services/Profile.lua" })
    invalidated = 0
    ns.Plan = { Invalidate = function() invalidated = invalidated + 1 end }
    env.fire(ns, "ADDON_LOADED", "Altrobe")
  end)

  it("defaults to the current character's class, appearance mode and every kind", function()
    assert.are.same({
      classes = { "PRIEST" }, ownership = "appearance", instanceKinds = { dungeon = true, raid = true },
    }, ns.Profile.Get())
  end)

  it("follows the logged-in class until classes are set", function()
    env.player.classFile = "ROGUE"
    assert.are.same({ "ROGUE" }, ns.Profile.Get().classes)
  end)

  it("describes the character for the evaluator", function()
    env.player.level = 42
    assert.are.same({ classFile = "PRIEST", level = 42, faction = "Horde" }, ns.Profile.Character())
  end)

  it("sets classes from the slash command and saves them", function()
    _G.SlashCmdList.ALTROBE("class priest Rogue PRIEST")
    assert.are.same({ "PRIEST", "ROGUE" }, ns.Profile.Get().classes)
    assert.are.same({ "PRIEST", "ROGUE" }, _G.AltrobeDB.profile.classes)
    assert.are.equal(1, invalidated)
    assert.matches("PRIEST, ROGUE", env.output())
  end)

  it("rejects an unknown class and keeps the profile", function()
    _G.SlashCmdList.ALTROBE("class priest monk")
    assert.are.same({ "PRIEST" }, ns.Profile.Get().classes)
    assert.matches("unknown class: MONK", env.output())
    assert.are.equal(0, invalidated)
  end)

  it("prints the current classes when none are given", function()
    _G.SlashCmdList.ALTROBE("class")
    assert.matches("classes: PRIEST", env.output())
  end)

  it("sets the ownership mode", function()
    _G.SlashCmdList.ALTROBE("mode exact")
    assert.are.equal("exact", ns.Profile.Get().ownership)
    assert.are.equal("exact", _G.AltrobeDB.profile.ownership)
    _G.SlashCmdList.ALTROBE("mode sideways")
    assert.are.equal("exact", ns.Profile.Get().ownership)
    assert.matches("/altrobe mode appearance|exact", env.output(), 1, true)
  end)

  it("works before saved variables load", function()
    ns = env.load({ "Core.lua", "Data/ClassProficiency.lua", "Services/Profile.lua" })
    assert.are.same({ "PRIEST" }, ns.Profile.Get().classes)
  end)
end)
