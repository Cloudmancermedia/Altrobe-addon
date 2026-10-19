-- The in-instance window: the relevant bosses of one instance, each with its
-- missing items as icons, under the instance's per-class progress.
--
-- It opens on its own when the player enters a known instance with a
-- relevant boss, and closes when they leave. Closed by the player, it stays
-- closed until the next instance. /altrobe window toggles it or opens a
-- named instance from anywhere. It shows the last plan during combat; the
-- plan itself waits for combat to end (Services/Plan.lua). A plain frame
-- with no protected children, so showing and updating it in combat is
-- allowed. Templates checked against the Forever UI source
-- (Gethe/wow-ui-source@b401e0332adf, 1.60.1.70425): BackdropTemplate,
-- UIPanelCloseButton and UIPanelScrollFrameTemplate; GameTooltip:SetItemByID
-- (Blizzard_SharedXMLGame/Tooltip/TooltipDataHandler.lua). Not yet seen in
-- game, and neither is GetItemInfoInstant's icon return.
local _, ns = ...

local Window = {}
ns.InstanceWindow = Window

local WIDTH, MAX_HEIGHT = 320, 440
local PAD, HEADER = 12, 52
local ICON, ICON_GAP, ICONS_PER_LINE = 22, 3, 10
local LINE = 16
local QUESTION_MARK = "Interface\\Icons\\INV_Misc_QuestionMark"
local OPPORTUNITY_COLOURS = { sure = "ff1eff00", roll = "ffffd100", unknown = "ff9d9d9d" }
local GREY = { 0.5, 0.5, 0.5 }
local GOLD = { 1, 0.82, 0 }

local frame, title, subtitle, content, footer, empty
local rows, icons = {}, {}
local showingID
local auto = false
local dismissedFor
local lastCurrent
local hidingSelf = false

local function settings()
  ns.db.window = ns.db.window or {}
  if ns.db.window.autoOpen == nil then ns.db.window.autoOpen = true end
  return ns.db.window
end

local function coloured(opportunity)
  return ("|c%s%s|r"):format(OPPORTUNITY_COLOURS[opportunity] or OPPORTUNITY_COLOURS.unknown, opportunity or "unknown")
end

local function savePosition()
  local point, _, relativePoint, x, y = frame:GetPoint(1)
  settings().position = { point = point, relativePoint = relativePoint, x = x, y = y }
end

local function create()
  frame = CreateFrame("Frame", "AltrobeInstanceWindow", UIParent, "BackdropTemplate")
  frame:Hide()
  frame:SetSize(WIDTH, MAX_HEIGHT)
  frame:SetFrameStrata("MEDIUM")
  frame:SetClampedToScreen(true)
  frame:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
  })
  frame:SetBackdropColor(0, 0, 0, 0.85)
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    savePosition()
  end)
  frame:SetScript("OnHide", function()
    if not hidingSelf and lastCurrent then dismissedFor = lastCurrent end
  end)

  local position = settings().position
  if position then
    frame:SetPoint(position.point, UIParent, position.relativePoint, position.x, position.y)
  else
    frame:SetPoint("RIGHT", UIParent, "RIGHT", -80, 0)
  end
  table.insert(UISpecialFrames, "AltrobeInstanceWindow")

  local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -2)
  close:SetScript("OnClick", function() frame:Hide() end)

  title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -PAD)
  title:SetPoint("RIGHT", frame, "RIGHT", -32, 0)
  title:SetJustifyH("LEFT")
  subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
  subtitle:SetPoint("RIGHT", frame, "RIGHT", -PAD, 0)
  subtitle:SetJustifyH("LEFT")

  local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -HEADER)
  scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -30, PAD)
  content = CreateFrame("Frame", nil, scroll)
  content:SetSize(WIDTH - PAD - 30, 1)
  scroll:SetScrollChild(content)

  empty = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  empty:SetJustifyH("LEFT")
  footer = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  footer:SetJustifyH("LEFT")
  footer:SetWidth(WIDTH - PAD - 30)
end

local function row(i)
  if not rows[i] then
    local label = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetJustifyH("LEFT")
    rows[i] = label
  end
  return rows[i]
end

local function showTooltip(self)
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  GameTooltip:SetItemByID(self.itemID)
  GameTooltip:Show()
end

local function icon(i)
  if not icons[i] then
    local button = CreateFrame("Button", nil, content)
    button:SetSize(ICON, ICON)
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetAllPoints()
    button.flag = button:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    button.flag:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
    button:SetScript("OnEnter", showTooltip)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    icons[i] = button
  end
  return icons[i]
end

