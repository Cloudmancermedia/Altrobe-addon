# Data contract

The data pipeline (`tools/build_data.lua`) writes `Data/Generated/*.lua`. The farm-plan evaluator (`Domain/Evaluator.lua`) reads it. This file is the only agreement between them. Change it here first, then in both.

Generated files are never edited by hand. Fixes go in the adapter, in an overlay with provenance, or upstream in All The Things.

## Shape

Generated files assign into the addon namespace:

```lua
local _, ns = ...
ns.Data = ns.Data or {}
ns.Data.instances = { ... }
```

### `ns.Data.manifest`

| Field | Type | Meaning |
|---|---|---|
| `upstream` | string | `"ATTWoWAddon/AllTheThings"` |
| `commit` | string | Pinned upstream commit SHA |
| `generatedAt` | string | ISO 8601 UTC timestamp |
| `gameBuild` | string | Forever build the data targets, e.g. `"1.60.1.70338"` |
| `extractorVersion` | string | Version of `tools/build_data.lua` |
| `counts` | table | `{ instances = n, encounters = n, sources = n }` |
| `instanceSources` | table | `[instanceID] = "camelot" \| "vanilla"` |

### `ns.Data.instances[instanceID]`

`instanceID` is the journal instance ID that All The Things uses in `inst(id, ...)`.

| Field | Type | Meaning |
|---|---|---|
| `id` | number | Journal instance ID |
| `name` | string | Display name |
| `kind` | `"dungeon"` \| `"raid"` | |
| `availability` | `"live"` \| `"announced"` \| `"assumed"` | Assumed instances never become active farming targets |
| `unlockDate` | string \| nil | ISO date when known, e.g. `"2026-12-09"` |
| `uiMapIDs` | number[] | From upstream `maps`, for runtime instance detection |
| `zoneTextAreaID` | number \| nil | From upstream, for runtime instance detection |
| `zoneTextAreaIDs` | number[] \| nil | Optional. Every area ID when upstream lists more than one (Dire Maul, Sunken Temple). `zoneTextAreaID` is the first |
| `encounters` | number[] | Encounter IDs in upstream order |

### `ns.Data.encounters[encounterID]`

| Field | Type | Meaning |
|---|---|---|
| `id` | number | Journal encounter ID |
| `instanceID` | number | Owning instance |
| `name` | string \| nil | |
| `npcID` | number \| nil | |

### `ns.Data.sources[sourceID]`

One row per item modified-appearance source (`s(sourceID, itemID, ...)` upstream). The visual appearance ID is not stored. The runtime resolves it with `C_TransmogCollection.GetItemInfo(itemID)`.

| Field | Type | Meaning |
|---|---|---|
| `id` | number | Source ID (matches the client, verified 12/12 in the spike) |
| `itemID` | number | |
| `instanceID` | number | |
| `encounterID` | number \| nil | nil for non-boss sources |
| `kind` | `"boss"` \| `"trash"` \| `"quest"` \| `"token"` \| `"vendor"` \| `"unresolved"` | |
| `quality` | number \| nil | 2 uncommon, 3 rare, 4 epic. nil when unknown |
| `slot` | string \| nil | `INVTYPE_*` equip location |
| `itemClass` | `"armor"` \| `"weapon"` \| nil | |
| `itemSubType` | string \| nil | Armor: `"CLOTH"`, `"LEATHER"`, `"MAIL"`, `"PLATE"`, `"GENERIC"` (cloaks, rings, trinkets). Weapon: the WeaponWise weapon keys, e.g. `"DAGGER"`, `"STAFF"`, `"MACE_2H"` |
| `classes` | number[] \| nil | Class IDs the item itself is restricted to |
| `faction` | `"Alliance"` \| `"Horde"` \| nil | |
| `minLevel` | number \| nil | |
| `difficultyID` | number \| nil | nil while Forever has one difficulty |
| `collectionRule` | `"group"` \| `"recipient"` \| `"unknown"` | `group`: dungeon bind-on-pickup quality 2 or 3. `recipient`: quality 4 or raid drops. `unknown` when quality is nil |
| `name` | string \| nil | Only filled for items the client may not know (assumed instances) |
| `npcID` | number \| nil | Optional. For `unresolved` sources that drop from an upstream NPC with no journal encounter, the NPC ID |
| `alsoFrom` | table[] \| nil | Optional. Other places the same source drops, each `{ instanceID, encounterID, kind }`. The row's own fields are the first place upstream lists it |

### `ns.Data.tokens[itemID]`

Reserved. Tier tokens are an open question until raids unlock. The evaluator treats an absent table as empty.

## Runtime inputs to the evaluator

The evaluator is a pure function. It never calls WoW APIs; adapters build these tables.

```lua
ns.Evaluator.Evaluate({
  data = ns.Data,
  proficiency = ns.Proficiency,   -- Data/ClassProficiency.lua
  profile = {
    classes = { "PRIEST", "ROGUE" },        -- class file tokens
    instanceKinds = { dungeon = true, raid = true },
    instances = nil,                        -- nil = all, else set of instanceIDs
    slots = nil,                            -- nil = all, else set of INVTYPE_*
    ownership = "appearance",               -- or "exact"
  },
  collection = {
    visualOf = { [sourceID] = visualID },   -- from C_TransmogCollection.GetItemInfo
    ownedVisuals = { [visualID] = true },
    ownedSources = { [sourceID] = true },
  },
  character = { classFile = "PRIEST", level = 60, faction = "Horde" },
  instanceContext = nil,                    -- or { instanceID = n }
  lockouts = { [instanceID] = { killed = { [encounterID] = true } } },
})
```

A source whose `visualOf` entry is missing is unresolved: it is never counted as owned and never lets the evaluator call a boss irrelevant.

## Evaluator output

```lua
{
  instances = {
    {
      instanceID = n, kind = "dungeon", availability = "live", active = true,
      progress = { PRIEST = { owned = n, total = n }, ROGUE = { ... } },
      encounters = {
        {
          encounterID = n,
          relevant = true,              -- at least one eligible missing or unresolved appearance
          killed = false,               -- from lockouts, independent of relevance
          opportunity = "sure",         -- "sure" (any group source missing), "roll", or nil
          missing = {
            { sourceID = n, itemID = n, classes = { "PRIEST" }, collectionRule = "group", unresolved = false },
          },
        },
      },
      trash = { missing = { ... } },
    },
  },
  current = n | nil,                    -- instanceID from instanceContext when it is a known, non-assumed instance
}
```
