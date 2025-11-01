# Project Memory

## Overview
This project is a Roblox crate opening/unboxing game. It allows players to open virtual crates to acquire items of varying rarities and values. Key features include weighted probability rolls, comprehensive admin tools for item management, robust data persistence, an interactive inventory system, and the ability to equip and trade virtual goods. The game aims to deliver an engaging unboxing experience within the Roblox platform.

## User Preferences
- User will test the game in Roblox and provide feedback
- Agent cannot test in Roblox, so user is responsible for testing
- Iterative development: User tests → Reports bugs/requests → Agent implements → Repeat
- User wants a living documentation file that tracks game details

## Recent Changes (November 1, 2025)
- **Fixed CratesClient Initialization Delay**: Changed ItemDatabase to load asynchronously instead of blocking the require() call. This eliminates the 10-15 second delay before the crate opening UI becomes responsive when players join. RemoteEvents are now created immediately on server startup.
- **Client Optimization**: Reduced WaitForChild timeouts and improved initialization speed in CratesClient.lua for faster UI responsiveness.

## System Architecture

### Core Game Systems
-   **Item System**: Supports regular and limited stock items with up to 8 rarity tiers. Weighted probability governs item drops.
-   **Crate Opening**: Features weighted random selection, visual scrolling animation with rarity-colored item names, and serial number display for stock items. Includes "Fast Roll" for gamepass owners and "AutoRoll" and "HideRolls" toggles with persistence. High-value unboxes trigger chat notifications (server-wide and cross-server global).
-   **Admin Tools**: Whitelisted admin GUI for creating, giving, and deleting items with live previews, auto-fill for item names, and confirmation dialogs. Includes global "New Item" notifications.
-   **Data Persistence**: Uses Roblox DataStore Service for player inventories (with auto-stacking), rolls, cash, inventory value, AutoRoll state, HideRolls state, and Luck multiplier. Features auto-save, data versioning, and automatic cleanup of deleted items.
-   **Anti-AFK System**: Automatically rejoins players every 15 minutes to prevent AFK disconnection. Perfect for overnight AutoRoll farming sessions.
-   **Inventory Display**: Shows owned items with thumbnails, rarity colors, and serial numbers. Displays accurate copy counts for both stackable and stock items. Includes search/filter functionality and detailed item info on click. RareText appears only on items with less than 25 copies. Equipped items appear first and have an orange border.
-   **View Other Players' Inventories**: Allows players to view others' inventories via a GUI activated by clicking on a highlighted player. Features structured error handling and retry logic.
-   **Equipping Items**: Players can equip/unequip items (accessories, hats, tools) which persist across sessions and are visible to other players. Headless items are handled by setting head transparency. Tools are placed in the player's Backpack.
-   **Selling Items**: Players can sell regular items for 80% of their value with confirmation. Stock items cannot be sold.
-   **Index System**: Displays all game items with details, owner lists for stock items (with serial numbers), and refresh capabilities. Includes roll percentage display with smart decimal handling.
-   **Halloween Event Luck System**: A temporary luck system affecting Epic+ rarity items (value 250k+). Player Luck attribute and a Global Luck Modifier combine. Luck > 1.0 performs multiple rolls and picks the highest value Epic+ item; Luck < 1.0 picks the lowest. Maximum 10 rolls for performance.

### UI/UX Decisions
-   Item names are color-coded by rarity in the crate animation and inventory.
-   Admin panel is a graphical interface.
-   Notification system provides feedback for actions.
-   Hover effect with yellow glow for viewing other players' inventories.

### Technical Implementations
-   `RemoteEvents` and `RemoteFunctions` are used for client-server communication.
-   ItemDatabase loads asynchronously (non-blocking) to ensure RemoteEvents are created immediately on server startup.
-   Roll handler includes readiness check with graceful 30-second timeout if ItemDatabase is slow to load.
-   Roblox `InsertService` is used for equipping items.
-   Roblox `MarketplaceService` checks Fast Roll gamepass ownership.
-   DataStore operations include error logging and validation.
-   Inventory value (`InvValue`) is automatically calculated.
-   Uses `MessagingService` for cross-server notifications.
-   Utilizes `TeleportService` for auto-rejoin on server shutdown and every 15 minutes to prevent AFK kicks.
-   Equipping accessories uses `Humanoid:AddAccessory()`.

### File Structure (Key Directories)
-   `ReplicatedStorage/`: `ItemRarityModule.lua`
-   `ServerScriptService/`: `AdminConfig.lua`, `AdminItemHandler.lua`, `AntiAFKHandler.lua`, `CratesServer.lua`, `DataStoreAPI.lua`, `DataStoreManager.lua`, `ItemDatabase.lua`, `PlayerDataHandler.lua`, `EquipSellHandler.lua`, `ServerShutdownHandler.lua`
-   `StarterGUI/`: `AdminGUI.lua`, `CratesClient.lua`, `InventorySystem.lua`, `IndexLocal.lua`, `ViewPlayerInventory.lua`

## External Dependencies
-   **Roblox DataStore Service**: Persistent data storage for player data and global item database.
-   **Roblox API Services**: Requires "Studio Access to API Services" enabled.
-   **Roblox InsertService**: Loads and attaches accessories/tools.
-   **Roblox MarketplaceService**: Checks gamepass ownership (ID: 1242040274).
-   **Roblox MessagingService**: Cross-server notifications for ultra-rare unboxes.
-   **Roblox TeleportService**: Handles automatic player rejoining on server shutdowns.