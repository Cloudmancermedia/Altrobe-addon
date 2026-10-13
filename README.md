# Altrobe addon

A World of Warcraft: Forever addon that shows which dungeon and raid bosses still drop appearances you're missing, for the classes you're collecting for. It is part of [Altrobe](https://github.com/Cloudmancermedia/altrobe), the Forever dressing room.

Uses collection data from [All The Things](https://github.com/ATTWoWAddon/AllTheThings). See `NOTICE`. It does not need All The Things installed.

Status: early development, not yet playable.

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

## License

MIT. All The Things data keeps its own MIT notice in `NOTICE`.
