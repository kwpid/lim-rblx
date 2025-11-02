# Project Memory

## Overview
This project is a Roblox crate opening/unboxing game designed to provide an engaging unboxing experience. Players can open virtual crates to acquire items of varying rarities and values, managed by a weighted probability system. Key features include a player-to-player trading system, comprehensive admin tools for item management, robust data persistence, an interactive inventory, Discord webhook notifications, and the ability to equip virtual goods. The project aims to offer a feature-rich and dynamic virtual economy within Roblox.

## Recent Changes
- **2025-11-02**: Added max stack limit system for regular items - Players can now only hold a maximum of 100 copies of any regular item (Common to Ultra Rare rarities). When adding items would exceed this limit, excess copies are automatically sold at 80% value and the cash is added to the player's account. Epic, Ultra Epic, Mythic, and Insane items have no stack limit. Includes data migration that auto-sells excess items when players join the game.
- **2025-11-02**: Fixed event system not auto-starting - EventSystem.lua was a ModuleScript that wasn't being required on server startup, preventing automatic event spawning. Added require() for EventSystem in CratesServer.lua so it initializes on server start, enabling the 5-10 minute random event spawner to work properly.
- **2025-11-02**: Fixed critical serial owner preservation bug - RecordSerialOwner function was incorrectly updating existing owners instead of preserving the original owner. When player1 traded serial #1 to player2, it would incorrectly show player2 as the original owner. Now the function properly preserves the first person who obtained the serial as the permanent original owner, preventing any updates to existing serial ownership records.
- **2025-11-02**: Fixed search functionality in ViewInventory UI (TradeClient) - the SearchBar in ViewInventoryFrame now properly filters items when viewing other players' inventories during trades. Previously, there was no search functionality connected to the SearchBar at all. Now the search connection is created each time an inventory is loaded and properly cleaned up when the view is closed.
- **2025-11-02**: Fixed equipped items remaining on character after being traded away - when a player trades away an item they're currently wearing, it now automatically unequips from their character and is removed from their EquippedItems data. This prevents players from visually wearing items they no longer own.
- **2025-11-02**: Improved trade UI clarity - trade inventory now shows clean "0/3" format (amount in trade / total owned) instead of "x0/3". Offer frames still show "2x" format for clarity about what's being offered.
- **2025-11-02**: Fixed critical serial number skipping bug in event system - serial numbers are now claimed ONLY when a player collects the item, not when the item is dropped. This prevents "lost" serial numbers when event items despawn without being collected. If a stock item sells out between drop and collection, player gets a notification that the item sold out.
- **2025-11-02**: Improved trade history value display - values now show as "Gave: 3.00K" and "For: 5.00K" with K/M/B formatting instead of comparing with +/- symbols. Makes it clearer to see the total value of items given and received.
- **2025-11-02**: Fixed critical trading quantity bug - items with quantities (e.g., 3 eggs) now transfer the full amount instead of just 1. Updated DataStoreAPI:AddItem to use the passed Amount parameter instead of hardcoding to 1. Verified serial/stock items don't stack and serial numbers are properly preserved during trades.
- **2025-11-02**: Fixed QtySerial real-time updates - trade offer slots now dynamically update quantity text when multiple of the same item are added. Attached GetPropertyChangedSignal listeners to Amount values both at slot creation and when Amount is added later.
- **2025-11-02**: Added ViewInventory feature to trade UI - players can now view another player's inventory by clicking the ViewInventory button in PlayerFrame during trade request. Uses Sample button from TradeClient script and mirrors regular inventory display with all data fields (rarity colors, quantities, serials, RareText, LimText badges, etc.). Feature includes proper cleanup when switching between players and closing the view.
- **2025-11-02**: Enhanced trade notifications - added notification to other player when ongoing trade is cancelled/rejected (ERROR type with "Trade Cancelled" message). Complements existing notifications for trade requests, acceptances, and declinations.
- **2025-11-02**: Fixed QtySerial display consistency - trade inventory now shows "x0/5" format (amount in trade/total owned) while offer slots show "x2" format (amount being offered). Simplified itemsToDisplay logic to prevent duplicate tracking and item re-adding bugs.
- **2025-11-02**: Added comprehensive trade notification system - players receive notifications when they receive a trade request (VICTORY type), when their request is accepted (VICTORY type), and when their request is declined (ERROR type). Notifications use the existing CreateNotification RemoteEvent system.
- **2025-11-02**: Accept button now dynamically changes text - shows "Accepted" when player accepts the trade, and changes back to "Accept" when items are added/removed (leveraging server-side ACCEPTED tag resets).
- **2025-11-02**: Added 3-second countdown timer to trades - after both players accept, a countdown displays giving them one last chance to decline before the trade completes. Players can un-accept during the countdown to cancel.
- **2025-11-02**: Fixed trade UI not closing after completion - added explicit "trade completed" events to both clients ensuring the trade UI closes properly after items are transferred.
- **2025-11-02**: Fixed critical data migration bug - DataStoreManager now preserves existing player data when adding new fields like TradeHistory. Previously, version changes would reset all player data (wiping Player1, Player2 inventories). Now properly migrates data by backfilling missing fields while preserving existing inventory, rolls, equipped items, etc.
- **2025-11-02**: Added inventory search functionality during trades - players can filter their inventory by item name using the SearchInv textbox in the trade UI. Search is case-insensitive and updates in real-time as you type.
- **2025-11-02**: Implemented complete trade history system with persistent storage. Players can view their last 50 trades including partner name/avatar, date/time, items exchanged, and total values. Trade history persists across sessions and is accessed via the OpenHistory button in the trade UI.
- **2025-11-02**: Added real-time value tracking to active trades. YourValue and TheirValue labels update dynamically as items are added or removed from either side of the trade, showing the total value being offered.
- **2025-11-02**: Updated trade system UI to fix image display and quantity/serial numbering. Item images now correctly reference ItemImage1 element. Trade offers use QtySerial text to display "xN" for stackable items or "#N" for serial items. Items in the trade can be clicked to remove them. Item names show cleanly without embedded quantity/serial text.
- **2025-11-02**: Fixed critical race condition in trading system where TradeClient would hang indefinitely if it loaded before TradeServer created required folders. Added 30-second timeouts to all WaitForChild calls and comprehensive debug logging to both TradeServer and TradeClient for easier diagnosis.

