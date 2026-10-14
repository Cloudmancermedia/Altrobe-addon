-- The farm-plan evaluator: a pure function from generated data, the profile,
-- the collection and the character to the plan. It never calls WoW APIs.
-- docs/data-contract.md defines its input and output.
local _, ns = ...

local Evaluator = {}
ns.Evaluator = Evaluator

-- Quest and vendor sources are out of scope for the first release.
local IGNORED_KINDS = { quest = true, vendor = true }

local function contains(list, value)
  for _, v in ipairs(list) do
    if v == value then return true end
  end
  return false
end

-- Profile classes the source can count for, in profile order, and whether
-- the proficiency rule could decide for every one of them.
local function eligibleClasses(source, classes, proficiency)
  local result, undecided = {}, false
  for _, classFile in ipairs(classes) do
    local classID = proficiency.ClassIDs[classFile]
    if not source.classes or classID == nil or contains(source.classes, classID) then
      local can = proficiency.CanCollect(classFile, source)
      if can == nil then
        undecided = true
        result[#result + 1] = classFile
      elseif can then
        result[#result + 1] = classFile
      end
    end
  end
  return result, undecided
end

local function byID(a, b) return a.sourceID < b.sourceID end

local RULE_RANK = { group = 3, recipient = 2, unknown = 1 }
local RANK_RULE = { "unknown", "roll", "sure" }

local function opportunity(missing)
  local best = 0
  for _, e in ipairs(missing) do
    best = math.max(best, RULE_RANK[e.collectionRule] or RULE_RANK.unknown)
  end
  return RANK_RULE[best]
end

-- The contract's runtime rule: item facts fill a rule only the data left
-- unknown, the way the pipeline derives it. A rule from the data stands.
local BIND_ON_PICKUP = 1

local function collectionRule(source, instanceKind, itemFacts)
  if source.collectionRule ~= "unknown" then return source.collectionRule end
  local facts = itemFacts[source.itemID]
  local quality = facts and facts.quality
  if quality == nil then return "unknown" end
  if instanceKind == "raid" or quality >= 4 then return "recipient" end
  if (quality == 2 or quality == 3) and facts.bindType == BIND_ON_PICKUP then return "group" end
  return "unknown"
end

local function newInstanceState(inst)
  local encounterIndex = {}
  for _, encounterID in ipairs(inst.encounters or {}) do encounterIndex[encounterID] = {} end
  return { inst = inst, encounterMissing = encounterIndex, trash = {}, other = {}, units = {}, notInClient = 0 }
end

function Evaluator.Evaluate(input)
  local data, profile, collection, character = input.data, input.profile, input.collection, input.character
  local proficiency = input.proficiency
  local classes = profile.classes or {}
  local exact = profile.ownership == "exact"
  local visualOf = collection.visualOf or {}
  local ownedVisuals = collection.ownedVisuals or {}
  local ownedSources = collection.ownedSources or {}
  local level = character.level or 0
  local lockouts = input.lockouts or {}
  local itemFacts = input.itemFacts or {}
  local absentItems = input.absentItems or {}
  local instanceKinds = profile.instanceKinds or { dungeon = true, raid = true }

  local states = {}
  for instanceID, inst in pairs(data.instances or {}) do
    if not profile.instances or profile.instances[instanceID] then
      states[instanceID] = newInstanceState(inst)
    end
  end

  for sourceID, source in pairs(data.sources or {}) do
    local state = states[source.instanceID]
    -- An item the client cannot load is not farmable in a live instance;
    -- it is counted, not listed. Assumed instances keep theirs.
    if state and absentItems[source.itemID] and state.inst.availability ~= "assumed"
      and not IGNORED_KINDS[source.kind] then
      state.notInClient = state.notInClient + 1
      state = nil
    end
    if state and not IGNORED_KINDS[source.kind]
      and (source.faction == nil or source.faction == character.faction) then
      local eligible, undecided = eligibleClasses(source, classes, proficiency)
      if #eligible > 0 then
        -- Ownership is checked first: an owned appearance is never sent to
        -- farm, even when its data is incomplete. Unresolved only matters for
        -- what is still missing, where it keeps the boss relevant.
        local visual = visualOf[sourceID]
        local owned
        if exact then
          owned = ownedSources[sourceID] == true
        else
          owned = visual ~= nil and ownedVisuals[visual] == true
        end
        local unresolved = not owned
          and (undecided or source.itemSubType == nil or (not exact and visual == nil))

        -- Progress units: a source in exact mode or when the visual is
        -- unknown, otherwise the visual.
        local unit = (exact or visual == nil) and ("s" .. sourceID) or ("v" .. visual)
        for _, classFile in ipairs(eligible) do
          local units = state.units[classFile]
          if not units then
            units = {}
            state.units[classFile] = units
          end
          units[unit] = units[unit] or owned
        end

        if not owned and (not profile.slots or profile.slots[source.slot]) then
          local entry = {
            sourceID = sourceID, itemID = source.itemID, classes = eligible,
            collectionRule = collectionRule(source, state.inst.kind, itemFacts), unresolved = unresolved,
            levelLocked = source.minLevel ~= nil and level < source.minLevel,
          }
          local list
          if source.kind == "boss" and source.encounterID then
            list = state.encounterMissing[source.encounterID]
          elseif source.kind == "trash" then
            list = state.trash
          end
          -- Unresolved and token sources, and boss drops whose encounter the
          -- instance does not list, stay visible here instead of vanishing.
          list = list or state.other
          list[#list + 1] = entry
        end
      end
    end
  end

  local out = { instances = {} }
  local ids = {}
  for instanceID in pairs(states) do ids[#ids + 1] = instanceID end
  table.sort(ids)

  for _, instanceID in ipairs(ids) do
    local state = states[instanceID]
    local inst = state.inst
    local killed = (lockouts[instanceID] or {}).killed or {}

    local progress = {}
    for _, classFile in ipairs(classes) do
      local owned, total = 0, 0
      for _, isOwned in pairs(state.units[classFile] or {}) do
        total = total + 1
        if isOwned then owned = owned + 1 end
      end
      progress[classFile] = { owned = owned, total = total }
    end

    local encounters = {}
    for _, encounterID in ipairs(inst.encounters or {}) do
      local missing = state.encounterMissing[encounterID]
      table.sort(missing, byID)
      encounters[#encounters + 1] = {
        encounterID = encounterID,
        relevant = #missing > 0,
        killed = killed[encounterID] == true,
        opportunity = opportunity(missing),
        missing = missing,
      }
    end

    table.sort(state.trash, byID)
    table.sort(state.other, byID)
    out.instances[#out.instances + 1] = {
      instanceID = instanceID,
      kind = inst.kind,
      availability = inst.availability,
      active = inst.availability ~= "assumed" and instanceKinds[inst.kind] == true,
      progress = progress,
      encounters = encounters,
      trash = { missing = state.trash },
      other = { missing = state.other },
      notInClient = state.notInClient,
    }
  end

  local context = input.instanceContext
  local current = context and data.instances and data.instances[context.instanceID]
  if current and current.availability ~= "assumed" then
    out.current = context.instanceID
  end

  return out
end
