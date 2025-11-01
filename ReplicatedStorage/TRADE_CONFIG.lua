-- TRADE_CONFIG.lua
-- Configuration for the trading system adapted for crate opening game

local config = {}

-------Settings you can change-------
config.MaxSlots = 10 -- Maximum items that can be offered in a trade
config.TimeBeforeTradeConfirmed = 5 -- Countdown timer before trade completes (seconds)
config.AllowStockItemTrades = false -- Set to true to allow trading of stock items (items with serial numbers)
-------------------------------------

-- Stock items (items with SerialNumbers) cannot be traded by default
-- Regular items can be traded and will stack properly

return config