local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local gui = script.Parent
local buttons = {}

-- Load the ItemRarityModule
local ItemRarityModule = require(ReplicatedStorage:WaitForChild("ItemRarityModule"))

-- Get the actual ScreenGui (parent of the frame the script is in)
local screenGui = gui
while screenGui and not screenGui:IsA("ScreenGui") do
  screenGui = screenGui.Parent
end

local handler = gui:WaitForChild("Handler", 5)
if not handler then
  warn("❌ Handler not found in Index GUI")
  return
end

local sample = script.Sample
if not sample then
  warn("❌ Sample template not found in Handler")
  return
end

local userTemplate = script:FindFirstChild("UserTemplate")
if not userTemplate then
  warn("❌ UserTemplate not found in IndexLocal script")
  return
end

local frame = gui:WaitForChild("Frame", 5)
if not frame then
  warn("❌ Frame not found in Index GUI")
  return
end

local searchBar = gui:FindFirstChild("SearchBar")

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

local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents", 10)
if not remoteEvents then
  warn("❌ RemoteEvents folder not found")
  return
end

local getAllItemsFunction = remoteEvents:WaitForChild("GetAllItemsFunction", 10)
if not getAllItemsFunction then
  warn("❌ GetAllItemsFunction not found")
  return
end

local getItemOwnersFunction = remoteEvents:WaitForChild("GetItemOwnersFunction", 10)
if not getItemOwnersFunction then
  warn("❌ GetItemOwnersFunction not found")
  return
end

-- Rarity colors matching our 8-tier system
local rarityColors = {
  ["Common"] = Color3.fromRGB(170, 170, 170),
  ["Uncommon"] = Color3.fromRGB(85, 170, 85),
  ["Rare"] = Color3.fromRGB(85, 85, 255),
  ["Ultra Rare"] = Color3.fromRGB(170, 85, 255),
  ["Epic"] = Color3.fromRGB(255, 170, 0),
  ["Ultra Epic"] = Color3.fromRGB(255, 85, 0),
  ["Mythic"] = Color3.fromRGB(255, 0, 0),
  ["Insane"] = Color3.fromRGB(255, 0, 255)
}

function formatNumber(n)
  local formatted = tostring(n)
  while true do
    formatted, k = formatted:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
    if k == 0 then break end
  end
  return formatted
end

function refresh()
  local allItems
  local success, err = pcall(function()
    allItems = getAllItemsFunction:InvokeServer()
  end)

  if not success or not allItems or type(allItems) ~= "table" then
    warn("❌ Failed to get all items: " .. tostring(err))
    return
  end

  -- Calculate roll percentages for all items
  local itemsWithPercentages = ItemRarityModule:CalculateAllRollPercentages(allItems)

  -- Store the currently selected item ID to re-select it after refresh
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
    local button = sample:Clone()
    button.Name = item.Name or "Item_" .. i
    button.LayoutOrder = i
    button.Visible = true
    button.Parent = handler

    local contentFrame = button:FindFirstChild("Content")
    local content2Frame = button:FindFirstChild("content2")

    -- Set rarity colors
    if contentFrame then
      local rarityColor = rarityColors[item.Rarity] or Color3.new(1, 1, 1)
      contentFrame.BorderColor3 = rarityColor
    end
    if content2Frame then
      local rarityColor = rarityColors[item.Rarity] or Color3.new(1, 1, 1)
      content2Frame.BorderColor3 = rarityColor
    end

    -- Calculate the number of copies
    local copiesCount = 0
    if item.Stock and item.Stock > 0 then
      -- Stock item: use CurrentStock (number of serials claimed)
      copiesCount = item.CurrentStock or 0
    else
      -- Regular item: use Owners (unique players who own it)
      copiesCount = item.Owners or 0
    end
    
    -- Display stock info
    local qtyLabel = button:FindFirstChild("Qty")
    if qtyLabel then
      if item.Stock and item.Stock > 0 then
        qtyLabel.Text = copiesCount .. "/" .. item.Stock
      else
        qtyLabel.Text = "∞"
      end
    end

    -- Display rarity with roll percentage (hide if Common)
    local rarityLabel = contentFrame and contentFrame:FindFirstChild("Rarity")
    if rarityLabel then
      if item.Rarity == "Common" then
        rarityLabel.Visible = false
      else
        rarityLabel.Visible = true
        -- Format percentage with 2 decimal places
        local percentText = string.format("%.2f%%", item.RollPercentage or 0)
        rarityLabel.Text = item.Rarity .. " | " .. percentText
        rarityLabel.TextColor3 = rarityColors[item.Rarity] or Color3.new(1, 1, 1)
      end
    end

    -- Hide t1 label
    local t1Label = button:FindFirstChild("t1")
    if t1Label then
      t1Label.Visible = false
    end

    -- Display owners count
    local copiesLabel = button:FindFirstChild("copies")
    if copiesLabel then
      local stockCount = item.Stock or 0

      if copiesCount > 0 then
        if stockCount > 0 then
          copiesLabel.Text = "copies: " .. copiesCount .. " / " .. stockCount .. " exist"
        else
          copiesLabel.Text = "copies: " .. copiesCount
        end
        copiesLabel.Visible = true
      else
        copiesLabel.Visible = false
      end
    end

    -- Also update o2 label to show copies count
    local o2Label = contentFrame and contentFrame:FindFirstChild("o2")
    if o2Label then
      if item.Stock and item.Stock > 0 then
        o2Label.Text = formatNumber(copiesCount) .. "/" .. formatNumber(item.Stock)
      else
        o2Label.Text = formatNumber(copiesCount)
      end
    end

    -- Display value
    local valueLabel = contentFrame and contentFrame:FindFirstChild("Value")
    if valueLabel then
      valueLabel.Text = "R$ " .. formatNumber(item.Value)
    end

    local v2Label = contentFrame and contentFrame:FindFirstChild("v2")
    if v2Label then
      v2Label.Text = formatNumber(item.Value)
    end

    -- Display name
    local nameLabel = content2Frame and content2Frame:FindFirstChild("name")
    if nameLabel then
      local displayName = item.Name
      if #displayName > 20 then
        displayName = string.sub(displayName, 1, 17) .. "..."
      end
      nameLabel.Text = displayName
    end

    -- Set item image
    local img = button:FindFirstChild("Image")
    if img and img:IsA("ImageLabel") then
      img.Image = "rbxthumb://type=Asset&id=" .. item.RobloxId .. "&w=150&h=150"
    end

    table.insert(buttons, button)

    -- Click handler to show item details
    button.MouseButton1Click:Connect(function()
      updateItemDetails(item)
    end)
  end

  -- If an item was previously selected, re-select it with fresh data
  if currentlySelectedId then
    for _, item in ipairs(itemsWithPercentages) do
      if item.RobloxId == currentlySelectedId then
        updateItemDetails(item)
        break
      end
    end
  end
