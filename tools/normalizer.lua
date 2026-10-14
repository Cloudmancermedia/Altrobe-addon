-- Turns loaded All The Things trees into the tables of docs/data-contract.md.
--
-- Source kind comes from the nearest classifying ancestor:
--   q() -> quest; e() -> boss; an NPC boss (below) -> boss;
--   header -63 (Zone Drops) -> trash; header -58 (Vendors) -> vendor;
--   none of these -> unresolved.
-- Other n() nodes do not classify. An unresolved source under an n() keeps its npcID.
--
-- NPC bosses. Upstream lists most classic dungeon bosses as n() with no journal
-- encounter. Such an n() is a boss, keyed -npcID with journal = false, when:
--   * it sits at boss level: its ancestors up to the instance are only wing
--     headers (WING_HEADER) and objects (summoning altars, e.g. Edge of Madness);
--     so not under Rares (-46), Zone Drops, Vendors, Quests, another n() or an e();
--   * upstream does not describe it as a rare ("This is a rare ..."), which is
--     how upstream marks rares it lists beside bosses;
--   * it drops at least one source itself after the timeline, not only through
--     a nested n(), e(), q() or header.
--
-- Timeline: a subtree is dropped when upstream marks it never implemented or
-- removed (u=1, u=2), added after the target build (awp > timeline) or removed
-- at or before it (rwp <= timeline). awp > rwp means removed at rwp and re-added
-- at awp, so the subtree is dropped only between the two. Timeline numbers encode a patch as
-- major*10000 + minor*100 + patch, so 1.60.1 is 16001.
local iteminfo = require("tools.iteminfo")

local M = {}

local HEADER_KIND = { [-63] = "trash", [-58] = "vendor" }

-- Custom headers that only split an instance into wings or floors. Names from
-- L.HEADER_NAMES in db/Camelot/LocalizationDB.lua.
local WING_HEADER = {
  [-78] = true, [-79] = true, [-80] = true, [-81] = true, [-82] = true, -- Naxxramas quarters
  [-351] = true, [-352] = true, -- Blackrock Depths: Detention Block, Shadowforge City
  [-353] = true, [-354] = true, -- Lower and Upper Blackrock Spire
  [-355] = true, [-356] = true, [-357] = true, -- Dire Maul East, North, West
  [-359] = true, [-360] = true, -- Maraudon Orange and Purple paths
  [-361] = true, [-362] = true, [-363] = true, [-364] = true, -- Scarlet Monastery wings
  [-365] = true, [-366] = true, -- Stratholme Main Gate, Service Entrance
}
local FACTION = { [1] = "Horde", [2] = "Alliance" }

