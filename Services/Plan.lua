-- Assembles the evaluator's inputs from the services, evaluates, and caches
-- the plan. Changes mark it stale and schedule one debounced re-evaluation.
-- Nothing is evaluated during combat lockdown: transmog APIs are untested
-- there, so a re-evaluation waits for PLAYER_REGEN_ENABLED.
local _, ns = ...

local Plan = {}
ns.Plan = Plan

local DEBOUNCE = 0.5

local cached
local stale = true
local scheduled = false
local waitingForCombat = false
local factsRequested = false
local listeners = {}

-- Item facts only matter where the data left the rule unknown.
local function requestItemFacts()
  if factsRequested then return end
  factsRequested = true
  local itemIDs, seen = {}, {}
  for _, source in pairs(ns.Data and ns.Data.sources or {}) do
    if source.collectionRule == "unknown" and not seen[source.itemID] then
      seen[source.itemID] = true
      itemIDs[#itemIDs + 1] = source.itemID
    end
  end
  table.sort(itemIDs)
  ns.Collection.RequestItems(itemIDs)
end

function Plan.Inputs()
  return {
    data = ns.Data,
    proficiency = ns.Proficiency,
    profile = ns.Profile.Get(),
    collection = ns.Collection.Get(),
    itemFacts = ns.Collection.ItemFacts(),
    character = ns.Profile.Character(),
    instanceContext = ns.InstanceContext.Current(),
    lockouts = ns.Lockouts.Get(),
  }
end

local function refresh()
  requestItemFacts()
  cached = ns.Evaluator.Evaluate(Plan.Inputs())
  stale = false
  for _, fn in ipairs(listeners) do fn(cached) end
end

-- The plan, evaluated now if it is stale and the player is out of combat.
-- In combat it is the last plan, or nil before the first one.
function Plan.Get()
  if stale and not InCombatLockdown() then refresh() end
  return cached
end

function Plan.IsStale()
  return stale
end

function Plan.OnUpdate(fn)
  listeners[#listeners + 1] = fn
end

function Plan.Invalidate()
  stale = true
  if scheduled then return end
  scheduled = true
  C_Timer.After(DEBOUNCE, function()
    scheduled = false
    if InCombatLockdown() then
      waitingForCombat = true
    elseif stale then
      refresh()
    end
  end)
end

ns.On("PLAYER_REGEN_ENABLED", function()
  if waitingForCombat then
    waitingForCombat = false
    Plan.Invalidate()
  end
end)
ns.On("PLAYER_ENTERING_WORLD", Plan.Invalidate)
ns.On("ZONE_CHANGED_NEW_AREA", Plan.Invalidate)
