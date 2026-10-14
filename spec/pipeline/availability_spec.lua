local availability = require("tools.availability")

describe("availability table", function()
  it("marks the announced raids with the unlock date", function()
    for _, id in ipairs({ 760, 78789, 78790 }) do
      assert.are.equal("announced", availability[id].availability, id)
      assert.are.equal("2026-12-09", availability[id].unlockDate, id)
    end
  end)

  it("names the two raid shells that have no area name upstream", function()
    assert.are.equal("Hyjal Summit", availability[78789].name)
    assert.are.equal("The Barrow Deeps", availability[78790].name)
  end)

  it("marks Forever and classic dungeons live", function()
    for _, id in ipairs({ 2959, 2998, 2999, 3065, 63, 228, 241 }) do
      assert.are.equal("live", availability[id].availability, id)
    end
  end)

  it("marks the classic raids assumed and takes Molten Core from Vanilla", function()
    for _, id in ipairs({ 741, 742, 76, 743, 744, 754 }) do
      assert.are.equal("assumed", availability[id].availability, id)
    end
    assert.are.equal("vanilla", availability[741].fallback)
    assert.is_nil(availability[742].fallback)
  end)
end)