local function progressText(view)
  local parts = {}
  for _, p in ipairs(view.progress) do parts[#parts + 1] = ("%s %d/%d"):format(p.classFile, p.owned, p.total) end
  local text = "Collected: " .. table.concat(parts, ", ")
  if view.note then text = text .. " - " .. view.note end
  return text
end

local function footerText(view)
  local lines = { ("Trash: %d missing, Other: %d missing"):format(view.trash, view.other) }
  if view.notInClient > 0 then
    local plural = view.notInClient == 1 and "" or "s"
    lines[#lines + 1] = ("%d item%s not in the client yet"):format(view.notInClient, plural)
  end
  if view.flags.unresolved or view.flags.levelLocked then
    lines[#lines + 1] = "? incomplete data, * above your level"
  end
  return table.concat(lines, "\n")
end

local function render(view)
  local y, usedRows, usedIcons = 0, 0, 0
  if not view then
    title:SetText("Altrobe")
    subtitle:SetText("")
    empty:SetText("The plan appears after combat.")
  else
    title:SetText(("%s (%s)"):format(view.title, view.kind))
    subtitle:SetText(progressText(view))
    empty:SetText(#view.bosses == 0 and "No boss here drops anything you're missing." or nil)
  end
  if empty:GetText() then
    empty:ClearAllPoints()
    empty:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
    empty:Show()
    y = y + LINE + 6
  else
    empty:Hide()
  end

  for _, boss in ipairs(view and view.bosses or {}) do
    usedRows = usedRows + 1
    local label = row(usedRows)
    label:ClearAllPoints()
    label:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
    if boss.killed then
      label:SetText(("%d. %s - killed"):format(boss.number, boss.name))
      label:SetTextColor(unpack(GREY))
    else
      label:SetText(("%d. %s - %s"):format(boss.number, boss.name, coloured(boss.opportunity)))
      label:SetTextColor(unpack(GOLD))
    end
    label:Show()
    y = y + LINE + 2

    for k, item in ipairs(boss.items) do
      usedIcons = usedIcons + 1
      local button = icon(usedIcons)
      local column, line = (k - 1) % ICONS_PER_LINE, math.floor((k - 1) / ICONS_PER_LINE)
      button:ClearAllPoints()
      button:SetPoint("TOPLEFT", content, "TOPLEFT", column * (ICON + ICON_GAP), -(y + line * (ICON + ICON_GAP)))
      button.itemID = item.itemID
      local _, _, _, _, texture = C_Item.GetItemInfoInstant(item.itemID)
      button.icon:SetTexture(texture or QUESTION_MARK)
      button.icon:SetDesaturated(boss.killed)
      button.flag:SetText((item.unresolved and "?" or "") .. (item.levelLocked and "*" or ""))
      button:Show()
    end
    local lines = math.ceil(#boss.items / ICONS_PER_LINE)
    y = y + lines * (ICON + ICON_GAP) + 6
  end

  for i = usedRows + 1, #rows do rows[i]:Hide() end
  for i = usedIcons + 1, #icons do icons[i]:Hide() end

  if view then
    footer:ClearAllPoints()
    footer:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
    footer:SetText(footerText(view))
    footer:Show()
    y = y + footer:GetStringHeight() + PAD
  else
    footer:Hide()
  end

  content:SetHeight(y)
  frame:SetHeight(math.min(HEADER + y + PAD, MAX_HEIGHT))
end

local function viewOf(plan, instanceID)
  return ns.WindowModel.Build(plan, ns.Data, ns.Profile.Get().classes, instanceID)
end

local function open(plan, instanceID, isAuto)
  if not frame then create() end
  showingID, auto = instanceID, isAuto
  render(viewOf(plan, instanceID))
  frame:Show()
end

local function hideSelf()
  hidingSelf = true
  frame:Hide()
  hidingSelf = false
end

local function shown()
  return frame ~= nil and frame:IsShown()
end

local function onPlan(plan)
  local current = plan.current
  if current ~= lastCurrent then dismissedFor = nil end
  lastCurrent = current

  if current and shown() and showingID == current then
    render(viewOf(plan, current))
  elseif current and not (shown() and not auto) and settings().autoOpen and dismissedFor ~= current then
    local view = viewOf(plan, current)
    if view and #view.bosses > 0 then open(plan, current, true) end
  elseif shown() and auto and not current then
    hideSelf()
  elseif shown() then
    render(viewOf(plan, showingID))
  end
end

ns.Plan.OnUpdate(onPlan)

local function command(rest)
  local setting = rest:match("^auto%s+(%a+)$")
  if setting == "on" or setting == "off" then
    settings().autoOpen = setting == "on"
    ns.Print(("The window opens on entering an instance: %s."):format(setting))
    return
  end

  if rest == "" then
    if shown() then
      frame:Hide()
      return
    end
    local context = ns.InstanceContext.Current()
    if not context then
      ns.Print("You're not in a dungeon or raid Altrobe knows. Try /altrobe window <instance name>.")
      return
    end
    dismissedFor = nil
    open(ns.Plan.Get(), context.instanceID, true)
    return
  end

  local found = ns.InstanceContext.Find(rest)
  if #found == 0 then
    ns.Print(("No instance matches %q."):format(rest))
  elseif #found > 1 then
    ns.Print("Which one? " .. ns.InstanceContext.Names(found))
  else
    open(ns.Plan.Get(), found[1], false)
  end
end

ns.RegisterCommand("window", command, "toggle the boss window, open it for a named instance, or 'auto on|off'")
