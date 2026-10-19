-- Minimal WoW client stand-in for busted specs. Addon files are loaded the
-- way the client loads them: as chunks called with (addonName, namespace).
-- Client state lives in plain tables on M that specs set before acting.
local M = {}

M.printed = {}

-- Frames, font strings and textures keep the state specs read back (shown,
-- text, points, children); any other widget method is a no-op. Fields a
-- spec reads (text, itemID) go through rawget, since a missing key answers
-- with a no-op function.
local Widget = {}
Widget.__index = function(_, key)
  return Widget[key] or function() end
end
M.named = {}

function Widget:RegisterEvent(event) self.events[event] = true end
function Widget:SetScript(name, fn) self.scripts[name] = fn end
function Widget:GetScript(name) return self.scripts[name] end
function Widget:HookScript(name, fn) self.hooks[name] = fn end
function Widget:Show()
  if self.shown then return end
  self.shown = true
  if self.scripts.OnShow then self.scripts.OnShow(self) end
end
function Widget:Hide()
  if not self.shown then return end
  self.shown = false
  if self.scripts.OnHide then self.scripts.OnHide(self) end
end
function Widget:SetShown(shown) if shown then self:Show() else self:Hide() end end
function Widget:IsShown() return self.shown end
function Widget:SetText(text) self.text = text end
function Widget:GetText() return self.text end
function Widget:SetFormattedText(fmt, ...) self.text = fmt:format(...) end
function Widget:SetTexture(texture) self.texture = texture end
function Widget:SetDesaturated(on) self.desaturated = on end
function Widget:SetTextColor(r, g, b) self.color = { r, g, b } end
function Widget:SetHeight(h) self.height = h end
function Widget:GetHeight() return self.height or 0 end
function Widget:SetWidth(w) self.width = w end
function Widget:GetWidth() return self.width or 0 end
function Widget:SetSize(w, h) self.width, self.height = w, h end
function Widget.GetStringHeight() return 12 end
function Widget:ClearAllPoints() self.points = {} end
function Widget:SetPoint(...) self.points[#self.points + 1] = { ... } end
function Widget:GetPoint(i)
  local p = self.points[i or 1]
  if p then return unpack(p) end
end
function Widget:SetScrollChild(child) self.scrollChild = child end

local function newWidget(kind, name, parent, template)
  local w = setmetatable({
    kind = kind, name = name, parent = parent, template = template, events = {}, scripts = {}, hooks = {},
    points = {}, children = {}, shown = true,
  }, Widget)
  if parent then parent.children[#parent.children + 1] = w end
  if name then
    _G[name] = w
    M.named[#M.named + 1] = name
  end
  return w
end

function Widget:CreateFontString() return newWidget("FontString", nil, self) end
function Widget:CreateTexture() return newWidget("Texture", nil, self) end

local function newFrame(kind, name, parent, template)
  return newWidget(kind or "Frame", name, parent, template)
end

-- Text of every shown font string under a widget, in creation order.
function M.texts(widget)
  local out = {}
  local function walk(w)
    if not w.shown then return end
    local text = rawget(w, "text")
    if w.kind == "FontString" and text then out[#out + 1] = text end
    for _, child in ipairs(w.children) do walk(child) end
  end
  walk(widget)
  return out
end

local function itemLink(itemID, name)
  return ("|cff0070dd|Hitem:%d::::::::60:::::|h[%s]|h|r"):format(itemID, name)
end
M.itemLink = itemLink

function M.reset()
  M.printed = {}
  for _, name in ipairs(M.named) do _G[name] = nil end
  M.named = {}
  _G.print = function(...)
    local parts = {}
    for i = 1, select("#", ...) do parts[#parts + 1] = tostring(select(i, ...)) end
    M.printed[#M.printed + 1] = table.concat(parts, " ")
  end
  _G.CreateFrame = newFrame
  _G.SlashCmdList = {}
  _G.UIParent = newWidget("Frame", "UIParent")
  _G.UISpecialFrames = {}
  M.tooltip = { lines = {} }
  _G.GameTooltip = newWidget("GameTooltip", "GameTooltip")
  function _G.GameTooltip.SetOwner(_, owner) M.tooltip.owner = owner end
  function _G.GameTooltip.SetItemByID(_, itemID) M.tooltip.itemID = itemID end
  function _G.GameTooltip.AddLine(_, text) M.tooltip.lines[#M.tooltip.lines + 1] = text end
  _G.GameTooltip.shown = false

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
    -- Answers without the item cache, like the client. The icon is M.items[itemID].icon.
    GetItemInfoInstant = function(itemID)
      local item = M.items[itemID]
      return itemID, "Armor", "Cloth", "INVTYPE_CHEST", item and item.icon
    end,
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
