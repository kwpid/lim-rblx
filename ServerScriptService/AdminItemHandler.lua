-- AdminItemHandler.lua
-- Handles admin item creation requests from the client

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local AdminConfig = require(script.Parent.AdminConfig)
local ItemDatabase = require(script.Parent.ItemDatabase)
local DataStoreAPI = require(script.Parent.DataStoreAPI)

-- Create RemoteEvents folder if it doesn't exist
local remoteEventsFolder = ReplicatedStorage:FindFirstChild("RemoteEvents")
if not remoteEventsFolder then
  remoteEventsFolder = Instance.new("Folder")
  remoteEventsFolder.Name = "RemoteEvents"
  remoteEventsFolder.Parent = ReplicatedStorage
end

-- Create RemoteEvent for admin item creation
local createItemEvent = Instance.new("RemoteEvent")
createItemEvent.Name = "CreateItemEvent"
createItemEvent.Parent = remoteEventsFolder

-- Create RemoteEvent for giving items to players
local giveItemEvent = Instance.new("RemoteEvent")
giveItemEvent.Name = "GiveItemEvent"
giveItemEvent.Parent = remoteEventsFolder

-- Create RemoteFunction for checking admin status
local checkAdminFunction = Instance.new("RemoteFunction")
checkAdminFunction.Name = "CheckAdminFunction"
checkAdminFunction.Parent = remoteEventsFolder

-- Get or create notification RemoteEvent
local notificationEvent = remoteEventsFolder:FindFirstChild("CreateNotification")
if not notificationEvent then
  notificationEvent = Instance.new("RemoteEvent")
  notificationEvent.Name = "CreateNotification"
  notificationEvent.Parent = remoteEventsFolder
end

-- Handle admin check requests
checkAdminFunction.OnServerInvoke = function(player)
  return AdminConfig:IsAdmin(player)
end

-- Handle item creation requests
createItemEvent.OnServerEvent:Connect(function(player, robloxId, itemName, itemValue, itemStock)
  -- Verify player is admin
  if not AdminConfig:IsAdmin(player) then
    warn("⚠️ Non-admin " .. player.Name .. " attempted to create item!")
    return
  end

  -- Default stock to 0 if not provided
  itemStock = itemStock or 0

  -- Attempt to create item
  local success, result = ItemDatabase:AddItem(robloxId, itemName, itemValue, itemStock)

  if success then
    local stockText = itemStock > 0 and " [Stock: " .. itemStock .. "]" or ""
    print("✅ Admin " .. player.Name .. " created item: " .. itemName .. stockText)

    -- Send success back to client
    createItemEvent:FireClient(player, true, "Item created successfully!", result)

    -- Send notification to all players about the new item
    local notificationData = {
      Type = "GIFT",
      Title = "New Item",
      Body = itemName .. " is now available!",
      ImageId = robloxId  -- Pass just the number, handler will convert to rbxassetid://
    }
    notificationEvent:FireAllClients(notificationData)
    print("📢 Sent new item notification to all players: " .. itemName .. " (ImageId: " .. robloxId .. ")")
  else
    warn("❌ Failed to create item: " .. result)
    -- Send error back to client
    createItemEvent:FireClient(player, false, result)
  end
end)

-- ═══════════════════════════════════════════════════
-- GIVE ITEM HANDLER
-- ═══════════════════════════════════════════════════

-- Helper function to find player by ID or username
local function findPlayer(identifier)
  -- First, try to find by exact username
  local playerByName = Players:FindFirstChild(identifier)
  if playerByName then
    return playerByName
  end

  -- Try to parse as user ID
  local userId = tonumber(identifier)
  if userId then
    -- Find player with matching UserId
    for _, player in ipairs(Players:GetPlayers()) do
      if player.UserId == userId then
        return player
      end
    end
  else
    -- Try case-insensitive username search
    local lowerIdentifier = string.lower(identifier)
    for _, player in ipairs(Players:GetPlayers()) do
      if string.lower(player.Name) == lowerIdentifier then
        return player
      end
    end
  end

  return nil
end

