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
-- MATCH THIS WITH DATASTORE MANAGER
local DATA_VERSION = "DataVersion.30"

local ItemDatabase = {}
ItemDatabase.Items = {}
ItemDatabase.DataVersion = DATA_VERSION
ItemDatabase._saveQueued = false
ItemDatabase._lastSaveTime = 0

local SAVE_DEBOUNCE_TIME = 3

function ItemDatabase:QueueSave()
  if self._saveQueued then return end
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
      local items, savedVersion
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
        item.Stock = item.Stock or 0
        item.CurrentStock = item.CurrentStock or 0
        item.Owners = item.Owners or 0
        item.TotalCopies = item.TotalCopies or 0
        item.SerialOwners = item.SerialOwners or {}
        item.OffsaleAt = item.OffsaleAt or nil
        
        if item.Limited == true and item.Rarity ~= "Limited" then
          item.Rarity = "Limited"
        end
        item.Limited = nil
      end
    else
      self.Items = {}
      self.DataVersion = DATA_VERSION
    end
  end)
  if not success then
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
  return success
end

function ItemDatabase:AddItem(robloxId, itemName, itemValue, stock, isLimited, offsaleTimer)
  if type(robloxId) ~= "number" then return false, "RobloxId must be a number" end
  if type(itemName) ~= "string" or itemName == "" then return false, "Item name cannot be empty" end
  if type(itemValue) ~= "number" or itemValue < 0 then return false, "Item value must be a positive number" end
  stock = stock or 0
  if type(stock) ~= "number" or stock < 0 or stock > 100 then return false, "Stock must be between 0 and 100" end
  isLimited = isLimited or false
  offsaleTimer = offsaleTimer or 0
  
  for _, item in ipairs(self.Items) do
    if item.RobloxId == robloxId then return false, "Item with this Roblox ID already exists" end
  end
  
  local rarity = ItemRarityModule:GetRarity(itemValue, isLimited)
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
    OffsaleAt = offsaleTimer > 0 and (os.time() + offsaleTimer) or nil,
    CreatedAt = os.time()
  }
  table.insert(self.Items, newItem)
  local saveSuccess = self:SaveItems()
  if saveSuccess then
    return true, newItem
  else
    table.remove(self.Items, #self.Items)
    return false, "Failed to save item to database"
  end
end

function ItemDatabase:EditItem(robloxId, itemName, itemValue, stock, isLimited, offsaleTimer)
  if type(robloxId) ~= "number" then return false, "RobloxId must be a number" end
  if type(itemName) ~= "string" or itemName == "" then return false, "Item name cannot be empty" end
  if type(itemValue) ~= "number" or itemValue < 0 then return false, "Item value must be a positive number" end
  stock = stock or 0
  if type(stock) ~= "number" or stock < 0 or stock > 100 then return false, "Stock must be between 0 and 100" end
  isLimited = isLimited or false
  offsaleTimer = offsaleTimer or 0
  
  local itemToEdit
  for _, item in ipairs(self.Items) do
    if item.RobloxId == robloxId then
      itemToEdit = item
      break
    end
  end
  if not itemToEdit then return false, "Item with this Roblox ID does not exist" end
  
  local rarity = ItemRarityModule:GetRarity(itemValue, isLimited)
  itemToEdit.Name = itemName
  itemToEdit.Value = itemValue
  itemToEdit.Rarity = rarity
  itemToEdit.Stock = stock
  itemToEdit.OffsaleAt = offsaleTimer > 0 and (os.time() + offsaleTimer) or nil
  
  local saveSuccess = self:SaveItems()
  if saveSuccess then
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
    if item.Rarity ~= "Limited" and item.Rarity ~= "Vanity" then
      local stock = item.Stock or 0
      local currentStock = item.CurrentStock or 0
      if stock == 0 or currentStock < stock then
        local offsaleAt = item.OffsaleAt
        if not offsaleAt or os.time() < offsaleAt then
          table.insert(rollableItems, item)
        end
      end
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
      task.spawn(function()
        local handler = getWebhookHandler()
        if handler then handler:SendOutOfStock(item) end
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
  if not numericId then return nil end
  for _, item in ipairs(self.Items) do
    if item.RobloxId == numericId then return item end
  end
  return nil
end

function ItemDatabase:EnsureVanityItem(robloxId, itemName, itemValue)
  local existingItem = self:GetItemByRobloxId(robloxId)
  if existingItem then
    if existingItem.Rarity ~= "Vanity" then
      existingItem.Rarity = "Vanity"
      self:QueueSave()
    end
    return existingItem
  end
  
  local newItem = {
    RobloxId = robloxId,
    Name = itemName,
    Value = itemValue,
    Rarity = "Vanity",
    Stock = 0,
    CurrentStock = 0,
    Owners = 0,
    TotalCopies = 0,
    SerialOwners = {},
    OffsaleAt = nil,
    CreatedAt = os.time()
  }
  table.insert(self.Items, newItem)
  self:QueueSave()
  return newItem
end

function ItemDatabase:IncrementOwners(robloxId)
  local item = self:GetItemByRobloxId(robloxId)
  if item then
    item.Owners = (item.Owners or 0) + 1
    self:QueueSave()
    return item.Owners
  end
  return nil
end

function ItemDatabase:IncrementTotalCopies(robloxId, amount)
  local item = self:GetItemByRobloxId(robloxId)
  if item then
    item.TotalCopies = (item.TotalCopies or 0) + (amount or 1)
    self:QueueSave()
    return item.TotalCopies
  end
  return nil
end

function ItemDatabase:GetOwners(robloxId)
  local item = self:GetItemByRobloxId(robloxId)
  return item and item.Owners or 0
end

function ItemDatabase:DecrementOwners(robloxId)
  local item = self:GetItemByRobloxId(robloxId)
  if item then
    item.Owners = math.max(0, (item.Owners or 0) - 1)
    self:QueueSave()
    return item.Owners
  end
  return nil
end

function ItemDatabase:DecrementTotalCopies(robloxId, amount)
  local item = self:GetItemByRobloxId(robloxId)
  if item then
    item.TotalCopies = math.max(0, (item.TotalCopies or 0) - (amount or 1))
    self:QueueSave()
    return item.TotalCopies
  end
  return nil
end

function ItemDatabase:DecrementStock(robloxId)
  local item = self:GetItemByRobloxId(robloxId)
  if not item then return nil end
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
  local item = self:GetItemByRobloxId(robloxId)
  if not item then return nil end
  local stock = item.Stock or 0
  if stock > 0 then
    item.Stock = stock + 1
    item.CurrentStock = (item.CurrentStock or 0) + 1
    if userId and username then
      item.SerialOwners = item.SerialOwners or {}
      table.insert(item.SerialOwners, {
        UserId = userId,
        SerialNumber = item.CurrentStock,
        Username = username
      })
    end
    self:QueueSave()
    return item.CurrentStock
  end
  return nil
end

function ItemDatabase:RecordSerialOwner(robloxId, userId, username, serialNumber)
  local item = self:GetItemByRobloxId(robloxId)
  if not item then return false end
  item.SerialOwners = item.SerialOwners or {}
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
  local item = self:GetItemByRobloxId(robloxId)
  if not item or not item.SerialOwners or #item.SerialOwners == 0 then return {} end
  local sorted = {}
  for _, owner in ipairs(item.SerialOwners) do
    table.insert(sorted, {
      UserId = owner.UserId,
      SerialNumber = owner.SerialNumber,
      Username = owner.Username
    })
  end
  table.sort(sorted, function(a, b) return a.SerialNumber < b.SerialNumber end)
  return sorted
end

function ItemDatabase:DeleteItem(robloxId)
  local numericId = tonumber(robloxId)
  if not numericId then return false, "Invalid RobloxId: " .. tostring(robloxId), nil end
  local itemIndex, itemData
  for i, item in ipairs(self.Items) do
    if item.RobloxId == numericId then
      itemIndex = i
      itemData = item
      break
    end
  end
  if not itemIndex then return false, "Item with ID " .. numericId .. " does not exist", nil end
  table.remove(self.Items, itemIndex)
  local saveSuccess = self:SaveItems()
  if saveSuccess then
    return true, "Item deleted successfully", itemData
  else
    table.insert(self.Items, itemIndex, itemData)
    return false, "Failed to save deletion to database", nil
  end
end

ItemDatabase.IsReady = false

task.spawn(function()
  ItemDatabase:LoadItems()
  ItemDatabase.IsReady = true
end)

function ItemDatabase:ResetOwnershipData()
  for _, item in ipairs(self.Items) do
    item.CurrentStock = 0
    item.Owners = 0
    item.TotalCopies = 0
    item.SerialOwners = {}
  end
  self:SaveItems()
  local ReplicatedStorage = game:GetService("ReplicatedStorage")
  local remoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents")
  if remoteEvents then
    local createItemEvent = remoteEvents:FindFirstChild("CreateItemEvent")
    if createItemEvent then
      createItemEvent:FireAllClients()
    end
  end
  return true
end

_G.ResetOwnershipData = function()
  return ItemDatabase:ResetOwnershipData()
end

game:BindToClose(function()
  ItemDatabase._saveQueued = false
  ItemDatabase:SaveItems()
end)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local remoteEventsFolder = ReplicatedStorage:FindFirstChild("RemoteEvents") or Instance.new("Folder")
remoteEventsFolder.Name = "RemoteEvents"
remoteEventsFolder.Parent = ReplicatedStorage

local getAllItemsFunction = remoteEventsFolder:FindFirstChild("GetAllItemsFunction") or Instance.new("RemoteFunction")
getAllItemsFunction.Name = "GetAllItemsFunction"
getAllItemsFunction.Parent = remoteEventsFolder

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

local getItemOwnersFunction = remoteEventsFolder:FindFirstChild("GetItemOwnersFunction") or
    Instance.new("RemoteFunction")
getItemOwnersFunction.Name = "GetItemOwnersFunction"
getItemOwnersFunction.Parent = remoteEventsFolder

getItemOwnersFunction.OnServerInvoke = function(player, robloxId)
  return ItemDatabase:GetSerialOwners(robloxId)
end

return ItemDatabase
