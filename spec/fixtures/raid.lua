-- A hand-built live raid and an assumed raid in the shape of
-- docs/data-contract.md. Returns a function so every spec gets fresh tables.
return function()
  local data = {
    manifest = {
      upstream = "ATTWoWAddon/AllTheThings",
      commit = "fixture",
      generatedAt = "2026-10-13T00:00:00Z",
      gameBuild = "1.60.1.70338",
      extractorVersion = "fixture",
      counts = { instances = 2, encounters = 3, sources = 4 },
      instanceSources = { [200] = "vanilla", [300] = "camelot" },
    },
    instances = {
      [200] = {
        id = 200, name = "Fixture Spire", kind = "raid", availability = "live",
        uiMapIDs = { 2000 }, encounters = { 2001, 2002 },
      },
      [300] = {
        id = 300, name = "Fixture Citadel", kind = "raid", availability = "assumed",
        unlockDate = nil, uiMapIDs = {}, encounters = { 3001 },
      },
    },
    encounters = {
      [2001] = { id = 2001, instanceID = 200, name = "Raid Boss One" },
      [2002] = { id = 2002, instanceID = 200, name = "Raid Boss Two" },
      [3001] = { id = 3001, instanceID = 300, name = "Assumed Boss" },
    },
    sources = {
      [6001] = { id = 6001, itemID = 16001, instanceID = 200, encounterID = 2001, kind = "boss", quality = 4,
        slot = "INVTYPE_ROBE", itemClass = "armor", itemSubType = "CLOTH", collectionRule = "recipient" },
      [6002] = { id = 6002, itemID = 16002, instanceID = 200, encounterID = 2002, kind = "boss", quality = 4,
        slot = "INVTYPE_HEAD", itemClass = "armor", itemSubType = "PLATE", collectionRule = "recipient" },
      [6003] = { id = 6003, itemID = 16003, instanceID = 200, encounterID = 2002, kind = "boss", quality = 4,
        slot = "INVTYPE_SHOULDER", itemClass = "armor", itemSubType = "LEATHER", minLevel = 62,
        collectionRule = "recipient" },
      [7001] = { id = 7001, itemID = 17001, instanceID = 300, encounterID = 3001, kind = "boss", quality = 4,
        slot = "INVTYPE_CLOAK", itemClass = "armor", itemSubType = "GENERIC", collectionRule = "recipient",
        name = "Cloak of the Unknown" },
    },
  }

  local visualOf = { [6001] = 950, [6002] = 951, [6003] = 952 }

  return { data = data, visualOf = visualOf }
end
