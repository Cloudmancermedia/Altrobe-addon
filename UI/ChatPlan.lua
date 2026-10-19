-- /altrobe plan [instance name]: the farm plan for one instance, printed to
-- the chat frame in short lines.
local _, ns = ...

local OPPORTUNITY_COLOURS = { sure = "ff1eff00", roll = "ffffd100", unknown = "ff9d9d9d" }
local KILLED = "|cffff6060killed|r"
local ITEMS_PER_LINE = 3
local INDENT, ITEM_INDENT = "  ", "      "

local waitingQuery

local function coloured(opportunity)
  return ("|c%s%s|r"):format(OPPORTUNITY_COLOURS[opportunity] or OPPORTUNITY_COLOURS.unknown, opportunity or "unknown")
end

local function bossName(encounterID)
  return ns.WindowModel.BossName(ns.Data, encounterID)
end

local function findInstance(plan, instanceID)
  for _, inst in ipairs(plan.instances) do
    if inst.instanceID == instanceID then return inst end
  end
end

-- Prints the instance's plan. Item links where the client has them, item
-- IDs otherwise; the missing ones are asked for so the next print has them.
local function printInstance(plan, instanceID)
  local data = ns.Data.instances[instanceID]
  local inst = findInstance(plan, instanceID)
  local note = ""
  if data.availability == "assumed" then
    note = " - not in Forever yet"
  elseif data.availability == "announced" then
    note = " - announced"
  end
  ns.Print(("%s (%s)%s"):format(data.name, data.kind, note))

  local progress = {}
  for _, classFile in ipairs(ns.Profile.Get().classes) do
    local p = inst.progress[classFile]
    if p then progress[#progress + 1] = ("%s %d/%d"):format(classFile, p.owned, p.total) end
  end
  print(INDENT .. "Collected: " .. table.concat(progress, ", "))

  local loading, flagged, wanted = false, false, {}
  local function label(entry)
    local link = ns.Collection.ItemLink(entry.itemID)
    if not link then
      loading = true
      wanted[#wanted + 1] = entry.itemID
    end
    local text = link or ("item:" .. entry.itemID)
    if entry.unresolved then text, flagged = text .. "?", true end
    if entry.levelLocked then text, flagged = text .. "*", true end
    return text
  end

  local shown = 0
  for position, enc in ipairs(inst.encounters) do
    if enc.relevant then
      shown = shown + 1
      local line = ("%s%d. %s - %s - %d missing"):format(INDENT, position, bossName(enc.encounterID),
        coloured(enc.opportunity), #enc.missing)
      if enc.killed then line = line .. " - " .. KILLED end
      print(line)
      local chunk = {}
      for _, entry in ipairs(enc.missing) do
        chunk[#chunk + 1] = label(entry)
        if #chunk == ITEMS_PER_LINE then
          print(ITEM_INDENT .. table.concat(chunk, " "))
          chunk = {}
        end
      end
      if #chunk > 0 then print(ITEM_INDENT .. table.concat(chunk, " ")) end
    end
  end
  if shown == 0 then print(INDENT .. "No boss here drops anything you're missing.") end

  print(("%sTrash: %d missing, Other: %d missing"):format(INDENT, #inst.trash.missing, #inst.other.missing))
  if inst.notInClient > 0 then
    print(("%s%d item%s not in the client yet"):format(INDENT, inst.notInClient, inst.notInClient == 1 and "" or "s"))
  end
  if flagged then print(INDENT .. "? incomplete data, * above your level") end
  if loading then
    print(INDENT .. "Item names are loading. Run /altrobe plan again for links.")
    ns.Collection.RequestItems(wanted, true)
  end
end

local function show(query)
  if InCombatLockdown() then
    waitingQuery = query
    ns.Print("in combat. The plan will print after combat.")
    return
  end
  local instanceID
  if query == "" then
    local context = ns.InstanceContext.Current()
    instanceID = context and context.instanceID
    if not instanceID then
      ns.Print("You're not in a dungeon or raid Altrobe knows. Try /altrobe plan <instance name>.")
      return
    end
  else
    local found = ns.InstanceContext.Find(query)
    if #found == 0 then
      ns.Print(("No instance matches %q."):format(query))
      return
    elseif #found > 1 then
      ns.Print("Which one? " .. ns.InstanceContext.Names(found))
      return
    end
    instanceID = found[1]
  end
  printInstance(ns.Plan.Get(), instanceID)
end

ns.On("PLAYER_REGEN_ENABLED", function()
  if waitingQuery then
    local query = waitingQuery
    waitingQuery = nil
    show(query)
  end
end)

ns.RegisterCommand("plan", show, "bosses here (or in the named instance) that drop appearances you're missing")
