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
| `id` | number | Journal encounter ID, or `-npcID` for a boss upstream records only as an NPC |
| `instanceID` | number | Owning instance |
| `name` | string \| nil | Boss name from the best pinned upstream source. Used for display and to match lockouts, which the client reports by name |
| `npcID` | number \| nil | |
| `journal` | boolean | false for `-npcID` bosses |

Upstream models most classic dungeon bosses as an NPC with no journal encounter. Those NPCs become encounters keyed by the negative NPC ID, listed in the instance's `encounters` in upstream order, and their drops are `kind = "boss"` sources with that `encounterID`.

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
| `itemSubType` | string \| nil | Armor: `"CLOTH"`, `"LEATHER"`, `"MAIL"`, `"PLATE"`, `"SHIELD"`, `"GENERIC"` (cloaks, rings, trinkets). Weapon: the WeaponWise weapon keys, e.g. `"DAGGER"`, `"STAFF"`, `"MACE_2H"` |
| `classes` | number[] \| nil | Class IDs the item itself is restricted to |
| `faction` | `"Alliance"` \| `"Horde"` \| nil | |
| `minLevel` | number \| nil | |
| `difficultyID` | number \| nil | nil while Forever has one difficulty |
| `collectionRule` | `"group"` \| `"recipient"` \| `"unknown"` | `group`: dungeon bind-on-pickup quality 2 or 3. `recipient`: quality 4 or raid drops. `unknown` when quality is nil |
| `name` | string \| nil | Only filled for items the client may not know (assumed instances) |
| `npcID` | number \| nil | Optional. The NPC a source drops from, when upstream names one |
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
  itemFacts = { [itemID] = { quality = 3, bindType = 1 } },  -- from C_Item.GetItemInfo; may be partial
  character = { classFile = "PRIEST", level = 60, faction = "Horde" },
  instanceContext = nil,                    -- or { instanceID = n }
  lockouts = { [instanceID] = { killed = { [encounterID] = true } } },
})
```

Ownership is decided first. In appearance mode a source is owned when its visual is known and owned; in exact mode, when its source is owned. An owned source is never listed as missing, even when its data is incomplete. A source that is not owned and has incomplete data is unresolved: it never lets the evaluator call a boss irrelevant.

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
          opportunity = "sure",         -- "sure" (any group source missing), "roll", "unknown", or nil
          missing = {
            { sourceID = n, itemID = n, classes = { "PRIEST" }, collectionRule = "group", unresolved = false,
              levelLocked = false },
          },
        },
      },
      trash = { missing = { ... } },
      other = { missing = { ... } },    -- sources not tied to a listed boss or to trash
    },
  },
  current = n | nil,                    -- instanceID from instanceContext when it is a known, non-assumed instance
}
```

### Evaluator rules

- **Eligibility.** A source counts for a profile class when `proficiency.CanCollect(classFile, source)` allows it, the source's `classes` (if any) include the class ID, and its `faction` is nil or equals `character.faction`. A faction mismatch drops the source for every class.
- **Unresolved.** A source that is not owned is unresolved when its `itemSubType` is nil, `CanCollect` returns nil (a subtype or class the rule does not know), or, in appearance mode only, its `visualOf` entry is missing. It keeps its boss relevant. It is still listed for the classes its `classes` restriction allows.
- **Ownership.** `"appearance"`: owned when its visual is in `ownedVisuals`. `"exact"`: owned when `ownedSources[sourceID]`.
- **Missing entries.** Each missing source appears once. `classes` lists the eligible profile classes in profile order. `levelLocked` is true when `character.level < minLevel`; the entry stays listed.
- **Placement.** `kind = "boss"` with an `encounterID` the instance lists goes under that encounter. `"trash"` goes in `trash`. Everything else in scope goes in `other`: `"unresolved"`, `"token"` (tokens are an open question), and boss drops whose encounter is nil or not in the instance's `encounters`. `"quest"` and `"vendor"` sources are ignored in the first release.
- **Runtime rule.** When a source's `collectionRule` is `"unknown"` and `itemFacts[itemID]` has a quality, the evaluator derives the rule the way the pipeline does: `"recipient"` for quality 4 or any raid source, `"group"` for a dungeon source of quality 2 or 3 with `bindType` 1 (bind on pickup), otherwise `"unknown"`. A rule from the data is never overridden.
- **Opportunity.** `"sure"` if any listed missing source has rule `"group"`, else `"roll"` for `"recipient"`, else `"unknown"`, else nil. A nil rule counts as `"unknown"`.
- **Progress.** Per profile class, over every eligible source in the instance (bosses, trash and `other`). Appearance mode counts distinct visuals; exact mode counts sources; a source with no known visual counts as one unit by source ID. One class's progress never depends on which other classes are selected.
- **Filters.** `profile.instances` removes instances from the output. `profile.slots` limits listed missing entries, so it also drives `relevant` and `opportunity`, but it does not change `progress`. `profile.instanceKinds` only sets `active`; nil means every kind. `active` is false for assumed instances, which are still listed.
- **Current.** `current` is set from `instanceContext` regardless of the filters.
- **Order.** Instances by ID, encounters in the instance's `encounters` order, missing entries by source ID.
