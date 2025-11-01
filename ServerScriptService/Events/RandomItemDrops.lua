-- RandomItemDrops.lua
-- Random item drop event - items fall from the sky and players can collect them

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ProximityPromptService = game:GetService("ProximityPromptService")

local ItemDatabase = require(script.Parent.Parent.ItemDatabase)
local DataStoreAPI = require(script.Parent.Parent.DataStoreAPI)
local ItemRarityModule = require(ReplicatedStorage:WaitForChild("ItemRarityModule"))
local WebhookHandler = require(script.Parent.Parent.WebhookHandler)

local RandomItemDrops = {}

-- Event configuration
local NUM_ITEMS_TO_DROP = math.random(15, 20)
local EVENT_DURATION = 3 * 60 -- 3 minutes
local ITEM_LIFETIME = math.random(60, 120) -- Items stay 1-2 minutes after landing
local DROP_INTERVAL = EVENT_DURATION / NUM_ITEMS_TO_DROP

-- Increased probability power for event drops (higher value = higher chance)
-- For events, we use VALUE ^ POWER instead of 1/VALUE ^ POWER
-- This makes higher-value items MORE likely to drop (opposite of normal rolling)
local EVENT_DROP_POWER = 0.5 -- Power to apply to item value

-- Chat notification
local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local chatNotificationEvent = remoteEvents:FindFirstChild("ChatNotificationEvent")

-- Helper function to get color tag based on item value
local function getValueColorTag(value)
  if value >= 10000000 then
    return "<font color=\"#FF00FF\">" -- Insane (Magenta)
  elseif value >= 2500000 then
    return "<font color=\"#FF0000\">" -- Mythic (Red)
  elseif value >= 750000 then
    return "<font color=\"#FF5500\">" -- Ultra Epic (Red-Orange)
  elseif value >= 250000 then
    return "<font color=\"#FFAA00\">" -- Epic (Orange)
  elseif value >= 50000 then
    return "<font color=\"#AA55FF\">" -- Ultra Rare (Purple)
  elseif value >= 10000 then
    return "<font color=\"#5555FF\">" -- Rare (Blue)
  elseif value >= 2500 then
    return "<font color=\"#55AA55\">" -- Uncommon (Green)
  else
    return "<font color=\"#AAAAAA\">" -- Common (Gray)
  end
end

-- Helper to format numbers with commas
local function formatNumber(n)
  local formatted = tostring(n)
  while true do
    formatted, k = formatted:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
    if k == 0 then break end
  end
  return formatted
end

