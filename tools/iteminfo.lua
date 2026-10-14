-- Item facts for the Forever client, read from two pinned upstream tables:
--
-- 1. Wago DB2 exports of the client build, under
--    .contrib/.db/forever/.config/.wago/<Table>.<build>.csv:
--    Item (class, subclass, inventory type; covers every source item),
--    ItemSearchName (quality, class mask, required level, name; partial),
--    ItemModifiedAppearance (source ID -> item ID), AreaTable (area names).
-- 2. The ItemDB that upstream harvested from the Forever client,
--    .contrib/.db/forever/.config/exports/ItemDB.lua (quality `q`, binding
--    `b`, `classes`, `lvl`, name; partial). Loaded in the sandbox.
--
-- ItemSearchName wins over ItemDB when it has the row. For quality, which
-- decides the collection rule, a disagreement leaves the value nil instead.
local loader = require("tools.loader")

local M = {}

local WAGO = "/.contrib/.db/forever/.config/.wago/"
local ITEMDB = "/.contrib/.db/forever/.config/exports/ItemDB.lua"

-- Class IDs playable on Forever (no Death Knight 6, no Monk 10).
local PLAYABLE_CLASSES = { 1, 2, 3, 4, 5, 7, 8, 9, 11 }

-- Enum.InventoryType -> equip location. https://warcraft.wiki.gg/wiki/Enum.InventoryType
local INVTYPE = {
  [1] = "INVTYPE_HEAD", [2] = "INVTYPE_NECK", [3] = "INVTYPE_SHOULDER", [4] = "INVTYPE_BODY",
  [5] = "INVTYPE_CHEST", [6] = "INVTYPE_WAIST", [7] = "INVTYPE_LEGS", [8] = "INVTYPE_FEET",
  [9] = "INVTYPE_WRIST", [10] = "INVTYPE_HAND", [11] = "INVTYPE_FINGER", [12] = "INVTYPE_TRINKET",
  [13] = "INVTYPE_WEAPON", [14] = "INVTYPE_SHIELD", [15] = "INVTYPE_RANGED", [16] = "INVTYPE_CLOAK",
  [17] = "INVTYPE_2HWEAPON", [18] = "INVTYPE_BAG", [19] = "INVTYPE_TABARD", [20] = "INVTYPE_ROBE",
  [21] = "INVTYPE_WEAPONMAINHAND", [22] = "INVTYPE_WEAPONOFFHAND", [23] = "INVTYPE_HOLDABLE",
  [24] = "INVTYPE_AMMO", [25] = "INVTYPE_THROWN", [26] = "INVTYPE_RANGEDRIGHT", [27] = "INVTYPE_QUIVER",
  [28] = "INVTYPE_RELIC",
}
M.INVTYPE = INVTYPE

-- Weapon subclass -> WeaponWise key (WeaponWise/Data/WeaponTypes.lua).
local WEAPON_KEYS = {
  [0] = "AXE_1H", [1] = "AXE_2H", [2] = "BOW", [3] = "GUN", [4] = "MACE_1H", [5] = "MACE_2H",
  [6] = "POLEARM", [7] = "SWORD_1H", [8] = "SWORD_2H", [10] = "STAFF", [13] = "FIST", [15] = "DAGGER",
  [16] = "THROWN", [18] = "CROSSBOW", [19] = "WAND",
}
M.WEAPON_KEYS = WEAPON_KEYS

-- Armor subclass -> armor type. 0 is miscellaneous (rings, necks, trinkets,
-- shirts, tabards, off-hand frills). Relics (7-9) and bucklers (5) have none.
local ARMOR_KEYS = { [0] = "GENERIC", [1] = "CLOTH", [2] = "LEATHER", [3] = "MAIL", [4] = "PLATE", [6] = "SHIELD" }
local INVTYPE_CLOAK = 16

