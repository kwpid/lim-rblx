local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local gui = script.Parent
local buttons = {}
local mouse = player:GetMouse()

local ItemRarityModule = require(ReplicatedStorage:WaitForChild("ItemRarityModule"))

local handler = gui:WaitForChild("Handler", 5)
if not handler then
  warn("handler not found in index gui")
  return
end

local sample = script.Sample
if not sample then
  warn("sample template not found in handler")
  return
end

local userTemplate = script:FindFirstChild("UserTemplate")
if not userTemplate then
  warn("usertemplate not found in indexlocal script")
  return
end

local popup = gui:WaitForChild("Popup", 5)
if not popup then
  warn("popup not found in index gui")
  return
end

popup.Visible = false

local searchBar = gui:FindFirstChild("SearchBar")

local tooltip = nil

local selected = handler:FindFirstChild("Selected")
if not selected then
  selected = Instance.new("StringValue")
  selected.Name = "Selected"
  selected.Parent = handler
elseif not selected:IsA("StringValue") then
  selected:Destroy()
  selected = Instance.new("StringValue")
  selected.Name = "Selected"
  selected.Parent = handler
end

local selectedItemData = nil
local selectedButton = nil

local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents", 10)
if not remoteEvents then
  warn("remoteevents folder not found")
  return
end

local getAllItemsFunction = remoteEvents:WaitForChild("GetAllItemsFunction", 10)
if not getAllItemsFunction then
  warn("getallitemsfunction not found")
  return
end

local getItemOwnersFunction = remoteEvents:WaitForChild("GetItemOwnersFunction", 10)
if not getItemOwnersFunction then
  warn("getitemownersfunction not found")
  return
end

local rarityColors = {
  ["Common"] = Color3.fromRGB(170, 170, 170),
  ["Uncommon"] = Color3.fromRGB(85, 170, 85),
  ["Rare"] = Color3.fromRGB(85, 85, 255),
  ["Ultra Rare"] = Color3.fromRGB(170, 85, 255),
  ["Epic"] = Color3.fromRGB(255, 170, 0),
  ["Ultra Epic"] = Color3.fromRGB(255, 85, 0),
  ["Mythic"] = Color3.fromRGB(255, 0, 0),
  ["Insane"] = Color3.fromRGB(255, 0, 255),
  ["Limited"] = Color3.fromRGB(255, 215, 0),
  ["Vanity"] = Color3.fromRGB(255, 105, 180)
}

function formatNumber(n)
  local formatted = tostring(n)
  while true do
    formatted, k = formatted:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
    if k == 0 then break end
  end
  return formatted
end

function showPopup()
  popup.Visible = true
end

function hidePopup()
  popup.Visible = false
end

function clearSelection()
  if selectedButton then
    local uiStroke = selectedButton:FindFirstChildOfClass("UIStroke")
    if uiStroke then
      uiStroke.Thickness = 2
    end
    selectedButton = nil
  end

  selectedItemData = nil
  selected.Value = ""
end

