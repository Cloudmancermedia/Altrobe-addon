# Altrobe addon spec

What the addon does and the decisions behind it. `docs/roadmap.md` tracks what is done and what is next; `docs/data-contract.md` defines the generated data and the evaluator.

## Problem Statement

World of Warcraft: Forever players who collect transmog across multiple characters and classes lack a focused way to answer a simple question before a dungeon or raid: which bosses still drop appearances they care about?

Forever records appearance collection account-wide, but its Collections panel hides uncollected appearances and set progress. The game itself does not show what is still missing or where it drops. Forever's loot rules make the question sharper. Uncommon and rare bind-on-pickup dungeon items grant their appearance to every eligible player in the group. Raid epics grant it only to the player who receives the item. Dungeons are the dependable way to collect, and a raid boss matters because each kill is a chance to win a missing appearance.

All The Things has broad collection data and already ships a Forever database. Its completionist interface tracks every collectible type. It treats exact item-source completion as important even when the same appearance is already owned from another source, and its filtering centers on the current character. This makes transmog collecting harder to follow than it needs to be, particularly for players building wardrobes for several classes.

The desired product is a standalone addon for the Forever client, published as the Altrobe addon. It uses collection data from All The Things with clear attribution, but focuses on dungeon and raid transmog. It must reuse upstream data without depending on All The Things at runtime and without merging every upstream implementation change.

## Solution

Build the Altrobe addon as a standalone, transmog-focused addon for the World of Warcraft: Forever client. Its build pipeline treats the All The Things repository as an upstream data provider.

A data adapter will read a pinned All The Things revision. Its primary source is the Forever database (`db/Camelot`). For any instance the Forever database lacks, such as a classic raid not yet entered upstream, the adapter falls back to the Classic Era database (`db/Vanilla`) and records that fallback as provenance. The adapter extracts instance, encounter, source-item, appearance, set, difficulty, slot, armor-type, and class-restriction information, validates it, and produces a normalized addon dataset. Generated data will not be manually edited. Upstream updates go through a controlled synchronization process and are accepted only after compatibility and behavioral validation.

At runtime, the addon combines the normalized dataset with the Forever client's collection, character, instance, encounter, lockout, and model APIs. Forever runs on the modern client codebase and exposes `C_TransmogCollection`, `C_TransmogSets`, `GetSavedInstanceInfo`, and the model-widget transmog methods. A farm-plan evaluator produces the list of relevant dungeons, raids, bosses, trash sources, and missing appearances for one or more selected classes. Appearance ownership is the default completion rule. Exact-source ownership stays available as optional detail.

The evaluator models Forever's two collection rules. A dungeon bind-on-pickup green or blue grants its appearance to every eligible player present, so a relevant dungeon boss is a near-certain collection opportunity. A raid epic grants its appearance only to the recipient, so a relevant raid boss is a roll opportunity, and the addon presents it that way rather than as a guaranteed completion.

When the player enters a supported dungeon or raid, the addon automatically shows the remaining relevant bosses and appearances for the active farming profile. A partial-set model viewer uses the current character model to show collected pieces from a selected set, so the player can judge whether the collected subset is visually sufficient before farming the rest.

Every instance carries an availability status: live, announced, or assumed. Forever's launch content is its new dungeons, followed by Barrow Deeps, Hyjal Summit, and Onyxia's Lair on 2026-12-09, with more raids announced for 2027. The classic raids (Molten Core, Blackwing Lair, Zul'Gurub, Ruins and Temple of Ahn'Qiraj, Naxxramas) are included on the assumption that they will ship. Assumed instances appear in the browser marked as such and never appear as active farming targets until the client confirms them.

## User Stories

