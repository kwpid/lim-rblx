local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local gui = script.Parent
local buttons = {}

local handler = gui:WaitForChild("Handler", 5)
if not handler then
        warn("handler not found in marketplace gui")
        return
end

local sample = script:FindFirstChild("Sample")
if not sample then
        warn("sample template not found")
        return
end

local buyInfo = gui:FindFirstChild("BuyInfo")
if not buyInfo then
        warn("buyInfo not found in marketplace gui")
        return
end

buyInfo.Visible = false

local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents", 10)
if not remoteEvents then
        warn("remoteevents folder not found")
        return
end

local getListingsFunction = remoteEvents:WaitForChild("GetListingsFunction", 10)
local purchaseListingEvent = remoteEvents:WaitForChild("PurchaseListingEvent", 10)
local cancelListingEvent = remoteEvents:WaitForChild("CancelListingEvent", 10)

if not getListingsFunction then
        warn("getListingsFunction not found")
        return
end

local rarityColors = {
        ["Common"] = Color3.fromRGB(170, 170, 170),
        ["Uncommon"] = Color3.fromRGB(85, 170, 85),
        ["Rare"] = Color3.fromRGB(85, 85, 255),
        ["Ultra Rare"] = Color3.fromRGB(170, 85, 255),
        ["Epic"] = Color3.fromRGB(255, 170, 0),
        ["Ultra Epic"] = Color3.fromRGB(255, 85, 0),
        ["Mythic"] = Color3.fromRGB(255, 0, 0),
        ["Insane"] = Color3.fromRGB(255, 0, 255),
        ["Limited"] = Color3.fromRGB(255, 215, 0)
}

local selectedListing = nil

function formatNumber(n)
        local formatted = tostring(n)
        while true do
                formatted, k = formatted:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
                if k == 0 then break end
        end
        return formatted
end

function refresh()
        local listings
        local success, err = pcall(function()
                listings = getListingsFunction:InvokeServer()
        end)

        if not success or not listings or type(listings) ~= "table" then
                warn("failed to load marketplace listings")
                return false
        end

        for _, button in pairs(buttons) do
                button:Destroy()
        end
        buttons = {}

        table.sort(listings, function(a, b)
                return a.ItemData.Value > b.ItemData.Value
        end)

        for i, listing in ipairs(listings) do
                local item = listing.ItemData
                local button = sample:Clone()
                button.Name = item.Name or "Listing_" .. i
                button.LayoutOrder = i
                button.Visible = true
                button.Parent = handler

                local uiStroke = button:FindFirstChildOfClass("UIStroke")
                if uiStroke then
                        local rarityColor = rarityColors[item.Rarity] or Color3.new(1, 1, 1)
                        uiStroke.Color = rarityColor
                        uiStroke.Thickness = 5.5
                end

                local serialLabel = button:FindFirstChild("Serial")
                if serialLabel then
                        if item.SerialNumber then
                                serialLabel.Text = "#" .. item.SerialNumber
                                serialLabel.Visible = true
                        else
                                serialLabel.Visible = false
                        end
                end

                local rareText = button:FindFirstChild("RareText")
                if rareText then
                        local copiesCount = 0
                        if item.Stock and item.Stock > 0 then
                                copiesCount = item.CurrentStock or 0
                        end
                        if copiesCount > 0 and copiesCount <= 25 then
                                rareText.Visible = true
                        else
                                rareText.Visible = false
                        end
                end

                local limText = button:FindFirstChild("LimText")
                if limText then
                        if item.Rarity == "Limited" then
                                limText.Visible = true
                        else
                                limText.Visible = false
                        end
                end

                if button:IsA("ImageButton") then
                        button.Image = "rbxthumb://type=Asset&id=" .. item.RobloxId .. "&w=150&h=150"
                end

                table.insert(buttons, button)

                button.MouseButton1Click:Connect(function()
                        selectedListing = listing
                        buyInfo.Visible = true

                        local popFrame = buyInfo:FindFirstChild("Pop")
                        if not popFrame then
                                warn("Pop frame not found in BuyInfo")
                                return
                        end

                        local userInfo = popFrame:FindFirstChild("UserInfo")
                        if userInfo then
                                local playerPFP = userInfo:FindFirstChild("PlayerPFP")
                                local username = userInfo:FindFirstChild("Username")

                                if playerPFP and playerPFP:IsA("ImageLabel") then
                                        local thumbType = Enum.ThumbnailType.HeadShot
                                        local thumbSize = Enum.ThumbnailSize.Size150x150
                                        local content, isReady = Players:GetUserThumbnailAsync(listing.SellerUserId, thumbType, thumbSize)
                                        playerPFP.Image = content
                                end

                                if username then
                                        username.Text = "@" .. listing.SellerUsername
                                end
                        end

                        local itemInfo = popFrame:FindFirstChild("ItemInfo")
                        if itemInfo then
                                local itemPhoto = itemInfo:FindFirstChild("ItemPhoto")
                                local itemName = itemInfo:FindFirstChild("ItemName")
                                local itemValue = itemInfo:FindFirstChild("ItemValue")
                                local itemSerial = itemInfo:FindFirstChild("ItemSerial")

                                if itemPhoto then
                                        itemPhoto.Image = "rbxthumb://type=Asset&id=" .. item.RobloxId .. "&w=150&h=150"
                                end

                                if itemName then
                                        itemName.Text = item.Name
                                end

                                if itemValue then
                                        itemValue.Text = "R$ " .. formatNumber(item.Value)
                                end

                                if itemSerial then
                                        if item.SerialNumber then
                                                itemSerial.Visible = true
                                                itemSerial.Text = "#" .. item.SerialNumber
                                        else
                                                itemSerial.Visible = false
                                        end
                                end
                        end

                        local buyPriceLabel = popFrame:FindFirstChild("BuyPrice")
                        if buyPriceLabel then
                                if listing.ListingType == "cash" then
                                        buyPriceLabel.Text = "Price: $" .. formatNumber(listing.Price)
                                elseif listing.ListingType == "robux" then
                                        buyPriceLabel.Text = "Price: R$" .. formatNumber(listing.Price) .. " (Gamepass)"
                                end
                        end

                        local confirmBtn = popFrame:FindFirstChild("Confirm")
                        if confirmBtn then
                                if listing.IsOwnListing then
                                        confirmBtn.Text = "Cancel Listing"
                                else
                                        confirmBtn.Text = "Purchase"
                                end
                        end
                end)
        end

        return true
