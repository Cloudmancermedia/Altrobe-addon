-- /altrobe items <instance>: records what the client says about every missing
-- item in an instance, then logs the client's load answers. Results go to
-- AltrobeDB.debug and reach disk on /reload or logout. A diagnostic, not a
-- player feature.
local _, ns = ...

local MAX_EVENTS = 300
local watching = false

local function missingItems(inst)
  local seen, list = {}, {}
  local function add(entries)
    for _, entry in ipairs(entries) do
      if not seen[entry.itemID] then
        seen[entry.itemID] = true
        list[#list + 1] = entry
      end
    end
  end
  for _, enc in ipairs(inst.encounters) do add(enc.missing) end
  add(inst.trash.missing)
  add(inst.other.missing)
  return list
end

local function probe(query)
  local instanceID
  if query == "" then
    local context = ns.InstanceContext.Current()
    instanceID = context and context.instanceID
  else
    local found = ns.InstanceContext.Find(query)
    if #found == 1 then instanceID = found[1] end
  end
  if not instanceID then
    ns.Print(("No instance matches %q."):format(query))
    return
  end

  local plan = ns.Plan.Get()
  local inst
  for _, candidate in ipairs(plan.instances) do
    if candidate.instanceID == instanceID then inst = candidate end
  end

  local rows, ids = {}, {}
  local exists, cached = 0, 0
  for _, entry in ipairs(missingItems(inst)) do
    local itemID = entry.itemID
    local _, instantType = C_Item.GetItemInfoInstant(itemID)
    local name, _, quality = C_Item.GetItemInfo(itemID)
    local state = ns.Collection.ItemState(itemID)
    local row = {
      itemID = itemID, sourceID = entry.sourceID,
      exists = C_Item.DoesItemExistByID(itemID) == true,
      cached = C_Item.IsItemDataCachedByID(itemID) == true,
      instantType = instantType, name = name, quality = quality,
      hasFacts = state.hasFacts, hasLink = state.hasLink, pending = state.pending, queued = state.queued,
    }
    rows[#rows + 1] = row
    ids[#ids + 1] = itemID
    if row.exists then exists = exists + 1 end
    if row.cached then cached = cached + 1 end
  end

  ns.db.debug = ns.db.debug or {}
  ns.db.debug.items = { instanceID = instanceID, rows = rows }
  ns.db.debug.events = {}
  watching = true

  -- Ask again, so the event log shows how the client answers.
  ns.Collection.RequestItems(ids, true)
  for _, row in ipairs(rows) do
    local state = ns.Collection.ItemState(row.itemID)
    row.pending, row.queued = state.pending, state.queued
  end

  ns.Print(("%d missing items: %d exist, %d cached. Saved; wait 10 seconds, then /reload.")
    :format(#rows, exists, cached))
end

local function logEvent(event)
  return function(itemID, success)
    if not watching then return end
    local events = ns.db.debug.events
    if #events < MAX_EVENTS then
      events[#events + 1] = { event = event, itemID = itemID, success = success }
    end
  end
end

ns.On("GET_ITEM_INFO_RECEIVED", logEvent("GET_ITEM_INFO_RECEIVED"))
ns.On("ITEM_DATA_LOAD_RESULT", logEvent("ITEM_DATA_LOAD_RESULT"))

ns.RegisterCommand("items", probe, "diagnostic: save item loading state for an instance")