1. As a transmog collector, I want to see which dungeons and raids contain appearances I am still missing, so that I can choose where to spend my time.
2. As a transmog collector, I want an instance's relevant bosses listed clearly, so that I can skip bosses that cannot advance my selected collection goals.
3. As a player entering a dungeon or raid, I want the addon to detect the current instance automatically, so that I do not have to navigate to it manually.
4. As a player moving through an instance, I want completed or irrelevant bosses removed or visually de-emphasized, so that the remaining route is easy to parse.
5. As a collector with several characters, I want appearance ownership evaluated account-wide, so that an appearance collected by another character is not presented as missing.
6. As a completionist who still cares about exact items, I want exact-source ownership available as optional detail, so that the simplified default does not discard useful information.
7. As a player who only cares about visual completion, I want an appearance collected from any equivalent source to count as complete, so that I am not sent to farm redundant items.
8. As a multi-class collector, I want to select one or more target classes, so that the farm plan reflects the characters whose wardrobes I am building.
9. As a priest collector, I want to restrict results to appearances and sets relevant to priests, so that plate and unrelated class drops do not clutter the plan.
10. As a rogue collector, I want to restrict results to appearances and sets relevant to rogues, so that I can build a separate rogue farming plan.
11. As a player tracking priest and rogue together, I want the combined view to use the union of relevant appearances while preserving per-class attribution, so that shared progress is counted once without hiding which class benefits.
12. As a multi-class collector, I want separate progress totals for each selected class, so that one class's progress does not misleadingly inflate another class's completion.
13. As a player, I want the current character selected automatically as the default target class, so that the addon is useful immediately after installation.
14. As a player, I want to override the current-character default, so that I can farm for alts while playing a different class.
15. As a player, I want named farming profiles with selected classes, instances, sets, slots, and ownership rules, so that I can switch between different farming goals.
16. As a player, I want profile selections and UI state saved between sessions, so that I do not rebuild my plan every time I log in.
17. As a set collector, I want to select specific armor sets, so that only bosses contributing to those sets are treated as targets.
18. As a collector who wants broader coverage, I want to track all eligible dungeon and raid appearances for a class, so that I do not need to select every set manually.
19. As a collector, I want to filter by armor slot, so that I can focus on missing shoulders, helms, weapons, or other desired slots.
20. As a collector, I want to filter by instance type and by instance, so that I can plan sessions around dungeons, a particular raid, or both.
21. As a collector, I want difficulty variants represented separately when they have different appearances, so that variants are not incorrectly collapsed if Forever ships more than one difficulty.
22. As a collector, I want equivalent sources for the same visual appearance grouped together, so that I understand all valid ways to complete the appearance.
23. As a collector, I want token-derived appearances associated with the bosses and redemption requirements that matter, so that tier tokens do not appear as ordinary direct item drops.
24. As a collector, I want trash appearances distinguished from boss drops, so that I know when clearing trash can still advance my goals.
25. As a player, I want armor-type, class, faction, race, and level restrictions respected, so that the addon does not recommend appearances the selected class cannot collect or use.
26. As a player, I want tooltips to explain why a boss is relevant, so that I can see the missing appearances and selected classes behind the recommendation.
27. As a player, I want each target item to show its icon, name, slot, difficulty, source, and ownership state, so that I can recognize the reward without opening another addon.
28. As a player, I want a concise instance progress summary such as bosses remaining and appearances collected, so that I can evaluate an instance at a glance.
29. As a player, I want collection state to refresh after loot or collection changes, so that newly learned appearances disappear from the remaining farm plan without requiring a reload.
30. As a player, I want boss state to refresh after a kill, so that the active checklist remains accurate during the run.
31. As a player, I want lockout state represented independently from appearance completion, so that I can distinguish an irrelevant boss from a relevant boss I already killed this reset.
32. As a player, I want unsupported or unresolved records shown conservatively rather than silently omitted, so that data problems do not produce false completion.
33. As a set collector, I want to select a set and see how many pieces are currently collected, so that I understand my visual progress.
34. As a set collector, I want a model viewer based on my current character, so that the preview reflects the race, body, and presentation I actually use.
35. As a set collector, I want the partial-set viewer to apply only the appearances I have collected, so that I can judge what the current six-of-eight or similar collection looks like.
36. As a set collector, I want missing model slots visibly identified, so that I can distinguish intentionally empty areas from preview failures.
37. As a set collector, I want to switch between collected-only and complete-set previews, so that I can compare my current appearance with the intended finished set.
38. As a player, I want a defined policy for missing preview slots, such as empty, neutral, or current equipment, so that partial previews are predictable.
39. As a player, I want the model viewer to choose a valid visual source when several items grant the same appearance, so that equivalent sources do not break the preview.
40. As a player, I want the addon to load without All The Things installed, so that the addon behaves as a standalone product.
41. As a player who also uses All The Things, I want both addons to coexist without global, saved-variable, slash-command, or frame-name collisions.
42. As a player, I want data provenance and the imported upstream revision visible in addon diagnostics, so that I can report issues against the correct dataset.
43. As a maintainer, I want upstream data synchronized through a repeatable build process, so that data updates do not require manual copying or editing.
44. As a maintainer, I want upstream revisions pinned, so that builds are reproducible and a broken upstream revision does not alter released behavior unexpectedly.
45. As a maintainer, I want upstream syncs to produce reviewable changes, so that large or suspicious data shifts can be inspected before release.
46. As a maintainer, I want schema and semantic validation to fail the sync when required fields or relationships change, so that incompatible upstream changes cannot be published silently.
47. As a maintainer, I want the last known-good generated dataset retained when synchronization fails, so that players can continue using a stable release.
48. As a maintainer, I want application code isolated from upstream implementation files, so that data updates do not require routine merges of unrelated All The Things features.
49. As a maintainer, I want the generated package to include only required runtime code and data, so that the addon does not ship unrelated achievement, pet, mount, quest, or completionist functionality.
50. As a maintainer, I want each instance to carry an availability status of live, announced, or assumed, so that content Blizzard has not confirmed can be modeled without being presented as farmable.
51. As a player, I want weekly lockout, raid unlock dates, and availability modeled separately from ownership, so that recommendations stay accurate as Forever releases content over time.
52. As an addon user, I want clear attribution to All The Things and its contributors, so that the project's use of their data is transparent.
53. As a maintainer, I want third-party data and asset provenance documented, so that the All The Things software license is not incorrectly assumed to cover every imported resource.
54. As a player, I want the addon to remain responsive while evaluating the full dungeon and raid dataset, so that opening the tracker or changing filters does not noticeably freeze the game.
55. As a player, I want actionable diagnostics when item information or model data has not loaded yet, so that temporary client-cache behavior is not mistaken for permanent missing data.
56. As a dungeon runner, I want dungeon bosses whose drops would teach me a missing appearance marked as sure collections, so that I know a single clear completes them for my account.
57. As a raider, I want raid bosses with missing epic appearances marked as roll opportunities, so that I know a kill only helps if I receive the item.
58. As a player, I want instances whose availability is assumed shown in the browser with that status, so that I can plan ahead without being sent to content that may not exist.
59. As a player, I want the addon to respect Forever's level gating of appearances, so that an appearance I cannot yet use at my level is labeled rather than hidden or counted as complete.