function showTooltip(item, button)
  hideTooltip()

  tooltip = Instance.new("Frame")
  tooltip.Name = "Tooltip"
  tooltip.Size = UDim2.new(0, 180, 0, 60)
  tooltip.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
  tooltip.BorderSizePixel = 2
  tooltip.BorderColor3 = Color3.fromRGB(255, 255, 255)
  tooltip.ZIndex = 1000
  tooltip.Parent = gui

  local uiCorner = Instance.new("UICorner")
  uiCorner.CornerRadius = UDim.new(0, 8)
  uiCorner.Parent = tooltip

  local valueLabel = Instance.new("TextLabel")
  valueLabel.Name = "Value"
  valueLabel.Size = UDim2.new(1, -10, 0, 25)
  valueLabel.Position = UDim2.new(0, 5, 0, 5)
  valueLabel.BackgroundTransparency = 1
  valueLabel.Text = "R$ " .. formatNumber(item.Value)
  valueLabel.TextColor3 = Color3.fromRGB(85, 255, 85)
  valueLabel.TextSize = 16
  valueLabel.Font = Enum.Font.GothamBold
  valueLabel.TextXAlignment = Enum.TextXAlignment.Left
  valueLabel.Parent = tooltip

  local rollLabel = Instance.new("TextLabel")
  rollLabel.Name = "RollPercent"
  rollLabel.Size = UDim2.new(1, -10, 0, 20)
  rollLabel.Position = UDim2.new(0, 5, 0, 30)
  rollLabel.BackgroundTransparency = 1
  rollLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
  rollLabel.TextSize = 14
  rollLabel.Font = Enum.Font.Gotham
  rollLabel.TextXAlignment = Enum.TextXAlignment.Left
  rollLabel.Parent = tooltip

  if item.Rarity == "Limited" then
    rollLabel.Text = "Not Rollable"
  else
    local percentage = item.RollPercentage or 0
    local percentText = string.format("%.10f", percentage)

    local decimalPart = percentText:match("%.(%d+)")
    local firstNonZeroPos = 4

    if decimalPart then
      for i = 1, #decimalPart do
        if decimalPart:sub(i, i) ~= "0" then
          firstNonZeroPos = math.max(4, i)
          break
        end
      end
    end

    percentText = string.format("%." .. firstNonZeroPos .. "f%%", percentage)
    percentText = percentText:gsub("(%d)0+%%", "%1%%"):gsub("%.0+%%", "%%")
    rollLabel.Text = percentText
  end

  tooltip.Position = UDim2.new(0, button.AbsolutePosition.X - gui.AbsolutePosition.X + button.AbsoluteSize.X + 10, 0,
    button.AbsolutePosition.Y - gui.AbsolutePosition.Y)
end

function hideTooltip()
  if tooltip then
    tooltip:Destroy()
    tooltip = nil
  end
end

function refresh()
  local allItems
  local success, err = pcall(function()
    allItems = getAllItemsFunction:InvokeServer()
  end)

  if not success or not allItems or type(allItems) ~= "table" then
    warn("failed to get all items: " .. tostring(err))
    return
  end

  local itemsWithPercentages = ItemRarityModule:CalculateAllRollPercentages(allItems)

  local currentlySelectedId = selectedItemData and selectedItemData.RobloxId or nil

  for _, button in pairs(buttons) do
    button:Destroy()
  end
  buttons = {}

  table.sort(itemsWithPercentages, function(a, b)
    if a.Value ~= b.Value then
      return a.Value > b.Value
    elseif a.Rarity ~= b.Rarity then
      return a.Rarity > b.Rarity
    else
      return a.Name < b.Name
    end
  end)

  for i, item in ipairs(itemsWithPercentages) do
    if item.Rarity ~= "Vanity" then
      local button = sample:Clone()
      button.Name = item.Name or "Item_" .. i
      button.LayoutOrder = i
      button.Visible = true
      button.Parent = handler

      local uiStroke = button:FindFirstChildOfClass("UIStroke")
      if uiStroke then
        local rarityColor = rarityColors[item.Rarity] or Color3.new(1, 1, 1)
        uiStroke.Color = rarityColor
        uiStroke.Thickness = 2
      end

      local copiesCount = 0
      if item.Stock and item.Stock > 0 then
        copiesCount = item.CurrentStock or 0
      else
        copiesCount = item.TotalCopies or 0
      end

      local rareText = button:FindFirstChild("RareText")
      if rareText then
        if copiesCount > 0 and copiesCount <= 25 then
          rareText.Visible = true
        else
          rareText.Visible = false
        end
      end

      local limText = button:FindFirstChild("LimText")
      if limText then
        if item.Rarity == "Limited" then
          limText.Visible = true
        else
          limText.Visible = false
        end
      end

      if button:IsA("ImageButton") then
        button.Image = "rbxthumb://type=Asset&id=" .. item.RobloxId .. "&w=150&h=150"
      end

      table.insert(buttons, button)

      button.MouseButton1Click:Connect(function()
        if selectedButton and selectedButton ~= button then
          local prevStroke = selectedButton:FindFirstChildOfClass("UIStroke")
          if prevStroke then
            prevStroke.Thickness = 2
          end
        end

        if uiStroke then
          uiStroke.Thickness = 4
        end

        selectedButton = button
        updateItemDetails(item)
      end)

      button.MouseEnter:Connect(function()
        showTooltip(item, button)
      end)

      button.MouseLeave:Connect(function()
        hideTooltip()
      end)
    end
  end

  if currentlySelectedId then
    for _, item in ipairs(itemsWithPercentages) do
      if item.RobloxId == currentlySelectedId then
        updateItemDetails(item)
        break
      end
    end
  end
