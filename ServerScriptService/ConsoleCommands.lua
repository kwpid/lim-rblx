-- ConsoleCommands.lua
-- Sets up global console commands for admins

local ItemDatabase = require(script.Parent.ItemDatabase)

-- Wait for ItemDatabase to be ready
repeat
	task.wait(0.1)
until ItemDatabase.IsReady

-- Global command to reset ownership data
_G.ResetOwnershipData = function()
	return ItemDatabase:ResetOwnershipData()
end

-- Global command to check database
_G.CheckDatabase = function()
	print("\n========== ITEM DATABASE ==========")
	local items = ItemDatabase:GetAllItems()
	
	table.sort(items, function(a, b)
		return a.Value > b.Value
	end)
	
	for i, item in ipairs(items) do
		local stockText = ""
		if item.Stock and item.Stock > 0 then
			stockText = string.format(" [Stock: %d/%d]", item.CurrentStock or 0, item.Stock)
		end
		
		local ownersText = string.format(" [Owners: %d, Copies: %d]", item.Owners or 0, item.TotalCopies or 0)
		
		print(string.format("%d. %s - R$ %s (%s)%s%s", 
			i, 
			item.Name, 
			tostring(item.Value), 
			item.Rarity,
			stockText,
			ownersText
		))
	end
	
	print(string.format("\nTotal Items: %d", #items))
	print("===================================\n")
end

-- Global command to check rarities
_G.CheckRarities = function()
	print("\n========== RARITY BREAKDOWN ==========")
	local items = ItemDatabase:GetAllItems()
	local rarityCounts = {}
	
	for _, item in ipairs(items) do
		local rarity = item.Rarity or "Unknown"
		rarityCounts[rarity] = (rarityCounts[rarity] or 0) + 1
	end
	
	local rarityOrder = {"Common", "Uncommon", "Rare", "Ultra Rare", "Epic", "Ultra Epic", "Mythic", "Insane"}
	
	for _, rarity in ipairs(rarityOrder) do
		local count = rarityCounts[rarity] or 0
		if count > 0 then
			print(string.format("%s: %d items", rarity, count))
		end
	end
	
	print(string.format("\nTotal Items: %d", #items))
	print("======================================\n")
end

print("✅ Console commands ready: ResetOwnershipData(), CheckDatabase(), CheckRarities()")
