local addonName, ns = ...

ns.name = addonName
ns.commands = {}
ns.handlers = {}

function ns.Print(...)
  print("|cffc79c6eAltrobe|r:", ...)
end

function ns.RegisterCommand(name, handler, help)
  ns.commands[name] = { handler = handler, help = help }
end

function ns.HandleSlash(msg)
  local cmd, rest = (msg or ""):match("^%s*(%S*)%s*(.-)%s*$")
  local entry = ns.commands[cmd:lower()]
  if entry then
    entry.handler(rest)
    return
  end
  local names = {}
  for name in pairs(ns.commands) do names[#names + 1] = name end
  table.sort(names)
  ns.Print("commands:")
  for _, name in ipairs(names) do
    ns.Print("  /altrobe " .. name .. " - " .. ns.commands[name].help)
  end
end

SLASH_ALTROBE1 = "/altrobe"
SlashCmdList.ALTROBE = ns.HandleSlash

local frame = CreateFrame("Frame")
ns.frame = frame

function ns.On(event, fn)
  if not ns.handlers[event] then
    ns.handlers[event] = {}
    frame:RegisterEvent(event)
  end
  table.insert(ns.handlers[event], fn)
end

frame:SetScript("OnEvent", function(_, event, ...)
  for _, fn in ipairs(ns.handlers[event] or {}) do fn(...) end
end)

ns.On("ADDON_LOADED", function(loaded)
  if loaded ~= addonName then return end
  AltrobeDB = AltrobeDB or {}
  ns.db = AltrobeDB
end)
