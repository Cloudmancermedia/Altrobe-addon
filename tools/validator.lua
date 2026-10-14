-- Checks normalized data against docs/data-contract.md. Returns a sorted list
-- of error strings; empty means valid.
local iteminfo = require("tools.iteminfo")

local M = {}

local function set(list)
  local s = {}
  for _, v in ipairs(list) do s[v] = true end
  return s
end

local INSTANCE_KIND = set({ "dungeon", "raid" })
local AVAILABILITY = set({ "live", "announced", "assumed" })
local PROVENANCE = set({ "camelot", "vanilla" })
local SOURCE_KIND = set({ "boss", "trash", "quest", "token", "vendor", "unresolved" })
local ITEM_CLASS = set({ "armor", "weapon" })
local RULE = set({ "group", "recipient", "unknown" })
local FACTION = set({ "Alliance", "Horde" })
local ARMOR_SUBTYPE = set({ "CLOTH", "LEATHER", "MAIL", "PLATE", "GENERIC", "SHIELD" })
local WEAPON_SUBTYPE = {}
for _, key in pairs(iteminfo.WEAPON_KEYS) do WEAPON_SUBTYPE[key] = true end
local SLOT = {}
for _, name in pairs(iteminfo.INVTYPE) do SLOT[name] = true end

local function q(v) return string.format("%q", tostring(v)) end

function M.validate(data)
  local errors = {}
  local function fail(fmt, ...) errors[#errors + 1] = string.format(fmt, ...) end

  for key, inst in pairs(data.instances) do
    local where = "instance " .. key
    if inst.id ~= key then fail("%s: id is %s", where, tostring(inst.id)) end
    if type(inst.name) ~= "string" then fail("%s: no name", where) end
    if not INSTANCE_KIND[inst.kind] then fail("%s: kind %s", where, q(inst.kind)) end
    if not AVAILABILITY[inst.availability] then fail("%s: availability %s", where, q(inst.availability)) end
    if inst.unlockDate ~= nil and not tostring(inst.unlockDate):match("^%d%d%d%d%-%d%d%-%d%d$") then
      fail("%s: unlockDate %s", where, q(inst.unlockDate))
    end
    if type(inst.uiMapIDs) ~= "table" then fail("%s: uiMapIDs is not a list", where) end
    for _, encounterID in ipairs(inst.encounters or {}) do
      local enc = data.encounters[encounterID]
      if not enc then
        fail("%s: encounter %d does not exist", where, encounterID)
      elseif enc.instanceID ~= key then
        fail("%s: encounter %d belongs to instance %s", where, encounterID, tostring(enc.instanceID))
      end
    end
    if data.instanceSources[key] == nil then fail("%s: no instanceSources entry", where) end
  end

  for key, value in pairs(data.instanceSources) do
    if not PROVENANCE[value] then fail("instanceSources[%s] %s", tostring(key), q(value)) end
    if not data.instances[key] then fail("instanceSources[%s]: instance does not exist", tostring(key)) end
  end

  for key, enc in pairs(data.encounters) do
    local where = "encounter " .. key
    if enc.id ~= key then fail("%s: id is %s", where, tostring(enc.id)) end
    if not data.instances[enc.instanceID] then
      fail("%s: instance %s does not exist", where, tostring(enc.instanceID))
    end
    if type(enc.journal) ~= "boolean" then
      fail("%s: journal is not a boolean", where)
    elseif enc.journal and type(key) == "number" and key < 0 then
      fail("%s: journal encounter with a negative ID", where)
    elseif not enc.journal and key ~= -(tonumber(enc.npcID) or 0) then
      fail("%s: not keyed by -npcID", where)
    end
    if enc.name ~= nil and type(enc.name) ~= "string" then fail("%s: name is not a string", where) end
  end

  local function checkRelationship(where, rel)
    if not data.instances[rel.instanceID] then
      fail("%s: instance %s does not exist", where, tostring(rel.instanceID))
    end
    if rel.encounterID ~= nil then
      local enc = data.encounters[rel.encounterID]
      if not enc then
        fail("%s: encounter %s does not exist", where, tostring(rel.encounterID))
      elseif enc.instanceID ~= rel.instanceID then
        fail("%s: encounter %d belongs to instance %s", where, rel.encounterID, tostring(enc.instanceID))
      end
    end
    if not SOURCE_KIND[rel.kind] then fail("%s: kind %s", where, q(rel.kind)) end
    if (rel.kind == "boss") ~= (rel.encounterID ~= nil) then
      fail("%s: kind %s with encounter %s", where, q(rel.kind), tostring(rel.encounterID))
    end
  end

  for key, src in pairs(data.sources) do
    local where = "source " .. key
    if src.id ~= key then fail("%s: id is %s", where, tostring(src.id)) end
    if type(src.itemID) ~= "number" then fail("%s: no itemID", where) end
    checkRelationship(where, src)
    for i, rel in ipairs(src.alsoFrom or {}) do checkRelationship(where .. " alsoFrom[" .. i .. "]", rel) end
    if src.quality ~= nil and (type(src.quality) ~= "number" or src.quality < 0 or src.quality > 7) then
      fail("%s: quality %s", where, q(src.quality))
    end
    if src.slot ~= nil and not SLOT[src.slot] then fail("%s: slot %s", where, q(src.slot)) end
    if src.itemClass ~= nil and not ITEM_CLASS[src.itemClass] then
      fail("%s: itemClass %s", where, q(src.itemClass))
    end
    if src.itemSubType ~= nil then
      local allowed = (src.itemClass == "armor" and ARMOR_SUBTYPE)
        or (src.itemClass == "weapon" and WEAPON_SUBTYPE) or {}
      if not allowed[src.itemSubType] then
        fail("%s: itemSubType %s for itemClass %s", where, q(src.itemSubType), q(src.itemClass))
      end
    end
    if src.faction ~= nil and not FACTION[src.faction] then fail("%s: faction %s", where, q(src.faction)) end
    if not RULE[src.collectionRule] then fail("%s: collectionRule %s", where, q(src.collectionRule)) end
    if src.quality == nil and src.collectionRule ~= "unknown" then
      fail("%s: collectionRule %s with unknown quality", where, q(src.collectionRule))
    end
  end

  table.sort(errors)
  return errors
end

return M