-- Pick a random item using event probability (higher chance for rare items)
-- Unlike normal rolling, events FAVOR high-value items by using value^power directly
local function pickRandomEventItem(items)
  if #items == 0 then return nil end
  
  -- Calculate total value weight using EVENT_DROP_POWER
  -- Higher value items get HIGHER weights (opposite of normal rolling)
  local totalValueWeight = 0
  for _, item in ipairs(items) do
    totalValueWeight = totalValueWeight + (item.Value ^ EVENT_DROP_POWER)
  end
  
  -- Pick random item based on value weights
  local randomValue = math.random() * totalValueWeight
  local cumulative = 0
  for _, item in ipairs(items) do
    cumulative = cumulative + (item.Value ^ EVENT_DROP_POWER)
    if randomValue <= cumulative then
      return item
    end
  end
  
  return items[#items]
end

-- Create a physical item drop
local function createItemDrop(itemData, dropZone, onCollected)
  -- Create the item model
  local itemModel = Instance.new("Model")
  itemModel.Name = "DroppedItem_" .. itemData.Name
  
  -- Create main part
  local part = Instance.new("Part")
  part.Name = "ItemPart"
  part.Size = Vector3.new(3, 3, 3)
  part.Anchored = false
  part.CanCollide = true
  part.Material = Enum.Material.Neon
  
  -- Set color based on rarity
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
  part.Color = rarityColors[itemData.Rarity] or Color3.new(1, 1, 1)
  part.Parent = itemModel
  
  -- Add mesh/texture to show item
  local surfaceGui = Instance.new("SurfaceGui")
  surfaceGui.Face = Enum.NormalId.Top
  surfaceGui.Parent = part
  
  local imageLabel = Instance.new("ImageLabel")
  imageLabel.Size = UDim2.new(1, 0, 1, 0)
  imageLabel.BackgroundTransparency = 1
  imageLabel.Image = "rbxthumb://type=Asset&id=" .. itemData.RobloxId .. "&w=150&h=150"
  imageLabel.Parent = surfaceGui
  
  -- Add proximity prompt
  local proximityPrompt = Instance.new("ProximityPrompt")
  proximityPrompt.ActionText = "Collect Item"
  proximityPrompt.ObjectText = itemData.Name
  proximityPrompt.MaxActivationDistance = 10
  proximityPrompt.RequiresLineOfSight = false
  proximityPrompt.Parent = part
  
  -- Set primary part
  itemModel.PrimaryPart = part
  
  -- Spawn at dropzone
  local spawnPosition = dropZone.Position + Vector3.new(
    math.random(-dropZone.Size.X/2, dropZone.Size.X/2),
    10,
    math.random(-dropZone.Size.Z/2, dropZone.Size.Z/2)
  )
  part.Position = spawnPosition
  itemModel.Parent = workspace
  
  -- Add BodyVelocity for slow fall
  local bodyVelocity = Instance.new("BodyVelocity")
  bodyVelocity.Velocity = Vector3.new(0, -5, 0) -- Slow downward movement
  bodyVelocity.MaxForce = Vector3.new(0, math.huge, 0)
  bodyVelocity.Parent = part
  
  -- Rotate the item for visual effect
  task.spawn(function()
    while itemModel and itemModel.Parent do
      part.CFrame = part.CFrame * CFrame.Angles(0, math.rad(2), 0)
      task.wait(0.05)
    end
  end)
  
  -- Handle collection
  local collected = false
  proximityPrompt.Triggered:Connect(function(player)
    if collected then return end
    collected = true
    
    -- Add item to player inventory
    onCollected(player, itemData)
    
    -- Destroy the item
    itemModel:Destroy()
  end)
  
  -- Remove velocity when touching ground
  part.Touched:Connect(function(hit)
    if hit:IsA("BasePart") and not hit:IsDescendantOf(itemModel) then
      if bodyVelocity and bodyVelocity.Parent then
        bodyVelocity:Destroy()
      end
      part.Anchored = true
    end
  end)
  
  -- Auto-cleanup after lifetime
  task.delay(ITEM_LIFETIME, function()
    if itemModel and itemModel.Parent and not collected then
      itemModel:Destroy()
    end
  end)
  
  return itemModel
end

-- Handle item collection
local function handleItemCollection(player, itemData)
  -- Add to inventory (same as rolling)
  local success = DataStoreAPI:AddItem(player, itemData)
  
  if not success then
    warn("❌ Failed to give event item to player: " .. player.Name)
    return
  end
  
  print("✅ " .. player.Name .. " collected " .. itemData.Name .. " from event")
  
  -- Send chat notifications for high-value items (250k+)
  if itemData.Value >= 250000 then
    local colorTag = getValueColorTag(itemData.Value)
    local closeTag = "</font>"
    
    local message = colorTag .. player.Name .. " got " .. itemData.Name
    
    if itemData.SerialNumber then
      message = message .. " #" .. itemData.SerialNumber
    end
    
    message = message .. " (R$" .. formatNumber(itemData.Value) .. ") from the event!" .. closeTag
    
    if chatNotificationEvent then
      -- Send to all clients in this server
      chatNotificationEvent:FireAllClients(message)
    end
  end
  
  -- Send webhook notification for high-value items
  if itemData.Value >= 250000 then
    WebhookHandler:SendHighValueUnbox(player, itemData, "event")
  end
end

-- Event info
function RandomItemDrops.GetEventInfo()
  return {
    Name = "Random Item Drops!",
    Description = "Items are falling from the sky! Collect them before they disappear!",
    Image = "rbxassetid://8150337440"
  }
end

-- Start the event
function RandomItemDrops.Start(onEventEnd)
  print("🎁 Starting Random Item Drops event")
  
  -- Find dropzone
  local dropZone = workspace:FindFirstChild("dropzone")
  if not dropZone then
    warn("❌ No dropzone found in workspace! Event cancelled.")
    if onEventEnd then onEventEnd() end
    return
  end
  
  -- Wait for ItemDatabase to be ready
  local maxWait = 30
  local waited = 0
  while not ItemDatabase.IsReady and waited < maxWait do
    task.wait(0.5)
    waited = waited + 0.5
  end
  
  if not ItemDatabase.IsReady then
    warn("❌ ItemDatabase not ready! Event cancelled.")
    if onEventEnd then onEventEnd() end
    return
  end
  
  -- Get all rollable items
  local allItems = ItemDatabase:GetRollableItems()
  if #allItems == 0 then
    warn("❌ No items available for event!")
    if onEventEnd then onEventEnd() end
    return
  end
  
  print("✅ Found " .. #allItems .. " items available for event drops")
  
  -- Spawn items over time
  task.spawn(function()
    for i = 1, NUM_ITEMS_TO_DROP do
      -- Pick random item (with event probability)
      local randomItem = pickRandomEventItem(allItems)
      if randomItem then
        -- Handle stock items
        local itemData = {
          RobloxId = randomItem.RobloxId,
          Name = randomItem.Name,
          Value = randomItem.Value,
          Rarity = randomItem.Rarity or ItemRarityModule.GetRarity(randomItem.Value)
        }
        
        -- Check if stock item and claim serial number
        if randomItem.Stock and randomItem.Stock > 0 then
          local serialNumber = ItemDatabase:ClaimNextSerial(randomItem.RobloxId)
          if serialNumber then
            itemData.SerialNumber = serialNumber
            print("  📦 Dropping stock item: " .. itemData.Name .. " #" .. serialNumber)
          else
            -- Stock sold out, pick a different item
            print("  ⚠️ Stock sold out for " .. itemData.Name .. ", picking different item")
            randomItem = pickRandomEventItem(allItems)
            if randomItem then
              itemData = {
                RobloxId = randomItem.RobloxId,
                Name = randomItem.Name,
                Value = randomItem.Value,
                Rarity = randomItem.Rarity or ItemRarityModule.GetRarity(randomItem.Value)
              }
            end
          end
        end
        
        -- Create the item drop
        createItemDrop(itemData, dropZone, handleItemCollection)
        
        print("  🎁 Dropped item " .. i .. "/" .. NUM_ITEMS_TO_DROP .. ": " .. itemData.Name)
      else
        warn("⚠️ Failed to pick random item for event drop")
      end
      
      -- Wait before next drop
      if i < NUM_ITEMS_TO_DROP then
        task.wait(DROP_INTERVAL)
      end
    end
    
    print("✅ All event items dropped!")
    
    -- Event ends after all items are dropped
    if onEventEnd then
      onEventEnd()
    end
  end)
end

return RandomItemDrops
