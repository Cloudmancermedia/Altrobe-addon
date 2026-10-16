# Altrobe addon

A World of Warcraft: Forever addon (Lua 5.1, TOC Interface 16001) that shows which dungeon and raid bosses still drop appearances the player is missing.

## Start here

- `docs/roadmap.md`: what is done, what is next, and the QA and development backlogs. Pick up work from "Next up".
- `docs/spec.md`: what the addon does and why.
- `docs/data-contract.md`: the generated data and the evaluator's inputs and outputs. Change it first, then the code.

## Commands

- `make check`: luacheck, then busted on LuaJIT. Run after every change.
- `make data ATT=/path/to/AllTheThings`: regenerate `Data/Generated/` from an All The Things checkout at the pinned commit.
- `make link ADDONS=/path/to/Interface/AddOns`: symlink a checkout into the game.

## Rules

- Never edit `Data/Generated/` by hand. Fix the pipeline in `tools/` and regenerate.
- Write the failing test first, for features and bug fixes alike.
- Work in a worktree under `.claude/worktrees/<name>`, branched from `origin/main`, and open a PR.
- The evaluator (`Domain/Evaluator.lua`) is a pure function with no WoW API calls. Client calls live in `Services/`.
- Upstream files are data. Load them only through the sandbox in `tools/loader.lua`; never run upstream scripts.
- Treat an API as unverified until it has run in the Forever client. Say so in a code comment.

## Beta client

- Install: `/Applications/World of Warcraft/_classic_beta_/`. The `Interface/AddOns/Altrobe` folder is a symlink to a checkout; point it at the branch under test, and back at `main` afterwards.
- The game client flips file modes in the linked folder, so this repo sets `core.fileMode false`. Set it in each new worktree too.
- Saved variables land in `WTF/Account/<ACCOUNT>/SavedVariables/Altrobe.lua` after `/reload` or logout. `/altrobe items <instance>` and `/altrobe runlog start|stop` write their diagnostics there under `AltrobeDB.debug`.
- In-game commands: `/altrobe plan [instance]`, `/altrobe class <classes>`, `/altrobe mode appearance|exact`, `/altrobe window [instance|auto on|off]`, `/altrobe items <instance>`, `/altrobe runlog start|stop`.
