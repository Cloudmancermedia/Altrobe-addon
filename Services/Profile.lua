-- The active profile: which classes to collect for, the ownership mode and
-- the instance kinds. It lives in AltrobeDB.profile. Classes left unset
-- follow the logged-in character's class.
local _, ns = ...

local Profile = {}
ns.Profile = Profile

local MODES = { appearance = true, exact = true }

local function saved()
  if not ns.db then return {} end
  ns.db.profile = ns.db.profile or {}
  return ns.db.profile
end

local function currentClass()
  local _, classFile = UnitClass("player")
  return classFile
end

local function copy(list)
  local out = {}
  for i, v in ipairs(list) do out[i] = v end
  return out
end

-- The evaluator's profile input (docs/data-contract.md).
function Profile.Get()
  local p = saved()
  return {
    classes = p.classes and copy(p.classes) or { currentClass() },
    ownership = p.ownership or "appearance",
    instanceKinds = { dungeon = true, raid = true },
  }
end

function Profile.Character()
  local faction = UnitFactionGroup("player")
  return { classFile = currentClass(), level = UnitLevel("player"), faction = faction }
end

local function changed()
  if ns.Plan then ns.Plan.Invalidate() end
end

function Profile.SetClasses(classes)
  saved().classes = copy(classes)
  changed()
end

function Profile.SetOwnership(mode)
  saved().ownership = mode
  changed()
end

ns.RegisterCommand("class", function(rest)
  if rest == "" then
    ns.Print("classes: " .. table.concat(Profile.Get().classes, ", "))
    return
  end
  local classes, seen = {}, {}
  for word in rest:gmatch("%S+") do
    local classFile = word:upper()
    if not ns.Proficiency.ClassIDs[classFile] then
      ns.Print("unknown class: " .. classFile)
      return
    end
    if not seen[classFile] then
      seen[classFile] = true
      classes[#classes + 1] = classFile
    end
  end
  Profile.SetClasses(classes)
  ns.Print("classes: " .. table.concat(classes, ", "))
end, "set the classes to collect for, e.g. /altrobe class priest rogue")

ns.RegisterCommand("mode", function(rest)
  local mode = rest:lower()
  if not MODES[mode] then
    ns.Print("usage: /altrobe mode appearance|exact (now " .. Profile.Get().ownership .. ")")
    return
  end
  Profile.SetOwnership(mode)
  ns.Print("mode: " .. mode)
end, "appearance or exact: own an appearance through any item, or only the exact item")
