# Altrobe addon

A World of Warcraft: Forever addon that shows which dungeon and raid bosses still drop appearances you're missing, for the classes you're collecting for. It is part of [Altrobe](https://github.com/Cloudmancermedia/altrobe), the Forever dressing room.

Uses collection data from [All The Things](https://github.com/ATTWoWAddon/AllTheThings). See `NOTICE`. It does not need All The Things installed.

Status: early development. The first playable slice is a chat command.

## Commands

| Command | What it does |
|---|---|
| `/altrobe plan` | Bosses in the current dungeon or raid that drop appearances you're missing, in order |
| `/altrobe plan <instance name>` | The same for a named instance, from anywhere. Part of the name is enough |
| `/altrobe class <class ...>` | Collect for these classes, e.g. `/altrobe class priest rogue`. Defaults to your class |
| `/altrobe mode appearance\|exact` | Count an appearance as owned through any item (default), or only the exact item |

Each boss shows its opportunity: green `sure` (a group drop, everyone gets it), gold `roll` (one recipient), grey `unknown` (the drop rule is not known yet). `?` marks an item with incomplete data and `*` one above your level.

## Development

Requirements: LuaJIT (matches the game's Lua 5.1), and `busted` and `luacheck` installed for Lua 5.1 with LuaRocks.

```sh
brew install luajit
luarocks --lua-version=5.1 --local config variables.LUA "$(command -v luajit)"
luarocks --lua-version=5.1 --local install busted
luarocks --lua-version=5.1 --local install luacheck
```

| Command | What it does |
|---|---|
| `make check` | Lint and run the tests |
| `make data ATT=/path/to/AllTheThings` | Regenerate `Data/Generated/` from an All The Things checkout |
| `make link ADDONS=/path/to/Interface/AddOns` | Symlink this checkout into the game |

`docs/data-contract.md` defines the generated data and the evaluator's inputs and outputs. Files in `Data/Generated/` are never edited by hand.

### Runtime

The evaluator (`Domain/Evaluator.lua`) is pure. Services build its inputs from the client and `UI/ChatPlan.lua` prints the result.

| Module | Job |
|---|---|
| `Services/Profile.lua` | The active profile in `AltrobeDB`, and the `class` and `mode` commands |
| `Services/Collection.lua` | Visuals and owned sources and appearances, and item quality and binding loaded asynchronously |
| `Services/InstanceContext.lua` | The player's instance by map ID, falling back to the zone name |
| `Services/Lockouts.lua` | Killed bosses from saved instances (matched by name) and from `ENCOUNTER_END` |
| `Services/Plan.lua` | Assembles inputs, evaluates, caches, and re-evaluates out of combat |

### Data pipeline

`make data` needs a checkout of All The Things at the commit pinned in `tools/build_data.lua`, and refuses any other. A sparse clone of `db/Camelot/`, `db/Vanilla/` and `.contrib/.db/forever/.config/` is enough. Upstream files are treated as data: they load in a sandbox with no library access, and nothing upstream is run.

| Module | Job |
|---|---|
| `tools/loader.lua` | Loads an upstream category file into a node tree |
| `tools/iteminfo.lua` | Quality, slot and type from the Forever client tables (Wago CSVs, harvested ItemDB) |
| `tools/normalizer.lua` | Builds instances, encounters and sources; classifies sources; applies the timeline |
| `tools/availability.lua` | Hand-maintained availability per instance, with provenance |
| `tools/validator.lua` | Referential integrity and enum checks; the build writes nothing if they fail |
| `tools/emitter.lua` | Deterministic Lua output |

Fixtures for the pipeline specs live in `spec/pipeline/fixtures/` in the upstream layout.

## License

MIT. All The Things data keeps its own MIT notice in `NOTICE`.
