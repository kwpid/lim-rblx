-- ItemDatabase.lua

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")

local ItemDataStore = DataStoreService:GetDataStore("ItemDatabase_v1")
local ItemRarityModule = require(game.ReplicatedStorage.ItemRarityModule)

local WebhookHandler
local function getWebhookHandler()
  if not WebhookHandler then
    WebhookHandler = require(script.Parent.WebhookHandler)
  end
  return WebhookHandler
end

-- 🔑 DATA VERSION - Must match DataStoreManager.lua to keep data in sync
local DATA_VERSION = "DataVersion.16"

local ItemDatabase = {}
ItemDatabase.Items = {}
ItemDatabase.DataVersion = DATA_VERSION
ItemDatabase._saveQueued = false
ItemDatabase._lastSaveTime = 0

local SAVE_DEBOUNCE_TIME = 3

function ItemDatabase:QueueSave()
  if self._saveQueued then
    return
  end

  self._saveQueued = true

  task.delay(SAVE_DEBOUNCE_TIME, function()
    self._saveQueued = false
    local timeSinceLastSave = tick() - self._lastSaveTime

    if timeSinceLastSave >= 1 then
      self:SaveItems()
      self._lastSaveTime = tick()
    else
      self:QueueSave()
    end
  end)
end

function ItemDatabase:LoadItems()
  local success, result = pcall(function()
    local jsonData = ItemDataStore:GetAsync("AllItems")
    if jsonData then
      local data = HttpService:JSONDecode(jsonData)

      local items
      local savedVersion

      if data.Items then
        items = data.Items
        savedVersion = data.DataVersion
      else
        items = data
        savedVersion = nil
      end

      self.Items = items

      if savedVersion ~= DATA_VERSION then
        for _, item in ipairs(self.Items) do
          item.CurrentStock = 0
          item.Owners = 0
          item.SerialOwners = {}
        end

        self.DataVersion = DATA_VERSION
        self:SaveItems()
      else
        self.DataVersion = savedVersion
      end
      for _, item in ipairs(self.Items) do
        if item.Stock == nil then
          item.Stock = 0
        end
        if item.CurrentStock == nil then
          item.CurrentStock = 0
        end
        if item.Owners == nil then
          item.Owners = 0
        end
        if item.TotalCopies == nil then
          item.TotalCopies = 0
        end
        if item.SerialOwners == nil then
          item.SerialOwners = {}
        end
        if item.Limited == nil then
          item.Limited = false
        end
      end
    else
      self.Items = {}
      self.DataVersion = DATA_VERSION
    end
  end)

  if not success then
    warn("❌ Failed to load items: " .. tostring(result))
    self.Items = {}
    self.DataVersion = DATA_VERSION
  end
end

function ItemDatabase:SaveItems()
  local success, errorMessage = pcall(function()
    local dataToSave = {
      Items = self.Items,
      DataVersion = self.DataVersion or DATA_VERSION
    }
    local jsonData = HttpService:JSONEncode(dataToSave)
    ItemDataStore:SetAsync("AllItems", jsonData)
  end)

  if success then
    return true
  else
    warn("❌ Failed to save items: " .. errorMessage)
    return false
  end
end

