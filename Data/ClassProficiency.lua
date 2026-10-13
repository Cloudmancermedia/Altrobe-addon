-- What each class can collect as a transmog appearance at level 60.
-- CanCollect is the single place that decides it; change the rule there.
local _, ns = ...

local function set(list)
  local s = {}
  for _, key in ipairs(list) do s[key] = true end
  return s
end

local P = {}
ns.Proficiency = P

-- Class IDs as item class restrictions use them.
P.ClassIDs = {
  WARRIOR = 1, PALADIN = 2, HUNTER = 3, ROGUE = 4, PRIEST = 5,
  SHAMAN = 7, MAGE = 8, WARLOCK = 9, DRUID = 11,
}

-- Copied from WeaponWise Data/ClassWeapons.lua, keyed by WeaponWise
-- WeaponTypes keys.
-- ClassicWeapons is the Classic Era baseline, written from memory: UNVERIFIED.
-- ForeverAdditions holds what Forever adds on top.
P.ClassicWeapons = {
  WARRIOR = set({ "AXE_1H", "AXE_2H", "BOW", "GUN", "MACE_1H", "MACE_2H", "POLEARM", "SWORD_1H", "SWORD_2H",
    "STAFF", "FIST", "DAGGER", "THROWN", "CROSSBOW" }),
  PALADIN = set({ "AXE_1H", "AXE_2H", "MACE_1H", "MACE_2H", "POLEARM", "SWORD_1H", "SWORD_2H" }),
  HUNTER = set({ "AXE_1H", "AXE_2H", "BOW", "GUN", "POLEARM", "SWORD_1H", "SWORD_2H", "STAFF", "FIST", "DAGGER",
    "THROWN", "CROSSBOW" }),
  ROGUE = set({ "BOW", "GUN", "MACE_1H", "SWORD_1H", "FIST", "DAGGER", "THROWN", "CROSSBOW" }),
  PRIEST = set({ "MACE_1H", "STAFF", "DAGGER", "WAND" }),
  -- Two-handed axes and maces needed an Enhancement talent in Classic Era.
  SHAMAN = set({ "AXE_1H", "MACE_1H", "STAFF", "FIST", "DAGGER" }),
  MAGE = set({ "SWORD_1H", "STAFF", "DAGGER", "WAND" }),
  WARLOCK = set({ "SWORD_1H", "STAFF", "DAGGER", "WAND" }),
  DRUID = set({ "MACE_1H", "MACE_2H", "STAFF", "FIST", "DAGGER" }),
}

-- Source: the project owner (2026-10-13), who knows of no other Forever weapon
-- changes. Shaman 2H axes and maces no longer need the Enhancement talent;
-- Druids can train polearms with no talent.
P.ForeverAdditions = {
  SHAMAN = set({ "AXE_2H", "MACE_2H" }),
  ROGUE = set({ "AXE_1H" }),
  DRUID = set({ "POLEARM" }),
}

P.Weapons = {}
for class, weapons in pairs(P.ClassicWeapons) do
  local merged = {}
  for key in pairs(weapons) do merged[key] = true end
  for key in pairs(P.ForeverAdditions[class] or {}) do merged[key] = true end
  P.Weapons[class] = merged
end

-- Primary armor type per class at level 60. UNVERIFIED: whether Forever lets a
-- class collect armor types below its primary type is an open question. Until
-- it is settled, only the primary type counts.
P.ArmorType = {
  MAGE = "CLOTH", PRIEST = "CLOTH", WARLOCK = "CLOTH",
  ROGUE = "LEATHER", DRUID = "LEATHER",
  HUNTER = "MAIL", SHAMAN = "MAIL",
  WARRIOR = "PLATE", PALADIN = "PLATE",
}

-- Armor subtypes the rule knows. GENERIC (cloaks, rings, necks, trinkets,
-- shirts, tabards, off-hand frills) is collectable by every class.
local armorTypes = set({ "CLOTH", "LEATHER", "MAIL", "PLATE", "GENERIC" })

local weaponTypes = {}
for _, weapons in pairs(P.Weapons) do
  for key in pairs(weapons) do weaponTypes[key] = true end
end

-- Returns true or false when the rule decides, and nil when it cannot: an
-- unknown class, a nil subtype, or a subtype it does not know (shields among
-- them). The evaluator treats nil as unresolved, never as a skip.
function P.CanCollect(classFile, source)
  local primary = P.ArmorType[classFile]
  local subType = source.itemSubType
  if not primary or subType == nil then return nil end
  if armorTypes[subType] then
    return subType == "GENERIC" or subType == primary
  end
  if weaponTypes[subType] then
    return P.Weapons[classFile][subType] == true
  end
  return nil
end