end

function updateItemDetails(item)
  selectedItemData = item
  selected.Value = item.Name

  local pop = popup:FindFirstChild("Pop")
  if not pop then
    warn("Pop frame not found in Popup")
    return
  end

  local itemInfo = pop:FindFirstChild("ItemInfo")
  local itemInfo2 = pop:FindFirstChild("ItemInfo2")
  local ownerList = pop:FindFirstChild("OwnerList")

  if itemInfo then
    local itemPhoto = itemInfo:FindFirstChild("ItemPhoto")
    if itemPhoto and itemPhoto:IsA("ImageLabel") then
      itemPhoto.Image = "rbxthumb://type=Asset&id=" .. item.RobloxId .. "&w=420&h=420"
    end

    local itemName = itemInfo:FindFirstChild("ItemName")
    if itemName then
      itemName.Text = item.Name
    end

    local valueText = itemInfo:FindFirstChild("Value")
    if valueText then
      valueText.Text = "R$ " .. formatNumber(item.Value)
    end
  end

  if itemInfo2 then
    local totalOwnersText = itemInfo2:FindFirstChild("TotalOwners")
    if totalOwnersText then
      local isStockItem = item.Stock and item.Stock > 0
      if isStockItem then
        local currentCopies = item.CurrentStock or 0
        local maxCopies = item.Stock or 0
        totalOwnersText.Text = currentCopies .. "/" .. maxCopies
      else
        totalOwnersText.Text = formatNumber(item.Owners or 0)
      end
    end
  end

  local isStockItem = item.Stock and item.Stock > 0

  if ownerList then
    ownerList.Visible = isStockItem

    if isStockItem then
      for _, child in ipairs(ownerList:GetChildren()) do
        if child:IsA("Frame") or child:IsA("TextButton") then
          child:Destroy()
        end
      end

      local success, owners = pcall(function()
        return getItemOwnersFunction:InvokeServer(item.RobloxId)
      end)

      if success and owners and type(owners) == "table" then
        for i, owner in ipairs(owners) do
          local ownerEntry = userTemplate:Clone()
          ownerEntry.Name = "Owner_" .. i
          ownerEntry.LayoutOrder = i
          ownerEntry.Visible = true
          ownerEntry.Parent = ownerList

          local usernameLabel = ownerEntry:FindFirstChild("Username")
          if usernameLabel then
            usernameLabel.Text = "@" .. owner.Username
          end

          local serialLabel = ownerEntry:FindFirstChild("Serial")
          if serialLabel then
            serialLabel.Text = "#" .. owner.SerialNumber
          end

          local pfpImage = ownerEntry:FindFirstChild("PlayerPFP")
          if pfpImage and pfpImage:IsA("ImageLabel") then
            pfpImage.Image = "rbxthumb://type=AvatarHeadShot&id=" .. owner.UserId .. "&w=150&h=150"
          end
        end
      else
        warn("failed to get item owners: " .. tostring(owners))
      end
    end
  end

  showPopup()
end

if searchBar and searchBar:IsA("TextBox") then
  searchBar:GetPropertyChangedSignal("Text"):Connect(function()
    local filterText = searchBar.Text:lower()
    for _, button in pairs(buttons) do
      local itemName = button.Name:lower()
      button.Visible = filterText == "" or itemName:find(filterText, 1, true) ~= nil
    end
  end)
end

task.wait(1)
pcall(refresh)

task.spawn(function()
  while true do
    task.wait(180)
    if gui.Visible then
      pcall(refresh)
    end
  end
end)

gui:GetPropertyChangedSignal("Visible"):Connect(function()
  if gui.Visible then
    pcall(refresh)
  end
end)

local createItemEvent = remoteEvents:FindFirstChild("CreateItemEvent")
if createItemEvent then
  createItemEvent.OnClientEvent:Connect(function()
    task.wait(0.5)
    pcall(refresh)
  end)
end

local pop = popup:FindFirstChild("Pop")
if pop then
  local closeButton = pop:FindFirstChild("Close")
  if closeButton then
    closeButton.MouseButton1Click:Connect(function()
      hidePopup()
      clearSelection()
    end)
  end
end
