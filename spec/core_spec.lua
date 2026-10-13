local env = require("spec.helpers.wow_env")

describe("Core", function()
  local ns

  before_each(function()
    env.reset()
    _G.AltrobeDB = nil
    ns = env.load({ "Core.lua" })
  end)

  it("creates saved variables when the addon loads", function()
    env.fire(ns, "ADDON_LOADED", "Altrobe")
    assert.are.same({}, ns.db)
    assert.are.equal(_G.AltrobeDB, ns.db)
  end)

  it("ignores other addons loading", function()
    env.fire(ns, "ADDON_LOADED", "AllTheThings")
    assert.is_nil(ns.db)
  end)

  it("routes slash commands and lists them when unknown", function()
    local got
    ns.RegisterCommand("plan", function(rest) got = rest end, "show the farm plan")
    _G.SlashCmdList.ALTROBE("plan priest")
    assert.are.equal("priest", got)

    _G.SlashCmdList.ALTROBE("nope")
    assert.matches("/altrobe plan %- show the farm plan", env.output())
  end)
end)