local function sortedCopy(list)
  if type(list) ~= "table" then return nil end
  local out = {}
  for _, v in ipairs(list) do out[#out + 1] = v end
  table.sort(out)
  return out
end

-- Instance nodes in upstream order, without descending into an instance.
local function findInstances(root)
  local found, outside = {}, 0
  local function walk(node)
    if node.type == "inst" then
      found[#found + 1] = node
      return
    end
    if node.type == "s" then outside = outside + 1 end
    for _, child in ipairs(node.children) do walk(child) end
  end
  if root then walk(root) end
  return found, outside
end

local function excludedByTimeline(fields, timeline)
  if fields.u == 1 or fields.u == 2 then return true end
  local awp = type(fields.awp) == "number" and fields.awp or nil
  local rwp = type(fields.rwp) == "number" and fields.rwp or nil
  if awp and rwp and awp > rwp then
    -- Removed at rwp and re-added at awp: available before rwp or from awp on.
    return timeline >= rwp and timeline < awp
  end
  if awp and awp > timeline then return true end
  if rwp and rwp <= timeline then return true end
  return false
end

local function describedAsRare(fields)
  local d = type(fields.description) == "string" and fields.description:lower() or ""
  return d:find("this is a rare", 1, true) ~= nil
end

-- True when the NPC drops a source that the timeline keeps, without counting
-- drops that belong to a nested NPC, encounter, quest or header.
local function dropsSources(npc, timeline)
  local function walk(n)
    for _, c in ipairs(n.children) do
      if not excludedByTimeline(c.fields, timeline) then
        if c.type == "s" then return true end
        if c.type ~= "n" and c.type ~= "e" and c.type ~= "q" and c.type ~= "h" and walk(c) then return true end
      end
    end
    return false
  end
  return walk(npc)
end

function M.collectionRule(source, instanceKind, bop)
  if source.quality == nil then return "unknown" end
  if source.kind == "quest" or source.kind == "vendor" then return "recipient" end
  if instanceKind == "raid" or source.quality >= 4 then return "recipient" end
  if (source.quality == 2 or source.quality == 3) and bop then return "group" end
  return "unknown"
end

local function sameRelationship(a, b)
  return a.instanceID == b.instanceID and a.encounterID == b.encounterID and a.kind == b.kind
end

function M.normalize(opts)
  local items, availability, timeline = opts.items, opts.availability, opts.timeline
  local out = { instances = {}, encounters = {}, sources = {}, instanceSources = {} }
  local stats = {
    outsideInstance = 0, excludedByTimeline = 0, duplicateSources = {}, appearanceMismatch = {},
    qualityConflict = 0, byInstance = {},
  }
  out.stats = stats
  local duplicateSeen, mismatchSeen = {}, {}

  local camelot, outside = findInstances(opts.camelot)
  stats.outsideInstance = outside
  local camelotIDs = {}
  for _, node in ipairs(camelot) do camelotIDs[node.id] = true end

  local ordered = {}
  for _, node in ipairs(camelot) do
    if not availability[node.id] then
      error("instance " .. node.id .. " has no entry in tools/availability.lua", 0)
    end
    ordered[#ordered + 1] = { node = node, flavor = "camelot" }
  end

  local vanillaByID = {}
  for _, node in ipairs((findInstances(opts.vanilla))) do vanillaByID[node.id] = vanillaByID[node.id] or node end
  local wanted = {}
  for id, entry in pairs(availability) do
    if not camelotIDs[id] then
      if entry.fallback == "vanilla" and vanillaByID[id] then
        wanted[#wanted + 1] = id
      elseif entry.fallback == "vanilla" then
        error("instance " .. id .. " is in neither Camelot nor Vanilla", 0)
      else
        error("instance " .. id .. " is in tools/availability.lua but not in Camelot", 0)
      end
    end
  end
  table.sort(wanted)
  for _, id in ipairs(wanted) do ordered[#ordered + 1] = { node = vanillaByID[id], flavor = "vanilla" } end

  for _, entry in ipairs(ordered) do
    local node, flavor = entry.node, entry.flavor
    local avail = availability[node.id]
    local f = node.fields
    local kind = f.isRaid and "raid" or "dungeon"

    local maps, seenMap = {}, {}
    for _, m in ipairs(type(f.maps) == "table" and f.maps or {}) do
      if not seenMap[m] then seenMap[m] = true maps[#maps + 1] = m end
    end
    if type(f.mapID) == "number" and not seenMap[f.mapID] then maps[#maps + 1] = f.mapID end
    table.sort(maps)

    local areaIDs = type(f.zoneTextAreaIDs) == "table" and f.zoneTextAreaIDs or nil
    local areaID = f.zoneTextAreaID or (areaIDs and areaIDs[1])

    local inst = {
      id = node.id,
      name = avail.name or (areaID and items.areaNames[areaID]),
      kind = kind,
      availability = avail.availability,
      unlockDate = avail.unlockDate,
      uiMapIDs = maps,
      zoneTextAreaID = areaID,
      zoneTextAreaIDs = (areaIDs and #areaIDs > 1) and sortedCopy(areaIDs) or nil,
      encounters = {},
    }
    out.instances[node.id] = inst
    out.instanceSources[node.id] = flavor
    local istats = { sources = 0, nilQuality = 0, nilSlot = 0, nilSubType = 0 }
    stats.byInstance[node.id] = istats

    local function addSource(s, ctx)
      local rel = {
        instanceID = node.id,
        encounterID = ctx.kind == "boss" and ctx.encounterID or nil,
        kind = ctx.kind or "unresolved",
      }
      local faction = FACTION[ctx.r]
      local existing = out.sources[s.id]
      if existing then
        if not duplicateSeen[s.id] then
          duplicateSeen[s.id] = true
          stats.duplicateSources[#stats.duplicateSources + 1] = s.id
        end
        if existing.faction ~= faction then existing.faction = nil end
        if sameRelationship(existing, rel) then return end
        for _, other in ipairs(existing.alsoFrom or {}) do
          if sameRelationship(other, rel) then return end
        end
        existing.alsoFrom = existing.alsoFrom or {}
        existing.alsoFrom[#existing.alsoFrom + 1] = rel
        return
      end

      local info = items:lookup(s.itemID)
      local described = iteminfo.describe(info)
      local quality = info.quality
      if quality == nil and flavor == "vanilla" and type(s.fields.q) == "number" then quality = s.fields.q end
      local lvl = tonumber(s.fields.lvl)

      local src = {
        id = s.id,
        itemID = s.itemID,
        instanceID = rel.instanceID,
        encounterID = rel.encounterID,
        kind = rel.kind,
        npcID = (rel.kind == "unresolved" or ctx.npcBoss) and ctx.npcID or nil,
        quality = quality,
        slot = described.slot,
        itemClass = described.itemClass,
        itemSubType = described.itemSubType,
        classes = sortedCopy(s.fields.c) or info.classes,
        faction = faction,
        minLevel = (lvl and lvl > 1) and lvl or (not lvl and info.minLevel or nil),
        name = avail.availability == "assumed" and info.name or nil,
      }
      src.collectionRule = M.collectionRule(src, kind, s.fields.b == 1 or info.bop)
      out.sources[s.id] = src

      istats.sources = istats.sources + 1
      if src.quality == nil then istats.nilQuality = istats.nilQuality + 1 end
      if src.slot == nil then istats.nilSlot = istats.nilSlot + 1 end
      if src.itemSubType == nil then istats.nilSubType = istats.nilSubType + 1 end
      if info.qualityConflict and src.quality == nil then stats.qualityConflict = stats.qualityConflict + 1 end
      if items.appearanceItem[s.id] ~= s.itemID and not mismatchSeen[s.id] then
        mismatchSeen[s.id] = true
        stats.appearanceMismatch[#stats.appearanceMismatch + 1] = s.id
      end
    end

    local function walk(n, ctx)
      if excludedByTimeline(n.fields, timeline) then
        local function countSources(x)
          if x.type == "s" then stats.excludedByTimeline = stats.excludedByTimeline + 1 end
          for _, c in ipairs(x.children) do countSources(c) end
        end
        countSources(n)
        return
      end

      local c = { kind = ctx.kind, encounterID = ctx.encounterID, npcID = ctx.npcID, npcBoss = ctx.npcBoss, r = ctx.r }
      -- Boss level: nothing but wing headers and objects between here and the instance.
      c.bossLevel = ctx.bossLevel and ((n.type == "h" and WING_HEADER[n.id]) or n.type == "o")
      if type(n.fields.r) == "number" then c.r = n.fields.r end
      if n.type == "e" then
        c.kind, c.encounterID, c.npcBoss = "boss", n.id, nil
        if not out.encounters[n.id] then
          out.encounters[n.id] = { id = n.id, instanceID = node.id, npcID = n.fields.npcID, journal = true }
          inst.encounters[#inst.encounters + 1] = n.id
        end
      elseif n.type == "n" and ctx.bossLevel and not describedAsRare(n.fields) and dropsSources(n, timeline)
        and (out.encounters[-n.id] == nil or out.encounters[-n.id].instanceID == node.id) then
        c.kind, c.encounterID, c.npcID, c.npcBoss = "boss", -n.id, n.id, true
        if not out.encounters[-n.id] then
          out.encounters[-n.id] = { id = -n.id, instanceID = node.id, npcID = n.id, journal = false }
          inst.encounters[#inst.encounters + 1] = -n.id
        end
      elseif n.type == "q" then
        c.kind, c.encounterID, c.npcBoss = "quest", nil, nil
      elseif n.type == "h" and HEADER_KIND[n.id] then
        c.kind, c.encounterID, c.npcBoss = HEADER_KIND[n.id], nil, nil
      elseif n.type == "n" then
        c.npcID = n.id
      end

      if n.type == "s" then addSource(n, c) end
      for _, child in ipairs(n.children) do walk(child, c) end
    end

    for _, child in ipairs(node.children) do walk(child, { bossLevel = true }) end
  end

  table.sort(stats.duplicateSources)
  table.sort(stats.appearanceMismatch)
  return out
end

return M
