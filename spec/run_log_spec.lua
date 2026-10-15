local env = require("spec.helpers.wow_env")
local dungeonFixture = require("spec.fixtures.dungeon")

local FILES = {
  "Core.lua", "Data/ClassProficiency.lua", "Domain/Evaluator.lua", "Services/Profile.lua",
  "Services/Collection.lua", "Services/InstanceContext.lua", "Services/Lockouts.lua", "Services/Plan.lua",
  "UI/ChatPlan.lua", "Dev/ItemProbe.lua", "Dev/RunLog.lua",
}

describe("/altrobe runlog", function()
  local ns

  local function log() return _G.AltrobeDB.debug.runlog end

  local function entries(event)
    local list = {}
    for _, entry in ipairs(log().entries) do
      if entry.event == event then list[#list + 1] = entry end
    end
    return list
  end

  before_each(function()
    env.reset()
    _G.AltrobeDB = nil
    ns = env.load(FILES)
    local f = dungeonFixture()
    ns.Data = f.data
    for id, visual in pairs(f.visualOf) do env.transmog.visualOf[id] = visual end
    env.fire(ns, "ADDON_LOADED", "Altrobe")
  end)

  it("records nothing until started", function()
    env.fire(ns, "ENCOUNTER_END", 1001, "First Boss", 1, 5, 1)
    assert.is_nil((_G.AltrobeDB.debug or {}).runlog)
  end)

  it("starts a fresh log and stops recording on stop", function()
    _G.SlashCmdList.ALTROBE("runlog start")
    assert.matches("recording", env.output())
    env.fire(ns, "ENCOUNTER_END", 1001, "First Boss", 1, 5, 1)
    _G.SlashCmdList.ALTROBE("runlog stop")
    env.fire(ns, "ENCOUNTER_END", 1002, "Second Boss", 1, 5, 1)
    assert.are.equal(1, #entries("ENCOUNTER_END"))
    assert.matches("stopped", env.output())
  end)

  it("logs loot messages with the item and whether our data has it", function()
    _G.SlashCmdList.ALTROBE("runlog start")
    local text = "Tank receives loot: " .. env.itemLink(15001, "Fixture Robe") .. "."
    env.fire(ns, "CHAT_MSG_LOOT", text, "", "", "", "Tank")
    local entry = entries("CHAT_MSG_LOOT")[1]
    assert.are.equal(text, entry.text)
    assert.are.equal("Tank", entry.looter)
    assert.are.equal(15001, entry.itemID)
    assert.are.same({ 5001 }, entry.sourceIDs)
  end)

  it("logs appearances the player learns, with their item", function()
    _G.SlashCmdList.ALTROBE("runlog start")
    local getSourceInfo = _G.C_TransmogCollection.GetSourceInfo
    _G.C_TransmogCollection.GetSourceInfo = function(sourceID)
      local info = getSourceInfo(sourceID)
      if info then info.itemID = 15001 end
      return info
    end
    env.fire(ns, "TRANSMOG_COLLECTION_SOURCE_ADDED", 5001)
    local entry = entries("TRANSMOG_COLLECTION_SOURCE_ADDED")[1]
    assert.are.equal(5001, entry.sourceID)
    assert.are.equal(15001, entry.itemID)
    assert.is_true(entry.inData)
  end)

  it("logs ENCOUNTER_END raw, and whether the ID is one our data knows", function()
    _G.SlashCmdList.ALTROBE("runlog start")
    env.instance = { name = "Fixture Keep", type = "party", mapID = 2000 }
    env.fire(ns, "ENCOUNTER_END", 1001, "First Boss", 1, 5, 1)
    env.fire(ns, "ENCOUNTER_END", 777, "Stranger", 1, 5, 0)
    local known, unknown = entries("ENCOUNTER_END")[1], entries("ENCOUNTER_END")[2]
    assert.are.same({ 1001, "First Boss", 1, 5, 1 },
      { known.encounterID, known.name, known.difficultyID, known.groupSize, known.success })
    assert.is_true(known.known)
    assert.are.equal("Fixture Keep", known.instance)
    assert.are.equal(2000, known.instanceMapID)
    assert.is_false(unknown.known)
  end)

  it("saves raw saved-instance rows next to what Lockouts concludes", function()
    _G.SlashCmdList.ALTROBE("runlog start")
    env.saved = {
      { name = "Fixture Keep", locked = true, encounters = {
        { name = "First Boss", killed = true }, { name = "Second Boss", killed = false },
      } },
    }
    env.fire(ns, "UPDATE_INSTANCE_INFO")
    local snapshot = log().lockouts
    assert.are.equal("Fixture Keep", snapshot.saved[1].name)
    assert.is_true(snapshot.saved[1].locked)
    assert.are.same({ name = "First Boss", killed = true }, snapshot.saved[1].encounters[1])
    assert.is_true(snapshot.concluded[100].killed[1001])
  end)

  it("samples the transmog APIs a moment into combat", function()
    _G.SlashCmdList.ALTROBE("runlog start")
    env.fire(ns, "PLAYER_REGEN_DISABLED")
    env.inCombat = true
    env.runTimers()
    local probe = entries("combat")[1]
    assert.is_true(probe.inLockdown)
    local call = probe.calls[1]
    assert.are.equal("GetSourceInfo", call.api)
    assert.are.equal(5001, call.sourceID)
    assert.is_true(call.ok)
    assert.are.equal("table", call.kind)
  end)

  it("records an API that errors in combat instead of failing", function()
    _G.SlashCmdList.ALTROBE("runlog start")
    _G.C_TransmogCollection.PlayerHasTransmogItemModifiedAppearance = function() error("blocked") end
    env.fire(ns, "PLAYER_REGEN_DISABLED")
    env.runTimers()
    local failed
    for _, call in ipairs(entries("combat")[1].calls) do
      if call.api == "PlayerHasTransmogItemModifiedAppearance" then failed = call end
    end
    assert.is_false(failed.ok)
    assert.matches("blocked", failed.error)
  end)

  it("marks secret values and does not store them", function()
    _G.SlashCmdList.ALTROBE("runlog start")
    _G.issecretvalue = function(value) return value == true end
    env.transmog.ownedSources[5001] = true
    env.fire(ns, "PLAYER_REGEN_DISABLED")
    env.runTimers()
    _G.issecretvalue = nil
    local owned
    for _, call in ipairs(entries("combat")[1].calls) do
      if call.api == "PlayerHasTransmogItemModifiedAppearance" and call.sourceID == 5001 then owned = call end
    end
    assert.is_true(owned.secret)
    assert.is_nil(owned.value)
  end)
end)
