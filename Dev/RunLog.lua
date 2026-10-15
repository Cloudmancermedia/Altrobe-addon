-- /altrobe runlog start|stop: records the client's raw answers during a group
-- dungeon run, for the QA questions no solo test can answer:
-- * Group collection: loot messages next to TRANSMOG_COLLECTION_SOURCE_ADDED,
--   to see whether an item another player wins teaches its appearance.
-- * Combat: the transmog APIs sampled a second into each fight, to see whether
--   they answer plain values, secret values or errors during lockdown.
-- * Lockouts: raw saved-instance rows next to what Lockouts.Get() concludes.
-- * ENCOUNTER_END: its raw arguments, and whether the ID is one our data knows.
-- Results go to AltrobeDB.debug.runlog and reach disk on /reload or logout.
-- A diagnostic, not a player feature. issecretvalue is guarded: it is a
-- retail global that may not exist in the Forever client (unverified).
local _, ns = ...

local MAX_ENTRIES = 1000
local MAX_COMBAT_PROBES = 20
local COMBAT_DELAY = 1
local PROBE_SOURCES = 3

local recording = false
local combatProbes = 0

local function data()
  return ns.Data or {}
end

local function add(entry)
  if not recording then return end
  local entries = ns.db.debug.runlog.entries
  if #entries >= MAX_ENTRIES then return end
  entry.t = GetTime()
  entry.combat = InCombatLockdown() == true
  entries[#entries + 1] = entry
end

local function sourcesForItem(itemID)
  local list = {}
  for sourceID, source in pairs(data().sources or {}) do
    if source.itemID == itemID then list[#list + 1] = sourceID end
  end
  table.sort(list)
  return list
end

-- The lowest source IDs in our data, so every probe asks about the same ones.
local function probeSources()
  local ids = {}
  for sourceID in pairs(data().sources or {}) do ids[#ids + 1] = sourceID end
  table.sort(ids)
  local out = {}
  for i = 1, math.min(PROBE_SOURCES, #ids) do out[i] = ids[i] end
  return out
end

local function isSecret(value)
  return type(issecretvalue) == "function" and issecretvalue(value) == true
end

local function call(api, sourceID)
  local ok, value = pcall(C_TransmogCollection[api], sourceID)
  local row = { api = api, sourceID = sourceID, ok = ok }
  if not ok then
    row.error = tostring(value)
  elseif isSecret(value) then
    row.secret = true
  else
    row.kind = type(value)
    if type(value) ~= "table" then row.value = value end
  end
  return row
end

local function probeCombat()
  if not recording or combatProbes >= MAX_COMBAT_PROBES then return end
  combatProbes = combatProbes + 1
  local calls = {}
  for _, sourceID in ipairs(probeSources()) do
    calls[#calls + 1] = call("GetSourceInfo", sourceID)
    calls[#calls + 1] = call("PlayerHasTransmogItemModifiedAppearance", sourceID)
    calls[#calls + 1] = call("GetAppearanceInfoBySource", sourceID)
  end
  add({ event = "combat", inLockdown = InCombatLockdown() == true, calls = calls })
end

local function snapshotLockouts()
  if not recording then return end
  local saved = {}
  for i = 1, GetNumSavedInstances() do
    local name, id, reset, difficultyID, locked, extended, _, isRaid, maxPlayers, difficultyName,
      numEncounters = GetSavedInstanceInfo(i)
    local row = {
      name = name, id = id, reset = reset, difficultyID = difficultyID, locked = locked,
      extended = extended, isRaid = isRaid, maxPlayers = maxPlayers, difficultyName = difficultyName,
      encounters = {},
    }
    for e = 1, numEncounters or 0 do
      local bossName, _, killed = GetSavedInstanceEncounterInfo(i, e)
      row.encounters[e] = { name = bossName, killed = killed }
    end
    saved[i] = row
  end
  ns.db.debug.runlog.lockouts = { t = GetTime(), saved = saved, concluded = ns.Lockouts.Get() }
end

local function start()
  ns.db.debug = ns.db.debug or {}
  ns.db.debug.runlog = { entries = {} }
  recording = true
  combatProbes = 0
  snapshotLockouts()
  ns.Print("Run log recording. /altrobe runlog stop when done, then /reload to save.")
end

local function stop()
  recording = false
  local count = ns.db.debug and ns.db.debug.runlog and #ns.db.debug.runlog.entries or 0
  ns.Print(("Run log stopped with %d entries. /reload to save."):format(count))
end

ns.On("CHAT_MSG_LOOT", function(text, playerName, _, _, playerName2)
  local itemID = tonumber((text or ""):match("|Hitem:(%d+)"))
  add({
    event = "CHAT_MSG_LOOT", text = text, looter = playerName2 ~= "" and playerName2 or playerName,
    itemID = itemID, sourceIDs = itemID and sourcesForItem(itemID),
  })
end)

ns.On("TRANSMOG_COLLECTION_SOURCE_ADDED", function(sourceID)
  local info = recording and C_TransmogCollection.GetSourceInfo(sourceID)
  add({
    event = "TRANSMOG_COLLECTION_SOURCE_ADDED", sourceID = sourceID, itemID = info and info.itemID,
    inData = (data().sources or {})[sourceID] ~= nil,
  })
end)

ns.On("ENCOUNTER_END", function(encounterID, encounterName, difficultyID, groupSize, success)
  local instanceName, _, _, _, _, _, _, instanceMapID = GetInstanceInfo()
  add({
    event = "ENCOUNTER_END", encounterID = encounterID, name = encounterName, difficultyID = difficultyID,
    groupSize = groupSize, success = success, known = (data().encounters or {})[encounterID] ~= nil,
    instance = instanceName, instanceMapID = instanceMapID,
  })
end)

ns.On("UPDATE_INSTANCE_INFO", snapshotLockouts)

ns.On("PLAYER_REGEN_DISABLED", function()
  if recording then C_Timer.After(COMBAT_DELAY, probeCombat) end
end)

ns.RegisterCommand("runlog", function(arg)
  if arg == "start" then
    start()
  elseif arg == "stop" then
    stop()
  else
    ns.Print("usage: /altrobe runlog start|stop")
  end
end, "diagnostic: record loot, kills, lockouts and combat API answers")
