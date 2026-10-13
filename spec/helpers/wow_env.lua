-- Minimal WoW client stand-in for busted specs. Addon files are loaded the
-- way the client loads them: as chunks called with (addonName, namespace).
local M = {}

M.printed = {}

local function newFrame()
  local frame = { events = {}, scripts = {}, hooks = {} }
  function frame:RegisterEvent(event) self.events[event] = true end
  function frame:SetScript(name, fn) self.scripts[name] = fn end
  function frame:HookScript(name, fn) self.hooks[name] = fn end
  return frame
end

function M.reset()
  M.printed = {}
  _G.print = function(...)
    local parts = {}
    for i = 1, select("#", ...) do parts[#parts + 1] = tostring(select(i, ...)) end
    M.printed[#M.printed + 1] = table.concat(parts, " ")
  end
  _G.CreateFrame = function() return newFrame() end
  _G.SlashCmdList = {}
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