## User Preferences
- User will test the game in Roblox and provide feedback
- Agent cannot test in Roblox, so user is responsible for testing
- Iterative development: User tests → Reports bugs/requests → Agent implements → Repeat
- User wants a living documentation file that tracks game details

## System Architecture

### Core Game Systems
-   **Item System**: Supports regular and limited stock items across eight rarity tiers with weighted probability drops. Items can be marked as "Limited" with a special indicator. Regular items (Common to Ultra Rare) have a max stack limit of 100 copies per item - excess copies are automatically sold at 80% value when items are added to inventory. Epic+ items have no stack limit.
-   **Crate Opening**: Features weighted random selection, visual scrolling animations, and serial number display for stock items. Includes "Fast Roll" for gamepass owners, "AutoRoll," and "HideRolls" toggles. High-value unboxes trigger server-wide and cross-server notifications.
-   **Luck System**: A three-tier luck system allows for separate, multiplicatively stacking luck multipliers for different rarity groups (Regular, Mythic, Insane). This system directly boosts the probability of Epic+ items appearing and includes admin-only console commands for testing specific rarities.
-   **Event System**: Dynamic, modular event system with automatic spawning (5-10 minute intervals) and manual admin triggers. The "Random Item Drops" event spawns actual Roblox item models with rarity-colored highlights and proximity prompts. Event probabilities use rarity-based multipliers, favoring rare items.
-   **Admin Tools**: A whitelisted graphical interface for creating, editing, giving, and deleting items with live previews, auto-fill, and confirmation dialogs. Includes global notifications for item changes and a "LimitedToggle" button. Admins can manually trigger events.
-   **Data Persistence**: Utilizes Roblox DataStore Service for player inventories (with auto-stacking), rolls, cash, inventory value, AutoRoll/HideRolls state, Luck multipliers, and trade history. Features auto-save, data versioning, and automatic cleanup. A debounced/batched save system prevents DataStore queue overload.
-   **Anti-AFK System**: Automatically rejoins players who haven't moved in 15 minutes to prevent AFK disconnection.
-   **Inventory Display**: Shows owned items with thumbnails, rarity colors, serial numbers, search/filter, and detailed info. Displays "RareText" for items with 25 or fewer copies and "LimText" for Limited items. Equipped items are prioritized with an orange border.
-   **View Other Players' Inventories**: Allows players to inspect other users' inventories via GUI with structured error handling.
-   **Equipping Items**: Players can equip/unequip accessories, hats, and tools that persist across sessions and are visible to others. Handles headless items and tool placement in the player's Backpack.
-   **Selling Items**: Players can sell regular items for 80% of their value with confirmation; stock items cannot be sold.
-   **Index System**: Displays all game items with details, owner lists (including serial numbers), and refresh capabilities. Shows roll percentages and "RareText"/"LimText" where applicable.
-   **Trading System**: Player-to-player trading system integrated with inventory data. Supports trade requests, adding stacked/serial items, dual acceptance, item transfer via DataStoreAPI (preserving serial numbers and ownership), and trade cancellation on player leave/death. Max 8 items per player per trade with a 0.5s confirmation delay. Features real-time value tracking showing both players' offer values, and persistent trade history (last 50 trades) with full details including partner info, items exchanged, values, and timestamps.

