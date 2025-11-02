local ItemRarityModule = {}
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

function ItemRarityModule:GetRarityColor(value)
  for _, tier in ipairs(self.RarityTiers) do
    if value >= tier.Min and value <= tier.Max then
      return tier.Color
    end
  end
  return Color3.fromRGB(255, 255, 255)
end

function ItemRarityModule:GetRarityInfo(value)
  for _, tier in ipairs(self.RarityTiers) do
    if value >= tier.Min and value <= tier.Max then
      return tier
    end
  end
  return nil
end

-- Power of 1.0 = steeper rarity curve (rare items more rare)
function ItemRarityModule:GetRollPercentage(value, totalValue)
  if totalValue == 0 then return 0 end

  local inverseValue = 1 / (value ^ 1.0)
  local percentage = (inverseValue / totalValue) * 100

  return percentage
end

function ItemRarityModule:CalculateAllRollPercentages(items)
  local totalInverseValue = 0
  for _, item in ipairs(items) do
    totalInverseValue = totalInverseValue + (1 / (item.Value ^ 1.0))
  end

  local itemsWithPercentages = {}
  for _, item in ipairs(items) do
    local itemCopy = table.clone(item)
    itemCopy.RollPercentage = self:GetRollPercentage(item.Value, totalInverseValue)
    table.insert(itemsWithPercentages, itemCopy)
  end

  return itemsWithPercentages
end

return ItemRarityModule
