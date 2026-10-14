-- Builds the evaluator's collection and itemFacts inputs from the client.
--
-- Client APIs, checked against the Forever 1.60.1.70338 API docs
-- (Gethe/wow-ui-source@943764493e6b, Blizzard_APIDocumentationGenerated/
-- TransmogItemsDocumentation.lua and ItemDocumentation.lua; names also in
-- Ketho/BlizzardInterfaceResources@c5a49d394564, Resources/GlobalAPI.lua):
-- * C_TransmogCollection.GetSourceInfo(sourceID).visualID: the visual per
--   source. Verified in game.
-- * C_TransmogCollection.PlayerHasTransmogItemModifiedAppearance(sourceID):
--   exact ownership. Verified in game.
-- * C_TransmogCollection.GetAppearanceInfoBySource(sourceID)
--   .appearanceIsCollected: whether any source of the visual is owned,
--   including sources outside our data. Documented for Forever, not yet
--   seen in game. When it answers nothing, an appearance counts as owned
--   only through an owned source in our data.
-- * C_Item.GetItemInfo(itemID): quality (3rd return) and bindType (14th)
--   once the item is cached; C_Item.RequestLoadItemDataByID plus
--   GET_ITEM_INFO_RECEIVED otherwise. Not loaded yet is never "missing".
-- C_TransmogCollection.PlayerCanCollectSource is not used: in game it does
-- not reflect class proficiency.
local _, ns = ...

local Collection = {}
ns.Collection = Collection

local BATCH = 20
local BATCH_DELAY = 0.1

local visualOf, ownedSources, ownedVisuals = {}, {}, {}
local sourcesByVisual = {}
local stale = true

local facts, links = {}, {}
local queue, queued, pending = {}, {}, {}
local pumping = false

local function changed()
  if ns.Plan then ns.Plan.Invalidate() end
end

local function sources()
  return ns.Data and ns.Data.sources or {}
end

local function resolveVisual(sourceID)
  local info = C_TransmogCollection.GetSourceInfo(sourceID)
  return info and info.visualID
end

-- Whether a visual is owned, asked through one of our sources that has it.
local function visualOwned(visual)
  local anyOwned = false
  for sourceID in pairs(sourcesByVisual[visual] or {}) do
    if ownedSources[sourceID] then anyOwned = true end
  end
  local sourceID = next(sourcesByVisual[visual] or {})
  local info = sourceID and C_TransmogCollection.GetAppearanceInfoBySource(sourceID)
  if info and info.appearanceIsCollected ~= nil then
    return info.appearanceIsCollected or anyOwned
  end
  return anyOwned
end

local function rescan()
  ownedSources, ownedVisuals = {}, {}
  for sourceID in pairs(sources()) do
    local visual = visualOf[sourceID]
    if visual == nil then
      visual = resolveVisual(sourceID)
      if visual ~= nil then
        visualOf[sourceID] = visual
        sourcesByVisual[visual] = sourcesByVisual[visual] or {}
        sourcesByVisual[visual][sourceID] = true
      end
    end
    if C_TransmogCollection.PlayerHasTransmogItemModifiedAppearance(sourceID) then
      ownedSources[sourceID] = true
    end
  end
  for visual in pairs(sourcesByVisual) do
    if visualOwned(visual) then ownedVisuals[visual] = true end
  end
  stale = false
end

function Collection.Get()
  if stale then rescan() end
  return { visualOf = visualOf, ownedVisuals = ownedVisuals, ownedSources = ownedSources }
end

local function onSourceChanged(sourceID, added)
  if stale then return changed() end
  local ours = sources()[sourceID] ~= nil
  if ours then ownedSources[sourceID] = added or nil end
  local visual = visualOf[sourceID]
  if visual == nil then visual = resolveVisual(sourceID) end
  if visual ~= nil and sourcesByVisual[visual] then
    if added then
      ownedVisuals[visual] = true
    else
      ownedVisuals[visual] = visualOwned(visual) or nil
    end
  end
  changed()
end

ns.On("TRANSMOG_COLLECTION_SOURCE_ADDED", function(sourceID) onSourceChanged(sourceID, true) end)
ns.On("TRANSMOG_COLLECTION_SOURCE_REMOVED", function(sourceID) onSourceChanged(sourceID, false) end)
ns.On("TRANSMOG_COLLECTION_UPDATED", function()
  stale = true
  changed()
end)

-- Item facts --------------------------------------------------------------

local function readItem(itemID)
  local name, link, quality, _, _, _, _, _, _, _, _, _, _, bindType = C_Item.GetItemInfo(itemID)
  if name == nil or quality == nil then return false end
  facts[itemID] = { quality = quality, bindType = bindType }
  links[itemID] = link
  return true
end

local function pump()
  for _ = 1, BATCH do
    local itemID = table.remove(queue, 1)
    if not itemID then break end
    queued[itemID] = nil
    pending[itemID] = true
    C_Item.RequestLoadItemDataByID(itemID)
  end
  if #queue > 0 then
    C_Timer.After(BATCH_DELAY, pump)
  else
    pumping = false
  end
end

-- Asks the client for items whose facts are not known yet. Cached items are
-- read at once; the rest load in batches. Urgent items go to the front.
function Collection.RequestItems(itemIDs, urgent)
  for _, itemID in ipairs(itemIDs) do
    if not facts[itemID] and not pending[itemID] and not readItem(itemID) then
      if urgent and queued[itemID] then
        for i, id in ipairs(queue) do
          if id == itemID then table.remove(queue, i) break end
        end
        queued[itemID] = nil
      end
      if not queued[itemID] then
        queued[itemID] = true
        if urgent then table.insert(queue, 1, itemID) else queue[#queue + 1] = itemID end
      end
    end
  end
  if not pumping and #queue > 0 then
    pumping = true
    pump()
  end
end

ns.On("GET_ITEM_INFO_RECEIVED", function(itemID, success)
  if not pending[itemID] then return end
  pending[itemID] = nil
  if success and readItem(itemID) then changed() end
end)

function Collection.ItemFacts()
  return facts
end

function Collection.ItemLink(itemID)
  return links[itemID]
end

-- Loading state for one item, for diagnostics.
function Collection.ItemState(itemID)
  return {
    hasFacts = facts[itemID] ~= nil,
    hasLink = links[itemID] ~= nil,
    pending = pending[itemID] == true,
    queued = queued[itemID] == true,
  }
end