-- Handle give item requests
giveItemEvent.OnServerEvent:Connect(function(adminPlayer, giveItemId, giveAmount, playerIdentifier)
  -- Verify player is admin
  if not AdminConfig:IsAdmin(adminPlayer) then
    warn("⚠️ Non-admin " .. adminPlayer.Name .. " attempted to give item!")
    giveItemEvent:FireClient(adminPlayer, false, "You are not an admin!")
    return
  end

  -- Validate inputs
  if not giveItemId or type(giveItemId) ~= "number" then
    giveItemEvent:FireClient(adminPlayer, false, "Invalid item ID!")
    return
  end

  if not giveAmount or giveAmount < 1 then
    giveItemEvent:FireClient(adminPlayer, false, "Amount must be at least 1!")
    return
  end

  if not playerIdentifier or playerIdentifier == "" then
    giveItemEvent:FireClient(adminPlayer, false, "Player ID/Username cannot be empty!")
    return
  end

  -- Find the target player
  local targetPlayer = findPlayer(playerIdentifier)
  if not targetPlayer then
    giveItemEvent:FireClient(adminPlayer, false, "Player not found! Make sure they are in the game.")
    return
  end

  -- Get the item from database
  local item = ItemDatabase:GetItemByRobloxId(giveItemId)
  if not item then
    giveItemEvent:FireClient(adminPlayer, false, "Item with ID " .. giveItemId .. " does not exist!")
    return
  end

  -- Check if this is a stock item or regular item
  local stock = item.Stock or 0
  local currentStock = item.CurrentStock or 0

  if stock == 0 then
    -- ═══════════════════════════════════════════════════
    -- REGULAR ITEM - Give amount times
    -- ═══════════════════════════════════════════════════
    
    for i = 1, giveAmount do
      local itemToAdd = {
        RobloxId = item.RobloxId,
        Name = item.Name,
        Value = item.Value,
        Rarity = item.Rarity
      }
      DataStoreAPI:AddItem(targetPlayer, itemToAdd)
    end

    print("✅ Admin " .. adminPlayer.Name .. " gave " .. giveAmount .. "x " .. item.Name .. " to " .. targetPlayer.Name)
    giveItemEvent:FireClient(adminPlayer, true, "Gave " .. giveAmount .. "x " .. item.Name .. " to " .. targetPlayer.Name)

  else
    -- ═══════════════════════════════════════════════════
    -- STOCK ITEM
    -- ═══════════════════════════════════════════════════
    
    local itemsGiven = 0
    
    for i = 1, giveAmount do
      local serialNumber = nil
      
      -- Check if stock is available
      if currentStock < stock then
        -- Stock available - claim next serial
        serialNumber = ItemDatabase:IncrementStock(item)
        if serialNumber then
          currentStock = currentStock + 1
        end
      else
        -- Stock is full - increase limit and claim new serial
        serialNumber = ItemDatabase:IncreaseStockLimit(giveItemId)
        if serialNumber then
          stock = stock + 1
          currentStock = currentStock + 1
        end
      end

      if serialNumber then
        -- Add stock item with serial number
        local itemToAdd = {
          RobloxId = item.RobloxId,
          Name = item.Name,
          Value = item.Value,
          Rarity = item.Rarity,
          SerialNumber = serialNumber
        }
        DataStoreAPI:AddItem(targetPlayer, itemToAdd)
        itemsGiven = itemsGiven + 1
      else
        warn("⚠️ Failed to give stock item " .. item.Name .. " #" .. i)
      end
    end

    if itemsGiven > 0 then
      print("✅ Admin " .. adminPlayer.Name .. " gave " .. itemsGiven .. "x " .. item.Name .. " to " .. targetPlayer.Name)
      giveItemEvent:FireClient(adminPlayer, true, "Gave " .. itemsGiven .. "x " .. item.Name .. " to " .. targetPlayer.Name)
    else
      giveItemEvent:FireClient(adminPlayer, false, "Failed to give stock items!")
    end
  end
end)

-- Global admin console commands
_G.CheckDatabase = function()
  local items = ItemDatabase:GetAllItems()
  print("╔═══════════════════════════════════════╗")
  print("║         ITEM DATABASE                 ║")
  print("╠═══════════════════════════════════════╣")
  print("║ Total Items: " .. #items .. string.rep(" ", 27 - #tostring(#items)) .. "║")
  print("╚═══════════════════════════════════════╝")
  print("")

  if #items == 0 then
    print("📭 Database is empty. Create items using the Admin Panel!")
    return
  end

  -- Sort by value (highest to lowest)
  table.sort(items, function(a, b) return a.Value > b.Value end)

  for i, item in ipairs(items) do
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("📦 " .. i .. ". " .. item.Name)
    print("   🆔 Roblox ID: " .. item.RobloxId)
    print("   💎 Rarity: " .. item.Rarity)
    print("   💰 Value: " .. string.format("%,d", item.Value):gsub(",", ","))
    print("")
  end
  print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
end

_G.CheckRarities = function()
  local items = ItemDatabase:GetAllItems()
  local rarityCount = {}

  for _, item in ipairs(items) do
    rarityCount[item.Rarity] = (rarityCount[item.Rarity] or 0) + 1
  end

  print("╔═══════════════════════════════════════╗")
  print("║      ITEMS BY RARITY                  ║")
  print("╚═══════════════════════════════════════╝")

  local rarities = {"Insane", "Mythic", "Ultra Epic", "Epic", "Ultra Rare", "Rare", "Uncommon", "Common"}
  for _, rarity in ipairs(rarities) do
    local count = rarityCount[rarity] or 0
    if count > 0 then
      print("  " .. rarity .. ": " .. count)
    end
  end

end

