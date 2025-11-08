local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BadgeService = game:GetService("BadgeService")
local Players = game:GetService("Players")

local MasteryCollections = require(ReplicatedStorage:WaitForChild("MasteryCollections"))

local remoteEventsFolder = ReplicatedStorage:FindFirstChild("RemoteEvents") or Instance.new("Folder")
remoteEventsFolder.Name = "RemoteEvents"
remoteEventsFolder.Parent = ReplicatedStorage

local checkMasteryCompletedFunction = Instance.new("RemoteFunction")
checkMasteryCompletedFunction.Name = "CheckMasteryCompletedFunction"
checkMasteryCompletedFunction.Parent = remoteEventsFolder

local awardMasteryBadgeEvent = Instance.new("RemoteEvent")
awardMasteryBadgeEvent.Name = "AwardMasteryBadgeEvent"
awardMasteryBadgeEvent.Parent = remoteEventsFolder

local notificationEvent = remoteEventsFolder:FindFirstChild("CreateNotification")
if not notificationEvent then
	notificationEvent = Instance.new("RemoteEvent")
	notificationEvent.Name = "CreateNotification"
	notificationEvent.Parent = remoteEventsFolder
end

local function getPlayerData(player)
	return _G.PlayerData[player.UserId]
end

local function playerOwnsAllItems(player, itemsList)
	local playerData = getPlayerData(player)
	if not playerData or not playerData.Inventory then
		return false
	end
	
	for _, requiredItemId in ipairs(itemsList) do
		local ownsItem = false
		for _, invItem in ipairs(playerData.Inventory) do
			if invItem.RobloxId == requiredItemId then
				ownsItem = true
				break
			end
		end
		if not ownsItem then
			return false
		end
	end
	
	return true
end

local function checkBadgeOwnership(userId, badgeId)
	if badgeId == 0 then
		return false
	end
	
	local success, hasBadge = pcall(function()
		return BadgeService:UserHasBadgeAsync(userId, badgeId)
	end)
	
	if success then
		return hasBadge
	else
		warn("Failed to check badge ownership for user " .. userId .. ", badge " .. badgeId)
		return false
	end
end

local function awardBadge(userId, badgeId)
	if badgeId == 0 then
		warn("Cannot award badge: BadgeId is 0 (not configured)")
		return false
	end
	
	local success, result = pcall(function()
		BadgeService:AwardBadge(userId, badgeId)
	end)
	
	if success then
		print("Awarded badge " .. badgeId .. " to user " .. userId)
		return true
	else
		warn("Failed to award badge " .. badgeId .. " to user " .. userId .. ": " .. tostring(result))
		return false
	end
end

checkMasteryCompletedFunction.OnServerInvoke = function(player, collectionName)
	for _, collection in ipairs(MasteryCollections.Collections) do
		if collection.Name == collectionName then
			if collection.BadgeId == 0 then
				return false
			end
			
			return checkBadgeOwnership(player.UserId, collection.BadgeId)
		end
	end
	
	return false
end

awardMasteryBadgeEvent.OnServerEvent:Connect(function(player, collectionName)
	local collection = nil
	for _, coll in ipairs(MasteryCollections.Collections) do
		if coll.Name == collectionName then
			collection = coll
			break
		end
	end
	
	if not collection then
		warn("Collection '" .. collectionName .. "' not found")
		return
	end
	
	if collection.BadgeId == 0 then
		warn("Cannot award badge for '" .. collectionName .. "': BadgeId not configured (set to 0)")
		notificationEvent:FireClient(player, {
			Type = "ERROR",
			Title = "Badge Not Configured",
			Body = "This mastery doesn't have a badge configured yet"
		})
		return
	end
	
	if #collection.Items == 0 then
		warn("Cannot complete mastery '" .. collectionName .. "': No items configured")
		return
	end
	
	local alreadyHasBadge = checkBadgeOwnership(player.UserId, collection.BadgeId)
	if alreadyHasBadge then
		print("Player " .. player.Name .. " already has badge for " .. collectionName)
		return
	end
	
	local ownsAll = playerOwnsAllItems(player, collection.Items)
	if not ownsAll then
		warn("Player " .. player.Name .. " tried to claim mastery '" .. collectionName .. "' but doesn't own all items")
		return
	end
	
	local awarded = awardBadge(player.UserId, collection.BadgeId)
	if awarded then
		notificationEvent:FireClient(player, {
			Type = "VICTORY",
			Title = "Mastery Completed!",
			Body = "You completed the " .. collectionName .. " mastery!"
		})
	end
end)

print("MasteryHandler loaded successfully")