function ItemDatabase:AddItem(robloxId, itemName, itemValue, stock, isLimited)
  if type(robloxId) ~= "number" then
    return false, "RobloxId must be a number"
  end

  if type(itemName) ~= "string" or itemName == "" then
    return false, "Item name cannot be empty"
  end

  if type(itemValue) ~= "number" or itemValue < 0 then
    return false, "Item value must be a positive number"
  end

  stock = stock or 0
  if type(stock) ~= "number" or stock < 0 or stock > 100 then
    return false, "Stock must be between 0 and 100"
  end

  isLimited = isLimited or false

  for _, item in ipairs(self.Items) do
    if item.RobloxId == robloxId then
      return false, "Item with this Roblox ID already exists"
    end
  end

  local rarity = ItemRarityModule:GetRarity(itemValue)

  local newItem = {
    RobloxId = robloxId,
    Name = itemName,
    Value = itemValue,
    Rarity = rarity,
    Stock = stock,
    CurrentStock = 0,
    Owners = 0,
    TotalCopies = 0,
    SerialOwners = {},
    Limited = isLimited,
    CreatedAt = os.time()
  }

  table.insert(self.Items, newItem)

  local saveSuccess = self:SaveItems()

  if saveSuccess then
    local stockText = stock > 0 and " [Stock: " .. stock .. "]" or ""

    return true, newItem
  else
    table.remove(self.Items, #self.Items)
    return false, "Failed to save item to database"
  end
end

function ItemDatabase:EditItem(robloxId, itemName, itemValue, stock, isLimited)
  if type(robloxId) ~= "number" then
    return false, "RobloxId must be a number"
  end

  if type(itemName) ~= "string" or itemName == "" then
    return false, "Item name cannot be empty"
  end

  if type(itemValue) ~= "number" or itemValue < 0 then
    return false, "Item value must be a positive number"
  end

  stock = stock or 0
  if type(stock) ~= "number" or stock < 0 or stock > 100 then
    return false, "Stock must be between 0 and 100"
  end

  if isLimited == nil then
    isLimited = false
  end

  local itemToEdit = nil
  for _, item in ipairs(self.Items) do
    if item.RobloxId == robloxId then
      itemToEdit = item
      break
    end
  end

  if not itemToEdit then
    return false, "Item with this Roblox ID does not exist"
  end

  local rarity = ItemRarityModule:GetRarity(itemValue)

  itemToEdit.Name = itemName
  itemToEdit.Value = itemValue
  itemToEdit.Rarity = rarity
  itemToEdit.Stock = stock
  itemToEdit.Limited = isLimited

  print("🔧 DEBUG EditItem: Set item.Limited to", isLimited, "| item.Limited is now", itemToEdit.Limited)

  local saveSuccess = self:SaveItems()

  print("🔧 DEBUG EditItem: After save, item.Limited =", itemToEdit.Limited)

  if saveSuccess then
    local stockText = stock > 0 and " [Stock: " .. stock .. "]" or ""
    local limitedText = isLimited and " [Limited]" or ""
    return true, itemToEdit
  else
    return false, "Failed to save edited item to database"
  end
end

function ItemDatabase:GetAllItems()
  return self.Items
end

function ItemDatabase:GetRollableItems()
  local rollableItems = {}
  for _, item in ipairs(self.Items) do
    local stock = item.Stock or 0
    local currentStock = item.CurrentStock or 0

    if stock == 0 or currentStock < stock then
      table.insert(rollableItems, item)
    end
  end
  return rollableItems
end

function ItemDatabase:IncrementStock(item)
  local stock = item.Stock or 0
  local currentStock = item.CurrentStock or 0

  if stock > 0 and currentStock < stock then
    item.CurrentStock = currentStock + 1
    self:QueueSave()

    if item.CurrentStock >= stock then
      print(string.format("🔴 Item went out of stock: %s (%d/%d)", item.Name, item.CurrentStock, stock))

      task.spawn(function()
        local handler = getWebhookHandler()
        if handler then
          handler:SendOutOfStock(item)
        end
      end)
    end

    return item.CurrentStock
  end
  return nil
end

function ItemDatabase:IsSoldOut(item)
  local stock = item.Stock or 0
  local currentStock = item.CurrentStock or 0
  return stock > 0 and currentStock >= stock
end

function ItemDatabase:GetItemByRobloxId(robloxId)
  local numericId = tonumber(robloxId)
  if not numericId then
    warn("❌ ItemDatabase:GetItemByRobloxId - Invalid RobloxId: " .. tostring(robloxId))
    return nil
  end

  for _, item in ipairs(self.Items) do
    if item.RobloxId == numericId then
      return item
    end
  end

  warn("⚠️ ItemDatabase:GetItemByRobloxId - No item found with RobloxId: " .. numericId)
  return nil
end

function ItemDatabase:IncrementOwners(robloxId)
  local numericId = tonumber(robloxId)
  if not numericId then
    warn("❌ ItemDatabase:IncrementOwners - Invalid RobloxId: " .. tostring(robloxId))
    return nil
  end

  local item = self:GetItemByRobloxId(numericId)
  if item then
    local oldOwners = item.Owners or 0
    item.Owners = oldOwners + 1
    self:QueueSave()
    return item.Owners
  else
    return nil
  end
end

function ItemDatabase:IncrementTotalCopies(robloxId, amount)
  local numericId = tonumber(robloxId)
  if not numericId then
    warn("❌ ItemDatabase:IncrementTotalCopies - Invalid RobloxId: " .. tostring(robloxId))
    return nil
  end

  amount = amount or 1

  local item = self:GetItemByRobloxId(numericId)
  if item then
    local oldCopies = item.TotalCopies or 0
    item.TotalCopies = oldCopies + amount
    self:QueueSave()
    return item.TotalCopies
  else
    return nil
  end
end

function ItemDatabase:GetOwners(robloxId)
  local numericId = tonumber(robloxId)
  if not numericId then
    warn("❌ ItemDatabase:GetOwners - Invalid RobloxId: " .. tostring(robloxId))
    return 0
  end

  local item = self:GetItemByRobloxId(numericId)
  if item then
    return item.Owners or 0
  end
  return 0
end

function ItemDatabase:DecrementOwners(robloxId)
  local numericId = tonumber(robloxId)
  if not numericId then
    warn("❌ ItemDatabase:DecrementOwners - Invalid RobloxId: " .. tostring(robloxId))
    return nil
  end

  local item = self:GetItemByRobloxId(numericId)
  if item then
    local oldOwners = item.Owners or 0
    item.Owners = math.max(0, oldOwners - 1)
    self:QueueSave()

    return item.Owners
  else
    warn("❌ ItemDatabase:DecrementOwners - Item not found for RobloxId: " .. numericId)
    return nil
  end
end

function ItemDatabase:DecrementTotalCopies(robloxId, amount)
  local numericId = tonumber(robloxId)
  if not numericId then
    warn("❌ ItemDatabase:DecrementTotalCopies - Invalid RobloxId: " .. tostring(robloxId))
    return nil
  end

  amount = amount or 1

  local item = self:GetItemByRobloxId(numericId)
  if item then
    local oldCopies = item.TotalCopies or 0
    item.TotalCopies = math.max(0, oldCopies - amount)
    self:QueueSave()

    return item.TotalCopies
  else
    warn("❌ ItemDatabase:DecrementTotalCopies - Item not found for RobloxId: " .. numericId)
    return nil
  end
end

function ItemDatabase:DecrementStock(robloxId)
  local numericId = tonumber(robloxId)
  if not numericId then
    warn("❌ ItemDatabase:DecrementStock - Invalid RobloxId: " .. tostring(robloxId))
    return nil
  end

  local item = self:GetItemByRobloxId(numericId)
  if not item then
    warn("❌ ItemDatabase:DecrementStock - Item not found for RobloxId: " .. numericId)
    return nil
  end

  local stock = item.Stock or 0
  local currentStock = item.CurrentStock or 0

  if stock > 0 and currentStock > 0 then
    item.CurrentStock = currentStock - 1
    self:QueueSave()
    return true
  end

  return nil
end

function ItemDatabase:IncreaseStockLimit(robloxId, userId, username)
  local numericId = tonumber(robloxId)
  if not numericId then
    warn("❌ ItemDatabase:IncreaseStockLimit - Invalid RobloxId: " .. tostring(robloxId))
    return nil
  end

  local item = self:GetItemByRobloxId(numericId)
  if not item then
    warn("❌ ItemDatabase:IncreaseStockLimit - Item not found for RobloxId: " .. numericId)
    return nil
  end

  local stock = item.Stock or 0

  if stock > 0 then
    item.Stock = stock + 1
    item.CurrentStock = (item.CurrentStock or 0) + 1

    if userId and username then
      if not item.SerialOwners then
        item.SerialOwners = {}
      end
      table.insert(item.SerialOwners, {
        UserId = userId,
        SerialNumber = item.CurrentStock,
        Username = username
      })
    end

    self:QueueSave()
    print("📈 Increased stock limit for " .. item.Name .. " from " .. stock .. " to " .. item.Stock)
    return item.CurrentStock
  end

  return nil
end

function ItemDatabase:RecordSerialOwner(robloxId, userId, username, serialNumber)
  local numericId = tonumber(robloxId)
  if not numericId then
    warn("❌ ItemDatabase:RecordSerialOwner - Invalid RobloxId: " .. tostring(robloxId))
    return false
  end

  local item = self:GetItemByRobloxId(numericId)
  if not item then
    warn("❌ ItemDatabase:RecordSerialOwner - Item not found for RobloxId: " .. numericId)
    return false
  end

  if not item.SerialOwners then
    item.SerialOwners = {}
  end

  for _, owner in ipairs(item.SerialOwners) do
    if owner.SerialNumber == serialNumber then
      owner.UserId = userId
      owner.Username = username
      self:QueueSave()
      return true
    end
  end

  table.insert(item.SerialOwners, {
    UserId = userId,
    SerialNumber = serialNumber,
    Username = username
  })

  self:QueueSave()
  return true
end

function ItemDatabase:GetSerialOwners(robloxId)
  local numericId = tonumber(robloxId)
  if not numericId then
    warn("❌ ItemDatabase:GetSerialOwners - Invalid RobloxId: " .. tostring(robloxId))
    return {}
  end

  local item = self:GetItemByRobloxId(numericId)
  if not item then
    warn("❌ ItemDatabase:GetSerialOwners - Item not found for RobloxId: " .. numericId)
    return {}
  end

  if not item.SerialOwners or #item.SerialOwners == 0 then
    return {}
  end

  local sorted = {}
  for _, owner in ipairs(item.SerialOwners) do
    table.insert(sorted, {
      UserId = owner.UserId,
      SerialNumber = owner.SerialNumber,
      Username = owner.Username
    })
  end

  table.sort(sorted, function(a, b)
    return a.SerialNumber < b.SerialNumber
  end)

  return sorted
end

function ItemDatabase:DeleteItem(robloxId)
  local numericId = tonumber(robloxId)
  if not numericId then
    return false, "Invalid RobloxId: " .. tostring(robloxId), nil
  end

  local itemIndex = nil
  local itemData = nil
  for i, item in ipairs(self.Items) do
    if item.RobloxId == numericId then
      itemIndex = i
      itemData = item
      break
    end
  end

  if not itemIndex then
    return false, "Item with ID " .. numericId .. " does not exist", nil
  end

  table.remove(self.Items, itemIndex)

  local saveSuccess = self:SaveItems()

  if saveSuccess then
    print("🗑️ Deleted item: " .. itemData.Name .. " (RobloxId: " .. numericId .. ")")
    return true, "Item deleted successfully", itemData
  else
    table.insert(self.Items, itemIndex, itemData)
    return false, "Failed to save deletion to database", nil
  end
end

ItemDatabase.IsReady = false

task.spawn(function()
  local startTime = tick()
  print("⏳ Loading ItemDatabase...")

  ItemDatabase:LoadItems()
  ItemDatabase.IsReady = true

  local loadTime = tick() - startTime
  print(string.format("✅ ItemDatabase ready! Loaded %d items in %.2f seconds", #ItemDatabase.Items, loadTime))
end)

function ItemDatabase:ResetOwnershipData()
  print("🔄 Resetting all ownership data (CurrentStock, Owners, TotalCopies, SerialOwners)...")
  
  local resetCount = 0
  for _, item in ipairs(self.Items) do
    item.CurrentStock = 0
    item.Owners = 0
    item.TotalCopies = 0
    item.SerialOwners = {}
    resetCount = resetCount + 1
  end
  
  local saveSuccess = self:SaveItems()
  
  if saveSuccess then
    print(string.format("✅ Reset ownership data for %d items successfully!", resetCount))
    print("📊 All items now show: 0 owners, 0 copies, 0 stock claimed")
    
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local remoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents")
    if remoteEvents then
      local createItemEvent = remoteEvents:FindFirstChild("CreateItemEvent")
      if createItemEvent then
        createItemEvent:FireAllClients()
      end
    end
    
    return true, string.format("Reset ownership data for %d items", resetCount)
  else
    print("❌ Failed to save reset data")
    return false, "Failed to save reset data"
  end
end

_G.ResetOwnershipData = function()
  return ItemDatabase:ResetOwnershipData()
end

game:BindToClose(function()
  print("🛑 Server shutdown - Force saving ItemDatabase...")
  ItemDatabase._saveQueued = false
  ItemDatabase:SaveItems()
  print("✅ ItemDatabase saved on shutdown")
end)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remoteEventsFolder = ReplicatedStorage:FindFirstChild("RemoteEvents")
if not remoteEventsFolder then
  remoteEventsFolder = Instance.new("Folder")
  remoteEventsFolder.Name = "RemoteEvents"
  remoteEventsFolder.Parent = ReplicatedStorage
end

local getAllItemsFunction = remoteEventsFolder:FindFirstChild("GetAllItemsFunction")
if not getAllItemsFunction then
  getAllItemsFunction = Instance.new("RemoteFunction")
  getAllItemsFunction.Name = "GetAllItemsFunction"
  getAllItemsFunction.Parent = remoteEventsFolder
end

getAllItemsFunction.OnServerInvoke = function(player)
  local itemsCopy = {}
  for i, item in ipairs(ItemDatabase.Items) do
    itemsCopy[i] = {
      RobloxId = item.RobloxId,
      Name = item.Name,
      Value = item.Value,
      Rarity = item.Rarity,
      Stock = item.Stock or 0,
      CurrentStock = item.CurrentStock or 0,
      Owners = item.Owners or 0,
      TotalCopies = item.TotalCopies or 0,
      CreatedAt = item.CreatedAt
    }
  end

  return itemsCopy
end

local getItemOwnersFunction = remoteEventsFolder:FindFirstChild("GetItemOwnersFunction")
if not getItemOwnersFunction then
  getItemOwnersFunction = Instance.new("RemoteFunction")
  getItemOwnersFunction.Name = "GetItemOwnersFunction"
  getItemOwnersFunction.Parent = remoteEventsFolder
end

getItemOwnersFunction.OnServerInvoke = function(player, robloxId)
  return ItemDatabase:GetSerialOwners(robloxId)
end

return ItemDatabase
