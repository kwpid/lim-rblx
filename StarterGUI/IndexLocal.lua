local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local gui = script.Parent
local buttons = {}

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

  for _, button in pairs(buttons) do
    button:Destroy()
  end
  buttons = {}

  table.sort(allItems, function(a, b)
    if a.Value ~= b.Value then
      return a.Value > b.Value
    elseif a.Rarity ~= b.Rarity then
      return a.Rarity > b.Rarity
    else
      return a.Name < b.Name
    end
  end)

  for i, item in ipairs(allItems) do
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

    -- Display stock info
    local qtyLabel = button:FindFirstChild("Qty")
    if qtyLabel then
      if item.Stock and item.Stock > 0 then
        qtyLabel.Text = item.CurrentStock .. "/" .. item.Stock
      else
        qtyLabel.Text = "∞"
      end
    end

    -- Display rarity (hide if Common)
    local rarityLabel = contentFrame and contentFrame:FindFirstChild("Rarity")
    if rarityLabel then
      if item.Rarity == "Common" then
        rarityLabel.Visible = false
      else
        rarityLabel.Visible = true
        rarityLabel.Text = item.Rarity
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
      local ownersCount = item.Owners or 0
      local stockCount = item.Stock or 0

      if ownersCount > 0 then
        if stockCount > 0 then
          copiesLabel.Text = "copies: " .. ownersCount .. " / " .. stockCount .. " exist"
        else
          copiesLabel.Text = "copies: " .. ownersCount
        end
        copiesLabel.Visible = true
      else
        copiesLabel.Visible = false
      end
    end

    -- Also update o2 label
    local o2Label = contentFrame and contentFrame:FindFirstChild("o2")
    if o2Label then
      local ownersCount = item.Owners or 0
      if item.Stock and item.Stock > 0 then
        o2Label.Text = formatNumber(ownersCount) .. "/" .. formatNumber(item.Stock)
      else
        o2Label.Text = formatNumber(ownersCount)
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

          -- Get owners from server
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
    end)
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

-- Listen for when the GUI is opened (Enabled property changes to true)
gui:GetPropertyChangedSignal("Enabled"):Connect(function()
  if gui.Enabled then
    -- Refresh data whenever the index is opened
    pcall(refresh)
  end
end)

-- Listen for item database updates (when new items are created)
local createItemEvent = remoteEvents:FindFirstChild("CreateItemEvent")
if createItemEvent then
  createItemEvent.OnClientEvent:Connect(function()
    task.wait(0.5)
    pcall(refresh)
  end)
end
