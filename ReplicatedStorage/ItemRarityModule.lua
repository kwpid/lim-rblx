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

ItemRarityModule.LimitedColor = Color3.fromRGB(255, 215, 0)

function ItemRarityModule:GetRarity(value, isLimited)
  if isLimited then
    return "Limited"
  end
  
  for _, tier in ipairs(self.RarityTiers) do
    if value >= tier.Min and value <= tier.Max then
      return tier.Name
    end
  end
  return "Unknown"
end

function ItemRarityModule:GetRarityColor(rarity)
  if type(rarity) == "string" then
    if rarity == "Limited" then
      return self.LimitedColor
    end
    
    for _, tier in ipairs(self.RarityTiers) do
      if tier.Name == rarity then
        return tier.Color
      end
    end
  else
    for _, tier in ipairs(self.RarityTiers) do
      if rarity >= tier.Min and rarity <= tier.Max then
        return tier.Color
      end
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

function ItemRarityModule:GetRollPercentage(value, totalValue)
  if totalValue == 0 then return 0 end

  local inverseValue = 1 / (value ^ 0.9)
  local percentage = (inverseValue / totalValue) * 100

  return percentage
end

function ItemRarityModule:CalculateAllRollPercentages(items)
  local totalInverseValue = 0
  for _, item in ipairs(items) do
    totalInverseValue = totalInverseValue + (1 / (item.Value ^ 0.9))
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
