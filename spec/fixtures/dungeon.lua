-- A hand-built dungeon in the shape of docs/data-contract.md.
-- Returns a function so every spec gets fresh tables it can change.
return function()
  local data = {
    manifest = {
      upstream = "ATTWoWAddon/AllTheThings",
      commit = "fixture",
      generatedAt = "2026-10-13T00:00:00Z",
      gameBuild = "1.60.1.70338",
      extractorVersion = "fixture",
      counts = { instances = 1, encounters = 3, sources = 11 },
      instanceSources = { [100] = "vanilla" },
    },
    instances = {
      [100] = {
        id = 100, name = "Fixture Keep", kind = "dungeon", availability = "live",
        uiMapIDs = { 1000 }, zoneTextAreaID = 1100, encounters = { 1003, 1001, 1002 },
      },
    },
    encounters = {
      [1001] = { id = 1001, instanceID = 100, name = "First Boss", npcID = 1 },
      [1002] = { id = 1002, instanceID = 100, name = "Second Boss", npcID = 2 },
      [1003] = { id = 1003, instanceID = 100, name = "Opening Boss", npcID = 3 },
    },
    sources = {},
    tokens = {},
  }

  local function add(row)
    row.instanceID = row.instanceID or 100
    row.quality = row.quality or 3
    row.itemID = row.itemID or row.id + 10000
    row.collectionRule = row.collectionRule or "group"
    data.sources[row.id] = row
  end

  -- 5001 and 5002 share visual 900.
  add({ id = 5001, encounterID = 1001, kind = "boss", slot = "INVTYPE_CHEST", itemClass = "armor",
    itemSubType = "CLOTH" })
  add({ id = 5002, encounterID = 1002, kind = "boss", slot = "INVTYPE_CHEST", itemClass = "armor",
    itemSubType = "CLOTH" })
  add({ id = 5003, encounterID = 1001, kind = "boss", slot = "INVTYPE_LEGS", itemClass = "armor",
    itemSubType = "LEATHER" })
  add({ id = 5004, encounterID = 1002, kind = "boss", slot = "INVTYPE_WEAPON", itemClass = "weapon",
    itemSubType = "DAGGER" })
  add({ id = 5005, encounterID = 1003, kind = "boss", slot = "INVTYPE_HEAD", itemClass = "armor",
    itemSubType = "PLATE" })
  add({ id = 5006, encounterID = 1003, kind = "boss", slot = "INVTYPE_CLOAK", itemClass = "armor",
    itemSubType = "GENERIC", classes = { 5 } })
  add({ id = 5007, encounterID = 1003, kind = "boss", slot = "INVTYPE_FINGER", itemClass = "armor",
    itemSubType = "GENERIC", faction = "Alliance" })
  add({ id = 5008, kind = "trash", slot = "INVTYPE_WRIST", itemClass = "armor", itemSubType = "CLOTH" })
  add({ id = 5009, kind = "unresolved", slot = "INVTYPE_NECK", itemClass = "armor", itemSubType = "GENERIC" })
  add({ id = 5010, kind = "quest", slot = "INVTYPE_HAND", itemClass = "armor", itemSubType = "CLOTH" })
  add({ id = 5011, kind = "vendor", slot = "INVTYPE_FEET", itemClass = "armor", itemSubType = "CLOTH" })

  local visualOf = {
    [5001] = 900, [5002] = 900, [5003] = 901, [5004] = 902, [5005] = 903, [5006] = 904,
    [5007] = 905, [5008] = 906, [5009] = 907, [5010] = 908, [5011] = 909,
  }

  return { data = data, visualOf = visualOf }
end