## Implementation Decisions

- The Altrobe addon will be a standalone addon for the World of Warcraft: Forever client and will not require All The Things to be installed at runtime.
- The TOC will declare the Forever Interface number (16001 during beta) and the `forever` game type. The launch Interface number must be confirmed when the client ships.
- The All The Things repository will be treated as a build-time upstream data provider rather than a runtime API dependency.
- The adapter reads the generated All The Things Forever database (`db/Camelot`) as its primary source. It falls back to the Classic Era database (`db/Vanilla`) per instance when the Forever database lacks that instance, and records which source supplied each instance.
- Classic raid items can lack client item data. Molten Core item 16805 returns no name and is not equippable in the Forever client (spike, 2026-10-13). For assumed instances, names, icons, slots, and armor types come from upstream data, and missing client item data for those items is not treated as a loading state.
- The adapter reads the committed generated database files rather than rebuilding them with the upstream C# Parser, which is not committed in built form.
- The addon lives in its own repository (`altrobe-addon`, alongside `Cloudmancermedia/altrobe`). It does not fork All The Things and ships none of its addon code; it synchronizes upstream data through an explicit adapter.
- The upstream revision used for each generated dataset will be pinned and recorded as build metadata.
- Generated addon data will never be manually edited. Corrections must be made through the source adapter, an explicit overlay with provenance, or an accepted upstream correction.
- Upstream synchronization will be controlled rather than blindly automatic. A sync will generate a reviewable change and must pass validation before it can become a release.
- The normalized domain hierarchy will be instance type (dungeon or raid), instance, difficulty, encounter or trash source, item source, visual appearance, armor set, and eligibility.
- Every instance carries an availability status (live, announced, assumed) and, where known, an unlock date. Assumed instances are browsable but never become active farming targets until the client confirms them, for example through the Encounter Journal or a recorded instance entry.
- Stable identifiers from the game and upstream data will be retained, including instance, encounter, item, modified-appearance source, visual appearance, set, difficulty, and inventory-slot identifiers where available.
- Boss, trash, and instance loot relationships ship as static data from the adapter. The Forever client's Encounter Journal has no data: `EJ_GetNumTiers()` returns 0 on build 1.60.1.70338 (spike, 2026-10-13).
- All The Things source IDs match the client: 12 of 12 sampled source IDs equal the source ID `C_TransmogCollection.GetItemInfo` returns for the same item. The runtime resolves each source's visual appearance with `C_TransmogCollection.GetItemInfo`, which returns values on the first call without a warm item cache.
- Source type will be explicit and will distinguish at least direct boss drop, token, trash, vendor redemption, and other unresolved source types.
- Each source records its collection rule: group collection (dungeon bind-on-pickup uncommon and rare items, granted to every eligible player present) or recipient collection (raid epics, granted only to the player who receives the item).
- Collection truth will be read from the Forever client's `C_TransmogCollection` APIs and interpreted as account-wide state.
- Ownership, source collection, and eligibility will remain separate dimensions: appearanceOwned, exactSourceOwned, and eligibleForClass.
- Eligibility follows Forever's item-type rule: an appearance applies to items of the same armor or weapon type. A class is eligible for an appearance when it can equip that item type, plus any class, faction, race, or level restriction on the item itself. The addon ships its own class-to-armor-and-weapon proficiency table. The client's `C_TransmogCollection.PlayerCanCollectSource` and `C_Item.IsEquippableItem` do not reflect class proficiency: in the spike, a Warlock was reported able to collect bows and two-handed maces and unable to collect cloth cloaks, and nearly every item was reported equippable. Neither API is used for eligibility.
- The primary completion policy will consider an appearance complete when an equivalent visual appearance is owned, regardless of whether the exact source item is collected.
- Exact-source collection will remain queryable and may be exposed as an optional completionist mode or secondary tooltip detail.
- Multi-class profiles will use a union for the combined target list while retaining per-class eligibility and progress. A single combined percentage will not replace the per-class views.
- Boss relevance will be derived rather than stored: a boss is relevant when at least one eligible target appearance under that boss remains missing for the active profile. Relevance carries the collection rule, so the UI can show a sure collection or a roll opportunity.
- Lockout completion and appearance completion will be modeled separately.
- Tier tokens will retain their token identity, eligible classes, relevant boss sources, redemption relationship, difficulty, and resulting appearances rather than being flattened into ordinary item drops.
- Unresolved or ambiguous source relationships will be represented explicitly and excluded from confident skip recommendations.
- A farming profile will support selected classes, instance types, instances, sets, slots, difficulties, and ownership mode.
- The current character's class will initialize the default profile but will not limit the player to current-character filtering.
- The addon will subscribe to the minimal game events needed to refresh instance context, boss state, lockouts, collection state, and item information.
- Runtime evaluation will be performed by one farm-plan evaluator that accepts normalized data, the active profile, collection state, current character context, current instance context, and lockout state.
- The farm-plan evaluator will return presentation-neutral instance progress, relevant encounters, missing appearances, relevance explanations, collection rules, and partial-set outfit state.
- UI components will render evaluator output and will not duplicate ownership, eligibility, token, collection-rule, or boss-relevance rules.
- External boundaries for upstream data, client APIs, saved state, and model rendering will be adapted behind narrow interfaces.
- The primary in-instance interface will prioritize remaining relevant bosses and the appearances that make each boss relevant.
- The broader browser will support instance type, instance, class, set, slot, difficulty, availability, and ownership filtering.
- The model viewer will use the current character as its base and apply appearance sources for collected set pieces with `SetItemTransmogInfo(ItemUtil.CreateItemTransmogInfo(sourceID))`. Both that call and `TryOn` work in the Forever client, `GetItemTransmogInfoList` reports what was applied, and the last source applied to a slot wins (spike, 2026-10-13).
- Partial-set preview behavior will be explicit. The initial default will apply collected target pieces while leaving missing target slots distinguishable; current equipment may be offered as a separate presentation option.
- Complete-set preview will be separate from collected-only preview so the player cannot confuse aspirational pieces with owned pieces.
- When multiple item sources share a visual, model selection will use a deterministic compatible source.
- Item and model information that loads asynchronously will produce a loading or unresolved state instead of being interpreted as missing.
- The addon will do its evaluation and rendering outside combat where Forever's addon restrictions limit what can be read in combat, and will defer refreshes that arrive during combat.
- Saved variables, globals, slash commands, frame names, and addon identifiers will use an Altrobe namespace so the addon can coexist with All The Things.
- The released addon will include the All The Things MIT copyright and permission notice and the attribution line "Uses collection data from All The Things."
- Data-source, asset, and branding rights will be audited separately from the MIT software license before public distribution.