end

local popFrame = buyInfo:FindFirstChild("Pop")
if popFrame then
        local confirmBtn = popFrame:FindFirstChild("Confirm")
        if confirmBtn then
                confirmBtn.MouseButton1Click:Connect(function()
                        if not selectedListing then return end

                        if selectedListing.IsOwnListing then
                                cancelListingEvent:FireServer(selectedListing.ListingId)
                        else
                                purchaseListingEvent:FireServer(selectedListing.ListingId)
                        end

                        buyInfo.Visible = false
                        selectedListing = nil
                        task.wait(0.5)
                        pcall(refresh)
                end)
        end

        local cancelBtn = popFrame:FindFirstChild("Cancel")
        if cancelBtn then
                cancelBtn.MouseButton1Click:Connect(function()
                        buyInfo.Visible = false
                        selectedListing = nil
                end)
        end
else
        warn("Pop frame not found in BuyInfo for button connections")
end

local function loadListingsWithRetry()
        local maxRetries = 10
        local retryDelay = 0.5

        for attempt = 1, maxRetries do
                task.wait(retryDelay)

                local success, result = pcall(refresh)
                if success and result == true then
                        return
                end

                retryDelay = math.min(retryDelay * 2, 4)
                warn(string.format("marketplace load attempt %d/%d failed, retrying in %.1fs",
                        attempt, maxRetries, retryDelay))
        end

        warn("failed to load marketplace after " .. maxRetries .. " attempts")
end

task.spawn(loadListingsWithRetry)

gui:GetPropertyChangedSignal("Visible"):Connect(function()
        if gui.Visible then
                pcall(refresh)
        end
end)

local inventoryUpdatedEvent = remoteEvents:FindFirstChild("InventoryUpdatedEvent")
if inventoryUpdatedEvent then
        inventoryUpdatedEvent.OnClientEvent:Connect(function()
                if gui.Visible then
                        pcall(refresh)
                end
        end)
end

print("MarketplaceUI loaded successfully")
