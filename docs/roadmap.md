# Roadmap

Where the addon stands and what to pick up next. `docs/spec.md` says what the addon does; this file says what is done and what is left. Update it in the same PR as the work it describes.

Last updated: 2026-10-14.

## Dates that drive the plan

| Date | What happens |
|---|---|
| Now | Forever beta, build 1.60.1.70338, capped at level 30 |
| 2026-11-04 | Forever launches with its new dungeons |
| 2026-12-09 | Barrow Deeps, Hyjal Summit and Onyxia's Lair unlock |
| Spring and summer 2027 | More raids, including a revamped classic raid |

Dungeons ship first because they are the only instanced loot at launch.

## Where things stand

- **Phase 1, beta spike: done.** The client exposes the retail transmog APIs, our source IDs match the client's, the Encounter Journal is empty, and the model preview works. Three answers still need a group dungeon run (see QA).
- **Phase 2, foundation: mostly done.** Merged in PR #1: the data pipeline, the evaluator, the runtime services, and `/altrobe plan`. PR #3 leaves items the beta client does not have out of live plans and adds `/altrobe items`. PR #4 matches lockout boss names that differ from the client's. `/altrobe runlog` records what the group dungeon run in QA needs. Tested in the beta: boss names, sure and roll marks, item links, multi-class, and instance detection all work.

## Next up, in order

1. Check the in-instance window in the beta (see QA), then merge `feat/instance-window`.
2. Continue Phase 3 with the boss tooltips, then the browser.
3. Do the group dungeon run in QA and fold its answers into `docs/spec.md` and the code comments marked untested.

## Development backlog

### Phase 2 leftovers

- **Group equivalent sources.** Story 22: several items that share one visual should show as one appearance with its sources, not as separate missing items.
- **Session kills.** Kills from `ENCOUNTER_END` last for the session, so a dungeon reset does not clear them.
- **Unnamed bosses.** Five encounters have no name (Atiesh, Fel Steed / Shadow Charger, Princess Moira, Cannon Master Willey, Archivist Galford) and print as `NPC <id>`.

### Phase 3, dungeon release (target late November)

- **In-instance window: built, not yet checked in game.** `UI/InstanceWindow.lua` opens on entering a dungeon or raid with a relevant boss and lists those bosses with their missing items as icons.
- **Browser.** Filters for instance, class, slot, set and ownership mode.
- **Tooltips.** Why a boss is relevant: the missing appearances and the classes they count for.
- **Profiles UI.** Named profiles with saved classes, filters and mode.
- **Release.** CurseForge packaging (`.pkgmeta` and a release workflow), with the All The Things attribution and `NOTICE`. Public alpha.

### Phase 4, raids (by 2026-12-09)

- **Raid data.** Barrow Deeps and Hyjal Summit have no upstream data yet, and their IDs (78789, 78790) are upstream placeholders. Re-pin and regenerate once upstream fills them in.
- **Tokens.** Model tier tokens once their Forever behavior is known; `ns.Data.tokens` is empty today.
- **Raid loot.** Roll-opportunity marking for raid epics, and raid lockouts end to end.

### Phase 5, partial-set preview

- Collected-only and complete-set previews on the player model, with explicit missing slots and a fixed choice of source per visual.

### Ongoing

- **Re-pin upstream.** `tools/build_data.lua` pins All The Things at `cb48940f`. Later upstream commits removed the classic raids other than Onyxia from the Forever data, so a re-pin will take them from Classic Era. Review the generated-data diff on every re-pin.
- **Item quality.** 1,446 of 2,105 sources have no quality in the pinned client tables, so their rule is `unknown` offline. The runtime fills it from the client for live content.
- **Drop sources for the dressing room.** The Altrobe dressing room's drop-source backlog item could read a JSON export of this addon's boss-to-loot data.

## QA backlog (in the beta or live client)

### Open now

- **Instance window.** `/reload`, walk into Shadowfang Keep or another live dungeon. The window should open on its own, list bosses with numbers and icons, show the item tooltip on hover, and remember its place after a drag and `/reload`. Close it, then `/altrobe window` reopens it. Leave the dungeon and it closes. Watch for missing textures on the frame border, close button or scroll bar.
- **#3 check.** `/reload`, then run `/altrobe plan blackrock depths` twice about 10 seconds apart. The second run should list fewer bosses and end with "items not in the client yet".
- **Fenrus check.** `/altrobe plan shadowfang` after a few seconds: Fenrus the Devourer should show sure or roll, not unknown.
- **Group dungeon run.** `/altrobe runlog start` before the first pull, `/altrobe runlog stop` and `/reload` after the last boss. The answers are in `AltrobeDB.debug.runlog`:
  - Group collection: does a green or blue won by another player teach its appearance to everyone eligible?
  - Combat: do the transmog APIs return plain values during combat lockdown?
  - Lockouts: do saved-instance fields read as expected, and does #4 mark the right bosses killed?
  - `ENCOUNTER_END`: is its encounter ID the journal ID our data uses?
- **Appearance ownership.** Confirm `C_TransmogCollection.GetAppearanceInfoBySource` answers in game. `Services/Collection.lua` falls back to owned sources when it does not.
- **Questionable bosses.** These passed the boss rule but may be trash or rares: Scarlet Trainee, Arugal's Voidwalker, Razorfen Spearhide, Techbot, Verek, Watchman Doomgrip.
- **Instance detection.** Six instances have no `uiMapIDs` and rely on name matching. Walk into each to confirm.
- **Armor types.** On characters of different armor types, check whether a class can collect appearances below its primary armor type. `Data/ClassProficiency.lua` assumes it cannot.

### At launch (2026-11-04)

- The Interface number (16001 in the beta) and the client's install folder, which may move off `_classic_beta_`.
- Run `/altrobe items` across live dungeons. Items the beta lacked should load once the level cap lifts.
- Re-check `C_TransmogCollection.PlayerCanCollectSource`; in the beta it did not follow class proficiency.

### At raid unlock (2026-12-09)

- Raid difficulties, tier sets and tokens, and raid lockouts.

## Decisions on record

- Bosses are numbered by their position in the instance, so hidden bosses leave gaps. The number tells the player how far in a boss is.
- The instance window opens on its own on entering an instance with a relevant boss, and stays closed for that instance once the player closes it.
- Forever only; Retail and the other Classic clients are out of scope.
- Dungeons and raids are in scope. The classic raids are included as assumed content until Blizzard confirms them.
- The addon is its own repo, using All The Things data with attribution. It does not fork All The Things.
- An owned appearance is never listed as missing; incomplete data never produces a confident skip.
- Items the client cannot load are left out of live plans and re-checked every session.
- Quest and vendor rewards are out of the first release.
