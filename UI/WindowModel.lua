-- Turns the evaluator's plan for one instance into what a view shows: a
-- title, per-class progress, the relevant bosses with their missing items,
-- and the summary counts. Pure: no WoW API calls, so views stay thin.
local _, ns = ...

local WindowModel = {}
ns.WindowModel = WindowModel

local NOTES = { assumed = "not in Forever yet", announced = "announced" }

function WindowModel.BossName(data, encounterID)
  local enc = (data.encounters or {})[encounterID] or {}
  return enc.name or (enc.npcID and ("NPC " .. enc.npcID)) or ("Boss " .. encounterID)
end

local function findInstance(plan, instanceID)
  for _, inst in ipairs(plan and plan.instances or {}) do
    if inst.instanceID == instanceID then return inst end
  end
end

-- The view of one instance, or nil when the plan does not have it. Bosses
-- keep their position in the instance as their number, so gaps show where
-- bosses with nothing missing were left out.
function WindowModel.Build(plan, data, classes, instanceID)
  local inst = findInstance(plan, instanceID)
  if not inst then return nil end
  local info = data.instances[instanceID]

  local progress = {}
  for _, classFile in ipairs(classes) do
    local p = inst.progress[classFile]
    if p then progress[#progress + 1] = { classFile = classFile, owned = p.owned, total = p.total } end
  end

  local flags = { unresolved = false, levelLocked = false }
  local bosses = {}
  for position, enc in ipairs(inst.encounters) do
    if enc.relevant then
      local items = {}
      for _, entry in ipairs(enc.missing) do
        items[#items + 1] = {
          itemID = entry.itemID, sourceID = entry.sourceID, unresolved = entry.unresolved == true,
          levelLocked = entry.levelLocked == true, classes = entry.classes,
        }
        if entry.unresolved then flags.unresolved = true end
        if entry.levelLocked then flags.levelLocked = true end
      end
      bosses[#bosses + 1] = {
        number = position, encounterID = enc.encounterID, name = WindowModel.BossName(data, enc.encounterID),
        opportunity = enc.opportunity, killed = enc.killed == true, items = items,
      }
    end
  end

  return {
    instanceID = instanceID, title = info.name, kind = info.kind, note = NOTES[info.availability],
    progress = progress, bosses = bosses, flags = flags,
    trash = #inst.trash.missing, other = #inst.other.missing, notInClient = inst.notInClient or 0,
  }
end