end

-- Helper function to update item details panel
function updateItemDetails(item)
  selectedItemData = item
  selected.Value = item.Name

  -- Update frame details
  local itemNameText = frame:FindFirstChild("ItemName")
  local totalOwnersText = frame:FindFirstChild("TotalOwners")
  local valueText = frame:FindFirstChild("Value")
  local ownerList = frame:FindFirstChild("OwnerList")

  if itemNameText then
    itemNameText.Text = item.Name
  end

  if totalOwnersText then
    totalOwnersText.Text = "Owners: " .. formatNumber(item.Owners or 0)
  end

  if valueText then
    valueText.Text = "R$ " .. formatNumber(item.Value)
  end

  -- Show/hide OwnerList based on if it's a stock item
  if ownerList then
    local isStockItem = item.Stock and item.Stock > 0
    ownerList.Visible = isStockItem

    if isStockItem then
      -- Clear previous owner entries
      for _, child in ipairs(ownerList:GetChildren()) do
        if child:IsA("Frame") or child:IsA("TextButton") then
          child:Destroy()
        end
      end

      -- Get fresh owners data from server (always fetch latest)
      local success, owners = pcall(function()
        return getItemOwnersFunction:InvokeServer(item.RobloxId)
      end)

      if success and owners and type(owners) == "table" then
        -- Create owner entries (already sorted by serial number from server)
        for i, owner in ipairs(owners) do
          local ownerEntry = userTemplate:Clone()
          ownerEntry.Name = "Owner_" .. i
          ownerEntry.LayoutOrder = i
          ownerEntry.Visible = true
          ownerEntry.Parent = ownerList

          -- Set username with @ prefix
          local usernameLabel = ownerEntry:FindFirstChild("Username")
          if usernameLabel then
            usernameLabel.Text = "@" .. owner.Username
          end

          -- Set serial with # prefix
          local serialLabel = ownerEntry:FindFirstChild("Serial")
          if serialLabel then
            serialLabel.Text = "#" .. owner.SerialNumber
          end

          -- Set player avatar (PFP)
          local pfpImage = ownerEntry:FindFirstChild("PlayerPFP")
          if pfpImage and pfpImage:IsA("ImageLabel") then
            pfpImage.Image = "rbxthumb://type=AvatarHeadShot&id=" .. owner.UserId .. "&w=150&h=150"
          end
        end
      else
        warn("❌ Failed to get item owners: " .. tostring(owners))
      end
    end
  end
end

-- Search bar functionality
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

-- Auto-refresh every 3 minutes
task.spawn(function()
  while true do
    task.wait(180) -- 3 minutes
    if screenGui and screenGui.Enabled then
      pcall(refresh)
    end
  end
end)

-- Listen for when the GUI is opened (Enabled property changes to true)
if screenGui then
  screenGui:GetPropertyChangedSignal("Enabled"):Connect(function()
    if screenGui.Enabled then
      -- Refresh data whenever the index is opened
      pcall(refresh)
    end
  end)
end

-- Listen for item database updates (when new items are created)
local createItemEvent = remoteEvents:FindFirstChild("CreateItemEvent")
if createItemEvent then
  createItemEvent.OnClientEvent:Connect(function()
    task.wait(0.5)
    pcall(refresh)
  end)
end
