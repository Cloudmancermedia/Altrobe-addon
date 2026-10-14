-- Maps where the player is to an instance in ns.Data.instances, and finds
-- instances by name for slash commands.
--
-- The player's map (C_Map.GetBestMapForUnit) is matched against uiMapIDs
-- first. Instances without uiMapIDs, and floors the data does not list,
-- fall back to the zone name from GetInstanceInfo() while inside an
-- instance. The Encounter Journal is empty on Forever, so it is not used.
local _, ns = ...

local InstanceContext = {}
ns.InstanceContext = InstanceContext

local function instances()
  return ns.Data and ns.Data.instances or {}
end

-- Lower case, single spaces, no leading "the".
function InstanceContext.Normalize(name)
  name = (name or ""):lower():gsub("%s+", " "):gsub("^ ", ""):gsub(" $", "")
  return (name:gsub("^the ", ""))
end
local normalize = InstanceContext.Normalize

local function byName(name)
  local wanted = normalize(name)
  for instanceID, inst in pairs(instances()) do
    if normalize(inst.name) == wanted then return instanceID end
  end
end

-- { instanceID = n } for where the player is, or nil.
function InstanceContext.Current()
  local mapID = C_Map.GetBestMapForUnit("player")
  if mapID then
    for instanceID, inst in pairs(instances()) do
      for _, id in ipairs(inst.uiMapIDs or {}) do
        if id == mapID then return { instanceID = instanceID } end
      end
    end
  end
  local name, instanceType = GetInstanceInfo()
  if instanceType == nil or instanceType == "none" then return nil end
  local instanceID = byName(name)
  return instanceID and { instanceID = instanceID } or nil
end

-- Instance IDs whose name matches the query: the exact name when there is
-- one, otherwise every name containing it, by ID.
function InstanceContext.Find(query)
  local exact = byName(query)
  if exact then return { exact } end
  local wanted = normalize(query)
  local found = {}
  for instanceID, inst in pairs(instances()) do
    if wanted ~= "" and normalize(inst.name):find(wanted, 1, true) then
      found[#found + 1] = instanceID
    end
  end
  table.sort(found)
  return found
end
