std = "lua51"
max_line_length = 120
exclude_files = { ".claude/", "dist/", "Data/Generated/", "spec/pipeline/fixtures/" }

globals = {
  "SLASH_ALTROBE1", "SlashCmdList", "AltrobeDB",
}

read_globals = {
  "CreateFrame", "C_TransmogCollection", "C_Item", "C_Map", "GetInstanceInfo", "GetSavedInstanceInfo",
  "GetNumSavedInstances", "GetSavedInstanceEncounterInfo", "UnitClass", "UnitLevel", "UnitFactionGroup",
  "C_Timer", "InCombatLockdown", "RequestRaidInfo", "GetTime", "issecretvalue",
}

files["spec/"] = {
  std = "+busted",
  globals = { "_G" },
}

-- Host-side tools run on LuaJIT outside the game.
files["tools/"] = {
  std = "luajit",
}