## Testing Decisions

- The highest practical behavioral seam will be the farm-plan evaluator. Most domain behavior will be tested by supplying normalized instance data, profile selections, collection state, character context, instance context, and lockout state, then asserting the resulting farm plan.
- Tests will assert externally meaningful behavior rather than internal traversal order, cache shape, helper calls, or private data structures.
- The preferred tests are two compact end-to-end domain scenarios, one dungeon and one raid, each from normalized input through relevant-boss and missing-appearance output.
- The dungeon scenario will include group-collected green and blue drops, equivalent appearance sources, an armor-type-restricted item, an owned appearance, and an unowned appearance.
- The raid scenario will include recipient-collected epics, a class-restricted item, a tier token, a trash drop, an owned appearance, an unowned appearance, and a killed-but-still-relevant boss.
- Collection-rule tests will prove that dungeon bosses report sure collections and raid bosses report roll opportunities for the same missing-appearance state.
- Availability tests will prove that assumed instances appear in the browser with their status and never become active farming targets.
- Fallback tests will prove that an instance missing from the Forever database is supplied from the Classic Era database and labeled with that provenance.
- Appearance ownership tests will prove that an owned visual suppresses redundant farming recommendations even when the exact item source is uncollected.
- Exact-source tests will prove that exact-source state remains available without affecting the default appearance-based recommendation.
- Multi-class tests will prove that combined targets use union semantics while per-class progress and eligibility remain accurate.
- Eligibility tests will cover armor type, class, faction, race, level, and inventory-slot restrictions without asserting how those restrictions are internally represented.
- Token tests will assert the player-visible relationship among boss, token, eligible class, difficulty, redemption path, and resulting appearance.
- Difficulty tests will prove that visually distinct difficulty variants remain separate while equivalent appearances are grouped, if Forever ships more than one difficulty.
- Lockout tests will prove that killed, irrelevant, completed, and currently unavailable are distinct user-visible states.
- Instance-context tests will assert that entering a supported dungeon or raid selects the correct farm plan and that leaving or changing instances clears or replaces it.
- Refresh tests will assert that a newly collected appearance and a boss kill update the visible plan after the corresponding external event, including events that arrive during combat.
- Unresolved-data tests will prove that ambiguous or missing mappings are surfaced conservatively and never cause a confident recommendation to skip a potentially relevant boss.
- Model outfit tests will exercise the presentation-neutral outfit result from the farm-plan evaluator rather than inspecting model-widget implementation details.
- Partial-preview tests will verify deterministic source selection, collected-only versus complete-preview behavior, and explicit missing-slot state.
- Adapter contract tests will validate representative upstream snapshots from both `db/Camelot` and `db/Vanilla` and fail clearly when required fields, identifiers, or relationships change.
- Data validation will check referential integrity, duplicate identities, valid class restrictions, valid slot and difficulty values, encounter-to-instance ownership, source-to-visual resolution, availability status, and token redemption relationships.
- Sync tests will prove that the same pinned upstream revision produces deterministic generated output.
- Regression fixtures will be kept small and domain-focused rather than copying the complete upstream database into the test suite.
- Performance tests will evaluate the full dungeon and raid dataset at the public evaluator seam and establish budgets for addon load, profile changes, collection refreshes, and instance entry.
- Thin UI tests or manual smoke tests will verify visible filtering, tooltips, automatic instance selection, boss checklist updates, saved profile restoration, and model interaction.
- In-game smoke coverage on the Forever client will include installation without All The Things, coexistence with All The Things, a cold item cache, at least two character classes of different armor types, at least one dungeon, and at least one raid.
- Release validation will compare aggregate counts and material mapping changes against the previous known-good dataset so unexpectedly large upstream changes require review.
- Existing All The Things behavior and data structures may inform fixtures, but tests will target the addon's contract rather than locking the project to undocumented upstream internals.
- No addon codebase or existing test suite exists yet; implementation must choose a Lua test runner and conventions before adding test infrastructure, while preserving the single high-level evaluator seam described here.

