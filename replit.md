# Project Memory

## Overview
This project is a Roblox crate opening/unboxing game designed to provide an engaging unboxing experience. Players can open virtual crates to acquire items of varying rarities and values, managed by a weighted probability system. Key features include a player-to-player trading system, comprehensive admin tools for item management, robust data persistence, an interactive inventory, Discord webhook notifications, and the ability to equip virtual goods. The project aims to offer a feature-rich and dynamic virtual economy within Roblox.

## Recent Changes
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
-   **Item System**: Supports regular and limited stock items across eight rarity tiers with weighted probability drops. Items can be marked as "Limited" with a special indicator.
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
-   Notification system provides feedback for actions.
-   Hover effects with yellow glow for viewing other players' inventories.
-   Unified MainUI system combines Inventory and Index into a single ScreenGui with toggle buttons.
-   Inventory and Index popups use smooth slide-in/out animations and clear selection states.
-   AutoRoll and HideRolls buttons have UIStroke colors indicating their state.
-   Event status is displayed in the MainUI.
-   Trade offers display item images using ItemImage1 element with QtySerial text showing "xN" for quantities or "#N" for serial numbers.
-   Real-time value displays (YourValue and TheirValue) update dynamically during trading.
-   Trade history interface accessible via OpenHistory button shows past trades with player avatars and full trade details.

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