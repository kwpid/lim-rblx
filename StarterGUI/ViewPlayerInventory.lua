local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local gui = script.Parent
local buttons = {}

local currentlyViewingPlayer = nil
local highlightedPlayer = nil
local glowEffect = nil

-- Get the actual ScreenGui (parent of the frame the script is in)
local screenGui = gui
while screenGui and not screenGui:IsA("ScreenGui") do
  screenGui = screenGui.Parent
end

if not screenGui then
  warn("❌ ViewPlayerInventory: ScreenGui not found")
  return
end

-- Start with GUI disabled
screenGui.Enabled = false

local handler = gui:WaitForChild("Handler", 5)
if not handler then
  warn("❌ Handler not found in ViewPlayerInventory GUI")
  return
end

local sample = script.Sample
if not sample then
  warn("❌ Sample template not found in ViewPlayerInventory script")
  return
end

local titleLabel = gui:FindFirstChild("Title")
if not titleLabel then
  warn("❌ Title label not found in ViewPlayerInventory GUI")
end

local closeButton = gui:FindFirstChild("Close")
if not closeButton then
  warn("❌ Close button not found in ViewPlayerInventory GUI")
end

local searchBar = gui:FindFirstChild("SearchBar")

local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents", 10)
if not remoteEvents then
  warn("❌ RemoteEvents folder not found")
  return
end

local getPlayerInventoryFunction = remoteEvents:WaitForChild("GetPlayerInventoryFunction", 10)
if not getPlayerInventoryFunction then
  warn("❌ GetPlayerInventoryFunction not found")
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

-- Function to create glow effect on a character
function createGlowEffect(character)
  if not character then return nil end
  
  -- Check if character already has a glow
  local existingGlow = character:FindFirstChild("PlayerViewGlow")
  if existingGlow then
    return existingGlow
  end
  
  -- Create a Highlight effect
  local highlight = Instance.new("Highlight")
  highlight.Name = "PlayerViewGlow"
  highlight.Adornee = character
  highlight.FillColor = Color3.fromRGB(255, 255, 0) -- Yellow glow
  highlight.FillTransparency = 0.5
  highlight.OutlineColor = Color3.fromRGB(255, 255, 0)
  highlight.OutlineTransparency = 0
  highlight.Parent = character
  
  return highlight
end

-- Function to remove glow effect
function removeGlowEffect(character)
  if not character then return end
  
  local glow = character:FindFirstChild("PlayerViewGlow")
  if glow then
    glow:Destroy()
  end
end

-- Function to get player from mouse target
function getPlayerFromMouse()
  local target = mouse.Target
  if not target then return nil end
  
  -- Find the character model
  local character = target
  while character and not character:FindFirstChild("Humanoid") do
    character = character.Parent
  end
  
  if not character then return nil end
  
  -- Get the player from the character
  local targetPlayer = Players:GetPlayerFromCharacter(character)
  if not targetPlayer or targetPlayer == player then
    return nil -- Don't allow viewing own inventory this way
  end
  
  return targetPlayer
end

