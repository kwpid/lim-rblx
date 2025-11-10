local HttpService = game:GetService("HttpService")
local ItemRarityModule = require(game.ReplicatedStorage.ItemRarityModule)

local WebhookHandler = {}

local WebhookConfig
local configSuccess, configError = pcall(function()
        WebhookConfig = require(script.Parent.WebhookConfig)
end)

local function getWebhookUrl(configKey)
        if configSuccess and WebhookConfig and WebhookConfig[configKey] then
                return WebhookConfig[configKey]
        end

        return ""
end

local ITEM_RELEASE_WEBHOOK = getWebhookUrl("ITEM_RELEASE_WEBHOOK")
local ITEM_DROP_WEBHOOK = getWebhookUrl("ITEM_DROP_WEBHOOK")
local MARKETPLACE_WEBHOOK = getWebhookUrl("MARKETPLACE_WEBHOOK")

if not configSuccess then
        warn("WebhookConfig module not found - webhooks will be disabled. Create ServerScriptService/WebhookConfig.lua to enable webhooks.")
end

local RARITY_COLORS = {
        ["Common"] = 11184810,     -- #AAAAAA (Gray)
        ["Uncommon"] = 5614165,    -- #55AA55 (Green)
        ["Rare"] = 5592575,        -- #5555FF (Blue)
        ["Ultra Rare"] = 11167999, -- #AA55FF (Purple)
        ["Epic"] = 16755200,       -- #FFAA00 (Orange)
        ["Ultra Epic"] = 16733440, -- #FF5500 (Red-Orange)
        ["Mythic"] = 16711680,     -- #FF0000 (Red)
        ["Insane"] = 16711935      -- #FF00FF (Magenta)
}

local function formatNumber(n)
        local formatted = tostring(n)
        while true do
                formatted, k = formatted:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
                if k == 0 then break end
        end
        return formatted
end

local function getRarityColor(rarity)
        return RARITY_COLORS[rarity] or 16777215
end

local function sendWebhook(webhookUrl, payload)
        local success, result = pcall(function()
                local jsonPayload = HttpService:JSONEncode(payload)
                HttpService:PostAsync(webhookUrl, jsonPayload, Enum.HttpContentType.ApplicationJson, false)
        end)

        if not success then
                warn("failed to send Discord webhook: " .. tostring(result))
                return false
        end

        return true
end

function WebhookHandler:SendItemRelease(item, rollPercentage)
        local rarityColor = getRarityColor(item.Rarity)

        local description = string.format("**Rarity:**\n%s\n\n**Value:**\nR$ %s\n\n**Roll %%:**\n%.4f%%",
                item.Rarity,
                formatNumber(item.Value),
                rollPercentage or 0
        )

        if item.Stock and item.Stock > 0 then
                description = description .. string.format("\n\n**Stock:**\n%d", item.Stock)
        end

        local payload = {
                embeds = { {
                        title = item.Name,
                        description = description,
                        color = rarityColor,
                        thumbnail = {
                                url = string.format("https://assetdelivery.roblox.com/v1/asset?id=%d", item.RobloxId)
                        },
                        footer = {
                                text = "New Item Release"
                        },
                        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
                } }
        }

        if item.Value >= 250000 then
                payload.content = "<@&1381033979502661722>"
        end

        local success = sendWebhook(ITEM_RELEASE_WEBHOOK, payload)


        return success
end