## Out of Scope

- Tracking achievements, quests, mounts, pets, toys, titles, recipes, reputation, exploration, decor, or other non-transmog completion categories.
- Reproducing the complete All The Things interface or its completionist experience.
- Requiring or modifying a player's installed copy of All The Things.
- Treating exact item-source collection as the default completion rule.
- Manually maintaining a second complete copy of upstream dungeon and raid data.
- Blindly publishing every upstream data change without compatibility checks and review.
- Supporting Retail, Classic Era, Season of Discovery, Hardcore-specific rules, or any client other than World of Warcraft: Forever.
- Supporting world drops, quests, vendors, crafted items, PvP appearances, holiday content, or other non-instance sources in the initial release.
- Loot-council, roll-priority, or loot-distribution recommendations for groups.
- Optimizing routes through instance geometry or integrating navigation arrows.
- Automating combat, loot decisions, character movement, group formation, instance resets, or any action prohibited by World of Warcraft addon restrictions.
- Guaranteeing a pixel-perfect representation of every appearance on every race, body, animation, weapon state, or client graphics configuration.
- Editing, recoloring, or synthesizing item models or textures.
- Providing a hosted backend or requiring network access during gameplay.
- Monetization, paid data access, or legal conclusions about Blizzard, Wago, Wowhead, trademark, asset, or data licensing.
- Upstreaming the feature into All The Things as part of this spec.

