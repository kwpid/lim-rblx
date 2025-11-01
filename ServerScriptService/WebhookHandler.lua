-- WebhookHandler.lua
-- Handles Discord webhook notifications for item releases and drops

local HttpService = game:GetService("HttpService")
local ItemRarityModule = require(game.ReplicatedStorage.ItemRarityModule)

local WebhookHandler = {}

-- ═══════════════════════════════════════════════════════════════════════════
-- 🔒 SECURITY WARNING: CONFIGURE WEBHOOK URLs IN WebhookConfig
-- ═══════════════════════════════════════════════════════════════════════════
-- Do NOT commit actual webhook URLs to source control!
-- The WebhookConfig module should be in .gitignore and configured per environment
-- ═══════════════════════════════════════════════════════════════════════════

-- Try to load webhook config (should be in .gitignore)
local WebhookConfig
local configSuccess, configError = pcall(function()
        WebhookConfig = require(script.Parent.WebhookConfig)
end)

-- Fallback to empty strings if config not found
local ITEM_RELEASE_WEBHOOK = ""
local ITEM_DROP_WEBHOOK = ""

if configSuccess and WebhookConfig then
        ITEM_RELEASE_WEBHOOK = WebhookConfig.ITEM_RELEASE_WEBHOOK or ""
        ITEM_DROP_WEBHOOK = WebhookConfig.ITEM_DROP_WEBHOOK or ""
        print("✅ Loaded webhook configuration")
else
        warn("⚠️ WebhookConfig not found - webhooks will not be sent")
        warn("   Create ServerScriptService/WebhookConfig.lua with your webhook URLs")
end

-- Rarity colors for Discord embeds (decimal format)
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

-- Format number with commas
local function formatNumber(n)
        local formatted = tostring(n)
        while true do
                formatted, k = formatted:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
                if k == 0 then break end
        end
        return formatted
end

-- Get rarity color for Discord embed
local function getRarityColor(rarity)
        return RARITY_COLORS[rarity] or 16777215 -- Default to white
end

-- Send webhook to Discord
local function sendWebhook(webhookUrl, payload)
        local success, result = pcall(function()
                local jsonPayload = HttpService:JSONEncode(payload)
                HttpService:PostAsync(webhookUrl, jsonPayload, Enum.HttpContentType.ApplicationJson, false)
        end)
        
        if not success then
                warn("⚠️ Failed to send Discord webhook: " .. tostring(result))
                return false
        end
        
        return true
end

-- Send new item release notification
function WebhookHandler:SendItemRelease(item, rollPercentage)
        local rarityColor = getRarityColor(item.Rarity)
        
        -- Build description
        local description = string.format("**Rarity:**\n%s\n\n**Value:**\nR$ %s\n\n**Roll %%:**\n%.4f%%",
                item.Rarity,
                formatNumber(item.Value),
                rollPercentage or 0
        )
        
        -- Add stock information if available
        if item.Stock and item.Stock > 0 then
                description = description .. string.format("\n\n**Stock:**\n%d", item.Stock)
        end
        
        local payload = {
                embeds = {{
                        title = item.Name,
                        description = description,
                        color = rarityColor,
                        thumbnail = {
                                url = string.format("https://www.roblox.com/asset-thumbnail/image?assetId=%d&width=420&height=420&format=png", item.RobloxId)
                        },
                        footer = {
                                text = "New Item Release"
                        },
                        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
                }}
        }
        
        local success = sendWebhook(ITEM_RELEASE_WEBHOOK, payload)
        
        if success then
                print("📢 Sent item release webhook for: " .. item.Name)
        end
        
        return success
end

-- Send high-value item drop notification
function WebhookHandler:SendItemDrop(player, item, serialNumber)
        local rarityColor = getRarityColor(item.Rarity)
        
        -- Build description
        local description = string.format("**Player:**\n%s\n\n**Item:**\n%s\n\n**Value:**\nR$ %s",
                player.Name,
                item.Name,
                formatNumber(item.Value)
        )
        
        -- Add serial number if available
        if serialNumber then
                description = description .. string.format("\n\n**Serial:**\n#%d", serialNumber)
        end
        
        -- Get player thumbnail URL
        local playerThumbnailUrl = string.format("https://www.roblox.com/headshot-thumbnail/image?userId=%d&width=150&height=150&format=png", player.UserId)
        
        local payload = {
                embeds = {{
                        title = "🎉 High-Value Item Unboxed!",
                        description = description,
                        color = rarityColor,
                        thumbnail = {
                                url = playerThumbnailUrl
                        },
                        image = {
                                url = string.format("https://www.roblox.com/asset-thumbnail/image?assetId=%d&width=420&height=420&format=png", item.RobloxId)
                        },
                        footer = {
                                text = "Item Drop"
                        },
                        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
                }}
        }
        
        local success = sendWebhook(ITEM_DROP_WEBHOOK, payload)
        
        if success then
                print(string.format("📢 Sent item drop webhook: %s unboxed %s", player.Name, item.Name))
        end
        
        return success
end

-- Send out of stock notification
function WebhookHandler:SendOutOfStock(item)
        local rarityColor = getRarityColor(item.Rarity)
        
        local description = string.format("**Item:**\n%s\n\n**Rarity:**\n%s\n\n**Value:**\nR$ %s\n\n**Stock:**\n%d/%d (SOLD OUT)",
                item.Name,
                item.Rarity,
                formatNumber(item.Value),
                item.CurrentStock or item.Stock,
                item.Stock
        )
        
        local payload = {
                embeds = {{
                        title = "🔴 Item Out of Stock!",
                        description = description,
                        color = rarityColor,
                        thumbnail = {
                                url = string.format("https://www.roblox.com/asset-thumbnail/image?assetId=%d&width=420&height=420&format=png", item.RobloxId)
                        },
                        footer = {
                                text = "Out of Stock"
                        },
                        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
                }}
        }
        
        local success = sendWebhook(ITEM_DROP_WEBHOOK, payload)
        
        if success then
                print("📢 Sent out of stock webhook for: " .. item.Name)
        end
        
        return success
end

return WebhookHandler