function WebhookHandler:SendHighValueUnbox(player, item, source)
        local rarityColor = getRarityColor(item.Rarity)

        source = source or "roll"
        local sourceText = "Rolled"
        local title = "High-Value Item Rolled"

        if source == "event" then
                sourceText = "Event Drop"
                title = "High-Value Item from Event"
        elseif source == "barrel" then
                sourceText = "Barrel Pull"
                title = "High-Value Item from Barrel"
        end

        local description = string.format("**Player:**\n%s\n\n**Item:**\n%s\n\n**Value:**\nR$ %s\n\n**Source:**\n%s",
                player.Name,
                item.Name,
                formatNumber(item.Value),
                sourceText
        )

        if item.SerialNumber then
                description = description .. string.format("\n\n**Serial:**\n#%d", item.SerialNumber)
        end

        local playerThumbnailUrl = string.format(
                "https://www.roblox.com/headshot-thumbnail/image?userId=%d&width=150&height=150&format=png", player.UserId)

        local payload = {
                embeds = { {
                        title = title,
                        description = description,
                        color = rarityColor,
                        thumbnail = {
                                url = playerThumbnailUrl
                        },
                        image = {
                                url = string.format("https://assetdelivery.roblox.com/v1/asset?id=%d", item.RobloxId)
                        },
                        footer = {
                                text = sourceText
                        },
                        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
                } }
        }

        local success = sendWebhook(ITEM_DROP_WEBHOOK, payload)



        return success
end

function WebhookHandler:SendItemDrop(player, item, serialNumber)
        local itemData = {
                RobloxId = item.RobloxId,
                Name = item.Name,
                Value = item.Value,
                Rarity = item.Rarity,
                SerialNumber = serialNumber
        }
        return self:SendHighValueUnbox(player, itemData, "roll")
end

function WebhookHandler:SendOutOfStock(item)
        local rarityColor = getRarityColor(item.Rarity)

        local description = string.format(
                "**Item:**\n%s\n\n**Rarity:**\n%s\n\n**Value:**\nR$ %s\n\n**Stock:**\n%d/%d (SOLD OUT)",
                item.Name,
                item.Rarity,
                formatNumber(item.Value),
                item.CurrentStock or item.Stock,
                item.Stock
        )

        local payload = {
                embeds = { {
                        title = "Item Out of Stock!",
                        description = description,
                        color = rarityColor,
                        thumbnail = {
                                url = string.format("https://assetdelivery.roblox.com/v1/asset?id=%d", item.RobloxId)
                        },
                        footer = {
                                text = "Out of Stock"
                        },
                        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
                } }
        }

        local success = sendWebhook(ITEM_DROP_WEBHOOK, payload)

        return success
end

function WebhookHandler:SendMarketplaceSale(buyerPlayer, sellerUsername, item, price, saleType, sellerReceives)
        if not MARKETPLACE_WEBHOOK or MARKETPLACE_WEBHOOK == "" then
                return false
        end

        local rarityColor = getRarityColor(item.Rarity)

        local priceText = ""
        local sellerGets = ""
        if saleType == "cash" then
                priceText = "$" .. formatNumber(price)
                sellerGets = "$" .. formatNumber(sellerReceives or price) .. " (after 15% tax)"
        else
                priceText = "R$" .. formatNumber(price)
                sellerGets = "R$" .. formatNumber(sellerReceives or price) .. " (after 15% tax)"
        end

        local description = string.format(
                "**Buyer:**\n%s\n\n**Seller:**\n%s\n\n**Item:**\n%s\n\n**Sale Price:**\n%s\n\n**Seller Receives:**\n%s\n\n**Item Value:**\nR$ %s",
                buyerPlayer.Name,
                sellerUsername,
                item.Name,
                priceText,
                sellerGets,
                formatNumber(item.Value)
        )

        if item.SerialNumber then
                description = description .. string.format("\n\n**Serial:**\n#%d", item.SerialNumber)
        end

        local buyerThumbnailUrl = string.format(
                "https://www.roblox.com/headshot-thumbnail/image?userId=%d&width=150&height=150&format=png",
                buyerPlayer.UserId
        )

        local payload = {
                embeds = { {
                        title = "Marketplace Sale!",
                        description = description,
                        color = rarityColor,
                        thumbnail = {
                                url = buyerThumbnailUrl
                        },
                        image = {
                                url = string.format("https://assetdelivery.roblox.com/v1/asset?id=%d", item.RobloxId)
                        },
                        footer = {
                                text = "Marketplace Sale - " .. (saleType == "cash" and "Cash" or "Robux")
                        },
                        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
                } }
        }

        local success = sendWebhook(MARKETPLACE_WEBHOOK, payload)

        return success
end

return WebhookHandler
