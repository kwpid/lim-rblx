-- AdminItemHandler.lua
-- Handles admin item creation requests from the client

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AdminConfig = require(script.Parent.AdminConfig)
local ItemDatabase = require(script.Parent.ItemDatabase)

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

-- Create RemoteFunction for checking admin status
local checkAdminFunction = Instance.new("RemoteFunction")
checkAdminFunction.Name = "CheckAdminFunction"
checkAdminFunction.Parent = remoteEventsFolder

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
  else
    warn("❌ Failed to create item: " .. result)
    -- Send error back to client
    createItemEvent:FireClient(player, false, result)
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
  print("")
  print("Total: " .. #items .. " items")
end

print("✅ Admin Item Handler initialized!")
print("💡 Admin Console Commands:")
print("   - CheckDatabase() - View all items")
print("   - CheckRarities() - View item count by rarity")
