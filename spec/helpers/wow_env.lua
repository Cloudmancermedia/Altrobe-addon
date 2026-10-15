-- Minimal WoW client stand-in for busted specs. Addon files are loaded the
-- way the client loads them: as chunks called with (addonName, namespace).
-- Client state lives in plain tables on M that specs set before acting.
local M = {}

M.printed = {}

local function newFrame()
  local frame = { events = {}, scripts = {}, hooks = {} }
  function frame:RegisterEvent(event) self.events[event] = true end
  function frame:SetScript(name, fn) self.scripts[name] = fn end
  function frame:HookScript(name, fn) self.hooks[name] = fn end
  return frame
end

local function itemLink(itemID, name)
  return ("|cff0070dd|Hitem:%d::::::::60:::::|h[%s]|h|r"):format(itemID, name)
end
M.itemLink = itemLink

function M.reset()
  M.printed = {}
  _G.print = function(...)
    local parts = {}
    for i = 1, select("#", ...) do parts[#parts + 1] = tostring(select(i, ...)) end
    M.printed[#M.printed + 1] = table.concat(parts, " ")
  end
  _G.CreateFrame = function() return newFrame() end
  _G.SlashCmdList = {}

  -- C_Timer.After queues; M.runTimers() runs what is due.
  M.timers = {}
  _G.C_Timer = {
    After = function(delay, fn) M.timers[#M.timers + 1] = { delay = delay, fn = fn } end,
  }

  M.inCombat = false
  _G.InCombatLockdown = function() return M.inCombat end
  M.now = 0
  _G.GetTime = function() return M.now end

  M.player = { className = "Priest", classFile = "PRIEST", classID = 5, level = 60, faction = "Horde" }
  _G.UnitClass = function() return M.player.className, M.player.classFile, M.player.classID end
  _G.UnitLevel = function() return M.player.level end
  _G.UnitFactionGroup = function() return M.player.faction, M.player.faction end

  -- Transmog collection: visualOf[sourceID] = visualID; owned sets by ID.
  -- appearanceInfo = false removes GetAppearanceInfoBySource's answer.
  M.transmog = { visualOf = {}, ownedSources = {}, ownedVisuals = {}, calls = 0, appearanceInfo = true }
  local t = M.transmog
  _G.C_TransmogCollection = {
    GetSourceInfo = function(sourceID)
      t.calls = t.calls + 1
      local visual = t.visualOf[sourceID]
      if visual == nil then return nil end
      return { sourceID = sourceID, visualID = visual, categoryID = 1 }
    end,
    GetAppearanceInfoBySource = function(sourceID)
      t.calls = t.calls + 1
      local visual = t.visualOf[sourceID]
      if not t.appearanceInfo or visual == nil then return nil end
      return {
        appearanceID = visual,
        appearanceIsCollected = t.ownedVisuals[visual] == true,
        sourceIsCollected = t.ownedSources[sourceID] == true,
      }
    end,
    PlayerHasTransmogItemModifiedAppearance = function(sourceID)
      t.calls = t.calls + 1
      return t.ownedSources[sourceID] == true
    end,
    GetItemInfo = function() return nil end,
  }

  -- Items: M.items[itemID] = { name, quality, bindType, cached }. Uncached
  -- items answer nil until a spec caches them and fires the load event.
  M.items = {}
  M.itemRequests = {}
  _G.C_Item = {
    GetItemInfo = function(itemID)
      local item = M.items[itemID]
      if not (item and item.cached) then return nil end
      return item.name, itemLink(itemID, item.name), item.quality, 50, 45, "Armor", "Cloth", 1,
        "INVTYPE_CHEST", 0, 100, 4, 1, item.bindType
    end,
    RequestLoadItemDataByID = function(itemID) M.itemRequests[#M.itemRequests + 1] = itemID end,
  }

  -- Where the player is.
  M.mapID = nil
  M.instance = { name = "Eastern Kingdoms", type = "none" }
  _G.C_Map = { GetBestMapForUnit = function() return M.mapID end }
  _G.GetInstanceInfo = function()
    return M.instance.name, M.instance.type, 1, "Normal", 5, 0, false, M.instance.mapID or 0
  end

  -- Saved instances: { name, locked, encounters = { { name, killed } } }.
  M.saved = {}
  M.raidInfoRequests = 0
  _G.RequestRaidInfo = function() M.raidInfoRequests = M.raidInfoRequests + 1 end
  _G.GetNumSavedInstances = function() return #M.saved end
  _G.GetSavedInstanceInfo = function(i)
    local s = M.saved[i]
    return s.name, 1000 + i, 3600, 1, s.locked, false, 0, s.isRaid or false, 5, "Normal", #s.encounters, 0, false, 0
  end
  _G.GetSavedInstanceEncounterInfo = function(i, e)
    local boss = M.saved[i].encounters[e]
    return boss.name, 0, boss.killed, false
  end
end

-- Runs queued timers, including ones they queue, up to a limit.
function M.runTimers()
  for _ = 1, 100 do
    if #M.timers == 0 then return end
    local due = M.timers
    M.timers = {}
    for _, timer in ipairs(due) do timer.fn() end
  end
  error("timers kept rescheduling")
end

-- Loads addon files in TOC order into a fresh namespace and returns it.
function M.load(files)
  local ns = {}
  for _, path in ipairs(files) do
    local chunk = assert(loadfile(path))
    chunk("Altrobe", ns)
  end
  return ns
end

-- Fires an event through the namespace's event frame.
function M.fire(ns, event, ...)
  ns.frame.scripts.OnEvent(ns.frame, event, ...)
end

function M.output()
  return table.concat(M.printed, "\n")
end

return M
