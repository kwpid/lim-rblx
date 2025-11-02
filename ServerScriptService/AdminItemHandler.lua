-- AdminItemHandler.lua
-- Handles admin item creation requests from the client

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local AdminConfig = require(script.Parent.AdminConfig)
local ItemDatabase = require(script.Parent.ItemDatabase)
local DataStoreAPI = require(script.Parent.DataStoreAPI)
local WebhookHandler = require(script.Parent.WebhookHandler)
local ItemRarityModule = require(ReplicatedStorage:WaitForChild("ItemRarityModule"))

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

-- Create RemoteEvent for deleting items
local deleteItemEvent = Instance.new("RemoteEvent")
deleteItemEvent.Name = "DeleteItemEvent"
deleteItemEvent.Parent = remoteEventsFolder

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

-- Handle item creation/edit requests
createItemEvent.OnServerEvent:Connect(function(player, robloxId, itemName, itemValue, itemStock, isLimited, isEditMode)
  -- Verify player is admin
  if not AdminConfig:IsAdmin(player) then
    warn("⚠️ Non-admin " .. player.Name .. " attempted to create/edit item!")
    return
  end

  -- Default stock to 0 if not provided
  itemStock = itemStock or 0
  
  -- Default Limited to false if not provided
  isLimited = isLimited or false
  
  -- Default edit mode to false if not provided
  isEditMode = isEditMode or false

  local success, result
  
  if isEditMode then
    -- EDIT MODE - Update existing item
    print("🔧 DEBUG: Editing item with isLimited =", isLimited, "type =", type(isLimited))
    success, result = ItemDatabase:EditItem(robloxId, itemName, itemValue, itemStock, isLimited)
    
    if success then
      print("🔧 DEBUG: Edit successful, result.Limited =", result.Limited)
      local stockText = itemStock > 0 and " [Stock: " .. itemStock .. "]" or ""
      local limitedText = isLimited and " [Limited]" or ""
      print("✅ Admin " .. player.Name .. " edited item: " .. itemName .. stockText .. limitedText)

      -- Send success back to client
      createItemEvent:FireClient(player, true, "Item edited successfully!", result)

      -- Send notification to all players about the edited item
      local notificationData = {
        Type = "GIFT",
        Title = "Item Updated",
        Body = itemName .. " has been updated!",
        ImageId = robloxId
      }
      notificationEvent:FireAllClients(notificationData)
      print("📢 Sent item update notification to all players: " .. itemName)
    else
      warn("❌ Failed to edit item: " .. result)
      createItemEvent:FireClient(player, false, result)
    end
  else
    -- CREATE MODE - Add new item
    success, result = ItemDatabase:AddItem(robloxId, itemName, itemValue, itemStock, isLimited)

    if success then
      local stockText = itemStock > 0 and " [Stock: " .. itemStock .. "]" or ""
      local limitedText = isLimited and " [Limited]" or ""
      print("✅ Admin " .. player.Name .. " created item: " .. itemName .. stockText .. limitedText)

      -- Send success back to client
      createItemEvent:FireClient(player, true, "Item created successfully!", result)

      -- Send notification to all players about the new item
      local notificationData = {
        Type = "GIFT",
        Title = "New Item",
        Body = itemName .. " is now available!",
        ImageId = robloxId
      }
      notificationEvent:FireAllClients(notificationData)
      print("📢 Sent new item notification to all players: " .. itemName .. " (ImageId: " .. robloxId .. ")")
      
      -- Calculate roll percentage and send Discord webhook
      task.spawn(function()
        local allItems = ItemDatabase:GetAllItems()
        local itemsWithPercentages = ItemRarityModule:CalculateAllRollPercentages(allItems)
        
        -- Find the newly created item's roll percentage
        local rollPercentage = 0
        for _, itemData in ipairs(itemsWithPercentages) do
          if itemData.RobloxId == robloxId then
            rollPercentage = itemData.RollPercentage
            break
          end
        end
        
        -- Send webhook notification
        WebhookHandler:SendItemRelease(result, rollPercentage)
      end)
    else
      warn("❌ Failed to create item: " .. result)
      -- Send error back to client
      createItemEvent:FireClient(player, false, result)
    end
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
    
    -- Send notification to admin
    local adminNotification = {
      Type = "GIFT",
      Title = "Item Given!",
      Body = "Gave " .. giveAmount .. "x " .. item.Name .. " to " .. targetPlayer.Name,
      ImageId = item.RobloxId
    }
    notificationEvent:FireClient(adminPlayer, adminNotification)
    
    -- Send notification to target player
    local playerNotification = {
      Type = "GIFT",
      Title = "Admin Gift!",
      Body = "You received " .. giveAmount .. "x " .. item.Name .. " from an admin!",
      ImageId = item.RobloxId
    }
    notificationEvent:FireClient(targetPlayer, playerNotification)

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
        serialNumber = ItemDatabase:IncreaseStockLimit(giveItemId, targetPlayer.UserId, targetPlayer.Name)
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
      
      -- Send notification to admin
      local adminNotification = {
        Type = "GIFT",
        Title = "Item Given!",
        Body = "Gave " .. itemsGiven .. "x " .. item.Name .. " to " .. targetPlayer.Name,
        ImageId = item.RobloxId
      }
      notificationEvent:FireClient(adminPlayer, adminNotification)
      
      -- Send notification to target player
      local playerNotification = {
        Type = "GIFT",
        Title = "Admin Gift!",
        Body = "You received " .. itemsGiven .. "x " .. item.Name .. " from an admin!",
        ImageId = item.RobloxId
      }
      notificationEvent:FireClient(targetPlayer, playerNotification)
    else
      giveItemEvent:FireClient(adminPlayer, false, "Failed to give stock items!")
    end
  end
end)