## Further Notes

- Name: the Altrobe addon, part of the Altrobe project (https://github.com/Cloudmancermedia/altrobe). Public naming and branding must stay visibly distinct from All The Things and must not imply official endorsement.
- Attribution wording is "uses data from", not "fork of". If All The Things code is ever copied in, revisit the wording.
- A later link to the Altrobe dressing room is possible, for example an addon command that prints an Altrobe look URL for a set, or an export string of collected appearances. It is not in the initial release.
- Forever launches with nine new dungeons. Barrow Deeps, Hyjal Summit, and Onyxia's Lair unlock on 2026-12-09. Two new raids are announced for spring 2027, and a revamped classic raid plus another new raid for summer 2027. The classic raids are included as assumed content by decision, not by Blizzard confirmation.
- All The Things ships a Forever database (`db/Camelot`). The data is pinned at `cb48940f`, where Molten Core is commented out of the Forever source, so it comes from the Classic Era database. Later upstream commits also removed Blackwing Lair, Zul'Gurub, both Ahn'Qiraj raids and Naxxramas from `db/Camelot`, so a re-pin will take those from Classic Era too.
- Open questions for the beta and live client are tracked in `docs/roadmap.md` under QA.
- Competing addons on Forever as of 2026-10-13: All The Things (broad collection tracking), AtlasLoot Classic Forever (loot tables with class filter), Transmog Hunter Forever (wishlist, drop alerts, dressing-room preview), and Can I Mog It (item collected overlays). None combines a collected-aware remaining-boss list, class filtering, auto-show on instance entry, and a partial-set preview. AtlasLoot Classic Forever and Transmog Hunter Forever are actively updated and could close part of that gap.
- All The Things exposes internal global application objects, but its source does not present them as a stable public plugin contract. Build-time data ingestion is therefore the intended long-term boundary.
- All The Things contains both generated database output and manually curated relationships. Upstream data should be treated as valuable but not infallible.
- The upstream software is MIT-licensed and requires retention of its copyright and permission notice. That license should not be assumed to grant rights to every third-party data source, asset, logo, or game property.
- A data manifest should record the upstream repository URL, commit identifier, extraction version, generation timestamp, supported game build, per-instance source database, validation result, and aggregate record counts.
- The sync mechanism should preserve the last known-good dataset when an upstream fetch, extraction, schema check, or semantic validation fails.
- Sources: [World of Warcraft: Forever (wiki)](https://warcraft.wiki.gg/wiki/World_of_Warcraft:_Forever), [Forever deep dive panel recap](https://news.blizzard.com/en-us/article/24303313/world-of-warcraft-forever-deep-dive-panel-recap), [Patch 1.60.1 API changes](https://warcraft.wiki.gg/wiki/Patch_1.60.1/API_changes), [wow-ui-source forever branch](https://github.com/Gethe/wow-ui-source/tree/forever), [Forever API dump](https://github.com/Ketho/BlizzardInterfaceResources/tree/forever/Resources), [All The Things repository](https://github.com/ATTWoWAddon/AllTheThings).
