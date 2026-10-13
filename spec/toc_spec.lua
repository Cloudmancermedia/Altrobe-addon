describe("Altrobe.toc", function()
  local function tocFiles()
    local files = {}
    for line in io.lines("Altrobe.toc") do
      if line ~= "" and not line:match("^##") then
        files[#files + 1] = (line:gsub("\\", "/"))
      end
    end
    return files
  end

  it("lists only files that exist", function()
    for _, path in ipairs(tocFiles()) do
      local f = io.open(path)
      assert.is_not_nil(f, path .. " is listed in the TOC but missing")
      if f then f:close() end
    end
  end)

  it("targets the Forever client", function()
    local toc = assert(io.open("Altrobe.toc")):read("*a")
    assert.matches("## Interface: 16001", toc)
  end)
end)
