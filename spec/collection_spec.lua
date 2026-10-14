local env = require("spec.helpers.wow_env")

describe("Collection", function()
  local ns, invalidated, t

  local function source(id, itemID)
    return { id = id, itemID = itemID, instanceID = 100, kind = "boss", collectionRule = "unknown" }
  end

  before_each(function()
    env.reset()
    ns = env.load({ "Core.lua", "Services/Collection.lua" })
    ns.Data = { sources = { [1] = source(1, 101), [2] = source(2, 102), [3] = source(3, 103) } }
    invalidated = 0
    ns.Plan = { Invalidate = function() invalidated = invalidated + 1 end }
    t = env.transmog
    t.visualOf = { [1] = 10, [2] = 10, [3] = 30, [99] = 30 }
  end)

  describe("ownership", function()
    it("resolves visuals per source and reads owned sources and appearances", function()
      t.ownedSources = { [1] = true }
      t.ownedVisuals = { [10] = true, [30] = true } -- 30 through source 99, outside the data
      assert.are.same({
        visualOf = { [1] = 10, [2] = 10, [3] = 30 },
        ownedVisuals = { [10] = true, [30] = true },
        ownedSources = { [1] = true },
      }, ns.Collection.Get())
    end)

    it("caches until the collection changes", function()
      ns.Collection.Get()
      local calls = t.calls
      ns.Collection.Get()
      assert.are.equal(calls, t.calls)
    end)

    it("derives owned appearances from owned sources when the client gives no appearance info", function()
      t.appearanceInfo = false
      t.ownedSources = { [2] = true }
      t.ownedVisuals = { [30] = true }
      assert.are.same({ [10] = true }, ns.Collection.Get().ownedVisuals)
    end)

    it("leaves an unresolved visual out and retries it after a collection update", function()
      t.visualOf[3] = nil
      assert.is_nil(ns.Collection.Get().visualOf[3])
      t.visualOf[3] = 30
      env.fire(ns, "TRANSMOG_COLLECTION_UPDATED")
      assert.are.equal(30, ns.Collection.Get().visualOf[3])
      assert.are.equal(1, invalidated)
    end)

    it("adds one learned source without a full rescan", function()
      ns.Collection.Get()
      local calls = t.calls
      t.ownedSources[2] = true
      env.fire(ns, "TRANSMOG_COLLECTION_SOURCE_ADDED", 2)
      local c = ns.Collection.Get()
      assert.is_true(c.ownedSources[2])
      assert.is_true(c.ownedVisuals[10])
      assert.is_true(t.calls - calls <= 2)
      assert.are.equal(1, invalidated)
    end)

    it("marks an appearance owned when a source outside the data shares it", function()
      ns.Collection.Get()
      env.fire(ns, "TRANSMOG_COLLECTION_SOURCE_ADDED", 99)
      local c = ns.Collection.Get()
      assert.is_true(c.ownedVisuals[30])
      assert.is_nil(c.ownedSources[99])
    end)

    it("removes a source and rechecks its appearance", function()
      t.ownedSources = { [1] = true }
      t.ownedVisuals = { [10] = true }
      ns.Collection.Get()
      t.ownedSources[1] = nil
      t.ownedVisuals[10] = nil
      env.fire(ns, "TRANSMOG_COLLECTION_SOURCE_REMOVED", 1)
      local c = ns.Collection.Get()
      assert.is_nil(c.ownedSources[1])
      assert.is_nil(c.ownedVisuals[10])
    end)
  end)

  describe("item facts", function()
    it("reads cached items at once", function()
      env.items[101] = { name = "Robe", quality = 3, bindType = 1, cached = true }
      ns.Collection.RequestItems({ 101 })
      assert.are.same({ [101] = { quality = 3, bindType = 1 } }, ns.Collection.ItemFacts())
      assert.matches("%[Robe%]", ns.Collection.ItemLink(101))
      assert.are.same({}, env.itemRequests)
    end)

    it("loads uncached items and fills them when the client answers", function()
      env.items[102] = { name = "Dagger", quality = 2, bindType = 1 }
      ns.Collection.RequestItems({ 102 })
      assert.are.same({ 102 }, env.itemRequests)
      assert.is_nil(ns.Collection.ItemFacts()[102])
      assert.is_nil(ns.Collection.ItemLink(102))

      env.items[102].cached = true
      env.fire(ns, "GET_ITEM_INFO_RECEIVED", 102, true)
      assert.are.same({ quality = 2, bindType = 1 }, ns.Collection.ItemFacts()[102])
      assert.are.equal(1, invalidated)
    end)

    it("never records facts for an item that failed to load", function()
      ns.Collection.RequestItems({ 103 })
      env.fire(ns, "GET_ITEM_INFO_RECEIVED", 103, false)
      assert.is_nil(ns.Collection.ItemFacts()[103])
      env.fire(ns, "GET_ITEM_INFO_RECEIVED", 555, true)
      assert.are.equal(0, invalidated)
    end)

    it("requests items in small batches and puts urgent ones first", function()
      local ids = {}
      for i = 1, 45 do ids[i] = 1000 + i end
      ns.Collection.RequestItems(ids)
      assert.are.equal(20, #env.itemRequests)
      ns.Collection.RequestItems({ 7 }, true)
      env.runTimers()
      assert.are.equal(7, env.itemRequests[21])
      assert.are.equal(46, #env.itemRequests)
      ns.Collection.RequestItems(ids)
      assert.are.equal(46, #env.itemRequests)
    end)
  end)
end)
