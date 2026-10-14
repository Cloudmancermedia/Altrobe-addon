-- Hand-maintained availability of every instance the pipeline emits.
--
-- Keyed by the journal instance ID All The Things uses in inst(id, ...).
-- Every instance in db/Camelot must have an entry, or the build fails.
--   availability  "live" | "announced" | "assumed"
--   unlockDate    ISO date when known
--   name          only when the client area table has no name for it
--   fallback      "vanilla": take the instance from db/Vanilla when Camelot lacks it
--
-- Provenance, unless an entry says otherwise:
--   * Upstream contents: ATTWoWAddon/AllTheThings at cb48940f5c66.
--   * Statuses: the project brief of 2026-10-13. "live" for Forever dungeons and
--     for classic dungeons present in db/Camelot; Onyxia's Lair, Hyjal Summit and
--     The Barrow Deeps announced for 2026-12-09; classic raids "assumed".
--     The brief's statuses are not verified against the game.

local ANNOUNCED = "2026-12-09"

return {
  -- Forever dungeons (db/Camelot, added with awp=16001).
  [2959] = { availability = "live" }, -- City of Dalaran
  [2998] = { availability = "live" }, -- Excavation Site: Wetlands
  [2999] = { availability = "live" }, -- Ruins of Lordaeron
  [3065] = { availability = "live" }, -- The Hall of Thanes

  -- Classic dungeons present in db/Camelot.
  [63] = { availability = "live" }, -- The Deadmines
  [64] = { availability = "live" }, -- Shadowfang Keep
  [226] = { availability = "live" }, -- Ragefire Chasm
  [227] = { availability = "live" }, -- Blackfathom Deeps
  [228] = { availability = "live" }, -- Blackrock Depths
  [229] = { availability = "live" }, -- Blackrock Spire
  [230] = { availability = "live" }, -- Dire Maul
  [231] = { availability = "live" }, -- Gnomeregan
  [232] = { availability = "live" }, -- Maraudon
  [233] = { availability = "live" }, -- Razorfen Downs
  [234] = { availability = "live" }, -- Razorfen Kraul
  [236] = { availability = "live" }, -- Stratholme
  [237] = { availability = "live" }, -- The Temple of Atal'Hakkar
  [238] = { availability = "live" }, -- The Stockade
  [239] = { availability = "live" }, -- Uldaman
  [240] = { availability = "live" }, -- Wailing Caverns
  [241] = { availability = "live" }, -- Zul'Farrak
  [246] = { availability = "live" }, -- Scholomance
  [316] = { availability = "live" }, -- Scarlet Monastery

  -- Announced raids.
  [760] = { availability = "announced", unlockDate = ANNOUNCED }, -- Onyxia's Lair
  -- 78789 and 78790 are empty isRaid shells in db/Camelot with no area ID. Names
  -- from the achievement each one holds, in the Forever client table
  -- .contrib/.db/forever/.config/.wago/Achievement.1.60.1.70338.csv:
  -- 78789 holds ach 62034 "Defeat the following encounters in Hyjal Summit.",
  -- 78790 holds ach 62035 "Defeat the following encounters in the Barrow Deeps."
  -- (criteria tree 230799 "Complete The Barrow Deeps").
  [78789] = { availability = "announced", unlockDate = ANNOUNCED, name = "Hyjal Summit" },
  [78790] = { availability = "announced", unlockDate = ANNOUNCED, name = "The Barrow Deeps" },

  -- Classic raids. The brief expected all of these from db/Vanilla, but at
  -- cb48940f5c66 db/Camelot already has every one except Molten Core, so only
  -- Molten Core falls back to Vanilla.
  [741] = { availability = "assumed", fallback = "vanilla" }, -- Molten Core
  [742] = { availability = "assumed" }, -- Blackwing Lair
  [76] = { availability = "assumed" }, -- Zul'Gurub
  [743] = { availability = "assumed" }, -- Ruins of Ahn'Qiraj
  [744] = { availability = "assumed" }, -- Temple of Ahn'Qiraj
  [754] = { availability = "assumed" }, -- Naxxramas
}