function M.parseCSVLine(line)
  local out, i, n = {}, 1, #line
  while i <= n + 1 do
    if line:sub(i, i) == '"' then
      local buf, j = {}, i + 1
      while j <= n do
        local c = line:sub(j, j)
        if c == '"' then
          if line:sub(j + 1, j + 1) == '"' then
            buf[#buf + 1] = '"'
            j = j + 2
          else
            j = j + 1
            break
          end
        else
          buf[#buf + 1] = c
          j = j + 1
        end
      end
      out[#out + 1] = table.concat(buf)
      i = j + 1
    else
      local j = line:find(",", i, true) or n + 1
      out[#out + 1] = line:sub(i, j - 1)
      i = j + 1
    end
  end
  return out
end

-- Reads a Wago CSV into { [ID] = { column = string } }.
local function readCSV(path)
  local f = io.open(path, "rb")
  if not f then error("missing upstream table " .. path, 0) end
  local rows, header = {}, nil
  for line in f:lines() do
    line = line:gsub("\r$", "")
    if not header then
      header = M.parseCSVLine((line:gsub("^\239\187\191", "")))
    elseif line ~= "" then
      local fields, row = M.parseCSVLine(line), {}
      for k, name in ipairs(header) do row[name] = fields[k] end
      local id = tonumber(row.ID)
      if id then rows[id] = row end
    end
  end
  f:close()
  return rows
end

local function classesFromMask(mask)
  mask = tonumber(mask)
  if not mask or mask == -1 or mask == 0 then return nil end
  local out, all = {}, true
  for _, classID in ipairs(PLAYABLE_CLASSES) do
    if bit.band(mask, bit.lshift(1, classID - 1)) ~= 0 then
      out[#out + 1] = classID
    else
      all = false
    end
  end
  if all or #out == 0 then return nil end
  return out
end

local function sortedCopy(list)
  if type(list) ~= "table" then return nil end
  local out = {}
  for _, v in ipairs(list) do out[#out + 1] = v end
  table.sort(out)
  return out
end

local function levelOrNil(v)
  v = tonumber(v)
  if v and v > 1 then return v end
  return nil
end

local Info = {}
Info.__index = Info

-- Returns everything known about an item. Fields absent upstream are nil.
function Info:lookup(itemID)
  local row = { itemID = itemID }
  local item, sn, idb = self.item[itemID], self.searchName[itemID], self.itemDB[itemID]

  if item then
    row.classID, row.subclassID = tonumber(item.ClassID), tonumber(item.SubclassID)
    row.inventoryType = tonumber(item.InventoryType)
  elseif idb then
    row.classID, row.subclassID, row.inventoryType = idb.class, idb.subclass, idb.inventoryType
  end

  local snQuality = sn and tonumber(sn.OverallQualityID)
  local idbQuality = idb and idb.q
  if snQuality and idbQuality and snQuality ~= idbQuality then
    row.qualityConflict = true
  else
    row.quality = snQuality or idbQuality
  end

  if idb and idb.b == 1 then row.bop = true end

  if sn then
    row.classes = classesFromMask(sn.AllowableClass)
    row.minLevel = levelOrNil(sn.RequiredLevel)
    row.name = sn.Display_lang
  elseif idb then
    row.classes = sortedCopy(idb.classes)
    row.minLevel = levelOrNil(idb.lvl)
    row.name = idb.name
  end
  return row
end

-- Slot, item class and subtype for a looked-up row. Empty when the client
-- tables do not know the item.
function M.describe(row)
  if not row.classID then return {} end
  local out = { slot = INVTYPE[row.inventoryType] }
  if row.classID == 2 then
    out.itemClass = "weapon"
    out.itemSubType = WEAPON_KEYS[row.subclassID]
  elseif row.classID == 4 then
    out.itemClass = "armor"
    if row.inventoryType == INVTYPE_CLOAK then
      out.itemSubType = "GENERIC"
    else
      out.itemSubType = ARMOR_KEYS[row.subclassID]
    end
  end
  return out
end

function M.load(root, build)
  local self = setmetatable({}, Info)
  self.item = readCSV(root .. WAGO .. "Item." .. build .. ".csv")
  self.searchName = readCSV(root .. WAGO .. "ItemSearchName." .. build .. ".csv")

  self.appearanceItem = {}
  for id, row in pairs(readCSV(root .. WAGO .. "ItemModifiedAppearance." .. build .. ".csv")) do
    self.appearanceItem[id] = tonumber(row.ItemID)
  end

  self.areaNames = {}
  for id, row in pairs(readCSV(root .. WAGO .. "AreaTable." .. build .. ".csv")) do
    self.areaNames[id] = row.AreaName_lang
  end

  local _, app = loader.loadFile(root .. ITEMDB)
  self.itemDB = rawget(app, "ItemDB") or {}
  return self
end

return M