-- Populate inventory GUI with target player's items
function populateInventory(targetPlayer)
  currentlyViewingPlayer = targetPlayer
  
  -- Update title
  if titleLabel then
    titleLabel.Text = targetPlayer.Name .. "'s Inventory"
  end
  
  -- Clear existing buttons
  for _, button in pairs(buttons) do
    button:Destroy()
  end
  buttons = {}
  
  -- Get target player's inventory
  local response
  local callSuccess, err = pcall(function()
    response = getPlayerInventoryFunction:InvokeServer(targetPlayer.UserId)
  end)
  
  -- Check if the call failed or response indicates failure
  if not callSuccess or not response or type(response) ~= "table" or not response.success then
    local errorMsg = "Failed to load inventory. Player may have just joined or left the game."
    if response and response.error then
      errorMsg = response.error
    elseif not callSuccess then
      errorMsg = "Connection error: " .. tostring(err)
    end
    
    warn("❌ Failed to get inventory for " .. targetPlayer.Name .. ": " .. errorMsg)
    
    -- Close the GUI and clear state
    screenGui.Enabled = false
    currentlyViewingPlayer = nil
    
    -- Clear buttons
    for _, button in pairs(buttons) do
      button:Destroy()
    end
    buttons = {}
    
    -- TODO: Show notification to user (would need notification system)
    print("⚠️ Could not view " .. targetPlayer.Name .. "'s inventory: " .. errorMsg)
    return
  end
  
  local inventory = response.inventory
  
  -- Sort inventory by value (highest to lowest)
  table.sort(inventory, function(a, b)
    return a.Value > b.Value
  end)
  
  -- Create buttons for each item
  for i, item in ipairs(inventory) do
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
    
    -- Display quantity or serial number
    local qtyLabel = button:FindFirstChild("Qty")
    if qtyLabel then
      if item.SerialNumber then
        qtyLabel.Text = "#" .. item.SerialNumber
      elseif item.Amount then
        qtyLabel.Text = item.Amount .. "x"
      else
        qtyLabel.Text = "1x"
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
    
    -- Hide t1 label if it exists
    local t1Label = button:FindFirstChild("t1")
    if t1Label then
      t1Label.Visible = false
    end
    
    -- Calculate the number of copies for display
    local copiesCount = 0
    if item.Stock and item.Stock > 0 then
      -- Stock item: use CurrentStock
      copiesCount = item.CurrentStock or 0
    else
      -- Regular item: use TotalCopies
      copiesCount = item.TotalCopies or 0
    end
    
    -- Display copies count
    local copiesLabel = button:FindFirstChild("copies")
    if copiesLabel then
      local stockCount = item.Stock or 0
      
      if copiesCount > 0 then
        if stockCount > 0 then
          -- Stock item: show "X / Y copies"
          copiesLabel.Text = copiesCount .. " / " .. stockCount .. " copies"
        else
          -- Regular item: show "X copies"
          copiesLabel.Text = copiesCount .. " copies"
        end
        copiesLabel.Visible = true
      else
        copiesLabel.Visible = false
      end
    end
    
    -- Update o2 label to show copies count
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

-- Close button functionality
if closeButton then
  closeButton.MouseButton1Click:Connect(function()
    screenGui.Enabled = false
    currentlyViewingPlayer = nil
    
    -- Clear buttons
    for _, button in pairs(buttons) do
      button:Destroy()
    end
    buttons = {}
  end)
end

-- Mouse hover detection (runs continuously)
task.spawn(function()
  while true do
    task.wait(0.1) -- Check every 0.1 seconds
    
    -- Only check if GUI is not open
    if not screenGui.Enabled then
      local targetPlayer = getPlayerFromMouse()
      
      if targetPlayer ~= highlightedPlayer then
        -- Remove old glow
        if highlightedPlayer and highlightedPlayer.Character then
          removeGlowEffect(highlightedPlayer.Character)
        end
        
        -- Add new glow
        if targetPlayer and targetPlayer.Character then
          createGlowEffect(targetPlayer.Character)
        end
        
        highlightedPlayer = targetPlayer
      end
    else
      -- GUI is open, remove any highlights
      if highlightedPlayer and highlightedPlayer.Character then
        removeGlowEffect(highlightedPlayer.Character)
      end
      highlightedPlayer = nil
    end
  end
end)

-- Click detection to open inventory
UserInputService.InputBegan:Connect(function(input, gameProcessed)
  if gameProcessed then return end
  
  if input.UserInputType == Enum.UserInputType.MouseButton1 then
    -- Don't open if GUI is already open
    if screenGui.Enabled then return end
    
    local targetPlayer = getPlayerFromMouse()
    if targetPlayer then
      -- Remove highlight
      if highlightedPlayer and highlightedPlayer.Character then
        removeGlowEffect(highlightedPlayer.Character)
      end
      highlightedPlayer = nil
      
      -- Open GUI and populate with player's inventory
      screenGui.Enabled = true
      populateInventory(targetPlayer)
    end
  end
end)

-- Clean up highlights when players leave
Players.PlayerRemoving:Connect(function(removingPlayer)
  if removingPlayer == highlightedPlayer then
    if removingPlayer.Character then
      removeGlowEffect(removingPlayer.Character)
    end
    highlightedPlayer = nil
  end
  
  if removingPlayer == currentlyViewingPlayer then
    screenGui.Enabled = false
    currentlyViewingPlayer = nil
  end
end)