### UI/UX Decisions
-   Item names are color-coded by rarity in animations and inventory.
-   Admin panel is a graphical interface.
-   Notification system provides feedback for actions including trade requests (VICTORY type), acceptances (VICTORY type), and rejections (ERROR type).
-   Hover effects with yellow glow for viewing other players' inventories.
-   Unified MainUI system combines Inventory and Index into a single ScreenGui with toggle buttons.
-   Inventory and Index popups use smooth slide-in/out animations and clear selection states.
-   AutoRoll and HideRolls buttons have UIStroke colors indicating their state.
-   Event status is displayed in the MainUI.
-   Trade offers display item images using ItemImage1 element with QtySerial text. Inventory items show "x0/5" format (amount in trade/total owned) while offer slots show "x2" format (amount being offered). Serial items display "#1" format.
-   Real-time value displays (YourValue and TheirValue) update dynamically during trading.
-   Trade history interface accessible via OpenHistory button shows past trades with player avatars and full trade details.
-   Accept button dynamically changes text to "Accepted" when the player accepts, reverting to "Accept" when items are added/removed.

### Technical Implementations
-   `RemoteEvents` and `RemoteFunctions` for client-server communication.
-   Asynchronous ItemDatabase loading to prevent UI blocking.
-   Debounced DataStore saves with a 3-second debounce for batching changes, critical operations save immediately.
-   SerialOwner repair system automatically fixes missing records on player join.
-   `HideRolls` system disables the crate opening GUI to prevent input blocking while clearing items between rolls.
-   Roblox `InsertService` for equipping items.
-   Roblox `MarketplaceService` for gamepass checks.
-   Roblox `MessagingService` for cross-server notifications.
-   Roblox `TeleportService` for auto-rejoin.
-   `Humanoid:AddAccessory()` for equipping accessories.

## External Dependencies
-   **Roblox DataStore Service**: Persistent data storage for player data and global item database.
-   **Roblox API Services**: Requires "Studio Access to API Services" enabled.
-   **Roblox InsertService**: Loads and attaches accessories/tools.
-   **Roblox MarketplaceService**: Checks gamepass ownership (ID: 1242040274).
-   **Roblox MessagingService**: Cross-server notifications for ultra-rare unboxes.
-   **Roblox TeleportService**: Handles automatic player rejoining on server shutdowns.
-   **Discord Webhooks**: For new item releases, high-value drops, and out-of-stock notifications (requires configuration in `ServerScriptService/WebhookConfig.lua`).