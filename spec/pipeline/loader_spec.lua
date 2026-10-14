local loader = require("tools.loader")

describe("loader", function()
  local header = 'local appName, _ = ...\n_.AddEventHandler("OnBuildDataCache", function(categories)\n'
    .. 'local e,h,i,inst,q,s=_.CreateEncounter,_.CreateCustomHeader,_.CreateItem,'
    .. '_.CreateInstance,_.CreateQuest,_.CreateItemSource;\n'

  local function load(body)
    return loader.loadString(header .. body .. "\nend)", "fixture")
  end

  it("builds a node tree from the upstream constructors", function()
    local root = load([[categories.Instances={
inst(2959,{maps={1501},g={
  h(-46,{e(3310)}),
  e(3311,{npcID=247126,g={s(308394,273033,{f=33}),i(273032,{f=52})}}),
}})}]])
    local instance = root.Instances[1]
    assert.are.equal("inst", instance.type)
    assert.are.equal(2959, instance.id)
    assert.are.same({ 1501 }, instance.fields.maps)

    local headerNode = instance.children[1]
    assert.are.equal("h", headerNode.type)
    assert.are.equal(-46, headerNode.id)
    assert.are.equal(3310, headerNode.children[1].id)

    local boss = instance.children[2]
    assert.are.equal("e", boss.type)
    assert.are.equal(247126, boss.fields.npcID)
    local source = boss.children[1]
    assert.are.equal("s", source.type)
    assert.are.equal(308394, source.id)
    assert.are.equal(273033, source.itemID)
    assert.are.equal(33, source.fields.f)
    assert.are.equal("i", boss.children[2].type)
    assert.are.equal(273032, boss.children[2].id)
  end)

  it("tolerates references to other app fields", function()
    local root = load([[categories.Instances={
inst(1,{OnTooltip=_.OnTooltipDB.Foo,icon=_.asset("x"),g={}})}]])
    assert.are.equal(1, root.Instances[1].id)
  end)

  it("exposes no host library to the data file", function()
    local ok, err = pcall(load, "categories.Instances = { io.open('x') }")
    assert.is_false(ok)
    assert.matches("io", err)
  end)

  it("refuses precompiled bytecode", function()
    local ok, err = pcall(loader.loadString, string.dump(function() end), "bytecode")
    assert.is_false(ok)
    assert.matches("bytecode", err)
  end)

  it("stops a data file that never finishes", function()
    local ok, err = pcall(load, "while true do end")
    assert.is_false(ok)
    assert.matches("instruction limit", err)
  end)
end)
