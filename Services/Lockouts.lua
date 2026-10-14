-- Builds the evaluator's lockouts input: lockouts[instanceID].killed[encounterID].
--
-- Saved instances (GetSavedInstanceInfo, GetSavedInstanceEncounterInfo)
-- report instances and bosses by name, so both are matched by name against
-- the data. A boss whose data has no name is never marked killed from a
-- lockout. ENCOUNTER_END adds kills for the session: by encounter ID when it
-- is one the data knows, otherwise by boss name in the current instance.
-- UNTESTED in game: the lockout fields, and whether ENCOUNTER_END's ID is
-- the journal encounter ID the data uses.
local _, ns = ...

local Lockouts = {}
ns.Lockouts = Lockouts

local normalize = ns.InstanceContext.Normalize
local session = {}

local function data()
  return ns.Data or {}
end

local function instanceByName(name)
  local wanted = normalize(name)
  for instanceID, inst in pairs(data().instances or {}) do
    if normalize(inst.name) == wanted then return instanceID, inst end
  end
end

local function encounterByName(inst, name)
  local wanted = normalize(name)
  if wanted == "" then return nil end
  local encounters = data().encounters or {}
  for _, encounterID in ipairs(inst.encounters or {}) do
    local enc = encounters[encounterID]
    if enc and enc.name and normalize(enc.name) == wanted then return encounterID end
  end
end

local function mark(out, instanceID, encounterID)
  out[instanceID] = out[instanceID] or { killed = {} }
  out[instanceID].killed[encounterID] = true
end

function Lockouts.Get()
  local out = {}
  for i = 1, GetNumSavedInstances() do
    local name, _, _, _, locked, _, _, _, _, _, numEncounters = GetSavedInstanceInfo(i)
    local instanceID, inst = instanceByName(name)
    if locked and inst then
      for e = 1, numEncounters or 0 do
        local bossName, _, isKilled = GetSavedInstanceEncounterInfo(i, e)
        local encounterID = isKilled and encounterByName(inst, bossName)
        if encounterID then mark(out, instanceID, encounterID) end
      end
    end
  end
  for instanceID, killed in pairs(session) do
    for encounterID in pairs(killed) do mark(out, instanceID, encounterID) end
  end
  return out
end

local function changed()
  if ns.Plan then ns.Plan.Invalidate() end
end

ns.On("ENCOUNTER_END", function(encounterID, encounterName, _, _, success)
  if success == 1 then
    local enc = (data().encounters or {})[encounterID]
    local instanceID = enc and enc.instanceID
    if not instanceID then
      local context = ns.InstanceContext.Current()
      local inst = context and (data().instances or {})[context.instanceID]
      encounterID = inst and encounterByName(inst, encounterName)
      instanceID = encounterID and context.instanceID
    end
    if instanceID then
      session[instanceID] = session[instanceID] or {}
      session[instanceID][encounterID] = true
    end
  end
  changed()
end)

ns.On("PLAYER_ENTERING_WORLD", function() RequestRaidInfo() end)
ns.On("UPDATE_INSTANCE_INFO", changed)