-- ═══════════════════════════════════════════════════
-- DELETE ITEM HANDLER
-- ═══════════════════════════════════════════════════

-- Handle delete item requests
deleteItemEvent.OnServerEvent:Connect(function(adminPlayer, deleteItemId)
  -- Verify player is admin
  if not AdminConfig:IsAdmin(adminPlayer) then
    warn("⚠️ Non-admin " .. adminPlayer.Name .. " attempted to delete item!")
    deleteItemEvent:FireClient(adminPlayer, false, "You are not an admin!")
    return
  end

  -- Validate inputs
  if not deleteItemId or type(deleteItemId) ~= "number" then
    deleteItemEvent:FireClient(adminPlayer, false, "Invalid item ID!")
    return
  end

  -- Get the item from database
  local item = ItemDatabase:GetItemByRobloxId(deleteItemId)
  if not item then
    deleteItemEvent:FireClient(adminPlayer, false, "Item with ID " .. deleteItemId .. " does not exist!")
    return
  end

  -- Store item data for rollback if needed
  local itemBackup = table.clone(item)

  -- Delete item from database
  local success, message, deletedItemData = ItemDatabase:DeleteItem(deleteItemId)

  if not success then
    warn("❌ Failed to delete item: " .. message)
    deleteItemEvent:FireClient(adminPlayer, false, message)
    return
  end

  -- ═══════════════════════════════════════════════════
  -- Remove item from all ONLINE players' inventories
  -- (Offline players will be cleaned up when they load their data)
  -- ═══════════════════════════════════════════════════
  local playersUpdated = 0
  local itemsRemoved = 0
  local cleanupSuccess = true

  for _, player in ipairs(Players:GetPlayers()) do
    local playerSuccess, playerError = pcall(function()
      local playerData = DataStoreAPI:GetPlayerData(player)
      if playerData and playerData.Inventory then
        local indicesToRemove = {}

        -- Find all instances of this item in player's inventory
        for i, invItem in ipairs(playerData.Inventory) do
          if invItem.RobloxId == deleteItemId then
            table.insert(indicesToRemove, i)
          end
        end

        -- Remove items in reverse order to maintain indices
        for i = #indicesToRemove, 1, -1 do
          table.remove(playerData.Inventory, indicesToRemove[i])
          itemsRemoved = itemsRemoved + 1
        end

        if #indicesToRemove > 0 then
          playersUpdated = playersUpdated + 1

          -- Update inventory value
          DataStoreAPI:UpdateInventoryValue(player)

          -- Unequip the item if equipped
          if playerData.EquippedItems then
            for i = #playerData.EquippedItems, 1, -1 do
              if playerData.EquippedItems[i] == deleteItemId then
                table.remove(playerData.EquippedItems, i)
              end
            end
          end

          -- Unequip from character
          local character = player.Character
          if character then
            for _, child in ipairs(character:GetChildren()) do
              if child:IsA("Accessory") or child:IsA("Tool") or child:IsA("Hat") then
                local storedId = child:FindFirstChild("OriginalRobloxId")
                if storedId and storedId.Value == deleteItemId then
                  child:Destroy()
                end
              end
            end
          end

          -- Send notification to player
          local playerNotification = {
            Type = "ERROR",
            Title = "Item Removed",
            Body = deletedItemData.Name .. " was deleted from the game by an admin"
          }
          notificationEvent:FireClient(player, playerNotification)
        end
      end
    end)

    if not playerSuccess then
      warn("⚠️ Failed to cleanup item for player " .. player.Name .. ": " .. tostring(playerError))
      -- Continue with other players even if one fails
    end
  end

  print("🗑️ Admin " .. adminPlayer.Name .. " deleted item: " .. deletedItemData.Name)
  print("   📊 Removed from " .. playersUpdated .. " online players (" .. itemsRemoved .. " total items)")
  print("   ℹ️ Offline players will be cleaned up when they rejoin")

  -- Send success notification to admin
  deleteItemEvent:FireClient(adminPlayer, true, "Deleted " .. deletedItemData.Name .. " from game and " .. playersUpdated .. " online players")

  local adminNotification = {
    Type = "VICTORY",
    Title = "Item Deleted!",
    Body = "Deleted " .. deletedItemData.Name .. " from " .. playersUpdated .. " online players",
    ImageId = deletedItemData.RobloxId
  }
  notificationEvent:FireClient(adminPlayer, adminNotification)
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

_G.SetPlayerLuck = function(username, multiplier)
  if not username or not multiplier then
    print("❌ Usage: SetPlayerLuck(\"username\", multiplier)")
    print("   Example: SetPlayerLuck(\"2kwpid\", 300)")
    return
  end

  if type(multiplier) ~= "number" or multiplier <= 0 then
    print("❌ Multiplier must be a positive number!")
    return
  end

  local Players = game:GetService("Players")
  local targetPlayer = Players:FindFirstChild(username)

  if not targetPlayer then
    print("❌ Player '" .. username .. "' is not in the server!")
    print("   Make sure the player is online and spell their username exactly.")
    return
  end

  local oldLuck = targetPlayer:GetAttribute("Luck") or 1.0
  targetPlayer:SetAttribute("Luck", multiplier)

  print("╔═══════════════════════════════════════╗")
  print("║      LUCK MULTIPLIER UPDATED          ║")
  print("╚═══════════════════════════════════════╝")
  print("  Player: " .. targetPlayer.Name)
  print("  Old Luck: " .. string.format("%.1fx", oldLuck))
  print("  New Luck: " .. string.format("%.1fx", multiplier))
  print("")
  print("🍀 " .. targetPlayer.Name .. " now has " .. multiplier .. "x luck!")
end

_G.ResetPlayerLuck = function(username)
  if not username then
    print("❌ Usage: ResetPlayerLuck(\"username\")")
    print("   Example: ResetPlayerLuck(\"2kwpid\")")
    return
  end

  local Players = game:GetService("Players")
  local targetPlayer = Players:FindFirstChild(username)

  if not targetPlayer then
    print("❌ Player '" .. username .. "' is not in the server!")
    return
  end

  local oldLuck = targetPlayer:GetAttribute("Luck") or 1.0
  targetPlayer:SetAttribute("Luck", 1.0)

  print("╔═══════════════════════════════════════╗")
  print("║      LUCK MULTIPLIER RESET            ║")
  print("╚═══════════════════════════════════════╝")
  print("  Player: " .. targetPlayer.Name)
  print("  Old Luck: " .. string.format("%.1fx", oldLuck))
  print("  New Luck: 1.0x (default)")
  print("")
  print("🔄 " .. targetPlayer.Name .. "'s luck has been reset to normal!")
end

_G.CheckPlayerLuck = function(username)
  if not username then
    print("❌ Usage: CheckPlayerLuck(\"username\")")
    print("   Example: CheckPlayerLuck(\"2kwpid\")")
    return
  end

  local Players = game:GetService("Players")
  local targetPlayer = Players:FindFirstChild(username)

  if not targetPlayer then
    print("❌ Player '" .. username .. "' is not in the server!")
    return
  end

  local playerLuck = targetPlayer:GetAttribute("Luck") or 1.0

  print("╔═══════════════════════════════════════╗")
  print("║      PLAYER LUCK STATUS               ║")
  print("╚═══════════════════════════════════════╝")
  print("  Player: " .. targetPlayer.Name)
  print("  Current Luck: " .. string.format("%.1fx", playerLuck))
  print("")
  if playerLuck > 1.0 then
    print("🍀 " .. targetPlayer.Name .. " has BOOSTED luck!")
  elseif playerLuck < 1.0 then
    print("💀 " .. targetPlayer.Name .. " has REDUCED luck!")
  else
    print("➖ " .. targetPlayer.Name .. " has NORMAL luck")
  end
end

_G.StartEvent = function(eventName)
  if not eventName then
    print("❌ Usage: StartEvent(\"eventName\")")
    print("   Example: StartEvent(\"RandomItemDrops\")")
    print("")
    print("📋 Available Events:")
    print("   - RandomItemDrops")
    return
  end

  local EventSystem = require(script.Parent.EventSystem)
  local success = EventSystem:StartEvent(eventName)

  if success then
    print("╔═══════════════════════════════════════╗")
    print("║      EVENT STARTED                    ║")
    print("╚═══════════════════════════════════════╝")
    print("  Event: " .. eventName)
    print("")
    print("🎉 " .. eventName .. " event is now running!")
  else
    print("❌ Failed to start event: " .. eventName)
    print("   Make sure the event name is correct.")
    print("   Available events: RandomItemDrops")
  end
end

_G.SetUltraLuck = function(username, multiplier)
  if not username or not multiplier then
    print("❌ Usage: SetUltraLuck(\"username\", multiplier)")
    print("   Example: SetUltraLuck(\"2kwpid\", 1000)")
    print("")
    print("💎 Ultra Luck boosts ONLY Mythic/Insane items (2.5M+ Robux)")
    print("   This stacks with regular Luck for extreme testing!")
    return
  end

  if type(multiplier) ~= "number" or multiplier <= 0 then
    print("❌ Multiplier must be a positive number!")
    return
  end

  local Players = game:GetService("Players")
  local targetPlayer = Players:FindFirstChild(username)

  if not targetPlayer then
    print("❌ Player '" .. username .. "' is not in the server!")
    print("   Make sure the player is online and spell their username exactly.")
    return
  end

  local oldUltraLuck = targetPlayer:GetAttribute("UltraLuck") or 1.0
  targetPlayer:SetAttribute("UltraLuck", multiplier)

  print("╔═══════════════════════════════════════╗")
  print("║   ULTRA LUCK MULTIPLIER UPDATED       ║")
  print("╚═══════════════════════════════════════╝")
  print("  Player: " .. targetPlayer.Name)
  print("  Old Ultra Luck: " .. string.format("%.1fx", oldUltraLuck))
  print("  New Ultra Luck: " .. string.format("%.1fx", multiplier))
  print("")
  print("💎 " .. targetPlayer.Name .. " now has " .. multiplier .. "x ULTRA luck for Mythic/Insane items!")
  print("   This multiplies on top of regular Luck for Epic+ items.")
end

_G.ResetUltraLuck = function(username)
  if not username then
    print("❌ Usage: ResetUltraLuck(\"username\")")
    print("   Example: ResetUltraLuck(\"2kwpid\")")
    return
  end

  local Players = game:GetService("Players")
  local targetPlayer = Players:FindFirstChild(username)

  if not targetPlayer then
    print("❌ Player '" .. username .. "' is not in the server!")
    return
  end

  local oldUltraLuck = targetPlayer:GetAttribute("UltraLuck") or 1.0
  targetPlayer:SetAttribute("UltraLuck", 1.0)

  print("╔═══════════════════════════════════════╗")
  print("║   ULTRA LUCK MULTIPLIER RESET         ║")
  print("╚═══════════════════════════════════════╝")
  print("  Player: " .. targetPlayer.Name)
  print("  Old Ultra Luck: " .. string.format("%.1fx", oldUltraLuck))
  print("  New Ultra Luck: 1.0x (default)")
  print("")
  print("🔄 " .. targetPlayer.Name .. "'s ultra luck has been reset to normal!")
end

_G.CheckUltraLuck = function(username)
  if not username then
    print("❌ Usage: CheckUltraLuck(\"username\")")
    print("   Example: CheckUltraLuck(\"2kwpid\")")
    return
  end

  local Players = game:GetService("Players")
  local targetPlayer = Players:FindFirstChild(username)

  if not targetPlayer then
    print("❌ Player '" .. username .. "' is not in the server!")
    return
  end

  local playerUltraLuck = targetPlayer:GetAttribute("UltraLuck") or 1.0
  local playerLuck = targetPlayer:GetAttribute("Luck") or 1.0

  print("╔═══════════════════════════════════════╗")
  print("║   PLAYER LUCK STATUS (FULL)           ║")
  print("╚═══════════════════════════════════════╝")
  print("  Player: " .. targetPlayer.Name)
  print("  Regular Luck (Epic+): " .. string.format("%.1fx", playerLuck))
  print("  Ultra Luck (Mythic/Insane): " .. string.format("%.1fx", playerUltraLuck))
  print("")
  print("  💡 Combined effect on Mythic/Insane:")
  print("     Total multiplier = " .. string.format("%.1fx", playerLuck * playerUltraLuck))
  print("")
  if playerUltraLuck > 1.0 then
    print("💎 " .. targetPlayer.Name .. " has ULTRA LUCK for Mythic/Insane items!")
  else
    print("➖ " .. targetPlayer.Name .. " has NORMAL ultra luck")
  end
end

