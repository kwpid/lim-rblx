-- ItemRarityModule.lua
-- Determines rarity based on item value and calculates roll percentages

local ItemRarityModule = {}

-- Rarity tiers with value ranges
ItemRarityModule.RarityTiers = {
  { Name = "Common",     Min = 1,        Max = 2499,      Color = Color3.fromRGB(170, 170, 170) },
  { Name = "Uncommon",   Min = 2500,     Max = 9999,      Color = Color3.fromRGB(85, 170, 85) },
  { Name = "Rare",       Min = 10000,    Max = 49999,     Color = Color3.fromRGB(85, 85, 255) },
  { Name = "Ultra Rare", Min = 50000,    Max = 250999,    Color = Color3.fromRGB(170, 85, 255) },
  { Name = "Epic",       Min = 250000,   Max = 750000,    Color = Color3.fromRGB(255, 170, 0) },
  { Name = "Ultra Epic", Min = 750000,   Max = 2500000,   Color = Color3.fromRGB(255, 85, 0) },
  { Name = "Mythic",     Min = 2500000,  Max = 9999999,   Color = Color3.fromRGB(255, 0, 0) },
  { Name = "Insane",     Min = 10000000, Max = math.huge, Color = Color3.fromRGB(255, 0, 255) }
}

-- Get rarity name from value
function ItemRarityModule:GetRarity(value)
  for _, tier in ipairs(self.RarityTiers) do
    if value >= tier.Min and value <= tier.Max then
      return tier.Name
    end
  end
  return "Unknown"
end

-- Get rarity color from value
function ItemRarityModule:GetRarityColor(value)
  for _, tier in ipairs(self.RarityTiers) do
    if value >= tier.Min and value <= tier.Max then
      return tier.Color
    end
  end
  return Color3.fromRGB(255, 255, 255)
end

-- Get rarity tier info
function ItemRarityModule:GetRarityInfo(value)
  for _, tier in ipairs(self.RarityTiers) do
    if value >= tier.Min and value <= tier.Max then
      return tier
    end
  end
  return nil
end

-- Calculate roll percentage (higher value = lower chance)
-- Uses power of 0.6 inverse scaling for balanced percentage distribution
function ItemRarityModule:GetRollPercentage(value, totalValue)
  if totalValue == 0 then return 0 end

  -- Power of 0.6 inverse relationship: higher value = lower percentage
  local inverseValue = 1 / (value ^ 0.6)
  local percentage = (inverseValue / totalValue) * 100

  return percentage
end

-- Calculate all roll percentages for a list of items
function ItemRarityModule:CalculateAllRollPercentages(items)
  -- Calculate total inverse value using power of 0.6
  local totalInverseValue = 0
  for _, item in ipairs(items) do
    totalInverseValue = totalInverseValue + (1 / (item.Value ^ 0.6))
  end

  -- Calculate each item's percentage
  local itemsWithPercentages = {}
  for _, item in ipairs(items) do
    local itemCopy = table.clone(item)
    itemCopy.RollPercentage = self:GetRollPercentage(item.Value, totalInverseValue)
    table.insert(itemsWithPercentages, itemCopy)
  end

  return itemsWithPercentages
end

return ItemRarityModule
