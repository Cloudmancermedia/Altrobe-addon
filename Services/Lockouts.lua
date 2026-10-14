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

local function words(name)
  local list = {}
  for word in name:gmatch("[%w']+") do list[#list + 1] = word end
  return list
end

-- True when the shorter name's words appear in a row inside the longer name:
-- "Cookie" in "Captain Cookie", "Hakkar" in "Hakkar the Soulflayer".
local function wordsWithin(a, b)
  local short, long = words(a), words(b)
  if #short > #long then short, long = long, short end
  if #short == 0 then return false end
  for start = 1, #long - #short + 1 do
    local all = true
    for i = 1, #short do
      if long[start + i - 1] ~= short[i] then all = false break end
    end
    if all then return true end
  end
  return false
end

local function distance(a, b)
  local prev = {}
  for j = 0, #b do prev[j] = j end
  for i = 1, #a do
    local cur = { [0] = i }
    for j = 1, #b do
      local cost = a:byte(i) == b:byte(j) and 0 or 1
      cur[j] = math.min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + cost)
    end
    prev = cur
  end
  return prev[#b]
end

-- Upstream boss names sometimes differ from the client's: "Cookie" for
-- "Captain Cookie", "Shade of Erankikus" for "Shade of Eranikus". Matching
-- tries exact names, then whole words, then a misspelling of at most two
-- letters in names of eight letters or more. A tolerant step counts only
-- when exactly one boss in the instance fits, so it never marks the wrong one.
local MIN_TYPO_LENGTH, MAX_TYPOS = 8, 2

local function encounterByName(inst, name)
  local wanted = normalize(name)
  if wanted == "" then return nil end
  local encounters = data().encounters or {}
  local named = {}
  for _, encounterID in ipairs(inst.encounters or {}) do
    local enc = encounters[encounterID]
    if enc and enc.name then named[#named + 1] = { id = encounterID, name = normalize(enc.name) } end
  end
  local tests = {
    function(candidate) return candidate == wanted end,
    function(candidate) return wordsWithin(candidate, wanted) end,
    function(candidate)
      return #candidate >= MIN_TYPO_LENGTH and #wanted >= MIN_TYPO_LENGTH
        and distance(candidate, wanted) <= MAX_TYPOS
    end,
  }
  for _, test in ipairs(tests) do
    local found, count = nil, 0
    for _, enc in ipairs(named) do
      if test(enc.name) then found, count = enc.id, count + 1 end
    end
    if count == 1 then return found end
    if count > 1 then return nil end
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
